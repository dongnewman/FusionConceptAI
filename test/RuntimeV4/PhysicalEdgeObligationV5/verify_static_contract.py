"""Python-only source guard for the isolated UP5 V5 negative fixture."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[3]
TEST = Path(__file__).with_name("physical_edge_obligation_v5_tests.jl")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    test = TEST.read_text(encoding="utf-8")
    v1 = (ROOT / "src/RuntimeV4/PhysicalEdgeObligationV1.jl").read_text(encoding="utf-8")
    compat = (ROOT / "src/RuntimeV4/PhysicalEdgeObligationV1Compat.jl").read_text(encoding="utf-8")
    v3 = (ROOT / "src/RuntimeV4/PhysicalEdgeObligationV3.jl").read_text(encoding="utf-8")
    v4_test = (ROOT / "test/RuntimeV4/PhysicalEdgeObligationV4/physical_edge_obligation_v4_tests.jl").read_text(encoding="utf-8")
    runtime_entry = (ROOT / "src/RuntimeV4/FusionRuntimeV4.jl").read_text(encoding="utf-8")
    package_entry = (ROOT / "src/FusionConceptAI.jl").read_text(encoding="utf-8")

    checks = {
        "test_uses_official_single_scenario_typed_binding": (
            "scenarios = (scenario,)" in test
            and "scenario_scope = (scenario.name,)" in test
            and "make_axisymmetric_equilibrium_binding(compiled" in test
            and "ExecutablePhysicalSubjectV4" in test
            and "length(fixture.subject.bindings) == 1" in test
            and "only(fixture.subject.bindings).scenario_hash == context.scenario_hash" in test
        ),
        "strong_two_atomic_g1_edges_and_exact_compiler_gap_are_preserved": (
            "@test length(edges) == 2" in test
            and "typeof(edge) === AtomicMIMOHyperedgeV1" in test
            and "fixture.candidate.mechanism_genome_ref.payload === fixture.g1_payload" in test
            and '("required_physical_capability:IDENTITY@v1",)' in test
            and "TypedOperatorHypergraphV1(getfield(graph, :nodes), ()" in test
            and "@test_throws ArgumentError MechanismGenomePayloadV1(" in test
        ),
        "duplicate_binding_and_foreign_scenario_controls_are_present": (
            "duplicate_subject" in test
            and "@test_throws ArgumentError R5._freegs_context_binding(duplicate_context)" in test
            and "context_a.scenario_hash != context_b.scenario_hash" in test
            and "request_b.status === :recoverable_gap" in test
            and '("trusted_provider_registration_missing",)' in test
            and "foreign_g3=true" in test
        ),
        "cached_forgery_and_string_only_gap_stay_deferred": (
            "fabricated_cached_successes_v5" in test
            and "PEO1_V5.assess_candidate_obligations_v1(" in test
            and "assessment.reasons == (:live_receipt_revalidation_required,)" in test
            and "result.reasons == (:compiler_gap_has_no_edge_bound_resolution,)" in test
            and "result.candidate_discovery_credit == 0" in test
        ),
        "g2_request_cannot_substitute_for_typed_g1_edge_input": (
            "live_attempt_missing_edge_bound_input" in v3
            and "attempt.input" not in v3
            and "input isa PEO1.PhysicalEdgeProviderInputV1" in v3
            and "V5 G2 request and forged receipt are not a G1 edge envelope" in test
            and "reason === :live_attempt_missing_edge_bound_input" in test
            and "validate_trusted_provider_execution_receipt(" in test
            and "assessment.reasons == (:compiler_gap_has_no_edge_bound_resolution,)" in test
        ),
        "executor_issuance_ceiling_is_explicit": (
            "receipt_validator_is_issuer_attestation=false" in v3
            and "executor_issuance_provenance_available=false" in v3
            and "V5 self-consistent caller receipt lacks executor issuance authority" in test
            and "!hasproperty(forged_receipt, :issuer_proof)" in test
            and "!hasproperty(forged_receipt, :execution_identity)" in test
            and "validate_trusted_provider_execution_receipt(" in test
        ),
        "namespace_repeat_foreign_and_collision_controls_are_present": (
            "parent namespace already binds PhysicalEdgeObligationV1" in test
            and "parent namespace already loaded PhysicalEdgeObligationV1Compat" in test
            and "PhysicalEdgeObligationV5ForeignAliasFixture" in test
            and "@test_throws ArgumentError _load_v1_compat_with_parent_alias_v5!(" in test
            and "invalid redefinition of constant" in test
            and "PhysicalEdgeObligationV1.PhysicalEdgeObligationV1" in test
            and "module PhysicalEdgeObligationV1Compat" in compat
            and "struct PhysicalEdgeObligationV1" in v1
        ),
        "frozen_v4_negative_cases_are_recovered_in_new_v5_test": all(
            marker in test
            for marker in (
                "V5 cached caller-forged edge success remains deferred",
                "V5 string-only compiler label cannot resolve typed edges",
                "V5 registration is scenario and candidate bound",
                "V5 compat loader is single-owner and fail-closed",
                "V5 frozen V1 name collision is contained in a disposable module",
                "V5 G2 request and forged receipt are not a G1 edge envelope",
            )
        ),
        "no_shared_entry_is_wired_and_no_freegs_executor_is_called_by_v5_test": (
            "PhysicalEdgeObligationV5" not in runtime_entry
            and "PhysicalEdgeObligationV5" not in package_entry
            and "execute_freegs_axisymmetric_screen(" not in test
            and "execute_trusted_provider(" not in test
        ),
        "failure_case_source_is_pinned_instead_of_rewritten": (
            "trusted_registry_v4(context)" in v4_test
            and "physical subject must contain exactly one typed axisymmetric binding" not in test
            and "search_physical_fixture_v4(foreign_g3=foreign_g3)" in test
        ),
        "frozen_v1_v2_v3_and_v4_test_sources_match_known_hashes": (
            sha256(ROOT / "src/RuntimeV4/PhysicalEdgeObligationV1.jl")
                == "9663dcb3ef6b64eda0ef7e09e1ec0785adfc1e6512f9c84bdd633288e6abcb80"
            and sha256(ROOT / "src/RuntimeV4/PhysicalEdgeObligationV2.jl")
                == "9ae869282fe4d2f15918f225b2976370e092396ab5222ef20ed184199a407ba2"
            and sha256(ROOT / "src/RuntimeV4/PhysicalEdgeObligationV3.jl")
                == "5f2a73c5c38b06aeae4273d6945da362f74f5bb12ddbcb972fe2efb75422850b"
            and sha256(ROOT / "src/RuntimeV4/PhysicalEdgeObligationV1Compat.jl")
                == "4a73e38127f29f68a93c0aebf87aec1c925e50194692531c6b32cf7162aec525"
            and sha256(ROOT / "test/RuntimeV4/PhysicalEdgeObligationV4/physical_edge_obligation_v4_tests.jl")
                == "b0d189af65e33a98201ed8f375dcd8387ad2f46953d4b2c4dd777ce95999e06f"
        ),
    }

    failed = [name for name, passed in checks.items() if not passed]
    result = {
        "schema": "up5-physical-edge-obligation-v5-static-contract-r1",
        "execution": "python_static_only_no_julia_no_freegs",
        "passed": sum(checks.values()),
        "total": len(checks),
        "checks": checks,
        "failures": failed,
        "v1_sha256": sha256(ROOT / "src/RuntimeV4/PhysicalEdgeObligationV1.jl"),
        "v1_compat_sha256": sha256(ROOT / "src/RuntimeV4/PhysicalEdgeObligationV1Compat.jl"),
        "v3_sha256": sha256(ROOT / "src/RuntimeV4/PhysicalEdgeObligationV3.jl"),
        "test_sha256": sha256(TEST),
    }
    print(json.dumps(result, sort_keys=True, separators=(",", ":")))
    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main())