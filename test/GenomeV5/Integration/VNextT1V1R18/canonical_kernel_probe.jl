using Test, SHA, Dates, Serialization
using FusionConceptAI
const G = FusionConceptAI
const ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", ".."))
Base.include(Main, joinpath(@__DIR__, "..", "vnext_declaration_transport_local_v1_tests.jl"))
Base.include(G, joinpath(ROOT, "src/GenomeV5/Integration/VNextDeclarationAuthorityRecheckLocalV1.jl"))
Base.include(G, joinpath(ROOT, "src/Contracts/CandidateStatePackageV5Next.jl"))

const TOKENS = String[G._canonical(UInt8(i)) for i in 0:255]
@noinline Base.@nospecializeinfer function bounded_canonical(@nospecialize(x::G.VNextT1CanonicalBytesV1))
    io = IOBuffer()
    write(io, "{\"bytes\":[")
    bytes = x.bytes
    for i in 1:length(bytes)
        i == 1 || write(io, ',')
        write(io, TOKENS[Int(bytes[i]) + 1])
    end
    write(io, "],\"sha256\":")
    write(io, G._canonical(x.sha256))
    write(io, '}')
    String(take!(io))
end

@testset "bounded writer exact legacy canonical parity" begin
    cases = [UInt8[mod(i - 1, 251) for i in 1:n] for n in (0, 1, 63, 64, 65, 1024)]
    append!(cases, [collect(UInt8(0):UInt8(255)), reverse(collect(UInt8(0):UInt8(255))),
        UInt8[0x00, 0xff, 0xc0, 0x80, 0xed, 0xa0, 0x80]])
    for bytes in cases
        owned = G.VNextT1CanonicalBytesV1(bytes)
        legacy = G._canonical(G.semantic_view(owned))
        @test bounded_canonical(owned) == legacy
        @test G.canonical_json(owned) == legacy
        @test G.semantic_view(owned).bytes === owned.bytes
        @test owned.sha256 == G._vnext_t1_sha(bytes)
        io = IOBuffer()
        serialize(io, owned)
        seekstart(io)
        reloaded = deserialize(io)
        @test typeof(reloaded) === typeof(owned)
        @test bounded_canonical(reloaded) == legacy
        changed = copy(bytes)
        isempty(changed) ? push!(changed, 0xff) : (changed[1] ⊻= 0xff)
        mutated = G.VNextT1CanonicalBytesV1(changed)
        @test bounded_canonical(mutated) != bounded_canonical(owned)
        @test mutated.sha256 != owned.sha256
        @test G.canonical_json(mutated) == G._canonical(G.semantic_view(mutated))
    end
end
flush(stdout)

n = 8_269_445
bytes = UInt8[mod(i - 1, 251) for i in 1:n]
owned = G.VNextT1CanonicalBytesV1(bytes)
t0 = time_ns()
text = bounded_canonical(owned)
seconds = (time_ns() - t0) / 1e9
println("CANONICAL_KERNEL_LARGE length=$n canonical_length=$(ncodeunits(text)) seconds=$seconds canonical_sha256=$(bytes2hex(sha256(Vector{UInt8}(codeunits(text))))) byte_sha256=$(owned.sha256.value)")
flush(stdout)
