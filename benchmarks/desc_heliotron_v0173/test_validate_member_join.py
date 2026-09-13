import copy
import hashlib
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from validate_member_join import DEFAULT_INTERIOR, DEFAULT_NORMALIZED, DEFAULT_SOURCE, validate


def canonical_bytes(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()


class MemberJoinTests(unittest.TestCase):
    def test_raw_member_join_passes_screen_only(self):
        result = validate(DEFAULT_SOURCE, DEFAULT_NORMALIZED, DEFAULT_INTERIOR)
        self.assertEqual(result["status"], "screen_only_raw_member_join_verified")
        self.assertEqual(result["selected_equilibrium_index"], 3)
        self.assertEqual(result["resolution"]["NFP"], 19)
        self.assertFalse(result["authority"]["geometry_proved"])
        self.assertLessEqual(max(result["numeric_maxima_m"].values()), result["numerical_join_tolerance_m"])

    def test_altered_interior_term_fails(self):
        record = json.loads(DEFAULT_INTERIOR.read_text(encoding="utf-8"))
        record["subject"]["R"]["terms"][0]["coefficient_m"] *= 2
        wire = canonical_bytes(record["subject"])
        record["subject_canonical_json"] = wire.decode()
        record["subject_hash"] = hashlib.sha256(wire).hexdigest()
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "interior.json"
            path.write_text(json.dumps(record), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "raw HDF5"):
                validate(DEFAULT_SOURCE, DEFAULT_NORMALIZED, path)

    def test_wrong_member_and_nfp_fail(self):
        normalized = json.loads(DEFAULT_NORMALIZED.read_text(encoding="utf-8"))
        normalized["subject"]["provenance"]["selected_equilibrium_index"] = 2
        wire = canonical_bytes(normalized["subject"])
        normalized["subject_canonical_json"] = wire.decode()
        normalized["subject_hash"] = hashlib.sha256(wire).hexdigest()
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "normalized.json"
            path.write_text(json.dumps(normalized), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "normalized selected member"):
                validate(DEFAULT_SOURCE, path, DEFAULT_INTERIOR)
        interior = json.loads(DEFAULT_INTERIOR.read_text(encoding="utf-8"))
        interior["subject"]["source_resolution"]["NFP"] = 18
        wire = canonical_bytes(interior["subject"])
        interior["subject_canonical_json"] = wire.decode()
        interior["subject_hash"] = hashlib.sha256(wire).hexdigest()
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "interior.json"
            path.write_text(json.dumps(interior), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "raw HDF5"):
                validate(DEFAULT_SOURCE, DEFAULT_NORMALIZED, path)

    def test_rehashed_boundary_change_and_promoted_authority_fail(self):
        normalized = json.loads(DEFAULT_NORMALIZED.read_text(encoding="utf-8"))
        normalized["subject"]["boundary"]["radial_modes"][0]["coefficient_m"] += 1e-4
        wire = canonical_bytes(normalized["subject"])
        normalized["subject_canonical_json"] = wire.decode()
        normalized["subject_hash"] = hashlib.sha256(wire).hexdigest()
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "normalized.json"
            path.write_text(json.dumps(normalized), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "roundoff budget"):
                validate(DEFAULT_SOURCE, path, DEFAULT_INTERIOR)
        normalized = json.loads(DEFAULT_NORMALIZED.read_text(encoding="utf-8"))
        normalized["authority"]["measurement"] = True
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "normalized.json"
            path.write_text(json.dumps(normalized), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "authority exceeds"):
                validate(DEFAULT_SOURCE, path, DEFAULT_INTERIOR)


if __name__ == "__main__":
    unittest.main()
