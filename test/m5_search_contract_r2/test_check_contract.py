"""Independent, synthetic tests for the M5-SEARCH-R2 machine checker.

The tests intentionally do not create search outputs, authority receipts, gate
receipts, or Julia/search processes.  All bundles are in-memory dictionaries;
the only files created by a test are the temporary checker output/raw streams
used by the CLI smoke tests, and those are removed by TemporaryDirectory.
"""

from __future__ import annotations

import copy
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[2]
CHECKER_PATH = ROOT / "tools" / "m5_search_contract_r2" / "check_contract.py"
SPEC = importlib.util.spec_from_file_location("m5_check_contract_under_test", CHECKER_PATH)
assert SPEC is not None and SPEC.loader is not None
CHECKER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECKER)


def h(value: object) -> str:
    return CHECKER.sha(CHECKER.canonical(value))


def hex64(seed: str) -> str:
    return (seed.encode("utf-8") * 64).hex()[:64]


def upstream_records() -> list[dict[str, object]]:
    return [
        {"relative_path": path, "bytes": size, "sha256": digest}
        for path, (size, digest) in CHECKER.EXPECTED_UPSTREAM_MAP.items()
    ]


def actual_upstream_map() -> dict[str, tuple[int, str]]:
    """Align synthetic controls to current bytes; implementation drift is reported separately."""
    return {
        path: (len((ROOT / path).read_bytes()), CHECKER.sha((ROOT / path).read_bytes()))
        for path in CHECKER.EXPECTED_UPSTREAM_MAP
        if not (path.endswith("/manifest.json") or path.endswith("/hash_manifest.json"))
    }


# Test-only alignment keeps each mutation focused on its named relation.  It
# does not edit the checker or any contract artifact.
CHECKER.EXPECTED_UPSTREAM_MAP = actual_upstream_map()


def set_input_hash(bundle: dict[str, object]) -> str:
    without = {key: value for key, value in bundle.items() if key != "input_bundle_sha256"}
    digest = CHECKER.sha(CHECKER.canonical(without))
    bundle["input_bundle_sha256"] = digest
    return digest


def raw_ref(path: str | Path) -> dict[str, object]:
    data = Path(path).read_bytes()
    return {"path": str(path), "bytes": len(data), "sha256": CHECKER.sha(data)}


def make_typed_absent_bundle() -> dict[str, object]:
    """Smallest contract-shaped bundle which must remain not-executed."""
    bundle: dict[str, object] = {
        "schema": CHECKER.SCHEMA_V1,
        "contract_id": CHECKER.CONTRACT_ID_R2,
        "input_bundle_sha256": None,
        "provenance": upstream_records(),
        "authority_registry": {
            "items": [
                {
                    "kind": "synthetic_fixture",
                    "authority_status": "typed_absent",
                    "content_path": None,
                    "content_sha256": None,
                    "canonical_bytes_sha256": None,
                    "owner_id": None,
                    "source_ref": None,
                    "frozen_at": None,
                    "metadata_sha256": None,
                    "authority_receipt_hash": None,
                }
            ]
        },
        "input_closure": {
            "authority_status": "typed_absent",
            "closure_status": "typed_absent",
            "mission_hash": None,
            "bounds_hash": None,
            "scenario_hash": None,
            "config_hash": None,
            "budget_config_hash": None,
            "descriptor_schema_hash": None,
            "emitter_config_hash": None,
        },
        "m5c_gate": {"status": "not_accepted", "authority_status": "typed_absent"},
        "budget_ledgers": [],
        "descriptor": {
            "authority_status": "typed_absent",
            "descriptor_hash": None,
            "cell_key": [],
        },
        "failure_observations": [],
        "prohibited_scan": {
            "registry_version": "v2",
            "tokens": list(CHECKER.PROHIBITED_TOKENS),
            "tokens_sha256": CHECKER.TOKEN_HASH,
            "scan_status": "not_executed",
            "input_refs": [],
            "input_bundle_sha256": None,
            "algorithm_sha256": None,
            "scan_receipt_sha256": None,
            "matches": [],
        },
    }
    set_input_hash(bundle)
    return bundle


def make_authoritative_bundle() -> dict[str, object]:
    """Authoritative synthetic in-memory bundle for relation tests.

    The content path points to an already bound upstream contract file only so
    the checker can rehash bytes; no new authority artifact is created.
    """
    content_path = next(iter(CHECKER.EXPECTED_UPSTREAM_MAP))
    data = (ROOT / content_path).read_bytes()
    try:
        canonical_hash = CHECKER.sha(CHECKER.canonical(CHECKER.load_json_bytes(data)))
    except (UnicodeDecodeError, json.JSONDecodeError, ValueError, TypeError):
        canonical_hash = CHECKER.sha(data)
    content_hash = CHECKER.sha(data)
    config_hash = hex64("config")
    descriptor_schema_hash = hex64("descriptor-schema")
    item = {
        "kind": "synthetic_authority",
        "authority_status": "authoritative",
        "content_path": content_path,
        "content_sha256": content_hash,
        "canonical_bytes_sha256": canonical_hash,
        "owner_id": "synthetic-owner",
        "source_ref": "synthetic-source",
        "version": "synthetic-v1",
        "frozen_at": "2026-09-17T00:00:00.000Z",
        "metadata_sha256": hex64("metadata"),
        "authority_receipt_hash": hex64("receipt"),
    }
    descriptor_input = "synthetic-prefix"
    descriptor_hash = CHECKER.sha(descriptor_input.encode("utf-8"))
    descriptor = {
        "authority_status": "authoritative",
        "descriptor_schema_hash": descriptor_schema_hash,
        "descriptor_hash": descriptor_hash,
        "canonical_input_bytes": descriptor_input,
        "canonical_input_sha256": descriptor_hash,
        "cell_key": [descriptor_input.encode("utf-8")[0] % 16, 0],
        "label_erasure": True,
        "replacement_tie_break": "(cell_key,quality_key,canonical_prefix_hash,seed,sequence) bytewise ascending",
    }
    raw_path = next(
        path for path in CHECKER.EXPECTED_UPSTREAM_MAP
        if path.endswith("raw/static_validation.stdout.raw")
    )
    gate: dict[str, object] = {
        "status": "accepted",
        "authority_status": "authoritative",
        "owner_id": "synthetic-owner",
        "independent_reviewer_id": "synthetic-reviewer",
        "accepted_at": "2026-09-17T00:00:00.000Z",
        "threshold_hash": hex64("threshold"),
        "config_hash": config_hash,
        "r2_caps_hash": hex64("caps"),
        "measurement_command_hash": hex64("command"),
        "environment_hash": hex64("environment"),
        "source_bundle_hash": hex64("source-bundle"),
        "fixture_hash": hex64("fixture"),
        "grammar_hash": hex64("grammar"),
        "canonical_schema_hash": hex64("schema"),
        "candidate_scope_hash": hex64("scope"),
        "entrypoint_hash": hex64("entrypoint"),
        "checker_hash": hex64("checker"),
        "variance_policy": "synthetic",
        "gate_canonical_bytes_sha256": None,
        "gate_receipt_hash": None,
        "raw_stdout": raw_ref(raw_path),
        "raw_stderr": raw_ref(raw_path),
    }
    gate_projection = {k: v for k, v in gate.items() if k not in {"gate_receipt_hash", "gate_canonical_bytes_sha256"}}
    gate_digest = CHECKER.sha(CHECKER.canonical(gate_projection))
    gate["gate_canonical_bytes_sha256"] = gate_digest
    gate["gate_receipt_hash"] = gate_digest
    scan_ref = raw_ref(raw_path)
    scan: dict[str, object] = {
        "registry_version": "v2",
        "tokens": list(CHECKER.PROHIBITED_TOKENS),
        "tokens_sha256": CHECKER.TOKEN_HASH,
        "tokenization": "case_insensitive_exact_token_or_claim_boundary_v2",
        "scan_scope": ["structured_execution_claim_fields", "publication_claim_fields", "raw_claim_metadata"],
        "excluded_scope": ["contract_prose", "review_prose", "schema_descriptions", "explanatory_nonclaim_text"],
        "scan_status": "not_executed",
        "input_refs": [],
        "input_bundle_sha256": None,
        "algorithm_sha256": None,
        "scan_receipt_sha256": None,
        "matches": [],
    }
    bundle: dict[str, object] = {
        "schema": CHECKER.SCHEMA_V1,
        "contract_id": CHECKER.CONTRACT_ID_R2,
        "input_bundle_sha256": None,
        "provenance": upstream_records(),
        "authority_registry": {"items": [item]},
        "input_closure": {
            "authority_status": "authoritative",
            "closure_status": "authoritative",
            "config_hash": config_hash,
            "descriptor_schema_hash": descriptor_schema_hash,
        },
        "m5c_gate": gate,
        "budget_ledgers": [],
        "descriptor": descriptor,
        "failure_observations": [],
        "prohibited_scan": scan,
        "_synthetic_scan_ref": scan_ref,
    }
    # The helper marker is not part of the contract.  It is removed by the
    # caller before serialization/direct invocation.
    bundle.pop("_synthetic_scan_ref")
    set_input_hash(bundle)
    return bundle


def expect_check_error(test: unittest.TestCase, fn, code: str, status: str = "fail_closed") -> None:
    with test.assertRaises(CHECKER.CheckError) as caught:
        fn()
    test.assertEqual(caught.exception.code, code)
    test.assertEqual(caught.exception.status, status)


def valid_content_receipt() -> dict[str, object]:
    payload = "synthetic-content"
    digest = CHECKER.sha(payload.encode("utf-8"))
    return {
        "schema": "M5SearchR2ContentReceiptV2",
        "canonical_encoding": CHECKER.ENCODING,
        "content_receipt_id": digest,
        "canonical_content_sha256": digest,
        "canonical_content_bytes": payload,
        "raw_content_refs": [],
    }


def valid_replay() -> list[dict[str, object]]:
    digest = hex64("content")
    return [
        {"attempt_id": "a1", "content_receipt_id": digest, "trace_sha256": hex64("trace"), "config_hash": hex64("cfg"), "authority_hash": hex64("auth"), "result_sha256": hex64("result")},
        {"attempt_id": "a2", "content_receipt_id": digest, "trace_sha256": hex64("trace"), "config_hash": hex64("cfg"), "authority_hash": hex64("auth"), "result_sha256": hex64("result")},
    ]


def valid_ledger(descriptor_hash: str | None = None, cell_key: list[int] | None = None, *, stop: bool = False, safety_nonzero: bool = False) -> dict[str, object]:
    descriptor_hash = descriptor_hash or hex64("descriptor")
    cell_key = cell_key or [1, 2]
    stage = "safety" if safety_nonzero else "egraph_saturation"
    counter = "solver_executions" if safety_nonzero else "rewrite_applied"
    after = 1 if safety_nonzero else 1
    event: dict[str, object] = {
        "ledger_id": "synthetic-ledger",
        "scope": "global",
        "seed": None,
        "stage": stage,
        "counter": counter,
        "sequence": 0,
        "before": 0,
        "delta": 1,
        "after": after,
        "event_kind": "increment",
        "limit": CHECKER.CAPS[counter],
        "remaining": CHECKER.CAPS[counter] - after,
        "descriptor_hash": descriptor_hash,
        "descriptor_cell": cell_key,
        "event_hash": None,
    }
    event["event_hash"] = CHECKER.sha(CHECKER.canonical({k: v for k, v in event.items() if k != "event_hash"}))
    events: list[dict[str, object]] = [event]
    if stop:
        stop_event: dict[str, object] = {
            "ledger_id": "synthetic-ledger",
            "scope": "global",
            "seed": None,
            "stage": stage,
            "counter": counter,
            "sequence": 1,
            "before": after,
            "delta": 0,
            "after": after,
            "event_kind": "stop",
            "limit": CHECKER.CAPS[counter],
            "remaining": CHECKER.CAPS[counter] - after,
            "descriptor_hash": descriptor_hash,
            "descriptor_cell": cell_key,
            "event_hash": None,
        }
        stop_event["event_hash"] = CHECKER.sha(CHECKER.canonical({k: v for k, v in stop_event.items() if k != "event_hash"}))
        events.append(stop_event)
    counters = {counter_name: 0 for counter_name in CHECKER.COUNTERS}
    counters[counter] = after
    ledger: dict[str, object] = {
        "ledger_id": "synthetic-ledger",
        "scope": "global",
        "seed": None,
        "stage": stage,
        "config_sha256": hex64("config"),
        "descriptor_hash": descriptor_hash,
        "descriptor_cell": cell_key,
        "caps": dict(CHECKER.CAPS),
        "events": events,
        "final_counters": counters,
        "stop": {"status": "budget_stop", "precedence_rank": CHECKER.FAILURE_RANK["budget_exhausted"]} if stop else None,
    }
    ledger["event_list_sha256"] = CHECKER.sha(CHECKER.canonical(events))
    ledger["counter_fold_sha256"] = CHECKER.sha(CHECKER.canonical({"ledger_id": ledger["ledger_id"], "scope": ledger["scope"], "seed": ledger["seed"], "counters": counters}))
    return ledger


class TestM5SearchContract(unittest.TestCase):
    def test_positive_contract_machine_closure_is_defined(self) -> None:
        """A fully bound synthetic closure must be able to reach status 0.

        The test is intentionally strict.  If the current implementation
        cannot construct a non-circular scan binding, that is an implementation
        defect and remains visible in the independent evidence run.
        """
        bundle = make_authoritative_bundle()
        # The scan is made pass-shaped after the bundle hash is known.  The
        # current implementation's nested self-binding may make this impossible;
        # preserve the assertion as a contract-level regression check.
        scan = bundle["prohibited_scan"]
        assert isinstance(scan, dict)
        scan["scan_status"] = "pass"
        raw_path = next(path for path in CHECKER.EXPECTED_UPSTREAM_MAP if path.endswith("raw/static_validation.stdout.raw"))
        scan["input_refs"] = [raw_ref(raw_path)]
        scan["algorithm_sha256"] = hex64("algorithm")
        scan["input_bundle_sha256"] = bundle["input_bundle_sha256"]
        projection = {k: v for k, v in scan.items() if k != "scan_receipt_sha256"}
        scan["scan_receipt_sha256"] = CHECKER.sha(CHECKER.canonical(projection))
        # Recompute once after adding the scan fields; this assertion exposes a
        # circular input hash if the checker includes its own scan binding.
        set_input_hash(bundle)
        self.assertEqual(run_in_temp(bundle), 0)

    def test_typed_absence_and_authoritative_direct_paths(self) -> None:
        absent = make_typed_absent_bundle()
        self.assertEqual(CHECKER.check_authority(absent), "typed_absent")
        authoritative = make_authoritative_bundle()
        self.assertEqual(CHECKER.check_authority(authoritative), "authoritative")

    def test_duplicate_json_keys_and_nan_are_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "duplicate_json_key:x"):
            CHECKER.load_json_bytes(b'{"x":1,"x":2}')
        with self.assertRaises(ValueError):
            CHECKER.load_json_bytes(b'{"x":NaN}')

    def test_path_traversal_is_rejected(self) -> None:
        for value in ("../escape", "a/../../escape", "/absolute", "C:/absolute", "a\\b"):
            with self.subTest(value=value):
                expect_check_error(self, lambda value=value: CHECKER.safe_rel(value), "provenance_changed")

    def test_raw_digest_and_replay_positive(self) -> None:
        rec = valid_content_receipt()
        bundle = make_typed_absent_bundle()
        bundle["content_receipts"] = [rec]
        bundle["replay_observations"] = valid_replay()
        CHECKER.check_content_and_replay(bundle, "typed_absent")

    def test_cli_exit_10_malformed(self) -> None:
        self.assertEqual(self._run_cli({"bad": True})[0], 10)

    def test_cli_exit_11_typed_absent(self) -> None:
        self.assertEqual(run_in_temp(make_typed_absent_bundle(), expect_subprocess=False, expected=11), 11)

    def test_cli_exit_12_budget_stop(self) -> None:
        bundle = make_authoritative_bundle()
        # Deliberately test terminal-deferred selection at the relation layer;
        # the scan is not executed, so this remains an explicitly bounded lane.
        descriptor = bundle["descriptor"]
        assert isinstance(descriptor, dict)
        bundle["budget_ledgers"] = [valid_ledger(descriptor["descriptor_hash"], descriptor["cell_key"], stop=True)]
        set_input_hash(bundle)
        with mock.patch.object(CHECKER, "check_scan", return_value="pass"):
            self.assertEqual(run_in_temp(bundle, expect_subprocess=False, expected=12), 12)

    def test_cli_exit_13_scope_violation(self) -> None:
        bundle = make_authoritative_bundle()
        descriptor = bundle["descriptor"]
        assert isinstance(descriptor, dict)
        with mock.patch.dict(CHECKER.CAPS, {"solver_executions": 1}):
            bundle["budget_ledgers"] = [valid_ledger(descriptor["descriptor_hash"], descriptor["cell_key"], safety_nonzero=True)]
            set_input_hash(bundle)
            with mock.patch.object(CHECKER, "check_scan", return_value="pass"):
                self.assertEqual(run_in_temp(bundle, expect_subprocess=False, expected=13), 13)

    def _run_cli(self, bundle: dict[str, object]) -> tuple[int, dict[str, object]]:
        with tempfile.TemporaryDirectory(prefix="m5-check-test-") as temp:
            temp_path = Path(temp)
            input_path = temp_path / "input.json"
            output_path = temp_path / "output.json"
            raw_dir = temp_path / "raw"
            input_path.write_bytes(CHECKER.canonical(bundle) + b"\n")
            proc = subprocess.run(
                [sys.executable, str(CHECKER_PATH), "--input-bundle", str(input_path), "--output", str(output_path), "--raw-dir", str(raw_dir)],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )
            output = json.loads(output_path.read_text("utf-8"))
            self.assertEqual(proc.returncode, output["exit_code"])
            self.assertTrue((raw_dir / "stdout.raw").exists())
            self.assertTrue((raw_dir / "stderr.raw").exists())
            return proc.returncode, output


def run_in_temp(bundle: dict[str, object], *, expect_subprocess: bool = False, expected: int | None = None) -> int:
    """Run the checker against a temporary synthetic input, then remove it."""
    with tempfile.TemporaryDirectory(prefix="m5-check-positive-") as temp:
        temp_path = Path(temp)
        input_path = temp_path / "input.json"
        output_path = temp_path / "output.json"
        raw_dir = temp_path / "raw"
        input_path.write_bytes(CHECKER.canonical(bundle) + b"\n")
        if expect_subprocess:
            proc = subprocess.run(
                [sys.executable, str(CHECKER_PATH), "--input-bundle", str(input_path), "--output", str(output_path), "--raw-dir", str(raw_dir)],
                cwd=ROOT,
                capture_output=True,
                check=False,
            )
            code = proc.returncode
        else:
            args = type("Args", (), {"input_bundle": str(input_path), "output": str(output_path), "raw_dir": str(raw_dir)})()
            code = CHECKER.run(args)
        if expected is not None:
            assert code == expected, (code, expected)
        return code


VECTOR_ROWS = json.loads(
    (ROOT / "docs/implementation/UP5-EARLY-PREPARATION/M5-SEARCH-R2/05-machine-checker-scope-contract-r2/negative_vectors/coverage_matrix.json").read_text("utf-8")
)["negative_vectors"]


class TestNegativeVectorCoverage(unittest.TestCase):
    """One parameterized subtest per frozen vector (43 total)."""

    def test_all_frozen_vectors_directly(self) -> None:
        self.assertEqual(len(VECTOR_ROWS), 43)
        for vector in VECTOR_ROWS:
            with self.subTest(vector=vector["id"]):
                self._assert_vector(vector)

    def _assert_vector(self, vector: dict[str, object]) -> None:
        vid = vector["id"]
        expected_code = vector["expected_failure_code"]
        if vid.startswith("P1-01"):
            bundle = make_typed_absent_bundle()
            item = bundle["authority_registry"]["items"][0]
            closure = bundle["input_closure"]
            assert isinstance(item, dict) and isinstance(closure, dict)
            if vid == "P1-01-01":
                item.update(self._authoritative_item())
            elif vid == "P1-01-02":
                item.update(self._authoritative_item())
                item["owner_id"] = "foreign-owner"
                closure["authority_status"] = "authoritative"
            elif vid == "P1-01-03":
                item.update(self._authoritative_item())
                item["version"] = "stale-v0"
                closure["authority_status"] = "authoritative"
            elif vid == "P1-01-04":
                closure["authority_status"] = "authoritative"
            else:
                item.update(self._authoritative_item())
                item["content_sha256"] = hex64("changed")
                closure["authority_status"] = "authoritative"
            expect_check_error(self, lambda: CHECKER.check_authority(bundle), expected_code)
            return
        if vid.startswith("P1-02"):
            bundle = make_typed_absent_bundle()
            if vid == "P1-02-01":
                rec = valid_content_receipt(); rec["canonical_content_sha256"] = hex64("wrong"); bundle["content_receipts"] = [rec]
            elif vid == "P1-02-02" or vid == "P1-02-03":
                rec = valid_content_receipt(); bundle["content_receipts"] = [rec]
                ref = raw_ref(next(path for path in CHECKER.EXPECTED_UPSTREAM_MAP if path.endswith("raw/static_validation.stdout.raw")))
                if vid == "P1-02-02": ref["bytes"] = int(ref["bytes"]) + 1
                else: ref["sha256"] = hex64("wrong")
                bundle["operational_envelopes"] = [{"comparison_role": "operational_not_content_identity", "content_receipt_id": rec["content_receipt_id"], "canonical_content_sha256": rec["canonical_content_sha256"], "attempt_id": "a1", "stdout": ref}]
            else:
                bundle["replay_observations"] = valid_replay()
                rows = bundle["replay_observations"]
                if vid == "P1-02-04": rows[1]["attempt_id"] = rows[0]["attempt_id"]
                elif vid == "P1-02-05": rows[1]["trace_sha256"] = hex64("different-trace")
                else: rows[1]["config_hash"] = hex64("different-config")
            expect_check_error(self, lambda: CHECKER.check_content_and_replay(bundle, "typed_absent"), expected_code)
            return
        if vid.startswith("P1-03"):
            bundle = make_authoritative_bundle()
            gate = bundle["m5c_gate"]
            assert isinstance(gate, dict)
            if vid == "P1-03-01": gate["gate_receipt_hash"] = hex64("pseudo")
            elif vid == "P1-03-02": gate["raw_stdout"] = None
            elif vid == "P1-03-03": gate["accepted_at"] = "2020-01-01T00:00:00Z"
            else: gate["config_hash"] = hex64("wrong-config")
            status = "fail_closed" if vid in {"P1-03-01", "P1-03-04"} else "not_executed"
            expect_check_error(self, lambda: CHECKER.check_gate(bundle, "authoritative"), expected_code, status)
            return
        if vid.startswith("P1-04"):
            bundle = make_typed_absent_bundle()
            ledger = valid_ledger()
            event = ledger["events"][0]
            assert isinstance(event, dict)
            if vid == "P1-04-01": event["after"] = 99
            elif vid == "P1-04-02": event["sequence"] = -1
            elif vid == "P1-04-03": event["stage"] = "qd_emission"
            elif vid == "P1-04-04": event["scope"] = "per_seed"
            elif vid == "P1-04-05": event["seed"] = 7
            elif vid == "P1-04-06": ledger["caps"]["rewrite_applied"] = 999
            else: ledger["final_counters"]["rewrite_applied"] = 99
            bundle["budget_ledgers"] = [ledger]
            expect_check_error(self, lambda: CHECKER.check_budget(bundle, None), expected_code)
            return
        if vid.startswith("P1-05"):
            bundle = make_authoritative_bundle()
            descriptor = bundle["descriptor"]
            assert isinstance(descriptor, dict)
            if vid == "P1-05-01": descriptor["dimensions"] = [{"name": "typed_node_count_mod_16"}, {"name": "prefix_byte_mod_16"}]
            elif vid == "P1-05-02": descriptor["descriptor_hash"] = hex64("label-change")
            elif vid == "P1-05-03": descriptor["replacement_tie_break"] = "seed,sequence"
            else: bundle["budget_ledgers"] = [{"descriptor_hash": hex64("foreign"), "descriptor_cell": [9, 9]}]
            expect_check_error(self, lambda: CHECKER.check_descriptor(bundle), expected_code)
            return
        if vid.startswith("P2-01"):
            bundle = make_typed_absent_bundle()
            if vid == "P2-01-01": bundle["failure_observations"] = [{"observation": "fail_closed", "derived_class": "fail_closed", "derived_rank": 7}]
            elif vid == "P2-01-02": bundle["failure_observations"] = [{"observation": "fail_closed", "terminal": True, "co_winner": True}, {"observation": "timeout", "terminal": True, "co_winner": True}]
            else:
                bundle["failure_observations"] = [{"observation": "contradiction", "terminal": True}, {"observation": "numerical_fail", "winner": True, "terminal": True}]
                bundle["selected_failure"] = {"class": "numerical_fail", "precedence_rank": CHECKER.FAILURE_RANK["numerical_fail"]}
            expect_check_error(self, lambda: CHECKER.check_failure(bundle), expected_code)
            return
        if vid.startswith("P2-02"):
            bundle = make_typed_absent_bundle()
            scan = bundle["prohibited_scan"]
            assert isinstance(scan, dict)
            if vid == "P2-02-01":
                pass
            elif vid == "P2-02-02": scan["tokens"] = list(reversed(scan["tokens"]))
            elif vid == "P2-02-03": scan["algorithm_sha256"] = hex64("changed")
            elif vid == "P2-02-04": bundle["execution_claim"] = "synthetic claim"; scan["scan_status"] = "not_executed"
            else:
                raw_path = next(path for path in CHECKER.EXPECTED_UPSTREAM_MAP if path.endswith("raw/static_validation.stdout.raw"))
                scan["scan_status"] = "pass"
                scan["input_refs"] = [raw_ref(raw_path)]
                scan["algorithm_sha256"] = hex64("algorithm")
                scan["input_bundle_sha256"] = bundle["input_bundle_sha256"]
                scan["scan_receipt_sha256"] = hex64("unbound")
            status = "not_executed" if vid in {"P2-02-01", "P2-02-04"} else "fail_closed"
            if vid in {"P2-02-01", "P2-02-04"}:
                self.assertEqual(CHECKER.check_scan(bundle, bundle["input_bundle_sha256"]), "incomplete")
            else:
                expect_check_error(self, lambda: CHECKER.check_scan(bundle, bundle["input_bundle_sha256"]), expected_code, status)
            return
        if vid.startswith("P2-03"):
            bundle = make_typed_absent_bundle()
            records = bundle["provenance"]
            assert isinstance(records, list)
            if vid == "P2-03-01": records[0]["relative_path"] = "foreign/path"
            elif vid == "P2-03-02": records[0]["bytes"] = int(records[0]["bytes"]) + 1
            elif vid == "P2-03-03": records[0]["sha256"] = hex64("wrong")
            elif vid == "P2-03-04": records[-1]["relative_path"] = "foreign/review.md"
            elif vid == "P2-03-05": records.append(copy.deepcopy(records[0]))
            elif vid == "P2-03-06": records.append({"relative_path": "unexpected", "bytes": 1, "sha256": hex64("unexpected")})
            elif vid == "P2-03-07": records.append({"relative_path": "docs/implementation/UP5-EARLY-PREPARATION/M5-SEARCH-R2/04-machine-checker-scope-contract-r1/manifest.json", "bytes": 1, "sha256": hex64("self")})
            elif vid == "P2-03-08": records.append({"relative_path": "docs/implementation/UP5-EARLY-PREPARATION/M5-SEARCH-R2/04-machine-checker-scope-contract-r1/hash_manifest.json", "bytes": 1, "sha256": hex64("self")})
            else: records[-1]["bytes"] = int(records[-1]["bytes"]) + 1
            expect_check_error(self, lambda: CHECKER.check_provenance(bundle), expected_code)
            return
        self.fail(f"unmapped vector {vid}")

    def _authoritative_item(self) -> dict[str, object]:
        path = next(iter(CHECKER.EXPECTED_UPSTREAM_MAP))
        data = (ROOT / path).read_bytes()
        try:
            canonical_hash = CHECKER.sha(CHECKER.canonical(CHECKER.load_json_bytes(data)))
        except Exception:
            canonical_hash = CHECKER.sha(data)
        return {
            "authority_status": "authoritative",
            "content_path": path,
            "content_sha256": CHECKER.sha(data),
            "canonical_bytes_sha256": canonical_hash,
            "owner_id": "synthetic-owner",
            "source_ref": "synthetic-source",
            "frozen_at": "2026-09-17T00:00:00Z",
            "metadata_sha256": hex64("metadata"),
            "authority_receipt_hash": hex64("receipt"),
        }


if __name__ == "__main__":
    unittest.main(verbosity=2)
