using SHA
using FusionConceptAI
const G = FusionConceptAI
const test_path = joinpath(@__DIR__, "..", "..", "..", "..", "..", "test", "GenomeV5", "G2", "g2_source_authority_factory_v1_tests.jl")
Base.include(Main, test_path)
payload, contract = Main._source()
ctor = G.G2SourceDeclarationConstructorV1(G.g2mb_declaration_v1)
fixture = Main._tracked_fixture(G.G2_SOURCE_AUTHORITY_FACTORY_SOURCE_PATH_V1)
path = joinpath(fixture.repository_root, split(fixture.source_path, '/')...)
mutated = vcat(read(path), UInt8[0x0a])
write(path, mutated)
run(Cmd(["git", "-C", fixture.repository_root, "update-index", "--assume-unchanged", fixture.source_path]))
locator = G.G2IndependentSourceLocatorV1(fixture.repository_root, fixture.observed_head, fixture.source_path,
    length(mutated), G.Digest256(bytes2hex(SHA.sha256(mutated))), :present, :present, :clean,
    G.Digest256(bytes2hex(SHA.sha256(mutated))), :repository_head)
result = G.g2_source_authority_factory_v1(locator, Main._HANDLE, contract, payload, Main._AXES, ctor)
println("G2_ASSUMED_UNCHANGED_MUTATION_STATUS=", G.g2_source_factory_result_status(result))
println("G2_ASSUMED_UNCHANGED_MUTATION_WORKTREE_STATUS=", G._g2sf_git(fixture.repository_root, "status", "--porcelain=v1", "--untracked-files=all", "--", fixture.source_path))
println("G2_ASSUMED_UNCHANGED_MUTATION_SOURCE_HASH=", locator.source_sha256.value)
println("G2_ASSUMED_UNCHANGED_MUTATION_HEAD=", fixture.observed_head)
