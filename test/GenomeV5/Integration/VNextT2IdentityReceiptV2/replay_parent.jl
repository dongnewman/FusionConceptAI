include(joinpath(@__DIR__, "fixture_helpers.jl"))

length(ARGS) == 1 || error("expected replay output path")
output_path = abspath(ARGS[1])
chain = t2_chain()
result = T2_G.vnext_t2_rebind_identity_receipts_v2(chain.build)
result.committed || error((:parent_not_committed, result.status, result.reason))
expected = (schema="vnext-t2-identity-receipt-v2-replay-parent-r2",
    package_hash=chain.reloaded_package.package_hash.value,
    semantic_identity=chain.reloaded_package.semantic_identity.value,
    wire_hash=chain.reloaded_package.wire.sha256.value,
    witness_hash=chain.source.witness.witness_hash.value,
    formal_t1_software_acceptance_receipt_hash=
        chain.gate.formal_t1_software_acceptance_receipt_hash.value,
    candidate_t1_admission_receipt_hash=
        chain.gate.candidate_t1_admission_receipt_hash.value,
    t1_admission_status=String(chain.admission.status),
    t1_admission_resolution=String(chain.admission.resolution),
    t1_admission_invocation_count=chain.t1_admission_invocation_count,
    input_hash=chain.build.input.input_hash.value,
    ledger_hash=result.ledger.ledger_hash.value,
    consumer_order=Tuple(String(x.consumer_id) for x in
        result.attempted_trace.events),
    counts=T2_G.semantic_view(result.attempted_trace.counts),
    formal_gate_evidence_kind="synthetic_local",
    formal_gate_verified=false,
    formal_t2_accepted=false)
open(output_path, "w") do io
    write(io, T2_G.canonical_json(expected), "\n")
    flush(io)
end
println(T2_G.canonical_json(expected))
println("VNEXT_T2_IDENTITY_RECEIPT_V2_REPLAY_PARENT=PASS")
