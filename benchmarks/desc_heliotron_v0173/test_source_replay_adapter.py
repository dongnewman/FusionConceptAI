import copy
import hashlib
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))
from source_replay_adapter import (  # noqa: E402
    R2_REQUEST_SHA256, construct_equilibrium, validate_request,
    verify_constructed_equilibrium,
)


REQUEST = ROOT.parent.parent / "runs" / "goal_recovery_20260913_012528_cst" / "n2_source_desc_replay_request_r2" / "request.json"
SOLVE = ROOT.parent.parent / "runs" / "goal_recovery_20260913_012528_cst" / "n2_source_desc_solve_r3"


class SourceReplayRequestTests(unittest.TestCase):
    def test_request_rehash_and_physics_join(self):
        request, _, joined = validate_request(REQUEST, R2_REQUEST_SHA256)
        self.assertEqual(request["authority"]["claim_ceiling"], "screen_only")
        self.assertEqual(joined["status"], "screen_only_raw_member_join_verified")

    def test_tamper_and_convention_cases_are_rejected(self):
        record = json.loads(REQUEST.read_text(encoding="utf-8"))
        cases = [("boundary", lambda x: x["boundary"]["R_modes"][0].__setitem__("coefficient_m", 9.0), "boundary"),
                 ("source", lambda x: x.__setitem__("source_artifact_sha256", "0" * 64), "hash mismatch"),
                 ("convention", lambda x: x["source_basis"].__setitem__("indexing", "ansi"), "convention"),
                 ("authority", lambda x: x["authority"].__setitem__("provider_executed", True), "authority")]
        for _, mutate, message in cases:
            changed = copy.deepcopy(record)
            mutate(changed)
            with self.subTest(message=message), self.assertRaisesRegex(ValueError, message):
                with tempfile.NamedTemporaryFile("w", suffix=".json", encoding="utf-8", delete=False) as stream:
                    json.dump(changed, stream)
                    path = Path(stream.name)
                try:
                    validate_request(path, hashlib.sha256(path.read_bytes()).hexdigest())
                finally:
                    path.unlink()

    def test_frozen_request_bytes_are_required(self):
        with self.assertRaisesRegex(ValueError, "request file hash mismatch"):
            validate_request(REQUEST, "0" * 64)

    def test_desc_fresh_construction_preserves_source_profiles(self):
        request, _, _ = validate_request(REQUEST, R2_REQUEST_SHA256)
        equilibrium = construct_equilibrium(request)
        verify_constructed_equilibrium(equilibrium, request)
        self.assertEqual(equilibrium.NFP, 19)
        self.assertEqual(equilibrium.spectral_indexing, "fringe")

    def test_nonconverged_output_reimports_with_source_subject(self):
        import desc.io

        receipt = json.loads((SOLVE / "result.json").read_text(encoding="utf-8"))
        output = SOLVE / "replay_equilibrium.h5"
        self.assertEqual(hashlib.sha256(output.read_bytes()).hexdigest(),
                         receipt["output_hdf5_sha256"])
        self.assertEqual(receipt["status"], "solver_nonconverged_screen_only")
        self.assertFalse(receipt["solver"]["success"])
        self.assertEqual(receipt["solver"]["niter"], 3)
        self.assertEqual(receipt["solver"]["residual_count"], 4940)
        self.assertTrue(receipt["solver"]["residual_all_finite"])
        self.assertGreater(receipt["solver"]["residual_l2_norm"], 0)
        self.assertGreater(receipt["solver"]["residual_max_abs"], 0)
        self.assertEqual(receipt["authority"]["physical_validation"], "unsupported")
        self.assertFalse(receipt["authority"]["geometry_proved"])
        self.assertFalse(receipt["authority"]["provider_executed"])
        self.assertEqual(hashlib.sha256((ROOT / "source_replay_adapter.py").read_bytes()).hexdigest(),
                         receipt["adapter_sha256"])
        equilibrium = desc.io.load(output)
        request, _, _ = validate_request(REQUEST, R2_REQUEST_SHA256)
        verify_constructed_equilibrium(equilibrium, request)
        for name, basis, values in (
            ("R", equilibrium.surface.R_basis, equilibrium.surface.R_lmn),
            ("Z", equilibrium.surface.Z_basis, equilibrium.surface.Z_lmn),
        ):
            expected = {(row["m"], row["n"])
                        for row in request["boundary"][f"{name}_modes"]}
            extras = [float(value) for mode, value in zip(basis.modes, values, strict=True)
                      if (int(mode[1]), int(mode[2])) not in expected]
            self.assertTrue(all(value == 0.0 for value in extras))


if __name__ == "__main__":
    unittest.main()
