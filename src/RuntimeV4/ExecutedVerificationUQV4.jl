#= Executed numerical verification and deterministic scenario propagation.

Independent implementation checks are software evidence. This module never
converts an exploratory design interval into a probability distribution or
claims experimental validation from a solver comparison.
=#
using LinearAlgebra
using SHA
using Serialization
import FusionConceptAI: semantic_view, canonical_hash, Digest256

const _EVUQ_SOURCE_V4 = abspath(@__FILE__)
const _EVUQ_REVISION_V4 = "executed-verification-uq-v1"
_evuq_file_hash(path) = Digest256(bytes2hex(SHA.sha256(read(path))))

struct ExecutedValidationDeclarationV4
    revision::String
    independent_formulation::Symbol
    jacobian_protocol::NamedTuple
    analytic_benchmark::NamedTuple
    propagation::NamedTuple
    physical_validation::NamedTuple
end
semantic_view(x::ExecutedValidationDeclarationV4) = NamedTuple{fieldnames(typeof(x))}(Tuple(getfield(x,k) for k in fieldnames(typeof(x))))

function validation_declaration_v4()
    ExecutedValidationDeclarationV4(_EVUQ_REVISION_V4,
        :raw_cartesian_maxwell_cauchy_stress_moments,
        (scheme=:central_all_state_columns,step_rule=:cbrt_epsilon_scaled,
         relative_tolerance=1e-7,comparison_scope=:software_derivative_verification),
        (problem=:piecewise_constant_emf_linear_RL,scope=:software_equation_verification,
         physical_validation_credit=0),
        (method=:deterministic_cartesian_endpoints,
         parameters=(:loop_radius_m,:resistivity_ohm_m,:load_resistance_ohm),
         interval_owner=:G3_engineering_declaration,
         coupled_parameter=:reference_pressure_multiplier,
         coupled_interval_owner=:G2_multiregion_declaration,
         distribution=:none,confidence_interval=:unsupported,
         applicability=:conditional_on_fixed_candidate_physics_and_declared_design_range),
        (status=:unsupported,experimental_dataset_count=0,
         independent_physical_solver=false,model_discrepancy_basis=false,
         recovery="Candidate-applicable independent observations, units, uncertainty and held-out comparison protocol; or independently applicable physical solver and model discrepancy evidence."))
end

struct ExecutedVerificationUQResultV4
    candidate_hash::Digest256
    context_hash::Digest256
    status::Symbol
    executed::Bool
    solver_exit_code::Int
    declaration_hash::Digest256
    upstream_hash::Digest256
    physics_hash::Digest256
    engineering_hash::Digest256
    numerical::NamedTuple
    propagation::NamedTuple
    physical_validation::NamedTuple
    upstream_validity::NamedTuple
    artifacts::Tuple
    source_hash::Digest256
    result_hash::Digest256
end
semantic_view(x::ExecutedVerificationUQResultV4) = NamedTuple{fieldnames(typeof(x))[1:end-1]}(ntuple(i->getfield(x,i),fieldcount(typeof(x))-1))

function canonical_hash(x::ExecutedVerificationUQResultV4)
    x.executed && x.solver_exit_code in (0,1) || throw(ArgumentError("verification execution state invalid"))
    x.physical_validation.status === :unsupported &&
        x.physical_validation.experimental_dataset_count == 0 ||
        throw(ArgumentError("this execution has no physical validation data"))
    x.propagation.distribution === :none && x.propagation.confidence_interval === :unsupported ||
        throw(ArgumentError("deterministic design scenarios cannot imply a distribution"))
    isfile(_EVUQ_SOURCE_V4) && _evuq_file_hash(_EVUQ_SOURCE_V4) == x.source_hash ||
        throw(ArgumentError("verification source bytes changed"))
    for artifact in x.artifacts
        isfile(artifact.path) && _evuq_file_hash(artifact.path) == artifact.sha256 ||
            throw(ArgumentError("verification artifact bytes changed"))
    end
    payload=deserialize(first(x.artifacts).path)
    expected_payload=(candidate_hash=x.candidate_hash,context_hash=x.context_hash,
        numerical=x.numerical,propagation=x.propagation,physical_validation=x.physical_validation)
    canonical_hash(payload)==canonical_hash(expected_payload) ||
        throw(ArgumentError("verification result differs from actual serialized output bytes"))
    checks_pass=x.numerical.physics.status===:pass && x.numerical.engineering.status===:pass &&
        all(c->c.independent_residual_status===:pass,x.propagation.coupled_pressure_sensitivity.cases)
    x.status===(checks_pass ? :executed_conditional : :fail) &&
        x.solver_exit_code==(checks_pass ? 0 : 1) || throw(ArgumentError("verification status does not match executed checks"))
    result_hash=canonical_hash(semantic_view(x))
    result_hash == x.result_hash || throw(ArgumentError("verification result hash mismatch"))
    result_hash
end

"""Central differences of every state column, independent of an analytic J."""
function verification_full_jacobian_v4(residual, state, analytic_jacobian;
        relative_tolerance=1e-7)
    x=Float64.(collect(state)); reference=Float64.(analytic_jacobian)
    nrows=length(residual(x)); size(reference)==(nrows,length(x)) ||
        throw(ArgumentError("Jacobian must contain every residual row and state column"))
    finite_difference=zeros(nrows,length(x)); steps=zeros(length(x))
    for k in eachindex(x)
        h=cbrt(eps(Float64))*max(abs(x[k]),1.0); steps[k]=h
        plus=copy(x); minus=copy(x); plus[k]+=h; minus[k]-=h
        finite_difference[:,k]=(residual(plus)-residual(minus))/(2h)
    end
    denominator=max(norm(reference),eps(Float64))
    relative_error=norm(finite_difference-reference)/denominator
    column_errors=Tuple(norm(finite_difference[:,k]-reference[:,k])/
        max(norm(reference[:,k]),eps(Float64)) for k in eachindex(x))
    (executed=true,status=all(isfinite,finite_difference) && relative_error<=relative_tolerance ? :pass : :fail,
     row_count=nrows,column_count=length(x),relative_error=relative_error,
     column_relative_errors=column_errors,steps=Tuple(steps),
     finite_difference_rows=Tuple(Tuple(row) for row in eachrow(finite_difference)),
     scope=:software_derivative_verification,physical_validation_credit=0)
end

"""Independent transformed linear least-squares lower bound for R=C*[a1²,c1,a2²,c2]+d.

The unconstrained transformed optimum is a lower bound even if it requires
negative a² or pressure. It is not substituted for the actual nonlinear solve.
"""
function verification_residual_floor_v4(coefficients, constant, row_scales, state)
    C=Float64.(coefficients); d=Float64.(collect(constant)); scales=Float64.(collect(row_scales))
    size(C)==(length(d),4) && length(scales)==length(d) && all(>(0),scales) ||
        throw(ArgumentError("invalid four-state weak system"))
    A=C./scales; b=d./scales
    factor=svd(A); cutoff=maximum(factor.S)*max(size(A)...)*eps(Float64)
    inverse_singular=map(s->s>cutoff ? inv(s) : 0.0,factor.S)
    y=-(factor.V*(inverse_singular.*(factor.U'*b)))
    lower=norm(A*y+b)
    x=Float64.(collect(state)); actual_y=[x[1]^2,x[2],x[3]^2,x[4]]
    actual=norm(A*actual_y+b)
    (executed=true,method=:independent_svd_transformed_linear_system,
     rank=count(>(cutoff),factor.S),singular_values=Tuple(factor.S),
     transformed_unconstrained_state=Tuple(y),
     unconstrained_scaled_residual_floor=lower,
     actual_scaled_residual=actual,
     squared_objective_excess=max(0.0,actual^2-lower^2),
     transformed_solution_nonnegative=all(>=(0),y),
     interpretation="Residual floor is unconstrained model/discrete-test incompatibility at this quadrature. Excess above an infeasible unconstrained floor combines declared-bound cost and algorithmic suboptimality; a constrained optimum is required to separate them. Neither is an integration-error estimate.")
end

_evuq_parameter(d,name) = only(p for p in d.parameters if p.name===name)
_evuq_nominal(d,name) = Float64(_evuq_parameter(d,name).nominal)

"""Exact unprotected RL response to a rectangular emf, including the decay."""
function verification_rl_exact_v4(B::Real,decl,t::Real; overrides=NamedTuple())
    p(name)=haskey(overrides,name) ? Float64(getproperty(overrides,name)) : _evuq_nominal(decl,name)
    radius=p(:loop_radius_m); N=p(:turns); wire_radius=p(:wire_radius_m)
    rw=p(:resistivity_ohm_m)*(N*2pi*radius)/(pi*wire_radius^2)
    resistance=rw+p(:load_resistance_ohm); L=p(:series_inductance_H)
    area=N*pi*radius^2; ramp_time=p(:ramp_duration_s)
    emf=-area*Float64(B)*p(:ramp_fraction)/ramp_time
    tau=L/resistance; active=min(max(Float64(t),0.0),ramp_time)
    current_end=emf/resistance*(-expm1(-active/tau))
    integral_active=emf/resistance*(active-tau*(-expm1(-active/tau)))
    decay=max(Float64(t)-ramp_time,0.0)
    current=current_end*exp(-decay/tau)
    integral=integral_active+current_end*tau*(-expm1(-decay/tau))
    (current_A=current,current_peak_A=abs(emf/resistance*(-expm1(-ramp_time/tau))),
     reconstructed_delta_B_T=-p(:load_resistance_ohm)*integral/area,
     wire_resistance_ohm=rw,time_constant_s=tau,
     scope=:analytic_software_verification_unprotected_nominal_RL)
end

function verification_engineering_propagation_v4(engineering; declaration=engineering_declaration_v4())
    names=validation_declaration_v4().propagation.parameters
    parameters=Tuple(_evuq_parameter(declaration,n) for n in names)
    all(p->length(p.interval)==2 && all(isfinite,p.interval) &&
        p.interval[1]<=p.nominal<=p.interval[2] && !isempty(p.source) && !isempty(p.unit),parameters) ||
        throw(ArgumentError("propagation inputs need declared, sourced finite intervals and SI units"))
    B=Float64(engineering.B_projected_T); isfinite(B) || throw(ArgumentError("nonfinite genuine physics field"))
    cases=NamedTuple[]
    for endpoints in Iterators.product((p.interval for p in parameters)...)
        overrides=NamedTuple{names}(Tuple(Float64.(endpoints)))
        response=magnetic_pickup_response_v4(B;declaration=declaration,overrides=overrides,fault=:none)
        push!(cases,(scenario_hash=canonical_hash((engineering_hash=canonical_hash(engineering),
                declaration_hash=canonical_hash(declaration),overrides=overrides)),
            overrides=overrides,metrics=response.metrics,
            response_hash=canonical_hash(response)))
    end
    observables=(:induced_emf_peak_V,:current_peak_A,:reconstructed_delta_B_T,:joule_energy_J)
    ranges=Tuple((observable=name,min=minimum(getproperty(c.metrics,name) for c in cases),
        max=maximum(getproperty(c.metrics,name) for c in cases)) for name in observables)
    (executed=true,status=:executed_conditional,method=:deterministic_cartesian_endpoints,
     case_count=length(cases),parameters=parameters,cases=Tuple(cases),ranges=ranges,
     distribution=:none,confidence_interval=:unsupported,
     interval_interpretation=:evaluated_design_corner_range_not_certified_global_bound,
     candidate_variation=false,physics_recomputed=false,
     fixed_physics_result_hash=engineering.physics_result_hash,
     upstream_status=engineering.upstream_status,
     applicability_status=engineering.applicability_status,
     physical_validation_credit=0)
end

function verification_engineering_numerics_v4(engineering; declaration=engineering_declaration_v4())
    nominal=only(s for s in engineering.scenarios if s.fault===:none)
    dt=_evuq_nominal(declaration,:time_step_s)
    fine=magnetic_pickup_response_v4(engineering.B_projected_T;
        declaration=declaration,fault=:none,dt_override=dt/2)
    function compare(response)
        # The last step that triggers a relay is still governed by nominal R.
        rows=Tuple(row for row in response.trajectory if row.readout_connected)
        exact=Tuple(verification_rl_exact_v4(engineering.B_projected_T,declaration,row.t_s) for row in rows)
        currents=Tuple(abs(row.current_A-e.current_A) for (row,e) in zip(rows,exact))
        reconstruction=Tuple(abs(row.reconstructed_delta_B_T-e.reconstructed_delta_B_T) for (row,e) in zip(rows,exact))
        (sample_count=length(rows),last_compared_time_s=last(rows).t_s,
         maximum_current_error_A=maximum(currents),
         maximum_reconstruction_error_T=maximum(reconstruction),
         final_compared_exact=last(exact),
         entire_nominal_trajectory_compared=length(rows)==length(response.trajectory))
    end
    coarse_comparison=compare(nominal); fine_comparison=compare(fine)
    ce=coarse_comparison.maximum_current_error_A; fe=fine_comparison.maximum_current_error_A
    decreases=fe<=ce*(1+1e-10)+1e-14
    order=ce>1e-14 && fe>1e-14 ? log2(ce/fe) : nothing
    (executed=true,status=decreases ? :pass : :fail,
     independent_analytic_formulation=:piecewise_exponential_RL,
     coarse=coarse_comparison,fine=fine_comparison,
     time_discretization=(coarse_dt_s=dt,fine_dt_s=dt/2,
        maximum_current_error_observed_order=order,
        endpoint_reconstructed_field_difference_T=abs(nominal.metrics.reconstructed_delta_B_T-fine.metrics.reconstructed_delta_B_T),
        energy_defect_coarse_J=nominal.metrics.integrated_energy_balance_defect_J,
        energy_defect_fine_J=fine.metrics.integrated_energy_balance_defect_J,
        backward_euler_dissipation_coarse_J=nominal.metrics.backward_euler_numerical_dissipation_J,
        backward_euler_dissipation_fine_J=fine.metrics.backward_euler_numerical_dissipation_J,
        interpretation="Backward Euler numerical dissipation is separate from its discrete algebraic energy identity residual."),
     solve_error=(maximum_discrete_circuit_residual_V=nominal.metrics.maximum_circuit_residual_V,
        discrete_energy_identity_error_J=nominal.metrics.discrete_energy_identity_error_J),
     fine_response=fine,physical_validation_credit=0)
end

function verification_coupled_pressure_sensitivity_v4(physics,engineering)
    parameter=only(p for p in physics.declaration.parameters if p.name===:reference_pressure_multiplier)
    parameter.value==1.0 && parameter.interval[1]<=1.0<=parameter.interval[2] &&
        !isempty(parameter.source) && !isempty(parameter.unit) || throw(ArgumentError("sourced G2 pressure interval required"))
    samples=_evuq_read_raw_samples(physics.execution.raw_samples_path)
    mu0=only(p.value for p in physics.declaration.parameters if p.name===:mu0)
    lengthscale=only(p.value for p in physics.declaration.parameters if p.name===:test_reference_length)
    cases=NamedTuple[]
    for q in parameter.interval
        solve=solve_multiregion_state_v4(physics;pressure_multiplier=q)
        independent=verification_raw_weak_residual_v4(samples,solve.final_state;
            mu0=mu0,reference_length_m=lengthscale,pressure_multiplier=q)
        scale=Float64.(collect(physics.row_scales))
        residual=Float64.(collect(solve.residual))
        difference=maximum(abs,(independent.residual-residual)./scale)
        # Same raw outer field and same point/orientation as the actual engineering
        # input, with the scenario's newly solved outer regional amplitude.
        B=engineering.B_projected_T*solve.final_state[3]/physics.final_state[3]
        circuit=magnetic_pickup_response_v4(B;fault=:none)
        realization=(candidate_hash=physics.candidate_hash,physics_result_hash=canonical_hash(physics),
            engineering_result_hash=canonical_hash(engineering),parameter=parameter.name,value=q,
            input_sample_hash=canonical_hash(engineering.input_sample))
        push!(cases,(realization_hash=canonical_hash(realization),parameter_value=q,
            physics_executed=true,physics_solver_exit_code=solve.solver_exit_code,
            physics_stopping_reason=solve.stopping_reason,physics_status=solve.status,
            final_state=solve.final_state,iteration_history=solve.iterations,
            final_scaled_residual_norm=norm(residual./scale),
            independent_residual_maximum_scaled_difference=difference,
            independent_residual_status=difference<=1e-10 ? :pass : :fail,
            B_projected_T=B,engineering_executed=true,engineering_solver_exit_code=circuit.solver_exit_code,
            engineering_metrics=circuit.metrics,circuit_response_hash=canonical_hash(circuit),
            upstream_valid=false,applicability_status=engineering.applicability_status,
            physical_validation_credit=0))
    end
    (executed=true,status=:executed_conditional,parameter=parameter,
     case_count=length(cases),cases=Tuple(cases),
     method=:declared_constitutive_interval_nonlinear_resolve_and_circuit_propagation,
     fixed_geometry=true,fixed_DESC_reference_B=true,DESC_equilibrium_recomputed=false,
     interpretation="Pressure scales the declared constitutive and prescribed exterior terms. New reduced states and circuit responses are executed; this is not equilibrium-profile uncertainty.")
end

function _evuq_owned_declaration(context)
    validate_forward_chain_context(context)
    declarations=Tuple(d for d in context.candidate.realization_control_genome_ref.control
        if d isa ExecutedValidationDeclarationV4)
    length(declarations)==1 || throw(ArgumentError("one G3-owned verification declaration required"))
    declaration=only(declarations)
    canonical_hash(declaration)==canonical_hash(validation_declaration_v4()) ||
        throw(ArgumentError("verification declaration revision is not implemented"))
    declaration
end

function _evuq_read_raw_samples(path)
    lines=readlines(path); header=split(first(lines),'\t')
    expected=split("kind region rho theta zeta x y z Bx By Bz p Jx Jy Jz gradpx gradpy gradpz nx ny nz measure")
    header==expected || throw(ArgumentError("independent oracle raw schema mismatch"))
    rows=NamedTuple[]
    for line in lines[2:end]
        parts=split(line,'\t'); length(parts)==22 || throw(ArgumentError("malformed raw sample"))
        values=Dict(String(k)=>parse(Float64,v) for (k,v) in zip(header[2:end],parts[2:end]))
        all(isfinite,Base.values(values)) || throw(ArgumentError("nonfinite oracle input"))
        getvec(a,b,c)=(values[a],values[b],values[c])
        kind=Symbol(parts[1]); owner=Int(values["region"])
        kind in (:volume,:interface,:exterior) && values["measure"]>0 || throw(ArgumentError("invalid domain sample"))
        kind===:volume && !(owner in (1,2)) && throw(ArgumentError("missing regional ownership"))
        kind===:interface && values["rho"]!=0.5 && throw(ArgumentError("interface sample is not exact rho=.5"))
        kind===:exterior && values["rho"]!=1.0 && throw(ArgumentError("exterior sample is not exact rho=1"))
        push!(rows,(kind=kind,owner=owner,position=getvec("x","y","z"),B=getvec("Bx","By","Bz"),
            pressure=values["p"],J=getvec("Jx","Jy","Jz"),gradp=getvec("gradpx","gradpy","gradpz"),
            normal=getvec("nx","ny","nz"),weight=values["measure"]))
    end
    all(k->any(r->r.kind===k,rows),(:volume,:interface,:exterior)) || throw(ArgumentError("missing complete weak integration domain"))
    rows
end

"""Independent scalar stress contraction; never calls the physics assembler."""
function verification_raw_weak_residual_v4(samples,state;mu0=1.25663706127e-6,reference_length_m=1.0,pressure_multiplier=1.0)
    x=Float64.(collect(state)); length(x)==4 || throw(ArgumentError("four states required"))
    residual=zeros(36); volume=zeros(24); natural=zeros(24); strong=zeros(24)
    interface=zeros(24); exterior=zeros(24); jump=zeros(12)
    for s in samples
        b2=sum(v*v for v in s.B)
        stress(a,c,k,l)=(a*a/mu0)*(s.B[k]*s.B[l]-(k==l ? b2/2 : 0.0))-
            (k==l ? c*pressure_multiplier*s.pressure : 0.0)
        basis=(1.0,s.position[1]/reference_length_m,s.position[2]/reference_length_m,s.position[3]/reference_length_m)
        if s.kind===:volume
            region=s.owner
            # grad(phi_l e_k) has one nonzero entry; direct scalar contraction.
            for component in 1:3, coordinate in 1:3
                row=(region-1)*12+coordinate*3+component
                volume[row]-=s.weight*stress(x[2region-1],x[2region],component,coordinate)/reference_length_m
            end
            lorentz=(s.J[2]*s.B[3]-s.J[3]*s.B[2],s.J[3]*s.B[1]-s.J[1]*s.B[3],s.J[1]*s.B[2]-s.J[2]*s.B[1])
            force=ntuple(k->x[2region-1]^2*lorentz[k]-pressure_multiplier*x[2region]*s.gradp[k],3)
            for test in 1:4, component in 1:3
                row=(region-1)*12+(test-1)*3+component
                strong[row]+=s.weight*basis[test]*force[component]
            end
        elseif s.kind===:interface
            traction=ntuple(region->ntuple(k->sum(stress(x[2region-1],x[2region],k,l)*s.normal[l] for l in 1:3),3),2)
            for test in 1:4, component in 1:3
                localrow=(test-1)*3+component; w=s.weight*basis[test]
                flux=(traction[1][component]+traction[2][component])/2
                interface[localrow]+=w*flux; interface[12+localrow]-=w*flux
                jump[localrow]+=w*(traction[1][component]-traction[2][component])
                natural[localrow]+=w*traction[1][component]
                natural[12+localrow]-=w*traction[2][component]
            end
        else
            reference_traction=ntuple(k->sum(stress(1.0,1.0,k,l)*s.normal[l] for l in 1:3),3)
            actual_traction=ntuple(k->sum(stress(x[3],x[4],k,l)*s.normal[l] for l in 1:3),3)
            for test in 1:4, component in 1:3
                row=12+(test-1)*3+component; w=s.weight*basis[test]
                exterior[row]+=w*reference_traction[component]
                natural[row]+=w*actual_traction[component]
            end
        end
    end
    residual[1:24]=volume+interface+exterior
    residual[25:36]=jump
    (residual=residual,volume=volume,interface=interface,exterior=exterior,jump=jump,
     explicit_zero_body_source=zeros(24),strong_moments=strong,natural_weak_moments=volume+natural,
     differential_identity_discrepancy=strong-volume-natural)
end

function verification_physics_numerics_v4(physics)
    validate_raw=_evuq_file_hash(physics.execution.raw_samples_path)
    validate_raw==physics.execution.raw_samples_sha256 || throw(ArgumentError("physics raw bytes differ"))
    samples=_evuq_read_raw_samples(physics.execution.raw_samples_path)
    parameters=physics.declaration.parameters
    mu0=only(p.value for p in parameters if p.name===:mu0)
    lengthscale=only(p.value for p in parameters if p.name===:test_reference_length)
    independent(x;q=1.0)=verification_raw_weak_residual_v4(samples,x;mu0=mu0,
        reference_length_m=lengthscale,pressure_multiplier=q)
    evaluated=independent(physics.final_state)
    J=reduce(vcat,(reshape(collect(row),1,:) for row in physics.full_state_jacobian))
    derivative=verification_full_jacobian_v4(x->independent(x).residual,physics.final_state,J)
    production=Float64.(collect(physics.residual)); scales=Float64.(collect(physics.row_scales))
    difference=norm(evaluated.residual-production)
    scaled_difference=maximum(abs,(evaluated.residual-production)./scales)
    C=reduce(vcat,(reshape(collect(row),1,:) for row in physics.coefficient_matrix))
    constant=Float64.(collect(physics.constant_magnetic)).+Float64.(collect(physics.constant_pressure))
    floor=verification_residual_floor_v4(C,constant,scales,physics.final_state)
    identity=evaluated.differential_identity_discrepancy
    source_or_stress_scale=max(norm(evaluated.strong_moments),norm(evaluated.volume),norm(evaluated.natural_weak_moments),1.0)
    residual_check=(executed=true,status=scaled_difference<=1e-10 ? :pass : :fail,
        residual_rows=36,absolute_difference_N=difference,maximum_scaled_difference=scaled_difference,
        independent_residual=Tuple(evaluated.residual),scope=:independent_implementation_same_physical_model,
        raw_samples_sha256=validate_raw,exact_surface_sampling=true)
    (executed=true,status=residual_check.status===:pass && derivative.status===:pass ? :pass : :fail,
     residual_crosscheck=residual_check,full_state_jacobian=derivative,
     solve_error=floor,
     integration_diagnostic=(executed=true,status=:diagnostic_only,
        formulation=:independent_strong_volume_vs_natural_weak_moments,
        discrepancy_rows_N=Tuple(identity),discrepancy_norm_N=norm(identity),
        stress_normalized_discrepancy=norm(identity)/source_or_stress_scale,
        quadrature_error_estimate=:unsupported,
        interpretation="This discrepancy combines current quadrature, derivative/metric consistency and representation identities. No refinement or independent field derivative evidence isolates pure quadrature error."),
     spatial_discretization=(executed=false,status=:unsupported,implementation=:not_implemented,
        reason="No candidate-bound enriched-state/test-space solve; four amplitudes and affine moments do not establish spatial convergence."),
     model_residual=(final_weak_norm_N=norm(production),final_scaled_weak_norm=norm(production./scales),
        strong_force_rms_N_m3=physics.diagnostics.strong_force_rms_N_m3,
        pointwise_interface_traction_jump_peak_Pa=physics.diagnostics.pointwise_interface_traction_jump_peak_Pa,
        upstream_equilibrium_convergence=physics.diagnostics.upstream_equilibrium_convergence,
        interpretation="Actual residual of the declared reduced ansatz; physical model bias is unknown."),
     physical_validation_credit=0)
end

function execute_verification_uq_v4(context,upstream,physics,engineering,run_dir;kwargs...)
    isempty(kwargs) || throw(ArgumentError("verification controls belong to the frozen candidate declaration"))
    declaration=_evuq_owned_declaration(context)
    validate_multiregion_result_v4(context,physics)
    validate_engineering_result_v4(context,physics,engineering)
    physics.candidate_hash==engineering.candidate_hash==context.candidate_hash &&
        physics.context_hash==engineering.context_hash==context.context_hash || throw(ArgumentError("foreign candidate verification input"))
    canonical_hash(upstream.request)==physics.execution.upstream_request_hash &&
        canonical_hash(upstream.result)==physics.execution.upstream_result_hash || throw(ArgumentError("verification upstream receipt mismatch"))
    numerical_physics=verification_physics_numerics_v4(physics)
    numerical_engineering=verification_engineering_numerics_v4(engineering)
    propagation=merge(verification_engineering_propagation_v4(engineering),
        (coupled_pressure_sensitivity=verification_coupled_pressure_sensitivity_v4(physics,engineering),))
    numerical=(physics=numerical_physics,engineering=numerical_engineering)
    checks_pass=numerical_physics.status===:pass && numerical_engineering.status===:pass &&
        all(c->c.independent_residual_status===:pass,propagation.coupled_pressure_sensitivity.cases)
    status=checks_pass ? :executed_conditional : :fail
    exit_code=status===:fail ? 1 : 0
    dir=abspath(run_dir); mkpath(dir)
    payload=(candidate_hash=context.candidate_hash,context_hash=context.context_hash,
        numerical=numerical,propagation=propagation,physical_validation=declaration.physical_validation)
    raw_path=joinpath(dir,"numerical_and_propagation.jls")
    serialize(raw_path,payload)
    readable=joinpath(dir,"numerical_and_propagation.txt")
    open(readable,"w") do io; show(io,MIME("text/plain"),payload); println(io);end
    code_path=joinpath(dir,"verification.exitcode"); write(code_path,string(exit_code)*"\n")
    artifacts=Tuple((path=abspath(p),sha256=_evuq_file_hash(p)) for p in (raw_path,readable,code_path))
    body=(candidate_hash=context.candidate_hash,context_hash=context.context_hash,status=status,
        executed=true,solver_exit_code=exit_code,declaration_hash=canonical_hash(declaration),
        upstream_hash=canonical_hash((request=upstream.request,result=upstream.result)),
        physics_hash=canonical_hash(physics),engineering_hash=canonical_hash(engineering),
        numerical=numerical,propagation=propagation,physical_validation=declaration.physical_validation,
        upstream_validity=(physics_status=physics.status,physics_solver_exit_code=physics.solver_exit_code,
            engineering_status=engineering.status,engineering_solver_exit_code=engineering.solver_exit_code,
            engineering_upstream_valid=engineering.upstream_valid,
            engineering_applicability=engineering.applicability_status,physical_qualification=false),
        artifacts=artifacts,source_hash=_evuq_file_hash(_EVUQ_SOURCE_V4))
    result=ExecutedVerificationUQResultV4(values(body)...,canonical_hash(body)); canonical_hash(result); result
end

function validate_verification_uq_result_v4(context,upstream,physics,engineering,result::ExecutedVerificationUQResultV4)
    validate_multiregion_result_v4(context,physics)
    validate_engineering_result_v4(context,physics,engineering)
    result.candidate_hash==context.candidate_hash && result.context_hash==context.context_hash &&
        result.declaration_hash==canonical_hash(_evuq_owned_declaration(context)) &&
        result.physics_hash==canonical_hash(physics) && result.engineering_hash==canonical_hash(engineering) &&
        result.upstream_hash==canonical_hash((request=upstream.request,result=upstream.result)) ||
        throw(ArgumentError("verification input/declaration binding mismatch"))
    canonical_hash(result)
end
