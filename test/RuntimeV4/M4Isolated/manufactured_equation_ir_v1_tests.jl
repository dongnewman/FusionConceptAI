using Test
using SHA

const SOURCE_PATH = normpath(joinpath(@__DIR__, "../../..", "src", "RuntimeV4", "M4Isolated", "ManufacturedEquationIRV1.jl"))
@assert isfile(SOURCE_PATH) "M4-A source path is missing: $SOURCE_PATH"
include(SOURCE_PATH)

function failure_codes(result)
    Set(f.code for f in result.failures)
end

function failure_signature(result)
    [(f.code, f.path, f.detail) for f in result.failures]
end

function stable_payload_bytes(ir)
    # The declaration uses immutable scalar/tuple fields.  A fixed structural
    # representation is sufficient for this isolated deterministic control;
    # no production serializer or lowering path is imported.
    sprint(show, manufactured_equation_payload(ir))
end

@testset "M4-A manufactured equation IR v1" begin
    ir = manufactured_equation_ir_v1()
    validation = validate_manufactured_equation_ir(ir)

    @test validation.valid
    @test validation.status == :valid
    @test isempty(validation.failures)
    @test validation.claim_ceiling == :manufactured_control
    @test validation.evidence_scope == :screen_only
    @test ir.domain.id == "Omega"
    @test ir.domain.dimension == 3
    @test ir.domain.coordinate_names == ("x", "y", "z")
    @test ir.domain.lower == (0.0, 0.0, 0.0)
    @test ir.domain.upper == (1.0, 1.0, 1.0)
    @test ir.scalar_field.expression == "x/L + y/L + z/L"
    @test ir.operator.expression == "-div(K*grad(u)) - f = 0"
    @test ir.source.value.numerator == -11
    @test ir.source.value.denominator == 60
    @test ir.time_scope == :terminal_deferred
    @test ir.multifield_scope == :terminal_deferred

    payload_a = stable_payload_bytes(ir)
    payload_b = stable_payload_bytes(manufactured_equation_ir_v1())
    @test payload_a == payload_b
    @test bytes2hex(sha256(codeunits(payload_a))) == bytes2hex(sha256(codeunits(payload_b)))

    @testset "typed negative controls" begin
        @testset "missing or unknown operator" begin
            missing = validate_manufactured_equation_ir(manufactured_equation_ir_v1(operator_name=""))
            @test !missing.valid
            @test :unknown_operator in failure_codes(missing)
            @test failure_signature(missing) == failure_signature(validate_manufactured_equation_ir(manufactured_equation_ir_v1(operator_name="")))
            result = validate_manufactured_equation_ir(manufactured_equation_ir_v1(operator_name="UNKNOWN"))
            @test !result.valid
            @test :unknown_operator in failure_codes(result)
        end

        @testset "wrong units" begin
            wrong_units = M4UnitV1("kg", (0, 1, 0, 0, 0, 0, 0), 1.0)
            result = validate_manufactured_equation_ir(manufactured_equation_ir_v1(scalar_unit=wrong_units))
            @test !result.valid
            @test :unit_closure_failure in failure_codes(result)
        end

        @testset "nonpositive coefficient" begin
            result = validate_manufactured_equation_ir(manufactured_equation_ir_v1(coefficient_lower_bounds=(2.0, 0.0, 4.0)))
            @test !result.valid
            @test :nonpositive_coefficient in failure_codes(result)
        end

        @testset "non-SPD coefficient" begin
            result = validate_manufactured_equation_ir(manufactured_equation_ir_v1(spd_certificate=:unknown))
            @test !result.valid
            @test :non_spd_coefficient in failure_codes(result)
        end

        @testset "duplicate conservation owner" begin
            owners = (M4_MANUFACTURED_CONSERVATION_OWNER_V1, M4_MANUFACTURED_CONSERVATION_OWNER_V1)
            result = validate_manufactured_equation_ir(manufactured_equation_ir_v1(conservation_owners=owners))
            @test !result.valid
            @test :non_unique_source_owner in failure_codes(result)
        end

        @testset "missing boundary or closure" begin
            result = validate_manufactured_equation_ir(manufactured_equation_ir_v1(boundary_complete=false))
            @test !result.valid
            @test :missing_boundary_closure in failure_codes(result)
        end

        @testset "foreign source" begin
            result = validate_manufactured_equation_ir(manufactured_equation_ir_v1(source_equation_id="FOREIGN-EQUATION"))
            @test !result.valid
            @test :foreign_source_reference in failure_codes(result)
        end

        @testset "time and multifield remain deferred" begin
            time_result = validate_manufactured_equation_ir(manufactured_equation_ir_v1(time_scope=:time_dependent))
            multi_result = validate_manufactured_equation_ir(manufactured_equation_ir_v1(multifield_scope=:multifield))
            @test !time_result.valid
            @test :terminal_deferred in failure_codes(time_result)
            @test !multi_result.valid
            @test :terminal_deferred in failure_codes(multi_result)
        end
    end

    # Explicit scope guard: this test file only validates declarations and
    # typed structural controls; it does not lower, discretize, solve, or bind.
    @test !isdefined(Main, :CandidateStatePackageV5)
    @test !isdefined(Main, :ForwardChainContextV4)
    @test !isdefined(Main, :RuntimeEvidenceV4)
end
