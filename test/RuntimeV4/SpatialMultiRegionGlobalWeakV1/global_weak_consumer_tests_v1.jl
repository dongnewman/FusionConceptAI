"""Independent checks for the additive global shared-node Q1 successor.

The default formal numerical consumer is the real manufactured q1_2 candidate
path. Explicitly parameterized q1_4 and q1_8 producer/consumers are also
available. These software checks
carry no DESC execution, physical acceptance, or publish authority.
"""
module SpatialMultiRegionGlobalWeakV1Tests

using Test, FusionConceptAI, LinearAlgebra, SparseArrays, SHA, JSON3

const REPO=normpath(joinpath(@__DIR__,"..","..",".."))

module DefinitionRuntime
    using FusionConceptAI
    const REPO=normpath(joinpath(@__DIR__,"..","..",".."))
    for name in ("Contracts.jl","Compiler.jl","ForwardChainContext.jl",
            "ThreeDPhysicalProviderInputV4.jl","CompleteMultiRegionV4.jl",
            "RevisedCandidateV4.jl","SpatialExecutionTypesV4.jl",
            "SpatialMultiRegionV4.jl","SpatialPickupEngineeringV4.jl",
            "SpatialVerificationUQV4.jl","SpatialCandidateV4.jl",
            "SpatialWholeDeviceV4.jl")
        include(joinpath(REPO,"src","RuntimeV4",name))
    end
    include(joinpath(REPO,"src","RuntimeV4","SpatialMultiRegionGlobalWeakV1.jl"))
end

const S=DefinitionRuntime
module ParentTemplate
    using FusionConceptAI
    include(joinpath(@__DIR__,"..","..","..","examples","runtime_v4_declared_fixture.jl"))
end
include("independent_global_weak_oracle_v1.jl")
const O=SpatialMultiRegionGlobalWeakOracleV1

sha(path)=bytes2hex(SHA.sha256(read(path)))
wire_digest(value)=String(value isa AbstractString ? value :
    value isa NamedTuple ? getproperty(value,:value) : value["value"])

function _smgw_trace_begin(name)
    started_ns=time_ns()
    println("SMGW_SUBCALL_BEGIN name=",name," monotonic_ns=",started_ns)
    flush(stdout)
    started_ns
end

function _smgw_trace_end(name,started_ns)
    elapsed_seconds=Float64(time_ns()-started_ns)/1.0e9
    println("SMGW_SUBCALL_END name=",name," elapsed_seconds=",elapsed_seconds)
    flush(stdout)
    nothing
end

function fresh_manufactured_parent_context(input)
    started_ns=_smgw_trace_begin("spatial_manufactured_parent_geometry_v1")
    geometry=S.spatial_manufactured_parent_geometry_v1(input)

    _smgw_trace_end("spatial_manufactured_parent_geometry_v1",started_ns)
    template=ParentTemplate
    started_ns=_smgw_trace_begin("FieldGeometryGenomeV4")
    g2=FieldGeometryGenomeV4(2026092201,template._fixture_refs[2],geometry.graph;
            fields=(geometry.support,geometry.physical_input))

    _smgw_trace_end("FieldGeometryGenomeV4",started_ns)
    started_ns=_smgw_trace_begin("CandidateStatePackageV4")
    parent_candidate=CandidateStatePackageV4("manufactured-n1-circular-parent-v1",
            template._fixture_mission,template._fixture_mechanism,g2,
            template._fixture_realization,template.registry)

    _smgw_trace_end("CandidateStatePackageV4",started_ns)
    mission=(mission="manufactured-n1-numerical-verification",
        contract=parent_candidate.mission_contract_ref,authority=:no_publish)
    started_ns=_smgw_trace_begin("bounds_declaration_hash")
    declaration_hash=canonical_hash(geometry.physical_input)

    _smgw_trace_end("bounds_declaration_hash",started_ns)
    started_ns=_smgw_trace_begin("bounds_input_hash")
    input_hash=canonical_hash(input)

    _smgw_trace_end("bounds_input_hash",started_ns)
    bounds=(declaration_hash=declaration_hash,
        input_hash=input_hash,scope=:manufactured_numerical_only)
    comparison=("manufactured-n1-single-mesh-endpoint",)
    scenario=(name="manufactured-n1-circular-analytic",
        source=:manufactured_not_measured,desc_execution=:not_executed)
    scenario_scope=(scenario.name,)
    started_ns=_smgw_trace_begin("compile_candidate")
    compiled=S.compile_candidate(parent_candidate,template.registry;
            mission_payload=mission,bounds_payload=bounds,
            comparison_scope=comparison,scenario_scope=scenario_scope)

    _smgw_trace_end("compile_candidate",started_ns)
    started_ns=_smgw_trace_begin("make_three_d_physical_provider_input_binding")
    binding=S.make_three_d_physical_provider_input_binding(compiled,template.registry,
            mission,bounds,comparison,scenario_scope,scenario,geometry.physical_input)

    _smgw_trace_end("make_three_d_physical_provider_input_binding",started_ns)
    subject_prefix_hash=compiled.prefix_hash
    subject_genome_bundle_hash=parent_candidate.canonical_hashes.genome_bundle_hash
    subject_mission_hash=compiled.minimality_scope.mission_hash
    subject_bounds_hash=compiled.minimality_scope.bounds_hash
    subject_bindings=(binding,)
    subject_scenarios=(scenario,)
    started_ns=_smgw_trace_begin("subject_materialized_payload_input_hash")
    subject_input_hash=canonical_hash(input)

    _smgw_trace_end("subject_materialized_payload_input_hash",started_ns)
    materialized_payload=(input_hash=subject_input_hash,
        materialization=:manufactured_analytic_provider,authority=:no_publish)
    started_ns=_smgw_trace_begin("derive_capability_obligations")
    capability_obligations=S.derive_capability_obligations(compiled)

    _smgw_trace_end("derive_capability_obligations",started_ns)
    started_ns=_smgw_trace_begin("ExecutablePhysicalSubjectV4")
    subject=S.ExecutablePhysicalSubjectV4(subject_prefix_hash,
            subject_genome_bundle_hash,subject_mission_hash,subject_bounds_hash,
            subject_bindings,subject_scenarios,
            materialized_payload,capability_obligations)

    _smgw_trace_end("ExecutablePhysicalSubjectV4",started_ns)
    started_ns=_smgw_trace_begin("make_forward_chain_context")
    parent_context=S.make_forward_chain_context(parent_candidate,compiled,
            template.registry,mission,bounds,comparison,scenario_scope,subject,scenario)

    _smgw_trace_end("make_forward_chain_context",started_ns)
    started_ns=_smgw_trace_begin("validate_forward_chain_context")
    S.validate_forward_chain_context(parent_context)

    _smgw_trace_end("validate_forward_chain_context",started_ns)
    geometry.physical_input,parent_context
end

function fresh_manufactured_context(input,declaration;parent_context=nothing)
    physical_input=if parent_context===nothing
        generated_input,parent_context=fresh_manufactured_parent_context(input)
        generated_input
    else
        S.validate_forward_chain_context(parent_context)
        target_geometry=S.spatial_manufactured_parent_geometry_v1(input)
        inherited=only(filter(value->value isa S.ThreeDPhysicalProviderInputV4,
            parent_context.candidate.field_geometry_genome_ref.fields))
        canonical_hash(inherited)==canonical_hash(target_geometry.physical_input) ||
            throw(ArgumentError("supplied continuation parent does not own the target manufactured geometry"))
        target_geometry.physical_input
    end
    started_ns=_smgw_trace_begin("build_spatial_candidate_v4_manufactured")
    child=S.build_spatial_candidate_v4(parent_context,physical_input;
            physical_declaration=declaration)

    _smgw_trace_end("build_spatial_candidate_v4_manufactured",started_ns)
    context=child.context
    started_ns=_smgw_trace_begin("validate_spatial_manufactured_candidate_input_v1")
    S.validate_spatial_manufactured_candidate_input_v1(context,input)

    _smgw_trace_end("validate_spatial_manufactured_candidate_input_v1",started_ns)
    context.candidate_hash!=parent_context.candidate_hash ||
        error("manufactured child candidate reused parent identity")
    context,physical_input,parent_context
end

function _tuple_close(a,b;rtol=2e-8,atol=2e-9)
    length(a)==length(b) && all(i->isapprox(Float64(a[i]),Float64(b[i]);rtol,atol),eachindex(a))
end

function _named_numeric_close(actual,expected;rtol=2e-8,atol=2e-8)
    actual_keys=keys(actual);expected_keys=keys(expected)
    length(actual_keys)==length(expected_keys) && Set(actual_keys)==Set(expected_keys) || return false
    all(keys(actual)) do key
        a=getproperty(actual,key);b=getproperty(expected,key)
        if a isa Tuple
            b isa Tuple && _tuple_close(a,b;rtol,atol)
        elseif a isa Real && b isa Real
            isapprox(Float64(a),Float64(b);rtol,atol)
        else
            isequal(a,b)
        end
    end
end

function assert_assembly_matches(actual,expected,label)
    @test actual.schema=="spatial-global-shared-q1-weak-assembly-v1"
    @test actual.revision=="spatial-q1-global-shared-test-rows-v1"
    @test actual.row_layout==expected.row_layout
    @test actual.node_order==expected.node_order
    @test actual.element_nodes==expected.element_nodes
    @test actual.row_blocks==expected.row_blocks
    @test actual.row_supports==expected.row_supports
    @test length(actual.residual)==length(expected.residual)
    @test all(i->isapprox(actual.row_scales[i],expected.row_scales[i];rtol=3e-11,atol=1e-12),eachindex(actual.row_scales))
    scaled_difference=maximum(abs.(actual.residual.-expected.residual)./actual.row_scales)
    @test isfinite(scaled_difference) && scaled_difference<=5e-10
    @test _named_numeric_close(actual.interface_checks,expected.interface_checks;rtol=2e-8,atol=2e-9)
    @test _named_numeric_close(actual.boundary_checks,expected.boundary_checks;rtol=2e-8,atol=2e-8)
    @test _named_numeric_close(actual.conservation_checks,expected.conservation_checks;rtol=2e-8,atol=2e-8)
    println("SMGW_ORACLE_COMPARE=",label," scaled_residual_delta=",scaled_difference)
    flush(stdout)
    scaled_difference
end

function naive_centered_fd(input,g,state;order=3)
    baseline=Float64.(state)
    reference=O.assemble(input,g,baseline;order)
    rows=O.assemble(input,g,baseline;order,residual_only=true)
    @test rows==reference.residual
    jacobian=zeros(length(rows),length(baseline))
    step_scale=sqrt(eps(Float64))
    for column in eachindex(baseline)
        step=step_scale*max(1.0,abs(baseline[column]))
        plus=copy(baseline);minus=copy(baseline)
        plus[column]+=step
        minus[column]-=step
        plus_rows=O.assemble(input,g,plus;order,residual_only=true)
        minus_rows=O.assemble(input,g,minus;order,residual_only=true)
        jacobian[:,column].=(plus_rows.-minus_rows)./(2*step)
    end
    jacobian,reference
end

function assert_colored_fd_matches_naive(input,g,state,column_scales,label)
    colored=O.finite_difference_jacobian(input,g,state;order=3,row_masked=false)
    masked=O.finite_difference_jacobian(input,g,state;order=3,row_masked=true)
    naive,reference=naive_centered_fd(input,g,state;order=3)
    row_scale=Diagonal(1.0./reference.row_scales)
    column_scale=Diagonal(column_scales)
    colored_scaled=row_scale*colored*column_scale
    masked_scaled=row_scale*masked*column_scale
    naive_scaled=row_scale*naive*column_scale
    relative_error=norm(colored_scaled-naive_scaled,Inf)/
        max(norm(naive_scaled,Inf),eps(Float64))
    @test size(colored)==size(naive)==(length(reference.residual),length(state))
    @test all(isfinite,colored_scaled) && all(isfinite,masked_scaled) && all(isfinite,naive_scaled)
    @test masked==colored
    @test relative_error<=5.0e-6
    support_mask=trues(size(naive))
    for row in eachindex(reference.row_supports),column in reference.row_supports[row]
        support_mask[row,column]=false
    end
    @test all(iszero,naive[support_mask])
    @test all(iszero,colored[support_mask])
    println("SMGW_COLORED_FD_NAIVE_COMPARE=",label," scaled_relative_inf_error=",relative_error,
        " unsupported_entries=",count(identity,support_mask))
    flush(stdout)
    colored,naive,relative_error
end

function assert_row_masked_residual_matches_full_per_color(input,g,state,label)
    baseline=Float64.(state)
    reference=O.assemble(input,g,baseline;order=3)
    column_rows=O._fd_column_rows(reference.row_supports,length(baseline))
    coloring=O._fd_structural_colors(column_rows)
    steps=sqrt(eps(Float64)).*max.(1.0,abs.(baseline))
    covered=falses(length(reference.residual))
    full_fd=zeros(length(reference.residual),length(baseline))
    masked_fd=zeros(size(full_fd))
    for columns in coloring.columns
        row_mask=falses(length(reference.residual))
        for column in columns,row in column_rows[column]
            row_mask[row]=true
        end
        @test any(row_mask)
        covered .|= row_mask
        plus=copy(baseline);minus=copy(baseline)
        for column in columns
            plus[column]+=steps[column]
            minus[column]-=steps[column]
        end
        plus_full=O.assemble(input,g,plus;order=3,residual_only=true)
        minus_full=O.assemble(input,g,minus;order=3,residual_only=true)
        plus_masked=O.assemble(input,g,plus;order=3,residual_only=true,row_mask)
        minus_masked=O.assemble(input,g,minus;order=3,residual_only=true,row_mask)
        @test plus_masked[row_mask]==plus_full[row_mask]
        @test minus_masked[row_mask]==minus_full[row_mask]
        @test all(iszero,plus_masked[.!row_mask])
        @test all(iszero,minus_masked[.!row_mask])
        for column in columns,row in column_rows[column]
            full_fd[row,column]=(plus_full[row]-minus_full[row])/(2*steps[column])
            masked_fd[row,column]=(plus_masked[row]-minus_masked[row])/(2*steps[column])
        end
    end
    layout=reference.row_layout
    @test all(covered[layout.volume_rows.first:layout.volume_rows.last])
    @test all(covered[layout.boundary_trace_rows.first:layout.boundary_trace_rows.last])
    @test covered[layout.total_flux_row]
    interface_rhos=Set(g.rhos[2:end-1])
    interface_nodes=findall(q->q[1] in interface_rhos,reference.node_order)
    seam_nodes=findall(q->q[2]==0.0 || q[3]==0.0,reference.node_order)
    @test !isempty(interface_nodes) && !isempty(seam_nodes)
    interface_rows=[4(node-1)+component for node in interface_nodes for component in 1:4]
    seam_rows=[4(node-1)+component for node in seam_nodes for component in 1:4]
    @test all(covered[interface_rows])
    @test all(covered[seam_rows])
    @test masked_fd==full_fd
    @test_throws ArgumentError O.assemble(input,g,baseline;order=3,
        residual_only=true,row_mask=falses(length(reference.residual)-1))
    @test_throws ArgumentError O.assemble(input,g,baseline;order=3,
        residual_only=true,row_mask=falses(length(reference.residual)))
    @test_throws ArgumentError O.assemble(input,g,baseline;order=3,
        row_mask=trues(length(reference.residual)))
    @test_throws ArgumentError O.assemble(input,g,baseline;order=3,
        residual_only=true,row_mask=ones(Int,length(reference.residual)))
    println("SMGW_ROW_MASK_FULL_RESIDUAL_COMPARE=",label,
        " colors=",length(coloring.columns)," rows=",length(reference.residual),
        " columns=",length(baseline));flush(stdout)
    nothing
end

function test_quartic_ray_alpha_v1()
    @testset "Q1_8 quartic ray selector and conservative fallbacks" begin
        alpha=0.375
        r0=Float64[-alpha,alpha^2]
        b=Float64[1.0,-2alpha]
        r1=r0+b+Float64[0.0,1.0]
        selected=S._smgw_quartic_ray_alpha_v1(r0,b,r1)
        @test selected!==nothing
        @test isapprox(selected,alpha;rtol=2e-12,atol=2e-12)

        # Exercise the real Q1_8 factory and its consumer/operator policy binding.
        q1_8_input=S.spatial_n1_manufactured_input_v1(;level=:q1_8)
        q1_8_declaration=S.spatial_n1_manufactured_declaration_v1(q1_8_input)
        @test q1_8_declaration.solver.coarse_seconds==q1_8_input.numerics.seconds
        @test q1_8_declaration.source.input.numerics.seconds==_q1_real_consumer_spec(:q1_8).seconds
        @test S._smgw_validate_policy_v1(q1_8_declaration)
        # Routing checks supplement the actual producer/report evidence below.
        mapped_input=S.spatial_n1_manufactured_input_v1(;level=:q1_4,interior_map=:m1n1_ripple_v1)
        circular_input=S.spatial_n1_manufactured_input_v1(;level=:q1_4)
        coarse_mapped=S.spatial_n1_manufactured_input_v1(;level=:coarse,interior_map=:m1n1_ripple_v1)
        @test S._smgw_curvature_step_enabled_v1(mapped_input,:spatial_native)
        @test !S._smgw_curvature_step_enabled_v1(circular_input,:spatial_native)
        @test !S._smgw_curvature_step_enabled_v1(mapped_input,:inhouse_kkt)
        @test !S._smgw_curvature_step_enabled_v1(coarse_mapped,:spatial_native)
        @test S._smgw_curvature_step_enabled_v1(q1_8_input,:spatial_native)

        # A genuinely linear ray has no resolved quadratic term; caller keeps alpha0=1.
        linear_r0=Float64[1.0,0.0]
        linear_b=Float64[-0.5,0.0]
        @test S._smgw_quartic_ray_alpha_v1(linear_r0,linear_b,linear_r0+linear_b)===nothing
        @test S._smgw_quartic_ray_alpha_v1(linear_r0,linear_b,Float64[Inf,0.0])===nothing
        @test S._smgw_quartic_ray_alpha_v1(Float64[NaN,0.0],linear_b,linear_r0)===nothing

        A=sparse(Float64[1.0 0.0;0.0 2.0;1.0 1.0])
        r0=Float64[0.0,1.0,0.0]
        b=Float64[2.0,0.0,0.0]
        alpha_lm=0.25
        r1=r0+b+Float64[8.0,0.0,0.0]
        damping=S._smgw_lm_curvature_scale_v1(A,r0,b,r1,alpha_lm)
        @test damping!==nothing
        if damping!==nothing
            independent_ratio=alpha_lm*norm(Float64[8.0,0.0,0.0])/norm(b)
            independent_mean_column_norm2=sum(abs2,A)/size(A,2)
            independent_damping_factor=0.01*min(1.0,independent_ratio)^2
            @test damping.curvature_ratio==independent_ratio==1.0
            @test damping.mean_column_norm2==independent_mean_column_norm2==3.5
            @test damping.damping_factor==independent_damping_factor
            @test damping.lambda==independent_damping_factor*independent_mean_column_norm2
            step_identity=S._smgw_step_identity_v1(:spatial_native)
            @test step_identity.schema=="spatial-global-weak-step-identity-v7"
            @test step_identity.nonlinear_direction_policy===:q1_8_or_q1_4_m1n1_curvature_triggered_bounded_lm_chord_corrector_v1
            @test step_identity.curvature_step_scope==(q1_8=:existing_maps,q1_4=:m1n1_ripple_torus_only)
            @test step_identity.damping_rule===:actual_linear_gain_ratio_075_025_factor_tenth_ten_seed_1e_2_multiplier_1e5_100
            @test step_identity.chord_corrector===:quadratic_raw_ray_residual_shifted_lower_same_lambda_one_bounded_qr
            @test step_identity.selected_lm_ray_start===:quartic_minimizer_if_eligible_else_one
            native_test_hash=string(S.canonical_hash(step_identity))
            missing_lm_attempt=(selected_direction=:q1_8_bounded_lm_alternate,step=(0.0,))
            missing_lm_solver=(residual_partition=:spatial_native,step_identity=step_identity,step_identity_hash=native_test_hash,iterations=(),attempts=(missing_lm_attempt,))
            @test_throws ArgumentError S._smgw_verify_solver_step_identity_v1(missing_lm_solver)
            chord_raw=(0.0,0.4)
            chord_correction=(0.1,-0.2)
            chord_alpha=0.5
            chord_composite=Tuple(chord_alpha.*Float64.(collect(chord_raw)).+Float64.(collect(chord_correction)))
            valid_chord_lm=(schema="q1-8-bounded-lm-chord-corrector-v1",selected=true,status=:kkt_converged,
                corrector_kkt=(passed=true,),lambda=1.0,augmented_rank_evidence=:not_used_for_raw_rank,
                raw_step=chord_raw,correction_step=chord_correction,corrector_alpha=chord_alpha,
                selection_reason=:finite_kkt_feasible_descent,step=chord_composite,
                selected_lm_ray_alpha=nothing,line_search_alpha0=1.0,line_search_alpha_source=:alpha_one_fallback)
            valid_chord_attempt=(direction=:global_shared_q1_lower_bounded_sparse_QR,
                selected_direction=:q1_8_bounded_lm_alternate,lm_alternate=valid_chord_lm,step=chord_composite)
            valid_chord_solver=(residual_partition=:spatial_native,step_identity=step_identity,
                step_identity_hash=native_test_hash,iterations=(),attempts=(valid_chord_attempt,))
            @test S._smgw_verify_solver_step_identity_v1(valid_chord_solver)===:spatial_native
            mapped_lm=merge(valid_chord_lm,(schema="q1-4-m1n1-bounded-lm-chord-corrector-v1",))
            mapped_attempt=merge(valid_chord_attempt,
                (selected_direction=:q1_4_m1n1_bounded_lm_alternate,lm_alternate=mapped_lm))
            mapped_solver=merge(valid_chord_solver,(attempts=(mapped_attempt,),))
            @test S._smgw_verify_solver_step_identity_v1(mapped_solver)===:spatial_native
            for (attempt,wrong_lm) in ((mapped_attempt,valid_chord_lm),(valid_chord_attempt,mapped_lm))
                wrong_schema_solver=merge(valid_chord_solver,
                    (attempts=(merge(attempt,(lm_alternate=wrong_lm,)),),))
                @test_throws ArgumentError S._smgw_verify_solver_step_identity_v1(wrong_schema_solver)
            end
            # Refined m1n1 records carry a real augmented KKT chain; Q1_8 stays v1.
            refine_A=sparse(Matrix{Float64}(I,4,4));refine_aug=vcat(refine_A,refine_A)
            refine_raw=zeros(4);refine_initial=fill(0.1,4);refine_correction=fill(0.2,4)
            refine_residual=fill(-0.4,4);refine_lower=Float64[-Inf,-Inf,-Inf,-0.1]
            refine_kkt=S.SpatialBoundedLinearStepV1.bounded_step_kkt_v1(
                refine_aug,vcat(refine_residual,zeros(4)),refine_lower,refine_correction,Int[])
            @test refine_kkt.passed
            refine_final=refine_initial.+refine_correction
            refine_entry=(inner=1,eligible=true,kkt=refine_kkt,
                kkt_scope=:local_augmented_shifted_lower_bound_subproblem,
                correction=Tuple(refine_correction),residual=Tuple(refine_residual),
                lower=(nothing,nothing,nothing,-0.1),before_composite=Tuple(refine_initial),
                resulting_composite=Tuple(refine_final),cache_pass=true,refactor=false,active_indices=())
            refinement=(schema="m1n1-bounded-chord-refinement-v1",selected=true,
                shared_seconds_limit=6.0,extra_corrector_limit=2,elapsed_seconds=0.25,
                baseline_objective=1.0,selected_objective=0.5,
                initial_composite=Tuple(refine_initial),selected_chain=(refine_entry,))
            refined_lm=merge(mapped_lm,(schema="q1-4-m1n1-bounded-lm-chord-refined-v2",
                raw_step=Tuple(refine_raw),correction_step=Tuple(refine_initial),
                step=Tuple(refine_final),refinement=refinement,
                corrector_kkt_scope=:initial_chord_augmented_shifted_lower_bound_subproblem))
            refined_attempt=merge(mapped_attempt,(step=Tuple(refine_final),lm_alternate=refined_lm,
                linear_input=(rows=4,columns=4,matrix=(row_indices=(1,2,3,4),
                    column_indices=(1,2,3,4),values=(1.0,1.0,1.0,1.0)),)))
            refined_solver=merge(mapped_solver,(attempts=(refined_attempt,),))
            @test S._smgw_verify_solver_step_identity_v1(refined_solver)===:spatial_native
            for bad_refinement in (merge(refinement,(elapsed_seconds=6.01,)),
                    merge(refinement,(extra_corrector_limit=3,)),
                    merge(refinement,(selected_objective=1.0,)),
                    merge(refinement,(selected_chain=(merge(refine_entry,(correction=(0.2,0.2,0.2,-0.2),)),),)),
                    merge(refinement,(selected_chain=(merge(refine_entry,(before_composite=(0.2,0.1,0.1,0.1),)),),)),
                    merge(refinement,(selected_chain=(merge(refine_entry,(resulting_composite=(0.4,0.3,0.3,0.3),)),),)))
                bad_attempt=merge(refined_attempt,(lm_alternate=merge(refined_lm,(refinement=bad_refinement,)),))
                @test_throws ArgumentError S._smgw_verify_solver_step_identity_v1(
                    merge(refined_solver,(attempts=(bad_attempt,),)))
            end
            for bad_lm in (merge(refined_lm,(schema="q1-4-m1n1-bounded-lm-chord-corrector-v1",)),
                    merge(refined_lm,(refinement=nothing,)),merge(refined_lm,(refinement=(selected=1,),)),
                    merge(refined_lm,(lambda=-1.0,)),merge(refined_lm,(lambda=NaN,)),
                    merge(refined_lm,(lambda=Inf,)),merge(refined_lm,(corrector_kkt_scope=:wrong_scope,)),
                    Base.structdiff(refined_lm,(corrector_kkt_scope=nothing,)))
                @test_throws ArgumentError S._smgw_verify_solver_step_identity_v1(
                    merge(refined_solver,(attempts=(merge(refined_attempt,(lm_alternate=bad_lm,)),),)))
            end
            @test_throws ArgumentError S._smgw_verify_solver_step_identity_v1(
                merge(refined_solver,(attempts=(merge(refined_attempt,
                    (selected_direction=:q1_8_bounded_lm_alternate,)),),)))
            # An expired deadline cannot assemble or replace the original chord.
            expired_chord=(composite=copy(refine_initial),correction=copy(refine_initial),
                solved=(active_indices=(),free_indices=(1,2,3,4)))
            expired=S._smgw_m1n1_refine_chord_v1(refine_A,refine_residual,zeros(4),ones(4),
                refine_raw,0.5,expired_chord,1.0,ones(4),(:test,:test,:test,:test),
                _->error("expired refinement must not assemble"),()->nothing,time()-1.0)
            @test !expired.selected && expired.step==expired_chord.composite
            @test expired.record.status===:time_ineligible && isempty(expired.record.selected_chain)
            @test any(e->e.stage===:baseline_ray && e.reason===:deadline_reached && !e.time_eligible,
                expired.record.events)
            for (bad_step,reason) in ((fill(-0.1,4),:non_descent),
                    (Float64[0.1,0.1,0.1,-0.1],:pressure_or_nonfinite_endpoint))
                bad_chord=merge(expired_chord,(composite=bad_step,))
                rejected=S._smgw_m1n1_refine_chord_v1(refine_A,refine_residual,zeros(4),ones(4),
                    refine_raw,0.5,bad_chord,1.0,ones(4),(:test,:test,:test,:test),
                    _->error("rejected baseline must not assemble"),()->nothing,Inf)
                @test !rejected.selected && rejected.step==bad_step
                @test any(e->e.stage===:baseline_ray && e.reason===reason,rejected.record.events)
                if reason===:pressure_or_nonfinite_endpoint
                    @test only(filter(e->e.stage===:baseline_ray,rejected.record.events)).pressure_violating_columns==(4,)
                end
            end
            # Endpoint reuse is local to one exact chord state, not a historical
            # assembly or an accepted alpha<1 state masquerading as full endpoint.
            cache_blocks=(:test,:test,:test,:test);cache_scales=ones(4)
            cache_binding=repeat("a",64);foreign_cache_binding=repeat("b",64)
            cache_seed=(state=copy(refine_initial),assembly=(residual=refine_initial.-1.0,
                row_scales=cache_scales,row_blocks=cache_blocks),binding=cache_binding)
            for bad_seed in (merge(cache_seed,(state=zeros(4),)),
                    merge(cache_seed,(assembly=merge(cache_seed.assembly,(row_blocks=(:wrong,:test,:test,:test),)),)),
                    merge(cache_seed,(assembly=merge(cache_seed.assembly,(row_scales=fill(2.0,4),)),)),
                    merge(cache_seed,(binding=foreign_cache_binding,)),
                    merge(cache_seed,(assembly=merge(cache_seed.assembly,(residual=fill(NaN,4),)),)))
                @test_throws ArgumentError S._smgw_m1n1_refine_chord_v1(refine_A,fill(-1.0,4),
                    zeros(4),ones(4),refine_raw,0.5,expired_chord,1.0,cache_scales,cache_blocks,
                    _->error("invalid endpoint must be rejected before assembly"),()->cache_binding,Inf;
                    initial_endpoint=bad_seed)
            end
            plain_calls=Ref(0);seeded_calls=Ref(0)
            plain_assembly=z->begin
                plain_calls[]+=1;(residual=z.-1.0,row_scales=cache_scales,row_blocks=cache_blocks)
            end
            seeded_assembly=z->begin
                seeded_calls[]+=1;(residual=z.-1.0,row_scales=cache_scales,row_blocks=cache_blocks)
            end
            plain=S._smgw_m1n1_refine_chord_v1(refine_A,fill(-1.0,4),zeros(4),ones(4),
                refine_raw,0.5,expired_chord,1.0,cache_scales,cache_blocks,plain_assembly,()->cache_binding,Inf)
            seeded=S._smgw_m1n1_refine_chord_v1(refine_A,fill(-1.0,4),zeros(4),ones(4),
                refine_raw,0.5,expired_chord,1.0,cache_scales,cache_blocks,seeded_assembly,()->cache_binding,Inf;
                initial_endpoint=cache_seed)
            @test plain.selected && seeded.selected && plain.step==seeded.step
            @test plain.ray.objective==seeded.ray.objective<seeded.record.baseline_objective
            @test plain.ray.state==seeded.ray.state
            @test plain_calls[]==seeded_calls[]+1
            # The external seed cost remains one assembly: no end-to-end free-work claim.
            @test seeded_calls[]+1==plain_calls[]
            @test any(e->e.stage===:endpoint_cache && e.reason===:reused &&
                e.consumer_stage===:baseline_ray,seeded.record.events)
            @test any(e->e.stage===:endpoint_cache && e.reason===:reused &&
                e.consumer_stage===:inner_corrector,seeded.record.events)
            @test length(seeded.record.selected_chain)==1
            @test any(e->e.stage===:inner_corrector && e.reason===:first_improvement_selected &&
                e.inner==1,seeded.record.events)
            @test !any(e->hasproperty(e,:inner) && e.inner==2,seeded.record.events)
            old_identity=merge(step_identity,(schema="spatial-global-weak-step-identity-v6",))
            old_identity_solver=merge(mapped_solver,(step_identity=old_identity,
                step_identity_hash=string(S.canonical_hash(old_identity))))
            @test_throws ArgumentError S._smgw_verify_solver_step_identity_v1(old_identity_solver)
            wrong_composite=(chord_composite[1],chord_composite[2]+0.1)
            wrong_chord_lm=merge(valid_chord_lm,(step=wrong_composite,))
            wrong_chord_attempt=merge(valid_chord_attempt,(step=wrong_composite,lm_alternate=wrong_chord_lm))
            wrong_chord_solver=merge(valid_chord_solver,(attempts=(wrong_chord_attempt,),))
            @test_throws ArgumentError S._smgw_verify_solver_step_identity_v1(wrong_chord_solver)
            bool_alpha_lm=merge(valid_chord_lm,(line_search_alpha0=true,selected_lm_ray_alpha=0.5,
                line_search_alpha_source=:quartic_selected))
            bool_alpha_attempt=merge(valid_chord_attempt,(lm_alternate=bool_alpha_lm,))
            bool_alpha_solver=merge(valid_chord_solver,(attempts=(bool_alpha_attempt,),))
            @test_throws ArgumentError S._smgw_verify_solver_step_identity_v1(bool_alpha_solver)
        end
        @test S._smgw_step_identity_v1(:inhouse_kkt).schema=="spatial-global-weak-step-identity-v1"
        @test S._smgw_step_identity_v1(:inhouse_kkt).partition_mode===:inhouse_kkt

        # The real gain ratio compares reductions in the same squared-residual merit.
        merit_before=dot(Float64[1.0,0.0],Float64[1.0,0.0])
        merit_linear=dot(Float64[0.5,0.0],Float64[0.5,0.0])
        predicted_reduction=merit_before-merit_linear
        high_actual_residual=Float64[sqrt(0.4),0.0]
        low_actual_residual=Float64[sqrt(0.85),0.0]
        high_actual_reduction=merit_before-dot(high_actual_residual,high_actual_residual)
        low_actual_reduction=merit_before-dot(low_actual_residual,low_actual_residual)
        high_gain_ratio=high_actual_reduction/predicted_reduction
        low_gain_ratio=low_actual_reduction/predicted_reduction
        @test isapprox(high_gain_ratio,0.8;atol=2*eps(Float64),rtol=0)
        @test isapprox(low_gain_ratio,0.2;atol=2*eps(Float64),rtol=0)
        @test S._smgw_lm_next_damping_multiplier_v1(1.0,high_gain_ratio)==0.1
        @test S._smgw_lm_next_damping_multiplier_v1(1.0,low_gain_ratio)==10.0
        @test S._smgw_lm_next_damping_multiplier_v1(0.2,0.75)==0.2
        @test S._smgw_lm_next_damping_multiplier_v1(0.2,0.25)==0.2
        @test S._smgw_lm_next_damping_multiplier_v1(1.0,NaN)==1.0
        @test S._smgw_lm_next_damping_multiplier_v1(1.0,Inf)==1.0
        floor_multiplier=1.0
        for _ in 1:12
            floor_multiplier=S._smgw_lm_next_damping_multiplier_v1(floor_multiplier,0.9)
        end
        @test floor_multiplier==1.0e-5
        ceiling_multiplier=1.0
        for _ in 1:5
            ceiling_multiplier=S._smgw_lm_next_damping_multiplier_v1(ceiling_multiplier,0.1)
        end
        @test ceiling_multiplier==1.0e2
        @test_throws ArgumentError S._smgw_lm_next_damping_multiplier_v1(0.0,0.9)
        @test_throws ArgumentError S._smgw_lm_next_damping_multiplier_v1(prevfloat(1.0e-5),0.9)
        @test_throws ArgumentError S._smgw_lm_next_damping_multiplier_v1(1.0e2+1.0,0.1)
        @test_throws ArgumentError S._smgw_lm_next_damping_multiplier_v1(NaN,0.9)
        @test_throws ArgumentError S._smgw_lm_next_damping_multiplier_v1(Inf,0.9)
        low_multiplier_scale=S._smgw_lm_curvature_scale_v1(A,r0,b,r1,alpha_lm;
            damping_multiplier=1.0e-5)
        @test low_multiplier_scale!==nothing
        if low_multiplier_scale!==nothing
            @test isapprox(low_multiplier_scale.lambda,1.0e-5*independent_damping_factor*independent_mean_column_norm2;atol=0,rtol=4*eps(Float64))
        end
        ceiling_multiplier_scale=S._smgw_lm_curvature_scale_v1(A,r0,b,r1,alpha_lm;
            damping_multiplier=1.0e2)
        @test ceiling_multiplier_scale!==nothing
        if ceiling_multiplier_scale!==nothing
            @test isapprox(ceiling_multiplier_scale.lambda,1.0e2*independent_damping_factor*independent_mean_column_norm2;atol=0,rtol=4*eps(Float64))
        end
        @test S._smgw_lm_curvature_scale_v1(A,r0,b,r1,alpha_lm;
            damping_multiplier=0.0)===nothing
        @test S._smgw_lm_curvature_scale_v1(A,r0,b,r1,alpha_lm;
            damping_multiplier=prevfloat(1.0e-5))===nothing
        @test S._smgw_lm_curvature_scale_v1(A,r0,b,r1,alpha_lm;
            damping_multiplier=1.0e2+1.0)===nothing
        @test S._smgw_lm_curvature_scale_v1(A,r0,b,r1,alpha_lm;
            damping_multiplier=NaN)===nothing
        @test S._smgw_lm_curvature_scale_v1(A,r0,b,r1,alpha_lm;
            damping_multiplier=Inf)===nothing
        # Subunit curvature ratio exercises the squared ratio term independently.
        subunit_r1=r0+b+Float64[6.0,0.0,0.0]
        subunit=S._smgw_lm_curvature_scale_v1(A,r0,b,subunit_r1,alpha_lm)
        @test subunit!==nothing
        if subunit!==nothing
            subunit_ratio=alpha_lm*norm(Float64[6.0,0.0,0.0])/norm(b)
            subunit_mean_column_norm2=sum(abs2,A)/size(A,2)
            subunit_factor=0.01*min(1.0,subunit_ratio)^2
            @test subunit.curvature_ratio==subunit_ratio==0.75
            @test subunit.damping_factor==subunit_factor
            @test subunit.lambda==subunit_factor*subunit_mean_column_norm2
        end
        @test S._smgw_lm_curvature_scale_v1(A,r0,b,r1,0.5)===nothing
        @test S._smgw_lm_curvature_scale_v1(A,r0,b,r0+b+Float64[4.0,0.0,0.0],alpha_lm)===nothing
        @test S._smgw_lm_curvature_scale_v1(A,r0,b,r0+b,alpha_lm)===nothing
        @test S._smgw_lm_curvature_scale_v1(A,r0,b,Float64[Inf,0.0,0.0],alpha_lm)===nothing

        @testset "quadratic raw-ray chord corrector uses shifted feasible bounds once" begin
            A_chord=sparse(Matrix{Float64}(I,3,3))
            r0_chord=Float64[1.0,0.0,0.0]
            b_chord=Float64[-1.0,0.0,4.0]
            q_chord=Float64[0.0,-1.0,0.0]
            alpha_chord=0.5
            raw_step_chord=Float64[0.0,0.4,0.4]
            lower_chord=Float64[-Inf,0.0,0.0]
            inputs=S._smgw_lm_chord_corrector_inputs_v1(r0_chord,b_chord,q_chord,
                alpha_chord,raw_step_chord,lower_chord)
            @test inputs!==nothing
            if inputs!==nothing
                @test inputs.residual==Float64[0.5,-0.25,2.0]
                @test inputs.lower==Float64[-Inf,-0.2,-0.2]
                @test all(v->v<=0.0,inputs.lower)
                @test inputs.shifted_finite_bounds==2
            end

            stage_name="test_q1_8_lm_chord_corrector"
            stage_events=Tuple{String,Symbol}[]
            stage_trace=(name,edge,stamp)->push!(stage_events,(String(name),Symbol(edge)))
            result=S._smgw_lm_chord_corrector_v1(A_chord,r0_chord,b_chord,q_chord,
                alpha_chord,raw_step_chord,lower_chord,0.1;seconds=6.0,
                stage_trace=stage_trace,stage_name=stage_name)
            @test result!==nothing
            if result!==nothing
                @test result.valid
                @test result.solved.converged
                @test result.solved.kkt.passed
                @test result.solved.active_indices==(3,)
                @test 2 in result.solved.free_indices
                @test isapprox(result.correction,Float64[-0.5/1.1,0.25/1.1,-0.2];
                    rtol=0.0,atol=2e-12)
                @test result.composite==alpha_chord.*raw_step_chord.+result.correction
                @test result.composite[2]>0.0
                @test abs(result.composite[3])<=2e-12
                @test count(event->event==(stage_name,:begin),stage_events)==1
            end

            @test S._smgw_lm_chord_corrector_inputs_v1(r0_chord,b_chord,q_chord,
                1.0,raw_step_chord,lower_chord)===nothing
            @test S._smgw_lm_chord_corrector_inputs_v1(r0_chord,b_chord,q_chord[1:2],
                alpha_chord,raw_step_chord,lower_chord)===nothing
            q_nonfinite=Float64[0.0,Inf,0.0]
            @test S._smgw_lm_chord_corrector_inputs_v1(r0_chord,b_chord,q_nonfinite,
                alpha_chord,raw_step_chord,lower_chord)===nothing
            infeasible_raw_step=Float64[0.0,-0.4,0.4]
            @test S._smgw_lm_chord_corrector_inputs_v1(r0_chord,b_chord,q_chord,
                alpha_chord,infeasible_raw_step,lower_chord)===nothing
            invalid_events=Tuple{String,Symbol}[]
            invalid_trace=(name,edge,stamp)->push!(invalid_events,(String(name),Symbol(edge)))
            @test S._smgw_lm_chord_corrector_v1(A_chord,r0_chord,b_chord,q_chord,
                1.0,raw_step_chord,lower_chord,1.0;stage_trace=invalid_trace,
                stage_name="invalid_q1_8_lm_chord_corrector")===nothing
            @test isempty(invalid_events)
        end
    end
    nothing
end

function test_canonical_tuple_view_v1()
    @testset "canonical tuple view preserves legacy tuple identity" begin
        legacy=(
            (entity_id=1,qp_id=1,weight=0.125,normal=(1.0,0.0,0.0)),
            (entity_id=2,qp_id=1,weight=0.25,normal=(0.0,1.0,0.0)),
            (entity_id=3,qp_id=1,weight=0.5,normal=(0.0,0.0,1.0)))
        values=collect(legacy)
        wrapped=S._smgw_tuple_view_v1(values)
        wrapped_again=S._smgw_tuple_view_v1(copy(values))
        legacy_json=canonical_json(legacy)
        legacy_hash=canonical_hash(legacy)
        wrapped_json=canonical_json(wrapped)
        wrapped_hash=canonical_hash(wrapped)

        @test wrapped_json==legacy_json
        @test wrapped_hash==legacy_hash
        @test canonical_json(wrapped)==wrapped_json
        @test canonical_hash(wrapped)==wrapped_hash
        @test canonical_json(wrapped_again)==wrapped_json
        @test canonical_hash(wrapped_again)==wrapped_hash

        reordered=S._smgw_tuple_view_v1(reverse(copy(values)))
        @test canonical_json(reordered)!=legacy_json
        @test canonical_hash(reordered)!=legacy_hash

        changed=copy(values)
        changed[2]=merge(changed[2],(weight=nextfloat(changed[2].weight),))
        changed_view=S._smgw_tuple_view_v1(changed)
        @test canonical_json(changed_view)!=legacy_json
        @test canonical_hash(changed_view)!=legacy_hash
    end
    nothing
end

function test_canonical_matrix_fragment_v1()
    @testset "3x3 matrix fragment preserves canonical shape and column-major values" begin
        matrix = Float64[1 4 7; 2 5 8; 3 6 9]
        old_projection = (shape=Tuple(size(matrix)), values=Tuple(vec(matrix)))
        fragment = S._smgw_array_view_v1(matrix, "test 3x3 matrix")

        @test canonical_json(fragment) == canonical_json(old_projection)
        @test canonical_hash(fragment) == canonical_hash(old_projection)
        @test canonical_json(fragment) == FusionConceptAI._canonical(matrix)

        reordered = permutedims(matrix, (2, 1))
        reordered_fragment = S._smgw_array_view_v1(reordered, "reordered 3x3 matrix")
        @test canonical_json(reordered_fragment) != canonical_json(fragment)
        @test canonical_hash(reordered_fragment) != canonical_hash(fragment)

        changed = copy(matrix)
        changed[2, 3] = nextfloat(changed[2, 3])
        changed_fragment = S._smgw_array_view_v1(changed, "changed 3x3 matrix")
        @test canonical_json(changed_fragment) != canonical_json(fragment)
        @test canonical_hash(changed_fragment) != canonical_hash(fragment)
        @test_throws ArgumentError S._smgw_array_view_v1(
            [1.0 4.0 7.0; 2.0 NaN 8.0; 3.0 6.0 9.0], "nonfinite 3x3 matrix")
    end
    nothing
end

function test_fd_coloring_matches_naive_v1()
    @testset "Q1_2 colored centered FD matches every naive column" begin
        input=S.spatial_n1_manufactured_input_v1()
        g=O.grid(collect(input.mesh.rho),input.mesh.theta_count,
            input.mesh.zeta_per_period*input.mesh.nfp)
        state=O.initial_nodal_state(input,g)
        declaration=S.spatial_n1_manufactured_declaration_v1(input)
        columns=repeat([declaration.scaling.B_T,declaration.scaling.B_T,
            declaration.scaling.B_T,declaration.scaling.p_Pa],div(length(state),4))
        colored,naive,relative_error=assert_colored_fd_matches_naive(
            input,g,state,columns,"initial_q1_2")
        @test size(colored)==(57,40)
        @test relative_error<=5.0e-6

        mixed_state=copy(state)
        for dof in eachindex(mixed_state)
            mixed_state[dof]+=0.013*columns[dof]*sin(0.7*dof)
        end
        mixed_colored,mixed_naive,mixed_relative_error=assert_colored_fd_matches_naive(
            input,g,mixed_state,columns,"mixed_nonlinear_q1_2")
        assert_row_masked_residual_matches_full_per_color(
            input,g,mixed_state,"mixed_nonlinear_q1_2")
        row_scale=Diagonal(1.0./O.assemble(input,g,state;order=3).row_scales)
        column_scale=Diagonal(columns)
        @test norm(row_scale*mixed_colored*column_scale-
            row_scale*colored*column_scale,Inf)>1.0e-8
        @test mixed_relative_error<=5.0e-6
    end
    nothing
end

"""Opt-in oracle check for the source-bound m=1,n=1 coordinate map."""
function test_m1n1_geometry_oracle_v1()
    input = S.spatial_n1_manufactured_input_v1(; level=:coarse,
        interior_map=:m1n1_ripple_v1)
    @testset "independent m1n1 chart, metric, normals, volume, and flux" begin
        @test S.validate_spatial_manufactured_input_v1(input)
        a = Float64(input.geometry.minor_radius_m)
        r0 = Float64(input.geometry.R0_m)
        eps = Float64(input.geometry.ripple_amplitude)
        beta = Float64(input.fields.beta_T_m)
        tuple_matrix = rows -> [rows[i][j] for i in 1:3, j in 1:3]
        law = input.boundary.normal_law
        @test law.schema == "spatial-manufactured-normal-field-law-v1"
        @test law.model === :m1n1_analytic_B_dot_outward_unit_conormal
        @test law.geometry_map_hash == canonical_hash(input.geometry)
        @test law.field.model === :beta_R_e_phi
        @test law.field.beta_T_m == beta
        @test law.field.unit == "T m^-1"
        @test law.field.unit_signature == S.UnitSignature((1,-1,-2,-1,0,0,0))
        @test law.field.component_law === :B_cyl_equals_0_beta_R_0
        @test law.field_hash == canonical_hash(law.field)
        @test law.conormal.coordinate === :rho
        @test law.conormal.location === :rho_1
        @test law.conormal.direction === :outward_increasing_rho
        @test law.conormal.construction === :normalized_E_inverse_transpose_e_rho
        @test law.conormal.unnormalized_phi_component === :rho_epsilon_sin_zeta_over_D_R
        @test law.conormal.physical_type.value_kind === :outward_unit_conormal
        @test law.conormal.physical_type.tensor_rank == 1
        @test law.conormal.physical_type.spatial_dimension == 3
        @test law.conormal.physical_type.units == S.UnitSignature()
        @test law.conormal.physical_type.temporal_type.kind === S.static_time
        @test law.formula === :beta_a_rho_epsilon_sin_zeta_over_sqrt_D_plus_metric_term
        @test law.formula_text == "beta*a*rho*epsilon*sin(zeta)/sqrt(D+(a*rho*epsilon*sin(zeta)/R)^2)"
        @test law.formula_parameters.D === :one_plus_epsilon_squared_plus_two_epsilon_cos_zeta
        @test law.formula_parameters.R === :m1n1_mapped_cylindrical_major_radius
        @test law.formula_parameters.map_hash == law.geometry_map_hash
        @test law.output.quantity === :B_dot_outward_conormal
        @test law.output.unit == "T"
        @test law.output.unit_signature == S.UnitSignature((1,0,-2,-1,0,0,0))
        @test law.output.physical_type.value_kind === :normal_magnetic_field
        @test law.output.physical_type.tensor_rank == 0
        @test law.output.physical_type.spatial_dimension == 0
        @test law.output.physical_type.temporal_type.kind === S.static_time
        @test law.output.physical_type.units == law.output.unit_signature
        @test law.evaluation === :pointwise_outer_face_quadrature
        @test law.no_constant_scalar === true
        @test input.boundary.analytic_normal_B_T === nothing
        declaration = S.spatial_n1_manufactured_declaration_v1(input)
        @test declaration.boundary.normal_B_T === nothing
        @test declaration.boundary.normal_law.input_hash == canonical_hash(input)
        @test canonical_hash(declaration.boundary.normal_law) ==
            canonical_hash(merge(law, (input_hash=canonical_hash(input),)))
        @test S._smm_validate_m1n1_normal_law_v1(input,
            declaration.boundary.normal_law; bind_input=true)
        wrong_map_law = merge(declaration.boundary.normal_law,
            (geometry_map_hash=canonical_hash((wrong_geometry_map=:rehashed_test_control,)),))
        @test_throws ArgumentError S._smm_validate_m1n1_normal_law_v1(input,
            wrong_map_law; bind_input=true)
        samples = ((0.31, 0.23, 0.41), (0.72, 1.17, 2.03),
            (1.0, 2.21, 0.73))
        for q in samples
            rho, theta, zeta = q
            c, s, D, R, Z = O._independent_map_terms(input, rho, theta, zeta)
            xyz, E, Q = O._geometry(input, q)
            expected_xyz = (R*cos(zeta), R*sin(zeta), Z)
            expected_det = -R*a^2*rho*D
            invE = O._m1n1_inverse(input, q)
            @test collect(xyz) ≈ collect(expected_xyz) rtol=2e-14 atol=2e-14
            @test E*invE ≈ Matrix{Float64}(I, 3, 3) rtol=2e-13 atol=2e-13
            @test invE*E ≈ Matrix{Float64}(I, 3, 3) rtol=2e-13 atol=2e-13
            @test det(E) ≈ expected_det rtol=2e-14 atol=2e-14

            chart = S.spatial_manufactured_chart_value_v1(input,
                (rho, theta/(2pi), zeta/(2pi)))
            @test collect(chart.coordinate) ≈ collect(expected_xyz) rtol=2e-13 atol=2e-13
            @test tuple_matrix(chart.raw_E) ≈ E rtol=2e-13 atol=2e-13
            @test chart.signed_raw_detE ≈ expected_det rtol=2e-13 atol=2e-13
            @test tuple_matrix(chart.raw_metric) ≈ transpose(E)*E rtol=2e-13 atol=2e-13
            @test tuple_matrix(chart.raw_cartesian_jacobian) ≈ Q*E rtol=2e-13 atol=2e-13

            for axis in 1:3
                sample = S._smm_sample_v1(input, 1, 1, q, 1.0, axis)
                tangents = filter(!=(axis), 1:3)
                area_vector = axis == 1 ? cross(E[:,3], E[:,2]) :
                    axis == 2 ? cross(E[:,1], E[:,3]) : cross(E[:,2], E[:,1])
                expected_normal = Q*(area_vector/norm(area_vector))
                expected_area = norm(cross(E[:,tangents[1]], E[:,tangents[2]]))
                @test collect(sample.normal) ≈ expected_normal rtol=2e-13 atol=2e-13
                @test sample.weight ≈ expected_area rtol=2e-13 atol=2e-13
            end

            # The rippled outer surface is not everywhere tangent to toroidal B.
            sample = S._smm_sample_v1(input, 1, 1, q, 1.0, 1)
            normal_cyl = transpose(Q)*collect(sample.normal)
            bdotn = beta*R*normal_cyl[2]
            grad_rho_norm = sqrt(1/(a^2*D) +
                rho^2*eps^2*sin(zeta)^2/(D^2*R^2))
            expected_bdotn = beta*rho*eps*sin(zeta)/(D*grad_rho_norm)
            @test bdotn ≈ expected_bdotn rtol=2e-12 atol=2e-12
            if zeta == 0.41
                @test abs(bdotn) > 1e-8
            end
        end

        # Exercise both signs and the symmetry zeros in the authored boundary
        # law, independently from the production evaluator.
        independent_bn(q) = begin
            rho, theta, zeta = q
            _, _, D, R, _ = O._independent_map_terms(input, rho, theta, zeta)
            beta*a*rho*eps*sin(zeta) /
                sqrt(D+(a*rho*eps*sin(zeta)/R)^2)
        end
        for zeta in (pi/2, -pi/2, 0.0, pi)
            q = (1.0, 0.37, Float64(zeta))
            _, _, _, R, _ = O._independent_map_terms(input, q...)
            _, _, Qz = O._geometry(input, q)
            expected = independent_bn(q)
            observed = S._smm_m1n1_normal_value_validated_v1(input, q, R)
            sample = S._smm_sample_v1(input, 1, 1, q, 1.0, 1)
            normal_cyl = transpose(Qz)*collect(sample.normal)
            @test observed ≈ expected rtol=2e-13 atol=2e-13
            @test beta*R*normal_cyl[2] ≈ expected rtol=2e-13 atol=2e-13
            if zeta == pi/2
                @test expected > 0.0
            elseif zeta == -pi/2
                @test expected < 0.0
            else
                @test expected ≈ 0.0 atol=2e-14
            end
        end

        # Build and load the actual source samples, then verify both existing
        # production consumers use the bound pointwise law. No solver runs.
        mktempdir() do geometry_dir
            binding = (candidate_hash=canonical_hash((scope=:m1n1_geometry_test,)),
                context_hash=canonical_hash((scope=:m1n1_geometry_context_test,)))
            receipt = S._smm_materialize_geometry_v1(input, declaration, binding,
                geometry_dir)
            data = S.load_spatial_data_v4(declaration,
                (level=input.mesh.level, nfp=input.mesh.nfp,
                    flux_Wb=input.flux.nominal_Wb, raw_artifacts=receipt.raw_artifacts))
            independent_flux = sum(s.weight*independent_bn(s.q)
                for s in data.face_quadrature if data.mesh.faces[s.entity_id].role === :exterior)
            texts = S._smr_current_texts(data, data.initial_state; declaration)
            @test texts.diagnostics.manufactured_loads.prescribed_outer_normal_flux_Wb ≈
                independent_flux rtol=2e-12 atol=2e-12
            sampled_mismatch = maximum(abs(dot(S.spatial_field_v4(data,
                data.mesh.faces[s.entity_id].left_cell, s, data.initial_state).B_xyz,
                collect(s.normal)) - independent_bn(s.q)) for s in data.face_quadrature
                if data.mesh.faces[s.entity_id].role === :exterior)
            @test texts.diagnostics.manufactured_loads.outer_normal_field_mismatch_peak_T ≈
                sampled_mismatch rtol=2e-12 atol=2e-12
            @test maximum(abs(independent_bn(s.q)) for s in data.face_quadrature
                if data.mesh.faces[s.entity_id].role === :exterior) > 1e-8
            surface_flux = 0.0
            ntheta_surface, nzeta_surface = 64, 64
            for itheta in 0:ntheta_surface-1, izeta in 0:nzeta_surface-1
                theta = 2pi*(itheta+0.5)/ntheta_surface
                zeta = 2pi*(izeta+0.5)/nzeta_surface
                q = (1.0, theta, zeta)
                _, E, _ = O._geometry(input, q)
                area = norm(cross(E[:,2], E[:,3]))
                surface_flux += independent_bn(q)*area*
                    (2pi/ntheta_surface)*(2pi/nzeta_surface)
            end
            @test abs(surface_flux) <= 2e-12

            assembly = S.assemble_spatial_system_v4(declaration, data,
                data.initial_state; jacobian=false)
            expected_trace_rows = zeros(length(assembly.residual))
            for s in data.face_quadrature
                face = data.mesh.faces[s.entity_id]
                face.role === :exterior || continue
                field = S.spatial_field_v4(data, face.left_cell, s, data.initial_state)
                n = collect(s.normal)
                expected_bn = independent_bn(s.q)
                trace = findall(a -> data.mesh.nodes_q[1,field.ids[a]] == 1.0,
                    eachindex(field.ids))
                firstrow = data.mesh.exterior_row_start[s.entity_id]
                for (i,j) in enumerate(trace)
                    row = firstrow + 4*(i-1) + 3
                    expected_trace_rows[row] += s.weight*field.N[j]*
                        (dot(field.B_xyz,n)-expected_bn)
                end
            end
            normal_trace_rows = Int[]
            for (fid, firstrow) in data.mesh.exterior_row_start
                face = data.mesh.faces[fid]
                face.role === :exterior || continue
                first_face_sample = first(s for s in data.face_quadrature if s.entity_id == fid)
                fl = S.spatial_field_v4(data, face.left_cell, first_face_sample,
                    data.initial_state)
                trace = count(a -> data.mesh.nodes_q[1,fl.ids[a]] == 1.0,
                    eachindex(fl.ids))
                append!(normal_trace_rows, (firstrow + 4*(i-1) + 3 for i in 1:trace))
            end
            @test !isempty(normal_trace_rows)
            @test assembly.residual[normal_trace_rows] ≈
                expected_trace_rows[normal_trace_rows] rtol=2e-12 atol=2e-12
        end

        # Tensor midpoint in the periodic coordinates and 3-point Gauss in rho
        # independently recover the exact ripple volume and zeta=0 flux.
        gx = (-sqrt(3/5), 0.0, sqrt(3/5))
        gw = (5/9, 8/9, 5/9)
        ntheta, nzeta = 48, 48
        volume = 0.0
        for k in eachindex(gx), itheta in 0:ntheta-1, izeta in 0:nzeta-1
            rho = (gx[k]+1)/2
            theta = 2pi*(itheta+0.5)/ntheta
            zeta = 2pi*(izeta+0.5)/nzeta
            c, s, D, R, _ = O._independent_map_terms(input, rho, theta, zeta)
            volume += (gw[k]/2)*(2pi/ntheta)*(2pi/nzeta)*R*a^2*rho*D
        end
        expected_volume = 2pi^2*r0*a^2*(1+eps^2)
        @test volume ≈ expected_volume rtol=2e-13 atol=2e-13

        flux = 0.0
        for k in eachindex(gx), itheta in 0:ntheta-1
            rho = (gx[k]+1)/2
            theta = 2pi*(itheta+0.5)/ntheta
            _, _, D, R, _ = O._independent_map_terms(input, rho, theta, 0.0)
            flux += (gw[k]/2)*(2pi/ntheta)*beta*R*a^2*rho*D
        end
        expected_flux = beta*r0*pi*a^2*(1+eps)^2
        @test flux ≈ expected_flux rtol=2e-13 atol=2e-13
        @test input.flux.nominal_Wb ≈ expected_flux rtol=2e-13 atol=2e-13
    end
    nothing
end

function check_multilevel_diagnostics(input,declaration,out)
    println("SMGW_PHASE_BEGIN=analytic_multilevel_diagnostics");flush(stdout)
    diagnostics=O.multilevel_diagnostics(input;scaling=declaration.scaling,order=3)
    levels=diagnostics.levels
    @test map(x->x.level,levels)==(:q1_2,:q1_4,:q1_8)
    @test map(x->x.dof_count,levels)==(40,272,2080)
    @test map(x->(x.row_count,length(x.row_layout.outer_nodes)),levels)==((57,4),(337,16),(2337,64))
    exact_volume=2pi^2*input.geometry.R0_m*input.geometry.minor_radius_m^2
    exact_flux=input.fields.beta_T_m*input.geometry.R0_m*pi*input.geometry.minor_radius_m^2
    for level in levels
        @test level.nonlinear_solve==:not_executed && level.formal_credit===false
        @test level.physical_validation==:unsupported && level.authority==:no_publish
        @test isapprox(level.volume_m3,exact_volume;rtol=2e-12,atol=2e-12)
        @test isapprox(level.cut_flux_Wb,exact_flux;rtol=2e-11,atol=2e-11)
        @test norm(collect(level.source_integral_N),Inf)<=2e-8
        @test level.momentum_defect_norm<=2e-8*level.conservation_scale
        @test level.divergence_defect<=2e-8*max(1.0,abs(level.cut_flux_Wb))
        @test norm(collect(level.interface_action_reaction_N),Inf)<=2e-8
        @test level.divB_peak_T<=2e-11
        @test level.pressure_min_Pa>=0.0
        @test all(isfinite,(level.B_relative_L2,level.pressure_relative_L2,
            level.B_relative_H1,level.pressure_relative_H1))
    end
    @test last(levels).B_relative_L2<first(levels).B_relative_L2
    @test last(levels).pressure_relative_L2<first(levels).pressure_relative_L2
    @test diagnostics.formal_refinement_gate==:outstanding
    @test diagnostics.claim_ceiling==:diagnostic_only
    write(joinpath(out,"analytic_multilevel_diagnostics.json"),canonical_json(diagnostics)*"\n")
    println("SMGW_PHASE_END=analytic_multilevel_diagnostics");flush(stdout)
    diagnostics
end

function read_state_csv(path,node_count)
    lines=readlines(path)
    first(lines)=="node_id,BR_T,Bphi_T,BZ_T,p_Pa" || throw(ArgumentError("state CSV header mismatch"))
    length(lines)==node_count+1 || throw(ArgumentError("state CSV row count mismatch"))
    state=zeros(4node_count)
    for node in 1:node_count
        fields=split(lines[node+1],',')
        length(fields)==5 || throw(ArgumentError("state CSV column count mismatch"))
        parse(Int,fields[1])==node || throw(ArgumentError("state CSV node order mismatch"))
        values=parse.(Float64,fields[2:5])
        all(isfinite,values) || throw(ArgumentError("state CSV contains nonfinite values"))
        state[4(node-1)+1:4node].=values
    end
    state
end

function _wire_artifact(item)
    item isa NamedTuple && return S.SpatialArtifactV4(String(item.path),Digest256(wire_digest(item.sha256)),
        String(item.schema),Int(item.row_count))
    S.SpatialArtifactV4(String(item["path"]),Digest256(wire_digest(item["sha256"])),
        String(item["schema"]),Int(item["row_count"]))
end

function raw_geometry_artifacts(primary_wire)
    if primary_wire isa NamedTuple
        raw=primary_wire.geometry_receipt.raw_artifacts
        return (nodes=_wire_artifact(raw.nodes),volume=_wire_artifact(raw.volume),
            faces=_wire_artifact(raw.faces))
    end
    raw=primary_wire["geometry_receipt"]["raw_artifacts"]
    (nodes=_wire_artifact(raw["nodes"]),volume=_wire_artifact(raw["volume"]),
        faces=_wire_artifact(raw["faces"]))
end

function verify_primary_identity(primary,input,declaration,context,production_dir;point_only=false)
    @test primary["schema"]=="spatial-manufactured-global-weak-result-v2"
    @test wire_digest(primary["binding"]["candidate_hash"])==string(context.candidate_hash)
    @test wire_digest(primary["binding"]["context_hash"])==string(context.context_hash)
    @test wire_digest(primary["binding"]["context_candidate_hash"])==string(context.candidate_hash)
    @test wire_digest(primary["declaration_hash"])==string(canonical_hash(declaration))
    @test wire_digest(primary["input_hash"])==string(canonical_hash(input))
    identity=primary["operator_identity"]
    @test identity["revision"]=="spatial-q1-global-shared-test-rows-bound-v2"
    expected_identities=expected_semantic_identities()
    @test semantic_identities_match(identity["dependency_semantic_hashes"])
    @test identity["finite_element_space"]=="continuous_tensor_Q1_shared_global_nodes"
    @test wire_digest(identity["solver_semantic_hash"])==expected_identities.solver_semantic_hash
    @test wire_digest(identity["provider_semantic_hash"])==expected_identities.provider_semantic_hash
    @test wire_digest(identity["contract_semantic_hash"])==expected_identities.contract_semantic_hash
    solver_wire=primary["solver"]
    @test solver_wire["schema"]=="spatial-global-weak-solver-state-v2"
    binding=solver_wire["operator_binding"]
    @test binding["schema"]=="spatial-global-weak-operator-binding-v1"
    @test wire_digest(binding["candidate_hash"])==string(context.candidate_hash)
    @test wire_digest(binding["context_hash"])==string(context.context_hash)
    @test wire_digest(binding["declaration_hash"])==string(canonical_hash(declaration))
    @test wire_digest(binding["input_hash"])==string(canonical_hash(input))
    @test semantic_identities_match(binding["semantic_identities"])
    geometry=primary["geometry_receipt"]
    @test geometry["schema"]=="spatial-manufactured-geometry-receipt-v1"
    @test wire_digest(geometry["candidate_hash"])==string(context.candidate_hash)
    @test wire_digest(geometry["context_hash"])==string(context.context_hash)
    @test wire_digest(geometry["declaration_hash"])==string(canonical_hash(declaration))
    @test wire_digest(geometry["input_hash"])==string(canonical_hash(input))
    @test geometry["desc_execution"]=="not_executed"
    @test geometry["physical_validation"]=="unsupported" && geometry["authority"]=="no_publish"
    provider_source=geometry["provider_source"]
    @test normpath(String(provider_source["path"]))==normpath(joinpath(REPO,"src","RuntimeV4","SpatialManufacturedInputV1.jl"))
    @test wire_digest(provider_source["sha256"])==sha(String(provider_source["path"]))
    @test Int(provider_source["row_count"])==length(readlines(String(provider_source["path"])))
    for (name,file) in (("nodes","manufactured_nodes.csv"),("volume","manufactured_volume.csv"),
                        ("faces","manufactured_faces.csv"))
        artifact=geometry["raw_artifacts"][name]
        expected=joinpath(production_dir,"geometry",file)
        @test normpath(String(artifact["path"]))==normpath(expected)
        @test isfile(expected) && (point_only ? S._smgw_sha256_file_v1(expected) : sha(expected))==wire_digest(artifact["sha256"])
        @test artifact["schema"]=="spatial-manufactured-geometry-v1"
    end
    true
end

function verify_saved_artifacts(primary,production_dir,expected_final,state;point_only=false)
    files=Dict(Symbol(String(a["name"]))=>a for a in primary["artifacts"])
    expected_names=Set((:state,:residual,:jacobian,:row_supports,:iterations,:attempts))
    @test Set(keys(files))==expected_names
    paths=Dict(:state=>"solver_state.csv",:residual=>"residual_rows.csv",
        :jacobian=>"global_weak_jacobian.csv",:row_supports=>"global_weak_row_supports.csv",
        :iterations=>"iterations.json",:attempts=>"attempts.json")
    for (name,artifact) in files
        expected=joinpath(production_dir,paths[name])
        @test normpath(String(artifact["path"]))==normpath(expected)
        @test isfile(expected) && (point_only ? S._smgw_sha256_file_v1(expected) : sha(expected))==String(artifact["sha256"])
        if point_only
            count=artifact["row_count"]
            @test count isa Integer && !(count isa Bool) && count>=0
        end
    end
    if point_only
        counts=Dict(:state=>div(length(state),4),:residual=>length(expected_final.residual),
            :jacobian=>nnz(expected_final.jacobian),:row_supports=>length(expected_final.row_blocks))
        for (name,count) in counts
            @test Int(files[name]["row_count"])==count
        end
    end
    state_rows=read_state_csv(files[:state]["path"],div(length(state),4))
    @test state_rows==state
    @test Int(files[:state]["row_count"])==div(length(state),4)
    residual_lines=readlines(files[:residual]["path"])
    @test first(residual_lines)=="row,block,residual,declared_scale"
    residual_rows=[split(line,',') for line in residual_lines[2:end]]
    @test length(residual_rows)==length(expected_final.residual)
    @test all(i->parse(Int,residual_rows[i][1])==i &&
        Symbol(residual_rows[i][2])==expected_final.row_blocks[i] &&
        isapprox(parse(Float64,residual_rows[i][3]),expected_final.residual[i];rtol=1e-13,atol=1e-13) &&
        isapprox(parse(Float64,residual_rows[i][4]),expected_final.row_scales[i];rtol=1e-13,atol=1e-13),
        eachindex(residual_rows))
    if point_only
        open(files[:jacobian]["path"],"r") do io
            readline(io)=="row,column,value" || throw(ArgumentError("Jacobian CSV header mismatch"))
            A=expected_final.jacobian; row_ids=SparseArrays.rowvals(A); values=SparseArrays.nonzeros(A)
            seen=0
            for column in axes(A,2), ptr in SparseArrays.nzrange(A,column)
                eof(io) && throw(ArgumentError("Jacobian CSV ended before all stored triplets"))
                fields=split(readline(io),',')
                length(fields)==3 && parse(Int,fields[1])==row_ids[ptr] &&
                    parse(Int,fields[2])==column && parse(Float64,fields[3])==values[ptr] ||
                    throw(ArgumentError("Jacobian CSV triplet differs from fresh sparse assembly at item $(seen+1)"))
                seen+=1
            end
            eof(io) || throw(ArgumentError("Jacobian CSV contains extra triplets"))
            seen==nnz(A)==Int(files[:jacobian]["row_count"]) ||
                throw(ArgumentError("Jacobian CSV triplet count differs from fresh assembly/manifest"))
        end
    else
        jacobian_lines=readlines(files[:jacobian]["path"])
        @test first(jacobian_lines)=="row,column,value"
        triples=[parse.(Float64,split(line,',')) for line in jacobian_lines[2:end]]
        matrix=sparse(Int[t[1] for t in triples],Int[t[2] for t in triples],
            Float64[t[3] for t in triples],size(expected_final.jacobian)...)
        @test matrix==expected_final.jacobian
    end
    support_lines=readlines(files[:row_supports]["path"])
    @test first(support_lines)=="row,block,columns_semicolon"
    support_rows=[split(line,',') for line in support_lines[2:end]]
    @test length(support_rows)==length(expected_final.row_blocks)
    @test all(i->parse(Int,support_rows[i][1])==i &&
        Symbol(support_rows[i][2])==expected_final.row_blocks[i] &&
        Int[parse(Int,x) for x in split(support_rows[i][3],';') if !isempty(x)]==collect(expected_final.row_supports[i]),
        eachindex(support_rows))
    if !point_only
        iter_wire=JSON3.read(read(files[:iterations]["path"],String))
        attempt_wire=JSON3.read(read(files[:attempts]["path"],String))
        @test Int(files[:iterations]["row_count"])==length(iter_wire)
        @test Int(files[:attempts]["row_count"])==length(attempt_wire)
    end
    primary_state=Float64.(collect(primary["solver"]["final_state"]))
    @test primary_state==state
    if !point_only
        wire_assembly=primary["final_assembly"]
    @test Int(wire_assembly["row_count"])==length(expected_final.residual)
    wire_residual=Float64.(collect(wire_assembly["residual"]))
    wire_scales=Float64.(collect(wire_assembly["row_scales"]))
    @test maximum(abs.(wire_residual.-expected_final.residual)./expected_final.row_scales)<=5e-10
    @test all(i->isapprox(wire_scales[i],expected_final.row_scales[i];rtol=3e-11,atol=1e-12),eachindex(wire_scales))
    @test Tuple(Symbol.(collect(wire_assembly["row_blocks"])))==expected_final.row_blocks
    wire_jac=wire_assembly["jacobian"]
    matrix_from_primary=sparse(Int.(collect(wire_jac["row_indices"])),
        Int.(collect(wire_jac["column_indices"])),Float64.(collect(wire_jac["values"])),
        Int(wire_assembly["rows"]),Int(wire_assembly["columns"]))
    @test matrix_from_primary==expected_final.jacobian
    wire_named=S._smr_json_native_v1(wire_assembly)
    @test _named_numeric_close(wire_named.interface_checks,expected_final.interface_checks;rtol=2e-8,atol=2e-9)
    @test _named_numeric_close(wire_named.boundary_checks,expected_final.boundary_checks;rtol=2e-8,atol=2e-8)
    @test _named_numeric_close(wire_named.conservation_checks,expected_final.conservation_checks;rtol=2e-8,atol=2e-8)
    end
    true
end

expected_semantic_identities() = S.spatial_global_weak_operator_identity_v1().dependency_semantic_hashes

function semantic_identities_match(value)
    actual=value isa NamedTuple ? value : S._smr_json_native_v1(value)
    expected=expected_semantic_identities()
    actual isa NamedTuple && Set(keys(actual))==Set(keys(expected)) &&
        all(name->getproperty(actual,name)==getproperty(expected,name),keys(expected))
end

function assert_frozen_input(input,declaration)
    @test input.mesh.level==:coarse && input.mesh.unknowns==40 && input.mesh.rows==289
    @test declaration.source.input==input
    @test declaration.solver.coarse_iterations==12 && declaration.solver.coarse_seconds==120.0
    @test declaration.solver.residual_tolerance==1.0e-6
    @test declaration.solver.gradient_tolerance==1.0e-10
    @test declaration.solver.rank_relative_tolerance==1.0e-10
    @test declaration.solver.bounded_linear_step.policy.kkt_absolute_tolerance==1.0e-10
    @test declaration.solver.line_search_steps==20 && declaration.solver.pressure_lower_Pa==0.0
    identity=S.spatial_global_weak_operator_identity_v1()
    expected=expected_semantic_identities()
    @test identity.solver_semantic_hash==expected.solver_semantic_hash
    @test identity.provider_semantic_hash==expected.provider_semantic_hash
    @test identity.contract_semantic_hash==expected.contract_semantic_hash
    @test identity.revision=="spatial-q1-global-shared-test-rows-bound-v2"
    @test identity.dependency_semantic_hashes==expected
    @test identity.finite_element_space==:continuous_tensor_Q1_shared_global_nodes
    input.mesh.level==:coarse && input.mesh.unknowns==40 && input.mesh.rows==289 &&
        declaration.source.input==input &&
        declaration.solver.coarse_iterations==12 && declaration.solver.coarse_seconds==120.0 &&
        declaration.solver.residual_tolerance==1.0e-6 &&
        declaration.solver.gradient_tolerance==1.0e-10 &&
        declaration.solver.rank_relative_tolerance==1.0e-10 &&
        declaration.solver.bounded_linear_step.policy.kkt_absolute_tolerance==1.0e-10 &&
        declaration.solver.line_search_steps==20 && declaration.solver.pressure_lower_Pa==0.0 &&
        identity.solver_semantic_hash==expected.solver_semantic_hash &&
        identity.provider_semantic_hash==expected.provider_semantic_hash &&
        identity.contract_semantic_hash==expected.contract_semantic_hash &&
        identity.revision=="spatial-q1-global-shared-test-rows-bound-v2" &&
        identity.dependency_semantic_hashes==expected &&
        identity.finite_element_space==:continuous_tensor_Q1_shared_global_nodes ||
        error("fresh consumer frozen input, policy, or semantic identity mismatch")
    identity
end

function assert_candidate_chain(input,declaration;parent_context=nothing)
    context,physical_input,parent_context=fresh_manufactured_context(input,declaration;
        parent_context=parent_context)
    @test physical_input.fourier_boundary.field_periods==1
    @test context.candidate.identity_ref==S._SMM_CANDIDATE_ID_V1
    @test context.candidate_hash!=parent_context.candidate_hash
    @test context.context_hash!=parent_context.context_hash
    @test context.subject.materialized_payload.provenance.authority==:no_publish
    physical_input.fourier_boundary.field_periods==1 &&
        context.candidate.identity_ref==S._SMM_CANDIDATE_ID_V1 &&
        context.candidate_hash!=parent_context.candidate_hash &&
        context.context_hash!=parent_context.context_hash &&
        context.subject.materialized_payload.provenance.authority==:no_publish ||
        error("fresh consumer candidate/context chain mismatch")
    context,parent_context
end

function _candidate_with_identity(context,identity)
    c=context.candidate
    S.CandidateStatePackageV4(identity,c.mission_contract_ref,c.mechanism_genome_ref,
        c.field_geometry_genome_ref,c.realization_control_genome_ref,context.registry;
        lifecycle=c.lifecycle,applicability_records=c.applicability_records,
        compilation_records=c.compilation_records,proposal_lineage=c.proposal_lineage,
        stage_evidence_refs=c.stage_evidence_refs,archive_memberships=c.archive_memberships,
        claim_ceiling=c.claim_ceiling)
end

function _candidate_with_provenance(context,replacement)
    c=context.candidate
    replace_fields(fields)=Tuple(x isa NamedTuple && hasproperty(x,:revision) ?
        replacement : x for x in fields)
    old_field=c.field_geometry_genome_ref
    field=S.FieldGeometryGenomeV4(old_field.seed,old_field.contract_ref,old_field.graph;
        fields=replace_fields(old_field.fields))
    old_control=c.realization_control_genome_ref
    control=S.RealizationControlGenomeV4(old_control.seed,old_control.control_seed,
        old_control.contract_ref,old_control.realization_graph,old_control.control_graph;
        realization=old_control.realization,control=replace_fields(old_control.control))
    proposals=Tuple(S.ProposalEnvelopeV4(p.proposal_id,p.candidate_or_prefix_ref,p.parent_refs,
        p.search_channel,p.typed_edit_trace,p.target_behavior_cell,p.predicted_outcomes,
        p.uncertainty,p.estimated_cost,canonical_hash(replacement),p.requested_next_stage)
        for p in c.proposal_lineage)
    S.CandidateStatePackageV4(c.identity_ref,c.mission_contract_ref,c.mechanism_genome_ref,
        field,control,context.registry;lifecycle=c.lifecycle,
        applicability_records=c.applicability_records,compilation_records=c.compilation_records,
        proposal_lineage=proposals,stage_evidence_refs=c.stage_evidence_refs,
        archive_memberships=c.archive_memberships,claim_ceiling=c.claim_ceiling)
end

function _rebuild_candidate_context(context,candidate;provenance=nothing)
    compiled=S.compile_candidate(candidate,context.registry;
        mission_payload=context.mission_payload,bounds_payload=context.bounds_payload,
        comparison_scope=context.comparison_scope,scenario_scope=context.scenario_scope)
    physical_input=only(filter(x->x isa S.ThreeDPhysicalProviderInputV4,
        candidate.field_geometry_genome_ref.fields))
    bindings=Tuple(S.make_three_d_physical_provider_input_binding(compiled,context.registry,
        context.mission_payload,context.bounds_payload,context.comparison_scope,
        context.scenario_scope,scenario,physical_input) for scenario in context.subject.scenarios)
    payload=context.subject.materialized_payload
    if provenance!==nothing && payload isa NamedTuple && hasproperty(payload,:provenance)
        payload=merge(payload,(revision=provenance.revision,provenance=provenance))
    end
    subject=S.ExecutablePhysicalSubjectV4(compiled.prefix_hash,
        candidate.canonical_hashes.genome_bundle_hash,
        compiled.minimality_scope.mission_hash,compiled.minimality_scope.bounds_hash,
        bindings,context.subject.scenarios,payload,S.derive_capability_obligations(compiled))
    S.make_forward_chain_context(candidate,compiled,context.registry,context.mission_payload,
        context.bounds_payload,context.comparison_scope,context.scenario_scope,subject,context.scenario)
end

function _without_named_field(value::NamedTuple,field::Symbol)
    names=Tuple(name for name in keys(value) if name!==field)
    NamedTuple{names}(Tuple(getproperty(value,name) for name in names))
end

function _candidate_validation_error(context,message)
    try
        S.validate_spatial_candidate_v4(context)
    catch err
        return sprint(showerror,err)==message
    end
    false
end

const _CANDIDATE_IDENTITY_SHARDS_V1=("default","loads_only","bounded_only",
    "loads_bounded","manufactured","negative_identity","negative_revision",
    "negative_missing_loads")

function _assert_candidate_identity_branch(name,context,declaration,expected)
    extracted=S._smr_declaration(context)
    provenance=only(filter(x->x isa NamedTuple && hasproperty(x,:revision),
        context.candidate.field_geometry_genome_ref.fields))
    @test extracted==declaration
    @test context.candidate.identity_ref==expected.id
    @test provenance.revision==expected.revision
    if name===:manufactured
        @test provenance.manufactured.input_hash==canonical_hash(declaration.source.input)
    end
    provenance
end

function candidate_identity_main(out,shard)
    shard in _CANDIDATE_IDENTITY_SHARDS_V1 ||
        error("unknown candidate identity shard: $shard; expected one of $(_CANDIDATE_IDENTITY_SHARDS_V1)")
    ispath(out) && error("preserve existing candidate identity evidence directory")
    mkpath(out)
    input=S.spatial_n1_manufactured_input_v1()
    manufactured_declaration=S.spatial_n1_manufactured_declaration_v1(input)
    println("SMGW_CANDIDATE_IDENTITY_BEGIN shard=",shard);flush(stdout)
    expected=(
        default=(id="spatial-coupled-20260912-r1",revision="spatial-coupled-candidate-v1"),
        loads_only=(id="spatial-coupled-declared-loads-v1",revision="spatial-coupled-candidate-declared-loads-v1"),
        bounded_only=(id="spatial-coupled-bounded-step-v1",revision="spatial-coupled-candidate-bounded-step-v1"),
        loads_bounded=(id="spatial-coupled-declared-loads-bounded-step-v1",
            revision="spatial-coupled-candidate-declared-loads-bounded-step-v1"),
        manufactured=(id=S._SMM_CANDIDATE_ID_V1,
            revision="spatial-coupled-candidate-manufactured-n1-bounded-step-v1"))
    if shard=="manufactured"
        manufactured_context,_,_=fresh_manufactured_context(input,manufactured_declaration)
        @testset "candidate identity branch: manufactured" begin
            _assert_candidate_identity_branch(:manufactured,manufactured_context,
                manufactured_declaration,expected.manufactured)
        end
        println("SMGW_CANDIDATE_IDENTITY_COMPLETE shard=manufactured branches=1 negatives=0");flush(stdout)
        return nothing
    end
    physical_input,parent_context=fresh_manufactured_parent_context(input)
    flux_Wb=physical_input.profiles_flux.toroidal_flux_wb
    default_declaration=S.spatial_multiregion_declaration_v4(;flux_Wb=flux_Wb)
    loads_declaration=S.spatial_multiregion_declared_loads_v1(default_declaration;
        source_xyz_N_m3=(1.0,-2.0,3.0),normal_B_T=0.0,
        source_provenance="Candidate identity control only; not solved",
        boundary_provenance="Closed numerical boundary")
    bounded_declaration=S.spatial_multiregion_bounded_step_v1(default_declaration)
    combined_declaration=S.spatial_multiregion_bounded_step_v1(loads_declaration)
    declarations=(default=default_declaration,loads_only=loads_declaration,
        bounded_only=bounded_declaration,loads_bounded=combined_declaration)
    if shard=="negative_identity"
        default=S.build_spatial_candidate_v4(parent_context,physical_input;
            physical_declaration=default_declaration)
        wrong_identity=_candidate_with_identity(default.context,"wrong-spatial-candidate-id")
        wrong_identity_context=_rebuild_candidate_context(default.context,wrong_identity)
        @testset "candidate identity negative control" begin
            @test _candidate_validation_error(wrong_identity_context,
                "spatial candidate identity/provenance mismatch")
        end
        println("SMGW_CANDIDATE_IDENTITY_COMPLETE shard=negative_identity branches=0 negatives=1");flush(stdout)
        return nothing
    elseif shard in ("negative_revision","negative_missing_loads")
        loads_only=S.build_spatial_candidate_v4(parent_context,physical_input;
            physical_declaration=loads_declaration)
        if shard=="negative_revision"
            wrong_revision=merge(loads_only.provenance,(revision="wrong-spatial-revision-v1",))
            wrong_revision_candidate=_candidate_with_provenance(loads_only.context,wrong_revision)
            wrong_revision_context=_rebuild_candidate_context(loads_only.context,
                wrong_revision_candidate;provenance=wrong_revision)
            @testset "candidate revision negative control" begin
                @test _candidate_validation_error(wrong_revision_context,
                    "spatial candidate identity/provenance mismatch")
            end
        else
            missing_loads=_without_named_field(loads_only.provenance,:declared_loads)
            missing_loads_candidate=_candidate_with_provenance(loads_only.context,missing_loads)
            missing_loads_context=_rebuild_candidate_context(loads_only.context,
                missing_loads_candidate;provenance=missing_loads)
            @testset "candidate missing loads negative control" begin
                @test _candidate_validation_error(missing_loads_context,
                    "spatial candidate provenance scope mismatch")
            end
        end
        println("SMGW_CANDIDATE_IDENTITY_COMPLETE shard=",shard," branches=0 negatives=1");flush(stdout)
        return nothing
    end
    name=Symbol(shard)
    declaration=getproperty(declarations,name)
    candidate=S.build_spatial_candidate_v4(parent_context,physical_input;
        physical_declaration=declaration)
    @testset "candidate identity branch: $shard" begin
        provenance=_assert_candidate_identity_branch(name,candidate.context,
            declaration,getproperty(expected,name))
        if name===:default
            @test !hasproperty(provenance,:declared_loads)
            @test !hasproperty(provenance,:numerical_algorithm)
        elseif name===:loads_only
            @test provenance.declared_loads==(
                declaration_hash=canonical_hash(loads_declaration),source=loads_declaration.source,
                normal_boundary=loads_declaration.boundary,scope=:declared_load_assembly_only,
                pressure_current_topology=:not_fixed,exterior_current_closure=:terminal_deferred)
            @test !hasproperty(provenance,:numerical_algorithm)
        elseif name===:bounded_only
            @test provenance.numerical_algorithm==(
                declaration_hash=canonical_hash(bounded_declaration),
                identity=bounded_declaration.solver.bounded_linear_step,
                scope=:linearized_subproblem_only,nonlinear_convergence=:requires_full_residual_gate,
                physical_validation=:unsupported)
            @test !hasproperty(provenance,:declared_loads)
        elseif name===:loads_bounded
            @test hasproperty(provenance,:declared_loads)
            @test hasproperty(provenance,:numerical_algorithm)
        end
    end
    println("SMGW_CANDIDATE_IDENTITY_COMPLETE shard=",shard," branches=1 negatives=0");flush(stdout)
    nothing
end

function producer_main(out)
    ispath(out) && error("preserve existing global weak producer evidence directory")
    mkpath(out)
    println("SMGW_PRODUCER_START julia=",VERSION," pid=",getpid()," threads=",Threads.nthreads());flush(stdout)
    input=S.spatial_n1_manufactured_input_v1()
    declaration=S.spatial_n1_manufactured_declaration_v1(input)
    @testset "frozen global weak source, input, and solver policy" begin
        assert_frozen_input(input,declaration)
    end
    println("SMGW_PHASE_BEGIN=real_candidate_chain");flush(stdout)
    context,parent_context=assert_candidate_chain(input,declaration)
    println("SMGW_PHASE_END=real_candidate_chain candidate=",context.candidate_hash);flush(stdout)
    println("SMGW_PHASE_BEGIN=official_q1_2_producer");flush(stdout)
    result=S.execute_spatial_manufactured_global_weak_numerical_v1(context,joinpath(out,"production"))
    report=result.report;solver=report.solver
    @testset "actual q1_2 producer and unchanged numerical/scope bounds" begin
        @test report.schema=="spatial-manufactured-global-weak-result-v2"
        @test report.binding.candidate_hash==context.candidate_hash
        @test report.binding.context_hash==context.context_hash
        @test report.binding.context_candidate_hash==context.candidate_hash
        @test report.declaration_hash==canonical_hash(declaration)
        @test report.input_hash==canonical_hash(input)
        @test report.solver_exit_code==solver.solver_exit_code==0
        @test report.status==:converged && report.numerical_status==:full_discrete_residual_converged
        @test report.stopping_reason==:all_scaled_residuals_converged
        @test report.accepted_update_count==solver.accepted_update_count<=12
        @test isfinite(solver.elapsed_seconds) && solver.elapsed_seconds>=0.0
        @test all(i->i.elapsed_seconds<=120.0,solver.iterations)
        @test all(a->a.elapsed_seconds<=120.0,solver.attempts)
        @test report.final_scaled_residual_max<=1.0e-6
        @test solver.final_scaled_residual_max==report.final_scaled_residual_max
        @test solver.numerical_policy.max_iterations==12 && solver.numerical_policy.seconds==120.0
        @test solver.numerical_policy.residual_tolerance==1.0e-6
        @test solver.numerical_policy.gradient_tolerance==1.0e-10
        @test solver.numerical_policy.rank_relative_tolerance==1.0e-10
        @test solver.numerical_policy.kkt_absolute_tolerance==1.0e-10
        @test solver.numerical_policy.line_search_steps==20
        @test solver.numerical_policy.pressure_lower_Pa==0.0
        pressure_min=minimum(solver.final_state[4:4:end])
        pressure_tolerance=8eps(Float64)*max(1.0,abs(pressure_min/declaration.scaling.p_Pa))*declaration.scaling.p_Pa
        @test pressure_min>=-pressure_tolerance
        @test report.physical_validation==:unsupported && report.authority==:no_publish
        @test report.claim_ceiling==screen_only
        @test report.desc_execution==:not_executed && report.engineering_execution==:not_executed
        @test report.whole_device_validation==:unsupported
        @test report.formal_policy==(status=:typed_absent,value=nothing)
        @test all(c->c.status==:typed_absent && c.value===nothing,values(report.spatial_closures))
    end
    handoff=(schema="spatial-global-weak-two-process-handoff-v1",
        semantic_identities=expected_semantic_identities(),candidate_hash=context.candidate_hash,
        context_hash=context.context_hash,declaration_hash=canonical_hash(declaration),
        input_hash=canonical_hash(input),result_hash=result.result_hash,
        solver_exit_code=report.solver_exit_code,final_scaled_residual_max=report.final_scaled_residual_max,
        q1_2=:producer_completed,formal_refinement_gate=:outstanding,
        physical_validation=:unsupported,authority=:no_publish)
    write(joinpath(out,"producer_handoff.json"),canonical_json(handoff)*"\n")
    println("SMGW_PRODUCER_COMPLETE solver_exit=",report.solver_exit_code,
        " residual=",report.final_scaled_residual_max," formal_refinement_gate=outstanding");flush(stdout)
    nothing
end

function _q1_real_consumer_spec(level::Symbol)
    level===:q1_4 && return (revision="spatial-manufactured-n1-q1_4-input-v1",
        unknowns=272,ownership_rows=2177,nodes=68,global_rows=337,seconds=120.0)
    level===:q1_8 && return (revision="spatial-manufactured-n1-q1_8-input-v1",
        unknowns=2080,ownership_rows=16897,nodes=520,global_rows=2337,seconds=600.0)
    throw(ArgumentError("unsupported real-consumer Q1 level: $level"))
end

function _assert_q1_level_solver_result(level,input,declaration,context,report)
    spec=_q1_real_consumer_spec(level)
    input.revision==spec.revision && input.mesh.level==level &&
        input.mesh.unknowns==spec.unknowns && input.mesh.rows==spec.ownership_rows ||
        error("$level input semantic binding or mesh inventory mismatch")
    assembly=report.final_assembly
    layout=assembly.row_layout
    length(report.solver.initial_state)==spec.unknowns &&
        length(report.solver.final_state)==spec.unknowns &&
        length(assembly.node_order)==spec.nodes &&
        length(assembly.residual)==spec.global_rows && layout.total_rows==spec.global_rows &&
        layout.volume_rows.last==spec.unknowns &&
        layout.boundary_trace_rows.first==spec.unknowns+1 &&
        layout.boundary_trace_rows.last==spec.global_rows-1 &&
        layout.total_flux_row==spec.global_rows ||
        error("$level producer GlobalWeak residual row-space identity mismatch")
    canonical_hash(input)!=canonical_hash(S.spatial_n1_manufactured_input_v1()) ||
        error("$level input reused the default Q1_2 semantic identity")
    report.binding.candidate_hash==context.candidate_hash &&
        report.binding.context_hash==context.context_hash &&
        report.binding.context_candidate_hash==context.candidate_hash &&
        report.declaration_hash==canonical_hash(declaration) &&
        report.input_hash==canonical_hash(input) ||
        error("$level producer candidate/source/input binding mismatch")
    report.solver_exit_code==0 && report.status==:converged &&
        report.numerical_status==:full_discrete_residual_converged &&
        report.stopping_reason==:all_scaled_residuals_converged &&
        report.accepted_update_count==report.solver.accepted_update_count<=12 &&
        report.final_scaled_residual_max<=1.0e-6 &&
        report.solver.elapsed_seconds<=spec.seconds &&
        all(i->i.elapsed_seconds<=spec.seconds,report.solver.iterations) &&
        all(a->a.elapsed_seconds<=spec.seconds,report.solver.attempts) &&
        report.solver.numerical_policy.max_iterations==12 &&
        report.solver.numerical_policy.seconds==spec.seconds &&
        report.solver.numerical_policy.residual_tolerance==1.0e-6 &&
        report.solver.numerical_policy.gradient_tolerance==1.0e-10 &&
        report.solver.numerical_policy.rank_relative_tolerance==1.0e-10 &&
        report.solver.numerical_policy.kkt_absolute_tolerance==1.0e-10 &&
        report.solver.numerical_policy.line_search_steps==20 &&
        report.solver.numerical_policy.pressure_lower_Pa==0.0 ||
        error("$level nonlinear solve failed an unchanged frozen numerical gate")
    pressure_min=minimum(report.solver.final_state[4:4:end])
    pressure_tolerance=8eps(Float64)*max(1.0,
        abs(pressure_min/declaration.scaling.p_Pa))*declaration.scaling.p_Pa
    pressure_min>=-pressure_tolerance || error("$level nonlinear state violates the pressure lower bound")
    mapped_native=level===:q1_4 && input.geometry.model===:m1n1_ripple_torus &&
        report.solver.residual_partition===:spatial_native
    if level===:q1_8 || mapped_native
        expected_lm_label=mapped_native ? :q1_4_m1n1_bounded_lm_alternate : :q1_8_bounded_lm_alternate
        expected_lm_schema=mapped_native ? "q1-4-m1n1-bounded-lm-chord-corrector-v1" :
            "q1-8-bounded-lm-chord-corrector-v1"
        lm_attempts=[attempt for attempt in report.solver.attempts
            if hasproperty(attempt,:selected_direction) &&
                attempt.selected_direction===expected_lm_label]
        if level===:q1_8
            @test !isempty(lm_attempts)
        else
            # Convergence need not use LM. Its execution coverage is separate.
            lm_records=[a.lm_alternate for a in report.solver.attempts if a.lm_alternate!==nothing]
            @test all(lm->lm.schema==(hasproperty(lm,:refinement) && lm.refinement.selected ?
                "q1-4-m1n1-bounded-lm-chord-refined-v2" : expected_lm_schema),lm_records)
            refined_count=count(lm->hasproperty(lm,:refinement) && lm.refinement.selected,lm_records)
            println("SMGW_Q1_4_M1N1_REFINEMENT_COVERAGE selected=",refined_count,
                " execution_coverage=",refined_count>0 ? "observed" : "not_proven")
            evaluated_count=count(lm->hasproperty(lm,:corrector_kkt),lm_records)
            println("SMGW_Q1_4_M1N1_CURVATURE_COVERAGE evaluated=",evaluated_count,
                " selected=",length(lm_attempts)," execution_coverage=",
                evaluated_count>0 ? "observed" : "not_proven")
            flush(stdout)
        end
        for attempt in lm_attempts
            if !hasproperty(attempt,:lm_alternate) || attempt.lm_alternate===nothing
                @test false
                continue
            end
            lm=attempt.lm_alternate
            is_refined=mapped_native && hasproperty(lm,:refinement) && lm.refinement.selected
            @test lm.schema==(is_refined ? "q1-4-m1n1-bounded-lm-chord-refined-v2" : expected_lm_schema)
            if !mapped_native
                @test !hasproperty(lm,:refinement)
            end
            @test lm.selected===true
            @test attempt.step==lm.step
            @test Tuple(attempt.bounded_step.step)==Tuple(lm.raw_step)
            if mapped_native && attempt.accepted
                @test any(t->t.accepted && t.armijo && t.strict_decrease && t.feasible &&
                    t.alpha==attempt.accepted_alpha && t.objective_after==attempt.objective_after,attempt.trials)
                @test attempt.objective_after<attempt.objective_before
            end
            @test lm.status===:kkt_converged
            @test isfinite(lm.lambda) && lm.lambda>0.0
            @test lm.corrector_kkt.passed
            if is_refined
                @test S._smgw_m1n1_refinement_identity_v1(lm,attempt)
                @test lm.corrector_kkt_scope===:initial_chord_augmented_shifted_lower_bound_subproblem
                @test lm.refinement.elapsed_seconds<=lm.refinement.shared_seconds_limit==6.0
                @test 1<=length(lm.refinement.selected_chain)<=lm.refinement.extra_corrector_limit==2
                @test lm.refinement.selected_objective<lm.refinement.baseline_objective
                @test all(entry->entry.eligible && entry.kkt.passed,lm.refinement.selected_chain)
            else
                @test Tuple(lm.corrector_alpha.*Float64.(collect(lm.raw_step)).+Float64.(collect(lm.correction_step)))==lm.step
            end
            if mapped_native
                @test lm.total_extra_elapsed_seconds<=72.0
            end
            @test lm.augmented_rank_evidence===:not_used_for_raw_rank
            @test attempt.direction===:global_shared_q1_lower_bounded_sparse_QR
            @test hasproperty(attempt,:linear_input) && hasproperty(attempt,:bounded_step)
            if hasproperty(attempt,:bounded_step)
                @test attempt.bounded_step.converged
                @test attempt.bounded_step.kkt.passed
                @test all(isfinite,attempt.bounded_step.step)
            end
            state_index=Int(attempt.iteration)+1
            if 1<=state_index<=length(report.solver.state_history) &&
                    length(lm.step)==length(report.solver.state_history[state_index])
                state=report.solver.state_history[state_index]
                columns=repeat(Float64[declaration.scaling.B_T,declaration.scaling.B_T,
                    declaration.scaling.B_T,declaration.scaling.p_Pa],div(length(state),4))
                for j in 4:4:length(state)
                    tol=8eps(Float64)*max(1.0,abs(state[j]/declaration.scaling.p_Pa))*declaration.scaling.p_Pa
                    @test state[j]+columns[j]*lm.step[j]>=-tol
                end
            else
                @test false
            end
        end
        if mapped_native
            @test S._smgw_verify_solver_step_identity_v1(report.solver)===:spatial_native
        end
    elseif level===:q1_4
        # Real default circular and InHouse runs must not acquire an LM direction.
        @test all(a->a.lm_alternate===nothing &&
            !(a.selected_direction in (:q1_8_bounded_lm_alternate,:q1_4_m1n1_bounded_lm_alternate)),
            report.solver.attempts)
    end
    report.physical_validation==:unsupported && report.authority==:no_publish &&
        report.formal_policy==(status=:typed_absent,value=nothing) &&
        all(c->c.status==:typed_absent && c.value===nothing,values(report.spatial_closures)) ||
        error("$level result promoted unsupported physical scope or closures")
    true
end

_assert_q1_4_solver_result(input,declaration,context,report)=
    _assert_q1_level_solver_result(:q1_4,input,declaration,context,report)

function _q1_4_continuation_source_v1(source_root)
    root=abspath(String(source_root))
    isdir(root) || throw(ArgumentError("Q1_8 continuation source root is absent"))
    production_dir=joinpath(root,"production")
    consumer_receipt_path=joinpath(root,"q1_4_consumer","q1_4_validation_receipt.json")
    isdir(production_dir) && isfile(consumer_receipt_path) ||
        throw(ArgumentError("Q1_8 continuation requires the Q1_4 producer and full fresh consumer validation"))
    input=S.spatial_n1_manufactured_input_v1(;level=:q1_4)
    declaration=S.spatial_n1_manufactured_declaration_v1(input)
    context,parent_context=assert_candidate_chain(input,declaration)
    receipt_wire=read(consumer_receipt_path,String)
    S._smr_read_canonical_json_v1(receipt_wire)
    receipt=JSON3.read(receipt_wire)
    binding=_consumer_artifact_binding_v1(production_dir)
    receipt["schema"]=="spatial-global-weak-q1_4-independent-consumer-receipt-v1" &&
        receipt["level"]=="q1_4" && receipt["input_revision"]==input.revision &&
        String(receipt["input_hash"])==string(canonical_hash(input)) &&
        String(receipt["declaration_hash"])==string(canonical_hash(declaration)) &&
        String(receipt["candidate_hash"])==string(context.candidate_hash) &&
        String(receipt["context_hash"])==string(context.context_hash) &&
        Int(receipt["unknowns"])==272 && Int(receipt["ownership_rows"])==2177 &&
        Int(receipt["globalweak_residual_rows"])==337 &&
        receipt["artifact_replay"]=="passed" && receipt["nonlinear_solve"]=="executed" &&
        Int(receipt["solver_exit_code"])==0 &&
        Float64(receipt["fd_threshold"])==5.0e-6 &&
        isfinite(Float64(receipt["independent_centered_fd_relative_error"])) &&
        Float64(receipt["independent_centered_fd_relative_error"])<=5.0e-6 &&
        String(receipt["producer_result_hash"])==binding.result_hash &&
        String(receipt["producer_primary_sha256"])==binding.primary_sha256 &&
        String(receipt["producer_artifact_set_hash"])==binding.artifact_set_hash &&
        String(receipt["geometry_artifact_set_hash"])==binding.geometry_artifact_set_hash ||
        throw(ArgumentError("Q1_4 fresh consumer receipt is stale, incomplete, or did not pass all 272 FD columns"))
    (context=context,parent_context=parent_context,production_dir=production_dir)
end

function test_q1_4_continuation_rejects_wrong_candidate_v1(source,target_context)
    input=S.spatial_n1_manufactured_input_v1(;level=:q1_4)
    declaration=S.spatial_n1_manufactured_declaration_v1(input)
    source_admission=S._smgw_admit_context_v1(source.context)
    target_admission=S._smgw_admit_context_v1(target_context)
    source_input=source_admission.declaration.source.input
    target_input=target_admission.declaration.source.input
    @test S.validate_spatial_manufactured_candidate_input_v1(source.context,source_input)
    @test S.validate_spatial_manufactured_candidate_input_v1(target_context,target_input)
    @test source_input.mesh.level===:q1_4 && target_input.mesh.level===:q1_8
    @test source_input.geometry==target_input.geometry && source_input.fields==target_input.fields &&
        source_input.initialization==target_input.initialization &&
        source_input.quadrature==target_input.quadrature && source_input.boundary==target_input.boundary &&
        source_input.flux==target_input.flux && source_input.provenance==target_input.provenance
    @test Tuple((key,getproperty(source_input.numerics,key)) for key in keys(source_input.numerics)
        if key!==:seconds)==Tuple((key,getproperty(target_input.numerics,key))
        for key in keys(target_input.numerics) if key!==:seconds)
    # Q1_4 default construction remains deterministic; the Q1_8 child must inherit
    # this exact parent while its complete numerical input identity remains distinct.
    default_physical_input,default_parent=fresh_manufactured_parent_context(source_input)
    @test default_parent.candidate_hash==source.parent_context.candidate_hash
    @test default_parent.context_hash==source.parent_context.context_hash
    @test canonical_hash(default_physical_input)==
        canonical_hash(only(filter(v->v isa S.ThreeDPhysicalProviderInputV4,
            source.parent_context.candidate.field_geometry_genome_ref.fields)))
    q14_geometry=S.spatial_manufactured_parent_geometry_v1(source_input)
    q18_geometry=S.spatial_manufactured_parent_geometry_v1(target_input)
    @test canonical_hash(source_input)!=canonical_hash(target_input)
    @test q14_geometry.provenance.input_hash==canonical_hash(source_input)
    @test q18_geometry.provenance.input_hash==canonical_hash(target_input)
    @test q14_geometry.provenance.input_hash!=q18_geometry.provenance.input_hash
    @test q14_geometry.typed_binding.input_hash==canonical_hash(source_input)
    @test q18_geometry.typed_binding.input_hash==canonical_hash(target_input)
    @test canonical_hash(q14_geometry.graph)==canonical_hash(q18_geometry.graph)
    @test canonical_hash(q14_geometry.support)==canonical_hash(q18_geometry.support)
    @test canonical_hash(q14_geometry.physical_input)==canonical_hash(q18_geometry.physical_input)
    @test_throws ArgumentError S.interpret_spatial_manufactured_geometry_v1(
        target_input,q14_geometry.typed_binding,(0.5,0.25,0.125))
    target_parent_binding=only(filter(value->value isa NamedTuple &&
        hasproperty(value,:parent_candidate_hash),target_context.candidate.field_geometry_genome_ref.fields))
    @test target_parent_binding.parent_candidate_hash==source.parent_context.candidate_hash
    @test target_parent_binding.parent_package_hash==canonical_hash(source.parent_context.candidate)
    @test target_parent_binding.parent_context_hash==source.parent_context.context_hash

    q14_bounds_hash=S._runtime_decl_hash(source.context.bounds_payload)
    q18_bounds_hash=S._runtime_decl_hash(target_context.bounds_payload)
    @test q14_bounds_hash!=q18_bounds_hash
    is_screen=o->o.schema=="fusionconceptai:runtime-v4-screen" && o.revision=="v1" &&
        o.kind===:structural_screen && o.operator=="typed_structure_audit" &&
        o.input_schema_hash==canonical_hash((schema="fusionconceptai:screen-input",revision="v1"))
    q14_screen=only(filter(is_screen,source.context.compiled.capability_obligations))
    q18_screen=only(filter(is_screen,target_context.compiled.capability_obligations))
    @test S._smgw_q1_continuation_obligation_shapes_v1((q14_screen,),q14_bounds_hash)==
        S._smgw_q1_continuation_obligation_shapes_v1((q18_screen,),q18_bounds_hash)
    @test_throws ArgumentError S._smgw_q1_continuation_obligation_shapes_v1(
        (q14_screen,),canonical_hash((wrong_bounds=true,)))
    changed_screen_operator=S.CapabilitySignatureV4(q14_screen.schema,q14_screen.revision,
        q14_screen.kind,q14_screen.operator*"_changed",q14_screen.states,q14_screen.source_space,
        q14_screen.target_space,q14_screen.dimension,q14_screen.coordinates,q14_screen.boundary_relation,
        q14_screen.interface_relation,q14_screen.time_semantics,q14_screen.required_output,
        q14_screen.evidence_level,q14_screen.applicability_bounds;
        input_schema_hash=q14_screen.input_schema_hash,coordinate_system=q14_screen.coordinate_system)
    @test S._smgw_q1_continuation_obligation_shapes_v1((q14_screen,),q14_bounds_hash)!=
        S._smgw_q1_continuation_obligation_shapes_v1((changed_screen_operator,),q14_bounds_hash)
    changed_screen_schema=S.CapabilitySignatureV4(q14_screen.schema,q14_screen.revision,
        q14_screen.kind,q14_screen.operator,q14_screen.states,q14_screen.source_space,
        q14_screen.target_space,q14_screen.dimension,q14_screen.coordinates,q14_screen.boundary_relation,
        q14_screen.interface_relation,q14_screen.time_semantics,q14_screen.required_output,
        q14_screen.evidence_level,q14_screen.applicability_bounds;
        input_schema_hash=canonical_hash((changed_screen_input_schema=true,)),
        coordinate_system=q14_screen.coordinate_system)
    @test S._smgw_q1_continuation_obligation_shapes_v1((q14_screen,),q14_bounds_hash)!=
        S._smgw_q1_continuation_obligation_shapes_v1((changed_screen_schema,),q14_bounds_hash)
    synthetic_non_screen=S.CapabilitySignatureV4(q14_screen.schema,q14_screen.revision,
        :operator_capability,"test.operator",q14_screen.states,q14_screen.source_space,
        q14_screen.target_space,q14_screen.dimension,q14_screen.coordinates,q14_screen.boundary_relation,
        q14_screen.interface_relation,q14_screen.time_semantics,q14_screen.required_output,
        q14_screen.evidence_level,q14_screen.applicability_bounds;
        coordinate_system=q14_screen.coordinate_system)
    synthetic_non_screen_bounds=S.CapabilitySignatureV4(synthetic_non_screen.schema,
        synthetic_non_screen.revision,synthetic_non_screen.kind,synthetic_non_screen.operator,
        synthetic_non_screen.states,synthetic_non_screen.source_space,synthetic_non_screen.target_space,
        synthetic_non_screen.dimension,synthetic_non_screen.coordinates,
        synthetic_non_screen.boundary_relation,synthetic_non_screen.interface_relation,
        synthetic_non_screen.time_semantics,synthetic_non_screen.required_output,
        synthetic_non_screen.evidence_level,canonical_hash((changed_non_screen_bounds=true,));
        input_schema_hash=synthetic_non_screen.input_schema_hash,
        coordinate_system=synthetic_non_screen.coordinate_system)
    @test S._smgw_q1_continuation_obligation_shapes_v1((synthetic_non_screen,),q14_bounds_hash)!=
        S._smgw_q1_continuation_obligation_shapes_v1((synthetic_non_screen_bounds,),q14_bounds_hash)
    @test S._smgw_q1_continuation_obligation_shapes_v1(
        (q14_screen,synthetic_non_screen),q14_bounds_hash)==
        S._smgw_q1_continuation_obligation_shapes_v1(
        (synthetic_non_screen,q14_screen),q14_bounds_hash)

    source_family=S._smgw_q1_continuation_context_family_v1(source_admission)
    target_family=S._smgw_q1_continuation_context_family_v1(target_admission)
    @test canonical_hash(source_family)==canonical_hash(target_family)

    different_parent_candidate=_candidate_with_identity(source.parent_context,
        "different-q1_4-continuation-parent")
    different_parent=_rebuild_candidate_context(source.parent_context,different_parent_candidate)
    physical_input=only(filter(value->value isa S.ThreeDPhysicalProviderInputV4,
        source.context.candidate.field_geometry_genome_ref.fields))
    wrong_child=S.build_spatial_candidate_v4(different_parent,physical_input;
        physical_declaration=declaration).context
    @test wrong_child.candidate_hash!=source.context.candidate_hash
    @test S.validate_spatial_manufactured_candidate_input_v1(wrong_child,input)
    wrong_admission=S._smgw_admit_context_v1(wrong_child)
    wrong_input=wrong_admission.declaration.source.input
    @test wrong_input==source_input
    wrong_family=S._smgw_q1_continuation_context_family_v1(wrong_admission)
    @test canonical_hash(wrong_family)!=canonical_hash(target_family)
    guard_error=try
        S._smgw_current_q1_4_artifact_state_v1(wrong_child,source.production_dir,target_context)
        nothing
    catch err
        err
    end
    @test guard_error isa ArgumentError
    @test sprint(showerror,guard_error)=="ArgumentError: Q1 continuation source candidate/context family differs from target"

    wrong_physics_input=S.spatial_n1_manufactured_input_v1(;level=:q1_8,
        interior_map=:m1n1_ripple_v1)
    wrong_physics_declaration=S.spatial_n1_manufactured_declaration_v1(wrong_physics_input)
    wrong_physics_context,_,_=fresh_manufactured_context(wrong_physics_input,wrong_physics_declaration)
    @test_throws ArgumentError S._smgw_current_q1_4_artifact_state_v1(
        source.context,source.production_dir,wrong_physics_context)
    nothing
end

function test_q1_4_to_q1_8_prolongation_v1()
    @testset "nested Q1_4 to Q1_8 prolongation" begin
        coarse_input=S.spatial_n1_manufactured_input_v1(;level=:q1_4)
        fine_input=S.spatial_n1_manufactured_input_v1(;level=:q1_8)
        coarse_declaration=S.spatial_n1_manufactured_declaration_v1(coarse_input)
        fine_declaration=S.spatial_n1_manufactured_declaration_v1(fine_input)
        coarse_mesh=S.build_spatial_mesh_v4(coarse_declaration,:q1_4,coarse_input.mesh.nfp)
        fine_mesh=S.build_spatial_mesh_v4(fine_declaration,:q1_8,fine_input.mesh.nfp)
        source_state=Vector{Float64}(undef,coarse_input.mesh.unknowns)
        for node in axes(coarse_mesh.nodes_q,2)
            rho,theta,zeta=coarse_mesh.nodes_q[:,node]
            source_state[4node-3]=0.3+2rho+3theta+5zeta
            source_state[4node-2]=-0.7-rho+2theta-zeta
            source_state[4node-1]=1.1+rho-theta+2zeta
            source_state[4node]=1.0e5+1.0e3rho+10theta+2zeta
        end
        source_before=copy(source_state)
        prolongated=S.spatial_q1_4_to_q1_8_initial_state_v1(coarse_input,coarse_mesh,
            source_state,fine_input,fine_mesh;pressure_scale_Pa=coarse_declaration.scaling.p_Pa)
        @test length(prolongated)==fine_input.mesh.unknowns
        @test all(isfinite,prolongated)
        @test minimum(prolongated[4:4:end])>=0.0
        @test source_state==source_before

        # Shared nodes are copied exactly; the toroidal axis uses its canonical periodic copy.
        coordinate_tolerance=64eps(Float64)*2pi
        for coarse_node in axes(coarse_mesh.nodes_q,2)
            q=coarse_mesh.nodes_q[:,coarse_node]
            fine_node=findfirst(candidate->maximum(abs.(fine_mesh.nodes_q[:,candidate].-q))<=coordinate_tolerance,
                axes(fine_mesh.nodes_q,2))
            @test fine_node!==nothing
            if fine_node!==nothing
                @test prolongated[4fine_node-3:4fine_node]==source_state[4coarse_node-3:4coarse_node]
            end
        end
        axis_nodes=findall(node->fine_mesh.nodes_q[1,node]==0.0,axes(fine_mesh.nodes_q,2))
        @test !isempty(axis_nodes)
        @test all(node->fine_mesh.nodes_q[2,node]==0.0,axis_nodes)

        # A factor-two cell midpoint must equal the exact trilinear average of its corners.
        cell=findfirst(bounds->bounds[1][1]>0.0 && bounds[2][1]>0.0 && bounds[3][1]>0.0 &&
            bounds[2][2]<2pi && bounds[3][2]<2pi,coarse_mesh.cell_bounds)
        @test cell!==nothing
        if cell!==nothing
            bounds=coarse_mesh.cell_bounds[cell]
            q=ntuple(axis->sum(bounds[axis])/2,3)
            fine_node=findfirst(candidate->maximum(abs.(fine_mesh.nodes_q[:,candidate].-collect(q)))<=coordinate_tolerance,
                axes(fine_mesh.nodes_q,2))
            @test fine_node!==nothing
            if fine_node!==nothing
                expected=Float64[0.3+2q[1]+3q[2]+5q[3],-0.7-q[1]+2q[2]-q[3],
                    1.1+q[1]-q[2]+2q[3],1.0e5+1.0e3q[1]+10q[2]+2q[3]]
                @test isapprox(prolongated[4fine_node-3:4fine_node],expected;rtol=2e-14,atol=2e-10)
            end
        end

        negative_pressure=copy(source_state)
        negative_pressure[4]=-1.0
        @test_throws ArgumentError S.spatial_q1_4_to_q1_8_initial_state_v1(coarse_input,coarse_mesh,
            negative_pressure,fine_input,fine_mesh;pressure_scale_Pa=coarse_declaration.scaling.p_Pa)
        wrong_physics=S.spatial_n1_manufactured_input_v1(;level=:q1_4,interior_map=:m1n1_ripple_v1)
        wrong_declaration=S.spatial_n1_manufactured_declaration_v1(wrong_physics)
        wrong_mesh=S.build_spatial_mesh_v4(wrong_declaration,:q1_4,wrong_physics.mesh.nfp)
        @test_throws ArgumentError S.spatial_q1_4_to_q1_8_initial_state_v1(wrong_physics,wrong_mesh,
            source_state,fine_input,fine_mesh;pressure_scale_Pa=coarse_declaration.scaling.p_Pa)
    end
    nothing
end

function producer_q1_level_main(out,level::Symbol;continuation_q1_4_root=nothing,
        interior_map::Symbol=:circular_v1)
    _q1_real_consumer_spec(level)
    interior_map===:circular_v1 || level===:q1_4 ||
        throw(ArgumentError("nondefault manufactured maps are admitted only by the Q1_4 consumer"))
    continuation_q1_4_root===nothing || level===:q1_8 ||
        throw(ArgumentError("Q1_4 continuation can initialize only the Q1_8 producer"))
    continuation_source=continuation_q1_4_root===nothing ? nothing :
        _q1_4_continuation_source_v1(continuation_q1_4_root)
    if level===:q1_8
        test_quartic_ray_alpha_v1()
        test_q1_4_to_q1_8_prolongation_v1()
    end
    test_canonical_tuple_view_v1()
    test_canonical_matrix_fragment_v1()
    ispath(out) && error("preserve existing $level global weak producer evidence directory")
    mkpath(out)
    println("SMGW_PRODUCER_START level=",level," julia=",VERSION," pid=",getpid()," threads=",Threads.nthreads());flush(stdout)
    input=S.spatial_n1_manufactured_input_v1(;level,interior_map)
    declaration=S.spatial_n1_manufactured_declaration_v1(input)
    context,parent_context=assert_candidate_chain(input,declaration;
        parent_context=continuation_source===nothing ? nothing : continuation_source.parent_context)
    context.candidate_hash!=parent_context.candidate_hash || error("$level candidate reused parent identity")
    continuation_source===nothing || test_q1_4_continuation_rejects_wrong_candidate_v1(
        continuation_source,context)
    println("SMGW_PHASE_BEGIN=official_$(level)_producer candidate=",context.candidate_hash);flush(stdout)
    producer_stage_trace=if level===:q1_8
        (name,edge,stamp)->begin
            println("SMGW_Q1_8_STAGE_",uppercase(String(edge))," name=",name,
                " monotonic_ns=",stamp)
            flush(stdout)
        end
    else
        nothing
    end
    result=if continuation_source===nothing
        S.execute_spatial_manufactured_global_weak_numerical_v1(
            context,joinpath(out,"production");residual_partition=:spatial_native,
            stage_trace=producer_stage_trace)
    else
        S.execute_spatial_manufactured_global_weak_numerical_v1(
            context,joinpath(out,"production");residual_partition=:spatial_native,
            stage_trace=producer_stage_trace,
            continuation_source_context=continuation_source.context,
            continuation_source_dir=continuation_source.production_dir)
    end
    report=result.report
    _assert_q1_level_solver_result(level,input,declaration,context,report)
    handoff_core=(schema="spatial-global-weak-$(level)-two-process-handoff-v1",
        level=level,semantic_identities=expected_semantic_identities(),
        candidate_hash=context.candidate_hash,context_hash=context.context_hash,
        declaration_hash=canonical_hash(declaration),input_hash=canonical_hash(input),
        result_hash=result.result_hash,solver_exit_code=report.solver_exit_code,
        final_scaled_residual_max=report.final_scaled_residual_max,
        formal_refinement_gate=:outstanding,
        physical_validation=:unsupported,authority=:no_publish)
    handoff=merge(handoff_core,level===:q1_4 ?
        (q1_4_nonlinear_solve=:producer_completed,) :
        (q1_8_nonlinear_solve=:producer_completed,))
    write(joinpath(out,"producer_handoff.json"),canonical_json(handoff)*"\n")
    println("SMGW_PRODUCER_COMPLETE level=",level," solver_exit=",report.solver_exit_code,
        " residual=",report.final_scaled_residual_max," formal_refinement_gate=outstanding");flush(stdout)
    nothing
end

producer_q1_4_main(out;interior_map::Symbol=:circular_v1)=
    producer_q1_level_main(out,:q1_4;interior_map)
producer_q1_8_main(out;continuation_q1_4_root=nothing)=
    producer_q1_level_main(out,:q1_8;continuation_q1_4_root=continuation_q1_4_root)

function _wire_solver_scope(primary,diagnostics)
    solver=primary["solver"]
    @test Int(primary["solver_exit_code"])==0
    @test primary["status"]=="converged" && primary["numerical_status"]=="full_discrete_residual_converged"
    @test primary["stopping_reason"]=="all_scaled_residuals_converged"
    @test Int(primary["accepted_update_count"])<=12
    @test Float64(primary["final_scaled_residual_max"])<=1.0e-6
    policy=solver["numerical_policy"]
    @test Int(policy["max_iterations"])==12 && Float64(policy["seconds"])==120.0
    @test Float64(policy["residual_tolerance"])==1.0e-6
    @test Float64(policy["gradient_tolerance"])==1.0e-10
    @test Float64(policy["rank_relative_tolerance"])==1.0e-10
    @test Float64(policy["kkt_absolute_tolerance"])==1.0e-10
    @test Int(policy["line_search_steps"])==20 && Float64(policy["pressure_lower_Pa"])==0.0
    @test primary["physical_validation"]=="unsupported" && primary["authority"]=="no_publish"
    @test primary["claim_ceiling"]=="screen_only"
    @test primary["desc_execution"]=="not_executed" && primary["engineering_execution"]=="not_executed"
    @test primary["whole_device_validation"]=="unsupported"
    @test primary["formal_policy"]["status"]=="typed_absent"
    @test primary["formal_policy"]["value"]===nothing
    closures=primary["spatial_closures"]
    @test Set(Symbol.(collect(keys(closures))))==Set((:J_source,:return_current_path,:B_out,:K_outer,:pressure_current_topology))
    @test all(c->c["status"]=="typed_absent" && c["value"]===nothing,values(closures))
    @test diagnostics.formal_refinement_gate==:outstanding
    @test diagnostics.required_formal_levels==(:q1_2,:q1_4,:q1_8)
    true
end

function _tree_map(value,f)
    value isa NamedTuple && return NamedTuple{keys(value)}(Tuple(_tree_map(v,f) for v in values(value)))
    value isa Tuple && return Tuple(_tree_map(v,f) for v in value)
    f(value)
end

function _replace_named_field(value::NamedTuple,key::Symbol,replacement)
    key in keys(value) || throw(ArgumentError("missing named wire field $key"))
    NamedTuple{keys(value)}(Tuple(k==key ? replacement : getproperty(value,k) for k in keys(value)))
end

function _without_named_field(value::NamedTuple,key::Symbol)
    key in keys(value) || throw(ArgumentError("missing named wire field $key"))
    names=Tuple(k for k in keys(value) if k!=key)
    NamedTuple{names}(Tuple(getproperty(value,k) for k in names))
end

function _relocate_wire_path(value,source_root,target_root)
    value isa AbstractString || return value
    isabspath(String(value)) || return value
    relative=relpath(String(value),source_root)
    parts=splitpath(relative)
    (!isabspath(relative) && !isempty(parts) && first(parts)!="..") || return value
    joinpath(target_root,relative)
end

function _write_rehashed_primary!(mutate_body,directory)
    path=joinpath(directory,"global_weak_primary.json")
    top=S._smr_read_canonical_json_v1(read(path,String))
    body=_without_named_field(top,:result_hash)
    changed=mutate_body(body)
    result_hash=canonical_hash(changed)
    write(path,canonical_json(merge(changed,(result_hash=result_hash,)))*"\n")
    path
end

function _rewrite_state_artifact_sha(body,directory)
    state_sha=sha(joinpath(directory,"solver_state.csv"))
    artifacts=Tuple(a.name=="state" ? _replace_named_field(a,:sha256,state_sha) : a
        for a in body.artifacts)
    _replace_named_field(body,:artifacts,artifacts)
end

function _copy_relocated_run(context,source_root,target_root,admission)
    ispath(target_root) && throw(ArgumentError("preserve existing tamper-control directory"))
    cp(source_root,target_root)
    _write_rehashed_primary!(target_root) do body
        _tree_map(body,value->_relocate_wire_path(value,source_root,target_root))
    end
    provider_path=joinpath(target_root,"geometry","manufactured_provider.json")
    provider=S._smr_read_canonical_json_v1(read(provider_path,String))
    moved_provider=_tree_map(provider,value->_relocate_wire_path(value,source_root,target_root))
    write(provider_path,canonical_json(moved_provider)*"\n")
    primary_path=joinpath(target_root,"global_weak_primary.json")
    primary=S._smr_read_canonical_json_v1(read(primary_path,String))
    declared=S._smr_declaration(context)
    input=declared.source.input
    admission.candidate_hash==context.candidate_hash && admission.context_hash==context.context_hash &&
        admission.declaration_hash==canonical_hash(declared) &&
        admission.input_hash==canonical_hash(input) ||
        error("relocation admission differs from fresh candidate context")
    receipt=S._smgw_geometry_receipt_from_wire_v1(primary.geometry_receipt,input)
    S._smm_validate_geometry_receipt_v1(input,declared,
        (candidate_hash=context.candidate_hash,context_hash=context.context_hash),receipt)
    data=S.load_spatial_data_v4(declared,(level=input.mesh.level,nfp=input.mesh.nfp,
        flux_Wb=input.flux.nominal_Wb,raw_artifacts=receipt.raw_artifacts))
    initial=Tuple(data.initial_state)
    solver=primary.solver
    residual_partition=S._smgw_verify_solver_step_identity_v1(solver)
    seal=S._smgw_capture_validator_fresh_data_binding_v1(admission,data,receipt,initial;
        residual_partition)
    operator_binding=S._smgw_operator_binding_wire_v1(seal)
    _write_rehashed_primary!(target_root) do body
        solver=_replace_named_field(body.solver,:operator_binding,operator_binding)
        _replace_named_field(body,:solver,solver)
    end
    target_root
end

function _integrity_fixture_manifest_v1(root)
    isdir(root) && !islink(root) || throw(ArgumentError("integrity fixture root is absent or linked"))
    paths=String[]
    for (directory,subdirectories,files) in walkdir(root;follow_symlinks=false)
        any(name->islink(joinpath(directory,name)),subdirectories) &&
            throw(ArgumentError("integrity fixture contains a linked directory"))
        for name in files
            path=joinpath(directory,name)
            islink(path) && throw(ArgumentError("integrity fixture contains a linked file"))
            isfile(path) && push!(paths,path)
        end
    end
    sort!(paths;by=path->replace(relpath(path,root),'\\'=>'/'))
    file_manifest=Tuple((path=replace(relpath(path,root),'\\'=>'/'),sha256=sha(path)) for path in paths)
    isempty(file_manifest) && throw(ArgumentError("integrity fixture contains no files"))
    manifest=(schema="spatial-global-weak-integrity-fixture-manifest-v1",files=file_manifest)
    (manifest=manifest,sha256=string(canonical_hash(manifest)))
end

function expect_relocated_artifact_replay_positive!(context,source_root,positive_root,semantic_ids,consumer_admission)
    copied=_copy_relocated_run(context,source_root,positive_root,consumer_admission)
    replay=S.validate_spatial_manufactured_global_weak_artifacts_v1(context,copied;
        expected_candidate_hash=string(context.candidate_hash),expected_context_hash=string(context.context_hash),
        expected_input_hash=string(canonical_hash(S._smr_declaration(context).source.input)),
        expected_semantic_identities=semantic_ids,_consumer_admission=consumer_admission)
    @test replay.validation==:artifact_replay_completed
    @test replay.candidate_hash==string(context.candidate_hash)
    @test replay.context_hash==string(context.context_hash)
    @test replay.physical_validation==:unsupported && replay.authority==:no_publish
    replay.validation==:artifact_replay_completed &&
        replay.candidate_hash==string(context.candidate_hash) &&
        replay.context_hash==string(context.context_hash) &&
        replay.physical_validation==:unsupported && replay.authority==:no_publish ||
        error("relocated artifact replay positive control failed")
    true
end

function _rewrite_tampered_state!(directory,mutate_row;sync_solver_state=false)
    path=joinpath(directory,"solver_state.csv")
    lines=readlines(path)
    lines[2:end]=mutate_row(lines[2:end])
    write(path,join(lines,'\n')*"\n")
    _write_rehashed_primary!(directory) do body
        updated=_rewrite_state_artifact_sha(body,directory)
        sync_solver_state || return updated
        state=Tuple(read_state_csv(path,length(lines)-1))
        solver=updated.solver
        history=Tuple(index==length(solver.state_history) ? state : row
            for (index,row) in enumerate(solver.state_history))
        solver=_replace_named_field(solver,:final_state,state)
        solver=_replace_named_field(solver,:state_history,history)
        _replace_named_field(updated,:solver,solver)
    end
end

function expect_artifact_replay_rejection!(context,production_dir,tamper_root,kind,semantic_ids,expected_reason,
        consumer_admission)
    copied=_copy_relocated_run(context,production_dir,joinpath(tamper_root,kind),consumer_admission)
    if kind=="csv_active_dof_rehashed"
        _rewrite_tampered_state!(copied,rows->begin
            fields=split(rows[2],',');fields[2]=string(parse(Float64,fields[2])+1.0e-6)
            rows[2]=join(fields,',');rows
        end;sync_solver_state=true)
    elseif kind=="csv_only_active_dof_rehashed"
        _rewrite_tampered_state!(copied,rows->begin
            fields=split(rows[2],',');fields[2]=string(parse(Float64,fields[2])+1.0e-6)
            rows[2]=join(fields,',');rows
        end)
    elseif kind=="csv_duplicate_node_rehashed"
        _rewrite_tampered_state!(copied,rows->begin
            fields=split(rows[2],',');fields[1]="1";rows[2]=join(fields,',');rows
        end)
    elseif kind=="csv_malformed_node_rehashed"
        _rewrite_tampered_state!(copied,rows->begin
            fields=split(rows[2],',');fields[1]="02";rows[2]=join(fields,',');rows
        end)
    elseif kind in ("stale_candidate_binding","stale_context_binding")
        _write_rehashed_primary!(copied) do body
            binding=body.binding
            field=kind=="stale_candidate_binding" ? :candidate_hash : :context_hash
            stale=(value=repeat("0",64),)
            _replace_named_field(body,:binding,_replace_named_field(binding,field,stale))
        end
    else
        throw(ArgumentError("unknown artifact replay tamper case"))
    end
    failure=try
        S.validate_spatial_manufactured_global_weak_artifacts_v1(context,copied;
            expected_candidate_hash=string(context.candidate_hash),expected_context_hash=string(context.context_hash),
            expected_input_hash=string(canonical_hash(S._smr_declaration(context).source.input)),
            expected_semantic_identities=semantic_ids,_consumer_admission=consumer_admission)
        nothing
    catch error
        error
    end
    @test failure isa ArgumentError
    if failure isa ArgumentError
        @test occursin(expected_reason,sprint(showerror,failure))
    end
    failure isa ArgumentError && occursin(expected_reason,sprint(showerror,failure)) ||
        error("artifact replay rejection differed from expected reason: $expected_reason")
    true
end

function _smgw_receipt_with_raw_artifacts(receipt,raw_artifacts)
    S.SpatialManufacturedGeometryReceiptV1(receipt.schema,receipt.candidate_hash,
        receipt.context_hash,receipt.declaration_hash,receipt.input_hash,receipt.provider,
        receipt.provider_source,raw_artifacts,receipt.initializer_hash,receipt.reference_state_hash,
        receipt.enclosure,receipt.desc_execution,receipt.physical_validation,receipt.authority)
end

function _smgw_changed_operator_data(data,kind)
    if kind==:mesh_node_coordinates
        changed=deepcopy(data)
        changed.mesh.nodes_q[1,1]=nextfloat(changed.mesh.nodes_q[1,1])
        return changed
    elseif kind==:cell_connectivity
        changed=deepcopy(data);cell=changed.mesh.cell_nodes[1]
        cell[1]=mod1(cell[1]+1,size(changed.mesh.nodes_q,2))
        return changed
    elseif kind==:mesh_face_orientation
        changed=deepcopy(data);mesh=changed.mesh
        index=findfirst(face->face.role==:interface,mesh.faces)
        index===nothing && throw(ArgumentError("fixture has no two-sided interface face"))
        face=mesh.faces[index]
        face.right_cell>0 || throw(ArgumentError("selected interface face has no right cell"))
        mesh.faces[index]=merge(face,(left_cell=face.right_cell,right_cell=face.left_cell))
        return changed
    elseif kind==:corner_to_local
        changed=deepcopy(data);mapping=changed.mesh.corner_to_local[1]
        length(mapping)>1 || throw(ArgumentError("corner map is too short to mutate"))
        mapping[1]=mod1(mapping[1]+1,length(mapping))
        return changed
    elseif kind==:row_layout_support
        changed=deepcopy(data);support=changed.mesh.row_supports[1]
        length(support)>1 || throw(ArgumentError("row support is too short to mutate"))
        support[1]=mod1(support[1]+1,4*size(changed.mesh.nodes_q,2))
        return changed
    elseif kind==:row_layout_block
        changed=deepcopy(data)
        changed.mesh.row_blocks[1]=:forged_operator_row
        return changed
    elseif kind==:node_quadrature
        rows=copy(data.nodes);sample=rows[1]
        q=collect(sample.q);q[1]=nextfloat(q[1])
        rows[1]=merge(sample,(q=Tuple(q),))
        return merge(data,(nodes=rows,))
    elseif kind==:volume_quadrature
        rows=copy(data.volume);sample=rows[1]
        rows[1]=merge(sample,(weight=nextfloat(sample.weight),))
        return merge(data,(volume=rows,))
    elseif kind==:face_quadrature
        rows=copy(data.face_quadrature);sample=rows[1]
        rows[1]=merge(sample,(weight=nextfloat(sample.weight),))
        return merge(data,(face_quadrature=rows,))
    elseif kind==:initial_state_payload
        changed=copy(data.initial_state);changed[1]=nextfloat(changed[1])
        return merge(data,(initial_state=changed,))
    elseif kind==:continuous_enclosure
        enclosure=merge(data.continuous_enclosure,(R_upper_m=nextfloat(data.continuous_enclosure.R_upper_m),))
        return merge(data,(continuous_enclosure=enclosure,))
    end
    throw(ArgumentError("unknown operator-data mutation"))
end

function _smgw_bigfloat_projection_alias(data)
    rows=copy(data.volume)
    sample=rows[1]
    alias=BigFloat(sample.weight)+BigFloat(eps(sample.weight))/4
    typeof(alias)===BigFloat && alias!=BigFloat(sample.weight) &&
        Float64(alias)==sample.weight || throw(ArgumentError("BigFloat alias does not preserve the original Float64 projection"))
    rows[1]=merge(sample,(weight=alias,))
    merge(data,(volume=rows,))
end

function _smgw_binding_rejection(seal,context,declaration,data,receipt,initial)
    try
        S._smgw_assert_operator_binding_v1(seal,context,declaration,data,receipt,initial)
        nothing
    catch err
        err
    end
end

function _smgw_rehashed_raw_artifact_guard_control!(context,declaration,data,receipt,
        admission,initial,control_root)
    ispath(control_root) && throw(ArgumentError("preserve existing raw-artifact binding control"))
    mkpath(control_root)
    raw=NamedTuple{keys(receipt.raw_artifacts)}(Tuple(begin
        source=getproperty(receipt.raw_artifacts,key)
        path=joinpath(control_root,"manufactured_$(key).csv")
        cp(source.path,path)
        S.SpatialArtifactV4(path,S.Digest256(sha(path)),source.schema,source.row_count)
    end for key in keys(receipt.raw_artifacts)))
    copied_receipt=_smgw_receipt_with_raw_artifacts(receipt,raw)
    copied_data=merge(data,(raw_artifacts=raw,))
    copied_seal=S._smgw_capture_operator_binding_v1(admission,copied_data,copied_receipt,initial)
    copied_fingerprint=S._smgw_assert_operator_binding_v1(copied_seal,context,declaration,
        copied_data,copied_receipt,initial)
    @test occursin(r"^[0-9a-f]{64}$",copied_fingerprint)

    volume_path=raw.volume.path
    lines=readlines(volume_path)
    fields=split(lines[2],',')
    fields[11]=repr(parse(Float64,fields[11])*1.000001)
    lines[2]=join(fields,',')
    write(volume_path,join(lines,'\n')*"\n")
    rehashed_volume=S.SpatialArtifactV4(volume_path,S.Digest256(sha(volume_path)),
        raw.volume.schema,raw.volume.row_count)
    forged_raw=merge(raw,(volume=rehashed_volume,))
    forged_data=merge(copied_data,(raw_artifacts=forged_raw,))
    forged_receipt=_smgw_receipt_with_raw_artifacts(copied_receipt,forged_raw)
    failure=_smgw_binding_rejection(copied_seal,context,declaration,forged_data,forged_receipt,initial)
    @test failure isa ArgumentError &&
        occursin("geometry receipt binding changed",sprint(showerror,failure))
    capture_failure=try
        S._smgw_capture_operator_binding_v1(admission,forged_data,forged_receipt,initial)
        nothing
    catch err
        err
    end
    @test capture_failure isa ArgumentError &&
        occursin("raw geometry/model replay mismatch",sprint(showerror,capture_failure))
    true
end

function assert_operator_binding_controls!(context,parent_context,declaration,data,receipt,
        initial,primary,consumer_dir)
    admission=S._smgw_admit_context_v1(context)
    seal=S._smgw_capture_operator_binding_v1(admission,data,receipt,initial)
    fingerprint=S._smgw_assert_operator_binding_v1(seal,context,declaration,data,receipt,initial)
    @test occursin(r"^[0-9a-f]{64}$",fingerprint)
    live_operator_binding=S._smr_json_native_v1(JSON3.read(
        canonical_json(S._smgw_operator_binding_wire_v1(seal))))
    @test S._smr_json_native_v1(primary["solver"]["operator_binding"])==live_operator_binding

    @testset "production operator binding rejects stale inputs and payloads" begin
        wrong_context=_smgw_binding_rejection(seal,parent_context,declaration,data,receipt,initial)
        @test wrong_context isa ArgumentError
        for kind in (:mesh_node_coordinates,:cell_connectivity,:mesh_face_orientation,
                :corner_to_local,:row_layout_support,:row_layout_block,
                :node_quadrature,:volume_quadrature,:face_quadrature,
                :initial_state_payload,:continuous_enclosure)
            changed=_smgw_changed_operator_data(data,kind)
            failure=_smgw_binding_rejection(seal,context,declaration,changed,receipt,initial)
            @test failure isa ArgumentError
        end
        bigfloat_data=_smgw_bigfloat_projection_alias(data)
        @test typeof(bigfloat_data.volume[1].weight)===BigFloat
        @test Float64(bigfloat_data.volume[1].weight)==data.volume[1].weight
        @test bigfloat_data.volume[1].weight!=BigFloat(data.volume[1].weight)
        bigfloat_failure=_smgw_binding_rejection(seal,context,declaration,bigfloat_data,receipt,initial)
        @test bigfloat_failure isa ArgumentError &&
            occursin("quadrature sample weight must retain a finite Float64 loader value",
                sprint(showerror,bigfloat_failure))
        changed_initial=copy(initial);changed_initial[1]=nextfloat(changed_initial[1])
        @test _smgw_binding_rejection(seal,context,declaration,data,receipt,changed_initial) isa ArgumentError

        stale_identities=merge(seal.semantic_identities,
            (accepted_step_core_semantic_hash=repeat("0",64),))
        stale_seal=S._SMGWOperatorBindingSealV1(seal.admission,seal.receipt_hash,
            seal.data_fingerprint,seal.initial_state_hash,stale_identities,
            seal.residual_partition,seal.step_identity)
        @test _smgw_binding_rejection(stale_seal,context,declaration,data,receipt,initial) isa ArgumentError

        @test _smgw_rehashed_raw_artifact_guard_control!(context,declaration,data,receipt,
            admission,initial,joinpath(consumer_dir,"operator_binding_mutations","operator_binding_rehashed_raw"))
    end

    state_before=copy(initial)
    trial_data=Ref{Any}(data)
    trial_calls=Ref(0)
    trial_assembly_returned=Ref(false)
    accepted_return=nothing
    trial_failure=try
        accepted_return=S.MultiTopologyNonlinearSolveV1.accepted_step_v1(initial,
            [i==1 ? 1.0e-6 : 0.0 for i in eachindex(initial)],ones(length(initial));
            objective_before=1.0,directional_derivative=-1.0,max_backtracks=1,
            armijo_fraction=1.0e-4,require_strict_decrease=false,
            assemble_trial=trial_state->begin
                trial_calls[]+=1
                trial_data[]=_smgw_bigfloat_projection_alias(data)
                trial_assembly=S.assemble_spatial_global_weak_system_v1(declaration,trial_data[],trial_state;
                    flux_Wb=declaration.flux.nominal_Wb,jacobian=false)
                trial_assembly_returned[]=true
                trial_assembly
            end,
            assembly_ready=_->true,unavailable_reason=_->nothing,
            residual_for_merit=trial_assembly->trial_assembly.residual,
            merit=(assembly,residual)->0.5*sum(abs2,residual),
            project_state=identity,feasible=_->true,changed=(before,after)->before!=after,
            evaluation_record=_->nothing,
            binding_guard=()->S._smgw_assert_operator_binding_v1(seal,context,declaration,
                trial_data[],receipt,initial))
        nothing
    catch err
        err
    end
    @test trial_failure isa ArgumentError
    @test occursin("quadrature sample weight must retain a finite Float64 loader value",
        sprint(showerror,trial_failure))
    @test trial_calls[]==1
    @test trial_assembly_returned[]
    @test accepted_return===nothing
    @test initial==state_before
    @test trial_data[]!==data
    (status=:operator_binding_rejected_during_trial,exception=string(typeof(trial_failure)),
        exception_message=sprint(showerror,trial_failure),trial_calls=trial_calls[],
        trial_assembly_returned=trial_assembly_returned[],accepted_returned=false,formal_credit=false,
        physical_validation=:unsupported,authority=:no_publish)
end

const _INTEGRITY_CASE_PHASES_V1=(
    (:integrity_relocation_positive,"relocation_positive"),
    (:integrity_csv_active_dof_rehashed,"csv_active_dof_rehashed"),
    (:integrity_csv_only_active_dof_rehashed,"csv_only_active_dof_rehashed"),
    (:integrity_csv_duplicate_node_rehashed,"csv_duplicate_node_rehashed"),
    (:integrity_csv_malformed_node_rehashed,"csv_malformed_node_rehashed"),
    (:integrity_stale_candidate_binding,"stale_candidate_binding"),
    (:integrity_stale_context_binding,"stale_context_binding"))
const _CONSUMER_PHASES_V1=(:diagnostics,:identity_replay,:inhouse_produce,
    :inhouse_validate,:inhouse_replay,:csv_oracle,
    :integrity_relocation_positive,:integrity_csv_active_dof_rehashed,
    :integrity_csv_only_active_dof_rehashed,:integrity_csv_duplicate_node_rehashed,
    :integrity_csv_malformed_node_rehashed,:integrity_stale_candidate_binding,
    :integrity_stale_context_binding,:integrity_finalize)

function _consumer_phase_receipt_path_v1(consumer_dir,phase)
    joinpath(consumer_dir,"consumer_phase_$(phase)_receipt.json")
end

function _consumer_write_phase_receipt_v1(consumer_dir,phase,payload)
    path=_consumer_phase_receipt_path_v1(consumer_dir,phase)
    ispath(path) && error("preserve existing consumer phase receipt: $phase")
    payload_wire=canonical_json(payload)*"\n"
    receipt=(schema="spatial-global-weak-consumer-phase-receipt-v1",
        phase=String(phase),payload_json=payload_wire,
        payload_sha256=bytes2hex(SHA.sha256(codeunits(payload_wire))))
    write(path,canonical_json(receipt)*"\n")
    path
end

function _consumer_read_phase_receipt_v1(consumer_dir,phase)
    path=_consumer_phase_receipt_path_v1(consumer_dir,phase)
    isfile(path) || error("required earlier consumer phase receipt is absent: $phase")
    wire=read(path,String)
    S._smr_read_canonical_json_v1(wire)
    receipt=JSON3.read(wire)
    receipt["schema"]=="spatial-global-weak-consumer-phase-receipt-v1" ||
        error("consumer phase receipt schema mismatch: $phase")
    receipt["phase"]==String(phase) || error("consumer phase receipt name mismatch: $phase")
    payload_wire=String(receipt["payload_json"])
    bytes2hex(SHA.sha256(codeunits(payload_wire)))==String(receipt["payload_sha256"]) ||
        error("consumer phase receipt payload hash mismatch: $phase")
    S._smr_read_canonical_json_v1(payload_wire)
    JSON3.read(payload_wire)
end

function _consumer_artifact_binding_v1(artifact_dir;include_primary_projection=false)
    primary_path=joinpath(artifact_dir,"global_weak_primary.json")
    isfile(primary_path) || throw(ArgumentError("GlobalWeak primary artifact is absent"))
    primary_wire=read(primary_path,String)
    primary=S._smr_read_canonical_json_v1(primary_wire)
    artifacts=Tuple(sort!(collect((
        begin
            name=String(a.name)
            relpath=get(Dict("state"=>"solver_state.csv","residual"=>"residual_rows.csv",
                "jacobian"=>"global_weak_jacobian.csv","row_supports"=>"global_weak_row_supports.csv",
                "iterations"=>"iterations.json","attempts"=>"attempts.json"),name,nothing)
            relpath===nothing && throw(ArgumentError("unknown GlobalWeak artifact name: $name"))
            expected=joinpath(artifact_dir,relpath)
            normpath(String(a.path))==normpath(expected) ||
                throw(ArgumentError("GlobalWeak artifact path is not confined to its production directory"))
            (name=name,path=normpath(expected),declared_sha256=wire_digest(a.sha256),
                actual_sha256=isfile(expected) ? sha(expected) : "missing")
        end for a in primary.artifacts));by=x->x.name))
    raw=primary.geometry_receipt.raw_artifacts
    raw_paths=Dict("nodes"=>joinpath(artifact_dir,"geometry","manufactured_nodes.csv"),
        "volume"=>joinpath(artifact_dir,"geometry","manufactured_volume.csv"),
        "faces"=>joinpath(artifact_dir,"geometry","manufactured_faces.csv"))
    raw_artifacts=Tuple(sort!(collect((
        begin
            key=String(name)
            expected=get(raw_paths,key,nothing)
            expected===nothing && throw(ArgumentError("unknown raw geometry artifact: $key"))
            normpath(String(getproperty(raw,Symbol(name)).path))==normpath(expected) ||
                throw(ArgumentError("raw geometry artifact path is not confined to its production directory"))
            (name=key,path=normpath(expected),declared_sha256=wire_digest(getproperty(raw,Symbol(name)).sha256),
                actual_sha256=isfile(expected) ? sha(expected) : "missing")
        end for name in keys(raw)));by=x->x.name))
    binding=(primary_sha256=sha(primary_path),result_hash=wire_digest(primary.result_hash),
        artifact_set_hash=string(canonical_hash(artifacts)),
        geometry_artifact_set_hash=string(canonical_hash(raw_artifacts)))
    include_primary_projection || return binding
    primary_binding=hasproperty(primary,:binding) ? primary.binding : nothing
    solver=hasproperty(primary,:solver) ? primary.solver : nothing
    operator_binding=solver!==nothing && hasproperty(solver,:operator_binding) ? solver.operator_binding : nothing
    projection=(
        binding=primary_binding===nothing ? nothing : (
            candidate_hash=hasproperty(primary_binding,:candidate_hash) ? primary_binding.candidate_hash : nothing,
            context_hash=hasproperty(primary_binding,:context_hash) ? primary_binding.context_hash : nothing),
        input_hash=hasproperty(primary,:input_hash) ? primary.input_hash : nothing,
        geometry_receipt=hasproperty(primary,:geometry_receipt) ? primary.geometry_receipt : nothing,
        solver=(
            final_state=solver!==nothing && hasproperty(solver,:final_state) ? solver.final_state : nothing,
            operator_binding=operator_binding===nothing ? nothing : (
                candidate_hash=hasproperty(operator_binding,:candidate_hash) ? operator_binding.candidate_hash : nothing,
                context_hash=hasproperty(operator_binding,:context_hash) ? operator_binding.context_hash : nothing)),
        solver_exit_code=hasproperty(primary,:solver_exit_code) ? primary.solver_exit_code : nothing,
        status=hasproperty(primary,:status) ? primary.status : nothing,
        numerical_status=hasproperty(primary,:numerical_status) ? primary.numerical_status : nothing,
        final_scaled_residual_max=hasproperty(primary,:final_scaled_residual_max) ?
            primary.final_scaled_residual_max : nothing)
    merge(binding,(primary_projection=projection,))
end

function _consumer_phase_binding_v1(input,declaration,context,artifact_binding=nothing)
    (semantic_identities=expected_semantic_identities(),
        input_hash=string(canonical_hash(input)),
        declaration_hash=string(canonical_hash(declaration)),
        candidate_hash=context===nothing ? nothing : string(context.candidate_hash),
        context_hash=context===nothing ? nothing : string(context.context_hash),
        producer_result_hash=artifact_binding===nothing ? nothing : artifact_binding.result_hash,
        producer_artifact_binding=artifact_binding)
end

function _consumer_assert_phase_binding_v1(payload,input,declaration,context,artifact_binding)
    input_ok=String(payload["input_hash"])==string(canonical_hash(input))
    declaration_ok=String(payload["declaration_hash"])==string(canonical_hash(declaration))
    candidate_ok=String(payload["candidate_hash"])==string(context.candidate_hash)
    context_ok=String(payload["context_hash"])==string(context.context_hash)
    result_ok=String(payload["producer_result_hash"])==artifact_binding.result_hash
    semantic_ok=semantic_identities_match(payload["semantic_identities"])
    stored_binding=S._smr_json_native_v1(payload["producer_artifact_binding"])
    producer_ok=canonical_hash(stored_binding)==canonical_hash(artifact_binding)
    @test semantic_identities_match(payload["semantic_identities"])
    @test input_ok
    @test declaration_ok
    @test candidate_ok
    @test context_ok
    @test result_ok
    @test producer_ok
    semantic_ok && input_ok && declaration_ok && candidate_ok && context_ok && result_ok && producer_ok ||
        error("consumer phase candidate/source/producer artifact binding mismatch")
    true
end

function _consumer_diagnostics_from_json_v1(wire)
    parsed=S._smr_json_native_v1(JSON3.read(wire))
    levels=Tuple(merge(level,(level=Symbol(level.level),
        nonlinear_solve=Symbol(level.nonlinear_solve),
        physical_validation=Symbol(level.physical_validation),
        authority=Symbol(level.authority),scope=Symbol(level.scope))) for level in parsed.levels)
    merge(parsed,(levels=levels,required_formal_levels=Tuple(Symbol.(parsed.required_formal_levels)),
        formal_refinement_gate=Symbol(parsed.formal_refinement_gate),
        claim_ceiling=Symbol(parsed.claim_ceiling),
        physical_validation=Symbol(parsed.physical_validation),authority=Symbol(parsed.authority),
        solver_runs=Tuple(Symbol.(parsed.solver_runs))))
end

function consumer_main(out,consumer_output_dir=joinpath(out,"consumer"),phase::Symbol=:all)
    production_dir=joinpath(out,"production")
    isdir(production_dir) || error("producer artifact directory is absent")
    phase in (:all,_CONSUMER_PHASES_V1...) || error("unknown consumer phase: $phase")
    consumer_dir=abspath(consumer_output_dir)
    real_out=realpath(out)
    realpath(dirname(consumer_dir))==real_out ||
        error("consumer output directory must be a direct child of the production artifact root")
    if phase in (:all,:diagnostics)
        ispath(consumer_dir) && error("preserve existing global weak consumer evidence directory")
        mkdir(consumer_dir)
    else
        isdir(consumer_dir) || error("diagnostics phase must create the consumer evidence directory first")
        islink(consumer_dir) && error("consumer evidence directory must not be a link")
        expected_consumer=normpath(joinpath(real_out,basename(consumer_dir)))
        lowercase(normpath(realpath(consumer_dir)))==lowercase(expected_consumer) ||
            error("consumer evidence directory must resolve directly under the production artifact root")
    end
    if phase!==:all
        ispath(_consumer_phase_receipt_path_v1(consumer_dir,phase)) &&
            error("preserve existing consumer phase evidence: $phase")
        phase===:inhouse_produce && !isfile(_consumer_phase_receipt_path_v1(consumer_dir,:identity_replay)) &&
            error("identity replay phase must complete before InHouse production")
        phase===:inhouse_validate &&
            (!isfile(_consumer_phase_receipt_path_v1(consumer_dir,:inhouse_produce)) ||
                !isfile(_consumer_phase_receipt_path_v1(consumer_dir,:identity_replay))) &&
            error("InHouse production and identity receipts are required before validation")
        phase===:inhouse_validate && ispath(_consumer_phase_receipt_path_v1(consumer_dir,:inhouse_replay)) &&
            error("preserve existing final InHouse replay receipt")
        phase in first.(_INTEGRITY_CASE_PHASES_V1) &&
            !isfile(_consumer_phase_receipt_path_v1(consumer_dir,:csv_oracle)) &&
            error("CSV/oracle phase receipt is required before integrity controls")
        phase===:integrity_finalize &&
            (!isfile(_consumer_phase_receipt_path_v1(consumer_dir,:csv_oracle)) ||
                any(case->!isfile(_consumer_phase_receipt_path_v1(consumer_dir,case[1])),
                    _INTEGRITY_CASE_PHASES_V1)) &&
            error("all seven integrity control receipts and the CSV/oracle receipt are required before finalization")
        if phase===:csv_oracle
            for name in ("operator_binding_negative_controls.json","independent_fd_check.json",
                "independent_global_weak_consumer_receipt.json","operator_binding_mutations",
                "integrity_negative_controls")
                ispath(joinpath(consumer_dir,name)) &&
                    error("preserve existing consumer phase output: $name")
            end
        elseif phase in first.(_INTEGRITY_CASE_PHASES_V1) &&
                ispath(joinpath(consumer_dir,"integrity_negative_controls",
                    only(filter(case->case[1]===phase,_INTEGRITY_CASE_PHASES_V1))[2]))
            error("preserve existing integrity control evidence: $phase")
        elseif phase===:integrity_finalize && ispath(joinpath(consumer_dir,"independent_global_weak_consumer_receipt.json"))
            error("preserve existing final independent consumer receipt")
        end
    end
    inhouse_dir=joinpath(consumer_dir,"inhouse_kkt_production")
    if phase===:inhouse_produce
        ispath(inhouse_dir) && error("preserve existing InHouse production evidence directory")
    elseif phase===:inhouse_validate
        isdir(inhouse_dir) || error("InHouse production phase must create its evidence directory first")
        islink(inhouse_dir) && error("InHouse production evidence directory must not be a link")
        expected_inhouse=normpath(joinpath(consumer_dir,"inhouse_kkt_production"))
        lowercase(normpath(realpath(inhouse_dir)))==lowercase(expected_inhouse) ||
            error("InHouse production evidence directory must remain inside the consumer directory")
    end
    println("SMGW_CONSUMER_START julia=",VERSION," pid=",getpid()," threads=",Threads.nthreads());flush(stdout)
    input=S.spatial_n1_manufactured_input_v1()
    declaration=S.spatial_n1_manufactured_declaration_v1(input)
    @testset "fresh consumer semantic identities, candidate, and policy" begin
        assert_frozen_input(input,declaration)
    end
    diagnostics_path=joinpath(consumer_dir,"analytic_multilevel_diagnostics.json")
    if phase in (:all,:diagnostics)
        diagnostics=check_multilevel_diagnostics(input,declaration,consumer_dir)
        if phase===:diagnostics
            diagnostics_json=read(diagnostics_path,String)
            producer_binding=_consumer_artifact_binding_v1(production_dir)
            _consumer_write_phase_receipt_v1(consumer_dir,:diagnostics,(
                semantic_identities=expected_semantic_identities(),
                input_hash=string(canonical_hash(input)),
                declaration_hash=string(canonical_hash(declaration)),candidate_hash=nothing,
                context_hash=nothing,producer_result_hash=producer_binding.result_hash,
                producer_artifact_binding=producer_binding,
                diagnostics_file_sha256=sha(diagnostics_path),
                diagnostics_hash=sha(diagnostics_path),diagnostics_json=diagnostics_json))
            println("SMGW_CONSUMER_PHASE_COMPLETE=diagnostics");flush(stdout)
            return nothing
        end
    else
        diagnostic_receipt=_consumer_read_phase_receipt_v1(consumer_dir,:diagnostics)
        diagnostics_semantic_ok=semantic_identities_match(diagnostic_receipt["semantic_identities"])
        diagnostics_input_ok=String(diagnostic_receipt["input_hash"])==string(canonical_hash(input))
        diagnostics_declaration_ok=String(diagnostic_receipt["declaration_hash"])==string(canonical_hash(declaration))
        diagnostics_candidate_absent=diagnostic_receipt["candidate_hash"]===nothing
        diagnostics_context_absent=diagnostic_receipt["context_hash"]===nothing
        @test diagnostics_semantic_ok
        @test diagnostics_input_ok
        @test diagnostics_declaration_ok
        @test diagnostics_candidate_absent
        @test diagnostics_context_absent
        isfile(diagnostics_path) || error("diagnostics output is absent")
        diagnostics_json=read(diagnostics_path,String)
        diagnostics_file_binding_ok=sha(diagnostics_path)==String(diagnostic_receipt["diagnostics_file_sha256"])
        @test diagnostics_file_binding_ok
        diagnostics=_consumer_diagnostics_from_json_v1(diagnostics_json)
        diagnostics_hash_binding_ok=sha(diagnostics_path)==String(diagnostic_receipt["diagnostics_hash"])
        @test diagnostics_hash_binding_ok
        if phase in first.(_INTEGRITY_CASE_PHASES_V1) || phase===:integrity_finalize
            diagnostics_semantic_ok && diagnostics_input_ok && diagnostics_declaration_ok &&
                diagnostics_candidate_absent && diagnostics_context_absent &&
                diagnostics_file_binding_ok && diagnostics_hash_binding_ok ||
                error("integrity leaf diagnostics/source binding mismatch")
        end
    end
    println("SMGW_PHASE_BEGIN=fresh_candidate_chain");flush(stdout)
    context,parent_context=assert_candidate_chain(input,declaration)
    println("SMGW_PHASE_END=fresh_candidate_chain candidate=",context.candidate_hash);flush(stdout)
    replay_admission=(phase in first.(_INTEGRITY_CASE_PHASES_V1) || phase===:csv_oracle ||
        phase===:integrity_finalize) ?
        S._smgw_admission_record_v1(context,declaration) : nothing
    primary_path=joinpath(production_dir,"global_weak_primary.json")
    primary_wire=read(primary_path,String)
    S._smr_read_canonical_json_v1(primary_wire)
    primary=JSON3.read(primary_wire)
    artifact_binding=phase===:all ? nothing : _consumer_artifact_binding_v1(production_dir)
    if phase!==:all
        diagnostics_producer_hash_ok=String(diagnostic_receipt["producer_result_hash"])==artifact_binding.result_hash
        @test diagnostics_producer_hash_ok
        diagnostic_producer_binding=S._smr_json_native_v1(diagnostic_receipt["producer_artifact_binding"])
        diagnostics_producer_binding_ok=canonical_hash(diagnostic_producer_binding)==canonical_hash(artifact_binding)
        @test diagnostics_producer_binding_ok
        if phase in first.(_INTEGRITY_CASE_PHASES_V1) || phase===:integrity_finalize
            diagnostics_producer_hash_ok && diagnostics_producer_binding_ok ||
                error("integrity leaf diagnostics producer artifact binding mismatch")
        end
    end
    semantic_ids=expected_semantic_identities()
    run_identity=phase in (:all,:identity_replay)
    run_inhouse=phase in (:all,:inhouse_replay,:inhouse_produce)
    run_inhouse_validate=phase===:inhouse_validate
    run_csv=phase===:all || phase===:csv_oracle ||
        phase in first.(_INTEGRITY_CASE_PHASES_V1) || phase===:integrity_finalize
    replay=nothing
    if run_identity
        @testset "serialized identities and no-authority scope" begin
            verify_primary_identity(primary,input,declaration,context,production_dir)
            @test _wire_solver_scope(primary,diagnostics)
            handoff_wire=read(joinpath(out,"producer_handoff.json"),String)
            S._smr_read_canonical_json_v1(handoff_wire)
            handoff=JSON3.read(handoff_wire)
            @test handoff["schema"]=="spatial-global-weak-two-process-handoff-v1"
            @test semantic_identities_match(handoff["semantic_identities"])
            @test wire_digest(handoff["candidate_hash"])==string(context.candidate_hash)
            @test wire_digest(handoff["context_hash"])==string(context.context_hash)
            @test wire_digest(handoff["declaration_hash"])==string(canonical_hash(declaration))
            @test wire_digest(handoff["input_hash"])==string(canonical_hash(input))
            @test wire_digest(handoff["result_hash"])==wire_digest(primary["result_hash"])
            @test handoff["solver_exit_code"]==0 && handoff["formal_refinement_gate"]=="outstanding"
            @test handoff["physical_validation"]=="unsupported" && handoff["authority"]=="no_publish"
        end
        println("SMGW_PHASE_BEGIN=production_artifact_replay");flush(stdout)
        replay_admission=S._smgw_admission_record_v1(context,declaration)
        replay=S.validate_spatial_manufactured_global_weak_artifacts_v1(context,production_dir;
            expected_candidate_hash=string(context.candidate_hash),expected_context_hash=string(context.context_hash),
            expected_input_hash=string(canonical_hash(input)),expected_semantic_identities=semantic_ids,
            _consumer_admission=replay_admission)
        @test replay.validation==:artifact_replay_completed
        @test replay.candidate_hash==string(context.candidate_hash)
        @test replay.context_hash==string(context.context_hash)
        @test replay.input_hash==string(canonical_hash(input))
        @test replay.result_hash==wire_digest(primary["result_hash"])
        @test replay.final_scaled_residual_max<=declaration.solver.residual_tolerance
        @test replay.physical_validation==:unsupported && replay.authority==:no_publish
        println("SMGW_PHASE_END=production_artifact_replay residual=",replay.final_scaled_residual_max);flush(stdout)
        if phase===:identity_replay
            _consumer_write_phase_receipt_v1(consumer_dir,:identity_replay,merge(
                _consumer_phase_binding_v1(input,declaration,context,artifact_binding),
                (diagnostics_hash=String(diagnostic_receipt["diagnostics_hash"]),
                    replay_json=canonical_json((validation=replay.validation,
                        candidate_hash=replay.candidate_hash,context_hash=replay.context_hash,
                        input_hash=replay.input_hash,result_hash=replay.result_hash,
                        final_scaled_residual_max=replay.final_scaled_residual_max,
                        physical_validation=replay.physical_validation,authority=replay.authority,
                        interface_checks=replay.interface_checks,boundary_checks=replay.boundary_checks,
                        conservation_checks=replay.conservation_checks)))))
            println("SMGW_CONSUMER_PHASE_COMPLETE=identity_replay");flush(stdout)
            return nothing
        end
    else
        identity_receipt=_consumer_read_phase_receipt_v1(consumer_dir,:identity_replay)
        _consumer_assert_phase_binding_v1(identity_receipt,input,declaration,context,artifact_binding)
        String(identity_receipt["diagnostics_hash"])==String(diagnostic_receipt["diagnostics_hash"]) ||
            error("identity phase used a different diagnostics receipt")
        replay_native=S._smr_json_native_v1(JSON3.read(String(identity_receipt["replay_json"])))
        replay=merge(replay_native,(validation=Symbol(replay_native.validation),
            physical_validation=Symbol(replay_native.physical_validation),
            authority=Symbol(replay_native.authority)))
        replay_valid=replay.validation==:artifact_replay_completed &&
            replay.candidate_hash==string(context.candidate_hash) &&
            replay.context_hash==string(context.context_hash) &&
            replay.input_hash==string(canonical_hash(input)) &&
            replay.result_hash==artifact_binding.result_hash &&
            replay.final_scaled_residual_max<=declaration.solver.residual_tolerance &&
            replay.physical_validation==:unsupported && replay.authority==:no_publish
        @test replay.validation==:artifact_replay_completed
        @test replay.candidate_hash==string(context.candidate_hash)
        @test replay.context_hash==string(context.context_hash)
        @test replay.input_hash==string(canonical_hash(input))
        @test replay.result_hash==artifact_binding.result_hash
        @test replay.final_scaled_residual_max<=declaration.solver.residual_tolerance
        @test replay.physical_validation==:unsupported && replay.authority==:no_publish
        if phase in first.(_INTEGRITY_CASE_PHASES_V1) || phase===:integrity_finalize
            replay_valid || error("integrity leaf identity replay binding mismatch")
        end
    end

    if !run_identity && phase in (:inhouse_replay,:inhouse_validate)
        replay_admission=S._smgw_admission_record_v1(context,declaration)
    end
    inhouse_binding=nothing
    if run_inhouse
        # Exercise the opt-in through the real manufactured Q1 consumer in this
        # fresh consumer process. The default producer above continues to cover
        # the frozen spatial-native path and its thresholds.
        println("SMGW_PHASE_BEGIN=inhouse_kkt_real_consumer");flush(stdout)
        inhouse_stage_trace=(name,edge,stamp)->begin
            println("SMGW_INHOUSE_STAGE_",uppercase(String(edge))," name=",name,
                " monotonic_ns=",stamp)
            flush(stdout)
        end
        inhouse_result=S.execute_spatial_manufactured_global_weak_numerical_v1(
            context,inhouse_dir;residual_partition=:inhouse_kkt,
            stage_trace=inhouse_stage_trace)
        inhouse_solver=inhouse_result.report.solver
        inhouse_final=inhouse_result.report.final_assembly
        @test inhouse_solver.residual_partition==:inhouse_kkt
        @test inhouse_solver.solver_exit_code in (0,2,3,4,6,7)
        @test (inhouse_solver.solver_exit_code==0)==(inhouse_solver.status==:converged)
        @test inhouse_solver.numerical_status==(inhouse_solver.solver_exit_code==0 ?
            :full_discrete_residual_converged : :numerical_fail)
        @test inhouse_final.row_blocks[end]==:total_flux_Wb
        @test length(inhouse_final.residual)==57
        @test length(inhouse_final.residual)==Int(primary["final_assembly"]["row_count"])
        @test !isempty(inhouse_solver.iterations)
        @test all(record->record.residual_partition.schema=="weighted-residual-kkt-partition-v1" &&
            record.residual_partition.least_squares_rows==length(inhouse_final.residual) &&
            record.residual_partition.equality_rows==0,
            inhouse_solver.iterations)
        @test any(attempt->hasproperty(attempt,:bounded_step) &&
            hasproperty(attempt.bounded_step,:backend) &&
            attempt.bounded_step.backend==:inhouse_weighted_residual_kkt &&
            attempt.linear_input.schema=="inhouse-weighted-residual-kkt-input-v1" &&
            attempt.linear_input.rows==length(inhouse_final.residual) &&
            isempty(attempt.linear_input.equality_residual),inhouse_solver.attempts)
        @test inhouse_result.report.solver.numerical_policy.max_iterations==12
        @test inhouse_result.report.solver.numerical_policy.seconds==120.0
        @test inhouse_result.report.solver.numerical_policy.residual_tolerance==1.0e-6
        @test inhouse_result.report.solver.numerical_policy.gradient_tolerance==1.0e-10
        @test inhouse_result.report.solver.numerical_policy.rank_relative_tolerance==1.0e-10
        @test inhouse_result.report.solver.numerical_policy.kkt_absolute_tolerance==1.0e-10
        @test inhouse_result.report.solver.numerical_policy.line_search_steps==20
        @test inhouse_result.report.solver.numerical_policy.pressure_lower_Pa==0.0
        @test inhouse_result.report.physical_validation==:unsupported
        @test inhouse_result.report.authority==:no_publish
        inhouse_binding=phase===:all ? nothing : _consumer_artifact_binding_v1(inhouse_dir)
        if phase===:inhouse_produce
            identity_receipt_path=_consumer_phase_receipt_path_v1(consumer_dir,:identity_replay)
            _consumer_write_phase_receipt_v1(consumer_dir,:inhouse_produce,merge(
                _consumer_phase_binding_v1(input,declaration,context,artifact_binding),
                (diagnostics_hash=String(diagnostic_receipt["diagnostics_hash"]),
                    identity_receipt_sha256=sha(identity_receipt_path),
                    inhouse_artifact_binding=inhouse_binding,
                    inhouse_result_hash=inhouse_binding.result_hash,
                    inhouse_solver_exit_code=inhouse_solver.solver_exit_code,
                    inhouse_residual_max=inhouse_solver.final_scaled_residual_max,
                    inhouse_residual_row_count=length(inhouse_final.residual),
                    inhouse_status=String(inhouse_solver.status),
                    inhouse_numerical_status=String(inhouse_solver.numerical_status),
                    inhouse_partition=String(inhouse_solver.residual_partition),
                    inhouse_step_identity_hash=string(inhouse_solver.step_identity_hash),
                    inhouse_numerical_policy_hash=string(canonical_hash(inhouse_solver.numerical_policy)))))
            println("SMGW_CONSUMER_PHASE_COMPLETE=inhouse_produce");flush(stdout)
            return nothing
        end
    elseif run_inhouse_validate
        inhouse_produce_receipt=_consumer_read_phase_receipt_v1(consumer_dir,:inhouse_produce)
        _consumer_assert_phase_binding_v1(inhouse_produce_receipt,input,declaration,context,artifact_binding)
        String(inhouse_produce_receipt["diagnostics_hash"])==String(diagnostic_receipt["diagnostics_hash"]) ||
            error("InHouse producer phase used a different diagnostics receipt")
        identity_receipt_path=_consumer_phase_receipt_path_v1(consumer_dir,:identity_replay)
        @test String(inhouse_produce_receipt["identity_receipt_sha256"])==sha(identity_receipt_path)
        inhouse_binding=_consumer_artifact_binding_v1(inhouse_dir)
        stored_inhouse=S._smr_json_native_v1(inhouse_produce_receipt["inhouse_artifact_binding"])
        @test canonical_hash(stored_inhouse)==canonical_hash(inhouse_binding)
        @test String(inhouse_produce_receipt["inhouse_result_hash"])==inhouse_binding.result_hash
        @test Int(inhouse_produce_receipt["inhouse_solver_exit_code"]) in (0,2,3,4,6,7)
        @test String(inhouse_produce_receipt["inhouse_partition"])=="inhouse_kkt"
        @test Int(inhouse_produce_receipt["inhouse_residual_row_count"])==
            Int(JSON3.read(read(joinpath(inhouse_dir,"global_weak_primary.json"),String))["final_assembly"]["row_count"])
        inhouse_replay=S.validate_spatial_manufactured_global_weak_artifacts_v1(
            context,inhouse_dir;expected_candidate_hash=string(context.candidate_hash),
            expected_context_hash=string(context.context_hash),
            expected_input_hash=string(canonical_hash(input)),
            expected_semantic_identities=expected_semantic_identities(),_consumer_admission=replay_admission)
        @test inhouse_replay.validation==:artifact_replay_completed
        @test inhouse_replay.candidate_hash==string(context.candidate_hash)
        @test inhouse_replay.context_hash==string(context.context_hash)
        @test inhouse_replay.input_hash==string(canonical_hash(input))
        @test inhouse_replay.result_hash==inhouse_binding.result_hash
        @test inhouse_replay.result_hash==String(inhouse_produce_receipt["inhouse_result_hash"])
        @test inhouse_replay.final_scaled_residual_max==Float64(inhouse_produce_receipt["inhouse_residual_max"])
        @test inhouse_replay.physical_validation==:unsupported && inhouse_replay.authority==:no_publish
        identity_receipt_path=_consumer_phase_receipt_path_v1(consumer_dir,:identity_replay)
        inhouse_produce_receipt_path=_consumer_phase_receipt_path_v1(consumer_dir,:inhouse_produce)
        _consumer_write_phase_receipt_v1(consumer_dir,:inhouse_replay,merge(
            _consumer_phase_binding_v1(input,declaration,context,artifact_binding),
            (diagnostics_hash=String(diagnostic_receipt["diagnostics_hash"]),
                identity_receipt_sha256=sha(identity_receipt_path),
                inhouse_produce_receipt_sha256=sha(inhouse_produce_receipt_path),
                inhouse_artifact_binding=inhouse_binding,
                inhouse_result_hash=inhouse_binding.result_hash,
                inhouse_solver_exit_code=Int(inhouse_produce_receipt["inhouse_solver_exit_code"]),
                inhouse_residual_max=Float64(inhouse_produce_receipt["inhouse_residual_max"]))))
        println("SMGW_CONSUMER_PHASE_COMPLETE=inhouse_validate");flush(stdout)
        return nothing
    else
        inhouse_receipt=_consumer_read_phase_receipt_v1(consumer_dir,:inhouse_replay)
        _consumer_assert_phase_binding_v1(inhouse_receipt,input,declaration,context,artifact_binding)
        String(inhouse_receipt["diagnostics_hash"])==String(diagnostic_receipt["diagnostics_hash"]) ||
            error("InHouse phase used a different diagnostics receipt")
        identity_receipt_path=_consumer_phase_receipt_path_v1(consumer_dir,:identity_replay)
        inhouse_identity_receipt_ok=String(inhouse_receipt["identity_receipt_sha256"])==sha(identity_receipt_path)
        @test inhouse_identity_receipt_ok
        inhouse_produce_receipt_ok=true
        if hasproperty(inhouse_receipt,:inhouse_produce_receipt_sha256)
            inhouse_produce_receipt_path=_consumer_phase_receipt_path_v1(consumer_dir,:inhouse_produce)
            inhouse_produce_receipt_ok=
                String(inhouse_receipt["inhouse_produce_receipt_sha256"])==sha(inhouse_produce_receipt_path)
            @test inhouse_produce_receipt_ok
        end
        inhouse_binding=_consumer_artifact_binding_v1(inhouse_dir)
        stored_inhouse=S._smr_json_native_v1(inhouse_receipt["inhouse_artifact_binding"])
        inhouse_artifact_binding_ok=canonical_hash(stored_inhouse)==canonical_hash(inhouse_binding)
        inhouse_result_ok=String(inhouse_receipt["inhouse_result_hash"])==inhouse_binding.result_hash
        inhouse_exit_ok=Int(inhouse_receipt["inhouse_solver_exit_code"]) in (0,2,3,4,6,7)
        @test inhouse_artifact_binding_ok
        @test inhouse_result_ok
        @test inhouse_exit_ok
        if phase in first.(_INTEGRITY_CASE_PHASES_V1) || phase===:integrity_finalize
            inhouse_identity_receipt_ok && inhouse_produce_receipt_ok &&
                inhouse_artifact_binding_ok && inhouse_result_ok && inhouse_exit_ok ||
                error("integrity leaf InHouse artifact or receipt binding mismatch")
        end
    end

    if phase in first.(_INTEGRITY_CASE_PHASES_V1) || phase===:integrity_finalize
        csv_receipt=_consumer_read_phase_receipt_v1(consumer_dir,:csv_oracle)
        _consumer_assert_phase_binding_v1(csv_receipt,input,declaration,context,artifact_binding)
        String(csv_receipt["diagnostics_hash"])==String(diagnostic_receipt["diagnostics_hash"]) ||
            error("CSV/oracle phase used a different diagnostics receipt")
        String(csv_receipt["inhouse_result_hash"])==String(inhouse_receipt["inhouse_result_hash"]) ||
            error("CSV/oracle phase used a different InHouse result")
        stored_inhouse=S._smr_json_native_v1(csv_receipt["inhouse_artifact_binding"])
        csv_inhouse_binding_ok=canonical_hash(stored_inhouse)==canonical_hash(inhouse_binding)
        csv_state_binding_ok=String(csv_receipt["csv_state_sha256"])==
            sha(joinpath(production_dir,"solver_state.csv"))
        csv_operator_controls_binding_ok=String(csv_receipt["operator_binding_controls_sha256"])==
            sha(joinpath(consumer_dir,"operator_binding_negative_controls.json"))
        csv_fd_binding_ok=String(csv_receipt["fd_check_sha256"])==
            sha(joinpath(consumer_dir,"independent_fd_check.json"))
        @test csv_inhouse_binding_ok
        @test csv_state_binding_ok
        @test csv_operator_controls_binding_ok
        @test csv_fd_binding_ok
        csv_inhouse_binding_ok && csv_state_binding_ok && csv_operator_controls_binding_ok &&
            csv_fd_binding_ok || error("integrity leaf CSV/oracle artifact binding mismatch")
        if phase===:integrity_finalize
            integrity_receipt_names=Tuple(basename(_consumer_phase_receipt_path_v1(consumer_dir,item[1]))
                for item in _INTEGRITY_CASE_PHASES_V1)
            actual_integrity_receipt_names=Tuple(sort(filter(name->
                startswith(name,"consumer_phase_integrity_") && endswith(name,"_receipt.json"),
                readdir(consumer_dir))))
            length(unique(integrity_receipt_names))==7 &&
                Set(actual_integrity_receipt_names)==Set(integrity_receipt_names) ||
                error("finalizer requires exactly seven unique integrity case receipts")
            csv_receipt_sha=sha(_consumer_phase_receipt_path_v1(consumer_dir,:csv_oracle))
            for (integrity_phase,control_name) in _INTEGRITY_CASE_PHASES_V1
                integrity_receipt=_consumer_read_phase_receipt_v1(consumer_dir,integrity_phase)
                _consumer_assert_phase_binding_v1(integrity_receipt,input,declaration,context,artifact_binding)
                String(integrity_receipt["integrity_case"])==control_name &&
                    String(integrity_receipt["integrity_control"])=="passed" &&
                    String(integrity_receipt["csv_oracle_receipt_sha256"])==csv_receipt_sha &&
                    String(integrity_receipt["diagnostics_hash"])==String(diagnostic_receipt["diagnostics_hash"]) &&
                    String(integrity_receipt["inhouse_result_hash"])==String(inhouse_receipt["inhouse_result_hash"]) ||
                    error("integrity case receipt binding mismatch: $integrity_phase")
                stored_integrity_inhouse=S._smr_json_native_v1(integrity_receipt["inhouse_artifact_binding"])
                integrity_inhouse_binding_ok=canonical_hash(stored_integrity_inhouse)==canonical_hash(inhouse_binding)
                @test integrity_inhouse_binding_ok
                integrity_inhouse_binding_ok ||
                    error("integrity case InHouse artifact binding mismatch: $integrity_phase")
                fixture_root=joinpath(consumer_dir,"integrity_negative_controls",control_name)
                fixture_manifest=_integrity_fixture_manifest_v1(fixture_root)
                String(integrity_receipt["fixture_manifest_sha256"])==fixture_manifest.sha256 ||
                    error("integrity fixture content hash mismatch: $integrity_phase")
                stored_fixture_manifest=S._smr_json_native_v1(integrity_receipt["fixture_manifest"])
                canonical_hash(stored_fixture_manifest)==canonical_hash(fixture_manifest.manifest) ||
                    error("integrity fixture manifest mismatch: $integrity_phase")
            end
        end
    end

    if run_inhouse
        inhouse_replay=S.validate_spatial_manufactured_global_weak_artifacts_v1(
            context,inhouse_dir;expected_candidate_hash=string(context.candidate_hash),
            expected_context_hash=string(context.context_hash),
            expected_input_hash=string(canonical_hash(input)),
            expected_semantic_identities=expected_semantic_identities(),
            _consumer_admission=phase===:all ? nothing : replay_admission)
        @test inhouse_replay.validation==:artifact_replay_completed
        @test inhouse_replay.candidate_hash==string(context.candidate_hash)
        @test inhouse_replay.final_scaled_residual_max==inhouse_solver.final_scaled_residual_max
        @test inhouse_replay.physical_validation==:unsupported && inhouse_replay.authority==:no_publish
        println("SMGW_PHASE_END=inhouse_kkt_real_consumer solver_exit=",
            inhouse_solver.solver_exit_code," residual=",inhouse_solver.final_scaled_residual_max);flush(stdout)
        if phase===:inhouse_replay
            identity_receipt_path=_consumer_phase_receipt_path_v1(consumer_dir,:identity_replay)
            _consumer_write_phase_receipt_v1(consumer_dir,:inhouse_replay,merge(
                _consumer_phase_binding_v1(input,declaration,context,artifact_binding),
                (diagnostics_hash=String(diagnostic_receipt["diagnostics_hash"]),
                    identity_receipt_sha256=sha(identity_receipt_path),
                    inhouse_artifact_binding=inhouse_binding,
                    inhouse_result_hash=inhouse_binding.result_hash,
                    inhouse_solver_exit_code=inhouse_solver.solver_exit_code,
                    inhouse_residual_max=inhouse_solver.final_scaled_residual_max)))
            println("SMGW_CONSUMER_PHASE_COMPLETE=inhouse_replay");flush(stdout)
        end
    end
    phase===:inhouse_replay && return nothing

    if !(phase in first.(_INTEGRITY_CASE_PHASES_V1) || phase===:integrity_finalize)
        receipt=S._smgw_geometry_receipt_from_wire_v1(
        S._smr_json_native_v1(primary["geometry_receipt"]),input)
    raw=raw_geometry_artifacts(primary)
    @test receipt.raw_artifacts==raw
    data=S.load_spatial_data_v4(declaration,(level=input.mesh.level,nfp=input.mesh.nfp,
        flux_Wb=input.flux.nominal_Wb,raw_artifacts=raw))
    g=O.grid(collect(input.mesh.rho),input.mesh.theta_count,input.mesh.zeta_per_period*input.mesh.nfp)
    state=read_state_csv(joinpath(production_dir,"solver_state.csv"),length(g.node_order))
    @test data.mesh.level==:coarse && size(data.mesh.nodes_q,2)==length(g.node_order)
    @test Tuple(Tuple(data.mesh.nodes_q[:,node]) for node in axes(data.mesh.nodes_q,2))==Tuple(g.node_order)
    @test Tuple(Tuple(ids) for ids in data.mesh.cell_nodes)==Tuple(Tuple(ids) for ids in g.element_nodes)
    @test Tuple(Tuple(Float64.(collect(row))) for row in primary["final_assembly"]["node_order"])==Tuple(g.node_order)
    @test Tuple(Tuple(Int.(collect(row))) for row in primary["final_assembly"]["element_nodes"])==Tuple(Tuple(x) for x in g.element_nodes)
    wire_solver_state=Float64.(collect(primary["solver"]["final_state"]))
    @test wire_solver_state==state
    pressure_min=minimum(state[4:4:end])
    pressure_tolerance=8eps(Float64)*max(1.0,abs(pressure_min/declaration.scaling.p_Pa))*declaration.scaling.p_Pa
    @test pressure_min>=-pressure_tolerance
    initial_actual=S.assemble_spatial_global_weak_system_v1(declaration,data,data.initial_state;
        flux_Wb=input.flux.nominal_Wb,jacobian=true)
    initial_oracle=O.assemble(input,g,data.initial_state;order=3,scaling=declaration.scaling)
    println("SMGW_PHASE_BEGIN=independent_csv_reassembly_and_fd");flush(stdout)
    assert_assembly_matches(initial_actual,initial_oracle,"initial_q1_2_from_materialized_geometry")
    final_actual=S.assemble_spatial_global_weak_system_v1(declaration,data,state;
        flux_Wb=input.flux.nominal_Wb,jacobian=true)
    final_oracle=O.assemble(input,g,state;order=3,scaling=declaration.scaling)
    assert_assembly_matches(final_actual,final_oracle,"csv_derived_final_q1_2")
    wire_assembly=primary["final_assembly"]
    @test Tuple(Tuple(Int.(collect(row))) for row in wire_assembly["row_supports"])==final_oracle.row_supports
    wire_layout=S._smr_json_native_v1(wire_assembly["row_layout"])
    oracle_layout=S._smr_json_native_v1(JSON3.read(canonical_json(final_oracle.row_layout)))
    @test wire_layout==oracle_layout
    final_physical=O.physical_checks(input,g,state;order=3)
    wire_physical=S._smr_json_native_v1(primary["solver"]["physical_checks"])
    oracle_physical=S._smr_json_native_v1(JSON3.read(canonical_json(final_physical)))
    @test wire_physical.authority==oracle_physical.authority
    @test wire_physical.physical_validation==oracle_physical.physical_validation
    @test _named_numeric_close(wire_physical,oracle_physical;rtol=2e-8,atol=2e-8)
    @test _named_numeric_close(replay.interface_checks,final_oracle.interface_checks;rtol=2e-8,atol=2e-9)
    @test _named_numeric_close(replay.boundary_checks,final_oracle.boundary_checks;rtol=2e-8,atol=2e-8)
    @test _named_numeric_close(replay.conservation_checks,final_oracle.conservation_checks;rtol=2e-8,atol=2e-8)
    verify_saved_artifacts(primary,production_dir,final_actual,state)
    println("SMGW_PHASE_BEGIN=production_operator_binding_mutation_controls");flush(stdout)
    trial_binding_control=assert_operator_binding_controls!(context,parent_context,declaration,
        data,receipt,data.initial_state,primary,consumer_dir)
    write(joinpath(consumer_dir,"operator_binding_negative_controls.json"),canonical_json((
        schema="spatial-global-weak-operator-binding-negative-controls-v1",
        semantic_identities=expected_semantic_identities(),candidate_hash=context.candidate_hash,
        context_hash=context.context_hash,guard=:production_operator_binding_guard,
        mutated_data=(:mesh_node_coordinates,:cell_connectivity,:mesh_face_orientation,
            :corner_to_local,:row_layout_support,:row_layout_block,
            :node_quadrature,:volume_quadrature,:face_quadrature,:initial_state_payload,
            :continuous_enclosure,:bigfloat_volume_weight_projection_alias),
        wrong_context=:rejected,stale_core_pin=:rejected,
        rehashed_raw_artifact=:rejected,trial=trial_binding_control,
        global_weak_nonlinear_solver_run=:not_executed,accepted_step_core_trial_probe=:executed,
        formal_credit=false,
        physical_validation=:unsupported,authority=:no_publish))*"\n")
    println("SMGW_PHASE_END=production_operator_binding_mutation_controls status=",trial_binding_control.status);flush(stdout)

    fd=O.finite_difference_jacobian(input,g,data.initial_state;order=3)
    columns=repeat([declaration.scaling.B_T,declaration.scaling.B_T,
        declaration.scaling.B_T,declaration.scaling.p_Pa],div(length(data.initial_state),4))
    actual_scaled=Diagonal(1.0./initial_actual.row_scales)*Matrix(initial_actual.jacobian)*Diagonal(columns)
    fd_scaled=Diagonal(1.0./initial_oracle.row_scales)*fd*Diagonal(columns)
    fd_relative=norm(actual_scaled-fd_scaled,Inf)/max(norm(actual_scaled,Inf),eps(Float64))
    @test initial_actual.jacobian_assembled
    @test all(isfinite,actual_scaled) && all(isfinite,fd_scaled)
    @test fd_relative<=5.0e-6
    write(joinpath(consumer_dir,"independent_fd_check.json"),canonical_json((
        schema="spatial-global-weak-independent-fd-check-v1",
        candidate_hash=context.candidate_hash,context_hash=context.context_hash,
        solver_semantic_hash=expected_semantic_identities().solver_semantic_hash,level=:q1_2,
        method=:centered_finite_difference_of_independent_shared_node_residual,
        scaled_relative_infinity_error=fd_relative,threshold=5.0e-6,
        nonlinear_solve=:not_executed_by_oracle,formal_credit=false,
        physical_validation=:unsupported,authority=:no_publish))*"\n")

    if phase===:csv_oracle
        _consumer_write_phase_receipt_v1(consumer_dir,:csv_oracle,merge(
            _consumer_phase_binding_v1(input,declaration,context,artifact_binding),
            (diagnostics_hash=String(diagnostic_receipt["diagnostics_hash"]),
                inhouse_result_hash=String(inhouse_receipt["inhouse_result_hash"]),
                inhouse_artifact_binding=inhouse_binding,
                csv_state_sha256=sha(joinpath(production_dir,"solver_state.csv")),
                operator_binding_controls_sha256=sha(joinpath(consumer_dir,
                    "operator_binding_negative_controls.json")),
                fd_check_sha256=sha(joinpath(consumer_dir,"independent_fd_check.json")),
                fd_relative_error=fd_relative)))
        println("SMGW_CONSUMER_PHASE_COMPLETE=csv_oracle");flush(stdout)
        return nothing
    end
    end

    tamper_root=joinpath(consumer_dir,"integrity_negative_controls")
    if phase in first.(_INTEGRITY_CASE_PHASES_V1)
        mkpath(tamper_root)
        phase_case=only(filter(case->case[1]===phase,_INTEGRITY_CASE_PHASES_V1))
        control_name=phase_case[2]
        started_ns=_smgw_trace_begin("artifact_replay_control_$(control_name)")
        integrity_result=nothing
        try
            if phase===:integrity_relocation_positive
                integrity_result=expect_relocated_artifact_replay_positive!(context,production_dir,
                    joinpath(tamper_root,control_name),semantic_ids,replay_admission)
            else
                expected_reason=phase===:integrity_csv_active_dof_rehashed ?
                    "serialized global residual/Jacobian/scale/support replay mismatch" :
                    phase===:integrity_csv_only_active_dof_rehashed ?
                    "serialized solver state differs from fresh artifact state" :
                    phase===:integrity_csv_duplicate_node_rehashed ?
                    "solver state IDs must be unique, ordered, and complete" :
                    phase===:integrity_csv_malformed_node_rehashed ?
                    "solver_state.node_id is not a canonical integer" :
                    "GlobalWeak primary candidate/context binding mismatch"
                integrity_result=expect_artifact_replay_rejection!(context,production_dir,tamper_root,
                    control_name,semantic_ids,expected_reason,replay_admission)
            end
        finally
            _smgw_trace_end("artifact_replay_control_$(control_name)",started_ns)
        end
        @test integrity_result
        integrity_result || error("serialized artifact integrity control failed: $control_name")
        fixture_manifest=_integrity_fixture_manifest_v1(joinpath(tamper_root,control_name))
        csv_receipt_path=_consumer_phase_receipt_path_v1(consumer_dir,:csv_oracle)
        _consumer_write_phase_receipt_v1(consumer_dir,phase,merge(
            _consumer_phase_binding_v1(input,declaration,context,artifact_binding),
            (integrity_case=control_name,integrity_control=:passed,
                diagnostics_hash=String(diagnostic_receipt["diagnostics_hash"]),
                inhouse_result_hash=String(inhouse_receipt["inhouse_result_hash"]),
                inhouse_artifact_binding=inhouse_binding,
                csv_oracle_receipt_sha256=sha(csv_receipt_path),
                fixture_manifest=fixture_manifest.manifest,
                fixture_manifest_sha256=fixture_manifest.sha256)))
        println("SMGW_CONSUMER_PHASE_COMPLETE=",phase);flush(stdout)
        return nothing
    end

    if phase!==:integrity_finalize
        mkpath(tamper_root)
        @testset "serialized artifact replay rejects rehashed forgeries" begin
            integrity_results=(
                expect_relocated_artifact_replay_positive!(context,production_dir,
                    joinpath(tamper_root,"relocation_positive"),semantic_ids,replay_admission),
                expect_artifact_replay_rejection!(context,production_dir,tamper_root,
                    "csv_active_dof_rehashed",semantic_ids,"serialized global residual/Jacobian/scale/support replay mismatch",
                    replay_admission),
                expect_artifact_replay_rejection!(context,production_dir,tamper_root,
                    "csv_only_active_dof_rehashed",semantic_ids,"serialized solver state differs from fresh artifact state",
                    replay_admission),
                expect_artifact_replay_rejection!(context,production_dir,tamper_root,
                    "csv_duplicate_node_rehashed",semantic_ids,"solver state IDs must be unique, ordered, and complete",
                    replay_admission),
                expect_artifact_replay_rejection!(context,production_dir,tamper_root,
                    "csv_malformed_node_rehashed",semantic_ids,"solver_state.node_id is not a canonical integer",
                    replay_admission),
                expect_artifact_replay_rejection!(context,production_dir,tamper_root,
                    "stale_candidate_binding",semantic_ids,"GlobalWeak primary candidate/context binding mismatch",
                    replay_admission),
                expect_artifact_replay_rejection!(context,production_dir,tamper_root,
                    "stale_context_binding",semantic_ids,"GlobalWeak primary candidate/context binding mismatch",
                    replay_admission))
            for result in integrity_results
                @test result
            end
            all(integrity_results) || error("one or more serialized artifact integrity controls failed")
        end
    end

    receipt_summary=(schema="spatial-global-weak-independent-consumer-receipt-v1",
        semantic_identities=semantic_ids,candidate_hash=context.candidate_hash,context_hash=context.context_hash,
        declaration_hash=canonical_hash(declaration),input_hash=canonical_hash(input),
        result_hash=wire_digest(primary["result_hash"]),solver_exit_code=Int(primary["solver_exit_code"]),
        stopping_reason=Symbol(primary["stopping_reason"]),final_scaled_residual_max=Float64(primary["final_scaled_residual_max"]),
        accepted_update_count=Int(primary["accepted_update_count"]),q1_2_actual_consumer=:executed,
        q1_2_independent_fresh_artifact_replay=:passed,q1_2_csv_derived_oracle=:passed,
        integrity_controls=:passed,
        q1_4_q1_8=diagnostics,formal_multilevel_gate=:outstanding,
        physical_validation=:unsupported,authority=:no_publish,claim_ceiling=screen_only)
    write(joinpath(consumer_dir,"independent_global_weak_consumer_receipt.json"),canonical_json(receipt_summary)*"\n")
    if phase===:integrity_finalize
        csv_receipt_path=_consumer_phase_receipt_path_v1(consumer_dir,:csv_oracle)
        integrity_case_receipt_hashes=Tuple((phase=String(item[1]),
            sha256=sha(_consumer_phase_receipt_path_v1(consumer_dir,item[1])))
            for item in _INTEGRITY_CASE_PHASES_V1)
        _consumer_write_phase_receipt_v1(consumer_dir,:integrity_finalize,merge(
            _consumer_phase_binding_v1(input,declaration,context,artifact_binding),
            (diagnostics_hash=String(diagnostic_receipt["diagnostics_hash"]),
                inhouse_result_hash=String(inhouse_receipt["inhouse_result_hash"]),
                inhouse_artifact_binding=inhouse_binding,
                csv_oracle_receipt_sha256=sha(csv_receipt_path),integrity_control_count=7,
                integrity_controls=:passed,
                integrity_case_receipt_hashes=integrity_case_receipt_hashes,
                fd_relative_error=Float64(csv_receipt["fd_relative_error"]),
                independent_receipt_sha256=sha(joinpath(consumer_dir,
                    "independent_global_weak_consumer_receipt.json")))))
        println("SMGW_CONSUMER_PHASE_COMPLETE=integrity_finalize")
    else
        println("SMGW_CONSUMER_COMPLETE residual=",replay.final_scaled_residual_max,
            " formal_multilevel_gate=outstanding physical_validation=unsupported authority=no_publish")
    end
    flush(stdout)
end

function _assert_q1_level_oracle_assembly(level,actual,expected,label)
    actual.schema=="spatial-global-shared-q1-weak-assembly-v1" &&
        actual.row_layout==expected.row_layout && actual.node_order==expected.node_order &&
        actual.element_nodes==expected.element_nodes && actual.row_blocks==expected.row_blocks &&
        actual.row_supports==expected.row_supports && length(actual.residual)==length(expected.residual) ||
        error("$level independent oracle structure mismatch: $label")
    all(i->isapprox(actual.row_scales[i],expected.row_scales[i];rtol=3e-11,atol=1e-12),eachindex(actual.row_scales)) ||
        error("$level independent oracle row-scale mismatch: $label")
    scaled_difference=maximum(abs.(actual.residual.-expected.residual)./actual.row_scales;init=0.0)
    isfinite(scaled_difference) && scaled_difference<=5e-10 ||
        error("$level independent oracle residual mismatch: $label")
    interface_match=_named_numeric_close(actual.interface_checks,expected.interface_checks;rtol=2e-8,atol=2e-9)
    boundary_match=_named_numeric_close(actual.boundary_checks,expected.boundary_checks;rtol=2e-8,atol=2e-8)
    conservation_match=_named_numeric_close(actual.conservation_checks,expected.conservation_checks;rtol=2e-8,atol=2e-8)
    if !(interface_match && boundary_match && conservation_match)
        !interface_match && println(level,"_ORACLE_PHYSICAL_MISMATCH label=",label,
            " category=interface actual=",repr(actual.interface_checks),
            " expected=",repr(expected.interface_checks))
        !boundary_match && println(level,"_ORACLE_PHYSICAL_MISMATCH label=",label,
            " category=boundary actual=",repr(actual.boundary_checks),
            " expected=",repr(expected.boundary_checks))
        !conservation_match && println(level,"_ORACLE_PHYSICAL_MISMATCH label=",label,
            " category=conservation actual=",repr(actual.conservation_checks),
            " expected=",repr(expected.conservation_checks))
        flush(stdout)
        error("$level independent oracle physical/conservation mismatch: $label")
    end
    println("SMGW_",uppercase(String(level)),"_ORACLE_COMPARE=",label," scaled_residual_delta=",scaled_difference);flush(stdout)
    scaled_difference
end

_assert_q1_4_oracle_assembly(actual,expected,label)=
    _assert_q1_level_oracle_assembly(:q1_4,actual,expected,label)

function _assert_q1_globalweak_rowspace(level,assembly,spec,label)
    layout=assembly.row_layout
    layout.total_rows==spec.global_rows && length(assembly.residual)==spec.global_rows &&
        layout.volume_rows==(first=1,last=spec.unknowns,
            per_node=(:momentum_x,:momentum_y,:momentum_z,:divB)) &&
        layout.boundary_trace_rows.first==spec.unknowns+1 &&
        layout.boundary_trace_rows.last==spec.global_rows-1 &&
        layout.total_flux_row==spec.global_rows ||
        error("$level GlobalWeak residual row-space identity mismatch: $label")
    true
end

const CoupledInHouse=S.InHouseCoupledMHDGlobalSolveV1
const _MESH_EDGE_TEST_REGIONS=("mesh_region_1","mesh_region_2")
const _MESH_EDGE_TEST_EDGE_ID="source_mesh_region_1_to_2"
const _MESH_EDGE_TEST_CONSTRAINT="source_mesh_interface_equality"
_mesh_edge_test_eqids(region,n)=Tuple("$(region)_weak_row_$(i)" for i in 1:n)

function _mesh_edge_test_envelope(context,region_id)
    (candidate_hash=context.candidate_hash,
        provider_semantic_hash=context.provider_semantic_hash,
        provider_context_hash=context.provider_context_hash,region_id=region_id)
end

function _mesh_edge_test_coefficients(sample,endpoint)
    phi=atan(sample.xyz[2],sample.xyz[1]);c=cos(phi);s=sin(phi)
    rotation=Float64[c -s 0.0;s c 0.0;0.0 0.0 1.0]
    Einv=Float64[sample.Einv[i][j] for i in 1:3,j in 1:3]
    transformed=rotation*transpose(Einv);normal=Float64.(collect(sample.normal))
    Float64[dot(normal,transformed*Float64.(collect(gradient)))
        for gradient in endpoint.basis_chart_gradients]
end

function _mesh_edge_test_edge_terms(minus,plus,geometry;with_jacobian::Bool)
    rminus=zeros(Float64,length(minus));rplus=zeros(Float64,length(plus))
    Jmm=with_jacobian ? zeros(Float64,length(minus),length(minus)) : nothing
    Jmp=with_jacobian ? zeros(Float64,length(minus),length(plus)) : nothing
    Jpm=with_jacobian ? zeros(Float64,length(plus),length(minus)) : nothing
    Jpp=with_jacobian ? zeros(Float64,length(plus),length(plus)) : nothing
    for sample in geometry.samples
        qm=_mesh_edge_test_coefficients(sample,sample.minus)
        qp=_mesh_edge_test_coefficients(sample,sample.plus)
        jump=sum(qm[j]*minus[sample.minus.local_dofs[j][4]] for j in eachindex(qm))-
            sum(qp[j]*plus[sample.plus.local_dofs[j][4]] for j in eachindex(qp))
        for i in eachindex(sample.minus.local_dofs)
            rowm=sample.minus.local_dofs[i][4]
            rminus[rowm]+=sample.weight*sample.minus.basis_values[i]*jump
            with_jacobian || continue
            for j in eachindex(qm)
                colm=sample.minus.local_dofs[j][4]
                colp=sample.plus.local_dofs[j][4]
                Jmm[rowm,colm]+=sample.weight*sample.minus.basis_values[i]*qm[j]
                Jmp[rowm,colp]-=sample.weight*sample.minus.basis_values[i]*qp[j]
            end
        end
        for i in eachindex(sample.plus.local_dofs)
            rowp=sample.plus.local_dofs[i][4]
            rplus[rowp]-=sample.weight*sample.plus.basis_values[i]*jump
            with_jacobian || continue
            for j in eachindex(qm)
                colm=sample.minus.local_dofs[j][4]
                colp=sample.plus.local_dofs[j][4]
                Jpm[rowp,colm]-=sample.weight*sample.plus.basis_values[i]*qm[j]
                Jpp[rowp,colp]+=sample.weight*sample.plus.basis_values[i]*qp[j]
            end
        end
    end
    (minus_residual=rminus,plus_residual=rplus,jacobian_minus_minus=Jmm,
        jacobian_minus_plus=Jmp,jacobian_plus_minus=Jpm,jacobian_plus_plus=Jpp)
end

function _mesh_edge_test_edge_residual(edge,minus,plus,geometry)
    terms=_mesh_edge_test_edge_terms(minus,plus,geometry;with_jacobian=false)
    (terms.minus_residual,terms.plus_residual)
end

function _mesh_edge_test_edge_evaluator(edge,minus,plus,closures,context)
    geometry=context.interface_geometry_context
    terms=_mesh_edge_test_edge_terms(minus,plus,geometry;with_jacobian=true)
    region_id="edge_equilibrium:$(edge.edge_id)"
    ids=(_mesh_edge_test_eqids(edge.minus_region_id,length(minus))...,
        _mesh_edge_test_eqids(edge.plus_region_id,length(plus))...)
    merge(_mesh_edge_test_envelope(context,region_id),(edge_id=edge.edge_id,
        equation_ids=ids,terms...))
end

function _mesh_edge_test_legacy_evaluator(edge,minus,plus,closures,context)
    region_id="edge_equilibrium:$(edge.edge_id)"
    merge(_mesh_edge_test_envelope(context,region_id),(edge_id=edge.edge_id,
        equation_ids=(_mesh_edge_test_eqids(edge.minus_region_id,length(minus))...,
            _mesh_edge_test_eqids(edge.plus_region_id,length(plus))...),
        minus_residual=zeros(length(minus)),plus_residual=zeros(length(plus)),
        jacobian_minus_minus=zeros(length(minus),length(minus)),
        jacobian_minus_plus=zeros(length(minus),length(plus)),
        jacobian_plus_minus=zeros(length(plus),length(minus)),
        jacobian_plus_plus=zeros(length(plus),length(plus))))
end

function _mesh_edge_test_region_evaluator(region_id,state,closures,context)
    n=length(state)
    merge(_mesh_edge_test_envelope(context,region_id),(equation_ids=_mesh_edge_test_eqids(region_id,n),
        residual=zeros(n),jacobian=zeros(n,n)))
end

function _mesh_edge_test_interface_evaluator(minus,plus,closures,context)
    edge=context.interface_edge;region_id="interface:$(edge.edge_id)"
    jm=zeros(1,length(minus));jp=zeros(1,length(plus));jm[1]=1.0;jp[1]=-1.0
    merge(_mesh_edge_test_envelope(context,region_id),(constraint_ids=edge.constraint_ids,
        residual=[minus[1]-plus[1]],jacobian_minus=jm,jacobian_plus=jp))
end

function _mesh_edge_test_outer_evaluator(region_id,state,closures,context)
    J=zeros(1,length(state))
    merge(_mesh_edge_test_envelope(context,region_id),(constraint_ids=("outer_$(region_id)",),
        residual=[0.0],jacobian=J))
end

function _mesh_edge_test_conservation_evaluator(state,closures,context)
    merge(_mesh_edge_test_envelope(context,"global"),(conservation_ids=("mesh_test_balance",),
        residual=[0.0],jacobian=zeros(1,length(state))))
end

function _mesh_edge_test_jacobian_oracle(operation,region_id,state,closures,context)
    if operation===:edge_equilibrium
        edge=context.interface_edge
        ids=(_mesh_edge_test_eqids(edge.minus_region_id,length(state.minus))...,
            _mesh_edge_test_eqids(edge.plus_region_id,length(state.plus))...)
        J=if hasproperty(context,:interface_geometry_context)
            terms=_mesh_edge_test_edge_terms(state.minus,state.plus,
                context.interface_geometry_context;with_jacobian=true)
            [terms.jacobian_minus_minus terms.jacobian_minus_plus;
                terms.jacobian_plus_minus terms.jacobian_plus_plus]
        else
            zeros(length(ids),length(state.minus)+length(state.plus))
        end
        field=(equation_ids=ids,)
    elseif operation===:regional
        J=zeros(length(state),length(state));field=(equation_ids=_mesh_edge_test_eqids(region_id,length(state)),)
    elseif operation===:interface
        edge=context.interface_edge
        J=zeros(1,length(state[1])+length(state[2]));J[1,1]=1.0;J[1,length(state[1])+1]=-1.0
        field=(constraint_ids=edge.constraint_ids,)
    elseif operation===:outer
        J=zeros(1,length(state));field=(constraint_ids=("outer_$(region_id)",),)
    elseif operation===:global_conservation
        J=zeros(1,length(state));field=(conservation_ids=("mesh_test_balance",),)
    else
        throw(ArgumentError("unsupported source-mesh edge oracle operation"))
    end
    oracle_hash=string(CoupledInHouse.canonical_hash(CoupledInHouse._callback_identity(_mesh_edge_test_jacobian_oracle)))
    merge(_mesh_edge_test_envelope(context,region_id),field,
        (jacobian=J,jacobian_oracle_hash=oracle_hash))
end

function _mesh_edge_test_node_layout(data)
    mesh=data.mesh;node_count=size(mesh.nodes_q,2)
    mesh_region_ids=Tuple(sort!(unique(mesh.cell_regions)))
    model_region_ids=Tuple("mesh_region_$(region)" for region in mesh_region_ids)
    region_nodes=Tuple(sort!(unique(vcat((mesh.cell_nodes[c] for c in eachindex(mesh.cell_regions)
        if mesh.cell_regions[c]==region)...))) for region in mesh_region_ids)
    node_dof_maps=Tuple(begin
        node_local_map=Dict(node=>i for (i,node) in enumerate(region_nodes[k]))
        node_dofs=ntuple(node_count) do node
            i=get(node_local_map,node,0)
            i==0 ? nothing : ntuple(component->4(i-1)+component,4)
        end
        (region_id=model_region_ids[k],node_dofs=node_dofs)
    end for k in eachindex(mesh_region_ids))
    (mesh_region_ids=mesh_region_ids,model_region_ids=model_region_ids,
        region_nodes=region_nodes,node_dof_maps=node_dof_maps)
end

function _mesh_edge_test_layout(data,state,candidate_hash,edges,geometry_contexts,edge_evaluator)
    node_layout=_mesh_edge_test_node_layout(data)
    region_nodes=node_layout.region_nodes;node_dof_maps=node_layout.node_dof_maps
    local_states=Tuple(begin
        values=Float64[]
        for node in nodes;append!(values,state[4node-3:4node]);end
        values
    end for nodes in region_nodes)
    offsets=(0,length(local_states[1]));nd=(length(local_states[1]),length(local_states[2]))
    dof_maps=Tuple(Tuple(offsets[k]+i for i in 1:nd[k]) for k in 1:2)
    local_pressure=Tuple(vcat((offsets[k]+4i for i in 1:div(nd[k],4))...) for k in 1:2)
    pressure_indices=Tuple(vcat(collect(local_pressure[1]),collect(local_pressure[2])))
    equation_ids=Tuple(_mesh_edge_test_eqids(_MESH_EDGE_TEST_REGIONS[k],nd[k]) for k in 1:2)
    closures_payload=(classification=:test_only,physical=false,
        purpose="source-backed SpatialMesh interface geometry seam fixture")
    closures=NamedTuple{CoupledInHouse._REQUIRED_CLOSURES}(Tuple(CoupledInHouse.make_closure_evidence_v1(kind,
        candidate_hash,"preparation/test_only/source_mesh_interface_geometry_v1",@__FILE__,
        closures_payload) for kind in CoupledInHouse._REQUIRED_CLOSURES))
    callbacks=(_mesh_edge_test_region_evaluator,_mesh_edge_test_interface_evaluator,
        _mesh_edge_test_outer_evaluator,_mesh_edge_test_conservation_evaluator,
        _mesh_edge_test_jacobian_oracle)
    provider_context_hash=CoupledInHouse.coupled_mhd_provider_context_hash_v1(callbacks...;
        edge_equilibrium_evaluator=edge_evaluator,interface_geometry_contexts=geometry_contexts)
    model=CoupledInHouse.make_global_model_v1(candidate_hash=candidate_hash,
        region_ids=_MESH_EDGE_TEST_REGIONS,region_dofs=nd,pressure_indices=pressure_indices,
        regional_equation_ids=equation_ids,interface_constraint_ids=(_MESH_EDGE_TEST_CONSTRAINT,),
        interface_edges=edges,interface_geometry_contexts=geometry_contexts,
        local_dof_to_global=dof_maps,local_test_row_to_global=dof_maps,
        pressure_indices_global=true,edge_equilibrium_evaluator=edge_evaluator,
        outer_constraint_ids=(("outer_mesh_region_1",),("outer_mesh_region_2",)),
        global_conservation_ids=("mesh_test_balance",),closure_evidence=closures,
        provider_id="preparation/test_only/source_mesh_edge_geometry_v1",
        provider_source_path=@__FILE__,provider_context_hash=provider_context_hash,
        regional_evaluator=callbacks[1],interface_evaluator=callbacks[2],
        outer_evaluator=callbacks[3],conservation_evaluator=callbacks[4],
        jacobian_oracle=callbacks[5])
    (model=model,state=vcat(local_states...),region_nodes=region_nodes,
        node_dof_maps=node_dof_maps,dof_maps=dof_maps)
end

function _mesh_edge_test_full_residual(x,dof_maps,edge,geometry)
    edge_minus=findfirst(==(edge.minus_region_id),_MESH_EDGE_TEST_REGIONS)
    edge_plus=findfirst(==(edge.plus_region_id),_MESH_EDGE_TEST_REGIONS)
    states=Tuple(Float64[x[i] for i in map] for map in dof_maps)
    minus=states[edge_minus];plus=states[edge_plus]
    rm,rp=_mesh_edge_test_edge_residual(edge,minus,plus,geometry)
    rows=zeros(Float64,length(x))
    rows[collect(dof_maps[edge_minus])].+=rm
    rows[collect(dof_maps[edge_plus])].+=rp
    vcat(rows,[minus[1]-plus[1],0.0,0.0,0.0])
end

function _mesh_edge_test_fd_jacobian(f,x)
    fx=f(x);J=zeros(Float64,length(fx),length(x))
    for column in eachindex(x)
        h=1.0e-4*max(1.0,abs(x[column]))
        p1=copy(x);p2=copy(x);m1=copy(x);m2=copy(x)
        p1[column]+=h;p2[column]+=2h;m1[column]-=h;m2[column]-=2h
        J[:,column].=(-f(p2).+8.0.*f(p1).-8.0.*f(m1).+f(m2))./(12.0h)
    end
    J
end

const _SOURCE_MESH_Q1_TARGETS=(0.125,0.25,0.375,0.5)

function _source_mesh_q1_operator(data,nodes,mesh_region)
    n=4length(nodes);node_local=Dict(node=>i for (i,node) in enumerate(nodes))
    K=zeros(Float64,n,n);load=zeros(Float64,n);mass=zeros(Float64,n);volume=0.0
    target=Float64[_SOURCE_MESH_Q1_TARGETS...]
    diffusion=Float64[1.0e-3,1.5e-3,2.0e-3,2.5e-3]
    reaction=Float64[1.0,1.1,1.2,1.3]
    zero_state=zeros(Float64,4size(data.mesh.nodes_q,2));quadrature=NamedTuple[]
    for sample in data.volume
        cell=sample.entity_id
        data.mesh.cell_regions[cell]==mesh_region || continue
        field=S.spatial_field_v4(data,cell,sample,zero_state)
        local_ids=Int[node_local[node] for node in field.ids]
        local_dofs=Tuple(ntuple(c->4(i-1)+c,4) for i in local_ids)
        N=Tuple(field.N);gradN=Tuple(Tuple(field.gradN_xyz[d,a] for d in 1:3) for a in eachindex(local_ids))
        push!(quadrature,(weight=sample.weight,local_dofs=local_dofs,N=N,gradN=gradN))
        volume+=sample.weight
        for a in eachindex(local_ids)
            ia=local_ids[a];mass[4ia-2]+=sample.weight*field.N[a]
            for component in 1:4
                row=4(ia-1)+component
                load[row]+=sample.weight*reaction[component]*target[component]*field.N[a]
                for b in eachindex(local_ids)
                    ib=local_ids[b]
                    value=sample.weight*(diffusion[component]*dot(field.gradN_xyz[:,a],field.gradN_xyz[:,b])+reaction[component]*field.N[a]*field.N[b])
                    K[row,4(ib-1)+component]+=value
                end
            end
        end
    end
    volume>0.0 && all(isfinite,K) && all(isfinite,load) && all(isfinite,mass) && !isempty(quadrature) ||
        throw(ArgumentError("source-mesh regional Q1 operator is empty or nonfinite"))
    (matrix=sparse(K),load=load,mass=mass,volume=volume,quadrature=Tuple(quadrature))
end

const _SOURCE_MESH_Q1_NONLINEAR_PARAMS=(diffusion=(1.0e-3,1.5e-3,2.0e-3,2.5e-3),
    beta=(0.8,-0.45,0.55,0.6),mass=1.0,cross=0.35,quartic=0.8,
    weights=(0.5,-0.25,0.75,1.0),interface_tau=0.15,interface_beta=0.6)

function _source_mesh_q1_nonlinear_region(op,state,p;with_jacobian::Bool)
    n=length(state);r=zeros(Float64,n);J=with_jacobian ? zeros(Float64,n,n) : nothing
    cfg=p.nonlinear_params;target=_SOURCE_MESH_Q1_TARGETS
    for q in op.quadrature
        u=zeros(Float64,4);grad=zeros(Float64,3,4)
        for a in eachindex(q.local_dofs),c in 1:4
            value=state[q.local_dofs[a][c]];u[c]+=q.N[a]*value
            for d in 1:3;grad[d,c]+=q.gradN[a][d]*value;end
        end
        delta=ntuple(c->u[c]-target[c],4);s=sum(delta);z=sum(cfg.weights[c]*delta[c] for c in 1:4)
        kap=ntuple(c->cfg.diffusion[c]*exp(cfg.beta[c]*delta[4]),4)
        norm2=ntuple(c->sum(grad[d,c]^2 for d in 1:3),4)
        potential=ntuple(c->cfg.mass*delta[c]+cfg.cross*s+cfg.quartic*cfg.weights[c]*z^3,4)
        for a in eachindex(q.local_dofs),c in 1:4
            row=q.local_dofs[a][c];grad_test=sum(grad[d,c]*q.gradN[a][d] for d in 1:3)
            coeff_term=c==4 ? 0.5*sum(cfg.beta[d]*kap[d]*norm2[d] for d in 1:4) : 0.0
            r[row]+=q.weight*(kap[c]*grad_test+q.N[a]*(coeff_term+potential[c]))
        end
        with_jacobian || continue
        for a in eachindex(q.local_dofs),c in 1:4,b in 1:4,k in eachindex(q.local_dofs)
            row=q.local_dofs[a][c];col=q.local_dofs[k][b]
            grad_dot=sum(q.gradN[a][d]*q.gradN[k][d] for d in 1:3)
            grad_state_test=sum(grad[d,c]*q.gradN[a][d] for d in 1:3)
            value=(b==c ? kap[c]*grad_dot : 0.0)+
                (b==4 ? cfg.beta[c]*kap[c]*q.N[k]*grad_state_test : 0.0)
            if c==4
                for d in 1:4
                    grad_state_trial=sum(grad[j,d]*q.gradN[k][j] for j in 1:3)
                    coeff_derivative=2.0*(d==b ? grad_state_trial : 0.0)+
                        (b==4 ? cfg.beta[d]*q.N[k]*norm2[d] : 0.0)
                    value+=0.5*cfg.beta[d]*kap[d]*coeff_derivative*q.N[a]
                end
            end
            potential_derivative=(c==b ? cfg.mass : 0.0)+cfg.cross+
                3.0*cfg.quartic*cfg.weights[c]*cfg.weights[b]*z^2
            value+=potential_derivative*q.N[a]*q.N[k]
            J[row,col]+=q.weight*value
        end
    end
    (residual=r,jacobian=with_jacobian ? sparse(J) : nothing)
end

function _source_mesh_q1_nonlinear_edge_terms(minus,plus,geometry,cfg;with_jacobian::Bool)
    rminus=zeros(Float64,length(minus));rplus=zeros(Float64,length(plus))
    Jmm=with_jacobian ? zeros(Float64,length(minus),length(minus)) : nothing
    Jmp=with_jacobian ? zeros(Float64,length(minus),length(plus)) : nothing
    Jpm=with_jacobian ? zeros(Float64,length(plus),length(minus)) : nothing
    Jpp=with_jacobian ? zeros(Float64,length(plus),length(plus)) : nothing
    for sample in geometry.samples
        um=sum(sample.minus.basis_values[a]*minus[sample.minus.local_dofs[a][4]] for a in eachindex(sample.minus.local_dofs))
        up=sum(sample.plus.basis_values[a]*plus[sample.plus.local_dofs[a][4]] for a in eachindex(sample.plus.local_dofs))
        jump=um-up;mean_delta=0.5*(um+up)-_SOURCE_MESH_Q1_TARGETS[4]
        tau=cfg.interface_tau*exp(cfg.interface_beta*mean_delta);alpha=cfg.interface_beta
        fm=tau*jump+0.25*alpha*tau*jump^2;fp=-tau*jump+0.25*alpha*tau*jump^2
        dmm=tau*(1.0+alpha*jump+alpha^2*jump^2/8.0)
        dmp=tau*(-1.0+alpha^2*jump^2/8.0)
        dpm=dmp;dpp=tau*(1.0-alpha*jump+alpha^2*jump^2/8.0)
        for a in eachindex(sample.minus.local_dofs)
            row=sample.minus.local_dofs[a][4]
            rminus[row]+=sample.weight*sample.minus.basis_values[a]*fm
            with_jacobian || continue
            for b in eachindex(sample.minus.local_dofs)
                col=sample.minus.local_dofs[b][4]
                Jmm[row,col]+=sample.weight*sample.minus.basis_values[a]*sample.minus.basis_values[b]*dmm
            end
            for b in eachindex(sample.plus.local_dofs)
                col=sample.plus.local_dofs[b][4]
                Jmp[row,col]+=sample.weight*sample.minus.basis_values[a]*sample.plus.basis_values[b]*dmp
            end
        end
        for a in eachindex(sample.plus.local_dofs)
            row=sample.plus.local_dofs[a][4]
            rplus[row]+=sample.weight*sample.plus.basis_values[a]*fp
            with_jacobian || continue
            for b in eachindex(sample.minus.local_dofs)
                col=sample.minus.local_dofs[b][4]
                Jpm[row,col]+=sample.weight*sample.plus.basis_values[a]*sample.minus.basis_values[b]*dpm
            end
            for b in eachindex(sample.plus.local_dofs)
                col=sample.plus.local_dofs[b][4]
                Jpp[row,col]+=sample.weight*sample.plus.basis_values[a]*sample.plus.basis_values[b]*dpp
            end
        end
    end
    (minus_residual=rminus,plus_residual=rplus,jacobian_minus_minus=Jmm,
        jacobian_minus_plus=Jmp,jacobian_plus_minus=Jpm,jacobian_plus_plus=Jpp)
end

function _source_mesh_q1_nonlinear_edge_evaluator(edge,minus,plus,closures,context)
    p=_source_mesh_q1_payload(closures)
    terms=_source_mesh_q1_nonlinear_edge_terms(minus,plus,context.interface_geometry_context,
        p.nonlinear_params;with_jacobian=true)
    ids=(_mesh_edge_test_eqids(edge.minus_region_id,length(minus))...,
        _mesh_edge_test_eqids(edge.plus_region_id,length(plus))...)
    merge(_mesh_edge_test_envelope(context,"edge_equilibrium:$(edge.edge_id)"),
        (edge_id=edge.edge_id,equation_ids=ids,terms...))
end

function _source_mesh_q1_trace_matrices(geometry,nm,np)
    area=sum(sample.weight for sample in geometry.samples)
    area>0.0 || throw(ArgumentError("source interface has zero quadrature area"))
    Bm=zeros(Float64,3,nm);Bp=zeros(Float64,3,np)
    for sample in geometry.samples
        for a in eachindex(sample.minus.local_dofs),component in 1:3
            Bm[component,sample.minus.local_dofs[a][component]]+=sample.weight*sample.minus.basis_values[a]/area
        end
        for a in eachindex(sample.plus.local_dofs),component in 1:3
            Bp[component,sample.plus.local_dofs[a][component]]+=sample.weight*sample.plus.basis_values[a]/area
        end
    end
    (minus=Bm,plus=Bp)
end

function _source_mesh_q1_boundary_weights(data,nodes,mesh_region,model_region,geometries)
    node_local=Dict(node=>i for (i,node) in enumerate(nodes));w=zeros(Float64,4length(nodes));area=0.0
    for geometry in geometries, sample in geometry.samples
        endpoint=sample.minus.region_id==model_region ? sample.minus :
            sample.plus.region_id==model_region ? sample.plus : nothing
        endpoint===nothing && continue
        for a in eachindex(endpoint.local_dofs)
            w[endpoint.local_dofs[a][4]]+=sample.weight*endpoint.basis_values[a]
        end
        area+=sample.weight
    end
    for sample in data.face_quadrature
        face=data.mesh.faces[sample.entity_id]
        face.role===:exterior || continue
        data.mesh.cell_regions[face.left_cell]==mesh_region || continue
        basis=S.spatial_basis_v4(data.mesh,face.left_cell,sample.q)
        for a in eachindex(basis.ids)
            i=get(node_local,basis.ids[a],0);i>0 || throw(ArgumentError("exterior boundary node is absent from regional map"))
            w[4(i-1)+4]+=sample.weight*basis.N[a]
        end
        area+=sample.weight
    end
    area>0.0 || throw(ArgumentError("source-mesh regional boundary has zero quadrature area"))
    w./area
end

function _source_mesh_q1_payload(closures)
    first(values(closures)).payload
end

function _source_mesh_q1_region_eval(region_id,state,closures,context)
    p=_source_mesh_q1_payload(closures);i=findfirst(==(region_id),p.region_ids);op=p.operators[i]
    if hasproperty(p,:nonlinear) && p.nonlinear
        evaluated=_source_mesh_q1_nonlinear_region(op,state,p;with_jacobian=true)
        residual=evaluated.residual;jacobian=evaluated.jacobian
    else
        residual=op.matrix*state-op.load;jacobian=op.matrix
    end
    merge(_mesh_edge_test_envelope(context,region_id),(equation_ids=_mesh_edge_test_eqids(region_id,length(state)),
        residual=residual,jacobian=jacobian))
end
function _source_mesh_q1_interface_eval(minus,plus,closures,context)
    edge=context.interface_edge;geometry=context.interface_geometry_context
    p=_source_mesh_q1_payload(closures)
    iminus=findfirst(==(edge.minus_region_id),p.region_ids);iplus=findfirst(==(edge.plus_region_id),p.region_ids)
    B=_source_mesh_q1_trace_matrices(geometry,p.region_dofs[iminus],p.region_dofs[iplus])
    merge(_mesh_edge_test_envelope(context,"interface:$(edge.edge_id)"),
        (constraint_ids=edge.constraint_ids,residual=B.minus*minus-B.plus*plus,
            jacobian_minus=B.minus,jacobian_plus=-B.plus))
end

function _source_mesh_q1_outer_eval(region_id,state,closures,context)
    p=_source_mesh_q1_payload(closures);i=findfirst(==(region_id),p.region_ids);w=p.outer_weights[i]
    merge(_mesh_edge_test_envelope(context,region_id),(constraint_ids=p.outer_ids[i],
        residual=[dot(w,state)-_SOURCE_MESH_Q1_TARGETS[4]],jacobian=reshape(w,1,:)))
end

function _source_mesh_q1_conservation_eval(state,closures,context)
    p=_source_mesh_q1_payload(closures)
    merge(_mesh_edge_test_envelope(context,"global"),(conservation_ids=("source_mesh_field2_inventory",),
        residual=[dot(p.mass_weights,state)-_SOURCE_MESH_Q1_TARGETS[2]*p.total_volume],
        jacobian=reshape(p.mass_weights,1,:)))
end

function _source_mesh_q1_jacobian_oracle(operation,region_id,state,closures,context)
    p=_source_mesh_q1_payload(closures)
    if operation===:regional
        i=findfirst(==(region_id),p.region_ids);op=p.operators[i]
        J=hasproperty(p,:nonlinear) && p.nonlinear ?
            _source_mesh_q1_nonlinear_region(op,state,p;with_jacobian=true).jacobian : op.matrix
        field=(equation_ids=_mesh_edge_test_eqids(region_id,length(state)),)
    elseif operation===:edge_equilibrium
        edge=context.interface_edge
        terms=if hasproperty(p,:nonlinear) && p.nonlinear
            _source_mesh_q1_nonlinear_edge_terms(state.minus,state.plus,context.interface_geometry_context,
                p.nonlinear_params;with_jacobian=true)
        else
            _mesh_edge_test_edge_terms(state.minus,state.plus,context.interface_geometry_context;with_jacobian=true)
        end
        J=[terms.jacobian_minus_minus terms.jacobian_minus_plus;terms.jacobian_plus_minus terms.jacobian_plus_plus]
        field=(equation_ids=(_mesh_edge_test_eqids(edge.minus_region_id,length(state.minus))...,
            _mesh_edge_test_eqids(edge.plus_region_id,length(state.plus))...),)
    elseif operation===:interface
        edge=context.interface_edge
        iminus=findfirst(==(edge.minus_region_id),p.region_ids);iplus=findfirst(==(edge.plus_region_id),p.region_ids)
        B=_source_mesh_q1_trace_matrices(context.interface_geometry_context,
            p.region_dofs[iminus],p.region_dofs[iplus])
        J=[B.minus -B.plus];field=(constraint_ids=edge.constraint_ids,)
    elseif operation===:outer
        i=findfirst(==(region_id),p.region_ids);J=reshape(p.outer_weights[i],1,:)
        field=(constraint_ids=p.outer_ids[i],)
    elseif operation===:global_conservation
        J=reshape(p.mass_weights,1,:);field=(conservation_ids=("source_mesh_field2_inventory",),)
    else
        throw(ArgumentError("unsupported source-mesh Q1 oracle operation"))
    end
    oracle_hash=string(CoupledInHouse.canonical_hash(CoupledInHouse._callback_identity(_source_mesh_q1_jacobian_oracle)))
    merge(_mesh_edge_test_envelope(context,region_id),field,(jacobian=J,jacobian_oracle_hash=oracle_hash))
end

function _source_mesh_q1_positive_layout(data,candidate_hash,edge,geometry;
        nonlinear=false,operators=nothing,seed_amplitude=0.01)
    node_layout=_mesh_edge_test_node_layout(data);nodes=node_layout.region_nodes
    mesh_region_ids=node_layout.mesh_region_ids;region_ids=node_layout.model_region_ids
    edges=edge isa Tuple ? edge : (edge,)
    geometry_contexts=geometry isa Tuple ? geometry : (geometry,)
    length(edges)==length(geometry_contexts)==length(region_ids)-1 ||
        throw(ArgumentError("source-mesh Q1 layout requires one ordered geometry context per declared edge"))
    raw_operators=operators===nothing ?
        Tuple(_source_mesh_q1_operator(data,nodes[i],mesh_region_ids[i]) for i in eachindex(nodes)) : operators
    nd=Tuple(4length(nodes[i]) for i in eachindex(nodes))
    maps=Tuple(begin
        first_index=1+sum(nd[1:(k-1)];init=0)
        Tuple(first_index:(first_index+nd[k]-1))
    end for k in eachindex(nd))
    outer_weights=Tuple(_source_mesh_q1_boundary_weights(data,nodes[i],mesh_region_ids[i],region_ids[i],geometry_contexts)
        for i in eachindex(nodes))
    mass_weights=zeros(Float64,sum(nd));total_volume=sum(op.volume for op in raw_operators)
    for k in eachindex(nd);mass_weights[collect(maps[k])].=raw_operators[k].mass;end
    model_operators=nonlinear ? raw_operators :
        Tuple((matrix=op.matrix,load=op.load,mass=op.mass,volume=op.volume) for op in raw_operators)
    outer_ids=length(nodes)==2 ? (("source_mesh_outer_1_pressure_mean",),
        ("source_mesh_outer_2_pressure_mean",)) :
        Tuple(("source_mesh_outer_$(mesh_region_ids[k])_pressure_mean",) for k in eachindex(nodes))
    base_payload=(classification=:test_only,physical=false,
        purpose="manufactured source-mesh Q1 reaction-diffusion/interface solve",
        equation="regional integral of diffusion plus reaction minus manufactured source; source interface flux and trace constraints",
        region_ids=region_ids,region_dofs=nd,operators=model_operators,outer_weights=outer_weights,
        outer_ids=outer_ids,mass_weights=mass_weights,total_volume=total_volume)
    p=nonlinear ? merge(base_payload,(purpose="manufactured nonlinear cross-field source-mesh Q1 energy solve",
        equation="first variation of variable-coefficient four-field volume energy plus nonlinear interface contact energy",
        nonlinear=true,nonlinear_params=_SOURCE_MESH_Q1_NONLINEAR_PARAMS)) : base_payload
    source_ref=nonlinear ? "preparation/test_only/source_mesh_q1_nonlinear_energy_v1" :
        "preparation/test_only/source_mesh_q1_reaction_diffusion_v1"
    payload_hash=string(CoupledInHouse.canonical_hash(p))
    closures=NamedTuple{CoupledInHouse._REQUIRED_CLOSURES}(Tuple(begin
        closure_payload=nonlinear && kind!==first(CoupledInHouse._REQUIRED_CLOSURES) ?
            (classification=:test_only,physical=false,purpose="source-mesh nonlinear fixture closure binding",
                model_payload_hash=payload_hash) : p
        CoupledInHouse.make_closure_evidence_v1(kind,candidate_hash,source_ref,@__FILE__,closure_payload)
    end for kind in CoupledInHouse._REQUIRED_CLOSURES))
    callbacks=(_source_mesh_q1_region_eval,_source_mesh_q1_interface_eval,
        _source_mesh_q1_outer_eval,_source_mesh_q1_conservation_eval,_source_mesh_q1_jacobian_oracle)
    edge_evaluator=nonlinear ? _source_mesh_q1_nonlinear_edge_evaluator : _mesh_edge_test_edge_evaluator
    provider_hash=CoupledInHouse.coupled_mhd_provider_context_hash_v1(callbacks...;
        edge_equilibrium_evaluator=edge_evaluator,interface_geometry_contexts=geometry_contexts)
    model_id=nonlinear ? "preparation/test_only/source_mesh_q1_nonlinear_energy_v1" :
        "preparation/test_only/source_mesh_q1_reaction_diffusion_v1"
    pressure_indices=Tuple(vcat((collect(maps[k][4:4:nd[k]]) for k in eachindex(nd))...))
    equation_ids=Tuple(_mesh_edge_test_eqids(region_ids[k],nd[k]) for k in eachindex(nd))
    interface_constraint_ids=Tuple(id for item in edges for id in item.constraint_ids)
    model=CoupledInHouse.make_global_model_v1(candidate_hash=candidate_hash,
        region_ids=region_ids,region_dofs=nd,pressure_indices=pressure_indices,
        regional_equation_ids=equation_ids,interface_constraint_ids=interface_constraint_ids,
        interface_edges=edges,interface_geometry_contexts=geometry_contexts,
        local_dof_to_global=maps,local_test_row_to_global=maps,pressure_indices_global=true,
        edge_equilibrium_evaluator=edge_evaluator,outer_constraint_ids=outer_ids,
        global_conservation_ids=("source_mesh_field2_inventory",),closure_evidence=closures,
        provider_id=model_id,provider_source_path=@__FILE__,provider_context_hash=provider_hash,
        regional_evaluator=callbacks[1],interface_evaluator=callbacks[2],outer_evaluator=callbacks[3],
        conservation_evaluator=callbacks[4],jacobian_oracle=callbacks[5])
    state=Float64[]
    for region in eachindex(nodes),node in eachindex(nodes[region]),component in 1:4
        push!(state,_SOURCE_MESH_Q1_TARGETS[component]*(1.0+seed_amplitude*sin(0.37node+0.2region+component)))
    end
    single_edge=length(edges)==1 ? only(edges) : nothing
    single_geometry=length(geometry_contexts)==1 ? only(geometry_contexts) : nothing
    (model=model,state=state,nodes=nodes,dof_maps=maps,operators=raw_operators,
        edge=single_edge,geometry=single_geometry,edges=edges,geometry_contexts=geometry_contexts,outer_weights=outer_weights,
        mass_weights=mass_weights,total_volume=total_volume,outer_ids=outer_ids,nonlinear=nonlinear,
        nonlinear_params=nonlinear ? _SOURCE_MESH_Q1_NONLINEAR_PARAMS : nothing)
end

function _source_mesh_q1_full_residual(layout,x)
    states=Tuple(Float64[x[i] for i in map] for map in layout.dof_maps)
    rows=zeros(Float64,length(x))
    for k in eachindex(states)
        regional=layout.nonlinear ?
            _source_mesh_q1_nonlinear_region(layout.operators[k],states[k],
                (nonlinear_params=layout.nonlinear_params,);with_jacobian=false).residual :
            layout.operators[k].matrix*states[k]-layout.operators[k].load
        rows[collect(layout.dof_maps[k])].=regional
    end
    equality=Float64[]
    for (edge,geometry) in zip(layout.edges,layout.geometry_contexts)
        iminus=findfirst(==(edge.minus_region_id),layout.model.region_ids)
        iplus=findfirst(==(edge.plus_region_id),layout.model.region_ids)
        if layout.nonlinear
            terms=_source_mesh_q1_nonlinear_edge_terms(states[iminus],states[iplus],geometry,
                layout.nonlinear_params;with_jacobian=false)
            rm=terms.minus_residual;rp=terms.plus_residual
        else
            rm,rp=_mesh_edge_test_edge_residual(edge,states[iminus],states[iplus],geometry)
        end
        rows[collect(layout.dof_maps[iminus])].+=rm
        rows[collect(layout.dof_maps[iplus])].+=rp
        B=_source_mesh_q1_trace_matrices(geometry,length(states[iminus]),length(states[iplus]))
        append!(equality,B.minus*states[iminus]-B.plus*states[iplus])
    end
    append!(equality,[dot(layout.outer_weights[k],states[k])-_SOURCE_MESH_Q1_TARGETS[4]
        for k in eachindex(states)])
    push!(equality,dot(layout.mass_weights,x)-_SOURCE_MESH_Q1_TARGETS[2]*layout.total_volume)
    vcat(rows,equality)
end
function test_source_backed_inhouse_interface_geometry_v1(data,state,candidate_hash,input)
    candidate_hash=string(candidate_hash)
    # Source is the real Q1_4 manufactured loader payload; this validates its mesh
    # adapter seam only and grants no production-geometry or physical evidence.
    @testset "source-backed InHouse interface geometry seam" begin
        mesh=data.mesh
        mesh_to_model=((mesh_region_id=1,model_region_id=_MESH_EDGE_TEST_REGIONS[1]),
            (mesh_region_id=2,model_region_id=_MESH_EDGE_TEST_REGIONS[2]))
        node_maps=_mesh_edge_test_node_layout(data).node_dof_maps
        forward_edge=(edge_id=_MESH_EDGE_TEST_EDGE_ID,minus_region_id=_MESH_EDGE_TEST_REGIONS[1],
            plus_region_id=_MESH_EDGE_TEST_REGIONS[2],constraint_ids=(_MESH_EDGE_TEST_CONSTRAINT,))
        reverse_edge=(edge_id=_MESH_EDGE_TEST_EDGE_ID,minus_region_id=_MESH_EDGE_TEST_REGIONS[2],
            plus_region_id=_MESH_EDGE_TEST_REGIONS[1],constraint_ids=(_MESH_EDGE_TEST_CONSTRAINT,))
        forward_geometry=only(S.spatial_multiregion_interface_geometry_contexts_v1(data,
            (forward_edge,);mesh_region_to_model_region=mesh_to_model,region_node_local_dofs=node_maps))
        reverse_geometry=only(S.spatial_multiregion_interface_geometry_contexts_v1(data,
            (reverse_edge,);mesh_region_to_model_region=mesh_to_model,region_node_local_dofs=node_maps))
        @test forward_geometry.orientation===:minus_to_plus
        @test forward_geometry.source_geometry.face_sha256==string(data.raw_artifacts.faces.sha256)
        @test forward_geometry.source_geometry.face_schema==data.raw_artifacts.faces.schema
        @test forward_geometry.source_geometry.face_row_count==data.raw_artifacts.faces.row_count
        source_samples=Tuple(sample for sample in data.face_quadrature if
            mesh.faces[sample.entity_id].role==:interface && mesh.faces[sample.entity_id].right_cell>0)
        expected_keys=Set((sample.entity_id,sample.qp_id) for sample in source_samples)
        forward_by_key=Dict((sample.face_id,sample.quadrature_id)=>sample for sample in forward_geometry.samples)
        reverse_by_key=Dict((sample.face_id,sample.quadrature_id)=>sample for sample in reverse_geometry.samples)
        @test Set(keys(forward_by_key))==expected_keys
        @test Set(keys(reverse_by_key))==expected_keys
        @test length(forward_by_key)==length(forward_geometry.samples)
        @test length(reverse_by_key)==length(reverse_geometry.samples)
        @test length(unique(sample.face_id for sample in forward_geometry.samples))==
            length(unique(sample.entity_id for sample in source_samples))
        for key in expected_keys
            source=only(filter(sample->(sample.entity_id,sample.qp_id)==key,source_samples))
            f=forward_by_key[key];r=reverse_by_key[key];face=mesh.faces[f.face_id]
            @test f.xyz==source.xyz && f.chart_q==source.q && f.weight==source.weight
            @test f.E==Tuple(Tuple(source.E[i,j] for j in 1:3) for i in 1:3)
            @test f.Einv==Tuple(Tuple(source.Einv[i,j] for j in 1:3) for i in 1:3)
            sign=mesh.cell_regions[face.left_cell]==1 ? 1.0 : -1.0
            @test f.normal==Tuple(sign.*collect(source.normal))
            @test r.normal==Tuple(-collect(f.normal))
            # Reconstruct the unit conormal independently from the chart metric dual.
            # SpatialMesh interface faces use axis 1; orientation follows edge minus-to-plus.
            phi=atan(f.xyz[2],f.xyz[1]);c=cos(phi);s=sin(phi)
            chart_to_cartesian=Float64[c -s 0.0;s c 0.0;0.0 0.0 1.0]
            @test face.axis==1
            for oriented in (f,r)
                dual=Float64.(collect(oriented.Einv[face.axis]))
                orientation_sign=oriented.minus.cell_id==face.left_cell ? 1.0 : -1.0
                expected_conormal=orientation_sign.*(chart_to_cartesian*(dual./norm(dual)))
                @test isapprox(norm(expected_conormal),1.0;atol=2e-14,rtol=2e-14)
                @test collect(oriented.normal)≈expected_conormal atol=2e-12 rtol=2e-12
            end
            @test r.minus.cell_id==f.plus.cell_id && r.plus.cell_id==f.minus.cell_id
            @test r.minus.node_ids==f.plus.node_ids && r.plus.node_ids==f.minus.node_ids
            @test r.minus.local_dofs==f.plus.local_dofs && r.plus.local_dofs==f.minus.local_dofs
            @test r.minus.basis_values==f.plus.basis_values && r.plus.basis_values==f.minus.basis_values
            @test r.minus.basis_chart_gradients==f.plus.basis_chart_gradients &&
                r.plus.basis_chart_gradients==f.minus.basis_chart_gradients
            for endpoint in (f.minus,f.plus)
                bounds=mesh.cell_bounds[endpoint.cell_id];q=f.chart_q;xi=ntuple(a->
                    2.0*(q[a]-bounds[a][1])/(bounds[a][2]-bounds[a][1])-1.0,3)
                N=zeros(length(mesh.cell_nodes[endpoint.cell_id]));dN=zeros(3,length(N))
                for corner in 0:7
                    bits=(corner%2,div(corner,2)%2,div(corner,4)%2)
                    signs=ntuple(a->bits[a]==1 ? 1.0 : -1.0,3)
                    local_node=mesh.corner_to_local[endpoint.cell_id][corner+1]
                    N[local_node]+=prod(1.0+signs[a]*xi[a] for a in 1:3)/8.0
                    for a in 1:3
                        dN[a,local_node]+=signs[a]/(4.0*(bounds[a][2]-bounds[a][1]))*
                            prod(1.0+signs[b]*xi[b] for b in 1:3 if b!=a)
                    end
                end
                @test Float64.(collect(endpoint.basis_values))≈N atol=2e-13 rtol=2e-13
                @test permutedims(reshape(Float64.(collect(Iterators.flatten(endpoint.basis_chart_gradients))),3,length(N)))≈permutedims(dN) atol=2e-13 rtol=2e-13
            end
        end

        f_layout=_mesh_edge_test_layout(data,state,candidate_hash,(forward_edge,),
            (forward_geometry,),_mesh_edge_test_edge_evaluator)
        r_layout=_mesh_edge_test_layout(data,state,candidate_hash,(reverse_edge,),
            (reverse_geometry,),_mesh_edge_test_edge_evaluator)
        forward=CoupledInHouse.assemble_coupled_mhd_global_v1(f_layout.model,f_layout.state)
        reverse=CoupledInHouse.assemble_coupled_mhd_global_v1(r_layout.model,r_layout.state)
        fe=only(forward.raw_blocks.edge_equilibrium);re=only(reverse.raw_blocks.edge_equilibrium)
        @test fe.oracle_check.passed && re.oracle_check.passed
        @test re.minus_residual≈-fe.plus_residual atol=2e-12 rtol=2e-12
        @test re.plus_residual≈-fe.minus_residual atol=2e-12 rtol=2e-12
        @test Matrix(re.jacobian_minus_minus)≈-Matrix(fe.jacobian_plus_plus) atol=2e-12 rtol=2e-12
        @test Matrix(re.jacobian_minus_plus)≈-Matrix(fe.jacobian_plus_minus) atol=2e-12 rtol=2e-12
        @test Matrix(re.jacobian_plus_minus)≈-Matrix(fe.jacobian_minus_plus) atol=2e-12 rtol=2e-12
        @test Matrix(re.jacobian_plus_plus)≈-Matrix(fe.jacobian_minus_minus) atol=2e-12 rtol=2e-12
        # This InHouse seam model has 336 unknowns (36+48 region nodes × 4 fields).
        # Its full-column FD is separate from the spatial solver's 272-column Q1_4
        # and 2080-column Q1_8 residual checks.
        @test length(f_layout.state)==336
        full_fd=_mesh_edge_test_fd_jacobian(x->_mesh_edge_test_full_residual(
            x,f_layout.dof_maps,forward_edge,forward_geometry),f_layout.state)
        assembled=vcat(Matrix(forward.jacobian),Matrix(forward.equality_jacobian))
        @test size(full_fd,2)==336 && size(full_fd)==size(assembled)
        fd_relative=norm(assembled-full_fd,Inf)/max(norm(assembled,Inf),eps(Float64))
        @test isfinite(fd_relative) && fd_relative<=5.0e-6
        # Real source-geometry two-region positive model: four manufactured scalar
        # fields use Q1 volume weak forms, an interface flux block, three trace
        # equalities, two pressure-boundary means, and one global inventory row.
        positive_edge=merge(forward_edge,(constraint_ids=("q1_trace_field_1","q1_trace_field_2","q1_trace_field_3"),))
        positive_layout=_source_mesh_q1_positive_layout(data,candidate_hash,positive_edge,forward_geometry)
        positive=CoupledInHouse.assemble_coupled_mhd_global_v1(positive_layout.model,positive_layout.state)
        @test positive.status===:assembled
        @test norm(positive.residual,Inf)>0.0 && nnz(positive.jacobian)>0
        @test length(positive.jacobian_checks.interfaces)==1 && only(positive.jacobian_checks.interfaces).passed
        positive_explicit=CoupledInHouse.assemble_coupled_mhd_global_v1(
            positive_layout.model,positive_layout.state;allow_incomplete=true)
        @test keys(positive_explicit)==keys(positive)
        @test positive_explicit.status===:assembled
        @test positive_explicit.residual==positive.residual
        @test positive_explicit.jacobian==positive.jacobian
        @test positive_explicit.equality_residual==positive.equality_residual
        @test positive_explicit.equality_jacobian==positive.equality_jacobian
        positive_fd=_mesh_edge_test_fd_jacobian(x->_source_mesh_q1_full_residual(positive_layout,x),positive_layout.state)
        positive_jacobian=vcat(Matrix(positive.jacobian),Matrix(positive.equality_jacobian))
        @test size(positive_fd)==size(positive_jacobian)==(342,336)
        positive_fd_relative=norm(positive_jacobian-positive_fd,Inf)/max(norm(positive_jacobian,Inf),eps(Float64))
        @test isfinite(positive_fd_relative) && positive_fd_relative<=5.0e-6
        positive_policy=CoupledInHouse.make_global_policy_v1(acceptance_ref="source_mesh_q1_reaction_diffusion_test_v1",
            contract_source_path=@__FILE__,max_updates=12,wall_seconds=120.0,
            residual_tolerance=1.0e-8,constraint_tolerance=1.0e-8,
            stationarity_tolerance=1.0e-8,bound_dual_tolerance=1.0e-8,
            complementarity_tolerance=1.0e-8,step_tolerance=1.0e-10,
            minimum_step=1.0e-8,armijo_fraction=1.0e-4,max_backtracks=20,
            max_active_set_iterations=128,stagnation_window=3)
        positive_result=CoupledInHouse.solve_coupled_mhd_global_v1(positive_layout.model,positive_layout.state,positive_policy)
        @test positive_result.status===:converged
        @test positive_result.physical_validation===false && positive_result.promotion_authority===false && positive_result.terminal_authority===false && positive_result.claim_ceiling===:numerical_mechanism_only
        positive_replay=CoupledInHouse.replay_coupled_mhd_global_v1(positive_layout.model,
            positive_layout.state,positive_policy,positive_result)
        @test positive_replay.status===:replayed_exact
        @test positive_replay.replayed_result.final_state==positive_result.final_state
        println("SOURCE_MESH_Q1_POSITIVE_RESULT=",CoupledInHouse.canonical_json((
            schema="source-mesh-q1-positive-result-v1",candidate_hash=positive_result.candidate_hash,
            status=positive_result.status,physical=false,dofs=length(positive_layout.state),
            equilibrium_rows=size(positive.jacobian,1),equality_rows=size(positive.equality_jacobian,1),
            equilibrium_nnz=nnz(positive.jacobian),equality_nnz=nnz(positive.equality_jacobian),
            full_fd_rows=size(positive_jacobian,1),full_fd_columns=size(positive_fd,2),
            full_fd_relative=positive_fd_relative,updates=positive_result.updates,
            max_residual=positive_result.final_metrics.max_residual,
            max_constraint=positive_result.final_metrics.max_constraint,
            conservation_defect=positive_result.final_metrics.conservation_defect,
            final_state_hash=string(CoupledInHouse.canonical_hash(positive_result.final_state)),
            result_hash=positive_result.result_hash,replay_status=positive_replay.status,
            replay_raw_trace_match=positive_replay.raw_trace_match,
            replay_disposition_match=positive_replay.disposition_match,
            replay_result_hash=positive_replay.replayed_result_hash,
            source_geometry=(face_sha256=positive_layout.geometry.source_geometry.face_sha256,
                face_schema=positive_layout.geometry.source_geometry.face_schema,
                face_row_count=positive_layout.geometry.source_geometry.face_row_count,
                volume_samples=length(data.volume),face_quadrature_samples=length(data.face_quadrature),
                interface_quadrature_samples=length(positive_layout.geometry.samples),
                region_node_counts=Tuple(length(nodes) for nodes in positive_layout.nodes),
                region_cell_counts=Tuple(count(==(r),data.mesh.cell_regions) for r in (1,2)),
                region_volumes=Tuple(op.volume for op in positive_layout.operators)))))
        flush(stdout)
        nonlinear_edge=merge(forward_edge,(constraint_ids=("q1_trace_field_1","q1_trace_field_2","q1_trace_field_3"),))
        nonlinear_layout=_source_mesh_q1_positive_layout(data,candidate_hash,nonlinear_edge,forward_geometry;
            nonlinear=true,operators=positive_layout.operators,seed_amplitude=0.06)
        nonlinear_initial_pressure=nonlinear_layout.state[collect(nonlinear_layout.model.pressure_indices)]
        @test all(>(0.0),nonlinear_initial_pressure)
        nonlinear_assembly=CoupledInHouse.assemble_coupled_mhd_global_v1(nonlinear_layout.model,nonlinear_layout.state)
        @test nonlinear_assembly.status===:assembled && norm(nonlinear_assembly.residual,Inf)>0.0
        @test all(block->block.oracle_check.passed,nonlinear_assembly.raw_blocks.edge_equilibrium)
        @test all(check->check.passed,nonlinear_assembly.jacobian_checks.interfaces)
        nd1=nonlinear_layout.model.region_dofs[1]
        rows1=collect(1:4:nd1);cols2=collect(2:4:nd1);cols4=collect(4:4:nd1)
        @test nnz(nonlinear_assembly.jacobian[rows1,cols2])>0
        @test nnz(nonlinear_assembly.jacobian[rows1,cols4])>0
        nonlinear_fd=_mesh_edge_test_fd_jacobian(x->_source_mesh_q1_full_residual(nonlinear_layout,x),nonlinear_layout.state)
        nonlinear_jacobian=vcat(Matrix(nonlinear_assembly.jacobian),Matrix(nonlinear_assembly.equality_jacobian))
        @test size(nonlinear_fd)==size(nonlinear_jacobian)==(342,336)
        nonlinear_fd_relative=norm(nonlinear_jacobian-nonlinear_fd,Inf)/max(norm(nonlinear_jacobian,Inf),eps(Float64))
        @test isfinite(nonlinear_fd_relative) && nonlinear_fd_relative<=5.0e-6
        nonlinear_policy=CoupledInHouse.make_global_policy_v1(acceptance_ref="source_mesh_q1_nonlinear_energy_test_v1",
            contract_source_path=@__FILE__,max_updates=12,wall_seconds=120.0,
            residual_tolerance=1.0e-8,constraint_tolerance=1.0e-8,
            stationarity_tolerance=1.0e-8,bound_dual_tolerance=1.0e-8,
            complementarity_tolerance=1.0e-8,step_tolerance=1.0e-10,
            minimum_step=1.0e-8,armijo_fraction=1.0e-4,max_backtracks=20,
            max_active_set_iterations=128,stagnation_window=3)
        nonlinear_result=CoupledInHouse.solve_coupled_mhd_global_v1(nonlinear_layout.model,nonlinear_layout.state,nonlinear_policy)
        @test nonlinear_result.status===:converged && nonlinear_result.updates>1
        @test all(i->nonlinear_result.final_state[i]>=0.0,nonlinear_layout.model.pressure_indices)
        nonlinear_metrics=nonlinear_result.final_metrics
        nonlinear_min_pressure=minimum(nonlinear_result.final_state[i] for i in nonlinear_layout.model.pressure_indices)
        @test nonlinear_metrics.max_residual<=nonlinear_policy.residual_tolerance
        @test nonlinear_metrics.max_constraint<=nonlinear_policy.constraint_tolerance
        @test nonlinear_metrics.conservation_defect<=nonlinear_policy.constraint_tolerance
        @test nonlinear_metrics.stationarity<=nonlinear_policy.stationarity_tolerance
        @test nonlinear_metrics.bound_dual_violation<=nonlinear_policy.bound_dual_tolerance
        @test nonlinear_metrics.complementarity<=nonlinear_policy.complementarity_tolerance
        @test nonlinear_metrics.step_norm<=nonlinear_policy.step_tolerance
        @test isfinite(nonlinear_min_pressure) && nonlinear_min_pressure>=0.0
        @test nonlinear_result.physical_validation===false && nonlinear_result.promotion_authority===false &&
            nonlinear_result.terminal_authority===false && nonlinear_result.claim_ceiling===:numerical_mechanism_only
        nonlinear_replay=CoupledInHouse.replay_coupled_mhd_global_v1(nonlinear_layout.model,
            nonlinear_layout.state,nonlinear_policy,nonlinear_result)
        @test nonlinear_replay.status===:replayed_exact
        @test nonlinear_replay.replayed_result.final_state==nonlinear_result.final_state
        println("SOURCE_MESH_Q1_NONLINEAR_RESULT=",CoupledInHouse.canonical_json((
            schema="source-mesh-q1-nonlinear-result-v1",candidate_hash=nonlinear_result.candidate_hash,
            status=nonlinear_result.status,physical=false,dofs=length(nonlinear_layout.state),
            equilibrium_rows=size(nonlinear_assembly.jacobian,1),equality_rows=size(nonlinear_assembly.equality_jacobian,1),
            equilibrium_nnz=nnz(nonlinear_assembly.jacobian),equality_nnz=nnz(nonlinear_assembly.equality_jacobian),
            full_fd_rows=size(nonlinear_jacobian,1),full_fd_columns=size(nonlinear_fd,2),
            full_fd_relative=nonlinear_fd_relative,updates=nonlinear_result.updates,
            max_residual=nonlinear_metrics.max_residual,
            max_constraint=nonlinear_metrics.max_constraint,
            conservation_defect=nonlinear_metrics.conservation_defect,
            stationarity=nonlinear_metrics.stationarity,
            bound_dual_violation=nonlinear_metrics.bound_dual_violation,
            complementarity=nonlinear_metrics.complementarity,
            step_norm=nonlinear_metrics.step_norm,min_pressure=nonlinear_min_pressure,
            policy_thresholds=(residual=nonlinear_policy.residual_tolerance,
                constraint=nonlinear_policy.constraint_tolerance,
                stationarity=nonlinear_policy.stationarity_tolerance,
                bound_dual=nonlinear_policy.bound_dual_tolerance,
                complementarity=nonlinear_policy.complementarity_tolerance,
                step=nonlinear_policy.step_tolerance),
            final_state_hash=string(CoupledInHouse.canonical_hash(nonlinear_result.final_state)),
            result_hash=nonlinear_result.result_hash,replay_status=nonlinear_replay.status,
            replay_raw_trace_match=nonlinear_replay.raw_trace_match,
            replay_disposition_match=nonlinear_replay.disposition_match,
            replay_result_hash=nonlinear_replay.replayed_result_hash,
            source_geometry=(face_sha256=nonlinear_layout.geometry.source_geometry.face_sha256,
                face_schema=nonlinear_layout.geometry.source_geometry.face_schema,
                face_row_count=nonlinear_layout.geometry.source_geometry.face_row_count,
                volume_samples=length(data.volume),face_quadrature_samples=length(data.face_quadrature),
                interface_quadrature_samples=length(nonlinear_layout.geometry.samples),
                region_node_counts=Tuple(length(nodes) for nodes in nonlinear_layout.nodes),
                region_cell_counts=Tuple(count(==(r),data.mesh.cell_regions) for r in (1,2)),
                region_volumes=Tuple(op.volume for op in nonlinear_layout.operators)))))
        flush(stdout)

        # A separate declaration partitions the exact Q1_4 source grid at its
        # native rho=.25 and rho=.5 faces. Raw face samples cover every face
        # independently of region ownership, so the declaration-driven mesh
        # producer can expose two distinct source-backed interfaces without
        # duplicating or relabeling the old two-region mesh.
        # Reuse this complete nonlinear consumer for a distinct toroidally
        # varying source chart; retain the original case and all its assertions.
        for (g2_case,g2_input) in ((:original,input),(:m1n1_ripple,
                S.spatial_n1_manufactured_input_v1(;level=:q1_4,interior_map=:m1n1_ripple_v1)))
        g2_declaration=S.spatial_g2_three_region_source_declaration_v1(g2_input)
        S.validate_spatial_multiregion_declaration_v4(g2_declaration)
        g2_candidate_hash=string(CoupledInHouse.canonical_hash(g2_declaration))
        @test g2_candidate_hash!=candidate_hash
        g2_region_ids=Tuple("mesh_region_$(r)" for r in 1:3)
        g2_mesh_to_model=Tuple((mesh_region_id=r,model_region_id=g2_region_ids[r]) for r in 1:3)
        g2_edges=(
            (edge_id="source_mesh_rho_025",minus_region_id=g2_region_ids[1],
                plus_region_id=g2_region_ids[2],constraint_ids=("source_mesh_trace_rho_025_B_R",
                    "source_mesh_trace_rho_025_B_phi","source_mesh_trace_rho_025_B_Z")),
            (edge_id="source_mesh_rho_050",minus_region_id=g2_region_ids[2],
                plus_region_id=g2_region_ids[3],constraint_ids=("source_mesh_trace_rho_050_B_R",
                    "source_mesh_trace_rho_050_B_phi","source_mesh_trace_rho_050_B_Z")))
        g2_data,g2_geometries=mktempdir() do g2_geometry_dir
            g2_binding=(candidate_hash=S.canonical_hash(g2_declaration),
                context_hash=S.canonical_hash((scope=:g2_three_region_source_geometry,)))
            g2_receipt=S.materialize_spatial_g2_three_region_source_geometry_v1(g2_input,g2_declaration,
                g2_binding,g2_geometry_dir)
            @test S.validate_spatial_g2_three_region_source_geometry_v1(g2_input,g2_declaration,g2_binding,g2_receipt)
            loaded_data=S.load_spatial_data_v4(g2_declaration,
                (level=g2_input.mesh.level,nfp=g2_input.mesh.nfp,flux_Wb=g2_input.flux.nominal_Wb,
                    raw_artifacts=g2_receipt.raw_artifacts))
            @test loaded_data.g2_source_identity.declaration_hash==S.canonical_hash(g2_declaration)
            @test Tuple((sample.entity_id,sample.qp_id) for sample in loaded_data.face_quadrature)==
                Tuple((face_id,qp_id) for face_id in eachindex(loaded_data.mesh.faces) for qp_id in 1:9)
            node_maps=_mesh_edge_test_node_layout(loaded_data).node_dof_maps
            geometries=S.spatial_multiregion_interface_geometry_contexts_v1(loaded_data,g2_edges;
                mesh_region_to_model_region=g2_mesh_to_model,region_node_local_dofs=node_maps)
            @test length(geometries)==2
            g2_data,g2_geometries=loaded_data,geometries

        @test Tuple(sort!(unique(g2_data.mesh.cell_regions)))==(1,2,3)
        @test Tuple(count(==(r),g2_data.mesh.cell_regions) for r in 1:3)==(16,16,32)
        g2_face_ids=Tuple(Set(sample.face_id for sample in geometry.samples) for geometry in g2_geometries)
        @test all(!isempty, g2_face_ids)
        @test isempty(intersect(g2_face_ids[1],g2_face_ids[2]))
        @test Tuple(count(f->f.role===:interface &&
            (g2_data.mesh.cell_regions[f.left_cell],g2_data.mesh.cell_regions[f.right_cell])==pair,
            g2_data.mesh.faces) for pair in ((1,2),(2,3)))==(16,16)

        if g2_case===:m1n1_ripple
            @test g2_input.geometry.model===:m1n1_ripple_torus
            @test g2_input.geometry.ripple_amplitude==0.05
            @test all(sample->isfinite(sample.weight) && sample.weight>0.0,g2_data.volume)
            for sample in g2_data.volume
                xyz,E,Q=O._geometry(g2_input,sample.q)
                rho,theta,zeta=sample.q
                aa=g2_input.geometry.minor_radius_m;ee=g2_input.geometry.ripple_amplitude
                expected_det=-hypot(xyz[1],xyz[2])*aa^2*rho*(1+ee^2+2ee*cos(zeta))
                @test expected_det<0.0
                @test sample.detE≈expected_det rtol=2e-13 atol=2e-13
                @test sample.E≈E rtol=2e-13 atol=2e-13
                @test collect(sample.xyz)≈collect(xyz) rtol=2e-13 atol=2e-13
                @test sample.E*sample.Einv≈Matrix{Float64}(I,3,3) rtol=2e-13 atol=2e-13
            end
            ripple_normal_phi_peak=0.0
            for geometry in g2_geometries,sample in geometry.samples
                xyz,E,Q=O._geometry(g2_input,sample.chart_q)
                face=g2_data.mesh.faces[sample.face_id]
                orientation=sample.minus.cell_id==face.left_cell ? 1.0 : -1.0
                # Independent tangential cross-product, not the provider inverse row.
                area_vector=cross(E[:,3],E[:,2]);normal=orientation.*(Q*(area_vector/norm(area_vector)))
                @test sample.weight>0.0 && all(isfinite,normal)
                @test collect(sample.normal)≈normal rtol=2e-12 atol=2e-12
                ripple_normal_phi_peak=max(ripple_normal_phi_peak,abs((transpose(Q)*normal)[2]))
                # Manufactured source traction holdout; the solved contact law
                # remains the existing nonlinear scalar energy interface law.
                X,Y,Z=xyz;beta=g2_input.fields.beta_T_m;R=hypot(X,Y)
                B=Float64[-beta*Y,beta*X,0.0]
                pressure=g2_input.fields.p0_Pa+g2_input.fields.alpha_Pa_m2*((R-g2_input.geometry.R0_m)^2+Z^2)
                traction=(dot(B,normal).*B-0.5*dot(B,B).*normal)./g2_input.fields.mu0_N_A2-pressure.*normal
                @test S._smm_traction_v1(g2_input,sample.xyz,sample.normal)≈traction rtol=2e-12 atol=2e-12
                @test S._smm_traction_v1(g2_input,sample.xyz,Tuple(-normal))≈-traction rtol=2e-12 atol=2e-12
            end
            @test ripple_normal_phi_peak>1e-8
        end

        g2_layout=_source_mesh_q1_positive_layout(g2_data,g2_candidate_hash,g2_edges,g2_geometries;
            nonlinear=true,seed_amplitude=0.06)
        g2_assembly=CoupledInHouse.assemble_coupled_mhd_global_v1(g2_layout.model,g2_layout.state)
        @test g2_assembly.status===:assembled && norm(g2_assembly.residual,Inf)>0.0
        @test length(g2_assembly.raw_blocks.edge_equilibrium)==2
        @test all(block->block.oracle_check.passed,g2_assembly.raw_blocks.edge_equilibrium)
        @test length(g2_assembly.jacobian_checks.interfaces)==2 &&
            all(check->check.passed,g2_assembly.jacobian_checks.interfaces)
        g2_fd=_mesh_edge_test_fd_jacobian(x->_source_mesh_q1_full_residual(g2_layout,x),g2_layout.state)
        g2_jacobian=vcat(Matrix(g2_assembly.jacobian),Matrix(g2_assembly.equality_jacobian))
        @test size(g2_fd)==size(g2_jacobian)==(410,400)
        g2_fd_relative=norm(g2_jacobian-g2_fd,Inf)/max(norm(g2_jacobian,Inf),eps(Float64))
        @test isfinite(g2_fd_relative) && g2_fd_relative<=5.0e-6
        g2_policy=CoupledInHouse.make_global_policy_v1(acceptance_ref="g2_source_mesh_three_region_nonlinear_test_v1",
            contract_source_path=@__FILE__,max_updates=12,wall_seconds=120.0,
            residual_tolerance=1.0e-8,constraint_tolerance=1.0e-8,
            stationarity_tolerance=1.0e-8,bound_dual_tolerance=1.0e-8,
            complementarity_tolerance=1.0e-8,step_tolerance=1.0e-10,
            minimum_step=1.0e-8,armijo_fraction=1.0e-4,max_backtracks=20,
            max_active_set_iterations=128,stagnation_window=3)
        g2_result=CoupledInHouse.solve_coupled_mhd_global_v1(g2_layout.model,g2_layout.state,g2_policy)
        @test g2_result.status===:converged && g2_result.updates>1
        @test all(i->g2_result.final_state[i]>=0.0,g2_layout.model.pressure_indices)
        g2_metrics=g2_result.final_metrics
        g2_min_pressure=minimum(g2_result.final_state[i] for i in g2_layout.model.pressure_indices)
        @test g2_metrics.max_residual<=g2_policy.residual_tolerance
        @test g2_metrics.max_constraint<=g2_policy.constraint_tolerance
        @test g2_metrics.conservation_defect<=g2_policy.constraint_tolerance
        @test g2_metrics.stationarity<=g2_policy.stationarity_tolerance
        @test g2_metrics.bound_dual_violation<=g2_policy.bound_dual_tolerance
        @test g2_metrics.complementarity<=g2_policy.complementarity_tolerance
        @test g2_metrics.step_norm<=g2_policy.step_tolerance
        @test isfinite(g2_min_pressure) && g2_min_pressure>=0.0
        @test g2_result.physical_validation===false && g2_result.promotion_authority===false &&
            g2_result.terminal_authority===false && g2_result.claim_ceiling===:numerical_mechanism_only
        g2_replay=CoupledInHouse.replay_coupled_mhd_global_v1(g2_layout.model,g2_layout.state,g2_policy,g2_result)
        @test g2_replay.status===:replayed_exact
        @test g2_replay.replayed_result.final_state==g2_result.final_state
        println(g2_case===:original ? "SOURCE_MESH_Q1_G2_THREE_REGION_RESULT=" :
            "SOURCE_MESH_Q1_G2_THREE_REGION_M1N1_RESULT=",CoupledInHouse.canonical_json((
            schema="source-mesh-q1-g2-three-region-result-v1",candidate_hash=g2_candidate_hash,
            status=g2_result.status,physical=false,dofs=length(g2_layout.state),
            region_cell_counts=Tuple(count(==(r),g2_data.mesh.cell_regions) for r in 1:3),
            interface_face_counts=Tuple(length(ids) for ids in g2_face_ids),
            interface_quadrature_counts=Tuple(length(geometry.samples) for geometry in g2_geometries),
            equilibrium_rows=size(g2_assembly.jacobian,1),equality_rows=size(g2_assembly.equality_jacobian,1),
            full_fd_rows=size(g2_jacobian,1),full_fd_columns=size(g2_fd,2),full_fd_relative=g2_fd_relative,
            updates=g2_result.updates,max_residual=g2_metrics.max_residual,
            max_constraint=g2_metrics.max_constraint,conservation_defect=g2_metrics.conservation_defect,
            stationarity=g2_metrics.stationarity,bound_dual_violation=g2_metrics.bound_dual_violation,
            complementarity=g2_metrics.complementarity,step_norm=g2_metrics.step_norm,min_pressure=g2_min_pressure,
            final_state_hash=string(CoupledInHouse.canonical_hash(g2_result.final_state)),
            result_hash=g2_result.result_hash,replay_status=g2_replay.status,
            replay_raw_trace_match=g2_replay.raw_trace_match,replay_disposition_match=g2_replay.disposition_match,
            replay_result_hash=g2_replay.replayed_result_hash,
            source_geometry=(face_sha256=string(g2_data.raw_artifacts.faces.sha256),
                face_schema=g2_data.raw_artifacts.faces.schema,
                face_row_count=g2_data.raw_artifacts.faces.row_count,
                source_declaration_hash=string(g2_data.g2_source_identity.declaration_hash)))))
        flush(stdout)
        (g2_data,g2_geometries)
        end

        end # original and m1n1-ripple source geometry

        # Exercise the second geometry-context index through the existing
        # three-region sparse assembler. The reverse source-backed context has
        # the same interface samples with the opposite endpoint orientation.
        multi_regions=("geometry_core","geometry_mid","geometry_edge")
        multi_edges=(
            (edge_id="source_mesh_edge_1",minus_region_id=multi_regions[1],
                plus_region_id=multi_regions[2],constraint_ids=("geometry_interface_1",)),
            (edge_id="source_mesh_edge_2",minus_region_id=multi_regions[2],
                plus_region_id=multi_regions[3],constraint_ids=("geometry_interface_2",)))
        remap_geometry=(geometry,edge_id,minus_region,plus_region)->begin
            samples=Tuple(merge(sample,(minus=merge(sample.minus,(region_id=minus_region,)),
                plus=merge(sample.plus,(region_id=plus_region,)))) for sample in geometry.samples)
            merge(geometry,(edge_id=edge_id,samples=samples))
        end
        multi_geometries=(remap_geometry(forward_geometry,multi_edges[1].edge_id,
                multi_regions[1],multi_regions[2]),
            remap_geometry(reverse_geometry,multi_edges[2].edge_id,
                multi_regions[2],multi_regions[3]))
        multi_dofs=(length(f_layout.region_nodes[1])*4,
            length(f_layout.region_nodes[2])*4,length(f_layout.region_nodes[1])*4)
        multi_maps=(Tuple(1:multi_dofs[1]),
            Tuple((multi_dofs[1]+1):(multi_dofs[1]+multi_dofs[2])),
            Tuple((multi_dofs[1]+multi_dofs[2]+1):sum(multi_dofs)))
        multi_state=vcat(Float64[f_layout.state[1:multi_dofs[1]]...],
            Float64[f_layout.state[(multi_dofs[1]+1):(multi_dofs[1]+multi_dofs[2])]...],
            Float64[f_layout.state[1:multi_dofs[1]]...])
        multi_eqids=Tuple(_mesh_edge_test_eqids(multi_regions[k],multi_dofs[k]) for k in 1:3)
        multi_callbacks=(_mesh_edge_test_region_evaluator,_mesh_edge_test_interface_evaluator,
            _mesh_edge_test_outer_evaluator,_mesh_edge_test_conservation_evaluator,
            _mesh_edge_test_jacobian_oracle)
        multi_closure_payload=(classification=:test_only,physical=false,
            purpose="two-edge source-backed interface context index parity")
        multi_closures=NamedTuple{CoupledInHouse._REQUIRED_CLOSURES}(Tuple(
            CoupledInHouse.make_closure_evidence_v1(kind,candidate_hash,
                "preparation/test_only/two_edge_context_index_v1",@__FILE__,
                multi_closure_payload) for kind in CoupledInHouse._REQUIRED_CLOSURES))
        multi_model_for=ordered_contexts->begin
            multi_provider_hash=CoupledInHouse.coupled_mhd_provider_context_hash_v1(
                multi_callbacks...;edge_equilibrium_evaluator=_mesh_edge_test_edge_evaluator,
                interface_geometry_contexts=ordered_contexts)
            CoupledInHouse.make_global_model_v1(candidate_hash=candidate_hash,
                region_ids=multi_regions,region_dofs=multi_dofs,
                pressure_indices=Tuple(vcat(collect(4:4:multi_dofs[1]),
                    collect(multi_dofs[1].+(4:4:multi_dofs[2])),
                    collect((multi_dofs[1]+multi_dofs[2]).+(4:4:multi_dofs[3])))),
                regional_equation_ids=multi_eqids,
                interface_constraint_ids=("geometry_interface_1","geometry_interface_2"),
                interface_edges=multi_edges,interface_geometry_contexts=ordered_contexts,
                local_dof_to_global=multi_maps,local_test_row_to_global=multi_maps,
                pressure_indices_global=true,
                edge_equilibrium_evaluator=_mesh_edge_test_edge_evaluator,
                outer_constraint_ids=Tuple(("outer_$(region)",) for region in multi_regions),
                global_conservation_ids=("mesh_test_balance",),
                closure_evidence=multi_closures,
                provider_id="preparation/test_only/two_edge_context_index_v1",
                provider_source_path=@__FILE__,provider_context_hash=multi_provider_hash,
                regional_evaluator=multi_callbacks[1],interface_evaluator=multi_callbacks[2],
                outer_evaluator=multi_callbacks[3],conservation_evaluator=multi_callbacks[4],
                jacobian_oracle=multi_callbacks[5])
        end
        multi_model=multi_model_for(multi_geometries)
        multi=CoupledInHouse.assemble_coupled_mhd_global_v1(multi_model,multi_state)
        multi_edge_blocks=multi.raw_blocks.edge_equilibrium
        @test length(multi_edge_blocks)==2
        @test all(block->block.oracle_check.passed,multi_edge_blocks)
        @test length(multi.jacobian_checks.interfaces)==2 &&
            all(check->check.passed,multi.jacobian_checks.interfaces)
        multi_terms=(
            _mesh_edge_test_edge_terms(Float64[multi_state[i] for i in multi_maps[1]],
                Float64[multi_state[i] for i in multi_maps[2]],multi_geometries[1];with_jacobian=true),
            _mesh_edge_test_edge_terms(Float64[multi_state[i] for i in multi_maps[2]],
                Float64[multi_state[i] for i in multi_maps[3]],multi_geometries[2];with_jacobian=true))
        @test multi_edge_blocks[1].minus_residual≈multi_terms[1].minus_residual atol=2e-12 rtol=2e-12
        @test multi_edge_blocks[2].minus_residual≈multi_terms[2].minus_residual atol=2e-12 rtol=2e-12
        expected_multi_residual=zeros(Float64,sum(multi_dofs))
        expected_multi_jacobian=zeros(Float64,sum(multi_dofs),sum(multi_dofs))
        for (edge_index,(minus_index,plus_index)) in enumerate(((1,2),(2,3)))
            minus_rows=collect(multi_maps[minus_index]);plus_rows=collect(multi_maps[plus_index])
            terms=multi_terms[edge_index]
            expected_multi_residual[minus_rows].+=terms.minus_residual
            expected_multi_residual[plus_rows].+=terms.plus_residual
            edge_rows=vcat(minus_rows,plus_rows)
            edge_jacobian=[terms.jacobian_minus_minus terms.jacobian_minus_plus;
                terms.jacobian_plus_minus terms.jacobian_plus_plus]
            expected_multi_jacobian[edge_rows,edge_rows].+=edge_jacobian
        end
        @test multi.residual≈expected_multi_residual atol=2e-12 rtol=2e-12
        @test Matrix(multi.jacobian)≈expected_multi_jacobian atol=2e-12 rtol=2e-12
        @test_throws ArgumentError multi_model_for(Base.reverse(multi_geometries))

        legacy_layout=_mesh_edge_test_layout(data,state,candidate_hash,(forward_edge,),nothing,
            _mesh_edge_test_legacy_evaluator)
        legacy_context=CoupledInHouse._provider_context(legacy_layout.model;interface_edge=forward_edge)
        @test legacy_layout.model.interface_geometry_contexts===nothing
        @test hasproperty(legacy_context,:interface_edge) &&
            !hasproperty(legacy_context,:interface_geometry_context)
        legacy=CoupledInHouse.assemble_coupled_mhd_global_v1(legacy_layout.model,legacy_layout.state)
        @test legacy.status===:assembled && only(legacy.raw_blocks.edge_equilibrium).edge.edge_id==
            _MESH_EDGE_TEST_EDGE_ID
    end
    nothing
end

function q1_8_continuation_seed_diagnostic_v1(source_root,diagnostic_root)
    source=_q1_4_continuation_source_v1(source_root)
    root=abspath(String(diagnostic_root));ispath(root)&&throw(ArgumentError("preserve existing Q1_8 seed diagnostic directory"));mkpath(root)
    input=S.spatial_n1_manufactured_input_v1(;level=:q1_8);declaration=S.spatial_n1_manufactured_declaration_v1(input)
    context,_=assert_candidate_chain(input,declaration;parent_context=source.parent_context)
    test_q1_4_continuation_rejects_wrong_candidate_v1(source,context)
    spec=_q1_real_consumer_spec(:q1_8)
    source_state=S._smgw_current_q1_4_artifact_state_v1(source.context,source.production_dir,context)
    mesh=S.build_spatial_mesh_v4(declaration,:q1_8,input.mesh.nfp)
    seed=S.spatial_q1_4_to_q1_8_initial_state_v1(source_state.input,source_state.mesh,
        source_state.state,input,mesh;pressure_scale_Pa=declaration.scaling.p_Pa)
    receipt=S.materialize_spatial_manufactured_geometry_v1(context,input,joinpath(root,"geometry"))
    data=S.load_spatial_data_v4(declaration,(level=input.mesh.level,nfp=input.mesh.nfp,
        flux_Wb=input.flux.nominal_Wb,raw_artifacts=receipt.raw_artifacts))
    cols=repeat(Float64[declaration.scaling.B_T,declaration.scaling.B_T,
        declaration.scaling.B_T,declaration.scaling.p_Pa],div(spec.unknowns,4))
    length(seed)==spec.unknowns&&all(isfinite,seed)&&
        all(i->S._smr_pressure_feasible(seed[i],cols[i]),4:4:length(seed))||error("invalid prolonged diagnostic seed")
    admission=S._smgw_admit_context_v1(context)
    seal=S._smgw_capture_operator_binding_v1(admission,data,receipt,seed;residual_partition=:spatial_native)
    guard=()->S._smgw_assert_operator_binding_v1(seal,context,declaration,data,receipt,seed;residual_partition=:spatial_native)
    println("SMGW_PHASE_BEGIN=q1_8_continuation_seed_assembly");flush(stdout)
    actual=S.assemble_spatial_global_weak_system_v1(declaration,data,seed;
        flux_Wb=input.flux.nominal_Wb,jacobian=true,residual_partition=:spatial_native)
    grid=O.grid(collect(input.mesh.rho),input.mesh.theta_count,input.mesh.zeta_per_period*input.mesh.nfp)
    oracle=O.assemble(input,grid,seed;order=3,scaling=declaration.scaling)
    _assert_q1_globalweak_rowspace(:q1_8,actual,spec,"continuation_seed_actual")
    _assert_q1_globalweak_rowspace(:q1_8,oracle,spec,"continuation_seed_oracle")
    _assert_q1_level_oracle_assembly(:q1_8,actual,oracle,"continuation_seed")
    delta=maximum(abs.(actual.residual.-oracle.residual)./actual.row_scales;init=0.0)
    r=actual.residual./actual.row_scales
    blocks=Tuple((block=String(b),maximum=maximum((abs(r[i]) for i in eachindex(r)
        if actual.row_blocks[i]==b);init=0.0)) for b in unique(actual.row_blocks))
    mrows=Int[4*(n-1)+k for n in 1:spec.nodes for k in 1:3]
    worst=sort(mrows;by=i->(-abs(r[i]),i))[1:min(6,length(mrows))]
    rowinfo=Tuple((row=i,node=div(i-1,4)+1,component=(:x,:y,:z)[mod(i-1,4)+1],
        scaled_residual=r[i],support=actual.row_supports[i]) for i in worst)
    A=spdiagm(0=>1.0./actual.row_scales)*actual.jacobian*spdiagm(0=>cols)
    g=transpose(A)*r;z=seed./cols;bt=S._smr_scaled_bound_tolerance(z)
    pressure_contacts=Int[i for i in 4:4:spec.unknowns if z[i]<=bt[i]]
    active=Int[i for i in pressure_contacts if g[i]>0.0]
    contact_records=Tuple((index=i,scaled_gap=z[i],gradient=g[i],
        projected_active=g[i]>0.0,gradient_sign=sign(g[i])) for i in pressure_contacts)
    chosen=Set{Int}();for i in worst;union!(chosen,actual.row_supports[i]);end;union!(chosen,pressure_contacts)
    fcols=sort!(collect(chosen));colrows=Dict(j=>Int[] for j in fcols)
    for row in eachindex(actual.row_supports),j in actual.row_supports[row]
        haskey(colrows,j)&&push!(colrows[j],row)
    end
    # Color only this bounded column subset by its declared row supports.
    groups=Vector{Vector{Int}}();used=BitSet[]
    for j in fcols
        rows=colrows[j];slot=findfirst(u->all(i->!(i in u),rows),used)
        if slot===nothing;push!(groups,Int[j]);push!(used,BitSet(rows))
        else;push!(groups[slot],j);union!(used[slot],rows);end
    end
    ferr=Dict(j=>Float64[] for j in fcols);fref=Dict(j=>Float64[] for j in fcols)
    for group in groups
        xp=copy(seed);xm=copy(seed);mask=falses(spec.global_rows);hs=Dict{Int,Float64}()
        for j in group
            h=sqrt(eps(Float64))*max(abs(seed[j]),cols[j]);hs[j]=h;xp[j]+=h;xm[j]-=h
            for i in colrows[j];mask[i]=true;end
        end
        rp=O.assemble(input,grid,xp;order=3,residual_only=true,row_mask=mask)
        rm=O.assemble(input,grid,xm;order=3,residual_only=true,row_mask=mask)
        for j in group,i in colrows[j]
            fd=(rp[i]-rm[i])/(2hs[j])*cols[j]/oracle.row_scales[i]
            prod=A[i,j];push!(ferr[j],abs(prod-fd));push!(fref[j],abs(prod))
        end
    end
    fd_by_column=Tuple((column=j,max_abs_error=maximum(ferr[j];init=0.0),
        max_abs_reference=maximum(fref[j];init=0.0),relative_error=maximum(ferr[j];init=0.0)/
            max(maximum(fref[j];init=0.0),eps(Float64))) for j in fcols)
    fd_worst=isempty(fd_by_column) ? nothing : fd_by_column[argmax(map(x->x.relative_error,fd_by_column))]
    fdrel=fd_worst===nothing ? 0.0 : fd_worst.relative_error
    lower=S._smgw_scaled_lower_bounds_v1(seed,cols);bp=S.SpatialBoundedLinearStepV1.bounded_linear_step_policy_v1()
    raw=S.SpatialBoundedLinearStepV1.solve_lower_bounded_step_v1(A,r,lower;policy=bp,seconds=120.0)
    ranks=Int[h.rank_estimate for h in raw.history if hasproperty(h,:rank_estimate)&&h.rank_estimate isa Integer]
    rawinfo=(status=raw.status,converged=raw.converged,elapsed_seconds=raw.elapsed_seconds,
        rank_estimate=isempty(ranks) ? nothing : last(ranks),active_count=length(raw.active_indices),
        free_count=length(raw.free_indices),kkt=(passed=raw.kkt.passed,
        free_stationarity=raw.kkt.free_stationarity,lower_dual_violation=raw.kkt.lower_dual_violation,
        scaled_complementarity=raw.kkt.scaled_complementarity,primal_feasible=raw.kkt.primal_feasible))
    line=nothing;candidate=nothing
    if raw.converged
        step=Float64.(collect(raw.step));dirdot=2.0*dot(g,step);phi=dot(r,r)
        search=S.MultiTopologyNonlinearSolveV1.accepted_step_v1(seed,step,cols;
            objective_before=phi,directional_derivative=dirdot,max_backtracks=input.numerics.line_search_steps,
            alpha0=1.0,reduction=0.5,minimum_alpha=0.0,armijo_fraction=2.0e-4,
            require_strict_decrease=true,
            assemble_trial=t->S.assemble_spatial_global_weak_system_v1(declaration,data,t;
                flux_Wb=input.flux.nominal_Wb,jacobian=false,residual_partition=:spatial_native),
            assembly_ready=_->true,unavailable_reason=_->(kind=:unexpected_unavailable_global_weak_assembly,),
            residual_for_merit=a->a.residual./a.row_scales,merit=(_,q)->dot(q,q),
            project_state=t->begin
                for i in 4:4:length(t);S._smr_pressure_feasible(t[i],cols[i])&&t[i]<0.0&&(t[i]=0.0);end;t
            end,
            feasible=t->all(i->S._smr_pressure_feasible(t[i],cols[i]),4:4:length(t)),
            changed=(a,b)->a!=b&&S._smr_scaled_state_change(a,b,cols),
            evaluation_record=_->nothing,binding_guard=guard)
        ix=findlast(t->t.accepted,search.trials);alpha=search.accepted_alpha
        actual_step=alpha===nothing ? nothing : (search.state.-seed)./cols
        pred_at=actual_step===nothing ? nothing : dot(r.+A*actual_step,r.+A*actual_step)
        pred_full=dot(r.+A*step,r.+A*step)
        actual_obj=alpha===nothing ? nothing : search.accepted_objective
        line=(status=search.status,accepted_alpha=alpha,objective_before=phi,
            objective_after=actual_obj,predicted_objective_after_same_alpha=pred_at,
            predicted_objective_after_alpha_one=pred_full,
            predicted_decrease_same_alpha=pred_at===nothing ? nothing : phi-pred_at,
            actual_decrease=actual_obj===nothing ? nothing : phi-actual_obj,
            same_alpha_actual_to_predicted_ratio=(pred_at===nothing||phi==pred_at||actual_obj===nothing) ? nothing :
                (phi-actual_obj)/(phi-pred_at),directional_derivative=dirdot,
            armijo_bound=ix===nothing ? nothing : search.trials[ix].armijo_bound,
            trials=Tuple((index=t.trial_index,alpha=t.alpha,evaluated=t.evaluated,
                feasible=t.feasible,objective_after=t.objective_after,armijo=t.armijo,accepted=t.accepted)
                for t in search.trials))
        final=search.accepted_assembly===nothing ? actual : search.accepted_assembly
        rf=final.residual./final.row_scales
        candidate=(accepted=search.status===:accepted,evaluated=search.accepted_assembly!==nothing,scaled_maximum=maximum(abs,rf),
            block_maxima=Tuple((block=String(b),maximum=maximum((abs(rf[i]) for i in eachindex(rf)
                if final.row_blocks[i]==b);init=0.0)) for b in unique(final.row_blocks)),
            state_hash=string(canonical_hash(Tuple(search.state))))
    end
    summary=(schema="spatial-global-weak-q1_8-continuation-seed-diagnostic-v1",
        diagnostic_scope=:seed_diagnostic_only,acceptance=:not_assessed,
        physical_validation=:unsupported,authority=:no_publish,q1_4_root=realpath(source_root),
        q1_4_state_hash=string(canonical_hash(source_state.state)),
        q1_8_candidate_hash=string(context.candidate_hash),q1_8_context_hash=string(context.context_hash),
        unknowns=spec.unknowns,rows=spec.global_rows,seed_hash=string(canonical_hash(Tuple(seed))),
        seed_pressure_min_Pa=minimum(seed[4:4:end]),independent_residual_scaled_inf_delta=delta,
        residual_block_maxima=blocks,worst_momentum_rows=rowinfo,pressure_lower_contacts=contact_records,
        positive_gradient_active_pressure_indices=Tuple(active),
        selected_fd_columns=length(fcols),selected_fd_colors=length(groups),
        selected_fd_per_column=fd_by_column,selected_fd_worst_column=fd_worst,
        selected_fd_relative_error=fdrel,
        raw_bounded_qr=rawinfo,armijo=line,accepted_candidate_original_residual=candidate)
    path=joinpath(root,"q1_8_continuation_seed_diagnostic.json")
    write(path,canonical_json(summary)*"\n")
    println("SMGW_PHASE_END=q1_8_continuation_seed_assembly residual_delta=",delta,
        " selected_fd_relative=",fdrel," diagnostic_only=true report=",path);flush(stdout)
    summary
end

function _q1_4_inhouse_step_probe_v1(input,declaration,context,data,receipt,state,grid,spec)
    length(state)==272 && length(data.mesh.row_blocks)==spec.ownership_rows==2177 &&
        spec.global_rows==337 && spec.unknowns==272 ||
        error("Q1_4 InHouse probe input is not the current 337x272/68-node consumer")
    admission=S._smgw_admission_record_v1(context,declaration)
    seal=S._smgw_capture_operator_binding_v1(admission,data,receipt,state;
        residual_partition=:inhouse_kkt)
    binding_guard=()->S._smgw_assert_operator_binding_v1(seal,context,declaration,data,
        receipt,state;residual_partition=:inhouse_kkt)
    binding_guard()
    actual=S.assemble_spatial_global_weak_system_v1(declaration,data,state;
        flux_Wb=input.flux.nominal_Wb,jacobian=true,residual_partition=:inhouse_kkt)
    binding_guard()
    native_actual=S.assemble_spatial_global_weak_system_v1(declaration,data,state;
        flux_Wb=input.flux.nominal_Wb,jacobian=true,residual_partition=:spatial_native)
    oracle=O.assemble(input,grid,state;order=3,scaling=declaration.scaling)
    _assert_q1_globalweak_rowspace(:q1_4,actual,spec,"inhouse_probe_actual")
    _assert_q1_globalweak_rowspace(:q1_4,oracle,spec,"inhouse_probe_oracle")
    oracle_delta=_assert_q1_level_oracle_assembly(:q1_4,actual,oracle,"inhouse_probe_final_state")
    residual_partition_delta=maximum(abs.(actual.residual.-native_actual.residual);init=0.0)
    jacobian_partition_delta=maximum(abs,nonzeros(sparse(actual.jacobian-native_actual.jacobian));init=0.0)
    columns=repeat(Float64[declaration.scaling.B_T,declaration.scaling.B_T,
        declaration.scaling.B_T,declaration.scaling.p_Pa],div(length(state),4))
    fd=O.finite_difference_jacobian(input,grid,state;order=3,column_scales=columns)
    actual_scaled=spdiagm(0=>1.0./actual.row_scales)*actual.jacobian*spdiagm(0=>columns)
    fd_scaled=Diagonal(1.0./oracle.row_scales)*fd*Diagonal(columns)
    actual_dense=Matrix(actual_scaled)
    fd_relative=norm(actual_dense-fd_scaled,Inf)/max(norm(actual_dense,Inf),eps(Float64))
    fd_finite=size(fd)==(spec.global_rows,spec.unknowns) && all(isfinite,fd) &&
        all(isfinite,actual_dense) && all(isfinite,fd_scaled) && isfinite(fd_relative)

    partition=S._smgw_inhouse_partition_v1(actual,admission,seal)
    A=actual_scaled
    r=partition.scaled_least_squares_residual
    lower=S._smgw_scaled_lower_bounds_v1(state,columns)
    linear_policy=S.SpatialBoundedLinearStepV1.bounded_linear_step_policy_v1()
    native_started=time_ns()
    native=S.SpatialBoundedLinearStepV1.solve_lower_bounded_step_v1(
        A,r,lower;policy=linear_policy,seconds=120.0)
    native_seconds=(time_ns()-native_started)/1.0e9
    native_step=Float64.(collect(native.step))
    native_finite=length(native_step)==spec.unknowns && all(isfinite,native_step)
    native_audit=native_finite ? S.SpatialBoundedLinearStepV1.bounded_step_kkt_v1(
        A,r,lower,native_step,native.active_indices;policy=linear_policy) : nothing
    native_model=native_finite ? r+A*native_step : nothing

    inhouse_started=time_ns()
    inhouse_step_matrix=partition.scaled_least_squares_jacobian*spdiagm(0=>columns)
    inhouse=CoupledInHouse.solve_weighted_residual_kkt_step_v1(partition;
        scaled_state=state./columns,column_scales=columns,
        pressure_indices=Tuple(4:4:length(state)),
        stationarity_tolerance=linear_policy.kkt_absolute_tolerance,
        bound_dual_tolerance=linear_policy.kkt_absolute_tolerance,
        max_active_set_iterations=8*spec.unknowns+16,seconds=120.0)
    inhouse_seconds=(time_ns()-inhouse_started)/1.0e9
    inhouse_step=hasproperty(inhouse,:step) ? Float64.(collect(inhouse.step)) : nothing
    inhouse_finite=inhouse_step!==nothing && length(inhouse_step)==spec.unknowns &&
        all(isfinite,inhouse_step)
    inhouse_audit=inhouse_finite ? S.SpatialBoundedLinearStepV1.bounded_step_kkt_v1(
        A,r,lower,inhouse_step,inhouse.active_bounds;policy=linear_policy) : nothing
    inhouse_model=inhouse_finite ? r+A*inhouse_step : nothing
    native_endpoint=native_finite ? state.+columns.*native_step : nothing
    native_endpoint_pressure=native_finite ? native_endpoint[4:4:end] : nothing
    endpoint=inhouse_finite ? state.+columns.*inhouse_step : nothing
    endpoint_pressure=inhouse_finite ? endpoint[4:4:end] : nothing
    rank_snapshots=Tuple(item.kkt_rank for item in inhouse.active_set_trace)
    fallback_snapshot_index=findlast(item->item!==nothing && hasproperty(item,:fallback_reason),rank_snapshots)
    fallback_snapshot=fallback_snapshot_index===nothing ? nothing : rank_snapshots[fallback_snapshot_index]
    rank_snapshot=isempty(rank_snapshots) ? nothing : rank_snapshots[end]
    kkt_order=rank_snapshot===nothing ? nothing :
        (hasproperty(rank_snapshot,:original_kkt_order) ? rank_snapshot.original_kkt_order : rank_snapshot.columns)
    equality_error=isempty(partition.equality_residual) ? 0.0 :
        maximum(abs.(partition.equality_jacobian*inhouse_step.+partition.equality_residual);init=0.0)
    known_rank_gap=inhouse.status===:numerical_fail &&
        inhouse.reason===:rank_verification_capability_gap
    (schema="q1-4-inhouse-kkt-one-step-probe-v1",level=:q1_4,
        diagnostic_only=true,nonlinear_solve=:not_reexecuted,physical_validation=:unsupported,
        authority=:no_publish,formal_credit=false,convergence_credit=false,
        candidate_hash=string(context.candidate_hash),context_hash=string(context.context_hash),
        input_hash=string(canonical_hash(input)),declaration_hash=string(canonical_hash(declaration)),
        producer_state_hash=string(canonical_hash(Tuple(state))),
        assembly=(rows=size(actual.jacobian,1),columns=size(actual.jacobian,2),nnz=nnz(actual.jacobian),
            residual_finite=all(isfinite,actual.residual),jacobian_finite=all(isfinite,nonzeros(actual.jacobian)),
            independent_oracle_scaled_residual_delta=oracle_delta,
            native_partition_residual_max_delta=residual_partition_delta,
            native_partition_jacobian_max_delta=jacobian_partition_delta),
        finite_difference=(method=:independent_centered_fd_all_columns,rows=size(fd,1),columns=size(fd,2),
            threshold=5.0e-6,relative_infinity_error=fd_relative,all_finite=fd_finite),
        partition=(rows=length(partition.least_squares_row_ids),columns=size(partition.scaled_least_squares_jacobian,2),
            nnz=nnz(partition.scaled_least_squares_jacobian),equality_rows=length(partition.equality_residual),
            equality_jacobian_size=size(partition.equality_jacobian),equality_max_abs=equality_error,
            row_identity_hash=partition.row_identity_hash,partition_hash=partition.partition_hash),
        inhouse_kkt_input=(schema="saved-inhouse-kkt-step-input-v1",
            jacobian_csc=(rows=size(inhouse_step_matrix,1),columns=size(inhouse_step_matrix,2),
                colptr=Tuple(inhouse_step_matrix.colptr),rowval=Tuple(inhouse_step_matrix.rowval),
                nzval=Tuple(nonzeros(inhouse_step_matrix))),
            scaled_residual=Tuple(r),scaled_state=Tuple(state./columns),
            column_scales=Tuple(columns),pressure_indices=Tuple(4:4:length(state)),
            equality_rows=length(partition.equality_residual),partition_hash=partition.partition_hash),
        coordinates=:dimensionless_column_scaled_step,
        kkt_absolute_tolerance=linear_policy.kkt_absolute_tolerance,
        original_bounded_linear_step=(status=String(native.status),converged=native.converged,
            elapsed_seconds=native_seconds,step_finite=native_finite,
            step=native_finite ? Tuple(native_step) : nothing,
            step_hash=native_finite ? string(S.canonical_hash(Tuple(native_step))) : nothing,
            step_norm=native_finite ? norm(native_step) : nothing,
            predicted_scaled_residual_l2=native_model===nothing ? nothing : norm(native_model),
            active_bounds=Tuple(Int(i) for i in native.active_indices),
            endpoint_min_pressure_Pa=native_endpoint_pressure===nothing ? nothing : minimum(native_endpoint_pressure),
            kkt=native_audit===nothing ? nothing :
                (passed=native_audit.passed,free_stationarity=native_audit.free_stationarity,
                 lower_dual_violation=native_audit.lower_dual_violation,
                 scaled_complementarity=native_audit.scaled_complementarity,
                 primal_feasible=native_audit.primal_feasible)),
        inhouse=(status=String(inhouse.status),reason=inhouse.reason===nothing ? nothing : String(inhouse.reason),
            detail=inhouse.detail,kkt_order=kkt_order,
            rank_estimate=rank_snapshot===nothing ? nothing : rank_snapshot.rank_estimate,
            rank_columns=rank_snapshot===nothing ? nothing : rank_snapshot.columns,
            elapsed_seconds=inhouse_seconds,known_rank_capability_gap=known_rank_gap,
            step_finite=inhouse_finite,step=inhouse_finite ? Tuple(inhouse_step) : nothing,
            step_hash=inhouse_finite ? string(S.canonical_hash(Tuple(inhouse_step))) : nothing,
            step_norm=inhouse_finite ? norm(inhouse_step) : nothing,
            predicted_scaled_residual_l2=inhouse_model===nothing ? nothing : norm(inhouse_model),
            active_bounds=Tuple(Int(i) for i in inhouse.active_bounds),
            endpoint_min_pressure_Pa=endpoint_pressure===nothing ? nothing : minimum(endpoint_pressure),
            endpoint_min_scaled_pressure=endpoint_pressure===nothing ? nothing :
                minimum(endpoint_pressure./columns[4:4:end]),
            own_kkt=inhouse_finite ?
                (relative_defect=inhouse.kkt_relative_defect,stationarity=inhouse.stationarity,
                 dual_violation=inhouse.dual_violation,complementarity=inhouse.complementarity) : nothing,
            independent_kkt_audit=inhouse_audit===nothing ? nothing :
                (passed=inhouse_audit.passed,free_stationarity=inhouse_audit.free_stationarity,
                 lower_dual_violation=inhouse_audit.lower_dual_violation,
                 scaled_complementarity=inhouse_audit.scaled_complementarity,
                 primal_feasible=inhouse_audit.primal_feasible),
            rank_snapshots=rank_snapshots,
            fallback_reason=fallback_snapshot===nothing ? nothing : String(fallback_snapshot.fallback_reason),
            fallback_order=fallback_snapshot===nothing ? nothing : fallback_snapshot.fallback_order),
        comparison=(same_partition_objective=true,
            inhouse_predicted_l2_no_worse_than_native=inhouse_model===nothing || native_model===nothing ? nothing :
                norm(inhouse_model)<=norm(native_model)+1.0e-8*max(1.0,norm(native_model))))
end

function _assert_q1_4_inhouse_probe_v1(probe_ref::Ref{NamedTuple})
    probe=probe_ref[]
    @testset "Q1_4 current-assembly InHouse KKT probe" begin
        @test (probe.assembly.rows,probe.assembly.columns)==(337,272)
        @test probe.assembly.residual_finite && probe.assembly.jacobian_finite
        @test probe.assembly.native_partition_residual_max_delta==0.0
        @test probe.assembly.native_partition_jacobian_max_delta==0.0
        @test probe.assembly.independent_oracle_scaled_residual_delta<=5.0e-10
        @test (probe.finite_difference.rows,probe.finite_difference.columns)==(337,272)
        @test probe.finite_difference.all_finite
        @test probe.finite_difference.relative_infinity_error<=probe.finite_difference.threshold
        @test probe.partition.rows==337 && probe.partition.columns==272
        @test probe.partition.equality_rows==0 && probe.partition.equality_jacobian_size==(0,272)
        @test probe.partition.equality_max_abs==0.0
        @test probe.original_bounded_linear_step.converged
        @test probe.original_bounded_linear_step.step_finite
        @test probe.original_bounded_linear_step.kkt.passed
        @test probe.original_bounded_linear_step.kkt.primal_feasible
        @test probe.original_bounded_linear_step.kkt.free_stationarity<=probe.kkt_absolute_tolerance
        @test probe.original_bounded_linear_step.kkt.lower_dual_violation<=probe.kkt_absolute_tolerance
        @test abs(probe.original_bounded_linear_step.kkt.scaled_complementarity)<=probe.kkt_absolute_tolerance
        if probe.inhouse.status=="ok"
            rank_snapshot=last(probe.inhouse.rank_snapshots)
            if rank_snapshot.method===:bound_only_sparse_minimum_norm_qr
                @test probe.partition.equality_rows==0
                saved=probe.inhouse_kkt_input; encoded=saved.jacobian_csc
                design=SparseMatrixCSC(Int(encoded.rows),Int(encoded.columns),
                    Int.(collect(encoded.colptr)),Int.(collect(encoded.rowval)),
                    Float64.(collect(encoded.nzval)))
                active=collect(probe.inhouse.active_bounds)
                free=setdiff(collect(1:encoded.columns),active)
                # Independent rank of this actual final active-set design;
                # dense SVD is bounded to the existing 337x272 diagnostic.
                threshold=rank_snapshot.relative_threshold
                @test isfinite(threshold) && threshold>0
                design_rank=isempty(free) ? 0 :
                    count(>(threshold),svdvals(Matrix(design[:,free])))
                @test rank_snapshot.free_rank==design_rank
                @test rank_snapshot.free_columns==length(free)
                @test 0<=design_rank<=length(free)
                @test rank_snapshot.constraint_rank==rank_snapshot.constraint_rows==length(active)
                @test probe.inhouse.rank_estimate==encoded.rows+2length(active)+design_rank
                @test probe.inhouse.rank_columns==encoded.rows+encoded.columns+length(active)
            else
                @test probe.inhouse.rank_estimate==probe.inhouse.rank_columns
            end
            @test probe.inhouse.step_finite
            @test probe.inhouse.independent_kkt_audit.passed
            @test probe.inhouse.independent_kkt_audit.primal_feasible
            @test probe.inhouse.independent_kkt_audit.free_stationarity<=probe.kkt_absolute_tolerance
            @test probe.inhouse.independent_kkt_audit.lower_dual_violation<=probe.kkt_absolute_tolerance
            @test abs(probe.inhouse.independent_kkt_audit.scaled_complementarity)<=probe.kkt_absolute_tolerance
            @test probe.inhouse.endpoint_min_scaled_pressure>=-probe.kkt_absolute_tolerance
            @test probe.inhouse.own_kkt.relative_defect<=probe.kkt_absolute_tolerance
            @test probe.inhouse.own_kkt.stationarity<=probe.kkt_absolute_tolerance
            @test probe.inhouse.own_kkt.dual_violation<=probe.kkt_absolute_tolerance
            @test probe.inhouse.own_kkt.complementarity<=probe.kkt_absolute_tolerance
            @test probe.comparison.inhouse_predicted_l2_no_worse_than_native
        else
            @test probe.inhouse.known_rank_capability_gap
            @test probe.inhouse.reason=="rank_verification_capability_gap"
            @test probe.inhouse.fallback_reason=="kkt_order_over_fallback_limit"
            @test probe.inhouse.fallback_order>128
            @test probe.inhouse.kkt_order>128
            @test probe.inhouse.rank_estimate<probe.inhouse.rank_columns
            @test !probe.inhouse.step_finite
        end
    end
    probe
end

function _q1_4_inhouse_result_identity_hash_v1(input,declaration,context,receipt,initial,solved)
    canonical_hash((schema="q1-4-inhouse-stable-result-v1",
        candidate_hash=string(context.candidate_hash),context_hash=string(context.context_hash),
        input_hash=string(canonical_hash(input)),declaration_hash=string(canonical_hash(declaration)),
        geometry_receipt_hash=string(canonical_hash(receipt)),
        initial_state_hash=string(canonical_hash(Tuple(initial))),
        final_state=Tuple(solved.final_state),solver=(exit_code=solved.solver_exit_code,
            status=solved.status,numerical_status=solved.numerical_status,
            stopping_reason=solved.stopping_reason,residual_partition=solved.residual_partition,
            accepted_update_count=solved.accepted_update_count,attempt_count=solved.attempt_count,
            final_scaled_residual_max=solved.final_scaled_residual_max,
            numerical_policy=solved.numerical_policy,rank_diagnostics=solved.rank_diagnostics,
            physical_checks=solved.physical_checks,operator_binding=solved.operator_binding,
            step_identity_hash=solved.step_identity_hash,formal_policy=solved.formal_policy,
            spatial_closures=solved.spatial_closures,claim_ceiling=solved.claim_ceiling),
        final_assembly=S._smgw_serializable_assembly_v1(solved.final_assembly)))
end

function consumer_q1_level_main(out,consumer_output_dir,phase::Symbol,level::Symbol;
        continuation_q1_4_root=nothing,failed_state_origin=nothing,inhouse_result_path=nothing,
        interior_map::Symbol=:circular_v1)
    spec=_q1_real_consumer_spec(level)
    interior_map===:circular_v1 || level===:q1_4 ||
        throw(ArgumentError("nondefault manufactured maps are admitted only by the Q1_4 consumer"))
    point_diagnostic=phase in (:diagnostic_failed_state_fd,:diagnostic_failed_state_ray)
    (phase===:validate || (point_diagnostic && level===:q1_8 &&
        continuation_q1_4_root!==nothing) ||
        (phase in (:inhouse_kkt_probe,:inhouse_full_nonlinear_solve,:inhouse_final_replay) && level===:q1_4)) ||
        error("$level consumer supports only validate, its existing Q1_8 saved-point diagnostics, or the Q1_4 InHouse phases")
    (phase===:inhouse_final_replay)==(inhouse_result_path!==nothing) &&
        (inhouse_result_path===nothing || level===:q1_4) ||
        throw(ArgumentError("Q1_4 InHouse final replay requires --inhouse-result and is its only supported consumer"))
    continuation_q1_4_root===nothing || level===:q1_8 ||
        throw(ArgumentError("Q1_4 continuation can initialize only the Q1_8 consumer"))
    point_diagnostic && failed_state_origin===nothing &&
        throw(ArgumentError("failed-state diagnostic requires --failed-state-origin"))
    !point_diagnostic && failed_state_origin!==nothing &&
        throw(ArgumentError("--failed-state-origin is supported only by the Q1_8 failed-state diagnostic"))
    production_dir=joinpath(out,"production")
    isdir(production_dir) || error("$level producer artifact directory is absent")
    consumer_dir=abspath(consumer_output_dir)
    real_out=realpath(out)
    inhouse_result_file=inhouse_result_path===nothing ? nothing :
        S._smgw_confined_file_v1(real_out,abspath(String(inhouse_result_path)),"Q1_4 InHouse saved result")
    realpath(dirname(consumer_dir))==real_out || error("$level consumer output must be a direct child of its producer root")
    expected_consumer=normpath(joinpath(real_out,basename(consumer_dir)))
    lowercase(normpath(consumer_dir))==lowercase(expected_consumer) ||
        error("$level consumer output path escaped its producer root")
    ispath(consumer_dir) && error("preserve existing $level consumer evidence directory")
    println("SMGW_CONSUMER_START level=",level," julia=",VERSION," pid=",getpid()," threads=",Threads.nthreads());flush(stdout)
    input=S.spatial_n1_manufactured_input_v1(;level,interior_map)
    declaration=S.spatial_n1_manufactured_declaration_v1(input)
    input.revision==spec.revision && input.mesh.level==level &&
        input.mesh.unknowns==spec.unknowns && input.mesh.rows==spec.ownership_rows ||
        error("$level consumer input semantic identity or mesh inventory mismatch")
    input_hash=string(canonical_hash(input));declaration_hash=string(canonical_hash(declaration))
    semantic_ids=expected_semantic_identities()
    continuation_source=continuation_q1_4_root===nothing ? nothing :
        _q1_4_continuation_source_v1(continuation_q1_4_root)
    context,parent_context=assert_candidate_chain(input,declaration;
        parent_context=continuation_source===nothing ? nothing : continuation_source.parent_context)
    context.candidate_hash!=parent_context.candidate_hash &&
        canonical_hash(input)!=canonical_hash(S.spatial_n1_manufactured_input_v1()) ||
        error("$level fresh candidate reused parent or default Q1_2 input identity")
    continuation_source===nothing || point_diagnostic ||
        test_q1_4_continuation_rejects_wrong_candidate_v1(continuation_source,context)
    handoff_path=joinpath(out,"producer_handoff.json")
    if !point_diagnostic
        isfile(handoff_path) || error("$level producer handoff is absent")
        handoff_wire=read(handoff_path,String);S._smr_read_canonical_json_v1(handoff_wire)
        handoff=JSON3.read(handoff_wire)
        handoff["schema"]=="spatial-global-weak-$(level)-two-process-handoff-v1" &&
            handoff["level"]==String(level) && wire_digest(handoff["candidate_hash"])==string(context.candidate_hash) &&
            wire_digest(handoff["context_hash"])==string(context.context_hash) &&
            wire_digest(handoff["declaration_hash"])==declaration_hash &&
            wire_digest(handoff["input_hash"])==input_hash &&
            semantic_identities_match(handoff["semantic_identities"]) ||
            error("$level producer handoff source/candidate binding mismatch")
    end
    artifact_binding = nothing
    primary = nothing
    failed_state_origin_evidence=nothing
    println(point_diagnostic ? "SMGW_PHASE_BEGIN=q1_8_supplied_saved_point_identity" :
        "SMGW_PHASE_BEGIN=$(level)_fresh_production_artifact_replay");flush(stdout)
    replay_admission=S._smgw_admission_record_v1(context,declaration)
    if point_diagnostic
        primary_path=joinpath(production_dir,"global_weak_primary.json")
        primary_wire=S._smgw_validator_timed_v1(:q1_8_primary_file_read, () -> read(primary_path,String))
        primary_sha256=S._smgw_validator_timed_v1(:q1_8_primary_file_sha256,
            () -> S._smgw_sha256_file_v1(primary_path))
        primary=S._smgw_validator_timed_v1(:q1_8_primary_json3_parse, () -> JSON3.read(primary_wire))
        S._smgw_validator_timed_v1(:q1_8_primary_identity_verify, () ->
            verify_primary_identity(primary,input,declaration,context,production_dir;point_only=true))
        realpath(String(primary["run_dir"]))==realpath(production_dir) ||
            error("$level failed-state primary run directory differs from its producer root")
        failed_state_origin_evidence=_q1_8_failed_state_origin_v1(failed_state_origin,out,continuation_q1_4_root)
        wire_digest(primary["geometry_receipt"]["provider_source"]["sha256"])==
            failed_state_origin_evidence.provider_source_sha256 ||
            error("$level historical provider source pin differs from its failed-state invocation")
        solver=primary["solver"]
        Int(primary["solver_exit_code"])==4 && primary["status"]=="fail" &&
            primary["numerical_status"]=="numerical_fail" && primary["stopping_reason"]=="wall_time_budget" &&
            Int(primary["accepted_update_count"])==10 && Int(solver["solver_exit_code"])==4 &&
            solver["status"]=="fail" && solver["numerical_status"]=="numerical_fail" &&
            solver["stopping_reason"]=="wall_time_budget" && Int(solver["accepted_update_count"])==10 ||
            error("$level supplied saved point does not report the original wall-budget numerical failure")
        artifact_binding=(primary_sha256=primary_sha256,result_hash=wire_digest(primary["result_hash"]),
            artifact_set_hash=nothing,geometry_artifact_set_hash=nothing,primary_projection=primary)
        final_state=Float64.(collect(solver["final_state"]))
        replay=(validation=:supplied_saved_point_verified,candidate_hash=string(context.candidate_hash),
            context_hash=string(context.context_hash),input_hash=input_hash,
            result_hash=wire_digest(primary["result_hash"]),state_hash=string(canonical_hash(Tuple(final_state))),
            solver_exit_code=4,status=:fail,numerical_status=:numerical_fail,
            stopping_reason=:wall_time_budget,accepted_update_count=10,
            final_scaled_residual_max=Float64(primary["final_scaled_residual_max"]),final_state=Tuple(final_state))
    else
        replay=if continuation_source===nothing
        S.validate_spatial_manufactured_global_weak_artifacts_v1(context,production_dir;
            expected_candidate_hash=string(context.candidate_hash),
            expected_context_hash=string(context.context_hash),expected_input_hash=input_hash,
            expected_semantic_identities=semantic_ids,_consumer_admission=replay_admission,
            _consumer_projection=true,
            _expected_result_hash=point_diagnostic ? nothing : wire_digest(handoff["result_hash"]))
        else
            S.validate_spatial_manufactured_global_weak_artifacts_v1(context,production_dir;
            expected_candidate_hash=string(context.candidate_hash),
            expected_context_hash=string(context.context_hash),expected_input_hash=input_hash,
            expected_semantic_identities=semantic_ids,_consumer_admission=replay_admission,
            continuation_source_context=continuation_source.context,
            continuation_source_dir=continuation_source.production_dir,
            _consumer_projection=true,
                _expected_result_hash=wire_digest(handoff["result_hash"]))
        end
        artifact_binding=replay.consumer_artifact_binding
        primary=artifact_binding.primary_projection
    end
    primary=artifact_binding.primary_projection
    if !point_diagnostic
        artifact_binding.result_hash==wire_digest(handoff["result_hash"]) ||
            error("$level producer result hash differs from bound primary artifact")
    end
    wire_digest(primary.binding.candidate_hash)==string(context.candidate_hash) &&
        wire_digest(primary.binding.context_hash)==string(context.context_hash) &&
        wire_digest(primary.input_hash)==input_hash ||
        error("$level primary candidate/context/input binding mismatch")
    replay.validation==(point_diagnostic ? :supplied_saved_point_verified : :artifact_replay_completed) &&
        replay.candidate_hash==string(context.candidate_hash) &&
        replay.context_hash==string(context.context_hash) && replay.input_hash==input_hash &&
        replay.result_hash==artifact_binding.result_hash ||
        error("$level production artifact replay/point identity mismatch")
    if point_diagnostic
        println("SMGW_PHASE_END=$(level)_supplied_saved_point_verified primary_sha256=",artifact_binding.primary_sha256);flush(stdout)
    else
        println("SMGW_PHASE_END=$(level)_fresh_production_artifact_replay result=",replay.result_hash);flush(stdout)
    end

    receipt=S._smgw_geometry_receipt_from_wire_v1(
        S._smr_json_native_v1(primary.geometry_receipt),input)
    raw=raw_geometry_artifacts(primary)
    receipt.raw_artifacts==raw || error("$level geometry receipt/raw artifact binding mismatch")
    data=S.load_spatial_data_v4(declaration,(level=input.mesh.level,nfp=input.mesh.nfp,
        flux_Wb=input.flux.nominal_Wb,raw_artifacts=raw))
    geometry_initial_state=Tuple(data.initial_state)
    grid=O.grid(collect(input.mesh.rho),input.mesh.theta_count,input.mesh.zeta_per_period*input.mesh.nfp)
    length(grid.node_order)==spec.nodes && size(data.mesh.nodes_q,2)==spec.nodes &&
        input.mesh.unknowns==4*length(grid.node_order) &&
        length(data.mesh.row_blocks)==spec.ownership_rows &&
        Tuple(Tuple(data.mesh.nodes_q[:,node]) for node in axes(data.mesh.nodes_q,2))==Tuple(grid.node_order) &&
        Tuple(Tuple(ids) for ids in data.mesh.cell_nodes)==Tuple(Tuple(ids) for ids in grid.element_nodes) ||
        error("$level production mesh differs from its explicit independent oracle grid/ownership contract")
    state=read_state_csv(joinpath(production_dir,"solver_state.csv"),length(grid.node_order))
    state==Float64.(collect(primary.solver.final_state)) ||
        error("$level CSV state differs from serialized solved state")
    if phase===:inhouse_full_nonlinear_solve
        # The artifact replay above already checked its serialized initial state against this loader state.
        source_initial=Float64.(collect(geometry_initial_state))
        admission=S._smgw_admission_record_v1(context,declaration)
        solved=S.solve_spatial_global_weak_state_v1(declaration,data,source_initial;
            flux_Wb=input.flux.nominal_Wb,admission,geometry_receipt=receipt,
            residual_partition=:inhouse_kkt)
        solved.residual_partition===:inhouse_kkt ||
            error("Q1_4 full solve did not use the InHouse residual partition")
        result=(schema="q1-4-inhouse-full-nonlinear-consumer-v1",level=:q1_4,
            diagnostic_only=false,physical_validation=solved.physical_validation,
            authority=solved.authority,formal_policy=solved.formal_policy,
            spatial_closures=solved.spatial_closures,claim_ceiling=solved.claim_ceiling,
            candidate_hash=string(context.candidate_hash),context_hash=string(context.context_hash),
            input_hash=string(canonical_hash(input)),declaration_hash=string(canonical_hash(declaration)),
            source_result_hash=artifact_binding.result_hash,
            geometry_receipt_hash=string(canonical_hash(receipt)),
            initial_state_hash=string(canonical_hash(Tuple(source_initial))),
            final_state_hash=string(canonical_hash(solved.final_state)),
            stable_result_hash=string(_q1_4_inhouse_result_identity_hash_v1(
                input,declaration,context,receipt,source_initial,solved)),
            initial_state=Tuple(source_initial),final_state=solved.final_state,
            solver=(exit_code=solved.solver_exit_code,status=String(solved.status),
                numerical_status=String(solved.numerical_status),stopping_reason=String(solved.stopping_reason),
                residual_partition=String(solved.residual_partition),
                accepted_update_count=solved.accepted_update_count,attempt_count=solved.attempt_count,
                final_scaled_residual_max=solved.final_scaled_residual_max,
                elapsed_seconds=solved.elapsed_seconds,numerical_policy=solved.numerical_policy,
                rank_diagnostics=solved.rank_diagnostics,physical_checks=solved.physical_checks,
                operator_binding=solved.operator_binding,step_identity=solved.step_identity,
                step_identity_hash=solved.step_identity_hash,
                iterations=solved.iterations,attempts=solved.attempts),
            final_assembly=S._smgw_serializable_assembly_v1(solved.final_assembly))
        mkdir(consumer_dir)
        islink(consumer_dir) || lowercase(normpath(realpath(consumer_dir)))==lowercase(expected_consumer) ||
            error("Q1_4 InHouse full solve output escaped its producer root")
        report_path=joinpath(consumer_dir,"q1_4_inhouse_full_nonlinear.json")
        write(report_path,canonical_json(result)*"\n")
        report=(solver=solved,final_assembly=solved.final_assembly,
            binding=(candidate_hash=context.candidate_hash,context_hash=context.context_hash,
                context_candidate_hash=context.candidate_hash),
            declaration_hash=canonical_hash(declaration),input_hash=canonical_hash(input),
            solver_exit_code=solved.solver_exit_code,stopping_reason=solved.stopping_reason,
            status=solved.status,numerical_status=solved.numerical_status,
            accepted_update_count=solved.accepted_update_count,
            final_scaled_residual_max=solved.final_scaled_residual_max,
            physical_validation=solved.physical_validation,authority=solved.authority,
            formal_policy=solved.formal_policy,spatial_closures=solved.spatial_closures)
        _assert_q1_level_solver_result(:q1_4,input,declaration,context,report)
        println("SMGW_Q1_4_INHOUSE_FULL_NONLINEAR status=",solved.status,
            " exit=",solved.solver_exit_code," updates=",solved.accepted_update_count,
            " residual=",solved.final_scaled_residual_max," report=",report_path);flush(stdout)
        return nothing
    end
    if phase===:inhouse_final_replay
        saved=JSON3.read(read(inhouse_result_file,String))
        String(saved["schema"])=="q1-4-inhouse-full-nonlinear-consumer-v1" &&
            String(saved["level"])=="q1_4" || error("saved Q1_4 InHouse result schema/level mismatch")
        String(saved["candidate_hash"])==string(context.candidate_hash) &&
            String(saved["context_hash"])==string(context.context_hash) &&
            String(saved["input_hash"])==input_hash &&
            String(saved["declaration_hash"])==declaration_hash &&
            String(saved["source_result_hash"])==artifact_binding.result_hash &&
            String(saved["geometry_receipt_hash"])==string(canonical_hash(receipt)) ||
            error("saved Q1_4 InHouse result source/geometry binding mismatch")
        initial=Float64.(collect(saved["initial_state"]))
        final_state=Float64.(collect(saved["final_state"]))
        length(initial)==spec.unknowns && Tuple(initial)==geometry_initial_state &&
            String(saved["initial_state_hash"])==string(canonical_hash(Tuple(initial))) ||
            error("saved Q1_4 InHouse initial state differs from its source geometry")
        length(final_state)==spec.unknowns && all(isfinite,final_state) &&
            String(saved["final_state_hash"])==string(canonical_hash(Tuple(final_state))) ||
            error("saved Q1_4 InHouse final state hash/shape/finite check failed")
        saved_solver=saved["solver"]
        String(saved_solver["residual_partition"])=="inhouse_kkt" &&
            Int(saved_solver["exit_code"])==0 && String(saved_solver["status"])=="converged" &&
            String(saved_solver["numerical_status"])=="full_discrete_residual_converged" &&
            Int(saved_solver["accepted_update_count"])<=12 &&
            Float64(saved_solver["elapsed_seconds"])<=spec.seconds &&
            Float64(saved_solver["final_scaled_residual_max"])<=1.0e-6 ||
            error("saved Q1_4 InHouse result did not pass the unchanged solver gates")
        saved_policy=saved_solver["numerical_policy"]
        Int(saved_policy["max_iterations"])==12 && Float64(saved_policy["seconds"])==spec.seconds &&
            Float64(saved_policy["residual_tolerance"])==1.0e-6 &&
            Float64(saved_policy["pressure_lower_Pa"])==0.0 ||
            error("saved Q1_4 InHouse numerical policy differs from the frozen input")
        actual=S.assemble_spatial_global_weak_system_v1(declaration,data,final_state;
            flux_Wb=input.flux.nominal_Wb,jacobian=true,residual_partition=:inhouse_kkt)
        oracle=O.assemble(input,grid,final_state;order=3,scaling=declaration.scaling)
        oracle_delta=length(actual.residual)==length(oracle.residual)==length(actual.row_scales) ?
            maximum(abs.(actual.residual.-oracle.residual)./actual.row_scales;init=0.0) : nothing
        serialized_actual=S._smgw_serializable_assembly_v1(actual)
        columns=repeat(Float64[declaration.scaling.B_T,declaration.scaling.B_T,
            declaration.scaling.B_T,declaration.scaling.p_Pa],div(length(final_state),4))
        fd=O.finite_difference_jacobian(input,grid,final_state;order=3,column_scales=columns)
        actual_scaled=spdiagm(0=>1.0./actual.row_scales)*actual.jacobian*spdiagm(0=>columns)
        fd_scaled=Diagonal(1.0./oracle.row_scales)*fd*Diagonal(columns)
        actual_dense=Matrix(actual_scaled);fd_dense=Matrix(fd_scaled)
        fd_relative=norm(actual_dense-fd_dense,Inf)/max(norm(actual_dense,Inf),eps(Float64))
        fd_finite=size(fd)==(spec.global_rows,spec.unknowns) && all(isfinite,fd) &&
            all(isfinite,actual_dense) && all(isfinite,fd_dense) && isfinite(fd_relative)
        final_residual_max=maximum(abs.(actual.residual./actual.row_scales);init=0.0)
        pressure_min=minimum(final_state[4:4:end])
        pressure_tolerance=8eps(Float64)*max(1.0,abs(pressure_min/declaration.scaling.p_Pa))*
            declaration.scaling.p_Pa
        actual_jacobian_rows,actual_jacobian_columns,actual_jacobian_values=findnz(actual.jacobian)
        pre_assert=Dict{String,Any}(
            "candidate_hash"=>string(context.candidate_hash),
            "context_hash"=>string(context.context_hash),
            "source_result_hash"=>String(saved["stable_result_hash"]),
            "final_state_hash"=>String(saved["final_state_hash"]),
            "final_state"=>collect(final_state),
            "actual"=>Dict{String,Any}(
                "rows"=>size(actual.jacobian,1),"columns"=>size(actual.jacobian,2),
                "residual"=>collect(actual.residual),"row_scales"=>collect(actual.row_scales),
                "jacobian"=>Dict{String,Any}(
                    "row_indices"=>actual_jacobian_rows,
                    "column_indices"=>actual_jacobian_columns,
                    "values"=>actual_jacobian_values)),
            "oracle"=>Dict{String,Any}(
                "residual_rows"=>length(oracle.residual),"state_columns"=>length(final_state),
                "row_scale_rows"=>length(oracle.row_scales),
                "row_support_rows"=>length(oracle.row_supports),
                "residual"=>collect(oracle.residual),"row_scales"=>collect(oracle.row_scales),
                "row_blocks"=>String.(collect(oracle.row_blocks))),
            "fd"=>fd,"fd_relative"=>fd_relative,
            "actual_scaled"=>actual_dense,"fd_scaled"=>fd_dense,"oracle_delta"=>oracle_delta,
            "fd_finite"=>fd_finite,"final_residual_max"=>final_residual_max,
            "pressure_min_Pa"=>pressure_min)
        println("SMGW_Q1_4_INHOUSE_FINAL_REPLAY_PRE_ASSERT=",repr(pre_assert));flush(stdout)
        saved_wire=S._smr_read_canonical_json_v1(read(inhouse_result_file,String))
        assembly_matches_saved_json3=S._smgw_json_equal_v1(saved["final_assembly"],serialized_actual)
        assembly_matches_saved=S._smgw_json_equal_v1(saved_wire.final_assembly,serialized_actual)
        println("SMGW_Q1_4_INHOUSE_SAVED_ASSEMBLY_COMPARE json3=",assembly_matches_saved_json3,
            " canonical_wire=",assembly_matches_saved);flush(stdout)
        _assert_q1_globalweak_rowspace(:q1_4,actual,spec,"inhouse_final_replay_actual")
        _assert_q1_globalweak_rowspace(:q1_4,oracle,spec,"inhouse_final_replay_oracle")
        _assert_q1_level_oracle_assembly(:q1_4,actual,oracle,"inhouse_final_replay_saved_final_state")
        admission=S._smgw_admission_record_v1(context,declaration)
        replay_started=time_ns()
        replay_solved=S.solve_spatial_global_weak_state_v1(declaration,data,initial;
            flux_Wb=input.flux.nominal_Wb,admission,geometry_receipt=receipt,
            residual_partition=:inhouse_kkt)
        replay_seconds=(time_ns()-replay_started)/1.0e9
        replay_hash=string(_q1_4_inhouse_result_identity_hash_v1(
            input,declaration,context,receipt,initial,replay_solved))
        result_hash_matches=replay_hash==String(saved["stable_result_hash"])
        state_matches=Tuple(replay_solved.final_state)==Tuple(final_state)
        replay_report=(solver=replay_solved,final_assembly=replay_solved.final_assembly,
            binding=(candidate_hash=context.candidate_hash,context_hash=context.context_hash,
                context_candidate_hash=context.candidate_hash),
            declaration_hash=canonical_hash(declaration),input_hash=canonical_hash(input),
            solver_exit_code=replay_solved.solver_exit_code,stopping_reason=replay_solved.stopping_reason,
            status=replay_solved.status,numerical_status=replay_solved.numerical_status,
            accepted_update_count=replay_solved.accepted_update_count,
            final_scaled_residual_max=replay_solved.final_scaled_residual_max,
            physical_validation=replay_solved.physical_validation,authority=replay_solved.authority,
            formal_policy=replay_solved.formal_policy,spatial_closures=replay_solved.spatial_closures)
        replay_result=(schema="q1-4-inhouse-final-independent-replay-v1",level=:q1_4,
            source_result_path=String(inhouse_result_file),source_result_hash=String(saved["stable_result_hash"]),
            candidate_hash=string(context.candidate_hash),context_hash=string(context.context_hash),
            input_hash=input_hash,declaration_hash=declaration_hash,
            geometry_receipt_hash=string(canonical_hash(receipt)),
            saved_final_state_hash=String(saved["final_state_hash"]),
            oracle=(residual_rows=length(oracle.residual),state_columns=length(final_state),
                row_scale_rows=length(oracle.row_scales),row_support_rows=length(oracle.row_supports),
                scaled_residual_delta=oracle_delta),
            finite_difference=(method=:independent_centered_fd_all_columns,rows=size(fd,1),
                columns=size(fd,2),threshold=5.0e-6,relative_infinity_error=fd_relative,all_finite=fd_finite),
            saved_assembly_matches_reassembly=assembly_matches_saved,
            final_residual_max=final_residual_max,pressure_min_Pa=pressure_min,
            second_process=(stable_result_hash=replay_hash,stable_result_matches_saved=result_hash_matches,
                final_state_hash=string(canonical_hash(replay_solved.final_state)),state_matches_saved=state_matches,
                solver_status=String(replay_solved.status),solver_exit_code=replay_solved.solver_exit_code,
                accepted_update_count=replay_solved.accepted_update_count,
                final_scaled_residual_max=replay_solved.final_scaled_residual_max),
            timings=(first_solve_seconds=Float64(saved_solver["elapsed_seconds"]),
                second_solve_seconds=replay_solved.elapsed_seconds,second_solve_wall_seconds=replay_seconds,
                identity_hash_excludes_timing=true),
            physical_validation=replay_solved.physical_validation,authority=replay_solved.authority,
            formal_policy=replay_solved.formal_policy,spatial_closures=replay_solved.spatial_closures,
            claim_ceiling=replay_solved.claim_ceiling)
        mkdir(consumer_dir)
        islink(consumer_dir) || lowercase(normpath(realpath(consumer_dir)))==lowercase(expected_consumer) ||
            error("Q1_4 InHouse replay output escaped its producer root")
        replay_path=joinpath(consumer_dir,"q1_4_inhouse_final_replay.json")
        write(replay_path,canonical_json(replay_result)*"\n")
        _assert_q1_level_solver_result(:q1_4,input,declaration,context,replay_report)
        oracle_delta<=5.0e-10 && assembly_matches_saved && fd_finite && fd_relative<=5.0e-6 &&
            final_residual_max<=1.0e-6 && pressure_min>=-pressure_tolerance &&
            result_hash_matches && state_matches ||
            error("Q1_4 saved final-state oracle/FD/second-process replay gate failed")
        println("SMGW_Q1_4_INHOUSE_FINAL_REPLAY oracle_delta=",oracle_delta,
            " fd_relative=",fd_relative," second_process_result_match=",result_hash_matches,
            " second_process_state_match=",state_matches," report=",replay_path);flush(stdout)
        return nothing
    end
    if phase===:inhouse_kkt_probe
        probe=_q1_4_inhouse_step_probe_v1(input,declaration,context,data,receipt,state,grid,spec)
        mkdir(consumer_dir)
        islink(consumer_dir) || lowercase(normpath(realpath(consumer_dir)))==lowercase(expected_consumer) ||
            error("Q1_4 InHouse KKT probe output escaped its producer root")
        probe_path=joinpath(consumer_dir,"q1_4_inhouse_kkt_probe.json")
        write(probe_path,canonical_json(probe)*"\n")
        println("SMGW_Q1_4_INHOUSE_KKT_PROBE status=",probe.inhouse.status,
            " reason=",probe.inhouse.reason," rows=",probe.assembly.rows,
            " columns=",probe.assembly.columns," fd_relative=",probe.finite_difference.relative_infinity_error,
            " report=",probe_path);flush(stdout)
        _assert_q1_4_inhouse_probe_v1(Ref{NamedTuple}(probe))
        return nothing
    end
    if point_diagnostic
        replay.validation===:supplied_saved_point_verified && replay.solver_exit_code==4 &&
            replay.status===:fail && replay.numerical_status===:numerical_fail ||
            error("failed-state point diagnostic requires the supplied saved point to report the original numerical-failure status")
        if phase===:diagnostic_failed_state_fd
        manufactured_nodal_state=Float64[]
        for node in data.nodes
            append!(manufactured_nodal_state,node.B_reference_cyl)
            push!(manufactured_nodal_state,node.p_reference)
        end
        length(manufactured_nodal_state)==spec.unknowns && all(isfinite,manufactured_nodal_state) ||
            error("manufactured nodal reference state is invalid for the admitted Q1_8 geometry")
        manufactured_reference_assembly=S.assemble_spatial_global_weak_system_v1(
            declaration,data,manufactured_nodal_state;
            flux_Wb=input.flux.nominal_Wb,jacobian=false,residual_partition=:spatial_native)
        manufactured_reference_scaled=manufactured_reference_assembly.residual ./
            manufactured_reference_assembly.row_scales
        manufactured_reference_blocks=Tuple(begin
            rows=findall(==(block),manufactured_reference_assembly.row_blocks)
            values=manufactured_reference_scaled[rows]
            (block=String(block),row_count=length(rows),scaled_l2=norm(values),
                scaled_maximum=maximum(abs,values;init=0.0))
        end for block in unique(manufactured_reference_assembly.row_blocks))
        manufactured_nodal_reference=(
            state_semantics=:analytic_manufactured_field_sampled_at_q1_nodes,
            dof_order="BR_T,Bphi_T,BZ_T,p_Pa",diagnostic_only=true,
            reference_state_hash=string(canonical_hash(Tuple(manufactured_nodal_state))),
            minimum_pressure_Pa=minimum(manufactured_nodal_state[4:4:end]),
            scaled_residual_l2=norm(manufactured_reference_scaled),
            scaled_residual_maximum=maximum(abs,manufactured_reference_scaled),
            original_residual_tolerance=declaration.solver.residual_tolerance,
            below_original_residual_tolerance=maximum(abs,manufactured_reference_scaled)<=
                declaration.solver.residual_tolerance,
            residual_blocks=manufactured_reference_blocks,
            nonlinear_solve=:not_executed,formal_credit=false)
        println("SMGW_MANUFACTURED_NODAL_RESIDUAL=",JSON3.write(manufactured_nodal_reference));flush(stdout)
        end
        println(phase===:diagnostic_failed_state_fd ?
            "SMGW_PHASE_BEGIN=q1_8_saved_failed_state_full_fd" :
            "SMGW_PHASE_BEGIN=q1_8_saved_failed_state_ray");flush(stdout)
        final_actual=S.assemble_spatial_global_weak_system_v1(declaration,data,state;
            flux_Wb=input.flux.nominal_Wb,jacobian=true,residual_partition=:spatial_native)
        final_oracle=O.assemble(input,grid,state;order=3,scaling=declaration.scaling)
        _assert_q1_globalweak_rowspace(:q1_8,final_actual,spec,"saved_failed_state_actual")
        _assert_q1_globalweak_rowspace(:q1_8,final_oracle,spec,"saved_failed_state_oracle")
        final_oracle_delta=_assert_q1_level_oracle_assembly(:q1_8,final_actual,final_oracle,
            "saved_failed_state")
        verify_saved_artifacts(primary,production_dir,final_actual,state;point_only=true)
        columns=repeat(Float64[declaration.scaling.B_T,declaration.scaling.B_T,
            declaration.scaling.B_T,declaration.scaling.p_Pa],div(length(state),4))
        if phase===:diagnostic_failed_state_fd
        fd=O.finite_difference_jacobian(input,grid,state;order=3,column_scales=columns)
        actual_scaled=Diagonal(1.0./final_actual.row_scales)*Matrix(final_actual.jacobian)*Diagonal(columns)
        fd_scaled=Diagonal(1.0./final_oracle.row_scales)*fd*Diagonal(columns)
        fd_actual_norm_inf=norm(actual_scaled,Inf)
        fd_error_norm_inf=norm(actual_scaled-fd_scaled,Inf)
        fd_relative=fd_error_norm_inf/max(fd_actual_norm_inf,eps(Float64))
        fd_actual_finite=all(isfinite,actual_scaled)
        fd_scaled_finite=all(isfinite,fd_scaled)
        fd_matrix_finite=all(isfinite,fd)
        fd_jacobian_finite=all(isfinite,nonzeros(final_actual.jacobian))
        fd_all_finite=fd_actual_finite && fd_scaled_finite && fd_matrix_finite && fd_jacobian_finite
        println("Q1_8_FD_LOCALIZATION relative=",fd_relative," error_norm_inf=",fd_error_norm_inf,
            " actual_norm_inf=",fd_actual_norm_inf," rows=",size(fd,1)," columns=",size(fd,2),
            " jacobian_assembled=",final_actual.jacobian_assembled,
            " actual_scaled_finite=",fd_actual_finite," fd_scaled_finite=",fd_scaled_finite,
            " fd_finite=",fd_matrix_finite," jacobian_finite=",fd_jacobian_finite,
            " residual_finite=",all(isfinite,final_actual.residual),
            " row_scales_finite=",all(isfinite,final_actual.row_scales),
            " all_finite=",fd_all_finite);flush(stdout)
        if fd_all_finite && final_actual.jacobian_assembled && !isempty(actual_scaled)
            fd_diag_worst_error=-Inf
            fd_diag_worst_linear=first(eachindex(actual_scaled))
            for index in eachindex(actual_scaled)
                point_error=abs(actual_scaled[index]-fd_scaled[index])
                if point_error>fd_diag_worst_error
                    fd_diag_worst_error=point_error
                    fd_diag_worst_linear=index
                end
            end
            fd_diag_worst=CartesianIndices(actual_scaled)[fd_diag_worst_linear]
            fd_diag_row=fd_diag_worst[1]
            fd_diag_column=fd_diag_worst[2]
            fd_diag_field=("BR_T","Bphi_T","BZ_T","p_Pa")[mod1(fd_diag_column,4)]
            fd_diag_node=cld(fd_diag_column,4)
            println("Q1_8_FD_WORST_CELL row=",fd_diag_row," column=",fd_diag_column,
                " node=",fd_diag_node," dof=",fd_diag_field,
                " block=",final_actual.row_blocks[fd_diag_row],
                " actual_jacobian=",final_actual.jacobian[fd_diag_row,fd_diag_column],
                " oracle_fd=",fd[fd_diag_row,fd_diag_column],
                " actual_scaled=",actual_scaled[fd_diag_row,fd_diag_column],
                " fd_scaled=",fd_scaled[fd_diag_row,fd_diag_column],
                " scaled_abs_error=",fd_diag_worst_error,
                " fd_step_h=",sqrt(eps(Float64))*max(1.0,Float64(columns[fd_diag_column]),abs(state[fd_diag_column])));flush(stdout)
        end
        size(fd)==(spec.global_rows,spec.unknowns) ||
            error("Q1_8 failed-state centered FD did not cover all rows and columns")
        final_actual.jacobian_assembled && all(isfinite,actual_scaled) && all(isfinite,fd_scaled) &&
            isfinite(fd_relative) && fd_relative<=5.0e-6 ||
            error("Q1_8 saved failed-state full centered FD gate failed")
        else
            fd_relative=nothing
            println("Q1_8_FD_STATUS=not_executed phase=diagnostic_failed_state_ray reason=terminal_alpha_1_merit_worsened");flush(stdout)
        end
        println("SMGW_PHASE_BEGIN=q1_8_saved_failed_state_bounded_linearized_check");flush(stdout)
        linear_A=spdiagm(0=>1.0./final_actual.row_scales)*final_actual.jacobian*spdiagm(0=>columns)
        linear_r=final_actual.residual./final_actual.row_scales
        linear_lower=S._smgw_scaled_lower_bounds_v1(state,columns)
        linear_policy=S.SpatialBoundedLinearStepV1.bounded_linear_step_policy_v1()
        linear_step_result=S.SpatialBoundedLinearStepV1.solve_lower_bounded_step_v1(
            linear_A,linear_r,linear_lower;policy=linear_policy,seconds=120.0)
        linear_step_values=collect(linear_step_result.step)
        linear_step_finite=length(linear_step_values)==length(state) &&
            all(value->value isa Real && isfinite(value),linear_step_values)
        linear_direction=linear_step_finite ? Float64.(linear_step_values) : nothing
        linear_model=linear_direction===nothing ? nothing : linear_r+linear_A*linear_direction
        linear_rank_values=Int[h.rank_estimate for h in linear_step_result.history
            if hasproperty(h,:rank_estimate) && h.rank_estimate isa Integer]
        linear_blocks=linear_model===nothing ? nothing : Tuple(begin
            rows=findall(==(block),final_actual.row_blocks)
            values=linear_model[rows]
            (block=String(block),row_count=length(rows),scaled_l2=norm(values),
                scaled_maximum=maximum(abs,values;init=0.0))
        end for block in unique(final_actual.row_blocks))
        linearized_check=(schema="q1-8-failed-state-bounded-linearized-check-v1",
            diagnostic_only=true,interpretation=:current_state_linearized_diagnostic,
            rows=size(linear_A,1),columns=size(linear_A,2),
            scaled_residual_l2_before=norm(linear_r),
            scaled_residual_max_before=maximum(abs,linear_r),
            solver_status=String(linear_step_result.status),
            solver_converged=linear_step_result.converged,
            solver_elapsed_seconds=linear_step_result.elapsed_seconds,
            solver_seconds_budget=120.0,
            rank_estimate=isempty(linear_rank_values) ? nothing : last(linear_rank_values),
            rank_estimate_is_inner_diagnostic=true,
            active_count=length(linear_step_result.active_indices),
            free_count=length(linear_step_result.free_indices),
            active_pressure_dof_indices=Tuple(Int(i) for i in linear_step_result.active_indices if i%4==0),
            active_nonpressure_dof_indices=Tuple(Int(i) for i in linear_step_result.active_indices if i%4!=0),
            state_pressure_contact_dof_indices=Tuple(i for i in 4:4:length(state) if state[i]==0.0),
            state_pressure_contact_node_indices=Tuple(i÷4 for i in 4:4:length(state) if state[i]==0.0),
            step_finite=linear_step_finite,
            step_norm=linear_direction===nothing ? nothing : norm(linear_direction),
            kkt=(passed=linear_step_result.kkt.passed,
                free_stationarity=linear_step_result.kkt.free_stationarity,
                lower_dual_violation=linear_step_result.kkt.lower_dual_violation,
                scaled_complementarity=linear_step_result.kkt.scaled_complementarity,
                primal_feasible=linear_step_result.kkt.primal_feasible),
            predicted_scaled_residual_l2=linear_model===nothing ? nothing : norm(linear_model),
            predicted_scaled_residual_max=linear_model===nothing ? nothing : maximum(abs,linear_model),
            predicted_residual_blocks=linear_blocks,
            strict_global_or_infinity_bound_claim=false,
            nonlinear_solve=:not_reexecuted)
        unbounded_lower=fill(-Inf,length(state))
        unbounded_qr_result=S.SpatialBoundedLinearStepV1.solve_lower_bounded_step_v1(
            linear_A,linear_r,unbounded_lower;policy=linear_policy,seconds=120.0)
        unbounded_rank_values=Int[h.rank_estimate for h in unbounded_qr_result.history
            if hasproperty(h,:rank_estimate) && h.rank_estimate isa Integer]
        unbounded_step_values=collect(unbounded_qr_result.step)
        unbounded_step_finite=length(unbounded_step_values)==length(state) &&
            all(value->value isa Real && isfinite(value),unbounded_step_values)
        unbounded_direction=unbounded_step_finite ? Float64.(unbounded_step_values) : nothing
        unbounded_model=unbounded_direction===nothing ? nothing : linear_r+linear_A*unbounded_direction
        objective_gradient=transpose(linear_A)*linear_r
        unbounded_directional_derivative=unbounded_direction===nothing ? nothing :
            dot(objective_gradient,unbounded_direction)
        unbounded_pre_endpoint=unbounded_direction===nothing ? nothing :
            Float64.(state .+ columns .* unbounded_direction)
        unbounded_post_endpoint=unbounded_pre_endpoint===nothing ? nothing : copy(unbounded_pre_endpoint)
        if unbounded_post_endpoint!==nothing
            for index in 4:4:length(columns)
                S._smr_pressure_feasible(unbounded_post_endpoint[index],columns[index]) &&
                    unbounded_post_endpoint[index]<0.0 && (unbounded_post_endpoint[index]=0.0)
            end
        end
        unbounded_pre_violations=unbounded_pre_endpoint===nothing ? nothing :
            Tuple(i for i in 4:4:length(columns) if
                !S._smr_pressure_feasible(unbounded_pre_endpoint[i],columns[i]))
        unbounded_post_violations=unbounded_post_endpoint===nothing ? nothing :
            Tuple(i for i in 4:4:length(columns) if
                !S._smr_pressure_feasible(unbounded_post_endpoint[i],columns[i]))
        unbounded_armijo=if unbounded_qr_result.converged && unbounded_qr_result.kkt.passed &&
                unbounded_direction!==nothing && unbounded_directional_derivative isa Real &&
                isfinite(unbounded_directional_derivative) && unbounded_directional_derivative<0.0 &&
                norm(unbounded_direction)>0.0
            unbounded_admission=S._smgw_admit_context_v1(context)
            unbounded_seal=S._smgw_capture_operator_binding_v1(unbounded_admission,data,receipt,state;
                residual_partition=:spatial_native)
            unbounded_guard=()->S._smgw_assert_operator_binding_v1(
                unbounded_seal,context,declaration,data,receipt,state;residual_partition=:spatial_native)
            unbounded_search=S.MultiTopologyNonlinearSolveV1.accepted_step_v1(
                state,unbounded_direction,columns;objective_before=dot(linear_r,linear_r),
                directional_derivative=unbounded_directional_derivative,max_backtracks=0,
                alpha0=1.0,reduction=0.5,minimum_alpha=0.0,armijo_fraction=2.0e-4,
                require_strict_decrease=true,
                assemble_trial=trial->S.assemble_spatial_global_weak_system_v1(declaration,data,trial;
                    flux_Wb=input.flux.nominal_Wb,jacobian=false,residual_partition=:spatial_native),
                assembly_ready=_->true,unavailable_reason=_->(kind=:unexpected_unavailable_global_weak_assembly,),
                residual_for_merit=assembly->begin
                    assembly.row_scales==final_actual.row_scales &&
                        assembly.row_blocks==final_actual.row_blocks ||
                        error("unbounded QR Armijo row system changed")
                    assembly.residual./assembly.row_scales
                end,
                merit=(_,residual)->dot(residual,residual),
                project_state=trial->begin
                    for index in 4:4:length(trial)
                        S._smr_pressure_feasible(trial[index],columns[index]) &&
                            trial[index]<0.0 && (trial[index]=0.0)
                    end
                    trial
                end,
                feasible=trial->all(index->S._smr_pressure_feasible(trial[index],columns[index]),
                    4:4:length(trial)),
                changed=(before,after)->after!=before &&
                    S._smr_scaled_state_change(before,after,columns),
                evaluation_record=assembly->begin
                    residual=assembly.residual./assembly.row_scales
                    (scaled_residual_l2=norm(residual),scaled_residual_max=maximum(abs,residual),
                        row_count=length(residual),row_scales_equal=assembly.row_scales==final_actual.row_scales,
                        row_layout_equal=assembly.row_blocks==final_actual.row_blocks)
                end,binding_guard=unbounded_guard)
            unbounded_trial=isempty(unbounded_search.trials) ? nothing : first(unbounded_search.trials)
            projection_matches=unbounded_trial===nothing ? nothing :
                unbounded_trial.state==Tuple(unbounded_post_endpoint)
            unbounded_trial===nothing || projection_matches ||
                error("manual unbounded QR projection differs from accepted-step trial")
            (status=String(unbounded_search.status),trial=unbounded_trial,
                evaluation=unbounded_trial===nothing ? nothing : unbounded_trial.evaluation,
                projection_matches_trial=projection_matches)
        else
            (status=:not_run,reason=:unbounded_qr_not_converged_or_not_descent,
                trial=nothing,evaluation=nothing,projection_matches_trial=nothing)
        end
        bounded_endpoint=linear_direction===nothing ? nothing :
            Float64.(state .+ columns .* linear_direction)
        bounded_post_endpoint=bounded_endpoint===nothing ? nothing : copy(bounded_endpoint)
        if bounded_post_endpoint!==nothing
            for index in 4:4:length(columns)
                S._smr_pressure_feasible(bounded_post_endpoint[index],columns[index]) &&
                    bounded_post_endpoint[index]<0.0 && (bounded_post_endpoint[index]=0.0)
            end
        end
        unbounded_qr_comparison=(schema="q1-8-saved-final-state-unbounded-qr-comparison-v1",
            diagnostic_only=true,saved_state_hash=replay.state_hash,all_lower_bounds_unbounded=true,
            solver=(status=String(unbounded_qr_result.status),exit_code=unbounded_qr_result.exit_code,
                converged=unbounded_qr_result.converged,elapsed_seconds=unbounded_qr_result.elapsed_seconds,
                seconds_budget=unbounded_qr_result.seconds_budget,inner_iterations=unbounded_qr_result.inner_iterations,
                inner_iteration_limit=unbounded_qr_result.inner_iteration_limit,
                rank_estimate=isempty(unbounded_rank_values) ? nothing : last(unbounded_rank_values),
                rank_estimate_is_inner_diagnostic=true,failure=unbounded_qr_result.failure,
                active_indices=Tuple(Int(i) for i in unbounded_qr_result.active_indices),
                free_count=length(unbounded_qr_result.free_indices),step_finite=unbounded_step_finite,
                step=unbounded_direction===nothing ? nothing : Tuple(unbounded_direction),
                step_norm=unbounded_direction===nothing ? nothing : norm(unbounded_direction)),
            kkt=(passed=unbounded_qr_result.kkt.passed,
                free_stationarity=unbounded_qr_result.kkt.free_stationarity,
                lower_dual_violation=unbounded_qr_result.kkt.lower_dual_violation,
                primal_violation=unbounded_qr_result.kkt.primal_violation,
                primal_tolerance=unbounded_qr_result.kkt.primal_tolerance,
                working_bound_error=unbounded_qr_result.kkt.working_bound_error,
                complementarity=unbounded_qr_result.kkt.complementarity,
                scaled_complementarity=unbounded_qr_result.kkt.scaled_complementarity,
                primal_feasible=unbounded_qr_result.kkt.primal_feasible,
                working_bounds_satisfied=unbounded_qr_result.kkt.working_bounds_satisfied,
                roundoff_floor=unbounded_qr_result.kkt.roundoff_floor,
                objective=unbounded_qr_result.kkt.objective,model_gradient=unbounded_qr_result.kkt.gradient),
            bounded_reference=(solver_status=String(linear_step_result.status),
                solver_converged=linear_step_result.converged,
                active_indices=Tuple(Int(i) for i in linear_step_result.active_indices),
                active_pressure_dof_indices=Tuple(Int(i) for i in linear_step_result.active_indices if i%4==0),
                free_count=length(linear_step_result.free_indices),
                step=linear_direction===nothing ? nothing : Tuple(linear_direction),
                step_norm=linear_direction===nothing ? nothing : norm(linear_direction),
                kkt=(passed=linear_step_result.kkt.passed,
                    free_stationarity=linear_step_result.kkt.free_stationarity,
                    lower_dual_violation=linear_step_result.kkt.lower_dual_violation,
                    scaled_complementarity=linear_step_result.kkt.scaled_complementarity,
                    primal_feasible=linear_step_result.kkt.primal_feasible,
                    gradient=linear_step_result.kkt.gradient),
                model_residual=linear_model===nothing ? nothing : Tuple(linear_model),
                model_residual_l2=linear_model===nothing ? nothing : norm(linear_model),
                model_residual_inf=linear_model===nothing ? nothing : maximum(abs,linear_model),
                objective_gradient_l2=norm(objective_gradient),
                objective_gradient_inf=maximum(abs,objective_gradient),
                directional_derivative=linear_direction===nothing ? nothing :
                    dot(objective_gradient,linear_direction),
                model_objective=linear_model===nothing ? nothing : dot(linear_model,linear_model),
                predicted_decrease=linear_model===nothing ? nothing :
                    dot(linear_r,linear_r)-dot(linear_model,linear_model),
                endpoint_pre_projection_pressure_Pa=bounded_endpoint===nothing ? nothing :
                    Tuple(bounded_endpoint[4:4:end]),
                endpoint_post_projection_pressure_Pa=bounded_post_endpoint===nothing ? nothing :
                    Tuple(bounded_post_endpoint[4:4:end]),
                endpoint_pre_pressure_min_Pa=bounded_endpoint===nothing ? nothing :
                    minimum(bounded_endpoint[4:4:end]),
                endpoint_post_pressure_min_Pa=bounded_post_endpoint===nothing ? nothing :
                    minimum(bounded_post_endpoint[4:4:end]),
                endpoint_pre_pressure_violation_dof_indices=bounded_endpoint===nothing ? nothing :
                    Tuple(i for i in 4:4:length(columns) if !S._smr_pressure_feasible(bounded_endpoint[i],columns[i])),
                endpoint_post_pressure_violation_dof_indices=bounded_post_endpoint===nothing ? nothing :
                    Tuple(i for i in 4:4:length(columns) if !S._smr_pressure_feasible(bounded_post_endpoint[i],columns[i]))),
            objective_gradient_l2=norm(objective_gradient),objective_gradient_inf=maximum(abs,objective_gradient),
            directional_derivative=unbounded_directional_derivative,
            model_residual=unbounded_model===nothing ? nothing : Tuple(unbounded_model),
            model_residual_l2=unbounded_model===nothing ? nothing : norm(unbounded_model),
            model_residual_inf=unbounded_model===nothing ? nothing : maximum(abs,unbounded_model),
            model_objective=unbounded_model===nothing ? nothing : dot(unbounded_model,unbounded_model),
            predicted_decrease=unbounded_model===nothing ? nothing :
                dot(linear_r,linear_r)-dot(unbounded_model,unbounded_model),
            endpoint=(pre_projection_state=unbounded_pre_endpoint===nothing ? nothing : Tuple(unbounded_pre_endpoint),
                post_projection_state=unbounded_post_endpoint===nothing ? nothing : Tuple(unbounded_post_endpoint),
                pre_projection_state_hash=unbounded_pre_endpoint===nothing ? nothing :
                    string(canonical_hash(Tuple(unbounded_pre_endpoint))),
                post_projection_state_hash=unbounded_post_endpoint===nothing ? nothing :
                    string(canonical_hash(Tuple(unbounded_post_endpoint))),
                pre_projection_pressure_Pa=unbounded_pre_endpoint===nothing ? nothing :
                    Tuple(unbounded_pre_endpoint[4:4:end]),
                post_projection_pressure_Pa=unbounded_post_endpoint===nothing ? nothing :
                    Tuple(unbounded_post_endpoint[4:4:end]),
                pre_pressure_min_Pa=unbounded_pre_endpoint===nothing ? nothing :
                    minimum(unbounded_pre_endpoint[4:4:end]),
                post_pressure_min_Pa=unbounded_post_endpoint===nothing ? nothing :
                    minimum(unbounded_post_endpoint[4:4:end]),
                pre_pressure_contact_dof_indices=unbounded_pre_endpoint===nothing ? nothing :
                    Tuple(i for i in 4:4:length(columns) if unbounded_pre_endpoint[i]==0.0),
                post_pressure_contact_dof_indices=unbounded_post_endpoint===nothing ? nothing :
                    Tuple(i for i in 4:4:length(columns) if unbounded_post_endpoint[i]==0.0),
                pre_pressure_violation_dof_indices=unbounded_pre_violations,
                post_pressure_violation_dof_indices=unbounded_post_violations,
                projection_changed=unbounded_pre_endpoint===nothing ? nothing :
                    unbounded_pre_endpoint!=unbounded_post_endpoint),
            armijo=(status=unbounded_armijo.status,trial=unbounded_armijo.trial,
                evaluation=unbounded_armijo.evaluation,
                projection_matches_trial=unbounded_armijo.projection_matches_trial,
                objective_before=dot(linear_r,linear_r),directional_derivative=unbounded_directional_derivative,
                fraction=2.0e-4,max_backtracks=0,alpha=1.0,strict_decrease_required=true),
            bounded_active_pressure_dof_indices=Tuple(Int(i) for i in linear_step_result.active_indices if i%4==0),
            bounded_active_nonpressure_dof_indices=Tuple(Int(i) for i in linear_step_result.active_indices if i%4!=0),
            bounded_state_pressure_contact_dof_indices=Tuple(i for i in 4:4:length(state) if state[i]==0.0),
            bounded_state_pressure_contact_node_indices=Tuple(i÷4 for i in 4:4:length(state) if state[i]==0.0))
        linearized_check=merge(linearized_check,(unbounded_qr_comparison=unbounded_qr_comparison,))
        linear_directional_derivative=linear_direction===nothing ? nothing :
            dot(transpose(linear_A)*linear_r,linear_direction)
        finite_linear_directional_derivative=linear_directional_derivative isa Real &&
            isfinite(linear_directional_derivative) ? Float64(linear_directional_derivative) : nothing
        ray_probe_residual=Ref{Any}(nothing)
        armijo_probe=if linear_step_result.converged && linear_step_result.kkt.passed && linear_direction!==nothing &&
                finite_linear_directional_derivative!==nothing && finite_linear_directional_derivative<0.0
            admission=S._smgw_admit_context_v1(context)
            seal=S._smgw_capture_operator_binding_v1(admission,data,receipt,state;
                residual_partition=:spatial_native)
            binding_guard=()->S._smgw_assert_operator_binding_v1(seal,context,declaration,data,receipt,state;
                residual_partition=:spatial_native)
            objective_before=dot(linear_r,linear_r)
            directional_derivative=finite_linear_directional_derivative
            run_search=alpha->S.MultiTopologyNonlinearSolveV1.accepted_step_v1(state,linear_direction,columns;
                objective_before=objective_before,directional_derivative=directional_derivative,
                max_backtracks=0,alpha0=alpha,reduction=0.5,minimum_alpha=0.0,
                armijo_fraction=2.0e-4,require_strict_decrease=true,
                assemble_trial=trial->S.assemble_spatial_global_weak_system_v1(declaration,data,trial;
                    flux_Wb=input.flux.nominal_Wb,jacobian=false,residual_partition=:spatial_native),
                assembly_ready=_->true,unavailable_reason=_->(kind=:unexpected_unavailable_global_weak_assembly,),
                residual_for_merit=assembly->assembly.residual./assembly.row_scales,
                merit=(_,residual)->dot(residual,residual),
                project_state=trial->begin
                    for index in 4:4:length(trial)
                        S._smr_pressure_feasible(trial[index],columns[index]) && trial[index]<0.0 &&
                            (trial[index]=0.0)
                    end
                    trial
                end,
                feasible=trial->all(index->S._smr_pressure_feasible(trial[index],columns[index]),4:4:length(trial)),
                changed=(before,after)->after!=before && S._smr_scaled_state_change(before,after,columns),
                evaluation_record=assembly->begin
                    residual=assembly.residual./assembly.row_scales
                    phase===:diagnostic_failed_state_ray && alpha==1.0 &&
                        assembly.row_scales==final_actual.row_scales &&
                        (ray_probe_residual[]=copy(residual))
                    (scaled_residual_l2=norm(residual),scaled_residual_max=maximum(abs,residual),
                        row_count=length(residual))
                end,
                binding_guard=binding_guard)
            alpha_one_search=run_search(1.0)
            quartic_alpha=if phase===:diagnostic_failed_state_ray && ray_probe_residual[]!==nothing
                S._smgw_quartic_ray_alpha_v1(linear_r,linear_A*linear_direction,ray_probe_residual[])
            else
                nothing
            end
            search=phase===:diagnostic_failed_state_ray && quartic_alpha!==nothing ?
                run_search(quartic_alpha) : alpha_one_search
            lm_chord_probe=if phase===:diagnostic_failed_state_ray &&
                    quartic_alpha!==nothing && ray_probe_residual[]!==nothing
                # Bind this one-point probe to the exact failed producer and attempts
                # artifact before extracting its last persisted next-step multiplier.
                artifact_binding.primary_sha256==
                    "7fe27c2781d37de574db7c93614764734a4765c89e568150cf42c6f74c0bcc61" ||
                    error("diagnostic LM multiplier is not bound to the reviewed Q1_8 primary")
                attempts_path=joinpath(production_dir,"attempts.json")
                S._smgw_sha256_file_v1(attempts_path)==
                    "ea4c09f4f24bf17b3f31420a475d793bd15cb0c4e53396933c7b52d9a035c396" ||
                    error("diagnostic LM multiplier attempts artifact differs from the reviewed producer")
                attempts_tail_io=open(attempts_path,"r")
                attempts_tail=try
                    seek(attempts_tail_io,max(0,filesize(attempts_path)-262144))
                    read(attempts_tail_io,String)
                finally
                    close(attempts_tail_io)
                end
                multiplier_matches=collect(eachmatch(r"\"next_damping_multiplier\":([0-9.eE+-]+)",attempts_tail))
                isempty(multiplier_matches) && error("failed producer has no readable final damping multiplier")
                lm_multiplier=parse(Float64,last(multiplier_matches).captures[1])
                isfinite(lm_multiplier) && lm_multiplier==1.0e-5 ||
                    error("failed producer final damping multiplier differs from the reviewed value")
                ray_curvature=ray_probe_residual[] .- linear_r .- linear_A*linear_direction
                damping=S._smgw_lm_curvature_scale_v1(linear_A,linear_r,
                    linear_A*linear_direction,ray_probe_residual[],quartic_alpha;
                    damping_multiplier=lm_multiplier)
                if damping===nothing
                    (status=:ineligible_curvature, damping_multiplier=lm_multiplier)
                else
                    chord_lower=S._smgw_scaled_lower_bounds_v1(state,columns)
                    chord_binding=binding_guard()
                    chord=S._smgw_lm_chord_corrector_v1(linear_A,linear_r,
                        linear_A*linear_direction,ray_curvature,quartic_alpha,
                        linear_direction,chord_lower,damping.lambda;seconds=6.0)
                    binding_guard()==chord_binding ||
                        error("operator binding changed during diagnostic LM chord corrector")
                    if chord===nothing
                        (status=:ineligible_chord_inputs,damping_multiplier=lm_multiplier,
                            lambda=damping.lambda,curvature_ratio=damping.curvature_ratio)
                    else
                        lm_step=chord.composite
                        lm_gradient=transpose(linear_A)*linear_r
                        lm_directional=lm_step===nothing ? Inf : dot(lm_gradient,lm_step)
                        lm_endpoint=lm_step===nothing ? Float64[] : state .+ columns .* lm_step
                        lm_feasible=lm_step!==nothing && all(isfinite,lm_endpoint) &&
                            all(i->S._smr_pressure_feasible(lm_endpoint[i],columns[i]),4:4:length(columns))
                        lm_selected=chord.solved.converged && chord.solved.kkt.passed &&
                            chord.valid && lm_feasible && isfinite(lm_directional) &&
                            lm_directional<0.0 && norm(lm_step)>0.0
                        if !lm_selected
                            (status=:corrector_not_selected,damping_multiplier=lm_multiplier,
                                lambda=chord.lambda,curvature_ratio=damping.curvature_ratio,
                                corrector_kkt=chord.solved.kkt,step_norm=lm_step===nothing ? nothing : norm(lm_step),
                                feasible=lm_feasible,directional_derivative=isfinite(lm_directional) ? lm_directional : nothing,
                                elapsed_seconds=chord.solved.elapsed_seconds)
                        else
                            endpoint_binding=binding_guard()
                            lm_endpoint_assembly=try
                                S.assemble_spatial_global_weak_system_v1(declaration,data,lm_endpoint;
                                    flux_Wb=input.flux.nominal_Wb,jacobian=false,residual_partition=:spatial_native)
                            catch err
                                numeric=err isa DomainError || (err isa ArgumentError &&
                                    occursin("nonfinite global weak residual",sprint(showerror,err)))
                                (err isa InterruptException || !numeric) && rethrow()
                                nothing
                            end
                            binding_guard()==endpoint_binding ||
                                error("operator binding changed during diagnostic LM endpoint probe")
                            lm_endpoint_residual=if lm_endpoint_assembly!==nothing &&
                                    lm_endpoint_assembly.row_scales==final_actual.row_scales
                                lm_endpoint_assembly.residual ./ lm_endpoint_assembly.row_scales
                            else
                                nothing
                            end
                            lm_quartic_alpha=lm_endpoint_residual===nothing ? nothing :
                                S._smgw_quartic_ray_alpha_v1(linear_r,linear_A*lm_step,lm_endpoint_residual)
                            lm_selected_alpha=1.0
                            lm_selected_alpha_source=:alpha_one_fallback
                            lm_probe_status=lm_endpoint_residual===nothing ? :alpha_one_fallback_endpoint_probe_unavailable :
                                :alpha_one_fallback_no_quartic_minimum
                            if lm_quartic_alpha!==nothing
                                lm_raw_trial=state .+ lm_quartic_alpha .* columns .* lm_step
                                lm_projected_trial=copy(lm_raw_trial)
                                for i in 4:4:length(columns)
                                    S._smr_pressure_feasible(lm_projected_trial[i],columns[i]) &&
                                        lm_projected_trial[i]<0.0 && (lm_projected_trial[i]=0.0)
                                end
                                if lm_raw_trial==lm_projected_trial &&
                                        all(i->S._smr_pressure_feasible(lm_projected_trial[i],columns[i]),4:4:length(columns))
                                    lm_selected_alpha=lm_quartic_alpha
                                    lm_selected_alpha_source=:quartic_selected
                                    lm_probe_status=:quartic_selected
                                else
                                    lm_probe_status=:alpha_one_fallback_quartic_candidate_ineligible
                                end
                            end
                            S.MultiTopologyNonlinearSolveV1.verify_source_v1(
                                joinpath(REPO,"src","RuntimeV4","MultiTopologyNonlinearSolveV1.jl"))
                            trial_search=S.MultiTopologyNonlinearSolveV1.accepted_step_v1(
                                state,lm_step,columns;objective_before=objective_before,
                                directional_derivative=2.0*lm_directional,max_backtracks=0,
                                alpha0=lm_selected_alpha,reduction=0.5,minimum_alpha=0.0,
                                armijo_fraction=2.0e-4,require_strict_decrease=true,
                                assemble_trial=trial->S.assemble_spatial_global_weak_system_v1(
                                    declaration,data,trial;flux_Wb=input.flux.nominal_Wb,
                                    jacobian=false,residual_partition=:spatial_native),
                                assembly_ready=_ -> true,
                                unavailable_reason=_ -> (kind=:unexpected_unavailable_global_weak_assembly,),
                                residual_for_merit=assembly->begin
                                    assembly.row_scales==final_actual.row_scales ||
                                        error("diagnostic LM trial row scales differ from the saved-point objective")
                                    assembly.residual ./ assembly.row_scales
                                end,
                                merit=(_,residual)->dot(residual,residual),
                                project_state=trial->begin
                                    for i in 4:4:length(trial)
                                        S._smr_pressure_feasible(trial[i],columns[i]) &&
                                            trial[i]<0.0 && (trial[i]=0.0)
                                    end
                                    trial
                                end,
                                feasible=trial->all(i->S._smr_pressure_feasible(trial[i],columns[i]),4:4:length(trial)),
                                changed=(before,after)->after!=before &&
                                    S._smr_scaled_state_change(before,after,columns),
                                evaluation_record=assembly->begin
                                    residual=assembly.residual ./ assembly.row_scales
                                    row_layout_matches=hasproperty(assembly,:row_blocks) &&
                                        assembly.row_blocks==final_actual.row_blocks
                                    row_blocks=if assembly.row_scales==final_actual.row_scales &&
                                            row_layout_matches && length(residual)==length(assembly.row_blocks)
                                        layout=assembly.row_blocks
                                        Tuple(begin
                                            rows=findall(==(block),layout)
                                            values=residual[rows]
                                            (block=String(block),row_count=length(rows),scaled_l2=norm(values),
                                                scaled_maximum=maximum(abs,values;init=0.0))
                                        end for block in unique(layout))
                                    else
                                        nothing
                                    end
                                    (scaled_residual_l2=norm(residual),
                                            scaled_residual_max=maximum(abs,residual),row_count=length(residual),
                                            row_scales_equal=assembly.row_scales==final_actual.row_scales,
                                            row_layout_equal=row_layout_matches,
                                            scaled_residual_blocks=row_blocks)
                                end,
                                binding_guard=binding_guard)
                            outcome=isempty(trial_search.trials) ? nothing : first(trial_search.trials)
                            endpoint_was_evaluated=outcome!==nothing && outcome.evaluated &&
                                outcome.evaluation!==nothing
                            (status=:corrector_evaluated,damping_multiplier=lm_multiplier,
                                lambda=chord.lambda,curvature_ratio=damping.curvature_ratio,
                                damping_factor=damping.damping_factor,
                                corrector_status=String(chord.solved.status),
                                corrector_kkt=(passed=chord.solved.kkt.passed,
                                    free_stationarity=chord.solved.kkt.free_stationarity,
                                    lower_dual_violation=chord.solved.kkt.lower_dual_violation,
                                    scaled_complementarity=chord.solved.kkt.scaled_complementarity,
                                    primal_feasible=chord.solved.kkt.primal_feasible),
                                active_count=length(chord.solved.active_indices),
                                corrector_active_pressure_dof_indices=Tuple(Int(i) for i in chord.solved.active_indices if i%4==0),
                                corrector_active_nonpressure_dof_indices=Tuple(Int(i) for i in chord.solved.active_indices if i%4!=0),
                                corrector_correction=Tuple(Float64.(chord.correction)),
                                corrector_free_indices=Tuple(Int(i) for i in chord.solved.free_indices),
                                evaluated_endpoint_pressure_at_bound_dof_indices=endpoint_was_evaluated ?
                                    Tuple(i for i in 4:4:length(outcome.state) if outcome.state[i]==0.0) : nothing,
                                evaluated_endpoint_pressure_at_bound_node_indices=endpoint_was_evaluated ?
                                    Tuple(i÷4 for i in 4:4:length(outcome.state) if outcome.state[i]==0.0) : nothing,
                                free_count=length(chord.solved.free_indices),
                                corrector_elapsed_seconds=chord.solved.elapsed_seconds,
                                endpoint_probe_available=lm_endpoint_residual!==nothing,
                                step_norm=norm(lm_step),directional_derivative=lm_directional,
                                lm_quartic_alpha=lm_quartic_alpha,
                                line_search_alpha0=lm_selected_alpha,
                                line_search_alpha_source=lm_selected_alpha_source,
                                selection_note=lm_probe_status,
                                armijo_status=String(trial_search.status),
                                trial_alpha=outcome===nothing ? nothing : outcome.alpha,
                                evaluated=outcome===nothing ? false : outcome.evaluated,
                                armijo=outcome===nothing ? false : outcome.armijo,
                                strict_decrease=outcome===nothing ? false : outcome.strict_decrease,
                                objective_before=objective_before,
                                objective_after=outcome===nothing ? nothing : outcome.objective_after,
                                evaluation=outcome===nothing ? nothing : outcome.evaluation,
                                trial_feasible=outcome===nothing ? nothing : outcome.feasible,
                                trial_pressure_contact_dof_indices=outcome===nothing ? nothing :
                                    Tuple(i for i in 4:4:length(outcome.state) if outcome.state[i]==0.0),
                                trial_pressure_contact_node_indices=outcome===nothing ? nothing :
                                    Tuple(i÷4 for i in 4:4:length(outcome.state) if outcome.state[i]==0.0))
                        end
                    end
                end
            else
                (status=:not_run,reason=:raw_ray_probe_ineligible)
            end
            lm_damping_comparison=if phase===:diagnostic_failed_state_ray &&
                    lm_chord_probe!==nothing && hasproperty(lm_chord_probe,:lambda) &&
                    lm_chord_probe.status===:corrector_evaluated
                ray_curvature=ray_probe_residual[] .- linear_r .- linear_A*linear_direction
                inputs5=S._smgw_lm_chord_corrector_inputs_v1(linear_r,
                    linear_A*linear_direction,ray_curvature,quartic_alpha,linear_direction,
                    S._smgw_scaled_lower_bounds_v1(state,columns))
                correction5=Float64.(collect(lm_chord_probe.corrector_correction))
                tangent5=transpose(linear_A)*(linear_A*correction5+inputs5.residual)+
                    lm_chord_probe.lambda.*correction5
                free5=collect(lm_chord_probe.corrector_free_indices)
                free_tangent5=isempty(free5) ? 0.0 : maximum(abs,tangent5[free5])
                damping5=S._smgw_lm_curvature_scale_v1(linear_A,linear_r,
                    linear_A*linear_direction,ray_probe_residual[],quartic_alpha;
                    damping_multiplier=1.0e-5)
                damping5!==nothing && damping5.lambda==lm_chord_probe.lambda ||
                    error("mu comparison production-floor lambda differs from current equation")
                same_equation_hash=S.canonical_hash((
                    candidate_hash=string(context.candidate_hash),
                    context_hash=string(context.context_hash), input_hash=input_hash,
                    saved_state_hash=replay.state_hash,
                    row_scales=Tuple(final_actual.row_scales),
                    row_blocks=Tuple(String(x) for x in final_actual.row_blocks),
                    A_size=size(linear_A), A_colptr=Tuple(linear_A.colptr),
                    A_rowval=Tuple(linear_A.rowval), A_nzval=Tuple(linear_A.nzval),
                    r=Tuple(linear_r), raw_step=Tuple(linear_direction),
                    linear_delta=Tuple(linear_A*linear_direction),
                    endpoint_residual=Tuple(ray_probe_residual[]),
                    curvature=Tuple(ray_curvature), alpha=quartic_alpha,
                    lower=Tuple(S._smgw_scaled_lower_bounds_v1(state,columns))))
                lambda8=lm_chord_probe.lambda*(1.0e-8/1.0e-5)
                isfinite(lambda8) && lambda8>0.0 || error("mu=1e-8 counterfactual lambda is invalid")
                chord8=S._smgw_lm_chord_corrector_v1(linear_A,linear_r,
                    linear_A*linear_direction,ray_curvature,quartic_alpha,
                    linear_direction,S._smgw_scaled_lower_bounds_v1(state,columns),
                    lambda8;seconds=6.0,stage_name="diagnostic_q1_8_lm_chord_mu_1e8")
                chord8!==nothing || error("mu=1e-8 chord QR did not return a diagnostic result")
                same_chord_equations=inputs5!==nothing &&
                    inputs5.residual==chord8.inputs.residual &&
                    inputs5.lower==chord8.inputs.lower &&
                    inputs5.curvature==chord8.inputs.curvature &&
                    inputs5.alpha==chord8.inputs.alpha
                same_chord_equations || error("damping arms changed the chord residual or feasible bounds")
                correction8=Float64.(collect(chord8.correction))
                tangent8=transpose(linear_A)*(linear_A*correction8+chord8.inputs.residual)+
                    chord8.lambda.*correction8
                free8=collect(chord8.solved.free_indices)
                free_tangent8=isempty(free8) ? 0.0 : maximum(abs,tangent8[free8])
                step8=chord8.composite
                endpoint8=step8===nothing ? Float64[] : state .+ columns .* step8
                feasible8=step8!==nothing && all(isfinite,endpoint8) &&
                    all(i->S._smr_pressure_feasible(endpoint8[i],columns[i]),4:4:length(columns))
                gradient=transpose(linear_A)*linear_r
                directional8=step8===nothing ? Inf : dot(gradient,step8)
                selected8=chord8.solved.converged && chord8.solved.kkt.passed &&
                    chord8.valid && feasible8 && isfinite(directional8) && directional8<0.0 &&
                    norm(step8)>0.0
                endpoint_binding8=selected8 ? binding_guard() : nothing
                endpoint_assembly8=selected8 ? S.assemble_spatial_global_weak_system_v1(
                    declaration,data,endpoint8;flux_Wb=input.flux.nominal_Wb,
                    jacobian=false,residual_partition=:spatial_native) : nothing
                selected8 && binding_guard()==endpoint_binding8 || !selected8 ||
                    error("operator binding changed during mu=1e-8 endpoint probe")
                same_scales8=endpoint_assembly8!==nothing &&
                    endpoint_assembly8.row_scales==final_actual.row_scales &&
                    endpoint_assembly8.row_blocks==final_actual.row_blocks
                endpoint_residual8=same_scales8 ?
                    endpoint_assembly8.residual ./ endpoint_assembly8.row_scales : nothing
                alpha8=same_scales8 ? S._smgw_quartic_ray_alpha_v1(
                    linear_r,linear_A*step8,endpoint_residual8) : nothing
                selected_alpha8=alpha8===nothing ? 1.0 : Float64(alpha8)
                alpha8_eligible=alpha8!==nothing && begin
                    raw_trial=state .+ alpha8 .* columns .* step8
                    projected_trial=copy(raw_trial)
                    for i in 4:4:length(columns)
                        S._smr_pressure_feasible(projected_trial[i],columns[i]) &&
                            projected_trial[i]<0.0 && (projected_trial[i]=0.0)
                    end
                    raw_trial==projected_trial &&
                        all(i->S._smr_pressure_feasible(projected_trial[i],columns[i]),4:4:length(columns))
                end
                alpha8_eligible || (selected_alpha8=1.0)
                line_search8=if selected8
                    S.MultiTopologyNonlinearSolveV1.verify_source_v1(
                        joinpath(REPO,"src","RuntimeV4","MultiTopologyNonlinearSolveV1.jl"))
                    S.MultiTopologyNonlinearSolveV1.accepted_step_v1(state,step8,columns;
                        objective_before=objective_before,directional_derivative=2.0*directional8,
                        max_backtracks=0,alpha0=selected_alpha8,reduction=0.5,
                        minimum_alpha=0.0,armijo_fraction=2.0e-4,
                        require_strict_decrease=true,
                        assemble_trial=trial->S.assemble_spatial_global_weak_system_v1(
                            declaration,data,trial;flux_Wb=input.flux.nominal_Wb,
                            jacobian=false,residual_partition=:spatial_native),
                        assembly_ready=_ -> true,
                        unavailable_reason=_ -> (kind=:unexpected_unavailable_global_weak_assembly,),
                        residual_for_merit=assembly->begin
                            assembly.row_scales==final_actual.row_scales &&
                                assembly.row_blocks==final_actual.row_blocks ||
                                error("mu=1e-8 Armijo row system changed")
                            assembly.residual ./ assembly.row_scales
                        end,
                        merit=(_,residual)->dot(residual,residual),
                        project_state=trial->begin
                            for i in 4:4:length(trial)
                                S._smr_pressure_feasible(trial[i],columns[i]) &&
                                    trial[i]<0.0 && (trial[i]=0.0)
                            end
                            trial
                        end,
                        feasible=trial->all(i->S._smr_pressure_feasible(trial[i],columns[i]),4:4:length(trial)),
                        changed=(before,after)->after!=before &&
                            S._smr_scaled_state_change(before,after,columns),
                    binding_guard=binding_guard,
                        evaluation_record=assembly->begin
                            residual=assembly.residual ./ assembly.row_scales
                            (scaled_residual_l2=norm(residual),
                                scaled_residual_max=maximum(abs,residual),
                                row_count=length(residual),
                                row_scales_equal=assembly.row_scales==final_actual.row_scales,
                                row_layout_equal=assembly.row_blocks==final_actual.row_blocks)
                        end)
                else
                    nothing
                end
                trial8=line_search8===nothing || isempty(line_search8.trials) ?
                    nothing : first(line_search8.trials)
                trial8_evaluated=trial8!==nothing && trial8.evaluated &&
                    trial8.evaluation!==nothing
                (schema="q1-8-saved-point-lm-multiplier-counterfactual-v1",
                    diagnostic_only=true, nonlinear_solve=:not_executed,
                    source_primary_sha256=artifact_binding.primary_sha256,
                    saved_state_hash=replay.state_hash,
                    equation_hash=same_equation_hash,
                    same_chord_equations=same_chord_equations,
                    damping_multiplier_ratio=lambda8/lm_chord_probe.lambda,
                    equation_rebuilt_once=true,jacobian_nnz=nnz(linear_A),
                    scaled_residual_l2=norm(linear_r),
                    raw_direction_hash=S.canonical_hash(Tuple(linear_direction)),
                    q_hash=S.canonical_hash(Tuple(ray_curvature)),
                    armijo_policy=(max_backtracks=0,reduction=0.5,
                        armijo_fraction=2.0e-4,require_strict_decrease=true),
                    raw_quartic_alpha=quartic_alpha,
                    mu_1e5=(lambda=lm_chord_probe.lambda,
                        corrector_status=lm_chord_probe.corrector_status,
                        gradient_l2=norm(gradient),
                        gradient_inf=maximum(abs,gradient),
                        directional_derivative=lm_chord_probe.directional_derivative,
                        trial_feasible=lm_chord_probe.trial_feasible,
                        trial_pressure_contact_dof_indices=lm_chord_probe.trial_pressure_contact_dof_indices,
                        trial_pressure_contact_node_indices=lm_chord_probe.trial_pressure_contact_node_indices,
                        trial_scaled_residual_l2=lm_chord_probe.evaluation===nothing ? nothing :
                            lm_chord_probe.evaluation.scaled_residual_l2,
                        trial_scaled_residual_max=lm_chord_probe.evaluation===nothing ? nothing :
                            lm_chord_probe.evaluation.scaled_residual_max,
                        corrector_kkt=lm_chord_probe.corrector_kkt,
                        active_count=lm_chord_probe.active_count,
                        free_count=lm_chord_probe.free_count,
                        active_pressure_dof_indices=lm_chord_probe.corrector_active_pressure_dof_indices,
                        active_nonpressure_dof_indices=lm_chord_probe.corrector_active_nonpressure_dof_indices,
                        free_pressure_dof_indices=Tuple(i for i in lm_chord_probe.corrector_free_indices if i%4==0),
                        free_nonpressure_dof_indices=Tuple(i for i in lm_chord_probe.corrector_free_indices if i%4!=0),
                        free_tangent_inf=free_tangent5,
                        feasible_composite=lm_chord_probe.feasible,
                        selected=lm_chord_probe.status===:corrector_evaluated &&
                            lm_chord_probe.directional_derivative<0.0,
                        alpha=lm_chord_probe.line_search_alpha0,
                        alpha_source=lm_chord_probe.line_search_alpha_source,
                        trial_status=lm_chord_probe.armijo_status,
                        trial_evaluated=lm_chord_probe.evaluated && lm_chord_probe.evaluation!==nothing,
                        actual_armijo=lm_chord_probe.evaluated && lm_chord_probe.evaluation!==nothing ?
                            lm_chord_probe.armijo : nothing,
                        actual_strict_decrease=lm_chord_probe.evaluated && lm_chord_probe.evaluation!==nothing ?
                            lm_chord_probe.strict_decrease : nothing,
                        objective_before=lm_chord_probe.objective_before,
                        objective_after=lm_chord_probe.objective_after,
                        residual=lm_chord_probe.evaluation),
                    mu_1e8=(lambda=lambda8,
                        corrector_status=String(chord8.solved.status),
                        gradient_l2=norm(gradient),
                        gradient_inf=maximum(abs,gradient),
                        directional_derivative=directional8,
                        trial_feasible=trial8===nothing ? nothing : trial8.feasible,
                        trial_pressure_contact_dof_indices=trial8===nothing ? nothing :
                            Tuple(i for i in 4:4:length(trial8.state) if trial8.state[i]==0.0),
                        trial_pressure_contact_node_indices=trial8===nothing ? nothing :
                            Tuple(i÷4 for i in 4:4:length(trial8.state) if trial8.state[i]==0.0),
                        trial_scaled_residual_l2=trial8_evaluated ? trial8.evaluation.scaled_residual_l2 : nothing,
                        trial_scaled_residual_max=trial8_evaluated ? trial8.evaluation.scaled_residual_max : nothing,
                        corrector_kkt=(passed=chord8.solved.kkt.passed,
                            free_stationarity=chord8.solved.kkt.free_stationarity,
                            lower_dual_violation=chord8.solved.kkt.lower_dual_violation,
                            scaled_complementarity=chord8.solved.kkt.scaled_complementarity,
                            primal_feasible=chord8.solved.kkt.primal_feasible),
                        active_count=length(chord8.solved.active_indices),
                        free_count=length(chord8.solved.free_indices),
                        active_pressure_dof_indices=Tuple(Int(i) for i in chord8.solved.active_indices if i%4==0),
                        active_nonpressure_dof_indices=Tuple(Int(i) for i in chord8.solved.active_indices if i%4!=0),
                        free_pressure_dof_indices=Tuple(Int(i) for i in chord8.solved.free_indices if i%4==0),
                        free_nonpressure_dof_indices=Tuple(Int(i) for i in chord8.solved.free_indices if i%4!=0),
                        free_tangent_inf=free_tangent8,
                        feasible_composite=feasible8,selected=selected8,
                        alpha=selected_alpha8,
                        alpha_source=alpha8_eligible ? :quartic_selected : :alpha_one_fallback,
                        trial_status=line_search8===nothing ? "not_run" : String(line_search8.status),
                        trial_evaluated=trial8_evaluated,
                        actual_armijo=trial8_evaluated ? trial8.armijo : nothing,
                        actual_strict_decrease=trial8_evaluated ? trial8.strict_decrease : nothing,
                        objective_before=objective_before,
                        objective_after=trial8===nothing ? nothing : trial8.objective_after,
                        residual=trial8===nothing ? nothing : trial8.evaluation))
            else
                (schema="q1-8-saved-point-lm-multiplier-counterfactual-v1",
                    diagnostic_only=true,nonlinear_solve=:not_executed,
                    status=:ineligible_base_chord,base=lm_chord_probe)
            end
            trial=isempty(search.trials) ? nothing : first(search.trials)
            alpha_one_trial=isempty(alpha_one_search.trials) ? nothing : first(alpha_one_search.trials)
            alpha_one_trial_info=alpha_one_trial===nothing ? nothing :
                (alpha=alpha_one_trial.alpha,evaluated=alpha_one_trial.evaluated,
                    armijo=alpha_one_trial.armijo,strict_decrease=alpha_one_trial.strict_decrease,
                    objective_after=alpha_one_trial.objective_after,evaluation=alpha_one_trial.evaluation)
            (status=String(search.status),alpha=trial===nothing ? nothing : trial.alpha,
                candidate_kind=phase===:diagnostic_failed_state_ray && quartic_alpha!==nothing ?
                    :quartic_ray : :alpha_one,
                alpha_one_status=String(alpha_one_search.status),
                alpha_one_trial=alpha_one_trial_info,
                quartic_alpha=quartic_alpha,
                alpha_one_endpoint_residual_captured=ray_probe_residual[]!==nothing,
                directional_derivative=finite_linear_directional_derivative,
                evaluated=trial===nothing ? false : trial.evaluated,
                armijo=trial===nothing ? false : trial.armijo,
                strict_decrease=trial===nothing ? false : trial.strict_decrease,
                objective_before=objective_before,
                objective_after=trial===nothing ? nothing : trial.objective_after,
                evaluation=trial===nothing ? nothing : trial.evaluation,
                lm_chord_corrector=lm_chord_probe,
                lm_damping_comparison=lm_damping_comparison)
        elseif linear_step_result.converged && linear_step_result.kkt.passed &&
                linear_step_finite && finite_linear_directional_derivative!==nothing &&
                finite_linear_directional_derivative>=0.0
            (status="non_descent_direction",reason=:directional_derivative_not_negative,
                directional_derivative=finite_linear_directional_derivative,evaluated=false)
        else
            (status="not_run",reason=:linear_step_not_kkt_converged_or_invalid_direction,
                directional_derivative=finite_linear_directional_derivative,evaluated=false)
        end
        linearized_check=phase===:diagnostic_failed_state_ray ?
            merge(linearized_check,(quartic_ray_original_armijo_probe=armijo_probe,)) :
            merge(linearized_check,(single_alpha_one_original_armijo_probe=armijo_probe,))
        println("SMGW_PHASE_END=q1_8_saved_failed_state_bounded_linearized_check status=",
            linearized_check.solver_status," kkt_passed=",linearized_check.kkt.passed,
            " predicted_l2=",linearized_check.predicted_scaled_residual_l2,
            " predicted_max=",linearized_check.predicted_scaled_residual_max);flush(stdout)
        diagnostic=if phase===:diagnostic_failed_state_fd
        (schema="spatial-global-weak-q1_8-saved-failed-state-point-diagnostic-v1",
            diagnostic_scope=:supplied_saved_state_only,acceptance=:not_assessed,
            validation=replay.validation,artifact_replay=:not_executed,
            full_failure_trajectory_replay=:not_executed,
            original_failure_output_attribution=:not_proven,
            origin=failed_state_origin_evidence,
            source_q1_4_candidate_hash=string(continuation_source.context.candidate_hash),
            source_q1_4_context_hash=string(continuation_source.context.context_hash),
            candidate_hash=string(context.candidate_hash),context_hash=string(context.context_hash),
            input_hash=input_hash,declaration_hash=declaration_hash,
            primary_sha256=artifact_binding.primary_sha256,
            saved_state_hash=replay.state_hash,
            solver_exit_code=replay.solver_exit_code,status=replay.status,
            numerical_status=replay.numerical_status,stopping_reason=replay.stopping_reason,
            accepted_update_count=replay.accepted_update_count,
            final_scaled_residual_max=replay.final_scaled_residual_max,
            global_rows=size(fd,1),full_unknown_columns=size(fd,2),
            method=:centered_finite_difference_of_independent_shared_node_residual,
            production_to_oracle_scaled_residual_delta=final_oracle_delta,
            scaled_relative_infinity_error=fd_relative,threshold=5.0e-6,
            manufactured_nodal_reference=manufactured_nodal_reference,
            bounded_linearized_check=linearized_check,
            nonlinear_solve=:not_reexecuted,formal_credit=false,convergence_credit=false,
            physical_validation=:unsupported,authority=:no_publish)
        else
        (schema="spatial-global-weak-q1_8-saved-failed-state-ray-diagnostic-v1",
            diagnostic_scope=:supplied_saved_state_only,acceptance=:not_assessed,
            validation=replay.validation,artifact_replay=:not_executed,
            full_failure_trajectory_replay=:not_executed,
            original_failure_output_attribution=:not_proven,
            origin=failed_state_origin_evidence,
            source_q1_4_candidate_hash=string(continuation_source.context.candidate_hash),
            source_q1_4_context_hash=string(continuation_source.context.context_hash),
            candidate_hash=string(context.candidate_hash),context_hash=string(context.context_hash),
            input_hash=input_hash,declaration_hash=declaration_hash,
            primary_sha256=artifact_binding.primary_sha256,saved_state_hash=replay.state_hash,
            solver_exit_code=replay.solver_exit_code,status=replay.status,
            numerical_status=replay.numerical_status,stopping_reason=replay.stopping_reason,
            accepted_update_count=replay.accepted_update_count,
            final_scaled_residual_max=replay.final_scaled_residual_max,
            finite_difference=:not_executed,full_unknown_columns=0,full_global_rows=0,
            scaled_relative_infinity_error=nothing,threshold=nothing,
            production_to_oracle_scaled_residual_delta=final_oracle_delta,
            bounded_linearized_check=linearized_check,
            alpha_one_endpoint_probe=armijo_probe===nothing || !hasproperty(armijo_probe,:alpha_one_status) ? nothing :
                (status=armijo_probe.alpha_one_status,trial=armijo_probe.alpha_one_trial,
                    residual_captured=armijo_probe.alpha_one_endpoint_residual_captured),
            quartic_ray_armijo_probe=if armijo_probe===nothing || !hasproperty(armijo_probe,:quartic_alpha)
                (status=:not_run,reason=:linear_step_not_eligible)
            elseif armijo_probe.quartic_alpha===nothing
                (status=:not_run,reason=:no_interior_quartic_minimum,
                    alpha_one_status=armijo_probe.alpha_one_status)
            else
                (status=armijo_probe.status,alpha=armijo_probe.alpha,candidate_kind=:quartic_ray,
                    evaluated=armijo_probe.evaluated,armijo=armijo_probe.armijo,
                    strict_decrease=armijo_probe.strict_decrease,
                    objective_after=armijo_probe.objective_after,evaluation=armijo_probe.evaluation)
            end,
            lm_damping_comparison=armijo_probe===nothing ||
                !hasproperty(armijo_probe,:lm_damping_comparison) ? nothing :
                armijo_probe.lm_damping_comparison,
            nonlinear_solve=:not_reexecuted,formal_credit=false,convergence_credit=false,
            physical_validation=:unsupported,authority=:no_publish)
        end
        mkdir(consumer_dir)
        islink(consumer_dir) || lowercase(normpath(realpath(consumer_dir)))==lowercase(expected_consumer) ||
            error("Q1_8 failed-state diagnostic output escaped its producer root")
        diagnostic_path=joinpath(consumer_dir,phase===:diagnostic_failed_state_fd ?
            "q1_8_saved_failed_state_full_fd_diagnostic.json" :
            "q1_8_saved_failed_state_ray_diagnostic.json")
        write(diagnostic_path,canonical_json(diagnostic)*"\n")
        if phase===:diagnostic_failed_state_fd
            println("SMGW_PHASE_END=q1_8_saved_failed_state_full_fd fd_relative_error=",fd_relative,
                " columns=",size(fd,2)," diagnostic_only=true report=",diagnostic_path);flush(stdout)
        else
            println("SMGW_PHASE_END=q1_8_saved_failed_state_ray quartic_alpha=",
                armijo_probe===nothing || !hasproperty(armijo_probe,:quartic_alpha) ? nothing : armijo_probe.quartic_alpha,
                " fd=not_executed diagnostic_only=true report=",diagnostic_path);flush(stdout)
        end
        return nothing
    end
    level===:q1_4 && test_source_backed_inhouse_interface_geometry_v1(data,data.initial_state,
        context.candidate_hash,input)
    println("SMGW_PHASE_BEGIN=$(level)_independent_csv_oracle_fd");flush(stdout)
    fd_initial_state=continuation_source===nothing ? data.initial_state :
        Float64.(collect(replay.initial_state))
    continuation_source===nothing || (fd_initial_state!==data.initial_state &&
        Tuple(data.initial_state)==geometry_initial_state) ||
        error("$level continuation modified the original geometry initial state")
    initial_actual=S.assemble_spatial_global_weak_system_v1(declaration,data,fd_initial_state;
        flux_Wb=input.flux.nominal_Wb,jacobian=true)
    initial_oracle=O.assemble(input,grid,fd_initial_state;order=3,scaling=declaration.scaling)
    _assert_q1_globalweak_rowspace(level,initial_actual,spec,"initial_actual")
    _assert_q1_globalweak_rowspace(level,initial_oracle,spec,"initial_oracle")
    initial_oracle_delta=_assert_q1_level_oracle_assembly(level,initial_actual,initial_oracle,"initial_csv_geometry")
    final_actual=S.assemble_spatial_global_weak_system_v1(declaration,data,state;
        flux_Wb=input.flux.nominal_Wb,jacobian=true)
    final_oracle=O.assemble(input,grid,state;order=3,scaling=declaration.scaling)
    _assert_q1_globalweak_rowspace(level,final_actual,spec,"final_actual")
    _assert_q1_globalweak_rowspace(level,final_oracle,spec,"final_oracle")
    final_oracle_delta=_assert_q1_level_oracle_assembly(level,final_actual,final_oracle,"csv_derived_final")
    columns=repeat([declaration.scaling.B_T,declaration.scaling.B_T,
        declaration.scaling.B_T,declaration.scaling.p_Pa],div(length(fd_initial_state),4))
    fd=if level===:q1_8
        O.finite_difference_jacobian(input,grid,fd_initial_state;order=3,column_scales=columns)
    else
        O.finite_difference_jacobian(input,grid,fd_initial_state;order=3)
    end
    actual_scaled=Diagonal(1.0./initial_actual.row_scales)*Matrix(initial_actual.jacobian)*Diagonal(columns)
    fd_scaled=Diagonal(1.0./initial_oracle.row_scales)*fd*Diagonal(columns)
    fd_relative=norm(actual_scaled-fd_scaled,Inf)/max(norm(actual_scaled,Inf),eps(Float64))
    size(fd)==(spec.global_rows,spec.unknowns) ||
        error("$level independent centered FD did not cover its complete column/row space")
    isfinite(fd_relative) && fd_relative<=5.0e-6 ||
        error("$level independent centered finite-difference gate failed")
    solver=primary.solver
    Int(primary.solver_exit_code)==0 && primary.status=="converged" &&
        primary.numerical_status=="full_discrete_residual_converged" &&
        Float64(primary.final_scaled_residual_max)<=1.0e-6 &&
        wire_digest(solver.operator_binding.candidate_hash)==string(context.candidate_hash) &&
        wire_digest(solver.operator_binding.context_hash)==string(context.context_hash) ||
        error("$level consumer numerical or operator-binding gate failed")
    receipt_payload=(schema="spatial-global-weak-$(level)-independent-consumer-receipt-v1",
        level,input_revision=input.revision,input_hash=string(canonical_hash(input)),
        declaration_hash=string(canonical_hash(declaration)),candidate_hash=string(context.candidate_hash),
        context_hash=string(context.context_hash),producer_result_hash=artifact_binding.result_hash,
        producer_primary_sha256=artifact_binding.primary_sha256,
        producer_artifact_set_hash=artifact_binding.artifact_set_hash,
        geometry_artifact_set_hash=artifact_binding.geometry_artifact_set_hash,
        unknowns=spec.unknowns,ownership_rows=spec.ownership_rows,
        globalweak_residual_rows=spec.global_rows,
        artifact_replay=:passed,initial_oracle_scaled_residual_delta=initial_oracle_delta,
        csv_final_oracle_scaled_residual_delta=final_oracle_delta,
        independent_centered_fd_relative_error=fd_relative,fd_threshold=5.0e-6,
        solver_exit_code=Int(primary.solver_exit_code),
        final_scaled_residual_max=Float64(primary.final_scaled_residual_max),
        nonlinear_solve=:executed,formal_refinement_gate=:outstanding,
        physical_validation=:unsupported,authority=:no_publish)
    receipt_path=joinpath(consumer_dir,"$(level)_validation_receipt.json")
    ispath(receipt_path) && error("preserve existing $level validation receipt")
    mkdir(consumer_dir)
    islink(consumer_dir) || lowercase(normpath(realpath(consumer_dir)))==lowercase(expected_consumer) ||
        error("$level consumer evidence directory escaped its producer root")
    write(receipt_path,canonical_json(receipt_payload)*"\n")
    println("SMGW_PHASE_END=$(level)_independent_csv_oracle_fd fd_relative_error=",fd_relative)
    println("SMGW_CONSUMER_PHASE_COMPLETE=$(level)_validate result=",artifact_binding.result_hash);flush(stdout)
    nothing
end

function _q1_8_failed_state_origin_v1(origin_path,out,continuation_root)
    repo=realpath(REPO)
    invocation_path=realpath(String(origin_path))
    startswith(lowercase(normpath(relpath(invocation_path,repo))),"..") &&
        throw(ArgumentError("failed-state origin must be inside this workspace"))
    invocation=JSON3.read(read(invocation_path,String))
    invocation["status"]=="TERMINAL" && Int(invocation["outer_exit_code"])==1 ||
        throw(ArgumentError("failed-state origin must be the terminal failed bounded invocation"))
    outer_argv=String.(collect(invocation["outer_argv"]))
    positions=findall(==("--output-dir"),outer_argv)
    length(positions)==1 && first(positions)<length(outer_argv) ||
        throw(ArgumentError("failed-state origin has no unique bounded output root"))
    bounded_arg=outer_argv[first(positions)+1]
    bounded_dir=normpath(isabspath(bounded_arg) ? bounded_arg : joinpath(repo,bounded_arg))
    isdir(bounded_dir) || throw(ArgumentError("failed-state bounded receipt directory is absent"))
    receipt_path=joinpath(bounded_dir,"receipt.json")
    before_path=joinpath(bounded_dir,"source_pins_before.json")
    after_path=joinpath(bounded_dir,"source_pins_after.json")
    receipt=JSON3.read(read(receipt_path,String))
    before_wire=read(before_path,String); after_wire=read(after_path,String)
    JSON3.write(JSON3.read(before_wire))==JSON3.write(JSON3.read(after_wire)) ||
        throw(ArgumentError("failed-state producer source pins changed during execution"))
    receipt["source_pins_unchanged"]===true && receipt["executable_pin_unchanged"]===true &&
        receipt["rss_accounting_incomplete"]===false && receipt["stop_reason"]===nothing &&
        receipt["resource_audit_coverage"]["complete"]===true ||
        throw(ArgumentError("failed-state producer bounded resource/source audit is incomplete"))
    memory_limit=4*1024^3
    Int(receipt["job_memory_limit_bytes"])==memory_limit &&
        Int(receipt["process_tree_rss_limit_bytes"])<=memory_limit &&
        Int(receipt["peak_job_commit_bytes"])<=memory_limit &&
        Int(receipt["peak_sampled_tree_rss_bytes"])<=memory_limit ||
        throw(ArgumentError("failed-state producer exceeded the bounded memory policy"))
    Int(receipt["actual_child_os_exit_code"])==1 ||
        throw(ArgumentError("failed-state producer child exit is not the expected numerical-failure exit"))
    active=receipt["job_active_processes_after_run"]
    (active isa Integer ? Int(active)==0 : active isa AbstractVector && isempty(active)) ||
        throw(ArgumentError("failed-state producer still owns an active process"))
    hasproperty(receipt,:pending_process_sample_handles) &&
        !isempty(receipt.pending_process_sample_handles) &&
        throw(ArgumentError("failed-state producer has pending resource sample handles"))
    argv=String.(collect(receipt["argv"]))
    script_index=findfirst(==("test/RuntimeV4/SpatialMultiRegionGlobalWeakV1/global_weak_consumer_tests_v1.jl"),argv)
    script_index!==nothing && script_index+2<=length(argv) &&
        argv[script_index+1]=="--produce-q1_8" ||
        throw(ArgumentError("failed-state origin did not run the Q1_8 producer"))
    producer_root=normpath(isabspath(argv[script_index+2]) ? argv[script_index+2] : joinpath(repo,argv[script_index+2]))
    realpath(producer_root)==realpath(out) ||
        throw(ArgumentError("failed-state origin does not name this producer artifact root"))
    continuation_arg=findfirst(==("--continuation-q1_4"),argv)
    continuation_arg!==nothing && continuation_arg<length(argv) ||
        throw(ArgumentError("failed-state origin does not bind its Q1_4 continuation"))
    continuation=normpath(isabspath(argv[continuation_arg+1]) ? argv[continuation_arg+1] : joinpath(repo,argv[continuation_arg+1]))
    realpath(continuation)==realpath(continuation_root) ||
        throw(ArgumentError("failed-state origin continuation root differs from the consumer input"))
    pins=JSON3.read(before_wire)
    provider_pin=pins["src/RuntimeV4/SpatialManufacturedInputV1.jl"]
    (invocation_sha256=bytes2hex(SHA.sha256(codeunits(read(invocation_path,String)))),
        receipt_sha256=S._smgw_sha256_file_v1(receipt_path),
        source_pins_sha256=S._smgw_sha256_file_v1(before_path),
        provider_source_sha256=String(provider_pin["sha256"]),
        child_exit_code=Int(receipt["actual_child_os_exit_code"]),
        resource_audit_complete=true,
        resource_audit_samples=Int(receipt["resource_audit_coverage"]["samples"]),
        producer_root=producer_root,continuation_root=continuation,argv=Tuple(argv))
end

consumer_q1_4_main(out,consumer_output_dir=joinpath(out,"q1_4_consumer"),phase::Symbol=:validate;
        inhouse_result_path=nothing,interior_map::Symbol=:circular_v1)=
    consumer_q1_level_main(out,consumer_output_dir,phase,:q1_4;inhouse_result_path,interior_map)
consumer_q1_8_main(out,consumer_output_dir=joinpath(out,"q1_8_consumer"),phase::Symbol=:validate;
        continuation_q1_4_root=nothing,failed_state_origin=nothing)=
    consumer_q1_level_main(out,consumer_output_dir,phase,:q1_8;
        continuation_q1_4_root=continuation_q1_4_root,failed_state_origin=failed_state_origin)

function main(args)
    continuation_q1_4_root=nothing
    failed_state_origin=nothing
    inhouse_result_path=nothing
    if length(args)>=4 && args[end-1]=="--inhouse-result"
        inhouse_result_path=String(args[end])
        args=args[1:end-2]
    end
    if length(args)>=2 && args[end-1]=="--failed-state-origin"
        args[end]=="" && error("--failed-state-origin needs an actual_invocation.json path")
        failed_state_origin=String(args[end])
        args=args[1:end-2]
    end
    if length(args)>=4 && args[end-1]=="--continuation-q1_4"
        args[1] in ("--produce-q1_8","--consume-q1_8") ||
            error("--continuation-q1_4 is supported only by --produce-q1_8 and --consume-q1_8")
        continuation_q1_4_root=String(args[end])
        args=args[1:end-2]
    end
    length(args)==3 && args[1]=="--diagnose-q1_8-continuation-seed" ||
    (length(args)==2 && args[1] in ("--produce","--consume") ||
        length(args)==2 && args[1]=="--produce-q1_4" ||
        length(args)==2 && args[1]=="--produce-q1_8" ||
        length(args)==4 && args[1]=="--consume-q1_4" && args[3]=="--phase" ||
        length(args)==5 && args[1]=="--consume-q1_4" && args[4]=="--phase" ||
        length(args)==4 && args[1]=="--consume-q1_8" && args[3]=="--phase" ||
        length(args)==5 && args[1]=="--consume-q1_8" && args[4]=="--phase" ||
        length(args)==4 && args[1]=="--candidate-identity" && args[3]=="--branch" ||
        length(args)==3 && args[1]=="--consume" ||
        length(args)==4 && args[1]=="--consume" && args[3]=="--phase" ||
        length(args)==5 && args[1]=="--consume" && args[4]=="--phase") ||
        error("expected --produce OUTPUT_DIR, --produce-q1_4 OUTPUT_DIR, --produce-q1_8 OUTPUT_DIR [--continuation-q1_4 Q1_4_ROOT], --consume-q1_4 OUTPUT_DIR [CONSUMER_OUTPUT_DIR] --phase validate|inhouse_kkt_probe|inhouse_full_nonlinear_solve|inhouse_final_replay [--inhouse-result RESULT_JSON], --consume-q1_8 OUTPUT_DIR [CONSUMER_OUTPUT_DIR] --phase validate [--continuation-q1_4 Q1_4_ROOT], --candidate-identity OUTPUT_DIR --branch default|loads_only|bounded_only|loads_bounded|manufactured|negative_identity|negative_revision|negative_missing_loads, --consume OUTPUT_DIR [CONSUMER_OUTPUT_DIR], or --consume OUTPUT_DIR [CONSUMER_OUTPUT_DIR] --phase diagnostics|identity_replay|inhouse_produce|inhouse_validate|inhouse_replay|csv_oracle|integrity_relocation_positive|integrity_csv_active_dof_rehashed|integrity_csv_only_active_dof_rehashed|integrity_csv_duplicate_node_rehashed|integrity_csv_malformed_node_rehashed|integrity_stale_candidate_binding|integrity_stale_context_binding|integrity_finalize; no solver runs at include time")
    out=abspath(args[2])
    mode=String(args[1])
    failed_state_origin===nothing || mode=="--consume-q1_8" ||
        error("--failed-state-origin is supported only by --consume-q1_8")
    inhouse_result_path===nothing || mode=="--consume-q1_4" ||
        error("--inhouse-result is supported only by --consume-q1_4")
    if mode=="--diagnose-q1_8-continuation-seed"
        length(args)==3 || error("Q1_8 seed diagnostic needs Q1_4_ROOT and DIAGNOSTIC_DIR")
        q1_8_continuation_seed_diagnostic_v1(args[2],args[3])
    elseif mode=="--produce-q1_4"
        producer_q1_4_main(out)
    elseif mode=="--produce-q1_8"
        producer_q1_8_main(out;continuation_q1_4_root=continuation_q1_4_root)
    elseif mode=="--consume-q1_4"
        phase=Symbol(args[end])
        phase in (:validate,:inhouse_kkt_probe,:inhouse_full_nonlinear_solve,:inhouse_final_replay) ||
            error("unknown Q1_4 consumer phase: $phase")
        (phase===:inhouse_final_replay)==(inhouse_result_path!==nothing) ||
            error("Q1_4 --inhouse-result is required only with --phase inhouse_final_replay")
        consumer_output_dir=length(args)==4 ? joinpath(out,"q1_4_consumer") :
            (isabspath(args[3]) ? args[3] : joinpath(out,args[3]))
        resolved_inhouse_result=inhouse_result_path===nothing ? nothing :
            (isabspath(inhouse_result_path) ? inhouse_result_path : joinpath(out,inhouse_result_path))
        consumer_q1_4_main(out,consumer_output_dir,phase;inhouse_result_path=resolved_inhouse_result)
    elseif mode=="--consume-q1_8"
        phase=Symbol(args[end])
        phase in (:validate,:diagnostic_failed_state_fd,:diagnostic_failed_state_ray) || error("unknown Q1_8 consumer phase: $phase")
        consumer_output_dir=length(args)==4 ? joinpath(out,"q1_8_consumer") :
            (isabspath(args[3]) ? args[3] : joinpath(out,args[3]))
        consumer_q1_8_main(out,consumer_output_dir,phase;
            continuation_q1_4_root=continuation_q1_4_root,failed_state_origin=failed_state_origin)
    elseif mode=="--produce"
        producer_main(out)
    elseif mode=="--candidate-identity"
        candidate_identity_main(out,String(args[4]))
    else
        has_phase=length(args)>=4
        consumer_output_dir=length(args)==3 || length(args)==5 ?
            (isabspath(args[3]) ? args[3] : joinpath(out,args[3])) : joinpath(out,"consumer")
        phase=has_phase ? Symbol(args[end]) : :all
        has_phase && !(phase in _CONSUMER_PHASES_V1) && error("unknown consumer phase: $phase")
        consumer_main(out,consumer_output_dir,phase)
    end
end

end

if abspath(PROGRAM_FILE)==abspath(@__FILE__)
    if Sys.iswindows() && ((length(ARGS) in (2,4) && ARGS[1]=="--produce-q1_8" &&
            (length(ARGS)==2 || ARGS[3]=="--continuation-q1_4")) ||
            (length(ARGS)==3 && ARGS[1]=="--diagnose-q1_8-continuation-seed") ||
            (length(ARGS)==9 && ARGS[1]=="--consume-q1_8" && ARGS[4]=="--phase" &&
                ARGS[5] in ("diagnostic_failed_state_fd","diagnostic_failed_state_ray") && ARGS[6]=="--continuation-q1_4" &&
                ARGS[end-1]=="--failed-state-origin"))
        task=Task(() -> SpatialMultiRegionGlobalWeakV1Tests.main(ARGS),16*1024*1024)
        schedule(task)
        fetch(task)
    else
        SpatialMultiRegionGlobalWeakV1Tests.main(ARGS)
    end
end
