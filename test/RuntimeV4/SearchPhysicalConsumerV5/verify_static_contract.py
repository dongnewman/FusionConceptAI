"""Python-only static evidence for the isolated V5 deferred regression test.

This does not run Julia, dispatch a provider, or execute a solver.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[3]
TEST = Path(__file__).with_name("search_physical_consumer_v5_deferred_tests.jl")
V4_RUN = ROOT / "docs/implementation/UP5-01/archive/root_search_physical_consumer_v4_focused_grant_20260924/actual_run_v1"
V4_FINAL = V4_RUN / "final.json"
V4_DECISION = ROOT / "docs/implementation/UP5-01/archive/root_search_physical_consumer_v4_focused_grant_20260924/decision.md"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> int:
    final = json.loads(V4_FINAL.read_text(encoding="utf-8"))
    stdout_path = V4_RUN / "stdout.raw"
    stderr_path = V4_RUN / "stderr.raw"
    samples_path = V4_RUN / "samples.jsonl"
    stdout = stdout_path.read_text(encoding="utf-8")
    decision = V4_DECISION.read_text(encoding="utf-8")

    pin_mismatches = []
    for relpath, expected in final["pins_after"].items():
        source = ROOT / relpath
        actual = sha256(source) if source.is_file() else None
        if actual != expected:
            pin_mismatches.append({"path": relpath, "expected": expected, "actual": actual})

    checks = {
        "v4_actual_run_is_natural_exit_1": final["child_exit_code"] == 1 and final["stop_reason"] == "natural_exit",
        "v4_actual_run_is_below_limits": final["elapsed_seconds"] < final["wall_limit_seconds"] and final["peak_sampled_tree_rss_bytes"] < final["rss_limit_bytes"],
        "v4_actual_raw_hashes_match": sha256(stdout_path) == final["stdout_sha256"] and sha256(stderr_path) == final["stderr_sha256"] and sha256(samples_path) == final["samples_sha256"],
        "v4_run_reports_the_two_compile_expectation_failures": "prefix_incomplete === prefix_consistent" in stdout and "required_physical_capability:IDENTITY@v1" in stdout and "4     2      6" in stdout,
        "v4_root_decision_remains_no_go": "Decision: **NO-GO" in decision and "physical/engineering/search credit" in decision,
        "v4_all_35_source_pins_still_match": len(final["pins_after"]) == 35 and not pin_mismatches,
    }

    compiler = (ROOT / "src/RuntimeV4/Compiler.jl").read_text(encoding="utf-8")
    search = (ROOT / "src/RuntimeV4/Search.jl").read_text(encoding="utf-8")
    consumer = (ROOT / "src/RuntimeV4/SearchPhysicalConsumerV1.jl").read_text(encoding="utf-8")
    consumer_v3 = (ROOT / "src/RuntimeV4/SearchPhysicalConsumerV3.jl").read_text(encoding="utf-8")
    test = TEST.read_text(encoding="utf-8")

    checks.update({
        "compiler_retains_physical_edge_gap": 'nothing, string("required_physical_capability:", op)' in compiler and "status = isempty(unresolved) ? :prefix_consistent : :prefix_incomplete" in compiler,
        "search_defers_unresolved_prefix": "isempty(compiled.unresolved_nonterminals) ? :queued : :deferred" in search and "e.compiled.compilation_status == :prefix_consistent && isempty(e.compiled.unresolved_nonterminals)" in search,
        "consumer_requires_active_complete_entry_before_request": "entry.status === :active || return (:deferred, :search_entry_not_active" in consumer and "entry.compiled.compilation_status === :prefix_consistent" in consumer,
        "consumer_v3_dispatch_requires_ready_preflight": "if prepared.state !== :ready_for_dispatch" in consumer_v3 and "execute_trusted_provider(registry, context, request)" in consumer_v3,
        "v5_test_asserts_strong_payload_and_exact_gap": "length(edges) == 2" in test and "typeof(edge) === AtomicMIMOHyperedgeV1" in test and '"required_physical_capability:IDENTITY@v1"' in test,
        "v5_test_asserts_deferred_queue_and_no_dispatch_payload": all(fragment in test for fragment in (":deferred", "next_compilable!(queue) === nothing", "prepare_search_physical_consumer_v3", "record.inner.request === nothing", "record.inner.trusted_receipt === nothing", "record.candidate_discovery_credit == 0", "record.credible_device_count == 0")),
        "v5_test_does_not_call_dispatch_or_solver": "execute_search_physical_consumer_v3!(" not in test and "execute_trusted_provider(" not in test and "execute_freegs_axisymmetric_screen(" not in test and "freegs_solve" not in test,
        "v5_test_does_not_force_queue_active": not re.search(r"queue\.entries\s*\[[^\]]+\]\s*=", test) and ":active" not in test,
    })

    result = {
        "schema": "up5_search_physical_consumer_v5_deferred_static_check_v1",
        "execution": "python_static_only_no_julia_or_provider_dispatch",
        "passed": sum(checks.values()),
        "total": len(checks),
        "checks": checks,
        "pin_count": len(final["pins_after"]),
        "pin_mismatches": pin_mismatches,
        "v4_final_sha256": sha256(V4_FINAL),
        "v4_stdout_sha256": sha256(stdout_path),
        "v4_stderr_sha256": sha256(stderr_path),
        "v4_samples_sha256": sha256(samples_path),
        "v5_test_sha256": sha256(TEST),
        "static_verifier_sha256": sha256(Path(__file__)),
    }
    print(json.dumps(result, sort_keys=True, separators=(",", ":")))
    return 0 if all(checks.values()) else 1


if __name__ == "__main__":
    sys.exit(main())
