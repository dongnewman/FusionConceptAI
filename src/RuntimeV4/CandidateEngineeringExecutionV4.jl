#= Actual plasma-load projection with candidate-owned engineering admission gaps.

The executed constitutive law is the static MHD momentum-flux tensor
`Pi = (p + |B|^2/(2mu0)) I - B B'/mu0`, with outward traction `Pi*n`.
It is not a solid Cauchy stress and the sampled rho interfaces are not hardware
surfaces. No component load, material margin, control trajectory or protection
response is inferred from it. The full real DESC/traction chain is replayed
before these observations are admitted.
=#

using FusionConceptAI
using LinearAlgebra
using SHA
import FusionConceptAI: canonical_hash, semantic_view, Digest256, ClaimCeiling

const _CEE_REVISION = "candidate-engineering-execution-v4-1"
const _CEE_TOKEN = Val(:candidate_engineering_execution_private)
const _CEE_SOURCE_PATH = abspath(@__FILE__)
_cee_file_hash(path) = Digest256(bytes2hex(SHA.sha256(read(path))))
_cee_body(x) = NamedTuple{fieldnames(typeof(x))[1:end-1]}(
    ntuple(i -> getfield(x, i), fieldcount(typeof(x))-1))

struct CandidateEngineeringGapV4
    domain::Symbol
    code::Symbol
    status::Symbol
    recoverable::Bool
    g3_hash::Digest256
    graph_binding_hash::Digest256
    required_inputs::Tuple{Vararg{String}}
    explanation::String
    gap_hash::Digest256
    function CandidateEngineeringGapV4(token::Val{:candidate_engineering_execution_private}, fields...)
        token === _CEE_TOKEN || throw(ArgumentError("private engineering gap constructor"))
        new(fields...)
    end
end
semantic_view(x::CandidateEngineeringGapV4) = _cee_body(x)
function canonical_hash(x::CandidateEngineeringGapV4)
    x.domain in (:engineering, :control, :fault) && x.status === :unsupported &&
        x.recoverable && !isempty(x.required_inputs) && !isempty(x.explanation) ||
        throw(ArgumentError("invalid recoverable engineering gap"))
    expected = canonical_hash(semantic_view(x))
    expected == x.gap_hash || throw(ArgumentError("engineering gap hash mismatch"))
    expected
end

"""One actual pressure/B sample projected at a plasma interface, never a component."""
struct CandidatePlasmaLoadSampleV4
    upstream_sample_hash::Digest256
    interface_id::String
    region_id::String
    side::Symbol
    pressure_Pa::Float64
    B_xyz_T::NTuple{3,Float64}
    outward_normal_xyz::NTuple{3,Float64}
    mu0_N_A2::Float64
    magnetic_energy_density_J_m3::Float64
    momentum_flux_xyz_Pa::NTuple{3,NTuple{3,Float64}}
    traction_xyz_Pa::NTuple{3,Float64}
    normal_traction_Pa::Float64
    tangential_traction_xyz_Pa::NTuple{3,Float64}
    independent_traction_difference_Pa::Float64
    spatial_scope::Symbol
    component_load::Bool
    sample_hash::Digest256
    function CandidatePlasmaLoadSampleV4(token::Val{:candidate_engineering_execution_private}, fields...)
        token === _CEE_TOKEN || throw(ArgumentError("private plasma-load sample constructor"))
        new(fields...)
    end
end
semantic_view(x::CandidatePlasmaLoadSampleV4) = _cee_body(x)

"""Pure SI constitutive kernel, independently tested against analytic cases."""
function candidate_plasma_momentum_flux(p::Real, B, n, mu0::Real)
    length(B) == length(n) == 3 || throw(ArgumentError("three-dimensional vectors required"))
    all(isfinite, (p, B..., n..., mu0)) && p >= 0 && mu0 > 0 ||
        throw(ArgumentError("finite pressure, B, normal and positive permeability required"))
    isapprox(sum(abs2, n), 1.0; rtol=0, atol=1e-9) ||
        throw(ArgumentError("outward normal must be unit length"))
    energy = Float64(sum(abs2, B)/(2mu0))
    tensor = ntuple(i -> ntuple(j -> Float64((i == j ? p+energy : 0.0) -
        B[i]*B[j]/mu0), 3), 3)
    traction = ntuple(i -> sum(tensor[i][j]*n[j] for j in 1:3), 3)
    normal = sum(traction[i]*n[i] for i in 1:3)
    tangent = ntuple(i -> traction[i]-normal*n[i], 3)
    (magnetic_energy_density_J_m3=energy, momentum_flux_xyz_Pa=tensor,
        traction_xyz_Pa=traction, normal_traction_Pa=normal,
        tangential_traction_xyz_Pa=tangent)
end

function canonical_hash(x::CandidatePlasmaLoadSampleV4)
    x.side in (:minus, :plus) && !isempty(x.interface_id) && !isempty(x.region_id) &&
        x.spatial_scope === :sampled_plasma_rho_interface && !x.component_load &&
        isfinite(x.independent_traction_difference_Pa) && x.independent_traction_difference_Pa >= 0 ||
        throw(ArgumentError("invalid plasma-load scope or finite difference"))
    kernel = candidate_plasma_momentum_flux(x.pressure_Pa, x.B_xyz_T,
        x.outward_normal_xyz, x.mu0_N_A2)
    all(getproperty(x, k) == getproperty(kernel, k) for k in keys(kernel)) ||
        throw(ArgumentError("plasma-load constitutive replay mismatch"))
    expected = canonical_hash(semantic_view(x))
    expected == x.sample_hash || throw(ArgumentError("plasma-load sample hash mismatch"))
    expected
end

function candidate_engineering_declaration_audit(context::ForwardChainContextV4)
    validate_forward_chain_context(context)
    g3 = context.candidate.realization_control_genome_ref
    realization = forward_graph_binding(context, :realization)
    control = forward_graph_binding(context, :control)
    (g3_hash=canonical_hash(g3), realization_graph_binding_hash=canonical_hash(realization),
        control_graph_binding_hash=canonical_hash(control),
        realization_payload_count=length(g3.realization), control_payload_count=length(g3.control),
        realization_operator_count=length(realization.graph.hyperedges),
        control_operator_count=length(control.graph.hyperedges))
end

function _cee_gaps(audit)
    # These are capability/input requirements, not topology or family labels.
    declarations_empty = audit.realization_payload_count == 0 && audit.control_payload_count == 0 &&
        audit.realization_operator_count == 0 && audit.control_operator_count == 0
    provenance = declarations_empty ? "Current G3 has no realization/control payload or executable operators. " :
        "Current G3 has no admitted adapter for this model's typed inputs. "
    specs = (
        (:engineering, :missing_component_load_mapping,
            ("component geometry in m", "plasma-to-component boundary map", "loads with area/time support"),
            "Plasma rho-interface point tractions cannot be assigned to a coil, wall or support."),
        (:engineering, :missing_material_model_and_allowables,
            ("material identity and property source", "temperature/irradiation applicability", "allowable stress in Pa"),
            "Material strength, critical current and lifetime margins cannot be evaluated."),
        (:engineering, :missing_structural_model,
            ("solid mesh and supports", "constitutive law in SI", "load cases and displacement boundary conditions"),
            "No solid residual, Jacobian or structural stress solve was executed."),
        (:engineering, :missing_power_and_magnet_model,
            ("finite conductor geometry", "current and winding law in A", "inductance/resistance and supply limits"),
            "Plasma B does not determine conductor field, Lorentz loads, coil stored energy or supply power."),
        (:engineering, :missing_thermal_hydraulic_model,
            ("deposited heat map in W/m3 or W/m2", "coolant/material properties", "channel geometry and mass flow in kg/s"),
            "Static plasma pressure is not deposited heat; no coolant or wall-temperature solve was executed."),
        (:control, :missing_control_plant_and_actuator_model,
            ("upstream linearization or nonlinear state equations", "sensor transfer/noise and delay", "actuator authority and controller parameters"),
            "No plant/controller trajectory was generated; prescribed legacy growth rates would be manufactured input."),
        (:fault, :missing_protection_model,
            ("quench/detection model", "energy extraction circuit and voltage limits", "safe-state and recovery criteria"),
            "No quench hotspot, shutdown transient or protection response was computed."),
        (:fault, :missing_declared_fault_cases,
            ("candidate-owned fault triggers", "fault magnitude and timing", "recovery horizon and acceptance thresholds"),
            "No fault case was injected or recovered; a fixed legacy scenario list is not a current G3 declaration."))
    Tuple(begin
        binding = domain === :engineering ? audit.realization_graph_binding_hash : audit.control_graph_binding_hash
        body = (domain=domain, code=code, status=:unsupported, recoverable=true,
            g3_hash=audit.g3_hash, graph_binding_hash=binding, required_inputs=inputs,
            explanation=provenance*reason)
        CandidateEngineeringGapV4(_CEE_TOKEN, values(body)..., canonical_hash(body))
    end for (domain, code, inputs, reason) in specs)
end

struct CandidateEngineeringExecutionV4
    revision::String
    context_hash::Digest256
    candidate_hash::Digest256
    scenario_hash::Digest256
    g3_hash::Digest256
    realization_graph_binding_hash::Digest256
    control_graph_binding_hash::Digest256
    realization_payload_count::Int
    control_payload_count::Int
    realization_operator_count::Int
    control_operator_count::Int
    traction_request_hash::Digest256
    traction_result_hash::Digest256
    pressure_field_receipt_hash::Digest256
    equilibrium_output_sha256::Digest256
    mu0_source::String
    samples::Tuple{Vararg{CandidatePlasmaLoadSampleV4}}
    load_projection_status::Symbol
    load_projection_executed::Bool
    engineering_status::Symbol
    engineering_executed::Bool
    control_status::Symbol
    control_executed::Bool
    fault_status::Symbol
    fault_executed::Bool
    gaps::Tuple{Vararg{CandidateEngineeringGapV4}}
    physical_validation::Bool
    engineering_validation::Bool
    promotion_authority::Bool
    terminal_authority::Bool
    credible_device_count::Int
    claim_ceiling::ClaimCeiling
    source_path::String
    source_sha256::Digest256
    result_hash::Digest256
    function CandidateEngineeringExecutionV4(token::Val{:candidate_engineering_execution_private}, fields...)
        token === _CEE_TOKEN || throw(ArgumentError("private engineering execution constructor"))
        new(fields...)
    end
end
semantic_view(x::CandidateEngineeringExecutionV4) = _cee_body(x)
function canonical_hash(x::CandidateEngineeringExecutionV4)
    x.revision == _CEE_REVISION && !isempty(x.samples) && x.load_projection_executed &&
        x.load_projection_status === :pointwise_physics_load_projection_executed &&
        x.engineering_status === x.control_status === x.fault_status === :unsupported &&
        !x.engineering_executed && !x.control_executed && !x.fault_executed &&
        !x.physical_validation && !x.engineering_validation && !x.promotion_authority &&
        !x.terminal_authority && x.credible_device_count == 0 && x.claim_ceiling === screen_only &&
        length(x.gaps) == 8 && all(g -> g.g3_hash == x.g3_hash, x.gaps) &&
        isfile(x.source_path) && _cee_file_hash(x.source_path) == x.source_sha256 ||
        throw(ArgumentError("engineering execution exceeds observation or candidate scope"))
    foreach(canonical_hash, x.samples); foreach(canonical_hash, x.gaps)
    expected = canonical_hash(semantic_view(x))
    expected == x.result_hash || throw(ArgumentError("engineering execution hash mismatch"))
    expected
end

function _cee_load_samples(request, result)
    Tuple(begin
        p = getproperty(sample, Symbol(side, :_pressure_Pa))
        B = getproperty(sample, Symbol(side, :_B_xyz_T))
        normal = getproperty(sample, Symbol(side, :_outward_normal_xyz))
        kernel = candidate_plasma_momentum_flux(p, B, normal, request.mu0_N_A2)
        upstream_traction = getproperty(sample, Symbol(side, :_traction_xyz_Pa))
        difference = maximum(abs(kernel.traction_xyz_Pa[i]-upstream_traction[i]) for i in 1:3)
        difference <= 1e-10*max(1.0, maximum(abs, upstream_traction)) ||
            throw(ArgumentError("independent tensor/traction decomposition disagrees"))
        body = (upstream_sample_hash=canonical_hash(sample), interface_id=sample.interface_id,
            region_id=getproperty(sample, Symbol(side, :_region_id)), side=side,
            pressure_Pa=p, B_xyz_T=B, outward_normal_xyz=normal, mu0_N_A2=request.mu0_N_A2,
            kernel..., independent_traction_difference_Pa=difference,
            spatial_scope=:sampled_plasma_rho_interface, component_load=false)
        CandidatePlasmaLoadSampleV4(_CEE_TOKEN, values(body)..., canonical_hash(body))
    end for sample in result.samples for side in (:minus, :plus))
end

function _cee_compute(context, request, result)
    audit = candidate_engineering_declaration_audit(context)
    body = (revision=_CEE_REVISION, context_hash=context.context_hash,
        candidate_hash=context.candidate_hash, scenario_hash=context.scenario_hash,
        audit..., traction_request_hash=canonical_hash(request), traction_result_hash=canonical_hash(result),
        pressure_field_receipt_hash=request.pressure_field_receipt_hash,
        equilibrium_output_sha256=request.equilibrium_output_sha256,
        mu0_source=String(request.mu0_source), samples=_cee_load_samples(request, result),
        load_projection_status=:pointwise_physics_load_projection_executed,
        load_projection_executed=true, engineering_status=:unsupported, engineering_executed=false,
        control_status=:unsupported, control_executed=false, fault_status=:unsupported, fault_executed=false,
        gaps=_cee_gaps(audit), physical_validation=false, engineering_validation=false,
        promotion_authority=false, terminal_authority=false, credible_device_count=0,
        claim_ceiling=screen_only, source_path=_CEE_SOURCE_PATH,
        source_sha256=_cee_file_hash(_CEE_SOURCE_PATH))
    execution = CandidateEngineeringExecutionV4(_CEE_TOKEN, values(body)..., canonical_hash(body))
    canonical_hash(execution)
    execution
end

"""Consume the same typed upstream tuple used by the real ideal-MHD traction edge."""
function execute_candidate_engineering(context::ForwardChainContextV4,
        traction_upstream::Tuple, traction_request, traction_result)
    length(traction_upstream) == 17 && first(traction_upstream) === context ||
        throw(ArgumentError("engineering requires the exact current candidate traction context"))
    validate_ideal_mhd_interface_traction_result(traction_upstream..., traction_request, traction_result)
    context.context_hash == traction_result.context_hash && context.candidate_hash == traction_result.candidate_hash ||
        throw(ArgumentError("engineering input belongs to a different candidate"))
    _cee_compute(context, traction_request, traction_result)
end

function validate_candidate_engineering_execution(context::ForwardChainContextV4,
        traction_upstream::Tuple, traction_request, traction_result, execution::CandidateEngineeringExecutionV4)
    expected = execute_candidate_engineering(context, traction_upstream, traction_request, traction_result)
    canonical_hash(execution) == canonical_hash(expected) ||
        throw(ArgumentError("engineering receipt differs from actual upstream replay"))
    execution
end

candidate_engineering_summary(x::CandidateEngineeringExecutionV4) = (
    candidate_hash=x.candidate_hash, context_hash=x.context_hash, scenario_hash=x.scenario_hash,
    g3_hash=x.g3_hash, result_hash=canonical_hash(x),
    load_projection_status=x.load_projection_status, load_sample_count=length(x.samples),
    max_sampled_pressure_Pa=maximum(s.pressure_Pa for s in x.samples),
    max_sampled_magnetic_energy_density_J_m3=maximum(s.magnetic_energy_density_J_m3 for s in x.samples),
    max_sampled_traction_Pa=maximum(norm(collect(s.traction_xyz_Pa)) for s in x.samples),
    maximum_independent_traction_difference_Pa=maximum(s.independent_traction_difference_Pa for s in x.samples),
    engineering_status=x.engineering_status, engineering_executed=x.engineering_executed,
    control_status=x.control_status, control_executed=x.control_executed,
    fault_status=x.fault_status, fault_executed=x.fault_executed,
    recoverable_gap_codes=Tuple(g.code for g in x.gaps), credible_device_count=x.credible_device_count,
    claim_ceiling=x.claim_ceiling)
