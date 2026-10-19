from __future__ import annotations

import copy
import ctypes
import hashlib
import json
import math
import os
import shutil
import struct
import sys
import tempfile
import unittest
from dataclasses import replace
from pathlib import Path
from typing import Any, Callable
from unittest.mock import patch

import numpy as np


ROOT = Path(__file__).resolve().parents[2]
ADAPTER_DIR = ROOT / "benchmarks" / "reference_validation_expansion_v1"
SOURCE_ROOT = ROOT / "benchmarks" / "reference_data_level1_expansion_v1"
PROTOCOL_PATH = ADAPTER_DIR / "protocol.json"
INDEX_PATH = ADAPTER_DIR / "acquisition_index.json"
SELECTION_PATH = SOURCE_ROOT / "selection.json"
sys.path.insert(0, str(ADAPTER_DIR))

import manifest_adapter as adapter  # noqa: E402


EXPECTED_COUNTS = {
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


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def canonical_json_bytes(value: Any) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        allow_nan=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


class IndependentBloscDecoder:
    """Decode stored chunks through C-Blosc without using adapter decode code."""

    def __init__(self) -> None:
        directory = Path(sys.executable).parent / "Library" / "bin"
        self._directory_handle = os.add_dll_directory(str(directory))
        self._library = ctypes.CDLL(str(directory / "blosc.dll"))
        self._library.blosc_cbuffer_validate.argtypes = [
            ctypes.c_void_p,
            ctypes.c_size_t,
            ctypes.POINTER(ctypes.c_size_t),
        ]
        self._library.blosc_cbuffer_validate.restype = ctypes.c_int
        self._library.blosc_decompress_ctx.argtypes = [
            ctypes.c_void_p,
            ctypes.c_void_p,
            ctypes.c_size_t,
            ctypes.c_int,
        ]
        self._library.blosc_decompress_ctx.restype = ctypes.c_int

    def decode(self, compressed: bytes, expected_size: int) -> bytes:
        source = ctypes.create_string_buffer(compressed)
        decoded_size = ctypes.c_size_t()
        status = self._library.blosc_cbuffer_validate(
            source, len(compressed), ctypes.byref(decoded_size)
        )
        if status != 0 or decoded_size.value != expected_size:
            raise AssertionError(
                f"invalid Blosc buffer: status={status}, size={decoded_size.value}"
            )
        destination = ctypes.create_string_buffer(expected_size)
        actual = self._library.blosc_decompress_ctx(
            source, destination, expected_size, 1
        )
        if actual != expected_size:
            raise AssertionError(
                f"Blosc decoded {actual} bytes, expected {expected_size}"
            )
        return destination.raw

    def close(self) -> None:
        self._directory_handle.close()


def independent_source_records_hash(records: Any) -> str:
    normalized = {name: records[name] for name in sorted(records)}
    return sha256_bytes(canonical_json_bytes(normalized))


def independent_payload_hash(observation: adapter.ExpansionObservation) -> str:
    helper_header = {
        "domain": "FusionConceptAI.reference_validation.level1_error_observation.v1",
        "shot_id": observation.shot_id,
        "split_independent_identity": True,
        "source_directory": observation.source_directory,
        "acquisition_sha256": observation.acquisition_sha256,
        "zmetadata_sha256": observation.zmetadata_sha256,
        "dimensions": ["time", "radial_index"],
        "shape": list(observation.shape),
        "dtype": "float32_little_endian",
        "mapping": "identity",
        "error_semantics": "unverified_not_assumed_standard_deviation",
        "source_records": {
            name: observation.source_records[name]
            for name in sorted(observation.source_records)
        },
    }
    helper_digest = hashlib.sha256()
    helper_digest.update(canonical_json_bytes(helper_header))
    for name in sorted(observation.arrays):
        helper_digest.update(name.encode("ascii") + b"\0")
        helper_digest.update(
            np.asarray(observation.arrays[name], dtype="<f4").tobytes(order="C")
        )
    identity = {
        "domain": "FusionConceptAI.reference_validation.level1_expansion_observation.v1",
        "selection_id": "mast-ayc-m9-expansion-r1",
        "selection_sha256": adapter.EXPECTED_SELECTION_SHA256,
        "acquisition_index_sha256": adapter.EXPECTED_INDEX_SHA256,
        "verified_helper_sha256": adapter.EXPECTED_HELPER_SHA256,
        "shot_id": observation.shot_id,
        "selection_key_sha256": observation.selection_key_sha256,
        "catalog_uuid": observation.catalog_uuid,
        "helper_payload_sha256": helper_digest.hexdigest(),
    }
    return sha256_bytes(canonical_json_bytes(identity))


def independent_lineage_hash(observation: adapter.ExpansionObservation) -> str:
    digest = hashlib.sha256()
    digest.update(b"FusionConceptAI.reference_validation.level1_cells.v1\0")
    digest.update(observation.canonical_payload_sha256.encode("ascii"))
    for t_raw, r_raw in np.argwhere(observation.observed_mask):
        t, r = int(t_raw), int(r_raw)
        digest.update(struct.pack("<II", t, r))
        for name in adapter.MEASUREMENT_ARRAYS:
            digest.update(struct.pack("<f", float(observation.arrays[name][t, r])))
    return digest.hexdigest()


def independently_rehash(
    observation: adapter.ExpansionObservation, **changes: Any
) -> adapter.ExpansionObservation:
    changed = replace(observation, **changes)
    changed = replace(
        changed,
        source_records_sha256=independent_source_records_hash(changed.source_records),
    )
    changed = replace(changed, canonical_payload_sha256=independent_payload_hash(changed))
    return replace(changed, sample_lineage_sha256=independent_lineage_hash(changed))


class IndependentExpansionManifestTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.index = json.loads(INDEX_PATH.read_text(encoding="utf-8"))
        cls.selection = json.loads(SELECTION_PATH.read_text(encoding="utf-8"))
        cls.calibration = adapter.load_expansion_split("calibration")
        cls.validation = adapter.load_expansion_split("validation")
        cls.decoder = IndependentBloscDecoder()

    @classmethod
    def tearDownClass(cls) -> None:
        cls.decoder.close()

    def assert_adapter_code(self, expected: str, action: Callable[[], Any]) -> None:
        with self.assertRaises(adapter.core.AdapterError) as caught:
            action()
        self.assertEqual(caught.exception.code, expected)

    def test_all_real_receipts_bytes_masks_and_identity_hashes(self) -> None:
        indexed = {int(record["shot_id"]): record for record in self.index["records"]}
        for package in (self.calibration, self.validation):
            expected = EXPECTED_COUNTS[package.split]
            self.assertEqual(tuple(x.shot_id for x in package.observations), tuple(expected))
            for observation in package.observations:
                with self.subTest(split=package.split, shot=observation.shot_id):
                    shape, observed_count = expected[observation.shot_id]
                    record = indexed[observation.shot_id]
                    shot_dir = SOURCE_ROOT / observation.source_directory
                    self.assertEqual(observation.shape, shape)
                    self.assertEqual(observation.observed_count, observed_count)
                    self.assertEqual(
                        sha256_file(shot_dir / "acquisition.json"),
                        record["acquisition_receipt_sha256"],
                    )
                    self.assertEqual(
                        sha256_file(shot_dir / "zmetadata.json"),
                        record["zmetadata_sha256"],
                    )

                    decoded: dict[str, np.ndarray] = {}
                    entries = {item["name"]: item for item in record["arrays"]}
                    self.assertEqual(tuple(entries), adapter.ACQUIRED_ARRAYS)
                    for name, entry in entries.items():
                        raw = (shot_dir / f"{name}.raw").read_bytes()
                        compressed = (shot_dir / f"{name}.blosc").read_bytes()
                        self.assertEqual(sha256_bytes(raw), entry["raw_sha256"])
                        self.assertEqual(
                            sha256_bytes(compressed), entry["compressed_sha256"]
                        )
                        entry_shape = tuple(entry["metadata"]["shape"])
                        self.assertEqual(entry["metadata"]["dtype"], "<f4")
                        self.assertEqual(entry["metadata"]["order"], "C")
                        self.assertEqual(entry["metadata"]["chunks"], list(entry_shape))
                        self.assertEqual(len(raw), math.prod(entry_shape) * 4)
                        self.assertEqual(self.decoder.decode(compressed, len(raw)), raw)
                        values = np.frombuffer(raw, dtype="<f4").reshape(entry_shape)
                        decoded[name] = values
                        finite = values[np.isfinite(values)]
                        self.assertEqual(finite.size, entry["finite_count"])
                        self.assertEqual(values.size, entry["total_count"])
                        self.assertEqual(
                            int(np.count_nonzero(finite < 0.0)),
                            entry["negative_finite_count"],
                        )
                        if finite.size:
                            self.assertEqual(float(finite.min()), entry["minimum"])
                            self.assertEqual(float(finite.max()), entry["maximum"])
                        np.testing.assert_array_equal(observation.arrays[name], values)

                    expected_mask = np.logical_and.reduce(
                        [np.isfinite(decoded[name]) for name in adapter.MEASUREMENT_ARRAYS]
                    )
                    self.assertEqual(observation.observed_mask.dtype, np.dtype(np.bool_))
                    self.assertFalse(observation.observed_mask.flags.writeable)
                    np.testing.assert_array_equal(observation.observed_mask, expected_mask)
                    self.assertTrue(np.all(np.diff(decoded["time"]) > 0.0))
                    np.testing.assert_array_equal(
                        decoded["radial_index"], np.arange(shape[1], dtype="<f4")
                    )
                    self.assertEqual(
                        independent_source_records_hash(observation.source_records),
                        observation.source_records_sha256,
                    )
                    self.assertEqual(
                        independent_payload_hash(observation),
                        observation.canonical_payload_sha256,
                    )
                    self.assertEqual(
                        independent_lineage_hash(observation),
                        observation.sample_lineage_sha256,
                    )

        self.assertEqual(sum(x.observed_count for x in self.calibration.observations), 37215)
        self.assertEqual(sum(x.observed_count for x in self.validation.observations), 4552)

    def test_frozen_split_membership_and_global_hash_separation(self) -> None:
        groups = self.selection["groups"]
        seen: set[int] = set()
        for split, ids in {**adapter.LOADABLE_SPLITS, **adapter.BLOCKED_SPLITS}.items():
            self.assertEqual(groups[split]["shot_ids"], list(ids))
            self.assertTrue(seen.isdisjoint(ids))
            seen.update(ids)
        self.assertEqual(len(seen), 16)
        self.assertEqual(
            {record["split"] for record in self.index["records"]},
            set(adapter.LOADABLE_SPLITS),
        )
        for split in adapter.BLOCKED_SPLITS:
            self.assertFalse((SOURCE_ROOT / split).exists())

        by_split: dict[str, set[str]] = {name: set() for name in adapter.LOADABLE_SPLITS}
        for record in self.index["records"]:
            for entry in record["arrays"]:
                if entry["name"] in adapter.RESPONSE_AND_ERROR_ARRAYS:
                    by_split[record["split"]].add(entry["raw_sha256"])
        self.assertTrue(by_split["calibration"].isdisjoint(by_split["validation"]))
        receipt = self.validation.split_receipt["index_leakage_receipt"]
        self.assertEqual(receipt["global_response_error_hash_intersection"], [])
        self.assertEqual(receipt["strict_any_artifact_policy"]["status"], "terminal_deferred")
        self.assertIn("radial_index", receipt["shared_non_response_artifacts"])
        self.assertFalse(receipt["formal_split_ready"])

    def test_release_guard_precedes_every_control_or_source_open(self) -> None:
        for split in adapter.BLOCKED_SPLITS:
            with self.subTest(split=split), patch.object(
                Path, "open", side_effect=AssertionError("guard opened a path")
            ):
                self.assert_adapter_code(
                    "expansion_split_release_required",
                    lambda split=split: adapter.load_expansion_split(
                        split,
                        source_root=Path("unreachable-source"),
                        protocol_path=Path("unreachable-protocol"),
                        selection_path=Path("unreachable-selection"),
                        index_path=Path("unreachable-index"),
                    ),
                )

    def test_frozen_control_regroup_rehash_and_path_escape_attacks_reject(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_raw:
            temporary = Path(temporary_raw)
            selection = copy.deepcopy(self.selection)
            selection["groups"]["calibration"]["shot_ids"][0] = 30469
            selection_path = temporary / "selection.json"
            selection_path.write_text(json.dumps(selection), encoding="utf-8")
            self.assert_adapter_code(
                "expansion_selection_hash_mismatch",
                lambda: adapter.load_expansion_split(
                    "validation", selection_path=selection_path
                ),
            )
            protocol = json.loads(PROTOCOL_PATH.read_text(encoding="utf-8"))
            protocol["selection"]["sha256"] = sha256_file(selection_path)
            protocol_path = temporary / "protocol.json"
            protocol_path.write_text(json.dumps(protocol), encoding="utf-8")
            self.assert_adapter_code(
                "expansion_protocol_hash_mismatch",
                lambda: adapter.load_expansion_split(
                    "validation",
                    protocol_path=protocol_path,
                    selection_path=selection_path,
                ),
            )

            for relative in (
                "../held_out/shot30471_r1",
                "validation\\shot30469_r1",
                "C:/validation/shot30469_r1",
            ):
                with self.subTest(relative=relative):
                    index = copy.deepcopy(self.index)
                    index["records"][0]["relative_directory"] = relative
                    index_path = temporary / f"index_{len(relative)}.json"
                    index_path.write_text(json.dumps(index), encoding="utf-8")
                    with patch.object(
                        adapter,
                        "_resolve_shot_directory",
                        side_effect=AssertionError("source was resolved"),
                    ):
                        self.assert_adapter_code(
                            "expansion_source_path_error",
                            lambda index_path=index_path: adapter.load_expansion_split(
                                "validation", index_path=index_path
                            ),
                        )

    def test_source_receipt_metadata_raw_and_compressed_tamper_reject(self) -> None:
        attacks = (
            ("acquisition.json", "expansion_acquisition_hash_mismatch"),
            ("zmetadata.json", "expansion_zmetadata_hash_mismatch"),
            ("ne_error.raw", "level1_raw_hash_mismatch"),
            ("covariance_ne_te.blosc", "level1_compressed_hash_mismatch"),
        )
        for filename, expected_code in attacks:
            with self.subTest(filename=filename), tempfile.TemporaryDirectory() as temporary:
                source = Path(temporary) / "source"
                shutil.copytree(SOURCE_ROOT / "validation", source / "validation")
                target = source / "validation" / "shot30469_r1" / filename
                content = bytearray(target.read_bytes())
                content[len(content) // 2] ^= 0x01
                target.write_bytes(content)
                self.assert_adapter_code(
                    expected_code,
                    lambda source=source: adapter.load_expansion_split(
                        "validation", source_root=source
                    ),
                )

    def test_index_storage_units_shapes_and_cross_name_leakage_reject(self) -> None:
        mutations: tuple[tuple[str, Callable[[dict[str, Any]], None], str], ...] = (
            (
                "endian",
                lambda index: index["records"][0]["arrays"][0]["metadata"].__setitem__(
                    "dtype", ">f4"
                ),
                "expansion_array_contract_error",
            ),
            (
                "unit",
                lambda index: index["records"][0]["arrays"][2]["attributes"].__setitem__(
                    "units", "m^-3"
                ),
                "expansion_array_contract_error",
            ),
            (
                "shape",
                lambda index: index["records"][0]["arrays"][0]["metadata"].__setitem__(
                    "shape", [131, 44]
                ),
                "expansion_array_shape_error",
            ),
        )
        for name, mutate, expected_code in mutations:
            with self.subTest(mutation=name):
                index = copy.deepcopy(self.index)
                mutate(index)
                self.assert_adapter_code(
                    expected_code,
                    lambda index=index: adapter.validate_acquisition_index_no_leakage(
                        index, self.selection
                    ),
                )

        calibration_hash = next(
            entry["raw_sha256"]
            for entry in self.index["records"][0]["arrays"]
            if entry["name"] == "ne"
        )
        for target_name in ("ne", "te_error"):
            with self.subTest(hash_reuse=target_name):
                index = copy.deepcopy(self.index)
                validation = next(
                    record for record in index["records"] if record["split"] == "validation"
                )
                next(
                    entry for entry in validation["arrays"] if entry["name"] == target_name
                )["raw_sha256"] = calibration_hash
                self.assert_adapter_code(
                    "expansion_split_leakage",
                    lambda index=index: adapter.validate_acquisition_index_no_leakage(
                        index, self.selection
                    ),
                )

    def test_live_array_mask_and_rehashed_forgery_reject(self) -> None:
        observation = self.validation.observation(30469)
        arrays = dict(observation.arrays)
        big_endian = arrays["te"].astype(">f4")
        big_endian.setflags(write=False)
        arrays["te"] = big_endian
        self.assert_adapter_code(
            "expansion_observation_array_contract_error",
            lambda: adapter.validate_expansion_observation(
                replace(observation, arrays=arrays)
            ),
        )

        writable_arrays = dict(observation.arrays)
        writable_arrays["radius"] = writable_arrays["radius"].copy()
        self.assert_adapter_code(
            "expansion_observation_array_contract_error",
            lambda: adapter.validate_expansion_observation(
                replace(observation, arrays=writable_arrays)
            ),
        )

        drifted_mask = observation.observed_mask.copy()
        drifted_mask.flat[0] = not drifted_mask.flat[0]
        drifted_mask.setflags(write=False)
        self.assert_adapter_code(
            "expansion_observation_alignment_error",
            lambda: adapter.validate_expansion_observation(
                replace(observation, observed_mask=drifted_mask)
            ),
        )

        changed_arrays = dict(observation.arrays)
        changed_error = changed_arrays["ne_error"].copy()
        t_raw, r_raw = np.argwhere(observation.observed_mask)[0]
        t, r = int(t_raw), int(r_raw)
        changed_error[t, r] = np.nextafter(changed_error[t, r], np.float32(np.inf))
        changed_error.setflags(write=False)
        changed_arrays["ne_error"] = changed_error
        forged_values = independently_rehash(observation, arrays=changed_arrays)
        self.assert_adapter_code(
            "expansion_source_array_binding_error",
            lambda: adapter.validate_expansion_observation(forged_values),
        )

        records = copy.deepcopy(observation.source_records)
        records["te_error"]["metadata"]["order"] = "F"
        forged_records = independently_rehash(observation, source_records=records)
        self.assert_adapter_code(
            "expansion_source_records_binding_error",
            lambda: adapter.validate_expansion_observation(forged_records),
        )

    def test_cells_and_package_claims_remain_non_likelihood_and_deferred(self) -> None:
        observation = self.validation.observation(30469)
        cells = list(adapter.iter_expansion_cells(observation))
        self.assertEqual(len(cells), 4552)
        for cell in (cells[0], cells[len(cells) // 2], cells[-1]):
            t, r = cell["canonical_index"]
            self.assertEqual(cell["raw_index"], cell["canonical_index"])
            self.assertEqual(cell["ne"], float(observation.arrays["ne"][t, r]))
            self.assertEqual(cell["radius_m"], float(observation.arrays["radius"][t, r]))
            self.assertEqual(cell["error_semantics"], "unknown")
            self.assertFalse(cell["likelihood_ready"])
            self.assertEqual(len(cell["sample_sha256"]), 64)
        self.assert_adapter_code(
            "expansion_error_semantics_unknown", observation.require_likelihood_ready
        )
        self.assert_adapter_code(
            "expansion_error_semantics_unknown", self.validation.require_likelihood_ready
        )

        for forged in (
            replace(self.validation, likelihood_ready=True),
            replace(self.validation, error_semantics="provider_bound_sigma"),
            replace(self.validation, claim_ceiling="formal inverse ready"),
        ):
            with self.subTest(forged=forged):
                self.assert_adapter_code(
                    "expansion_package_metadata_error",
                    lambda forged=forged: adapter.validate_expansion_package(forged),
                )

        stale = copy.deepcopy(self.validation.split_receipt)
        stale["formal_split_ready"] = True
        self.assert_adapter_code(
            "expansion_split_receipt_stale",
            lambda: adapter.validate_expansion_package(
                replace(self.validation, split_receipt=stale)
            ),
        )
        duplicated = replace(
            self.validation,
            observations=(observation, observation),
        )
        self.assert_adapter_code(
            "expansion_split_coverage_error",
            lambda: adapter.validate_expansion_package(duplicated),
        )

    def test_writer_revalidates_and_materializes_hashed_validation_artifacts(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "canonical"
            report = adapter.write_expansion_package(self.validation, output)
            self.assertEqual(report["program_state"], "pass_with_scope")
            self.assertEqual(report["records"], 1)
            self.assertEqual(report["joint_observed_cells"], 4552)
            self.assertEqual(report["physical_state"], "unknown")
            self.assertEqual(report["resolution"], "terminal_deferred")
            self.assertFalse(report["likelihood_ready"])
            self.assertFalse(report["formal_split_ready"])
            manifest = json.loads(
                (output / "artifact_manifest.json").read_text(encoding="utf-8")
            )
            self.assertEqual(len(manifest["files"]), 14)
            for item in manifest["files"]:
                relative = Path(item["path"])
                self.assertFalse(relative.is_absolute())
                content = (output / relative).read_bytes()
                self.assertEqual(len(content), item["bytes"])
                self.assertEqual(sha256_bytes(content), item["sha256"])
            self.assert_adapter_code(
                "output_exists",
                lambda: adapter.write_expansion_package(self.validation, output),
            )


if __name__ == "__main__":
    unittest.main()
