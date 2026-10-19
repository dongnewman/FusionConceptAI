using Test, SHA, JSON3, Dates

const R26_ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", ".."))
const R26_FIXTURE_SOURCE = joinpath(R26_ROOT,
    "test/GenomeV5/Integration/vnext_t1_candidate_state_package_v5_next_formal_v2_tests.jl")

# Load the original R25 fixture/helper definitions without executing either
# formal testset.  This intentionally matches the retained R25 observation.
const R26_DEFINITION_OMISSIONS = Dict("testsets" => 0, "printlns" => 0)
Base.include(Main, R26_FIXTURE_SOURCE) do expression
    if expression isa Expr
        if expression.head === :macrocall && string(expression.args[1]) == "@testset"
            R26_DEFINITION_OMISSIONS["testsets"] += 1
            return nothing
        elseif expression.head === :call && expression.args[1] === :println
            R26_DEFINITION_OMISSIONS["printlns"] += 1
            return nothing
        end
    end
    expression
end

length(ARGS) == 2 && ARGS[1] == "--observe" ||
    error("usage: --observe <fresh-evidence-dir>")
const R26_OUT = normpath(abspath(ARGS[2]))
isdir(R26_OUT) || error("recorder must create the evidence directory")
ispath(joinpath(R26_OUT, "observation.json")) && error("observation already exists")

println("R26_STAGE utc=", Dates.now(Dates.UTC), " stage=fixture_before"); flush(stdout)
fixture = _t1_fixture()
println("R26_STAGE utc=", Dates.now(Dates.UTC), " stage=fixture_after"); flush(stdout)

absent_g3 = G.VNextT0LocalAbsentDeclarationV1(:G3, _T1_CANDIDATE,
    :missing_material, :terminal_deferred)
println("R26_STAGE utc=", Dates.now(Dates.UTC), " stage=recheck_before"); flush(stdout)
observed = G.vnext_declaration_authority_recheck_local_v1(
    G.VNextAuthorityRecheckLocalInputV1(_T1_CANDIDATE, fixture.transport,
        (fixture.declarations[1], fixture.declarations[2], absent_g3)))
println("R26_STAGE utc=", Dates.now(Dates.UTC), " stage=recheck_after"); flush(stdout)

# Save finite, compact metadata before making any semantic assertion.  Avoid
# formatting the full result because it owns the multi-megabyte canonical wire.
metadata = (
    observed_type=string(typeof(observed)),
    output_type=string(typeof(observed.output)),
    status=observed.status,
    resolution=observed.resolution,
    accepted=observed.accepted,
    claim_ceiling=observed.claim_ceiling,
    errors=observed.errors,
    errors_length=length(observed.errors),
    prior_bundle_bytes_length=length(observed.prior_bundle_bytes),
    prior_bundle_sha256=observed.prior_bundle_sha256.value,
    transport_bundle_sha256=fixture.transport.bundle_hash.value,
    transport_g3_type=string(typeof(fixture.transport.declarations[3])),
    local_g3_type=string(typeof(absent_g3)),
    definition_omissions=R26_DEFINITION_OMISSIONS,
    fixture_source_sha256=uppercase(bytes2hex(sha256(read(R26_FIXTURE_SOURCE)))),
    recorded_before_assertions=true,
    formal_T1=false,
)
open(joinpath(R26_OUT, "observation.json"), "w") do io
    JSON3.write(io, metadata)
    flush(io)
end
println("R26_OBSERVATION_SAVED status=", observed.status,
    " resolution=", observed.resolution,
    " errors_length=", length(observed.errors),
    " observed_type=", nameof(typeof(observed))); flush(stdout)

@testset "R26 retained R25 mismatch classification" begin
    @test R26_DEFINITION_OMISSIONS == Dict("testsets" => 2, "printlns" => 5)
    @test observed.status === :fail_closed
    @test observed.resolution === :none
    @test observed.accepted === false
    @test observed.claim_ceiling === :contract_only
    @test observed.output === nothing
    @test observed.errors == (:record_bundle_canonical_mismatch,)
    @test typeof(observed) === G.VNextAuthorityRecheckLocalResultV1{Nothing}
end

println("R26_OBSERVATION_PASS formal_T1=false repair_applied=false"); flush(stdout)
