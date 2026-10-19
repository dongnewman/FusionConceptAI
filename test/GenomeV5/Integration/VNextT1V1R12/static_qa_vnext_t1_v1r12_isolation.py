"""Static gate for the R13 coverage-preserving isolation lane.

This checker is intentionally source-only.  It does not execute Julia or the
legacy V1 regression; the runner performs the fresh-process execution after
this gate passes.
"""

from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path
from pathlib import PureWindowsPath


ROOT = Path(__file__).resolve().parents[4]
TEST = ROOT / "test/GenomeV5/Integration/vnext_t1_candidate_state_package_v5_next_tests.jl"
RUNNER = Path(__file__).with_name("vnext_t1_v1r12_isolated_regression.jl")
MANIFEST = Path(__file__).with_name("coverage_manifest.json")
EVIDENCE_ENV = "VNEXT_T1_V1_ISOLATION_EVIDENCE_REL"
OLD_EVIDENCE_REL = "docs/implementation/UP1-04A-VNEXT-T1/agent_local_r12_v1_isolation"


def fail(message: str) -> None:
    raise SystemExit(f"R15_STATIC_FAIL: {message}")


manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
source = TEST.read_bytes()
source_sha = hashlib.sha256(source).hexdigest().upper()
source_text = source.decode("utf-8")
runner_text = RUNNER.read_text(encoding="utf-8")

if len(source) != manifest["original_test"]["bytes"]:
    fail("original byte length differs from frozen manifest")
if source_sha != manifest["original_test"]["sha256"]:
    fail("original test SHA differs from frozen manifest")
if len(source) != 12975 or source_sha != "970976C4122FC6B4F5303D6763C286514B1C9DC653ABA36D46E1D003BCBF9669":
    fail("direct source size/SHA binding is not the frozen current input")

test_occurrences = len(re.findall(r"(?<![A-Za-z0-9_])@test(?![A-Za-z0-9_])", source_text))
throws_occurrences = len(re.findall(r"(?<![A-Za-z0-9_])@test_throws(?![A-Za-z0-9_])", source_text))
if test_occurrences != manifest["coverage_contract"]["test_occurrences"]:
    fail(f"@test count {test_occurrences} != manifest")
if throws_occurrences != manifest["coverage_contract"]["test_throws_occurrences"]:
    fail(f"@test_throws count {throws_occurrences} != manifest")
for marker in manifest["required_markers"]:
    if marker not in source_text:
        fail(f"missing required marker: {marker}")
if "_T1_EXISTING_LARGE_PAYLOAD_LENGTH = 8_269_445" not in source_text:
    fail("8269445 direct SHA payload marker missing")

for token in (
    "Meta.parseall",
    "expression_hash",
    "_r12_collect",
    "_r12_transform",
    "_r12_dry_transform_source",
    "Base.include",
    "mapexpr",
    "runtime_cursor",
    "String(copy(bytes))",
    "R12_CHILD_UNIQUE_ASSERTION_COUNT",
    "R12_CHILD_RUNTIME_ASSERTION_IDS",
    "R12_CHILD_RUNTIME_HIT_COUNT",
    "typed_unknown",
    "_r12_parse_child_ledger",
    "first_failure",
    "ordered_unrun_target_ids",
    "source_pre",
    "source_post",
    "source_unchanged",
    "protected_hashes_unchanged",
    "2_147_483_648",
    "JULIA_NUM_THREADS",
    "--child",
):
    if token not in runner_text:
        fail(f"runner missing required isolation token: {token}")

runtime_contract = manifest.get("runtime_contract")
if not runtime_contract:
    fail("manifest missing R13 runtime contract")
if runtime_contract.get("legal_repeated_hits") is not True:
    fail("manifest does not allow legal repeated target hits")
if runtime_contract.get("runtime_id_policy") != "all_ids_equal_target":
    fail("manifest runtime id policy is not target-only")
if runtime_contract.get("minimum_hit_count") != 1:
    fail("manifest minimum runtime hit count is not one")
if runtime_contract.get("expected_multiplicity_status") != "typed_unknown":
    fail("manifest expected multiplicity is not typed unknown")
if runtime_contract.get("aggregate_fail_fast") is not True:
    fail("manifest aggregate fail-fast contract missing")
if runtime_contract.get("ordered_unrun_target_ids") is not True:
    fail("manifest ordered unrun target contract missing")
ledger_contract = manifest.get("coverage_ledger", {})
for required_field in (
    "static_assertion_rows",
    "static_unique_expression_hashes",
    "runtime_children",
    "expected_multiplicity",
    "success_stdout_markers",
    "source_hashes",
):
    if ledger_contract.get(required_field) is not True:
        fail(f"manifest coverage ledger field missing: {required_field}")

if "child executed assertion set is not singleton" in runner_text:
    fail("runner retains obsolete singleton runtime contract")
if "unique_ids == [target_id]" in runner_text:
    fail("runner still requires singleton runtime invocation")
if "String(bytes)" in runner_text:
    fail("runner converts source bytes without an independent copy")
if "sprint(show, transformed)" in runner_text:
    fail("runner round-trips transformed AST through show/string")
if "Base.include_string" in runner_text:
    fail("runner executes transformed source through include_string")
if EVIDENCE_ENV not in runner_text:
    fail("runner does not bind evidence root to the required environment variable")
if OLD_EVIDENCE_REL in runner_text or "_R12_EVIDENCE_REL" in runner_text:
    fail("runner retains the old hard-coded R12 evidence root")


def validate_evidence_rel(repo_root: Path, rel: str) -> Path:
    """Pure writer-root validation; validation never creates the candidate."""

    if not rel or not rel.strip():
        raise ValueError("empty evidence root")
    windows_rel = PureWindowsPath(rel)
    candidate_input = Path(rel)
    if candidate_input.is_absolute() or windows_rel.is_absolute() or windows_rel.drive:
        raise ValueError("absolute evidence root")
    if ".." in candidate_input.parts or ".." in windows_rel.parts:
        raise ValueError("traversal evidence root")
    repo = repo_root.resolve()
    candidate = (repo / candidate_input).resolve()
    try:
        candidate.relative_to(repo)
    except ValueError as exc:
        raise ValueError("outside-repository evidence root") from exc
    if candidate.exists():
        raise ValueError("existing evidence root")
    return candidate


def validate_runtime_ids(target: str, ids: list[str], hit_count: int) -> bool:
    """Pure simulation of the child ledger contract; never launches Julia."""

    return bool(ids) and hit_count >= 1 and hit_count == len(ids) and all(
        item == target for item in ids
    )


def source_unchanged(pre: dict[str, object], post: dict[str, object]) -> bool:
    """Fail closed unless all three source identity fields match exactly."""

    fields = ("bytes", "length", "sha256")
    return all(field in pre and field in post and pre[field] == post[field] for field in fields)


def simulate_fail_fast(
    children: list[dict[str, object]],
    source_pre: dict[str, object],
    source_post: dict[str, object],
) -> dict[str, object]:
    launched: list[str] = []
    for index, child in enumerate(children):
        target = str(child["target"])
        launched.append(target)
        valid = (
            bool(child["exit0"])
            and bool(child["marker"])
            and validate_runtime_ids(
                target, list(child["ids"]), int(child["hit_count"])
            )
        )
        if not valid:
            return {
                "launched": launched,
                "first_failure": target,
                "unrun": [str(item["target"]) for item in children[index + 1 :]],
                "source_unchanged": source_unchanged(source_pre, source_post),
                "verdict": False,
            }
    unchanged = source_unchanged(source_pre, source_post)
    return {
        "launched": launched,
        "first_failure": None,
        "unrun": [],
        "source_unchanged": unchanged,
        "verdict": bool(unchanged),
    }


def expect_reject(repo_root: Path, rel: str) -> None:
    try:
        validate_evidence_rel(repo_root, rel)
    except ValueError:
        return
    raise AssertionError(f"evidence root unexpectedly accepted: {rel!r}")


self_tests = 0
valid_rel = "docs/implementation/UP1-04A-VNEXT-T1/agent_local_r15_v1_harness_rootcause_repair_candidate"
assert validate_evidence_rel(ROOT, valid_rel) == (ROOT / valid_rel).resolve()
self_tests += 1
for invalid_rel in (
    "",
    str(ROOT / "absolute-evidence-root"),
    "docs/implementation/UP1-04A-VNEXT-T1/../escape",
    "docs/implementation/UP1-04A-VNEXT-T1/agent_local_r13_v1_harness_repair",
):
    expect_reject(ROOT, invalid_rel)
    self_tests += 1
assert OLD_EVIDENCE_REL not in runner_text
self_tests += 1
assert validate_runtime_ids("r12-001", ["r12-001", "r12-001"], 2)
self_tests += 1
assert not validate_runtime_ids("r12-001", ["r12-001", "r12-002"], 2)
self_tests += 1
assert not validate_runtime_ids("r12-001", ["r12-001"], 0)
self_tests += 1
assert not validate_runtime_ids("r12-001", [], 0)
self_tests += 1
source_identity = {"bytes": 10, "length": 10, "sha256": "A"}
assert source_unchanged(source_identity, source_identity)
self_tests += 1
assert not source_unchanged(source_identity, {"bytes": 11, "length": 10, "sha256": "A"})
self_tests += 1
assert not source_unchanged(source_identity, {"bytes": 10, "length": 11, "sha256": "A"})
self_tests += 1
assert not source_unchanged(source_identity, {"bytes": 10, "length": 10, "sha256": "B"})
self_tests += 1
simulated = simulate_fail_fast(
    [
        {
            "target": "r12-001",
            "ids": ["r12-001", "r12-002"],
            "hit_count": 2,
            "exit0": True,
            "marker": True,
        },
        {
            "target": "r12-002",
            "ids": ["r12-002"],
            "hit_count": 1,
            "exit0": True,
            "marker": True,
        },
    ],
    source_identity,
    source_identity,
)
assert simulated == {
    "launched": ["r12-001"],
    "first_failure": "r12-001",
    "unrun": ["r12-002"],
    "source_unchanged": True,
    "verdict": False,
}
self_tests += 1
source_mismatch = simulate_fail_fast(
    [
        {
            "target": "r12-001",
            "ids": ["r12-001"],
            "hit_count": 1,
            "exit0": True,
            "marker": True,
        }
    ],
    source_identity,
    {"bytes": 10, "length": 10, "sha256": "B"},
)
assert source_mismatch == {
    "launched": ["r12-001"],
    "first_failure": None,
    "unrun": [],
    "source_unchanged": False,
    "verdict": False,
}
self_tests += 1

# The aggregate may only spawn this additive runner.  It may read the frozen
# original path, but must not invoke the monolithic V1 test as a child command.
if re.search(r"julia[^\n`]*vnext_t1_candidate_state_package_v5_next_tests\.jl", runner_text):
    fail("runner contains a monolithic V1 command")
if "docs/v4_multitopology_generation" in runner_text:
    fail("runner writes or depends on active planning docs")

print(
    "R15_STATIC_PASS "
    f"source_bytes={len(source)} source_sha256={source_sha} "
    f"test_occurrences={test_occurrences} test_throws_occurrences={throws_occurrences} "
    f"large_payload=8269445 markers={len(manifest['required_markers'])} "
    f"self_tests={self_tests}"
)
