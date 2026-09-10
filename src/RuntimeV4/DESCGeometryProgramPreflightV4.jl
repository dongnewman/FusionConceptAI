"""Candidate-bound preflight for a future RuntimeV4-to-DESC geometry proof.

This slice does not prove geometry.  It reconstructs the accepted 3-D input
composition and DESC declarations, then audits whether the actual G2 chart
roots are executable programs with the normalized turn-coordinate ABI needed
by a later proof.  All present outputs remain screen-only and non-evidentiary.
"""

using FusionConceptAI
import FusionConceptAI: canonical_hash, semantic_view

const _DGPP_REVISION = "runtime-v4-desc-geometry-program-preflight-v1"
const _DGPP_SCHEMA = "fusionconceptai:runtime-v4-desc-geometry-program-preflight"
const _DGPP_LOCAL_GAPS = (
    "required_desc_normalized_turn_chart_domain",
    "required_desc_poloidal_turn_period_axis_declaration",
    "required_desc_field_period_turn_axis_declaration",
    "required_desc_exact_periodic_turn_axis_set",
    "desc_coordinate_chart_root_abi_mismatch",
    "desc_metric_chart_root_abi_mismatch",
    "required_desc_normalized_physical_root_bridge_contract",
    "required_executable_desc_coordinate_map_program",
    "required_executable_desc_metric_program",
    "required_pinned_desc_geometry_operator_manifests",
    "required_desc_geometry_program_interpreter")
const _DGPP_GAP_VOCABULARY = (_DFBRC_GAP_VOCABULARY...,
    _DGPP_LOCAL_GAPS...)

mutable struct _DGPPPrivateToken end
const _DGPP_TOKEN = _DGPPPrivateToken()

function _dgpp_gap_tuple(values)
    values isa Tuple && !(values isa NamedTuple) ||
        throw(ArgumentError("geometry preflight gaps must be an immutable tuple"))
    gaps = Tuple(_dfbrc_text(x, "geometry preflight gap") for x in values)
    ranks = Tuple(findfirst(==(x), _DGPP_GAP_VOCABULARY) for x in gaps)
    all(!isnothing, ranks) ||
        throw(ArgumentError("geometry preflight gap is outside the closed vocabulary"))
    iranks = Tuple(Int(x) for x in ranks)
    length(unique(iranks)) == length(iranks) && issorted(iranks) ||
        throw(ArgumentError("geometry preflight gaps must be unique and canonically ordered"))
    gaps
end

function _dgpp_order_gaps(values)
    unique_values = unique(String(x) for x in values)
    all(x -> x in _DGPP_GAP_VOCABULARY, unique_values) ||
        throw(ArgumentError("geometry preflight produced an undeclared gap"))
    Tuple(sort!(unique_values; by=x -> something(
        findfirst(==(x), _DGPP_GAP_VOCABULARY), typemax(Int))))
end

function _dgpp_audit_body(context, composition, compatibility, declaration,
        request_binding, field_graph, support, chart, coordinate_edge,
        metric_edge, coordinate_program_hash, metric_program_hash,
        coordinate_root_identity_hash, metric_root_identity_hash,
        coordinate_root_declaration_hash, metric_root_declaration_hash,
        coordinate_input_abi_exact, metric_input_abi_exact,
        coordinate_output_abi_exact, metric_output_abi_exact,
        coordinate_identity_exact, metric_identity_exact,
        normalized_turn_domain, poloidal_turn_period_axis_declared,
        field_period_turn_axis_declared, periodic_turn_axis_set_exact,
        normalized_physical_root_bridge_available,
        coordinate_program_shape_admissible,
        metric_program_shape_admissible, operator_manifests_pinned,
        geometry_program_interpreter_available, gaps)
    (revision=_DGPP_REVISION,
     audit_kind=:desc_geometry_program_preflight,
     context_hash=context.context_hash,
     candidate_hash=context.candidate_hash,
     compiled_prefix_hash=context.compiled.prefix_hash,
     registry_hash=context.registry_hash,
     physical_subject_hash=context.subject.physical_subject_hash,
     composition_hash=canonical_hash(composition),
     compatibility_declaration_hash=canonical_hash(compatibility),
     request_declaration_hash=canonical_hash(declaration),
     request_binding_hash=canonical_hash(request_binding),
     field_geometry_genome_hash=context.candidate.canonical_hashes.field_geometry_hash,
     field_geometry_graph_hash=field_graph.canonical_graph_hash,
     field_geometry_graph_binding_hash=field_graph.binding_hash,
     support_hash=canonical_hash(support), chart_hash=canonical_hash(chart),
     coordinate_edge_identity_hash=_forward_edge_identity(coordinate_edge,
        findfirst(==(coordinate_edge), field_graph.graph.hyperedges)),
     metric_edge_identity_hash=_forward_edge_identity(metric_edge,
        findfirst(==(metric_edge), field_graph.graph.hyperedges)),
     coordinate_program_hash=coordinate_program_hash,
     metric_program_hash=metric_program_hash,
     coordinate_root_identity_hash=coordinate_root_identity_hash,
     metric_root_identity_hash=metric_root_identity_hash,
     coordinate_root_declaration_hash=coordinate_root_declaration_hash,
     metric_root_declaration_hash=metric_root_declaration_hash,
     coordinate_input_abi_exact=coordinate_input_abi_exact,
     metric_input_abi_exact=metric_input_abi_exact,
     coordinate_output_abi_exact=coordinate_output_abi_exact,
     metric_output_abi_exact=metric_output_abi_exact,
     coordinate_identity_exact=coordinate_identity_exact,
     metric_identity_exact=metric_identity_exact,
     normalized_turn_domain=normalized_turn_domain,
     poloidal_turn_period_axis_declared=poloidal_turn_period_axis_declared,
     field_period_turn_axis_declared=field_period_turn_axis_declared,
     periodic_turn_axis_set_exact=periodic_turn_axis_set_exact,
     normalized_physical_root_bridge_available=normalized_physical_root_bridge_available,
     coordinate_program_shape_admissible=coordinate_program_shape_admissible,
     metric_program_shape_admissible=metric_program_shape_admissible,
     operator_manifests_pinned=operator_manifests_pinned,
     geometry_program_interpreter_available=geometry_program_interpreter_available,
     recoverable_gaps=gaps,
     model_class=:manufactured_input_fixture, claim_ceiling=screen_only,
     geometry_proved=false, certificate_emitted=false,
     request_emitted=false, provider_selected=false, provider_executed=false,
     solver_execution_attempted=false, solver_executed=false,
     physical_validation=false, engineering_validation=false,
     emits_evidence=false, grants_pass=false, promotion_authority=false,
     p5_ready=false, terminal_authority=false,
     credible_physical_device_count=0)
end

struct DESCGeometryProgramAuditV4
    revision::String
    audit_kind::Symbol
    context_hash::Digest256
    candidate_hash::Digest256
    compiled_prefix_hash::Digest256
    registry_hash::Digest256
    physical_subject_hash::Digest256
    composition_hash::Digest256
    compatibility_declaration_hash::Digest256
    request_declaration_hash::Digest256
    request_binding_hash::Digest256
    field_geometry_genome_hash::Digest256
    field_geometry_graph_hash::Digest256
    field_geometry_graph_binding_hash::Digest256
    support_hash::Digest256
    chart_hash::Digest256
    coordinate_edge_identity_hash::Digest256
    metric_edge_identity_hash::Digest256
    coordinate_program_hash::Digest256
    metric_program_hash::Digest256
    coordinate_root_identity_hash::Digest256
    metric_root_identity_hash::Digest256
    coordinate_root_declaration_hash::Digest256
    metric_root_declaration_hash::Digest256
    coordinate_input_abi_exact::Bool
    metric_input_abi_exact::Bool
    coordinate_output_abi_exact::Bool
    metric_output_abi_exact::Bool
    coordinate_identity_exact::Bool
    metric_identity_exact::Bool
    normalized_turn_domain::Bool
    poloidal_turn_period_axis_declared::Bool
    field_period_turn_axis_declared::Bool
    periodic_turn_axis_set_exact::Bool
    normalized_physical_root_bridge_available::Bool
    coordinate_program_shape_admissible::Bool
    metric_program_shape_admissible::Bool
    operator_manifests_pinned::Bool
    geometry_program_interpreter_available::Bool
    recoverable_gaps::Tuple{Vararg{String}}
    model_class::Symbol
    claim_ceiling::ClaimCeiling
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
    function DESCGeometryProgramAuditV4(token::_DGPPPrivateToken, fields...)
        token === _DGPP_TOKEN ||
            throw(ArgumentError("private DESC geometry program audit constructor"))
        new(fields...)
    end
end

function _dgpp_audit_values(x::DESCGeometryProgramAuditV4)
    ntuple(i -> getfield(x, i), fieldcount(DESCGeometryProgramAuditV4) - 1)
end

semantic_view(x::DESCGeometryProgramAuditV4) = merge(
    _dgpp_audit_body_from_values(_dgpp_audit_values(x)...),
    (audit_hash=x.audit_hash,))

function _dgpp_audit_body_from_values(values...)
    names = fieldnames(DESCGeometryProgramAuditV4)[1:end-1]
    NamedTuple{names}(values)
end

function canonical_hash(x::DESCGeometryProgramAuditV4)
    body = _dgpp_audit_body_from_values(_dgpp_audit_values(x)...)
    expected = canonical_hash(body)
    expected == x.audit_hash || throw(ArgumentError("geometry preflight audit hash mismatch"))
    x.revision == _DGPP_REVISION &&
        x.audit_kind === :desc_geometry_program_preflight ||
        throw(ArgumentError("geometry preflight audit schema mismatch"))
    _dgpp_gap_tuple(x.recoverable_gaps)
    expected_gaps = String[]
    x.normalized_turn_domain || push!(expected_gaps, _DGPP_LOCAL_GAPS[1])
    x.poloidal_turn_period_axis_declared ||
        push!(expected_gaps, _DGPP_LOCAL_GAPS[2])
    x.field_period_turn_axis_declared ||
        push!(expected_gaps, _DGPP_LOCAL_GAPS[3])
    x.periodic_turn_axis_set_exact || push!(expected_gaps, _DGPP_LOCAL_GAPS[4])
    x.coordinate_input_abi_exact && x.coordinate_output_abi_exact &&
        x.coordinate_identity_exact || push!(expected_gaps, _DGPP_LOCAL_GAPS[5])
    x.metric_input_abi_exact && x.metric_output_abi_exact &&
        x.metric_identity_exact || push!(expected_gaps, _DGPP_LOCAL_GAPS[6])
    x.normalized_physical_root_bridge_available ||
        push!(expected_gaps, _DGPP_LOCAL_GAPS[7])
    x.coordinate_program_shape_admissible ||
        push!(expected_gaps, _DGPP_LOCAL_GAPS[8])
    x.metric_program_shape_admissible || push!(expected_gaps, _DGPP_LOCAL_GAPS[9])
    x.operator_manifests_pinned || push!(expected_gaps, _DGPP_LOCAL_GAPS[10])
    x.geometry_program_interpreter_available ||
        push!(expected_gaps, _DGPP_LOCAL_GAPS[11])
    x.recoverable_gaps == _dgpp_order_gaps(expected_gaps) ||
        throw(ArgumentError("geometry preflight audit flags/gaps mismatch"))
    x.model_class === :manufactured_input_fixture && x.claim_ceiling == screen_only &&
        !x.normalized_physical_root_bridge_available &&
        !x.geometry_program_interpreter_available &&
        !x.geometry_proved && !x.certificate_emitted && !x.request_emitted &&
        !x.provider_selected && !x.provider_executed &&
        !x.solver_execution_attempted && !x.solver_executed &&
        !x.physical_validation && !x.engineering_validation &&
        !x.emits_evidence && !x.grants_pass && !x.promotion_authority &&
        !x.p5_ready && !x.terminal_authority &&
        x.credible_physical_device_count == 0 ||
        throw(ArgumentError("geometry preflight audit exceeded authority ceiling"))
    expected
end

function _dgpp_resolution_body(context_hash, status, audit, gaps)
    (revision=_DGPP_REVISION,
     resolution_kind=:desc_geometry_program_preflight_resolution,
     context_hash=context_hash, status=status, audit=audit,
     recoverable_gaps=gaps, model_class=:manufactured_input_fixture,
     claim_ceiling=screen_only, geometry_proved=false,
     certificate_emitted=false, request_emitted=false,
     provider_selected=false, provider_executed=false,
     solver_execution_attempted=false, solver_executed=false,
     physical_validation=false, engineering_validation=false,
     emits_evidence=false, grants_pass=false, promotion_authority=false,
     p5_ready=false, terminal_authority=false,
     credible_physical_device_count=0)
end

struct DESCGeometryProgramPreflightResolutionV4
    revision::String
    resolution_kind::Symbol
    context_hash::Digest256
    status::Symbol
    audit::Union{Nothing,DESCGeometryProgramAuditV4}
    recoverable_gaps::Tuple{Vararg{String}}
    model_class::Symbol
    claim_ceiling::ClaimCeiling
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
    function DESCGeometryProgramPreflightResolutionV4(
            token::_DGPPPrivateToken, fields...)
        token === _DGPP_TOKEN ||
            throw(ArgumentError("private DESC geometry preflight resolution constructor"))
        new(fields...)
    end
end

semantic_view(x::DESCGeometryProgramPreflightResolutionV4) = merge(
    _dgpp_resolution_body(x.context_hash, x.status, x.audit,
        x.recoverable_gaps), (resolution_hash=x.resolution_hash,))

function canonical_hash(x::DESCGeometryProgramPreflightResolutionV4)
    x.revision == _DGPP_REVISION &&
        x.resolution_kind === :desc_geometry_program_preflight_resolution ||
        throw(ArgumentError("geometry preflight resolution schema mismatch"))
    x.status === :recoverable_gap ||
        throw(ArgumentError("invalid geometry preflight status"))
    x.audit === nothing &&
        !any(g -> g in _DFBRC_GAP_VOCABULARY, x.recoverable_gaps) &&
        throw(ArgumentError("geometry preflight lacks an audit without an upstream gap"))
    x.audit === nothing || canonical_hash(x.audit)
    _dgpp_gap_tuple(x.recoverable_gaps)
    !isempty(x.recoverable_gaps) ||
        throw(ArgumentError("recoverable geometry preflight requires gaps"))
    x.audit === nothing || x.recoverable_gaps == x.audit.recoverable_gaps ||
        throw(ArgumentError("geometry preflight resolution/audit gaps mismatch"))
    x.audit === nothing || x.context_hash == x.audit.context_hash ||
        throw(ArgumentError("geometry preflight resolution/audit context mismatch"))
    body = _dgpp_resolution_body(x.context_hash, x.status, x.audit,
        x.recoverable_gaps)
    expected = canonical_hash(body)
    expected == x.resolution_hash ||
        throw(ArgumentError("geometry preflight resolution hash mismatch"))
    x.model_class === :manufactured_input_fixture && x.claim_ceiling == screen_only &&
        !x.geometry_proved && !x.certificate_emitted && !x.request_emitted &&
        !x.provider_selected && !x.provider_executed &&
        !x.solver_execution_attempted && !x.solver_executed &&
        !x.physical_validation && !x.engineering_validation &&
        !x.emits_evidence && !x.grants_pass && !x.promotion_authority &&
        !x.p5_ready && !x.terminal_authority &&
        x.credible_physical_device_count == 0 ||
        throw(ArgumentError("geometry preflight resolution exceeded authority ceiling"))
    expected
end

function _dgpp_resolution(context_hash, status, audit, gaps)
    gap_tuple = _dgpp_order_gaps(gaps)
    body = _dgpp_resolution_body(context_hash, status, audit, gap_tuple)
    result = DESCGeometryProgramPreflightResolutionV4(_DGPP_TOKEN,
        values(body)..., canonical_hash(body))
    canonical_hash(result)
    result
end

function _dgpp_field_graph(context)
    graphs = Tuple(graph for genome in context.genome_bindings
        for graph in genome.graph_bindings if graph.role === :field_geometry)
    length(graphs) == 1 ||
        throw(ArgumentError("forward field/geometry graph is missing or ambiguous"))
    graph = only(graphs)
    canonical_hash(graph)
    graph
end

function _dgpp_support_chart(candidate, coordinate)
    supports = Tuple(x for x in candidate.field_geometry_genome_ref.fields
        if typeof(x) === SpatialSupportGeneV1 &&
           x.support_ref == coordinate.support_ref)
    length(supports) == 1 ||
        throw(ArgumentError("DESC coordinate support is missing or ambiguous"))
    support = only(supports)
    charts = Tuple(x for x in support.charts
        if x.chart_ref == coordinate.chart_ref)
    length(charts) == 1 ||
        throw(ArgumentError("DESC coordinate chart is missing or ambiguous"))
    support, only(charts)
end

function _dgpp_edge(graph, site::FieldOperatorSiteRefV1, label::String)
    matches = Tuple(edge for edge in graph.graph.hyperedges
        if edge.edge_id == site.value)
    length(matches) == 1 ||
        throw(ArgumentError("$label program edge is missing or ambiguous"))
    only(matches)
end

function _dgpp_root_position_valid(edge, root_position::Int)
    _, roots, _ = _forward_edge_program(edge)
    1 <= root_position <= length(roots)
end

function _dgpp_program_details(graph, edge, root_position::Int)
    nodes, roots, program_hash = _forward_edge_program(edge)
    1 <= root_position <= length(roots) ||
        throw(ArgumentError("declared chart root position is outside its program"))
    root_node_index = roots[root_position]
    graph_node_index = _forward_root_output_node(edge, root_position)
    edge_position = findfirst(==(edge), graph.graph.hyperedges)
    edge_position === nothing && throw(ArgumentError("program edge is foreign to G2 graph"))
    root_offset = sum((length(_forward_edge_program(prior)[2])
        for prior in graph.graph.hyperedges[1:edge_position-1]); init=0)
    identity_hash = graph.ast_root_identity_hashes[root_offset + root_position]
    if edge isa TypedHyperedge
        input_nodes = edge.inputs
        input_ports = edge.ast.input_ports
        manifests = edge.ast.manifest_bindings
        shape_admissible = length(input_ports) == 1 &&
            length(input_nodes) == 1 &&
            nodes[root_node_index].opcode ∉ (:state, :parameter, :constant) &&
            _dgpp_depends_on(nodes, root_node_index, only(input_ports))
        input_type = length(input_ports) == 1 ? nodes[only(input_ports)].output_type : nothing
    elseif edge isa AtomicMIMOHyperedgeV1
        input_nodes = Tuple(b.graph_node_index for b in edge.input_bindings)
        input_ports = edge.program.input_ports
        manifests = edge.program.used_manifest_bindings
        shape_admissible = length(input_ports) == 1 && length(input_nodes) == 1 &&
            !(nodes[root_node_index] isa ASTInputV1) &&
            !(nodes[root_node_index] isa ASTParameterV1) &&
            !(nodes[root_node_index] isa ASTConstantV1) &&
            _dgpp_depends_on(nodes, root_node_index, only(input_ports))
        input_type = length(input_ports) == 1 ?
            nodes[only(input_ports)].output_type : nothing
    else
        throw(ArgumentError("unsealed geometry program edge type"))
    end
    (nodes=nodes, roots=roots, program_hash=program_hash,
     root_node_index=root_node_index,
     root_type=nodes[root_node_index].output_type,
     graph_output_type=graph.graph.nodes[graph_node_index].physical_type,
     input_type=input_type, input_count=length(input_ports),
     graph_input_count=length(input_nodes), manifests=Tuple(manifests),
     shape_admissible=shape_admissible, identity_hash=identity_hash)
end

function _dgpp_depends_on(nodes, position::Int, input_position::Int)
    position == input_position && return true
    node = nodes[position]
    inputs = node isa TypedASTNode ? node.inputs :
        node isa ASTApplyV1 ? node.inputs : ()
    any(i -> _dgpp_depends_on(nodes, i, input_position), inputs)
end

function _dgpp_manifests_exact(bindings)
    isempty(bindings) && return false
    operator_registry = default_operator_registry()
    all(bindings) do binding
        ref, digest = binding
        manifest = try
            operator_manifest(operator_registry, ref.qualified)
        catch
            return false
        end
        manifest.operator_ref == ref && manifest.manifest_hash == digest
    end
end

function _dgpp_unit_turn_domain(chart)
    all(bound -> bound.unit == UnitSignature() &&
        bound.interval.lower == 0//1 && bound.interval.upper == 1//1 &&
        !bound.interval.allow_equal, chart.chart_bounds)
end

function _dgpp_periodic_unit_axis(chart, position::Int)
    matches = Tuple(axis for axis in chart.periodic_axes
        if axis.axis_position == position)
    length(matches) == 1 && only(matches).period.unit == UnitSignature() &&
        only(matches).period.value == 1//1
end


_dgpp_exact_periodic_axis_set(chart) =
    Tuple(axis.axis_position for axis in chart.periodic_axes) == (2, 3)

function _dgpp_rebuild_request_binding(context, inventory)
    make_desc_fixed_boundary_request_binding(context.compiled,
        context.registry, context.mission_payload, context.bounds_payload,
        context.comparison_scope, context.scenario_scope, context.scenario,
        only(inventory.composition_bindings), only(inventory.physical_bindings),
        only(inventory.support_mapping_bindings),
        only(inventory.region_law_bindings), only(inventory.oriented_bindings),
        only(inventory.residual_bindings),
        only(inventory.discretization_bindings),
        only(inventory.compatibility), only(inventory.declarations))
end

"""Audit the exact candidate-owned G2 geometry-program ABI.

This revision is intentionally gap-only: the accepted upstream schema lacks a
normalized-to-SI root bridge and RuntimeV4 lacks a geometry-program
interpreter. It is not a geometry proof or a DESC request authorization.
"""
function preflight_desc_geometry_program(context::ForwardChainContextV4)
    validate_forward_chain_context(context)
    composition_resolution = compose_three_d_physical_inputs(context)
    composition_resolution.status === :input_complete ||
        return _dgpp_resolution(context.context_hash, :recoverable_gap,
            nothing, composition_resolution.recoverable_gaps)
    inventory = _dfbrc_inventory(context)
    length(inventory.bindings) > 1 &&
        throw(ArgumentError("duplicate DESC request bindings are an integrity error"))
    groups = (inventory.composition_bindings, inventory.physical_bindings,
        inventory.support_mapping_bindings, inventory.region_law_bindings,
        inventory.oriented_bindings, inventory.residual_bindings,
        inventory.discretization_bindings)
    length(inventory.bindings) == 1 &&
        (length(inventory.compatibility) != 1 ||
         length(inventory.declarations) != 1 ||
         any(x -> length(x) != 1, groups)) &&
        throw(ArgumentError("orphan DESC binding lacks exact declarations or upstream bindings"))
    inventory_gaps = _dfbrc_inventory_gaps(inventory)
    isempty(inventory_gaps) ||
        return _dgpp_resolution(context.context_hash, :recoverable_gap,
            nothing, inventory_gaps)
    all(x -> length(x) == 1, groups) ||
        throw(ArgumentError("DESC geometry preflight requires exact upstream bindings"))

    rebuilt_binding = _dgpp_rebuild_request_binding(context, inventory)
    request_binding = only(inventory.bindings)
    canonical_hash(request_binding) == canonical_hash(rebuilt_binding) &&
        semantic_view(request_binding) == semantic_view(rebuilt_binding) ||
        throw(ArgumentError("DESC request binding is foreign to current context"))

    composition = something(composition_resolution.input)
    compatibility = only(inventory.compatibility)
    declaration = only(inventory.declarations)
    physical = composition.physical
    coordinate = physical.coordinate_metric
    support, chart = _dgpp_support_chart(context.candidate, coordinate)
    field_graph = _dgpp_field_graph(context)
    coordinate_edge = _dgpp_edge(field_graph,
        coordinate.coordinate_map_site_ref, "coordinate-map")
    metric_edge = _dgpp_edge(field_graph, coordinate.metric_site_ref, "metric")
    coordinate_root_position_valid = _dgpp_root_position_valid(
        coordinate_edge, chart.coordinate_map_root.root_position)
    metric_root_position_valid = _dgpp_root_position_valid(
        metric_edge, chart.metric_program_root.root_position)
    coordinate_root_position_valid && metric_root_position_valid ||
        throw(ArgumentError(
            "DESC chart root position does not select an actual G2 program root"))
    coordinate_details = _dgpp_program_details(field_graph, coordinate_edge,
        chart.coordinate_map_root.root_position)
    metric_details = _dgpp_program_details(field_graph, metric_edge,
        chart.metric_program_root.root_position)

    coordinate_input = coordinate_details.input_count == 1 &&
        coordinate_details.graph_input_count == 1 &&
        coordinate_details.input_type == chart.coordinate_map_root.declared_input_type
    metric_input = metric_details.input_count == 1 &&
        metric_details.graph_input_count == 1 &&
        metric_details.input_type == chart.metric_program_root.declared_input_type
    coordinate_output = coordinate_details.root_type ==
        chart.coordinate_map_root.declared_type &&
        coordinate_details.graph_output_type == chart.coordinate_map_root.declared_type
    metric_output = metric_details.root_type ==
        chart.metric_program_root.declared_type &&
        metric_details.graph_output_type == chart.metric_program_root.declared_type
    coordinate_identity = coordinate_details.identity_hash ==
        coordinate.coordinate_map_root_identity_hash
    metric_identity = metric_details.identity_hash ==
        coordinate.metric_root_identity_hash
    normalized_domain = _dgpp_unit_turn_domain(chart)
    poloidal_periodic = _dgpp_periodic_unit_axis(chart, 2)
    field_periodic = _dgpp_periodic_unit_axis(chart, 3)
    periodic_axis_set_exact = _dgpp_exact_periodic_axis_set(chart)
    coordinate_shape = coordinate_details.shape_admissible
    metric_shape = metric_details.shape_admissible
    manifests_pinned = _dgpp_manifests_exact(coordinate_details.manifests) &&
        _dgpp_manifests_exact(metric_details.manifests)
    # Current upstream types cannot represent the required pair of normalized
    # chart roots and SI physical roots as one joined program ABI.  Likewise no
    # pinned RuntimeV4 interpreter implements component assembly, sinpi/cospi,
    # symbolic derivatives, or metric derivation.  These are explicit
    # prerequisite gaps, never inferred from a nonempty manifest tuple.
    bridge_available = false
    interpreter_available = false

    gaps = String[]
    normalized_domain || push!(gaps, _DGPP_LOCAL_GAPS[1])
    poloidal_periodic || push!(gaps, _DGPP_LOCAL_GAPS[2])
    field_periodic || push!(gaps, _DGPP_LOCAL_GAPS[3])
    periodic_axis_set_exact || push!(gaps, _DGPP_LOCAL_GAPS[4])
    coordinate_input && coordinate_output && coordinate_identity ||
        push!(gaps, _DGPP_LOCAL_GAPS[5])
    metric_input && metric_output && metric_identity ||
        push!(gaps, _DGPP_LOCAL_GAPS[6])
    bridge_available || push!(gaps, _DGPP_LOCAL_GAPS[7])
    coordinate_shape || push!(gaps, _DGPP_LOCAL_GAPS[8])
    metric_shape || push!(gaps, _DGPP_LOCAL_GAPS[9])
    manifests_pinned || push!(gaps, _DGPP_LOCAL_GAPS[10])
    interpreter_available || push!(gaps, _DGPP_LOCAL_GAPS[11])
    gap_tuple = _dgpp_order_gaps(gaps)

    body = _dgpp_audit_body(context, composition, compatibility, declaration,
        request_binding, field_graph, support, chart, coordinate_edge,
        metric_edge, coordinate_details.program_hash,
        metric_details.program_hash, coordinate_details.identity_hash,
        metric_details.identity_hash,
        canonical_hash(chart.coordinate_map_root),
        canonical_hash(chart.metric_program_root), coordinate_input,
        metric_input, coordinate_output, metric_output,
        coordinate_identity, metric_identity, normalized_domain,
        poloidal_periodic, field_periodic, periodic_axis_set_exact,
        bridge_available,
        coordinate_shape, metric_shape, manifests_pinned,
        interpreter_available, gap_tuple)
    body_values = Tuple(Base.values(body))
    audit = DESCGeometryProgramAuditV4(_DGPP_TOKEN, body_values...,
        canonical_hash(body))
    canonical_hash(audit)
    _dgpp_resolution(context.context_hash, :recoverable_gap, audit, gap_tuple)
end

validate_desc_geometry_program_preflight(
    context::ForwardChainContextV4,
    resolution::DESCGeometryProgramPreflightResolutionV4) = begin
    expected = preflight_desc_geometry_program(context)
    canonical_hash(resolution) == canonical_hash(expected) &&
        semantic_view(resolution) == semantic_view(expected) ||
        throw(ArgumentError("geometry preflight resolution differs from current context"))
    resolution.resolution_hash
end

validate_desc_geometry_program_preflight(
    ::DESCGeometryProgramPreflightResolutionV4) = false

desc_geometry_program_preflight_manifest() = (
    schema=_DGPP_SCHEMA, revision=_DGPP_REVISION,
    purpose=:candidate_bound_desc_geometry_program_abi_preflight,
    statuses=(:recoverable_gap,), program_ready=false,
    verifies_chart_root_graph_abi=true,
    requires_normalized_turn_domain=true,
    requires_poloidal_and_field_period_axes=true,
    requires_executable_coordinate_and_metric_programs=true,
    geometry_proved=false, certificate_emitted=false,
    request_emitted=false, model_class=:manufactured_input_fixture,
    claim_ceiling=screen_only, provider_selected=false,
    provider_executed=false, solver_execution_attempted=false,
    solver_executed=false, physical_validation=false,
    engineering_validation=false, emits_evidence=false,
    grants_pass=false, promotion_authority=false, p5_ready=false,
    terminal_authority=false, credible_physical_device_count=0)
