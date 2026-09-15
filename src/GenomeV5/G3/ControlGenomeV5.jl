"""Candidate-owned G3 control, signal and fault contract."""

const _G3_V5_FAULT_MODES = (:open_circuit, :short_circuit, :sensor_dropout,
                            :actuator_stuck, :overtemperature)
const _G3_V5_SAFE_ACTIONS = (:trip, :hold, :disable, :recover)

struct G3FaultPathV2
    fault_id::String
    target_id::String
    mode::Symbol
    safe_action::Symbol
    detection_signal_id::String
    deadline::Rational{Int64}
    function G3FaultPathV2(fault_id::Any, target_id::Any, mode::Any,
            safe_action::Any, detection_signal_id::Any, deadline::Any)
        new(_g3_text(fault_id, "fault_id"), _g3_text(target_id, "fault target_id"),
            _g3_symbol(mode, _G3_V5_FAULT_MODES, "fault mode"),
            _g3_symbol(safe_action, _G3_V5_SAFE_ACTIONS, "fault safe_action"),
            _g3_text(detection_signal_id, "fault detection_signal_id"),
            _g3_rational(deadline, "fault deadline"; positive=true))
    end
end

struct G3ControllerV2
    controller_id::String
    sensor_port_ids::Tuple{Vararg{String}}
    actuator_port_ids::Tuple{Vararg{String}}
    actuator_resource_port_ids::Tuple{Vararg{String}}
    fault_ids::Tuple{Vararg{String}}
    initial_states::Tuple{Vararg{G3InitialStateV2}}
    events::Tuple{Vararg{G3EventV2}}
    function G3ControllerV2(controller_id::Any, sensor_port_ids::Any,
            actuator_port_ids::Any, actuator_resource_port_ids::Any,
            fault_ids::Any, initial_states::Any=(), events::Any=())
        id = _g3_text(controller_id, "controller_id")
        sensors = _g3_tuple(sensor_port_ids, "sensor_port_ids")
        actuators = _g3_tuple(actuator_port_ids, "actuator_port_ids")
        resource_actuators = _g3_tuple(actuator_resource_port_ids, "actuator_resource_port_ids")
        faults = _g3_tuple(fault_ids, "fault_ids")
        all(x -> x isa AbstractString && !isempty(String(x)), sensors) ||
            throw(ArgumentError("controller sensor ids are invalid"))
        all(x -> x isa AbstractString && !isempty(String(x)), actuators) ||
            throw(ArgumentError("controller actuator ids are invalid"))
        all(x -> x isa AbstractString && !isempty(String(x)), resource_actuators) ||
            throw(ArgumentError("controller resource actuator ids are invalid"))
        all(x -> x isa AbstractString && !isempty(String(x)), faults) ||
            throw(ArgumentError("controller fault ids are invalid"))
        !isempty(sensors) && !isempty(actuators) ||
            throw(ArgumentError("controller requires sensor and actuator ports"))
        length(sensors) == length(actuators) ||
            throw(ArgumentError("controller sensor/actuator cardinality must match"))
        length(actuators) == length(resource_actuators) ||
            throw(ArgumentError("controller actuator/resource cardinality must match"))
        states = _g3_tuple(initial_states, "controller initial_states")
        event_tuple = _g3_tuple(events, "controller events")
        all(x -> x isa G3InitialStateV2, states) || throw(ArgumentError("invalid controller initial state"))
        all(x -> x isa G3EventV2, event_tuple) || throw(ArgumentError("invalid controller event"))
        new(id, Tuple(String.(sensors)), Tuple(String.(actuators)),
            Tuple(String.(resource_actuators)), Tuple(String.(faults)),
            Tuple(states), Tuple(event_tuple))
    end
end

semantic_view(x::G3FaultPathV2) =
    (fault_id=x.fault_id, target_id=x.target_id, mode=x.mode, safe_action=x.safe_action,
     detection_signal_id=x.detection_signal_id, deadline=x.deadline)
semantic_view(x::G3ControllerV2) =
    (controller_id=x.controller_id, sensor_port_ids=x.sensor_port_ids,
     actuator_port_ids=x.actuator_port_ids,
     actuator_resource_port_ids=x.actuator_resource_port_ids, fault_ids=x.fault_ids,
     initial_states=x.initial_states, events=x.events)

struct G3ControlPlanV2
    controller_ids::Tuple{Vararg{String}}
    signal_port_ids::Tuple{Vararg{String}}
    fault_ids::Tuple{Vararg{String}}
    function G3ControlPlanV2(controller_ids::Any, signal_port_ids::Any, fault_ids::Any)
        cs = _g3_tuple(controller_ids, "control plan controller_ids")
        ss = _g3_tuple(signal_port_ids, "control plan signal_port_ids")
        fs = _g3_tuple(fault_ids, "control plan fault_ids")
        !isempty(cs) || throw(ArgumentError("control plan controller_ids must be non-empty"))
        all(x -> x isa AbstractString && !isempty(String(x)), cs) || throw(ArgumentError("invalid control plan controller id"))
        !isempty(ss) || throw(ArgumentError("control plan signal_port_ids must be non-empty"))
        all(x -> x isa AbstractString && !isempty(String(x)), ss) || throw(ArgumentError("invalid control plan signal id"))
        !isempty(fs) || throw(ArgumentError("control plan fault_ids must be non-empty"))
        all(x -> x isa AbstractString && !isempty(String(x)), fs) || throw(ArgumentError("invalid control plan fault id"))
        controllers = Tuple(String.(cs)); signals = Tuple(String.(ss)); faults = Tuple(String.(fs))
        length(unique(controllers)) == length(controllers) ||
            throw(ArgumentError("control plan controller ids must be unique"))
        length(unique(signals)) == length(signals) ||
            throw(ArgumentError("control plan signal ids must be unique"))
        length(unique(faults)) == length(faults) ||
            throw(ArgumentError("control plan fault ids must be unique"))
        new(controllers, signals, faults)
    end
end
semantic_view(x::G3ControlPlanV2) =
    (controller_ids=x.controller_ids, signal_port_ids=x.signal_port_ids, fault_ids=x.fault_ids)

struct ControlGenomeV5
    contract_binding::G3ContractBindingV2
    signal_ports::Tuple{Vararg{G3SignalPortV2}}
    controllers::Tuple{Vararg{G3ControllerV2}}
    faults::Tuple{Vararg{G3FaultPathV2}}
    plan::G3ControlPlanV2
    provider_match::Symbol
    plan_hash::Digest256
    candidate_hash::Digest256
    function ControlGenomeV5(contract_binding::Any, signal_ports::Any,
            controllers::Any, faults::Any, plan::Any; provider_match=:no_match)
        contract_binding isa G3ContractBindingV2 || throw(ArgumentError("control requires G3ContractBindingV2"))
        signals = _g3_tuple(signal_ports, "signal_ports")
        cs = _g3_tuple(controllers, "controllers")
        fs = _g3_tuple(faults, "faults")
        all(x -> x isa G3SignalPortV2, signals) || throw(ArgumentError("invalid signal port"))
        all(x -> x isa G3ControllerV2, cs) || throw(ArgumentError("invalid controller"))
        all(x -> x isa G3FaultPathV2, fs) || throw(ArgumentError("invalid fault path"))
        plan isa G3ControlPlanV2 || throw(ArgumentError("control requires G3ControlPlanV2"))
        match = _g3_symbol(provider_match, _G3_V5_PROVIDER_MATCHES, "control provider_match")
        body = (signal_ports=Tuple(signals), controllers=Tuple(cs), faults=Tuple(fs), plan=plan)
        plan_hash = canonical_hash(body)
        candidate_hash = canonical_hash((contract_binding=contract_binding, body=body, provider_match=match))
        new(contract_binding, Tuple(signals), Tuple(cs), Tuple(fs), plan, match, plan_hash, candidate_hash)
    end
end

semantic_view(x::ControlGenomeV5) =
    (contract_binding=x.contract_binding, signal_ports=x.signal_ports,
     controllers=x.controllers, faults=x.faults, plan=x.plan,
     provider_match=x.provider_match, plan_hash=x.plan_hash,
     candidate_hash=x.candidate_hash)

function g3_validate_control(genome::ControlGenomeV5)
    errors = String[]
    signal_map = Dict(x.port_id => x for x in genome.signal_ports)
    controller_map = Dict(x.controller_id => x for x in genome.controllers)
    fault_map = Dict(x.fault_id => x for x in genome.faults)
    length(unique(x.port_id for x in genome.signal_ports)) == length(genome.signal_ports) ||
        push!(errors, "duplicate_signal_port_id")
    length(unique(x.controller_id for x in genome.controllers)) == length(genome.controllers) ||
        push!(errors, "duplicate_controller_id")
    length(unique(x.fault_id for x in genome.faults)) == length(genome.faults) ||
        push!(errors, "duplicate_fault_id")
    for controller in genome.controllers
        for id in controller.sensor_port_ids
            haskey(signal_map, id) || push!(errors, "missing_sensor_port:" * id)
            haskey(signal_map, id) && signal_map[id].direction in (:in, :bidirectional) ||
                (haskey(signal_map, id) && push!(errors, "sensor_direction_invalid:" * id))
        end
        for id in controller.actuator_port_ids
            haskey(signal_map, id) || push!(errors, "missing_actuator_port:" * id)
            haskey(signal_map, id) && signal_map[id].direction in (:out, :bidirectional) ||
                (haskey(signal_map, id) && push!(errors, "actuator_direction_invalid:" * id))
        end
        for id in controller.fault_ids
            haskey(fault_map, id) || push!(errors, "missing_controller_fault:" * id)
        end
    end
    for fault in genome.faults
        haskey(controller_map, fault.target_id) || push!(errors, "fault_target_missing:" * fault.fault_id)
        haskey(signal_map, fault.detection_signal_id) || push!(errors, "fault_detection_signal_missing:" * fault.fault_id)
    end
    Set(genome.plan.controller_ids) == Set(keys(controller_map)) || push!(errors, "control_plan_controller_mismatch")
    Set(genome.plan.signal_port_ids) == Set(keys(signal_map)) || push!(errors, "control_plan_signal_mismatch")
    Set(genome.plan.fault_ids) == Set(keys(fault_map)) || push!(errors, "control_plan_fault_mismatch")
    unique!(errors)
end

function g3_edit_fault(genome::ControlGenomeV5, fault_id::AbstractString, mode::Symbol)
    id = String(fault_id); found = false; rebuilt = G3FaultPathV2[]
    for fault in genome.faults
        if fault.fault_id == id
            found = true
            push!(rebuilt, G3FaultPathV2(fault.fault_id, fault.target_id, mode,
                fault.safe_action, fault.detection_signal_id, fault.deadline))
        else
            push!(rebuilt, fault)
        end
    end
    found || throw(ArgumentError("unknown G3 fault"))
    ControlGenomeV5(genome.contract_binding, genome.signal_ports, genome.controllers,
        Tuple(rebuilt), genome.plan; provider_match=genome.provider_match)
end

