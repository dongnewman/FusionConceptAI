"""G2 chart-to-metric, bounded-discretization and face-ownership V1 slice.

This file is additive to the accepted UP1-02 structural G2 contract.  It does
not register a mesh backend, invoke a provider, or alter the old G2 V5 files.
The affine chart is intentionally executable as a value-level declaration:
its map, Jacobian and pullback metric can be evaluated from the typed source.
"""

const G2MB_SCHEMA_ID_V1 = "fusion.g2.metric-boundary.schema"
const G2MB_SCHEMA_VERSION_V1 = "v1"
const G2MB_PROFILE_ID_V1 = "fusion.g2.metric-boundary.profile"
const G2MB_CLAIM_CEILING_V1 = :contract_only
const G2MB_LABEL_ERASURE_SCOPE_V1 = :display_metadata_only

struct G2MBChartMapV1
    chart_ref::QualifiedRefV1
    domain_lower::NTuple{3,Rational{Int64}}
    domain_upper::NTuple{3,Rational{Int64}}
    jacobian_rows::NTuple{3,NTuple{3,Rational{Int64}}}
    offset::NTuple{3,Rational{Int64}}
    map_kind::Symbol
    axes::Union{Nothing,NTuple{3,Symbol}}
    function G2MBChartMapV1(chart_ref::Any, domain_lower::Any, domain_upper::Any,
                            jacobian_rows::Any, offset::Any; map_kind=:affine,
                            axes=nothing)
        chart_ref isa QualifiedRefV1 && chart_ref.version == "v1" ||
            throw(ArgumentError("chart_ref must be a v1 QualifiedRefV1"))
        length(domain_lower) == 3 && length(domain_upper) == 3 ||
            throw(ArgumentError("chart bounds must have three coordinates"))
        lower = ntuple(i -> _g2mb_ratio(domain_lower[i], "domain_lower[$i]"), 3)
        upper = ntuple(i -> _g2mb_ratio(domain_upper[i], "domain_upper[$i]"), 3)
        all(lower[i] < upper[i] for i in 1:3) ||
            throw(ArgumentError("chart bounds must be strictly ordered"))
        rows = _g2mb_matrix(jacobian_rows, "jacobian_rows")
        shift = _g2mb_vector(offset, "offset")
        _g2mb_det3(rows) != 0 || throw(ArgumentError("chart Jacobian must be nonsingular"))
        map_kind === :affine || throw(ArgumentError("only affine chart maps are supported"))
        axis_labels = if axes === nothing
            nothing
        else
            axes isa Tuple && length(axes) == 3 &&
                all(x -> x isa Symbol && x in (:x, :y, :z), axes) &&
                length(unique(axes)) == 3 ||
                throw(ArgumentError("chart axes must be three unique Cartesian labels"))
            ntuple(i -> axes[i], 3)
        end
        new(chart_ref, lower, upper, rows, shift, map_kind, axis_labels)
    end
end

_g2mb_ratio(x::Rational{Int64}, field::AbstractString) = x
_g2mb_ratio(x::Integer, field::AbstractString) = Int64(x) // 1
function _g2mb_ratio(x, field::AbstractString)
    x isa AbstractString && occursin("/", String(x)) ||
        throw(ArgumentError("$field must be an exact Rational{Int64}"))
    a, b = split(String(x), "/"; limit=2)
    _g2mb_ratio(parse(Int64, a), field) / parse(Int64, b)
end

function _g2mb_vector(value, field::AbstractString)
    value isa Tuple && length(value) == 3 || throw(ArgumentError("$field must be a 3-tuple"))
    ntuple(i -> _g2mb_ratio(value[i], "$field[$i]"), 3)
end

function _g2mb_matrix(value, field::AbstractString)
    value isa Tuple && length(value) == 3 || throw(ArgumentError("$field must be a 3x3 tuple"))
    rows = ntuple(i -> _g2mb_vector(value[i], "$field[$i]"), 3)
    rows
end

function _g2mb_det3(a::NTuple{3,NTuple{3,Rational{Int64}}})
    a[1][1] * (a[2][2] * a[3][3] - a[2][3] * a[3][2]) -
        a[1][2] * (a[2][1] * a[3][3] - a[2][3] * a[3][1]) +
        a[1][3] * (a[2][1] * a[3][2] - a[2][2] * a[3][1])
end

function semantic_view(x::G2MBChartMapV1)
    body = (chart_ref=x.chart_ref, domain_lower=x.domain_lower, domain_upper=x.domain_upper,
        jacobian_rows=x.jacobian_rows, offset=x.offset, map_kind=x.map_kind)
    x.axes === nothing ? body : merge(body, (axes=x.axes,))
end
canonical_json(x::G2MBChartMapV1) = canonical_json(semantic_view(x))

function g2mb_chart_map(x::G2MBChartMapV1, point::Any)
    p = _g2mb_vector(point, "chart point")
    all(x.domain_lower[i] <= p[i] <= x.domain_upper[i] for i in 1:3) ||
        throw(ArgumentError("chart point is outside the bounded chart domain"))
    ntuple(i -> x.offset[i] + sum(x.jacobian_rows[i][j] * p[j] for j in 1:3), 3)
end

g2mb_chart_jacobian(x::G2MBChartMapV1) = x.jacobian_rows

g2mb_det_jacobian(x::G2MBChartMapV1)::Rational{Int64} = _g2mb_det3(x.jacobian_rows)
g2mb_orientation_positive(x::G2MBChartMapV1) = g2mb_det_jacobian(x) > 0

function g2mb_metric(x::G2MBChartMapV1)
    ntuple(i -> ntuple(j -> sum(x.jacobian_rows[k][i] * x.jacobian_rows[k][j] for k in 1:3), 3), 3)
end

function g2mb_metric_positive_definite(x::G2MBChartMapV1)
    m = g2mb_metric(x)
    m[1][1] > 0 &&
        (m[1][1] * m[2][2] - m[1][2] * m[2][1]) > 0 &&
        _g2mb_det3(m) > 0
end

function _g2mb_cofactor_matrix(a::NTuple{3,NTuple{3,Rational{Int64}}})
    ((a[2][2] * a[3][3] - a[2][3] * a[3][2],
      -(a[2][1] * a[3][3] - a[2][3] * a[3][1]),
      a[2][1] * a[3][2] - a[2][2] * a[3][1]),
     (-(a[1][2] * a[3][3] - a[1][3] * a[3][2]),
      a[1][1] * a[3][3] - a[1][3] * a[3][1],
      -(a[1][1] * a[3][2] - a[1][2] * a[3][1])),
     (a[1][2] * a[2][3] - a[1][3] * a[2][2],
      -(a[1][1] * a[2][3] - a[1][3] * a[2][1]),
      a[1][1] * a[2][2] - a[1][2] * a[2][1]))
end

"""Return det(J) J^-T n_ref as an unnormalised physical area vector.

The input is explicitly a reference-box normal.  The result is a physical
oriented area vector; it is not a normalized physical normal.
"""
function g2mb_physical_oriented_area_vector(x::G2MBChartMapV1, reference_normal::Any)::NTuple{3,Rational{Int64}}
    n = _g2mb_vector(reference_normal, "reference_normal")
    all(denominator(v) == 1 && abs(numerator(v)) <= 1 for v in n) ||
        throw(ArgumentError("reference_normal must contain -1, 0 or +1"))
    cofactor = _g2mb_cofactor_matrix(x.jacobian_rows)
    ntuple(i -> sum(cofactor[i][j] * n[j] for j in 1:3), 3)
end

struct G2MBVolumeMeasureV1
    signed_scale::Rational{Int64}
    absolute_scale::Rational{Int64}
    orientation::Symbol
    unit::UnitSignature
end

semantic_view(x::G2MBVolumeMeasureV1) =
    (signed_scale=x.signed_scale, absolute_scale=x.absolute_scale,
     orientation=x.orientation, unit=x.unit)
canonical_json(x::G2MBVolumeMeasureV1) = canonical_json(semantic_view(x))

function g2mb_chart_image_bounds(x::G2MBChartMapV1)
    corners = ntuple(n -> ntuple(i -> ((n - 1) >> (i - 1)) & 1 == 1 ?
        x.domain_upper[i] : x.domain_lower[i], 3), 8)
    images = ntuple(n -> g2mb_chart_map(x, corners[n]), 8)
    ntuple(i -> (minimum(p[i] for p in images), maximum(p[i] for p in images)), 3)
end

struct G2MBMeshPlanV1
    mesh_ref::QualifiedRefV1
    chart_ref::QualifiedRefV1
    cells::NTuple{3,Int}
    basis::Symbol
    quadrature_points::Tuple{Vararg{NTuple{3,Rational{Int64}}}}
    quadrature_weights::Tuple{Vararg{Rational{Int64}}}
    execution_status::Symbol
    function G2MBMeshPlanV1(mesh_ref::Any, chart_ref::Any, cells::Any, basis::Any,
                            quadrature_points::Any, quadrature_weights::Any;
                            execution_status=:declared)
        mesh_ref isa QualifiedRefV1 && mesh_ref.version == "v1" ||
            throw(ArgumentError("mesh_ref must be a v1 QualifiedRefV1"))
        chart_ref isa QualifiedRefV1 && chart_ref.version == "v1" ||
            throw(ArgumentError("mesh chart_ref must be a v1 QualifiedRefV1"))
        cells isa Tuple && length(cells) == 3 || throw(ArgumentError("cells must be a 3-tuple"))
        cs = ntuple(i -> cells[i] isa Integer && cells[i] >= 1 ? Int(cells[i]) :
            throw(ArgumentError("mesh cells must be positive integers")), 3)
        basis in (:Q1, :Q2) || throw(ArgumentError("unsupported basis"))
        quadrature_points isa Tuple && !isempty(quadrature_points) ||
            throw(ArgumentError("quadrature_points must be non-empty"))
        points = Tuple(_g2mb_vector(p, "quadrature point") for p in quadrature_points)
        all(all(0 <= p[i] <= 1 for i in 1:3) for p in points) ||
            throw(ArgumentError("quadrature points must lie in the reference cell"))
        quadrature_weights isa Tuple && length(quadrature_weights) == length(points) ||
            throw(ArgumentError("quadrature weight arity mismatch"))
        weights = Tuple(_g2mb_ratio(w, "quadrature weight") for w in quadrature_weights)
        all(>(0), weights) || throw(ArgumentError("quadrature weights must be positive"))
        execution_status in (:declared, :not_executed) ||
            throw(ArgumentError("mesh execution status is outside this contract"))
        new(mesh_ref, chart_ref, cs, basis, points, weights, execution_status)
    end
end

semantic_view(x::G2MBMeshPlanV1) =
    (mesh_ref=x.mesh_ref, chart_ref=x.chart_ref, cells=x.cells, basis=x.basis,
     quadrature_points=x.quadrature_points, quadrature_weights=x.quadrature_weights,
     execution_status=x.execution_status)
canonical_json(x::G2MBMeshPlanV1) = canonical_json(semantic_view(x))

struct G2MBFaceValueV1
    kind::Symbol
    value::Rational{Int64}
    unit::UnitSignature
    function G2MBFaceValueV1(kind::Any, value::Any, unit::Any)
        kind in (:dirichlet, :neumann) || throw(ArgumentError("face value kind must be Dirichlet or Neumann"))
        unit isa UnitSignature || throw(ArgumentError("face value unit must be UnitSignature"))
        new(kind, _g2mb_ratio(value, "face value"), unit)
    end
end

semantic_view(x::G2MBFaceValueV1) = (kind=x.kind, value=x.value, unit=x.unit)
canonical_json(x::G2MBFaceValueV1) = canonical_json(semantic_view(x))

struct G2MBFaceOwnerV1
    face_id::String
    face::Symbol
    owner_region_id::String
    reference_normal::NTuple{3,Int8}
    value::G2MBFaceValueV1
    ownership::Symbol
    function G2MBFaceOwnerV1(face_id::Any, face::Any, owner_region_id::Any,
                             reference_normal::Any, value::Any; ownership=:candidate_owned)
        face_id isa String && !isempty(face_id) || throw(ArgumentError("face_id is required"))
        face in (:x_min, :x_max, :y_min, :y_max, :z_min, :z_max) ||
            throw(ArgumentError("unsupported boundary face"))
        owner_region_id isa String && !isempty(owner_region_id) ||
            throw(ArgumentError("owner_region_id is required"))
        n = _g2mb_vector(reference_normal, "reference_normal")
        all(x -> denominator(x) == 1 && abs(numerator(x)) <= 1, n) ||
            throw(ArgumentError("reference_normal must contain -1, 0 or +1"))
        value isa G2MBFaceValueV1 || throw(ArgumentError("face value must be typed"))
        ownership === :candidate_owned || throw(ArgumentError("face ownership must be candidate_owned"))
        new(face_id, face, owner_region_id, ntuple(i -> Int8(numerator(n[i])), 3), value, ownership)
    end
end

semantic_view(x::G2MBFaceOwnerV1) =
    (face_id=x.face_id, face=x.face, owner_region_id=x.owner_region_id,
     reference_normal=x.reference_normal, value=x.value, ownership=x.ownership)
canonical_json(x::G2MBFaceOwnerV1) = canonical_json(semantic_view(x))

struct G2MBAuthorityV1
    metric::Symbol
    mesh::Symbol
    boundary::Symbol
    function G2MBAuthorityV1(metric::Any, mesh::Any, boundary::Any)
        all(x -> x in (:unique_match, :no_match, :missing), (metric, mesh, boundary)) ||
            throw(ArgumentError("authority states are invalid"))
        new(metric, mesh, boundary)
    end
end

semantic_view(x::G2MBAuthorityV1) = (metric=x.metric, mesh=x.mesh, boundary=x.boundary)
canonical_json(x::G2MBAuthorityV1) = canonical_json(semantic_view(x))

struct G2MBProfileV1
    profile_id::String
    dimension::Int
    topology::Symbol
    basis_family::Symbol
    claim_ceiling::Symbol
    function G2MBProfileV1(profile_id::Any; dimension=3, topology=:cartesian,
                           basis_family=:tensor_product, claim_ceiling=:contract_only)
        profile_id isa String && !isempty(profile_id) || throw(ArgumentError("profile_id is required"))
        dimension == 3 || throw(ArgumentError("metric-boundary profile requires dimension=3"))
        topology === :cartesian || throw(ArgumentError("only cartesian topology is supported"))
        basis_family === :tensor_product || throw(ArgumentError("unsupported basis family"))
        claim_ceiling === :contract_only || throw(ArgumentError("profile claim ceiling is contract_only"))
        new(profile_id, 3, topology, basis_family, claim_ceiling)
    end
end

semantic_view(x::G2MBProfileV1) =
    (profile_id=x.profile_id, dimension=x.dimension, topology=x.topology,
     basis_family=x.basis_family, claim_ceiling=x.claim_ceiling)
canonical_json(x::G2MBProfileV1) = canonical_json(semantic_view(x))

struct G2MBUnitContractV1
    reference_coordinate::UnitSignature
    coordinate::UnitSignature
    jacobian::UnitSignature
    metric::UnitSignature
    area::UnitSignature
    volume::UnitSignature
    field_value::UnitSignature
    flux_value::UnitSignature
    function G2MBUnitContractV1(reference_coordinate::Any, coordinate::Any, jacobian::Any,
                                metric::Any, area::Any, volume::Any, field_value::Any,
                                flux_value::Any)
        units = (reference_coordinate, coordinate, jacobian, metric, area, volume,
                 field_value, flux_value)
        all(x -> x isa UnitSignature, units) ||
            throw(ArgumentError("G2 metric-boundary units must be UnitSignature values"))
        new(units...)
    end
end

semantic_view(x::G2MBUnitContractV1) =
    (reference_coordinate=x.reference_coordinate, coordinate=x.coordinate,
     jacobian=x.jacobian, metric=x.metric, area=x.area, volume=x.volume,
     field_value=x.field_value, flux_value=x.flux_value)
canonical_json(x::G2MBUnitContractV1) = canonical_json(semantic_view(x))

struct G2MBFieldSpaceV1
    state_field_id::String
    value_shape::Symbol
    state_unit::String
    state_unit_signature::UnitSignature
    function G2MBFieldSpaceV1(state_field_id::Any, value_shape::Any,
                              state_unit::Any, state_unit_signature::Any)
        state_field_id isa AbstractString && !isempty(String(state_field_id)) ||
            throw(ArgumentError("field-space state_field_id is required"))
        value_shape in (:scalar, :vector3) ||
            throw(ArgumentError("field-space value_shape must be :scalar or :vector3"))
        state_unit isa String && !isempty(state_unit) ||
            throw(ArgumentError("field-space state_unit is required"))
        state_unit_signature isa UnitSignature ||
            throw(ArgumentError("field-space state_unit_signature must be UnitSignature"))
        dimensionless = all(iszero, state_unit_signature.exponents)
        (state_unit == "1") == dimensionless ||
            throw(ArgumentError("field-space unit label '1' must mean exactly dimensionless"))
        new(String(state_field_id), value_shape, state_unit, state_unit_signature)
    end
end

semantic_view(x::G2MBFieldSpaceV1) =
    (state_field_id=x.state_field_id, value_shape=x.value_shape,
     state_unit=x.state_unit, state_unit_signature=x.state_unit_signature)
canonical_json(x::G2MBFieldSpaceV1) = canonical_json(semantic_view(x))

# Face order is a canonicalization concern, not an execution-order concern.
# `face`/owner/value are semantic fields; an input tuple permutation must not
# create a new source or declaration identity.  The complete key includes the
# fields needed to distinguish duplicate/contradictory owners, so even an
# invalid source has deterministic bytes and classification.  Opaque face_id
# remains part of the owner contract and is therefore not erased as display
# metadata.
function _g2mb_canonical_faces(faces)
    Tuple(sort(collect(faces); by=f -> (String(f.face), f.face_id, f.owner_region_id,
        String(f.ownership), Tuple(f.reference_normal), String(f.value.kind),
        f.value.value, Tuple(f.value.unit.exponents))))
end

struct G2MBRegionExteriorOwnerV1
    face::Symbol
    owner_region_id::String
    function G2MBRegionExteriorOwnerV1(face::Any, owner_region_id::Any)
        face isa Symbol && face in (:x_min, :x_max, :y_min, :y_max, :z_min, :z_max) ||
            throw(ArgumentError("unsupported region exterior face"))
        owner_region_id isa String && !isempty(owner_region_id) ||
            throw(ArgumentError("region exterior owner id is required"))
        new(face, owner_region_id)
    end
end
semantic_view(x::G2MBRegionExteriorOwnerV1) =
    (face=x.face, owner_region_id=x.owner_region_id)
canonical_json(x::G2MBRegionExteriorOwnerV1) = canonical_json(semantic_view(x))

function _g2mb_source_body(source_ref, source_version, candidate_ref, chart_map,
                           mesh, faces, profile, units, authority;
                           field_space=nothing, q1_interpretation=nothing,
                           boundary_coverage=nothing, region_interface=nothing,
                           region_exterior_owners=nothing)
    body = (source_ref=source_ref, source_version=source_version, candidate_ref=candidate_ref,
     chart_map=chart_map, mesh=mesh, faces=_g2mb_canonical_faces(faces), profile=profile,
     units=units, authority=authority)
    if field_space !== nothing || q1_interpretation !== nothing
        field_space isa G2MBFieldSpaceV1 ||
            throw(ArgumentError("field_space must be G2MBFieldSpaceV1 when declared"))
        q1_interpretation === :continuous_tensor_product_lagrange_degree1_h1 ||
            throw(ArgumentError("unsupported Q1 field-space interpretation"))
        body = merge(body, (field_space=field_space, q1_interpretation=q1_interpretation))
    end
    if boundary_coverage !== nothing
        boundary_coverage === :whole_face ||
            throw(ArgumentError("unsupported boundary coverage semantics"))
        chart_map isa G2MBChartMapV1 && chart_map.axes !== nothing ||
            throw(ArgumentError("whole-face coverage requires explicit chart axes"))
        body = merge(body, (boundary_coverage=boundary_coverage,))
    end
    if region_interface === nothing
        region_exterior_owners === nothing ||
            throw(ArgumentError("region exterior owners require a region interface"))
    else
        region_interface isa RegionInterfaceContractV2 ||
            throw(ArgumentError("region_interface must be RegionInterfaceContractV2"))
        region_exterior_owners isa Tuple &&
            all(x -> x isa G2MBRegionExteriorOwnerV1, region_exterior_owners) ||
            throw(ArgumentError("region_exterior_owners must be a typed tuple"))
        _g2mb_validate_region_interface(region_interface, chart_map, region_exterior_owners)
        body = merge(body, (region_interface=region_interface,
            region_exterior_owners=region_exterior_owners))
    end
    body
end

# The optional internal partition is restricted to two exact chart boxes joined
# by one complete axis-aligned face. It records candidate geometry only.
function _g2mb_validate_region_interface(contract, chart_map::G2MBChartMapV1, region_exterior_owners)
    contract isa RegionInterfaceContractV2 ||
        throw(ArgumentError("region_interface must be RegionInterfaceContractV2"))
    length(contract.regions) == 2 && length(contract.interfaces) == 1 ||
        throw(ArgumentError("G2MB partition requires two regions and one interface"))
    interface = only(contract.interfaces)
    left_index = findfirst(region -> region.region_id == interface.left_region_id,
        contract.regions)
    right_index = findfirst(region -> region.region_id == interface.right_region_id,
        contract.regions)
    # Keep the prior ordered validation path for malformed references.  The
    # authored tuple position is no longer used to assign interface roles.
    left = left_index === nothing ? first(contract.regions) : contract.regions[left_index]
    right = right_index === nothing ? last(contract.regions) : contract.regions[right_index]
    axis = Int(interface.axis)
    left.chart_ref.id == chart_map.chart_ref.id && left.chart_ref.version == "v2" &&
        chart_map.chart_ref.version == "v1" &&
        left.chart_ref == right.chart_ref && left.embedding_ref == right.embedding_ref &&
        left.field_space_ref == right.field_space_ref ||
        throw(ArgumentError("G2MB partition region references differ"))
    all(region.boundary_kinds == (:dirichlet,) for region in contract.regions) ||
        throw(ArgumentError("G2MB partition regions must inherit the authored Dirichlet boundary kind"))
    left.lower == chart_map.domain_lower && right.upper == chart_map.domain_upper ||
        throw(ArgumentError("G2MB partition does not cover the chart domain"))
    left.upper[axis] == interface.coordinate && right.lower[axis] == interface.coordinate ||
        throw(ArgumentError("G2MB partition interface faces do not coincide"))
    all(left.lower[i] == right.lower[i] && left.upper[i] == right.upper[i]
        for i in 1:3 if i != axis) ||
        throw(ArgumentError("G2MB partition tangential coverage is incomplete"))
    left_index !== nothing && right_index !== nothing &&
        interface.left_region_id == left.region_id &&
        interface.right_region_id == right.region_id && interface.normal == 1 &&
        interface.continuity === :trace_flux &&
        interface.transfer_kind === :conservative ||
        throw(ArgumentError("G2MB interface orientation or transfer contract is unsupported"))
    expected = Set{Tuple{Symbol,String}}()
    for face in (:x_min, :x_max, :y_min, :y_max, :z_min, :z_max)
        a = face in (:x_min, :x_max) ? 1 : face in (:y_min, :y_max) ? 2 : 3
        lower_side = face in (:x_min, :y_min, :z_min)
        boundary = lower_side ? chart_map.domain_lower[a] : chart_map.domain_upper[a]
        for region in contract.regions
            edge = lower_side ? region.lower[a] : region.upper[a]
            edge == boundary && push!(expected, (face, region.region_id))
        end
    end
    actual = Set((face.face, face.owner_region_id) for face in region_exterior_owners)
    length(actual) == length(region_exterior_owners) && actual == expected ||
        throw(ArgumentError("G2MB exterior owners do not match the partition boundary"))
    nothing
end

function _g2mb_validate_field_space(field_space, q1_interpretation,
                                    mesh::G2MBMeshPlanV1, profile::G2MBProfileV1,
                                    units::G2MBUnitContractV1)
    if field_space === nothing && q1_interpretation === nothing
        return nothing
    end
    field_space isa G2MBFieldSpaceV1 ||
        throw(ArgumentError("field_space must be G2MBFieldSpaceV1 when declared"))
    q1_interpretation === :continuous_tensor_product_lagrange_degree1_h1 ||
        throw(ArgumentError("unsupported Q1 field-space interpretation"))
    field_space.state_unit_signature == units.field_value ||
        throw(ArgumentError("field-space state unit signature must match units.field_value"))
    mesh.basis === :Q1 && profile.basis_family === :tensor_product ||
        throw(ArgumentError("continuous Q1 interpretation requires Q1 basis and tensor_product profile"))
    nothing
end

function _g2mb_validate_boundary_coverage(boundary_coverage,
        chart_map::G2MBChartMapV1, faces, profile::G2MBProfileV1;
        region_interface=nothing)
    boundary_coverage === nothing && return nothing
    boundary_coverage === :whole_face ||
        throw(ArgumentError("unsupported boundary coverage semantics"))
    chart_map.axes == (:x, :y, :z) && profile.topology === :cartesian ||
        throw(ArgumentError("whole-face coverage requires ordered Cartesian axes"))
    all(iszero(chart_map.jacobian_rows[i][j]) for i in 1:3 for j in 1:3 if i != j) &&
        all(chart_map.jacobian_rows[i][i] > 0 for i in 1:3) ||
        throw(ArgumentError("whole-face coverage requires a positive diagonal chart"))
    if region_interface === nothing
        length(faces) == 6 && Set(f.face for f in faces) ==
            Set((:x_min, :x_max, :y_min, :y_max, :z_min, :z_max)) &&
            length(Set(f.owner_region_id for f in faces)) == 1 ||
            throw(ArgumentError("whole-face coverage requires one closed six-face region"))
    else
        _g2mb_validate_region_interface(region_interface, chart_map, faces)
    end
    all(Tuple(f.reference_normal) == _g2mb_expected_normal(f.face) for f in faces) ||
        throw(ArgumentError("whole-face coverage face normals do not match Cartesian labels"))
    nothing
end

_g2mb_unit_add(a::UnitSignature, b::UnitSignature) =
    UnitSignature(ntuple(i -> a.exponents[i] + b.exponents[i], 7))
_g2mb_unit_zero() = UnitSignature((0, 0, 0, 0, 0, 0, 0))
_g2mb_length_unit() = UnitSignature((1, 0, 0, 0, 0, 0, 0))

"""Return exact dimension algebra violations without throwing.

The first exponent is the contract's length dimension.  Reference coordinates
are dimensionless; a physical coordinate and its Jacobian carry L, pullback
metric and oriented area carry L², and volume carries L³.  Value units remain
field/flux-specific and are checked against face declarations separately.
"""
function g2mb_unit_algebra_errors(units::G2MBUnitContractV1)::Tuple{Vararg{String}}
    zero = _g2mb_unit_zero()
    length = _g2mb_length_unit()
    square = _g2mb_unit_add(length, length)
    cube = _g2mb_unit_add(square, length)
    expected = ((:reference_coordinate, units.reference_coordinate, zero),
                (:coordinate, units.coordinate, length),
                (:jacobian, units.jacobian, length),
                (:metric, units.metric, square),
                (:area, units.area, square),
                (:volume, units.volume, cube))
    errors = String[]
    for (name, actual, required) in expected
        actual == required || push!(errors, String(name) * "_unit_mismatch")
    end
    Tuple(errors)
end

struct G2MBAreaMeasureV1
    oriented_vector::NTuple{3,Rational{Int64}}
    unit::UnitSignature
end

semantic_view(x::G2MBAreaMeasureV1) =
    (oriented_vector=x.oriented_vector, unit=x.unit)
canonical_json(x::G2MBAreaMeasureV1) = canonical_json(semantic_view(x))

function g2mb_physical_oriented_area_measure(x::G2MBChartMapV1,
                                             reference_normal::Any,
                                             units::G2MBUnitContractV1)
    isempty(g2mb_unit_algebra_errors(units)) ||
        throw(ArgumentError("unit algebra is not validated"))
    G2MBAreaMeasureV1(g2mb_physical_oriented_area_vector(x, reference_normal), units.area)
end

function g2mb_volume_measure(x::G2MBChartMapV1, units::G2MBUnitContractV1)
    isempty(g2mb_unit_algebra_errors(units)) ||
        throw(ArgumentError("unit algebra is not validated"))
    signed = g2mb_det_jacobian(x)
    G2MBVolumeMeasureV1(signed, abs(signed), signed > 0 ? :orientation_preserving : :orientation_reversing,
        units.volume)
end

const G2MB_SCHEMA_DESCRIPTOR_V1 =
    (id=G2MB_SCHEMA_ID_V1, version=G2MB_SCHEMA_VERSION_V1,
     fields=("candidate_ref", "chart_map", "jacobian", "metric", "mesh", "basis",
             "quadrature", "face_owner", "face_value", "units", "detJ", "authority",
             "reference_coordinate_unit", "derived_geometry_unit_algebra",
             "optional_chart_map_axes", "optional_boundary_coverage",
             "optional_field_space(state_field_id,value_shape,state_unit,state_unit_signature)",
             "optional_q1_interpretation"),
     constraints=("bounded_3d_chart", "J_transpose_J_positive_definite",
                  "unique_face_owner", "dirichlet_or_neumann_value",
                  "reference_coordinate_dimensionless", "coordinate_J_L_metric_L2_area_L2_volume_L3",
                  "fail_closed_contradiction", "terminal_deferred_missing_authority",
                  "field_space_and_q1_interpretation_declared_together",
                  "field_space_value_shape_scalar_or_vector3",
                  "field_space_state_unit_signature_equals_units_field_value",
                  "state_unit_label_1_iff_dimensionless",
                  "continuous_tensor_product_lagrange_degree1_h1_requires_Q1_tensor_product_profile",
                  "cartesian_chart_axes_are_unique_ordered_xyz_labels",
                  "whole_face_coverage_requires_positive_diagonal_rectangular_chart_and_closed_face_normals",
                  "whole_face_patch_tangential_bounds_are_exact_chart_image_bounds"))
const G2MB_CANONICALIZATION_DESCRIPTOR_V1 =
    (domain="fusionconceptai:g2:metric-boundary:v1", encoding="canonical_json_named_tuple",
     coordinate_type="Rational{Int64}", matrix_order="row_major", face_order="lexical")

const G2MB_REGION_INTERFACE_EXTENSION_DESCRIPTOR_V1 =
    (fields=("optional_region_interface(RegionInterfaceContractV2:exact_two_region_partition)",
             "optional_region_exterior_owners(Tuple{G2MBRegionExteriorOwnerV1}:exact_boundary_union)"),
     constraints=("exact_two_region_full_face_partition", "region_exterior_owner_union_matches_geometry"))
g2mb_schema_hash_v1()::Digest256 = canonical_hash(G2MB_SCHEMA_DESCRIPTOR_V1)
g2mb_schema_hash_v1(region_interface_present::Bool)::Digest256 = region_interface_present ?
    canonical_hash((base=G2MB_SCHEMA_DESCRIPTOR_V1, extension=G2MB_REGION_INTERFACE_EXTENSION_DESCRIPTOR_V1)) :
    g2mb_schema_hash_v1()
g2mb_canonicalization_hash_v1()::Digest256 = canonical_hash(G2MB_CANONICALIZATION_DESCRIPTOR_V1)
g2mb_profile_hash_v1(profile::G2MBProfileV1)::Digest256 = canonical_hash(profile)
g2mb_profile_token_v1(profile::G2MBProfileV1) = "g2-metric-boundary-v1-profile:" * g2mb_profile_hash_v1(profile).value

struct G2MBSourceV1
    source_ref::QualifiedRefV1
    source_version::String
    candidate_ref::GenomeContractRef
    chart_map::G2MBChartMapV1
    mesh::G2MBMeshPlanV1
    faces::Tuple{Vararg{G2MBFaceOwnerV1}}
    profile::G2MBProfileV1
    units::G2MBUnitContractV1
    authority::G2MBAuthorityV1
    field_space::Union{Nothing,G2MBFieldSpaceV1}
    q1_interpretation::Union{Nothing,Symbol}
    boundary_coverage::Union{Nothing,Symbol}
    region_interface::Union{Nothing,RegionInterfaceContractV2}
    region_exterior_owners::Union{Nothing,Tuple{Vararg{G2MBRegionExteriorOwnerV1}}}
    source_hash::Digest256
    function G2MBSourceV1(source_ref::Any, source_version::Any, candidate_ref::Any,
                          chart_map::Any, mesh::Any, faces::Any, profile::Any,
                          units::Any, authority::Any, source_hash::Any;
                          field_space=nothing, q1_interpretation=nothing,
                          boundary_coverage=nothing, region_interface=nothing,
                          region_exterior_owners=nothing)
        source_ref isa QualifiedRefV1 || throw(ArgumentError("source_ref must be typed"))
        source_version isa String && !isempty(source_version) || throw(ArgumentError("source_version is required"))
        candidate_ref isa GenomeContractRef && candidate_ref.version == "v5" ||
            throw(ArgumentError("candidate_ref must be a v5 GenomeContractRef"))
        chart_map isa G2MBChartMapV1 || throw(ArgumentError("chart_map must be typed"))
        mesh isa G2MBMeshPlanV1 || throw(ArgumentError("mesh must be typed"))
        faces isa Tuple && !isempty(faces) && all(x -> x isa G2MBFaceOwnerV1, faces) ||
            throw(ArgumentError("faces must be a non-empty tuple of typed owners"))
        profile isa G2MBProfileV1 || throw(ArgumentError("profile must be typed"))
        units isa G2MBUnitContractV1 || throw(ArgumentError("units must be typed"))
        authority isa G2MBAuthorityV1 || throw(ArgumentError("authority must be typed"))
        source_hash isa Digest256 || throw(ArgumentError("source_hash must be Digest256"))
        _g2mb_validate_field_space(field_space, q1_interpretation, mesh, profile, units)
        _g2mb_validate_boundary_coverage(boundary_coverage, chart_map, faces, profile)
        region_interface === nothing || region_interface isa RegionInterfaceContractV2 ||
            throw(ArgumentError("region_interface must be RegionInterfaceContractV2"))
        region_exterior_owners === nothing || (region_exterior_owners isa Tuple &&
            all(x -> x isa G2MBRegionExteriorOwnerV1, region_exterior_owners)) ||
            throw(ArgumentError("region_exterior_owners must be a typed tuple"))
        body = _g2mb_source_body(source_ref, source_version, candidate_ref, chart_map,
            mesh, faces, profile, units, authority; field_space=field_space,
            q1_interpretation=q1_interpretation,
            boundary_coverage=boundary_coverage, region_interface=region_interface,
            region_exterior_owners=region_exterior_owners)
        source_hash == canonical_hash(body) || throw(ArgumentError("source_hash does not match source body"))
        new(source_ref, source_version, candidate_ref, chart_map, mesh, _g2mb_canonical_faces(faces), profile,
            units, authority, field_space, q1_interpretation, boundary_coverage,
            region_interface, region_exterior_owners, source_hash)
    end
end

function g2mb_source_v1(source_ref, source_version, candidate_ref, chart_map, mesh, faces,
                        profile, units, authority; field_space=nothing,
                        q1_interpretation=nothing, boundary_coverage=nothing,
                        region_interface=nothing, region_exterior_owners=nothing)
    _g2mb_validate_field_space(field_space, q1_interpretation, mesh, profile, units)
    body = _g2mb_source_body(source_ref, source_version, candidate_ref, chart_map,
        mesh, faces, profile, units, authority; field_space=field_space,
        q1_interpretation=q1_interpretation,
        boundary_coverage=boundary_coverage, region_interface=region_interface,
        region_exterior_owners=region_exterior_owners)
    G2MBSourceV1(source_ref, source_version, candidate_ref, chart_map, mesh, faces, profile,
                 units, authority, canonical_hash(body); field_space=field_space,
                 q1_interpretation=q1_interpretation,
                 boundary_coverage=boundary_coverage, region_interface=region_interface,
                 region_exterior_owners=region_exterior_owners)
end

function semantic_view(x::G2MBSourceV1)
    body = (source_ref=x.source_ref, source_version=x.source_version, candidate_ref=x.candidate_ref,
        chart_map=x.chart_map, mesh=x.mesh, faces=_g2mb_canonical_faces(x.faces), profile=x.profile,
        units=x.units, authority=x.authority)
    if x.field_space !== nothing || x.q1_interpretation !== nothing
        body = merge(body, (field_space=x.field_space,
            q1_interpretation=x.q1_interpretation))
    end
    x.boundary_coverage === nothing ||
        (body = merge(body, (boundary_coverage=x.boundary_coverage,)))
    x.region_interface === nothing ||
        (body = merge(body, (region_interface=x.region_interface,
            region_exterior_owners=x.region_exterior_owners)))
    merge(body, (source_hash=x.source_hash,))
end
canonical_json(x::G2MBSourceV1) = canonical_json(semantic_view(x))

struct G2MBAdmissionV1
    status::Symbol
    structural_status::Symbol
    metric_status::Symbol
    mesh_status::Symbol
    boundary_status::Symbol
    resolution::Symbol
    error_code::Symbol
    error_path::String
    errors::Tuple{Vararg{String}}
    gaps::Tuple{Vararg{String}}
    exception_type::Union{Nothing,DataType}
end

semantic_view(x::G2MBAdmissionV1) =
    (status=x.status, structural_status=x.structural_status, metric_status=x.metric_status,
     mesh_status=x.mesh_status, boundary_status=x.boundary_status, resolution=x.resolution,
     error_code=x.error_code, error_path=x.error_path, errors=x.errors, gaps=x.gaps,
     exception_type=x.exception_type === nothing ? nothing : string(x.exception_type))
canonical_json(x::G2MBAdmissionV1) = canonical_json(semantic_view(x))

function _g2mb_expected_normal(face::Symbol)
    face === :x_min && return (-1, 0, 0)
    face === :x_max && return (1, 0, 0)
    face === :y_min && return (0, -1, 0)
    face === :y_max && return (0, 1, 0)
    face === :z_min && return (0, 0, -1)
    face === :z_max && return (0, 0, 1)
    throw(ArgumentError("unsupported face"))
end

function _g2mb_validate_source(x::G2MBSourceV1)
    errors = String[]
    gaps = String[]
    body = _g2mb_source_body(x.source_ref, x.source_version, x.candidate_ref, x.chart_map,
        x.mesh, x.faces, x.profile, x.units, x.authority;
        field_space=x.field_space, q1_interpretation=x.q1_interpretation,
        boundary_coverage=x.boundary_coverage, region_interface=x.region_interface,
        region_exterior_owners=x.region_exterior_owners)
    try
        _g2mb_validate_field_space(x.field_space, x.q1_interpretation,
            x.mesh, x.profile, x.units)
    catch
        push!(errors, "field_space_contract_invalid")
    end
    try
        _g2mb_validate_boundary_coverage(x.boundary_coverage,
            x.chart_map, x.faces, x.profile)
    catch
        push!(errors, "boundary_coverage_contract_invalid")
    end
    if x.region_interface !== nothing
        try
            _g2mb_validate_region_interface(x.region_interface, x.chart_map,
                x.region_exterior_owners)
            all(f -> f.value.kind === :dirichlet && iszero(f.value.value), x.faces) ||
                push!(errors, "region_exterior_boundary_value_mismatch")
        catch
            push!(errors, "region_interface_contract_invalid")
        end
    end
    x.source_hash == canonical_hash(body) || push!(errors, "source_hash_mismatch")
    x.mesh.chart_ref == x.chart_map.chart_ref || push!(errors, "mesh_chart_ref_mismatch")
    append!(errors, g2mb_unit_algebra_errors(x.units))
    g2mb_metric_positive_definite(x.chart_map) || push!(errors, "metric_not_positive_definite")
    g2mb_orientation_positive(x.chart_map) || push!(errors, "chart_orientation_not_preserved")
    if isempty(g2mb_unit_algebra_errors(x.units))
        g2mb_volume_measure(x.chart_map, x.units).orientation === :orientation_preserving ||
            push!(errors, "volume_orientation_reversing")
    end
    length(x.faces) == 6 || push!(errors, "boundary_face_count_mismatch")
    face_ids = Tuple(f.face_id for f in x.faces)
    length(unique(face_ids)) == length(face_ids) || push!(errors, "boundary_face_id_duplicate")
    face_names = Tuple(f.face for f in x.faces)
    expected_faces = (:x_min, :x_max, :y_min, :y_max, :z_min, :z_max)
    Set(face_names) == Set(expected_faces) || push!(errors, "boundary_faces_not_closed")
    length(unique(face_names)) != length(face_names) &&
        push!(errors, "boundary_face_owner_duplicate")
    (x.region_interface === nothing) == (x.region_exterior_owners === nothing) ||
        push!(errors, "region_interface_owner_presence_mismatch")
    for f in x.faces
        expected = _g2mb_expected_normal(f.face)
        Tuple(f.reference_normal) == expected || push!(errors, "reference_face_orientation_mismatch:" * String(f.face))
        f.ownership === :candidate_owned || push!(errors, "boundary_owner_not_candidate_owned:" * f.face_id)
        expected_unit = f.value.kind === :dirichlet ? x.units.field_value : x.units.flux_value
        f.value.unit == expected_unit || push!(errors, "boundary_value_unit_mismatch:" * f.face_id)
        if isempty(g2mb_unit_algebra_errors(x.units))
            area_measure = g2mb_physical_oriented_area_measure(x.chart_map, f.reference_normal, x.units)
            area_measure.unit == x.units.area && length(area_measure.oriented_vector) == 3 ||
                push!(errors, "physical_area_unit_binding_failed:" * f.face_id)
        end
    end
    x.mesh.execution_status in (:declared, :not_executed) && push!(gaps, "mesh_execution_not_executed")
    x.authority.metric === :unique_match || push!(gaps, "metric_authority=" * String(x.authority.metric))
    x.authority.mesh === :unique_match || push!(gaps, "mesh_authority=" * String(x.authority.mesh))
    x.authority.boundary === :unique_match || push!(gaps, "boundary_authority=" * String(x.authority.boundary))
    unique!(errors); unique!(gaps)
    errors, gaps
end

struct _G2MBControlledFaultV1 <: Exception end
struct _G2MBFaultProbeV1
    source::G2MBSourceV1
end
_g2mb_fault_probe(source::G2MBSourceV1) = _G2MBFaultProbeV1(source)

"""Internal review seam: only the module-owned probe can exercise the catch path."""
function g2mb_admit(probe::_G2MBFaultProbeV1)::G2MBAdmissionV1
    try
        throw(_G2MBControlledFaultV1())
    catch error
        G2MBAdmissionV1(:program_exception, :unknown, :unknown, :unknown, :unknown,
            :terminal_deferred, :unexpected_exception, "/source", (), (), typeof(error))
    end
end

function g2mb_admit(x::Any)::G2MBAdmissionV1
    x isa G2MBSourceV1 || return G2MBAdmissionV1(:fail_closed, :fail_closed, :not_checked,
        :not_checked, :not_checked, :fail_closed, :source_type, "/source", ("source_type",), (), nothing)
    try
        errors, gaps = _g2mb_validate_source(x)
        isempty(errors) || return G2MBAdmissionV1(:fail_closed, :fail_closed,
            :fail_closed, :fail_closed, :fail_closed, :fail_closed, :structural_contradiction,
            "/source", Tuple(errors), Tuple(gaps), nothing)
        if !isempty(gaps)
            return G2MBAdmissionV1(:terminal_deferred, :valid, :valid, :declared,
                :declared, :terminal_deferred, :missing_authority, "/authority", (), Tuple(gaps), nothing)
        end
        G2MBAdmissionV1(:valid, :valid, :valid, :declared, :declared, :resolved,
            :none, "", (), (), nothing)
    catch error
        G2MBAdmissionV1(:program_exception, :unknown, :unknown, :unknown, :unknown,
            :terminal_deferred, :unexpected_exception, "/source", (), (), typeof(error))
    end
end

struct G2MBDeclarationV1
    contract_ref::GenomeContractRef
    source::G2MBSourceV1
    schema_hash::Digest256
    canonicalization_hash::Digest256
    profile_hash::Digest256
    declaration_hash::Digest256
    function G2MBDeclarationV1(contract_ref::Any, source::Any, schema_hash::Any,
                               canonicalization_hash::Any, profile_hash::Any, declaration_hash::Any)
        contract_ref isa GenomeContractRef && contract_ref.version == "v5" ||
            throw(ArgumentError("metric-boundary contract_ref must use v5"))
        source isa G2MBSourceV1 || throw(ArgumentError("source must be G2MBSourceV1"))
        schema_hash == g2mb_schema_hash_v1(source.region_interface !== nothing) || throw(ArgumentError("schema_hash mismatch"))
        canonicalization_hash == g2mb_canonicalization_hash_v1() || throw(ArgumentError("canonicalization_hash mismatch"))
        profile_hash == g2mb_profile_hash_v1(source.profile) || throw(ArgumentError("profile_hash mismatch"))
        contract_ref.schema_hash == schema_hash || throw(ArgumentError("external schema hash mismatch"))
        contract_ref.canonicalization_hash == canonicalization_hash || throw(ArgumentError("external canonicalization hash mismatch"))
        contract_ref.compatibility_profile == g2mb_profile_token_v1(source.profile) ||
            throw(ArgumentError("external profile token mismatch"))
        body = (contract_ref=contract_ref, source=source, schema_hash=schema_hash,
                canonicalization_hash=canonicalization_hash, profile_hash=profile_hash)
        declaration_hash == canonical_hash(body) || throw(ArgumentError("declaration_hash mismatch"))
        new(contract_ref, source, schema_hash, canonicalization_hash, profile_hash, declaration_hash)
    end
end

function g2mb_declaration_v1(contract_ref, source)
    schema = g2mb_schema_hash_v1(source.region_interface !== nothing); canon = g2mb_canonicalization_hash_v1()
    profile = g2mb_profile_hash_v1(source.profile)
    body = (contract_ref=contract_ref, source=source, schema_hash=schema,
            canonicalization_hash=canon, profile_hash=profile)
    G2MBDeclarationV1(contract_ref, source, schema, canon, profile, canonical_hash(body))
end

semantic_view(x::G2MBDeclarationV1) =
    (contract_ref=x.contract_ref, source=x.source, schema_hash=x.schema_hash,
     canonicalization_hash=x.canonicalization_hash, profile_hash=x.profile_hash,
     declaration_hash=x.declaration_hash)
canonical_json(x::G2MBDeclarationV1) = canonical_json(semantic_view(x))
g2mb_declaration_hash_v1(x::G2MBDeclarationV1) = x.declaration_hash

struct G2MBReceiptV1
    declaration_hash::Digest256
    source_hash::Digest256
    schema_hash::Digest256
    canonicalization_hash::Digest256
    profile_hash::Digest256
    review_pending::Bool
    accepted::Bool
    admission_status::Symbol
    resolution::Symbol
    claim_ceiling::Symbol
    gaps::Tuple{Vararg{String}}
    errors::Tuple{Vararg{String}}
    compile_calls::Int
    provider_calls::Int
    mesh_calls::Int
    solver_calls::Int
    physical_evidence::Bool
end

semantic_view(x::G2MBReceiptV1) =
    (declaration_hash=x.declaration_hash, source_hash=x.source_hash, schema_hash=x.schema_hash,
     canonicalization_hash=x.canonicalization_hash, profile_hash=x.profile_hash,
     review_pending=x.review_pending, accepted=x.accepted, admission_status=x.admission_status,
     resolution=x.resolution, claim_ceiling=x.claim_ceiling, gaps=x.gaps, errors=x.errors,
     compile_calls=x.compile_calls, provider_calls=x.provider_calls, mesh_calls=x.mesh_calls,
     solver_calls=x.solver_calls, physical_evidence=x.physical_evidence)
canonical_json(x::G2MBReceiptV1) = canonical_json(semantic_view(x))
g2mb_receipt_hash_v1(x::G2MBReceiptV1) = canonical_hash(x)

function g2mb_receipt_v1(x::G2MBDeclarationV1)
    admission = g2mb_admit(x.source)
    G2MBReceiptV1(x.declaration_hash, x.source.source_hash, x.schema_hash,
        x.canonicalization_hash, x.profile_hash, true, false, admission.status,
        admission.resolution, G2MB_CLAIM_CEILING_V1, admission.gaps, admission.errors,
        0, 0, 0, 0, false)
end

function _g2mb_rebuild(x::G2MBDeclarationV1, source::G2MBSourceV1)
    g2mb_declaration_v1(x.contract_ref, source)
end

function g2mb_edit_source(x::G2MBDeclarationV1, field::Symbol, value)
    s = x.source
    if field === :chart_map && value isa G2MBChartMapV1
        chart_value = value
        if s.chart_map.axes !== nothing && value.axes === nothing
            chart_value = G2MBChartMapV1(value.chart_ref, value.domain_lower,
                value.domain_upper, value.jacobian_rows, value.offset;
                map_kind=value.map_kind, axes=s.chart_map.axes)
        end
        return _g2mb_rebuild(x, g2mb_source_v1(s.source_ref, s.source_version, s.candidate_ref,
            chart_value, s.mesh, s.faces, s.profile, s.units, s.authority;
            field_space=s.field_space, q1_interpretation=s.q1_interpretation,
            boundary_coverage=s.boundary_coverage, region_interface=s.region_interface,
            region_exterior_owners=s.region_exterior_owners))
    elseif field === :mesh && value isa G2MBMeshPlanV1
        return _g2mb_rebuild(x, g2mb_source_v1(s.source_ref, s.source_version, s.candidate_ref,
            s.chart_map, value, s.faces, s.profile, s.units, s.authority;
            field_space=s.field_space, q1_interpretation=s.q1_interpretation,
            boundary_coverage=s.boundary_coverage, region_interface=s.region_interface,
            region_exterior_owners=s.region_exterior_owners))
    elseif field === :face_value && value isa Tuple && length(value) == 2 && value[1] isa String &&
            value[2] isa G2MBFaceValueV1
        faces = Tuple(f.face_id == value[1] ? G2MBFaceOwnerV1(f.face_id, f.face, f.owner_region_id,
            f.reference_normal, value[2]; ownership=f.ownership) : f for f in s.faces)
        any(f.face_id == value[1] for f in s.faces) || throw(ArgumentError("unknown face_id"))
        return _g2mb_rebuild(x, g2mb_source_v1(s.source_ref, s.source_version, s.candidate_ref,
            s.chart_map, s.mesh, faces, s.profile, s.units, s.authority;
            field_space=s.field_space, q1_interpretation=s.q1_interpretation,
            boundary_coverage=s.boundary_coverage, region_interface=s.region_interface,
            region_exterior_owners=s.region_exterior_owners))
    elseif field === :field_space && value isa G2MBFieldSpaceV1
        return _g2mb_rebuild(x, g2mb_source_v1(s.source_ref, s.source_version, s.candidate_ref,
            s.chart_map, s.mesh, s.faces, s.profile, s.units, s.authority;
            field_space=value, q1_interpretation=:continuous_tensor_product_lagrange_degree1_h1,
            boundary_coverage=s.boundary_coverage, region_interface=s.region_interface,
            region_exterior_owners=s.region_exterior_owners))
    end
    throw(ArgumentError("editable source field must be :chart_map, :mesh, :face_value or :field_space"))
end
