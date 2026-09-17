using Test
using FusionConceptAI
include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_regional_force_quadrature_direction_diagnostic.jl"))

@testset "direction diagnostic" begin
    @test RFQ4.validate_regional_force_quadrature_direction_diagnostic(rfdd) ==
        rfdd.diagnostic_hash
    @test rfdd.status == :diagnostic_only
    @test rfdd.claim_ceiling == screen_only
    @test rfdd.evidence_credit == 0
    @test Tuple(config.label for config in rfdd.configs) == (
        :radial2_angular4, :radial3_angular4,
        :radial4_angular2, :radial4_angular3, :q4_shared)
    @test length(rfdd.adjacent_differences) == 4
    @test Tuple(difference.axis for difference in rfdd.adjacent_differences) ==
        (:radial, :radial, :angular, :angular)
    @test all(config -> all(isfinite, config.total_force), rfdd.configs)
    @test rfdd.configs[end].total_force == q4_comparison.q4_total_force
    @test rfdd.configs[end].field_receipt_hash ==
        q4_comparison.q4_receipt.field_receipt_hash

    foreign_config_body = merge(RFQ4.semantic_view(rfdd.configs[1]),
        (region_ids=("foreign-region",)))
    foreign_config = RFQ4.RegionalForceDirectionConfigV4(
        values(foreign_config_body)...)
    foreign_configs = Base.setindex(rfdd.configs, foreign_config, 1)
    foreign_body = merge(RFQ4.semantic_view(rfdd), (configs=foreign_configs,))
    foreign = RFQ4.RegionalForceQuadratureDirectionDiagnosticV4(
        Val(:rfdd_private), values(foreign_body)..., canonical_hash(foreign_body))
    @test_throws ArgumentError canonical_hash(foreign)

    forged_output_body = merge(RFQ4.semantic_view(rfdd),
        (output_sha256=Digest256("0"^64),))
    forged_output = RFQ4.RegionalForceQuadratureDirectionDiagnosticV4(
        Val(:rfdd_private), values(forged_output_body)...,
        canonical_hash(forged_output_body))
    @test_throws ArgumentError canonical_hash(forged_output)

    bad_differences = Base.setindex(rfdd.adjacent_differences,
        merge(rfdd.adjacent_differences[1], (absolute_difference_N=0.0,)), 1)
    bad_body = merge(RFQ4.semantic_view(rfdd),
        (adjacent_differences=bad_differences,))
    bad = RFQ4.RegionalForceQuadratureDirectionDiagnosticV4(Val(:rfdd_private),
        values(bad_body)..., canonical_hash(bad_body))
    @test_throws ArgumentError canonical_hash(bad)
end
println("RFDD_FOCUSED_EXIT_CODE=0")
