from __future__ import annotations

import copy
import hashlib
import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PROTOCOL_SHA256 = "32bb7c9f7d4f7aabaf563cc57842408d132ae8c374af869084ccd32979fe8cfc"
PROTOCOL_REL = Path(
    "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/agent_r1_20260923/"
    "native_axisymmetric_forward_v7/actual_run_protocol_v16_candidate_v1.json"
)
PRODUCER_ARCHIVE_REL = Path(
    "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/archive/"
    "agent_r1_20260923/freegs_v16_static_candidate_r1"
)
PRODUCER_MANIFEST_SHA256 = "d712ef4f061acaf77356eb70c0aa17c3fe3c507bf52f9489bc99dc4f28664476"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def resolve_pin_path(value: str) -> Path:
    candidate = Path(value)
    return candidate if candidate.is_absolute() else ROOT / candidate


def verify_pins(document: dict[str, object]) -> int:
    pins = document.get("dependency_file_pins")
    require(isinstance(pins, list), "dependency_file_pins is not a list")
    require(document.get("dependency_file_pin_count") == len(pins), "pin count metadata differs")
    paths: list[str] = []
    for item in pins:
        require(isinstance(item, dict), "pin row is not an object")
        path = item.get("path")
        size = item.get("bytes")
        digest = item.get("sha256")
        require(isinstance(path, str) and path, "pin path missing")
        require(isinstance(size, int) and size >= 0, f"invalid byte count: {path}")
        require(isinstance(digest, str) and len(digest) == 64, f"invalid SHA-256: {path}")
        paths.append(path.casefold())
        target = resolve_pin_path(path)
        require(target.is_file(), f"pinned file missing: {path}")
        payload = target.read_bytes()
        require(len(payload) == size, f"byte count mismatch: {path}")
        require(sha256_bytes(payload) == digest, f"SHA-256 mismatch: {path}")
    require(len(paths) == len(set(paths)), "duplicate pinned path")
    return len(pins)


def verify_contract(document: dict[str, object]) -> None:
    require(document.get("schema") == "fusionconceptai:native-axisymmetric-forward-fixed-dirichlet-dof-elimination-v16", "protocol schema mismatch")
    require(document.get("state") == "review_candidate_ungranted_not_dispatched", "protocol state is not an ungranted candidate")
    require(document.get("runtime_execution_authorized") is False, "runtime execution is authorized")
    require(document.get("dependency_file_pin_count") == 158, "expected 158 current dependency pins")

    scope = document["scope"]
    require(isinstance(scope, dict), "scope must be an object")
    for key in ("formal_acceptance", "physical_validation", "engineering_validation", "independent_validation", "terminal_authority", "parent_UP4_03_complete"):
        require(scope.get(key) is False, f"scope.{key} must remain false")

    slot = document["root_resource_slot"]
    require(isinstance(slot, dict) and slot.get("granted") is False, "root FreeGS resource slot must remain ungranted")

    elimination = document["dirichlet_elimination"]
    require(isinstance(elimination, dict), "Dirichlet elimination contract missing")
    require(elimination.get("equation") == "A_BI=0 and A_BB=I imply psi_B=b_B=g_B; solve A_II psi_I=b_I-A_IB g_B", "A_II/A_IB equation changed")
    require(elimination.get("flatten_order") == "C order with row=x*ny+y", "C-order row convention changed")
    require(elimination.get("boundary_partition") == "unique union of the four edges; shared corners occur once; disjoint exhaustive interior/boundary index sets", "boundary partition changed")
    require(elimination.get("rhs_and_corner_rule", "").startswith("use the final RHS after the pinned Equilibrium.solve edge assignments"), "exact RHS/corner rule changed")
    require(elimination.get("no_full_grid_fallback") is True, "full-grid fallback must stay forbidden")
    require(elimination.get("projection_method") == "no post-solve projection; boundary unknowns are eliminated before solving; no threshold waiver", "post-solve projection is not forbidden")
    require(elimination.get("projection_cap_semantics") == "historical v15 full-grid projection guard cap only; not used as a v16 acceptance criterion", "1e-12 guard no longer historical-only")
    require(elimination.get("projection_cap_wb_per_rad") == 1e-12, "historical 1e-12 cap changed")
    require(elimination.get("setSolverVcycle_policy") == "reject if solver object identity differs from the constructor-captured MGDirect; unchecked setSolverVcycle is forbidden because it rebuilds the second-order GSsparse operator", "setSolverVcycle identity guard changed")
    require(elimination.get("cache_lifecycle") == "A_II factorization is local to one marked Equilibrium.solve call and is reused only across that call's Picard linear solves; each new solve builds a fresh operator and factorization", "factorization scope changed")

    runner = document["v7_runner"]
    require(isinstance(runner, dict), "v7 runner binding missing")
    require(runner.get("runner") == "tools/up4_reference_validation/runtime_v4_freegs_axisymmetric_profile_runner_v7.py", "runner path changed")
    require(runner.get("adapter") == "tools/up4_reference_validation/freegs_observed_dirichlet_boundary_v4.py", "adapter path changed")
    require(runner.get("elimination_core") == "tools/up4_reference_validation/freegs_dirichlet_elimination_v1.py", "elimination core path changed")
    require(runner.get("static_fake_test_count") == 23, "expected 23 fake/static tests")
    require(runner.get("runtime_physics_credit") is False, "runtime physics credit must remain false")

    resource = document["resource_contract"]
    require(isinstance(resource, dict), "resource contract missing")
    require(resource.get("wall_seconds_per_step") == 180, "per-step wall ceiling changed")
    require(resource.get("process_tree_rss_bytes_per_step") == 2_147_483_648, "2 GiB process-tree RSS ceiling changed")
    require(resource.get("julia_threads") == 1 and resource.get("blas_threads") == 1, "single-thread contract changed")
    require(resource.get("fresh_process_per_step") is True, "fresh-process contract changed")

    ancestry = document["prior_candidate_no_go_ancestry"]
    require(isinstance(ancestry, dict) and ancestry.get("status") == "frozen_prior_no_go_only", "prior NO-GO ancestry missing")
    require(ancestry["v13_dispatch_review"].get("verdict") == "NO-GO", "v13 prior NO-GO status changed")
    require(ancestry["v14_math_code_review"].get("verdict") == "NO-GO", "v14 prior NO-GO status changed")

    v15 = document["prior_actual_v15_projection_failure"]
    require(isinstance(v15, dict), "v15 failure ancestry missing")
    require(v15.get("status") == "program_exception_exit5_pre_update", "v15 failure status changed")
    require(v15.get("event_index") == 35 and v15.get("applied_projection_count_before_failure") == 34, "v15 event/projection count changed")
    require(v15.get("historical_guard_cap_wb_per_rad") == 1e-12, "v15 guard cap changed")
    require(v15.get("r_max_max_abs_delta_wb_per_rad") == 1.0143656747896301e-12, "v15 measured drift changed")
    require(v15.get("r_max_guard_excess_wb_per_rad") == 1.43656747896301e-14, "v15 measured excess changed")
    require("not committed" in v15.get("failure_point", ""), "v15 uncommitted candidate boundary changed")


def verify_producer_archive() -> int:
    manifest_path = ROOT / PRODUCER_ARCHIVE_REL / "archive_manifest.json"
    manifest_bytes = manifest_path.read_bytes()
    require(sha256_bytes(manifest_bytes) == PRODUCER_MANIFEST_SHA256, "producer evidence manifest SHA-256 mismatch")
    manifest = json.loads(manifest_bytes)
    require(manifest.get("classification") == "evidence_only_no_source_test_or_launcher", "producer leaf is not evidence-only")
    entries = manifest.get("entries")
    require(isinstance(entries, list) and manifest.get("entry_count") == len(entries), "producer archive entry count mismatch")
    for entry in entries:
        path = entry.get("path")
        require(isinstance(path, str) and path, "producer evidence path missing")
        require(not path.lower().endswith((".py", ".jl", ".ps1", ".bat", ".cmd", ".exe")), f"executable/source payload in producer archive: {path}")
        target = manifest_path.parent / path
        require(target.is_file(), f"producer evidence payload missing: {path}")
        payload = target.read_bytes()
        require(len(payload) == entry.get("bytes"), f"producer evidence byte count mismatch: {path}")
        require(sha256_bytes(payload) == entry.get("sha256"), f"producer evidence SHA-256 mismatch: {path}")
    return len(entries)


def expect_rejection(label: str, mutate: object, validator: object, base: dict[str, object]) -> None:
    candidate = copy.deepcopy(base)
    mutate(candidate)  # type: ignore[operator]
    try:
        validator(candidate)  # type: ignore[operator]
    except (AssertionError, KeyError, TypeError, ValueError):
        print(f"NEGATIVE_CONTROL=PASS name={label}")
        return
    raise AssertionError(f"negative control accepted: {label}")


def main() -> int:
    protocol_path = ROOT / PROTOCOL_REL
    protocol_bytes = protocol_path.read_bytes()
    require(sha256_bytes(protocol_bytes) == PROTOCOL_SHA256, "frozen protocol SHA-256 mismatch")
    document = json.loads(protocol_bytes)
    count = verify_pins(document)
    verify_contract(document)
    producer_entry_count = verify_producer_archive()

    reversed_document = copy.deepcopy(document)
    reversed_document["dependency_file_pins"] = list(reversed(reversed_document["dependency_file_pins"]))
    require(verify_pins(reversed_document) == count, "pin order should not change set closure")

    pin_validator = lambda candidate: verify_pins(candidate)
    contract_validator = lambda candidate: verify_contract(candidate)
    expect_rejection("missing-pin", lambda d: d["dependency_file_pins"].pop(), pin_validator, document)
    expect_rejection("extra-pin", lambda d: d["dependency_file_pins"].append(copy.deepcopy(d["dependency_file_pins"][0])), pin_validator, document)
    expect_rejection("wrong-pin-sha", lambda d: d["dependency_file_pins"][0].update(sha256="0" * 64), pin_validator, document)
    expect_rejection("wrong-pin-path", lambda d: d["dependency_file_pins"][0].update(path="missing-v16-pin.bin"), pin_validator, document)
    expect_rejection("wrong-equation-sign", lambda d: d["dirichlet_elimination"].update(equation="A_II psi_I=b_I+A_IB g_B"), contract_validator, document)
    expect_rejection("fallback-enabled", lambda d: d["dirichlet_elimination"].update(no_full_grid_fallback=False), contract_validator, document)
    expect_rejection("post-projection-enabled", lambda d: d["dirichlet_elimination"].update(projection_method="project after solve"), contract_validator, document)
    expect_rejection("vcycle-identity-control-removed", lambda d: d["dirichlet_elimination"].update(setSolverVcycle_policy="call setSolverVcycle"), contract_validator, document)
    expect_rejection("historical-cap-repurposed", lambda d: d["dirichlet_elimination"].update(projection_cap_semantics="acceptance threshold"), contract_validator, document)
    expect_rejection("runtime-authorized", lambda d: d.update(runtime_execution_authorized=True), contract_validator, document)
    expect_rejection("v15-event-drift", lambda d: d["prior_actual_v15_projection_failure"].update(event_index=34), contract_validator, document)
    expect_rejection("v13-no-go-erased", lambda d: d["prior_candidate_no_go_ancestry"]["v13_dispatch_review"].update(verdict="GO"), contract_validator, document)

    print(f"FROZEN_PROTOCOL_SHA256={PROTOCOL_SHA256}")
    print(f"PIN_SET=PASS count={count} duplicate_paths=0 order_invariant=true")
    print(f"PRODUCER_EVIDENCE_ARCHIVE=PASS manifest_sha256={PRODUCER_MANIFEST_SHA256} payload_count={producer_entry_count} executable_payloads=0")
    print("CONTRACT=PASS A_II/A_IB C_order corners exact_rhs no_fallback no_projection vcycle_identity historical_cap v15_lineage resource ungranted_scope")
    print("NEGATIVE_CONTROLS=PASS count=12")
    print("INDEPENDENT_FREEGS_V16_CHECK=PASS runtime_not_started=true")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"INDEPENDENT_FREEGS_V16_CHECK=FAIL error={type(exc).__name__}:{exc}", file=sys.stderr)
        raise
