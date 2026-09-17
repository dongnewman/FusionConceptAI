using Test
using FusionConceptAI

# Declaration fixture only; this loads no DESC provider process.
include(joinpath(@__DIR__, "..", "examples", "runtime_v4_spatial_candidate.jl"))
const SGE = SCV
const ThreeDPhysicalProviderInputV4 = SGE.ThreeDPhysicalProviderInputV4
const SGE_EDITED = SGE.build_spatial_geometry_edit_v4(spatial_context)

@testset "lawful G2 geometry edit child" begin
    edited = SGE_EDITED
    child = edited.context
    old = only(filter(x -> x isa ThreeDPhysicalProviderInputV4,
        spatial_context.candidate.field_geometry_genome_ref.fields))
    new = edited.declaration
    @test new.fourier_boundary.field_periods == 5
    @test new.fourier_boundary.stellarator_symmetric
    @test only(filter(c -> (c.poloidal_mode, c.toroidal_mode) == (1, 0),
        new.fourier_boundary.radial_coefficients)).coefficient_m == 0.42
    @test new.fourier_boundary.radial_coefficients != old.fourier_boundary.radial_coefficients
    @test canonical_hash(new) != canonical_hash(old)
    @test edited.changes.old_program_hash != edited.changes.new_program_hash
    @test child.candidate_hash != spatial_context.candidate_hash
    @test last(child.candidate.proposal_lineage).search_channel ===
        :deterministic_g2_screen_coverage
    @test child.candidate.proposal_lineage[1:end-1] ==
        spatial_context.candidate.proposal_lineage
    @test edited.provenance.originality === :not_claimed
    @test child.subject.physical_subject_hash != spatial_context.subject.physical_subject_hash
    @test child.bounds_payload.declaration_hash == canonical_hash(new)
    @test child.subject.bindings[1].declaration_hash == canonical_hash(new)
    @test SGE.validate_forward_chain_context(child) isa Digest256
    @test SGE.validate_spatial_candidate_v4(child)
    @test child.candidate.mechanism_genome_ref === spatial_context.candidate.mechanism_genome_ref
    @test child.candidate.realization_control_genome_ref === spatial_context.candidate.realization_control_genome_ref
    @test new.profiles_flux == old.profiles_flux
    @test new.coordinate_metric.coordinate_map_root_identity_hash !=
        old.coordinate_metric.coordinate_map_root_identity_hash
    @test new.coordinate_metric.metric_root_identity_hash !=
        old.coordinate_metric.metric_root_identity_hash
    @test canonical_hash(child.candidate.mechanism_genome_ref) ==
        canonical_hash(spatial_context.candidate.mechanism_genome_ref)
    @test canonical_hash(child.candidate.realization_control_genome_ref) ==
        canonical_hash(spatial_context.candidate.realization_control_genome_ref)
end

@testset "geometry edit fail-closed controls" begin
    @test_throws ArgumentError SGE.build_spatial_geometry_edit_v4(spatial_context;
        coefficient_m=NaN)
    @test_throws ArgumentError SGE.build_spatial_geometry_edit_v4(spatial_context;
        coefficient_m=0.0)
    @test_throws ArgumentError SGE.build_spatial_geometry_edit_v4(spatial_context;
        coefficient_m=only(filter(c -> (c.poloidal_mode, c.toroidal_mode) == (1, 0),
            only(filter(x -> x isa ThreeDPhysicalProviderInputV4,
            spatial_context.candidate.field_geometry_genome_ref.fields)).fourier_boundary.radial_coefficients)).coefficient_m)
    edited43 = SGE.build_spatial_geometry_edit_v4(spatial_context; coefficient_m=0.43)
    @test edited43.context.candidate.identity_ref !=
        SGE_EDITED.context.candidate.identity_ref
    edited = SGE_EDITED
    old = only(filter(x -> x isa ThreeDPhysicalProviderInputV4,
        spatial_context.candidate.field_geometry_genome_ref.fields))
    old_graph = spatial_context.candidate.field_geometry_genome_ref.graph
    old_payload = SGE._sge_program_payload(old_graph,
        old.coordinate_metric.coordinate_map_site_ref)
    support = only(filter(x -> x isa SpatialSupportGeneV1 &&
        x.support_ref == old.coordinate_metric.support_ref,
        spatial_context.candidate.field_geometry_genome_ref.fields))
    @test_throws ArgumentError SGE._dgpi_program_from_ast_payload(
        merge(old_payload, (boundary_hash=canonical_hash(edited.declaration.fourier_boundary),)),
        old.fourier_boundary, support.resolution_independent_scale)
    @test_throws ArgumentError SGE.validate_desc_geometry_compatibility(
        edited.context, spatial_bridge, spatial_geometry, spatial_proof)
    @test_throws ArgumentError SGE.build_spatial_geometry_edit_v4(edited.context;
        coefficient_m=0.42)
end
