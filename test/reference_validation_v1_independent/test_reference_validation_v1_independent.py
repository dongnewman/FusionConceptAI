from __future__ import annotations

import hashlib
import json
import math
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
import zstandard


ROOT = Path(__file__).resolve().parents[2]
ADAPTER_DIR = ROOT / "benchmarks" / "reference_validation_v1"
SOURCE_ROOT = ROOT / "benchmarks" / "reference_data_v2"
LEVEL1_ROOT = ROOT / "benchmarks" / "reference_data_level1_v1"
PROTOCOL_PATH = ADAPTER_DIR / "protocol.json"
SOURCE_EVIDENCE_PATH = ADAPTER_DIR / "source_evidence.json"
sys.path.insert(0, str(ADAPTER_DIR))

import reference_adapter as adapter  # noqa: E402


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def json_bytes(value: Any) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        allow_nan=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


def source_reference(manifest: dict[str, Any], shot_id: int) -> dict[str, Any]:
    matches = [
        item
        for item in manifest["references"]
        if item.get("device_name") == "MAST" and item.get("shot_id") == shot_id
    ]
    if len(matches) != 1:
        raise AssertionError(f"expected one MAST reference for shot {shot_id}")
    return matches[0]


def raw_entry(reference: dict[str, Any], kind: str) -> dict[str, Any]:
    matches = [item for item in reference["raw_files"] if item["kind"] == kind]
    if len(matches) != 1:
        raise AssertionError(f"expected one raw entry of kind {kind}")
    return matches[0]


def decode_zarr_v3_chunk(
    source_root: Path,
    reference: dict[str, Any],
    metadata: dict[str, Any],
    array_path: str,
    kind: str,
) -> np.ndarray:
    """Independent minimal decoder for the exact acquired full-shape chunks."""

    node = metadata[array_path]
    shape = tuple(node["shape"])
    entry = raw_entry(reference, kind)
    compressed_path = source_root / entry["path"]
    if sha256_file(compressed_path) != entry["sha256"]:
        raise AssertionError(f"fixture hash mismatch for {compressed_path}")
    decoded = zstandard.ZstdDecompressor().decompress(
        compressed_path.read_bytes(), max_output_size=math.prod(shape) * 8
    )
    if len(decoded) != math.prod(shape) * 8:
        raise AssertionError(f"unexpected decoded byte count for {array_path}")
    return np.frombuffer(decoded, dtype="<f8").reshape(shape).copy()


def independent_payload_hash(observation: adapter.CanonicalObservation) -> str:
    header = {
        "domain": "FusionConceptAI.reference_validation.canonical_observation.v1",
        "record_id": observation.record_id,
        "shot_id": observation.shot_id,
        "channel": observation.channel,
        "quantity": observation.quantity,
        "raw_dimensions": list(observation.raw_dimensions),
        "raw_shape": list(observation.raw_shape),
        "raw_unit": observation.raw_unit,
        "canonical_dimensions": list(observation.canonical_dimensions),
        "canonical_unit": observation.canonical_unit,
        "axis_permutation": list(observation.axis_permutation),
        "shape": list(observation.values.shape),
        "source_response_sha256": observation.source_response_sha256,
        "source_schema_sha256": observation.source_schema_sha256,
        "source_time_sha256": observation.source_time_sha256,
        "source_radius_sha256": observation.source_radius_sha256,
        "catalog_sha256": observation.catalog_sha256,
        "catalog_row": dict(observation.catalog_row),
        "catalog_comparison": dict(observation.catalog_comparison),
        "uncertainty": dict(observation.uncertainty),
    }
    digest = hashlib.sha256()
    digest.update(json_bytes(header))
    digest.update(np.asarray(observation.time_s, dtype="<f8").tobytes(order="C"))
    digest.update(
        np.asarray(observation.major_radius_m, dtype="<f8").tobytes(order="C")
    )
    digest.update(np.asarray(observation.values, dtype="<f8").tobytes(order="C"))
    digest.update(
        np.asarray(observation.observed_mask, dtype=np.uint8).tobytes(order="C")
    )
    return digest.hexdigest()


def independent_lineage_hash(observation: adapter.CanonicalObservation) -> str:
    digest = hashlib.sha256()
    digest.update(b"FusionConceptAI.reference_validation.sample_lineage.v1\0")
    digest.update(observation.record_id.encode("utf-8"))
    digest.update(observation.source_response_sha256.encode("ascii"))
    digest.update(observation.canonical_payload_sha256.encode("ascii"))
    for t_index, r_index in np.argwhere(observation.observed_mask):
        t = int(t_index)
        r = int(r_index)
        digest.update(struct.pack("<II", t, r))
        digest.update(
            struct.pack(
                "<ddd",
                float(observation.time_s[t]),
                float(observation.major_radius_m[r]),
                float(observation.values[t, r]),
            )
        )
    return digest.hexdigest()


def rehash_observation(
    observation: adapter.CanonicalObservation,
    **changes: Any,
) -> adapter.CanonicalObservation:
    changed = replace(observation, **changes)
    payload_hash = independent_payload_hash(changed)
    changed = replace(changed, canonical_payload_sha256=payload_hash)
    return replace(changed, sample_lineage_sha256=independent_lineage_hash(changed))


def refresh_entry(source_root: Path, reference: dict[str, Any], kind: str) -> None:
    entry = raw_entry(reference, kind)
    path = source_root / entry["path"]
    entry["sha256"] = sha256_file(path)
    entry["bytes"] = path.stat().st_size


Mutation = Callable[[Path, dict[str, Any], dict[str, Any]], None]


@contextmanager
def rebased_source_copy(mutator: Mutation) -> Iterator[tuple[Path, Path]]:
    """Make a fully re-hashed temporary source package for semantic negatives."""

    with tempfile.TemporaryDirectory() as temporary:
        temporary_root = Path(temporary)
        source_copy = temporary_root / "reference_data_v2"
        protocol_dir = temporary_root / "reference_validation_v1"
        shutil.copytree(SOURCE_ROOT, source_copy)
        protocol_dir.mkdir()
        shutil.copy2(SOURCE_EVIDENCE_PATH, protocol_dir / "source_evidence.json")

        manifest_path = source_copy / "reference_manifest.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        reference = source_reference(manifest, 30421)
        mutator(source_copy, manifest, reference)
        manifest_path.write_text(
            json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )

        inverse_path = source_copy / "inverse_protocol.json"
        inverse = json.loads(inverse_path.read_text(encoding="utf-8"))
        inverse["manifest"]["sha256"] = sha256_file(manifest_path)
        inverse_path.write_text(
            json.dumps(inverse, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )

        protocol = json.loads(PROTOCOL_PATH.read_text(encoding="utf-8"))
        protocol["source_package"]["reference_manifest_sha256"] = sha256_file(
            manifest_path
        )
        protocol["source_package"]["inverse_protocol_sha256"] = sha256_file(
            inverse_path
        )
        protocol_copy = protocol_dir / "protocol.json"
        protocol_copy.write_text(
            json.dumps(protocol, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        yield source_copy, protocol_copy


class IndependentReferenceValidationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.manifest = json.loads(
            (SOURCE_ROOT / "reference_manifest.json").read_text(encoding="utf-8")
        )
        cls.package = adapter.load_reference_package(SOURCE_ROOT, PROTOCOL_PATH)

    def assert_adapter_code(self, expected: str, callable_: Callable[[], Any]) -> None:
        with self.assertRaises(adapter.AdapterError) as caught:
            callable_()
        self.assertEqual(caught.exception.code, expected)

    def test_independent_raw_decode_axes_mask_and_hash_chain(self) -> None:
        contracts = {
            "n_e": ("zarr_v3_chunk_thomson_scattering_n_e", "m^-3"),
            "t_e": ("zarr_v3_chunk_thomson_scattering_t_e", "eV"),
        }
        for observation in self.package.observations:
            with self.subTest(shot=observation.shot_id, channel=observation.channel):
                reference = source_reference(self.manifest, observation.shot_id)
                schema_entry = raw_entry(reference, "zarr_v3_consolidated_schema")
                schema_path = SOURCE_ROOT / schema_entry["path"]
                self.assertEqual(sha256_file(schema_path), schema_entry["sha256"])
                schema = json.loads(schema_path.read_text(encoding="utf-8"))
                metadata = schema["consolidated_metadata"]["metadata"]

                response_kind, canonical_unit = contracts[observation.channel]
                response_path = f"thomson_scattering/{observation.channel}"
                raw = decode_zarr_v3_chunk(
                    SOURCE_ROOT, reference, metadata, response_path, response_kind
                )
                time_s = decode_zarr_v3_chunk(
                    SOURCE_ROOT,
                    reference,
                    metadata,
                    "thomson_scattering/time",
                    "zarr_v3_chunk_thomson_scattering_time",
                ).reshape(-1)
                radius_m = decode_zarr_v3_chunk(
                    SOURCE_ROOT,
                    reference,
                    metadata,
                    "thomson_scattering/major_radius",
                    "zarr_v3_chunk_thomson_scattering_major_radius",
                ).reshape(-1)
                canonical = np.transpose(raw, (1, 0))
                mask = np.isfinite(canonical)

                self.assertEqual(
                    tuple(metadata[response_path]["dimension_names"]),
                    ("major_radius", "time"),
                )
                self.assertEqual(observation.raw_shape, raw.shape)
                self.assertEqual(observation.axis_permutation, (1, 0))
                self.assertEqual(observation.canonical_dimensions, ("time", "major_radius"))
                self.assertEqual(observation.canonical_shape, canonical.shape)
                self.assertEqual(observation.canonical_unit, canonical_unit)
                np.testing.assert_allclose(
                    observation.values, canonical, rtol=0.0, atol=0.0, equal_nan=True
                )
                np.testing.assert_array_equal(observation.observed_mask, mask)
                np.testing.assert_array_equal(observation.time_s, time_s)
                np.testing.assert_array_equal(observation.major_radius_m, radius_m)

                response_entry = raw_entry(reference, response_kind)
                self.assertEqual(
                    observation.source_response_sha256, response_entry["sha256"]
                )
                self.assertEqual(
                    sha256_file(SOURCE_ROOT / response_entry["path"]),
                    observation.source_response_sha256,
                )
                self.assertEqual(
                    independent_payload_hash(observation),
                    observation.canonical_payload_sha256,
                )
                self.assertEqual(
                    independent_lineage_hash(observation),
                    observation.sample_lineage_sha256,
                )

    def test_source_byte_tamper_is_rejected_before_decode(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            source_copy = Path(temporary) / "reference_data_v2"
            shutil.copytree(SOURCE_ROOT, source_copy)
            reference = source_reference(self.manifest, 30421)
            entry = raw_entry(reference, "zarr_v3_chunk_thomson_scattering_n_e")
            path = source_copy / entry["path"]
            tampered = bytearray(path.read_bytes())
            tampered[len(tampered) // 2] ^= 0x01
            path.write_bytes(tampered)
            self.assert_adapter_code(
                "raw_hash_mismatch",
                lambda: adapter.load_reference_package(source_copy, PROTOCOL_PATH),
            )

    def test_rebased_schema_unit_axis_dtype_endian_and_codec_tamper_fail_closed(self) -> None:
        def mutate_schema(
            edit: Callable[[dict[str, Any]], None]
        ) -> Mutation:
            def mutation(
                source_root: Path,
                _manifest: dict[str, Any],
                reference: dict[str, Any],
            ) -> None:
                entry = raw_entry(reference, "zarr_v3_consolidated_schema")
                path = source_root / entry["path"]
                schema = json.loads(path.read_text(encoding="utf-8"))
                edit(schema["consolidated_metadata"]["metadata"])
                path.write_text(
                    json.dumps(schema, ensure_ascii=False, separators=(",", ":")),
                    encoding="utf-8",
                )
                refresh_entry(source_root, reference, "zarr_v3_consolidated_schema")

            return mutation

        cases: list[tuple[str, Callable[[dict[str, Any]], None], str]] = [
            (
                "wrong profile unit",
                lambda metadata: metadata["thomson_scattering/n_e"]["attributes"].__setitem__(
                    "units", "eV"
                ),
                "unit_contract_error",
            ),
            (
                "wrong profile axes",
                lambda metadata: metadata["thomson_scattering/n_e"].__setitem__(
                    "dimension_names", ["time", "channel"]
                ),
                "dimension_contract_error",
            ),
            (
                "wrong dtype",
                lambda metadata: metadata["thomson_scattering/n_e"].__setitem__(
                    "data_type", "float32"
                ),
                "zarr_dtype_error",
            ),
            (
                "wrong endian",
                lambda metadata: metadata["thomson_scattering/n_e"]["codecs"][0][
                    "configuration"
                ].__setitem__("endian", "big"),
                "zarr_codec_error",
            ),
            (
                "wrong compressor",
                lambda metadata: metadata["thomson_scattering/n_e"]["codecs"][1].__setitem__(
                    "name", "gzip"
                ),
                "zarr_codec_error",
            ),
            (
                "wrong coordinate unit",
                lambda metadata: metadata["thomson_scattering/time"]["attributes"].__setitem__(
                    "units", "ms"
                ),
                "coordinate_unit_error",
            ),
            (
                "wrong coordinate axis",
                lambda metadata: metadata["thomson_scattering/time"].__setitem__(
                    "dimension_names", ["major_radius"]
                ),
                "coordinate_dimension_error",
            ),
        ]
        for label, edit, code in cases:
            with self.subTest(label=label):
                with rebased_source_copy(mutate_schema(edit)) as (source_copy, protocol):
                    self.assert_adapter_code(
                        code,
                        lambda: adapter.load_reference_package(source_copy, protocol),
                    )

    def test_rebased_nonmonotone_time_coordinate_is_rejected(self) -> None:
        def mutation(
            source_root: Path,
            _manifest: dict[str, Any],
            reference: dict[str, Any],
        ) -> None:
            entry = raw_entry(reference, "zarr_v3_chunk_thomson_scattering_time")
            path = source_root / entry["path"]
            schema_entry = raw_entry(reference, "zarr_v3_consolidated_schema")
            schema = json.loads(
                (source_root / schema_entry["path"]).read_text(encoding="utf-8")
            )
            node = schema["consolidated_metadata"]["metadata"][
                "thomson_scattering/time"
            ]
            shape = tuple(node["shape"])
            decoded = zstandard.ZstdDecompressor().decompress(
                path.read_bytes(), max_output_size=math.prod(shape) * 8
            )
            values = np.frombuffer(decoded, dtype="<f8").copy()
            values[1] = values[0]
            path.write_bytes(zstandard.ZstdCompressor().compress(values.tobytes()))
            refresh_entry(
                source_root, reference, "zarr_v3_chunk_thomson_scattering_time"
            )

        with rebased_source_copy(mutation) as (source_copy, protocol):
            self.assert_adapter_code(
                "coordinate_order_error",
                lambda: adapter.load_reference_package(source_copy, protocol),
            )

    def test_pure_canonical_boundary_rejects_shape_axis_unit_and_empty_data(self) -> None:
        raw = np.array([[1.0, np.nan, 3.0], [4.0, 5.0, 6.0]], dtype="<f8")
        time_s = np.array([0.1, 0.2, 0.3], dtype="<f8")
        radius_m = np.array([1.0, 1.1], dtype="<f8")
        values, mask, permutation = adapter.canonicalize_profile(
            raw,
            raw_dimensions=("major_radius", "time"),
            raw_unit="1 / m ** 3",
            channel="n_e",
            time_s=time_s,
            major_radius_m=radius_m,
        )
        np.testing.assert_allclose(values, raw.T, rtol=0.0, atol=0.0, equal_nan=True)
        np.testing.assert_array_equal(mask, np.isfinite(raw.T))
        self.assertEqual(permutation, (1, 0))

        failures = [
            (
                "shape_contract_error",
                dict(raw_values=raw.reshape(-1), raw_dimensions=("major_radius", "time")),
            ),
            (
                "dimension_contract_error",
                dict(raw_values=raw, raw_dimensions=("major_radius", "channel")),
            ),
            (
                "unit_contract_error",
                dict(raw_values=raw, raw_dimensions=("major_radius", "time"), raw_unit="eV"),
            ),
            (
                "time_alignment_error",
                dict(
                    raw_values=raw,
                    raw_dimensions=("major_radius", "time"),
                    time_s=np.array([0.1, 0.2]),
                ),
            ),
            (
                "radius_alignment_error",
                dict(
                    raw_values=raw,
                    raw_dimensions=("major_radius", "time"),
                    major_radius_m=np.array([1.0]),
                ),
            ),
            (
                "empty_observation",
                dict(
                    raw_values=np.full_like(raw, np.nan),
                    raw_dimensions=("major_radius", "time"),
                ),
            ),
        ]
        defaults = dict(
            raw_unit="1 / m ** 3",
            channel="n_e",
            time_s=time_s,
            major_radius_m=radius_m,
        )
        for code, changes in failures:
            with self.subTest(code=code):
                arguments = defaults | changes
                self.assert_adapter_code(
                    code, lambda arguments=arguments: adapter.canonicalize_profile(**arguments)
                )

    def test_operator_rejects_grid_prediction_and_observation_identity_drift(self) -> None:
        observation = self.package.observation(30421, "n_e")
        projection = adapter.apply_thomson_sample_operator(
            observation,
            observation.values,
            observation.canonical_unit,
            observation.major_radius_m,
            observation.time_s,
        )
        self.assertEqual(len(projection.sample_ids), observation.observed_count)
        self.assertFalse(projection.likelihood_ready)
        self.assertEqual(projection.uncertainty_status, "typed_absent")

        bad_time = observation.time_s.copy()
        bad_time[0] = np.nextafter(bad_time[0], math.inf)
        bad_radius = observation.major_radius_m.copy()
        bad_radius[-1] = np.nextafter(bad_radius[-1], math.inf)
        bad_prediction = observation.values.copy()
        observed_index = tuple(np.argwhere(observation.observed_mask)[0])
        bad_prediction[observed_index] = np.nan
        cases = [
            (
                "prediction_unit_error",
                dict(predicted_values=observation.values, predicted_unit="eV"),
            ),
            (
                "prediction_shape_error",
                dict(predicted_values=observation.values[:, :-1]),
            ),
            ("prediction_time_grid_error", dict(time_s=bad_time)),
            ("prediction_radius_grid_error", dict(major_radius_m=bad_radius)),
            ("prediction_nonfinite_error", dict(predicted_values=bad_prediction)),
        ]
        defaults = dict(
            predicted_values=observation.values,
            predicted_unit=observation.canonical_unit,
            major_radius_m=observation.major_radius_m,
            time_s=observation.time_s,
        )
        for code, changes in cases:
            with self.subTest(code=code):
                arguments = defaults | changes
                self.assert_adapter_code(
                    code,
                    lambda arguments=arguments: adapter.apply_thomson_sample_operator(
                        observation, **arguments
                    ),
                )

        drifted_mask = observation.observed_mask.copy()
        drifted_mask[observed_index] = False
        drifted_values = observation.values.copy()
        drifted_values[observed_index] = np.nextafter(
            drifted_values[observed_index], math.inf
        )
        drifted_time = observation.time_s.copy()
        drifted_time[0] = np.nextafter(drifted_time[0], math.inf)
        drifted_mask.setflags(write=False)
        drifted_values.setflags(write=False)
        drifted_time.setflags(write=False)
        for field, forged, expected_code in (
            (
                "mask",
                replace(observation, observed_mask=drifted_mask),
                "observation_mask_mismatch",
            ),
            (
                "values",
                replace(observation, values=drifted_values),
                "canonical_payload_hash_mismatch",
            ),
            (
                "time",
                replace(observation, time_s=drifted_time),
                "canonical_payload_hash_mismatch",
            ),
        ):
            with self.subTest(identity_drift=field):
                self.assert_adapter_code(
                    expected_code,
                    lambda forged=forged: adapter.apply_thomson_sample_operator(
                        forged,
                        forged.values,
                        forged.canonical_unit,
                        forged.major_radius_m,
                        forged.time_s,
                    ),
                )

    def test_split_rejects_shot_response_and_stored_lineage_reuse(self) -> None:
        receipt = adapter.validate_no_leakage(self.package)
        self.assertEqual(receipt["status"], "pass_no_cross_split_response_lineage")
        self.assertEqual(receipt["validation_split"]["status"], "typed_absent")
        self.assertFalse(receipt["formal_minimum_met"])
        self.assertFalse(receipt["formal_split_ready"])
        self.assertEqual(receipt["strict_any_artifact_policy"]["status"], "terminal_deferred")
        self.assertIn("canonical_payload_hashes", receipt["checked_identities"])
        self.assertIn("sample_lineage_hashes", receipt["checked_identities"])

        calibration = self.package.observation(30421, "n_e")
        held_out = self.package.observation(30420, "n_e")

        same_shot_records = list(self.package.observations)
        same_shot_records[same_shot_records.index(calibration)] = replace(
            calibration, split="held_out"
        )
        self.assert_adapter_code(
            "split_leakage",
            lambda: adapter.validate_no_leakage_records(
                same_shot_records, self.package.protocol
            ),
        )

        shared_response = rehash_observation(
            held_out, source_response_sha256=calibration.source_response_sha256
        )
        response_records = list(self.package.observations)
        response_records[response_records.index(held_out)] = shared_response
        self.assert_adapter_code(
            "split_leakage",
            lambda: adapter.validate_no_leakage_records(
                response_records, self.package.protocol
            ),
        )

        forged_lineage = replace(
            held_out, sample_lineage_sha256=calibration.sample_lineage_sha256
        )
        lineage_records = list(self.package.observations)
        lineage_records[lineage_records.index(held_out)] = forged_lineage
        self.assert_adapter_code(
            "split_leakage",
            lambda: adapter.validate_no_leakage_records(
                lineage_records, self.package.protocol
            ),
        )

    def test_level1_error_products_are_real_but_unbound_to_level2_likelihood(self) -> None:
        candidate = self.package.uncertainty["candidate_level1_error_arrays"]
        self.assertEqual(candidate["status"], "discovered_unbound_not_consumed")
        self.assertEqual(set(candidate["observed_metadata_shot_ids"]), {30420, 30421})
        self.assertEqual(self.package.uncertainty["status"], "typed_absent")
        self.assertEqual(
            self.package.uncertainty["scope"],
            "selected_fair_mast_level2_thomson_profiles",
        )
        self.assertFalse(self.package.uncertainty["likelihood_ready"])
        self.assert_adapter_code(
            "uncertainty_typed_absent", self.package.require_likelihood_ready
        )

        for shot_id in (30420, 30421):
            with self.subTest(shot=shot_id):
                acquisition = json.loads(
                    (
                        LEVEL1_ROOT / f"shot{shot_id}_r1" / "acquisition.json"
                    ).read_text(encoding="utf-8")
                )
                arrays = {item["name"]: item for item in acquisition["arrays"]}
                self.assertEqual(
                    acquisition["error_semantics"],
                    "unverified_not_assumed_standard_deviation",
                )
                self.assertFalse(acquisition["likelihood_ready"])
                self.assertFalse(acquisition["scientific_acceptance"])
                self.assertEqual(arrays["ne_error"]["attributes"]["units"], "")
                self.assertEqual(arrays["te_error"]["attributes"]["units"], "")
                self.assertEqual(
                    arrays["ne_error"]["metadata"]["shape"],
                    arrays["ne"]["metadata"]["shape"],
                )
                self.assertEqual(
                    arrays["te_error"]["metadata"]["shape"],
                    arrays["te"]["metadata"]["shape"],
                )
                level2_shape = list(self.package.observation(shot_id, "n_e").raw_shape)
                self.assertNotEqual(arrays["ne_error"]["metadata"]["shape"], level2_shape)
                self.assertEqual(
                    arrays["ne_error"]["attributes"]["_ARRAY_DIMENSIONS"],
                    ["time", "radial_index"],
                )
                self.assertEqual(
                    self.package.observation(shot_id, "n_e").raw_dimensions,
                    ("major_radius", "time"),
                )

    def test_catalog_conflict_and_iter_design_never_drive_measurement_values(self) -> None:
        for observation in self.package.observations:
            comparison = observation.catalog_comparison
            self.assertEqual(comparison["status"], "conflict_preserved")
            self.assertEqual(comparison["root_cause_status"], "unproven")
            self.assertEqual(comparison["normalization"], "none")
            self.assertEqual(comparison["raw_shape"], list(observation.raw_shape))
            self.assertEqual(comparison["raw_unit"], observation.raw_unit)
            if observation.channel == "n_e":
                self.assertEqual(comparison["catalog_unit"], "eV")
                self.assertEqual(observation.raw_unit, "1 / m ** 3")

        self.assertEqual(
            {item["reference_id"] for item in self.package.design_references},
            {"iter_design_v1"},
        )
        self.assertTrue(
            all(item["measurement_status"] == "typed_absent" for item in self.package.design_references)
        )
        self.assertTrue(all(item.shot_id in {30420, 30421} for item in self.package.observations))
        self.assertTrue(all("ITER" not in item.record_id for item in self.package.observations))

    def test_forged_package_uncertainty_and_claim_cannot_bypass_consumers(self) -> None:
        forged_uncertainty = dict(self.package.uncertainty)
        forged_uncertainty["status"] = "present_bound"
        forged_uncertainty["likelihood_ready"] = True
        forged_likelihood = replace(
            self.package,
            uncertainty=forged_uncertainty,
        )
        self.assert_adapter_code(
            "reference_package_uncertainty_error",
            forged_likelihood.require_likelihood_ready,
        )
        self.assert_adapter_code(
            "reference_package_uncertainty_error",
            lambda: adapter.validate_reference_package_integrity(forged_likelihood),
        )
        with tempfile.TemporaryDirectory() as temporary:
            self.assert_adapter_code(
                "reference_package_uncertainty_error",
                lambda: adapter.write_canonical_package(
                    forged_likelihood, Path(temporary) / "forged-likelihood"
                ),
            )

        broadened_claim = replace(
            self.package,
            claim_ceiling="likelihood_ready_and_formal_inverse_validated",
        )
        self.assert_adapter_code(
            "reference_package_metadata_error",
            lambda: adapter.validate_reference_package_integrity(broadened_claim),
        )
        with tempfile.TemporaryDirectory() as temporary:
            self.assert_adapter_code(
                "reference_package_metadata_error",
                lambda: adapter.write_canonical_package(
                    broadened_claim, Path(temporary) / "broadened-claim"
                ),
            )

    def test_materialized_bytes_hashes_and_claim_ceiling_are_self_consistent(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "canonical"
            report = adapter.write_canonical_package(self.package, output)
            self.assertEqual(report["program_state"], "pass_with_scope")
            self.assertEqual(report["execution_classification"], "process_completed")
            self.assertEqual(report["numerical_state"], "not_executed")
            self.assertEqual(report["physical_state"], "unknown")
            self.assertEqual(report["resolution"], "terminal_deferred")
            self.assertEqual(report["formal_inverse"], "not_executed")
            self.assertEqual(report["b07b"], "not_claimed")
            self.assertFalse(report["likelihood_ready"])

            artifact_manifest = json.loads(
                (output / "artifact_manifest.json").read_text(encoding="utf-8")
            )
            for record in artifact_manifest["files"]:
                path = output / record["path"]
                self.assertTrue(path.is_file(), record["path"])
                self.assertEqual(path.stat().st_size, record["bytes"])
                self.assertEqual(sha256_file(path), record["sha256"])

            manifest = json.loads(
                (output / "canonical_manifest.json").read_text(encoding="utf-8")
            )
            self.assertEqual(manifest["formal_inverse"], "not_executed")
            self.assertEqual(manifest["b03"], "not_claimed")
            self.assertEqual(manifest["b07b"], "not_claimed")
            self.assertEqual(
                manifest["split_receipt"]["validation_split"]["status"],
                "typed_absent",
            )
            self.assertTrue(
                all(
                    not item["included_in_observations"]
                    for item in manifest["design_references"]
                )
            )

            for entry in manifest["observations"]:
                observation = self.package.observation(entry["shot_id"], entry["channel"])
                values_path = output / entry["canonical"]["files"]["values"]["path"]
                mask_path = output / entry["canonical"]["files"]["mask"]["path"]
                values = np.frombuffer(values_path.read_bytes(), dtype="<f8").reshape(
                    observation.canonical_shape
                )
                mask = np.frombuffer(mask_path.read_bytes(), dtype=np.uint8).reshape(
                    observation.canonical_shape
                )
                np.testing.assert_allclose(
                    values, observation.values, rtol=0.0, atol=0.0, equal_nan=True
                )
                np.testing.assert_array_equal(mask.astype(bool), observation.observed_mask)

            self.assert_adapter_code(
                "output_exists",
                lambda: adapter.write_canonical_package(self.package, output),
            )


if __name__ == "__main__":
    unittest.main(verbosity=2)
