"""Narrow queue-child dispatch for a selected native V5 thermal candidate.

This is a software screening route: it validates the existing T2-bound V5
input once, then delegates to the existing UP3 slab composition consumer.
It does not adapt V4 queue entries or create new source/identity receipts.
"""

const VNEXT_UP3_THERMAL_QUEUE_CHILD_SCHEMA_V1 =
    "GenomeV5/Integration/VNextUP3ThermalQueueChildV1"

struct VNextUP3ThermalQueueChildV1{S,P}
    input::VNextT2UP2BoundInputV2
    spatial_case::S
    protocol::P
    subject_ref::Digest256
    mission_ref::Digest256
    scenario_ref::Digest256
    solver_component::Symbol
end

VNextUP3ThermalQueueChildV1(input::VNextT2UP2BoundInputV2,
        spatial_case, protocol, subject_ref::Digest256,
        mission_ref::Digest256, scenario_ref::Digest256) =
    VNextUP3ThermalQueueChildV1(input, spatial_case, protocol,
        subject_ref, mission_ref, scenario_ref, :fv)

function vnext_up3_thermal_queue_child_v1(input::VNextT2UP2BoundInputV2,
        spatial_case, protocol, subject_ref::Digest256,
        mission_ref::Digest256, scenario_ref::Digest256;
        solver_component::Symbol=:fv)
    solver_component in (:fv, :gridap_q1) ||
        throw(ArgumentError("vnext_up3_solver_component_unsupported"))
    VNextUP3ThermalQueueChildV1(input, spatial_case, protocol,
        subject_ref, mission_ref, scenario_ref, solver_component)
end
function vnext_up3_thermal_queue_child_v1(::Nothing, args...)
    throw(ArgumentError("vnext_up3_child_input_absent"))
end

mutable struct VNextUP3ThermalQueueV1
    children::Vector{VNextUP3ThermalQueueChildV1}
    cursor::Int
    selected::Union{Nothing,Int}
end
VNextUP3ThermalQueueV1() = VNextUP3ThermalQueueV1(
    VNextUP3ThermalQueueChildV1[], 1, nothing)

struct VNextUP3ThermalQueueSelectionV1
    queue::VNextUP3ThermalQueueV1
    index::Int
    child::VNextUP3ThermalQueueChildV1
end

function vnext_up3_thermal_enqueue!(queue::VNextUP3ThermalQueueV1,
        child::VNextUP3ThermalQueueChildV1)
    queue.selected === nothing || throw(ArgumentError("vnext_up3_queue_has_selected_child"))
    candidate_ref = child.input.package.candidate_ref
    candidate_ref == child.input.witness.candidate_ref ==
        child.input.formal_gate.candidate_ref ||
        throw(ArgumentError("vnext_up3_queue_candidate_ref_mismatch"))
    push!(queue.children, child)
    length(queue.children)
end

function vnext_up3_thermal_next!(queue::VNextUP3ThermalQueueV1)
    queue.selected === nothing || throw(ArgumentError("vnext_up3_queue_selection_pending"))
    queue.cursor <= length(queue.children) || return nothing
    index = queue.cursor
    queue.cursor += 1
    queue.selected = index
    VNextUP3ThermalQueueSelectionV1(queue, index, queue.children[index])
end

struct VNextUP3ThermalDispatchResultV1
    status::Symbol
    resolution::Symbol
    reason::Symbol
    candidate_ref::Union{Nothing,QualifiedRefV1}
    result::Any
end

function _vnext_up3_thermal_typed_absent(reason::Symbol, candidate=nothing, result=nothing)
    VNextUP3ThermalDispatchResultV1(:typed_absent, :terminal_deferred,
        reason, candidate, result)
end
function _vnext_up3_thermal_fail_closed(reason::Symbol, candidate=nothing, result=nothing)
    VNextUP3ThermalDispatchResultV1(:fail_closed, :none,
        reason, candidate, result)
end
function _vnext_up3_thermal_program_exception(stage::Symbol, err, candidate=nothing)
    detail = (stage=stage, exception_type=string(typeof(err)), exception=err,
        message=sprint(showerror, err))
    VNextUP3ThermalDispatchResultV1(:program_exception, :none,
        Symbol(String(stage) * "_program_exception"), candidate, detail)
end

function _vnext_up3_thermal_ensure_consumer()
    root = normpath(joinpath(@__DIR__, "..", ".."))
    plan_path = joinpath(root, "RuntimeV4", "CompositionSolvePlanV1.jl")
    consumer_path = joinpath(root, "RuntimeV4",
        "SteadyPlanarThermalDiffusionConsumerV1.jl")
    isdefined(@__MODULE__, :CompositionSolveProtocolV1) ||
        Base.include(@__MODULE__, plan_path)
    if !isdefined(Main, :SteadyPlanarThermalDiffusionConsumerV1)
        Base.include(Main, consumer_path)
    end
    consumer = getfield(Main, :SteadyPlanarThermalDiffusionConsumerV1)
    consumer isa Module || throw(ArgumentError("thermal_consumer_binding_is_not_a_module"))
    (consumer=consumer, protocol_type=getfield(@__MODULE__, :CompositionSolveProtocolV1))
end

function _vnext_up3_thermal_screen_contract_errors(result)
    fixed_point = hasproperty(result, :temperature_source_fixed_point)
    expected = fixed_point ? ((:accepted, false),
        (:claim_ceiling, :screen_only), (:provider_invocation_count, 0),
        (:evidence_credit, 0), (:physical_validation, false),
        (:engineering_validation, false)) :
        ((:status, :screen_only), (:accepted, false),
         (:claim_ceiling, :screen_only), (:provider_invocation_count, 0),
         (:solver_invocation_count, 1), (:evidence_credit, 0),
         (:physical_validation, false), (:engineering_validation, false))
    errors = Symbol[]
    for (field, value) in expected
        if !hasproperty(result, field)
            push!(errors, Symbol("missing_" * String(field)))
        elseif getproperty(result, field) != value
            push!(errors, Symbol("unexpected_" * String(field)))
        end
    end
    if fixed_point
        summary = result.temperature_source_fixed_point
        required = (:schema, :status, :fixed_point_converged,
            :claim_ceiling, :iteration_count, :iteration_trace,
            :nonconvergent_policy, :solver_invocation_count)
        missing = Tuple(field for field in required if !hasproperty(summary, field))
        isempty(missing) || return (errors..., :fixed_point_summary_fields_missing)
        summary.schema == "fusionconceptai:runtime-v4:thermal-source-fixed-point-screen-v1" ||
            push!(errors, :fixed_point_schema_invalid)
        summary.claim_ceiling === :screen_only ||
            push!(errors, :fixed_point_claim_ceiling_invalid)
        summary.status == result.status || push!(errors, :fixed_point_status_mismatch)
        summary.fixed_point_converged isa Bool ||
            push!(errors, :fixed_point_convergence_flag_invalid)
        converged = summary.fixed_point_converged === true
        policy = summary.nonconvergent_policy
        status_matches = (converged && result.status === :screen_only) ||
            (!converged && policy === :terminal_deferred &&
                result.status === :terminal_deferred) ||
            (!converged && policy === :fail_closed && result.status === :fail_closed)
        status_matches || push!(errors, :fixed_point_policy_status_mismatch)
        if !(summary.iteration_trace isa Tuple) ||
                !(summary.iteration_count isa Integer) ||
                !(summary.solver_invocation_count isa Integer) ||
                !(result.solver_invocation_count isa Integer)
            push!(errors, :fixed_point_count_fields_invalid)
        else
            trace_count = length(summary.iteration_trace)
            summary.iteration_count == trace_count && trace_count > 0 ||
                push!(errors, :fixed_point_iteration_count_mismatch)
            summary.solver_invocation_count == trace_count &&
                result.solver_invocation_count == trace_count ||
                push!(errors, :fixed_point_solver_count_mismatch)
        end
    end
    Tuple(errors)
end

function vnext_up3_thermal_dispatch_selected!(queue::VNextUP3ThermalQueueV1,
        ::Nothing)
    _vnext_up3_thermal_typed_absent(:queue_selection_absent)
end

function vnext_up3_thermal_dispatch_selected!(queue::VNextUP3ThermalQueueV1,
        selection::VNextUP3ThermalQueueSelectionV1)
    selection.queue === queue && queue.selected === selection.index &&
        1 <= selection.index <= length(queue.children) &&
        queue.children[selection.index] === selection.child ||
        throw(ArgumentError("vnext_up3_queue_selected_child_mismatch"))
    queue.selected = nothing
    child = selection.child
    input = child.input
    candidate = input.package.candidate_ref

    # Reuse the existing source/package validator exactly once at dispatch.
    validation = try
        vnext_t2_up2_validate_input_v2(input)
    catch err
        return _vnext_up3_thermal_program_exception(:input_validator, err, candidate)
    end
    validation.status === :valid || return VNextUP3ThermalDispatchResultV1(
        validation.status, validation.resolution, validation.reason, candidate, validation)
    witness = input.witness
    witness.candidate_ref == candidate ||
        return _vnext_up3_thermal_fail_closed(:selected_child_candidate_mismatch, candidate)
    bundle = witness.t0_transport
    bundle.candidate_ref == candidate ||
        return _vnext_up3_thermal_fail_closed(:selected_child_t0_candidate_mismatch, candidate)

    # A genuinely absent G1 thermal carrier selects no evaluator. Bad record
    # multiplicity or malformed carrier shape fails closed instead.
    g1_records = Tuple(r for r in bundle.declarations if r.layer === :G1)
    isempty(g1_records) &&
        return _vnext_up3_thermal_typed_absent(:g1_source_absent, candidate)
    length(g1_records) == 1 ||
        return _vnext_up3_thermal_fail_closed(:g1_source_record_not_unique, candidate)
    g1_record = only(g1_records)
    g1_record isa VNextT0LocalPresentDeclarationV1 ||
        return _vnext_up3_thermal_typed_absent(:g1_source_typed_absent, candidate)
    source_body = g1_record.semantic_body.body
    hasproperty(source_body, :value) ||
        return _vnext_up3_thermal_fail_closed(:g1_present_semantic_body_value_missing, candidate)
    source_value = source_body.value
    hasproperty(source_value, :g1_typed_source_field_program) ||
        return _vnext_up3_thermal_typed_absent(:thermal_model_not_present, candidate)
    capability = source_value.g1_typed_source_field_program
    hasproperty(capability, :schema) ||
        return _vnext_up3_thermal_fail_closed(:thermal_capability_schema_malformed, candidate)
    capability.schema isa AbstractString ||
        return _vnext_up3_thermal_fail_closed(:thermal_capability_schema_malformed, candidate)
    capability.schema == "fusionconceptai:genome-v5:g1-typed-source-field-program-v1" ||
        return _vnext_up3_thermal_typed_absent(:unsupported_native_model, candidate)

    ensured = try
        _vnext_up3_thermal_ensure_consumer()
    catch err
        return _vnext_up3_thermal_program_exception(:consumer_load, err, candidate)
    end
    consumer, protocol_type = ensured.consumer, ensured.protocol_type
    child.protocol isa protocol_type ||
        return _vnext_up3_thermal_fail_closed(:composition_protocol_invalid, candidate)
    g1, g2, g3 = witness.g1.declaration, witness.g2.declaration,
        witness.g3.declaration
    admission = try
        admit = getfield(consumer, :up3_steady_planar_composition_admit_v1)
        Base.invokelatest(admit, candidate, g1, g2, g3,
            bundle, child.spatial_case, child.protocol;
            solver_component=child.solver_component,
            subject_ref=child.subject_ref, mission_ref=child.mission_ref,
            scenario_ref=child.scenario_ref)
    catch err
        return _vnext_up3_thermal_program_exception(:up3_admission, err, candidate)
    end
    admission isa CompositionSolveAdmissionV1 ||
        return _vnext_up3_thermal_fail_closed(:up3_admission_result_malformed,
            candidate, admission)
    if admission.outcome.status !== :ready || admission.plan === nothing ||
            admission.plan.status !== :ready
        admission.outcome.status === :ready &&
            return _vnext_up3_thermal_fail_closed(:up3_admission_disposition_mismatch,
                candidate, admission)
        resolution = admission.outcome.status === :terminal_deferred ?
            :terminal_deferred : :none
        return VNextUP3ThermalDispatchResultV1(admission.outcome.status,
            resolution, admission.outcome.code, candidate, admission)
    end

    feedback_declared = try
        Base.invokelatest(getfield(consumer,
            :up3_temperature_source_feedback_declared_v1), bundle)
    catch err
        return _vnext_up3_thermal_fail_closed(
            :temperature_source_feedback_route_invalid, candidate,
            (exception_type=string(typeof(err)), message=sprint(showerror, err)))
    end
    result = try
        execute = getfield(consumer, :execute_up3_steady_planar_composition_v1)
        Base.invokelatest(execute, candidate, g1, g2, g3,
            bundle, child.spatial_case, admission;
            solver_component=child.solver_component)
    catch err
        feedback_error_type = getfield(consumer,
            :ThermalTemperatureSourceFeedbackInvalidV1)
        if feedback_declared && err isa feedback_error_type
            return _vnext_up3_thermal_fail_closed(
                :temperature_source_feedback_invalid, candidate,
                (exception_type=string(typeof(err)), message=sprint(showerror, err)))
        end
        return _vnext_up3_thermal_program_exception(:up3_execution, err, candidate)
    end
    errors = _vnext_up3_thermal_screen_contract_errors(result)
    isempty(errors) || return _vnext_up3_thermal_fail_closed(
        :up3_screen_contract_violation, candidate, (errors=errors, result=result))
    if hasproperty(result, :temperature_source_fixed_point)
        status = result.status
        resolution = status === :fail_closed ? :none : :terminal_deferred
        reason = status === :screen_only ? :up3_thermal_screen_complete :
            status === :terminal_deferred ? :up3_thermal_fixed_point_nonconvergent :
            :up3_thermal_fixed_point_nonconvergent_fail_closed
        return VNextUP3ThermalDispatchResultV1(status, resolution, reason,
            candidate, result)
    end
    VNextUP3ThermalDispatchResultV1(result.status, :terminal_deferred,
        :up3_thermal_screen_complete, candidate, result)
end

export VNextUP3ThermalQueueChildV1, VNextUP3ThermalQueueV1,
    VNextUP3ThermalQueueSelectionV1, VNextUP3ThermalDispatchResultV1,
    vnext_up3_thermal_queue_child_v1, vnext_up3_thermal_enqueue!,
    vnext_up3_thermal_next!, vnext_up3_thermal_dispatch_selected!
