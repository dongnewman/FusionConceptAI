"""Sealed, candidate-bound identity context for RuntimeV4 forward modules.

This file is intentionally isolated from `FusionRuntimeV4.jl`.  It creates no
evidence, stage outcome, promotion, or terminal classification.  Downstream
modules may consume a validated context, but may not reconstruct one from
caller-supplied digests.
"""

import FusionConceptAI: semantic_view, canonical_hash
using FusionConceptAI

const _FORWARD_CHAIN_CONTEXT_REVISION = "forward-chain-context-v1"
const _FORWARD_GRAPH_ROLES = (:mechanism, :field_geometry, :realization, :control)
const _FORWARD_GENOME_ROLES = (:mechanism, :field_geometry, :realization_control)

struct _ForwardChainContextToken end
const _FORWARD_CHAIN_CONTEXT_TOKEN = _ForwardChainContextToken()

"""Exact identity of one owned typed graph, including names and AST roots."""
struct ForwardGraphBindingV4
    role::Symbol
    graph::TypedOperatorHypergraphV1
    canonical_graph_hash::Digest256
    node_identity_hashes::Tuple{Vararg{Digest256}}
    hyperedge_identity_hashes::Tuple{Vararg{Digest256}}
    ast_root_identity_hashes::Tuple{Vararg{Digest256}}
    binding_hash::Digest256
    function ForwardGraphBindingV4(token::_ForwardChainContextToken, role::Symbol,
            graph::TypedOperatorHypergraphV1, canonical_graph_hash::Digest256,
            node_identity_hashes::Tuple{Vararg{Digest256}},
            hyperedge_identity_hashes::Tuple{Vararg{Digest256}},
            ast_root_identity_hashes::Tuple{Vararg{Digest256}}, binding_hash::Digest256)
        token === _FORWARD_CHAIN_CONTEXT_TOKEN || throw(ArgumentError("private constructor"))
        new(role, graph, canonical_graph_hash, node_identity_hashes,
            hyperedge_identity_hashes, ast_root_identity_hashes, binding_hash)
    end
end

semantic_view(x::ForwardGraphBindingV4) = (
    role=x.role,
    canonical_graph_hash=x.canonical_graph_hash,
    node_identity_hashes=x.node_identity_hashes,
    hyperedge_identity_hashes=x.hyperedge_identity_hashes,
    ast_root_identity_hashes=x.ast_root_identity_hashes,
    binding_hash=x.binding_hash)

"""One of the three frozen Genome contracts and the graphs it owns."""
struct ForwardGenomeBindingV4
    role::Symbol
    contract_ref::GenomeContractRef
    genome_hash::Digest256
    graph_bindings::Tuple{Vararg{ForwardGraphBindingV4}}
    binding_hash::Digest256
    function ForwardGenomeBindingV4(token::_ForwardChainContextToken, role::Symbol,
            contract_ref::GenomeContractRef, genome_hash::Digest256,
            graph_bindings::Tuple{Vararg{ForwardGraphBindingV4}}, binding_hash::Digest256)
        token === _FORWARD_CHAIN_CONTEXT_TOKEN || throw(ArgumentError("private constructor"))
        new(role, contract_ref, genome_hash, graph_bindings, binding_hash)
    end
end

semantic_view(x::ForwardGenomeBindingV4) = (role=x.role, contract_ref=x.contract_ref,
    genome_hash=x.genome_hash, graph_binding_hashes=Tuple(canonical_hash(g) for g in x.graph_bindings),
    binding_hash=x.binding_hash)

"""Validated identity shared by one candidate/scenario forward-chain slice."""
struct ForwardChainContextV4
    candidate::CandidateStatePackageV4
    compiled::CompiledCandidatePrefixV4
    registry::GenomeContractRegistryV4
    mission_payload::Any
    bounds_payload::Any
    comparison_scope::Tuple{Vararg{String}}
    scenario_scope::Tuple{Vararg{String}}
    subject::ExecutablePhysicalSubjectV4
    scenario::Any
    genome_bindings::NTuple{3,ForwardGenomeBindingV4}
    obligations::Tuple{Vararg{CapabilitySignatureV4}}
    candidate_hash::Digest256
    registry_hash::Digest256
    scenario_hash::Digest256
    obligation_hashes::Tuple{Vararg{Digest256}}
    context_hash::Digest256
    function ForwardChainContextV4(token::_ForwardChainContextToken,
            candidate::CandidateStatePackageV4, compiled::CompiledCandidatePrefixV4,
            registry::GenomeContractRegistryV4, mission_payload, bounds_payload,
            comparison_scope::Tuple{Vararg{String}}, scenario_scope::Tuple{Vararg{String}},
            subject::ExecutablePhysicalSubjectV4, scenario,
            genome_bindings::NTuple{3,ForwardGenomeBindingV4},
            obligations::Tuple{Vararg{CapabilitySignatureV4}}, candidate_hash::Digest256,
            registry_hash::Digest256, scenario_hash::Digest256,
            obligation_hashes::Tuple{Vararg{Digest256}}, context_hash::Digest256)
        token === _FORWARD_CHAIN_CONTEXT_TOKEN || throw(ArgumentError("private constructor"))
        new(candidate, compiled, registry, mission_payload, bounds_payload,
            comparison_scope, scenario_scope, subject, scenario, genome_bindings,
            obligations, candidate_hash, registry_hash, scenario_hash,
            obligation_hashes, context_hash)
    end
end

function _forward_node_identity(node::TypedNode, position::Int)
    canonical_hash((kind=:typed_graph_node, position=position, node_id=node.node_id,
        node_kind=node.node_kind, physical_type=node.physical_type, label=node.label))
end

function _forward_edge_program(edge::TypedHyperedge)
    edge.ast.nodes, (edge.ast.root,), canonical_hash(edge.ast)
end

function _forward_edge_program(edge::AtomicMIMOHyperedgeV1)
    canonical_hash(edge.program) == edge.program_hash ||
        throw(ArgumentError("AtomicMIMOHyperedgeV1 program hash mismatch"))
    edge.program.nodes, edge.program.roots, edge.program_hash
end

function _forward_edge_identity(edge::TypedHyperedge, position::Int)
    canonical_hash((kind=:TypedHyperedge, position=position, edge_id=edge.edge_id,
        inputs=edge.inputs, outputs=edge.outputs, ast_hash=canonical_hash(edge.ast), role=edge.role))
end

function _forward_edge_identity(edge::AtomicMIMOHyperedgeV1, position::Int)
    canonical_hash(edge.program) == edge.program_hash ||
        throw(ArgumentError("AtomicMIMOHyperedgeV1 program hash mismatch"))
    canonical_hash((kind=:AtomicMIMOHyperedgeV1, position=position, edge_id=edge.edge_id,
        input_bindings=edge.input_bindings, output_bindings=edge.output_bindings,
        program_hash=edge.program_hash, role=edge.role, account_effects=edge.account_effects,
        interface_flux_pairs=edge.interface_flux_pairs, registry_hash=canonical_hash(edge.registry)))
end

function _forward_root_output_node(edge::TypedHyperedge, root_position::Int)
    root_position == 1 || throw(ArgumentError("TypedHyperedge has one root"))
    only(edge.outputs)
end

function _forward_root_output_node(edge::AtomicMIMOHyperedgeV1, root_position::Int)
    matches = Tuple(b.graph_node_index for b in edge.output_bindings if b.program_position == root_position)
    length(matches) == 1 || throw(ArgumentError("AST root output binding is missing or ambiguous"))
    only(matches)
end

function _forward_graph_components(role::Symbol, graph::TypedOperatorHypergraphV1)
    role in _FORWARD_GRAPH_ROLES || throw(ArgumentError("unknown forward graph role"))
    node_ids = Tuple(n.node_id for n in graph.nodes)
    length(unique(node_ids)) == length(node_ids) || throw(ArgumentError("typed graph node IDs must be unique"))
    edge_ids = Tuple(e.edge_id for e in graph.hyperedges)
    length(unique(edge_ids)) == length(edge_ids) || throw(ArgumentError("typed graph edge IDs must be unique"))
    nodes = Tuple(_forward_node_identity(n, i) for (i, n) in enumerate(graph.nodes))
    edges = Tuple(_forward_edge_identity(e, i) for (i, e) in enumerate(graph.hyperedges))
    roots = Digest256[]
    for (edge_position, edge) in enumerate(graph.hyperedges)
        program_nodes, program_roots, program_hash = _forward_edge_program(edge)
        for (root_position, program_node_index) in enumerate(program_roots)
            1 <= program_node_index <= length(program_nodes) ||
                throw(ArgumentError("AST root node reference is out of range"))
            graph_node_index = _forward_root_output_node(edge, root_position)
            1 <= graph_node_index <= length(graph.nodes) ||
                throw(ArgumentError("AST root graph output reference is out of range"))
            push!(roots, canonical_hash((kind=:typed_ast_root, graph_role=role,
                edge_position=edge_position, edge_id=edge.edge_id,
                program_hash=program_hash, root_position=root_position,
                program_node_index=program_node_index,
                root_node_hash=canonical_hash(program_nodes[program_node_index]),
                graph_output_node_hash=nodes[graph_node_index])))
        end
    end
    graph_hash = canonical_hash(graph)
    body = (revision=_FORWARD_CHAIN_CONTEXT_REVISION, role=role,
        canonical_graph_hash=graph_hash, node_identity_hashes=nodes,
        hyperedge_identity_hashes=edges, ast_root_identity_hashes=Tuple(roots))
    (canonical_graph_hash=graph_hash, node_identity_hashes=nodes,
     hyperedge_identity_hashes=edges, ast_root_identity_hashes=Tuple(roots),
     binding_hash=canonical_hash(body))
end

function _make_forward_graph_binding(role::Symbol, graph::TypedOperatorHypergraphV1)
    c = _forward_graph_components(role, graph)
    ForwardGraphBindingV4(_FORWARD_CHAIN_CONTEXT_TOKEN, role, graph,
        c.canonical_graph_hash, c.node_identity_hashes, c.hyperedge_identity_hashes,
        c.ast_root_identity_hashes, c.binding_hash)
end

function _validate_forward_graph_binding(binding::ForwardGraphBindingV4)
    c = _forward_graph_components(binding.role, binding.graph)
    binding.canonical_graph_hash == c.canonical_graph_hash || throw(ArgumentError("forward graph canonical hash mismatch"))
    binding.node_identity_hashes == c.node_identity_hashes || throw(ArgumentError("forward graph node identity mismatch"))
    binding.hyperedge_identity_hashes == c.hyperedge_identity_hashes || throw(ArgumentError("forward graph hyperedge identity mismatch"))
    binding.ast_root_identity_hashes == c.ast_root_identity_hashes || throw(ArgumentError("forward graph AST root identity mismatch"))
    binding.binding_hash == c.binding_hash || throw(ArgumentError("forward graph binding hash mismatch"))
    binding.binding_hash
end

canonical_hash(x::ForwardGraphBindingV4) = _validate_forward_graph_binding(x)

function _make_forward_genome_binding(role::Symbol, contract_ref::GenomeContractRef,
        genome_hash::Digest256, graph_bindings::Tuple{Vararg{ForwardGraphBindingV4}})
    role in _FORWARD_GENOME_ROLES || throw(ArgumentError("unknown forward Genome role"))
    graph_hashes = Tuple(canonical_hash(g) for g in graph_bindings)
    body = (revision=_FORWARD_CHAIN_CONTEXT_REVISION, role=role,
        contract_ref=contract_ref, genome_hash=genome_hash, graph_binding_hashes=graph_hashes)
    ForwardGenomeBindingV4(_FORWARD_CHAIN_CONTEXT_TOKEN, role, contract_ref,
        genome_hash, graph_bindings, canonical_hash(body))
end

function _validate_forward_genome_binding(binding::ForwardGenomeBindingV4)
    expected_graph_roles = binding.role === :mechanism ? (:mechanism,) :
        binding.role === :field_geometry ? (:field_geometry,) :
        binding.role === :realization_control ? (:realization, :control) :
        throw(ArgumentError("unknown forward Genome role"))
    Tuple(g.role for g in binding.graph_bindings) == expected_graph_roles ||
        throw(ArgumentError("forward Genome graph ownership mismatch"))
    graph_hashes = Tuple(canonical_hash(g) for g in binding.graph_bindings)
    body = (revision=_FORWARD_CHAIN_CONTEXT_REVISION, role=binding.role,
        contract_ref=binding.contract_ref, genome_hash=binding.genome_hash,
        graph_binding_hashes=graph_hashes)
    expected = canonical_hash(body)
    binding.binding_hash == expected || throw(ArgumentError("forward Genome binding hash mismatch"))
    expected
end

canonical_hash(x::ForwardGenomeBindingV4) = _validate_forward_genome_binding(x)

_forward_candidate_identity(candidate::CandidateStatePackageV4) =
    canonical_hash((identity_ref=candidate.identity_ref, candidate=semantic_view(candidate)))

function _forward_subject_identity(subject::ExecutablePhysicalSubjectV4)
    body = (compiled_prefix_hash=subject.compiled_prefix_hash,
        genome_bundle_hash=subject.genome_bundle_hash, mission_hash=subject.mission_hash,
        bounds_hash=subject.bounds_hash, bindings=subject.bindings,
        scenarios=subject.scenarios, materialized_payload=subject.materialized_payload,
        operator_obligations=subject.operator_obligations)
    is_canonical_value(body) || throw(ArgumentError("physical subject body is not canonicalizable"))
    canonical_hash(body)
end

function _forward_scenario_name(scenario)
    hasproperty(scenario, :name) || throw(ArgumentError("forward scenario must have a name"))
    _runtime_nonwild_text(getproperty(scenario, :name), "scenario name")
end

function _forward_genome_bindings(candidate::CandidateStatePackageV4,
        compiled::CompiledCandidatePrefixV4, registry::GenomeContractRegistryV4)
    refs = (candidate.mechanism_genome_ref.contract_ref,
        candidate.field_geometry_genome_ref.contract_ref,
        candidate.realization_control_genome_ref.contract_ref)
    expected_refs = (registry.mechanism, registry.field_geometry, registry.realization_control)
    refs == expected_refs || throw(ArgumentError("candidate Genome contract roles do not match registry"))
    ref_hashes = Tuple(canonical_hash(r) for r in refs)
    length(unique(ref_hashes)) == 3 || throw(ArgumentError("Genome contract roles must be distinct"))

    mechanism_hash_value = mechanism_hash(candidate.mechanism_genome_ref)
    field_hash_value = field_geometry_hash(candidate.field_geometry_genome_ref)
    realization_hash_value = realization_control_hash(candidate.realization_control_genome_ref)
    stored = candidate.canonical_hashes
    stored.mechanism_hash == mechanism_hash_value || throw(ArgumentError("candidate mechanism Genome hash mismatch"))
    stored.field_geometry_hash == field_hash_value || throw(ArgumentError("candidate field/geometry Genome hash mismatch"))
    stored.realization_control_hash == realization_hash_value || throw(ArgumentError("candidate realization/control Genome hash mismatch"))
    expected_bundle = genome_bundle_hash(candidate.mechanism_genome_ref,
        candidate.field_geometry_genome_ref, candidate.realization_control_genome_ref;
        mission_contract=candidate.mission_contract_ref)
    stored.genome_bundle_hash == expected_bundle || throw(ArgumentError("candidate Genome bundle hash mismatch"))

    mechanism = _make_forward_graph_binding(:mechanism, compiled.mechanism_graph)
    field = _make_forward_graph_binding(:field_geometry, compiled.field_geometry_graph)
    realization = _make_forward_graph_binding(:realization, compiled.realization_graph)
    control = _make_forward_graph_binding(:control, compiled.control_graph)
    (_make_forward_genome_binding(:mechanism, refs[1], mechanism_hash_value, (mechanism,)),
     _make_forward_genome_binding(:field_geometry, refs[2], field_hash_value, (field,)),
     _make_forward_genome_binding(:realization_control, refs[3], realization_hash_value,
        (realization, control)))
end


function _forward_context_components(candidate::CandidateStatePackageV4,
        compiled::CompiledCandidatePrefixV4, registry::GenomeContractRegistryV4,
        mission_payload, bounds_payload, comparison_scope, scenario_scope,
        subject::ExecutablePhysicalSubjectV4, scenario)
    comparison = _runtime_axis_tuple(comparison_scope, "comparison_scope")
    scope_scenarios = _runtime_axis_tuple(scenario_scope, "scenario_scope")
    _runtime_validate_compiled_prefix(compiled, candidate, registry, mission_payload,
        bounds_payload, comparison, scope_scenarios)
    _forward_candidate_identity(compiled.candidate) == _forward_candidate_identity(candidate) ||
        throw(ArgumentError("compiled prefix does not own the supplied candidate"))

    genome_bindings = _forward_genome_bindings(candidate, compiled, registry)
    Tuple(g.role for g in genome_bindings) == _FORWARD_GENOME_ROLES ||
        throw(ArgumentError("forward context Genome roles are missing, duplicated, or reordered"))
    Tuple(canonical_hash(g) for g in genome_bindings)

    subject.compiled_prefix_hash == compiled.prefix_hash || throw(ArgumentError("physical subject prefix mismatch"))
    subject.genome_bundle_hash == candidate.canonical_hashes.genome_bundle_hash || throw(ArgumentError("physical subject Genome bundle mismatch"))
    subject.mission_hash == _runtime_decl_hash(mission_payload) || throw(ArgumentError("physical subject mission mismatch"))
    subject.bounds_hash == _runtime_decl_hash(bounds_payload) || throw(ArgumentError("physical subject bounds mismatch"))
    _forward_subject_identity(subject) == subject.physical_subject_hash || throw(ArgumentError("physical subject content hash mismatch"))
    !isempty(subject.bindings) || throw(ArgumentError("physical subject has no materialized bindings"))
    subject.materialized_payload !== nothing && subject.materialized_payload !== missing ||
        throw(ArgumentError("physical subject is not materialized"))
    !isempty(subject.scenarios) || throw(ArgumentError("physical subject has no frozen scenarios"))
    subject_names = Tuple(_forward_scenario_name(s) for s in subject.scenarios)
    subject_names == scope_scenarios || throw(ArgumentError("physical subject scenarios do not exactly match frozen scenario scope"))
    subject_scenario_hashes = Tuple(begin
        is_canonical_value(s) || throw(ArgumentError("physical subject scenario is not canonicalizable"))
        canonical_hash(s)
    end for s in subject.scenarios)
    length(unique(subject_scenario_hashes)) == length(subject_scenario_hashes) ||
        throw(ArgumentError("physical subject scenarios have duplicate canonical identities"))
    is_canonical_value(scenario) || throw(ArgumentError("selected scenario is not canonicalizable"))
    scenario_hash = canonical_hash(scenario)
    count(==(scenario_hash), subject_scenario_hashes) == 1 ||
        throw(ArgumentError("selected scenario is absent from or ambiguous in physical subject"))
    _forward_scenario_name(scenario) in scope_scenarios ||
        throw(ArgumentError("selected scenario is outside frozen scenario scope"))

    obligations = Tuple(derive_capability_obligations(compiled))
    all(o -> o isa CapabilitySignatureV4, obligations) ||
        throw(ArgumentError("compiled obligations are not typed CapabilitySignatureV4 values"))
    !isempty(obligations) || throw(ArgumentError("compiled prefix has no derived obligations"))
    obligation_hashes = Tuple(canonical_hash(o) for o in obligations)
    length(unique(obligation_hashes)) == length(obligation_hashes) ||
        throw(ArgumentError("compiled prefix has duplicate obligation identities"))
    subject_obligations = Tuple(subject.operator_obligations)
    all(o -> o isa CapabilitySignatureV4, subject_obligations) ||
        throw(ArgumentError("physical subject obligations are not typed"))
    Tuple(canonical_hash(o) for o in subject_obligations) == obligation_hashes ||
        throw(ArgumentError("physical subject obligations do not exactly equal compiler-derived obligations"))

    candidate_hash = _forward_candidate_identity(candidate)
    registry_hash = canonical_hash(registry)
    body = (revision=_FORWARD_CHAIN_CONTEXT_REVISION,
        candidate_hash=candidate_hash, compiled_prefix_hash=compiled.prefix_hash,
        registry_hash=registry_hash, mission_hash=_runtime_decl_hash(mission_payload),
        bounds_hash=_runtime_decl_hash(bounds_payload), comparison_scope=comparison,
        scenario_scope=scope_scenarios, physical_subject_hash=subject.physical_subject_hash,
        scenario_hash=scenario_hash,
        genome_binding_hashes=Tuple(canonical_hash(g) for g in genome_bindings),
        obligation_hashes=obligation_hashes)
    (comparison_scope=comparison, scenario_scope=scope_scenarios,
     genome_bindings=genome_bindings, obligations=obligations,
     candidate_hash=candidate_hash, registry_hash=registry_hash,
     scenario_hash=scenario_hash, obligation_hashes=obligation_hashes,
     context_hash=canonical_hash(body))
end

"""Create one sealed context after recomputing every upstream identity."""
function make_forward_chain_context(candidate::CandidateStatePackageV4,
        compiled::CompiledCandidatePrefixV4, registry::GenomeContractRegistryV4,
        mission_payload, bounds_payload, comparison_scope, scenario_scope,
        subject::ExecutablePhysicalSubjectV4, scenario)
    c = _forward_context_components(candidate, compiled, registry, mission_payload,
        bounds_payload, comparison_scope, scenario_scope, subject, scenario)
    ForwardChainContextV4(_FORWARD_CHAIN_CONTEXT_TOKEN, candidate, compiled, registry,
        mission_payload, bounds_payload, c.comparison_scope, c.scenario_scope,
        subject, scenario, c.genome_bindings, c.obligations, c.candidate_hash,
        c.registry_hash, c.scenario_hash, c.obligation_hashes, c.context_hash)
end

"""Create one context per frozen subject scenario, requiring exact batch order."""
function make_forward_chain_contexts(candidate::CandidateStatePackageV4,
        compiled::CompiledCandidatePrefixV4, registry::GenomeContractRegistryV4,
        mission_payload, bounds_payload, comparison_scope, scenario_scope,
        subject::ExecutablePhysicalSubjectV4, scenarios::Tuple)
    isempty(scenarios) && throw(ArgumentError("forward scenario batch cannot be empty"))
    requested_hashes = Tuple(begin
        is_canonical_value(s) || throw(ArgumentError("forward scenario is not canonicalizable"))
        canonical_hash(s)
    end for s in scenarios)
    length(unique(requested_hashes)) == length(requested_hashes) ||
        throw(ArgumentError("forward scenario batch contains duplicate canonical identities"))
    subject_hashes = Tuple(canonical_hash(s) for s in subject.scenarios)
    requested_hashes == subject_hashes ||
        throw(ArgumentError("forward scenario batch must exactly match frozen subject order"))
    Tuple(make_forward_chain_context(candidate, compiled, registry, mission_payload,
        bounds_payload, comparison_scope, scenario_scope, subject, scenario)
        for scenario in scenarios)
end

function _forward_context_body(context::ForwardChainContextV4)
    (revision=_FORWARD_CHAIN_CONTEXT_REVISION,
     candidate_hash=context.candidate_hash,
     compiled_prefix_hash=context.compiled.prefix_hash,
     registry_hash=context.registry_hash,
     mission_hash=_runtime_decl_hash(context.mission_payload),
     bounds_hash=_runtime_decl_hash(context.bounds_payload),
     comparison_scope=context.comparison_scope,
     scenario_scope=context.scenario_scope,
     physical_subject_hash=context.subject.physical_subject_hash,
     scenario_hash=context.scenario_hash,
     genome_binding_hashes=Tuple(canonical_hash(g) for g in context.genome_bindings),
     obligation_hashes=context.obligation_hashes)
end

"""Fail-closed integrity validation; returns the recomputed context digest."""
function validate_forward_chain_context(context::ForwardChainContextV4)
    c = _forward_context_components(context.candidate, context.compiled,
        context.registry, context.mission_payload, context.bounds_payload,
        context.comparison_scope, context.scenario_scope, context.subject,
        context.scenario)
    context.genome_bindings == c.genome_bindings || throw(ArgumentError("forward context Genome bindings mismatch"))
    context.obligations == c.obligations || throw(ArgumentError("forward context obligations mismatch"))
    context.candidate_hash == c.candidate_hash || throw(ArgumentError("forward context candidate hash mismatch"))
    context.registry_hash == c.registry_hash || throw(ArgumentError("forward context registry hash mismatch"))
    context.scenario_hash == c.scenario_hash || throw(ArgumentError("forward context scenario hash mismatch"))
    context.obligation_hashes == c.obligation_hashes || throw(ArgumentError("forward context obligation hashes mismatch"))
    recomputed = canonical_hash(_forward_context_body(context))
    recomputed == c.context_hash || throw(ArgumentError("forward context body reconstruction mismatch"))
    context.context_hash == recomputed || throw(ArgumentError("forward context content hash mismatch"))
    recomputed
end

canonical_hash(x::ForwardChainContextV4) = validate_forward_chain_context(x)

semantic_view(x::ForwardChainContextV4) = (
    candidate_hash=x.candidate_hash, compiled_prefix_hash=x.compiled.prefix_hash,
    registry_hash=x.registry_hash, mission_hash=_runtime_decl_hash(x.mission_payload),
    bounds_hash=_runtime_decl_hash(x.bounds_payload), comparison_scope=x.comparison_scope,
    scenario_scope=x.scenario_scope, physical_subject_hash=x.subject.physical_subject_hash,
    scenario_hash=x.scenario_hash,
    genome_binding_hashes=Tuple(canonical_hash(g) for g in x.genome_bindings),
    obligation_hashes=x.obligation_hashes, context_hash=x.context_hash)

function forward_genome_binding(context::ForwardChainContextV4, role::Symbol)
    validate_forward_chain_context(context)
    hits = Tuple(g for g in context.genome_bindings if g.role === role)
    length(hits) == 1 || throw(ArgumentError("forward Genome role is missing or ambiguous"))
    only(hits)
end

function forward_graph_binding(context::ForwardChainContextV4, role::Symbol)
    validate_forward_chain_context(context)
    hits = Tuple(graph for genome in context.genome_bindings for graph in genome.graph_bindings
        if graph.role === role)
    length(hits) == 1 || throw(ArgumentError("forward graph role is missing or ambiguous"))
    only(hits)
end

forward_chain_context_manifest() = (
    schema="fusionconceptai:runtime-v4-forward-chain-context",
    revision=_FORWARD_CHAIN_CONTEXT_REVISION,
    purpose=:validated_forward_identity,
    emits_evidence=false,
    terminal_authority=false)
