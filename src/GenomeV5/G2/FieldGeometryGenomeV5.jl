"""Candidate-bound G2 V5 geometry Genome and fail-closed admission."""

struct G2VersionAxesV2
    payload_schema_version::QualifiedRefV1
    canonicalization_profile_version::QualifiedRefV1
    applicability_profile_version::QualifiedRefV1
    evidence_receipt_version::QualifiedRefV1
    function G2VersionAxesV2(payload_schema_version::Any,
                             canonicalization_profile_version::Any,
                             applicability_profile_version::Any,
                             evidence_receipt_version::Any)
        refs = (payload_schema_version, canonicalization_profile_version,
                applicability_profile_version, evidence_receipt_version)
        all(x -> x isa QualifiedRefV1 && x.version == "v5", refs) ||
            throw(ArgumentError("G2 V5 version axes require QualifiedRefV1 version v5"))
        new(refs...)
    end
end

semantic_view(x::G2VersionAxesV2) =
    (payload_schema_version=x.payload_schema_version,
     canonicalization_profile_version=x.canonicalization_profile_version,
     applicability_profile_version=x.applicability_profile_version,
     evidence_receipt_version=x.evidence_receipt_version)
canonical_json(x::G2VersionAxesV2) = canonical_json(semantic_view(x))

struct G2AdmissionResultV2
    structural_status::Symbol
    geometry_status::Symbol
    mesh_status::Symbol
    physical_status::Symbol
    provider_match::Symbol
    resolution::Symbol
    errors::Tuple{Vararg{String}}
    structural_errors::Tuple{Vararg{String}}
    geometry_errors::Tuple{Vararg{String}}
    gaps::Tuple{Vararg{String}}
    plan_hash::Digest256
end

semantic_view(x::G2AdmissionResultV2) =
    (structural_status=x.structural_status, geometry_status=x.geometry_status,
     mesh_status=x.mesh_status, physical_status=x.physical_status,
     provider_match=x.provider_match, resolution=x.resolution, errors=x.errors,
     structural_errors=x.structural_errors, geometry_errors=x.geometry_errors,
     gaps=x.gaps, plan_hash=x.plan_hash)
canonical_json(x::G2AdmissionResultV2) = canonical_json(semantic_view(x))

function _g2v5_find_region(contract::RegionInterfaceContractV2, id::String)
    found = Tuple(r for r in contract.regions if r.region_id == id)
    length(found) == 1 ? first(found) : nothing
end

function _g2v5_positive_overlap(left::G2RegionV2, right::G2RegionV2, axis::Int)
    all(min(left.upper[i], right.upper[i]) > max(left.lower[i], right.lower[i]) for i in 1:3 if i != axis)
end

function _g2v5_region_volume_overlap(left::G2RegionV2, right::G2RegionV2)
    all(min(left.upper[i], right.upper[i]) > max(left.lower[i], right.lower[i]) for i in 1:3)
end

function _g2v5_face_axes(face::Symbol)
    face === :x_min && return (1, false, (2, 3))
    face === :x_max && return (1, true, (2, 3))
    face === :y_min && return (2, false, (1, 3))
    face === :y_max && return (2, true, (1, 3))
    face === :z_min && return (3, false, (1, 2))
    face === :z_max && return (3, true, (1, 2))
    throw(ArgumentError("unsupported G2 exterior face"))
end

function _g2v5_check_exterior_patches!(structural_errors::Vector{String},
                                       geometry_errors::Vector{String},
                                       contract::RegionInterfaceContractV2,
                                       plan::FieldSpacePlanV2,
                                       required_faces::Set{Symbol})
    region_ids = Set(r.region_id for r in contract.regions)
    length(unique(plan.exterior.boundary_region_ids)) == length(plan.exterior.boundary_region_ids) ||
        push!(structural_errors, "exterior_region_owner_duplicate")
    Tuple(plan.exterior.boundary_region_ids) == Tuple(r.region_id for r in contract.regions) ||
        push!(structural_errors, "exterior_region_ownership_mismatch")

    for patch in plan.exterior.boundary_patches
        patch.region_id in region_ids ||
            push!(structural_errors, "exterior_patch_region_missing:" * patch.region_id)
    end

    for face in required_faces
        axis, upper_side, tangential_axes = _g2v5_face_axes(face)
        patches = [p for p in plan.exterior.boundary_patches if p.face === face]
        isempty(patches) && (push!(geometry_errors, "exterior_face_patch_missing:" * String(face)); continue)
        global_lower = ntuple(k -> minimum(r.lower[tangential_axes[k]] for r in contract.regions), 2)
        global_upper = ntuple(k -> maximum(r.upper[tangential_axes[k]] for r in contract.regions), 2)
        valid_patches = G2BoundaryFacePatchV2[]
        for patch in patches
            region = _g2v5_find_region(contract, patch.region_id)
            region === nothing && continue
            boundary_coordinate = upper_side ? region.upper[axis] : region.lower[axis]
            expected_coordinate = upper_side ?
                maximum(r.upper[axis] for r in contract.regions) :
                minimum(r.lower[axis] for r in contract.regions)
            boundary_coordinate == expected_coordinate ||
                push!(geometry_errors, "exterior_face_patch_not_on_boundary:" * String(face) * ":" * patch.region_id)
            in_region = all(region.lower[tangential_axes[k]] <= patch.lower[k] &&
                            patch.upper[k] <= region.upper[tangential_axes[k]] for k in 1:2)
            in_global = all(global_lower[k] <= patch.lower[k] &&
                            patch.upper[k] <= global_upper[k] for k in 1:2)
            in_region && in_global && boundary_coordinate == expected_coordinate &&
                push!(valid_patches, patch)
            in_region || push!(geometry_errors, "exterior_face_patch_outside_region:" * String(face) * ":" * patch.region_id)
        end
        coordinates_a = sort!(unique(vcat([global_lower[1], global_upper[1]],
            [p.lower[1] for p in valid_patches], [p.upper[1] for p in valid_patches])))
        coordinates_b = sort!(unique(vcat([global_lower[2], global_upper[2]],
            [p.lower[2] for p in valid_patches], [p.upper[2] for p in valid_patches])))
        for i in 1:(length(coordinates_a) - 1), j in 1:(length(coordinates_b) - 1)
            a0, a1 = coordinates_a[i], coordinates_a[i + 1]
            b0, b1 = coordinates_b[j], coordinates_b[j + 1]
            covered = count(p -> p.lower[1] <= a0 && a1 <= p.upper[1] &&
                                  p.lower[2] <= b0 && b1 <= p.upper[2], valid_patches)
            covered == 1 || push!(geometry_errors,
                covered == 0 ? "exterior_face_patch_gap:" * String(face) :
                "exterior_face_patch_overlap:" * String(face))
        end
    end
end

function _g2v5_admission_errors(contract::RegionInterfaceContractV2,
                                plan::FieldSpacePlanV2,
                                profile::SpatialGrammarProfileV2)
    structural_errors = String[]
    geometry_errors = String[]
    gaps = String[]
    profile.ambient_dimension == 3 || push!(structural_errors, "ambient_dimension_not_3")
    :cartesian in profile.supported_topologies || push!(structural_errors, "cartesian_topology_not_supported")
    :linear in profile.mesh_families || push!(structural_errors, "linear_mesh_family_not_supported")

    region_ids = Tuple(r.region_id for r in contract.regions)
    Tuple(plan.mesh.region_ids) == region_ids ||
        Set(plan.mesh.region_ids) == Set(region_ids) || push!(structural_errors, "mesh_region_ownership_mismatch")
    Tuple(plan.exterior.boundary_region_ids) == region_ids ||
        push!(structural_errors, "exterior_region_ownership_mismatch")
    length(unique(plan.exterior.boundary_region_ids)) == length(plan.exterior.boundary_region_ids) ||
        push!(structural_errors, "exterior_region_owner_duplicate")
    length(contract.interfaces) == length(contract.regions) - 1 ||
        push!(structural_errors, isempty(contract.interfaces) ? "missing_interface" : "interface_count_mismatch")

    for i in 1:length(contract.regions), j in (i + 1):length(contract.regions)
        _g2v5_region_volume_overlap(contract.regions[i], contract.regions[j]) &&
            push!(geometry_errors, "region_volume_overlap:" * contract.regions[i].region_id * ":" * contract.regions[j].region_id)
    end

    interface_keys = Set{Any}()
    interface_ref_ids = Set{String}()

    for region in contract.regions
        region.chart_ref == plan.chart.chart_ref ||
            push!(structural_errors, "region_chart_ref_mismatch:" * region.region_id)
        region.embedding_ref == plan.embedding.embedding_ref ||
            push!(structural_errors, "region_embedding_ref_mismatch:" * region.region_id)
        region.field_space_ref == plan.field_space.field_space_ref ||
            push!(structural_errors, "region_field_space_ref_mismatch:" * region.region_id)
    end

    for interface in contract.interfaces
        interface.interface_ref.id in interface_ref_ids &&
            push!(structural_errors, "duplicate_interface_ref:" * interface.interface_ref.id)
        push!(interface_ref_ids, interface.interface_ref.id)
        interface_key = (interface.left_region_id, interface.right_region_id,
                         interface.axis, interface.coordinate)
        interface_key in interface_keys &&
            push!(geometry_errors, "duplicate_interface:" * interface.interface_ref.id)
        push!(interface_keys, interface_key)
        left = _g2v5_find_region(contract, interface.left_region_id)
        right = _g2v5_find_region(contract, interface.right_region_id)
        left === nothing && (push!(structural_errors, "interface_left_region_missing:" * interface.interface_ref.id); continue)
        right === nothing && (push!(structural_errors, "interface_right_region_missing:" * interface.interface_ref.id); continue)
        axis = Int(interface.axis)
        left.upper[axis] == interface.coordinate && right.lower[axis] == interface.coordinate ||
            push!(geometry_errors, "interface_faces_do_not_coincide:" * interface.interface_ref.id)
        _g2v5_positive_overlap(left, right, axis) ||
            push!(geometry_errors, "interface_tangential_overlap_missing:" * interface.interface_ref.id)
        all(left.lower[i] == right.lower[i] && left.upper[i] == right.upper[i] for i in 1:3 if i != axis) ||
            push!(geometry_errors, "interface_tangential_coverage_incomplete:" * interface.interface_ref.id)
        interface.normal == 1 || push!(geometry_errors, "interface_orientation_mismatch:" * interface.interface_ref.id)
        interface.continuity == :trace_flux ||
            push!(geometry_errors, "interface_continuity_unsupported:" * interface.interface_ref.id)
        interface.transfer_kind == :conservative ||
            push!(geometry_errors, "interface_transfer_not_conservative:" * interface.interface_ref.id)
    end

    required_faces = Set((:x_min, :x_max, :y_min, :y_max, :z_min, :z_max))
    Set(plan.exterior.boundary_faces) == required_faces ||
        push!(geometry_errors, "exterior_boundary_not_closed")
    plan.exterior.boundary_condition == :none_declared &&
        push!(geometry_errors, "exterior_boundary_condition_missing")
    _g2v5_check_exterior_patches!(structural_errors, geometry_errors, contract, plan, required_faces)
    for axis in 1:3
        lower = minimum(r.lower[axis] for r in contract.regions)
        upper = maximum(r.upper[axis] for r in contract.regions)
        any(r.lower[axis] == lower for r in contract.regions) ||
            push!(geometry_errors, "exterior_min_face_missing:$(axis)")
        any(r.upper[axis] == upper for r in contract.regions) ||
            push!(geometry_errors, "exterior_max_face_missing:$(axis)")
    end

    plan.exterior.provider_match != :unique_match &&
        push!(gaps, "exterior_provider_match=" * String(plan.exterior.provider_match))
    profile.provider_match != :unique_match &&
        push!(gaps, "geometry_provider_match=" * String(profile.provider_match))
    unique!(structural_errors)
    unique!(geometry_errors)
    unique!(gaps)
    structural_errors, geometry_errors, gaps
end

function g2_admission(contract::RegionInterfaceContractV2,
                      plan::FieldSpacePlanV2,
                      profile::SpatialGrammarProfileV2)::G2AdmissionResultV2
    structural_errors, geometry_errors, gaps = _g2v5_admission_errors(contract, plan, profile)
    errors = vcat(structural_errors, geometry_errors)
    structural = isempty(structural_errors) ? :valid : :fail_closed
    geometry = isempty(geometry_errors) ? :valid : :fail_closed
    provider_match = profile.provider_match
    resolution = isempty(errors) && provider_match == :unique_match && isempty(gaps) ?
        :resolved : isempty(errors) ? :terminal_deferred : :fail_closed
    G2AdmissionResultV2(structural, geometry, :not_executed, :not_executed,
                        provider_match, resolution, Tuple(errors),
                        Tuple(structural_errors), Tuple(geometry_errors), Tuple(gaps),
                        canonical_hash((contract=contract, plan=plan)))
end

struct FieldGeometryGenomeV5
    contract_ref::GenomeContractRef
    region_interface::RegionInterfaceContractV2
    plan::FieldSpacePlanV2
    grammar_profile::SpatialGrammarProfileV2
    version_axes::G2VersionAxesV2
    admission::G2AdmissionResultV2
    candidate_hash::Digest256
    function FieldGeometryGenomeV5(contract_ref::Any,
                                   region_interface::Any,
                                   plan::Any,
                                   grammar_profile::Any,
                                   version_axes::Any)
        contract_ref isa GenomeContractRef ||
            throw(ArgumentError("G2 V5 contract_ref must be GenomeContractRef"))
        contract_ref.version == "v5" ||
            throw(ArgumentError("G2 V5 contract_ref must use version v5"))
        region_interface isa RegionInterfaceContractV2 ||
            throw(ArgumentError("region_interface must be RegionInterfaceContractV2"))
        plan isa FieldSpacePlanV2 || throw(ArgumentError("plan must be FieldSpacePlanV2"))
        grammar_profile isa SpatialGrammarProfileV2 ||
            throw(ArgumentError("grammar_profile must be SpatialGrammarProfileV2"))
        version_axes isa G2VersionAxesV2 ||
            throw(ArgumentError("G2 V5 requires four explicit version axes"))
        contract_ref.schema_hash == g2_schema_hash() ||
            throw(ArgumentError("G2 external schema_hash does not match controlled schema descriptor"))
        contract_ref.canonicalization_hash == g2_canonicalization_hash(grammar_profile) ||
            throw(ArgumentError("G2 external canonicalization_hash does not match controlled canonicalization descriptor"))
        contract_ref.compatibility_profile == g2_compatibility_profile_token(grammar_profile) ||
            throw(ArgumentError("G2 external compatibility_profile does not match controlled profile hash"))
        version_axes.payload_schema_version.id == "fusion.g2.payload-schema" ||
            throw(ArgumentError("G2 payload schema axis is bound to the wrong ref domain"))
        expected_canonicalization_axis = _g2v5_source_order_profile(grammar_profile) ?
            G2_SOURCE_ORDER_CANONICALIZATION_AXIS_REF_ID : "fusion.g2.canonicalization"
        version_axes.canonicalization_profile_version.id == expected_canonicalization_axis ||
            throw(ArgumentError("G2 canonicalization axis is bound to the wrong ref domain"))
        version_axes.applicability_profile_version.id == "fusion.g2.applicability" ||
            throw(ArgumentError("G2 applicability axis is bound to the wrong ref domain"))
        version_axes.evidence_receipt_version.id == "fusion.g2.receipt" ||
            throw(ArgumentError("G2 evidence axis is bound to the wrong ref domain"))
        if _g2v5_source_order_profile(grammar_profile)
            contract_ref.uri == "fusionconceptai://GenomeV5/G2/metric-boundary-source-projection/v5" ||
                throw(ArgumentError("source-order canonicalization is reserved for the source-backed G2 projection"))
            region_interface, plan = _g2v5_source_order_normalize(region_interface, plan)
        end
        admission = g2_admission(region_interface, plan, grammar_profile)
        candidate_hash = canonical_hash((contract_ref=contract_ref,
            region_interface=region_interface, plan=plan,
            grammar_profile=grammar_profile, version_axes=version_axes,
            admission=admission))
        new(contract_ref, region_interface, plan, grammar_profile, version_axes,
            admission, candidate_hash)
    end
end

function FieldGeometryGenomeV5(old::FieldGeometryGenomeV4)
    throw(ArgumentError("V4 Genome is read-only and requires an explicit migration receipt; it is not reinterpreted as V5"))
end

semantic_view(x::FieldGeometryGenomeV5) =
    (contract_ref=x.contract_ref, region_interface=x.region_interface, plan=x.plan,
     grammar_profile=x.grammar_profile, version_axes=x.version_axes,
     admission=x.admission, candidate_hash=x.candidate_hash)
canonical_json(x::FieldGeometryGenomeV5) = canonical_json(semantic_view(x))
g2_genome_hash(x::FieldGeometryGenomeV5)::Digest256 = x.candidate_hash
g2_provider_resolution(x::FieldGeometryGenomeV5) = x.admission.resolution
g2_plan_hash(x::FieldGeometryGenomeV5)::Digest256 = x.admission.plan_hash

function _g2v5_source_order_profile(profile::SpatialGrammarProfileV2)
    profile.canonicalization_profile_ref.id ==
        G2_SOURCE_ORDER_CANONICALIZATION_PROFILE_REF_ID
end

function _g2v5_source_order_normalize(region_interface::RegionInterfaceContractV2,
                                      plan::FieldSpacePlanV2)
    regions = Tuple(sort!(collect(region_interface.regions);
        by=region -> region.region_id))
    contract = RegionInterfaceContractV2(regions, region_interface.interfaces)
    mesh = G2MeshPlanV2(plan.mesh.mesh_ref,
        Tuple(sort!(collect(plan.mesh.region_ids))), plan.mesh.cells_per_region,
        plan.mesh.basis, plan.mesh.quadrature;
        execution_status=plan.mesh.execution_status)
    exterior = G2ExteriorPlanV2(plan.exterior.exterior_ref,
        Tuple(sort!(collect(plan.exterior.boundary_region_ids))),
        plan.exterior.boundary_condition,
        Tuple(sort!(collect(plan.exterior.boundary_faces); by=String));
        boundary_patches=Tuple(sort!(collect(plan.exterior.boundary_patches);
            by=patch -> (String(patch.face), patch.region_id, patch.lower, patch.upper))),
        provider_match=plan.exterior.provider_match)
    normalized_plan = FieldSpacePlanV2(plan.plan_ref, plan.chart, plan.embedding,
        plan.field_space, mesh, exterior)
    contract, normalized_plan
end

function _g2v5_source_order_canonical_genome(genome::FieldGeometryGenomeV5)
    _g2v5_source_order_profile(genome.grammar_profile) || return genome
    contract, plan = _g2v5_source_order_normalize(genome.region_interface, genome.plan)
    FieldGeometryGenomeV5(genome.contract_ref, contract, plan,
        genome.grammar_profile, genome.version_axes)
end

function _g2v5_source_order_semantically_equal(left::FieldGeometryGenomeV5,
                                                right::FieldGeometryGenomeV5)
    _g2v5_source_order_profile(left.grammar_profile) &&
        _g2v5_source_order_profile(right.grammar_profile) || return false
    normalized_left = _g2v5_source_order_canonical_genome(left)
    normalized_right = _g2v5_source_order_canonical_genome(right)
    semantic_view(normalized_left) == semantic_view(normalized_right)
end

function _g2v5_source_projection_rebuild_matches(left::FieldGeometryGenomeV5,
                                                  right::FieldGeometryGenomeV5)
    left.grammar_profile.canonicalization_profile_ref ==
        right.grammar_profile.canonicalization_profile_ref || return false
    if _g2v5_source_order_profile(left.grammar_profile)
        return _g2v5_source_order_semantically_equal(left, right)
    end
    semantic_view(left) == semantic_view(right)
end

function _g2v5_source_projection_component_matches(projection_genome::FieldGeometryGenomeV5,
                                                    component::FieldGeometryGenomeV5)
    _g2v5_source_order_profile(projection_genome.grammar_profile) ||
        return projection_genome === component
    _g2v5_source_order_semantically_equal(projection_genome, component)
end

function _g2v5_rebuild(genome::FieldGeometryGenomeV5,
                       region_interface::RegionInterfaceContractV2,
                       plan::FieldSpacePlanV2)
    FieldGeometryGenomeV5(genome.contract_ref, region_interface, plan,
                          genome.grammar_profile, genome.version_axes)
end

function g2_edit_interface(genome::FieldGeometryGenomeV5, interface_id::AbstractString;
                           coordinate=nothing, normal=nothing)
    id = String(interface_id)
    found = false
    rebuilt = G2InterfaceV2[]
    for interface in genome.region_interface.interfaces
        if interface.interface_ref.id == id
            found = true
            next_coordinate = coordinate === nothing ? interface.coordinate :
                _g2v5_rational(coordinate, "coordinate")
            next_normal = normal === nothing ? interface.normal : normal
            push!(rebuilt, G2InterfaceV2(interface.interface_ref,
                interface.left_region_id, interface.right_region_id, interface.axis,
                next_coordinate, next_normal, interface.continuity,
                interface.transfer_kind))
        else
            push!(rebuilt, interface)
        end
    end
    found || throw(ArgumentError("cannot edit unknown G2 interface id"))
    contract = RegionInterfaceContractV2(genome.region_interface.regions, Tuple(rebuilt))
    _g2v5_rebuild(genome, contract, genome.plan)
end

function g2_edit_mesh_cells(genome::FieldGeometryGenomeV5, cells_per_region::Any)
    mesh = G2MeshPlanV2(genome.plan.mesh.mesh_ref, genome.plan.mesh.region_ids,
        cells_per_region, genome.plan.mesh.basis, genome.plan.mesh.quadrature;
        execution_status=genome.plan.mesh.execution_status)
    plan = FieldSpacePlanV2(genome.plan.plan_ref, genome.plan.chart,
        genome.plan.embedding, genome.plan.field_space, mesh, genome.plan.exterior)
    _g2v5_rebuild(genome, genome.region_interface, plan)
end

"""A source-bound projection of a verified G2 metric-boundary declaration.

The V5 Genome keeps its historical serialized layout. `source_declaration`
retains the actual source affine map and its factory/content binding beside the
V5 geometry projection; callers must carry this value jointly when source-map
semantics are required. This is a bounded structural projection, not a lossless
migration or an executable geometry claim.
"""
struct G2V5SourceProjectionV1
    genome::FieldGeometryGenomeV5
    source_declaration::Any
    source_factory_identity::Any
    source_factory_receipt::Any
    source_payload_hash::Digest256
    source_content_hash::Digest256
    declaration_hash::Digest256
    source_map_retained::Bool
    resolution::Symbol
    claim_ceiling::Symbol
    projection_hash::Digest256
end

function _g2v5_source_qref(id, version="v2")
    QualifiedRefV1(String(id), String(version))
end

function _g2v5_source_project_bounds(chart_map, lower, upper)
    # Current G2 V5 regions are axis-aligned boxes. Preserve the exact affine
    # image only for the positive diagonal maps supported by whole-face source
    # coverage; a general affine map needs a richer V5 geometry representation.
    rows = chart_map.jacobian_rows
    all(iszero(rows[i][j]) for i in 1:3 for j in 1:3 if i != j) &&
        all(rows[i][i] > 0 for i in 1:3) ||
        throw(ArgumentError("G2 V5 source projection requires a positive diagonal affine chart"))
    lo = ntuple(i -> chart_map.offset[i] + rows[i][i] * lower[i], 3)
    hi = ntuple(i -> chart_map.offset[i] + rows[i][i] * upper[i], 3)
    lo, hi
end

"""Build a deferred G2 V5 geometry projection from a present real source factory result.

The result retains the original typed G2 source declaration and factory identity
so the affine map is still available and hash-bound. The V5 projection stores
its exact physical region/interface image and existing field/exterior fields.
"""
function g2_v5_source_projection_v1(factory_result;
        canonicalization_profile_ref::QualifiedRefV1=
            _g2v5_source_qref(G2_SOURCE_ORDER_CANONICALIZATION_PROFILE_REF_ID))
    all(name -> isdefined(@__MODULE__, name),
        (:G2SourceFactoryConstructionResultV1,
         :PresentG2SourceFactoryIdentityV1,
         :PresentG2SourceDeclarationV1,
         :PresentG2SourceConstructionReceiptV1,
         :G2MBSourceV1, :G2MBDeclarationV1)) ||
        throw(ArgumentError("G2 source factory and metric-boundary components must be loaded"))
    factory_result isa G2SourceFactoryConstructionResultV1 ||
        throw(ArgumentError("G2 V5 projection requires the actual G2 source factory result"))
    identity = factory_result.identity
    declaration_record = factory_result.source_declaration
    receipt = factory_result.receipt
    identity isa PresentG2SourceFactoryIdentityV1 &&
        declaration_record isa PresentG2SourceDeclarationV1 &&
        receipt isa PresentG2SourceConstructionReceiptV1 ||
        throw(ArgumentError("G2 V5 projection requires a present source factory/declaration receipt"))
    source = declaration_record.source_payload
    declaration = declaration_record.declaration
    source isa G2MBSourceV1 && declaration isa G2MBDeclarationV1 ||
        throw(ArgumentError("G2 V5 projection source payload/declaration types are invalid"))
    receipt.status === :present && receipt.output_source_declaration === declaration_record &&
        receipt.registry_not_used && identity.registry_not_used &&
        !receipt.candidate_identity_created && !receipt.final_hash_created &&
        !identity.candidate_identity_created && !identity.final_candidate_or_package_hash_created &&
        declaration_record.source_content_hash == identity.source_content_hash ==
            receipt.source_content_hash &&
        declaration_record.local_declaration_hash == identity.declaration_hash ==
            receipt.local_declaration_hash == declaration.declaration_hash &&
        declaration_record.declaration_hash == receipt.declaration_hash &&
        identity.source_payload_hash == source.source_hash == receipt.source_payload_hash &&
        declaration.source === source &&
        declaration.declaration_hash == g2mb_declaration_hash_v1(declaration) ||
        throw(ArgumentError("G2 source factory identity/receipt does not bind the typed declaration"))
    admission = g2mb_admit(source)
    admission.structural_status === :valid && admission.metric_status === :valid ||
        throw(ArgumentError("G2 V5 projection refuses structurally invalid source geometry"))
    source.chart_map.axes == (:x, :y, :z) &&
        source.boundary_coverage === :whole_face &&
        source.region_interface isa RegionInterfaceContractV2 &&
        source.region_exterior_owners isa Tuple ||
        throw(ArgumentError("G2 V5 source projection requires explicit Cartesian partition/exterior semantics"))
    source.field_space isa G2MBFieldSpaceV1 &&
        source.q1_interpretation === :continuous_tensor_product_lagrange_degree1_h1 ||
        throw(ArgumentError("G2 V5 source projection requires the declared typed Q1 field space"))
    source.units.coordinate == UnitSignature((1, 0, 0, 0, 0, 0, 0)) &&
        source.field_space.state_unit_signature == source.units.field_value ||
        throw(ArgumentError("G2 V5 source projection cannot represent these coordinate/field units"))
    all(face -> face.value.kind === :dirichlet && face.value.value == 0 &&
        face.value.unit == source.units.field_value, source.faces) ||
        throw(ArgumentError("G2 V5 source projection only represents the authored zero-Dirichlet face values"))
    regions_source = source.region_interface.regions
    length(regions_source) == 2 && length(source.region_interface.interfaces) == 1 ||
        throw(ArgumentError("G2 V5 source projection currently requires the exact two-region/one-interface source"))
    source_interface = only(source.region_interface.interfaces)
    left_index = findfirst(region -> region.region_id == source_interface.left_region_id,
        regions_source)
    right_index = findfirst(region -> region.region_id == source_interface.right_region_id,
        regions_source)
    left_index !== nothing && right_index !== nothing && left_index != right_index ||
        throw(ArgumentError("G2 V5 source interface does not uniquely bind its oriented regions"))
    left_source = regions_source[left_index]
    right_source = regions_source[right_index]
    source_regions = (left_source, right_source)
    chart_ref = _g2v5_source_qref(source.chart_map.chart_ref.id, "v2")
    all(region.chart_ref.id == chart_ref.id && region.chart_ref.version == "v2"
        for region in regions_source) ||
        throw(ArgumentError("G2 source regions do not reference the actual affine chart"))
    typed_regions = Tuple(begin
        lower, upper = _g2v5_source_project_bounds(source.chart_map,
            region.lower, region.upper)
        G2RegionV2(region.region_id, lower, upper, chart_ref,
            region.embedding_ref, region.field_space_ref, region.boundary_kinds)
    end for region in source_regions)
    typed_regions = Tuple(sort!(collect(typed_regions); by=region -> region.region_id))
    axis = Int(source_interface.axis)
    mapped_coordinate = source.chart_map.offset[axis] +
        source.chart_map.jacobian_rows[axis][axis] * source_interface.coordinate
    typed_interface = G2InterfaceV2(source_interface.interface_ref,
        source_interface.left_region_id, source_interface.right_region_id,
        axis, mapped_coordinate, source_interface.normal,
        source_interface.continuity, source_interface.transfer_kind)
    typed_contract = RegionInterfaceContractV2(typed_regions, (typed_interface,))

    patches = Tuple(begin
        index = findfirst(region -> region.region_id == owner.owner_region_id, typed_regions)
        index === nothing && throw(ArgumentError("G2 exterior owner references an unknown source region"))
        region = typed_regions[index]
        axes = owner.face in (:x_min, :x_max) ? (2, 3) :
            owner.face in (:y_min, :y_max) ? (1, 3) : (1, 2)
        G2BoundaryFacePatchV2(owner.face, owner.owner_region_id,
            (region.lower[axes[1]], region.lower[axes[2]]),
            (region.upper[axes[1]], region.upper[axes[2]]))
    end for owner in source.region_exterior_owners)
    patches = Tuple(sort!(collect(patches);
        by=patch -> (String(patch.face), patch.region_id)))
    faces = Tuple(sort!(unique!(Symbol[owner.face for owner in source.region_exterior_owners]);
        by=String))
    length(faces) == 6 ||
        throw(ArgumentError("G2 V5 source projection requires all six actual exterior faces"))

    all(region.embedding_ref == first(regions_source).embedding_ref &&
        region.field_space_ref == first(regions_source).field_space_ref
        for region in regions_source) ||
        throw(ArgumentError("G2 source partition changes embedding or field-space refs"))
    profile = SpatialGrammarProfileV2(
        _g2v5_source_qref("fusion.g2.grammar-profile"),
        canonicalization_profile_ref,
        _g2v5_source_qref("fusion.g2.applicability-profile"),
        source.profile.dimension, (source.profile.topology,), (:linear,);
        provider_match=:no_match)
    v5_contract = GenomeContractRef(
        "fusionconceptai://GenomeV5/G2/metric-boundary-source-projection/v5", "v5",
        g2_schema_hash(), g2_canonicalization_hash(profile),
        g2_compatibility_profile_token(profile))
    mesh = G2MeshPlanV2(_g2v5_source_qref(source.mesh.mesh_ref.id, "v2"),
        Tuple(region.region_id for region in typed_regions), source.mesh.cells,
        :linear, :declared_pending; execution_status=:declared_pending)
    field = G2FieldSpacePlanV2(first(typed_regions).field_space_ref,
        source.field_space.value_shape, :H1, source.field_space.state_unit)
    chart = G2ChartPlanV2(chart_ref,
        _g2v5_source_qref("fusion.g2.frame.cartesian"), (:x, :y, :z), :declared_map)
    embedding_ref = first(typed_regions).embedding_ref
    embedding = G2EmbeddingPlanV2(embedding_ref, chart_ref, 3, :declared_embedding)
    exterior = G2ExteriorPlanV2(
        _g2v5_source_qref("fusionconceptai://GenomeV5/G2/exterior/" * source.source_hash.value),
        Tuple(region.region_id for region in typed_regions), :dirichlet, faces;
        boundary_patches=patches, provider_match=:no_match)
    plan_ref = _g2v5_source_qref(
        "fusionconceptai://GenomeV5/G2/field-space-plan/" * source.source_hash.value)
    plan = FieldSpacePlanV2(plan_ref, chart, embedding, field, mesh, exterior)
    canonicalization_axis = _g2v5_source_order_profile(profile) ?
        G2_SOURCE_ORDER_CANONICALIZATION_AXIS_REF_ID : "fusion.g2.canonicalization"
    genome = FieldGeometryGenomeV5(v5_contract, typed_contract, plan, profile,
        G2VersionAxesV2(_g2v5_source_qref("fusion.g2.payload-schema", "v5"),
            _g2v5_source_qref(canonicalization_axis, "v5"),
            _g2v5_source_qref("fusion.g2.applicability", "v5"),
            _g2v5_source_qref("fusion.g2.receipt", "v5")))
    body = (genome=genome, source_factory_identity=identity,
        source_declaration=declaration_record,
        source_payload_hash=source.source_hash,
        source_content_hash=identity.source_content_hash,
        declaration_hash=declaration_record.declaration_hash,
        source_map_retained=true, resolution=:terminal_deferred,
        claim_ceiling=:contract_only)
    G2V5SourceProjectionV1(genome, declaration_record, identity, receipt,
        source.source_hash, identity.source_content_hash, declaration_record.declaration_hash,
        true, :terminal_deferred, :contract_only, canonical_hash(body))
end

semantic_view(x::G2V5SourceProjectionV1) =
    (genome=_g2v5_source_order_canonical_genome(x.genome), source_declaration=x.source_declaration,
     source_factory_identity=x.source_factory_identity,
     source_factory_receipt=x.source_factory_receipt,
     source_payload_hash=x.source_payload_hash,
     source_content_hash=x.source_content_hash,
     declaration_hash=x.declaration_hash, source_map_retained=x.source_map_retained,
     resolution=x.resolution, claim_ceiling=x.claim_ceiling,
     projection_hash=x.projection_hash)
canonical_hash(x::G2V5SourceProjectionV1) = x.projection_hash
