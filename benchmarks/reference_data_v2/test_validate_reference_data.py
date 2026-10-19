import copy
import json
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import validate_reference_data as checker  # noqa: E402


class ReferenceDataTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads((HERE / "reference_manifest.json").read_text(encoding="utf-8"))
        cls.protocol = json.loads((HERE / "inverse_protocol.json").read_text(encoding="utf-8"))

    def test_real_package_hashes_schema_and_split(self):
        result = checker.validate_manifest(self.manifest, self.protocol, checker.ROOT)
        self.assertEqual(result["status"], "pass")
        self.assertEqual(result["formal_inverse"], "not_executed")
        self.assertEqual(result["b07b"], "not_claimed")

    def test_raw_array_schema_resolves_density_unit_for_acquired_bytes(self):
        mast = [r for r in self.manifest["references"] if r.get("device_name") == "MAST"]
        self.assertEqual(len(mast), 2)
        for ref in mast:
            self.assertEqual(ref["raw_schema"]["arrays"]["thomson_scattering/n_e"]["units"], "1 / m ** 3")
            self.assertTrue(ref["raw_schema"]["arrays"]["thomson_scattering/n_e"]["has_raw_chunk"])
            self.assertEqual(ref["raw_schema"]["measurement_uncertainty"]["status"], "typed_absent")
        self.assertEqual(self.manifest["references"][0]["catalog_unit_conflict"]["catalog_reported_unit"], "eV")

    def test_metadata_only_is_rejected(self):
        bad = copy.deepcopy(self.manifest)
        next(r for r in bad["references"] if r.get("shot_id") == 30421)["raw_data_obtained"] = False
        with self.assertRaises(checker.ValidationError):
            checker.validate_manifest(bad, self.protocol, checker.ROOT)

    def test_wrong_raw_unit_is_rejected(self):
        bad = copy.deepcopy(self.manifest)
        ref = next(r for r in bad["references"] if r.get("shot_id") == 30421)
        ref["raw_schema"]["arrays"]["thomson_scattering/n_e"]["units"] = "eV"
        with self.assertRaises(checker.ValidationError):
            checker.validate_manifest(bad, self.protocol, checker.ROOT)

    def test_split_leakage_is_rejected(self):
        bad = copy.deepcopy(self.manifest)
        bad["split_protocol"]["held_out_shot_ids"].append(30421)
        with self.assertRaises(checker.ValidationError):
            checker.validate_manifest(bad, self.protocol, checker.ROOT)

    def test_observation_id_overlap_is_rejected_in_manifest_and_protocol(self):
        bad_manifest = copy.deepcopy(self.manifest)
        bad_manifest["split_protocol"]["validation_observation_ids"].append(
            bad_manifest["split_protocol"]["calibration_observation_ids"][0]
        )
        with self.assertRaises(checker.ValidationError):
            checker.validate_manifest(bad_manifest, self.protocol, checker.ROOT)

        bad_protocol = copy.deepcopy(self.protocol)
        bad_protocol["split"]["validation"]["observation_ids"].append(
            bad_protocol["split"]["calibration"]["observation_ids"][0]
        )
        with self.assertRaises(checker.ValidationError):
            checker.validate_manifest(self.manifest, bad_protocol, checker.ROOT)

    def test_anchor_copy_is_rejected(self):
        bad = copy.deepcopy(self.manifest)
        cal = next(r for r in bad["references"] if r.get("shot_id") == 30421)
        hold = next(r for r in bad["references"] if r.get("shot_id") == 30420)
        cal_chunk = next(x for x in cal["raw_files"] if x["kind"] == "zarr_v3_chunk_thomson_scattering_n_e")
        hold_chunk = next(x for x in hold["raw_files"] if x["kind"] == "zarr_v3_chunk_thomson_scattering_n_e")
        hold_chunk["sha256"] = cal_chunk["sha256"]
        with self.assertRaises(checker.ValidationError):
            checker.validate_manifest(bad, self.protocol, checker.ROOT)

    def test_protocol_freezes_eight_starts_and_three_layers(self):
        self.assertEqual(self.protocol["multi_start"]["required_count"], 8)
        self.assertEqual(len(self.protocol["multi_start"]["starts"]), 8)
        layers = {x["layer"] for x in self.manifest["references"][0]["unknown_theta"]}
        self.assertEqual(layers, {"G1", "G2", "G3"})
        self.assertEqual(self.protocol["formal_execution"]["status"], "not_executed")

    def test_g3_uses_observed_metadata_keys_without_inventing_values(self):
        mapping = next(x for x in self.manifest["references"][0]["theta_to_genome_mapping"] if x["genome_layer"] == "G3")
        self.assertEqual(mapping["source_paths"], ["shot_metadata.plasma_max_current", "shot_metadata.plasma_time_avg_current"])
        self.assertNotIn("value", mapping)

    def test_catalog_raw_identity_mismatch_is_explicit_and_unproven(self):
        mismatch = self.manifest["references"][0]["catalog_vs_raw_identity_mismatch"]
        self.assertEqual(mismatch["root_cause_status"], "unproven")
        self.assertTrue(mismatch["normalization"].startswith("none_declared"))


if __name__ == "__main__":
    unittest.main()
