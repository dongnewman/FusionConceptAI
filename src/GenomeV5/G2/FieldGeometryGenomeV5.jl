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
        contract_ref.canonicalization_hash == g2_canonicalization_hash() ||
            throw(ArgumentError("G2 external canonicalization_hash does not match controlled canonicalization descriptor"))
        contract_ref.compatibility_profile == g2_compatibility_profile_token(grammar_profile) ||
            throw(ArgumentError("G2 external compatibility_profile does not match controlled profile hash"))
        version_axes.payload_schema_version.id == "fusion.g2.payload-schema" ||
            throw(ArgumentError("G2 payload schema axis is bound to the wrong ref domain"))
        version_axes.canonicalization_profile_version.id == "fusion.g2.canonicalization" ||
            throw(ArgumentError("G2 canonicalization axis is bound to the wrong ref domain"))
        version_axes.applicability_profile_version.id == "fusion.g2.applicability" ||
            throw(ArgumentError("G2 applicability axis is bound to the wrong ref domain"))
        version_axes.evidence_receipt_version.id == "fusion.g2.receipt" ||
            throw(ArgumentError("G2 evidence axis is bound to the wrong ref domain"))
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
