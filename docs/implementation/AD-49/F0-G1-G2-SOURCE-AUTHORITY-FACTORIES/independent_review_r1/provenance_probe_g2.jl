using FusionConceptAI
const G = FusionConceptAI
const test_path = joinpath(@__DIR__, "..", "..", "..", "..", "..", "test", "GenomeV5", "G2", "g2_source_authority_factory_v1_tests.jl")
Base.include(Main, test_path)
payload, contract = Main._source()
ctor = G.G2SourceDeclarationConstructorV1(G.g2mb_declaration_v1)
fixture = Main._tracked_fixture(G.G2_SOURCE_AUTHORITY_FACTORY_SOURCE_PATH_V1)
repository_label_fixture = G.G2IndependentSourceLocatorV1(fixture.repository_root, fixture.observed_head,
    fixture.source_path, fixture.source_bytes, fixture.source_sha256, fixture.head_path_status,
    fixture.working_tree_path_status, fixture.working_tree_status, fixture.head_blob_sha256, :repository_head)
result = G.g2_source_authority_factory_v1(repository_label_fixture, Main._HANDLE, contract, payload, Main._AXES, ctor)
println("G2_WRONG_PROVENANCE_STATUS=", G.g2_source_factory_result_status(result))
println("G2_WRONG_PROVENANCE_SYNTHETIC_TEST_ONLY=", result.source_declaration isa G.PresentG2SourceDeclarationV1 ? result.source_declaration.synthetic_test_only : missing)
println("G2_WRONG_PROVENANCE_LOCATOR_PROVENANCE=", repository_label_fixture.provenance)
