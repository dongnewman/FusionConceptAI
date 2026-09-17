using Test

const TCIR_ROOT = normpath(joinpath(@__DIR__, "../../.."))
const TCIR_SOURCE = joinpath(TCIR_ROOT, "src", "RuntimeV4", "TypedCompilerIRV1.jl")
const TCIR_LOWERING = joinpath(TCIR_ROOT, "src", "RuntimeV4", "TypedCompilerLoweringV1.jl")
@assert isfile(TCIR_SOURCE) "typed compiler IR source is missing"
@assert isfile(TCIR_LOWERING) "typed compiler lowering source is missing"
include(TCIR_SOURCE)
include(TCIR_LOWERING)

failure_codes(result) = Set(f.code for f in result.failures)

function rebuild_ir(ir::TypedCompilerIRV1; schema=ir.schema, revision=ir.revision,
                    source_authority=ir.source_authority)
    _tc_new_ir_v1(String(schema), String(revision), ir.candidate_ref,
        ir.owner_ref, ir.region_ref, ir.chart_ref, ir.operator_ref, ir.source_ref,
        ir.conservation_ref, ir.input_unit, ir.output_unit, ir.operations,
        ir.source_kind, ir.synthetic, ir.measured, ir.claim_ceiling,
        ir.evidence_scope, source_authority)
end

function rebuild_authority(authority::TypedCompilerSourceAuthorityV1;
                           schema=authority.schema, revision=authority.revision,
                           status=authority.status, operator_ref=authority.operator_ref,
                           input_unit=authority.input_unit)
    _tc_new_source_authority_v1(String(schema), String(revision), status,
        authority.receipt_ref, authority.candidate_ref, authority.owner_ref,
        authority.region_ref, authority.chart_ref, operator_ref,
        authority.source_ref, authority.conservation_ref, input_unit,
        authority.output_unit)
end

@testset "UP2 pre-T0 typed compiler IR v1 contract" begin
    binding = typed_compiler_binding_v1()
    ir = typed_compiler_ir_v1()
    validation = validate_typed_compiler_ir(ir, binding)

    @test validation.valid
    @test validation.status === :ready
    @test isempty(validation.failures)
    @test validation.claim_ceiling === :contract_only
    @test validation.evidence_scope === :not_measured
    @test !validation.measured
    @test ir.synthetic
    @test !ir.measured

    @testset "factory trimming keeps concrete String fields" begin
        unit = typed_compiler_unit_v1("  meter  ", (1,0,0,0,0,0,0))
        @test unit.name == "meter"
        @test typeof(unit.name) === String
        trimmed_binding = typed_compiler_binding_v1(
            candidate_ref="  candidate  ", owner_ref="  owner  ",
            region_ref="  region  ", chart_ref="  chart  ",
            operator_ref="  operator  ", source_ref="  source  ",
            conservation_ref="  conservation  ", input_unit=unit, output_unit=unit)
        @test trimmed_binding.candidate_ref == "candidate"
        @test all(typeof(getfield(trimmed_binding, field)) === String for field in
            (:candidate_ref, :owner_ref, :region_ref, :chart_ref, :operator_ref,
             :source_ref, :conservation_ref))
        trimmed_ir = typed_compiler_ir_v1(
            candidate_ref="  candidate  ", owner_ref="  owner  ",
            region_ref="  region  ", chart_ref="  chart  ",
            operator_ref="  operator  ", source_ref="  source  ",
            conservation_ref="  conservation  ",
            operations=("  input  ", "  operator  ", "  source  ", "  conservation  "))
        @test trimmed_ir.candidate_ref == "candidate"
        @test all(typeof(getfield(trimmed_ir, field)) === String for field in
            (:schema, :revision, :candidate_ref, :owner_ref, :region_ref,
             :chart_ref, :operator_ref, :source_ref, :conservation_ref))
        @test trimmed_ir.operations == ("input", "operator", "source", "conservation")
        @test all(typeof(operation) === String for operation in trimmed_ir.operations)
    end

    @testset "schema revision and typed units are exact" begin
        schema_result = validate_typed_compiler_ir(
            rebuild_ir(ir; schema="foreign-schema"), binding)
        @test schema_result.status === :fail_closed
        @test :schema_mismatch in failure_codes(schema_result)
        revision_result = validate_typed_compiler_ir(
            rebuild_ir(ir; revision="foreign-revision"), binding)
        @test revision_result.status === :fail_closed
        @test :revision_mismatch in failure_codes(revision_result)
        meter = typed_compiler_unit_v1("m", (1,0,0,0,0,0,0))
        expected_units = typed_compiler_binding_v1(input_unit=meter, output_unit=meter)
        result = validate_typed_compiler_ir(ir, expected_units)
        @test result.status === :fail_closed
        @test :unit_mismatch in failure_codes(result)
    end

    lowered = lower_typed_compiler_ir(ir, binding)
    @test lowered.status === :ready
    @test lowered.lowered_operations == ir.operations
    @test lowered.claim_ceiling === :contract_only
    @test lowered.evidence_scope === :not_measured
    @test !lowered.measured
    @test validate_typed_compiler_lowering(lowered, binding) === lowered

    @testset "sealed factories and unsealed direct constructors" begin
        authority = typed_compiler_source_authority_v1()
        @test typed_compiler_unit_v1("1", (0,0,0,0,0,0,0)) isa TypedCompilerUnitV1
        @test typed_compiler_binding_v1() isa TypedCompilerBindingV1
        @test typed_compiler_source_authority_v1() isa TypedCompilerSourceAuthorityV1
        @test typed_compiler_ir_v1() isa TypedCompilerIRV1
        @test lower_typed_compiler_ir(ir, binding) isa TypedCompilerLoweringV1

        @test_throws ArgumentError TypedCompilerUnitV1(
            "1", (0,0,0,0,0,0,0), 1.0)
        @test_throws ArgumentError TypedCompilerBindingV1(
            binding.candidate_ref, binding.owner_ref, binding.region_ref,
            binding.chart_ref, binding.operator_ref, binding.source_ref,
            binding.conservation_ref, binding.input_unit, binding.output_unit)
        @test_throws ArgumentError TypedCompilerSourceAuthorityV1(
            authority.schema, authority.revision, authority.status,
            authority.receipt_ref, authority.candidate_ref, authority.owner_ref,
            authority.region_ref, authority.chart_ref, authority.operator_ref,
            authority.source_ref, authority.conservation_ref, authority.input_unit,
            authority.output_unit)
        @test_throws ArgumentError TypedCompilerIRV1(
            ir.schema, ir.revision, ir.candidate_ref, ir.owner_ref,
            ir.region_ref, ir.chart_ref, ir.operator_ref, ir.source_ref,
            ir.conservation_ref, ir.input_unit, ir.output_unit, ir.operations,
            ir.source_kind, ir.synthetic, ir.measured, ir.claim_ceiling,
            ir.evidence_scope, ir.source_authority)
        @test_throws ArgumentError TypedCompilerLoweringV1(
            lowered.ir, lowered.validation, lowered.lowered_operations)
    end

    @testset "typed absent source is terminal deferred" begin
        absent = typed_compiler_ir_v1(source_ref="typed_absent")
        result = validate_typed_compiler_ir(absent, binding)
        @test !result.valid
        @test result.status === :terminal_deferred
        @test :source_authority_absent in failure_codes(result)
        @test lower_typed_compiler_ir(absent, binding).status === :terminal_deferred
    end

    @testset "source kind and synthetic flag are a two-way contract" begin
        synthetic_true = typed_compiler_ir_v1(source_kind=:synthetic, synthetic=true)
        @test synthetic_true.synthetic
        @test validate_typed_compiler_ir(synthetic_true, binding).status === :ready
        @test_throws ArgumentError typed_compiler_ir_v1(source_kind=:synthetic, synthetic=false)

        local_false = typed_compiler_ir_v1(source_kind=:local_source, synthetic=false)
        @test !local_false.synthetic
        @test validate_typed_compiler_ir(local_false, binding).status === :terminal_deferred
        local_authority = typed_compiler_source_authority_v1()
        local_ready = typed_compiler_ir_v1(source_kind=:local_source, synthetic=false,
                                           source_authority=local_authority)
        @test validate_typed_compiler_ir(local_ready, binding).status === :ready
        @test_throws ArgumentError typed_compiler_ir_v1(source_kind=:local_source, synthetic=true)
    end

    @testset "candidate and all cross-layer bindings fail closed" begin
        cases = (
            (:candidate_ref, typed_compiler_ir_v1(candidate_ref="foreign:candidate_ref")),
            (:owner_ref, typed_compiler_ir_v1(owner_ref="foreign:owner_ref")),
            (:region_ref, typed_compiler_ir_v1(region_ref="foreign:region_ref")),
            (:chart_ref, typed_compiler_ir_v1(chart_ref="foreign:chart_ref")),
            (:operator_ref, typed_compiler_ir_v1(operator_ref="foreign:operator_ref")),
            (:source_ref, typed_compiler_ir_v1(source_ref="foreign:source_ref")),
            (:conservation_ref, typed_compiler_ir_v1(conservation_ref="foreign:conservation_ref")),
        )
        for (field, foreign) in cases
            result = validate_typed_compiler_ir(foreign, binding)
            @test result.status === :fail_closed
            @test :binding_mismatch in failure_codes(result)
        end
    end

    @testset "local source requires checked-present authority" begin
        local_missing = typed_compiler_ir_v1(source_kind=:local_source, synthetic=false)
        result = validate_typed_compiler_ir(local_missing, binding)
        @test !result.valid
        @test result.status === :terminal_deferred
        @test :source_authority_absent in failure_codes(result)

        authority = typed_compiler_source_authority_v1()
        local_ready = typed_compiler_ir_v1(source_kind=:local_source, synthetic=false,
                                           source_authority=authority)
        ready = validate_typed_compiler_ir(local_ready, binding)
        @test ready.valid
        @test ready.status === :ready
        @test local_ready.source_authority.status === :checked_present
        @test lower_typed_compiler_ir(local_ready, binding).status === :ready

        foreign_authority = rebuild_authority(authority; operator_ref="foreign:operator")
        foreign_local = typed_compiler_ir_v1(source_kind=:local_source, synthetic=false,
                                             source_authority=foreign_authority)
        foreign_result = validate_typed_compiler_ir(foreign_local, binding)
        @test foreign_result.status === :fail_closed
        @test :source_authority_mismatch in failure_codes(foreign_result)

        unchecked_authority = rebuild_authority(authority; status=:unchecked)
        unchecked_local = typed_compiler_ir_v1(source_kind=:local_source, synthetic=false,
                                               source_authority=unchecked_authority)
        unchecked_result = validate_typed_compiler_ir(unchecked_local, binding)
        @test unchecked_result.status === :fail_closed
        @test :source_authority_mismatch in failure_codes(unchecked_result)
    end

    @testset "illegal input is rejected before lowering" begin
        @test_throws ArgumentError typed_compiler_unit_v1("", (0,0,0,0,0,0,0))
        @test_throws ArgumentError typed_compiler_unit_v1("1", (0,0))
        @test_throws ArgumentError typed_compiler_unit_v1("1", (0,0,0,0,0,0,0); scale=0.0)
        @test_throws ArgumentError typed_compiler_binding_v1(candidate_ref="*")
        @test_throws ArgumentError typed_compiler_ir_v1(operations=())
        @test_throws ArgumentError typed_compiler_ir_v1(measured=true)
        @test_throws ArgumentError typed_compiler_ir_v1(claim_ceiling=:screen_only)
        @test_throws ArgumentError typed_compiler_ir_v1(evidence_scope=:screen_only)
    end

    @testset "unit/operator/conservation contradictions fail closed" begin
        bad_unit = typed_compiler_ir_v1(
            input_unit=typed_compiler_unit_v1("m", (1,0,0,0,0,0,0)),
            operations=("input", "operator", "unknown", "conservation"))
        result = validate_typed_compiler_ir(bad_unit, binding)
        @test result.status === :fail_closed
        @test :illegal_operation in failure_codes(result)
        @test :duplicate_operation ∉ failure_codes(result)
        foreign_operator = typed_compiler_ir_v1(operator_ref="foreign:operator")
        @test validate_typed_compiler_ir(foreign_operator, binding).status === :fail_closed
        foreign_source = typed_compiler_ir_v1(source_ref="foreign:source")
        @test validate_typed_compiler_ir(foreign_source, binding).status === :fail_closed
        foreign_conservation = typed_compiler_ir_v1(conservation_ref="foreign:conservation")
        @test validate_typed_compiler_ir(foreign_conservation, binding).status === :fail_closed
    end

    # This pre-T0 contract test intentionally does not construct the shared
    # FusionConceptAI module, invoke a provider, build a mesh, or solve.
    @test !isdefined(Main, :CandidateStatePackageV5)
end
