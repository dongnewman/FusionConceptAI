"""Gap compiler for the normalized-chart to SI-physical 3-D root bridge.

This slice recognizes an exact, candidate-owned two-root ABI on each coordinate
and metric program.  It does not interpret either program and therefore does
not prove geometry or authorize a provider request.
"""

using FusionConceptAI
import FusionConceptAI: canonical_hash, semantic_view

const _TDNPRB_REVISION = "runtime-v4-three-d-normalized-physical-root-bridge-v1"
const _TDNPRB_SCHEMA = "fusionconceptai:runtime-v4-three-d-normalized-physical-root-bridge"
const _TDNPRB_COORDINATE_OPERATOR = QualifiedRefV1(
    "RUNTIME_V4_SUPPORT_SCALE_COORDINATE", "v1")
const _TDNPRB_METRIC_OPERATOR = QualifiedRefV1(
    "RUNTIME_V4_SUPPORT_SCALE_METRIC", "v1")
const _TDNPRB_GAPS = (
    "required_distinct_normalized_coordinate_root",
    "required_distinct_normalized_metric_root",
    "required_support_scale_coordinate_root_bridge",
    "required_support_scale_metric_root_bridge")

mutable struct _TDNPRBPrivateToken end
const _TDNPRB_TOKEN = _TDNPRBPrivateToken()

function _tdnprb_gaps(values)
    values isa Tuple && !(values isa NamedTuple) ||
        throw(ArgumentError("root-bridge gaps must be an immutable tuple"))
    gaps = Tuple(_tdpi_text(x, "root-bridge gap") for x in values)
    positions = Tuple(findfirst(==(x), _TDNPRB_GAPS) for x in gaps)
    all(!isnothing, positions) ||
        throw(ArgumentError("root-bridge gap is outside the closed vocabulary"))
    indexes = Tuple(Int(x) for x in positions)
    length(unique(indexes)) == length(indexes) && issorted(indexes) ||
        throw(ArgumentError("root-bridge gaps must be unique and canonically ordered"))
    gaps
end

function _tdnprb_order_gaps(values)
    unique_values = unique(String(x) for x in values)
    all(x -> x in _TDNPRB_GAPS, unique_values) ||
        throw(ArgumentError("root-bridge compiler produced an undeclared gap"))
    Tuple(sort!(unique_values; by=x -> findfirst(==(x), _TDNPRB_GAPS)))
end

function _tdnprb_audit_body(context, declaration, binding, support, chart,
        coordinate_edge_hash, metric_edge_hash,
        normalized_coordinate_root_hash, physical_coordinate_root_hash,
        normalized_metric_root_hash, physical_metric_root_hash,
        support_scale, normalized_coordinate_root_distinct,
        normalized_metric_root_distinct, coordinate_bridge_exact,
        metric_bridge_exact, gaps)
    (revision=_TDNPRB_REVISION,
     audit_kind=:three_d_normalized_physical_root_bridge,
     context_hash=context.context_hash,
     candidate_hash=context.candidate_hash,
     compiled_prefix_hash=context.compiled.prefix_hash,
     registry_hash=context.registry_hash,
     physical_subject_hash=context.subject.physical_subject_hash,
     declaration_hash=canonical_hash(declaration),
     binding_hash=canonical_hash(binding),
     field_geometry_genome_hash=context.candidate.canonical_hashes.field_geometry_hash,
     coordinate_edge_identity_hash=coordinate_edge_hash,
     metric_edge_identity_hash=metric_edge_hash,
     normalized_coordinate_root_identity_hash=normalized_coordinate_root_hash,
     physical_coordinate_root_identity_hash=physical_coordinate_root_hash,
     normalized_metric_root_identity_hash=normalized_metric_root_hash,
     physical_metric_root_identity_hash=physical_metric_root_hash,
     support_scale=support_scale,
     support_hash=canonical_hash(support), chart_hash=canonical_hash(chart),
     normalized_coordinate_root_distinct=normalized_coordinate_root_distinct,
     normalized_metric_root_distinct=normalized_metric_root_distinct,
     coordinate_bridge_exact=coordinate_bridge_exact,
     metric_bridge_exact=metric_bridge_exact,
     recoverable_gaps=gaps,
     status=isempty(gaps) ? :bridge_ready : :recoverable_gap,
     model_class=:manufactured_input_fixture, claim_ceiling=screen_only,
     bridge_ready_is_geometry_proof=false,
     geometry_program_interpreted=false, geometry_proved=false,
     certificate_emitted=false, request_emitted=false,
     provider_selected=false, provider_executed=false,
     solver_execution_attempted=false, solver_executed=false,
     physical_validation=false, engineering_validation=false,
     emits_evidence=false, grants_pass=false, promotion_authority=false,
     p5_ready=false, terminal_authority=false,
     credible_physical_device_count=0)
end

struct ThreeDNormalizedPhysicalRootBridgeAuditV4
    revision::String
    audit_kind::Symbol
    context_hash::Digest256
    candidate_hash::Digest256
    compiled_prefix_hash::Digest256
    registry_hash::Digest256
    physical_subject_hash::Digest256
    declaration_hash::Digest256
    binding_hash::Digest256
    field_geometry_genome_hash::Digest256
    coordinate_edge_identity_hash::Digest256
    metric_edge_identity_hash::Digest256
    normalized_coordinate_root_identity_hash::Digest256
    physical_coordinate_root_identity_hash::Digest256
    normalized_metric_root_identity_hash::Digest256
    physical_metric_root_identity_hash::Digest256
    support_scale::NonnegativeQuantityV1
    support_hash::Digest256
    chart_hash::Digest256
    normalized_coordinate_root_distinct::Bool
    normalized_metric_root_distinct::Bool
    coordinate_bridge_exact::Bool
    metric_bridge_exact::Bool
    recoverable_gaps::Tuple{Vararg{String}}
    status::Symbol
    model_class::Symbol
    claim_ceiling::ClaimCeiling
    bridge_ready_is_geometry_proof::Bool
    geometry_program_interpreted::Bool
    geometry_proved::Bool
    certificate_emitted::Bool
    request_emitted::Bool
    provider_selected::Bool
    provider_executed::Bool
    solver_execution_attempted::Bool
    solver_executed::Bool
    physical_validation::Bool
    engineering_validation::Bool
    emits_evidence::Bool
    grants_pass::Bool
    promotion_authority::Bool
    p5_ready::Bool
    terminal_authority::Bool
    credible_physical_device_count::Int
    audit_hash::Digest256
    function ThreeDNormalizedPhysicalRootBridgeAuditV4(
            token::_TDNPRBPrivateToken, fields...)
        token === _TDNPRB_TOKEN || throw(ArgumentError("private root-bridge audit constructor"))
        new(fields...)
    end
end

_tdnprb_audit_values(x::ThreeDNormalizedPhysicalRootBridgeAuditV4) =
    ntuple(i -> getfield(x, i), fieldcount(typeof(x)) - 1)
function _tdnprb_audit_body_from_values(values...)
    NamedTuple{fieldnames(ThreeDNormalizedPhysicalRootBridgeAuditV4)[1:end-1]}(values)
end
semantic_view(x::ThreeDNormalizedPhysicalRootBridgeAuditV4) = merge(
    _tdnprb_audit_body_from_values(_tdnprb_audit_values(x)...),
    (audit_hash=x.audit_hash,))

function canonical_hash(x::ThreeDNormalizedPhysicalRootBridgeAuditV4)
    body = _tdnprb_audit_body_from_values(_tdnprb_audit_values(x)...)
    expected = canonical_hash(body)
    expected == x.audit_hash || throw(ArgumentError("root-bridge audit hash mismatch"))
    x.revision == _TDNPRB_REVISION &&
        x.audit_kind === :three_d_normalized_physical_root_bridge ||
        throw(ArgumentError("root-bridge audit schema mismatch"))
    _tdnprb_gaps(x.recoverable_gaps)
    expected_gaps = String[]
    x.normalized_coordinate_root_distinct || push!(expected_gaps, _TDNPRB_GAPS[1])
    x.normalized_metric_root_distinct || push!(expected_gaps, _TDNPRB_GAPS[2])
    x.coordinate_bridge_exact || push!(expected_gaps, _TDNPRB_GAPS[3])
    x.metric_bridge_exact || push!(expected_gaps, _TDNPRB_GAPS[4])
    x.recoverable_gaps == _tdnprb_order_gaps(expected_gaps) ||
        throw(ArgumentError("root-bridge audit flags/gaps mismatch"))
    x.status === (isempty(expected_gaps) ? :bridge_ready : :recoverable_gap) ||
        throw(ArgumentError("root-bridge audit status mismatch"))
    x.model_class === :manufactured_input_fixture && x.claim_ceiling == screen_only &&
        !x.bridge_ready_is_geometry_proof && !x.geometry_program_interpreted &&
        !x.geometry_proved && !x.certificate_emitted && !x.request_emitted &&
        !x.provider_selected && !x.provider_executed &&
        !x.solver_execution_attempted && !x.solver_executed &&
        !x.physical_validation && !x.engineering_validation &&
        !x.emits_evidence && !x.grants_pass && !x.promotion_authority &&
        !x.p5_ready && !x.terminal_authority &&
        x.credible_physical_device_count == 0 ||
        throw(ArgumentError("root-bridge audit exceeded authority ceiling"))
    expected
end

function _tdnprb_resolution_body(context_hash, status, audit, gaps)
    (revision=_TDNPRB_REVISION,
     resolution_kind=:three_d_normalized_physical_root_bridge_resolution,
     context_hash=context_hash, status=status, audit=audit,
     recoverable_gaps=gaps, claim_ceiling=screen_only,
     bridge_ready_is_geometry_proof=false,
     geometry_program_interpreted=false, geometry_proved=false,
     certificate_emitted=false, request_emitted=false,
     provider_selected=false, provider_executed=false,
     solver_execution_attempted=false, solver_executed=false,
     physical_validation=false, engineering_validation=false,
     emits_evidence=false, grants_pass=false, promotion_authority=false,
     p5_ready=false, terminal_authority=false,
     credible_physical_device_count=0)
end

struct ThreeDNormalizedPhysicalRootBridgeResolutionV4
    revision::String
    resolution_kind::Symbol
    context_hash::Digest256
    status::Symbol
    audit::Union{Nothing,ThreeDNormalizedPhysicalRootBridgeAuditV4}
    recoverable_gaps::Tuple{Vararg{String}}
    claim_ceiling::ClaimCeiling
    bridge_ready_is_geometry_proof::Bool
    geometry_program_interpreted::Bool
    geometry_proved::Bool
    certificate_emitted::Bool
    request_emitted::Bool
    provider_selected::Bool
    provider_executed::Bool
    solver_execution_attempted::Bool
    solver_executed::Bool
    physical_validation::Bool
    engineering_validation::Bool
    emits_evidence::Bool
    grants_pass::Bool
    promotion_authority::Bool
    p5_ready::Bool
    terminal_authority::Bool
    credible_physical_device_count::Int
    resolution_hash::Digest256
    function ThreeDNormalizedPhysicalRootBridgeResolutionV4(
            token::_TDNPRBPrivateToken, fields...)
        token === _TDNPRB_TOKEN || throw(ArgumentError("private root-bridge resolution constructor"))
        new(fields...)
    end
end

semantic_view(x::ThreeDNormalizedPhysicalRootBridgeResolutionV4) = merge(
    _tdnprb_resolution_body(x.context_hash, x.status, x.audit,
        x.recoverable_gaps), (resolution_hash=x.resolution_hash,))

function canonical_hash(x::ThreeDNormalizedPhysicalRootBridgeResolutionV4)
    x.revision == _TDNPRB_REVISION &&
        x.resolution_kind === :three_d_normalized_physical_root_bridge_resolution ||
        throw(ArgumentError("root-bridge resolution schema mismatch"))
    x.status in (:bridge_ready, :recoverable_gap) ||
        throw(ArgumentError("invalid root-bridge resolution status"))
    x.audit === nothing || canonical_hash(x.audit)
    _tdnprb_gaps(x.recoverable_gaps)
    x.audit === nothing && x.status !== :recoverable_gap &&
        throw(ArgumentError("missing declaration cannot be bridge-ready"))
    x.audit === nothing || (x.status == x.audit.status &&
        x.recoverable_gaps == x.audit.recoverable_gaps &&
        x.context_hash == x.audit.context_hash) ||
        throw(ArgumentError("root-bridge resolution/audit mismatch"))
    body = _tdnprb_resolution_body(x.context_hash, x.status, x.audit,
        x.recoverable_gaps)
    expected = canonical_hash(body)
    expected == x.resolution_hash || throw(ArgumentError("root-bridge resolution hash mismatch"))
    !x.bridge_ready_is_geometry_proof && !x.geometry_program_interpreted &&
        !x.geometry_proved && !x.certificate_emitted && !x.request_emitted &&
        !x.provider_selected && !x.provider_executed &&
        !x.solver_execution_attempted && !x.solver_executed &&
        !x.physical_validation && !x.engineering_validation &&
        !x.emits_evidence && !x.grants_pass && !x.promotion_authority &&
        !x.p5_ready && !x.terminal_authority &&
        x.credible_physical_device_count == 0 ||
        throw(ArgumentError("root-bridge resolution exceeded authority ceiling"))
    expected
end

function _tdnprb_resolution(context_hash, status, audit, gaps)
    ordered = _tdnprb_order_gaps(gaps)
    body = _tdnprb_resolution_body(context_hash, status, audit, ordered)
    result = ThreeDNormalizedPhysicalRootBridgeResolutionV4(
        _TDNPRB_TOKEN, values(body)..., canonical_hash(body))
    canonical_hash(result)
    result
end

function _tdnprb_inventory(context)
    declarations = Tuple(x for x in context.candidate.field_geometry_genome_ref.fields
        if typeof(x) === ThreeDPhysicalProviderInputV4)
    bindings = Tuple(x for x in context.subject.bindings
        if typeof(x) === ThreeDPhysicalProviderInputBindingV4)
    length(declarations) <= 1 || throw(ArgumentError("duplicate 3-D physical declarations"))
    length(bindings) <= 1 || throw(ArgumentError("duplicate 3-D physical bindings"))
    declarations, bindings
end

function _tdnprb_support_chart(candidate, coordinate)
    supports = Tuple(x for x in candidate.field_geometry_genome_ref.fields
        if typeof(x) === SpatialSupportGeneV1 && x.support_ref == coordinate.support_ref)
    length(supports) == 1 || throw(ArgumentError("root-bridge support is missing or ambiguous"))
    support = only(supports)
    charts = Tuple(x for x in support.charts if x.chart_ref == coordinate.chart_ref)
    length(charts) == 1 || throw(ArgumentError("root-bridge chart is missing or ambiguous"))
    support, only(charts)
end

function _tdnprb_edge(graph, site)
    matches = Tuple((i, edge) for (i, edge) in enumerate(graph.graph.hyperedges)
        if edge.edge_id == site.value)
    length(matches) == 1 || throw(ArgumentError("root-bridge edge is missing or ambiguous"))
    only(matches)
end

function _tdnprb_root(graph, edge_position, edge, root_position)
    nodes, roots, _ = _forward_edge_program(edge)
    1 <= root_position <= length(roots) || return nothing
    offset = sum(length(_forward_edge_program(e)[2])
        for e in graph.graph.hyperedges[1:edge_position-1]; init=0)
    node_position = roots[root_position]
    graph_position = _forward_root_output_node(edge, root_position)
    (root_position=root_position, node_position=node_position,
     node=nodes[node_position], graph_position=graph_position,
     graph_type=graph.graph.nodes[graph_position].physical_type,
     identity_hash=graph.ast_root_identity_hashes[offset + root_position])
end

function _tdnprb_root_by_hash(graph, edge_position, edge, hash)
    matches = Tuple(root for position in eachindex(_forward_edge_program(edge)[2])
        for root in (_tdnprb_root(graph, edge_position, edge, position),)
        if root.identity_hash == hash)
    length(matches) == 1 ? only(matches) : nothing
end

function _tdnprb_depends_on(nodes, position, ancestor)
    position == ancestor && return true
    node = nodes[position]
    inputs = node isa ASTApplyV1 ? node.inputs : ()
    any(i -> _tdnprb_depends_on(nodes, i, ancestor), inputs)
end

function _tdnprb_bridge_exact(edge, normalized, physical, support_scale,
        expected_ref, expected_scale_type, expected_value)
    edge isa AtomicMIMOHyperedgeV1 || return false
    normalized === nothing && return false
    physical === nothing && return false
    normalized.identity_hash != physical.identity_hash || return false
    nodes = edge.program.nodes
    physical.node isa ASTApplyV1 || return false
    physical.node.operator_ref.qualified == expected_ref || return false
    isempty(physical.node.parameters) || return false
    length(physical.node.inputs) == 2 || return false
    first(physical.node.inputs) == normalized.node_position || return false
    scale_node = nodes[last(physical.node.inputs)]
    scale_node isa ASTConstantV1 || return false
    isempty(scale_node.parameters) || return false
    scale_node.output_type == expected_scale_type || return false
    scale_node.value == expected_value || return false
    _tdnprb_depends_on(nodes, physical.node_position, normalized.node_position) || return false
    binding = Tuple(x for x in edge.program.used_manifest_bindings
        if x[1].qualified == expected_ref)
    length(binding) == 1 || return false
    manifest = try operator_manifest(edge.registry, expected_ref) catch; return false end
    expected_inputs = (normalized.node.output_type, expected_scale_type)
    expected_outputs = (physical.node.output_type,)
    input_rule = manifest.input_type_rule
    output_rule = manifest.output_type_rule
    only(binding)[1] == manifest.operator_ref &&
        only(binding)[2] == manifest.manifest_hash &&
        manifest.input_arity == 2 && manifest.output_arity == 1 &&
        typeof(input_rule) === ExactTypeRuleV1 &&
        input_rule.input_types == expected_inputs &&
        input_rule.output_types == expected_outputs &&
        typeof(output_rule) === ExactTypeRuleV1 &&
        output_rule.input_types == expected_inputs &&
        output_rule.output_types == expected_outputs &&
        manifest.allowed_roles == (:constraint,) &&
        isempty(manifest.parameter_schema) && manifest.locality === :local &&
        manifest.max_derivative_contribution == 0 && manifest.pure &&
        !manifest.stateful && !manifest.stochastic && !manifest.event &&
        isempty(manifest.commutative_input_groups) && manifest.cse_allowed &&
        isempty(manifest.allowed_conservation_effects) &&
        isempty(manifest.forbidden_conservation_effects)
end

"""Compile the exact root bridge; `bridge_ready` is structural, not geometry proof."""
function compile_three_d_normalized_physical_root_bridge(context::ForwardChainContextV4)
    validate_forward_chain_context(context)
    declarations, bindings = _tdnprb_inventory(context)
    if isempty(declarations) || isempty(bindings)
        return _tdnprb_resolution(context.context_hash, :recoverable_gap,
            nothing, _TDNPRB_GAPS)
    end
    declaration = only(declarations)
    binding = _tdpi_context_binding(context, declaration)
    canonical_hash(only(bindings)) == canonical_hash(binding) ||
        throw(ArgumentError("root-bridge binding is foreign"))
    coordinate = declaration.coordinate_metric
    support, chart = _tdnprb_support_chart(context.candidate, coordinate)
    graph = forward_graph_binding(context, :field_geometry)
    coordinate_edge_position, coordinate_edge = _tdnprb_edge(
        graph, coordinate.coordinate_map_site_ref)
    metric_edge_position, metric_edge = _tdnprb_edge(graph, coordinate.metric_site_ref)
    normalized_coordinate = _tdnprb_root(graph, coordinate_edge_position,
        coordinate_edge, Int(chart.coordinate_map_root.root_position))
    normalized_metric = _tdnprb_root(graph, metric_edge_position,
        metric_edge, Int(chart.metric_program_root.root_position))
    physical_coordinate = _tdnprb_root_by_hash(graph, coordinate_edge_position,
        coordinate_edge, coordinate.coordinate_map_root_identity_hash)
    physical_metric = _tdnprb_root_by_hash(graph, metric_edge_position,
        metric_edge, coordinate.metric_root_identity_hash)

    normalized_coordinate_distinct = normalized_coordinate !== nothing &&
        physical_coordinate !== nothing &&
        normalized_coordinate.node.output_type == chart.coordinate_map_root.declared_type &&
        normalized_coordinate.graph_type == chart.coordinate_map_root.declared_type &&
        normalized_coordinate.identity_hash != physical_coordinate.identity_hash
    normalized_metric_distinct = normalized_metric !== nothing &&
        physical_metric !== nothing &&
        normalized_metric.node.output_type == chart.metric_program_root.declared_type &&
        normalized_metric.graph_type == chart.metric_program_root.declared_type &&
        normalized_metric.identity_hash != physical_metric.identity_hash
    length_type = PhysicalType(:support_scale, 0, 3,
        TemporalTypeV1(static_time), _tdpi_length_unit())
    metric_scale_type = PhysicalType(:support_scale_squared, 0, 3,
        TemporalTypeV1(static_time), _tdpi_metric_unit())
    scale = support.resolution_independent_scale
    coordinate_bridge = normalized_coordinate_distinct &&
        physical_coordinate.node.output_type == coordinate.coordinate_type &&
        physical_coordinate.graph_type == coordinate.coordinate_type &&
        _tdnprb_bridge_exact(coordinate_edge, normalized_coordinate,
            physical_coordinate, scale, _TDNPRB_COORDINATE_OPERATOR,
            length_type, scale.value)
    metric_bridge = normalized_metric_distinct &&
        physical_metric.node.output_type == coordinate.metric_type &&
        physical_metric.graph_type == coordinate.metric_type &&
        _tdnprb_bridge_exact(metric_edge, normalized_metric, physical_metric,
            scale, _TDNPRB_METRIC_OPERATOR, metric_scale_type, scale.value^2)
    gaps = String[]
    normalized_coordinate_distinct || push!(gaps, _TDNPRB_GAPS[1])
    normalized_metric_distinct || push!(gaps, _TDNPRB_GAPS[2])
    coordinate_bridge || push!(gaps, _TDNPRB_GAPS[3])
    metric_bridge || push!(gaps, _TDNPRB_GAPS[4])
    body = _tdnprb_audit_body(context, declaration, binding, support, chart,
        _forward_edge_identity(coordinate_edge, coordinate_edge_position),
        _forward_edge_identity(metric_edge, metric_edge_position),
        normalized_coordinate === nothing ? coordinate.coordinate_map_root_identity_hash : normalized_coordinate.identity_hash,
        coordinate.coordinate_map_root_identity_hash,
        normalized_metric === nothing ? coordinate.metric_root_identity_hash : normalized_metric.identity_hash,
        coordinate.metric_root_identity_hash, scale,
        normalized_coordinate_distinct, normalized_metric_distinct,
        coordinate_bridge, metric_bridge, _tdnprb_order_gaps(gaps))
    audit = ThreeDNormalizedPhysicalRootBridgeAuditV4(
        _TDNPRB_TOKEN, values(body)..., canonical_hash(body))
    canonical_hash(audit)
    _tdnprb_resolution(context.context_hash, body.status, audit,
        body.recoverable_gaps)
end

function validate_three_d_normalized_physical_root_bridge(
        context::ForwardChainContextV4,
        resolution::ThreeDNormalizedPhysicalRootBridgeResolutionV4)
    canonical_hash(resolution)
    rebuilt = compile_three_d_normalized_physical_root_bridge(context)
    canonical_hash(rebuilt) == resolution.resolution_hash &&
        semantic_view(rebuilt) == semantic_view(resolution) ||
        throw(ArgumentError("root-bridge resolution is foreign to current context"))
    resolution.resolution_hash
end

validate_three_d_normalized_physical_root_bridge(
    resolution::ThreeDNormalizedPhysicalRootBridgeResolutionV4) =
    (canonical_hash(resolution); resolution.status === :bridge_ready)

three_d_normalized_physical_root_bridge_manifest() = (
    schema=_TDNPRB_SCHEMA, revision=_TDNPRB_REVISION,
    statuses=(:bridge_ready, :recoverable_gap), gaps=_TDNPRB_GAPS,
    bridge_ready_is_geometry_proof=false, geometry_program_interpreted=false,
    geometry_proved=false, certificate_emitted=false, request_emitted=false,
    provider_selected=false, provider_executed=false,
    solver_execution_attempted=false, solver_executed=false,
    emits_evidence=false, physical_validation=false, engineering_validation=false,
    claim_ceiling=screen_only, grants_pass=false, promotion_authority=false,
    p5_ready=false, terminal_authority=false, credible_physical_device_count=0)
