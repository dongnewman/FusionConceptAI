"""Current-G3-owned engineering control/fault graph obligation.

The slice compiles immutable graph ownership only. It cannot execute a
controller, emit evidence, promote a candidate, grant P5, or act terminally.
"""
const _ECFGO_REVISION = "v3"
const _ECFGO_SCHEMA =
    "fusionconceptai:runtime-v4-engineering-control-fault-graph-obligation"
struct _ECFGOToken end
const _ECFGO_TOKEN = _ECFGOToken()

_ecfgo_require_token(token::_ECFGOToken) = token === _ECFGO_TOKEN ||
    throw(ArgumentError("private constructor token mismatch"))

@enum EngineeringControlGraphStageV4 observation_stage controller_stage actuator_stage
@enum EngineeringFaultModeV4 observation_dropout actuator_stuck

struct EngineeringControlEdgeSpecV4
    stage::EngineeringControlGraphStageV4
    edge_id::String
    root_operator_ref::OperatorRefV1
    function EngineeringControlEdgeSpecV4(stage::EngineeringControlGraphStageV4,
            edge_id::AbstractString, root_operator_ref::OperatorRefV1)
        text = String(edge_id)
        !isempty(text) && isvalid(text) ||
            throw(ArgumentError("control edge id must be nonempty valid UTF-8"))
        new(stage, text, root_operator_ref)
    end
end
semantic_view(x::EngineeringControlEdgeSpecV4) =
    (stage=x.stage, edge_id=x.edge_id, root_operator_ref=x.root_operator_ref)

struct EngineeringActuatorLimitV4
    actuator_edge_id::String
    actuator_output_node_id::String
    interval::QuantityIntervalV1
    limit_hash::Digest256
    function EngineeringActuatorLimitV4(token::_ECFGOToken, a...)
        _ecfgo_require_token(token)
        new(a...)
    end
end
EngineeringActuatorLimitV4(a...) = throw(ArgumentError("sealed actuator limit"))

function _ecfgo_limit_body(x::EngineeringActuatorLimitV4)
    !isempty(x.actuator_edge_id) && isvalid(x.actuator_edge_id) ||
        throw(ArgumentError("actuator edge id is invalid"))
    !isempty(x.actuator_output_node_id) && isvalid(x.actuator_output_node_id) ||
        throw(ArgumentError("actuator output node id is invalid"))
    (actuator_edge_id=x.actuator_edge_id,
        actuator_output_node_id=x.actuator_output_node_id, interval=x.interval)
end
semantic_view(x::EngineeringActuatorLimitV4) = _ecfgo_limit_body(x)
function canonical_hash(x::EngineeringActuatorLimitV4)
    expected = canonical_hash(_ecfgo_limit_body(x))
    x.limit_hash == expected || throw(ArgumentError("actuator limit hash mismatch"))
    expected
end

function make_engineering_actuator_limit(actuator_edge_id::AbstractString,
        actuator_output_node_id::AbstractString, interval::QuantityIntervalV1)
    body = (actuator_edge_id=String(actuator_edge_id),
        actuator_output_node_id=String(actuator_output_node_id), interval=interval)
    probe = EngineeringActuatorLimitV4(_ECFGO_TOKEN, body..., canonical_hash(body))
    canonical_hash(probe)
    probe
end

struct EngineeringControlFaultTimingV4
    transport_delay::NonnegativeQuantityV1
    dropout_probability::Rational{Int64}
    dropout_onset::NonnegativeQuantityV1
    dropout_duration::NonnegativeQuantityV1
    fault_onset::NonnegativeQuantityV1
    recovery_deadline::NonnegativeQuantityV1
    fault_mode::EngineeringFaultModeV4
    timing_hash::Digest256
    function EngineeringControlFaultTimingV4(token::_ECFGOToken, a...)
        _ecfgo_require_token(token)
        new(a...)
    end
end
EngineeringControlFaultTimingV4(a...) =
    throw(ArgumentError("sealed control/fault timing"))

function _ecfgo_timing_body(x::EngineeringControlFaultTimingV4)
    0 // 1 <= x.dropout_probability <= 1 // 1 ||
        throw(ArgumentError("dropout probability must be exact and in [0,1]"))
    units = (x.transport_delay.unit, x.dropout_onset.unit,
        x.dropout_duration.unit, x.fault_onset.unit, x.recovery_deadline.unit)
    length(unique(units)) == 1 ||
        throw(ArgumentError("all control/fault times must use one unit"))
    x.dropout_duration.value > 0 ||
        throw(ArgumentError("dropout duration must be positive"))
    x.recovery_deadline.value > x.fault_onset.value ||
        throw(ArgumentError("recovery deadline must follow fault onset"))
    (transport_delay=x.transport_delay,
        dropout_probability=x.dropout_probability,
        dropout_onset=x.dropout_onset, dropout_duration=x.dropout_duration,
        fault_onset=x.fault_onset, recovery_deadline=x.recovery_deadline,
        fault_mode=x.fault_mode)
end
semantic_view(x::EngineeringControlFaultTimingV4) = _ecfgo_timing_body(x)
function canonical_hash(x::EngineeringControlFaultTimingV4)
    expected = canonical_hash(_ecfgo_timing_body(x))
    x.timing_hash == expected || throw(ArgumentError("control/fault timing hash mismatch"))
    expected
end

function make_engineering_control_fault_timing(
        transport_delay::NonnegativeQuantityV1, dropout_probability::Rational,
        dropout_onset::NonnegativeQuantityV1,
        dropout_duration::NonnegativeQuantityV1,
        fault_onset::NonnegativeQuantityV1,
        recovery_deadline::NonnegativeQuantityV1,
        fault_mode::EngineeringFaultModeV4)
    p = Rational{Int64}(dropout_probability)
    body = (transport_delay=transport_delay, dropout_probability=p,
        dropout_onset=dropout_onset, dropout_duration=dropout_duration,
        fault_onset=fault_onset, recovery_deadline=recovery_deadline,
        fault_mode=fault_mode)
    timing = EngineeringControlFaultTimingV4(_ECFGO_TOKEN, body...,
        canonical_hash(body))
    canonical_hash(timing)
    timing
end

const _ECFGO_AUTHORITY_FIELDS = (:emits_evidence, :execution_authority,
    :promotion_authority, :p5_authority, :terminal_authority)

function _ecfgo_require_no_authority(x)
    all(field -> getfield(x, field) === false, _ECFGO_AUTHORITY_FIELDS) ||
        throw(ArgumentError("engineering control/fault contract cannot grant authority"))
    x.claim_ceiling === screen_only ||
        throw(ArgumentError("engineering control/fault claim ceiling must be screen_only"))
    x.credible_device_count == 0 ||
        throw(ArgumentError("engineering control/fault credible device count must be zero"))
    nothing
end

struct EngineeringControlFaultDeclarationV4
    declaration_id::String
    specs::NTuple{3,EngineeringControlEdgeSpecV4}
    actuator_limit::EngineeringActuatorLimitV4
    timing::EngineeringControlFaultTimingV4
    claim_ceiling::ClaimCeiling
    credible_device_count::Int
    emits_evidence::Bool
    execution_authority::Bool
    promotion_authority::Bool
    p5_authority::Bool
    terminal_authority::Bool
    declaration_hash::Digest256
    function EngineeringControlFaultDeclarationV4(token::_ECFGOToken, a...)
        _ecfgo_require_token(token)
        new(a...)
    end
end
EngineeringControlFaultDeclarationV4(a...) =
    throw(ArgumentError("sealed engineering control/fault declaration"))

function _ecfgo_validate_specs(specs::NTuple{3,EngineeringControlEdgeSpecV4})
    Tuple(s.stage for s in specs) ==
        (observation_stage, controller_stage, actuator_stage) ||
        throw(ArgumentError("control stage declarations must be ordered and complete"))
    length(unique(s.edge_id for s in specs)) == 3 ||
        throw(ArgumentError("control stage edge ids must be distinct"))
    specs
end

function _ecfgo_declaration_body(x::EngineeringControlFaultDeclarationV4)
    _ecfgo_require_no_authority(x)
    _ecfgo_validate_specs(x.specs)
    canonical_hash(x.actuator_limit)
    canonical_hash(x.timing)
    x.actuator_limit.actuator_edge_id == x.specs[3].edge_id ||
        throw(ArgumentError("actuator limit must name the declared actuator edge"))
    !isempty(x.declaration_id) && isvalid(x.declaration_id) ||
        throw(ArgumentError("declaration id must be nonempty valid UTF-8"))
    (revision=_ECFGO_REVISION, schema=_ECFGO_SCHEMA,
        declaration_id=x.declaration_id, specs=x.specs,
        actuator_limit_hash=canonical_hash(x.actuator_limit),
        timing_hash=canonical_hash(x.timing), claim_ceiling=x.claim_ceiling,
        credible_device_count=x.credible_device_count,
        emits_evidence=x.emits_evidence,
        execution_authority=x.execution_authority,
        promotion_authority=x.promotion_authority, p5_authority=x.p5_authority,
        terminal_authority=x.terminal_authority)
end
semantic_view(x::EngineeringControlFaultDeclarationV4) = _ecfgo_declaration_body(x)
function canonical_hash(x::EngineeringControlFaultDeclarationV4)
    expected = canonical_hash(_ecfgo_declaration_body(x))
    x.declaration_hash == expected ||
        throw(ArgumentError("engineering control/fault declaration hash mismatch"))
    expected
end

function declare_engineering_control_fault_graph(declaration_id::AbstractString,
        specs::NTuple{3,EngineeringControlEdgeSpecV4},
        actuator_limit::EngineeringActuatorLimitV4,
        timing::EngineeringControlFaultTimingV4)
    text = String(declaration_id)
    _ecfgo_validate_specs(specs)
    canonical_hash(actuator_limit)
    canonical_hash(timing)
    body = (revision=_ECFGO_REVISION, schema=_ECFGO_SCHEMA,
        declaration_id=text, specs=specs,
        actuator_limit_hash=canonical_hash(actuator_limit),
        timing_hash=canonical_hash(timing), claim_ceiling=screen_only,
        credible_device_count=0, emits_evidence=false,
        execution_authority=false, promotion_authority=false,
        p5_authority=false, terminal_authority=false)
    declaration = EngineeringControlFaultDeclarationV4(_ECFGO_TOKEN, text,
        specs, actuator_limit, timing, screen_only, 0,
        false, false, false, false, false,
        canonical_hash(body))
    canonical_hash(declaration)
    declaration
end

struct EngineeringControlGraphEdgeRefV4
    stage::EngineeringControlGraphStageV4
    edge_position::Int
    edge_id::String
    edge::AtomicMIMOHyperedgeV1
    edge_identity_hash::Digest256
    program::TypedASTProgramV1
    program_hash::Digest256
    root_operator_ref::OperatorRefV1
    root_program_node_index::Int
    ast_root_identity_hash::Digest256
    input_node_position::Int
    input_node::TypedNode
    input_node_identity_hash::Digest256
    output_node_position::Int
    output_node::TypedNode
    output_node_identity_hash::Digest256
    ref_hash::Digest256
    function EngineeringControlGraphEdgeRefV4(token::_ECFGOToken, a...)
        _ecfgo_require_token(token)
        new(a...)
    end
end
EngineeringControlGraphEdgeRefV4(a...) =
    throw(ArgumentError("sealed control edge reference"))

function _ecfgo_edge_ref_body(x::EngineeringControlGraphEdgeRefV4)
    x.edge.role === control || throw(ArgumentError("control edge role mismatch"))
    x.edge.edge_id == x.edge_id || throw(ArgumentError("control edge id mismatch"))
    x.edge.program == x.program || throw(ArgumentError("control edge program mismatch"))
    canonical_hash(x.program) == x.program_hash == x.edge.program_hash ||
        throw(ArgumentError("control edge program hash mismatch"))
    _forward_edge_identity(x.edge, x.edge_position) == x.edge_identity_hash ||
        throw(ArgumentError("control edge identity hash mismatch"))
    _forward_node_identity(x.input_node, x.input_node_position) ==
        x.input_node_identity_hash || throw(ArgumentError("control input node identity mismatch"))
    _forward_node_identity(x.output_node, x.output_node_position) ==
        x.output_node_identity_hash || throw(ArgumentError("control output node identity mismatch"))
    1 <= x.root_program_node_index <= length(x.program.nodes) ||
        throw(ArgumentError("control AST root index is out of range"))
    root = x.program.nodes[x.root_program_node_index]
    root isa ASTApplyV1 || throw(ArgumentError("control AST root must be an ASTApplyV1"))
    root.operator_ref == x.root_operator_ref ||
        throw(ArgumentError("control root operator identity mismatch"))
    expected_root = canonical_hash((kind=:typed_ast_root, graph_role=:control,
        edge_position=x.edge_position, edge_id=x.edge_id,
        program_hash=x.program_hash, root_position=1,
        program_node_index=x.root_program_node_index,
        root_node_hash=canonical_hash(root),
        graph_output_node_hash=x.output_node_identity_hash))
    expected_root == x.ast_root_identity_hash ||
        throw(ArgumentError("control AST root identity hash mismatch"))
    (stage=x.stage, edge_position=x.edge_position, edge_id=x.edge_id,
        edge=x.edge, edge_identity_hash=x.edge_identity_hash, program=x.program,
        program_hash=x.program_hash, root_operator_ref=x.root_operator_ref,
        root_program_node_index=x.root_program_node_index,
        ast_root_identity_hash=x.ast_root_identity_hash,
        input_node_position=x.input_node_position, input_node=x.input_node,
        input_node_identity_hash=x.input_node_identity_hash,
        output_node_position=x.output_node_position, output_node=x.output_node,
        output_node_identity_hash=x.output_node_identity_hash)
end
semantic_view(x::EngineeringControlGraphEdgeRefV4) = _ecfgo_edge_ref_body(x)
function canonical_hash(x::EngineeringControlGraphEdgeRefV4)
    expected = canonical_hash(_ecfgo_edge_ref_body(x))
    x.ref_hash == expected || throw(ArgumentError("control edge reference hash mismatch"))
    expected
end

const _ECFGO_STAGE_KINDS = ((:plant_signal, :observation),
    (:observation, :controller_command),
    (:controller_command, :actuator_command))

function _ecfgo_edge_ref(binding::ForwardGraphBindingV4,
        spec::EngineeringControlEdgeSpecV4)
    hits = Tuple((i, edge) for (i, edge) in enumerate(binding.graph.hyperedges)
        if edge.edge_id == spec.edge_id)
    length(hits) == 1 ||
        throw(ArgumentError("declared control edge is missing or ambiguous"))
    edge_position, edge = only(hits)
    edge isa AtomicMIMOHyperedgeV1 ||
        throw(ArgumentError("control stage must be an AtomicMIMOHyperedgeV1"))
    edge.role === control ||
        throw(ArgumentError("control stage edge must have control role"))
    length(edge.input_bindings) == 1 && length(edge.output_bindings) == 1 ||
        throw(ArgumentError("control stage must have exactly one typed input and output"))
    length(edge.program.roots) == 1 ||
        throw(ArgumentError("control stage must have exactly one AST root"))
    input_position = only(edge.input_bindings).graph_node_index
    output_position = only(edge.output_bindings).graph_node_index
    root_program_node_index = only(edge.program.roots)
    root = edge.program.nodes[root_program_node_index]
    root isa ASTApplyV1 ||
        throw(ArgumentError("control stage root must be an ASTApplyV1"))
    root.operator_ref == spec.root_operator_ref ||
        throw(ArgumentError("control stage root operator mismatch"))
    input_node = binding.graph.nodes[input_position]
    output_node = binding.graph.nodes[output_position]
    input_node.physical_type == output_node.physical_type ||
        throw(ArgumentError("control stage physical type changes without conversion"))
    expected_input_kind, expected_output_kind =
        _ECFGO_STAGE_KINDS[Int(spec.stage) + 1]
    input_node.node_kind === expected_input_kind &&
        output_node.node_kind === expected_output_kind ||
        throw(ArgumentError("control stage node-kind chain mismatch"))
    root_offset = sum((length(e.program.roots) for e in
        binding.graph.hyperedges[1:edge_position-1]); init=0)
    body = (stage=spec.stage, edge_position=edge_position, edge_id=edge.edge_id,
        edge=edge, edge_identity_hash=binding.hyperedge_identity_hashes[edge_position],
        program=edge.program, program_hash=edge.program_hash,
        root_operator_ref=root.operator_ref,
        root_program_node_index=root_program_node_index,
        ast_root_identity_hash=binding.ast_root_identity_hashes[root_offset + 1],
        input_node_position=input_position, input_node=input_node,
        input_node_identity_hash=binding.node_identity_hashes[input_position],
        output_node_position=output_position, output_node=output_node,
        output_node_identity_hash=binding.node_identity_hashes[output_position])
    ref = EngineeringControlGraphEdgeRefV4(_ECFGO_TOKEN, body...,
        canonical_hash(body))
    canonical_hash(ref)
    ref
end

function _ecfgo_graph_refs(binding::ForwardGraphBindingV4,
        declaration::EngineeringControlFaultDeclarationV4)
    canonical_hash(declaration)
    atomic_control_edges = Tuple(e for e in binding.graph.hyperedges
        if e isa AtomicMIMOHyperedgeV1 && e.role === control)
    length(atomic_control_edges) == 3 ||
        throw(ArgumentError("current G3 must own exactly three AtomicMIMO control edges"))
    refs = Tuple(_ecfgo_edge_ref(binding, spec) for spec in declaration.specs)
    refs isa NTuple{3,EngineeringControlGraphEdgeRefV4} ||
        error("internal control edge tuple error")
    refs[1].output_node_position == refs[2].input_node_position &&
        refs[2].output_node_position == refs[3].input_node_position ||
        throw(ArgumentError("declared control edges do not form one graph-node chain"))
    limit = declaration.actuator_limit
    limit.actuator_edge_id == refs[3].edge_id &&
        limit.actuator_output_node_id == refs[3].output_node.node_id ||
        throw(ArgumentError("actuator limit is detached from actuator output"))
    limit.interval.unit == refs[3].output_node.physical_type.units ||
        throw(ArgumentError("actuator limit unit does not match actuator output"))
    refs
end

function _ecfgo_current_declarations(candidate::CandidateStatePackageV4)
    Tuple(x for x in candidate.realization_control_genome_ref.control
        if x isa EngineeringControlFaultDeclarationV4)
end

struct EngineeringControlFaultSubjectBindingV4
    candidate_identity_hash::Digest256
    compiled_prefix_hash::Digest256
    registry_hash::Digest256
    genome_bundle_hash::Digest256
    realization_control_genome_hash::Digest256
    control_graph_hash::Digest256
    control_graph_binding_hash::Digest256
    declaration_hash::Digest256
    edges::NTuple{3,EngineeringControlGraphEdgeRefV4}
    actuator_limit_hash::Digest256
    timing_hash::Digest256
    mission_hash::Digest256
    bounds_hash::Digest256
    comparison_scope::Tuple{Vararg{String}}
    scenario_scope::Tuple{Vararg{String}}
    scenario_hash::Digest256
    claim_ceiling::ClaimCeiling
    credible_device_count::Int
    emits_evidence::Bool
    execution_authority::Bool
    promotion_authority::Bool
    p5_authority::Bool
    terminal_authority::Bool
    binding_hash::Digest256
    function EngineeringControlFaultSubjectBindingV4(token::_ECFGOToken, a...)
        _ecfgo_require_token(token)
        new(a...)
    end
end
EngineeringControlFaultSubjectBindingV4(a...) =
    throw(ArgumentError("sealed engineering control/fault subject binding"))

function _ecfgo_subject_binding_body(x::EngineeringControlFaultSubjectBindingV4)
    _ecfgo_require_no_authority(x)
    edge_hashes = Tuple(canonical_hash(edge) for edge in x.edges)
    Tuple(edge.stage for edge in x.edges) ==
        (observation_stage, controller_stage, actuator_stage) ||
        throw(ArgumentError("subject binding control stages are incomplete"))
    (revision=_ECFGO_REVISION, schema=_ECFGO_SCHEMA,
        candidate_identity_hash=x.candidate_identity_hash,
        compiled_prefix_hash=x.compiled_prefix_hash, registry_hash=x.registry_hash,
        genome_bundle_hash=x.genome_bundle_hash,
        realization_control_genome_hash=x.realization_control_genome_hash,
        control_graph_hash=x.control_graph_hash,
        control_graph_binding_hash=x.control_graph_binding_hash,
        declaration_hash=x.declaration_hash, edge_ref_hashes=edge_hashes,
        actuator_limit_hash=x.actuator_limit_hash, timing_hash=x.timing_hash,
        mission_hash=x.mission_hash, bounds_hash=x.bounds_hash,
        comparison_scope=x.comparison_scope, scenario_scope=x.scenario_scope,
        scenario_hash=x.scenario_hash, claim_ceiling=x.claim_ceiling,
        credible_device_count=x.credible_device_count,
        emits_evidence=x.emits_evidence,
        execution_authority=x.execution_authority,
        promotion_authority=x.promotion_authority, p5_authority=x.p5_authority,
        terminal_authority=x.terminal_authority)
end
semantic_view(x::EngineeringControlFaultSubjectBindingV4) =
    _ecfgo_subject_binding_body(x)
function canonical_hash(x::EngineeringControlFaultSubjectBindingV4)
    expected = canonical_hash(_ecfgo_subject_binding_body(x))
    x.binding_hash == expected ||
        throw(ArgumentError("engineering control/fault subject binding hash mismatch"))
    expected
end

function make_engineering_control_fault_subject_binding(
        compiled::CompiledCandidatePrefixV4,
        registry::GenomeContractRegistryV4, mission_payload, bounds_payload,
        comparison_scope, scenario_scope, scenario,
        declaration::EngineeringControlFaultDeclarationV4)
    candidate = compiled.candidate
    comparison = _runtime_axis_tuple(comparison_scope, "comparison_scope")
    scenarios = _runtime_axis_tuple(scenario_scope, "scenario_scope")
    _runtime_validate_compiled_prefix(compiled, candidate, registry,
        mission_payload, bounds_payload, comparison, scenarios)
    declarations = _ecfgo_current_declarations(candidate)
    length(declarations) == 1 ||
        throw(ArgumentError("current G3 must own exactly one engineering control/fault declaration"))
    canonical_hash(only(declarations)) == canonical_hash(declaration) ||
        throw(ArgumentError("supplied declaration is not the current G3 declaration"))
    scenario_name = _forward_scenario_name(scenario)
    scenario_name in scenarios ||
        throw(ArgumentError("subject binding scenario is outside frozen scope"))
    is_canonical_value(scenario) ||
        throw(ArgumentError("subject binding scenario is not canonicalizable"))
    graph_binding = _make_forward_graph_binding(:control, compiled.control_graph)
    refs = _ecfgo_graph_refs(graph_binding, declaration)
    body = (revision=_ECFGO_REVISION, schema=_ECFGO_SCHEMA,
        candidate_identity_hash=_forward_candidate_identity(candidate),
        compiled_prefix_hash=compiled.prefix_hash,
        registry_hash=canonical_hash(registry),
        genome_bundle_hash=candidate.canonical_hashes.genome_bundle_hash,
        realization_control_genome_hash=
            realization_control_hash(candidate.realization_control_genome_ref),
        control_graph_hash=graph_binding.canonical_graph_hash,
        control_graph_binding_hash=canonical_hash(graph_binding),
        declaration_hash=canonical_hash(declaration),
        edge_ref_hashes=Tuple(canonical_hash(edge) for edge in refs),
        actuator_limit_hash=canonical_hash(declaration.actuator_limit),
        timing_hash=canonical_hash(declaration.timing),
        mission_hash=_runtime_decl_hash(mission_payload),
        bounds_hash=_runtime_decl_hash(bounds_payload), comparison_scope=comparison,
        scenario_scope=scenarios, scenario_hash=canonical_hash(scenario),
        claim_ceiling=screen_only, credible_device_count=0,
        emits_evidence=false, execution_authority=false,
        promotion_authority=false, p5_authority=false, terminal_authority=false)
    binding = EngineeringControlFaultSubjectBindingV4(_ECFGO_TOKEN,
        body.candidate_identity_hash, body.compiled_prefix_hash, body.registry_hash,
        body.genome_bundle_hash, body.realization_control_genome_hash,
        body.control_graph_hash, body.control_graph_binding_hash,
        body.declaration_hash, refs, body.actuator_limit_hash, body.timing_hash,
        body.mission_hash, body.bounds_hash, comparison, scenarios,
        body.scenario_hash, screen_only, 0, false, false, false, false, false,
        canonical_hash(body))
    canonical_hash(binding)
    binding
end

struct EngineeringControlFaultGraphGapV4
    context_hash::Digest256
    physical_subject_hash::Digest256
    reason::Symbol
    detail::String
    claim_ceiling::ClaimCeiling
    credible_device_count::Int
    emits_evidence::Bool
    execution_authority::Bool
    promotion_authority::Bool
    p5_authority::Bool
    terminal_authority::Bool
    gap_hash::Digest256
    function EngineeringControlFaultGraphGapV4(token::_ECFGOToken, a...)
        _ecfgo_require_token(token)
        new(a...)
    end
end
EngineeringControlFaultGraphGapV4(a...) =
    throw(ArgumentError("sealed engineering control/fault graph gap"))

function _ecfgo_gap_body(x::EngineeringControlFaultGraphGapV4)
    _ecfgo_require_no_authority(x)
    !isempty(x.detail) && isvalid(x.detail) ||
        throw(ArgumentError("engineering control/fault gap detail is invalid"))
    (context_hash=x.context_hash, physical_subject_hash=x.physical_subject_hash,
        reason=x.reason, detail=x.detail, claim_ceiling=x.claim_ceiling,
        credible_device_count=x.credible_device_count,
        emits_evidence=x.emits_evidence,
        execution_authority=x.execution_authority,
        promotion_authority=x.promotion_authority, p5_authority=x.p5_authority,
        terminal_authority=x.terminal_authority)
end
semantic_view(x::EngineeringControlFaultGraphGapV4) = _ecfgo_gap_body(x)
function canonical_hash(x::EngineeringControlFaultGraphGapV4)
    expected = canonical_hash(_ecfgo_gap_body(x))
    x.gap_hash == expected ||
        throw(ArgumentError("engineering control/fault graph gap hash mismatch"))
    expected
end

struct EngineeringControlFaultGraphCompilationV4
    status::Symbol
    context_hash::Digest256
    physical_subject_hash::Digest256
    declaration::Union{Nothing,EngineeringControlFaultDeclarationV4}
    subject_binding::Union{Nothing,EngineeringControlFaultSubjectBindingV4}
    gap::Union{Nothing,EngineeringControlFaultGraphGapV4}
    claim_ceiling::ClaimCeiling
    credible_device_count::Int
    emits_evidence::Bool
    execution_authority::Bool
    promotion_authority::Bool
    p5_authority::Bool
    terminal_authority::Bool
    compilation_hash::Digest256
    function EngineeringControlFaultGraphCompilationV4(token::_ECFGOToken, a...)
        _ecfgo_require_token(token)
        new(a...)
    end
end
EngineeringControlFaultGraphCompilationV4(a...) =
    throw(ArgumentError("sealed engineering control/fault graph compilation"))

function _ecfgo_compilation_body(x::EngineeringControlFaultGraphCompilationV4)
    _ecfgo_require_no_authority(x)
    x.status in (:compiled_contract, :recoverable_gap) ||
        throw(ArgumentError("engineering control/fault compilation status is invalid"))
    if x.status === :compiled_contract
        x.declaration === nothing &&
            throw(ArgumentError("compiled contract lacks declaration"))
        x.subject_binding === nothing &&
            throw(ArgumentError("compiled contract lacks subject binding"))
        x.gap === nothing || throw(ArgumentError("compiled contract contains a gap"))
    else
        x.declaration === nothing ||
            throw(ArgumentError("recoverable gap cannot carry a declaration"))
        x.subject_binding === nothing ||
            throw(ArgumentError("recoverable gap cannot carry a subject binding"))
        x.gap === nothing && throw(ArgumentError("recoverable gap lacks gap payload"))
    end
    declaration_hash = x.declaration === nothing ? nothing : canonical_hash(x.declaration)
    binding_hash = x.subject_binding === nothing ? nothing : canonical_hash(x.subject_binding)
    gap_hash = x.gap === nothing ? nothing : canonical_hash(x.gap)
    (status=x.status, context_hash=x.context_hash,
        physical_subject_hash=x.physical_subject_hash,
        declaration_hash=declaration_hash, subject_binding_hash=binding_hash,
        gap_hash=gap_hash, claim_ceiling=x.claim_ceiling,
        credible_device_count=x.credible_device_count,
        emits_evidence=x.emits_evidence,
        execution_authority=x.execution_authority,
        promotion_authority=x.promotion_authority, p5_authority=x.p5_authority,
        terminal_authority=x.terminal_authority)
end
semantic_view(x::EngineeringControlFaultGraphCompilationV4) =
    _ecfgo_compilation_body(x)
function canonical_hash(x::EngineeringControlFaultGraphCompilationV4)
    expected = canonical_hash(_ecfgo_compilation_body(x))
    x.compilation_hash == expected ||
        throw(ArgumentError("engineering control/fault compilation hash mismatch"))
    expected
end

function _ecfgo_gap(context::ForwardChainContextV4, reason::Symbol, detail::String)
    gap_body = (context_hash=context.context_hash,
        physical_subject_hash=context.subject.physical_subject_hash,
        reason=reason, detail=detail, claim_ceiling=screen_only,
        credible_device_count=0, emits_evidence=false,
        execution_authority=false, promotion_authority=false,
        p5_authority=false, terminal_authority=false)
    gap = EngineeringControlFaultGraphGapV4(_ECFGO_TOKEN,
        gap_body.context_hash, gap_body.physical_subject_hash, reason, detail,
        screen_only, 0, false, false, false, false, false,
        canonical_hash(gap_body))
    canonical_hash(gap)
    body = (status=:recoverable_gap, context_hash=context.context_hash,
        physical_subject_hash=context.subject.physical_subject_hash,
        declaration_hash=nothing, subject_binding_hash=nothing,
        gap_hash=canonical_hash(gap), claim_ceiling=screen_only,
        credible_device_count=0, emits_evidence=false,
        execution_authority=false, promotion_authority=false,
        p5_authority=false, terminal_authority=false)
    result = EngineeringControlFaultGraphCompilationV4(_ECFGO_TOKEN,
        :recoverable_gap, context.context_hash,
        context.subject.physical_subject_hash, nothing, nothing, gap,
        screen_only, 0, false, false, false, false, false,
        canonical_hash(body))
    canonical_hash(result)
    result
end

"""Resolve only declarations and bindings already owned by the validated context."""
function resolve_engineering_control_fault_graph_obligation(
        context::ForwardChainContextV4)
    validate_forward_chain_context(context)
    declarations = _ecfgo_current_declarations(context.candidate)
    isempty(declarations) && return _ecfgo_gap(context,
        :required_current_g3_engineering_control_fault_declaration,
        "current realization/control Genome has no engineering control/fault declaration")
    length(declarations) == 1 || return _ecfgo_gap(context,
        :unique_current_g3_engineering_control_fault_declaration_required,
        "current realization/control Genome has duplicate engineering control/fault declarations")
    declaration = only(declarations)
    try
        canonical_hash(declaration)
    catch err
        err isa ArgumentError || rethrow()
        return _ecfgo_gap(context, :invalid_current_g3_engineering_control_fault_declaration,
            sprint(showerror, err))
    end
    subject_bindings = Tuple(x for x in context.subject.bindings
        if x isa EngineeringControlFaultSubjectBindingV4)
    isempty(subject_bindings) && return _ecfgo_gap(context,
        :required_engineering_control_fault_subject_binding,
        "physical subject has no engineering control/fault binding")
    length(subject_bindings) == 1 || return _ecfgo_gap(context,
        :unique_engineering_control_fault_subject_binding_required,
        "physical subject has duplicate engineering control/fault bindings")
    found = only(subject_bindings)
    expected = try
        make_engineering_control_fault_subject_binding(context.compiled,
            context.registry, context.mission_payload, context.bounds_payload,
            context.comparison_scope, context.scenario_scope, context.scenario,
            declaration)
    catch err
        err isa ArgumentError || rethrow()
        return _ecfgo_gap(context,
            :required_owned_g3_observation_controller_actuator_graph,
            sprint(showerror, err))
    end
    found_hash = try
        canonical_hash(found)
    catch err
        err isa ArgumentError || rethrow()
        return _ecfgo_gap(context, :invalid_engineering_control_fault_subject_binding,
            sprint(showerror, err))
    end
    found_hash == canonical_hash(expected) &&
        semantic_view(found) == semantic_view(expected) || return _ecfgo_gap(context,
            :engineering_control_fault_subject_binding_mismatch,
            "physical subject binding does not match current candidate, prefix, G3, graph, declaration, mission, bounds, scopes, and scenario")
    body = (status=:compiled_contract, context_hash=context.context_hash,
        physical_subject_hash=context.subject.physical_subject_hash,
        declaration_hash=canonical_hash(declaration),
        subject_binding_hash=found_hash, gap_hash=nothing,
        claim_ceiling=screen_only, credible_device_count=0,
        emits_evidence=false, execution_authority=false,
        promotion_authority=false, p5_authority=false, terminal_authority=false)
    result = EngineeringControlFaultGraphCompilationV4(_ECFGO_TOKEN,
        :compiled_contract, context.context_hash,
        context.subject.physical_subject_hash, declaration, found, nothing,
        screen_only, 0, false, false, false, false, false,
        canonical_hash(body))
    canonical_hash(result)
    result
end

function validate_engineering_control_fault_graph_compilation(
        result::EngineeringControlFaultGraphCompilationV4,
        context::ForwardChainContextV4)
    expected = try resolve_engineering_control_fault_graph_obligation(context)
    catch
        return false
    end
    try
        canonical_hash(result) == canonical_hash(expected) &&
            semantic_view(result) == semantic_view(expected)
    catch
        false
    end
end

engineering_control_fault_graph_obligation_manifest() = (
    schema=_ECFGO_SCHEMA, revision=_ECFGO_REVISION,
    declaration_owned_exactly_once_by_current_g3=true,
    subject_binding_precedes_context=true,
    resolver_inputs=(:forward_chain_context,),
    actual_atomic_mimo_edges_required=true,
    exact_edge_program_ast_root_node_identity_required=true,
    exact_actuator_limits_and_fault_timing_required=true,
    subject_mission_bounds_scope_scenario_binding_required=true,
    missing_declaration_or_binding_is_recoverable=true,
    execution_available=false, emits_evidence=false,
    promotion_authority=false, p5_authority=false,
    terminal_authority=false, claim_ceiling=screen_only,
    credible_device_count=0)
