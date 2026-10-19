using FusionConceptAI, JSON3, SHA

const ROOT = normpath(joinpath(@__DIR__, "..", "..", ".."))
include(joinpath(ROOT, "test", "RuntimeV4", "SpatialMultiRegionGlobalWeakV1",
    "global_weak_consumer_tests_v1.jl"))
const T = SpatialMultiRegionGlobalWeakV1Tests
const S = T.S

function main()
    source_root = get(ENV, "UP2_Q1_COARSE_SOURCE_ROOT", "")
    out = get(ENV, "UP2_Q1_SAVED_AUDIT_OUTPUT", "")
    isempty(source_root) && error("UP2_Q1_COARSE_SOURCE_ROOT is required")
    isempty(out) && error("UP2_Q1_SAVED_AUDIT_OUTPUT is required")
    for name in ("transferred_q1_8_state.json", "mergeback_q1_4_state.json",
            "saved_transfer_audit.json")
        ispath(joinpath(out, name)) && error("preserve existing saved transfer audit file: $(joinpath(out, name))")
    end
    mkpath(out)

    source = T._q1_4_continuation_source_v1(source_root)
    coarse_input = S.spatial_n1_manufactured_input_v1(; level=:q1_4)
    coarse_declaration = S.spatial_n1_manufactured_declaration_v1(coarse_input)
    fine_input = S.spatial_n1_manufactured_input_v1(; level=:q1_8)
    fine_declaration = S.spatial_n1_manufactured_declaration_v1(fine_input)
    fine_context = T.fresh_manufactured_context(fine_input, fine_declaration;
        parent_context=source.parent_context)[1]
    coarse_record = S._smgw_current_q1_4_artifact_state_v1(
        source.context, source.production_dir, fine_context)

    coarse_data = S.spatial_manufactured_geometry_samples_v1(coarse_record.input)
    fine_data = S.spatial_manufactured_geometry_samples_v1(fine_input)
    pressure_scale = coarse_declaration.scaling.p_Pa
    transferred = S.spatial_q1_4_to_q1_8_initial_state_v1(coarse_record.input,
        coarse_record.mesh, coarse_record.state, fine_input, fine_data.mesh;
        pressure_scale_Pa=pressure_scale)
    merged = S.spatial_q1_nested_mergeback_v1(coarse_record.input,
        coarse_record.mesh, transferred, fine_input, fine_data.mesh;
        pressure_scale_Pa=pressure_scale)
    audit = S.spatial_q1_nested_saved_field_audit_v1(coarse_record.input,
        coarse_data, coarse_record.state, fine_input, fine_data;
        pressure_scale_Pa=pressure_scale)
    string(S.canonical_hash(Tuple(transferred))) == audit.transferred_state_hash ||
        error("saved audit does not match the production Q1_4-to-Q1_8 warm-start consumer output")

    write(joinpath(out, "transferred_q1_8_state.json"), JSON3.write(transferred))
    write(joinpath(out, "mergeback_q1_4_state.json"), JSON3.write(merged))
    write(joinpath(out, "saved_transfer_audit.json"), JSON3.write((
        schema="up2-q1-nested-saved-transfer-audit-v1",
        status="evaluated_saved_source_state_no_solver",
        source_root=abspath(source_root),
        source_receipt_sha256=bytes2hex(SHA.sha256(read(joinpath(source_root,
            "q1_4_consumer", "q1_4_validation_receipt.json")))),
        source_state_hash=coarse_record.state_hash,
        source_result_hash=coarse_record.result_hash,
        source_candidate_hash=string(source.context.candidate_hash),
        target_candidate_hash=string(fine_context.candidate_hash),
        audit=audit,
        transfer_state_sha256=bytes2hex(SHA.sha256(read(joinpath(out,
            "transferred_q1_8_state.json")))),
        mergeback_state_sha256=bytes2hex(SHA.sha256(read(joinpath(out,
            "mergeback_q1_4_state.json")))),
        solver_execution=:not_executed,
        formal_acceptance=false, physical_validation=:not_assessed)))
    println("UP2_Q1_NESTED_SAVED_AUDIT status=evaluated_saved_source_state_no_solver",
        " source_state_hash=", coarse_record.state_hash,
        " mergeback_max_abs=", audit.mergeback_max_abs,
        " field_and_divB_preserved=", audit.field_and_divB_preserved,
        " geometry_restriction_relative=", audit.physical_geometry_restriction_relative,
        " geometry_restriction_passed=", audit.physical_geometry_restriction_passed)
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
