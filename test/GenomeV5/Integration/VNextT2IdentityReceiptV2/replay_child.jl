include(joinpath(@__DIR__, "fixture_helpers.jl"))

length(ARGS) == 5 || error("expected package, input, ledger and two T1 receipt hashes")
expected_package_hash, expected_input_hash, expected_ledger_hash,
    expected_software_receipt_hash, expected_candidate_receipt_hash = ARGS
chain = t2_chain()
result = T2_G.vnext_t2_rebind_identity_receipts_v2(chain.build)
actual = (schema="vnext-t2-identity-receipt-v2-replay-child-r1",
    package_hash=chain.reloaded_package.package_hash.value,
    formal_t1_software_acceptance_receipt_hash=
        chain.gate.formal_t1_software_acceptance_receipt_hash.value,
    candidate_t1_admission_receipt_hash=
        chain.gate.candidate_t1_admission_receipt_hash.value,
    t1_admission_status=String(chain.admission.status),
    t1_admission_resolution=String(chain.admission.resolution),
    t1_admission_invocation_count=chain.t1_admission_invocation_count,
    input_hash=chain.build.input.input_hash.value,
    status=String(result.status), resolution=String(result.resolution),
    reason=String(result.reason), committed=result.committed,
    consumer_order=Tuple(String(x.consumer_id) for x in
        result.attempted_trace.events),
    counts=T2_G.semantic_view(result.attempted_trace.counts),
    formal_gate_evidence_kind="synthetic_local",
    formal_gate_verified=false,
    ledger_hash=result.ledger === nothing ? nothing :
        result.ledger.ledger_hash.value,
    formal_t2_accepted=false)
println(T2_G.canonical_json(actual))
flush(stdout)

actual.package_hash == expected_package_hash || error("replay package hash mismatch")
actual.input_hash == expected_input_hash || error("replay input hash mismatch")
actual.ledger_hash == expected_ledger_hash || error("replay ledger hash mismatch")
actual.formal_t1_software_acceptance_receipt_hash ==
    expected_software_receipt_hash || error("software receipt hash mismatch")
actual.candidate_t1_admission_receipt_hash ==
    expected_candidate_receipt_hash || error("candidate receipt hash mismatch")
actual.committed || error("replay did not commit five receipts")
actual.consumer_order == ("E0", "GI1A", "E1", "E2", "UP2_N10") ||
    error("replay consumer order mismatch")
println("VNEXT_T2_IDENTITY_RECEIPT_V2_REPLAY_CHILD=PASS")
