#= Candidate-owned magnetic pickup circuit, integrator and protection execution.

The driving static field is a genuine exact-surface DESC output from the revised
physics run. Its imposed fractional ramp is an exploratory circuit load case,
never a measured or plasma-solved time history. No plasma traction is interpreted
as a solid load. Placement/exterior-field applicability remains unsupported.
=#
using FusionConceptAI
using LinearAlgebra
using SHA
import FusionConceptAI: semantic_view, canonical_hash, Digest256

const _MEG_SOURCE = abspath(@__FILE__)
const _MEG_REVISION = "magnetic-engineering-v4-1"
_meg_file_hash(path) = Digest256(bytes2hex(SHA.sha256(read(path))))
_meg_body(x) = NamedTuple{fieldnames(typeof(x))[1:end-1]}(
    ntuple(i -> getfield(x, i), fieldcount(typeof(x))-1))

struct MagneticDesignParameterV4
    name::Symbol
    nominal::Float64
    unit::String
    interval::NTuple{2,Float64}
    source::String
    applicability::String
    function MagneticDesignParameterV4(name, nominal, unit, interval, source, applicability)
        a, b = Float64.(interval)
        isfinite(nominal) && isfinite(a) && isfinite(b) && 0 < a <= nominal <= b ||
            throw(ArgumentError("positive finite engineering parameter and ordered design interval required"))
        !isempty(source) && !isempty(unit) && !isempty(applicability) ||
            throw(ArgumentError("engineering parameter provenance, units and scope required"))
        new(Symbol(name), Float64(nominal), String(unit), (a,b), String(source), String(applicability))
    end
end
semantic_view(x::MagneticDesignParameterV4) = (
    name=x.name, nominal=x.nominal, unit=x.unit, interval=x.interval,
    source=x.source, applicability=x.applicability)

struct MagneticEngineeringDeclarationV4
    revision::String
    subsystem_id::String
    material_model::Symbol
    parameters::Tuple{Vararg{MagneticDesignParameterV4}}
    placement::NamedTuple
    states::Tuple
    laws::Tuple{Vararg{String}}
    scenarios::Tuple
    assumptions::Tuple{Vararg{String}}
    required_operator_ids::Tuple{Vararg{String}}
end
semantic_view(x::MagneticEngineeringDeclarationV4) = (
    revision=x.revision, subsystem_id=x.subsystem_id, material_model=x.material_model,
    parameters=x.parameters, placement=x.placement, states=x.states, laws=x.laws,
    scenarios=x.scenarios, assumptions=x.assumptions, required_operator_ids=x.required_operator_ids)

function engineering_declaration_v4()
    source = "exploratory engineering design specification: magnetic_engineering_v4.md revision 1; not measured"
    scope = "ideal lumped isothermal Ohmic pickup/readout circuit; no irradiation, heat, insulation or deployment qualification"
    specs = (
        (:loop_radius_m, .005, "m", (.0045,.0055)),
        (:wire_radius_m, .0001, "m", (.0001,.0001)),
        (:turns, 10.0, "1", (10.0,10.0)),
        (:resistivity_ohm_m, 1.72e-8, "ohm*m", (1.6e-8,1.9e-8)),
        (:series_inductance_H, .001, "H", (.001,.001)),
        (:load_resistance_ohm, 10.0, "ohm", (8.0,12.0)),
        (:ramp_fraction, .1, "1", (.1,.1)),
        (:ramp_duration_s, .002, "s", (.002,.002)),
        (:duration_s, .004, "s", (.004,.004)),
        (:time_step_s, 1e-5, "s", (1e-5,1e-5)),
        (:short_time_s, .001, "s", (.001,.001)),
        (:short_resistance_ohm, .01, "ohm", (.01,.01)),
        (:trip_current_A, .02, "A", (.02,.02)),
        (:dump_resistance_ohm, 100.0, "ohm", (100.0,100.0)))
    parameters = Tuple(MagneticDesignParameterV4(s..., source, scope) for s in specs)
    MagneticEngineeringDeclarationV4(_MEG_REVISION, "local_magnetic_pickup_readout",
        :ideal_ohmic_conductor, parameters,
        (coordinate_system=:desc_rho_theta_zeta, rho=1.0, theta=0.0, zeta=0.0,
         sample_selection=:nearest_exact_outer_surface_node, disk_normal=:local_toroidal_unit,
         external_standoff_m=0.0, aperture_model=:uniform_local_field,
         exterior_extension=:unverified_boundary_continuation),
        ((name=:circuit_current, unit="A", initial=0.0),
         (name=:reconstructed_field_change, unit="T", initial=0.0),
         (name=:protection_latched, unit="1", initial=false)),
        ("Phi=N*pi*r^2*(B_exact_boundary dot e_phi)*(1+ramp_fraction*min(t/T_ramp,1))",
         "emf=-dPhi/dt; Rwire=resistivity*(N*2*pi*r)/(pi*wire_radius^2)",
         "L*di/dt+(Rwire+Rbranch)*i=emf",
         "dBhat/dt=-Rbranch*i/(N*pi*r^2) while readout connected",
         "after each step latch if abs(i)>=trip_current; next interval commutates into dump resistance"),
        ((id=:nominal, fault=:none), (id=:readout_short, fault=:load_short)),
        ("All parameter intervals are design exploration ranges without a probability distribution.",
         "The B ramp is prescribed by a declared external excitation scenario, not predicted plasma dynamics.",
         "Aperture field uniformity, physical placement and continuation across the plasma boundary are unsupported.",
         "Effective total circuit inductance is a design input; finite winding and lead inductance have not been validated.",
         "The ideal relay commutation uses a closed dump path and latches with one time-step detection delay.",
         "Resistance is isothermal; temperature, insulation, radiation and sensor back reaction are omitted."),
        ("MAGNETIC_PICKUP_FLUX_V4", "FARADAY_RL_CIRCUIT_V4", "PICKUP_INTEGRATOR_PROTECTION_V4"))
end

function _meg_parameters(declaration; overrides=NamedTuple())
    names = Tuple(p.name for p in declaration.parameters)
    length(unique(names)) == length(names) || throw(ArgumentError("duplicate engineering parameter"))
    all(k -> k in names, keys(overrides)) || throw(ArgumentError("unknown parameter override"))
    vals = Tuple(begin
        value = Float64(get(overrides, p.name, p.nominal))
        p.interval[1] <= value <= p.interval[2] || throw(ArgumentError("parameter outside declared design interval"))
        value
    end for p in declaration.parameters)
    NamedTuple{names}(vals)
end

"""Actually integrate the declared circuit. Synthetic B is allowed only in tests.

Production admission is exclusively `execute_engineering_v4`, which obtains B
from the hash-bound physics output. This pure kernel also supports deterministic
parameter sensitivity and an independent closed-form RL verification.
"""
function magnetic_pickup_response_v4(B_projected_T::Real;
        declaration=engineering_declaration_v4(), overrides=NamedTuple(),
        fault=:none, dt_override=nothing)
    isfinite(B_projected_T) || throw(ArgumentError("finite applied boundary field required"))
    fault in (:none, :load_short) || throw(ArgumentError("undeclared fault scenario"))
    p = _meg_parameters(declaration; overrides)
    dt = isnothing(dt_override) ? p.time_step_s : Float64(dt_override)
    isfinite(dt) && 0 < dt <= p.time_step_s || throw(ArgumentError("positive refinement-only timestep required"))
    p.duration_s > p.ramp_duration_s > p.short_time_s > 0 || throw(ArgumentError("invalid event order"))
    p.turns == round(p.turns) || throw(ArgumentError("integer winding count required"))
    Narea = p.turns*pi*p.loop_radius_m^2
    wire_length = p.turns*2pi*p.loop_radius_m
    Rwire = p.resistivity_ohm_m*wire_length/(pi*p.wire_radius_m^2)
    L = p.series_inductance_H
    # Inserting declared event times prevents a ramp/fault discontinuity from
    # being hidden inside a quadrature step. No artificial measured trajectory.
    n = ceil(Int, p.duration_s/dt)
    times = sort!(unique!(vcat(collect(range(0.0,p.duration_s; length=n+1)),
        [p.short_time_s,p.ramp_duration_s])))
    current = 0.0; reconstructed = 0.0; latched = false
    trip_time = nothing; input_energy=0.0; joule=0.0; be_dissipation=0.0
    max_residual=0.0; current_peak=0.0; emf_peak=0.0
    trajectory = NamedTuple[]
    push!(trajectory, (t_s=0.0, imposed_B_T=Float64(B_projected_T), emf_V=0.0,
        current_A=0.0, load_voltage_V=0.0, reconstructed_delta_B_T=0.0,
        branch_resistance_ohm=p.load_resistance_ohm, relay_latched=false,
        readout_connected=true))
    for k in 2:length(times)
        t0=times[k-1]; t1=times[k]; h=t1-t0
        ramp0=min(t0/p.ramp_duration_s,1.0)
        ramp1=min(t1/p.ramp_duration_s,1.0)
        emf = -Narea*Float64(B_projected_T)*p.ramp_fraction*(ramp1-ramp0)/h
        shorted = fault === :load_short && t0 >= p.short_time_s
        Rbranch = latched ? p.dump_resistance_ohm :
            (shorted ? p.short_resistance_ohm : p.load_resistance_ohm)
        connected = !latched
        Rtotal=Rwire+Rbranch
        next_current = (L*current+h*emf)/(L+h*Rtotal)
        voltage = Rbranch*next_current
        if connected
            reconstructed -= h*voltage/Narea
        end
        residual = L*(next_current-current)/h+Rtotal*next_current-emf
        max_residual=max(max_residual,abs(residual))
        input_energy += h*emf*next_current
        joule += h*Rtotal*next_current^2
        be_dissipation += .5L*(next_current-current)^2
        current=next_current
        if !latched && abs(current)>=p.trip_current_A
            latched=true
            trip_time=t1
        end
        current_peak=max(current_peak,abs(current)); emf_peak=max(emf_peak,abs(emf))
        push!(trajectory,(t_s=t1,
            imposed_B_T=Float64(B_projected_T)*(1+p.ramp_fraction*ramp1),
            emf_V=emf,current_A=current,load_voltage_V=voltage,
            reconstructed_delta_B_T=reconstructed,branch_resistance_ohm=Rbranch,
            relay_latched=latched,readout_connected=connected))
    end
    stored=.5L*current^2
    all(isfinite,(current,reconstructed,joule,input_energy,max_residual)) ||
        throw(ArgumentError("non-finite circuit integration"))
    metrics=(induced_emf_peak_V=emf_peak,current_peak_A=current_peak,
        final_current_A=current,reconstructed_delta_B_T=reconstructed,
        imposed_delta_B_T=Float64(B_projected_T)*p.ramp_fraction,
        joule_energy_J=joule,input_energy_J=input_energy,final_stored_energy_J=stored,
        integrated_energy_balance_defect_J=input_energy-joule-stored,
        backward_euler_numerical_dissipation_J=be_dissipation,
        discrete_energy_identity_error_J=input_energy-joule-stored-be_dissipation,
        maximum_circuit_residual_V=max_residual,trip_time_s=trip_time,
        protection_latched=latched,measurement_valid=!latched && fault===:none,
        time_step_s=dt,steps=length(times)-1)
    (fault=fault,method=:event_aligned_backward_euler,executed=true,solver_exit_code=0,
        parameters=p,derived=(N_area_m2=Narea,wire_length_m=wire_length,
            winding_resistance_ohm=Rwire,total_inductance_H=L),
        metrics=metrics,trajectory=Tuple(trajectory),
        scenario_provenance=:exploratory_prescribed_field_ramp_not_measured)
end

function _meg_owned_declaration(context)
    validate_forward_chain_context(context)
    validate_revised_declarations_v4(context)
    g3=context.candidate.realization_control_genome_ref
    declarations=Tuple(d for d in g3.realization if d isa MagneticEngineeringDeclarationV4)
    length(declarations)==1 || throw(ArgumentError("one candidate-owned engineering declaration required"))
    declaration=only(declarations)
    canonical_hash(declaration)==canonical_hash(engineering_declaration_v4()) ||
        throw(ArgumentError("engineering executor does not implement this declaration revision"))
    expected=(realization=("MAGNETIC_PICKUP_FLUX_V4","FARADAY_RL_CIRCUIT_V4"),
        control=("PICKUP_INTEGRATOR_PROTECTION_V4",))
    for role in (:realization,:control)
        graph=forward_graph_binding(context,role).graph
        applies=Tuple(node for edge in graph.hyperedges for node in edge.program.nodes
            if node isa ASTApplyV1)
        ids=Tuple(String(node.operator_ref.qualified.id) for node in applies)
        Set(ids)==Set(getproperty(expected,role)) && length(ids)==length(getproperty(expected,role)) ||
            throw(ArgumentError("engineering typed graph does not exactly own its implemented operators"))
        for edge in graph.hyperedges
            constants=Tuple(node for node in edge.program.nodes
                if node isa ASTConstantV1 && node.name===:declaration)
            length(constants)==1 || throw(ArgumentError("operator declaration constant missing or ambiguous"))
            ref=only(constants).value
            ref isa QualifiedRefV1 || throw(ArgumentError("operator declaration constant is not a qualified reference"))
            ref.id==canonical_hash(declaration).value && ref.version=="v1" ||
                throw(ArgumentError("operator declaration differs from candidate G3"))
        end
        all(node->isempty(node.parameters),applies) || throw(ArgumentError("unexpected engineering operator parameters"))
    end
    declaration
end

struct MagneticEngineeringResultV4
    revision::String
    candidate_hash::Digest256
    context_hash::Digest256
    declaration_hash::Digest256
    physics_result_hash::Digest256
    upstream_status::Symbol
    upstream_valid::Bool
    applicability_status::Symbol
    status::Symbol
    executed::Bool
    solver_exit_code::Int
    B_projected_T::Float64
    input_sample::NamedTuple
    input_artifacts::Tuple
    scenarios::Tuple
    output_artifacts::Tuple
    remaining_conditions::Tuple{Vararg{String}}
    source_path::String
    source_sha256::Digest256
    environment::NamedTuple
    physical_validation::Bool
    engineering_qualified::Bool
    result_hash::Digest256
end
semantic_view(x::MagneticEngineeringResultV4)=_meg_body(x)

function _meg_assert_scenario_sequence_v4(scenarios,
        declaration=engineering_declaration_v4())
    actual=Tuple(s.fault for s in scenarios)
    expected=Tuple(s.fault for s in declaration.scenarios)
    actual==expected || throw(ArgumentError("engineering scenarios must exactly match the ordered candidate declaration"))
    true
end

function canonical_hash(x::MagneticEngineeringResultV4)
    x.revision==_MEG_REVISION && x.executed && x.solver_exit_code==0 &&
        x.status in (:fail,:unsupported) && x.applicability_status===:unsupported &&
        !x.physical_validation && !x.engineering_qualified &&
        isfinite(x.B_projected_T) && length(x.scenarios)==2 ||
        throw(ArgumentError("engineering result exceeds executed model/applicability scope"))
    _meg_assert_scenario_sequence_v4(x.scenarios)
    !x.upstream_valid && x.status!==:fail && x.upstream_status===:fail &&
        throw(ArgumentError("upstream computation failure must propagate"))
    isfile(x.source_path) && _meg_file_hash(x.source_path)==x.source_sha256 ||
        throw(ArgumentError("engineering source bytes changed"))
    for artifact in (x.input_artifacts...,x.output_artifacts...)
        isfile(artifact.path) && _meg_file_hash(artifact.path)==artifact.sha256 ||
            throw(ArgumentError("engineering artifact bytes changed"))
    end
    for scenario in x.scenarios
        replay=magnetic_pickup_response_v4(x.B_projected_T;fault=scenario.fault)
        canonical_hash(replay)==canonical_hash(scenario) || throw(ArgumentError("circuit replay differs"))
    end
    expected=canonical_hash(semantic_view(x))
    expected==x.result_hash || throw(ArgumentError("engineering result hash mismatch"))
    expected
end

function _meg_write_trajectory(path, response)
    rows=response.trajectory
    open(path,"w") do io
        println(io,join(String.(keys(first(rows))),','))
        for row in rows
            println(io,join(string.(values(row)),','))
        end
    end
    (path=abspath(path),sha256=_meg_file_hash(path),kind=:computed_circuit_trajectory)
end

function _meg_physics_input(context, physics)
    # This validator replays raw sample -> final state mapping; it does not
    # execute DESC again and cannot admit arbitrary caller-supplied B vectors.
    validate_multiregion_result_v4(context,physics)
    physics.candidate_hash==context.candidate_hash && physics.context_hash==context.context_hash ||
        throw(ArgumentError("engineering requires the same revised candidate physics"))
    canonical_hash(physics)
    input=physics.engineering_input
    input.B_includes_final_outer_scale===true || throw(ArgumentError("final solved outer state scale required"))
    samples=input.surface_samples
    !isempty(samples) && all(s->s.rho==1.0,samples) ||
        throw(ArgumentError("actual exact rho=1 exterior field samples required"))
    distance(s)=abs2(mod(s.theta+pi,2pi)-pi)+abs2(mod(s.zeta+pi,2pi)-pi)
    index=argmin(distance.(samples))
    sample=samples[index]
    xyz=sample.position_xyz_m
    R=hypot(xyz[1],xyz[2])
    isfinite(R) && R>0 || throw(ArgumentError("invalid cylindrical pickup location"))
    normal=(-xyz[2]/R,xyz[1]/R,0.0)
    Bprojected=sum(sample.B_xyz_T[i]*normal[i] for i in 1:3)
    isfinite(Bprojected) || throw(ArgumentError("nonfinite actual surface field"))
    artifacts=(
        (path=abspath(input.sample_artifact_path),sha256=input.sample_artifact_sha256,kind=:actual_desc_surface_samples),
        (path=abspath(input.reference_hdf5_path),sha256=input.reference_hdf5_sha256,kind=:actual_desc_equilibrium))
    for a in artifacts
        isfile(a.path) && _meg_file_hash(a.path)==a.sha256 ||
            throw(ArgumentError("engineering upstream artifact bytes do not match"))
    end
    (B_projected_T=Bprojected,
        input_sample=(sample_index=index,sample=sample,disk_normal_xyz=normal,
            B_projected_T=Bprojected,outer_B_scale=input.outer_B_scale,
            field_scope=:exact_plasma_boundary_not_material_or_exterior_field),
        artifacts=artifacts,upstream_status=input.upstream_status,
        upstream_valid=input.upstream_valid)
end

"""Execute the declared engineering scenarios against real same-revision physics."""
function execute_engineering_v4(context, physics, run_dir; kwargs...)
    isempty(kwargs) || throw(ArgumentError("production engineering accepts no undeclared runtime overrides"))
    declaration=_meg_owned_declaration(context)
    bound=_meg_physics_input(context,physics)
    mkpath(run_dir)
    scenarios=Tuple(magnetic_pickup_response_v4(bound.B_projected_T;
        declaration,fault=s.fault) for s in declaration.scenarios)
    artifacts=Tuple(_meg_write_trajectory(joinpath(run_dir,"$(s.id)_circuit.csv"),r)
        for (s,r) in zip(declaration.scenarios,scenarios))
    summary_path=abspath(joinpath(run_dir,"engineering_execution.txt"))
    open(summary_path,"w") do io
        println(io,"MAGNETIC_ENGINEERING_SOLVER_EXIT_CODE=0")
        println(io,repr((candidate_hash=context.candidate_hash,context_hash=context.context_hash,
            declaration_hash=canonical_hash(declaration),physics_result_hash=canonical_hash(physics),
            input=bound,metrics=Tuple(s.metrics for s in scenarios),
            actual_static_field=true,imposed_ramp_is_observed=false,
            applicability_status=:unsupported,engineering_qualified=false)))
    end
    outputs=(artifacts...,(path=summary_path,sha256=_meg_file_hash(summary_path),kind=:engineering_summary))
    status=(physics.status===:fail || bound.upstream_status===:fail) ? :fail : :unsupported
    body=(revision=_MEG_REVISION,candidate_hash=context.candidate_hash,
        context_hash=context.context_hash,declaration_hash=canonical_hash(declaration),
        physics_result_hash=canonical_hash(physics),upstream_status=bound.upstream_status,
        upstream_valid=bound.upstream_valid,applicability_status=:unsupported,status=status,
        executed=true,solver_exit_code=0,B_projected_T=bound.B_projected_T,
        input_sample=bound.input_sample,input_artifacts=bound.artifacts,scenarios=scenarios,
        output_artifacts=outputs,
        remaining_conditions=(
            "Converged/applicable physical field: clear DESC convergence attestation and complete residual solve status before engineering validity.",
            "Field/geometry model: map a physically placed exterior sensor aperture using a candidate-owned vacuum/external field solver and finite aperture quadrature.",
            "Dynamic input data/model: replace or qualify the prescribed fractional ramp with declared external-driver evidence or an actual coupled transient field solve.",
            "Engineering data: qualify effective inductance, winding resistance, material/environment range, insulation and relay switching against components or measurements.",
            "Physical validation data: an applicable calibrated pickup/readout experiment and model discrepancy evidence are missing."),
        source_path=_MEG_SOURCE,source_sha256=_meg_file_hash(_MEG_SOURCE),
        environment=(julia_version=string(VERSION),kernel=string(Sys.KERNEL),
            architecture=string(Sys.ARCH),threads=Threads.nthreads()),
        physical_validation=false,engineering_qualified=false)
    result=MagneticEngineeringResultV4(values(body)...,canonical_hash(body))
    canonical_hash(result)
    result
end

function validate_engineering_result_v4(context,physics,result::MagneticEngineeringResultV4)
    declaration=_meg_owned_declaration(context)
    _meg_assert_scenario_sequence_v4(result.scenarios,declaration)
    bound=_meg_physics_input(context,physics)
    result.candidate_hash==context.candidate_hash && result.context_hash==context.context_hash &&
        result.declaration_hash==canonical_hash(declaration) &&
        result.physics_result_hash==canonical_hash(physics) &&
        result.input_sample==bound.input_sample && result.input_artifacts==bound.artifacts &&
        result.B_projected_T==bound.B_projected_T && result.upstream_status==bound.upstream_status &&
        result.upstream_valid==bound.upstream_valid ||
        throw(ArgumentError("engineering output is not bound to current declaration and actual physics bytes"))
    canonical_hash(result)
    result
end

magnetic_engineering_summary_v4(result::MagneticEngineeringResultV4)=(
    candidate_hash=result.candidate_hash,context_hash=result.context_hash,
    status=result.status,executed=result.executed,solver_exit_code=result.solver_exit_code,
    B_projected_T=result.B_projected_T,upstream_status=result.upstream_status,
    upstream_valid=result.upstream_valid,applicability_status=result.applicability_status,
    scenarios=Tuple((fault=r.fault,metrics=r.metrics) for r in result.scenarios),
    output_artifacts=result.output_artifacts,engineering_qualified=false,
    result_hash=canonical_hash(result))
