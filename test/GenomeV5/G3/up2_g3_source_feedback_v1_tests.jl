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
            G.G3SFAuthorityV1(layer, _g3sf_candidate(), ref, digest256_text("foreign-content"), authority_status;
                attestation=authority_attestation)
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
