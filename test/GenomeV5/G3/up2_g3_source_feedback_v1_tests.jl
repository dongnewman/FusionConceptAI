using Test
using JSON3
using FusionConceptAI

const _G3SF_ROOT = joinpath(@__DIR__, "..", "..", "..", "src", "GenomeV5", "G3")
Base.include(FusionConceptAI, joinpath(_G3SF_ROOT, "G3SourceFeedbackLawV1.jl"))
const G = FusionConceptAI
const _G3SF_FIXTURE = JSON3.read(read(joinpath(@__DIR__, "up2_g3_source_feedback_v1_fixture.json"), String))

_g3sf_rat(v) = Rational{Int64}(Int(v[1]), Int(v[2]))
_g3sf_unit(v) = UnitSignature(ntuple(i -> Rational{Int64}(Int(v[i])), 7))
_g3sf_candidate() = QualifiedRefV1(String(_G3SF_FIXTURE.candidate_ref.id), String(_G3SF_FIXTURE.candidate_ref.version))

function _g3sf_build(; field_unit=nothing, source_unit=nothing, authority_status=:missing,
        authority_attestation=:unattested)
    owner = String(_G3SF_FIXTURE.owner_scope)
    unit = _g3sf_unit(_G3SF_FIXTURE.unit_watts)
    source_u = source_unit === nothing ? unit : source_unit
    field_u = field_unit === nothing ? unit : field_unit
    endpoints = Tuple(begin
        role = Symbol(String(e.role))
        eu = role === :source ? source_u : role === :field ? field_u : unit
        G.G3SFEndpointV1(String(e.id), role, eu, Symbol(String(e.direction)), Int(e.sign), owner)
    end for e in _G3SF_FIXTURE.endpoints)
    lawf = _G3SF_FIXTURE.law
    splitf = lawf.conservative_split
    split = G.G3SFConservativeSplitV1(_g3sf_rat(splitf.field_fraction), _g3sf_rat(splitf.return_fraction),
        _g3sf_rat(splitf.heat_fraction))
    heatf = lawf.heat_relation
    heat = G.G3SFHeatRelationV1(Symbol(String(heatf.source_role)), Symbol(String(heatf.heat_role)),
        _g3sf_rat(heatf.fraction))
    ledgerf = lawf.ledger_relation
    ledger = G.G3SFLedgerRelationV1(Tuple(Symbol(String(x)) for x in ledgerf.entry_roles),
        _g3sf_rat(ledgerf.expected_residual))
    law = G.G3SFLawV1(String(lawf.id), "source-power", "field-power", "return-power", "heat-power",
        _g3sf_rat(lawf.efficiency), _g3sf_rat(lawf.heat_fraction), split, heat, ledger, owner)
    entries = Tuple(begin
        G.G3SFLedgerEntryV1(String(e.id), String(e.endpoint_id),
            String(e.endpoint_id) == "field-power" ? field_u : source_u,
            Symbol(String(e.direction)), Int(e.sign), Symbol(String(e.effect)),
            _g3sf_rat(e.coefficient), owner)
    end for e in _G3SF_FIXTURE.ledger_entries)
    closuref = _G3SF_FIXTURE.ledger_closure
    closure = G.G3SFLedgerClosureV1(String(closuref.id), Tuple(String(x) for x in closuref.entry_ids),
        _g3sf_rat(closuref.expected_residual), unit, owner)
    authorities = Tuple(begin
        layer = Symbol(String(a.layer))
        if authority_status === :actual
            ref = GenomeContractRef("fusionconceptai://GenomeV5/" * String(layer) * "/foreign",
                "v5", digest256_text("foreign-schema"), digest256_text("foreign-canonical"), "foreign-profile")
            source_ref = QualifiedRefV1("fusionconceptai://GenomeV5/" * String(layer) * "/source-foreign", "v1")
            source_bytes = 1234
            source_sha256 = digest256_text("foreign-source-bytes-" * String(layer))
            content_hash = G.g3_sf_authority_content_hash_v1(layer, _g3sf_candidate(), ref,
                source_ref, source_bytes, source_sha256)
            G.G3SFAuthorityV1(layer, _g3sf_candidate(), ref, content_hash, authority_status;
                attestation=authority_attestation, source_ref=source_ref,
                source_bytes=source_bytes, source_sha256=source_sha256)
        else
            G.G3SFAuthorityV1(layer, _g3sf_candidate(), nothing, nothing, authority_status)
        end
    end for a in _G3SF_FIXTURE.upstream_authority)
    auth_map = Dict(a.layer => a for a in authorities)
    feedback = Tuple(begin
        layer = Symbol(String(f.layer))
        G.G3SFFeedbackTargetV1(String(f.id), layer, String(f.path), Symbol(String(f.quantity)),
            unit, Symbol(String(f.direction)), Int(f.sign), String(_G3SF_FIXTURE.source_id), owner,
            auth_map[layer])
    end for f in _G3SF_FIXTURE.feedback_targets)
    G.g3_sf_declaration_v1(_g3sf_candidate(), String(_G3SF_FIXTURE.source_id), owner,
        endpoints, law, entries, closure, feedback, authorities)
end

@testset "UP2-01 G3 source/feedback typed law" begin
    @test String(_G3SF_FIXTURE.fixture_id) == "UP2-01-G3-SOURCE-FEEDBACK-V1-FX-001"
    declaration = _g3sf_build()
    @test G.g3_sf_schema_hash_v1() isa Digest256
    @test declaration.declaration_hash == G.g3_sf_declaration_hash_v1(declaration)
    @test G.g3_sf_validate_v1(declaration)[1] == :valid
    value = G.g3_sf_evaluate_v1(declaration, 120)
    @test value.field_power == 90
    @test value.return_power == 15
    @test value.heat_power == 15
    @test value.energy_residual == 0
    @test value.ledger_residual == 0
end

@testset "UP2-01 G3 external authority and resolution ceiling" begin
    declaration = _g3sf_build()
    receipt = G.g3_sf_admit_v1(declaration)
    @test receipt.status == :proposal
    @test receipt.accepted === false
    @test receipt.resolution == :terminal_deferred
    @test receipt.claim_ceiling == :contract_only
    @test receipt.compiler_calls == 0 && receipt.provider_calls == 0
    @test receipt.mesh_calls == 0 && receipt.solver_calls == 0
    @test receipt.physical_evidence === false
    @test "external_authority_gap:G1" in receipt.gaps
    @test "external_authority_gap:G2" in receipt.gaps
end

@testset "UP2-01 G3 typed contradiction and edit identity" begin
    declaration = _g3sf_build()
    bad_unit = UnitSignature((0, 0, 0, 0, 0, 0, 0))
    bad = _g3sf_build(field_unit=bad_unit)
    @test G.g3_sf_validate_v1(bad)[1] == :fail_closed
    @test "source_output_unit_mismatch" in G.g3_sf_validate_v1(bad)[2]
    contradictory = _g3sf_build(authority_status=:contradictory)
    @test G.g3_sf_admit_v1(contradictory).status == :fail_closed
    @test "authority_contradiction:G1" in G.g3_sf_admit_v1(contradictory).errors
    actual = _g3sf_build(authority_status=:actual)
    @test G.g3_sf_admit_v1(actual).status == :fail_closed
    @test "unattested_authority:G1" in G.g3_sf_admit_v1(actual).errors
    trusted_looking = _g3sf_build(authority_status=:actual, authority_attestation=:trusted_receipt)
    @test G.g3_sf_admit_v1(trusted_looking).resolution == :terminal_deferred
    @test "same_candidate_authority_gate:VNEXT:G1" in G.g3_sf_admit_v1(trusted_looking).gaps
    tampered = G.G3SFDeclarationV1(declaration.candidate_ref, declaration.source_id, declaration.owner_scope,
        declaration.endpoints, declaration.law, declaration.ledger_entries, declaration.ledger_closure,
        declaration.feedback_targets, declaration.upstream_authority, digest256_text("tampered"))
    @test G.g3_sf_admit_v1(tampered).status == :fail_closed
    @test "declaration_hash_mismatch" in G.g3_sf_admit_v1(tampered).errors
    bad_entries = Tuple(e.entry_id == "field-entry" ?
        G.G3SFLedgerEntryV1(e.entry_id, e.endpoint_id, e.unit, e.direction, e.sign, e.effect, -1 // 2, e.owner_scope) : e
        for e in declaration.ledger_entries)
    bad_ledger = G.g3_sf_declaration_v1(declaration.candidate_ref, declaration.source_id, declaration.owner_scope,
        declaration.endpoints, declaration.law, bad_entries, declaration.ledger_closure,
        declaration.feedback_targets, declaration.upstream_authority)
    @test G.g3_sf_admit_v1(bad_ledger).status == :fail_closed
    @test "ledger_coefficient_mismatch:field-entry" in G.g3_sf_admit_v1(bad_ledger).errors
    @test_throws ArgumentError G.g3_sf_evaluate_v1(bad_ledger, 120)
    @test_throws MethodError G.g3_sf_admit_v1(declaration; fault_seam=:internal_validation_fault)
    @test G._g3sf_admit_fault_seam_v1(declaration).status == :program_exception
    @test G._g3sf_admit_fault_seam_v1(declaration).resolution == :program_exception
    @test G.G3SFConservativeSplitV1(3 // 4, 1 // 8, 1 // 8).field_fraction == 3 // 4
    @test_throws ArgumentError G.G3SFLawV1("bad-law", "source-power", "field-power", "return-power", "heat-power",
        3 // 4, 1 // 8, declaration.law.conservative_split, G.G3SFHeatRelationV1(:source, :heat, 1 // 4), declaration.law.ledger_relation,
        declaration.owner_scope)
    edited = G.g3_sf_edit_efficiency_v1(declaration, 7 // 8)
    @test edited.declaration_hash != declaration.declaration_hash
    edited_value = G.g3_sf_evaluate_v1(edited, 120)
    @test edited_value.field_power == 105
    @test edited_value.return_power == 0
    @test edited_value.heat_power == 15
    @test edited_value.energy_residual == 0
    @test edited_value.ledger_residual == 0
    edited_coefficients = Dict(e.effect => e.coefficient for e in edited.ledger_entries)
    @test edited_coefficients == Dict(:source => 1 // 1, :field => -7 // 8,
        :return => 0 // 1, :heat => -1 // 8)
    @test G.g3_sf_admit_v1(nothing).status == :fail_closed
    @test G.g3_sf_admit_v1(nothing).resolution == :fail_closed
end

@testset "UP2-01 G3 duplicate and pairing rejection" begin
    declaration = _g3sf_build()
    actual_ref = G.GenomeContractRef("fusionconceptai://GenomeV5/G1/foreign", "v5",
        digest256_text("foreign-schema"), digest256_text("foreign-canonical"), "foreign-profile")
    actual_source_ref = QualifiedRefV1("fusionconceptai://GenomeV5/G1/source-foreign", "v1")
    actual_source_bytes = 1234
    actual_source_sha256 = digest256_text("foreign-source-bytes-G1")
    actual_hash = G.g3_sf_authority_content_hash_v1(:G1, declaration.candidate_ref,
        actual_ref, actual_source_ref, actual_source_bytes, actual_source_sha256)
    @test_throws ArgumentError G.G3SFAuthorityV1(:G1, declaration.candidate_ref,
        actual_ref, nothing, :actual; attestation=:trusted_receipt,
        source_ref=actual_source_ref, source_bytes=actual_source_bytes,
        source_sha256=actual_source_sha256)
    @test_throws ArgumentError G.G3SFAuthorityV1(:G1, declaration.candidate_ref,
        nothing, actual_hash, :actual; attestation=:trusted_receipt,
        source_ref=actual_source_ref, source_bytes=actual_source_bytes,
        source_sha256=actual_source_sha256)

    status_body_authority = G.G3SFAuthorityV1(:G1, declaration.candidate_ref,
        actual_ref, actual_hash, :missing; source_ref=actual_source_ref,
        source_bytes=actual_source_bytes, source_sha256=actual_source_sha256)
    status_body = G.g3_sf_declaration_v1(declaration.candidate_ref, declaration.source_id,
        declaration.owner_scope, declaration.endpoints, declaration.law, declaration.ledger_entries,
        declaration.ledger_closure, declaration.feedback_targets,
        (status_body_authority, declaration.upstream_authority[2]))
    status_body_receipt = G.g3_sf_admit_v1(status_body)
    @test status_body_receipt.status == :fail_closed
    @test "authority_status_body_mismatch:G1" in status_body_receipt.errors

    wrong_layer_ref = G.GenomeContractRef("fusionconceptai://GenomeV5/G2/foreign", "v5",
        digest256_text("foreign-schema"), digest256_text("foreign-canonical"), "foreign-profile")
    wrong_layer_source_ref = QualifiedRefV1("fusionconceptai://GenomeV5/G2/source-foreign", "v1")
    wrong_layer_hash = G.g3_sf_authority_content_hash_v1(:G1, declaration.candidate_ref,
        wrong_layer_ref, wrong_layer_source_ref, actual_source_bytes, actual_source_sha256)
    wrong_layer_authority = G.G3SFAuthorityV1(:G1, declaration.candidate_ref,
        wrong_layer_ref, wrong_layer_hash, :actual; attestation=:trusted_receipt,
        source_ref=wrong_layer_source_ref, source_bytes=actual_source_bytes,
        source_sha256=actual_source_sha256)
    wrong_layer_target = G.G3SFFeedbackTargetV1(
        declaration.feedback_targets[1].target_id,
        declaration.feedback_targets[1].target_layer,
        declaration.feedback_targets[1].target_path,
        declaration.feedback_targets[1].quantity,
        declaration.feedback_targets[1].unit,
        declaration.feedback_targets[1].direction,
        declaration.feedback_targets[1].sign,
        declaration.feedback_targets[1].source_id,
        declaration.feedback_targets[1].owner_scope,
        wrong_layer_authority)
    wrong_layer = G.g3_sf_declaration_v1(declaration.candidate_ref, declaration.source_id,
        declaration.owner_scope, declaration.endpoints, declaration.law, declaration.ledger_entries,
        declaration.ledger_closure, (wrong_layer_target, declaration.feedback_targets[2]),
        (wrong_layer_authority, declaration.upstream_authority[2]))
    wrong_layer_receipt = G.g3_sf_admit_v1(wrong_layer)
    @test wrong_layer_receipt.status == :fail_closed
    @test "authority_contract_namespace_mismatch:G1" in wrong_layer_receipt.errors
    @test "authority_source_namespace_mismatch:G1" in wrong_layer_receipt.errors

    wrong_hash_authority = G.G3SFAuthorityV1(:G1, declaration.candidate_ref,
        actual_ref, digest256_text("wrong-bound-hash"), :actual; attestation=:trusted_receipt,
        source_ref=actual_source_ref, source_bytes=actual_source_bytes,
        source_sha256=actual_source_sha256)
    wrong_hash_target = G.G3SFFeedbackTargetV1(
        declaration.feedback_targets[1].target_id,
        declaration.feedback_targets[1].target_layer,
        declaration.feedback_targets[1].target_path,
        declaration.feedback_targets[1].quantity,
        declaration.feedback_targets[1].unit,
        declaration.feedback_targets[1].direction,
        declaration.feedback_targets[1].sign,
        declaration.feedback_targets[1].source_id,
        declaration.feedback_targets[1].owner_scope,
        wrong_hash_authority)
    wrong_hash = G.g3_sf_declaration_v1(declaration.candidate_ref, declaration.source_id,
        declaration.owner_scope, declaration.endpoints, declaration.law, declaration.ledger_entries,
        declaration.ledger_closure, (wrong_hash_target, declaration.feedback_targets[2]),
        (wrong_hash_authority, declaration.upstream_authority[2]))
    wrong_hash_receipt = G.g3_sf_admit_v1(wrong_hash)
    @test wrong_hash_receipt.status == :fail_closed
    @test "authority_contract_hash_source_binding_mismatch:G1" in wrong_hash_receipt.errors

    duplicate_authority = G.g3_sf_declaration_v1(declaration.candidate_ref, declaration.source_id,
        declaration.owner_scope, declaration.endpoints, declaration.law, declaration.ledger_entries,
        declaration.ledger_closure, declaration.feedback_targets,
        (declaration.upstream_authority[1], declaration.upstream_authority[1], declaration.upstream_authority[2]))
    duplicate_authority_receipt = G.g3_sf_admit_v1(duplicate_authority)
    @test duplicate_authority_receipt.status == :fail_closed
    @test "duplicate_upstream_authority_layer" in duplicate_authority_receipt.errors

    duplicate_target = G.g3_sf_declaration_v1(declaration.candidate_ref, declaration.source_id,
        declaration.owner_scope, declaration.endpoints, declaration.law, declaration.ledger_entries,
        declaration.ledger_closure, (declaration.feedback_targets[1], declaration.feedback_targets[1]),
        declaration.upstream_authority)
    duplicate_target_receipt = G.g3_sf_admit_v1(duplicate_target)
    @test duplicate_target_receipt.status == :fail_closed
    @test "duplicate_feedback_target_id" in duplicate_target_receipt.errors
    @test "duplicate_or_ambiguous_feedback_target" in duplicate_target_receipt.errors

    duplicate_closure = G.G3SFLedgerClosureV1(declaration.ledger_closure.closure_id,
        (declaration.ledger_closure.entry_ids[1], declaration.ledger_closure.entry_ids[1],
         declaration.ledger_closure.entry_ids[2], declaration.ledger_closure.entry_ids[3],
         declaration.ledger_closure.entry_ids[4]), declaration.ledger_closure.expected_residual,
        declaration.ledger_closure.unit, declaration.ledger_closure.owner_scope)
    duplicate_closure_declaration = G.g3_sf_declaration_v1(declaration.candidate_ref,
        declaration.source_id, declaration.owner_scope, declaration.endpoints, declaration.law,
        declaration.ledger_entries, duplicate_closure, declaration.feedback_targets,
        declaration.upstream_authority)
    duplicate_closure_receipt = G.g3_sf_admit_v1(duplicate_closure_declaration)
    @test duplicate_closure_receipt.status == :fail_closed
    @test "duplicate_ledger_closure_entry_id" in duplicate_closure_receipt.errors

    mismatched_feedback_authority = G.G3SFFeedbackTargetV1(
        declaration.feedback_targets[1].target_id,
        declaration.feedback_targets[1].target_layer,
        declaration.feedback_targets[1].target_path,
        declaration.feedback_targets[1].quantity,
        declaration.feedback_targets[1].unit,
        declaration.feedback_targets[1].direction,
        declaration.feedback_targets[1].sign,
        declaration.feedback_targets[1].source_id,
        declaration.feedback_targets[1].owner_scope,
        G.G3SFAuthorityV1(:G1, declaration.candidate_ref, nothing, nothing, :stale))
    mismatched_feedback = G.g3_sf_declaration_v1(declaration.candidate_ref, declaration.source_id,
        declaration.owner_scope, declaration.endpoints, declaration.law, declaration.ledger_entries,
        declaration.ledger_closure, (mismatched_feedback_authority, declaration.feedback_targets[2]),
        declaration.upstream_authority)
    mismatched_feedback_receipt = G.g3_sf_admit_v1(mismatched_feedback)
    @test mismatched_feedback_receipt.status == :fail_closed
    @test "feedback_authority_mismatch:g1-field-residual" in mismatched_feedback_receipt.errors
end
