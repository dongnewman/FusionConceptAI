using Test
using FusionConceptAI

module RuntimeV4CoreTestModule
using FusionConceptAI
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "Contracts.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "Compiler.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "Capability.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "Execution.jl"))
end

const R = RuntimeV4CoreTestModule
module RuntimeV4DeclaredFixture
using FusionConceptAI
include(joinpath(@__DIR__, "..", "examples", "runtime_v4_declared_fixture.jl"))
end
const H = digest256_text("runtime-v4-test")

@testset "RuntimeV4 contracts and exact capability closure" begin
    @test R.MinimalityScopeV4(H, H, H, screen_only, ("same-grammar",), ("startup", "hold")).scenario_scope == ("startup", "hold")
    normalized = R.MinimalityScopeV4(H, H, H, screen_only, ("  same-grammar  ",), (" STARTUP ", "hold"))
    canonical = R.MinimalityScopeV4(H, H, H, screen_only, ("same-grammar",), ("STARTUP", "hold"))
    @test normalized.comparison_scope == canonical.comparison_scope
    @test normalized.scenario_scope == canonical.scenario_scope
    @test all(x -> x isa String, normalized.comparison_scope)
    @test all(x -> x isa String, normalized.scenario_scope)
    @test_throws ArgumentError R.MinimalityScopeV4(H, H, H, screen_only, ("  ALL  ",), ("startup",))
    @test_throws ArgumentError R.MinimalityScopeV4(H, H, H, screen_only, ("  WiLdCaRd  ",), ("startup",))
    @test_throws ArgumentError R.MinimalityScopeV4(H, H, H, screen_only, (" a ", "a"), ("startup",))
    @test_throws ArgumentError R.MinimalityScopeV4(H, H, H, screen_only, ("   ",), ("startup",))
    compiled_fixture = R.compile_candidate(RuntimeV4DeclaredFixture.candidate,
        RuntimeV4DeclaredFixture.registry;
        mission_payload=(mission="  declared  ",), bounds_payload=(bounds="  finite  ",),
        comparison_scope=("  declared-grammar  ",), scenario_scope=("  startup  ",))
    @test compiled_fixture.minimality_scope.comparison_scope == ("declared-grammar",)
    @test compiled_fixture.minimality_scope.scenario_scope == ("startup",)
    @test !isempty(compiled_fixture.unresolved_nonterminals)
    @test all(x -> x isa String, compiled_fixture.unresolved_nonterminals)
    @test canonical_hash(compiled_fixture) isa Digest256
    @test_throws ArgumentError R.CapabilitySignatureV4("s", "v", :operator, "op", ("state",), "scalar", "scalar", 0,
        (), "none", "none", "static", ("out",), screen_only, H; coordinate_system="*")
    @test_throws ArgumentError R.CapabilitySignatureV4("s", "v", :operator, "op", ("*",), "scalar", "scalar", 0,
        (), "none", "none", "static", ("out",), screen_only, H)
    @test_throws ArgumentError R.CapabilitySignatureV4("s", "v", :operator, "*", ("state",), "scalar", "scalar", 0,
        (), "none", "none", "static", ("out",), screen_only, H)
    sig = R.CapabilitySignatureV4("schema", "v4", :operator, "identity", ("state",), "scalar", "scalar", 0,
        (), "none_declared", "none_declared", "static", ("out",), screen_only, H)
    provider = R.ProviderManifestV4("schema", "v4", :operator, sig, (bounds_hash=H,), "screen", "backend-v1", H,
        "independent-a", screen_only)
    @test R.match_provider(sig, provider).status == unique_match
    @test R.match_provider(sig, (provider, provider)).status == ambiguous
    altered = R.CapabilitySignatureV4("schema", "v4", :operator, "other", ("state",), "scalar", "scalar", 0,
        (), "none_declared", "none_declared", "static", ("out",), screen_only, H)
    @test R.match_provider(altered, provider).status == no_match
end

@testset "RuntimeV4 hash derivation, cache and fail-closed execution" begin
    sig = R.CapabilitySignatureV4("schema", "v4", :operator, "identity", ("state",), "scalar", "scalar", 0,
        (), "none_declared", "none_declared", "static", ("out",), screen_only, H)
    provider = R.ProviderManifestV4("schema", "v4", :operator, sig, (bounds_hash=H,), "screen", "backend-v1", H,
        "independent-a", screen_only)
    subject = R.ExecutablePhysicalSubjectV4(H, H, H, H, (("gain", 1),), ((scenario=:startup,),),
        (declared=true,), (sig,))
    changed = R.ExecutablePhysicalSubjectV4(H, H, H, H, (("gain", 2),), ((scenario=:startup,),),
        (declared=true,), (sig,))
    @test subject.physical_subject_hash != changed.physical_subject_hash
    input = R.compile_solver_input(subject, (scenario=:startup,), provider)
    store = Dict{Digest256,R.RuntimeEvidenceV4}()
    first = R.execute_once!(store, input, provider)
    second = R.execute_once!(store, input, provider)
    @test first === second
    @test first.claim_ceiling == screen_only
    @test_throws ArgumentError R.RuntimeEvidenceV4(H, H, H, provider.manifest_hash, (;),
        StatusVectorV4(required, unique_match, resolved, integrated_executed, unknown), (); claim_ceiling=integrated)
    deferred = R.execute_once!(Dict{Digest256,R.RuntimeEvidenceV4}(), input, nothing)
    @test deferred.status_vector.resolution == terminal_deferred
    @test deferred.claim_ceiling == none
end
