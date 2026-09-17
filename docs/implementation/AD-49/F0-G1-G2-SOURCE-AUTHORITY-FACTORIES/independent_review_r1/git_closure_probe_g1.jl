using SHA
using FusionConceptAI
const G = FusionConceptAI
const test_path = joinpath(@__DIR__, "..", "..", "..", "..", "..", "test", "GenomeV5", "G1", "g1_source_authority_factory_v1_tests.jl")
Base.include(Main, test_path)
fixture = Main._tracked_fixture(G.G1_SOURCE_AUTHORITY_FACTORY_SOURCE_PATH_V1)
payload, ctor = Main._payload_and_constructor()
contract = G._g1sf_expected_contract()
path = joinpath(fixture.repository_root, split(fixture.source_path, '/')...)
mutated = vcat(read(path), UInt8[0x0a])
write(path, mutated)
run(Cmd(["git", "-C", fixture.repository_root, "update-index", "--assume-unchanged", fixture.source_path]))
locator = G.G1IndependentSourceLocatorV1(fixture.repository_root, fixture.observed_head, fixture.source_path,
    length(mutated), G.Digest256(bytes2hex(SHA.sha256(mutated))), :present, :present, :clean,
    G.Digest256(bytes2hex(SHA.sha256(mutated))), :repository_head)
result = G.g1_source_authority_factory_v1(locator, Main._HANDLE, contract, payload, Main._AXES, ctor)
println("G1_ASSUMED_UNCHANGED_MUTATION_STATUS=", G.g1_source_factory_result_status(result))
println("G1_ASSUMED_UNCHANGED_MUTATION_WORKTREE_STATUS=", G._g1sf_git(fixture.repository_root, "status", "--porcelain=v1", "--untracked-files=all", "--", fixture.source_path))
println("G1_ASSUMED_UNCHANGED_MUTATION_SOURCE_HASH=", locator.source_sha256.value)
println("G1_ASSUMED_UNCHANGED_MUTATION_HEAD=", fixture.observed_head)
