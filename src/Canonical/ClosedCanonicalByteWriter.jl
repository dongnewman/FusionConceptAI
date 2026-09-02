"""Sealed, byte-oriented primitives for canonical JSON writers.

This file intentionally contains no package-level semantic dispatch.  Callers
write validated values to one `IOBuffer`; strings are copied by their UTF-8
bytes and numbers are rendered by the closed routines below.
"""

function _ccbw_new()
    IOBuffer()
end

function _ccbw_byte!(io::Base.GenericIOBuffer, byte::UInt8)
    invoke(write, Tuple{Base.GenericIOBuffer,UInt8}, io, byte)
    io
end

function _ccbw_ascii!(io::Base.GenericIOBuffer, value::String)
    n = Core.sizeof(value)
    GC.@preserve value begin
        ptr = ccall(:jl_string_ptr, Ptr{UInt8}, (Any,), value)
        i = 1
        while i <= n
            b = invoke(unsafe_load, Tuple{Ptr{UInt8},Integer}, ptr, i)
            b < 0x80 || throw(ArgumentError("canonical ASCII text contains non-ASCII bytes"))
            _ccbw_byte!(io, b)
            i += 1
        end
    end
    io
end

function _ccbw_utf8!(io::Base.GenericIOBuffer, value::AbstractString)
    text = typeof(value) === String ? value : invoke(String, Tuple{AbstractString}, value)
    invoke(isvalid, Tuple{String}, text) || throw(ArgumentError("invalid UTF-8 string is not canonical"))
    n = Core.sizeof(text)
    GC.@preserve text begin
        ptr = ccall(:jl_string_ptr, Ptr{UInt8}, (Any,), text)
        i = 1
        while i <= n
            _ccbw_byte!(io, invoke(unsafe_load, Tuple{Ptr{UInt8},Integer}, ptr, i))
            i += 1
        end
    end
    io
end

function _ccbw_quote!(io::Base.GenericIOBuffer, value::AbstractString)
    text = typeof(value) === String ? value : invoke(String, Tuple{AbstractString}, value)
    invoke(isvalid, Tuple{String}, text) || throw(ArgumentError("invalid UTF-8 string is not canonical"))
    _ccbw_byte!(io, UInt8('"'))
    n = Core.sizeof(text)
    GC.@preserve text begin
        ptr = ccall(:jl_string_ptr, Ptr{UInt8}, (Any,), text)
        i = 1
        while i <= n
            b = invoke(unsafe_load, Tuple{Ptr{UInt8},Integer}, ptr, i)
            if b == 0x22
                _ccbw_ascii!(io, "\\\"")
            elseif b == 0x5c
                _ccbw_ascii!(io, "\\\\")
            elseif b == 0x08
                _ccbw_ascii!(io, "\\b")
            elseif b == 0x0c
                _ccbw_ascii!(io, "\\f")
            elseif b == 0x0a
                _ccbw_ascii!(io, "\\n")
            elseif b == 0x0d
                _ccbw_ascii!(io, "\\r")
            elseif b == 0x09
                _ccbw_ascii!(io, "\\t")
            elseif b < 0x20
                _ccbw_ascii!(io, "\\u00")
                _ccbw_hex2!(io, b)
            else
                _ccbw_byte!(io, b)
            end
            i += 1
        end
    end
    _ccbw_byte!(io, UInt8('"'))
    io
end

function _ccbw_hex2!(io::Base.GenericIOBuffer, byte::UInt8)
    hi = byte >> 0x04
    lo = byte & 0x0f
    _ccbw_byte!(io, hi < 0x0a ? UInt8('0') + hi : UInt8('a') + (hi - 0x0a))
    _ccbw_byte!(io, lo < 0x0a ? UInt8('0') + lo : UInt8('a') + (lo - 0x0a))
    io
end

function _ccbw_uint64!(io::Base.GenericIOBuffer, value::UInt64)
    digits = Vector{UInt8}(undef, 20)
    n = value
    count = 0
    while n >= UInt64(10)
        count += 1
        Core.arrayset(true, digits, UInt8('0') + UInt8(invoke(rem, Tuple{UInt64,UInt64}, n, UInt64(10))), count)
        n = invoke(div, Tuple{UInt64,UInt64}, n, UInt64(10))
    end
    count += 1
    Core.arrayset(true, digits, UInt8('0') + UInt8(n), count)
    while count >= 1
        _ccbw_byte!(io, Core.arrayref(true, digits, count))
        count -= 1
    end
    io
end

function _ccbw_uint128!(io::Base.GenericIOBuffer, value::UInt128)
    digits = Vector{UInt8}(undef, 39)
    n = value
    count = 0
    while n >= UInt128(10)
        count += 1
        Core.arrayset(true, digits, UInt8('0') + UInt8(invoke(rem, Tuple{UInt128,UInt128}, n, UInt128(10))), count)
        n = invoke(div, Tuple{UInt128,UInt128}, n, UInt128(10))
    end
    count += 1
    Core.arrayset(true, digits, UInt8('0') + UInt8(n), count)
    while count >= 1
        _ccbw_byte!(io, Core.arrayref(true, digits, count))
        count -= 1
    end
    io
end

function _ccbw_int64!(io::Base.GenericIOBuffer, value::Int64)
    if value < 0
        _ccbw_byte!(io, UInt8('-'))
        magnitude = UInt64(0) - reinterpret(UInt64, value)
        return _ccbw_uint64!(io, magnitude)
    end
    _ccbw_uint64!(io, UInt64(value))
end

function _ccbw_int128!(io::Base.GenericIOBuffer, value::Int128)
    if value < 0
        _ccbw_byte!(io, UInt8('-'))
        magnitude = UInt128(0) - reinterpret(UInt128, value)
        return _ccbw_uint128!(io, magnitude)
    end
    _ccbw_uint128!(io, UInt128(value))
end

function _ccbw_integer!(io::Base.GenericIOBuffer, value::Integer)
    T = typeof(value)
    (T === Int8 || T === Int16 || T === Int32 || T === Int64 || T === Int128 ||
        T === UInt8 || T === UInt16 || T === UInt32 || T === UInt64 || T === UInt128) ||
        throw(ArgumentError("unsealed integer in canonical payload"))
    if T === Int128
        _ccbw_int128!(io, value)
    elseif T <: Signed
        value isa Int64 ? _ccbw_int64!(io, value) : _ccbw_int64!(io, Int64(value))
    elseif T === UInt128
        _ccbw_uint128!(io, value)
    else
        _ccbw_uint64!(io, UInt64(value))
    end
end

function _ccbw_finish(io::Base.GenericIOBuffer)
    invoke(String, Tuple{Vector{UInt8}}, invoke(take!, Tuple{Base.GenericIOBuffer}, io))
end
