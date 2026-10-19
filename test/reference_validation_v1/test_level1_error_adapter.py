from __future__ import annotations

import hashlib
import copy
import json
import shutil
import sys
import tempfile
import unittest
from dataclasses import replace
from pathlib import Path

import numpy as np


ROOT = Path(__file__).resolve().parents[2]
ADAPTER_DIR = ROOT / "benchmarks" / "reference_validation_v1"
sys.path.insert(0, str(ADAPTER_DIR))

import level1_error_adapter as adapter  # noqa: E402


class Level1ErrorAdapterTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.package = adapter.load_level1_error_package()

    def test_real_level1_error_data_is_loaded_on_its_own_grid(self) -> None:
        expected = {30421: ((284, 131), 15863), 30420: ((73, 131), 8264)}
        self.assertEqual(len(self.package.observations), 2)
        for shot_id, (shape, count) in expected.items():
            observation = self.package.observation(shot_id)
            self.assertEqual(observation.dimensions, ("time", "radial_index"))
            self.assertEqual(observation.shape, shape)
            self.assertEqual(observation.observed_count, count)
            self.assertEqual(observation.ne_error.shape, shape)
            self.assertEqual(observation.te_error.shape, shape)
            self.assertEqual(observation.covariance_ne_te.shape, shape)
            self.assertEqual(
                observation.source_records["ne_error"]["attributes"]["units"], ""
            )
            self.assertEqual(
                observation.source_records["te_error"]["attributes"]["units"], ""
            )
            self.assertEqual(
                observation.source_records["covariance_ne_te"]["attributes"][
                    "units"
                ],
                "eV / m ** 3",
            )

    def test_error_values_remain_unknown_semantics_and_reject_likelihood(self) -> None:
        for observation in self.package.observations:
            self.assertEqual(
                observation.error_semantics,
                "unverified_not_assumed_standard_deviation",
            )
            self.assertFalse(observation.likelihood_ready)
            with self.assertRaisesRegex(
                adapter.core.AdapterError, "level1_error_semantics_unknown"
            ):
                observation.require_likelihood_ready()
        with self.assertRaisesRegex(
            adapter.core.AdapterError, "level1_error_semantics_unknown"
        ):
            self.package.require_likelihood_ready()

    def test_conditional_cauchy_check_is_numeric_but_grants_no_semantics(self) -> None:
        expected = {30421: (15863, 191), 30420: (8264, 147)}
        for shot_id, (eligible, violations) in expected.items():
            diagnostic = adapter.conditional_error_consistency(
                self.package.observation(shot_id)
            )
            self.assertEqual(
                diagnostic["status"], "conditional_assumption_check_only"
            )
            self.assertFalse(diagnostic["assumption_supported_by_provider_evidence"])
            self.assertEqual(diagnostic["eligible_cell_count"], eligible)
            self.assertEqual(diagnostic["abs_rho_star_gt_one_count"], violations)
            self.assertEqual(
                diagnostic["conditional_2x2_psd_failure_count"], violations
            )
            self.assertEqual(diagnostic["error_semantics"], "unknown")
            self.assertFalse(diagnostic["likelihood_ready"])

    def test_each_cell_preserves_identity_raw_to_canonical_mapping(self) -> None:
        observation = self.package.observation(30420)
        cells = list(adapter.iter_level1_cells(observation))
        self.assertEqual(len(cells), observation.observed_count)
        first = cells[0]
        self.assertEqual(first["raw_index"], first["canonical_index"])
        t_index, r_index = first["canonical_index"]
        self.assertEqual(first["ne"], float(observation.ne[t_index, r_index]))
        self.assertEqual(first["error_semantics"], "unknown")
        self.assertFalse(first["likelihood_ready"])
        self.assertEqual(len(first["sample_sha256"]), 64)

    def test_level1_product_is_explicitly_not_index_joined_to_level2(self) -> None:
        binding = self.package.protocol["level2_binding"]
        self.assertEqual(binding["status"], "prohibited_unbound_products")
        self.assertEqual(self.package.observation(30421).shape, (284, 131))
        self.assertNotEqual(self.package.observation(30421).shape, (121, 135))
        self.assertEqual(self.package.observation(30420).shape, (73, 131))
        self.assertNotEqual(self.package.observation(30420).shape, (121, 77))

    def test_raw_byte_tamper_is_rejected_against_acquisition_receipt(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            copied_source = Path(temporary) / "source"
            shutil.copytree(adapter.DEFAULT_SOURCE_ROOT, copied_source)
            raw_path = copied_source / "shot30421_r1" / "ne_error.raw"
            content = bytearray(raw_path.read_bytes())
            content[0] ^= 0x01
            raw_path.write_bytes(content)
            with self.assertRaisesRegex(
                adapter.core.AdapterError, "level1_raw_hash_mismatch"
            ):
                adapter.load_level1_error_package(copied_source)

    def test_protocol_cannot_relabel_error_data_as_likelihood_ready(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            protocol_path = Path(temporary) / "level1_protocol.json"
            protocol = json.loads(adapter.DEFAULT_PROTOCOL.read_text(encoding="utf-8"))
            protocol["error_semantics"]["likelihood_ready"] = True
            protocol_path.write_text(json.dumps(protocol), encoding="utf-8")
            with self.assertRaisesRegex(
                adapter.core.AdapterError, "unsupported_level1_protocol"
            ):
                adapter.load_level1_error_package(
                    adapter.DEFAULT_SOURCE_ROOT, protocol_path
                )

    def test_level1_package_claim_mutation_is_rejected(self) -> None:
        mutated = replace(self.package, claim_ceiling="likelihood_ready")
        with self.assertRaisesRegex(
            adapter.core.AdapterError, "level1_package_metadata_error"
        ):
            mutated.require_likelihood_ready()
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "mutated"
            with self.assertRaisesRegex(
                adapter.core.AdapterError, "level1_package_metadata_error"
            ):
                adapter.write_level1_error_package(mutated, output)
            self.assertFalse(output.exists())

    def test_stale_level1_array_content_is_rejected_before_materialization(self) -> None:
        observation = self.package.observation(30421)
        changed = observation.ne_error.copy()
        t_index, r_index = np.argwhere(observation.observed_mask)[0]
        changed[int(t_index), int(r_index)] = np.nextafter(
            changed[int(t_index), int(r_index)], np.float32(np.inf)
        )
        changed.setflags(write=False)
        stale = replace(observation, ne_error=changed)
        with self.assertRaisesRegex(
            adapter.core.AdapterError, "level1_source_array_binding_error"
        ):
            adapter.validate_level1_observation(stale)
        observations = list(self.package.observations)
        observations[observations.index(observation)] = stale
        stale_package = replace(self.package, observations=tuple(observations))
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "stale"
            with self.assertRaisesRegex(
                adapter.core.AdapterError, "level1_source_array_binding_error"
            ):
                adapter.write_level1_error_package(stale_package, output)
            self.assertFalse(output.exists())

    def test_stale_level1_payload_identity_is_rejected(self) -> None:
        observation = self.package.observation(30421)
        stale = replace(observation, canonical_payload_sha256="0" * 64)
        with self.assertRaisesRegex(
            adapter.core.AdapterError, "level1_payload_hash_mismatch"
        ):
            adapter.validate_level1_observation(stale)

    def test_uint8_mask_cannot_pass_as_canonical_boolean_mask(self) -> None:
        observation = self.package.observation(30420)
        uint8_mask = observation.observed_mask.astype(np.uint8)
        uint8_mask.setflags(write=False)
        invalid = replace(observation, observed_mask=uint8_mask)
        with self.assertRaisesRegex(
            adapter.core.AdapterError, "level1_observation_mask_contract_error"
        ):
            adapter.conditional_error_consistency(invalid)
        observations = list(self.package.observations)
        observations[observations.index(observation)] = invalid
        invalid_package = replace(self.package, observations=tuple(observations))
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "invalid-mask"
            with self.assertRaisesRegex(
                adapter.core.AdapterError, "level1_observation_mask_contract_error"
            ):
                adapter.write_level1_error_package(invalid_package, output)
            self.assertFalse(output.exists())

    def test_rehashed_forged_source_metadata_is_rejected_at_all_consumer_seams(self) -> None:
        observation = self.package.observation(30421)
        forged_records = copy.deepcopy(observation.source_records)
        forged_records["ne"]["metadata"]["dtype"] = ">f4"
        forged_payload = adapter._payload_hash(
            shot_id=observation.shot_id,
            split=observation.split,
            shape=observation.shape,
            source_directory=observation.source_directory,
            acquisition_sha256=observation.acquisition_sha256,
            zmetadata_sha256=observation.zmetadata_sha256,
            arrays=observation.arrays,
            source_records=forged_records,
        )
        forged_lineage = adapter._sample_lineage_hash(
            forged_payload, observation.arrays, observation.observed_mask
        )
        forged = replace(
            observation,
            source_records=forged_records,
            canonical_payload_sha256=forged_payload,
            sample_lineage_sha256=forged_lineage,
        )
        for consumer in (
            adapter.validate_level1_observation,
            adapter.conditional_error_consistency,
        ):
            with self.assertRaisesRegex(
                adapter.core.AdapterError, "level1_source_records_binding_error"
            ):
                consumer(forged)
        observations = list(self.package.observations)
        observations[observations.index(observation)] = forged
        forged_package = replace(self.package, observations=tuple(observations))
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "forged-source-records"
            with self.assertRaisesRegex(
                adapter.core.AdapterError, "level1_source_records_binding_error"
            ):
                adapter.write_level1_error_package(forged_package, output)
            self.assertFalse(output.exists())

    def test_rehashed_forged_array_bytes_are_rejected_against_raw_acquisition(self) -> None:
        observation = self.package.observation(30420)
        changed = observation.ne_error.copy()
        t_index, r_index = np.argwhere(observation.observed_mask)[0]
        changed[int(t_index), int(r_index)] = np.nextafter(
            changed[int(t_index), int(r_index)], np.float32(np.inf)
        )
        changed.setflags(write=False)
        forged_arrays = dict(observation.arrays)
        forged_arrays["ne_error"] = changed
        forged_payload = adapter._payload_hash(
            shot_id=observation.shot_id,
            split=observation.split,
            shape=observation.shape,
            source_directory=observation.source_directory,
            acquisition_sha256=observation.acquisition_sha256,
            zmetadata_sha256=observation.zmetadata_sha256,
            arrays=forged_arrays,
            source_records=observation.source_records,
        )
        forged_lineage = adapter._sample_lineage_hash(
            forged_payload, forged_arrays, observation.observed_mask
        )
        forged = replace(
            observation,
            ne_error=changed,
            canonical_payload_sha256=forged_payload,
            sample_lineage_sha256=forged_lineage,
        )
        with self.assertRaisesRegex(
            adapter.core.AdapterError, "level1_source_array_binding_error"
        ):
            adapter.validate_level1_observation(forged)
        observations = list(self.package.observations)
        observations[observations.index(observation)] = forged
        forged_package = replace(self.package, observations=tuple(observations))
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "forged-array"
            with self.assertRaisesRegex(
                adapter.core.AdapterError, "level1_source_array_binding_error"
            ):
                adapter.write_level1_error_package(forged_package, output)
            self.assertFalse(output.exists())

    def test_materialized_level1_package_has_relative_verified_artifacts(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "canonical"
            report = adapter.write_level1_error_package(self.package, output)
            self.assertEqual(report["program_state"], "pass_with_scope")
            self.assertEqual(
                report["error_data_status"],
                "present_values_unknown_statistical_semantics",
            )
            self.assertFalse(report["likelihood_ready"])
            manifest = json.loads(
                (output / "canonical_manifest.json").read_text(encoding="utf-8")
            )
            self.assertEqual(len(manifest["observations"]), 2)
            artifacts = json.loads(
                (output / "artifact_manifest.json").read_text(encoding="utf-8")
            )
            for item in artifacts["files"]:
                path = Path(item["path"])
                self.assertFalse(path.is_absolute())
                data = (output / path).read_bytes()
                self.assertEqual(hashlib.sha256(data).hexdigest(), item["sha256"])


if __name__ == "__main__":
    unittest.main()
