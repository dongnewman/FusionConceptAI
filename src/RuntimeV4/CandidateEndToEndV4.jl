"""Same-candidate execution ledger and conservative whole-device assessment."""

# Retain concrete replay inputs for reports made in this process. This is not
# an evidence/authority registry: every write repeats the actual validators.
const _CANDIDATE_CHAIN_REPLAY_INPUTS = Dict{Digest256,Tuple}()

struct CandidateEndToEndResultV4
    revision::String
    identity::CandidateChainIdentityV4
    stages::NTuple{6,CandidateChainStageV4}
    dependency_queue::Tuple{Vararg{CandidateChainGapV4}}
    outcome::Symbol
    whole_device_assessment_executed::Bool
    whole_device_physics_executed::Bool
    terminal_authority::Bool
    p5_ready::Bool
    credible_device_count::Int
    claim_ceiling::ClaimCeiling
    result_hash::Digest256
    function CandidateEndToEndResultV4(::Val{:candidate_chain_execution}, args...)
        new(args...)
    end
end
semantic_view(x::CandidateEndToEndResultV4) = NamedTuple{fieldnames(typeof(x))[1:end-1]}(
    ntuple(i -> getfield(x,i),fieldcount(typeof(x))-1))

function canonical_hash(x::CandidateEndToEndResultV4)
    canonical_hash(x.identity)
    x.revision == _CANDIDATE_CHAIN_REVISION && x.outcome === :deferred &&
        x.whole_device_assessment_executed && !x.whole_device_physics_executed &&
        !x.terminal_authority && !x.p5_ready && x.credible_device_count == 0 &&
        x.claim_ceiling === screen_only || throw(ArgumentError("invalid whole-device claim"))
    Tuple(s.stage for s in x.stages) == _CANDIDATE_CHAIN_STAGES ||
        throw(ArgumentError("missing, duplicate, or reordered stage"))
    all(s -> canonical_hash(s) == s.stage_hash &&
        s.identity_hash == x.identity.identity_hash, x.stages) ||
        throw(ArgumentError("mixed candidate or invalid stage"))
    expected_executed = (
        (:three_genome_identity,:typed_graph_binding,:scenario_binding),
        (:desc_equilibrium_provider,:regional_field_sampling,:interface_traction,
         :weak_volume_moments,:strong_force_moments,:sample_constitutive_jacobian),
        (:candidate_g3_declaration_audit,:sampled_plasma_momentum_load_projection),
        (:midpoint_cubature,:periodic_vector_reconstruction,:local_force_norm_integration,
         :analytic_integration_benchmark,:observed_error_spread_propagation),
        (:validation_and_uncertainty_prerequisite_audit,),
        (:same_candidate_stage_audit,:dependency_queue_assessment))
    expected_unexecuted = ((),
        (:external_source_term,:complete_boundary_term,:complete_weak_residual,
         :full_state_jacobian,:global_conservation,:actual_multiregion_coupled_solve),
        (:material_response,:structural_response,:thermal_hydraulics,:power_balance,
         :control_dynamics,:protection_dynamics,:fault_dynamics),
        (:certified_discretization_error,:independent_physics_code_validation),
        (:held_out_physical_validation,:parameter_uncertainty_propagation,
         :model_form_uncertainty_propagation),
        (:high_fidelity_integrated_execution,:whole_device_validation,:terminal_physical_classification))
    Tuple(s.executed_components for s in x.stages) == expected_executed &&
        Tuple(s.unexecuted_components for s in x.stages) == expected_unexecuted ||
        throw(ArgumentError("execution components exceed this bound implementation"))
    x.dependency_queue == Tuple(g for s in x.stages for g in s.gaps) ||
        throw(ArgumentError("dependency queue differs from stage gaps"))
    h=canonical_hash(semantic_view(x))
    h == x.result_hash || throw(ArgumentError("end-to-end result hash mismatch"))
    h
end

"Rebuild from the actual upstream artifacts before accepting an external ledger."
function validate_candidate_end_to_end(result::CandidateEndToEndResultV4,args...)
    canonical_hash(result)
    rebuilt = build_candidate_end_to_end(args...)
    canonical_hash(rebuilt) == canonical_hash(result) ||
        throw(ArgumentError("ledger differs from actual same-candidate execution"))
    result.result_hash
end

function _chain_bound_to(context, result)
    canonical_hash(result)
    result.candidate_hash == context.candidate_hash &&
        result.context_hash == context.context_hash ||
        throw(ArgumentError("downstream result belongs to another candidate/context"))
end

function _chain_independent_envelope(execution)
    all(!getproperty(execution,key) for key in (:independent_code_validation,
        :physical_validation,:validation_uq,:promotion_authority,:terminal_authority)) &&
        execution.credible_device_count==0 && execution.evidence_credit==0 &&
        execution.claim_ceiling===screen_only ||
        throw(ArgumentError("independent quadrature envelope exceeds numerical observation"))
end

function build_candidate_end_to_end(upstream, traction_request, traction_result,
        q2_request, q2_result, q2_execution, q3_execution, q4_execution,
        independent_execution, physics::CandidateCoupledPhysicsResultV4,
        engineering::CandidateEngineeringExecutionV4,
        validation::CandidateValidationPropagationResultV4)
    context = first(upstream)
    identity = make_candidate_chain_identity(context)
    _chain_independent_envelope(independent_execution)
    for result in (physics, engineering, validation)
        _chain_bound_to(context, result)
    end
    # Acceptance uses actual upstream replay, not hash-only caller attestations.
    validate_candidate_coupled_physics(upstream, independent_execution, physics)
    validate_candidate_engineering_execution(context, upstream,
        traction_request, traction_result, engineering)
    validate_candidate_validation_propagation(validation, upstream,
        traction_request, traction_result, q2_request, q2_result, q2_execution,
        q3_execution, q4_execution, independent_execution)

    nunit = UnitSignature((1,1,-2,0,0,0,0))
    paunit = UnitSignature((1,-1,-2,0,0,0,0))
    unitless = UnitSignature()
    metric(name,value,unit,scope) = CandidateChainMetricV4(name,value,unit,scope)
    gap(stage,code,status,pre,input,check) = CandidateChainGapV4(stage,code,status,pre,input,check)
    binding = _candidate_chain_stage(identity, :candidate_binding,
        (canonical_hash(context),), :observed,
        (:three_genome_identity, :typed_graph_binding, :scenario_binding), (), (), ())

    pgaps = (
        gap(:multi_region_physics, :candidate_owned_region_partition_and_interface_laws,
            :deferred, (:candidate_binding,),
            "Genome-owned region/support/adjacency and constitutive/interface AST declarations",
            "Prove exact ownership and coverage of the current downstream diagnostic rho partition"),
        gap(:multi_region_physics, :candidate_weak_form_declaration, :deferred,
            (:candidate_binding,),
            "Candidate-owned test space, full state DOFs, body/source and boundary laws with typed ownership",
            "Compile all G1/G2 terms and Jacobian columns; no inferred zero source"),
        gap(:multi_region_physics, :complete_boundary_quadrature, :unsupported,
            (:candidate_binding,),
            "Exterior and interface boundary quadrature, oriented geometric normals, boundary-limit traces",
            "Execute both exterior and interface terms with paired ownership and convergence checks"),
        gap(:multi_region_physics, :global_conservation_and_coupled_solve, :deferred,
            (:candidate_binding,),
            "Complete candidate residual/Jacobian and production state-update provider",
            "Execute global conservation ledger and actual coupled solve with recorded solver exit and residual history"))
    p = _candidate_chain_stage(identity, :multi_region_physics,
        (canonical_hash(upstream[6]), canonical_hash(traction_result), canonical_hash(physics)),
        :deferred,
        (:desc_equilibrium_provider, :regional_field_sampling, :interface_traction,
         :weak_volume_moments, :strong_force_moments, :sample_constitutive_jacobian),
        (:external_source_term, :complete_boundary_term, :complete_weak_residual,
         :full_state_jacobian, :global_conservation, :actual_multiregion_coupled_solve),
        (metric(:jacobian_fd_max_scaled_error,physics.jacobian_fd_max_scaled_error,
            unitless,"sampled constitutive Jacobian only"),), pgaps)

    egaps = Tuple(gap(:engineering_control_fault, g.code, g.status,
        (:multi_region_physics,), join(g.required_inputs,"; "),
        "Bind to this G3 and real physical loads; execute the declared model and record outputs")
        for g in engineering.gaps)
    es = candidate_engineering_summary(engineering)
    e = _candidate_chain_stage(identity, :engineering_control_fault,
        (canonical_hash(traction_result),canonical_hash(engineering)), :unsupported,
        (:candidate_g3_declaration_audit, :sampled_plasma_momentum_load_projection),
        (:material_response, :structural_response, :thermal_hydraulics, :power_balance,
         :control_dynamics, :protection_dynamics, :fault_dynamics),
        (metric(:max_sampled_traction_Pa,es.max_sampled_traction_Pa,paunit,
            "finite-offset plasma interface proxy; not a component load"),
         metric(:independent_traction_difference_Pa,
            es.maximum_independent_traction_difference_Pa,paunit,"constitutive replay comparison")), egaps)

    ngaps = (gap(:numerical_verification, :unconverged_local_residual_integral,
        validation.numerical_status === :fail ? :fail : :deferred,
        (:multi_region_physics,),
        "Independent error-controlled quadrature and complete weak residual",
        "Demonstrate convergence of local residual norm; full-torus net-force cancellation is insufficient"),
        gap(:numerical_verification, :independent_physics_implementation, :unsupported,
        (:multi_region_physics,), "Independent physical solver/formulation for the same candidate",
        "Match units, state, geometry, boundary conditions, and applicability before comparison"))
    d = last(validation.quadrature_diagnostics).value
    n = _candidate_chain_stage(identity, :numerical_verification,
        (canonical_hash(independent_execution.result),canonical_hash(validation)),
        validation.numerical_status,
        (:midpoint_cubature, :periodic_vector_reconstruction, :local_force_norm_integration,
         :analytic_integration_benchmark, :observed_error_spread_propagation),
        (:certified_discretization_error, :independent_physics_code_validation),
        (metric(:local_force_integral_relative_spread,
            validation.local_force_integral_relative_spread,unitless,"Gauss3/Gauss4/midpoint formulation spread"),
         metric(:midpoint_integrated_local_force_magnitude_N,d.local_force_magnitude_integral_N,
            nunit,"integral of local force magnitude; not net force"),
         metric(:observed_resultant_spread_upper_N,last(validation.force_spread.resultant_norm_interval_N),
            nunit,"observed spread only; neither certified error bound nor confidence interval")),ngaps)

    vgaps = Tuple(gap(:validation_uq,g.kind,g.status,
        (:multi_region_physics,:engineering_control_fault),g.detail,
        "Execute candidate-applicable held-out comparison or declared uncertainty propagation with provenance")
        for g in validation.gaps if g.kind in (:physical_validation,:parameter_uq,:model_form_uq))
    v = _candidate_chain_stage(identity, :validation_uq,
        (canonical_hash(validation),canonical_hash(engineering)), :unsupported,
        (:validation_and_uncertainty_prerequisite_audit,),
        (:held_out_physical_validation, :parameter_uncertainty_propagation,
         :model_form_uncertainty_propagation),(),vgaps)
    wgaps = (gap(:whole_device,:integrated_physical_engineering_validation_closure,:deferred,
        (:multi_region_physics,:engineering_control_fault,:numerical_verification,:validation_uq),
        "All required same-candidate stage executions and admissible evidence",
        "Revalidate complete provider coverage and integrated outcomes; missing evidence cannot be promoted"),)
    w = _candidate_chain_stage(identity,:whole_device,
        Tuple(canonical_hash(s) for s in (p,e,n,v)),:deferred,
        (:same_candidate_stage_audit,:dependency_queue_assessment),
        (:high_fidelity_integrated_execution,:whole_device_validation,:terminal_physical_classification),(),wgaps)
    stages=(binding,p,e,n,v,w)
    body=(revision=_CANDIDATE_CHAIN_REVISION,identity=identity,stages=stages,
        dependency_queue=Tuple(g for s in stages for g in s.gaps),outcome=:deferred,
        whole_device_assessment_executed=true,whole_device_physics_executed=false,
        terminal_authority=false,p5_ready=false,credible_device_count=0,claim_ceiling=screen_only)
    result=CandidateEndToEndResultV4(_CANDIDATE_CHAIN_TOKEN,values(body)...,canonical_hash(body))
    canonical_hash(result)
    _CANDIDATE_CHAIN_REPLAY_INPUTS[result.result_hash] = (upstream,traction_request,
        traction_result,q2_request,q2_result,q2_execution,q3_execution,q4_execution,
        independent_execution,physics,engineering,validation)
    result
end

function write_candidate_chain_report(result::CandidateEndToEndResultV4, run_dir, inputs...)
    canonical_hash(result)
    raw = isempty(inputs) ? get(_CANDIDATE_CHAIN_REPLAY_INPUTS,result.result_hash,nothing) : inputs
    raw === nothing && throw(ArgumentError("report requires actual same-candidate replay inputs"))
    validate_candidate_end_to_end(result,raw...)
    mkpath(run_dir)
    write(joinpath(run_dir,"result.json"),canonical_json(semantic_view(result))*"\n")
    open(joinpath(run_dir,"result.md"),"w") do io
        println(io,"# Current candidate end-to-end execution\n")
        println(io,"Candidate: `",result.identity.candidate_ref,"` (`",result.identity.candidate_hash,"`).\n")
        println(io,"Outcome: **deferred**. Whole-device assessment executed; integrated whole-device physics did not. Credible devices: **0**.\n")
        println(io,"| Stage | Status | Actually executed | Not executed |\n|---|---|---|---|")
        for s in result.stages
            println(io,"| ",s.stage," | ",s.status," | ",join(s.executed_components,", "),
                " | ",join(s.unexecuted_components,", ")," |")
        end
        println(io,"\n## Measured quantities\n")
        for s in result.stages, m in s.metrics
            println(io,"- `",m.name," = ",m.value,"`; SI dimensions ",m.unit.exponents,". ",m.scope,".")
        end
        println(io,"\n## Recoverable dependency queue\n")
        for g in result.dependency_queue
            println(io,"- **",g.stage," / ",g.code,"** (`",g.status,"`): ",g.required_input,
                ". Acceptance: ",g.acceptance_check,".")
        end
    end
    joinpath(run_dir,"result.md")
end
