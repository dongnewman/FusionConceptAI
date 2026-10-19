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
from contextlib import contextmanager
from dataclasses import replace
from pathlib import Path
from typing import Any, Callable, Iterator

import numpy as np


ROOT = Path(__file__).resolve().parents[2]
ADAPTER_DIR = ROOT / "benchmarks" / "reference_validation_v1"
SOURCE_ROOT = ROOT / "benchmarks" / "reference_data_level1_v1"
PROTOCOL_PATH = ADAPTER_DIR / "level1_protocol.json"
sys.path.insert(0, str(ADAPTER_DIR))

import level1_error_adapter as adapter  # noqa: E402


PRIMARY_ARRAYS = (
    "ne",
    "te",
    "ne_error",
    "te_error",
    "covariance_ne_te",
    "radius",
)
ALL_ARRAYS = PRIMARY_ARRAYS + (
    "time",
    "radial_index",
    "instrument_dr",
    "instrument_time",
)


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
    """Minimal C-Blosc decoder used only to compare stored compressed/raw bytes."""

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


def observation_arrays(observation: adapter.Level1ErrorObservation) -> dict[str, np.ndarray]:
    return {
        "ne": observation.ne,
        "te": observation.te,
        "ne_error": observation.ne_error,
        "te_error": observation.te_error,
        "covariance_ne_te": observation.covariance_ne_te,
        "radius": observation.radius_m,
        "time": observation.time_s,
        "radial_index": observation.radial_index,
    }


def independent_payload_hash(observation: adapter.Level1ErrorObservation) -> str:
    arrays = observation_arrays(observation)
    header = {
        "domain": "FusionConceptAI.reference_validation.level1_error_observation.v1",
        "shot_id": observation.shot_id,
        "split_independent_identity": True,
        "source_directory": observation.source_directory,
        "acquisition_sha256": observation.acquisition_sha256,
        "zmetadata_sha256": observation.zmetadata_sha256,
        "dimensions": list(observation.dimensions),
        "shape": list(observation.shape),
        "dtype": "float32_little_endian",
        "mapping": "identity",
        "error_semantics": "unverified_not_assumed_standard_deviation",
        "source_records": {
            name: observation.source_records[name]
            for name in sorted(observation.source_records)
        },
    }
    digest = hashlib.sha256()
    digest.update(canonical_json_bytes(header))
    for name in sorted(arrays):
        digest.update(name.encode("ascii") + b"\0")
        digest.update(np.asarray(arrays[name], dtype="<f4").tobytes(order="C"))
    return digest.hexdigest()


def independent_lineage_hash(observation: adapter.Level1ErrorObservation) -> str:
    digest = hashlib.sha256()
    digest.update(b"FusionConceptAI.reference_validation.level1_cells.v1\0")
    digest.update(observation.canonical_payload_sha256.encode("ascii"))
    arrays = observation_arrays(observation)
    for t_index, r_index in np.argwhere(observation.observed_mask):
        t, r = int(t_index), int(r_index)
        digest.update(struct.pack("<II", t, r))
        for name in PRIMARY_ARRAYS:
            digest.update(struct.pack("<f", float(arrays[name][t, r])))
    return digest.hexdigest()


def independently_rehash(
    observation: adapter.Level1ErrorObservation, **changes: Any
) -> adapter.Level1ErrorObservation:
    changed = replace(observation, **changes)
    changed = replace(
        changed, canonical_payload_sha256=independent_payload_hash(changed)
    )
    return replace(changed, sample_lineage_sha256=independent_lineage_hash(changed))


@contextmanager
def copied_source() -> Iterator[Path]:
    with tempfile.TemporaryDirectory() as temporary:
        destination = Path(temporary) / "reference_data_level1_v1"
        shutil.copytree(SOURCE_ROOT, destination)
        yield destination


class IndependentLevel1ErrorAdapterTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.protocol = json.loads(PROTOCOL_PATH.read_text(encoding="utf-8"))
        cls.package = adapter.load_level1_error_package(SOURCE_ROOT, PROTOCOL_PATH)
        cls.decoder = IndependentBloscDecoder()

    @classmethod
    def tearDownClass(cls) -> None:
        cls.decoder.close()

    def assert_adapter_code(self, expected: str, action: Callable[[], Any]) -> None:
        with self.assertRaises(adapter.core.AdapterError) as caught:
            action()
        self.assertEqual(caught.exception.code, expected)

    def test_receipts_raw_compressed_endian_mask_and_hash_chain(self) -> None:
        contracts = {item["shot_id"]: item for item in self.protocol["shots"]}
        expected_joint = {30421: 15863, 30420: 8264}
        for observation in self.package.observations:
            with self.subTest(shot=observation.shot_id):
                contract = contracts[observation.shot_id]
                shot_dir = SOURCE_ROOT / contract["directory"]
                acquisition_path = shot_dir / "acquisition.json"
                metadata_path = shot_dir / "zmetadata.json"
                self.assertEqual(sha256_file(acquisition_path), contract["acquisition_sha256"])
                self.assertEqual(sha256_file(metadata_path), contract["zmetadata_sha256"])
                acquisition = json.loads(acquisition_path.read_text(encoding="utf-8"))
                self.assertEqual(acquisition["metadata_sha256"], contract["zmetadata_sha256"])
                self.assertEqual(acquisition["error_semantics"], "unverified_not_assumed_standard_deviation")
                self.assertFalse(acquisition["likelihood_ready"])
                entries = {item["name"]: item for item in acquisition["arrays"]}
                self.assertEqual(set(entries), set(ALL_ARRAYS))
                decoded: dict[str, np.ndarray] = {}
                for name, entry in entries.items():
                    raw = (shot_dir / f"{name}.raw").read_bytes()
                    compressed = (shot_dir / f"{name}.blosc").read_bytes()
                    self.assertEqual(sha256_bytes(raw), entry["raw_sha256"])
                    self.assertEqual(sha256_bytes(compressed), entry["compressed_sha256"])
                    shape = tuple(entry["metadata"]["shape"])
                    self.assertEqual(entry["metadata"]["dtype"], "<f4")
                    self.assertEqual(entry["metadata"]["order"], "C")
                    self.assertEqual(entry["metadata"]["chunks"], list(shape))
                    self.assertEqual(len(raw), math.prod(shape) * 4)
                    self.assertEqual(self.decoder.decode(compressed, len(raw)), raw)
                    values = np.frombuffer(raw, dtype="<f4").reshape(shape)
                    decoded[name] = values
                    finite = values[np.isfinite(values)]
                    self.assertEqual(finite.size, entry["finite_count"])
                    self.assertEqual(values.size, entry["total_count"])
                    self.assertEqual(np.count_nonzero(finite < 0.0), entry["negative_finite_count"])
                    if finite.size:
                        self.assertEqual(float(finite.min()), entry["minimum"])
                        self.assertEqual(float(finite.max()), entry["maximum"])

                for name, values in observation_arrays(observation).items():
                    np.testing.assert_array_equal(values, decoded[name])
                independent_mask = np.logical_and.reduce(
                    [np.isfinite(decoded[name]) for name in PRIMARY_ARRAYS]
                )
                self.assertEqual(observation.observed_mask.dtype, np.dtype(np.bool_))
                self.assertFalse(observation.observed_mask.flags.writeable)
                np.testing.assert_array_equal(observation.observed_mask, independent_mask)
                self.assertEqual(int(independent_mask.sum()), expected_joint[observation.shot_id])
                self.assertEqual(
                    independent_payload_hash(observation),
                    observation.canonical_payload_sha256,
                )
                self.assertEqual(
                    independent_lineage_hash(observation),
                    observation.sample_lineage_sha256,
                )

    def test_conditional_covariance_check_stays_out_of_scope(self) -> None:
        expected = {30421: (15863, 191), 30420: (8264, 147)}
        for shot_id, (eligible, violations) in expected.items():
            observation = self.package.observation(shot_id)
            mask = observation.observed_mask
            rho = observation.covariance_ne_te[mask].astype(np.float64) / (
                observation.ne_error[mask].astype(np.float64)
                * observation.te_error[mask].astype(np.float64)
            )
            independent_violations = int(np.count_nonzero(np.abs(rho) > 1.0))
            self.assertEqual(rho.size, eligible)
            self.assertEqual(independent_violations, violations)
            diagnostic = adapter.conditional_error_consistency(observation)
            self.assertEqual(diagnostic["eligible_cell_count"], eligible)
            self.assertEqual(diagnostic["abs_rho_star_gt_one_count"], violations)
            self.assertEqual(diagnostic["conditional_2x2_psd_failure_count"], violations)
            self.assertEqual(diagnostic["status"], "conditional_assumption_check_only")
            self.assertFalse(diagnostic["assumption_supported_by_provider_evidence"])
            self.assertEqual(diagnostic["error_semantics"], "unknown")
            self.assertFalse(diagnostic["likelihood_ready"])

    def test_acquisition_metadata_raw_and_compressed_tamper_fail_closed(self) -> None:
        attacks = (
            ("acquisition", "level1_acquisition_hash_mismatch"),
            ("zmetadata", "level1_metadata_hash_mismatch"),
            ("raw", "level1_raw_hash_mismatch"),
            ("compressed", "level1_compressed_hash_mismatch"),
        )
        for attack, expected_code in attacks:
            with self.subTest(attack=attack), copied_source() as source:
                shot_dir = source / "shot30421_r1"
                if attack == "acquisition":
                    path = shot_dir / "acquisition.json"
                    path.write_bytes(path.read_bytes() + b"\n")
                elif attack == "zmetadata":
                    path = shot_dir / "zmetadata.json"
                    content = bytearray(path.read_bytes())
                    content[-2] ^= 0x01
                    path.write_bytes(content)
                elif attack == "raw":
                    path = shot_dir / "ne_error.raw"
                    content = bytearray(path.read_bytes())
                    content[0] ^= 0x01
                    path.write_bytes(content)
                else:
                    path = shot_dir / "ne_error.blosc"
                    content = bytearray(path.read_bytes())
                    content[-1] ^= 0x01
                    path.write_bytes(content)
                self.assert_adapter_code(
                    expected_code,
                    lambda source=source: adapter.load_level1_error_package(
                        source, PROTOCOL_PATH
                    ),
                )

    def test_protocol_axis_endian_unit_shape_and_readiness_drift_reject(self) -> None:
        def reversed_axes(protocol: dict[str, Any]) -> None:
            protocol["canonical_contract"]["dimensions"] = ["radial_index", "time"]

        def big_endian(protocol: dict[str, Any]) -> None:
            protocol["canonical_contract"]["dtype"] = "float32_big_endian"

        def invented_error_unit(protocol: dict[str, Any]) -> None:
            protocol["canonical_contract"]["arrays"]["ne_error"]["unit"] = "m^-3"

        def changed_shape(protocol: dict[str, Any]) -> None:
            protocol["shots"][0]["shape"] = [131, 284]

        def forged_ready(protocol: dict[str, Any]) -> None:
            protocol["error_semantics"]["likelihood_ready"] = True

        for mutation in (
            reversed_axes,
            big_endian,
            invented_error_unit,
            changed_shape,
            forged_ready,
        ):
            with self.subTest(mutation=mutation.__name__), tempfile.TemporaryDirectory() as temporary:
                protocol = copy.deepcopy(self.protocol)
                mutation(protocol)
                path = Path(temporary) / "level1_protocol.json"
                path.write_text(json.dumps(protocol), encoding="utf-8")
                self.assert_adapter_code(
                    "unsupported_level1_protocol",
                    lambda path=path: adapter.load_level1_error_package(
                        SOURCE_ROOT, path
                    ),
                )

    def test_live_array_coordinate_mask_and_readiness_forgery_reject(self) -> None:
        observation = self.package.observation(30420)
        big_endian = observation.ne.astype(">f4")
        big_endian.setflags(write=False)
        self.assert_adapter_code(
            "level1_observation_array_contract_error",
            lambda: adapter.validate_level1_observation(
                replace(observation, ne=big_endian)
            ),
        )
        uint8_mask = observation.observed_mask.astype(np.uint8)
        uint8_mask.setflags(write=False)
        self.assert_adapter_code(
            "level1_observation_mask_contract_error",
            lambda: adapter.validate_level1_observation(
                replace(observation, observed_mask=uint8_mask)
            ),
        )
        drifted_mask = observation.observed_mask.copy()
        drifted_mask.flat[0] = not drifted_mask.flat[0]
        drifted_mask.setflags(write=False)
        self.assert_adapter_code(
            "level1_observation_alignment_error",
            lambda: adapter.validate_level1_observation(
                replace(observation, observed_mask=drifted_mask)
            ),
        )
        nonmonotone_time = observation.time_s.copy()
        nonmonotone_time[1] = nonmonotone_time[0]
        nonmonotone_time.setflags(write=False)
        self.assert_adapter_code(
            "level1_source_array_binding_error",
            lambda: adapter.validate_level1_observation(
                replace(observation, time_s=nonmonotone_time)
            ),
        )
        changed_error = observation.ne_error.copy()
        changed_index = tuple(np.argwhere(observation.observed_mask)[0])
        changed_error[changed_index] = np.nextafter(
            changed_error[changed_index], np.float32(np.inf)
        )
        changed_error.setflags(write=False)
        forged_values = independently_rehash(observation, ne_error=changed_error)
        self.assert_adapter_code(
            "level1_source_array_binding_error",
            lambda: adapter.validate_level1_observation(forged_values),
        )
        forged_ready = replace(observation, likelihood_ready=True)
        self.assert_adapter_code(
            "level1_error_semantics_contract_error",
            forged_ready.require_likelihood_ready,
        )
        forged_semantics = replace(
            observation,
            error_semantics="provider_standard_deviation_and_covariance",
            likelihood_ready=True,
        )
        self.assert_adapter_code(
            "level1_error_semantics_contract_error",
            lambda: adapter.conditional_error_consistency(forged_semantics),
        )

    def test_rehashed_source_record_metadata_and_hash_forgery_reject(self) -> None:
        observation = self.package.observation(30421)
        mutations = {
            "metadata_dtype": lambda records: records["ne"]["metadata"].__setitem__(
                "dtype", ">f4"
            ),
            "metadata_shape": lambda records: records["ne_error"]["metadata"].__setitem__(
                "shape", [131, 284]
            ),
            "raw_hash": lambda records: records["te_error"].__setitem__(
                "raw_sha256", "0" * 64
            ),
            "compressed_hash": lambda records: records["covariance_ne_te"].__setitem__(
                "compressed_sha256", "f" * 64
            ),
            "raw_path": lambda records: records["ne"].__setitem__(
                "path", "shot30420_r1/ne.raw"
            ),
        }
        for name, mutation in mutations.items():
            with self.subTest(mutation=name):
                records = copy.deepcopy(observation.source_records)
                mutation(records)
                forged = independently_rehash(observation, source_records=records)
                self.assert_adapter_code(
                    "level1_source_records_binding_error",
                    lambda forged=forged: adapter.validate_level1_observation(forged),
                )

    def test_package_claim_split_receipt_and_writer_cannot_forge_acceptance(self) -> None:
        broadened = replace(
            self.package,
            claim_ceiling="provider_bound_likelihood_and_formal_inverse_ready",
        )
        self.assert_adapter_code(
            "level1_package_metadata_error", broadened.require_likelihood_ready
        )
        stale_split = dict(self.package.split_receipt)
        stale_split["formal_split_ready"] = True
        forged_split = replace(self.package, split_receipt=stale_split)
        self.assert_adapter_code(
            "level1_split_receipt_stale",
            lambda: adapter.validate_level1_package_integrity(forged_split),
        )
        with tempfile.TemporaryDirectory() as temporary:
            self.assert_adapter_code(
                "level1_package_metadata_error",
                lambda: adapter.write_level1_error_package(
                    broadened, Path(temporary) / "broadened"
                ),
            )

    def test_valid_writer_preserves_unknown_semantics_and_artifact_hashes(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "canonical"
            report = adapter.write_level1_error_package(self.package, output)
            self.assertEqual(report["program_state"], "pass_with_scope")
            self.assertEqual(
                report["error_data_status"],
                "present_values_unknown_statistical_semantics",
            )
            self.assertFalse(report["likelihood_ready"])
            self.assertEqual(report["physical_state"], "unknown")
            self.assertEqual(report["resolution"], "terminal_deferred")
            self.assertEqual(report["formal_inverse"], "not_executed")
            self.assertEqual(report["b07b"], "not_claimed")
            manifest = json.loads(
                (output / "artifact_manifest.json").read_text(encoding="utf-8")
            )
            for record in manifest["files"]:
                path = output / record["path"]
                self.assertEqual(path.stat().st_size, record["bytes"])
                self.assertEqual(sha256_file(path), record["sha256"])
            canonical = json.loads(
                (output / "canonical_manifest.json").read_text(encoding="utf-8")
            )
            self.assertFalse(canonical["iter_included"])
            self.assertEqual(
                canonical["level2_binding"]["status"],
                "prohibited_unbound_products",
            )
            self.assertFalse(canonical["split_receipt"]["formal_split_ready"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
