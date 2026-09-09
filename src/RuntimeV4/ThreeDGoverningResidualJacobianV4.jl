"""Typed 3-D governing-residual/Jacobian ownership-set compiler.

Every current G2 state must have one distinct pair of repository-typed AST
roots on `AtomicMIMOHyperedgeV1` edges. This slice compiles ownership only: it
selects and executes no provider and emits no evidence or decision.
"""

using FusionConceptAI
import FusionConceptAI: canonical_hash, semantic_view

const _TDRJ_REVISION = "runtime-v4-three-d-governing-residual-jacobian-v2"
const _TDRJ_SCHEMA =
    "fusionconceptai:runtime-v4-three-d-governing-residual-jacobian-set"
const _TDRJ_TOKEN = Val(:three_d_governing_residual_jacobian_private)
const _TDRJ_GAP =
    "required_typed_three_d_governing_residual_jacobian_ownership"
const _TDRJ_BINDING_GAP =
    "required_typed_three_d_governing_residual_jacobian_subject_binding"
const _TDRJ_DOWNSTREAM_GAPS =
    ("required_typed_three_d_discretization_controls",)
const _TDRJ_SPEC_KEYS =
    (:state_node_id, :residual_edge_id, :jacobian_edge_id)

function _tdrj_text(value, field::String)
    typeof(value) === String ||
        throw(ArgumentError("$field must be an immutable String"))
    text = strip(value)
    !isempty(text) && isvalid(text) ||
        throw(ArgumentError("$field cannot be empty"))
    lowered = lowercase(text)
    (lowered in ("*", "any", "all", "wildcard") || occursin('*', text)) &&
        throw(ArgumentError("$field cannot contain a wildcard"))
    String(text)
end

function _tdrj_static_3d_type(value::PhysicalType, field::String)
    value.spatial_dimension == 3 ||
        throw(ArgumentError("$field must be three-dimensional"))
    value.temporal_type == TemporalTypeV1(static_time) ||
        throw(ArgumentError("$field must use static time semantics"))
    value
end

function _tdrj_jacobian_type(domain::PhysicalType, codomain::PhysicalType)
    _tdrj_static_3d_type(domain, "Jacobian domain")
    _tdrj_static_3d_type(codomain, "Jacobian codomain")
    domain.temporal_type == codomain.temporal_type ||
        throw(ArgumentError("residual and state time semantics are incompatible"))
    units = UnitSignature(ntuple(i ->
        codomain.units.exponents[i] - domain.units.exponents[i], 7))
    PhysicalType(:residual_jacobian,
        domain.tensor_rank + codomain.tensor_rank, 3,
        codomain.temporal_type, units)
end

"""Exact identity of one current-G2 AST operator root and its typed ports."""
struct ThreeDResidualJacobianOperatorIdentityV4
    operator_kind::Symbol
    edge_id::String
    edge_role::HyperedgeRoleV1
    edge_position::Int
    edge_identity_hash::Digest256
    program_hash::Digest256
    program_root_index::Int
    ast_root_identity_hash::Digest256
    operator_ref::OperatorRefV1
    operator_manifest_hash::Digest256
    domain_node_id::String
    domain_node_identity_hash::Digest256
    domain_type::PhysicalType
    codomain_node_id::String
    codomain_node_identity_hash::Digest256
    codomain_type::PhysicalType
    identity_hash::Digest256
    function ThreeDResidualJacobianOperatorIdentityV4(
            token::Val{:three_d_governing_residual_jacobian_private}, fields...)
        token === _TDRJ_TOKEN ||
            throw(ArgumentError("private residual/Jacobian operator identity constructor"))
        new(fields...)
    end
end

function _tdrj_operator_body(x::ThreeDResidualJacobianOperatorIdentityV4)
    (
    operator_kind=x.operator_kind, edge_id=x.edge_id,
    edge_role=x.edge_role, edge_position=x.edge_position,
    edge_identity_hash=x.edge_identity_hash, program_hash=x.program_hash,
    program_root_index=x.program_root_index,
    ast_root_identity_hash=x.ast_root_identity_hash,
    operator_ref=x.operator_ref,
    operator_manifest_hash=x.operator_manifest_hash,
    domain_node_id=x.domain_node_id,
    domain_node_identity_hash=x.domain_node_identity_hash,
    domain_type=x.domain_type, codomain_node_id=x.codomain_node_id,
    codomain_node_identity_hash=x.codomain_node_identity_hash,
    codomain_type=x.codomain_type)
end

semantic_view(x::ThreeDResidualJacobianOperatorIdentityV4) = merge(
    _tdrj_operator_body(x), (identity_hash=x.identity_hash,))

function canonical_hash(x::ThreeDResidualJacobianOperatorIdentityV4)
    expected = canonical_hash(_tdrj_operator_body(x))
    expected == x.identity_hash ||
        throw(ArgumentError("residual/Jacobian operator identity hash mismatch"))
    expected
end

function _tdrj_root_inventory(binding::ForwardGraphBindingV4)
    binding.role === :field_geometry ||
        throw(ArgumentError("residual/Jacobian ownership requires the G2 field graph"))
    result = NamedTuple[]
    global_root_position = 0
    for (edge_position, edge) in enumerate(binding.graph.hyperedges)
        nodes, roots, program_hash = _forward_edge_program(edge)
        for (root_position, program_root_index) in enumerate(roots)
            global_root_position += 1
            output_index = _forward_root_output_node(edge, root_position)
            push!(result, (edge=edge, edge_position=edge_position,
                edge_identity_hash=binding.hyperedge_identity_hashes[edge_position],
                program_nodes=nodes, program_hash=program_hash,
                program_root_index=program_root_index,
                ast_root_identity_hash=
                    binding.ast_root_identity_hashes[global_root_position],
                output_index=output_index,
                output_node=binding.graph.nodes[output_index],
                output_node_identity_hash=
                    binding.node_identity_hashes[output_index]))
        end
    end
    global_root_position == length(binding.ast_root_identity_hashes) ||
        throw(ArgumentError("G2 AST-root count mismatch"))
    Tuple(result)
end

function _tdrj_graph_node(binding::ForwardGraphBindingV4, node_id::String,
        node_kind::Symbol, field::String)
    hits = Tuple((index=i, node=n,
        identity_hash=binding.node_identity_hashes[i])
        for (i, n) in enumerate(binding.graph.nodes) if n.node_id == node_id)
    length(hits) == 1 ||
        throw(ArgumentError("$field is absent from or ambiguous in current G2"))
    hit = only(hits)
    hit.node.node_kind === node_kind ||
        throw(ArgumentError("$field has the wrong typed node kind"))
    _tdrj_static_3d_type(hit.node.physical_type, field)
    hit
end

function _tdrj_operator_root(binding::ForwardGraphBindingV4, inventory,
        edge_id::String,
        operator_kind::Symbol, expected_role::HyperedgeRoleV1,
        domain_node_index::Int, expected_output_kind::Symbol)
    roots = Tuple(root for root in inventory
        if root.edge.edge_id == edge_id)
    length(roots) == 1 ||
        throw(ArgumentError("$operator_kind edge must have one exact current-G2 AST root"))
    root = only(roots)
    edge = root.edge
    typeof(edge) === AtomicMIMOHyperedgeV1 ||
        throw(ArgumentError("$operator_kind edge must be AtomicMIMOHyperedgeV1"))
    edge.role === expected_role ||
        throw(ArgumentError("$operator_kind edge has the wrong typed role"))
    length(edge.input_bindings) == 1 &&
        only(edge.input_bindings).program_position == 1 &&
        only(edge.input_bindings).graph_node_index == domain_node_index ||
        throw(ArgumentError("$operator_kind domain must be its declared state node"))
    length(edge.output_bindings) == 1 ||
        throw(ArgumentError("$operator_kind edge must have one typed codomain"))
    output = root.output_node
    output.node_kind === expected_output_kind ||
        throw(ArgumentError("$operator_kind edge has the wrong codomain node kind"))
    _tdrj_static_3d_type(output.physical_type, "$operator_kind codomain")
    program_root = root.program_nodes[root.program_root_index]
    program_root isa ASTApplyV1 ||
        throw(ArgumentError("$operator_kind root must be a registered AST operator application"))
    manifest = operator_manifest(edge.registry,
        program_root.operator_ref.qualified.id,
        program_root.operator_ref.qualified.version)
    matches = Tuple(hash for (ref, hash) in edge.program.used_manifest_bindings
        if ref == program_root.operator_ref)
    length(matches) == 1 && only(matches) == manifest.manifest_hash ||
        throw(ArgumentError("$operator_kind root manifest identity mismatch"))
    input_index = only(edge.input_bindings).graph_node_index
    input = binding.graph.nodes[input_index]
    input.physical_type ==
        edge.program.nodes[only(edge.program.input_ports)].output_type ||
        throw(ArgumentError("$operator_kind AST domain type mismatch"))
    program_root.output_type == output.physical_type ||
        throw(ArgumentError("$operator_kind AST codomain type mismatch"))
    values = (operator_kind, edge.edge_id, edge.role, root.edge_position,
        root.edge_identity_hash, root.program_hash,
        root.program_root_index, root.ast_root_identity_hash,
        program_root.operator_ref, manifest.manifest_hash, input.node_id,
        binding.node_identity_hashes[input_index], input.physical_type,
        output.node_id, root.output_node_identity_hash, output.physical_type)
    provisional = ThreeDResidualJacobianOperatorIdentityV4(_TDRJ_TOKEN,
        operator_kind, edge.edge_id, edge.role, root.edge_position,
        root.edge_identity_hash, root.program_hash,
        root.program_root_index, root.ast_root_identity_hash,
        program_root.operator_ref, manifest.manifest_hash, input.node_id,
        binding.node_identity_hashes[input_index], input.physical_type,
        output.node_id, root.output_node_identity_hash, output.physical_type,
        canonical_hash((operator_kind=values[1], edge_id=values[2],
            edge_role=values[3], edge_position=values[4],
            edge_identity_hash=values[5], program_hash=values[6],
            program_root_index=values[7], ast_root_identity_hash=values[8],
            operator_ref=values[9], operator_manifest_hash=values[10],
            domain_node_id=values[11], domain_node_identity_hash=values[12],
            domain_type=values[13], codomain_node_id=values[14],
            codomain_node_identity_hash=values[15], codomain_type=values[16])))
    canonical_hash(provisional)
    provisional
end

function _tdrj_pair_body(state_node_id, state_node_identity_hash, state_type,
        residual, jacobian, expected_jacobian_type)
    (state_node_id=state_node_id,
     state_node_identity_hash=state_node_identity_hash,
     state_type=state_type, residual_operator_hash=residual.identity_hash,
     jacobian_operator_hash=jacobian.identity_hash,
     expected_jacobian_type=expected_jacobian_type)
end

"""One state and its exact governing-residual/Jacobian pair."""
struct ThreeDResidualJacobianPairV4
    state_node_id::String
    state_node_identity_hash::Digest256
    state_type::PhysicalType
    residual_operator::ThreeDResidualJacobianOperatorIdentityV4
    jacobian_operator::ThreeDResidualJacobianOperatorIdentityV4
    expected_jacobian_type::PhysicalType
    pair_hash::Digest256
    function ThreeDResidualJacobianPairV4(
            token::Val{:three_d_governing_residual_jacobian_private}, fields...)
        token === _TDRJ_TOKEN ||
            throw(ArgumentError("private residual/Jacobian pair constructor"))
        new(fields...)
    end
end

semantic_view(x::ThreeDResidualJacobianPairV4) = merge(
    _tdrj_pair_body(x.state_node_id, x.state_node_identity_hash,
        x.state_type, x.residual_operator, x.jacobian_operator,
        x.expected_jacobian_type), (pair_hash=x.pair_hash,))

function canonical_hash(x::ThreeDResidualJacobianPairV4)
    residual = x.residual_operator
    jacobian = x.jacobian_operator
    canonical_hash(residual)
    canonical_hash(jacobian)
    residual.operator_kind === :residual && residual.edge_role === governing &&
        jacobian.operator_kind === :jacobian && jacobian.edge_role === constraint ||
        throw(ArgumentError("residual/Jacobian pair roles are invalid"))
    residual.domain_node_id == x.state_node_id &&
        jacobian.domain_node_id == x.state_node_id &&
        residual.domain_node_identity_hash == x.state_node_identity_hash &&
        jacobian.domain_node_identity_hash == x.state_node_identity_hash &&
        residual.domain_type == x.state_type &&
        jacobian.domain_type == x.state_type ||
        throw(ArgumentError("residual/Jacobian pair does not own its state domain"))
    residual.codomain_type.value_kind === :governing_residual ||
        throw(ArgumentError("residual codomain must use governing_residual kind"))
    expected_jacobian = _tdrj_jacobian_type(x.state_type,
        residual.codomain_type)
    x.expected_jacobian_type == expected_jacobian &&
        jacobian.codomain_type == expected_jacobian ||
        throw(ArgumentError("Jacobian codomain rank/unit/dimension is incompatible"))
    residual.edge_identity_hash != jacobian.edge_identity_hash &&
        residual.ast_root_identity_hash != jacobian.ast_root_identity_hash ||
        throw(ArgumentError("residual and Jacobian operators must be distinct"))
    expected = canonical_hash(_tdrj_pair_body(x.state_node_id,
        x.state_node_identity_hash, x.state_type, residual, jacobian,
        x.expected_jacobian_type))
    expected == x.pair_hash ||
        throw(ArgumentError("residual/Jacobian pair hash mismatch"))
    expected
end

function _tdrj_make_pair(binding::ForwardGraphBindingV4, inventory, state,
        residual_edge_id::String, jacobian_edge_id::String)
    residual = _tdrj_operator_root(binding, inventory, residual_edge_id, :residual,
        governing, state.index, :residual)
    jacobian = _tdrj_operator_root(binding, inventory, jacobian_edge_id, :jacobian,
        constraint, state.index, :jacobian)
    expected = _tdrj_jacobian_type(state.node.physical_type,
        residual.codomain_type)
    pair_body = _tdrj_pair_body(state.node.node_id, state.identity_hash,
        state.node.physical_type, residual, jacobian, expected)
    pair = ThreeDResidualJacobianPairV4(_TDRJ_TOKEN,
        state.node.node_id, state.identity_hash, state.node.physical_type,
        residual, jacobian, expected, canonical_hash(pair_body))
    canonical_hash(pair)
    pair
end

function _tdrj_declaration_body(declaration_id, graph_hash,
        graph_binding_hash, pair_hashes)
    (revision=_TDRJ_REVISION, declaration_id=declaration_id,
     field_geometry_graph_hash=graph_hash,
     field_geometry_graph_binding_hash=graph_binding_hash,
     ordered_pair_hashes=pair_hashes,
     model_class=:manufactured_compiler_fixture,
     claim_ceiling=screen_only, provider_selected=false,
     provider_executed=false, emits_evidence=false, grants_pass=false,
     promotion_authority=false, p5_ready=false, terminal_authority=false,
     credible_physical_device_count=0)
end

"""Ordered exact-cover set: one distinct pair per current G2 state node."""
struct ThreeDGoverningResidualJacobianDeclarationSetV4
    declaration_id::String
    field_geometry_graph_hash::Digest256
    field_geometry_graph_binding_hash::Digest256
    pairs::Tuple{Vararg{ThreeDResidualJacobianPairV4}}
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
    function ThreeDGoverningResidualJacobianDeclarationSetV4(
            token::Val{:three_d_governing_residual_jacobian_private}, fields...)
        token === _TDRJ_TOKEN ||
            throw(ArgumentError("private residual/Jacobian declaration-set constructor"))
        new(fields...)
    end
end

semantic_view(x::ThreeDGoverningResidualJacobianDeclarationSetV4) = merge(
    _tdrj_declaration_body(x.declaration_id, x.field_geometry_graph_hash,
        x.field_geometry_graph_binding_hash,
        Tuple(pair.pair_hash for pair in x.pairs)),
    (declaration_hash=x.declaration_hash,))

function _tdrj_unique_pair_identities(pairs)
    state_hashes = Tuple(x.state_node_identity_hash for x in pairs)
    edge_hashes = Tuple(value for pair in pairs for value in
        (pair.residual_operator.edge_identity_hash,
         pair.jacobian_operator.edge_identity_hash))
    root_hashes = Tuple(value for pair in pairs for value in
        (pair.residual_operator.ast_root_identity_hash,
         pair.jacobian_operator.ast_root_identity_hash))
    residual_outputs = Tuple(x.residual_operator.codomain_node_identity_hash
        for x in pairs)
    jacobian_outputs = Tuple(x.jacobian_operator.codomain_node_identity_hash
        for x in pairs)
    length(unique(state_hashes)) == length(state_hashes) &&
        length(unique(edge_hashes)) == length(edge_hashes) &&
        length(unique(root_hashes)) == length(root_hashes) &&
        length(unique(residual_outputs)) == length(residual_outputs) &&
        length(unique(jacobian_outputs)) == length(jacobian_outputs) ||
        throw(ArgumentError("residual/Jacobian declaration set contains shared identities"))
    nothing
end

function canonical_hash(x::ThreeDGoverningResidualJacobianDeclarationSetV4)
    !isempty(x.pairs) ||
        throw(ArgumentError("residual/Jacobian declaration set cannot be empty"))
    Tuple(canonical_hash(pair) for pair in x.pairs)
    _tdrj_unique_pair_identities(x.pairs)
    expected = canonical_hash(_tdrj_declaration_body(x.declaration_id,
        x.field_geometry_graph_hash, x.field_geometry_graph_binding_hash,
        Tuple(pair.pair_hash for pair in x.pairs)))
    expected == x.declaration_hash ||
        throw(ArgumentError("residual/Jacobian declaration-set hash mismatch"))
    x.model_class === :manufactured_compiler_fixture &&
        x.claim_ceiling == screen_only && !x.provider_selected &&
        !x.provider_executed && !x.emits_evidence && !x.grants_pass &&
        !x.promotion_authority && !x.p5_ready && !x.terminal_authority &&
        x.credible_physical_device_count == 0 ||
        throw(ArgumentError("residual/Jacobian declaration authority ceiling was exceeded"))
    expected
end

function _tdrj_specs(raw)
    raw isa Tuple && !(raw isa NamedTuple) && !isempty(raw) ||
        throw(ArgumentError("pair selectors must be a nonempty immutable tuple"))
    result = Tuple(begin
        spec isa NamedTuple && keys(spec) == _TDRJ_SPEC_KEYS ||
            throw(ArgumentError("pair selector fields must be exact"))
        (state_node_id=_tdrj_text(spec.state_node_id, "state_node_id"),
         residual_edge_id=_tdrj_text(spec.residual_edge_id, "residual_edge_id"),
         jacobian_edge_id=_tdrj_text(spec.jacobian_edge_id, "jacobian_edge_id"))
    end for spec in raw)
    ids = Tuple(x.state_node_id for x in result)
    length(unique(ids)) == length(ids) ||
        throw(ArgumentError("pair selectors contain duplicate state nodes"))
    result
end

function _tdrj_declare_set(binding::ForwardGraphBindingV4,
        declaration_id::String, pair_selectors)
    specs = _tdrj_specs(pair_selectors)
    inventory = _tdrj_root_inventory(binding)
    state_inventory = Tuple((index=i, node=node,
        identity_hash=binding.node_identity_hashes[i])
        for (i, node) in enumerate(binding.graph.nodes)
        if node.node_kind === :state)
    !isempty(state_inventory) ||
        throw(ArgumentError("current G2 graph contains no state nodes"))
    all(state -> (_tdrj_static_3d_type(state.node.physical_type,
        "state node"); true), state_inventory)
    state_ids = Tuple(state.node.node_id for state in state_inventory)
    spec_ids = Tuple(spec.state_node_id for spec in specs)
    Set(spec_ids) == Set(state_ids) && length(spec_ids) == length(state_ids) ||
        throw(ArgumentError("pair selectors must exactly cover every current G2 state"))
    pairs = Tuple(begin
        spec = only(item for item in specs
            if item.state_node_id == state.node.node_id)
        _tdrj_make_pair(binding, inventory, state, spec.residual_edge_id,
            spec.jacobian_edge_id)
    end for state in state_inventory)
    _tdrj_unique_pair_identities(pairs)
    residual_nodes = Set(binding.node_identity_hashes[i]
        for (i, node) in enumerate(binding.graph.nodes)
        if node.node_kind === :residual)
    jacobian_nodes = Set(binding.node_identity_hashes[i]
        for (i, node) in enumerate(binding.graph.nodes)
        if node.node_kind === :jacobian)
    Set(x.residual_operator.codomain_node_identity_hash for x in pairs) ==
        residual_nodes ||
        throw(ArgumentError("declaration set must exactly cover residual codomains"))
    Set(x.jacobian_operator.codomain_node_identity_hash for x in pairs) ==
        jacobian_nodes ||
        throw(ArgumentError("declaration set must exactly cover Jacobian codomains"))
    id = _tdrj_text(declaration_id, "declaration_id")
    pair_hashes = Tuple(canonical_hash(pair) for pair in pairs)
    body = _tdrj_declaration_body(id, binding.canonical_graph_hash,
        binding.binding_hash, pair_hashes)
    declaration = ThreeDGoverningResidualJacobianDeclarationSetV4(
        _TDRJ_TOKEN, id, binding.canonical_graph_hash,
        binding.binding_hash, pairs, :manufactured_compiler_fixture,
        screen_only, false, false, false, false, false, false, false, 0,
        canonical_hash(body))
    canonical_hash(declaration)
    declaration
end

"""Derive an ordered exact-cover declaration set from the current G2 graph."""
function declare_three_d_governing_residual_jacobian_set(
        binding::ForwardGraphBindingV4; declaration_id::String, pair_selectors)
    # Validate the source graph once. All inner derivation consumes the sealed
    # identity inventory produced by that validation instead of recursively
    # rebuilding the full canonical graph for every state/operator.
    canonical_hash(binding)
    _tdrj_declare_set(binding, declaration_id, pair_selectors)
end

function _tdrj_rebuild_declaration(binding::ForwardGraphBindingV4,
        declaration::ThreeDGoverningResidualJacobianDeclarationSetV4)
    canonical_hash(declaration)
    selectors = Tuple((state_node_id=pair.state_node_id,
        residual_edge_id=pair.residual_operator.edge_id,
        jacobian_edge_id=pair.jacobian_operator.edge_id)
        for pair in declaration.pairs)
    rebuilt = _tdrj_declare_set(binding, declaration.declaration_id, selectors)
    canonical_hash(rebuilt) == declaration.declaration_hash &&
        semantic_view(rebuilt) == semantic_view(declaration) ||
        throw(ArgumentError("residual/Jacobian declaration set differs from current G2"))
    rebuilt
end

function _tdrj_binding_body(declaration_hash, candidate_hash,
        compiled_prefix_hash, genome_hash, graph_hash, graph_binding_hash,
        pair_hashes, residual_root_hashes, jacobian_root_hashes,
        mission_hash, bounds_hash, scenario_hash)
    (revision=_TDRJ_REVISION,
     binding_kind=:three_d_governing_residual_jacobian_subject_binding,
     declaration_hash=declaration_hash, candidate_hash=candidate_hash,
     compiled_prefix_hash=compiled_prefix_hash,
     field_geometry_genome_hash=genome_hash,
     field_geometry_graph_hash=graph_hash,
     field_geometry_graph_binding_hash=graph_binding_hash,
     ordered_pair_hashes=pair_hashes,
     ordered_residual_ast_root_identity_hashes=residual_root_hashes,
     ordered_jacobian_ast_root_identity_hashes=jacobian_root_hashes,
     mission_hash=mission_hash, bounds_hash=bounds_hash,
     scenario_hash=scenario_hash)
end

struct ThreeDGoverningResidualJacobianBindingV4
    declaration_hash::Digest256
    candidate_hash::Digest256
    compiled_prefix_hash::Digest256
    field_geometry_genome_hash::Digest256
    field_geometry_graph_hash::Digest256
    field_geometry_graph_binding_hash::Digest256
    ordered_pair_hashes::Tuple{Vararg{Digest256}}
    ordered_residual_ast_root_identity_hashes::Tuple{Vararg{Digest256}}
    ordered_jacobian_ast_root_identity_hashes::Tuple{Vararg{Digest256}}
    mission_hash::Digest256
    bounds_hash::Digest256
    scenario_hash::Digest256
    binding_hash::Digest256
    function ThreeDGoverningResidualJacobianBindingV4(
            token::Val{:three_d_governing_residual_jacobian_private}, fields...)
        token === _TDRJ_TOKEN ||
            throw(ArgumentError("private residual/Jacobian subject binding constructor"))
        new(fields...)
    end
end

semantic_view(x::ThreeDGoverningResidualJacobianBindingV4) = merge(
    _tdrj_binding_body(x.declaration_hash, x.candidate_hash,
        x.compiled_prefix_hash, x.field_geometry_genome_hash,
        x.field_geometry_graph_hash, x.field_geometry_graph_binding_hash,
        x.ordered_pair_hashes,
        x.ordered_residual_ast_root_identity_hashes,
        x.ordered_jacobian_ast_root_identity_hashes, x.mission_hash,
        x.bounds_hash, x.scenario_hash), (binding_hash=x.binding_hash,))

function canonical_hash(x::ThreeDGoverningResidualJacobianBindingV4)
    n = length(x.ordered_pair_hashes)
    n > 0 && length(x.ordered_residual_ast_root_identity_hashes) == n &&
        length(x.ordered_jacobian_ast_root_identity_hashes) == n ||
        throw(ArgumentError("subject binding ordered set lengths mismatch"))
    expected = canonical_hash(_tdrj_binding_body(x.declaration_hash,
        x.candidate_hash, x.compiled_prefix_hash,
        x.field_geometry_genome_hash, x.field_geometry_graph_hash,
        x.field_geometry_graph_binding_hash, x.ordered_pair_hashes,
        x.ordered_residual_ast_root_identity_hashes,
        x.ordered_jacobian_ast_root_identity_hashes, x.mission_hash,
        x.bounds_hash, x.scenario_hash))
    expected == x.binding_hash ||
        throw(ArgumentError("residual/Jacobian subject binding hash mismatch"))
    expected
end

function make_three_d_governing_residual_jacobian_binding(
        compiled::CompiledCandidatePrefixV4,
        registry::GenomeContractRegistryV4, mission_payload, bounds_payload,
        comparison_scope, scenario_scope, scenario,
        declaration::ThreeDGoverningResidualJacobianDeclarationSetV4)
    comparison = _runtime_axis_tuple(comparison_scope, "comparison_scope")
    scenarios = _runtime_axis_tuple(scenario_scope, "scenario_scope")
    _runtime_validate_compiled_prefix(compiled, compiled.candidate, registry,
        mission_payload, bounds_payload, comparison, scenarios)
    canonical_hash(declaration)
    compiled.mission_payload == mission_payload &&
        compiled.bounds_payload == bounds_payload ||
        throw(ArgumentError("binding payloads differ from compiled prefix"))
    compiled.minimality_scope.mission_hash ==
        _runtime_decl_hash(mission_payload) &&
        compiled.minimality_scope.bounds_hash ==
        _runtime_decl_hash(bounds_payload) ||
        throw(ArgumentError("binding payload hashes differ from compiled prefix"))
    compiled.minimality_scope.comparison_scope == comparison &&
        compiled.minimality_scope.scenario_scope == scenarios ||
        throw(ArgumentError("binding scope differs from compiled prefix"))
    compiled.field_geometry_graph ===
        compiled.candidate.field_geometry_genome_ref.graph ||
        throw(ArgumentError("compiled prefix does not own its candidate G2 graph"))
    canonical_hash(compiled.field_geometry_graph) ==
        declaration.field_geometry_graph_hash ||
        throw(ArgumentError("declaration is foreign to compiled G2 graph"))
    declared = Tuple(x for x in
        compiled.candidate.field_geometry_genome_ref.fields
        if typeof(x) === ThreeDGoverningResidualJacobianDeclarationSetV4)
    length(declared) == 1 &&
        only(declared).declaration_hash == declaration.declaration_hash ||
        throw(ArgumentError("compiled candidate lacks this exact declaration set"))
    expected_grammar = canonical_hash((registry=registry, contracts=(
        compiled.candidate.mechanism_genome_ref.contract_ref,
        compiled.candidate.field_geometry_genome_ref.contract_ref,
        compiled.candidate.realization_control_genome_ref.contract_ref)))
    compiled.minimality_scope.grammar_hash == expected_grammar ||
        throw(ArgumentError("binding registry differs from compiled prefix"))
    is_canonical_value(scenario) ||
        throw(ArgumentError("binding scenario is not canonicalizable"))
    _forward_scenario_name(scenario) in scenarios ||
        throw(ArgumentError("binding scenario is outside frozen scope"))
    pair_hashes = Tuple(canonical_hash(pair) for pair in declaration.pairs)
    residual_roots = Tuple(pair.residual_operator.ast_root_identity_hash
        for pair in declaration.pairs)
    jacobian_roots = Tuple(pair.jacobian_operator.ast_root_identity_hash
        for pair in declaration.pairs)
    body = _tdrj_binding_body(declaration.declaration_hash,
        _forward_candidate_identity(compiled.candidate), compiled.prefix_hash,
        compiled.candidate.canonical_hashes.field_geometry_hash,
        declaration.field_geometry_graph_hash,
        declaration.field_geometry_graph_binding_hash, pair_hashes,
        residual_roots, jacobian_roots, _runtime_decl_hash(mission_payload),
        _runtime_decl_hash(bounds_payload), canonical_hash(scenario))
    ThreeDGoverningResidualJacobianBindingV4(_TDRJ_TOKEN,
        body.declaration_hash, body.candidate_hash,
        body.compiled_prefix_hash, body.field_geometry_genome_hash,
        body.field_geometry_graph_hash,
        body.field_geometry_graph_binding_hash, body.ordered_pair_hashes,
        body.ordered_residual_ast_root_identity_hashes,
        body.ordered_jacobian_ast_root_identity_hashes,
        body.mission_hash, body.bounds_hash, body.scenario_hash,
        canonical_hash(body))
end

function _tdrj_ownership_body(context, declaration, binding)
    (revision=_TDRJ_REVISION, schema=_TDRJ_SCHEMA,
     context_hash=context.context_hash,
     candidate_hash=context.candidate_hash,
     compiled_prefix_hash=context.compiled.prefix_hash,
     registry_hash=context.registry_hash,
     physical_subject_hash=context.subject.physical_subject_hash,
     field_geometry_genome_hash=binding.field_geometry_genome_hash,
     field_geometry_graph_hash=binding.field_geometry_graph_hash,
     field_geometry_graph_binding_hash=
        binding.field_geometry_graph_binding_hash,
     mission_hash=_runtime_decl_hash(context.mission_payload),
     bounds_hash=_runtime_decl_hash(context.bounds_payload),
     scenario_hash=context.scenario_hash,
     declaration_hash=declaration.declaration_hash,
     binding_hash=binding.binding_hash,
     ordered_pair_hashes=binding.ordered_pair_hashes,
     model_class=:manufactured_compiler_fixture,
     claim_ceiling=screen_only, provider_selected=false,
     provider_executed=false, emits_evidence=false, grants_pass=false,
     promotion_authority=false, p5_ready=false, terminal_authority=false,
     credible_physical_device_count=0)
end

struct ThreeDGoverningResidualJacobianOwnershipV4
    context_hash::Digest256
    candidate_hash::Digest256
    compiled_prefix_hash::Digest256
    registry_hash::Digest256
    physical_subject_hash::Digest256
    field_geometry_genome_hash::Digest256
    field_geometry_graph_hash::Digest256
    field_geometry_graph_binding_hash::Digest256
    mission_hash::Digest256
    bounds_hash::Digest256
    scenario_hash::Digest256
    declaration_hash::Digest256
    binding_hash::Digest256
    pairs::Tuple{Vararg{ThreeDResidualJacobianPairV4}}
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
    ownership_hash::Digest256
    function ThreeDGoverningResidualJacobianOwnershipV4(
            token::Val{:three_d_governing_residual_jacobian_private}, fields...)
        token === _TDRJ_TOKEN ||
            throw(ArgumentError("private residual/Jacobian ownership constructor"))
        new(fields...)
    end
end

function _tdrj_make_ownership(context, declaration, binding)
    body = _tdrj_ownership_body(context, declaration, binding)
    ThreeDGoverningResidualJacobianOwnershipV4(_TDRJ_TOKEN,
        body.context_hash, body.candidate_hash, body.compiled_prefix_hash,
        body.registry_hash, body.physical_subject_hash,
        body.field_geometry_genome_hash, body.field_geometry_graph_hash,
        body.field_geometry_graph_binding_hash, body.mission_hash,
        body.bounds_hash, body.scenario_hash, body.declaration_hash,
        body.binding_hash, declaration.pairs, body.model_class, body.claim_ceiling,
        body.provider_selected, body.provider_executed, body.emits_evidence,
        body.grants_pass, body.promotion_authority, body.p5_ready,
        body.terminal_authority, body.credible_physical_device_count,
        canonical_hash(body))
end

semantic_view(x::ThreeDGoverningResidualJacobianOwnershipV4) = (
    revision=_TDRJ_REVISION, schema=_TDRJ_SCHEMA,
    context_hash=x.context_hash, candidate_hash=x.candidate_hash,
    compiled_prefix_hash=x.compiled_prefix_hash, registry_hash=x.registry_hash,
    physical_subject_hash=x.physical_subject_hash,
    field_geometry_genome_hash=x.field_geometry_genome_hash,
    field_geometry_graph_hash=x.field_geometry_graph_hash,
    field_geometry_graph_binding_hash=x.field_geometry_graph_binding_hash,
    mission_hash=x.mission_hash, bounds_hash=x.bounds_hash,
    scenario_hash=x.scenario_hash, declaration_hash=x.declaration_hash,
    binding_hash=x.binding_hash,
    ordered_pair_hashes=Tuple(pair.pair_hash for pair in x.pairs),
    model_class=x.model_class,
    claim_ceiling=x.claim_ceiling, provider_selected=x.provider_selected,
    provider_executed=x.provider_executed, emits_evidence=x.emits_evidence,
    grants_pass=x.grants_pass, promotion_authority=x.promotion_authority,
    p5_ready=x.p5_ready, terminal_authority=x.terminal_authority,
    credible_physical_device_count=x.credible_physical_device_count,
    ownership_hash=x.ownership_hash)

function canonical_hash(x::ThreeDGoverningResidualJacobianOwnershipV4)
    !isempty(x.pairs) || throw(ArgumentError("ownership pair set cannot be empty"))
    Tuple(canonical_hash(pair) for pair in x.pairs)
    _tdrj_unique_pair_identities(x.pairs)
    view = semantic_view(x)
    body = NamedTuple{keys(view)[1:end-1]}(values(view)[1:end-1])
    expected = canonical_hash(body)
    expected == x.ownership_hash ||
        throw(ArgumentError("residual/Jacobian ownership hash mismatch"))
    x.model_class === :manufactured_compiler_fixture &&
        x.claim_ceiling == screen_only && !x.provider_selected &&
        !x.provider_executed && !x.emits_evidence && !x.grants_pass &&
        !x.promotion_authority && !x.p5_ready && !x.terminal_authority &&
        x.credible_physical_device_count == 0 ||
        throw(ArgumentError("residual/Jacobian ownership authority ceiling was exceeded"))
    expected
end

function _tdrj_context_ownership(context::ForwardChainContextV4,
        declaration::ThreeDGoverningResidualJacobianDeclarationSetV4,
        binding::ThreeDGoverningResidualJacobianBindingV4)
    canonical_hash(binding)
    # The public caller has already validated the complete context. Reuse its
    # sealed graph identity instead of invoking forward_graph_binding, which
    # would recursively validate the complete context a second time.
    graphs = Tuple(graph for genome in context.genome_bindings
        for graph in genome.graph_bindings if graph.role === :field_geometry)
    length(graphs) == 1 ||
        throw(ArgumentError("forward field/geometry graph is missing or ambiguous"))
    graph = only(graphs)
    rebuilt = _tdrj_rebuild_declaration(graph, declaration)
    pair_hashes = Tuple(canonical_hash(pair) for pair in rebuilt.pairs)
    residual_roots = Tuple(pair.residual_operator.ast_root_identity_hash
        for pair in rebuilt.pairs)
    jacobian_roots = Tuple(pair.jacobian_operator.ast_root_identity_hash
        for pair in rebuilt.pairs)
    binding.declaration_hash == rebuilt.declaration_hash ||
        throw(ArgumentError("subject binding declaration is foreign"))
    binding.candidate_hash == context.candidate_hash ||
        throw(ArgumentError("subject binding candidate is foreign"))
    binding.compiled_prefix_hash == context.compiled.prefix_hash ||
        throw(ArgumentError("subject binding compiled prefix is foreign"))
    binding.field_geometry_genome_hash ==
        context.candidate.canonical_hashes.field_geometry_hash ||
        throw(ArgumentError("subject binding G2 Genome is foreign"))
    binding.field_geometry_graph_hash == graph.canonical_graph_hash ||
        throw(ArgumentError("subject binding G2 graph is foreign"))
    binding.field_geometry_graph_binding_hash == graph.binding_hash ||
        throw(ArgumentError("subject binding G2 graph identity is foreign"))
    binding.ordered_pair_hashes == pair_hashes ||
        throw(ArgumentError("subject binding ordered pair set is foreign"))
    binding.ordered_residual_ast_root_identity_hashes == residual_roots ||
        throw(ArgumentError("subject binding ordered residual roots are foreign"))
    binding.ordered_jacobian_ast_root_identity_hashes == jacobian_roots ||
        throw(ArgumentError("subject binding ordered Jacobian roots are foreign"))
    binding.mission_hash == _runtime_decl_hash(context.mission_payload) ||
        throw(ArgumentError("subject binding mission is foreign"))
    binding.bounds_hash == _runtime_decl_hash(context.bounds_payload) ||
        throw(ArgumentError("subject binding bounds are foreign"))
    binding.scenario_hash == context.scenario_hash ||
        throw(ArgumentError("subject binding scenario is foreign"))
    _tdrj_make_ownership(context, rebuilt, binding)
end

function validate_three_d_governing_residual_jacobian_ownership(
        context::ForwardChainContextV4,
        ownership::ThreeDGoverningResidualJacobianOwnershipV4)
    validate_forward_chain_context(context)
    # The public trust boundary above validates all upstream data exactly once.
    # The inner ownership reconstruction reuses that validated inventory.
    declarations = Tuple(x for x in
        context.candidate.field_geometry_genome_ref.fields
        if typeof(x) === ThreeDGoverningResidualJacobianDeclarationSetV4)
    bindings = Tuple(x for x in context.subject.bindings
        if typeof(x) === ThreeDGoverningResidualJacobianBindingV4)
    length(declarations) == 1 && length(bindings) == 1 ||
        throw(ArgumentError("current context lacks one exact residual/Jacobian declaration set and binding"))
    expected = _tdrj_context_ownership(context, only(declarations),
        only(bindings))
    canonical_hash(ownership) == canonical_hash(expected) &&
        semantic_view(ownership) == semantic_view(expected) ||
        throw(ArgumentError("residual/Jacobian ownership differs from current context"))
    ownership.ownership_hash
end


validate_three_d_governing_residual_jacobian_ownership(
    ::ThreeDGoverningResidualJacobianOwnershipV4) = false

function _tdrj_resolution_body(context_hash, status, ownership, gaps)
    (revision=_TDRJ_REVISION,
     kind=:three_d_governing_residual_jacobian_resolution,
     context_hash=context_hash, status=status,
     ownership_hash=ownership === nothing ? nothing : ownership.ownership_hash,
     recoverable_gaps=gaps, claim_ceiling=screen_only,
     provider_selected=false, provider_executed=false,
     emits_evidence=false, grants_pass=false, promotion_authority=false,
     p5_ready=false, terminal_authority=false,
     credible_physical_device_count=0)
end

struct ThreeDGoverningResidualJacobianResolutionV4
    context_hash::Digest256
    status::Symbol
    ownership::Union{Nothing,ThreeDGoverningResidualJacobianOwnershipV4}
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
    resolution_hash::Digest256
    function ThreeDGoverningResidualJacobianResolutionV4(
            token::Val{:three_d_governing_residual_jacobian_private}, fields...)
        token === _TDRJ_TOKEN ||
            throw(ArgumentError("private residual/Jacobian resolution constructor"))
        new(fields...)
    end
end

semantic_view(x::ThreeDGoverningResidualJacobianResolutionV4) = merge(
    _tdrj_resolution_body(x.context_hash, x.status, x.ownership,
        x.recoverable_gaps), (resolution_hash=x.resolution_hash,))

function canonical_hash(x::ThreeDGoverningResidualJacobianResolutionV4)
    x.status in (:compiled, :recoverable_gap) ||
        throw(ArgumentError("invalid residual/Jacobian resolution status"))
    if x.status === :compiled
        x.ownership !== nothing &&
            x.recoverable_gaps == _TDRJ_DOWNSTREAM_GAPS ||
            throw(ArgumentError("compiled residual/Jacobian result is malformed"))
        canonical_hash(x.ownership)
    else
        x.ownership === nothing && !isempty(x.recoverable_gaps) ||
            throw(ArgumentError("recoverable residual/Jacobian result is malformed"))
    end
    expected = canonical_hash(_tdrj_resolution_body(x.context_hash,
        x.status, x.ownership, x.recoverable_gaps))
    expected == x.resolution_hash ||
        throw(ArgumentError("residual/Jacobian resolution hash mismatch"))
    x.claim_ceiling == screen_only && !x.provider_selected &&
        !x.provider_executed && !x.emits_evidence && !x.grants_pass &&
        !x.promotion_authority && !x.p5_ready && !x.terminal_authority &&
        x.credible_physical_device_count == 0 ||
        throw(ArgumentError("residual/Jacobian resolution authority ceiling was exceeded"))
    expected
end

function _tdrj_resolution(context_hash, ownership, gaps)
    gap_tuple = Tuple(String(x) for x in gaps)
    status = ownership === nothing ? :recoverable_gap : :compiled
    status === :compiled && gap_tuple == _TDRJ_DOWNSTREAM_GAPS ||
        status === :recoverable_gap && !isempty(gap_tuple) ||
        throw(ArgumentError("residual/Jacobian resolution status/gap mismatch"))
    body = _tdrj_resolution_body(context_hash, status, ownership, gap_tuple)
    ThreeDGoverningResidualJacobianResolutionV4(_TDRJ_TOKEN,
        context_hash, status, ownership, gap_tuple, screen_only, false,
        false, false, false, false, false, false, 0, canonical_hash(body))
end

"""Compile exact full-state ownership or retain typed recoverable gaps."""
function compile_three_d_governing_residual_jacobian(
        context::ForwardChainContextV4)
    validate_forward_chain_context(context)
    # The public trust boundary above validates all upstream data exactly once;
    # inner declaration/ownership work consumes the sealed graph inventory.
    declarations = Tuple(x for x in
        context.candidate.field_geometry_genome_ref.fields
        if typeof(x) === ThreeDGoverningResidualJacobianDeclarationSetV4)
    bindings = Tuple(x for x in context.subject.bindings
        if typeof(x) === ThreeDGoverningResidualJacobianBindingV4)
    gaps = String[]
    isempty(declarations) ? push!(gaps, _TDRJ_GAP) :
        length(declarations) == 1 ||
            push!(gaps, "ambiguous_typed_three_d_governing_residual_jacobian_ownership")
    isempty(bindings) ? push!(gaps, _TDRJ_BINDING_GAP) :
        length(bindings) == 1 ||
            push!(gaps, "ambiguous_three_d_governing_residual_jacobian_subject_binding")
    if !isempty(gaps)
        return _tdrj_resolution(context.context_hash, nothing,
            (Tuple(gaps)..., _TDRJ_DOWNSTREAM_GAPS...))
    end
    ownership = _tdrj_context_ownership(context, only(declarations),
        only(bindings))
    _tdrj_resolution(context.context_hash, ownership,
        _TDRJ_DOWNSTREAM_GAPS)
end

three_d_governing_residual_jacobian_manifest() = (
    schema=_TDRJ_SCHEMA, revision=_TDRJ_REVISION,
    purpose=:typed_three_d_full_state_residual_jacobian_ownership,
    declaration_kind=:ordered_exact_state_cover_set,
    statuses=(:compiled, :recoverable_gap),
    generic_status=:recoverable_gap,
    manufactured_fixture_status=:compiled, resolved_gap=_TDRJ_GAP,
    downstream_gaps=_TDRJ_DOWNSTREAM_GAPS,
    requires_atomic_mimo=true, requires_registered_ast_roots=true,
    requires_distinct_edges_and_roots=true,
    requires_exact_state_coverage=true,
    requires_domain_codomain_unit_dimension_compatibility=true,
    model_class=:manufactured_compiler_fixture,
    claim_ceiling=screen_only, provider_selected=false,
    provider_executed=false, emits_evidence=false, grants_pass=false,
    physical_validation=false, engineering_validation=false,
    promotion_authority=false, p5_ready=false, terminal_authority=false,
    credible_physical_device_count=0)
