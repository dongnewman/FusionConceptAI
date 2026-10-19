using SHA, Test, Dates

@noinline Base.@nospecializeinfer function bounded_tuple_sha(@nospecialize(bytes::Tuple{Vararg{UInt8}}))
    copied = Vector{UInt8}(undef, length(bytes))
    for i in eachindex(copied)
        copied[i] = bytes[i]
    end
    SHA.sha256(copied)
end

struct BoundedTupleCarrier{N}
    bytes::NTuple{N,UInt8}
    sha256::Vector{UInt8}
    @noinline Base.@nospecializeinfer function BoundedTupleCarrier(@nospecialize(bytes::Tuple{Vararg{UInt8}}))
        new{length(bytes)}(bytes, bounded_tuple_sha(bytes))
    end
end
@noinline Base.@nospecializeinfer function BoundedTupleCarrier(@nospecialize(bytes::AbstractVector{UInt8}))
    BoundedTupleCarrier(Tuple(UInt8.(bytes)))
end

println("PROBE_LOADED utc=", Dates.now(Dates.UTC)); flush(stdout)
for n in (0, 1, 63, 64, 65, 1024, 8_269_445)
    vector = UInt8[mod(i - 1, 251) for i in 1:n]
    t0 = time_ns()
    tuple = Tuple(vector)
    t1 = time_ns()
    hashed = bounded_tuple_sha(tuple)
    t2 = time_ns()
    carrier1 = BoundedTupleCarrier(tuple)
    t3 = time_ns()
    carrier2 = BoundedTupleCarrier(vector)
    t4 = time_ns()
    @test hashed == SHA.sha256(vector)
    @test carrier1.bytes === tuple
    @test carrier2.bytes == tuple
    @test typeof(carrier2.bytes) === typeof(tuple)
    @test carrier1.sha256 == carrier2.sha256 == hashed
    if n > 0
        vector[1] ⊻= 0xff
        @test carrier2.bytes == tuple
    end
    println("BYTE_KERNEL_PASS n=$n tuple_s=$((t1-t0)/1e9) sha_s=$((t2-t1)/1e9) tuple_ctor_s=$((t3-t2)/1e9) vector_ctor_s=$((t4-t3)/1e9)")
    flush(stdout)
end
