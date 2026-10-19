from __future__ import annotations

import copy
import hashlib
import json
import shutil
import sys
import tempfile
import unittest
from dataclasses import replace
from pathlib import Path
from unittest.mock import patch

import numpy as np


ROOT = Path(__file__).resolve().parents[2]
ADAPTER_DIR = ROOT / "benchmarks" / "reference_validation_expansion_v1"
sys.path.insert(0, str(ADAPTER_DIR))

import manifest_adapter as adapter  # noqa: E402


def _rehash_observation(
    observation: adapter.ExpansionObservation,
    *,
    arrays=None,
    source_records=None,
) -> adapter.ExpansionObservation:
    arrays = dict(observation.arrays) if arrays is None else arrays
    source_records = (
        observation.source_records if source_records is None else source_records
    )
    payload = adapter._payload_hash(
        shot_id=observation.shot_id,
        source_directory=observation.source_directory,
        acquisition_sha256=observation.acquisition_sha256,
        zmetadata_sha256=observation.zmetadata_sha256,
        selection_key_sha256=observation.selection_key_sha256,
        catalog_uuid=observation.catalog_uuid,
        shape=observation.shape,
        arrays=arrays,
        source_records=source_records,
    )
    lineage = adapter.level1._sample_lineage_hash(
        payload, arrays, observation.observed_mask
    )
    return replace(
        observation,
        arrays=arrays,
        source_records=source_records,
        source_records_sha256=adapter._source_records_hash(source_records),
        canonical_payload_sha256=payload,
        sample_lineage_sha256=lineage,
    )


class ExpansionManifestAdapterTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.calibration = adapter.load_expansion_split("calibration")
        cls.validation = adapter.load_expansion_split("validation")

    def test_split_first_guard_blocks_unreleased_values_before_any_open(self) -> None:
        for split in ("held_out", "reserve"):
            with self.subTest(split=split), patch.object(
                Path, "open", side_effect=AssertionError("path was opened")
            ):
                with self.assertRaisesRegex(
                    adapter.core.AdapterError, "expansion_split_release_required"
                ):
                    adapter.load_expansion_split(
                        split,
                        source_root=Path("never-open-source"),
                        protocol_path=Path("never-open-protocol"),
                        selection_path=Path("never-open-selection"),
                        index_path=Path("never-open-index"),
                    )

    def test_real_calibration_and_validation_arrays_load_as_one_bundle_per_shot(self) -> None:
        expected = {
            "calibration": {
                30463: ((44, 131), 4812),
                30468: ((39, 131), 4191),
                30459: ((44, 131), 4758),
                30462: ((42, 131), 4599),
                30464: ((43, 131), 4619),
                30460: ((44, 131), 4711),
                30456: ((46, 131), 5066),
                30466: ((41, 131), 4459),
            },
            "validation": {30469: ((42, 131), 4552)},
        }
        for package in (self.calibration, self.validation):
            self.assertEqual(
                len(package.observations), len(expected[package.split])
            )
            for observation in package.observations:
                shape, count = expected[package.split][observation.shot_id]
                self.assertEqual(observation.shape, shape)
                self.assertEqual(observation.observed_count, count)
                self.assertEqual(set(observation.arrays), set(adapter.ACQUIRED_ARRAYS))
                self.assertFalse(observation.likelihood_ready)
            receipt = package.split_receipt
            self.assertEqual(receipt["combination_count"], len(package.observations))
            self.assertEqual(receipt["record_count"], len(package.observations))
            self.assertFalse(receipt["formal_split_ready"])

    def test_raw_to_canonical_cell_mapping_and_unknown_error_semantics(self) -> None:
        observation = self.validation.observation(30469)
        first = next(adapter.iter_expansion_cells(observation))
        self.assertEqual(first["raw_index"], first["canonical_index"])
        t_index, r_index = first["canonical_index"]
        self.assertEqual(
            first["ne"], float(observation.arrays["ne"][t_index, r_index])
        )
        self.assertEqual(first["error_semantics"], "unknown")
        self.assertFalse(first["likelihood_ready"])
        self.assertEqual(len(first["sample_sha256"]), 64)

    def test_index_has_no_response_or_error_overlap_but_shared_coordinates_defer_strict_policy(self) -> None:
        receipt = self.calibration.split_receipt["index_leakage_receipt"]
        for overlap in receipt["response_error_hash_intersections"].values():
            self.assertEqual(overlap, [])
        self.assertIn("radial_index", receipt["shared_non_response_artifacts"])
        self.assertEqual(
            receipt["strict_any_artifact_policy"]["status"], "terminal_deferred"
        )
        self.assertFalse(receipt["formal_split_ready"])

    def test_selection_regroup_and_self_rehashed_protocol_are_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            temporary = Path(temporary)
            selection = json.loads(adapter.DEFAULT_SELECTION.read_text(encoding="utf-8"))
            selection["groups"]["validation"]["shot_ids"] = [30463]
            selection["groups"]["validation"]["count"] = 1
            selection_path = temporary / "selection.json"
            selection_path.write_text(
                json.dumps(selection, sort_keys=True), encoding="utf-8"
            )
            with self.assertRaisesRegex(
                adapter.core.AdapterError, "expansion_selection_hash_mismatch"
            ):
                adapter.load_expansion_split(
                    "validation", selection_path=selection_path
                )
            protocol = json.loads(adapter.DEFAULT_PROTOCOL.read_text(encoding="utf-8"))
            protocol["selection"]["sha256"] = hashlib.sha256(
                selection_path.read_bytes()
            ).hexdigest()
            protocol_path = temporary / "protocol.json"
            protocol_path.write_text(
                json.dumps(protocol, sort_keys=True), encoding="utf-8"
            )
            with self.assertRaisesRegex(
                adapter.core.AdapterError, "expansion_protocol_hash_mismatch"
            ):
                adapter.load_expansion_split(
                    "validation",
                    protocol_path=protocol_path,
                    selection_path=selection_path,
                )

    def test_index_path_escape_is_rejected_before_source_open(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            index = json.loads(
                adapter.DEFAULT_ACQUISITION_INDEX.read_text(encoding="utf-8")
            )
            index["records"][0]["relative_directory"] = "../held_out/shot30471_r1"
            index_path = Path(temporary) / "index.json"
            index_path.write_text(json.dumps(index), encoding="utf-8")
            with patch.object(
                adapter, "_resolve_shot_directory", side_effect=AssertionError("source opened")
            ):
                with self.assertRaisesRegex(
                    adapter.core.AdapterError, "expansion_source_path_error"
                ):
                    adapter.load_expansion_split(
                        "validation", index_path=index_path
                    )

    def test_raw_and_compressed_drift_are_rejected(self) -> None:
        for filename, error in (
            ("ne.raw", "level1_raw_hash_mismatch"),
            ("ne.blosc", "level1_compressed_hash_mismatch"),
        ):
            with self.subTest(filename=filename), tempfile.TemporaryDirectory() as temporary:
                source = Path(temporary) / "source"
                shutil.copytree(
                    adapter.DEFAULT_SOURCE_ROOT / "validation",
                    source / "validation",
                )
                path = source / "validation" / "shot30469_r1" / filename
                data = bytearray(path.read_bytes())
                data[0] ^= 0x01
                path.write_bytes(data)
                with self.assertRaisesRegex(adapter.core.AdapterError, error):
                    adapter.load_expansion_split("validation", source_root=source)

    def test_rehashed_source_metadata_and_live_value_forgery_fail_closed(self) -> None:
        observation = self.validation.observation(30469)
        records = copy.deepcopy(observation.source_records)
        records["ne"]["metadata"]["dtype"] = ">f4"
        forged_metadata = _rehash_observation(
            observation, source_records=records
        )
        with self.assertRaisesRegex(
            adapter.core.AdapterError, "expansion_source_records_binding_error"
        ):
            adapter.validate_expansion_observation(forged_metadata)

        arrays = dict(observation.arrays)
        changed = arrays["ne_error"].copy()
        t_index, r_index = np.argwhere(observation.observed_mask)[0]
        changed[int(t_index), int(r_index)] = np.nextafter(
            changed[int(t_index), int(r_index)], np.float32(np.inf)
        )
        changed.setflags(write=False)
        arrays["ne_error"] = changed
        forged_value = _rehash_observation(observation, arrays=arrays)
        with self.assertRaisesRegex(
            adapter.core.AdapterError, "expansion_source_array_binding_error"
        ):
            adapter.validate_expansion_observation(forged_value)

    def test_endian_and_boolean_mask_contracts_fail_closed(self) -> None:
        observation = self.validation.observation(30469)
        arrays = dict(observation.arrays)
        big_endian = arrays["ne"].astype(">f4")
        big_endian.setflags(write=False)
        arrays["ne"] = big_endian
        invalid_endian = replace(observation, arrays=arrays)
        with self.assertRaisesRegex(
            adapter.core.AdapterError, "expansion_observation_array_contract_error"
        ):
            adapter.validate_expansion_observation(invalid_endian)

        uint8_mask = observation.observed_mask.astype(np.uint8)
        uint8_mask.setflags(write=False)
        invalid_mask = replace(observation, observed_mask=uint8_mask)
        with self.assertRaisesRegex(
            adapter.core.AdapterError, "expansion_observation_mask_contract_error"
        ):
            adapter.validate_expansion_observation(invalid_mask)

    def test_forged_readiness_claim_and_duplicate_combination_are_rejected(self) -> None:
        for changed in (
            replace(self.validation, likelihood_ready=True),
            replace(self.validation, claim_ceiling="formal_acceptance"),
        ):
            with self.subTest(change=changed), self.assertRaisesRegex(
                adapter.core.AdapterError, "expansion_package_metadata_error"
            ):
                changed.require_likelihood_ready()
        duplicated = replace(
            self.validation,
            observations=(self.validation.observations[0], self.validation.observations[0]),
        )
        with self.assertRaisesRegex(
            adapter.core.AdapterError, "expansion_split_coverage_error"
        ):
            adapter.validate_expansion_package(duplicated)

    def test_cross_split_response_hash_reuse_is_rejected(self) -> None:
        selection = json.loads(adapter.DEFAULT_SELECTION.read_text(encoding="utf-8"))
        index = json.loads(
            adapter.DEFAULT_ACQUISITION_INDEX.read_text(encoding="utf-8")
        )
        calibration_ne = next(
            item for item in index["records"][0]["arrays"] if item["name"] == "ne"
        )["raw_sha256"]
        validation_record = next(
            item for item in index["records"] if item["split"] == "validation"
        )
        next(
            item for item in validation_record["arrays"] if item["name"] == "ne"
        )["raw_sha256"] = calibration_ne
        with self.assertRaisesRegex(
            adapter.core.AdapterError, "expansion_split_leakage"
        ):
            adapter.validate_acquisition_index_no_leakage(index, selection)

    def test_cross_split_cross_name_response_hash_reuse_is_rejected(self) -> None:
        selection = json.loads(adapter.DEFAULT_SELECTION.read_text(encoding="utf-8"))
        index = json.loads(
            adapter.DEFAULT_ACQUISITION_INDEX.read_text(encoding="utf-8")
        )
        calibration_ne = next(
            item for item in index["records"][0]["arrays"] if item["name"] == "ne"
        )["raw_sha256"]
        validation_record = next(
            item for item in index["records"] if item["split"] == "validation"
        )
        next(
            item for item in validation_record["arrays"] if item["name"] == "te_error"
        )["raw_sha256"] = calibration_ne
        with self.assertRaisesRegex(
            adapter.core.AdapterError, "expansion_split_leakage"
        ):
            adapter.validate_acquisition_index_no_leakage(index, selection)

    def test_materialized_validation_package_has_verified_relative_artifacts(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "canonical"
            report = adapter.write_expansion_package(self.validation, output)
            self.assertEqual(report["program_state"], "pass_with_scope")
            self.assertEqual(report["combination_count"], 1)
            self.assertEqual(report["joint_observed_cells"], 4552)
            self.assertFalse(report["likelihood_ready"])
            self.assertFalse(report["formal_split_ready"])
            artifacts = json.loads(
                (output / "artifact_manifest.json").read_text(encoding="utf-8")
            )
            self.assertEqual(len(artifacts["files"]), 14)
            for item in artifacts["files"]:
                relative = Path(item["path"])
                self.assertFalse(relative.is_absolute())
                content = (output / relative).read_bytes()
                self.assertEqual(len(content), item["bytes"])
                self.assertEqual(hashlib.sha256(content).hexdigest(), item["sha256"])


if __name__ == "__main__":
    unittest.main()
