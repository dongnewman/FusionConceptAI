from __future__ import annotations

import copy
import importlib.util
import json
import math
from pathlib import Path
import shutil
import tempfile
import unittest

import numpy as np
import zstandard


ROOT = Path(__file__).resolve().parents[2]
TOOL = ROOT / "tools/fetch_mast_pf_geometry_v1.py"
ACTUAL = ROOT / "benchmarks/reference_source_fields_v1/shot30421_pf_geometry_r1/acquisition_r1"
SPEC = importlib.util.spec_from_file_location("mast_pf_geometry_v1", TOOL)
pf = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(pf)


def encode_strings(values: list[str]) -> bytes:
    raw = len(values).to_bytes(4, "little")
    for value in values:
        encoded = value.encode("utf-8")
        raw += len(encoded).to_bytes(4, "little") + encoded
    return raw


class PFGeometryProtocolTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.selection = pf.build_selection()

    def test_01_explicit_selection_and_budget(self):
        self.assertEqual(self.selection["selected_array_count"], 209)
        self.assertEqual(self.selection["active_array_count"], 69)
        self.assertEqual(self.selection["passive_array_count"], 140)
        self.assertEqual(self.selection["fixed_numeric_decoded_bytes"], 4_151_112)
        self.assertLessEqual(self.selection["fixed_numeric_decoded_bytes"], pf.MAX_TOTAL_DECODED_BYTES)
        paths = [item["path"] for item in self.selection["fields"]]
        self.assertEqual(paths, list(pf.SELECTED_ARRAYS))
        self.assertEqual(len(paths), len(set(paths)))
        self.assertNotIn("pf_active/coil_voltage", paths)
        self.assertNotIn("pf_active/voltage_channel", paths)

    def test_02_dirty_development_provenance_is_retained(self):
        for group in ("pf_active", "pf_passive"):
            attrs = self.selection["group_nodes"][group]["attributes"]
            self.assertIn("(dirty)", attrs["commit_url"])
            self.assertIn("ab435c799d892956fb042d55391f7d1be0c950e6", attrs["commit_url"])
        sol_r = next(item for item in self.selection["fields"] if item["path"] == "pf_active/sol_r")
        attrs = sol_r["node"]["attributes"]
        self.assertEqual(attrs["status"], "development")
        self.assertEqual(attrs["creatorCommitId"], "")
        self.assertEqual(attrs["units"], "SI, degrees, m")
        self.assertEqual(attrs["coordinateSystem"], "Cylindrical")

    def test_03_numeric_codec_endian_and_dimension_rejections(self):
        node = copy.deepcopy(next(item["node"] for item in self.selection["fields"] if item["path"] == "pf_active/coil_current"))
        node["codecs"][0]["configuration"]["endian"] = "big"
        with self.assertRaisesRegex(pf.PFError, "zarr_endian_error"):
            pf.validate_node("pf_active/coil_current", node)
        node = copy.deepcopy(next(item["node"] for item in self.selection["fields"] if item["path"] == "pf_active/coil_current"))
        node["dimension_names"] = ["time", "current_channel"]
        # Rank remains valid, but the exact node is still bound by selection/record equality.
        summary = pf.validate_node("pf_active/coil_current", node)
        self.assertEqual(summary["dimensions"], ["time", "current_channel"])
        field = next(item for item in self.selection["fields"] if item["path"] == "pf_active/coil_current")
        forged_record = {"path": field["path"], "node": node}
        with self.assertRaisesRegex(pf.PFError, "array_metadata_binding_error"):
            pf.verify_array_record(Path(tempfile.gettempdir()), forged_record, field)

    def test_04_scalar_and_unit_metadata_are_bound(self):
        shot = next(item for item in self.selection["fields"] if item["path"] == "pf_active/shot_id")
        self.assertEqual(shot["shape"], [])
        self.assertEqual(shot["dimensions"], [])
        geometry = next(item for item in self.selection["fields"] if item["path"] == "pf_passive/ring_r")
        forged = copy.deepcopy(geometry)
        forged["node"]["attributes"]["units"] = "cm"
        self.assertNotEqual(
            pf.sha256_bytes(pf.canonical_bytes({"groups": self.selection["group_nodes"], "fields": [geometry], "excluded": list(pf.EXPECTED_EXCLUDED_ARRAYS)})),
            pf.sha256_bytes(pf.canonical_bytes({"groups": self.selection["group_nodes"], "fields": [forged], "excluded": list(pf.EXPECTED_EXCLUDED_ARRAYS)})),
        )

    def test_05_vlen_utf8_codec_and_negative_controls(self):
        values = ["SOL", "P2IL FEED", "α"]
        raw = encode_strings(values)
        self.assertEqual(pf.decode_vlen_utf8(raw, (3,)), values)
        with self.assertRaisesRegex(pf.PFError, "string_count_error"):
            pf.decode_vlen_utf8(raw, (2,))
        with self.assertRaisesRegex(pf.PFError, "string_trailing_bytes_error"):
            pf.decode_vlen_utf8(raw + b"x", (3,))
        bad = (1).to_bytes(4, "little") + (1).to_bytes(4, "little") + b"\xff"
        with self.assertRaisesRegex(pf.PFError, "string_utf8_error"):
            pf.decode_vlen_utf8(bad, (1,))

    def test_06_zstd_numeric_decode_preserves_little_endian_shape(self):
        source = np.arange(12, dtype="<f8").reshape(3, 4)
        compressed = zstandard.ZstdCompressor(level=1).compress(source.tobytes(order="C"))
        raw = pf.decompress_chunk(compressed)
        values, shape = pf.decode_numeric(raw, "float64", (3, 4), (2, 4))
        self.assertEqual(shape, (3, 4))
        np.testing.assert_array_equal(values, source)
        with self.assertRaisesRegex(pf.PFError, "numeric_decoded_size_error"):
            pf.decode_numeric(raw[:-1], "float64", (3, 4), (2, 4))

    def test_07_path_escape_and_absolute_path_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with self.assertRaisesRegex(pf.PFError, "path_escape_error"):
                pf.safe_relative(root, "../outside")
            with self.assertRaisesRegex(pf.PFError, "path_escape_error"):
                pf.safe_relative(root, str((root.parent / "outside").resolve()))

    def test_08_payload_hashes_reject_stale_tampering(self):
        forged = copy.deepcopy(self.selection)
        forged["selected_array_count"] = 208
        with self.assertRaisesRegex(pf.PFError, "selection_payload_hash_error"):
            pf.validate_seal(forged, "selection_payload_sha256", "selection_payload_hash_error")
        forged = pf.seal(forged, "selection_payload_sha256")
        self.assertNotEqual(forged, self.selection)

    def test_09_science_readiness_cannot_be_forged(self):
        forged = dict(pf.SCIENCE_LOCKS)
        forged["free_boundary_ready"] = True
        with self.assertRaisesRegex(pf.PFError, "science_lock_error"):
            pf._science_locks(forged)
        forged = dict(pf.SCIENCE_LOCKS)
        forged["current_sign_semantics_verified"] = True
        with self.assertRaisesRegex(pf.PFError, "science_lock_error"):
            pf._science_locks(forged)

    def test_10_chunk_keys_and_coverage_are_exact(self):
        self.assertEqual(list(pf.array_chunk_indices((), ())), [()])
        self.assertEqual(pf.chunk_key(()), "c")
        indices = list(pf.array_chunk_indices((13, 15305), (7, 7653)))
        self.assertEqual(indices, [(0, 0), (0, 1), (1, 0), (1, 1)])
        self.assertEqual(pf.edge_layout((13, 15305), (7, 7653), (1, 1)), ((7, 7653), (6, 7652)))
        self.assertEqual(pf.chunk_key((1, 1)), "c/1/1")


@unittest.skipUnless(ACTUAL.is_dir(), "actual PF acquisition not present yet")
class PFGeometryActualAcquisitionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.report = pf.verify_acquisition(ACTUAL)
        cls.selection = json.loads((ACTUAL / "selection.json").read_text(encoding="utf-8"))
        cls.receipt = json.loads((ACTUAL / "acquisition.json").read_text(encoding="utf-8"))

    def test_11_actual_full_acquisition_verifies(self):
        self.assertEqual(self.report["array_count"], 209)
        self.assertLessEqual(self.report["decoded_chunk_bytes"], pf.MAX_TOTAL_DECODED_BYTES)
        self.assertEqual(self.report["science_locks"], pf.SCIENCE_LOCKS)

    def _one_array_copy(self, path: str):
        field = next(item for item in self.selection["fields"] if item["path"] == path)
        record = copy.deepcopy(next(item for item in self.receipt["arrays"] if item["path"] == path))
        temporary = tempfile.TemporaryDirectory()
        root = Path(temporary.name)
        relatives = [record["assembled_path"], record["field_record_path"]]
        for chunk in record["chunks_acquired"]:
            relatives.extend((chunk["compressed_path"], chunk["decoded_path"]))
        for relative in relatives:
            source = pf.safe_relative(ACTUAL, relative)
            target = pf.safe_relative(root, relative)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
        return temporary, root, record, field

    def test_12_raw_decoded_tamper_is_rejected(self):
        temporary, root, record, field = self._one_array_copy("pf_active/coil_current")
        try:
            path = pf.safe_relative(root, record["chunks_acquired"][0]["decoded_path"])
            path.write_bytes(path.read_bytes()[:-1] + bytes([path.read_bytes()[-1] ^ 1]))
            with self.assertRaisesRegex(pf.PFError, "chunk_decoded_hash_error"):
                pf.verify_array_record(root, record, field)
        finally:
            temporary.cleanup()

    def test_13_compressed_tamper_is_rejected(self):
        temporary, root, record, field = self._one_array_copy("pf_passive/ring_r")
        try:
            path = pf.safe_relative(root, record["chunks_acquired"][0]["compressed_path"])
            raw = path.read_bytes()
            path.write_bytes(raw[:-1] + bytes([raw[-1] ^ 1]))
            with self.assertRaisesRegex(pf.PFError, "chunk_compressed_hash_error"):
                pf.verify_array_record(root, record, field)
        finally:
            temporary.cleanup()

    def test_14_assembled_tamper_is_rejected(self):
        temporary, root, record, field = self._one_array_copy("pf_active/current_channel")
        try:
            path = pf.safe_relative(root, record["assembled_path"])
            path.write_bytes(path.read_bytes() + b" ")
            with self.assertRaisesRegex(pf.PFError, "assembled_hash_error"):
                pf.verify_array_record(root, record, field)
        finally:
            temporary.cleanup()

    def test_15_record_path_escape_is_rejected(self):
        temporary, root, record, field = self._one_array_copy("pf_passive/time")
        try:
            record["chunks_acquired"][0]["decoded_path"] = "../outside.raw"
            with self.assertRaisesRegex(pf.PFError, "path_escape_error"):
                pf.verify_array_record(root, record, field)
        finally:
            temporary.cleanup()

    def test_16_record_metadata_or_unit_drift_is_rejected(self):
        temporary, root, record, field = self._one_array_copy("pf_active/sol_r")
        try:
            record["node"] = copy.deepcopy(record["node"])
            record["node"]["attributes"]["units"] = "cm"
            with self.assertRaisesRegex(pf.PFError, "array_metadata_binding_error"):
                pf.verify_array_record(root, record, field)
        finally:
            temporary.cleanup()

    def test_17_rehashed_summary_forgery_is_rejected_from_source_bytes(self):
        temporary, root, record, field = self._one_array_copy("pf_passive/ring_r")
        try:
            record["minimum"] = float(record["minimum"]) + 1.0
            snapshot = {key: value for key, value in record.items() if key not in ("field_record_path", "field_record_sha256")}
            field_record = pf.safe_relative(root, record["field_record_path"])
            pf.write_json(field_record, snapshot)
            record["field_record_sha256"] = pf.sha256_path(field_record)
            with self.assertRaisesRegex(pf.PFError, "array_summary_error"):
                pf.verify_array_record(root, record, field)
        finally:
            temporary.cleanup()

    def test_18_rehashed_chunk_layout_forgery_is_rejected(self):
        temporary, root, record, field = self._one_array_copy("pf_active/coil_current")
        try:
            record["chunks_acquired"][0]["starts"] = [1, 0]
            snapshot = {key: value for key, value in record.items() if key not in ("field_record_path", "field_record_sha256")}
            field_record = pf.safe_relative(root, record["field_record_path"])
            pf.write_json(field_record, snapshot)
            record["field_record_sha256"] = pf.sha256_path(field_record)
            with self.assertRaisesRegex(pf.PFError, "chunk_layout_record_error"):
                pf.verify_array_record(root, record, field)
        finally:
            temporary.cleanup()


if __name__ == "__main__":
    unittest.main()
