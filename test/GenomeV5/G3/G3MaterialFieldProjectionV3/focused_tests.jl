using Test
using JSON3
using SHA
using FusionConceptAI

const _G3MFP3_ROOT = joinpath(@__DIR__, "..", "..", "..", "..", "src", "GenomeV5", "G3")
Base.include(FusionConceptAI, joinpath(_G3MFP3_ROOT, "G3SourceFeedbackLawV1.jl"))
Base.include(FusionConceptAI, joinpath(_G3MFP3_ROOT, "G3MaterialFieldProjectionV3.jl"))
const G = FusionConceptAI
const _G3MFP3_FIXTURE = JSON3.read(read(joinpath(@__DIR__, "..", "up2_g3_source_feedback_v1_fixture.json"), String))

_g3mfp3_rat(v) = Rational{Int64}(Int(v[1]), Int(v[2]))
_g3mfp3_unit(v) = UnitSignature(ntuple(i -> Rational{Int64}(Int(v[i])), 7))
_g3mfp3_candidate() = QualifiedRefV1(String(_G3MFP3_FIXTURE.candidate_ref.id),
    String(_G3MFP3_FIXTURE.candidate_ref.version))
_g3mfp3_bytes(s) = Vector{UInt8}(codeunits(String(s)))

function _g3mfp3_declaration()
    candidate = _g3mfp3_candidate()
    owner = String(_G3MFP3_FIXTURE.owner_scope)
    watts = _g3mfp3_unit(_G3MFP3_FIXTURE.unit_watts)
    endpoints = Tuple(G.G3SFEndpointV1(String(e.id), Symbol(String(e.role)), watts,
        Symbol(String(e.direction)), Int(e.sign), owner) for e in _G3MFP3_FIXTURE.endpoints)
    lawf = _G3MFP3_FIXTURE.law
    splitf = lawf.conservative_split
    split = G.G3SFConservativeSplitV1(_g3mfp3_rat(splitf.field_fraction),
        _g3mfp3_rat(splitf.return_fraction), _g3mfp3_rat(splitf.heat_fraction))
    heatf = lawf.heat_relation
    heat_relation = G.G3SFHeatRelationV1(Symbol(String(heatf.source_role)),
        Symbol(String(heatf.heat_role)), _g3mfp3_rat(heatf.fraction))
    ledgerf = lawf.ledger_relation
    ledger_relation = G.G3SFLedgerRelationV1(Tuple(Symbol(String(x)) for x in ledgerf.entry_roles),
        _g3mfp3_rat(ledgerf.expected_residual))
    law = G.G3SFLawV1(String(lawf.id), "source-power", "field-power", "return-power",
        "heat-power", _g3mfp3_rat(lawf.efficiency), _g3mfp3_rat(lawf.heat_fraction),
        split, heat_relation, ledger_relation, owner)
    entries = Tuple(G.G3SFLedgerEntryV1(String(e.id), String(e.endpoint_id), watts,
        Symbol(String(e.direction)), Int(e.sign), Symbol(String(e.effect)),
        _g3mfp3_rat(e.coefficient), owner) for e in _G3MFP3_FIXTURE.ledger_entries)
    closuref = _G3MFP3_FIXTURE.ledger_closure
    closure = G.G3SFLedgerClosureV1(String(closuref.id),
        Tuple(String(x) for x in closuref.entry_ids), _g3mfp3_rat(closuref.expected_residual),
        watts, owner)
    authorities = Tuple(G.G3SFAuthorityV1(Symbol(String(a.layer)), candidate, nothing,
        nothing, Symbol(String(a.status))) for a in _G3MFP3_FIXTURE.upstream_authority)
    authority_map = Dict(a.layer => a for a in authorities)
    feedback = Tuple(begin
        layer = Symbol(String(f.layer))
        G.G3SFFeedbackTargetV1(String(f.id), layer, String(f.path),
            Symbol(String(f.quantity)), watts, Symbol(String(f.direction)), Int(f.sign),
            String(_G3MFP3_FIXTURE.source_id), owner, authority_map[layer])
    end for f in _G3MFP3_FIXTURE.feedback_targets)
    G.g3_sf_declaration_v1(candidate, String(_G3MFP3_FIXTURE.source_id), owner,
        endpoints, law, entries, closure, feedback, authorities)
end

function _g3mfp3_inputs(; source_power=120 // 1, heat_power=15 // 1,
        source_candidate=_g3mfp3_candidate(), heat_candidate=_g3mfp3_candidate(),
        condition=QualifiedRefV1("local://operation/nominal", "v1"),
        heat_condition=condition, fractions=(1 // 4, 3 // 4), volumes=(2 // 1, 1 // 1),
        profiles=(:uniform_within_region, :uniform_within_region), jacobian=true,
        regions=("core", "blanket"), selection_regions=regions, conductivities=(10 // 1, 20 // 1),
        domain_lower=1 // 1, domain_upper=50 // 1,
        selection_condition=condition, selection_map_ref=QualifiedRefV1("local://g2/region-map", "v1"),
        selection_map_hash=digest256_text("synthetic G2 region map"),
        selection_frame_ref=QualifiedRefV1("local://g2/physical-cartesian-frame", "v1"),
        selection_frame_hash=digest256_text("synthetic G2 physical frame"))
    declaration = _g3mfp3_declaration()
    condition_hash = digest256_text("nominal-operating-condition-fixture")
    heat_condition_hash = heat_condition == condition ? condition_hash : digest256_text("other-condition")
    source_ref = QualifiedRefV1(G.G3_MFP_V3_SOURCE_RECORD_PREFIX * declaration.source_id, "v1")
    watts = G.G3_MFP_V3_W_UNIT
    source_point = G.G3MFPSourceOperatingPointV3(source_candidate, source_ref,
        declaration.source_id, declaration.declaration_hash, declaration.law.source_endpoint_id,
        condition, condition_hash, source_power, "W", watts, 1 // 1,
        QualifiedRefV1("local://fixture/source-operating-point", "v1"),
        _g3mfp3_bytes("synthetic source operating point fixture"),
        QualifiedRefV1("local://authority/source-operating-point", "v1"), :synthetic_local)
    heat_witness = G.G3MFPHeatEndpointWitnessV3(heat_candidate, source_ref,
        declaration.source_id, declaration.declaration_hash, declaration.law.heat_endpoint_id,
        heat_condition, heat_condition_hash, heat_power, "W", watts,
        QualifiedRefV1("local://fixture/evaluated-heat-endpoint", "v1"),
        _g3mfp3_bytes("independent synthetic ledger heat endpoint fixture"),
        QualifiedRefV1("local://authority/heat-endpoint", "v1"), :synthetic_local)
    allocation_rows = Tuple(G.G3MFPRegionHeatAllocationV3(regions[i], fractions[i],
        volumes[i], profiles[i]) for i in eachindex(regions))
    map_ref = QualifiedRefV1("local://g2/region-map", "v1")
    map_hash = digest256_text("synthetic G2 region map")
    frame_ref = QualifiedRefV1("local://g2/physical-cartesian-frame", "v1")
    frame_hash = digest256_text("synthetic G2 physical frame")
    allocation = G.G3MFPHeatAllocationReceiptV3(_g3mfp3_candidate(), source_ref,
        declaration.source_id, declaration.declaration_hash, source_point.record_hash,
        heat_witness.record_hash, declaration.law.heat_endpoint_id, condition,
        condition_hash, map_ref, map_hash, frame_ref, frame_hash, jacobian, allocation_rows,
        QualifiedRefV1("local://fixture/heat-region-allocation", "v1"),
        _g3mfp3_bytes("synthetic heat-to-region allocation and mapped-volume evidence"),
        QualifiedRefV1("local://authority/heat-allocation", "v1"), :synthetic_local)
    conductivity = Tuple(begin
        sel_condition_hash = selection_condition == condition ? condition_hash : digest256_text("other-condition")
        G.G3MFPConductivityTensorSelectionV3(_g3mfp3_candidate(), selection_regions[i],
            "component-" * selection_regions[i], "material-" * selection_regions[i],
            conductivities[i], :isotropic_scalar, domain_lower, domain_upper,
            selection_map_ref, selection_map_hash,
            selection_frame_ref, selection_frame_hash,
            "W/(m*K)", G.G3_MFP_V3_W_PER_M_K_UNIT,
            1 // 1, selection_condition, sel_condition_hash,
            QualifiedRefV1("local://material/" * selection_regions[i], "v1"),
            QualifiedRefV1("local://fixture/material/" * selection_regions[i], "v1"),
            _g3mfp3_bytes("synthetic SI material selection " * selection_regions[i]),
            QualifiedRefV1("local://authority/material/" * selection_regions[i], "v1"),
            :synthetic_local)
    end for i in eachindex(selection_regions))
    declaration, source_point, heat_witness, allocation, conductivity, condition_hash
end

@testset "G3MaterialFieldProjectionV3 source, heat endpoint, and power distinction" begin
    declaration, source_point, heat_witness, allocation, conductivity, _ = _g3mfp3_inputs()
    @test G.g3_sf_validate_v1(declaration)[1] == :valid
    @test G._g3mfp3_source_valid(source_point)
    @test G._g3mfp3_heat_valid(heat_witness)
    @test G._g3mfp3_allocation_valid(allocation)
    @test all(G._g3mfp3_conductivity_valid, conductivity)

    receipt = G.g3_mfp_project_v3(declaration, source_point;
        heat_endpoint_witness=heat_witness, heat_allocation=allocation,
        conductivity_selections=conductivity)
    @test receipt.status == :evaluated_screen_only
    @test receipt.resolution == :screen_only
    @test receipt.input_provenance == :synthetic_local
    @test receipt.source_power_w == 120 // 1
    @test receipt.field_power_w == 90 // 1
    @test receipt.return_power_w == 15 // 1
    @test receipt.heat_power_w == 15 // 1
    @test receipt.energy_residual_w == 0 // 1
    @test receipt.ledger_residual_w == 0 // 1
    @test receipt.heat_endpoint_witness_hash == heat_witness.record_hash
    @test receipt.integrated_heat_power_w == 15 // 1
    @test receipt.normalized_support_integral == 1 // 1
    @test Tuple(r.normalized_source_weight_m_inv3 for r in receipt.regions) == (1 // 8, 3 // 4)
    @test Tuple(r.volumetric_source_w_m3 for r in receipt.regions) == (15 // 8, 45 // 4)
    @test Tuple(r.conductivity_tensor_w_m_k for r in receipt.regions) ==
        ((10 // 1, 0 // 1, 0 // 1, 0 // 1, 10 // 1, 0 // 1, 0 // 1, 0 // 1, 10 // 1),
         (20 // 1, 0 // 1, 0 // 1, 0 // 1, 20 // 1, 0 // 1, 0 // 1, 0 // 1, 20 // 1))
    @test all(r.physical_frame_ref == allocation.physical_frame_ref for r in receipt.regions)
    @test receipt.accepted === false
    @test receipt.claim_ceiling === :screen_only
    @test receipt.physical_status === :unknown
    @test (receipt.formal_up2_credit, receipt.formal_r_credit,
        receipt.discovery_credit, receipt.engineering_credit) == (false, false, false, false)
    @test (receipt.compiler_calls, receipt.provider_calls, receipt.mesh_calls,
        receipt.solver_calls) == (0, 0, 0, 0)
end

@testset "G3MaterialFieldProjectionV3 missing provenance defers" begin
    declaration, source_point, heat_witness, allocation, conductivity, _ = _g3mfp3_inputs()
    no_source = G.g3_mfp_project_v3(declaration, nothing;
        heat_endpoint_witness=heat_witness, heat_allocation=allocation,
        conductivity_selections=conductivity)
    @test no_source.status == :terminal_deferred
    @test isempty(no_source.regions)
    @test "candidate_source_bound_operating_point_missing" in no_source.gaps

    no_heat = G.g3_mfp_project_v3(declaration, source_point;
        heat_allocation=allocation, conductivity_selections=conductivity)
    @test no_heat.status == :terminal_deferred
    @test no_heat.heat_power_w == 15 // 1
    @test isempty(no_heat.regions)
    @test "independent_candidate_bound_heat_endpoint_witness_missing" in no_heat.gaps

    no_allocation = G.g3_mfp_project_v3(declaration, source_point;
        heat_endpoint_witness=heat_witness, conductivity_selections=conductivity)
    @test no_allocation.status == :terminal_deferred
    @test isempty(no_allocation.regions)
    @test "candidate_bound_heat_to_region_allocation_missing" in no_allocation.gaps

    no_jacobian_inputs = _g3mfp3_inputs(jacobian=false)
    no_jacobian = G.g3_mfp_project_v3(no_jacobian_inputs[1], no_jacobian_inputs[2];
        heat_endpoint_witness=no_jacobian_inputs[3], heat_allocation=no_jacobian_inputs[4],
        conductivity_selections=no_jacobian_inputs[5])
    @test no_jacobian.status == :terminal_deferred
    @test isempty(no_jacobian.regions)
    @test "physical_measure_jacobian_missing" in no_jacobian.gaps

    unsupported_profile_inputs = _g3mfp3_inputs(profiles=(:uniform_within_region, :nonuniform))
    unsupported_profile = G.g3_mfp_project_v3(unsupported_profile_inputs[1], unsupported_profile_inputs[2];
        heat_endpoint_witness=unsupported_profile_inputs[3], heat_allocation=unsupported_profile_inputs[4],
        conductivity_selections=unsupported_profile_inputs[5])
    @test unsupported_profile.status == :terminal_deferred
    @test isempty(unsupported_profile.regions)
    @test "uniform_within_region_spatial_law_missing_or_unsupported" in unsupported_profile.gaps
end

@testset "G3MaterialFieldProjectionV3 contradictions fail closed" begin
    declaration, source_point, heat_witness, allocation, conductivity, _ = _g3mfp3_inputs()
    wrong_heat = G.G3MFPHeatEndpointWitnessV3(heat_witness.candidate_ref,
        heat_witness.source_ref, heat_witness.source_id, heat_witness.declaration_hash,
        heat_witness.endpoint_id, heat_witness.operating_condition_ref,
        heat_witness.operating_condition_hash, 120 // 1, "W", G.G3_MFP_V3_W_UNIT,
        heat_witness.evidence_ref, collect(heat_witness.evidence_bytes),
        heat_witness.authority_ref, :synthetic_local)
    mismatched_heat = G.g3_mfp_project_v3(declaration, source_point;
        heat_endpoint_witness=wrong_heat, heat_allocation=allocation,
        conductivity_selections=conductivity)
    @test mismatched_heat.status == :fail_closed
    @test "heat_endpoint_witness_disagrees_with_evaluated_ledger" in mismatched_heat.errors
    @test isempty(mismatched_heat.regions)

    foreign_candidate = QualifiedRefV1("local://foreign/candidate", "v5")
    foreign_inputs = _g3mfp3_inputs(source_candidate=foreign_candidate)
    wrong_source = G.g3_mfp_project_v3(foreign_inputs[1], foreign_inputs[2];
        heat_endpoint_witness=foreign_inputs[3], heat_allocation=foreign_inputs[4],
        conductivity_selections=foreign_inputs[5])
    @test wrong_source.status == :fail_closed
    @test "source_operating_point_candidate_mismatch" in wrong_source.errors

    foreign_heat_candidate = QualifiedRefV1("local://foreign/heat-candidate", "v5")
    foreign_heat_inputs = _g3mfp3_inputs(heat_candidate=foreign_heat_candidate)
    wrong_heat_candidate = G.g3_mfp_project_v3(foreign_heat_inputs[1], foreign_heat_inputs[2];
        heat_endpoint_witness=foreign_heat_inputs[3], heat_allocation=foreign_heat_inputs[4],
        conductivity_selections=foreign_heat_inputs[5])
    @test wrong_heat_candidate.status == :fail_closed
    @test "heat_endpoint_identity_or_semantics_mismatch" in wrong_heat_candidate.errors

    nominal_condition = QualifiedRefV1("local://operation/nominal", "v1")
    changed_condition = QualifiedRefV1("local://operation/changed", "v1")
    wrong_heat_condition_inputs = _g3mfp3_inputs(condition=changed_condition,
        heat_condition=nominal_condition)
    wrong_heat_condition = G.g3_mfp_project_v3(wrong_heat_condition_inputs[1],
        wrong_heat_condition_inputs[2];
        heat_endpoint_witness=wrong_heat_condition_inputs[3],
        heat_allocation=wrong_heat_condition_inputs[4],
        conductivity_selections=wrong_heat_condition_inputs[5])
    @test wrong_heat_condition.status == :fail_closed
    @test "heat_endpoint_identity_or_semantics_mismatch" in wrong_heat_condition.errors

    other_condition = QualifiedRefV1("local://operation/other", "v1")
    wrong_condition_inputs = _g3mfp3_inputs(selection_condition=other_condition)
    wrong_condition = G.g3_mfp_project_v3(wrong_condition_inputs[1], wrong_condition_inputs[2];
        heat_endpoint_witness=wrong_condition_inputs[3], heat_allocation=wrong_condition_inputs[4],
        conductivity_selections=wrong_condition_inputs[5])
    @test wrong_condition.status == :fail_closed
    @test "conductivity_operating_condition_mismatch:core" in wrong_condition.errors

    wrong_map_inputs = _g3mfp3_inputs(selection_map_ref=QualifiedRefV1("local://g2/foreign-map", "v1"),
        selection_map_hash=digest256_text("foreign G2 region map"))
    wrong_map = G.g3_mfp_project_v3(wrong_map_inputs[1], wrong_map_inputs[2];
        heat_endpoint_witness=wrong_map_inputs[3], heat_allocation=wrong_map_inputs[4],
        conductivity_selections=wrong_map_inputs[5])
    @test wrong_map.status == :fail_closed
    @test "conductivity_region_map_mismatch:core" in wrong_map.errors

    wrong_frame_inputs = _g3mfp3_inputs(selection_frame_ref=QualifiedRefV1("local://g2/other-frame", "v1"),
        selection_frame_hash=digest256_text("other G2 physical frame"))
    wrong_frame = G.g3_mfp_project_v3(wrong_frame_inputs[1], wrong_frame_inputs[2];
        heat_endpoint_witness=wrong_frame_inputs[3], heat_allocation=wrong_frame_inputs[4],
        conductivity_selections=wrong_frame_inputs[5])
    @test wrong_frame.status == :fail_closed
    @test "conductivity_physical_frame_mismatch:core" in wrong_frame.errors

    nonconservative = _g3mfp3_inputs(fractions=(1 // 2, 1 // 4))
    bad_allocation = G.g3_mfp_project_v3(nonconservative[1], nonconservative[2];
        heat_endpoint_witness=nonconservative[3], heat_allocation=nonconservative[4],
        conductivity_selections=nonconservative[5])
    @test bad_allocation.status == :fail_closed
    @test "heat_region_allocation_fractions_not_conservative" in bad_allocation.errors
    @test isempty(bad_allocation.regions)

    duplicate = G.g3_mfp_project_v3(declaration, source_point;
        heat_endpoint_witness=heat_witness, heat_allocation=allocation,
        conductivity_selections=(conductivity[1], conductivity[1]))
    @test duplicate.status == :fail_closed
    @test "duplicate_region_conductivity_selection" in duplicate.errors
end

@testset "G3MaterialFieldProjectionV3 conductivity tensor gates" begin
    candidate = _g3mfp3_candidate()
    condition = QualifiedRefV1("local://operation/nominal", "v1")
    condition_hash = digest256_text("nominal-operating-condition-fixture")
    common = (candidate, "core", "component-core", "material-core")
    map_ref = QualifiedRefV1("local://g2/region-map", "v1")
    map_hash = digest256_text("synthetic G2 region map")
    frame_ref = QualifiedRefV1("local://g2/physical-cartesian-frame", "v1")
    frame_hash = digest256_text("synthetic G2 physical frame")
    suffix = (map_ref, map_hash, frame_ref, frame_hash, "W/(m*K)", G.G3_MFP_V3_W_PER_M_K_UNIT, 1 // 1, condition,
        condition_hash, QualifiedRefV1("local://material/core", "v1"),
        QualifiedRefV1("local://fixture/material/core", "v1"),
        _g3mfp3_bytes("synthetic conductivity"),
        QualifiedRefV1("local://authority/material/core", "v1"), :synthetic_local)
    source = _g3mfp3_inputs()[2]
    @test_throws ArgumentError G.G3MFPSourceOperatingPointV3(source.candidate_ref,
        source.source_ref, source.source_id, source.declaration_hash, source.endpoint_id,
        source.operating_condition_ref, source.operating_condition_hash, -1 // 1, "W",
        G.G3_MFP_V3_W_UNIT, 1 // 1, source.evidence_ref,
        collect(source.evidence_bytes), source.authority_ref, :synthetic_local)
    @test_throws ArgumentError G.G3MFPRegionHeatAllocationV3("core", -1 // 1, 1 // 1,
        :uniform_within_region)
    @test_throws ArgumentError G.G3MFPConductivityTensorSelectionV3(common..., -1 // 1,
        :isotropic_scalar, 1 // 1, 50 // 1, suffix...)
    @test_throws ArgumentError G.G3MFPConductivityTensorSelectionV3(common...,
        (1 // 1, 2 // 1, 0 // 1, 0 // 1, 1 // 1, 0 // 1, 0 // 1, 0 // 1, 1 // 1),
        :symmetric_positive_definite_tensor, ntuple(_ -> -10 // 1, 9), ntuple(_ -> 10 // 1, 9), suffix...)
    @test_throws ArgumentError G.G3MFPConductivityTensorSelectionV3(common...,
        (1 // 1, 2 // 1, 0 // 1, 2 // 1, 1 // 1, 0 // 1, 0 // 1, 0 // 1, 1 // 1),
        :symmetric_positive_definite_tensor, ntuple(_ -> -10 // 1, 9), ntuple(_ -> 10 // 1, 9), suffix...)
    @test_throws ArgumentError G.G3MFPConductivityTensorSelectionV3(common...,
        (1 // 1, 2 // 1, 0 // 1, 3 // 1, 1 // 1, 0 // 1, 0 // 1, 0 // 1, 1 // 1),
        :symmetric_positive_definite_tensor, ntuple(_ -> -10 // 1, 9), ntuple(_ -> 10 // 1, 9), suffix...)
    @test_throws ArgumentError G.G3MFPConductivityTensorSelectionV3(common..., 60 // 1,
        :isotropic_scalar, 1 // 1, 50 // 1, suffix...)
    @test_throws ArgumentError G.G3MFPConductivityTensorSelectionV3(common..., 10 // 1,
        :isotropic_scalar, 1 // 1, 50 // 1, suffix[1], suffix[2], suffix[3], suffix[4],
        "mW/(m*K)", suffix[6:end]...)
    anisotropic = G.G3MFPConductivityTensorSelectionV3(common...,
        (4 // 1, 1 // 1, 0 // 1, 1 // 1, 3 // 1, 0 // 1, 0 // 1, 0 // 1, 2 // 1),
        :symmetric_positive_definite_tensor,
        (1 // 1, -1 // 1, -1 // 1, -1 // 1, 1 // 1, -1 // 1, -1 // 1, -1 // 1, 1 // 1),
        (5 // 1, 2 // 1, 2 // 1, 2 // 1, 4 // 1, 2 // 1, 2 // 1, 2 // 1, 3 // 1), suffix...)
    @test G._g3mfp3_conductivity_valid(anisotropic)
    @test anisotropic.conductivity_tensor_w_m_k[2] == 1 // 1

    incomplete_inputs = _g3mfp3_inputs(selection_regions=("core",))
    incomplete = G.g3_mfp_project_v3(incomplete_inputs[1], incomplete_inputs[2];
        heat_endpoint_witness=incomplete_inputs[3], heat_allocation=incomplete_inputs[4],
        conductivity_selections=incomplete_inputs[5])
    @test incomplete.status == :terminal_deferred
    @test isempty(incomplete.regions)
    @test "region_conductivity_selection_missing:blanket" in incomplete.gaps
end

@testset "G3MaterialFieldProjectionV3 symmetric negative determinant fails closed" begin
    candidate = _g3mfp3_candidate()
    condition = QualifiedRefV1("local://operation/nominal", "v1")
    condition_hash = digest256_text("nominal-operating-condition-fixture")
    common = (candidate, "core", "component-core", "material-core")
    map_ref = QualifiedRefV1("local://g2/region-map", "v1")
    map_hash = digest256_text("synthetic G2 region map")
    frame_ref = QualifiedRefV1("local://g2/physical-cartesian-frame", "v1")
    frame_hash = digest256_text("synthetic G2 physical frame")
    suffix = (map_ref, map_hash, frame_ref, frame_hash, "W/(m*K)",
        G.G3_MFP_V3_W_PER_M_K_UNIT, 1 // 1, condition, condition_hash,
        QualifiedRefV1("local://material/core", "v1"),
        QualifiedRefV1("local://fixture/material/core", "v1"),
        _g3mfp3_bytes("symmetric determinant-negative tensor"),
        QualifiedRefV1("local://authority/material/core", "v1"), :synthetic_local)
    @test_throws ArgumentError G.G3MFPConductivityTensorSelectionV3(common...,
        (1 // 1, 0 // 1, 0 // 1, 0 // 1, 1 // 1, 0 // 1, 0 // 1, 0 // 1, -1 // 1),
        :symmetric_positive_definite_tensor, ntuple(_ -> -10 // 1, 9),
        ntuple(_ -> 10 // 1, 9), suffix...)
end

@testset "G3MaterialFieldProjectionV3 witness hash body parity" begin
    declaration, source_point, heat_witness, allocation, conductivity, _ = _g3mfp3_inputs()
    @test source_point.candidate_ref == declaration.candidate_ref
    @test heat_witness.candidate_ref == declaration.candidate_ref
    @test all(selection.candidate_ref == declaration.candidate_ref for selection in conductivity)

    source_content = G._g3mfp3_source_content(source_point)
    source_authority = canonical_hash((domain="G3-MFP-V3-source-authority-binding", body=source_content))
    @test source_point.authority_binding_hash == source_authority
    @test source_point.record_hash == canonical_hash((domain="G3-MFP-V3-source-operating-point",
        body=merge(source_content, (authority_binding_hash=source_authority,))))
    @test source_content.unit_basis == G.G3_MFP_V3_SI_BASIS

    heat_content = G._g3mfp3_heat_content(heat_witness)
    heat_authority = canonical_hash((domain="G3-MFP-V3-heat-authority-binding", body=heat_content))
    @test heat_witness.authority_binding_hash == heat_authority
    @test heat_witness.record_hash == canonical_hash((domain="G3-MFP-V3-heat-endpoint-witness",
        body=merge(heat_content, (authority_binding_hash=heat_authority,))))
    @test heat_content.unit_basis == G.G3_MFP_V3_SI_BASIS

    for selection in conductivity
        content = G._g3mfp3_conductivity_content(selection)
        authority = canonical_hash((domain="G3-MFP-V3-material-authority-binding", body=content))
        @test selection.authority_binding_hash == authority
        @test selection.selection_hash == canonical_hash((domain="G3-MFP-V3-conductivity-tensor-selection",
            body=merge(content, (authority_binding_hash=authority,))))
        @test content.unit_basis == G.G3_MFP_V3_SI_BASIS
    end

    allocation_content = G._g3mfp3_allocation_content(allocation)
    allocation_authority = canonical_hash((domain="G3-MFP-V3-heat-allocation-authority",
        body=allocation_content))
    @test allocation.authority_binding_hash == allocation_authority
    @test allocation.receipt_hash == canonical_hash((domain="G3-MFP-V3-heat-allocation",
        body=merge(allocation_content, (authority_binding_hash=allocation_authority,))))
    @test allocation.source_operating_point_hash == source_point.record_hash
    @test allocation.heat_witness_hash == heat_witness.record_hash
    @test G._g3mfp3_allocation_valid(allocation)

    receipt = G.g3_mfp_project_v3(declaration, source_point;
        heat_endpoint_witness=heat_witness, heat_allocation=allocation,
        conductivity_selections=conductivity)
    receipt_content = G._g3mfp3_receipt_content(receipt)
    @test receipt.receipt_hash == canonical_hash(receipt_content)
    @test receipt_content.schema_id == G.G3_MFP_V3_SCHEMA_ID
    @test receipt_content.version == G.G3_MFP_V3_VERSION
    @test receipt_content.candidate_ref == declaration.candidate_ref
    @test receipt.receipt_hash != canonical_hash(merge(receipt_content,
        (candidate_ref=QualifiedRefV1("local://foreign/candidate", "v5"),)))
    @test G.semantic_view(receipt).schema_id == G.G3_MFP_V3_SCHEMA_ID

    @test G._g3mfp3_source_valid(source_point)
    @test G._g3mfp3_heat_valid(heat_witness)
    @test all(G._g3mfp3_conductivity_valid, conductivity)
end

@testset "G3MaterialFieldProjectionV3 SI basis and versioned hash tampering" begin
    declaration, source_point, heat_witness, _, conductivity, _ = _g3mfp3_inputs()
    wrong_basis = Tuple(reverse(collect(G.G3_MFP_V3_SI_BASIS)))

    source_content = G._g3mfp3_source_content(source_point)
    source_authority = canonical_hash((domain="G3-MFP-V3-source-authority-binding", body=source_content))
    @test G._g3mfp3_source_valid(source_point)
    @test source_authority != canonical_hash((domain="G3-MFP-V2-source-authority-binding", body=source_content))
    @test source_authority != canonical_hash((domain="G3-MFP-V3-source-authority-binding",
        body=merge(source_content, (unit_basis=wrong_basis,))))

    heat_content = G._g3mfp3_heat_content(heat_witness)
    heat_authority = canonical_hash((domain="G3-MFP-V3-heat-authority-binding", body=heat_content))
    @test G._g3mfp3_heat_valid(heat_witness)
    @test heat_authority != canonical_hash((domain="G3-MFP-V2-heat-authority-binding", body=heat_content))
    @test heat_authority != canonical_hash((domain="G3-MFP-V3-heat-authority-binding",
        body=merge(heat_content, (unit_basis=wrong_basis,))))

    for selection in conductivity
        content = G._g3mfp3_conductivity_content(selection)
        authority = canonical_hash((domain="G3-MFP-V3-material-authority-binding", body=content))
        @test G._g3mfp3_conductivity_valid(selection)
        @test authority != canonical_hash((domain="G3-MFP-V2-material-authority-binding", body=content))
        @test authority != canonical_hash((domain="G3-MFP-V3-material-authority-binding",
            body=merge(content, (unit_basis=wrong_basis,))))
    end
    @test declaration.candidate_ref == source_point.candidate_ref == heat_witness.candidate_ref
end
