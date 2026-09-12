# Actual revised-candidate stage execution and conservative whole-device assessment.
using FusionConceptAI
import FusionConceptAI: canonical_hash,semantic_view

struct RevisedStageExecutionV4
    stage::Symbol
    declaration_complete::Bool
    model_implemented::Bool
    executed::Bool
    status::Symbol
    exit_code::Union{Nothing,Int}
    upstream_valid::Bool
    metrics::NamedTuple
    scope::String
    remaining::Tuple
end
semantic_view(x::RevisedStageExecutionV4)=NamedTuple{fieldnames(typeof(x))}(Tuple(getfield(x,k) for k in fieldnames(typeof(x))))

struct RevisedWholeDeviceResultV4
    candidate_hash::Digest256
    context_hash::Digest256
    input_hashes::NamedTuple
    stages::Tuple{Vararg{RevisedStageExecutionV4}}
    status::Symbol
    declared_reduced_execution_minimum_reached::Bool
    full_function_space_mhd_solved::Bool
    physical_validation::Symbol
    p5_ready::Bool
    credible_device_count::Int
    result_hash::Digest256
end
semantic_view(x::RevisedWholeDeviceResultV4)=NamedTuple{fieldnames(typeof(x))[1:end-1]}(Tuple(getfield(x,k) for k in fieldnames(typeof(x))[1:end-1]))
function canonical_hash(x::RevisedWholeDeviceResultV4)
    x.status===:deferred && !x.full_function_space_mhd_solved &&
        x.physical_validation===:unsupported && !x.p5_ready && x.credible_device_count==0 ||
        throw(ArgumentError("whole-device claim exceeds declared execution"))
    canonical_hash(semantic_view(x))==x.result_hash || throw(ArgumentError("whole-device hash mismatch"))
    x.result_hash
end

function assess_revised_whole_device_v4(context,upstream,physics,engineering,verification)
    validate_revised_declarations_v4(context)
    validate_multiregion_result_v4(context,physics)
    validate_engineering_result_v4(context,physics,engineering)
    validate_verification_uq_result_v4(context,upstream,physics,engineering,verification)
    s=RevisedStageExecutionV4
    stages=(
        s(:declaration,true,true,true,:observed,0,true,
            (regions=length(physics.declaration.regions),state_dofs=length(physics.initial_state),
             residual_rows=length(physics.residual),g3_scenarios=length(engineering.scenarios)),
            "Exact owned G1/G2/G3 laws for the declared reduced model; generic capability compiler remains conservative.",()),
        s(:upstream_DESC,true,true,true,:observed,upstream.result.receipt.exit_code,false,
            (inspector_exit_code=upstream.result.receipt.inspection_exit_code,max_iterations=upstream.request.runner_payload.maxiter),
            "Fresh fixed-boundary DESC solve for this revised candidate; process exit is not convergence attestation.",
            ((kind=:missing_evidence,detail="Machine-readable equilibrium convergence and solution applicability."),)),
        s(:multiregion_physics,true,true,physics.executed,physics.status,physics.solver_exit_code,false,
            (initial_state=physics.initial_state,final_state=physics.final_state,
             initial_residual=first(physics.iterations),final_residual=last(physics.iterations),
             stopping_reason=physics.stopping_reason,conservation=physics.conservation,diagnostics=physics.diagnostics),
            "Every volume/source/exterior/interface term and all Jacobian columns of the four-coefficient, 36-row static-MHD system; actual bounded nonlinear solve.",
            ((kind=:model_limitation,detail="Four amplitudes and affine tests cannot establish full-function-space MHD equilibrium or spatial convergence."),
             (kind=:computation,detail="Residual and boundary/jump diagnostics retain their actual nonclosure."))),
        s(:engineering_control_fault,true,true,engineering.executed,engineering.status,engineering.solver_exit_code,
            engineering.upstream_valid,(B_projected_T=engineering.B_projected_T,
                scenarios=Tuple((fault=r.fault,metrics=r.metrics) for r in engineering.scenarios)),
            "Faraday/RL pickup, readout integration, load-short and dump protection; real static boundary B with declared imposed ramp.",
            Tuple((kind=:missing_model_or_data,detail=x) for x in engineering.remaining_conditions)),
        s(:numerical_verification,true,true,verification.executed,verification.status,
            verification.solver_exit_code,false,verification.numerical,
            "Independent raw stress implementation, full-state finite differences, transformed SVD residual floor, analytic RL and timestep comparison.",
            ((kind=:missing_verification,detail="No isolated quadrature error estimate or enriched spatial discretization study."),)),
        s(:uncertainty_propagation,true,true,verification.executed,verification.status,verification.solver_exit_code,
            false,verification.propagation,
            "Executed deterministic design corners and fixed-geometry pressure scenarios; no probability distribution or confidence interval.",
            ((kind=:missing_data,detail="Measured parameter distributions and physical model discrepancy remain unsupported."),)),
        s(:physical_validation,false,false,false,:unsupported,nothing,false,verification.physical_validation,
            "Applicable held-out measurements and independent physical solution/model discrepancy are absent.",
            ((kind=:missing_data,detail=verification.physical_validation.recovery),)),
        s(:whole_device_assessment,true,true,true,:deferred,0,false,
            (terminal_authority=false,p5_ready=false,credible_device_count=0),
            "Same-revision stage and dependency assessment executed; integrated device physics remains incomplete.",
            ((kind=:missing_model,detail="External field/aperture coupling, transport/energy evolution, component/environment models and broader device systems."),
             (kind=:missing_validation,detail="Candidate-applicable numerical and physical validation."))))
    body=(candidate_hash=context.candidate_hash,context_hash=context.context_hash,
        input_hashes=(upstream=canonical_hash(upstream.result),physics=canonical_hash(physics),
            engineering=canonical_hash(engineering),verification=canonical_hash(verification)),
        stages=stages,status=:deferred,
        declared_reduced_execution_minimum_reached=physics.executed && engineering.executed,
        full_function_space_mhd_solved=false,physical_validation=:unsupported,p5_ready=false,credible_device_count=0)
    result=RevisedWholeDeviceResultV4(values(body)...,canonical_hash(body));canonical_hash(result);result
end

function write_revised_whole_device_v4(result,dir)
    canonical_hash(result)
    write(joinpath(dir,"result.json"),canonical_json(semantic_view(result))*"\n")
    open(joinpath(dir,"result.md"),"w") do io
        println(io,"# Revised candidate actual execution\n")
        println(io,"Candidate: `",result.candidate_hash,"`. Context: `",result.context_hash,"`.\n")
        println(io,"| Stage | Declaration | Implemented | Executed | Status | Exit | Upstream valid |")
        println(io,"|---|---|---|---|---|---|---|")
        for s in result.stages
            println(io,"| ",s.stage," | ",s.declaration_complete," | ",s.model_implemented," | ",s.executed,
                " | ",s.status," | ",s.exit_code," | ",s.upstream_valid," |")
        end
        for s in result.stages
            println(io,"\n## ",s.stage,"\n\n",s.scope,"\n\nMetrics: `",repr(s.metrics),"`\n")
            for gap in s.remaining;println(io,"- ",gap.kind,": ",gap.detail);end
        end
        println(io,"\nWhole device deferred; physical validation unsupported; P5 false; credible devices 0.")
    end
end
