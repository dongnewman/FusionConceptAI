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

struct G2MBChartMapV1
    chart_ref::QualifiedRefV1
    domain_lower::NTuple{3,Rational{Int64}}
    domain_upper::NTuple{3,Rational{Int64}}
    jacobian_rows::NTuple{3,NTuple{3,Rational{Int64}}}
    offset::NTuple{3,Rational{Int64}}
    map_kind::Symbol
    function G2MBChartMapV1(chart_ref::Any, domain_lower::Any, domain_upper::Any,
                            jacobian_rows::Any, offset::Any; map_kind=:affine)
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
        new(chart_ref, lower, upper, rows, shift, map_kind)
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

semantic_view(x::G2MBChartMapV1) =
    (chart_ref=x.chart_ref, domain_lower=x.domain_lower, domain_upper=x.domain_upper,
     jacobian_rows=x.jacobian_rows, offset=x.offset, map_kind=x.map_kind)
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
             "reference_coordinate_unit", "derived_geometry_unit_algebra"),
     constraints=("bounded_3d_chart", "J_transpose_J_positive_definite",
                  "unique_face_owner", "dirichlet_or_neumann_value",
                  "reference_coordinate_dimensionless", "coordinate_J_L_metric_L2_area_L2_volume_L3",
                  "fail_closed_contradiction", "terminal_deferred_missing_authority"))
const G2MB_CANONICALIZATION_DESCRIPTOR_V1 =
    (domain="fusionconceptai:g2:metric-boundary:v1", encoding="canonical_json_named_tuple",
     coordinate_type="Rational{Int64}", matrix_order="row_major", face_order="lexical")

g2mb_schema_hash_v1()::Digest256 = canonical_hash(G2MB_SCHEMA_DESCRIPTOR_V1)
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
    source_hash::Digest256
    function G2MBSourceV1(source_ref::Any, source_version::Any, candidate_ref::Any,
                          chart_map::Any, mesh::Any, faces::Any, profile::Any,
                          units::Any, authority::Any, source_hash::Any)
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
        body = (source_ref=source_ref, source_version=source_version, candidate_ref=candidate_ref,
                chart_map=chart_map, mesh=mesh, faces=Tuple(faces), profile=profile,
                units=units, authority=authority)
        source_hash == canonical_hash(body) || throw(ArgumentError("source_hash does not match source body"))
        new(source_ref, source_version, candidate_ref, chart_map, mesh, Tuple(faces), profile,
            units, authority, source_hash)
    end
end

function g2mb_source_v1(source_ref, source_version, candidate_ref, chart_map, mesh, faces,
                        profile, units, authority)
    body = (source_ref=source_ref, source_version=source_version, candidate_ref=candidate_ref,
            chart_map=chart_map, mesh=mesh, faces=Tuple(faces), profile=profile,
            units=units, authority=authority)
    G2MBSourceV1(source_ref, source_version, candidate_ref, chart_map, mesh, faces, profile,
                 units, authority, canonical_hash(body))
end

semantic_view(x::G2MBSourceV1) =
    (source_ref=x.source_ref, source_version=x.source_version, candidate_ref=x.candidate_ref,
     chart_map=x.chart_map, mesh=x.mesh, faces=x.faces, profile=x.profile,
     units=x.units, authority=x.authority, source_hash=x.source_hash)
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
    body = (source_ref=x.source_ref, source_version=x.source_version, candidate_ref=x.candidate_ref,
            chart_map=x.chart_map, mesh=x.mesh, faces=x.faces, profile=x.profile,
            units=x.units, authority=x.authority)
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
    length(unique(face_names)) == length(face_names) || push!(errors, "boundary_face_owner_duplicate")
    expected_faces = (:x_min, :x_max, :y_min, :y_max, :z_min, :z_max)
    Set(face_names) == Set(expected_faces) || push!(errors, "boundary_faces_not_closed")
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
        schema_hash == g2mb_schema_hash_v1() || throw(ArgumentError("schema_hash mismatch"))
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
    schema = g2mb_schema_hash_v1(); canon = g2mb_canonicalization_hash_v1()
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
        return _g2mb_rebuild(x, g2mb_source_v1(s.source_ref, s.source_version, s.candidate_ref,
            value, s.mesh, s.faces, s.profile, s.units, s.authority))
    elseif field === :mesh && value isa G2MBMeshPlanV1
        return _g2mb_rebuild(x, g2mb_source_v1(s.source_ref, s.source_version, s.candidate_ref,
            s.chart_map, value, s.faces, s.profile, s.units, s.authority))
    elseif field === :face_value && value isa Tuple && length(value) == 2 && value[1] isa String &&
            value[2] isa G2MBFaceValueV1
        faces = Tuple(f.face_id == value[1] ? G2MBFaceOwnerV1(f.face_id, f.face, f.owner_region_id,
            f.reference_normal, value[2]; ownership=f.ownership) : f for f in s.faces)
        any(f.face_id == value[1] for f in s.faces) || throw(ArgumentError("unknown face_id"))
        return _g2mb_rebuild(x, g2mb_source_v1(s.source_ref, s.source_version, s.candidate_ref,
            s.chart_map, s.mesh, faces, s.profile, s.units, s.authority))
    end
    throw(ArgumentError("editable source field must be :chart_map, :mesh or :face_value"))
end
