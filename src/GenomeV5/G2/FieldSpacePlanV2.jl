"""Chart, embedding, field-space, mesh and exterior plans for G2 V5."""

struct G2ChartPlanV2
    chart_ref::QualifiedRefV1
    frame_ref::QualifiedRefV1
    axes::NTuple{3,Symbol}
    map_kind::Symbol
    function G2ChartPlanV2(chart_ref::Any, frame_ref::Any, axes::Any, map_kind::Any)
        cr = _g2v5_v2_qref(chart_ref, "chart_ref")
        fr = _g2v5_v2_qref(frame_ref, "frame_ref")
        ax = _g2v5_symbol_tuple(axes, "axes")
        ax == (:x, :y, :z) || throw(ArgumentError("G2 V5 chart axes must be (:x,:y,:z)"))
        map_kind isa Symbol && map_kind in (:identity, :declared_map) ||
            throw(ArgumentError("map_kind must be :identity or :declared_map"))
        new(cr, fr, ax, map_kind)
    end
end

semantic_view(x::G2ChartPlanV2) =
    (chart_ref=x.chart_ref, frame_ref=x.frame_ref, axes=x.axes, map_kind=x.map_kind)
canonical_json(x::G2ChartPlanV2) = canonical_json(semantic_view(x))

struct G2EmbeddingPlanV2
    embedding_ref::QualifiedRefV1
    chart_ref::QualifiedRefV1
    ambient_dimension::Int
    embedding_kind::Symbol
    function G2EmbeddingPlanV2(embedding_ref::Any, chart_ref::Any,
                               ambient_dimension::Any, embedding_kind::Any)
        er = _g2v5_v2_qref(embedding_ref, "embedding_ref")
        cr = _g2v5_v2_qref(chart_ref, "chart_ref")
        ambient_dimension isa Integer && !(ambient_dimension isa Bool) && ambient_dimension == 3 ||
            throw(ArgumentError("embedding ambient_dimension must be 3"))
        embedding_kind isa Symbol && embedding_kind in (:cartesian_identity, :declared_embedding) ||
            throw(ArgumentError("embedding_kind is not supported by G2 V5"))
        new(er, cr, 3, embedding_kind)
    end
end

semantic_view(x::G2EmbeddingPlanV2) =
    (embedding_ref=x.embedding_ref, chart_ref=x.chart_ref,
     ambient_dimension=x.ambient_dimension, embedding_kind=x.embedding_kind)
canonical_json(x::G2EmbeddingPlanV2) = canonical_json(semantic_view(x))

struct G2FieldSpacePlanV2
    field_space_ref::QualifiedRefV1
    value_shape::Symbol
    continuity::Symbol
    state_unit::String
    function G2FieldSpacePlanV2(field_space_ref::Any, value_shape::Any,
                                continuity::Any, state_unit::Any)
        fr = _g2v5_v2_qref(field_space_ref, "field_space_ref")
        value_shape isa Symbol && value_shape in (:scalar, :vector3) ||
            throw(ArgumentError("value_shape must be :scalar or :vector3"))
        continuity isa Symbol && continuity in (:L2, :H1, :Hdiv, :Hcurl) ||
            throw(ArgumentError("unsupported field-space continuity"))
        unit = _g2v5_text(state_unit, "state_unit")
        new(fr, value_shape, continuity, unit)
    end
end

semantic_view(x::G2FieldSpacePlanV2) =
    (field_space_ref=x.field_space_ref, value_shape=x.value_shape,
     continuity=x.continuity, state_unit=x.state_unit)
canonical_json(x::G2FieldSpacePlanV2) = canonical_json(semantic_view(x))

struct G2MeshPlanV2
    mesh_ref::QualifiedRefV1
    region_ids::Tuple{Vararg{String}}
    cells_per_region::NTuple{3,Int}
    basis::Symbol
    quadrature::Symbol
    execution_status::Symbol
    function G2MeshPlanV2(mesh_ref::Any, region_ids::Any, cells_per_region::Any,
                          basis::Any, quadrature::Any;
                          execution_status::Symbol=:declared_pending)
        mr = _g2v5_v2_qref(mesh_ref, "mesh_ref")
        ids = _g2v5_tuple(region_ids, "region_ids")
        all(x -> x isa String && !isempty(x), ids) ||
            throw(ArgumentError("region_ids must contain non-empty Strings"))
        length(unique(ids)) == length(ids) || throw(ArgumentError("mesh region_ids must be unique"))
        cells_per_region isa Tuple && !(cells_per_region isa NamedTuple) && length(cells_per_region) == 3 ||
            throw(ArgumentError("cells_per_region must be an immutable 3-tuple"))
        cells = ntuple(i -> begin
            cells_per_region[i] isa Integer && !(cells_per_region[i] isa Bool) && cells_per_region[i] >= 1 ||
                throw(ArgumentError("cells_per_region values must be positive integers"))
            Int(cells_per_region[i])
        end, 3)
        basis isa Symbol && basis in (:linear, :quadratic) ||
            throw(ArgumentError("basis must be :linear or :quadratic"))
        quadrature isa Symbol && quadrature in (:declared_pending, :tensor_gauss) ||
            throw(ArgumentError("quadrature must be :declared_pending or :tensor_gauss"))
        execution_status in (:declared_pending, :structural_only, :executable) ||
            throw(ArgumentError("invalid mesh execution_status"))
        new(mr, Tuple(ids), cells, basis, quadrature, execution_status)
    end
end

semantic_view(x::G2MeshPlanV2) =
    (mesh_ref=x.mesh_ref, region_ids=x.region_ids, cells_per_region=x.cells_per_region,
     basis=x.basis, quadrature=x.quadrature, execution_status=x.execution_status)
canonical_json(x::G2MeshPlanV2) = canonical_json(semantic_view(x))

function _g2v5_bounds2(value::Any, field::AbstractString)
    value isa Tuple && !(value isa NamedTuple) && length(value) == 2 ||
        throw(ArgumentError("$field must be an immutable 2-tuple"))
    ntuple(i -> _g2v5_rational(value[i], "$field[$i]"), 2)
end

struct G2BoundaryFacePatchV2
    face::Symbol
    region_id::String
    lower::NTuple{2,Rational{Int64}}
    upper::NTuple{2,Rational{Int64}}
    function G2BoundaryFacePatchV2(face::Any, region_id::Any, lower::Any, upper::Any)
        f = _g2v5_symbol(face, "boundary patch face",
                          (:x_min, :x_max, :y_min, :y_max, :z_min, :z_max))
        id = _g2v5_text(region_id, "boundary patch region_id")
        lo = _g2v5_bounds2(lower, "boundary patch lower")
        hi = _g2v5_bounds2(upper, "boundary patch upper")
        all(lo[i] < hi[i] for i in 1:2) ||
            throw(ArgumentError("boundary patch bounds must be strictly ordered"))
        new(f, id, lo, hi)
    end
end

semantic_view(x::G2BoundaryFacePatchV2) =
    (face=x.face, region_id=x.region_id, lower=x.lower, upper=x.upper)
canonical_json(x::G2BoundaryFacePatchV2) = canonical_json(semantic_view(x))

struct G2ExteriorPlanV2
    exterior_ref::QualifiedRefV1
    boundary_region_ids::Tuple{Vararg{String}}
    boundary_faces::Tuple{Vararg{Symbol}}
    boundary_patches::Tuple{Vararg{G2BoundaryFacePatchV2}}
    boundary_condition::Symbol
    provider_match::Symbol
    function G2ExteriorPlanV2(exterior_ref::Any, boundary_region_ids::Any,
                              boundary_condition::Any, boundary_faces::Any;
                              boundary_patches::Any=(),
                              provider_match::Symbol=:no_match)
        er = _g2v5_v2_qref(exterior_ref, "exterior_ref")
        ids = _g2v5_tuple(boundary_region_ids, "boundary_region_ids")
        all(x -> x isa String && !isempty(x), ids) ||
            throw(ArgumentError("boundary_region_ids must contain non-empty Strings"))
        length(unique(ids)) == length(ids) ||
            throw(ArgumentError("boundary_region_ids must be unique"))
        faces = _g2v5_symbol_tuple(boundary_faces, "boundary_faces")
        all(x -> x in (:x_min, :x_max, :y_min, :y_max, :z_min, :z_max), faces) ||
            throw(ArgumentError("boundary_faces contain an unsupported face"))
        length(unique(faces)) == length(faces) ||
            throw(ArgumentError("boundary_faces must be unique"))
        patches = _g2v5_tuple(boundary_patches, "boundary_patches")
        all(x -> x isa G2BoundaryFacePatchV2, patches) ||
            throw(ArgumentError("boundary_patches must contain G2BoundaryFacePatchV2"))
        boundary_condition isa Symbol && boundary_condition in (:none_declared, :neumann, :dirichlet, :mixed) ||
            throw(ArgumentError("unsupported boundary_condition"))
        boundary_condition != :none_declared || isempty(faces) ||
            throw(ArgumentError("none_declared cannot claim a closed exterior boundary"))
        provider_match in (:unique_match, :no_match, :invalid_signature) ||
            throw(ArgumentError("invalid exterior provider_match"))
        new(er, Tuple(ids), Tuple(faces), Tuple(patches), boundary_condition, provider_match)
    end
end

semantic_view(x::G2ExteriorPlanV2) =
    (exterior_ref=x.exterior_ref, boundary_region_ids=x.boundary_region_ids,
     boundary_faces=x.boundary_faces, boundary_patches=x.boundary_patches,
     boundary_condition=x.boundary_condition,
     provider_match=x.provider_match)
canonical_json(x::G2ExteriorPlanV2) = canonical_json(semantic_view(x))

struct FieldSpacePlanV2
    plan_ref::QualifiedRefV1
    chart::G2ChartPlanV2
    embedding::G2EmbeddingPlanV2
    field_space::G2FieldSpacePlanV2
    mesh::G2MeshPlanV2
    exterior::G2ExteriorPlanV2
    function FieldSpacePlanV2(plan_ref::Any, chart::Any, embedding::Any,
                              field_space::Any, mesh::Any, exterior::Any)
        pr = _g2v5_v2_qref(plan_ref, "plan_ref")
        chart isa G2ChartPlanV2 || throw(ArgumentError("chart must be G2ChartPlanV2"))
        embedding isa G2EmbeddingPlanV2 || throw(ArgumentError("embedding must be G2EmbeddingPlanV2"))
        field_space isa G2FieldSpacePlanV2 || throw(ArgumentError("field_space must be G2FieldSpacePlanV2"))
        mesh isa G2MeshPlanV2 || throw(ArgumentError("mesh must be G2MeshPlanV2"))
        exterior isa G2ExteriorPlanV2 || throw(ArgumentError("exterior must be G2ExteriorPlanV2"))
        embedding.chart_ref == chart.chart_ref ||
            throw(ArgumentError("embedding chart_ref must match chart"))
        new(pr, chart, embedding, field_space, mesh, exterior)
    end
end

semantic_view(x::FieldSpacePlanV2) =
    (plan_ref=x.plan_ref, chart=x.chart, embedding=x.embedding,
     field_space=x.field_space, mesh=x.mesh, exterior=x.exterior)
canonical_json(x::FieldSpacePlanV2) = canonical_json(semantic_view(x))
g2_plan_hash(x::FieldSpacePlanV2)::Digest256 = canonical_hash(x)
