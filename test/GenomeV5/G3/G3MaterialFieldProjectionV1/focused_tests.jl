using Test
using JSON3
using SHA
using FusionConceptAI

const _G3MFP_ROOT = joinpath(@__DIR__, "..", "..", "..", "..", "src", "GenomeV5", "G3")
Base.include(FusionConceptAI, joinpath(_G3MFP_ROOT, "RealizationGenomeV5.jl"))
Base.include(FusionConceptAI, joinpath(_G3MFP_ROOT, "G3SourceFeedbackLawV1.jl"))
Base.include(FusionConceptAI, joinpath(_G3MFP_ROOT, "G3MaterialFieldProjectionV1.jl"))
const G = FusionConceptAI
const _G3MFP_FIXTURE = JSON3.read(read(joinpath(@__DIR__, "..", "up2_g3_source_feedback_v1_fixture.json"), String))

_g3mfp_rat(v) = Rational{Int64}(Int(v[1]), Int(v[2]))
_g3mfp_unit(v) = UnitSignature(ntuple(i -> Rational{Int64}(Int(v[i])), 7))
_g3mfp_candidate() = QualifiedRefV1(String(_G3MFP_FIXTURE.candidate_ref.id),
    String(_G3MFP_FIXTURE.candidate_ref.version))
_g3mfp_bytes(s) = Vector{UInt8}(codeunits(String(s)))

function _g3mfp_declaration()
    candidate = _g3mfp_candidate()
    owner = String(_G3MFP_FIXTURE.owner_scope)
    watts = _g3mfp_unit(_G3MFP_FIXTURE.unit_watts)
    endpoints = Tuple(G.G3SFEndpointV1(String(e.id), Symbol(String(e.role)), watts,
        Symbol(String(e.direction)), Int(e.sign), owner) for e in _G3MFP_FIXTURE.endpoints)
    lawf = _G3MFP_FIXTURE.law
    splitf = lawf.conservative_split
    split = G.G3SFConservativeSplitV1(_g3mfp_rat(splitf.field_fraction),
        _g3mfp_rat(splitf.return_fraction), _g3mfp_rat(splitf.heat_fraction))
    heatf = lawf.heat_relation
    heat = G.G3SFHeatRelationV1(Symbol(String(heatf.source_role)),
        Symbol(String(heatf.heat_role)), _g3mfp_rat(heatf.fraction))
    ledgerf = lawf.ledger_relation
    ledger = G.G3SFLedgerRelationV1(Tuple(Symbol(String(x)) for x in ledgerf.entry_roles),
        _g3mfp_rat(ledgerf.expected_residual))
    law = G.G3SFLawV1(String(lawf.id), "source-power", "field-power", "return-power",
        "heat-power", _g3mfp_rat(lawf.efficiency), _g3mfp_rat(lawf.heat_fraction),
        split, heat, ledger, owner)
    entries = Tuple(G.G3SFLedgerEntryV1(String(e.id), String(e.endpoint_id), watts,
        Symbol(String(e.direction)), Int(e.sign), Symbol(String(e.effect)),
        _g3mfp_rat(e.coefficient), owner) for e in _G3MFP_FIXTURE.ledger_entries)
    closuref = _G3MFP_FIXTURE.ledger_closure
    closure = G.G3SFLedgerClosureV1(String(closuref.id),
        Tuple(String(x) for x in closuref.entry_ids), _g3mfp_rat(closuref.expected_residual),
        watts, owner)
    authorities = Tuple(G.G3SFAuthorityV1(Symbol(String(a.layer)), candidate, nothing,
        nothing, Symbol(String(a.status))) for a in _G3MFP_FIXTURE.upstream_authority)
    authority_map = Dict(a.layer => a for a in authorities)
    feedback = Tuple(begin
        layer = Symbol(String(f.layer))
        G.G3SFFeedbackTargetV1(String(f.id), layer, String(f.path),
            Symbol(String(f.quantity)), watts, Symbol(String(f.direction)), Int(f.sign),
            String(_G3MFP_FIXTURE.source_id), owner, authority_map[layer])
    end for f in _G3MFP_FIXTURE.feedback_targets)
    G.g3_sf_declaration_v1(candidate, String(_G3MFP_FIXTURE.source_id), owner,
        endpoints, law, entries, closure, feedback, authorities)
end

function _g3mfp_inputs(; provenance=:synthetic_local, jacobian_included=true,
        selection_regions=("core", "blanket"), shape_weights=(1 // 1, 3 // 1),
        volumes=(2 // 1, 1 // 1), candidate=_g3mfp_candidate(), power=120 // 1,
        unit=G.G3_MFP_V1_W_UNIT, unit_id="W", scale=1 // 1)
    declaration = _g3mfp_declaration()
    condition = QualifiedRefV1("local://operation/nominal", "v1")
    condition_hash = digest256_text("nominal-operating-condition-fixture")
    power_bytes = _g3mfp_bytes("synthetic operating-power fixture: nominal 120 W")
    witness = G.G3MFPOperatingPowerWitnessV1(candidate,
        QualifiedRefV1("fusionconceptai://GenomeV5/G3/source-record/" * declaration.source_id, "v1"),
        declaration.source_id, declaration.declaration_hash, declaration.law.source_endpoint_id,
        condition, condition_hash, power, unit_id, unit, scale,
        QualifiedRefV1("local://fixture/source-power-bytes", "v1"), power_bytes,
        QualifiedRefV1("local://authority/source-record", "v1"), :synthetic_local)
    supports = Tuple(G.G3MFPRegionSupportV1(selection_regions[i], shape_weights[i], volumes[i])
        for i in eachindex(selection_regions))
    measure = G.G3MFPPhysicalMeasureReceiptV1(candidate,
        QualifiedRefV1("local://g2/map", "v1"), digest256_text("synthetic-g2-map-fixture"),
        provenance, jacobian_included, supports,
        QualifiedRefV1("local://fixture/physical-measure", "v1"),
        _g3mfp_bytes("synthetic physical-mapped-volume fixture"),
        QualifiedRefV1("local://authority/measure", "v1"), :synthetic_local)
    conductivity_unit = G.G3_MFP_V1_W_PER_M_K_UNIT
    selections = Tuple(begin
        material_id = region == "core" ? "mat-core" : "mat-blanket"
        component = G.G3RealizationComponentV2("component-" * region, :passive,
            (), 1 // 1, UnitSignature((0, 0, 0, 0, 0, 0, 0)), material_id,
            "process-" * region, true)
        domain = G.G3MaterialDomainV2(material_id, :conductivity, 1 // 1, 50 // 1,
            conductivity_unit)
        G.G3MFPConductivitySelectionV1(candidate, region, component, domain,
            region == "core" ? 10 // 1 : 20 // 1, "W/(m*K)", 1 // 1,
            condition, condition_hash,
            QualifiedRefV1("local://fixture/material/" * region, "v1"),
            _g3mfp_bytes("synthetic SI conductivity fixture " * region),
            QualifiedRefV1("local://authority/material-selection", "v1"),
            :synthetic_local)
    end for region in selection_regions)
    declaration, witness, measure, selections, condition, condition_hash
end

@testset "G3MaterialFieldProjectionV1 source and unit binding" begin
    declaration, witness, measure, selections, condition, condition_hash = _g3mfp_inputs()
    @test G.G3_MFP_V1_SI_BASIS == (:kg, :m, :s, :A, :K, :mol, :cd)
    @test witness.source_evidence_sha256 ==
        Digest256(bytes2hex(SHA.sha256(collect(witness.source_evidence_bytes))))
    @test G._g3mfp_power_witness_valid(witness)
    @test all(G._g3mfp_selection_valid, selections)
    @test G._g3mfp_measure_valid(measure)
    @test witness.operating_condition_ref == condition
    @test witness.authority_scope == :synthetic_local
    @test witness.authority_binding_hash isa Digest256
    @test all(s -> s.authority_scope == :synthetic_local && s.authority_binding_hash isa Digest256, selections)
    @test G.g3_sf_validate_v1(declaration)[1] == :valid
    @test_throws ArgumentError G.G3MFPOperatingPowerWitnessV1(
        witness.candidate_ref, witness.source_ref, witness.source_id,
        witness.declaration_hash, witness.endpoint_id, condition, condition_hash,
        120, "kW", G.G3_MFP_V1_W_UNIT, 1000 // 1,
        witness.source_evidence_ref, collect(witness.source_evidence_bytes),
        witness.authority_ref, :synthetic_local)
end

@testset "G3MaterialFieldProjectionV1 typed absence and source conservation" begin
    declaration, witness, measure, selections, _, _ = _g3mfp_inputs()
    absent_declaration = G.g3_mfp_project_v1(nothing)
    @test absent_declaration.status == :terminal_deferred
    @test absent_declaration.candidate_ref === nothing
    @test "g3_source_declaration_missing" in absent_declaration.gaps

    missing = G.g3_mfp_project_v1(declaration, nothing;
        physical_measure=measure, conductivity_selections=selections)
    @test missing.status == :terminal_deferred
    @test missing.resolution == :terminal_deferred
    @test "candidate_source_bound_operating_power_witness_missing" in missing.gaps
    @test isempty(missing.regions)
    @test missing.source_power_w === nothing
    @test missing.accepted === false
    @test missing.claim_ceiling == :screen_only
    @test missing.physical_status == :unknown
    @test !missing.formal_up2_credit && !missing.formal_r_credit
    @test !missing.discovery_credit && !missing.engineering_credit
    @test (missing.compiler_calls, missing.provider_calls, missing.mesh_calls, missing.solver_calls) == (0, 0, 0, 0)

    receipt = G.g3_mfp_project_v1(declaration, witness;
        physical_measure=measure, conductivity_selections=selections)
    @test receipt.status == :evaluated_screen_only
    @test receipt.resolution == :screen_only
    @test receipt.input_provenance == :synthetic_local
    @test receipt.normalized_support_integral == 1 // 1
    @test receipt.source_power_w == 120 // 1
    @test receipt.integrated_source_power_w == 120 // 1
    @test Tuple(r.region_id for r in receipt.regions) == ("core", "blanket")
    @test Tuple(r.conductivity_w_m_k for r in receipt.regions) == (10 // 1, 20 // 1)
    @test Tuple(r.normalized_source_weight_m_inv3 for r in receipt.regions) == (1 // 5, 3 // 5)
    @test Tuple(r.volumetric_source_w_m3 for r in receipt.regions) == (24 // 1, 72 // 1)
    @test sum(r.volumetric_source_w_m3 * r.physical_volume_m3 for r in receipt.regions) == 120 // 1
    @test receipt.accepted === false && receipt.claim_ceiling == :screen_only
    @test receipt.physical_status == :unknown
    @test !receipt.formal_up2_credit && !receipt.formal_r_credit
    @test !receipt.discovery_credit && !receipt.engineering_credit
    @test (receipt.compiler_calls, receipt.provider_calls, receipt.mesh_calls, receipt.solver_calls) == (0, 0, 0, 0)
    @test G._g3mfp_projection_receipt_valid(receipt)
    @test G._g3mfp_projection_receipt_valid(missing)
end

@testset "G3MaterialFieldProjectionV1 fail-closed and deferred region gates" begin
    declaration, witness, measure, selections, _, _ = _g3mfp_inputs()

    missing_region = G.g3_mfp_project_v1(declaration, witness;
        physical_measure=measure, conductivity_selections=(selections[1],))
    @test missing_region.status == :terminal_deferred
    @test "region_conductivity_selection_missing:blanket" in missing_region.gaps

    duplicate_region = G.g3_mfp_project_v1(declaration, witness;
        physical_measure=measure, conductivity_selections=(selections[1], selections[1]))
    @test duplicate_region.status == :fail_closed
    @test "duplicate_region_conductivity_selection" in duplicate_region.errors

    other_condition = QualifiedRefV1("local://operation/other", "v1")
    other_condition_hash = digest256_text("other-operating-condition")
    wrong_condition_selection = G.G3MFPConductivitySelectionV1(
        selections[1].candidate_ref, selections[1].region_id, selections[1].component,
        selections[1].material_domain, selections[1].selected_value,
        selections[1].unit_id, selections[1].unit_scale_to_si, other_condition,
        other_condition_hash, selections[1].source_ref, collect(selections[1].source_bytes),
        selections[1].authority_ref, :synthetic_local)
    wrong_condition = G.g3_mfp_project_v1(declaration, witness;
        physical_measure=measure,
        conductivity_selections=(wrong_condition_selection, selections[2]))
    @test wrong_condition.status == :fail_closed
    @test "conductivity_operating_condition_ref_mismatch:core" in wrong_condition.errors

    wrong_candidate = G.g3_mfp_project_v1(declaration,
        G.G3MFPOperatingPowerWitnessV1(QualifiedRefV1("local://foreign", "v5"),
            witness.source_ref, witness.source_id, witness.declaration_hash,
            witness.endpoint_id, witness.operating_condition_ref,
            witness.operating_condition_hash, witness.power_w, witness.unit_id,
            witness.unit, witness.unit_scale_to_si, witness.source_evidence_ref,
            collect(witness.source_evidence_bytes), witness.authority_ref,
            :synthetic_local); physical_measure=measure,
        conductivity_selections=selections)
    @test wrong_candidate.status == :fail_closed
    @test "operating_power_candidate_mismatch" in wrong_candidate.errors

    no_jacobian_inputs = _g3mfp_inputs(jacobian_included=false)
    no_jacobian = G.g3_mfp_project_v1(no_jacobian_inputs[1], no_jacobian_inputs[2];
        physical_measure=no_jacobian_inputs[3],
        conductivity_selections=no_jacobian_inputs[4])
    @test no_jacobian.status == :fail_closed
    @test "physical_measure_jacobian_missing" in no_jacobian.errors

    zero_support_inputs = _g3mfp_inputs(shape_weights=(0 // 1, 0 // 1))
    zero_support = G.g3_mfp_project_v1(zero_support_inputs[1], zero_support_inputs[2];
        physical_measure=zero_support_inputs[3], conductivity_selections=zero_support_inputs[4])
    @test zero_support.status == :fail_closed
    @test "source_shape_has_zero_physical_support_integral" in zero_support.errors

    @test_throws ArgumentError G.G3MFPConductivitySelectionV1(
        selections[1].candidate_ref, selections[1].region_id, selections[1].component,
        selections[1].material_domain, selections[1].selected_value, "mW/(m*K)",
        1 // 1000, selections[1].operating_condition_ref,
        selections[1].operating_condition_hash, selections[1].source_ref,
        collect(selections[1].source_bytes), selections[1].authority_ref,
        selections[1].authority_scope)
end
