"""Static-only QA for the additive local T0 authority recheck adapter.

This checker reads source, test and JSON text.  It does not invoke a runtime,
provider, solver, mesh or external authority service.
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "src/GenomeV5/Integration/VNextDeclarationAuthorityRecheckLocalV1.jl"
TEST = ROOT / "test/GenomeV5/Integration/vnext_declaration_authority_recheck_local_v1_tests.jl"
HELPER = ROOT / "test/GenomeV5/Integration/vnext_declaration_transport_local_v1_tests.jl"
FIXTURE = ROOT / "test/GenomeV5/Integration/vnext_declaration_authority_recheck_local_v1_fixture.json"
ENTRY = ROOT / "src/FusionConceptAI.jl"
LEGACY = ROOT / "src/GenomeV5/Integration/VNextDeclarationAuthorityRecheckV1.jl"

checks: dict[str, bool] = {}
errors: list[str] = []


def require(name: str, condition: bool, detail: str) -> None:
    checks[name] = condition
    if not condition:
        errors.append(f"{name}: {detail}")


source = SOURCE.read_text(encoding="utf-8") if SOURCE.is_file() else ""
test = TEST.read_text(encoding="utf-8") if TEST.is_file() else ""
helper = HELPER.read_text(encoding="utf-8") if HELPER.is_file() else ""
fixture_text = FIXTURE.read_text(encoding="utf-8") if FIXTURE.is_file() else ""
entry = ENTRY.read_text(encoding="utf-8") if ENTRY.is_file() else ""

require("source_exists", SOURCE.is_file(), str(SOURCE))
require("test_exists", TEST.is_file(), str(TEST))
require("transport_helper_exists", HELPER.is_file(), str(HELPER))
require("fixture_exists", FIXTURE.is_file(), str(FIXTURE))
require("adapter_not_shared", "VNextDeclarationAuthorityRecheckLocalV1.jl" not in entry,
        "local adapter must remain additive and standalone")
require("legacy_source_not_redefined",
        "VNextDeclarationAuthorityRecheckV1.jl" not in source,
        "legacy recheck must remain read-only")
require("no_registry", "default_operator_registry" not in source,
        "registry edge is forbidden")
require("no_external_execution", all(token not in source.lower() for token in
        ("provider", "solver", "mesh", "julia", "desc.")),
        "external execution edge present")
require("no_source_include", "Base.include" not in source and "include(" not in source,
        "adapter must be an explicit include target")
require("closed_bundle_input", "VNextT0LocalTransportV1" in source,
        "real T0 bundle input is required")
require("agent_records_input", "local_records" in source,
        "agent-owned local records are required")

required_source = (
    "VNEXT_AR_LOCAL_SCHEMA_ID_V1", "VNEXT_AR_LOCAL_REQUIRED_LAYERS_V1",
    "VNextAuthorityRecheckLocalInputV1", "VNextAuthorityRecheckLocalCheckedPresentV1",
    "VNextAuthorityRecheckLocalTypedAbsentV1", "VNextAuthorityRecheckLocalResultV1",
    "local_checked_present", "typed_absent", "fail_closed", "contract_only",
    "vnext_declaration_authority_recheck_local_v1",
    "vnext_t0_local_bundle_hash_recompute_v1", "bundle_hash_mismatch",
    "candidate_mismatch", "unknown_layer", "duplicate_layer", "missing_layer",
    "record_bundle_canonical_mismatch", "canonical_equality_mismatch",
    "_vnl_t0_errors", "source_ref", "declaration_ref", "source_bytes",
    "declaration_bytes", "source_locator", "factory_receipt",
    "declaration_receipt", "_vnl_t0_feedback_errors",
    "feedback_projection_mismatch", "g3_child_present_forbidden",
    "terminal_deferred", "prior_bundle_bytes", "prior_bundle_sha256",
    "accepted::Bool", "claim_ceiling::Symbol")
for token in required_source:
    require(f"source_token:{token}", token in source, token)

required_test = (
    "local_checked_present", "typed_absent", "fail_closed", "LOCAL_NEGATIVE_DISPATCH",
    "duplicate_layer", "missing_layer", "unknown_layer", "foreign_candidate",
    "source_ref_mismatch", "declaration_ref_mismatch", "source_hash_mismatch",
    "declaration_hash_mismatch", "source_bytes_mismatch", "declaration_bytes_mismatch",
    "locator_mismatch", "factory_receipt_mismatch", "declaration_receipt_mismatch",
    "canonical_equality_mismatch", "feedback_projection_mismatch",
    "duplicate_feedback_target", "unknown_feedback_layer", "g3_child_present_forbidden",
    "stale_bundle", "bundle_hash_mismatch", "bundle_status_invalid",
    "bundle_errors_present", "prior_bundle_bytes_unchanged",
    "prior_bundle_hash_unchanged", "prior_bundle_bytes", "prior_bundle_sha256",
    "terminal_deferred", "contract_only", "accepted === false",
    "result.resolution === :none", "result.errors === expected_errors",
    "result.output === nothing", "axis_identity_or_order_invalid",
    "absent.accepted === false", "absent.claim_ceiling === :contract_only",
    "absent.errors === ()", "absent.output.reasons ===",
    ":missing_material, :g3_feedback_material_absent",
    "_closed_equal", "_freeze_state", "_assert_frozen_unchanged",
    "deepcopy(x)", "G.canonical_json(frozen)",
    "copy(Vector{UInt8}(codeunits(canonical)))", "hash = G._vnl_t0_sha(bytes)",
    "closed comparator mutation probe",
    "probe.declarations[1].source_bytes.bytes[1]",
    "!_closed_equal(probe, probe_snapshot)", "_CLOSED_EQUAL_MAX_DEPTH",
    "_CLOSED_EQUAL_PRODUCT_MODULE", "parentmodule(typeof(a))",
    "a isa AbstractString", "a isa Function", "depth + 1",
    "_expected_present", "_expected_typed_absent")
for token in required_test:
    require(f"test_token:{token}", token in test, token)

# R17 safety contract: the public adapter uses the pre-R6 transport validator
# unchanged.  The test-side snapshot deep-copies each object, canonicalizes
# the frozen copy once, and uses a closed structural comparator after the
# call.  The checker reports the resulting static contract; it never evaluates
# Julia.
performance_counters = {
    "transport_validator_calls": source.count(
        "_vnl_t0_errors(local_record, input.candidate_ref)"),
    "prepared_evidence_definitions": sum(source.count(token) for token in
        ("_ARLocalFactoryPreparedV1", "_ARLocalPresentPreparedV1",
         "_ar_local_prepare_present", "_ar_local_present_errors")),
    "test_snapshot_frozen_serializers": test.count(
        "G.canonical_json(frozen)"),
    "test_after_call_canonicalizers": test.count(
        "canonical_json(x)"),
    "test_after_call_state_helpers": len(re.findall(
        r"(?<!freeze)_state\(", test)),
}
require("r10_transport_validator_restored",
        performance_counters["transport_validator_calls"] == 1,
        str(performance_counters))
require("r10_prepared_evidence_disabled",
        performance_counters["prepared_evidence_definitions"] == 0,
        str(performance_counters))
require("performance_test_snapshot_once_on_frozen_copy",
        performance_counters["test_snapshot_frozen_serializers"] == 1 and
        performance_counters["test_after_call_canonicalizers"] == 0 and
        performance_counters["test_after_call_state_helpers"] == 0 and
        "function _snapshot_part" in test and
        "deepcopy(x)" in test and
        "G._vnl_t0_sha(bytes)" in test,
        str(performance_counters))
require("performance_no_after_call_canonicalization",
        "after = _state" not in test and
        not re.search(r"after[^\n]*canonical_json", test),
        "live after-call canonicalization remains")
require("snapshot_owned_vector_bytes",
        "canonical = G.canonical_json(frozen)" in test and
        "bytes = copy(Vector{UInt8}(codeunits(canonical)))" in test and
        "hash = G._vnl_t0_sha(bytes)" in test,
        "snapshot bytes are not an owned Vector hashed immediately")
require("snapshot_no_giant_ntuple_bytes",
        not re.search(r"Tuple\s*\(\s*codeunits\s*\(\s*G\.canonical_json\(frozen\)", test) and
        not re.search(r"Tuple\s*\(\s*Vector\{UInt8\}", test),
        "canonical bytes are still materialized as a giant NTuple")
require("prior_bytes_exact_without_tuple_rebuild",
        "collect(result.prior_bundle_bytes) == before.bundle_bytes" in test and
        "collect(absent.prior_bundle_bytes) == absent_before.bundle_bytes" in test,
        "returned prior bytes are not compared exactly without rebuilding a giant tuple")
require("prior_sha_uses_transport_bundle_hash",
        "result.prior_bundle_sha256 == bundle.bundle_hash" in test and
        "absent.prior_bundle_sha256 == absent_bundle.bundle_hash" in test and
        not re.search(r"prior_bundle_sha256\s*==\s*(?:\w+_)?before\.bundle_hash", test),
        "prior_bundle_sha256 must use the transport bundle.bundle_hash, not a snapshot hash")
require("closed_comparator_depth_guard",
        "const _CLOSED_EQUAL_MAX_DEPTH = 256" in test and
        "depth <= _CLOSED_EQUAL_MAX_DEPTH || return false" in test,
        "closed comparator has no explicit recursion bound")
require("closed_comparator_runtime_atom_guard",
        all(token in test for token in (
            "a isa AbstractString", "a isa Function", "a isa Type",
            "a isa Module", "a isa Ptr")),
        "runtime/internal values are still opened as generic structs")
require("closed_comparator_product_module_guard",
        "parentmodule(typeof(a)) === _CLOSED_EQUAL_PRODUCT_MODULE || return a == b" in test and
        "const _CLOSED_EQUAL_PRODUCT_MODULE = parentmodule(G.VNextT0LocalTransportV1)" in test,
        "generic struct recursion is not restricted to product values")
require("closed_comparator_nested_walk_is_bounded",
        "_closed_equal(getfield(a, i), getfield(b, i), depth + 1)" in test and
        "_closed_equal(x, y, depth + 1)" in test,
        "nested comparator calls do not carry the depth bound")
require("performance_no_shared_mutable_cache",
        not re.search(r"(?m)^\s*(?:const|global).*\b(?:Dict|cache)\b", source),
        "shared mutable cache/global state present")

# The absent G3 record contributes its contract reason while the authority
# boundary contributes the explicit deferred-feedback reason. Their source
# insertion order is part of the typed-absence contract.
require("typed_absence_reason_source_order",
        source.find("push!(reasons, local_record.reason)") <
        source.find("push!(reasons, :g3_feedback_material_absent)"),
        "typed-absence reason order no longer matches product source")

# The negative matrix is a dispatch contract, not a token checklist.  The
# fixture names, the executable dispatch table, and the case constructors must
# be exactly the same ordered set: no fixture can remain documentation-only and
# no unlisted case can silently enter the focused run.
fixture_names = []
dispatch_names = []
dispatch_expected = {}
case_names = []
try:
    fixture = json.loads(fixture_text)
    fixture_names = fixture.get("negative_controls", [])
    fixture_dispatch = fixture.get("negative_dispatch", [])
    dispatch_block = re.search(
        r"const LOCAL_NEGATIVE_DISPATCH\s*=\s*\((.*?)\n\n@testset",
        test, re.S)
    require("dispatch_table_present", dispatch_block is not None,
            "missing executable negative dispatch table")
    if dispatch_block:
        dispatch_rows = []
        for name, expected_text in re.findall(
                r"\(name=:(\w+),\s*expected_errors=\(([^)]*)\)\)",
                dispatch_block.group(1)):
            expected_errors = tuple(
                token.strip().lstrip(":") for token in expected_text.split(",")
                if token.strip())
            dispatch_rows.append((name, expected_errors))
        dispatch_names = [name for name, _ in dispatch_rows]
        dispatch_expected = dict(dispatch_rows)
    case_names = re.findall(r"cases\[:(\w+)\]\s*=", test)
    require("fixture_dispatch_exact_order", fixture_names == dispatch_names,
            f"fixture={fixture_names!r} dispatch={dispatch_names!r}")
    require("fixture_dispatch_expected_exact",
            [(x.get("name"), tuple(x.get("expected_errors", [])))
             for x in fixture_dispatch] == dispatch_rows,
            "fixture dispatch expected error tuples differ from executable dispatch")
    require("fixture_dispatch_count", len(dispatch_names) == 25,
            f"dispatch count={len(dispatch_names)}")
    negative_object_snapshots = len(dispatch_names) * (1 + 3)
    performance_counters["negative_dispatches"] = len(dispatch_names)
    performance_counters["negative_objects_per_call"] = 1 + 3
    performance_counters["negative_object_snapshots"] = negative_object_snapshots
    require("negative_dispatch_25_of_25", len(dispatch_names) == 25 and
            "for dispatch in LOCAL_NEGATIVE_DISPATCH" in test,
            f"dispatch count={len(dispatch_names)}")
    require("negative_object_snapshot_count_100",
            negative_object_snapshots == 100 and
            "before = _freeze_state(bundle, records)" in test and
            "record_state = Tuple(_snapshot_part(x) for x in records)" in test,
            f"negative object snapshots={negative_object_snapshots}")
    require("negative_snapshot_closed_comparator",
            "_assert_frozen_unchanged(before, bundle, records)" in test and
            "function _closed_equal(a, b, depth::Int=0)" in test and
            "probe.declarations[1].source_bytes.bytes[1]" in test,
            "closed nested-byte mutation check missing")
    require("case_constructor_exact_set", set(case_names) == set(dispatch_names),
            f"constructors={case_names!r}")
    require("case_constructor_unique", len(case_names) == len(set(case_names)),
            "duplicate case constructor")
    require("dispatch_executes_all", "for dispatch in LOCAL_NEGATIVE_DISPATCH" in test and
            re.search(r"_assert_negative\(dispatch\.name,\s*case_bundle,\s*"
                      r"case_records,\s*dispatch\.expected_errors\)", test) is not None,
            "dispatch loop does not call adapter assertions")
    require("dispatch_expected_nonempty", all(dispatch_expected.values()),
            "dispatch row is missing expected failure code")
    require("public_error_tuple_contract",
            "first(errors)" in source and
            all(len(expected_errors) == 1
                for expected_errors in dispatch_expected.values()),
            "public failure tuple no longer matches first-error contract")
    require("axis_identity_or_order_invalid_contract",
            dispatch_expected.get("axis_identity_or_order_invalid") ==
            ("axes_identity_or_order_invalid",),
            "axis identity/order case is not frozen to the existing axis error")
except (json.JSONDecodeError, TypeError) as exc:
    require("dispatch_fixture_json", False, str(exc))

try:
    fixture = json.loads(fixture_text)
    require("fixture_schema", fixture.get("schema_id") ==
            "GenomeV5/Integration/VNextDeclarationAuthorityRecheckLocalV1", "schema id")
    require("fixture_not_authority", fixture.get("fixture_is_authority") is False,
            "fixture cannot authorize a result")
    require("fixture_layers", fixture.get("required_layers") == ["G1", "G2"],
            "G1/G2 exact gate missing")
    require("fixture_g3_boundary", fixture.get("g3_boundary", {}).get("children") ==
            "typed_absent_or_terminal_deferred", "G3 child boundary missing")
    require("fixture_typed_absence_reasons",
            fixture.get("typed_absence_reasons") ==
            ["missing_material", "g3_feedback_material_absent"],
            "typed-absence reasons must preserve source insertion order")
    require("fixture_negative_count", len(fixture.get("negative_controls", [])) >= 20,
            "negative-control matrix too small")
    require("fixture_axis_identity_or_order_invalid", "axis_identity_or_order_invalid" in
            fixture.get("negative_controls", []),
            "axis identity/order case missing")
    require("fixture_exact_checks", len(fixture.get("exact_checks", [])) >= 13,
            "exact binding matrix too small")
    require("fixture_not_accepted", fixture.get("accepted") is False,
            "accepted must remain false")
except (json.JSONDecodeError, TypeError) as exc:
    require("fixture_json", False, str(exc))

require("no_old_source_edit", LEGACY.is_file(), "legacy source must remain present")
require("no_old_hash_literal", not re.search(r"[0-9a-f]{64}", source),
        "adapter must not freeze historical receipt hashes")

# The authority test must consume the already-complete transport helper.  The
# helper is included into Main, where it defines Main.G and loads G1/G2/G3 and
# LocalV1 in order; the new adapter is the only subsequent product include.
def _harness_order(candidate: str) -> tuple[bool, str]:
    helper_include = candidate.find("Base.include(Main, _TRANSPORT_TEST_HELPERS)")
    adapter_include = candidate.find("VNextDeclarationAuthorityRecheckLocalV1.jl")
    if helper_include < 0:
        return False, "transport helper include missing"
    if adapter_include < 0:
        return False, "local authority adapter include missing"
    if helper_include > adapter_include:
        return False, "transport helper must be included before local authority adapter"
    if "VNextDeclarationTransportLocalV1.jl" in candidate:
        return False, "authority test must not directly include LocalV1"
    if re.search(r"(?m)^\s*const\s+G\s*=\s*FusionConceptAI\s*$", candidate):
        return False, "authority test must not redeclare G"
    return True, ""

def _helper_order(candidate: str) -> tuple[bool, str]:
    required = (
        "const G = FusionConceptAI",
        "G3SourceFeedbackLawV1.jl",
        "VNextDeclarationTransportLocalV1.jl",
        "const _T0L_RUN_TESTSETS",
        "if _T0L_RUN_TESTSETS",
        "end # _T0L_RUN_TESTSETS",
    )
    missing = [token for token in required if token not in candidate]
    if missing:
        return False, f"helper missing {missing!r}"
    g3 = candidate.find("G3SourceFeedbackLawV1.jl")
    local = candidate.find("VNextDeclarationTransportLocalV1.jl")
    if g3 > local:
        return False, "G3 law must load before LocalV1"
    guard = candidate.find("if _T0L_RUN_TESTSETS")
    first_testset = candidate.find("@testset")
    if guard < 0 or first_testset < 0 or guard > first_testset:
        return False, "helper testsets must be inside direct-run guard"
    if candidate.find("function _t0l_present") > guard:
        return False, "helper definitions must precede direct-run guard"
    if not re.search(
            r"const _T0L_RUN_TESTSETS\s*=\s*isdefined\(Main,\s*:PROGRAM_FILE\)\s*&&\s*\n\s*abspath\(getfield\(Main,\s*:PROGRAM_FILE\)\)\s*==\s*abspath\(@__FILE__\)",
            candidate):
        return False, "direct-run guard must compare PROGRAM_FILE with @__FILE__"
    return True, ""

ok, detail = _helper_order(helper)
require("transport_helper_complete_load_order", ok, detail)
ok, detail = _harness_order(test)
require("authority_harness_load_order", ok, detail)
require("authority_harness_no_direct_local_v1_include",
        "VNextDeclarationTransportLocalV1.jl" not in test,
        "authority test directly includes LocalV1")
require("authority_harness_no_duplicate_g_alias",
        not re.search(r"(?m)^\s*const\s+G\s*=\s*FusionConceptAI\s*$", test),
        "authority test redeclares G instead of consuming Main.G")
require("g3_before_local_v1",
        helper.find("G3SourceFeedbackLawV1.jl") <
        helper.find("VNextDeclarationTransportLocalV1.jl") and
        helper.find("G3SourceFeedbackLawV1.jl") >= 0,
        "helper load order is unsafe")
require("helper_definition_only_include_mode",
        "if _T0L_RUN_TESTSETS" in helper and
        helper.find("function _t0l_present") < helper.find("if _T0L_RUN_TESTSETS") and
        helper.find("@testset") > helper.find("if _T0L_RUN_TESTSETS"),
        "helper include mode still executes testsets")
require("helper_direct_execution_preserved",
        "const _T0L_RUN_TESTSETS" in helper and
        "PROGRAM_FILE" in helper and "@__FILE__" in helper and
        "end # _T0L_RUN_TESTSETS" in helper,
        "helper direct-run guard is incomplete")

# Negative order controls ensure this QA rejects the R3 failure pattern rather
# than merely accepting the current spelling.
wrong_order = test.replace(
    "Base.include(Main, _TRANSPORT_TEST_HELPERS)",
    "Base.include(G, joinpath(_ROOT, \"src\", \"GenomeV5\", \"Integration\",\n"
    "    \"VNextDeclarationAuthorityRecheckLocalV1.jl\"))")
wrong_order = wrong_order.replace(
    "VNextDeclarationAuthorityRecheckLocalV1.jl\"))",
    "VNextDeclarationAuthorityRecheckLocalV1.jl\"))\n"
    "Base.include(Main, _TRANSPORT_TEST_HELPERS)")
wrong_helper_order = helper.replace(
    "VNextDeclarationTransportLocalV1.jl",
    "G3SourceFeedbackLawV1.jl\")\n# invalid-order-control")
require("reject_wrong_authority_include_order",
        not _harness_order(wrong_order)[0],
        "wrong helper/adapter include order was not rejected")
require("reject_wrong_helper_include_order",
        not _helper_order(wrong_helper_order)[0],
        "wrong G3/LocalV1 helper order was not rejected")

print(json.dumps({
    "record_kind": "vnext-t0-authority-recheck-local-v1-static-qa",
    "python": sys.executable,
    "checks": "pass" if not errors else "fail",
    "check_count": len(checks),
    "passed": sum(checks.values()),
    "errors": errors,
    "performance_counters": performance_counters,
    "scope": [str(path.relative_to(ROOT)).replace("\\", "/") for path in
              (SOURCE, TEST, HELPER, FIXTURE, Path(__file__))],
}, ensure_ascii=False, indent=2))
sys.exit(0 if not errors else 1)
