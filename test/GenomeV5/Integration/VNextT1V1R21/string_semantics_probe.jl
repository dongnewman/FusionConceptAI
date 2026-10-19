using Test, SHA, JSON3

struct StringHolder
    first::String
    second::String
end
Base.@noinline Base.@nospecializeinfer function fallback_copy(@nospecialize(x), stack::IdDict)
    invoke(Base.deepcopy_internal, Tuple{Any,IdDict}, x, stack)
end

rows = Any[]
@testset "R21 String Base semantic comparison" begin
    for n in (0, 1, 64, 1024)
        original = String(UInt8[UInt8(97 + mod(i, 26)) for i in 1:n])
        native_string = deepcopy(original)
        holder = StringHolder(original, original)
        copied = fallback_copy(holder, IdDict())
        native_holder = deepcopy(holder)
        @test typeof(copied.first) === typeof(native_string) === typeof(original)
        @test copied.first == native_string == original
        @test hash(copied.first) == hash(native_string) == hash(original)
        @test (original === copied.first) == (original === native_string)
        pointer_behavior = GC.@preserve original native_string copied native_holder begin
            (candidate_same=pointer(original) == pointer(copied.first),
                native_same=pointer(original) == pointer(native_string),
                holder_native_same=pointer(original) == pointer(native_holder.first),
                candidate_shared=pointer(copied.first) == pointer(copied.second),
                native_shared=pointer(native_holder.first) == pointer(native_holder.second))
        end
        @test pointer_behavior.candidate_same == pointer_behavior.native_same == pointer_behavior.holder_native_same
        @test pointer_behavior.candidate_shared == pointer_behavior.native_shared
        push!(rows, (length=n, runtime_ismutable=ismutable(original),
            original_equals_copied=original === copied.first, pointer_behavior=pointer_behavior))
    end
end
println("R21_STRING_SEMANTICS=", JSON3.write(rows))
