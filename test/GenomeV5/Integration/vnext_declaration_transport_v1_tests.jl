using Test
using FusionConceptAI

const _VNEXT_ROOT = joinpath(@__DIR__, "..", "..", "..", "src")
Base.include(FusionConceptAI, joinpath(_VNEXT_ROOT, "GenomeV5", "G1", "DiffusionDeclarationV1.jl"))
Base.include(FusionConceptAI, joinpath(_VNEXT_ROOT, "GenomeV5", "G2", "MetricBoundaryDeclarationV1.jl"))
Base.include(FusionConceptAI, joinpath(_VNEXT_ROOT, "GenomeV5", "G3", "G3SourceFeedbackLawV1.jl"))
Base.include(FusionConceptAI, joinpath(_VNEXT_ROOT, "GenomeV5", "Integration", "VNextDeclarationTransportV1.jl"))
const G = FusionConceptAI

const _CANDIDATE = G.QualifiedRefV1("synthetic://candidate/t0-shared-oracle", "v5")
const _ABSENT_AXES = ntuple(i -> G.VNextAxisProvenanceV1(G.VNEXT_T0_REQUIRED_AXES[i], nothing,
    nothing, nothing; status=:typed_absent, reason="axis source receipt is not supplied by V1"), 4)
const _AXES = (_ABSENT_AXES, _ABSENT_AXES, _ABSENT_AXES)
const _CHILD_KINDS = (:realization, :control, :binding)
const _CHILDREN = ntuple(i -> G.VNextG3ChildStateV1(_CHILD_KINDS[i],
    G.VNextTypedAbsenceV1(_CHILD_KINDS[i], "G3 V1 contains no child source or identity")), 3)

function _g1()
    zero = G.UnitSignature()
    grad_u = G.UnitSignature((-1, 0, 0, 0, 0, 0, 0))
    div_grad_u = G.UnitSignature((-2, 0, 0, 0, 0, 0, 0))
    scalar = G.PhysicalType(:scalar_field, 0, 3, G.TemporalTypeV1(G.static_time), zero)
    grad_type = G.PhysicalType(:vector_field, 1, 3, G.TemporalTypeV1(G.static_time), grad_u)
    tensor = G.PhysicalType(:tensor_field, 2, 3, G.TemporalTypeV1(G.static_time), zero)
    f_type = G.PhysicalType(:scalar_field, 0, 3, G.TemporalTypeV1(G.static_time), div_grad_u)
    source = G.QualifiedRefV1("synthetic://source/t0-g1", "v1")
    u = G.G1DiffusionScalarFieldV1("u_candidate", scalar, source;
        source_expression="u_candidate(x)=x1+x2+x3")
    expression = G.G1DiffusionDiagonalAffineKFieldV1("K_candidate_x_affine")
    k = G.G1DiffusionCoefficientFieldV1("K_candidate_x", tensor, source,
        lower_bound=2 // 1, upper_bound=121 // 30, expression=expression)
    f = G.G1DiffusionScalarFieldV1("f_candidate", f_type, source;
        source_expression="f_candidate(x)=1")
    grad = G.G1TypedGradV1(G.QualifiedRefV1("synthetic://operator/GRAD", "v1"),
        "u_candidate", "grad_u", scalar, grad_type)
    apply = G.G1TypedKApplyV1(G.QualifiedRefV1("synthetic://operator/K_APPLY", "v1"),
        "grad_u", "flux_u", grad_type, grad_type, "K_candidate_x")
    div = G.G1TypedDivV1(G.QualifiedRefV1("synthetic://operator/DIV", "v1"),
        "flux_u", "f_candidate", grad_type, f_type)
    chain = G.G1DiffusionOperatorChainV1(grad, apply, div, "f_candidate")
    payload = G.G1DiffusionSourcePayloadV1(source, "synthetic-source-v1", u, k, f)
    G.g1_diffusion_declaration_v1(_CANDIDATE, source, "synthetic-source-v1",
        G.g1_diffusion_source_hash_v1(payload), u, k, f, chain,
        G.QualifiedRefV1("synthetic://closure/diffusion", "v1"),
        G.QualifiedRefV1(G.G1_DIFFUSION_APPLICABILITY_ID_V1, "v1"),
        "bounded-3d-synthetic-oracle", (:synthetic_oracle,); source_payload=payload)
end

function _g2()
    chart_ref = G.QualifiedRefV1("synthetic://chart/t0", "v1")
    mesh_ref = G.QualifiedRefV1("synthetic://mesh/t0", "v1")
    chart = G.G2MBChartMapV1(chart_ref, (0, 0, 0), (1, 1, 1),
        ((2, 0, 0), (0, 3, 0), (0, 0, 4)), (1 // 2, 1 // 3, 1 // 4))
    mesh = G.G2MBMeshPlanV1(mesh_ref, chart_ref, (2, 3, 4), :Q1,
        ((1 // 2, 1 // 2, 1 // 2), (1 // 4, 1 // 4, 1 // 4)), (1, 1 // 2);
        execution_status=:not_executed)
    field_unit = G.UnitSignature((0, 0, 0, 0, 0, 0, 1))
    flux_unit = G.UnitSignature((0, 0, 0, 0, 0, 1, 0))
    faces = (
        G.G2MBFaceOwnerV1("x-min", :x_min, "synthetic-domain", (-1, 0, 0), G.G2MBFaceValueV1(:dirichlet, 0, field_unit)),
        G.G2MBFaceOwnerV1("x-max", :x_max, "synthetic-domain", (1, 0, 0), G.G2MBFaceValueV1(:neumann, 1, flux_unit)),
        G.G2MBFaceOwnerV1("y-min", :y_min, "synthetic-domain", (0, -1, 0), G.G2MBFaceValueV1(:dirichlet, 0, field_unit)),
        G.G2MBFaceOwnerV1("y-max", :y_max, "synthetic-domain", (0, 1, 0), G.G2MBFaceValueV1(:neumann, 1, flux_unit)),
        G.G2MBFaceOwnerV1("z-min", :z_min, "synthetic-domain", (0, 0, -1), G.G2MBFaceValueV1(:dirichlet, 0, field_unit)),
        G.G2MBFaceOwnerV1("z-max", :z_max, "synthetic-domain", (0, 0, 1), G.G2MBFaceValueV1(:neumann, 1, flux_unit)))
    units = G.G2MBUnitContractV1(G.UnitSignature(), G.UnitSignature((1, 0, 0, 0, 0, 0, 0)),
        G.UnitSignature((1, 0, 0, 0, 0, 0, 0)), G.UnitSignature((2, 0, 0, 0, 0, 0, 0)),
        G.UnitSignature((2, 0, 0, 0, 0, 0, 0)), G.UnitSignature((3, 0, 0, 0, 0, 0, 0)),
        field_unit, flux_unit)
    source_candidate = G.GenomeContractRef("synthetic://candidate/t0-g2-source", "v5",
        G.digest256_text("t0-g2-schema"), G.digest256_text("t0-g2-canonical"), "t0-g2-profile")
    authority = G.G2MBAuthorityV1(:unique_match, :no_match, :no_match)
    source = G.g2mb_source_v1(G.QualifiedRefV1("synthetic://source/t0-g2", "v1"),
        "synthetic-g2-source-v1", source_candidate, chart, mesh, faces,
        G.G2MBProfileV1("synthetic-t0-profile"), units, authority)
    contract = G.GenomeContractRef("synthetic://contract/t0-g2", "v5",
        G.g2mb_schema_hash_v1(), G.g2mb_canonicalization_hash_v1(),
        G.g2mb_profile_token_v1(source.profile))
    G.g2mb_declaration_v1(contract, source)
end

function _g3()
    unit = G.UnitSignature((1, 2, -3, 0, 0, 0, 0))
    owner = "synthetic:t0/device-power-loop"
    endpoints = (
        G.G3SFEndpointV1("source-power", :source, unit, :out, 1, owner),
        G.G3SFEndpointV1("field-power", :field, unit, :out, -1, owner),
        G.G3SFEndpointV1("return-power", :return, unit, :out, -1, owner),
        G.G3SFEndpointV1("heat-power", :heat, unit, :out, -1, owner),
        G.G3SFEndpointV1("energy-ledger", :ledger, unit, :bidirectional, 1, owner))
    split = G.G3SFConservativeSplitV1(3 // 4, 1 // 8, 1 // 8)
    heat = G.G3SFHeatRelationV1(:source, :heat, 1 // 8)
    relation = G.G3SFLedgerRelationV1((:source, :field, :return, :heat), 0)
    law = G.G3SFLawV1("source-law", "source-power", "field-power", "return-power",
        "heat-power", 3 // 4, 1 // 8, split, heat, relation, owner)
    entries = (
        G.G3SFLedgerEntryV1("source-entry", "source-power", unit, :out, 1, :source, 1 // 1, owner),
        G.G3SFLedgerEntryV1("field-entry", "field-power", unit, :out, -1, :field, -3 // 4, owner),
        G.G3SFLedgerEntryV1("return-entry", "return-power", unit, :out, -1, :return, -1 // 8, owner),
        G.G3SFLedgerEntryV1("heat-entry", "heat-power", unit, :out, -1, :heat, -1 // 8, owner))
    closure = G.G3SFLedgerClosureV1("closure", ("source-entry", "field-entry", "return-entry", "heat-entry"), 0, unit, owner)
    g1_authority = G.G3SFAuthorityV1(:G1, _CANDIDATE, nothing, nothing, :missing)
    g2_authority = G.G3SFAuthorityV1(:G2, _CANDIDATE, nothing, nothing, :missing)
    feedback = (
        G.G3SFFeedbackTargetV1("g1-residual", :G1, "/residual", :residual, unit, :in, 1, "source", owner, g1_authority),
        G.G3SFFeedbackTargetV1("g2-thermal", :G2, "/thermal", :thermal_load, unit, :in, 1, "source", owner, g2_authority))
    G.g3_sf_declaration_v1(_CANDIDATE, "synthetic-g3-source", owner, endpoints, law,
        entries, closure, feedback, (g1_authority, g2_authority))
end

function _g2_envelope(g2; candidate=_CANDIDATE, status=:typed_absent)
    G.VNextG2CandidateEnvelopeV1(candidate, g2.source.candidate_ref;
        mapping_status=status, reason="fresh source-backed G2 mapping receipt is not supplied")
end

function _g2_variant(g2; source_ref=g2.source.source_ref,
                     source_version=g2.source.source_version,
                     candidate_ref=g2.source.candidate_ref)
    source_body = (source_ref=source_ref, source_version=source_version,
        candidate_ref=candidate_ref, chart_map=g2.source.chart_map, mesh=g2.source.mesh,
        faces=g2.source.faces, profile=g2.source.profile, units=g2.source.units,
        authority=g2.source.authority)
    source = G.G2MBSourceV1(source_ref, source_version, candidate_ref,
        g2.source.chart_map, g2.source.mesh, g2.source.faces, g2.source.profile,
        g2.source.units, g2.source.authority, G.canonical_hash(source_body))
    G.g2mb_declaration_v1(g2.contract_ref, source)
end

@testset "AD-30 T0 preserves complete bodies and typed gaps" begin
    g1 = _g1(); g2 = _g2(); g3 = _g3()
    admission = G.vnext_declaration_transport_v1(g1, g2, g3, _CANDIDATE,
        _g2_envelope(g2), _AXES[1], _AXES[2], _AXES[3], _CHILDREN)
    @test admission.status === :valid
    @test admission.resolution === :terminal_deferred
    @test admission.accepted === false
    @test admission.claim_ceiling === :contract_only
    @test admission.transport.g3_source_content_hash === nothing
    @test all(occursin("terminal_deferred", gap) for gap in admission.gaps)
    @test G.vnext_transport_bundle_hash_v1(admission.transport) isa G.Digest256
    @test admission.transport.g1_body_hash == G.canonical_hash(G._vnext_t0_g1_body(g1))
    @test admission.transport.g2_body_hash == G.canonical_hash(G._vnext_t0_g2_body(g2))
    @test admission.transport.g3_body_hash == G.canonical_hash(G._vnext_t0_g3_body(g3))
    @test "G3_feedback_authority_missing:g1-residual:terminal_deferred" in admission.gaps
    @test "G3_feedback_authority_missing:g2-thermal:terminal_deferred" in admission.gaps
    @test "G3_upstream_authority_missing:G1:terminal_deferred" in admission.gaps
    @test "G3_upstream_authority_missing:G2:terminal_deferred" in admission.gaps
end

@testset "AD-30 T0 rejects candidate and axis contradictions" begin
    g1 = _g1(); g2 = _g2(); g3 = _g3()
    foreign = G.QualifiedRefV1("synthetic://candidate/foreign", "v5")
    bad_candidate = G.vnext_declaration_transport_v1(g1, g2, g3, foreign,
        _g2_envelope(g2; candidate=foreign), _AXES[1], _AXES[2], _AXES[3], _CHILDREN)
    @test bad_candidate.status === :fail_closed
    @test "G1_candidate_binding_mismatch" in bad_candidate.errors
    conflicting_g2 = ntuple(i -> i == 1 ? G.VNextAxisProvenanceV1(:payload_schema_version,
        "v2", "source://axis", "/payload_schema_version";
        candidate_ref=_CANDIDATE,
        source_record_hash=G.canonical_hash(G._vnext_t0_g2_body(g2)),
        identity_hash=G.vnext_axis_identity_hash_v1(_CANDIDATE, :G2,
            :payload_schema_version, "v2", "source://axis", "/payload_schema_version",
            G.canonical_hash(G._vnext_t0_g2_body(g2)), :trusted_receipt),
        attestation=:trusted_receipt) : _ABSENT_AXES[i], 4)
    conflicting_g1 = ntuple(i -> i == 1 ? G.VNextAxisProvenanceV1(:payload_schema_version,
        "v1", "source://axis", "/payload_schema_version";
        candidate_ref=_CANDIDATE,
        source_record_hash=G.canonical_hash(G._vnext_t0_g1_body(g1)),
        identity_hash=G.vnext_axis_identity_hash_v1(_CANDIDATE, :G1,
            :payload_schema_version, "v1", "source://axis", "/payload_schema_version",
            G.canonical_hash(G._vnext_t0_g1_body(g1)), :trusted_receipt),
        attestation=:trusted_receipt) : _ABSENT_AXES[i], 4)
    bad_axis = G.vnext_declaration_transport_v1(g1, g2, g3, _CANDIDATE,
        _g2_envelope(g2), conflicting_g1, conflicting_g2, _AXES[3], _CHILDREN)
    @test bad_axis.status === :fail_closed
    @test "axis_conflict:payload_schema_version" in bad_axis.errors
end

@testset "AD-30 T0 rejects forged mapping and axis receipts" begin
    g1 = _g1(); g2 = _g2(); g3 = _g3()
    stale_receipt = G.VNextG2CandidateMappingReceiptV1(g2.source, _CANDIDATE,
        G.digest256_text("synthetic-fake-evidence"), "source.candidate_ref";
        source_record_hash=G.digest256_text("stale-g2-source-record"),
        source_hash=g2.source.source_hash, attestation=:trusted_receipt)
    mapped = G.VNextG2CandidateEnvelopeV1(_CANDIDATE, g2.source.candidate_ref;
        mapping_status=:mapped, mapping_receipt=stale_receipt, reason="synthetic receipt")
    stale_mapping = G.vnext_declaration_transport_v1(g1, g2, g3, _CANDIDATE,
        mapped, _AXES[1], _AXES[2], _AXES[3], _CHILDREN)
    @test stale_mapping.status === :fail_closed
    @test "G2_mapping_source_record_hash_mismatch" in stale_mapping.errors

    valid_receipt = G.VNextG2CandidateMappingReceiptV1(g2.source, _CANDIDATE,
        G.digest256_text("unreadable-external-evidence"), "source.candidate_ref";
        attestation=:trusted_receipt)
    mapped = G.VNextG2CandidateEnvelopeV1(_CANDIDATE, g2.source.candidate_ref;
        mapping_status=:mapped, mapping_receipt=valid_receipt,
        reason="external receipt verification pending")
    mapped_result = G.vnext_declaration_transport_v1(g1, g2, g3, _CANDIDATE,
        mapped, _AXES[1], _AXES[2], _AXES[3], _CHILDREN)
    @test mapped_result.status === :valid
    @test mapped_result.resolution === :terminal_deferred
    @test "G2_mapping_external_receipt_verification_pending:terminal_deferred" in mapped_result.gaps

    foreign_mapping_candidate = G.QualifiedRefV1("synthetic://candidate/mapping-foreign", "v5")
    foreign_receipt = G.VNextG2CandidateMappingReceiptV1(g2.source, foreign_mapping_candidate,
        G.digest256_text("synthetic-fake-evidence-foreign"), "source.candidate_ref";
        attestation=:trusted_receipt)
    foreign_mapping = G.VNextG2CandidateEnvelopeV1(_CANDIDATE, g2.source.candidate_ref;
        mapping_status=:mapped, mapping_receipt=foreign_receipt, reason="candidate mismatch")
    foreign_mapping_result = G.vnext_declaration_transport_v1(g1, g2, g3, _CANDIDATE,
        foreign_mapping, _AXES[1], _AXES[2], _AXES[3], _CHILDREN)
    @test foreign_mapping_result.status === :fail_closed
    @test "G2_mapping_candidate_ref_mismatch" in foreign_mapping_result.errors

    forged_g1_axes = ntuple(i -> i == 1 ? G.VNextAxisProvenanceV1(
        :payload_schema_version, "v1", "source://forged-axis", "/payload_schema_version";
        candidate_ref=_CANDIDATE,
        source_record_hash=G.digest256_text("stale-axis-record"),
        identity_hash=G.digest256_text("forged-axis-identity"),
        attestation=:trusted_receipt) : _ABSENT_AXES[i], 4)
    stale_axis = G.vnext_declaration_transport_v1(g1, g2, g3, _CANDIDATE,
        _g2_envelope(g2), forged_g1_axes, _AXES[2], _AXES[3], _CHILDREN)
    @test stale_axis.status === :fail_closed
    @test "axis_source_record_hash_mismatch:G1:payload_schema_version" in stale_axis.errors

    identity_mismatch_axes = ntuple(i -> i == 1 ? G.VNextAxisProvenanceV1(
        :payload_schema_version, "v1", "source://identity-mismatch", "/payload_schema_version";
        candidate_ref=_CANDIDATE,
        source_record_hash=G.canonical_hash(G._vnext_t0_g1_body(g1)),
        identity_hash=G.digest256_text("wrong-axis-identity"),
        attestation=:trusted_receipt) : _ABSENT_AXES[i], 4)
    identity_mismatch = G.vnext_declaration_transport_v1(g1, g2, g3, _CANDIDATE,
        _g2_envelope(g2), identity_mismatch_axes, _AXES[2], _AXES[3], _CHILDREN)
    @test identity_mismatch.status === :fail_closed
    @test "axis_identity_hash_mismatch:G1:payload_schema_version" in identity_mismatch.errors

    pending_axis = ntuple(i -> i == 1 ? G.VNextAxisProvenanceV1(
        :payload_schema_version, "v1", "source://pending-axis", "/payload_schema_version";
        candidate_ref=_CANDIDATE,
        source_record_hash=G.canonical_hash(G._vnext_t0_g1_body(g1)),
        identity_hash=G.vnext_axis_identity_hash_v1(_CANDIDATE, :G1,
            :payload_schema_version, "v1", "source://pending-axis", "/payload_schema_version",
            G.canonical_hash(G._vnext_t0_g1_body(g1)), :trusted_receipt),
        attestation=:trusted_receipt) : _ABSENT_AXES[i], 4)
    pending_axis_result = G.vnext_declaration_transport_v1(g1, g2, g3, _CANDIDATE,
        _g2_envelope(g2), pending_axis, _AXES[2], _AXES[3], _CHILDREN)
    @test pending_axis_result.status === :valid
    @test pending_axis_result.resolution === :terminal_deferred
    @test "axis_external_receipt_verification_pending:G1:payload_schema_version" in pending_axis_result.gaps

    foreign_axis_candidate = G.QualifiedRefV1("synthetic://candidate/axis-foreign", "v5")
    foreign_candidate_axes = ntuple(i -> i == 1 ? G.VNextAxisProvenanceV1(
        :payload_schema_version, "v1", "source://foreign-axis", "/payload_schema_version";
        candidate_ref=foreign_axis_candidate,
        source_record_hash=G.canonical_hash(G._vnext_t0_g1_body(g1)),
        identity_hash=G.digest256_text("foreign-axis-identity"),
        attestation=:trusted_receipt) : _ABSENT_AXES[i], 4)
    foreign_axis = G.vnext_declaration_transport_v1(g1, g2, g3, _CANDIDATE,
        _g2_envelope(g2), foreign_candidate_axes, _AXES[2], _AXES[3], _CHILDREN)
    @test foreign_axis.status === :fail_closed
    @test "axis_candidate_ref_mismatch:G1:payload_schema_version" in foreign_axis.errors

    synthetic_g1_axes = ntuple(i -> i == 1 ? G.VNextAxisProvenanceV1(
        :payload_schema_version, "v1", "synthetic://axis", "/payload_schema_version";
        provenance=:synthetic_oracle) : _ABSENT_AXES[i], 4)
    synthetic_axis = G.vnext_declaration_transport_v1(g1, g2, g3, _CANDIDATE,
        _g2_envelope(g2), synthetic_g1_axes, _AXES[2], _AXES[3], _CHILDREN)
    @test synthetic_axis.status === :valid
    @test synthetic_axis.resolution === :terminal_deferred
    @test "axis_synthetic_oracle:G1:payload_schema_version" in synthetic_axis.gaps
end

@testset "AD-30 T0 checks every locally verifiable G2 mapping field" begin
    g1 = _g1(); g2 = _g2(); g3 = _g3()
    receipt = G.VNextG2CandidateMappingReceiptV1(g2.source, _CANDIDATE,
        G.digest256_text("unreadable-evidence-field"), "source.candidate_ref";
        attestation=:trusted_receipt)

    source_ref_variant = _g2_variant(g2;
        source_ref=G.QualifiedRefV1("synthetic://source/t0-g2-edited", "v1"))
    source_ref_result = G.vnext_declaration_transport_v1(g1, source_ref_variant, g3,
        _CANDIDATE, G.VNextG2CandidateEnvelopeV1(_CANDIDATE,
            source_ref_variant.source.candidate_ref; mapping_status=:mapped,
            mapping_receipt=receipt, reason="source ref mismatch"),
        _AXES[1], _AXES[2], _AXES[3], _CHILDREN)
    @test source_ref_result.status === :fail_closed
    @test "G2_mapping_source_ref_mismatch" in source_ref_result.errors

    version_variant = _g2_variant(g2; source_version="edited-g2-source-v2")
    version_result = G.vnext_declaration_transport_v1(g1, version_variant, g3,
        _CANDIDATE, G.VNextG2CandidateEnvelopeV1(_CANDIDATE,
            version_variant.source.candidate_ref; mapping_status=:mapped,
            mapping_receipt=receipt, reason="source version mismatch"),
        _AXES[1], _AXES[2], _AXES[3], _CHILDREN)
    @test version_result.status === :fail_closed
    @test "G2_mapping_source_version_mismatch" in version_result.errors

    candidate_variant_ref = G.GenomeContractRef("synthetic://candidate/t0-g2-source-edited", "v5",
        g2.source.candidate_ref.schema_hash, g2.source.candidate_ref.canonicalization_hash,
        g2.source.candidate_ref.compatibility_profile)
    candidate_variant = _g2_variant(g2; candidate_ref=candidate_variant_ref)
    candidate_result = G.vnext_declaration_transport_v1(g1, candidate_variant, g3,
        _CANDIDATE, G.VNextG2CandidateEnvelopeV1(_CANDIDATE,
            candidate_variant.source.candidate_ref; mapping_status=:mapped,
            mapping_receipt=receipt, reason="source candidate mismatch"),
        _AXES[1], _AXES[2], _AXES[3], _CHILDREN)
    @test candidate_result.status === :fail_closed
    @test "G2_mapping_source_candidate_ref_mismatch" in candidate_result.errors
    @test "G2_mapping_source_hash_mismatch" in candidate_result.errors

    source_hash_receipt = G.VNextG2CandidateMappingReceiptV1(g2.source, _CANDIDATE,
        G.digest256_text("same-valid-evidence"), "source.candidate_ref";
        source_hash=G.digest256_text("independently-stale-source-hash"),
        attestation=:trusted_receipt)
    source_hash_result = G.vnext_declaration_transport_v1(g1, g2, g3, _CANDIDATE,
        G.VNextG2CandidateEnvelopeV1(_CANDIDATE, g2.source.candidate_ref;
            mapping_status=:mapped, mapping_receipt=source_hash_receipt,
            reason="source hash mismatch only"), _AXES[1], _AXES[2], _AXES[3], _CHILDREN)
    @test source_hash_result.status === :fail_closed
    @test source_hash_result.errors == ("G2_mapping_source_hash_mismatch",)

    unattested_receipt = G.VNextG2CandidateMappingReceiptV1(g2.source, _CANDIDATE,
        G.digest256_text("unattested-evidence-field"), "source.candidate_ref";
        attestation=:unattested)
    unattested_result = G.vnext_declaration_transport_v1(g1, g2, g3, _CANDIDATE,
        G.VNextG2CandidateEnvelopeV1(_CANDIDATE, g2.source.candidate_ref;
            mapping_status=:mapped, mapping_receipt=unattested_receipt,
            reason="unattested mapping"), _AXES[1], _AXES[2], _AXES[3], _CHILDREN)
    @test unattested_result.status === :fail_closed
    @test "G2_mapping_unattested" in unattested_result.errors

    bad_path_receipt = G.VNextG2CandidateMappingReceiptV1(g2.source, _CANDIDATE,
        G.digest256_text("bad-path-evidence"), "/wrong/path";
        attestation=:trusted_receipt)
    bad_path_result = G.vnext_declaration_transport_v1(g1, g2, g3, _CANDIDATE,
        G.VNextG2CandidateEnvelopeV1(_CANDIDATE, g2.source.candidate_ref;
            mapping_status=:mapped, mapping_receipt=bad_path_receipt,
            reason="field path mismatch"), _AXES[1], _AXES[2], _AXES[3], _CHILDREN)
    @test bad_path_result.status === :fail_closed
    @test "G2_mapping_field_path_mismatch" in bad_path_result.errors
end

@testset "AD-30 T0 rejects stale complete declaration hashes" begin
    g1 = _g1(); g2 = _g2(); g3 = _g3()
    tampered = G.G3SFDeclarationV1(g3.candidate_ref, g3.source_id, g3.owner_scope,
        g3.endpoints, g3.law, g3.ledger_entries, g3.ledger_closure,
        g3.feedback_targets, g3.upstream_authority, G.digest256_text("stale"))
    result = G.vnext_declaration_transport_v1(g1, g2, tampered, _CANDIDATE,
        _g2_envelope(g2), _AXES[1], _AXES[2], _AXES[3], _CHILDREN)
    @test result.status === :fail_closed
    @test "G3_declaration_hash_mismatch" in result.errors

    edited_entry = G.G3SFLedgerEntryV1(g3.ledger_entries[1].entry_id,
        g3.ledger_entries[1].endpoint_id, g3.ledger_entries[1].unit,
        g3.ledger_entries[1].direction, g3.ledger_entries[1].sign,
        g3.ledger_entries[1].effect, 99 // 100, g3.ledger_entries[1].owner_scope)
    stale_ledger = G.G3SFDeclarationV1(g3.candidate_ref, g3.source_id, g3.owner_scope,
        g3.endpoints, g3.law, (edited_entry, g3.ledger_entries[2:end]...), g3.ledger_closure,
        g3.feedback_targets, g3.upstream_authority, g3.declaration_hash)
    stale_ledger_result = G.vnext_declaration_transport_v1(g1, g2, stale_ledger, _CANDIDATE,
        _g2_envelope(g2), _AXES[1], _AXES[2], _AXES[3], _CHILDREN)
    @test stale_ledger_result.status === :fail_closed
    @test "G3_declaration_hash_mismatch" in stale_ledger_result.errors

    edited_target = G.G3SFFeedbackTargetV1("g1-residual-edited", :G1,
        "/residual/edited", :residual, g3.feedback_targets[1].unit, :in, 1,
        g3.source_id, g3.owner_scope, g3.feedback_targets[1].authority)
    stale_feedback = G.G3SFDeclarationV1(g3.candidate_ref, g3.source_id, g3.owner_scope,
        g3.endpoints, g3.law, g3.ledger_entries, g3.ledger_closure,
        (edited_target, g3.feedback_targets[2]), g3.upstream_authority, g3.declaration_hash)
    stale_feedback_result = G.vnext_declaration_transport_v1(g1, g2, stale_feedback, _CANDIDATE,
        _g2_envelope(g2), _AXES[1], _AXES[2], _AXES[3], _CHILDREN)
    @test stale_feedback_result.status === :fail_closed
    @test "G3_declaration_hash_mismatch" in stale_feedback_result.errors

    stale_authority_ref = G.GenomeContractRef("synthetic://stale-authority", "v5",
        G.digest256_text("stale-authority-schema"), G.digest256_text("stale-authority-canonical"),
        "stale-authority-profile")
    edited_authority = G.G3SFAuthorityV1(:G1, _CANDIDATE, stale_authority_ref,
        G.digest256_text("stale-authority-content"), :actual; attestation=:trusted_receipt)
    stale_authority = G.G3SFDeclarationV1(g3.candidate_ref, g3.source_id, g3.owner_scope,
        g3.endpoints, g3.law, g3.ledger_entries, g3.ledger_closure,
        g3.feedback_targets, (edited_authority, g3.upstream_authority[2]), g3.declaration_hash)
    stale_authority_result = G.vnext_declaration_transport_v1(g1, g2, stale_authority, _CANDIDATE,
        _g2_envelope(g2), _AXES[1], _AXES[2], _AXES[3], _CHILDREN)
    @test stale_authority_result.status === :fail_closed
    @test "G3_declaration_hash_mismatch" in stale_authority_result.errors
end

@testset "AD-30 T0 rejects contradictory G3 authority" begin
    g1 = _g1(); g2 = _g2(); g3 = _g3()
    contradictory = G.G3SFAuthorityV1(:G1, _CANDIDATE, nothing, nothing, :contradictory)
    upstream_contradictory = G.g3_sf_declaration_v1(g3.candidate_ref, g3.source_id, g3.owner_scope,
        g3.endpoints, g3.law, g3.ledger_entries, g3.ledger_closure, g3.feedback_targets,
        (contradictory, g3.upstream_authority[2]))
    upstream_result = G.vnext_declaration_transport_v1(g1, g2, upstream_contradictory,
        _CANDIDATE, _g2_envelope(g2), _AXES[1], _AXES[2], _AXES[3], _CHILDREN)
    @test upstream_result.status === :fail_closed
    @test "G3_upstream_contradictory_authority:G1" in upstream_result.errors

    contradictory_target = G.G3SFFeedbackTargetV1("g1-residual-contradictory", :G1,
        "/residual", :residual, g3.feedback_targets[1].unit, :in, 1, g3.source_id,
        g3.owner_scope, contradictory)
    feedback_contradictory = G.g3_sf_declaration_v1(g3.candidate_ref, g3.source_id,
        g3.owner_scope, g3.endpoints, g3.law, g3.ledger_entries, g3.ledger_closure,
        (contradictory_target, g3.feedback_targets[2]), g3.upstream_authority)
    feedback_result = G.vnext_declaration_transport_v1(g1, g2, feedback_contradictory,
        _CANDIDATE, _g2_envelope(g2), _AXES[1], _AXES[2], _AXES[3], _CHILDREN)
    @test feedback_result.status === :fail_closed
    @test "G3_feedback_contradictory_authority:g1-residual-contradictory" in feedback_result.errors

    stale_authority = G.G3SFAuthorityV1(:G1, _CANDIDATE, nothing, nothing, :stale)
    upstream_stale = G.g3_sf_declaration_v1(g3.candidate_ref, g3.source_id, g3.owner_scope,
        g3.endpoints, g3.law, g3.ledger_entries, g3.ledger_closure, g3.feedback_targets,
        (stale_authority, g3.upstream_authority[2]))
    upstream_stale_result = G.vnext_declaration_transport_v1(g1, g2, upstream_stale,
        _CANDIDATE, _g2_envelope(g2), _AXES[1], _AXES[2], _AXES[3], _CHILDREN)
    @test upstream_stale_result.status === :fail_closed
    @test "G3_upstream_stale_authority:G1" in upstream_stale_result.errors

    stale_target = G.G3SFFeedbackTargetV1("g1-residual-stale", :G1,
        "/residual", :residual, g3.feedback_targets[1].unit, :in, 1, g3.source_id,
        g3.owner_scope, stale_authority)
    feedback_stale = G.g3_sf_declaration_v1(g3.candidate_ref, g3.source_id,
        g3.owner_scope, g3.endpoints, g3.law, g3.ledger_entries, g3.ledger_closure,
        (stale_target, g3.feedback_targets[2]), g3.upstream_authority)
    feedback_stale_result = G.vnext_declaration_transport_v1(g1, g2, feedback_stale,
        _CANDIDATE, _g2_envelope(g2), _AXES[1], _AXES[2], _AXES[3], _CHILDREN)
    @test feedback_stale_result.status === :fail_closed
    @test "G3_feedback_stale_authority:g1-residual-stale" in feedback_stale_result.errors
end

@testset "AD-30 T0 rejects bare actual feedback authority and tracks edits" begin
    g1 = _g1(); g2 = _g2(); g3 = _g3()
    foreign_contract = G.GenomeContractRef("synthetic://foreign/G1", "v5",
        G.digest256_text("foreign-schema"), G.digest256_text("foreign-canonical"), "foreign-profile")
    actual_unattested = G.G3SFAuthorityV1(:G1, _CANDIDATE, foreign_contract,
        G.digest256_text("foreign-content"), :actual; attestation=:unattested)
    authorities = (actual_unattested, g3.upstream_authority[2])
    targets = (G.G3SFFeedbackTargetV1("g1-residual", :G1, "/residual", :residual,
        g3.feedback_targets[1].unit, :in, 1, g3.source_id, g3.owner_scope, actual_unattested),
        g3.feedback_targets[2])
    bare_actual = G.g3_sf_declaration_v1(g3.candidate_ref, g3.source_id, g3.owner_scope,
        g3.endpoints, g3.law, g3.ledger_entries, g3.ledger_closure, targets, authorities)
    bare_result = G.vnext_declaration_transport_v1(g1, g2, bare_actual, _CANDIDATE,
        _g2_envelope(g2), _AXES[1], _AXES[2], _AXES[3], _CHILDREN)
    @test bare_result.status === :fail_closed
    @test "G3_feedback_unattested_authority:g1-residual" in bare_result.errors

    upstream_actual = G.g3_sf_declaration_v1(g3.candidate_ref, g3.source_id, g3.owner_scope,
        g3.endpoints, g3.law, g3.ledger_entries, g3.ledger_closure, g3.feedback_targets,
        (actual_unattested, g3.upstream_authority[2]))
    upstream_result = G.vnext_declaration_transport_v1(g1, g2, upstream_actual, _CANDIDATE,
        _g2_envelope(g2), _AXES[1], _AXES[2], _AXES[3], _CHILDREN)
    @test upstream_result.status === :fail_closed
    @test "G3_upstream_unattested_authority:G1" in upstream_result.errors

    edited_g1_field = G.G1DiffusionScalarFieldV1(g1.u.field_id, g1.u.physical_type, g1.u.source_ref;
        source_expression="u_candidate(x)=x1-x2+x3")
    edited_g1 = G.g1_diffusion_edit_source(g1, :u, edited_g1_field)
    edited_chart = G.G2MBChartMapV1(g2.source.chart_map.chart_ref,
        g2.source.chart_map.domain_lower, g2.source.chart_map.domain_upper,
        ((5, 0, 0), (0, 3, 0), (0, 0, 4)), g2.source.chart_map.offset)
    edited_g2 = G.g2mb_edit_source(g2, :chart_map, edited_chart)
    base_result = G.vnext_declaration_transport_v1(g1, g2, g3, _CANDIDATE,
        _g2_envelope(g2), _AXES[1], _AXES[2], _AXES[3], _CHILDREN)
    edit_result = G.vnext_declaration_transport_v1(edited_g1, edited_g2, g3, _CANDIDATE,
        _g2_envelope(edited_g2), _AXES[1], _AXES[2], _AXES[3], _CHILDREN)
    @test edited_g1.source_hash != g1.source_hash
    @test edited_g1.declaration_hash != g1.declaration_hash
    @test edited_g2.source.source_hash != g2.source.source_hash
    @test edited_g2.declaration_hash != g2.declaration_hash
    @test edit_result.transport.g1_source_hash != base_result.transport.g1_source_hash
    @test edit_result.transport.g2_source_hash != base_result.transport.g2_source_hash
    @test edit_result.transport.g1_body_hash != base_result.transport.g1_body_hash
    @test edit_result.transport.g2_body_hash != base_result.transport.g2_body_hash
    @test base_result.transport.bundle_hash != edit_result.transport.bundle_hash
end

println("VNEXT_T0_STATIC_TEST_DEFINED=true")
println("VNEXT_T0_JULIA_OR_DESC_EXECUTED=false")
