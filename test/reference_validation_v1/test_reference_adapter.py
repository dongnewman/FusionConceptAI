from __future__ import annotations

import json
import hashlib
import sys
import tempfile
import unittest
from dataclasses import replace
from pathlib import Path

import numpy as np


ROOT = Path(__file__).resolve().parents[2]
ADAPTER_DIR = ROOT / "benchmarks" / "reference_validation_v1"
sys.path.insert(0, str(ADAPTER_DIR))

import reference_adapter as adapter  # noqa: E402


class ReferenceAdapterTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.package = adapter.load_reference_package()

    def test_real_raw_arrays_are_decoded_and_canonicalized(self) -> None:
        expected = {
            (30421, "n_e"): ((135, 121), 11905, "m^-3"),
            (30421, "t_e"): ((135, 121), 11905, "eV"),
            (30420, "n_e"): ((77, 121), 5982, "m^-3"),
            (30420, "t_e"): ((77, 121), 5982, "eV"),
        }
        self.assertEqual(len(self.package.observations), 4)
        for key, (shape, count, unit) in expected.items():
            observation = self.package.observation(*key)
            self.assertEqual(observation.canonical_dimensions, ("time", "major_radius"))
            self.assertEqual(observation.canonical_shape, shape)
            self.assertEqual(observation.observed_count, count)
            self.assertEqual(observation.canonical_unit, unit)
            self.assertEqual(observation.axis_permutation, (1, 0))
            self.assertTrue(np.all(np.diff(observation.time_s) > 0.0))
            self.assertTrue(np.all(np.diff(observation.major_radius_m) > 0.0))

    def test_every_sample_preserves_raw_to_canonical_index_and_hash(self) -> None:
        observation = self.package.observation(30421, "n_e")
        samples = list(adapter.iter_canonical_samples(observation))
        self.assertEqual(len(samples), observation.observed_count)
        first = samples[0]
        raw_r, raw_t = first["raw_index"]
        canonical_t, canonical_r = first["canonical_index"]
        self.assertEqual((raw_r, raw_t), (canonical_r, canonical_t))
        self.assertEqual(first["value"], observation.values[canonical_t, canonical_r])
        self.assertEqual(len(first["sample_sha256"]), 64)
        self.assertEqual(
            len({sample["sample_id"] for sample in samples}), observation.observed_count
        )

    def test_catalog_conflict_is_decoded_and_never_used_as_a_conversion(self) -> None:
        expected_shapes = {30421: [146, 120], 30420: [88, 120]}
        for shot_id in (30421, 30420):
            observation = self.package.observation(shot_id, "n_e")
            comparison = observation.catalog_comparison
            self.assertEqual(comparison["status"], "conflict_preserved")
            self.assertEqual(comparison["root_cause_status"], "unproven")
            self.assertEqual(comparison["catalog_dimensions"], ["time", "major_radius"])
            self.assertEqual(comparison["catalog_shape"], expected_shapes[shot_id])
            self.assertEqual(comparison["catalog_unit"], "eV")
            self.assertEqual(comparison["catalog_quality"], "Not Checked")
            self.assertEqual(comparison["normalization"], "none")
            self.assertEqual(observation.raw_unit, "1 / m ** 3")

    def test_dimension_unit_and_coordinate_shape_negatives_fail_closed(self) -> None:
        raw = np.ones((3, 4), dtype=np.float64)
        time = np.arange(4, dtype=np.float64)
        radius = np.arange(3, dtype=np.float64)
        with self.assertRaisesRegex(adapter.AdapterError, "dimension_contract_error"):
            adapter.canonicalize_profile(
                raw,
                raw_dimensions=("time", "channel"),
                raw_unit="1 / m ** 3",
                channel="n_e",
                time_s=time,
                major_radius_m=radius,
            )
        with self.assertRaisesRegex(adapter.AdapterError, "unit_contract_error"):
            adapter.canonicalize_profile(
                raw,
                raw_dimensions=("major_radius", "time"),
                raw_unit="eV",
                channel="n_e",
                time_s=time,
                major_radius_m=radius,
            )
        with self.assertRaisesRegex(adapter.AdapterError, "time_alignment_error"):
            adapter.canonicalize_profile(
                raw,
                raw_dimensions=("major_radius", "time"),
                raw_unit="1 / m ** 3",
                channel="n_e",
                time_s=np.arange(5, dtype=np.float64),
                major_radius_m=radius,
            )

    def test_exact_grid_operator_and_negative_controls(self) -> None:
        observation = self.package.observation(30420, "t_e")
        projection = adapter.apply_thomson_sample_operator(
            observation,
            observation.values.copy(),
            "eV",
            observation.major_radius_m.copy(),
            observation.time_s.copy(),
        )
        self.assertEqual(projection.operator_status, "idealized_same_grid_sample_projection")
        self.assertTrue(np.array_equal(projection.observed_values, projection.predicted_values))
        self.assertFalse(projection.likelihood_ready)
        with self.assertRaisesRegex(adapter.AdapterError, "prediction_unit_error"):
            adapter.apply_thomson_sample_operator(
                observation,
                observation.values,
                "J",
                observation.major_radius_m,
                observation.time_s,
            )
        with self.assertRaisesRegex(adapter.AdapterError, "prediction_shape_error"):
            adapter.apply_thomson_sample_operator(
                observation,
                observation.values[:, :-1],
                "eV",
                observation.major_radius_m,
                observation.time_s,
            )
        shifted_time = observation.time_s.copy()
        shifted_time[0] += 1e-12
        with self.assertRaisesRegex(adapter.AdapterError, "prediction_time_grid_error"):
            adapter.apply_thomson_sample_operator(
                observation,
                observation.values,
                "eV",
                observation.major_radius_m,
                shifted_time,
            )

    def test_uncertainty_is_scoped_typed_absent_and_likelihood_is_rejected(self) -> None:
        self.assertEqual(self.package.uncertainty["status"], "typed_absent")
        self.assertEqual(
            self.package.uncertainty["scope"],
            "selected_fair_mast_level2_thomson_profiles",
        )
        self.assertEqual(
            self.package.uncertainty["candidate_level1_error_arrays"]["status"],
            "discovered_unbound_not_consumed",
        )
        with self.assertRaisesRegex(adapter.AdapterError, "uncertainty_typed_absent"):
            self.package.require_likelihood_ready()

    def test_package_uncertainty_or_claim_mutation_cannot_enable_readiness(self) -> None:
        mutated_uncertainty = dict(self.package.uncertainty)
        mutated_uncertainty["status"] = "present_bound"
        mutated_uncertainty["likelihood_ready"] = True
        mutated = replace(self.package, uncertainty=mutated_uncertainty)
        with self.assertRaisesRegex(
            adapter.AdapterError, "reference_package_uncertainty_error"
        ):
            mutated.require_likelihood_ready()
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "mutated"
            with self.assertRaisesRegex(
                adapter.AdapterError, "reference_package_uncertainty_error"
            ):
                adapter.write_canonical_package(mutated, output)
            self.assertFalse(output.exists())

        mutated_claim = replace(self.package, claim_ceiling="physically_valid")
        with self.assertRaisesRegex(
            adapter.AdapterError, "reference_package_metadata_error"
        ):
            adapter.validate_reference_package_integrity(mutated_claim)

    def test_no_response_lineage_leakage_but_formal_split_is_not_ready(self) -> None:
        receipt = adapter.validate_no_leakage(self.package)
        self.assertEqual(receipt["status"], "pass_no_cross_split_response_lineage")
        self.assertFalse(receipt["formal_minimum_met"])
        self.assertFalse(receipt["formal_split_ready"])
        self.assertEqual(receipt["validation_split"]["status"], "typed_absent")
        self.assertEqual(receipt["strict_any_artifact_policy"]["status"], "terminal_deferred")
        self.assertEqual(
            len(receipt["shared_non_response_artifacts"]["major_radius_coordinate_sha256"]),
            1,
        )

    def test_same_shot_or_response_artifact_cross_split_is_rejected(self) -> None:
        calibration_ne = self.package.observation(30421, "n_e")
        heldout_ne = self.package.observation(30420, "n_e")
        records = list(self.package.observations)
        records[records.index(calibration_ne)] = replace(calibration_ne, split="held_out")
        with self.assertRaisesRegex(adapter.AdapterError, "split_leakage"):
            adapter.validate_no_leakage_records(records, self.package.protocol)

        records = list(self.package.observations)
        records[records.index(heldout_ne)] = replace(
            heldout_ne, source_response_sha256=calibration_ne.source_response_sha256
        )
        with self.assertRaisesRegex(adapter.AdapterError, "split_leakage"):
            adapter.validate_no_leakage_records(records, self.package.protocol)

        records = list(self.package.observations)
        records[records.index(heldout_ne)] = replace(
            heldout_ne,
            sample_lineage_sha256=calibration_ne.sample_lineage_sha256,
        )
        with self.assertRaisesRegex(adapter.AdapterError, "split_leakage"):
            adapter.validate_no_leakage_records(records, self.package.protocol)

    def test_duplicate_same_split_identity_cannot_inflate_counts(self) -> None:
        records = list(self.package.observations)
        records.append(self.package.observation(30421, "n_e"))
        with self.assertRaisesRegex(
            adapter.AdapterError, "duplicate_observation_identity"
        ):
            adapter.validate_no_leakage_records(records, self.package.protocol)

    def test_stale_payload_is_rejected_at_operator_and_writer_boundaries(self) -> None:
        observation = self.package.observation(30421, "n_e")
        changed_values = observation.values.copy()
        t_index, r_index = np.argwhere(observation.observed_mask)[0]
        original = changed_values[int(t_index), int(r_index)]
        changed_values[int(t_index), int(r_index)] = np.nextafter(original, np.inf)
        changed_values.setflags(write=False)
        stale = replace(observation, values=changed_values)
        with self.assertRaisesRegex(
            adapter.AdapterError, "canonical_payload_hash_mismatch"
        ):
            adapter.apply_thomson_sample_operator(
                stale,
                stale.values,
                stale.canonical_unit,
                stale.major_radius_m,
                stale.time_s,
            )

        records = list(self.package.observations)
        records[records.index(observation)] = stale
        stale_package = replace(self.package, observations=tuple(records))
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "stale"
            with self.assertRaisesRegex(
                adapter.AdapterError, "canonical_payload_hash_mismatch"
            ):
                adapter.write_canonical_package(stale_package, output)
            self.assertFalse(output.exists())

    def test_same_schema_protocol_transform_tamper_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            temp = Path(temporary)
            protocol = json.loads((ADAPTER_DIR / "protocol.json").read_text("utf-8"))
            protocol["canonical_contract"]["scale"] = 1.0e-19
            (temp / "protocol.json").write_text(
                json.dumps(protocol), encoding="utf-8"
            )
            (temp / "source_evidence.json").write_bytes(
                (ADAPTER_DIR / "source_evidence.json").read_bytes()
            )
            with self.assertRaisesRegex(
                adapter.AdapterError, "unsupported_protocol_contract"
            ):
                adapter.load_reference_package(
                    adapter.DEFAULT_SOURCE_ROOT, temp / "protocol.json"
                )

    def test_iter_design_is_separate_from_measurement_records(self) -> None:
        self.assertEqual({item["reference_id"] for item in self.package.design_references}, {"iter_design_v1"})
        self.assertTrue(all(item.shot_id in {30420, 30421} for item in self.package.observations))
        self.assertTrue(all(item["measurement_status"] == "typed_absent" for item in self.package.design_references))

    def test_materialized_package_is_directly_readable_and_does_not_overwrite(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "canonical"
            report = adapter.write_canonical_package(self.package, output)
            self.assertEqual(report["program_state"], "pass_with_scope")
            self.assertEqual(report["resolution"], "terminal_deferred")
            manifest = json.loads((output / "canonical_manifest.json").read_text(encoding="utf-8"))
            self.assertEqual(len(manifest["observations"]), 4)
            self.assertEqual(manifest["formal_inverse"], "not_executed")
            self.assertEqual(manifest["b07b"], "not_claimed")
            sample_file = output / manifest["observations"][0]["canonical"]["files"]["samples"]["path"]
            self.assertTrue(sample_file.is_file())
            self.assertGreater(sample_file.stat().st_size, 0)
            artifacts = json.loads(
                (output / "artifact_manifest.json").read_text(encoding="utf-8")
            )
            for item in artifacts["files"]:
                path = Path(item["path"])
                self.assertFalse(path.is_absolute())
                data = (output / path).read_bytes()
                self.assertEqual(hashlib.sha256(data).hexdigest(), item["sha256"])
            with self.assertRaisesRegex(adapter.AdapterError, "output_exists"):
                adapter.write_canonical_package(self.package, output)


if __name__ == "__main__":
    unittest.main()
