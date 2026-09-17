"""Static QA for the UP3 contract-only composition matcher R7 slice."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "src" / "RuntimeV4" / "CompositionMatcherContractV1.jl"
TEST = ROOT / "test" / "RuntimeV4" / "composition_matcher_contract_v1_tests.jl"
FIXTURE = ROOT / "test" / "RuntimeV4" / "composition_matcher_contract_v1_fixture.json"


def main() -> int:
    source = SOURCE.read_text(encoding="utf-8")
    test = TEST.read_text(encoding="utf-8")
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))

    required_source = (
        "CompositionPortContractV1",
        "CompositionComponentContractV1",
        "CompositionMatchPlanV1",
        "_cmc_signature_compatible",
        "_cmc_port_key",
        "_cmc_normalized_edge",
        "_cmc_failure_path_key",
        "_cmc_failure_key",
        "_cmc_failure_sort_key",
        "_cmc_topological_order",
        "_cmc_ledger_defects",
        "match_composition_contract",
        "validate_composition_match",
        "composition_match_hash",
        "composition_match_hash(x::CompositionMatchPlanV1) = canonical_hash(semantic_view(x))",
        "unresolved_keys",
        "deferred_reasons",
        "provider_invocation_count",
        "solver_invocation_count",
        ":unmatched_signature",
        ":validation_mismatch",
        ":fail_closed",
        ":terminal_deferred",
        ":contract_only",
    )
    missing = [token for token in required_source if token not in source]
    if missing:
        raise AssertionError(f"missing source contract tokens: {missing}")
    required_source_imports = (
        "import FusionConceptAI: Digest256",
        "Digest256",
        "PhysicalType",
        "UnitSignature",
        "canonical_hash",
        "semantic_view",
    )
    missing_imports = [token for token in required_source_imports if token not in source]
    if missing_imports:
        raise AssertionError(f"source does not explicitly import package bindings: {missing_imports}")
    if "import FusionConceptAI: CapabilitySignatureV4" in source:
        raise AssertionError("matcher must not import RuntimeV4 CapabilitySignatureV4 from package root")
    if "using FusionConceptAI" in source:
        raise AssertionError("source must not depend on package export visibility")
    definition = source.index("function _cmc_failure_key")
    use = source.index("_cmc_failure_key(f) for f in sort")
    if definition > use:
        raise AssertionError("failure key is used before its definition")

    forbidden = (
        "invoke_provider",
        "execute_once!",
        "solve_pde",
        "iterative_solver",
        "build_mesh",
        "default_operator_registry() =",
    )
    found = [token for token in forbidden if token in source]
    if found:
        raise AssertionError(f"contract-only source contains execution token(s): {found}")

    if fixture["scope"] != "contract_only":
        raise AssertionError("fixture scope is not contract_only")
    if fixture["positive"]["provider_invocation_count"] != 0:
        raise AssertionError("provider invocation count is not zero")
    if fixture["positive"]["solver_invocation_count"] != 0:
        raise AssertionError("solver invocation count is not zero")
    expected_negative = {
        "unit_mismatch",
        "space_mismatch",
        "ambiguous_match",
        "cycle",
        "unclosed_ledger",
        "provider_dropout",
        "typed_absent_authority",
        "label_erasure",
        "permutation_erasure",
    }
    if set(fixture["negative"]) != expected_negative or len(fixture["negative"]) < 9:
        raise AssertionError("fixture negative matrix drifted")

    contracts_include = 'joinpath(@__DIR__, "..", "..", "src", "RuntimeV4", "Contracts.jl")'
    matcher_include = 'joinpath(@__DIR__, "..", "..", "src", "RuntimeV4", "CompositionMatcherContractV1.jl")'
    if contracts_include not in test or matcher_include not in test:
        raise AssertionError("isolated test must include Contracts.jl and matcher source")
    if test.index(contracts_include) >= test.index(matcher_include):
        raise AssertionError("isolated test must include RuntimeV4 Contracts before matcher")

    required_test = (
        "module CompositionMatcherIsolatedV1",
        "include(joinpath(@__DIR__",
        "const M = CompositionMatcherIsolatedV1",
        "isdefined(M, name)",
        "M.CapabilitySignatureV4(",
        "_d(c) = M.canonical_hash((tag=String(c),))",
        "input_schema_hash=input_schema",
        "length(string(_d(\"s\"))) == 64",
        "_d(\"s\") != _d(\"x\")",
        "M.match_composition_contract",
        "M.validate_composition_match",
        "M.composition_match_hash",
        "M._cmc_failure_key(failure_a)",
        "M._cmc_failure_key(failure_a) != M._cmc_failure_key(failure_c)",
        "M._cmc_failure_sort_key(failure_a)",
        "plan.plan_hash",
        "renamed.input_hash == plan.input_hash",
        "dropout.status === :terminal_deferred",
        "absent.status === :terminal_deferred",
        "bad_space.status === :fail_closed",
        "bad_schema.status === :fail_closed",
        "Set(f.code for f in bad_schema.failures) == Set([:unmatched_signature])",
        "ambiguous.status === :fail_closed",
        "Set(f.code for f in ambiguous.failures) == Set([:ambiguous_match])",
        "Set(f.code for f in cycle.failures) == Set([:cycle])",
        "unclosed.status === :fail_closed",
        "duplicate.status === :fail_closed",
        "invalid.status === :fail_closed",
        "tampered_hash",
        "checked_hash.status === :fail_closed",
        "@test_throws ArgumentError",
    )
    missing_test = [token for token in required_test if token not in test]
    if missing_test:
        raise AssertionError(f"test does not execute required assertions: {missing_test}")
    if "using FusionConceptAI" in test:
        raise AssertionError("test must not rely on package export visibility")
    if "repeat(" in test:
        raise AssertionError("test must not synthesize Digest256 values by padding labels")
    if "composition_match_hash(x::CompositionMatchPlanV1) = canonical_hash(x)" in source:
        raise AssertionError("composition hash must not hash the stored plan_hash field")
    if "isdefined(FusionConceptAI" in test:
        raise AssertionError("test checks invisible matcher symbols through shared entry")
    if "provider_invocation_count == 0" not in test or "solver_invocation_count == 0" not in test:
        raise AssertionError("test does not assert zero provider/solver counts")

    if "import FusionConceptAI: CapabilitySignatureV4" in test:
        raise AssertionError("test must not import non-exported CapabilitySignatureV4 from package root")
    print("PASS static_qa_composition_matcher_contract_v1_r7")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
