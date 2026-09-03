"""G3.1 closed control-observation requirement vocabulary."""

function _g31_text(value::Any, field::String)
    typeof(value) === String || throw(ArgumentError("$field must be String"))
    invoke(isvalid, Tuple{String}, value) || throw(ArgumentError("$field must be valid UTF-8"))
    Core.sizeof(value) > 0 || throw(ArgumentError("$field cannot be empty"))
    value
end

struct ObservationChannelRefV1
    value::String
    function ObservationChannelRefV1(value::Any)
        new(invoke(_g31_text, Tuple{Any,String}, value, "observation channel reference"))
    end
end

Base.:(==)(a::ObservationChannelRefV1, b::ObservationChannelRefV1) =
    invoke(_g31_text_equal, Tuple{String,String}, getfield(a, :value), getfield(b, :value))
Base.hash(a::ObservationChannelRefV1, h::UInt) = hash(getfield(a, :value), h)
semantic_view(a::ObservationChannelRefV1) = (value=getfield(a, :value),)

function _g31_text_equal(a::String, b::String)
    Core.sizeof(a) == Core.sizeof(b) || return false
    invoke(isequal, Tuple{String,String}, a, b)
end
