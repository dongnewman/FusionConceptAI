using Test
using JSON3
using FusionConceptAI

const _G3MFP2_NEG_ROOT = joinpath(@__DIR__, "..", "..", "..", "..", "src", "GenomeV5", "G3")
Base.include(FusionConceptAI, joinpath(_G3MFP2_NEG_ROOT, "G3SourceFeedbackLawV1.jl"))
Base.include(FusionConceptAI, joinpath(_G3MFP2_NEG_ROOT, "G3MaterialFieldProjectionV2.jl"))
const G = FusionConceptAI
const FIXTURE = JSON3.read(read(joinpath(@__DIR__, "determinant_negative_v1_fixture.json"), String))

_rat(x) = Rational{Int64}(Int64(x), Int64(1))

@testset "G3 MFP V2 symmetric determinant-negative tensor is rejected" begin
    tensor = Tuple(_rat(x) for x in FIXTURE.conductivity_tensor_w_m_k)
    a, b, c, d, e, f, g, h, i = tensor
    first_minor = a
    second_minor = a * e - b * d
    determinant = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g)

    @test String(FIXTURE.schema_id) == "GenomeV5/G3/G3MaterialFieldProjectionV2/DeterminantNegativeFixture"
    @test String(FIXTURE.version) == "v1"
    @test tensor[2] == tensor[4] && tensor[3] == tensor[7] && tensor[6] == tensor[8]
    @test first_minor == _rat(FIXTURE.expected_gate.first_leading_principal_minor)
    @test second_minor == _rat(FIXTURE.expected_gate.second_leading_principal_minor)
    @test determinant == _rat(FIXTURE.expected_gate.determinant)
    @test G._g3mfp2_tensor_spd(tensor) === false

    candidate = QualifiedRefV1("local://fixture/candidate", "v1")
    condition = QualifiedRefV1("local://fixture/condition", "v1")
    selection = () -> G.G3MFPConductivityTensorSelectionV2(
        candidate, "core", "component-core", "material-core", tensor,
        :symmetric_positive_definite_tensor,
        Tuple(_rat(x) for x in FIXTURE.declared_domain_lower_w_m_k),
        Tuple(_rat(x) for x in FIXTURE.declared_domain_upper_w_m_k),
        QualifiedRefV1("local://fixture/region-map", "v1"),
        digest256_text("determinant-negative fixture region map"),
        QualifiedRefV1("local://fixture/physical-frame", "v1"),
        digest256_text("determinant-negative fixture physical frame"),
        "W/(m*K)", G.G3_MFP_V2_W_PER_M_K_UNIT, 1 // 1,
        condition, digest256_text("determinant-negative fixture condition"),
        QualifiedRefV1("local://fixture/material-source", "v1"),
        QualifiedRefV1("local://fixture/material-evidence", "v1"),
        Vector{UInt8}(codeunits("synthetic test fixture only")),
        QualifiedRefV1("local://fixture/material-authority", "v1"),
        :synthetic_local)

    observed_error = try
        selection()
        nothing
    catch caught
        caught
    end
    @test observed_error isa ArgumentError
    @test observed_error isa ArgumentError &&
        occursin(String(FIXTURE.expected_gate.reject_reason_contains), sprint(showerror, observed_error))
end
