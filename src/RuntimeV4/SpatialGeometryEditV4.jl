"""Lawful, candidate-bound G2 Fourier geometry edit child.

This is deliberately an additive edit: it recompiles the current G2 graph,
rebinds both typed AST roots, and creates a fresh subject/context.  It does
not call `build_spatial_candidate_v4`, whose inherited-input identity check is
correct for the original spatial fixture.
"""

using FusionConceptAI
import FusionConceptAI: canonical_hash, semantic_view

const _SGE_REVISION = "runtime-v4-spatial-geometry-edit-v1"

function _sge_boundary_edit(boundary::ThreeDFourierBoundaryV4, coefficient_m)
    coefficient_m isa Real && !(coefficient_m isa Bool) ||
        throw(ArgumentError("geometry edit coefficient must be numeric"))
    isfinite(Float64(coefficient_m)) || throw(ArgumentError("geometry edit coefficient must be finite"))
    changed = false
    radial = Tuple(begin
        if c.poloidal_mode == 1 && c.toroidal_mode == 0
            Float64(c.coefficient_m) == Float64(coefficient_m) &&
                throw(ArgumentError("geometry edit is a no-op"))
            changed = true
            ThreeDFourierCoefficientV4(1, 0, coefficient_m)
        else
            c
        end
    end for c in boundary.radial_coefficients)
    changed || throw(ArgumentError("current G2 boundary has no R(1,0) mode"))
    ThreeDFourierBoundaryV4(boundary.boundary_id, boundary.field_periods,
        boundary.stellarator_symmetric, radial, boundary.vertical_coefficients,
        boundary.length_unit)
end

function _sge_replace_geometry_edges(graph::TypedOperatorHypergraphV1,
        binding::DESCGeometryProgramBindingV4)
    regs = Tuple(e.registry for e in graph.hyperedges
        if e isa AtomicMIMOHyperedgeV1)
    isempty(regs) && throw(ArgumentError("current G2 graph has no operator registry"))
    largest = maximum(length(r.operators) for r in regs)
    complete = Tuple(r for r in regs if length(r.operators) == largest)
    all(canonical_hash(r) == canonical_hash(first(complete)) for r in complete) ||
        throw(ArgumentError("current G2 graph has conflicting complete registries"))
    edges = Tuple(begin
        if e isa AtomicMIMOHyperedgeV1 && e.edge_id == binding.coordinate_site_ref.value
            binding.coordinate_edge
        elseif e isa AtomicMIMOHyperedgeV1 && e.edge_id == binding.metric_site_ref.value
            binding.metric_edge
        else
            e
        end
    end for e in graph.hyperedges)
    count(e -> e.edge_id == binding.coordinate_site_ref.value, edges) == 1 ||
        throw(ArgumentError("current G2 graph lacks unique coordinate edge"))
    count(e -> e.edge_id == binding.metric_site_ref.value, edges) == 1 ||
        throw(ArgumentError("current G2 graph lacks unique metric edge"))
    # The graph constructor verifies every retained and rebuilt AST manifest
    # against the most complete candidate-owned registry, independent of order.
    full_registry = first(complete)
    TypedOperatorHypergraphV1(graph.nodes, edges; registry=full_registry)
end

function _sge_program_payload(graph, site::FieldOperatorSiteRefV1)
    matches = Tuple(e for e in graph.hyperedges if e isa AtomicMIMOHyperedgeV1 &&
        e.edge_id == site.value)
    length(matches) == 1 || throw(ArgumentError("geometry AST edge is absent or ambiguous"))
    e = only(matches)
    length(e.program.nodes) >= 2 && e.program.nodes[2] isa ASTConstantV1 ||
        throw(ArgumentError("geometry AST lacks sealed payload"))
    p = e.program.nodes[2].value
    p isa NamedTuple || throw(ArgumentError("geometry AST payload is not canonical"))
    p
end

"""Build the G2-only 0.42-m child from an existing spatial context.

The returned named tuple mirrors `build_spatial_candidate_v4`; all mission,
scenario, comparison, G1 and G3 declarations are retained, while G2 and its
dependent compiled/subject/context identities are fresh.
"""
function build_spatial_geometry_edit_v4(parent_context::ForwardChainContextV4;
        coefficient_m=0.42)
    validate_forward_chain_context(parent_context)
    validate_spatial_candidate_v4(parent_context)
    parent = parent_context.candidate
    old_graph = parent.field_geometry_genome_ref.graph
    old_inputs = Tuple(x for x in parent.field_geometry_genome_ref.fields
        if typeof(x) === ThreeDPhysicalProviderInputV4)
    length(old_inputs) == 1 || throw(ArgumentError("spatial G2 input is absent or ambiguous"))
    old_input = only(old_inputs)
    old_cm = old_input.coordinate_metric
    old_boundary = old_input.fourier_boundary
    new_boundary = _sge_boundary_edit(old_boundary, coefficient_m)
    payload_r = _sge_program_payload(old_graph, old_cm.coordinate_map_site_ref)
    payload_m = _sge_program_payload(old_graph, old_cm.metric_site_ref)
    supports = Tuple(x for x in parent.field_geometry_genome_ref.fields
        if typeof(x) === SpatialSupportGeneV1 && x.support_ref == old_cm.support_ref)
    length(supports) == 1 || throw(ArgumentError("geometry support is absent or ambiguous"))
    scale = only(supports).resolution_independent_scale
    old_program_r = _dgpi_program_from_ast_payload(payload_r, old_boundary, scale)
    old_program_m = _dgpi_program_from_ast_payload(payload_m, old_boundary, scale)
    canonical_hash(old_program_r) == canonical_hash(old_program_m) ||
        throw(ArgumentError("coordinate/metric AST programs disagree"))
    payload_r.radial_powers == payload_m.radial_powers &&
        payload_r.vertical_powers == payload_m.vertical_powers ||
        throw(ArgumentError("coordinate/metric AST radial powers disagree"))
    program = DESCFourierGeometryProgramV4(new_boundary, scale,
        payload_r.radial_powers, payload_r.vertical_powers)
    typed = desc_geometry_typed_binding(program, old_cm.coordinate_map_site_ref,
        old_cm.metric_site_ref)
    graph = _sge_replace_geometry_edges(old_graph, typed)
    components = _forward_graph_components(:field_geometry, graph)
    new_cm = ThreeDCoordinateMetricV4(old_cm.support_ref, old_cm.chart_ref,
        old_cm.coordinate_map_site_ref, old_cm.metric_site_ref,
        components.ast_root_identity_hashes[2],
        components.ast_root_identity_hashes[4], old_cm.coordinate_type,
        old_cm.metric_type, old_cm.chart_bounds)
    new_input = ThreeDPhysicalProviderInputV4(old_input.declaration_id,
        new_boundary, new_cm, old_input.profiles_flux)
    fields = Tuple(x === old_input ? new_input : x
        for x in parent.field_geometry_genome_ref.fields)
    field = FieldGeometryGenomeV4(parent.field_geometry_genome_ref.seed + UInt64(1),
        parent.field_geometry_genome_ref.contract_ref, graph, fields)
    changes = (kind=:g2_geometry_edit, revision=_SGE_REVISION,
        parent_candidate_hash=parent_context.candidate_hash,
        old_declaration_hash=canonical_hash(old_input),
        new_declaration_hash=canonical_hash(new_input),
        old_boundary_hash=canonical_hash(old_boundary),
        new_boundary_hash=canonical_hash(new_boundary),
        old_program_hash=canonical_hash(old_program_r),
        new_program_hash=canonical_hash(program),
        edited_mode=(poloidal_mode=1, toroidal_mode=0),
        coefficient_m=Float64(coefficient_m), claim_ceiling=screen_only)
    provenance = (revision=_SGE_REVISION, parent_context_hash=parent_context.context_hash,
        geometry="Candidate-bound Fourier geometry edit R(1,0)=$(Float64(coefficient_m)) m",
        geometry_snapshot=(radial_coefficients=new_boundary.radial_coefficients,
            vertical_coefficients=new_boundary.vertical_coefficients,
            field_periods=new_boundary.field_periods,
            stellarator_symmetry=new_boundary.stellarator_symmetric,
            profiles_flux_hash=canonical_hash(old_input.profiles_flux),
            radial_powers=payload_r.radial_powers,
            vertical_powers=payload_r.vertical_powers),
        originality=:not_claimed, authority=:screen_only)
    child_id = string(parent.identity_ref, "-g2-geometry-edit-", canonical_hash(new_boundary))
    proposal = ProposalEnvelopeV4(child_id, child_id, (parent.identity_ref,),
        :deterministic_g2_screen_coverage, (changes,), "g2_geometry_edit",
        (outcome=:unknown,), (kind=:microperturbation_no_originality_claim,), 0.0,
        canonical_hash(provenance), :coupled_execution)
    candidate = CandidateStatePackageV4(child_id, parent.mission_contract_ref,
        parent.mechanism_genome_ref, field, parent.realization_control_genome_ref,
        parent_context.registry;
        proposal_lineage=(parent.proposal_lineage..., proposal), claim_ceiling=none)
    old_bounds = parent_context.bounds_payload
    old_bounds isa NamedTuple || throw(ArgumentError("spatial bounds payload must be NamedTuple"))
    bounds = merge(old_bounds, (declaration_hash=canonical_hash(new_input),))
    mission = parent_context.mission_payload
    comparison = parent_context.comparison_scope
    scenarios = parent_context.scenario_scope
    scenario = parent_context.scenario
    compiled = compile_candidate(candidate, parent_context.registry;
        mission_payload=mission, bounds_payload=bounds,
        comparison_scope=comparison, scenario_scope=scenarios)
    binding = make_three_d_physical_provider_input_binding(compiled,
        parent_context.registry, mission, bounds, comparison, scenarios,
        scenario, new_input)
    subject = ExecutablePhysicalSubjectV4(compiled.prefix_hash,
        candidate.canonical_hashes.genome_bundle_hash,
        compiled.minimality_scope.mission_hash,
        compiled.minimality_scope.bounds_hash, (binding,), (scenario,),
        (revision=_SGE_REVISION, changes=changes, provenance=provenance),
        derive_capability_obligations(compiled))
    context = make_forward_chain_context(candidate, compiled,
        parent_context.registry, mission, bounds, comparison, scenarios,
        subject, scenario)
    validate_forward_chain_context(context)
    validate_spatial_candidate_v4(context)
    (context=context, parent_hash=parent_context.candidate_hash,
        changes=changes, provenance=provenance, declaration=new_input)
end
