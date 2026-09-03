"""Closed canonical bytes for the G1 ObservableGeneV1 value."""

const _G1_OBSERVABLE_CANONICAL_DOMAIN = "fusionconceptai:v4:g1-primitive:v1"

function _g1_observable_write_qualified!(io::Base.GenericIOBuffer, value::QualifiedRefV1)
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, "{\"id\":")
    invoke(_ccbw_quote!, Tuple{Base.GenericIOBuffer,AbstractString}, io, getfield(value, :id))
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, ",\"version\":")
    invoke(_ccbw_quote!, Tuple{Base.GenericIOBuffer,AbstractString}, io, getfield(value, :version))
    invoke(_ccbw_byte!, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x7d))
    nothing
end

function _g1_observable_write_gene_ref!(io::Base.GenericIOBuffer, value::String)
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, "{\"value\":")
    invoke(_ccbw_quote!, Tuple{Base.GenericIOBuffer,AbstractString}, io, value)
    invoke(_ccbw_byte!, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x7d))
    nothing
end

function _g1_observable_write_rational!(io::Base.GenericIOBuffer, value::Rational{Int64})
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, "{\"denominator\":")
    invoke(_ccbw_int64!, Tuple{Base.GenericIOBuffer,Int64}, io, getfield(value, :den))
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, ",\"numerator\":")
    invoke(_ccbw_int64!, Tuple{Base.GenericIOBuffer,Int64}, io, getfield(value, :num))
    invoke(_ccbw_byte!, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x7d))
    nothing
end

function _g1_observable_write_unit!(io::Base.GenericIOBuffer, value::UnitSignature)
    exponents = getfield(value, :exponents)
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, "{\"exponents\":[")
    count = fieldcount(typeof(exponents))
    i = 1
    while i <= count
        i > 1 && invoke(_ccbw_byte!, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x2c))
        invoke(_g1_observable_write_rational!, Tuple{Base.GenericIOBuffer,Rational{Int64}}, io,
               getfield(exponents, i))
        i += 1
    end
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, "]}")
    nothing
end

function _g1_observable_write_time_kind!(io::Base.GenericIOBuffer, value::TimeKindV1)
    text = value === static_time ? "\"static_time\"" :
           value === algebraic_time ? "\"algebraic_time\"" :
           value === differential_time ? "\"differential_time\"" :
           value === discrete_time ? "\"discrete_time\"" :
           value === event_time ? "\"event_time\"" :
           throw(ArgumentError("unknown temporal kind"))
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, text)
    nothing
end

function _g1_observable_write_temporal!(io::Base.GenericIOBuffer, value::TemporalTypeV1)
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, "{\"clock_ref\":")
    clock = getfield(value, :clock_ref)
    if clock === nothing
        invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, "null")
    else
        invoke(_g1_observable_write_qualified!, Tuple{Base.GenericIOBuffer,QualifiedRefV1}, io, clock)
    end
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, ",\"derivative_order\":")
    invoke(_ccbw_uint64!, Tuple{Base.GenericIOBuffer,UInt64}, io, UInt64(getfield(value, :derivative_order)))
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, ",\"kind\":")
    invoke(_g1_observable_write_time_kind!, Tuple{Base.GenericIOBuffer,TimeKindV1}, io, getfield(value, :kind))
    invoke(_ccbw_byte!, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x7d))
    nothing
end

function _g1_observable_write_physical_type!(io::Base.GenericIOBuffer, value::PhysicalType)
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, "{\"spatial_dimension\":")
    invoke(_ccbw_int64!, Tuple{Base.GenericIOBuffer,Int64}, io, Int64(getfield(value, :spatial_dimension)))
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, ",\"tensor_rank\":")
    invoke(_ccbw_int64!, Tuple{Base.GenericIOBuffer,Int64}, io, Int64(getfield(value, :tensor_rank)))
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, ",\"temporal_type\":")
    invoke(_g1_observable_write_temporal!, Tuple{Base.GenericIOBuffer,TemporalTypeV1}, io,
           getfield(value, :temporal_type))
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, ",\"units\":")
    invoke(_g1_observable_write_unit!, Tuple{Base.GenericIOBuffer,UnitSignature}, io, getfield(value, :units))
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, ",\"value_kind\":")
    kind = invoke(String, Tuple{Symbol}, getfield(value, :value_kind))
    invoke(_ccbw_quote!, Tuple{Base.GenericIOBuffer,AbstractString}, io, kind)
    invoke(_ccbw_byte!, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x7d))
    nothing
end

function _g1_observable_write_interval_payload!(io::Base.GenericIOBuffer,
                                                value::ExactFiniteIntervalV1)
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, "{\"allow_equal\":")
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io,
           getfield(value, :allow_equal) ? "true" : "false")
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, ",\"lower\":")
    invoke(_g1_observable_write_rational!, Tuple{Base.GenericIOBuffer,Rational{Int64}}, io,
           getfield(value, :lower))
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, ",\"upper\":")
    invoke(_g1_observable_write_rational!, Tuple{Base.GenericIOBuffer,Rational{Int64}}, io,
           getfield(value, :upper))
    invoke(_ccbw_byte!, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x7d))
    nothing
end

function _g1_observable_write_quantity_interval!(io::Base.GenericIOBuffer,
                                                 value::QuantityIntervalV1)
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, "{\"interval\":")
    invoke(_g1_observable_write_interval_payload!, Tuple{Base.GenericIOBuffer,ExactFiniteIntervalV1}, io,
           getfield(value, :interval))
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, ",\"unit\":")
    invoke(_g1_observable_write_unit!, Tuple{Base.GenericIOBuffer,UnitSignature}, io, getfield(value, :unit))
    invoke(_ccbw_byte!, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x7d))
    nothing
end

function _g1_observable_write_nonnegative!(io::Base.GenericIOBuffer,
                                           value::NonnegativeQuantityV1)
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, "{\"unit\":")
    invoke(_g1_observable_write_unit!, Tuple{Base.GenericIOBuffer,UnitSignature}, io, getfield(value, :unit))
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, ",\"value\":")
    invoke(_g1_observable_write_rational!, Tuple{Base.GenericIOBuffer,Rational{Int64}}, io, getfield(value, :value))
    invoke(_ccbw_byte!, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x7d))
    nothing
end

function _g1_observable_write_root!(io::Base.GenericIOBuffer, value::ProgramRootRefV1)
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, "{\"declared_type\":")
    invoke(_g1_observable_write_physical_type!, Tuple{Base.GenericIOBuffer,PhysicalType}, io,
           getfield(value, :declared_type))
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, ",\"operator_site_ref\":")
    invoke(_g1_observable_write_gene_ref!, Tuple{Base.GenericIOBuffer,String}, io,
           getfield(getfield(value, :operator_site_ref), :value))
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, ",\"root_position\":")
    invoke(_ccbw_int64!, Tuple{Base.GenericIOBuffer,Int64}, io, Int64(getfield(value, :root_position)))
    invoke(_ccbw_byte!, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x7d))
    nothing
end

function _g1_observable_encoded_ref(value::QualifiedRefV1)::String
    io = invoke(_ccbw_new, Tuple{})
    invoke(_g1_observable_write_qualified!, Tuple{Base.GenericIOBuffer,QualifiedRefV1}, io, value)
    invoke(_ccbw_finish, Tuple{Base.GenericIOBuffer}, io)
end

function _g1_observable_string_lt(a::String, b::String)
    an = Core.sizeof(a)
    bn = Core.sizeof(b)
    common = an < bn ? an : bn
    GC.@preserve a b begin
        ap = ccall(:jl_string_ptr, Ptr{UInt8}, (Any,), a)
        bp = ccall(:jl_string_ptr, Ptr{UInt8}, (Any,), b)
        i = 1
        while i <= common
            av = invoke(unsafe_load, Tuple{Ptr{UInt8},Integer}, ap, i)
            bv = invoke(unsafe_load, Tuple{Ptr{UInt8},Integer}, bp, i)
            av < bv && return true
            av > bv && return false
            i += 1
        end
    end
    an < bn
end

function _g1_observable_sorted_competitors(value::ObservableGeneV1)
    refs = getfield(value, :competing_prediction_refs)
    count = fieldcount(typeof(refs))
    encoded = Vector{String}(undef, count)
    i = 1
    while i <= count
        Core.arrayset(true, encoded,
            invoke(_g1_observable_encoded_ref, Tuple{QualifiedRefV1}, getfield(refs, i)), i)
        i += 1
    end
    i = 2
    while i <= count
        current = Core.arrayref(true, encoded, i)
        j = i - 1
        while j >= 1 && invoke(_g1_observable_string_lt, Tuple{String,String}, current,
                               Core.arrayref(true, encoded, j))
            Core.arrayset(true, encoded, Core.arrayref(true, encoded, j), j + 1)
            j -= 1
        end
        Core.arrayset(true, encoded, current, j + 1)
        i += 1
    end
    encoded
end

function _g1_write_observable_canonical!(io::Base.GenericIOBuffer, value::ObservableGeneV1)
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io,
           "{\"canonicalization_version\":\"1\",\"domain\":")
    invoke(_ccbw_quote!, Tuple{Base.GenericIOBuffer,AbstractString}, io, _G1_OBSERVABLE_CANONICAL_DOMAIN)
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, ",\"kind\":\"observable_gene\",\"payload\":{")

    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, "\"competing_prediction_refs\":[")
    competitors = invoke(_g1_observable_sorted_competitors, Tuple{ObservableGeneV1}, value)
    count = fieldcount(typeof(getfield(value, :competing_prediction_refs)))
    i = 1
    while i <= count
        i > 1 && invoke(_ccbw_byte!, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x2c))
        invoke(_ccbw_utf8!, Tuple{Base.GenericIOBuffer,AbstractString}, io, Core.arrayref(true, competitors, i))
        i += 1
    end
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, "],\"expected_effect_interval\":")
    invoke(_g1_observable_write_quantity_interval!, Tuple{Base.GenericIOBuffer,QuantityIntervalV1}, io,
           getfield(value, :expected_effect_interval))
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, ",\"expression_root\":")
    invoke(_g1_observable_write_root!, Tuple{Base.GenericIOBuffer,ProgramRootRefV1}, io, getfield(value, :expression_root))
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, ",\"intervention_ref\":")
    invoke(_g1_observable_write_qualified!, Tuple{Base.GenericIOBuffer,QualifiedRefV1}, io, getfield(value, :intervention_ref))
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, ",\"minimum_effect_size\":")
    invoke(_g1_observable_write_nonnegative!, Tuple{Base.GenericIOBuffer,NonnegativeQuantityV1}, io, getfield(value, :minimum_effect_size))
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, ",\"noise_floor\":")
    invoke(_g1_observable_write_nonnegative!, Tuple{Base.GenericIOBuffer,NonnegativeQuantityV1}, io, getfield(value, :noise_floor))
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, ",\"noise_model_ref\":")
    invoke(_g1_observable_write_qualified!, Tuple{Base.GenericIOBuffer,QualifiedRefV1}, io, getfield(value, :noise_model_ref))
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, ",\"numerical_floor\":")
    invoke(_g1_observable_write_nonnegative!, Tuple{Base.GenericIOBuffer,NonnegativeQuantityV1}, io, getfield(value, :numerical_floor))
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, ",\"observable_ref\":")
    invoke(_g1_observable_write_gene_ref!, Tuple{Base.GenericIOBuffer,String}, io,
           getfield(getfield(value, :observable_ref), :value))
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, ",\"sampling_program\":")
    ast = invoke(_typed_ast_program_json, Tuple{TypedASTProgramV1}, getfield(value, :sampling_program))
    invoke(_ccbw_utf8!, Tuple{Base.GenericIOBuffer,AbstractString}, io, ast)
    invoke(_ccbw_byte!, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x7d))
    invoke(_ccbw_byte!, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x7d))
    nothing
end

function _g1_observable_canonical_bytes(value::ObservableGeneV1)::String
    io = invoke(_ccbw_new, Tuple{})
    invoke(_g1_write_observable_canonical!, Tuple{Base.GenericIOBuffer,ObservableGeneV1}, io, value)
    invoke(_ccbw_finish, Tuple{Base.GenericIOBuffer}, io)
end

function _g1_observable_canonical_hash(value::ObservableGeneV1)::Digest256
    invoke(_ccbw_hash_bytes, Tuple{String},
           invoke(_g1_observable_canonical_bytes, Tuple{ObservableGeneV1}, value))
end

canonical_json(value::ObservableGeneV1) =
    invoke(_g1_observable_canonical_bytes, Tuple{ObservableGeneV1}, value)
canonical_hash(value::ObservableGeneV1) =
    invoke(_g1_observable_canonical_hash, Tuple{ObservableGeneV1}, value)
