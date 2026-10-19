from __future__ import annotations

import base64
import dataclasses
import hashlib
import importlib.util
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from types import MappingProxyType, SimpleNamespace

import numpy as np


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "benchmarks" / "reference_source_fields_v1" / "native_axisymmetric_adapter.py"
RUNNER_SOURCE = ROOT / "scripts" / "runtime_v4_freegs_axisymmetric_profile_runner_v2.py"
PINNED_PYTHON = Path(
    r"D:\006-Programing\LMC\outputs\fusion_concept_ai\.venv-freegs\Scripts\python.exe"
)
SPEC = importlib.util.spec_from_file_location("native_axisymmetric_adapter_under_test", SOURCE)
assert SPEC is not None and SPEC.loader is not None
adapter = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = adapter
SPEC.loader.exec_module(adapter)
RUNNER_SPEC = importlib.util.spec_from_file_location(
    "freegs_axisymmetric_profile_runner_v2_under_test", RUNNER_SOURCE)
assert RUNNER_SPEC is not None and RUNNER_SPEC.loader is not None
runner = importlib.util.module_from_spec(RUNNER_SPEC)
sys.modules[RUNNER_SPEC.name] = runner
RUNNER_SPEC.loader.exec_module(runner)


class NativeAxisymmetricAdapterTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.series = adapter.load_native_axisymmetric_series()
        cls.snapshot = adapter.snapshot_native_axisymmetric(
            cls.series, 80, amc_max_delta_s=1.0e-6)

    def assertCode(self, code: str, function, *args, **kwargs) -> None:
        with self.assertRaises(adapter.SourceAdapterError) as caught:
            function(*args, **kwargs)
        self.assertEqual(caught.exception.code, code)

    def runnerWrapper(self, source_file: Path, source_payload: str) -> dict:
        return {
            "schema": runner.INPUT_SCHEMA,
            "revision": runner.REVISION,
            "context_hash": "1" * 64,
            "candidate_hash": "2" * 64,
            "compiled_prefix_hash": "3" * 64,
            "physical_subject_hash": "4" * 64,
            "scenario_hash": "5" * 64,
            "field_geometry_genome_hash": "6" * 64,
            "field_geometry_graph_hash": "7" * 64,
            "field_geometry_graph_binding_hash": "8" * 64,
            "binding_hash": "9" * 64,
            "declaration_hash": "a" * 64,
            "source_snapshot_file_sha256": hashlib.sha256(
                source_file.read_bytes()).hexdigest(),
            "source_snapshot_payload_sha256": source_payload,
            "controls": {
                "mode": "source_and_observed_dirichlet_fixed_boundary",
                "rtol": 1.0e-5,
                "atol": 1.0e-10,
                "max_iterations": 100,
                "blend": 0.0,
                "coordinate_transform": "linear_interp_source_r_to_uniform_solver_r",
                "machine": "explicit_empty_machine",
                "boundary": "observed_dirichlet_box_edges",
                "cocos_mapping": "identity_no_sign_or_2pi_transform",
                "cocos_scope": "gs_bp_subset_only_q_theta_not_consumed",
            },
        }

    def runValidationOnly(
        self, directory: Path, source_file: Path, source_payload: str,
        *, mutate_wrapper=None,
    ) -> tuple[subprocess.CompletedProcess[str], dict, Path]:
        wrapper = self.runnerWrapper(source_file, source_payload)
        if mutate_wrapper is not None:
            mutate_wrapper(wrapper)
        input_file = directory / "runner-input.json"
        output_file = directory / "runner-output.json"
        input_file.write_bytes(runner.canonical_bytes(wrapper) + b"\n")
        process = subprocess.run(
            [str(PINNED_PYTHON), str(RUNNER_SOURCE), "--input", str(input_file),
             "--source", str(source_file), "--output", str(output_file),
             "--validate-only"],
            text=True, capture_output=True, check=False,
        )
        return process, json.loads(output_file.read_text(encoding="utf-8")), input_file

    def test_01_real_compressed_to_canonical_series(self) -> None:
        receipt = adapter.validate_native_axisymmetric_series(self.series)
        self.assertEqual(receipt["array_count"], 48)
        self.assertEqual(receipt["psirz_finite_count"], 120 * 65 * 65)
        self.assertEqual(receipt["radial_support_count"], 65)
        self.assertEqual(receipt["gridr_max_abs_delta_from_r_m"], 2.0**-23)
        self.assertEqual(
            receipt["decoder_runtime"]["library_sha256"],
            adapter.EXPECTED_BLOSC_RUNTIME_SHA256,
        )
        self.assertEqual(receipt["decoder_runtime"]["path_basis"], "sys.base_prefix")
        self.assertFalse(receipt["likelihood_ready"])

    def test_02_full_120_by_65_support_and_exact_coordinate_binding(self) -> None:
        protocol = adapter._load_protocol()
        support = np.asarray(protocol["canonical_contract"]["radial_support_indices"])
        psi = self.series.arrays["efm/psirz"]
        mask = np.isfinite(psi)
        self.assertTrue(np.all(mask[:, :, support]))
        other = np.ones(129, dtype=bool)
        other[support] = False
        self.assertFalse(np.any(mask[:, :, other]))
        np.testing.assert_array_equal(
            self.series.arrays["efm/r"],
            self.series.arrays["efm/profile_r"][support])
        self.assertFalse(np.array_equal(
            self.series.arrays["efm/gridr"], self.series.arrays["efm/r"]))

    def test_03_raw_zr_to_canonical_rz_is_declared_transpose(self) -> None:
        protocol = adapter._load_protocol()
        support = np.asarray(protocol["canonical_contract"]["radial_support_indices"])
        expected = self.series.arrays["efm/psirz"][80, :, support].T.astype(np.float64)
        np.testing.assert_array_equal(self.snapshot.psi_wb_per_rad, expected)
        self.assertEqual(self.snapshot.psi_wb_per_rad.shape, (65, 65))

    def test_04_explicit_time_alignment_and_physical_units(self) -> None:
        receipt = adapter.validate_native_axisymmetric_snapshot(self.snapshot, self.series)
        self.assertEqual(receipt["efm_time_index"], 80)
        self.assertEqual(receipt["amc_time_index"], 11875)
        self.assertEqual(receipt["amc_signed_delta_s"], -2.384185791015625e-7)
        self.assertEqual(len(self.snapshot.internal_pf_currents_a_turn), 10)
        self.assertTrue(all(np.isfinite(v) for _, v in self.snapshot.internal_pf_currents_a_turn))

    def test_05_invalid_time_and_too_tight_alignment_fail(self) -> None:
        self.assertCode("native_snapshot_time_index_error",
                        adapter.snapshot_native_axisymmetric,
                        self.series, 10, amc_max_delta_s=1.0e-6)
        self.assertCode("native_amc_alignment_error",
                        adapter.snapshot_native_axisymmetric,
                        self.series, 80, amc_max_delta_s=1.0e-8)

    def test_06_protocol_rehash_rejects_policy_or_source_change(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "protocol.json"
            value = json.loads(adapter.DEFAULT_PROTOCOL.read_text(encoding="utf-8"))
            value["semantics"]["likelihood_ready"] = True
            path.write_text(json.dumps(value), encoding="utf-8")
            self.assertCode("native_protocol_hash_error", adapter._load_protocol, path)

    def test_07_raw_byte_tamper_is_rejected(self) -> None:
        source = ROOT / "benchmarks" / "reference_source_fields_v1" / "shot30421_native_coil_coords_r1"
        with tempfile.TemporaryDirectory() as directory:
            copy = Path(directory) / "supplement"
            shutil.copytree(source, copy)
            raw = copy / "fields" / "efm__r" / "assembled.raw"
            data = bytearray(raw.read_bytes())
            data[0] ^= 1
            raw.write_bytes(data)
            self.assertCode("native_assembled_raw_error",
                            adapter.load_native_axisymmetric_series,
                            supplement_root=copy)

    def test_08_compressed_chunk_tamper_is_rejected_before_use(self) -> None:
        source = ROOT / "benchmarks" / "reference_source_fields_v1" / "shot30421_native_coil_coords_r1"
        with tempfile.TemporaryDirectory() as directory:
            copy = Path(directory) / "supplement"
            shutil.copytree(source, copy)
            chunk = copy / "fields" / "efm__r" / "chunks" / "0.blosc"
            data = bytearray(chunk.read_bytes())
            data[-1] ^= 1
            chunk.write_bytes(data)
            self.assertCode("native_compressed_chunk_error",
                            adapter.load_native_axisymmetric_series,
                            supplement_root=copy)

    def test_09_metadata_unit_or_endian_drift_is_hash_bound(self) -> None:
        source = ROOT / "benchmarks" / "reference_source_fields_v1" / "shot30421_native_coil_coords_r1"
        with tempfile.TemporaryDirectory() as directory:
            copy = Path(directory) / "supplement"
            shutil.copytree(source, copy)
            acquisition = copy / "acquisition.json"
            value = json.loads(acquisition.read_text(encoding="utf-8"))
            value["arrays"][0]["dtype"] = ">f4"
            value["arrays"][0]["attributes"]["units"] = "A"
            acquisition.write_text(json.dumps(value), encoding="utf-8")
            self.assertCode("native_source_file_hash_error",
                            adapter.load_native_axisymmetric_series,
                            supplement_root=copy)

    def test_10_live_source_record_rehash_cannot_self_attest(self) -> None:
        records = list(self.series.source_records)
        records[0] = dataclasses.replace(records[0], dtype=">f4")
        records = tuple(records)
        binding = adapter._canonical_sha256({
            "protocol_sha256": self.series.protocol_sha256,
            "source_package_sha256": [list(x) for x in self.series.source_package_sha256],
            "source_records": [adapter._record_identity(x) for x in records],
        })
        provisional = dataclasses.replace(
            self.series, source_records=records, source_binding_sha256=binding,
            series_payload_sha256="")
        forged = dataclasses.replace(
            provisional,
            series_payload_sha256=adapter._canonical_sha256(adapter._series_body(provisional)))
        self.assertCode("native_series_live_source_binding_error",
                        adapter.validate_native_axisymmetric_series, forged)

    def test_11_live_array_bytes_cannot_be_rehashed_as_source(self) -> None:
        arrays = dict(self.series.arrays)
        changed = np.array(arrays["efm/r"], copy=True)
        changed[0] = np.nextafter(changed[0], np.float32(np.inf))
        changed.setflags(write=False)
        arrays["efm/r"] = changed
        forged = dataclasses.replace(self.series, arrays=MappingProxyType(arrays))
        self.assertCode("native_series_live_source_binding_error",
                        adapter.validate_native_axisymmetric_series, forged)

    def test_12_snapshot_value_rehash_cannot_escape_source_rederivation(self) -> None:
        changed = np.array(self.snapshot.psi_wb_per_rad, copy=True)
        changed[1, 1] += 1.0e-6
        changed.setflags(write=False)
        provisional = dataclasses.replace(
            self.snapshot, psi_wb_per_rad=changed, snapshot_payload_sha256="")
        forged = dataclasses.replace(
            provisional,
            snapshot_payload_sha256=adapter._canonical_sha256(
                adapter._snapshot_body(provisional)))
        self.assertCode("native_snapshot_live_source_binding_error",
                        adapter.validate_native_axisymmetric_snapshot,
                        forged, self.series)

    def test_13_readiness_and_claim_forgery_fail_closed(self) -> None:
        forged = dataclasses.replace(
            self.snapshot, likelihood_ready=True,
            claim_ceiling="formal inverse and likelihood ready")
        self.assertCode("native_snapshot_metadata_error",
                        adapter.validate_native_axisymmetric_snapshot,
                        forged, self.series)
        self.assertCode("native_likelihood_not_ready",
                        adapter.require_native_likelihood_ready, self.snapshot)

    def test_14_writer_hashes_exact_bytes_and_preserves_absent_geometry(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "snapshot.json"
            receipt = adapter.write_native_axisymmetric_snapshot(
                self.snapshot, self.series, output)
            raw = output.read_bytes()
            self.assertEqual(receipt["output_bytes"], len(raw))
            self.assertEqual(receipt["output_sha256"], hashlib.sha256(raw).hexdigest())
            value = json.loads(raw)
            self.assertEqual(
                value["coil_geometry_status"],
                "typed_absent_from_bound_source_protocol",
            )
            self.assertEqual(
                value["cocos_consumed_subset"]["mapping"],
                "identity_no_sign_or_2pi_transform",
            )
            self.assertEqual(
                value["cocos_consumed_subset"]["q_theta_status"],
                "not_consumed_not_verified",
            )
            self.assertFalse(value["likelihood_ready"])

    def test_15_runner_validate_only_binds_input_cocos_and_scope(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "snapshot.json"
            adapter.write_native_axisymmetric_snapshot(
                self.snapshot, self.series, source)
            process, value, input_file = self.runValidationOnly(
                root, source, self.snapshot.snapshot_payload_sha256)
            self.assertEqual(process.returncode, 0, process.stdout + process.stderr)
            self.assertEqual(value["status"], "validated_input_no_solve")
            self.assertEqual(
                value["semantic_input_sha256"],
                hashlib.sha256(input_file.read_bytes()).hexdigest(),
            )
            self.assertEqual(
                value["cocos_consumed_subset"]["mapping"],
                "identity_no_sign_or_2pi_transform",
            )
            self.assertEqual(
                value["claim_boundary"]["executable_source_scope"],
                "G2_profile_fixed_boundary",
            )
            self.assertFalse(value["claim_boundary"]["reference_inversion_G1_G2_G3"])
            self.assertFalse(value["claim_boundary"]["solve_attempted"])

    def test_16_runner_rejects_rehashed_cocos_forgery_before_solve(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "snapshot.json"
            adapter.write_native_axisymmetric_snapshot(
                self.snapshot, self.series, source)
            value = json.loads(source.read_text(encoding="utf-8"))
            value["cocos_consumed_subset"]["mapping"] = "forged_sign_flip"
            body = dict(value)
            body.pop("snapshot_payload_sha256")
            value["snapshot_payload_sha256"] = runner.canonical_hash(body)
            source.write_text(
                json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + "\n",
                encoding="utf-8",
            )
            process, failure, _ = self.runValidationOnly(
                root, source, value["snapshot_payload_sha256"])
            self.assertEqual(process.returncode, 2)
            self.assertEqual(failure["status"], "input_validation_failed")
            self.assertEqual(failure["phase"], "source_validation")
            self.assertFalse(failure["claim_boundary"]["solve_attempted"])
            self.assertIn("COCOS consumed-subset contract differs", failure["message"])

    def test_17_runner_has_finite_nonconvergence_and_program_classification(self) -> None:
        numerical = {
            "phase": "numerical_solve", "solve_attempted": True,
        }
        self.assertEqual(
            runner.classify_failure(
                RuntimeError(runner.PICARD_NONCONVERGENCE_MESSAGE), numerical),
            ("numerical_fail_nonconvergence", 4),
        )
        self.assertEqual(
            runner.classify_failure(RuntimeError("unexpected"), numerical),
            ("program_exception", 5),
        )

    def test_18_decoder_runtime_resolves_exact_base_prefix_bytes(self) -> None:
        identity = adapter._resolve_verified_blosc_runtime(adapter._load_protocol())
        expected = (
            Path(sys.base_prefix).resolve()
            / "Library" / "bin" / "blosc.dll"
        ).resolve()
        self.assertEqual(Path(identity.library_path), expected)
        self.assertEqual(identity.library_sha256, adapter.EXPECTED_BLOSC_RUNTIME_SHA256)
        self.assertEqual(identity.path_basis, "sys.base_prefix")
        self.assertEqual(identity.python_executable, str(Path(sys.executable).resolve()))

    def test_19_decoder_runtime_missing_or_hash_drift_fails_before_decode(self) -> None:
        protocol = adapter._load_protocol()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            kwargs = {
                "executable": Path(sys.executable),
                "prefix": root,
                "base_prefix": root,
            }
            self.assertCode(
                "native_blosc_runtime_missing",
                adapter._resolve_verified_blosc_runtime,
                protocol,
                **kwargs,
            )
            library = root / "Library" / "bin" / "blosc.dll"
            library.parent.mkdir(parents=True)
            library.write_bytes(b"not-the-pinned-runtime")
            self.assertCode(
                "native_blosc_runtime_hash_error",
                adapter._resolve_verified_blosc_runtime,
                protocol,
                **kwargs,
            )

    def test_20_pinned_venv_executes_real_decode_through_base_runtime(self) -> None:
        process = subprocess.run(
            [str(PINNED_PYTHON), str(SOURCE), "verify"],
            text=True, capture_output=True, check=False,
        )
        self.assertEqual(process.returncode, 0, process.stdout + process.stderr)
        value = json.loads(process.stdout)
        runtime = value["decoder_runtime"]
        self.assertEqual(runtime["python_executable"], str(PINNED_PYTHON.resolve()))
        self.assertTrue(runtime["base_prefix_differs_from_prefix"])
        self.assertEqual(
            runtime["library_path"],
            str((Path(runtime["sys_base_prefix"]) / "Library" / "bin" / "blosc.dll").resolve()),
        )
        self.assertEqual(runtime["library_sha256"], adapter.EXPECTED_BLOSC_RUNTIME_SHA256)

    def test_21_julia_declaration_normalizes_before_canonical_guard(self) -> None:
        source = (
            ROOT / "src" / "RuntimeV4" /
            "FreeGSAxisymmetricProfileExecutionV2.jl"
        ).read_text(encoding="utf-8")
        fixture = (
            ROOT / "examples" /
            "runtime_v4_freegs_axisymmetric_profile_execution_v2.jl"
        ).read_text(encoding="utf-8")
        julia_test = (
            ROOT / "test" /
            "runtime_v4_freegs_axisymmetric_profile_execution_v2_tests.jl"
        ).read_text(encoding="utf-8")
        self.assertIn("result = String(strip(String(value)))", source)
        self.assertIn("first_legacy_noncanonical_path", source)
        observation_index = fixture.index(
            "NATIVE_GS_DECLARATION_CANONICAL_OBSERVATION=")
        constructor_index = fixture.index(
            "declaration = F.GenericAxisymmetricProfileDeclarationV2")
        self.assertLess(observation_index, constructor_index)
        self.assertIn(
            'observation.first_legacy_noncanonical_path == "\\$.declaration_id"',
            julia_test,
        )

    def test_22_trace_payload_preserves_exact_finite_and_nonfinite_bytes(self) -> None:
        values = np.asarray([[1.0, np.nan], [np.inf, -2.0]], dtype=np.float64)
        payload = runner._trace_float64_payload(values, np)
        raw = base64.b64decode(payload["values_base64"])
        self.assertEqual(payload["encoding_dtype"], "<f8")
        self.assertEqual(payload["finite_count"], 2)
        self.assertEqual(payload["total_count"], 4)
        self.assertEqual(hashlib.sha256(raw).hexdigest(), payload["values_sha256"])
        decoded = np.frombuffer(raw, dtype="<f8").reshape(2, 2)
        np.testing.assert_array_equal(decoded, values)
        json.dumps(payload, allow_nan=False)

    def test_23_bound_equilibrium_observer_records_actual_calls_and_restores(self) -> None:
        def find_critical(_r, _z, psi):
            array = np.asarray(psi, dtype=float)
            return [(0.5, 0.0, float(np.min(array)))], []

        def core_mask(_r, _z, psi, _opt, _xpt, _psi_bndry=None):
            return np.ones_like(np.asarray(psi), dtype=bool)

        critical = SimpleNamespace(
            find_critical=find_critical,
            core_mask=core_mask,
        )

        class FakeProfiles:
            def pprime(self, normalized):
                return np.ones_like(normalized)

            def ffprime(self, normalized):
                return np.zeros_like(normalized)

            def Jtor(self, r, z, psi, psi_bndry=None):
                opt, xpt = critical.find_critical(r, z, psi)
                self.psi_axis = opt[0][2]
                self.psi_bndry = float(psi_bndry)
                normalized = np.clip(
                    (psi - self.psi_axis) / (self.psi_bndry - self.psi_axis),
                    0.0, 1.0,
                )
                result = r * self.pprime(normalized)
                return result * critical.core_mask(
                    r, z, psi, opt, xpt, self.psi_bndry)

        class FakeEquilibrium:
            def __init__(self, initial):
                axis = np.linspace(1.0, 2.0, initial.shape[0])
                self.R, self.Z = np.meshgrid(axis, axis, indexing="ij")
                self._psi = np.asarray(initial, dtype=float).copy()
                self.psi_axis = float(np.min(initial))
                self.psi_bndry = 1.0
                self.mask = None
                self.Jtor = None

            def psi(self):
                return self._psi

            def solve(self, profiles, Jtor=None, psi=None, psi_bndry=None):
                self.Jtor = (
                    profiles.Jtor(self.R, self.Z, psi, psi_bndry=psi_bndry)
                    if Jtor is None else Jtor)
                self.mask = critical.core_mask(
                    self.R, self.Z, psi,
                    *critical.find_critical(self.R, self.Z, psi),
                    psi_bndry,
                )
                self._psi = np.asarray(psi, dtype=float).copy()
                self._psi[1:-1, 1:-1] += 0.125
                self.psi_axis = float(np.min(self._psi))
                self.psi_bndry = float(psi_bndry)

        initial = np.zeros((5, 5), dtype=float)
        initial[1:-1, 1:-1] = np.linspace(0.1, 0.9, 9).reshape(3, 3)
        boundaries = {
            "r_min": initial[0, :].copy(), "r_max": initial[-1, :].copy(),
            "z_min": initial[:, 0].copy(), "z_max": initial[:, -1].copy(),
        }
        eq = FakeEquilibrium(initial)
        profiles = FakeProfiles()
        original_eq_function = eq.solve.__func__
        original_profile_function = profiles.Jtor.__func__
        original_find = critical.find_critical
        original_mask = critical.core_mask
        observer = runner.EquilibriumSolveObserver(
            eq=eq, profiles=profiles, critical_module=critical,
            boundary_edges=boundaries, mu_0=1.0, np=np,
        )
        with observer:
            eq.solve(profiles, psi=initial.copy(), psi_bndry=1.0)
        report = observer.report(formal_solve_returned=False)
        self.assertEqual(report["actual_eq_solve_call_count"], 1)
        self.assertFalse(report["iteration_count_claimed"])
        self.assertTrue(report["original_callables_restored"])
        call = report["calls"][0]
        self.assertTrue(call["call_completed"])
        self.assertEqual(len(call["profile_jtor_calls"]), 1)
        self.assertEqual(
            call["profile_jtor_calls"][0]["jtor_reconstruction"]["mask_source"],
            "actual_intercepted_profile_core_mask_return",
        )
        self.assertTrue(
            call["profile_jtor_calls"][0]["jtor_reconstruction"]["bit_exact"])
        self.assertEqual(
            call["profile_jtor_calls"][0]["jtor_reconstruction"]
            ["actual_critical_call_indices"],
            [1],
        )
        self.assertEqual(
            call["profile_jtor_calls"][0]["jtor_reconstruction"]
            ["actual_core_mask_call_indices"],
            [1],
        )
        self.assertTrue(call["eq_jtor_matches_last_profile_return"])
        mask_payload = call["core_mask_calls"][0]["returned_mask"]
        source_mask_raw = base64.b64decode(mask_payload["source_values_base64"])
        self.assertEqual(
            hashlib.sha256(source_mask_raw).hexdigest(),
            mask_payload["source_values_sha256"],
        )
        self.assertGreaterEqual(len(call["critical_calls"]), 2)
        self.assertGreaterEqual(len(call["core_mask_calls"]), 2)
        self.assertIs(eq.solve.__func__, original_eq_function)
        self.assertIs(profiles.Jtor.__func__, original_profile_function)
        self.assertIs(critical.find_critical, original_find)
        self.assertIs(critical.core_mask, original_mask)
        self.assertNotIn("solve", eq.__dict__)
        self.assertNotIn("Jtor", profiles.__dict__)
        json.dumps(report, allow_nan=False)

    def test_24_observer_retains_exception_and_restores_original_callables(self) -> None:
        class FailingEq:
            def __init__(self):
                self._psi = np.zeros((3, 3), dtype=float)
                self.Jtor = None
                self.mask = None

            def psi(self):
                return self._psi

            def solve(self, _profiles, **_kwargs):
                raise RuntimeError("deliberate fake linear failure")

        class Profiles:
            def Jtor(self, *_args, **_kwargs):
                raise AssertionError("profile should not be called")

        critical = SimpleNamespace(
            find_critical=lambda *_args, **_kwargs: ([], []),
            core_mask=lambda *_args, **_kwargs: np.ones((3, 3), dtype=bool),
        )
        eq = FailingEq()
        profiles = Profiles()
        observer = runner.EquilibriumSolveObserver(
            eq=eq, profiles=profiles, critical_module=critical,
            boundary_edges={
                "r_min": np.zeros(3), "r_max": np.zeros(3),
                "z_min": np.zeros(3), "z_max": np.zeros(3),
            },
            mu_0=1.0, np=np,
        )
        with self.assertRaisesRegex(RuntimeError, "deliberate fake linear failure"):
            with observer:
                eq.solve(profiles, psi=np.zeros((3, 3)), psi_bndry=0.0)
        report = observer.report(formal_solve_returned=False)
        self.assertEqual(report["actual_eq_solve_call_count"], 1)
        self.assertFalse(report["calls"][0]["call_completed"])
        self.assertEqual(
            report["calls"][0]["exception"]["message"],
            "deliberate fake linear failure",
        )
        self.assertTrue(report["original_callables_restored"])
        self.assertNotIn("solve", eq.__dict__)
        self.assertNotIn("Jtor", profiles.__dict__)

    def test_25_formal_solver_controls_unchanged_and_diagnostic_is_separate(self) -> None:
        source = RUNNER_SOURCE.read_text(encoding="utf-8")
        self.assertIn("with observer:\n                max_change, relative_change = freegs.solve(", source)
        self.assertIn('rtol=float(controls["rtol"])', source)
        self.assertIn('atol=float(controls["atol"])', source)
        self.assertIn('blend=float(controls["blend"])', source)
        self.assertIn('maxits=int(controls["max_iterations"])', source)
        self.assertIn("convergenceInfo=True, check_limited=False", source)
        self.assertIn('"formal_solve_replacement": False', source)
        self.assertIn('"changes_to_formal_equilibrium": False', source)
        self.assertNotIn("iteration = len(self.calls)", source)


if __name__ == "__main__":
    unittest.main()
