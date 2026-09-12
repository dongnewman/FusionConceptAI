using Test
function check_revised_chain_v4(R,context,upstream,physics,engineering,verification,whole)
    @testset "same revised candidate actual execution" begin
        @test R.validate_revised_declarations_v4(context)
        @test context.candidate_hash != dgpi_context.candidate_hash
        @test canonical_hash(context.candidate) != revised.parent_hash
        @test all(x.candidate_hash==context.candidate_hash for x in (upstream.request,upstream.result,physics,engineering,verification,whole))
        @test all(x.context_hash==context.context_hash for x in (upstream.request,upstream.result,physics,engineering,verification,whole))
        @test physics.executed && engineering.executed && verification.executed
        @test size(R._cmr_matrix(physics.full_state_jacobian))==(36,4)
        @test !isempty(physics.iterations)
        @test last(physics.iterations).state==physics.final_state
        @test physics.execution.sampler_exit_code==0
        @test physics.solver_exit_code in (0,2,3,4)
        @test engineering.solver_exit_code==0
        @test !engineering.engineering_qualified && !engineering.upstream_valid
        @test physics.status!==:fail || engineering.status===:fail
        @test engineering.physics_result_hash==canonical_hash(physics)
        @test engineering.input_sample.sample.rho==1.0
        @test length(engineering.scenarios)==2
        @test Tuple(s.fault for s in engineering.scenarios)==(:none,:load_short)
        @test verification.numerical.physics.residual_crosscheck.executed
        @test verification.numerical.physics.full_state_jacobian.column_count==4
        @test verification.physical_validation.status===:unsupported
        @test verification.propagation.distribution===:none
        @test whole.declared_reduced_execution_minimum_reached
        @test !whole.full_function_space_mhd_solved && !whole.p5_ready
        @test whole.status===:deferred && whole.credible_device_count==0
        @test canonical_hash(R.assess_revised_whole_device_v4(context,upstream,physics,engineering,verification))==canonical_hash(whole)
        c=context.candidate;g3=c.realization_control_genome_ref
        changed_g3=(realization=g3.realization,control=g3.control,
            realization_graph=g3.control_graph,control_graph=g3.control_graph)
        changed=(mechanism_genome_ref=c.mechanism_genome_ref,
            field_geometry_genome_ref=c.field_geometry_genome_ref,realization_control_genome_ref=changed_g3)
        @test_throws ArgumentError R._validate_revised_graphs_v4(changed)
        old_g1=merge(changed,(mechanism_genome_ref=dgpi_context.candidate.mechanism_genome_ref,
            realization_control_genome_ref=g3))
        @test_throws ArgumentError R._validate_revised_graphs_v4(old_g1)
    end
end
