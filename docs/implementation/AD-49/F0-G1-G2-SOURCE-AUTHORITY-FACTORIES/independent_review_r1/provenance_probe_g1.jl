using FusionConceptAI
const G = FusionConceptAI
const test_path = joinpath(@__DIR__, "..", "..", "..", "..", "..", "test", "GenomeV5", "G1", "g1_source_authority_factory_v1_tests.jl")
Base.include(Main, test_path)
fixture = Main._tracked_fixture(G.G1_SOURCE_AUTHORITY_FACTORY_SOURCE_PATH_V1)
payload, ctor = Main._payload_and_constructor()
contract = G._g1sf_expected_contract()
repository_label_fixture = G.G1IndependentSourceLocatorV1(fixture.repository_root, fixture.observed_head,
    fixture.source_path, fixture.source_bytes, fixture.source_sha256, fixture.head_path_status,
    fixture.working_tree_path_status, fixture.working_tree_status, fixture.head_blob_sha256, :repository_head)
result = G.g1_source_authority_factory_v1(repository_label_fixture, Main._HANDLE, contract, payload, Main._AXES, ctor)
println("G1_WRONG_PROVENANCE_STATUS=", G.g1_source_factory_result_status(result))
println("G1_WRONG_PROVENANCE_SYNTHETIC_TEST_ONLY=", result.source_declaration isa G.PresentG1SourceDeclarationV1 ? result.source_declaration.synthetic_test_only : missing)
println("G1_WRONG_PROVENANCE_LOCATOR_PROVENANCE=", repository_label_fixture.provenance)
