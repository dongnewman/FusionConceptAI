using Test
using FusionConceptAI

include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "FusionRuntimeV4.jl"))
using .FusionRuntimeV4

const R_BOUNDS = digest256_text("runtime-v4-test-bounds")

@testset "runtime v4 exact structural-screen capability" begin
    obligation = screen_capability(R_BOUNDS)
    provider = deterministic_screen_manifest(obligation)
    @test provider.capability == obligation
    @test match_provider(obligation, (provider,)).status == unique_match
    @test match_provider(obligation, ()).status == no_match
    @test match_provider(obligation, (deterministic_screen_manifest(
        screen_capability(digest256_text("other-bounds"))),)).status == out_of_domain
    @test_throws ArgumentError deterministic_screen_manifest(
        CapabilitySignatureV4("schema", "v1", :operator, "physical_operator",
            ("typed_graph",), "typed_graph", "typed_graph", 1, ("lumped",),
            "none", "none", "static", ("physical_result",), screen_only,
            R_BOUNDS; input_schema_hash=obligation.input_schema_hash))
end

@testset "runtime v4 provider computes a typed structural audit" begin
    # A provider may inspect the materialized payload but cannot receive a
    # proposal, label, or display-name shortcut as evidence.
    graph = (nodes=(;), hyperedges=(;))
    bad_payload = (materialized_payload=(mechanism_graph=graph,),)
    @test_throws ArgumentError deterministic_screen_execute(bad_payload)
    @test screen_execution_count() == 1
    reset_screen_execution_count!()
    @test screen_execution_count() == 0
end

@testset "runtime v4 compiles the declared three-Genome fixture" begin
    include(joinpath(@__DIR__, "..", "examples", "runtime_v4_declared_fixture.jl"))
    reset_screen_execution_count!()
    report = run_v4_vertical_slice(candidate, registry)
    @test report.compiled isa CompiledCandidatePrefixV4
    @test report.credible_count == 0
    @test report.unsupported_count == 0
    @test report.subject === nothing
    @test isempty(report.evidence)
    @test screen_execution_count() == 0
    @test report.layer_counts.genome_count == 3
    @test !isempty(report.capability_gaps)

    renamed = CandidateStatePackageV4("renamed-display", candidate.mission_contract_ref,
        candidate.mechanism_genome_ref, candidate.field_geometry_genome_ref,
        candidate.realization_control_genome_ref, registry)
    renamed_report = run_v4_vertical_slice(renamed, registry)
    @test renamed_report.compiled.prefix_hash == report.compiled.prefix_hash

    # Structural screening is an explicit capability injection, but an
    # unresolved physical prefix is not materialized and cannot emit evidence.
    structural = first(filter(o -> o.kind == :structural_screen,
                              report.compiled.capability_obligations))
    provider = deterministic_screen_manifest(structural)
    scenarios = ((name="scenario-a",), (name="scenario-b",))
    reset_screen_execution_count!()
    screened = run_v4_vertical_slice(candidate, registry; providers=(provider,),
        scenarios=scenarios)
    @test screened.subject === nothing
    @test screened.claim_ceiling == none
    @test screened.credible_count == 0
    @test screened.unsupported_count == 0
    @test isempty(screened.evidence)
    @test screened.layer_counts.solver_input_count == 0
    @test screen_execution_count() == 0
    @test any(getproperty(g, :reason) == "required_physical_capability:IDENTITY@v1"
              for g in screened.capability_gaps)
end
