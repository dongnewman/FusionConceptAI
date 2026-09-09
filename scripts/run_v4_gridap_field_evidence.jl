push!(LOAD_PATH, dirname(@__DIR__))
using FusionConceptAI
using Gridap
Base.include(Main, joinpath(@__DIR__, "..", "examples", "runtime_v4_gridap_field_evidence_fixture.jl"))
b = gridap_b3_bundle
FusionRuntimeV4.validate_gridap_field_evidence(b) || error("B3 evidence validation failed")
FusionRuntimeV4.replay_gridap_field_evidence!(gridap_b3_store, b) || error("B3 replay failed")
FusionRuntimeV4.replay_gridap_field_evidence_fresh(b) || error("B3 fresh replay failed")
b.status === :pass || error("B3 did not pass: $(b.status)")
b.evidence.claim_ceiling === screen_only || error("B3 exceeded screen_only")
b.report.credible_physical_candidate_count == 0 && !b.report.p5_ready || error("B3 authority boundary changed")
println("gridap_b3_status=", b.status)
println("gridap_b3_provider=", b.provider.manifest_hash)
println("gridap_b3_solver_input=", b.input.solver_input_hash)
println("gridap_b3_evidence=", b.evidence.evidence_id)
println("gridap_b3_replay=", b.replay.envelope_hash)
println("gridap_b3_claim_ceiling=", b.evidence.claim_ceiling)
println("GRIDAP_B3_OK")
