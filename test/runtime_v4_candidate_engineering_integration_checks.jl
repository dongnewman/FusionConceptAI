using Test
using FusionConceptAI

"""Called by the real whole-chain runner after it has executed/replayed upstream once."""
function check_candidate_engineering_integration(owner::Module, context, upstream, request, result, execution)
    @testset "engineering consumes the actual current-candidate physics" begin
        @test owner.validate_candidate_engineering_execution(context, upstream, request, result, execution) === execution
        @test execution.context_hash == context.context_hash
        @test execution.candidate_hash == context.candidate_hash
        @test execution.scenario_hash == context.scenario_hash
        @test execution.g3_hash == canonical_hash(context.candidate.realization_control_genome_ref)
        @test execution.traction_result_hash == canonical_hash(result)
        @test execution.pressure_field_receipt_hash == request.pressure_field_receipt_hash
        @test execution.equilibrium_output_sha256 == request.equilibrium_output_sha256
        @test execution.load_projection_executed
        @test length(execution.samples) == 2length(result.samples)
        @test all(s -> s.spatial_scope === :sampled_plasma_rho_interface && !s.component_load, execution.samples)
        @test !execution.engineering_executed && !execution.control_executed && !execution.fault_executed
        @test execution.engineering_status === execution.control_status === execution.fault_status === :unsupported
        @test !execution.physical_validation && !execution.engineering_validation
        @test !execution.promotion_authority && !execution.terminal_authority && execution.credible_device_count == 0
        @test length(execution.gaps) == 8
        @test all(g -> g.recoverable && g.status === :unsupported, execution.gaps)
        @test execution.realization_payload_count == execution.control_payload_count == 0
        @test execution.realization_operator_count == execution.control_operator_count == 0
        # Hash-valid fabricated engineering success remains forbidden.
        promoted = merge(semantic_view(execution), (engineering_executed=true, engineering_status=:pass))
        forged = owner.CandidateEngineeringExecutionV4(owner._CEE_TOKEN, values(promoted)..., canonical_hash(promoted))
        @test_throws ArgumentError canonical_hash(forged)
        foreign = merge(semantic_view(execution), (candidate_hash=digest256_text("foreign-candidate"),))
        forged_foreign = owner.CandidateEngineeringExecutionV4(owner._CEE_TOKEN, values(foreign)..., canonical_hash(foreign))
        @test_throws ArgumentError owner.validate_candidate_engineering_execution(context, upstream, request, result, forged_foreign)
        missing_sample = merge(semantic_view(execution), (samples=execution.samples[1:end-1],))
        forged_samples = owner.CandidateEngineeringExecutionV4(owner._CEE_TOKEN, values(missing_sample)..., canonical_hash(missing_sample))
        @test_throws ArgumentError owner.validate_candidate_engineering_execution(context, upstream, request, result, forged_samples)
    end
    println("CANDIDATE_ENGINEERING_REAL_INTEGRATION_EXIT_CODE=0")
    execution
end
