using Test
using SHA

const SOURCE_A = normpath(joinpath(@__DIR__, "../../..", "src", "RuntimeV4", "M4Isolated", "ManufacturedEquationIRV1.jl"))
const SOURCE_B = normpath(joinpath(@__DIR__, "../../..", "src", "RuntimeV4", "M4Isolated", "ManufacturedResidualLoweringV1.jl"))
@assert isfile(SOURCE_A) "M4-A source path is missing: $SOURCE_A"
@assert isfile(SOURCE_B) "M4-B source path is missing: $SOURCE_B"
include(SOURCE_A)
include(SOURCE_B)

failure_codes(result) = Set(f.code for f in result.failures)
failure_signature(result) = [(f.code, f.path, f.detail) for f in result.failures]
stable_bytes(x) = sprint(show, x)

function clone_residual(d::ManufacturedResidualDeclarationV1;
        equation_id=d.equation_id, equation_kind=d.equation_kind,
        domain=d.domain, field_id=d.field_id, field_unit=d.field_unit,
        operator_id=d.operator_id, operator_version=d.operator_version,
        operator_expression=d.operator_expression,
        operator_input_unit=d.operator_input_unit,
        operator_output_unit=d.operator_output_unit, source_id=d.source_id,
        source_equation_id=d.source_equation_id, source_unit=d.source_unit,
        coefficient_unit=d.coefficient_unit, source_owner=d.source_owner,
        conservation_owner=d.conservation_owner, provenance=d.provenance,
        divergence_contributions=d.divergence_contributions,
        divergence_total=d.divergence_total, source_value=d.source_value,
        residual_value=d.residual_value, claim_ceiling=d.claim_ceiling,
        evidence_scope=d.evidence_scope, time_scope=d.time_scope,
        multifield_scope=d.multifield_scope)
    ManufacturedResidualDeclarationV1(
        equation_id, equation_kind, domain, field_id, field_unit,
        operator_id, operator_version, operator_expression,
        operator_input_unit, operator_output_unit, source_id,
        source_equation_id, source_unit, coefficient_unit, source_owner,
        conservation_owner, provenance, divergence_contributions,
        divergence_total, source_value, residual_value, claim_ceiling,
        evidence_scope, time_scope, multifield_scope)
end

function foreign_domain()
    M4DomainDeclarationV1("ForeignOmega", 3, ("x", "y", "z"),
        (0.0, 0.0, 0.0), (1.0, 1.0, 1.0), M4_LENGTH_V1, 1.0)
end

@testset "M4-B manufactured residual lowering v1" begin
    ir = manufactured_equation_ir_v1()
    @test validate_manufactured_equation_ir(ir).valid
    a = lower_manufactured_residual(ir)
    @test a.valid
    @test a.status == :valid
    @test isempty(a.failures)
    @test a.claim_ceiling == :manufactured_residual_lowering
    @test a.evidence_scope == :screen_only
    @test a.declaration !== nothing
    d = a.declaration
    @test validate_manufactured_residual(d).valid
    @test validate_manufactured_residual(d, ir).valid
    @test d.source_owner == ir.source.owner
    @test !isempty(d.source_owner)
    @test d.source_owner != d.conservation_owner
    @test d.divergence_contributions ==
        (M4RationalV1(1, 10), M4RationalV1(1, 20), M4RationalV1(1, 30))
    @test d.divergence_total == M4RationalV1(11, 60)
    @test d.source_value == M4RationalV1(-11, 60)
    @test d.residual_value == M4RationalV1(0, 1)
    @test d.time_scope == :terminal_deferred
    @test d.multifield_scope == :terminal_deferred

    payload_a = stable_bytes(manufactured_residual_payload(d))
    payload_b = stable_bytes(manufactured_residual_payload(lower_manufactured_residual(
        manufactured_equation_ir_v1()).declaration))
    @test payload_a == payload_b
    @test sha256(codeunits(payload_a)) == sha256(codeunits(payload_b))

    @testset "typed identity and binding controls" begin
        @test :foreign_equation in failure_codes(validate_manufactured_residual(
            clone_residual(d; equation_id="FOREIGN")))
        @test :foreign_equation in failure_codes(validate_manufactured_residual(
            clone_residual(d; equation_kind=:foreign)))
        @test :domain_mismatch in failure_codes(validate_manufactured_residual(
            clone_residual(d; domain=foreign_domain())))
        @test :field_mismatch in failure_codes(validate_manufactured_residual(
            clone_residual(d; field_id="foreign_field")))
        @test :operator_mismatch in failure_codes(validate_manufactured_residual(
            clone_residual(d; operator_id="FOREIGN_OPERATOR")))
        @test :source_mismatch in failure_codes(validate_manufactured_residual(
            clone_residual(d; source_id="foreign_source")))
        @test :owner_mismatch in failure_codes(validate_manufactured_residual(
            clone_residual(d; source_owner="foreign-source-owner"), ir))
        @test :owner_mismatch in failure_codes(validate_manufactured_residual(
            clone_residual(d; conservation_owner="foreign-conservation-owner"), ir))
        @test :provenance_mismatch in failure_codes(validate_manufactured_residual(
            clone_residual(d; provenance=M4ProvenanceDeclarationV1(
                :explicit_manufactured_or_analytic, :manufactured_only,
                :no_external_authority, false, :foreign, :screen_only))))
    end

    @testset "typed units, sign, and exact arithmetic controls" begin
        wrong = M4UnitV1("kg", (0, 1, 0, 0, 0, 0, 0), 1.0)
        @test :unit_closure_failure in failure_codes(validate_manufactured_residual(
            clone_residual(d; field_unit=wrong)))
        @test :unit_closure_failure in failure_codes(validate_manufactured_residual(
            clone_residual(d; operator_input_unit=wrong)))
        @test :unit_closure_failure in failure_codes(validate_manufactured_residual(
            clone_residual(d; source_unit=wrong)))
        @test :unit_closure_failure in failure_codes(validate_manufactured_residual(
            clone_residual(d; coefficient_unit=wrong)))
        @test :sign_mismatch in failure_codes(validate_manufactured_residual(
            clone_residual(d; operator_expression="div(K*grad(u)) + f = 0")))
        @test :term_count_mismatch in failure_codes(validate_manufactured_residual(
            clone_residual(d; divergence_contributions=(M4RationalV1(1, 10),))))
        @test :term_mismatch in failure_codes(validate_manufactured_residual(
            clone_residual(d; divergence_contributions=(M4RationalV1(1, 9),
                M4RationalV1(1, 20), M4RationalV1(1, 30)))))
        @test :divergence_mismatch in failure_codes(validate_manufactured_residual(
            clone_residual(d; divergence_total=M4RationalV1(1, 2))))
        @test :source_mismatch in failure_codes(validate_manufactured_residual(
            clone_residual(d; source_value=M4RationalV1(-1, 2))))
        @test :nonzero_residual in failure_codes(validate_manufactured_residual(
            clone_residual(d; residual_value=M4RationalV1(1, 100))))
    end

    @testset "deferred scopes and API ceiling" begin
        @test :terminal_deferred in failure_codes(validate_manufactured_residual(
            clone_residual(d; time_scope=:time_dependent)))
        @test :terminal_deferred in failure_codes(validate_manufactured_residual(
            clone_residual(d; multifield_scope=:multifield)))
        forbidden = (:discretize, :assemble, :assemble_matrix, :solve,
            :couple, :transfer_topology, :bind_candidate, :invoke_provider)
        for name in forbidden
            @test !isdefined(@__MODULE__, name)
        end
        @test !isdefined(@__MODULE__, :CandidateStatePackageV5)
        @test !isdefined(@__MODULE__, :ForwardChainContextV4)
        @test !isdefined(@__MODULE__, :RuntimeEvidenceV4)
    end

    @testset "failure determinism" begin
        bad = clone_residual(d; divergence_total=M4RationalV1(1, 2),
            source_owner="foreign-source-owner")
        @test failure_signature(validate_manufactured_residual(bad, ir)) ==
            failure_signature(validate_manufactured_residual(bad, ir))
    end
end

println("M4-B-TESTS PASS manufactured_residual_lowering/screen_only")
