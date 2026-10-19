"""Static contract checks for the isolated candidate-bound G2 observer.

This verifier never launches Julia, FreeGS, DESC, or a provider.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "src/RuntimeV4/CandidateBoundG2ScreenObservationV1.jl"
TEST = Path(__file__).with_name("candidate_bound_g2_screen_observation_v1_tests.jl")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> int:
    source = SOURCE.read_text(encoding="utf-8")
    test = TEST.read_text(encoding="utf-8")
    runtime_entry = (ROOT / "src/RuntimeV4/FusionRuntimeV4.jl").read_text(encoding="utf-8")
    obligation = (ROOT / "src/RuntimeV4/PhysicalEdgeObligationV1Compat.jl").read_text(encoding="utf-8")
    registry = (ROOT / "src/RuntimeV4/TrustedProviderRegistryV4.jl").read_text(encoding="utf-8")
    freegs = (ROOT / "src/RuntimeV4/TrustedFreeGSAxisymmetricProviderV4.jl").read_text(encoding="utf-8")
    checks: dict[str, bool] = {}

    checks["isolated_module_is_not_wired_into_shared_runtime"] = (
        "module CandidateBoundG2ScreenObservationV1" in source
        and "CandidateBoundG2ScreenObservationV1.jl" not in runtime_entry
        and "include(" not in source
    )
    signature = re.search(
        r"function observe_candidate_bound_g2_screen_v1\s*\((.*?)\)\s*\n",
        source,
        flags=re.S,
    )
    checks["public_entry_accepts_only_context_and_registry"] = bool(
        signature
        and "context::ForwardChainContextV4" in signature.group(1)
        and "registry::TrustedProviderRegistryV4" in signature.group(1)
        and "CapabilitySignatureV4" not in signature.group(1)
        and "TrustedProviderDispatchRequestV4" not in signature.group(1)
        and "TrustedProviderExecutionReceiptV4" not in signature.group(1)
        and "executor" not in signature.group(1)
    )
    ordered = [
        "trusted_freegs_axisymmetric_capability(context)",
        "make_trusted_freegs_axisymmetric_input(context, capability)",
        "build_trusted_provider_dispatch_request(registry, context,",
        "execute_trusted_provider(registry, context, request)",
        "validate_trusted_provider_execution_receipt(receipt, request,",
    ]
    positions = [source.find(token) for token in ordered]
    checks["capability_request_and_receipt_are_derived_and_revalidated_in_order"] = (
        all(position >= 0 for position in positions)
        and positions == sorted(positions)
        and "validate_trusted_freegs_axisymmetric_capability(capability, context)" in source
        and "validate_trusted_freegs_axisymmetric_input(input, context, capability)" in source
        and "validate_trusted_provider_dispatch_request(request, registry, context," in source
    )
    checks["actual_executor_is_direct_tpr_call_and_serialized_locally"] = (
        "_G2OBS_EXECUTION_LOCK = ReentrantLock()" in source
        and "lock(_G2OBS_EXECUTION_LOCK) do" in source
        and "execute_trusted_provider(registry, context, request)" in source
        and "execute_freegs_axisymmetric_screen(" not in source
    )
    checks["exact_candidate_context_and_provider_source_identities_are_recorded"] = all(
        token in source
        for token in (
            "candidate_hash::Union{Nothing,Digest256}",
            "genome_bundle_hash::Union{Nothing,Digest256}",
            "subject_hash::Union{Nothing,Digest256}",
            "context_hash::Union{Nothing,Digest256}",
            "scenario_hash::Union{Nothing,Digest256}",
            "provider_descriptor_hash::Union{Nothing,Digest256}",
            "provider_manifest_hash::Union{Nothing,Digest256}",
            "provider_source_hash::Union{Nothing,Digest256}",
            "provider_runtime_hash::Union{Nothing,Digest256}",
            "provider_attested_source_paths::Tuple{Vararg{String}}",
            "provider_attested_source_hashes::Tuple{Vararg{Digest256}}",
            "record.provider_source_hash == source_provenance.provider_source_hash",
        )
    )
    checks["full_physical_edge_inventory_stays_unresolved_and_separate"] = (
        "physical_edge_obligations_v1(context)" in source
        and "validate_obligation_set_v1(context, obligations)" in source
        and "all(x -> x.provider.receipt_state === :missing, obligations)" in source
        and "unresolved_g1_identity_hashes" in source
        and "bind_trusted_provider_receipt_v1" not in source
        and "PhysicalEdgeProviderInputV1" not in source
    )
    checks["screen_ceiling_and_zero_credit_are_invariant"] = (
        "receipt.status === :physical_model_screen && receipt.exit_code == 0" in source
        and "claim_ceiling=claim_ceiling" in source
        and "search_activation=search_activation" in source
        and "physical_validation=physical_validation" in source
        and "engineering_validation=engineering_validation" in source
        and "candidate_discovery_credit=candidate_discovery_credit" in source
        and "!x.search_activation && !x.physical_validation && !x.engineering_validation" in source
        and "x.candidate_discovery_credit == 0 && x.credible_device_count == 0" in source
    )
    checks["process_local_ticket_and_live_revalidation_fail_closed"] = (
        "IdDict{_G2OBS_IssueTicket,Tuple{UInt64,Digest256}}()" in source
        and "_G2OBS_ISSUED[ticket] = (ticket.nonce, record.record_hash)" in source
        and "issued_hash == (record._ticket.nonce, record.record_hash) || return false" in source
        and "validate_trusted_provider_registry(registry)" in source
        and "validate_trusted_provider_execution_receipt(record.receipt, request," in source
    )
    checks["no_search_queue_or_queue_mutation_path_exists"] = not any(
        forbidden in source
        for forbidden in (
            "CandidateQueueV4",
            "enqueue_candidate!",
            "next_compilable!",
            "queue.entries",
            "execute_search_physical_consumer",
        )
    )
    checks["tests_cover_real_path_absence_drift_tamper_clone_and_no_injection"] = all(
        token in test
        for token in (
            "trusted_registry_v4(context)",
            "record.receipt !== nothing",
            "_g2obs_empty_trusted_registry()",
            "foreign_g3=true",
            "context_b, registry_a",
            "clone = deepcopy(record)",
            "_g2obs_replace_field(record, :receipt, nothing)",
            "applicable(G2OBS.observe_candidate_bound_g2_screen_v1",
            "record.unresolved_g1_identity_hashes",
            "record.candidate_discovery_credit == 0",
        )
    )
    checks["source_contract_matches_fixed_tpr_and_freegs_adapters"] = (
        "function execute_trusted_provider(registry::TrustedProviderRegistryV4" in registry
        and "validate_trusted_provider_execution_receipt(::TrustedProviderExecutionReceiptV4) = false" in registry
        and "input isa TrustedFreeGSAxisymmetricInputV4" in registry
        and "trusted_freegs_axisymmetric_capability(context)" in freegs
        and "validate_trusted_freegs_axisymmetric_output(output, context, input, capability)" in freegs
        and "edge_input isa PhysicalEdgeProviderInputV1" in obligation
        and "bind_trusted_provider_receipt_v1" in obligation
    )
    checks["fixture_keeps_compiler_gap_and_never_mutates_a_search_queue"] = (
        '"required_physical_capability:IDENTITY@v1"' in test
        and "fixture.compiled.compilation_status === :prefix_incomplete" in test
        and "make_axisymmetric_equilibrium_binding(compiled" in test
        and "scenarios = (scenario,)" in test
        and "CandidateQueueV4" not in test
        and "enqueue_candidate!" not in test
        and "queue.entries" not in test
    )

    failed = [name for name, passed in checks.items() if not passed]
    result = {
        "schema": "up5_candidate_bound_g2_screen_observation_v1_static_contract_v1",
        "execution": "python_static_only_no_julia_no_freegs_no_provider",
        "passed": sum(checks.values()),
        "total": len(checks),
        "checks": checks,
        "failures": failed,
        "source_sha256": sha256(SOURCE),
        "test_sha256": sha256(TEST),
        "registry_sha256": sha256(ROOT / "src/RuntimeV4/TrustedProviderRegistryV4.jl"),
        "freegs_sha256": sha256(ROOT / "src/RuntimeV4/TrustedFreeGSAxisymmetricProviderV4.jl"),
    }
    print(json.dumps(result, sort_keys=True, separators=(",", ":")))
    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main())
