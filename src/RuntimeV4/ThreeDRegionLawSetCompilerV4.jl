"""Exact-cover multi-region law set for one oriented RuntimeV4 G2 graph.

The set reuses the accepted single-region law declaration type, but owns one
such declaration for every oriented region in exact oriented order. It is a
typed input compiler only and carries no provider, solver, or evidence authority.
"""

using FusionConceptAI
import FusionConceptAI: canonical_hash, semantic_view

const _TDRLS_REVISION = "runtime-v4-three-d-region-law-set-compiler-v1"
const _TDRLS_SCHEMA = "fusionconceptai:runtime-v4-three-d-region-law-set"
const _TDRLS_TOKEN = Val(:three_d_region_law_set_private)
const _TDRLS_REQUIRED_GAPS = (
    "required_typed_three_d_oriented_interface_discrete_spaces",
    "required_three_d_oriented_interface_subject_binding",
    "required_typed_three_d_region_law_exact_cover_set",
    "required_three_d_region_law_set_subject_binding")
const _TDRLS_SELECTOR_KEYS = (
    :region_id, :constitutive_edge_id, :source_edge_id, :boundary_edge_id)

function _tdrls_selector_tuple(raw)
    raw isa Tuple && !(raw isa NamedTuple) && length(raw) >= 2 ||
        throw(ArgumentError("multi-region law selectors must be an immutable tuple of at least two entries"))
    selectors = Tuple(begin
        item isa NamedTuple && keys(item) == _TDRLS_SELECTOR_KEYS ||
            throw(ArgumentError("multi-region law selector fields must be exact"))
        (region_id=_tdrl_text(item.region_id, "region_id"),
         constitutive_edge_id=_tdrl_text(item.constitutive_edge_id,
             "constitutive_edge_id"),
         source_edge_id=_tdrl_text(item.source_edge_id, "source_edge_id"),
         boundary_edge_id=_tdrl_text(item.boundary_edge_id,
             "boundary_edge_id"))
    end for item in raw)
    region_ids = Tuple(x.region_id for x in selectors)
    length(unique(region_ids)) == length(region_ids) ||
        throw(ArgumentError("multi-region law selectors contain duplicate regions"))
    selectors
end

function _tdrls_identity_inventory(laws)
    edge_hashes = Tuple(value for law in laws for value in
        (law.constitutive_law.edge_identity_hash,
         law.source_law.edge_identity_hash,
         law.boundary_law.edge_identity_hash))
    root_hashes = Tuple(value for law in laws for value in
        (law.constitutive_law.ast_root_identity_hash,
         law.source_law.ast_root_identity_hash,
         law.boundary_law.ast_root_identity_hash))
    output_hashes = Tuple(value for law in laws for value in
        (law.constitutive_law.output_node_identity_hash,
         law.source_law.output_node_identity_hash,
         law.boundary_law.output_node_identity_hash))
    n = 3 * length(laws)
    length(unique(edge_hashes)) == n ||
        throw(ArgumentError("multi-region law set shares an edge identity"))
    length(unique(root_hashes)) == n ||
        throw(ArgumentError("multi-region law set shares an AST-root identity"))
    length(unique(output_hashes)) == n ||
        throw(ArgumentError("multi-region law set shares a law-output identity"))
    (edge_identity_hashes=edge_hashes,
     ast_root_identity_hashes=root_hashes,
     output_node_identity_hashes=output_hashes)
end

function _tdrls_declaration_body(declaration_id, graph_hash,
        graph_binding_hash, oriented_declaration_hash, region_ids, law_hashes,
        edge_hashes, root_hashes, output_hashes)
    (revision=_TDRLS_REVISION, declaration_id=declaration_id,
     field_geometry_graph_hash=graph_hash,
     field_geometry_graph_binding_hash=graph_binding_hash,
     oriented_declaration_hash=oriented_declaration_hash,
     ordered_region_ids=region_ids, ordered_law_hashes=law_hashes,
     ordered_edge_identity_hashes=edge_hashes,
     ordered_ast_root_identity_hashes=root_hashes,
     ordered_output_node_identity_hashes=output_hashes,
     model_class=:manufactured_compiler_fixture, claim_ceiling=screen_only,
     provider_selected=false, provider_executed=false,
     solver_executed=false, emits_evidence=false, grants_pass=false,
     promotion_authority=false, p5_ready=false, terminal_authority=false,
     credible_physical_device_count=0)
end

"""One accepted single-region declaration per oriented region, in exact order."""
struct ThreeDRegionLawSetDeclarationV4
    declaration_id::String
    field_geometry_graph_hash::Digest256
    field_geometry_graph_binding_hash::Digest256
    oriented_declaration_hash::Digest256
    ordered_region_ids::Tuple{Vararg{String}}
    laws::Tuple{Vararg{ThreeDRegionConstitutiveSourceBoundaryV4}}
    ordered_edge_identity_hashes::Tuple{Vararg{Digest256}}
    ordered_ast_root_identity_hashes::Tuple{Vararg{Digest256}}
    ordered_output_node_identity_hashes::Tuple{Vararg{Digest256}}
    model_class::Symbol
    claim_ceiling::ClaimCeiling
    provider_selected::Bool
    provider_executed::Bool
    solver_executed::Bool
    emits_evidence::Bool
    grants_pass::Bool
    promotion_authority::Bool
    p5_ready::Bool
    terminal_authority::Bool
    credible_physical_device_count::Int
    declaration_hash::Digest256
    function ThreeDRegionLawSetDeclarationV4(
            token::Val{:three_d_region_law_set_private}, fields...)
        token === _TDRLS_TOKEN ||
            throw(ArgumentError("private multi-region law-set constructor"))
        new(fields...)
    end
end

semantic_view(x::ThreeDRegionLawSetDeclarationV4) = merge(
    _tdrls_declaration_body(x.declaration_id,
        x.field_geometry_graph_hash, x.field_geometry_graph_binding_hash,
        x.oriented_declaration_hash, x.ordered_region_ids,
        Tuple(canonical_hash(law) for law in x.laws),
        x.ordered_edge_identity_hashes, x.ordered_ast_root_identity_hashes,
        x.ordered_output_node_identity_hashes),
    (declaration_hash=x.declaration_hash,))

function canonical_hash(x::ThreeDRegionLawSetDeclarationV4)
    n = length(x.ordered_region_ids)
    n >= 2 && length(x.laws) == n ||
        throw(ArgumentError("multi-region law set must cover at least two regions"))
    length(unique(x.ordered_region_ids)) == n ||
        throw(ArgumentError("multi-region law-set region IDs must be unique"))
    Tuple(law.region_node_id for law in x.laws) == x.ordered_region_ids ||
        throw(ArgumentError("multi-region laws differ from ordered region IDs"))
    inventory = _tdrls_identity_inventory(x.laws)
    inventory.edge_identity_hashes == x.ordered_edge_identity_hashes &&
        inventory.ast_root_identity_hashes == x.ordered_ast_root_identity_hashes &&
        inventory.output_node_identity_hashes == x.ordered_output_node_identity_hashes ||
        throw(ArgumentError("multi-region law-set identity inventory mismatch"))
    expected = canonical_hash(_tdrls_declaration_body(x.declaration_id,
        x.field_geometry_graph_hash, x.field_geometry_graph_binding_hash,
        x.oriented_declaration_hash, x.ordered_region_ids,
        Tuple(canonical_hash(law) for law in x.laws),
        x.ordered_edge_identity_hashes, x.ordered_ast_root_identity_hashes,
        x.ordered_output_node_identity_hashes))
    expected == x.declaration_hash ||
        throw(ArgumentError("multi-region law-set declaration hash mismatch"))
    x.model_class === :manufactured_compiler_fixture &&
        x.claim_ceiling == screen_only && !x.provider_selected &&
        !x.provider_executed && !x.solver_executed && !x.emits_evidence &&
        !x.grants_pass && !x.promotion_authority && !x.p5_ready &&
        !x.terminal_authority && x.credible_physical_device_count == 0 ||
        throw(ArgumentError("multi-region law-set authority ceiling was exceeded"))
    expected
end

function _tdrls_law_root(binding::ForwardGraphBindingV4, inventory,
        edge_id::String, law_kind::Symbol, expected_role::HyperedgeRoleV1,
        input_index::Int, output_kind::Symbol)
    roots = Tuple(x for x in inventory if x.edge.edge_id == edge_id)
    length(roots) == 1 ||
        throw(ArgumentError("$law_kind law edge must have one exact G2 AST root"))
    root = only(roots)
    edge = root.edge
    typeof(edge) === AtomicMIMOHyperedgeV1 ||
        throw(ArgumentError("$law_kind law must be AtomicMIMOHyperedgeV1"))
    edge.role === expected_role ||
        throw(ArgumentError("$law_kind law has the wrong typed role"))
    length(edge.input_bindings) == 1 &&
        only(edge.input_bindings).graph_node_index == input_index ||
        throw(ArgumentError("$law_kind law is not owned by its region"))
    root.output_node.node_kind === output_kind ||
        throw(ArgumentError("$law_kind law has the wrong output kind"))
    _tdrl_static_3d_type(root.output_node.physical_type,
        "$law_kind law output")
    program_node = root.program_nodes[root.program_root_index]
    program_node isa ASTApplyV1 ||
        throw(ArgumentError("$law_kind law root must be a registered AST application"))
    manifest = operator_manifest(edge.registry,
        program_node.operator_ref.qualified.id,
        program_node.operator_ref.qualified.version)
    manifests = Tuple(h for (ref, h) in edge.program.used_manifest_bindings
        if ref == program_node.operator_ref)
    length(manifests) == 1 && only(manifests) == manifest.manifest_hash ||
        throw(ArgumentError("$law_kind law manifest identity mismatch"))
    ThreeDRegionLawRootV4(_TDRL_TOKEN, law_kind, edge.edge_id,
        Symbol(edge.role), root.edge_identity_hash, root.program_hash,
        root.ast_root_identity_hash, root.output_node.node_id,
        root.output_node_identity_hash, root.output_node.physical_type)
end

function _tdrls_build_law(binding::ForwardGraphBindingV4, inventory,
        set_id::String, selector)
    region = _tdrl_node(binding, selector.region_id, :region, "region node")
    constitutive = _tdrls_law_root(binding, inventory,
        selector.constitutive_edge_id, :constitutive, governing,
        region.index, :region)
    source_law = _tdrls_law_root(binding, inventory,
        selector.source_edge_id, :source, source, region.index, :source)
    boundary_law = _tdrls_law_root(binding, inventory,
        selector.boundary_edge_id, :boundary, boundary, region.index,
        :boundary)
    constitutive.output_node_identity_hash == region.identity_hash ||
        throw(ArgumentError("constitutive law must close on its region node"))
    body = _tdrl_declaration_body("$set_id:$(selector.region_id)",
        binding.canonical_graph_hash, canonical_hash(binding),
        selector.region_id, region.identity_hash, region.node.physical_type,
        constitutive, source_law, boundary_law)
    ThreeDRegionConstitutiveSourceBoundaryV4(_TDRL_TOKEN,
        body.declaration_id, body.field_geometry_graph_hash,
        body.field_geometry_graph_binding_hash, body.region_node_id,
        body.region_node_identity_hash, body.region_type,
        body.constitutive_law, body.source_law, body.boundary_law,
        body.model_class, body.claim_ceiling, body.provider_selected,
        body.provider_executed, body.emits_evidence, body.grants_pass,
        body.promotion_authority, body.p5_ready, body.terminal_authority,
        body.credible_physical_device_count, canonical_hash(body))
end

"""Derive an exact-cover set from one G2 graph and one oriented declaration."""
function declare_three_d_region_law_set(binding::ForwardGraphBindingV4,
        oriented::ThreeDOrientedInterfaceDeclarationSetV4;
        declaration_id::String, law_selectors)
    canonical_hash(binding)
    canonical_hash(oriented)
    selectors = _tdrls_selector_tuple(law_selectors)
    region_ids = Tuple(x.region_id for x in oriented.regions)
    selector_ids = Tuple(x.region_id for x in selectors)
    Set(selector_ids) == Set(region_ids) &&
        length(selector_ids) == length(region_ids) ||
        throw(ArgumentError("law selectors must exactly cover oriented regions"))
    inventory = _tdrl_edge_root_inventory(binding)
    laws = Tuple(begin
        selector = only(x for x in selectors if x.region_id == region.region_id)
        _tdrls_build_law(binding, inventory,
            _tdrl_text(declaration_id, "declaration_id"), selector)
    end for region in oriented.regions)
    inventory = _tdrls_identity_inventory(laws)
    body = _tdrls_declaration_body(
        _tdrl_text(declaration_id, "declaration_id"),
        binding.canonical_graph_hash, canonical_hash(binding),
        canonical_hash(oriented), region_ids,
        Tuple(canonical_hash(law) for law in laws),
        inventory.edge_identity_hashes, inventory.ast_root_identity_hashes,
        inventory.output_node_identity_hashes)
    ThreeDRegionLawSetDeclarationV4(_TDRLS_TOKEN,
        body.declaration_id, body.field_geometry_graph_hash,
        body.field_geometry_graph_binding_hash,
        body.oriented_declaration_hash, body.ordered_region_ids, laws,
        body.ordered_edge_identity_hashes,
        body.ordered_ast_root_identity_hashes,
        body.ordered_output_node_identity_hashes, body.model_class,
        body.claim_ceiling, body.provider_selected, body.provider_executed,
        body.solver_executed, body.emits_evidence, body.grants_pass,
        body.promotion_authority, body.p5_ready, body.terminal_authority,
        body.credible_physical_device_count, canonical_hash(body))
end

function _tdrls_candidate_declarations(candidate::CandidateStatePackageV4)
    fields = candidate.field_geometry_genome_ref.fields
    sets = Tuple(x for x in fields if typeof(x) === ThreeDRegionLawSetDeclarationV4)
    oriented = Tuple(x for x in fields
        if typeof(x) === ThreeDOrientedInterfaceDeclarationSetV4)
    sets, oriented
end

function _tdrls_validate_declaration(candidate::CandidateStatePackageV4,
        graph::ForwardGraphBindingV4,
        declaration::ThreeDRegionLawSetDeclarationV4)
    canonical_hash(declaration)
    sets, oriented_values = _tdrls_candidate_declarations(candidate)
    matches = Tuple(x for x in sets
        if canonical_hash(x) == declaration.declaration_hash)
    length(matches) == 1 ||
        throw(ArgumentError("multi-region law set is absent from or ambiguous in current G2"))
    length(oriented_values) == 1 ||
        throw(ArgumentError("current G2 must own exactly one oriented declaration"))
    oriented = only(oriented_values)
    canonical_hash(oriented) == declaration.oriented_declaration_hash ||
        throw(ArgumentError("multi-region law set names a foreign oriented declaration"))
    regions, interfaces = _tdoi_compile_declaration(candidate, graph, oriented)
    Tuple(x.region_id for x in regions) == declaration.ordered_region_ids ||
        throw(ArgumentError("multi-region law set differs from current oriented order"))
    selectors = Tuple((region_id=law.region_node_id,
        constitutive_edge_id=law.constitutive_law.edge_id,
        source_edge_id=law.source_law.edge_id,
        boundary_edge_id=law.boundary_law.edge_id) for law in declaration.laws)
    rebuilt = declare_three_d_region_law_set(graph, oriented;
        declaration_id=declaration.declaration_id, law_selectors=selectors)
    canonical_hash(rebuilt) == declaration.declaration_hash &&
        semantic_view(rebuilt) == semantic_view(declaration) ||
        throw(ArgumentError("multi-region law set differs from current G2 identities"))
    (declaration=declaration, oriented=oriented, regions=regions,
     interfaces=interfaces)
end

function _tdrls_binding_body(candidate_hash, compiled_prefix_hash, genome_hash,
        graph_hash, graph_binding_hash, declaration_hash,
        oriented_declaration_hash, oriented_binding_hash, region_ids,
        law_hashes, edge_hashes, root_hashes, output_hashes,
        mission_hash, bounds_hash, scenario_hash)
    (revision=_TDRLS_REVISION,
     binding_kind=:three_d_region_law_set_subject_binding,
     candidate_hash=candidate_hash, compiled_prefix_hash=compiled_prefix_hash,
     field_geometry_genome_hash=genome_hash,
     field_geometry_graph_hash=graph_hash,
     field_geometry_graph_binding_hash=graph_binding_hash,
     declaration_hash=declaration_hash,
     oriented_declaration_hash=oriented_declaration_hash,
     oriented_binding_hash=oriented_binding_hash,
     ordered_region_ids=region_ids, ordered_law_hashes=law_hashes,
     ordered_edge_identity_hashes=edge_hashes,
     ordered_ast_root_identity_hashes=root_hashes,
     ordered_output_node_identity_hashes=output_hashes,
     mission_hash=mission_hash, bounds_hash=bounds_hash,
     scenario_hash=scenario_hash)
end

struct ThreeDRegionLawSetBindingV4
    candidate_hash::Digest256
    compiled_prefix_hash::Digest256
    field_geometry_genome_hash::Digest256
    field_geometry_graph_hash::Digest256
    field_geometry_graph_binding_hash::Digest256
    declaration_hash::Digest256
    oriented_declaration_hash::Digest256
    oriented_binding_hash::Digest256
    ordered_region_ids::Tuple{Vararg{String}}
    ordered_law_hashes::Tuple{Vararg{Digest256}}
    ordered_edge_identity_hashes::Tuple{Vararg{Digest256}}
    ordered_ast_root_identity_hashes::Tuple{Vararg{Digest256}}
    ordered_output_node_identity_hashes::Tuple{Vararg{Digest256}}
    mission_hash::Digest256
    bounds_hash::Digest256
    scenario_hash::Digest256
    binding_hash::Digest256
    function ThreeDRegionLawSetBindingV4(
            token::Val{:three_d_region_law_set_private}, fields...)
        token === _TDRLS_TOKEN ||
            throw(ArgumentError("private multi-region law-set binding constructor"))
        new(fields...)
    end
end

semantic_view(x::ThreeDRegionLawSetBindingV4) = merge(
    _tdrls_binding_body(x.candidate_hash, x.compiled_prefix_hash,
        x.field_geometry_genome_hash, x.field_geometry_graph_hash,
        x.field_geometry_graph_binding_hash, x.declaration_hash,
        x.oriented_declaration_hash, x.oriented_binding_hash,
        x.ordered_region_ids, x.ordered_law_hashes,
        x.ordered_edge_identity_hashes, x.ordered_ast_root_identity_hashes,
        x.ordered_output_node_identity_hashes, x.mission_hash,
        x.bounds_hash, x.scenario_hash), (binding_hash=x.binding_hash,))

function canonical_hash(x::ThreeDRegionLawSetBindingV4)
    n = length(x.ordered_region_ids)
    n >= 2 && length(x.ordered_law_hashes) == n &&
        length(x.ordered_edge_identity_hashes) == 3n &&
        length(x.ordered_ast_root_identity_hashes) == 3n &&
        length(x.ordered_output_node_identity_hashes) == 3n ||
        throw(ArgumentError("multi-region law-set binding inventory is incomplete"))
    expected = canonical_hash(_tdrls_binding_body(x.candidate_hash,
        x.compiled_prefix_hash, x.field_geometry_genome_hash,
        x.field_geometry_graph_hash, x.field_geometry_graph_binding_hash,
        x.declaration_hash, x.oriented_declaration_hash,
        x.oriented_binding_hash, x.ordered_region_ids, x.ordered_law_hashes,
        x.ordered_edge_identity_hashes, x.ordered_ast_root_identity_hashes,
        x.ordered_output_node_identity_hashes, x.mission_hash,
        x.bounds_hash, x.scenario_hash))
    expected == x.binding_hash ||
        throw(ArgumentError("multi-region law-set binding hash mismatch"))
    expected
end

function make_three_d_region_law_set_binding(
        compiled::CompiledCandidatePrefixV4,
        registry::GenomeContractRegistryV4, mission_payload, bounds_payload,
        comparison_scope, scenario_scope, scenario,
        declaration::ThreeDRegionLawSetDeclarationV4,
        oriented_binding::ThreeDOrientedInterfaceBindingV4)
    comparison = _runtime_axis_tuple(comparison_scope, "comparison_scope")
    scenarios = _runtime_axis_tuple(scenario_scope, "scenario_scope")
    compiled.mission_payload == mission_payload &&
        compiled.bounds_payload == bounds_payload ||
        throw(ArgumentError("law-set binding payload differs from compiled prefix"))
    compiled.minimality_scope.comparison_scope == comparison &&
        compiled.minimality_scope.scenario_scope == scenarios ||
        throw(ArgumentError("law-set binding scope differs from compiled prefix"))
    is_canonical_value(scenario) ||
        throw(ArgumentError("law-set binding scenario is not canonicalizable"))
    _forward_scenario_name(scenario) in scenarios ||
        throw(ArgumentError("law-set binding scenario is outside frozen scope"))
    graph = _make_forward_graph_binding(:field_geometry,
        compiled.field_geometry_graph)
    values = _tdrls_validate_declaration(compiled.candidate, graph,
        declaration)
    canonical_hash(oriented_binding)
    oriented_binding.declaration_hash == canonical_hash(values.oriented) &&
        oriented_binding.field_geometry_genome_hash ==
            field_geometry_hash(compiled.candidate.field_geometry_genome_ref) &&
        oriented_binding.field_geometry_graph_hash == graph.canonical_graph_hash &&
        oriented_binding.field_geometry_graph_binding_hash == canonical_hash(graph) &&
        oriented_binding.region_ref_hashes ==
            Tuple(x.ref_hash for x in values.regions) &&
        oriented_binding.interface_ref_hashes ==
            Tuple(x.ref_hash for x in values.interfaces) &&
        oriented_binding.mission_hash == _runtime_decl_hash(mission_payload) &&
        oriented_binding.bounds_hash == _runtime_decl_hash(bounds_payload) &&
        oriented_binding.scenario_hash == canonical_hash(scenario) ||
        throw(ArgumentError("oriented binding is foreign to multi-region law set"))
    body = _tdrls_binding_body(
        _forward_candidate_identity(compiled.candidate), compiled.prefix_hash,
        field_geometry_hash(compiled.candidate.field_geometry_genome_ref),
        graph.canonical_graph_hash, canonical_hash(graph),
        canonical_hash(declaration), canonical_hash(values.oriented),
        canonical_hash(oriented_binding), declaration.ordered_region_ids,
        Tuple(canonical_hash(law) for law in declaration.laws),
        declaration.ordered_edge_identity_hashes,
        declaration.ordered_ast_root_identity_hashes,
        declaration.ordered_output_node_identity_hashes,
        _runtime_decl_hash(mission_payload), _runtime_decl_hash(bounds_payload),
        canonical_hash(scenario))
    ThreeDRegionLawSetBindingV4(_TDRLS_TOKEN,
        body.candidate_hash, body.compiled_prefix_hash,
        body.field_geometry_genome_hash, body.field_geometry_graph_hash,
        body.field_geometry_graph_binding_hash, body.declaration_hash,
        body.oriented_declaration_hash, body.oriented_binding_hash,
        body.ordered_region_ids, body.ordered_law_hashes,
        body.ordered_edge_identity_hashes,
        body.ordered_ast_root_identity_hashes,
        body.ordered_output_node_identity_hashes, body.mission_hash,
        body.bounds_hash, body.scenario_hash, canonical_hash(body))
end

function _tdrls_context_binding(context::ForwardChainContextV4,
        declaration::ThreeDRegionLawSetDeclarationV4,
        oriented_binding::ThreeDOrientedInterfaceBindingV4, values)
    bindings = Tuple(x for x in context.subject.bindings
        if typeof(x) === ThreeDRegionLawSetBindingV4)
    length(bindings) == 1 ||
        throw(ArgumentError("physical subject must contain one multi-region law-set binding"))
    actual = only(bindings)
    canonical_hash(actual)
    actual.candidate_hash == context.candidate_hash &&
        actual.compiled_prefix_hash == context.compiled.prefix_hash &&
        actual.field_geometry_genome_hash ==
            field_geometry_hash(context.candidate.field_geometry_genome_ref) &&
        actual.field_geometry_graph_hash ==
            declaration.field_geometry_graph_hash &&
        actual.field_geometry_graph_binding_hash ==
            declaration.field_geometry_graph_binding_hash &&
        actual.declaration_hash == canonical_hash(declaration) &&
        actual.oriented_declaration_hash == canonical_hash(values.oriented) &&
        actual.oriented_binding_hash == canonical_hash(oriented_binding) &&
        actual.ordered_region_ids == declaration.ordered_region_ids &&
        actual.ordered_law_hashes ==
            Tuple(canonical_hash(law) for law in declaration.laws) &&
        actual.ordered_edge_identity_hashes ==
            declaration.ordered_edge_identity_hashes &&
        actual.ordered_ast_root_identity_hashes ==
            declaration.ordered_ast_root_identity_hashes &&
        actual.ordered_output_node_identity_hashes ==
            declaration.ordered_output_node_identity_hashes &&
        actual.mission_hash == _runtime_decl_hash(context.mission_payload) &&
        actual.bounds_hash == _runtime_decl_hash(context.bounds_payload) &&
        actual.scenario_hash == context.scenario_hash ||
        throw(ArgumentError("multi-region law-set binding is foreign to current context"))
    actual
end

function _tdrls_compilation_body(context_hash, status, declaration,
        binding_hash, gaps)
    (revision=_TDRLS_REVISION, schema=_TDRLS_SCHEMA,
     context_hash=context_hash, status=status,
     declaration_hash=declaration === nothing ? nothing : canonical_hash(declaration),
     binding_hash=binding_hash,
     ordered_region_ids=declaration === nothing ? () : declaration.ordered_region_ids,
     ordered_law_hashes=declaration === nothing ? () :
        Tuple(canonical_hash(law) for law in declaration.laws),
     ordered_edge_identity_hashes=declaration === nothing ? () :
        declaration.ordered_edge_identity_hashes,
     ordered_ast_root_identity_hashes=declaration === nothing ? () :
        declaration.ordered_ast_root_identity_hashes,
     ordered_output_node_identity_hashes=declaration === nothing ? () :
        declaration.ordered_output_node_identity_hashes,
     recoverable_gaps=gaps, claim_ceiling=screen_only,
     provider_selected=false, provider_executed=false,
     solver_executed=false, emits_evidence=false, grants_pass=false,
     promotion_authority=false, p5_ready=false, terminal_authority=false,
     credible_physical_device_count=0)
end

struct ThreeDRegionLawSetCompilationV4
    context_hash::Digest256
    status::Symbol
    declaration::Union{Nothing,ThreeDRegionLawSetDeclarationV4}
    binding_hash::Union{Nothing,Digest256}
    ordered_region_ids::Tuple{Vararg{String}}
    laws::Tuple{Vararg{ThreeDRegionConstitutiveSourceBoundaryV4}}
    ordered_edge_identity_hashes::Tuple{Vararg{Digest256}}
    ordered_ast_root_identity_hashes::Tuple{Vararg{Digest256}}
    ordered_output_node_identity_hashes::Tuple{Vararg{Digest256}}
    recoverable_gaps::Tuple{Vararg{String}}
    claim_ceiling::ClaimCeiling
    provider_selected::Bool
    provider_executed::Bool
    solver_executed::Bool
    emits_evidence::Bool
    grants_pass::Bool
    promotion_authority::Bool
    p5_ready::Bool
    terminal_authority::Bool
    credible_physical_device_count::Int
    compilation_hash::Digest256
    function ThreeDRegionLawSetCompilationV4(
            token::Val{:three_d_region_law_set_private}, fields...)
        token === _TDRLS_TOKEN ||
            throw(ArgumentError("private multi-region law-set result constructor"))
        new(fields...)
    end
end

semantic_view(x::ThreeDRegionLawSetCompilationV4) = merge(
    _tdrls_compilation_body(x.context_hash, x.status, x.declaration,
        x.binding_hash, x.recoverable_gaps),
    (compilation_hash=x.compilation_hash,))

function canonical_hash(x::ThreeDRegionLawSetCompilationV4)
    x.status in (:compiled, :recoverable_gap) ||
        throw(ArgumentError("invalid multi-region law-set status"))
    if x.status === :compiled
        x.declaration !== nothing && x.binding_hash !== nothing &&
            isempty(x.recoverable_gaps) &&
            x.ordered_region_ids == x.declaration.ordered_region_ids &&
            x.laws == x.declaration.laws &&
            x.ordered_edge_identity_hashes ==
                x.declaration.ordered_edge_identity_hashes &&
            x.ordered_ast_root_identity_hashes ==
                x.declaration.ordered_ast_root_identity_hashes &&
            x.ordered_output_node_identity_hashes ==
                x.declaration.ordered_output_node_identity_hashes ||
            throw(ArgumentError("compiled multi-region law set is incomplete"))
    else
        x.declaration === nothing && x.binding_hash === nothing &&
            isempty(x.ordered_region_ids) && isempty(x.laws) &&
            isempty(x.ordered_edge_identity_hashes) &&
            isempty(x.ordered_ast_root_identity_hashes) &&
            isempty(x.ordered_output_node_identity_hashes) &&
            !isempty(x.recoverable_gaps) ||
            throw(ArgumentError("recoverable multi-region law-set result is malformed"))
    end
    expected = canonical_hash(_tdrls_compilation_body(x.context_hash,
        x.status, x.declaration, x.binding_hash, x.recoverable_gaps))
    expected == x.compilation_hash ||
        throw(ArgumentError("multi-region law-set compilation hash mismatch"))
    x.claim_ceiling == screen_only && !x.provider_selected &&
        !x.provider_executed && !x.solver_executed && !x.emits_evidence &&
        !x.grants_pass && !x.promotion_authority && !x.p5_ready &&
        !x.terminal_authority && x.credible_physical_device_count == 0 ||
        throw(ArgumentError("multi-region law-set result authority ceiling was exceeded"))
    expected
end

function _tdrls_result(context_hash, declaration, binding_hash, gaps)
    gap_tuple = Tuple(String(x) for x in gaps)
    status = declaration === nothing ? :recoverable_gap : :compiled
    status === :compiled && isempty(gap_tuple) ||
        status === :recoverable_gap && !isempty(gap_tuple) ||
        throw(ArgumentError("multi-region law-set status/gap mismatch"))
    body = _tdrls_compilation_body(context_hash, status, declaration,
        binding_hash, gap_tuple)
    laws = declaration === nothing ? () : declaration.laws
    ThreeDRegionLawSetCompilationV4(_TDRLS_TOKEN, context_hash, status,
        declaration, binding_hash, body.ordered_region_ids, laws,
        body.ordered_edge_identity_hashes,
        body.ordered_ast_root_identity_hashes,
        body.ordered_output_node_identity_hashes, gap_tuple, screen_only,
        false, false, false, false, false, false, false, false, 0,
        canonical_hash(body))
end

"""Compile an exact current-context multi-region law cover or exact gaps."""
function compile_three_d_region_law_set(context::ForwardChainContextV4)
    validate_forward_chain_context(context)
    sets, oriented_values = _tdrls_candidate_declarations(context.candidate)
    bindings = Tuple(x for x in context.subject.bindings
        if typeof(x) === ThreeDRegionLawSetBindingV4)
    oriented_bindings = Tuple(x for x in context.subject.bindings
        if typeof(x) === ThreeDOrientedInterfaceBindingV4)
    gaps = String[]
    isempty(oriented_values) ? push!(gaps, _TDRLS_REQUIRED_GAPS[1]) :
        length(oriented_values) == 1 ||
            push!(gaps, "ambiguous_typed_three_d_oriented_interface_discrete_spaces")
    isempty(oriented_bindings) ? push!(gaps, _TDRLS_REQUIRED_GAPS[2]) :
        length(oriented_bindings) == 1 ||
            push!(gaps, "ambiguous_three_d_oriented_interface_subject_binding")
    isempty(sets) ? push!(gaps, _TDRLS_REQUIRED_GAPS[3]) :
        length(sets) == 1 ||
            push!(gaps, "ambiguous_typed_three_d_region_law_exact_cover_set")
    isempty(bindings) ? push!(gaps, _TDRLS_REQUIRED_GAPS[4]) :
        length(bindings) == 1 ||
            push!(gaps, "ambiguous_three_d_region_law_set_subject_binding")
    (!isempty(bindings) || !isempty(oriented_bindings)) &&
        (isempty(sets) || isempty(oriented_values)) &&
        throw(ArgumentError("typed multi-region subject binding has a missing declaration"))
    isempty(gaps) || return _tdrls_result(context.context_hash, nothing,
        nothing, Tuple(gaps))
    declaration = only(sets)
    graph = _make_forward_graph_binding(:field_geometry,
        context.compiled.field_geometry_graph)
    values = _tdrls_validate_declaration(context.candidate, graph, declaration)
    binding = _tdrls_context_binding(context, declaration,
        only(oriented_bindings), values)
    _tdrls_result(context.context_hash, declaration, canonical_hash(binding), ())
end

three_d_region_law_set_compiler_manifest() = (
    schema=_TDRLS_SCHEMA, revision=_TDRLS_REVISION,
    purpose=:typed_multi_region_constitutive_source_boundary_exact_cover,
    statuses=(:compiled, :recoverable_gap),
    exact_oriented_order=true, minimum_region_count=2,
    laws_per_region=3, forbids_shared_edges=true,
    forbids_shared_ast_roots=true, forbids_shared_outputs=true,
    model_class=:manufactured_compiler_fixture, claim_ceiling=screen_only,
    provider_selected=false, provider_executed=false,
    solver_executed=false, emits_evidence=false, grants_pass=false,
    physical_validation=false, engineering_validation=false,
    promotion_authority=false, p5_ready=false, terminal_authority=false,
    credible_physical_device_count=0)
