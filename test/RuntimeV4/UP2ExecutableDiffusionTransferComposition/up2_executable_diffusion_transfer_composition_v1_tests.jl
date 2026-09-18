using Test
using JSON3

const EDC_ROOT = normpath(joinpath(@__DIR__, "../../.."))
const EDC_SOURCE = joinpath(EDC_ROOT, "src", "RuntimeV4", "ExecutableDiffusionTransferCompositionV1.jl")
@assert isfile(EDC_SOURCE) "UP2-EXEC-01 source is missing"
include(EDC_SOURCE)

function replace_case(case; binding=case.binding, old_topology=case.old_topology,
                      new_topology=case.new_topology, transfer=case.transfer,
                      inputs=case.inputs, plan=case.plan)
    ExecutableDiffusionCaseV1(binding, old_topology, new_topology, transfer, inputs, plan)
end

@testset "UP2-EXEC-01 manufactured diffusion/transfer/composition screen R2" begin
    case = manufactured_executable_diffusion_case()
    observed_negative = Dict{String,Tuple{Symbol,Symbol}}()
    record_negative! = (name, result) -> (observed_negative[String(name)] = (result.status, result.code))
    outcome = execute_executable_diffusion_screen(case)
    @test outcome.status === :ready
    @test outcome.code === :joint_linear_solved
    @test outcome.claim_ceiling === :manufactured_numerical_screen
    @test outcome.evidence_scope === :screen_only
    @test outcome.accepted === false
    @test outcome.provider_call_count == 0
    @test outcome.mesh_call_count == 0
    @test outcome.solver_invocation_count == 1
    @test outcome.solution !== nothing
    @test outcome.residual_norm <= 1e-12
    @test outcome.binding_digest == case.binding.binding_digest
    @test outcome.receipt.binding_digest == case.binding.binding_digest
    @test outcome.receipt.receipt_hash != ""

    @testset "constructor recursion guard" begin
        transfer_probe = ExecutableTopologyTransferV1(case.transfer.old, case.transfer.new,
            case.transfer.overlap, case.transfer.weights, "constructor-probe")
        @test transfer_probe.transfer_ref === "constructor-probe"
        @test transfer_probe.overlap == case.transfer.overlap
        @test transfer_probe.weights == case.transfer.weights
    end

    @testset "typed case binding, source declarations, and digest receipt" begin
        @test validate_executable_case_binding(case.binding).valid
        @test length(case.binding.source_declarations) == 3
        @test Set(d.layer for d in case.binding.source_declarations) == Set((:g1, :g2, :g3))
        forged = ExecutableCaseBindingV1(case.binding.candidate_ref, case.binding.mission_ref,
            case.binding.scenario_ref, case.binding.source_declarations;
            binding_digest=repeat("0", 64))
        forged_outcome = execute_executable_diffusion_screen(replace_case(case; binding=forged))
        record_negative!(:binding_mismatch, forged_outcome)
        @test forged_outcome.status === :fail_closed && forged_outcome.code === :binding_mismatch
        mismatched = (ExecutableSourceDeclarationV1("source:bad", :g1, "candidate:other",
            case.binding.mission_ref, case.binding.scenario_ref, _edc_hash_text("bad")),
            case.binding.source_declarations[2], case.binding.source_declarations[3])
        mismatch_binding = ExecutableCaseBindingV1(case.binding.candidate_ref,
            case.binding.mission_ref, case.binding.scenario_ref, mismatched)
        mismatch_outcome = execute_executable_diffusion_screen(replace_case(case; binding=mismatch_binding))
        record_negative!(:binding_mismatch, mismatch_outcome)
        @test mismatch_outcome.status === :fail_closed && mismatch_outcome.code === :binding_mismatch
        malformed_declarations = (ExecutableSourceDeclarationV1("source:bad-digest", :g1,
            case.binding.candidate_ref, case.binding.mission_ref, case.binding.scenario_ref, "not-a-digest"),
            case.binding.source_declarations[2], case.binding.source_declarations[3])
        malformed_binding = ExecutableCaseBindingV1(case.binding.candidate_ref,
            case.binding.mission_ref, case.binding.scenario_ref, malformed_declarations)
        malformed_outcome = execute_executable_diffusion_screen(replace_case(case; binding=malformed_binding))
        record_negative!(:binding_malformed, malformed_outcome)
        @test malformed_outcome.status === :fail_closed && malformed_outcome.code === :binding_malformed
        @test outcome.receipt.receipt_hash != forged_outcome.receipt.receipt_hash
    end

    @testset "full topology identity and explicit old-to-new transfer" begin
        @test validate_executable_topology_identity(case.old_topology, :old).valid
        @test validate_executable_topology_identity(case.new_topology, :new).valid
        transfer_receipt = apply_old_to_new_state(case.transfer)
        @test transfer_receipt.old_state == case.old_topology.state_values
        @test transfer_receipt.new_state == (0.625, 0.625)
        @test outcome.transfer_receipt !== nothing
        @test outcome.transfer_receipt.receipt_hash == transfer_receipt.receipt_hash
        altered_old = ExecutableTopologyIdentityV1("topology:old", "space:manufactured", 2,
            1/3, ("old-left", "old-right"); state_values=(0.75, 0.25), state_semantics=:pre_transfer)
        altered_new = ExecutableTopologyIdentityV1("topology:new", "space:manufactured", 2,
            1/3, ("new-left", "new-right"); state_values=(0.375, 0.375), state_semantics=:expected_post_transfer)
        altered_transfer = ExecutableTopologyTransferV1(altered_old, altered_new,
            case.transfer.overlap, case.transfer.weights, "transfer:altered")
        altered_case = replace_case(case; old_topology=altered_old, new_topology=altered_new, transfer=altered_transfer)
        altered = execute_executable_diffusion_screen(altered_case)
        @test altered.status === :ready
        @test altered.transfer_receipt.receipt_hash != outcome.transfer_receipt.receipt_hash
        @test altered.assembly_hash != outcome.assembly_hash
        forged_topology = ExecutableTopologyIdentityV1("topology:old", "space:manufactured", 2,
            1/3, ("old-left", "old-right"); state_values=case.old_topology.state_values,
            state_semantics=:pre_transfer, semantic_digest=repeat("0", 64))
        forged_transfer = ExecutableTopologyTransferV1(forged_topology, case.new_topology,
            case.transfer.overlap, case.transfer.weights, "transfer:forged")
        forged_topology_outcome = execute_executable_diffusion_screen(
            replace_case(case; old_topology=forged_topology, transfer=forged_transfer))
        record_negative!(:topology_identity_mismatch, forged_topology_outcome)
        @test forged_topology_outcome.status === :fail_closed
        @test forged_topology_outcome.code === :topology_identity_mismatch

        renamed_old = ExecutableTopologyIdentityV1("topology:old", "space:manufactured", 2,
            1/3, ("renamed-old-left", "renamed-old-right");
            state_values=case.old_topology.state_values, state_semantics=:pre_transfer)
        renamed_new = ExecutableTopologyIdentityV1("topology:new", "space:manufactured", 2,
            1/3, ("renamed-new-left", "renamed-new-right");
            state_values=case.new_topology.state_values, state_semantics=:expected_post_transfer)
        renamed_transfer = ExecutableTopologyTransferV1(renamed_old, renamed_new,
            case.transfer.overlap, case.transfer.weights, "renamed-transfer")
        renamed_case = replace_case(case; old_topology=renamed_old,
            new_topology=renamed_new, transfer=renamed_transfer)
        renamed_outcome = execute_executable_diffusion_screen(renamed_case)
        @test renamed_outcome.status === :ready
        @test renamed_outcome.transfer_receipt.receipt_hash == outcome.transfer_receipt.receipt_hash
        @test renamed_outcome.assembly_hash == outcome.assembly_hash
        @test renamed_outcome.receipt.result_hash == outcome.receipt.result_hash
    end

    @testset "real variable-coefficient stencil, equation units, and hash drivers" begin
        base = assemble_variable_coefficient_diffusion(case.inputs, case.new_topology,
            case.transfer, case.plan; binding_digest=case.binding.binding_digest)
        @test base.matrix == ((27.0, -18.0), (-18.0, 31.5))
        @test base.rhs == (1.0, 13.0)
        @test validate_diffusion_equation_units(case.inputs).valid
        @test base.assembly_hash != assemble_variable_coefficient_diffusion(
            ExecutableDiffusionInputsV1((1.1, 2.0, 1.5), case.inputs.source, case.inputs.boundary),
            case.new_topology, case.transfer, case.plan; binding_digest=case.binding.binding_digest).assembly_hash
        same_ref_different_semantics = ExecutableTopologyIdentityV1("topology:new", "space:manufactured", 2,
            0.25, ("new-left", "new-right"); state_values=case.new_topology.state_values,
            state_semantics=:expected_post_transfer)
        @test_throws ArgumentError assemble_variable_coefficient_diffusion(case.inputs,
            same_ref_different_semantics, case.transfer, case.plan;
            binding_digest=case.binding.binding_digest)
        @test base.assembly_hash != assemble_variable_coefficient_diffusion(
            ExecutableDiffusionInputsV1(case.inputs.k_faces, (1.1, -0.5), case.inputs.boundary),
            case.new_topology, case.transfer, case.plan; binding_digest=case.binding.binding_digest).assembly_hash
        @test base.assembly_hash != assemble_variable_coefficient_diffusion(
            ExecutableDiffusionInputsV1(case.inputs.k_faces, case.inputs.source, (0.0, 0.0)),
            case.new_topology, case.transfer, case.plan; binding_digest=case.binding.binding_digest).assembly_hash
    end

    @testset "typed accounts/effects, closure, labels, and permutation — label erasure and component permutation invariance" begin
        unit = ExecutableDiffusionUnitV1(:field, (0,0,0,0,0,0,0))
        renamed_plan = ExecutableCompositionPlanV1((
            ExecutableComponentV1("arbitrary-B", (ExecutableTypedPortV1("arbitrary-in", :input, unit, "acct-B", -1),)),
            ExecutableComponentV1("arbitrary-A", (ExecutableTypedPortV1("arbitrary-out", :output, unit, "acct-B", 1),))),
            "renamed-plan")
        permuted_plan = ExecutableCompositionPlanV1(reverse(renamed_plan.components), "other-plan")
        @test validate_executable_composition(renamed_plan).valid
        @test validate_executable_composition(permuted_plan).conservation_residual == 0.0
        @test assemble_variable_coefficient_diffusion(case.inputs, case.new_topology,
            case.transfer, renamed_plan; binding_digest=case.binding.binding_digest).assembly_hash ==
            assemble_variable_coefficient_diffusion(case.inputs, case.new_topology,
            case.transfer, permuted_plan; binding_digest=case.binding.binding_digest).assembly_hash
        permuted_outcome = execute_executable_diffusion_screen(replace_case(case; plan=permuted_plan))
        @test permuted_outcome.status === :ready
        @test permuted_outcome.transfer_receipt.receipt_hash == outcome.transfer_receipt.receipt_hash
        @test permuted_outcome.assembly_hash == outcome.assembly_hash
        @test permuted_outcome.receipt.result_hash == outcome.receipt.result_hash
        @test_throws ArgumentError ExecutableTypedPortV1("bad", :output, unit, "field", -1)
    end

    @testset "deterministic invalid classifications and nonfinite guards" begin
        unit = ExecutableDiffusionUnitV1(:field, (0,0,0,0,0,0,0))
        duplicate = ExecutableCompositionPlanV1((
            ExecutableComponentV1("p1", (ExecutableTypedPortV1("o1", :output, unit, "field", 1),)),
            ExecutableComponentV1("p2", (ExecutableTypedPortV1("o2", :output, unit, "field", 1),)),
            ExecutableComponentV1("consumer", (ExecutableTypedPortV1("i", :input, unit, "field", -1),))), "duplicate")
        duplicate_outcome = execute_executable_diffusion_screen(replace_case(case; plan=duplicate))
        record_negative!(:duplicate_producer, duplicate_outcome)
        @test duplicate_outcome.status === :fail_closed && duplicate_outcome.code === :duplicate_producer
        @test_throws ArgumentError assemble_variable_coefficient_diffusion(case.inputs,
            case.new_topology, case.transfer, duplicate; binding_digest=case.binding.binding_digest)

        bad_unit = ExecutableDiffusionUnitV1(:field, (1,0,0,0,0,0,0))
        mismatch = ExecutableCompositionPlanV1((
            ExecutableComponentV1("p", (ExecutableTypedPortV1("o", :output, unit, "field", 1),)),
            ExecutableComponentV1("c", (ExecutableTypedPortV1("i", :input, bad_unit, "field", -1),))), "unit")
        mismatch_outcome = execute_executable_diffusion_screen(replace_case(case; plan=mismatch))
        record_negative!(:unit_mismatch, mismatch_outcome)
        @test mismatch_outcome.status === :fail_closed && mismatch_outcome.code === :unit_mismatch
        @test_throws ArgumentError assemble_variable_coefficient_diffusion(case.inputs,
            case.new_topology, case.transfer, mismatch; binding_digest=case.binding.binding_digest)

        wrong_source_unit = ExecutableDiffusionUnitV1(:source, (1,0,0,0,0,0,0))
        bad_equation_inputs = ExecutableDiffusionInputsV1(case.inputs.k_faces, case.inputs.source,
            case.inputs.boundary; equation_units=(k_unit=case.inputs.equation_units.k_unit,
                source_unit=wrong_source_unit, boundary_unit=case.inputs.equation_units.boundary_unit))
        equation_outcome = execute_executable_diffusion_screen(replace_case(case; inputs=bad_equation_inputs))
        record_negative!(:equation_unit_mismatch, equation_outcome)
        @test equation_outcome.status === :fail_closed && equation_outcome.code === :equation_unit_mismatch

        missing = ExecutableCompositionPlanV1((
            ExecutableComponentV1("c", (ExecutableTypedPortV1("i", :input, unit, "field", -1),)),), "missing")
        missing_outcome = execute_executable_diffusion_screen(replace_case(case; plan=missing))
        record_negative!(:missing_closure, missing_outcome)
        @test missing_outcome.status === :fail_closed && missing_outcome.code === :missing_closure
        @test_throws ArgumentError assemble_variable_coefficient_diffusion(case.inputs,
            case.new_topology, case.transfer, missing; binding_digest=case.binding.binding_digest)

        invalid_transfer = ExecutableTopologyTransferV1(case.transfer.old, case.transfer.new,
            (0.8, 0.2), (0.5, 0.5), "invalid-overlap")
        invalid_outcome = execute_executable_diffusion_screen(replace_case(case; transfer=invalid_transfer))
        record_negative!(:invalid_overlap, invalid_outcome)
        @test invalid_outcome.status === :terminal_deferred && invalid_outcome.code === :invalid_overlap
        @test_throws ArgumentError assemble_variable_coefficient_diffusion(case.inputs,
            case.new_topology, invalid_transfer, case.plan; binding_digest=case.binding.binding_digest)

        singular = ExecutableDiffusionAssemblyV1(((1.0, 1.0), (1.0, 1.0)), (1.0, 1.0),
            (0.0, 0.0), "singular-transfer", "singular")
        x, residual, status, code = solve_joint_linear_screen(singular)
        observed_negative["singular_matrix"] = (status, code)
        @test x === nothing && isfinite(residual)
        @test status === :numerical_fail && code === :singular_matrix
        nonfinite = ExecutableDiffusionAssemblyV1(((NaN, 1.0), (1.0, 1.0)), (1.0, 1.0),
            (0.0, 0.0), "nonfinite-transfer", "nonfinite")
        x, residual, status, code = solve_joint_linear_screen(nonfinite)
        observed_negative["nonfinite_derived"] = (status, code)
        @test x === nothing && isfinite(residual)
        @test status === :numerical_fail && code === :nonfinite_derived
    end

    fixture = JSON3.read(read(joinpath(@__DIR__, "up2_executable_diffusion_transfer_composition_v1_fixture.json"), String))
    expected_negative = Dict{String,Tuple{Symbol,Symbol}}()
    for (name, expectation) in pairs(fixture.negative_expectations)
        expected_negative[String(name)] = (Symbol(String(expectation.status)), Symbol(String(expectation.code)))
    end
    @test Set(keys(observed_negative)) == Set(keys(expected_negative))
    @test observed_negative == expected_negative
end
