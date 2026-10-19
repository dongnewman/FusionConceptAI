using Test, SHA, Dates
using FusionConceptAI
const G = FusionConceptAI
const ORIGINAL = joinpath(@__DIR__, "..", "vnext_t1_candidate_state_package_v5_next_tests.jl")
bytes2hex(sha256(read(ORIGINAL))) == "970976c4122fc6b4f5303d6763c286514b1c9dc653aba36d46e1d003bcbf9669" || error("frozen test changed")

# Definition-only loading, not a regression or assertion-coverage substitute.
definitions_only = expression -> begin
    if expression isa Expr
        expression.head === :macrocall && string(expression.args[1]) == "@testset" && return nothing
        expression.head === :call && expression.args[1] === :println && return nothing
    end
    expression
end
Base.include(definitions_only, Main, ORIGINAL)

function mark(stage, n)
    println("R18_DEEPCOPY stage=$stage n=$n utc=", Dates.now(Dates.UTC))
    flush(stdout)
end

# The largest length equals the actual prior byte-carrier B witnessed by the
# real-fixture gate probe. Pattern bytes isolate the same concrete storage type;
# this is not a claim that they reproduce the source-backed fixture contents.
@testset "R18 native carrier deepcopy mechanism" begin
    for n in (0, 64, 1024, 8_269_571)
        mark("construct_start", n)
        payload = UInt8[mod(i - 1, 251) for i in 1:n]
        original = G.VNextT1CanonicalBytesV1(payload)
        mark("construct_complete", n)
        before_hash = G.canonical_hash(original)
        mark("copy_start", n)
        started = time_ns()
        copied = deepcopy(original)
        seconds = (time_ns() - started) / 1e9
        println("R18_DEEPCOPY_COPY_COMPLETE n=$n seconds=$seconds")
        flush(stdout)
        @test typeof(copied) === typeof(original)
        @test copied.bytes == original.bytes
        @test copied.sha256 == original.sha256
        @test G.canonical_hash(copied) == before_hash
        mark("checks_complete", n)
        GC.gc()
    end
end
println("R18_DEEPCOPY_MECHANISM_PASS"); flush(stdout)
