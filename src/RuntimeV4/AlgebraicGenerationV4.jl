# Bounded G1 constraint edits for a screen-only search-mechanics slice.
# This changes a typed AST constant, not a label or proposal prediction; it
# is not a fusion design operator and cannot promote the scoped result.
using FusionConceptAI
import FusionConceptAI: canonical_hash
import FusionConceptAI: semantic_view

function _generation_constant_edge(candidate::CandidateStatePackageV4, edge_id::String)
    graph = candidate.mechanism_genome_ref.payload.operator_graph
    matches = [e for e in graph.hyperedges if e isa AtomicMIMOHyperedgeV1 &&
        e.edge_id == edge_id && e.role == constraint]
    length(matches) == 1 || throw(ArgumentError("exactly one typed constraint edge is required"))
    edge = only(matches)
    positions = [i for (i, n) in enumerate(edge.program.nodes) if n isa ASTConstantV1 &&
        n.value isa Integer && !(n.value isa Bool)]
    length(positions) == 1 || throw(ArgumentError("constraint edit requires exactly one integer AST constant"))
    edge, only(positions)
end

function _exact_generation_feedback(parent::CandidateStatePackageV4,
        entry::CandidateQueueEntryV4, feedback::AlgebraicScopedResolutionV4,
        registry::GenomeContractRegistryV4, expected_scenario_hash::Digest256)
    entry.candidate.identity_ref == parent.identity_ref &&
        semantic_view(entry.candidate) == semantic_view(parent) &&
        entry.registry_hash == canonical_hash(registry) &&
        feedback.candidate_ref == entry.candidate_ref &&
        feedback.prefix_hash == entry.compiled.prefix_hash &&
        feedback.scenario_hash == expected_scenario_hash &&
        feedback.classification == :evaluated_screen &&
        feedback.report.evidence.claim_ceiling == screen_only ||
        throw(ArgumentError("generation feedback is not the exact parent screen"))
    nothing
end

"""Materialize an actual G1 child after an exact parent screen result."""
function algebraic_generation_edit(parent::CandidateStatePackageV4,
        parent_entry::CandidateQueueEntryV4, feedback::AlgebraicScopedResolutionV4,
        registry::GenomeContractRegistryV4, edge_id::AbstractString,
        new_value::Integer, proposal_id::AbstractString,
        expected_scenario_hash::Digest256)
    _exact_generation_feedback(parent, parent_entry, feedback, registry, expected_scenario_hash)
    new_value isa Bool && throw(ArgumentError("boolean constant is not an integer edit"))
    -10 <= new_value <= 10 || throw(ArgumentError("bounded algebraic fixture edit must stay in [-10,10]"))
    edge, position = _generation_constant_edge(parent, String(edge_id))
    old = edge.program.nodes[position]::ASTConstantV1
    new_value != old.value || throw(ArgumentError("generation edit must change the AST constant"))
    graph = parent.mechanism_genome_ref.payload.operator_graph
    nodes = ntuple(i -> i == position ? ASTConstantV1(old.name, Int(new_value), old.output_type, old.parameters) :
        edge.program.nodes[i], length(edge.program.nodes))
    program = TypedASTProgramV1(nodes, edge.program.roots, edge.program.input_ports; registry=edge.registry)
    edited = AtomicMIMOHyperedgeV1(edge.edge_id, edge.input_bindings, edge.output_bindings,
        program, edge.role; account_effects=edge.account_effects,
        interface_flux_pairs=edge.interface_flux_pairs, registry=edge.registry)
    edges = Tuple(e === edge ? edited : e for e in graph.hyperedges)
    next_graph = TypedOperatorHypergraphV1(graph.nodes, edges; registry=edge.registry)
    payload = parent.mechanism_genome_ref.payload
    next_payload = MechanismGenomePayloadV1(payload.states, payload.invariants, next_graph,
        payload.parameters, payload.symmetries, payload.observables, payload.operator_holes)
    mechanism = MechanismGenomeV4(parent.mechanism_genome_ref.seed + 1,
        parent.mechanism_genome_ref.contract_ref, next_payload)
    trace = (genome=:G1, edit=:replace_integer_ast_constant, edge_id=String(edge_id),
        constant_name=old.name, old_value=old.value, new_value=Int(new_value),
        old_program_hash=canonical_hash(edge.program), new_program_hash=canonical_hash(program),
        feedback_resolution_hash=feedback.resolution_hash)
    # Prefix identity excludes proposal metadata. Compile the physics-bearing
    # child first, then bind the proposal to that exact prefix.
    preliminary = CandidateStatePackageV4(String(proposal_id), parent.mission_contract_ref,
        mechanism, parent.field_geometry_genome_ref, parent.realization_control_genome_ref,
        registry; proposal_lineage=parent.proposal_lineage)
    precompiled = compile_candidate(preliminary, registry;
        mission_payload=parent_entry.compiled.mission_payload,
        bounds_payload=parent_entry.compiled.bounds_payload,
        comparison_scope=parent_entry.compiled.minimality_scope.comparison_scope,
        scenario_scope=parent_entry.compiled.minimality_scope.scenario_scope)
    proposal = ProposalEnvelopeV4(String(proposal_id), string(precompiled.prefix_hash),
        (string(parent_entry.candidate_ref),), :deterministic_screen_coverage,
        (trace,), "0d-constraint-screen-coverage", (outcome=:unknown,),
        (kind=:not_a_physical_prediction,), 0.0,
        canonical_hash((rule="algebraic-generation-coverage-v1", edge_id=String(edge_id))),
        :g1_zero_dimensional_algebraic_constraint)
    child = CandidateStatePackageV4(String(proposal_id), parent.mission_contract_ref,
        mechanism, parent.field_geometry_genome_ref, parent.realization_control_genome_ref,
        registry; proposal_lineage=(parent.proposal_lineage..., proposal))
    child.canonical_hashes.mechanism_hash != parent.canonical_hashes.mechanism_hash &&
        child.canonical_hashes.field_geometry_hash == parent.canonical_hashes.field_geometry_hash &&
        child.canonical_hashes.realization_control_hash == parent.canonical_hashes.realization_control_hash ||
        throw(ArgumentError("generation edit did not change exactly G1"))
    compiled = compile_candidate(child, registry;
        mission_payload=parent_entry.compiled.mission_payload,
        bounds_payload=parent_entry.compiled.bounds_payload,
        comparison_scope=parent_entry.compiled.minimality_scope.comparison_scope,
        scenario_scope=parent_entry.compiled.minimality_scope.scenario_scope)
    compiled.prefix_hash == precompiled.prefix_hash &&
        proposal.candidate_or_prefix_ref == string(compiled.prefix_hash) ||
        throw(ArgumentError("proposal does not bind the child prefix"))
    compile_algebraic_residual_plan(compiled, registry).status == :ready ||
        throw(ArgumentError("edited child has no executable 0D algebraic plan"))
    (candidate=child, compiled=compiled, proposal=proposal)
end

"""Select the first not-yet-edited integer constraint after a valid screen.

This is novelty/coverage feedback, not scientific optimization. Exhaustion is
explicit rather than silently revisiting a previous edit.
"""
function next_algebraic_generation_edit(parent::CandidateStatePackageV4,
        parent_entry::CandidateQueueEntryV4, feedback::AlgebraicScopedResolutionV4,
        registry::GenomeContractRegistryV4; proposal_id::AbstractString,
        expected_scenario_hash::Digest256)
    _exact_generation_feedback(parent, parent_entry, feedback, registry, expected_scenario_hash)
    used = Set(String(trace.edge_id) for proposal in parent.proposal_lineage
        for trace in proposal.typed_edit_trace if trace isa NamedTuple &&
        :edit in keys(trace) && trace.edit == :replace_integer_ast_constant)
    graph = parent.mechanism_genome_ref.payload.operator_graph
    ids = sort([e.edge_id for e in graph.hyperedges if e isa AtomicMIMOHyperedgeV1 &&
        e.role == constraint && !(e.edge_id in used)])
    for id in ids
        edge, position = try _generation_constant_edge(parent, id) catch; continue end
        old = edge.program.nodes[position]::ASTConstantV1
        old.value < 10 || continue
        return algebraic_generation_edit(parent, parent_entry, feedback, registry,
            id, old.value + 1, proposal_id, expected_scenario_hash)
    end
    nothing
end
