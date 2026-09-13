"""Exact candidate-owned source Fourier-Zernike G2 binding, screen-only.

Include after the normalized-to-SI bridge and N2 source/reference modules in a
RuntimeV4 assembly. This adds no default-registry or provider authority.
"""
const _N2GC_REVISION = "runtime-v4-n2-source-candidate-geometry-binding-v1"
const _N2GC_GAPS = (
    "global_chart_orientation_and_nondegeneracy_not_proved",
    "existing_DESC_compatibility_proof_excludes_source_NFP19_L24_basis",
    "same_subject_equilibrium_provider_not_reexecuted",
    "independent_spatial_equilibrium_comparison_missing",
    "independent_physical_validation_missing")

struct N2SourceCandidateGeometryBindingV4
    candidate_hash::Digest256
    context_hash::Digest256
    physical_subject_hash::Digest256
    reference_binding_hash::Digest256
    source_program_hash::Digest256
    source_graph_binding_hash::Digest256
    root_bridge_hash::Digest256
    source_artifact_sha256::Digest256
    source_interior_subject_sha256::Digest256
    normalized_reference_subject_sha256::Digest256
    recoverable_gaps::Tuple{Vararg{String}}
    binding_hash::Digest256
end

function _n2gc_body(binding::N2SourceCandidateGeometryBindingV4)
    (revision=_N2GC_REVISION,
     candidate_hash=binding.candidate_hash,
     context_hash=binding.context_hash,
     physical_subject_hash=binding.physical_subject_hash,
     reference_binding_hash=binding.reference_binding_hash,
     source_program_hash=binding.source_program_hash,
     source_graph_binding_hash=binding.source_graph_binding_hash,
     root_bridge_hash=binding.root_bridge_hash,
     source_artifact_sha256=binding.source_artifact_sha256,
     source_interior_subject_sha256=binding.source_interior_subject_sha256,
     normalized_reference_subject_sha256=
        binding.normalized_reference_subject_sha256,
     source_representation_bound=true, normalized_SI_root_bridge_ready=true,
     recoverable_gaps=binding.recoverable_gaps,
     claim_ceiling=screen_only, geometry_proved=false,
     provider_selected=false, provider_executed=false,
     physical_validation=false, credible_device_count=0)
end
semantic_view(binding::N2SourceCandidateGeometryBindingV4) = _n2gc_body(binding)
function canonical_hash(binding::N2SourceCandidateGeometryBindingV4)
    binding.recoverable_gaps == _N2GC_GAPS ||
        throw(ArgumentError("source geometry candidate gaps changed"))
    expected = canonical_hash(_n2gc_body(binding))
    expected == binding.binding_hash ||
        throw(ArgumentError("source geometry candidate binding hash mismatch"))
    expected
end

function _n2gc_chart_exact(chart)
    all(bound -> bound.unit == UnitSignature() &&
        bound.interval.lower == 0//1 && bound.interval.upper == 1//1 &&
        !bound.interval.allow_equal, chart.chart_bounds) &&
        Tuple(axis.axis_position for axis in chart.periodic_axes) == (2, 3) &&
        all(axis -> axis.period.unit == UnitSignature() &&
            axis.period.value == 1//1, chart.periodic_axes)
end

"""Join the source spectrum, normalized reference and actual G2 candidate.

The source and reference results are reread and rehashed. A ready structural
bridge is required but is never interpreted as geometry proof.
"""
function bind_n2_source_candidate_geometry(context::ForwardChainContextV4,
        source_binding::N2SourceGeometryProgramRuntime.N2SourceGeometryBindingV4,
        reference_binding::N2ReferenceInputRuntime.N2ReferenceInputBindingV4,
        bridge::ThreeDNormalizedPhysicalRootBridgeResolutionV4,
        source_path::AbstractString, interior_result_path::AbstractString)
    validate_forward_chain_context(context)
    validate_three_d_normalized_physical_root_bridge(context, bridge)
    bridge.status === :bridge_ready ||
        throw(ArgumentError("source geometry candidate needs exact root bridge"))
    N2ReferenceInputRuntime.canonical_hash(reference_binding)
    reference_binding.context_hash == context.context_hash &&
        reference_binding.candidate_hash == context.candidate_hash &&
        reference_binding.source_artifact_sha256 ==
            source_binding.program.interior.source_artifact_sha256 &&
        reference_binding.source_artifact_path == String(source_path) ||
        throw(ArgumentError("reference/source binding is foreign to candidate"))
    fresh_reference = N2ReferenceInputRuntime.bind_n2_reference_input(
        context, only(_tdnprb_inventory(context)[1]), source_path,
        reference_binding.source_artifact_sha256,
        reference_binding.normalized_result_path,
        reference_binding.normalized_result_sha256;
        validator=validate_forward_chain_context)
    N2ReferenceInputRuntime.canonical_hash(fresh_reference) ==
        reference_binding.binding_hash &&
        N2ReferenceInputRuntime.semantic_view(fresh_reference) ==
            N2ReferenceInputRuntime.semantic_view(reference_binding) ||
        throw(ArgumentError("normalized reference binding is not reproducible"))
    fresh_program = N2SourceGeometryProgramRuntime.load_n2_source_geometry_program(
        source_path, interior_result_path,
        source_binding.program.interior.result_sha256,
        source_binding.program.support_scale)
    normalized_subject, normalized_subject_hash =
        N2ReferenceInputRuntime._n2r_load_normalized_result(
            reference_binding.normalized_result_path,
            reference_binding.normalized_result_sha256)
    normalized_subject_hash ==
        reference_binding.normalized_result_subject_sha256 &&
        normalized_subject.provenance.selected_equilibrium_index ==
            fresh_program.interior.selected_equilibrium_index &&
        normalized_subject.provenance.equilibrium_count == 4 &&
        normalized_subject.provenance.embedded_producer_version ==
            "0.17.1+38.g53ea59ef0.dirty" &&
        normalized_subject.provenance.distributed_in_release_tag == "v0.17.3" ||
        throw(ArgumentError("normalized boundary and source interior select different members"))
    canonical_hash(fresh_program) == canonical_hash(source_binding.program) &&
        fresh_program.interior.radial_modes == source_binding.program.interior.radial_modes &&
        fresh_program.interior.vertical_modes == source_binding.program.interior.vertical_modes ||
        throw(ArgumentError("source Fourier-Zernike program is not reproducible"))
    expected = N2SourceGeometryProgramRuntime.n2_source_geometry_typed_binding(
        fresh_program, source_binding.coordinate_site_ref,
        source_binding.metric_site_ref)
    canonical_hash(source_binding) == canonical_hash(expected) &&
        semantic_view(source_binding) == semantic_view(expected) ||
        throw(ArgumentError("source geometry AST/manifest binding is foreign"))
    declarations, _ = _tdnprb_inventory(context)
    declaration = only(declarations)
    reference_binding.declaration_hash == canonical_hash(declaration) ||
        throw(ArgumentError("source reference declaration differs"))
    coordinate = declaration.coordinate_metric
    coordinate.coordinate_map_site_ref == source_binding.coordinate_site_ref &&
        coordinate.metric_site_ref == source_binding.metric_site_ref ||
        throw(ArgumentError("source geometry sites differ from declaration"))
    support, chart = _tdnprb_support_chart(context.candidate, coordinate)
    _n2gc_chart_exact(chart) &&
        support.resolution_independent_scale == source_binding.program.support_scale ||
        throw(ArgumentError("source geometry chart or SI scale differs"))
    graph = forward_graph_binding(context, :field_geometry)
    _, coordinate_edge = _tdnprb_edge(graph, source_binding.coordinate_site_ref)
    _, metric_edge = _tdnprb_edge(graph, source_binding.metric_site_ref)
    canonical_hash(coordinate_edge.program) ==
        canonical_hash(source_binding.coordinate_program) &&
        canonical_hash(metric_edge.program) ==
        canonical_hash(source_binding.metric_program) &&
        semantic_view(coordinate_edge.program) ==
        semantic_view(source_binding.coordinate_program) &&
        semantic_view(metric_edge.program) ==
        semantic_view(source_binding.metric_program) &&
        canonical_hash(coordinate_edge.registry) ==
        canonical_hash(source_binding.registry) &&
        canonical_hash(metric_edge.registry) ==
        canonical_hash(source_binding.registry) ||
        throw(ArgumentError("candidate G2 source operator program differs"))
    interior = source_binding.program.interior
    binding = N2SourceCandidateGeometryBindingV4(
        context.candidate_hash, context.context_hash,
        context.subject.physical_subject_hash, reference_binding.binding_hash,
        canonical_hash(source_binding.program), graph.binding_hash,
        bridge.resolution_hash, interior.source_artifact_sha256,
        interior.subject_sha256,
        reference_binding.normalized_result_subject_sha256,
        _N2GC_GAPS, Digest256(repeat("0", 64)))
    body_hash = canonical_hash(_n2gc_body(binding))
    result = N2SourceCandidateGeometryBindingV4(
        binding.candidate_hash, binding.context_hash,
        binding.physical_subject_hash, binding.reference_binding_hash,
        binding.source_program_hash, binding.source_graph_binding_hash,
        binding.root_bridge_hash, binding.source_artifact_sha256,
        binding.source_interior_subject_sha256,
        binding.normalized_reference_subject_sha256,
        binding.recoverable_gaps, body_hash)
    canonical_hash(result)
    result
end

"""Candidate-bound local geometry evaluation, never a solver/evidence producer."""
function evaluate_n2_source_candidate_geometry(
        binding::N2SourceCandidateGeometryBindingV4,
        context::ForwardChainContextV4,
        source_binding::N2SourceGeometryProgramRuntime.N2SourceGeometryBindingV4,
        reference_binding::N2ReferenceInputRuntime.N2ReferenceInputBindingV4,
        bridge::ThreeDNormalizedPhysicalRootBridgeResolutionV4,
        source_path::AbstractString, interior_result_path::AbstractString,
        input::N2SourceGeometryProgramRuntime.N2SourceUnitTurnChartV4)
    canonical_hash(binding)
    fresh = bind_n2_source_candidate_geometry(context, source_binding,
        reference_binding, bridge, source_path, interior_result_path)
    canonical_hash(fresh) == binding.binding_hash &&
        semantic_view(fresh) == semantic_view(binding) ||
        throw(ArgumentError("source geometry evaluation binding is not reproducible"))
    value = N2SourceGeometryProgramRuntime.evaluate_n2_source_geometry(
        source_binding, input)
    (candidate_hash=context.candidate_hash,
     physical_subject_hash=context.subject.physical_subject_hash,
     candidate_geometry_binding_hash=binding.binding_hash,
     source_geometry=value,
     claim_ceiling=screen_only, geometry_proved=false,
     provider_selected=false, provider_executed=false,
     physical_validation=false, credible_device_count=0)
end
