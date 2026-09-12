# Same-candidate assessment of executed spatial physics and engineering.
using FusionConceptAI
import FusionConceptAI:canonical_hash,semantic_view

struct SpatialStageExecutionV4
    stage::Symbol
    declaration_complete::Bool
    model_implemented::Bool
    executed::Bool
    status::Symbol
    exit_code::Union{Nothing,Int}
    dependency_links_valid::Bool
    physical_upstream_valid::Bool
    metrics::NamedTuple
    scope::String
    remaining::Tuple
end
semantic_view(x::SpatialStageExecutionV4)=NamedTuple{fieldnames(typeof(x))}(Tuple(getfield(x,k) for k in fieldnames(typeof(x))))

struct SpatialWholeDeviceResultV4
    candidate_hash::Digest256
    context_hash::Digest256
    input_hashes::NamedTuple
    stages::Tuple
    status::Symbol
    spatial_execution_minimum_reached::Bool
    physical_validation::Symbol
    p5_ready::Bool
    credible_device_count::Int
    result_hash::Digest256
end
semantic_view(x::SpatialWholeDeviceResultV4)=NamedTuple{fieldnames(typeof(x))[1:end-1]}(Tuple(getfield(x,k) for k in fieldnames(typeof(x))[1:end-1]))
function canonical_hash(x::SpatialWholeDeviceResultV4)
    x.status===:deferred && x.physical_validation===:unsupported && !x.p5_ready && x.credible_device_count==0 || error("unsupported spatial whole-device authority")
    canonical_hash(semantic_view(x))==x.result_hash || error("spatial whole result hash differs")
    x.result_hash
end

function assess_spatial_whole_device_v4(context,upstream,physics,engineering,verification)
    # Producer validators run at stage boundaries in the runner; this assessment
    # also checks all result seals/identities but does not relaunch any solve.
    for x in (physics,engineering,verification)
        canonical_hash(x)
        x.candidate_hash==context.candidate_hash && x.context_hash==context.context_hash || error("cross-candidate spatial assessment")
    end
    validate_spatial_upstream_link_v4(upstream,physics)
    engineering.physics_hash==canonical_hash(physics) && verification.physics_hash==canonical_hash(physics) &&
        verification.engineering_hash==canonical_hash(engineering) && verification.upstream_hash==canonical_hash(upstream) ||
        error("whole-device inputs belong to different execution snapshots")
    ids=Tuple(c.case_id for c in physics.cases)
    ids==("nominal_coarse","nominal_fine","flux_low_coarse","flux_high_coarse") || error("incomplete spatial scenarios")
    Tuple(c.case_id for c in engineering.cases)==ids || error("engineering scenario coverage differs")
    minimum_reached=physics.executed && engineering.executed && all(c->c.executed,physics.cases) && all(c->c.executed,engineering.cases)
    s=SpatialStageExecutionV4
    case_metrics=Tuple((case_id=c.case_id,unknowns=length(c.final_state),flux_Wb=c.flux_Wb,
        status=c.status,solver_exit_code=c.solver_exit_code,stopping_reason=c.stopping_reason,
        initial_iteration=first(c.iterations),final_iteration=last(c.iterations),diagnostics=c.diagnostics,
        state_hash=c.state_hash) for c in physics.cases)
    engineering_metrics=Tuple((case_id=c.case_id,status=c.status,solver_exit_code=c.solver_exit_code,
        static=c.static,geometry=c.geometry,current_closure=c.current_closure,
        conditional_nominal=c.conditional.nominal.metrics,conditional_short=c.conditional.readout_short.metrics) for c in engineering.cases)
    stages=(
        s(:declaration,true,true,true,:observed,0,true,true,
            (regions=length(physics.declaration.regions),cases=ids,state_fields=physics.declaration.states),
            "Owned full-torus spatial fields, sources, all interfaces/exterior conditions and one finite-aperture pickup subsystem.",()),
        s(:upstream_DESC,true,true,upstream.result.provider_executed,:observed,upstream.result.receipt.exit_code,true,false,
            (inspection_exit_code=upstream.result.receipt.inspection_exit_code,),
            "Fresh same-revision DESC geometry and initializer; process exit alone is not physical validity.",
            ((kind=:missing_evidence,detail="Initializer convergence and physical applicability are not inferred from process exit."),)),
        s(:spatial_multiregion,true,true,physics.executed,physics.status,physics.solver_exit_code,true,false,
            (cases=case_metrics,primary_case_id=physics.primary_case_id),
            "Full declared local Q1 weak residual and all-state sparse Jacobian, actual coupled solve attempts in both spaces and both flux endpoints.",
            ((kind=:calculation,detail="Retain actual solver stops and raw residual blocks; a failed iterate is not an equilibrium."),
             (kind=:missing_model,detail="Pressure/current-topology uniqueness, transport/time evolution and external closure remain unresolved."))),
        s(:engineering_control_fault,true,true,engineering.executed,engineering.status,engineering.solver_exit_code,true,
            all(c->c.physical_upstream_valid,engineering.cases),
            (cases=engineering_metrics,),
            "Actual current quadrature to finite-aperture magnetic flux. Static zero EMF and separately imposed-ramp exact RL/short/protection.",
            ((kind=:missing_model_or_data,detail="Total external coils, outer sheet/return currents, component applicability and solved plasma dynamics are absent."),)),
        s(:numerical_verification,true,true,verification.executed,verification.numerical.status,verification.solver_exit_code,true,false,
            verification.numerical,"Independent field/weak-strong implementation, every-column derivative checks, analytic nonzero-source MMS and exact circuit audit.",
            ((kind=:missing_evidence,detail="No certified quadrature bound or converged physical mesh-error estimate is asserted."),)),
        s(:deterministic_propagation,true,true,verification.executed,verification.status,verification.solver_exit_code,true,false,
            verification.uncertainty,"Actual candidate-declared flux endpoint solves and current-to-engineering propagation; no probability law.",
            ((kind=:missing_data,detail="Input probability distributions and model-discrepancy evidence unavailable; failed-state ranges remain conditional."),)),
        s(:physical_validation,false,false,false,:unsupported,nothing,true,false,verification.physical_validation,
            "No applicable observations or independent physical solver dataset was supplied.",
            ((kind=:missing_data,detail="Candidate-applicable validation observations, uncertainty and discrepancy basis."),)),
        s(:whole_device_assessment,true,true,true,:deferred,0,true,false,
            (spatial_execution_minimum_reached=minimum_reached,p5_ready=false,credible_device_count=0),
            "Same-candidate dependency assessment executed; no device feasibility authority.",
            ((kind=:missing_model,detail="Broader device engineering, dynamic physics and physical validation remain absent."),)))
    body=(candidate_hash=context.candidate_hash,context_hash=context.context_hash,
        input_hashes=(upstream=canonical_hash(upstream),physics=canonical_hash(physics),engineering=canonical_hash(engineering),verification=canonical_hash(verification)),
        stages=stages,status=:deferred,spatial_execution_minimum_reached=minimum_reached,
        physical_validation=:unsupported,p5_ready=false,credible_device_count=0)
    result=SpatialWholeDeviceResultV4(values(body)...,canonical_hash(body));canonical_hash(result);result
end

function write_spatial_whole_device_v4(result,dir)
    canonical_hash(result)
    write(joinpath(dir,"result.json"),canonical_json(semantic_view(result))*"\n")
    open(joinpath(dir,"result.md"),"w") do io
        println(io,"# Spatial candidate execution\n\nCandidate: `",result.candidate_hash,"`.\n")
        println(io,"| Stage | Declared | Implemented | Executed | Status | Exit | Dependency links valid | Physical upstream valid |\n|---|---|---|---|---|---|---|---|")
        for s in result.stages
            println(io,"| ",s.stage," | ",s.declaration_complete," | ",s.model_implemented," | ",s.executed," | ",s.status," | ",s.exit_code," | ",s.dependency_links_valid," | ",s.physical_upstream_valid," |")
        end
        for s in result.stages
            println(io,"\n## ",s.stage,"\n\n",s.scope,"\n\nMetrics: `",repr(s.metrics),"`\n")
            for g in s.remaining;println(io,"- ",g.kind,": ",g.detail);end
        end
    end
end
