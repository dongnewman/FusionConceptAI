"""Region and oriented-interface ownership for the G2 V5 contract."""

function _g2v5_rational(value::Any, field::AbstractString)::Rational{Int64}
    value isa Rational{Int64} ||
        throw(ArgumentError("$field requires Rational{Int64}; use exact coordinates"))
    denominator(value) > 0 || throw(ArgumentError("$field denominator must be positive"))
    value
end

function _g2v5_bounds3(value::Any, field::AbstractString)
    value isa Tuple && !(value isa NamedTuple) && length(value) == 3 ||
        throw(ArgumentError("$field must be an immutable 3-tuple"))
    ntuple(i -> _g2v5_rational(value[i], "$field[$i]"), 3)
end

function _g2v5_symbol(value::Any, field::AbstractString, allowed::Tuple)
    value isa Symbol && value in allowed ||
        throw(ArgumentError("$field must be one of $(allowed)"))
    value
end

struct G2RegionV2
    region_id::String
    lower::NTuple{3,Rational{Int64}}
    upper::NTuple{3,Rational{Int64}}
    chart_ref::QualifiedRefV1
    embedding_ref::QualifiedRefV1
    field_space_ref::QualifiedRefV1
    boundary_kinds::Tuple{Vararg{Symbol}}
    function G2RegionV2(region_id::Any, lower::Any, upper::Any,
                        chart_ref::Any, embedding_ref::Any, field_space_ref::Any,
                        boundary_kinds::Any)
        id = _g2v5_text(region_id, "region_id")
        lo = _g2v5_bounds3(lower, "lower")
        hi = _g2v5_bounds3(upper, "upper")
        all(lo[i] < hi[i] for i in 1:3) ||
            throw(ArgumentError("region bounds must be strictly ordered in all axes"))
        cr = _g2v5_v2_qref(chart_ref, "chart_ref")
        er = _g2v5_v2_qref(embedding_ref, "embedding_ref")
        fr = _g2v5_v2_qref(field_space_ref, "field_space_ref")
        bk = _g2v5_symbol_tuple(boundary_kinds, "boundary_kinds")
        new(id, lo, hi, cr, er, fr, bk)
    end
end

semantic_view(x::G2RegionV2) =
    (region_id=x.region_id, lower=x.lower, upper=x.upper,
     chart_ref=x.chart_ref, embedding_ref=x.embedding_ref,
     field_space_ref=x.field_space_ref, boundary_kinds=x.boundary_kinds)
Base.:(==)(a::G2RegionV2, b::G2RegionV2) = semantic_view(a) == semantic_view(b)
Base.hash(a::G2RegionV2, h::UInt) = hash(semantic_view(a), h)
canonical_json(x::G2RegionV2) = canonical_json(semantic_view(x))

struct G2InterfaceV2
    interface_ref::QualifiedRefV1
    left_region_id::String
    right_region_id::String
    axis::Int8
    coordinate::Rational{Int64}
    normal::Int8
    continuity::Symbol
    transfer_kind::Symbol
    function G2InterfaceV2(interface_ref::Any, left_region_id::Any,
                            right_region_id::Any, axis::Any, coordinate::Any,
                            normal::Any, continuity::Any, transfer_kind::Any)
        ir = _g2v5_v2_qref(interface_ref, "interface_ref")
        left = _g2v5_text(left_region_id, "left_region_id")
        right = _g2v5_text(right_region_id, "right_region_id")
        left != right || throw(ArgumentError("interface regions must be distinct"))
        axis isa Integer && !(axis isa Bool) && 1 <= axis <= 3 ||
            throw(ArgumentError("interface axis must be an integer in 1:3"))
        normal isa Integer && !(normal isa Bool) && abs(normal) == 1 ||
            throw(ArgumentError("interface normal must be -1 or +1"))
        continuity isa Symbol || throw(ArgumentError("continuity must be a Symbol"))
        transfer_kind isa Symbol || throw(ArgumentError("transfer_kind must be a Symbol"))
        new(ir, left, right, Int8(axis), _g2v5_rational(coordinate, "coordinate"),
            Int8(normal), continuity, transfer_kind)
    end
end

semantic_view(x::G2InterfaceV2) =
    (interface_ref=x.interface_ref, left_region_id=x.left_region_id,
     right_region_id=x.right_region_id, axis=x.axis, coordinate=x.coordinate,
     normal=x.normal, continuity=x.continuity, transfer_kind=x.transfer_kind)
Base.:(==)(a::G2InterfaceV2, b::G2InterfaceV2) = semantic_view(a) == semantic_view(b)
Base.hash(a::G2InterfaceV2, h::UInt) = hash(semantic_view(a), h)
canonical_json(x::G2InterfaceV2) = canonical_json(semantic_view(x))

struct RegionInterfaceContractV2
    regions::Tuple{Vararg{G2RegionV2}}
    interfaces::Tuple{Vararg{G2InterfaceV2}}
    function RegionInterfaceContractV2(regions::Any, interfaces::Any)
        rs = _g2v5_tuple(regions, "regions")
        is = _g2v5_tuple(interfaces, "interfaces")
        2 <= length(rs) <= 8 || throw(ArgumentError("G2 V5 requires 2:8 regions"))
        all(x -> x isa G2RegionV2, rs) || throw(ArgumentError("regions must contain G2RegionV2"))
        all(x -> x isa G2InterfaceV2, is) || throw(ArgumentError("interfaces must contain G2InterfaceV2"))
        region_ids = Tuple(x.region_id for x in rs)
        length(unique(region_ids)) == length(region_ids) ||
            throw(ArgumentError("region ids must be unique"))
        # Duplicate interface declarations remain representable so the single
        # admission pass can classify them as invalid_closure instead of
        # converting a candidate-construction error into an opaque exception.
        new(rs, is)
    end
end

semantic_view(x::RegionInterfaceContractV2) =
    (regions=x.regions, interfaces=x.interfaces)
canonical_json(x::RegionInterfaceContractV2) = canonical_json(semantic_view(x))
g2_region_interface_hash(x::RegionInterfaceContractV2)::Digest256 = canonical_hash(x)
