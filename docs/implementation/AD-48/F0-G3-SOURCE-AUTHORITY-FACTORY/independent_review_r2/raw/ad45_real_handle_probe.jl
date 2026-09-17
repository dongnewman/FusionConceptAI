using SHA
using FusionConceptAI

const G = FusionConceptAI
G.load_genome_v5_components!()
Base.include(G, joinpath(@__DIR__, "..", "..", "..", "..", "..", "..", "src", "GenomeV5", "G3", "G3SourceAuthorityFactoryV1.jl"))

const ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", "..", "..", ".."))
const HANDLE = G.QualifiedRefV1(
    "fusionconceptai://candidate-binding/AD45-FRESH-CANDIDATE-BINDING-ENVELOPE/3da169fa-2376-4b36-b794-ac5a32161aa7",
    "v5")

const PATHS = Dict(
    :realization => "src/GenomeV5/G3/RealizationGenomeV5.jl",
    :control => "src/GenomeV5/G3/ControlGenomeV5.jl",
    :binding => "src/GenomeV5/G3/CoupledRealizationControlBindingV2.jl",
    :bundle => "src/GenomeV5/G3/RealizationControlGenomeV5.jl")

for scope in G.G3_SOURCE_AUTHORITY_FACTORY_SCOPES_V1
    path = PATHS[scope]
    bytes = read(joinpath(ROOT, split(path, '/')...))
    locator = G.G3IndependentSourceLocatorV1(scope, ROOT,
        "4b69f55f7f80240147a65a22809dc1207824dde2", path, length(bytes),
        G.Digest256(bytes2hex(SHA.sha256(bytes))), :absent_untracked,
        :absent_untracked, :untracked)
    declaration_ref = G.QualifiedRefV1(
        "fusionconceptai://GenomeV5/G3/$(scope)/source-declaration/ad48-f0-ad45",
        "v1")
    result = G.g3_source_authority_factory_v1(scope, locator, HANDLE,
        G.g3_contract_ref(scope), G.g3_version_axes(scope), declaration_ref)
    reason = hasproperty(result.identity, :reason) ? result.identity.reason : :none
    println("scope=$(scope) status=$(G.g3_factory_result_status(result)) reason=$(reason)")
end
