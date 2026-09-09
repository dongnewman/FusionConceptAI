"""Compiler-only slice for typed 3-D region constitutive/source/boundary laws.

The declaration is derived from one real G2 `ForwardGraphBindingV4`.  Resolution
revalidates the current `ForwardChainContextV4` and every node, hyperedge,
program, and AST-root identity.  This file selects and executes no provider and
creates no evidence, stage outcome, promotion, P5 claim, or terminal authority.
"""

using FusionConceptAI
import FusionConceptAI: canonical_hash, semantic_view

const _TDRL_REVISION = "runtime-v4-three-d-region-law-compiler-v1"
const _TDRL_SCHEMA = "fusionconceptai:runtime-v4-three-d-region-law-compiler"
const _TDRL_TOKEN = Val(:three_d_region_law_compiler_private)
const _TDRL_GAP = "required_typed_three_d_region_constitutive_source_boundary"
const _TDRL_BINDING_GAP = "required_typed_three_d_region_law_subject_binding"
const _TDRL_DOWNSTREAM_GAPS = (
    "required_typed_three_d_oriented_interface_discrete_spaces",
    "required_typed_three_d_governing_residual_jacobian_ownership",
    "required_typed_three_d_discretization_controls")

function _tdrl_text(value, field::String)
    typeof(value) === String || throw(ArgumentError("$field must be an immutable String"))
    text = strip(value)
    !isempty(text) && isvalid(text) || throw(ArgumentError("$field cannot be empty"))
    lowered = lowercase(text)
    (lowered in ("*", "any", "all", "wildcard") || occursin('*', text)) &&
        throw(ArgumentError("$field cannot contain a wildcard"))
    String(text)
end

function _tdrl_static_3d_type(value::PhysicalType, field::String)
    value.spatial_dimension == 3 || throw(ArgumentError("$field must be three-dimensional"))
    value.temporal_type == TemporalTypeV1(static_time) ||
        throw(ArgumentError("$field must use static time semantics"))
    value
end

"""Identity of one law root derived from an owned AtomicMIMO hyperedge."""
struct ThreeDRegionLawRootV4
    law_kind::Symbol
    edge_id::String
    edge_role::Symbol
    edge_identity_hash::Digest256
    program_hash::Digest256
    ast_root_identity_hash::Digest256
    output_node_id::String
    output_node_identity_hash::Digest256
    output_type::PhysicalType
    function ThreeDRegionLawRootV4(
            token::Val{:three_d_region_law_compiler_private}, fields...)
        token === _TDRL_TOKEN || throw(ArgumentError("private 3-D region-law root constructor"))
        new(fields...)
    end
end

semantic_view(x::ThreeDRegionLawRootV4) = (
    law_kind=x.law_kind, edge_id=x.edge_id, edge_role=x.edge_role,
    edge_identity_hash=x.edge_identity_hash, program_hash=x.program_hash,
    ast_root_identity_hash=x.ast_root_identity_hash,
    output_node_id=x.output_node_id,
    output_node_identity_hash=x.output_node_identity_hash,
    output_type=x.output_type)

function _tdrl_declaration_body(declaration_id, graph_hash, graph_binding_hash,
        region_node_id, region_node_identity_hash, region_type,
        constitutive_law, source_law, boundary_law)
    (revision=_TDRL_REVISION, declaration_id=declaration_id,
     field_geometry_graph_hash=graph_hash,
     field_geometry_graph_binding_hash=graph_binding_hash,
     region_node_id=region_node_id,
     region_node_identity_hash=region_node_identity_hash,
     region_type=region_type, constitutive_law=constitutive_law,
     source_law=source_law, boundary_law=boundary_law,
     model_class=:manufactured_compiler_fixture,
     claim_ceiling=screen_only, provider_selected=false,
     provider_executed=false, emits_evidence=false, grants_pass=false,
     promotion_authority=false, p5_ready=false, terminal_authority=false,
     credible_physical_device_count=0)
end

"""Three typed laws and their exact current-G2 ownership identities."""
struct ThreeDRegionConstitutiveSourceBoundaryV4
    declaration_id::String
    field_geometry_graph_hash::Digest256
    field_geometry_graph_binding_hash::Digest256
    region_node_id::String
    region_node_identity_hash::Digest256
    region_type::PhysicalType
    constitutive_law::ThreeDRegionLawRootV4
    source_law::ThreeDRegionLawRootV4
    boundary_law::ThreeDRegionLawRootV4
    model_class::Symbol
    claim_ceiling::ClaimCeiling
    provider_selected::Bool
    provider_executed::Bool
    emits_evidence::Bool
    grants_pass::Bool
    promotion_authority::Bool
    p5_ready::Bool
    terminal_authority::Bool
    credible_physical_device_count::Int
    declaration_hash::Digest256
    function ThreeDRegionConstitutiveSourceBoundaryV4(
            token::Val{:three_d_region_law_compiler_private}, fields...)
        token === _TDRL_TOKEN || throw(ArgumentError("private 3-D region-law declaration constructor"))
        new(fields...)
    end
end

semantic_view(x::ThreeDRegionConstitutiveSourceBoundaryV4) = merge(
    _tdrl_declaration_body(x.declaration_id, x.field_geometry_graph_hash,
        x.field_geometry_graph_binding_hash, x.region_node_id,
        x.region_node_identity_hash, x.region_type, x.constitutive_law,
        x.source_law, x.boundary_law),
    (declaration_hash=x.declaration_hash,))

function canonical_hash(x::ThreeDRegionConstitutiveSourceBoundaryV4)
    expected = canonical_hash(_tdrl_declaration_body(x.declaration_id,
        x.field_geometry_graph_hash, x.field_geometry_graph_binding_hash,
        x.region_node_id, x.region_node_identity_hash, x.region_type,
        x.constitutive_law, x.source_law, x.boundary_law))
    expected == x.declaration_hash ||
        throw(ArgumentError("3-D region-law declaration hash mismatch"))
    x.model_class === :manufactured_compiler_fixture &&
        x.claim_ceiling == screen_only && !x.provider_selected &&
        !x.provider_executed && !x.emits_evidence && !x.grants_pass &&
        !x.promotion_authority && !x.p5_ready && !x.terminal_authority &&
        x.credible_physical_device_count == 0 ||
        throw(ArgumentError("3-D region-law declaration authority ceiling was exceeded"))
    expected
end

function _tdrl_edge_root_inventory(binding::ForwardGraphBindingV4)
    binding.role === :field_geometry ||
        throw(ArgumentError("3-D region laws require the G2 field-geometry graph"))
    canonical_hash(binding)
    roots = NamedTuple[]
    root_index = 0
    for (edge_position, edge) in enumerate(binding.graph.hyperedges)
        nodes, program_roots, program_hash = _forward_edge_program(edge)
        for (root_position, program_node_index) in enumerate(program_roots)
            root_index += 1
            output_index = _forward_root_output_node(edge, root_position)
            push!(roots, (edge=edge, edge_position=edge_position,
                edge_identity_hash=binding.hyperedge_identity_hashes[edge_position],
                program_nodes=nodes, program_root_index=program_node_index,
                program_hash=program_hash,
                ast_root_identity_hash=binding.ast_root_identity_hashes[root_index],
                output_index=output_index,
                output_node=binding.graph.nodes[output_index],
                output_node_identity_hash=binding.node_identity_hashes[output_index]))
        end
    end
    root_index == length(binding.ast_root_identity_hashes) ||
        throw(ArgumentError("G2 AST-root count mismatch"))
    Tuple(roots)
end

function _tdrl_node(binding::ForwardGraphBindingV4, node_id::String,
        node_kind::Symbol, field::String)
    hits = Tuple((index=i, node=n, identity_hash=binding.node_identity_hashes[i])
        for (i, n) in enumerate(binding.graph.nodes) if n.node_id == node_id)
    length(hits) == 1 || throw(ArgumentError("$field is absent from or ambiguous in current G2"))
    hit = only(hits)
    hit.node.node_kind === node_kind || throw(ArgumentError("$field has the wrong typed node kind"))
    _tdrl_static_3d_type(hit.node.physical_type, field)
    hit
end

function _tdrl_law_root(binding::ForwardGraphBindingV4, edge_id::String,
        law_kind::Symbol, expected_role::HyperedgeRoleV1,
        expected_input_node::Int, expected_output_kind::Symbol)
    roots = Tuple(r for r in _tdrl_edge_root_inventory(binding)
        if r.edge.edge_id == edge_id)
    length(roots) == 1 ||
        throw(ArgumentError("$law_kind law edge must have exactly one current G2 AST root"))
    root = only(roots)
    edge = root.edge
    typeof(edge) === AtomicMIMOHyperedgeV1 ||
        throw(ArgumentError("$law_kind law must be an AtomicMIMOHyperedgeV1"))
    edge.role === expected_role || throw(ArgumentError("$law_kind law has the wrong typed edge role"))
    length(edge.input_bindings) == 1 &&
        only(edge.input_bindings).graph_node_index == expected_input_node ||
        throw(ArgumentError("$law_kind law is not owned by the declared region input"))
    root.output_node.node_kind === expected_output_kind ||
        throw(ArgumentError("$law_kind law has the wrong typed output node kind"))
    _tdrl_static_3d_type(root.output_node.physical_type, "$law_kind law output")
    program_node = root.program_nodes[root.program_root_index]
    program_node isa ASTApplyV1 ||
        throw(ArgumentError("$law_kind law root must be a registered AST operator application"))
    manifest = operator_manifest(edge.registry,
        program_node.operator_ref.qualified.id,
        program_node.operator_ref.qualified.version)
    manifest.manifest_hash == only(Tuple(h for (ref, h) in edge.program.used_manifest_bindings
        if ref == program_node.operator_ref)) ||
        throw(ArgumentError("$law_kind law root manifest identity mismatch"))
    ThreeDRegionLawRootV4(_TDRL_TOKEN, law_kind, edge.edge_id,
        Symbol(edge.role), root.edge_identity_hash, root.program_hash,
        root.ast_root_identity_hash, root.output_node.node_id,
        root.output_node_identity_hash, root.output_node.physical_type)
end

"""Derive a law declaration only from exact objects already owned by one G2 graph."""
function declare_three_d_region_laws(binding::ForwardGraphBindingV4;
        declaration_id::String, region_node_id::String,
        constitutive_edge_id::String, source_edge_id::String,
        boundary_edge_id::String)
    canonical_hash(binding)
    id = _tdrl_text(declaration_id, "declaration_id")
    region_id = _tdrl_text(region_node_id, "region_node_id")
    region = _tdrl_node(binding, region_id, :region, "region node")
    constitutive = _tdrl_law_root(binding,
        _tdrl_text(constitutive_edge_id, "constitutive_edge_id"),
        :constitutive, governing, region.index, :region)
    source_law = _tdrl_law_root(binding,
        _tdrl_text(source_edge_id, "source_edge_id"),
        :source, source, region.index, :source)
    boundary_law = _tdrl_law_root(binding,
        _tdrl_text(boundary_edge_id, "boundary_edge_id"),
        :boundary, boundary, region.index, :boundary)
    constitutive.output_node_identity_hash == region.identity_hash ||
        throw(ArgumentError("constitutive law must close on the declared region node"))
    length(unique((constitutive.edge_identity_hash, source_law.edge_identity_hash,
        boundary_law.edge_identity_hash))) == 3 ||
        throw(ArgumentError("constitutive/source/boundary laws must be distinct hyperedges"))
    graph_hash = binding.canonical_graph_hash
    graph_binding_hash = canonical_hash(binding)
    body = _tdrl_declaration_body(id, graph_hash, graph_binding_hash,
        region_id, region.identity_hash, region.node.physical_type,
        constitutive, source_law, boundary_law)
    ThreeDRegionConstitutiveSourceBoundaryV4(_TDRL_TOKEN, id, graph_hash,
        graph_binding_hash, region_id, region.identity_hash,
        region.node.physical_type, constitutive, source_law, boundary_law,
        :manufactured_compiler_fixture, screen_only, false, false, false,
        false, false, false, false, 0, canonical_hash(body))
end

function _tdrl_validate_declaration(candidate::CandidateStatePackageV4,
        graph::ForwardGraphBindingV4,
        declaration::ThreeDRegionConstitutiveSourceBoundaryV4)
    canonical_hash(declaration)
    matches = Tuple(x for x in candidate.field_geometry_genome_ref.fields
        if typeof(x) === ThreeDRegionConstitutiveSourceBoundaryV4 &&
           canonical_hash(x) == declaration.declaration_hash)
    length(matches) == 1 ||
        throw(ArgumentError("3-D region-law declaration is absent from or ambiguous in current G2 fields"))
    declaration.field_geometry_graph_hash == graph.canonical_graph_hash ||
        throw(ArgumentError("3-D region-law declaration has a foreign G2 graph"))
    declaration.field_geometry_graph_binding_hash == canonical_hash(graph) ||
        throw(ArgumentError("3-D region-law declaration has a foreign G2 graph binding"))
    rebuilt = declare_three_d_region_laws(graph;
        declaration_id=declaration.declaration_id,
        region_node_id=declaration.region_node_id,
        constitutive_edge_id=declaration.constitutive_law.edge_id,
        source_edge_id=declaration.source_law.edge_id,
        boundary_edge_id=declaration.boundary_law.edge_id)
    canonical_hash(rebuilt) == declaration.declaration_hash ||
        throw(ArgumentError("3-D region-law declaration does not equal current G2 identities"))
    declaration.declaration_hash
end

function _tdrl_binding_body(declaration_hash, genome_hash, graph_hash,
        graph_binding_hash, law_root_hashes, mission_hash, bounds_hash,
        scenario_hash)
    (revision=_TDRL_REVISION, binding_kind=:three_d_region_law_subject_binding,
     declaration_hash=declaration_hash,
     field_geometry_genome_hash=genome_hash,
     field_geometry_graph_hash=graph_hash,
     field_geometry_graph_binding_hash=graph_binding_hash,
     law_root_identity_hashes=law_root_hashes,
     mission_hash=mission_hash, bounds_hash=bounds_hash,
     scenario_hash=scenario_hash)
end

"""Sealed materialization binding for one candidate/scenario law declaration."""
struct ThreeDRegionLawBindingV4
    declaration_hash::Digest256
    field_geometry_genome_hash::Digest256
    field_geometry_graph_hash::Digest256
    field_geometry_graph_binding_hash::Digest256
    law_root_identity_hashes::NTuple{3,Digest256}
    mission_hash::Digest256
    bounds_hash::Digest256
    scenario_hash::Digest256
    binding_hash::Digest256
    function ThreeDRegionLawBindingV4(
            token::Val{:three_d_region_law_compiler_private}, fields...)
        token === _TDRL_TOKEN || throw(ArgumentError("private 3-D region-law binding constructor"))
        new(fields...)
    end
end


semantic_view(x::ThreeDRegionLawBindingV4) = merge(
    _tdrl_binding_body(x.declaration_hash, x.field_geometry_genome_hash,
        x.field_geometry_graph_hash, x.field_geometry_graph_binding_hash,
        x.law_root_identity_hashes, x.mission_hash, x.bounds_hash,
        x.scenario_hash), (binding_hash=x.binding_hash,))

function canonical_hash(x::ThreeDRegionLawBindingV4)
    expected = canonical_hash(_tdrl_binding_body(x.declaration_hash,
        x.field_geometry_genome_hash, x.field_geometry_graph_hash,
        x.field_geometry_graph_binding_hash, x.law_root_identity_hashes,
        x.mission_hash, x.bounds_hash, x.scenario_hash))
    expected == x.binding_hash ||
        throw(ArgumentError("3-D region-law binding hash mismatch"))
    expected
end

"""Create the subject binding before constructing `ForwardChainContextV4`."""
function make_three_d_region_law_binding(compiled::CompiledCandidatePrefixV4,
        registry::GenomeContractRegistryV4, mission_payload, bounds_payload,
        comparison_scope, scenario_scope, scenario,
        declaration::ThreeDRegionConstitutiveSourceBoundaryV4)
    comparison = _runtime_axis_tuple(comparison_scope, "comparison_scope")
    scenarios = _runtime_axis_tuple(scenario_scope, "scenario_scope")
    _runtime_validate_compiled_prefix(compiled, compiled.candidate, registry,
        mission_payload, bounds_payload, comparison, scenarios)
    is_canonical_value(scenario) ||
        throw(ArgumentError("3-D region-law binding scenario is not canonicalizable"))
    scenario_hash = canonical_hash(scenario)
    _forward_scenario_name(scenario) in scenarios ||
        throw(ArgumentError("3-D region-law binding scenario is outside frozen scope"))
    graph = _make_forward_graph_binding(:field_geometry,
        compiled.field_geometry_graph)
    declaration_hash = _tdrl_validate_declaration(compiled.candidate, graph,
        declaration)
    roots = (declaration.constitutive_law.ast_root_identity_hash,
        declaration.source_law.ast_root_identity_hash,
        declaration.boundary_law.ast_root_identity_hash)
    genome_hash = field_geometry_hash(compiled.candidate.field_geometry_genome_ref)
    graph_hash = graph.canonical_graph_hash
    graph_binding_hash = canonical_hash(graph)
    mission_hash = _runtime_decl_hash(mission_payload)
    bounds_hash = _runtime_decl_hash(bounds_payload)
    body = _tdrl_binding_body(declaration_hash, genome_hash, graph_hash,
        graph_binding_hash, roots, mission_hash, bounds_hash, scenario_hash)
    ThreeDRegionLawBindingV4(_TDRL_TOKEN, declaration_hash, genome_hash,
        graph_hash, graph_binding_hash, roots, mission_hash, bounds_hash,
        scenario_hash, canonical_hash(body))
end

function _tdrl_context_binding(context::ForwardChainContextV4,
        declaration::ThreeDRegionConstitutiveSourceBoundaryV4)
    bindings = Tuple(x for x in context.subject.bindings
        if typeof(x) === ThreeDRegionLawBindingV4)
    length(bindings) == 1 ||
        throw(ArgumentError("physical subject must contain exactly one typed 3-D region-law binding"))
    binding = only(bindings)
    canonical_hash(binding)
    graph = forward_graph_binding(context, :field_geometry)
    declaration_hash = _tdrl_validate_declaration(context.candidate, graph,
        declaration)
    rebuilt = make_three_d_region_law_binding(context.compiled,
        context.registry, context.mission_payload, context.bounds_payload,
        context.comparison_scope, context.scenario_scope, context.scenario,
        declaration)
    binding.declaration_hash == declaration_hash ||
        throw(ArgumentError("3-D region-law binding declaration is foreign"))
    binding.field_geometry_genome_hash == rebuilt.field_geometry_genome_hash ||
        throw(ArgumentError("3-D region-law binding G2 Genome is foreign"))
    binding.field_geometry_graph_hash == rebuilt.field_geometry_graph_hash ||
        throw(ArgumentError("3-D region-law binding G2 graph is foreign"))
    binding.field_geometry_graph_binding_hash ==
        rebuilt.field_geometry_graph_binding_hash ||
        throw(ArgumentError("3-D region-law binding G2 graph identity is foreign"))
    binding.law_root_identity_hashes == rebuilt.law_root_identity_hashes ||
        throw(ArgumentError("3-D region-law binding AST-root identities are foreign"))
    binding.mission_hash == rebuilt.mission_hash ||
        throw(ArgumentError("3-D region-law binding mission is foreign"))
    binding.bounds_hash == rebuilt.bounds_hash ||
        throw(ArgumentError("3-D region-law binding bounds are foreign"))
    binding.scenario_hash == rebuilt.scenario_hash ||
        throw(ArgumentError("3-D region-law binding scenario is foreign"))
    binding.binding_hash == rebuilt.binding_hash ||
        throw(ArgumentError("3-D region-law binding content is foreign"))
    binding
end

function _tdrl_resolution_body(context_hash, status, declaration_hash,
        binding_hash, compiled_law_root_hashes, recoverable_gaps)
    (revision=_TDRL_REVISION, kind=:three_d_region_law_compilation,
     context_hash=context_hash, status=status,
     declaration_hash=declaration_hash,
     binding_hash=binding_hash,
     compiled_law_root_hashes=compiled_law_root_hashes,
     recoverable_gaps=recoverable_gaps,
     claim_ceiling=screen_only, provider_selected=false,
     provider_executed=false, emits_evidence=false, grants_pass=false,
     promotion_authority=false, p5_ready=false, terminal_authority=false,
     credible_physical_device_count=0)
end

struct ThreeDRegionLawCompilationV4
    context_hash::Digest256
    status::Symbol
    declaration_hash::Union{Nothing,Digest256}
    binding_hash::Union{Nothing,Digest256}
    compiled_law_root_hashes::Tuple{Vararg{Digest256}}
    recoverable_gaps::Tuple{Vararg{String}}
    claim_ceiling::ClaimCeiling
    provider_selected::Bool
    provider_executed::Bool
    emits_evidence::Bool
    grants_pass::Bool
    promotion_authority::Bool
    p5_ready::Bool
    terminal_authority::Bool
    credible_physical_device_count::Int
    compilation_hash::Digest256
    function ThreeDRegionLawCompilationV4(
            token::Val{:three_d_region_law_compiler_private}, fields...)
        token === _TDRL_TOKEN || throw(ArgumentError("private 3-D region-law compilation constructor"))
        new(fields...)
    end
end

semantic_view(x::ThreeDRegionLawCompilationV4) = merge(
    _tdrl_resolution_body(x.context_hash, x.status, x.declaration_hash,
        x.binding_hash, x.compiled_law_root_hashes, x.recoverable_gaps),
    (compilation_hash=x.compilation_hash,))

function canonical_hash(x::ThreeDRegionLawCompilationV4)
    x.status in (:compiled, :recoverable_gap) ||
        throw(ArgumentError("invalid 3-D region-law compilation status"))
    if x.status === :compiled
        x.declaration_hash !== nothing && x.binding_hash !== nothing &&
            length(x.compiled_law_root_hashes) == 3 &&
            x.recoverable_gaps == _TDRL_DOWNSTREAM_GAPS ||
            throw(ArgumentError("compiled 3-D region-law result is incomplete"))
    else
        x.binding_hash === nothing && isempty(x.compiled_law_root_hashes) &&
            !isempty(x.recoverable_gaps) ||
            throw(ArgumentError("recoverable 3-D region-law gap is malformed"))
        if x.declaration_hash === nothing
            x.recoverable_gaps == (_TDRL_GAP, _TDRL_BINDING_GAP,
                _TDRL_DOWNSTREAM_GAPS...) ||
                throw(ArgumentError("generic 3-D region-law gaps are malformed"))
        else
            x.recoverable_gaps == (_TDRL_BINDING_GAP,
                _TDRL_DOWNSTREAM_GAPS...) ||
                throw(ArgumentError("3-D region-law subject-binding gap is malformed"))
        end
    end
    expected = canonical_hash(_tdrl_resolution_body(x.context_hash, x.status,
        x.declaration_hash, x.binding_hash, x.compiled_law_root_hashes,
        x.recoverable_gaps))
    expected == x.compilation_hash ||
        throw(ArgumentError("3-D region-law compilation hash mismatch"))
    x.claim_ceiling == screen_only && !x.provider_selected &&
        !x.provider_executed && !x.emits_evidence && !x.grants_pass &&
        !x.promotion_authority && !x.p5_ready && !x.terminal_authority &&
        x.credible_physical_device_count == 0 ||
        throw(ArgumentError("3-D region-law compilation authority ceiling was exceeded"))
    expected
end

function _tdrl_result(context_hash, status, declaration_hash, binding_hash,
        roots, gaps)
    root_hashes = Tuple(roots)
    gap_tuple = Tuple(String(x) for x in gaps)
    body = _tdrl_resolution_body(context_hash, status, declaration_hash,
        binding_hash, root_hashes, gap_tuple)
    ThreeDRegionLawCompilationV4(_TDRL_TOKEN, context_hash, status,
        declaration_hash, binding_hash, root_hashes, gap_tuple, screen_only,
        false, false, false, false, false, false, false, 0,
        canonical_hash(body))
end

"""Compile the law slice, retaining an exact recoverable gap when absent."""
function compile_three_d_region_laws(context::ForwardChainContextV4)
    validate_forward_chain_context(context)
    declarations = Tuple(x for x in context.candidate.field_geometry_genome_ref.fields
        if typeof(x) === ThreeDRegionConstitutiveSourceBoundaryV4)
    bindings = Tuple(x for x in context.subject.bindings
        if typeof(x) === ThreeDRegionLawBindingV4)
    if isempty(declarations)
        isempty(bindings) ||
            throw(ArgumentError("typed 3-D region-law binding has no current G2 declaration"))
        return _tdrl_result(context.context_hash, :recoverable_gap, nothing,
            nothing, (), (_TDRL_GAP, _TDRL_BINDING_GAP,
                _TDRL_DOWNSTREAM_GAPS...))
    end
    length(declarations) == 1 ||
        throw(ArgumentError("3-D region-law declaration is ambiguous in current G2"))
    declaration = only(declarations)
    graph = forward_graph_binding(context, :field_geometry)
    declaration_hash = _tdrl_validate_declaration(context.candidate, graph,
        declaration)
    isempty(bindings) && return _tdrl_result(context.context_hash,
        :recoverable_gap, declaration_hash, nothing, (),
        (_TDRL_BINDING_GAP, _TDRL_DOWNSTREAM_GAPS...))
    length(bindings) == 1 ||
        throw(ArgumentError("3-D region-law subject binding is ambiguous"))
    binding = _tdrl_context_binding(context, declaration)
    roots = (declaration.constitutive_law.ast_root_identity_hash,
        declaration.source_law.ast_root_identity_hash,
        declaration.boundary_law.ast_root_identity_hash)
    _tdrl_result(context.context_hash, :compiled, declaration_hash,
        canonical_hash(binding), roots, _TDRL_DOWNSTREAM_GAPS)
end

three_d_region_law_compiler_manifest() = (
    schema=_TDRL_SCHEMA, revision=_TDRL_REVISION,
    purpose=:typed_three_d_region_constitutive_source_boundary_compiler,
    statuses=(:compiled, :recoverable_gap),
    generic_status=:recoverable_gap,
    manufactured_fixture_status=:compiled,
    resolved_gap=_TDRL_GAP,
    required_subject_binding_gap=_TDRL_BINDING_GAP,
    downstream_gaps=_TDRL_DOWNSTREAM_GAPS,
    model_class=:manufactured_compiler_fixture,
    claim_ceiling=screen_only, provider_selected=false,
    provider_executed=false, emits_evidence=false, grants_pass=false,
    physical_validation=false, engineering_validation=false,
    promotion_authority=false, p5_ready=false, terminal_authority=false,
    credible_physical_device_count=0)
