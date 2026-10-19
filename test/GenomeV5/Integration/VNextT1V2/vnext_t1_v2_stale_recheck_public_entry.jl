using Test
using FusionConceptAI

const _R11C_ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", ".."))
const G_R11C = FusionConceptAI

Base.include(Main, joinpath(@__DIR__, "..", "vnext_g3_binding_authority_bridge_local_v1_tests.jl"))
Base.include(G_R11C, joinpath(_R11C_ROOT, "src", "Contracts", "VNextT1CanonicalBytesV2.jl"))
Base.include(G_R11C, joinpath(_R11C_ROOT, "src", "Contracts", "VNextT1CandidateBindingV2.jl"))
Base.include(G_R11C, joinpath(_R11C_ROOT, "src", "GenomeV5", "Integration", "VNextDeclarationAuthorityRecheckLocalV2.jl"))
Base.include(G_R11C, joinpath(_R11C_ROOT, "src", "Contracts", "CandidateStatePackageV5NextV2.jl"))
Base.include(G_R11C, joinpath(_R11C_ROOT, "src", "GenomeV5", "Integration", "VNextGenomeV5IntegrationV2.jl"))
Base.include(G_R11C, joinpath(_R11C_ROOT, "src", "Contracts", "VNextT1PackageBindingAdapterV2.jl"))

function _r11c_recheck_to_v1(x, t, declarations, g3_record)
    out = x.output
    o = (candidate_ref=t.candidate_ref, bundle_hash=t.bundle_hash,
        g1=declarations[1], g2=declarations[2], g3=g3_record,
        children=t.children, feedback=t.feedback)
    (; status=x.status, resolution=x.resolution, accepted=x.accepted,
        claim_ceiling=x.claim_ceiling, errors=x.errors, reasons=x.reasons,
        output=o, prior_bundle_sha256=x.prior_bundle_sha256)
end

function _r11c_fixture()
    g1 = Main._t0l_g1(); g2 = Main._t0l_g2(); g3 = Main._t0l_g3()
    declarations = (Main._t0l_present(:G1, g1),
        Main._t0l_present(:G2, g2; path="src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl"),
        Main._t0l_present(:G3, g3; path="src/GenomeV5/G3/G3SourceFeedbackLawV1.jl"))
    children = (Main._t0l_child(:realization), Main._t0l_child(:control), Main._t0l_child(:binding))
    feedback = (Main._t0l_feedback("g1-residual", declarations[1].declaration_ref),
        Main._t0l_feedback("g2-thermal", declarations[2].declaration_ref))
    admission = G_R11C.vnext_declaration_transport_local_v1(Main._T0L_CANDIDATE,
        declarations, children, feedback)
    t = admission.transport
    recheck = G_R11C.vnext_declaration_authority_recheck_local_v2(
        G_R11C.VNextAuthorityRecheckLocalV2Input(Main._T0L_CANDIDATE, t))
    g3_record = declarations[3]
    rs = Main._realization_state(g3_record); cs = Main._control_state(g3_record)
    ri, re = G_R11C._vnext_g3_state_info(rs, :realization, Main._T0L_CANDIDATE,
        g3_record.declaration_ref, g3_record.declaration_identity_hash); re === nothing || error(re)
    ci, ce = G_R11C._vnext_g3_state_info(cs, :control, Main._T0L_CANDIDATE,
        g3_record.declaration_ref, g3_record.declaration_identity_hash); ce === nothing || error(ce)
    rcommit = G_R11C.VNextG3BindingChildExpectedCommitmentV1(ri.child_kind, ri.candidate_ref,
        ri.parent_g3_declaration_ref, ri.parent_g3_declaration_hash, ri.child_ref,
        ri.contract_ref, ri.source_record_ref, ri.source_record_hash,
        ri.source_content_hash, ri.child_identity_hash, ri.state_hash)
    ccommit = G_R11C.VNextG3BindingChildExpectedCommitmentV1(ci.child_kind, ci.candidate_ref,
        ci.parent_g3_declaration_ref, ci.parent_g3_declaration_hash, ci.child_ref,
        ci.contract_ref, ci.source_record_ref, ci.source_record_hash,
        ci.source_content_hash, ci.child_identity_hash, ci.state_hash)
    expected = G_R11C.vnext_g3_binding_expected_commitment_v1(Main._T0L_CANDIDATE,
        recheck.prior_bundle_sha256, g3_record.declaration_ref, g3_record.declaration_identity_hash,
        rcommit, ccommit)
    key = G_R11C.G3BindingChildKeyV2(Main._T0L_CANDIDATE, g3_record.declaration_ref,
        g3_record.declaration_identity_hash, :binding, "binding-child-v2")
    a1 = G_R11C.G3SFAuthorityV1(:G1, Main._T0L_CANDIDATE, nothing, nothing, :missing)
    a2 = G_R11C.G3SFAuthorityV1(:G2, Main._T0L_CANDIDATE, nothing, nothing, :missing)
    l1 = G_R11C.G3BindingLinkV1("g1", :G1, "/g1", :residual, Main.UNIT, :in, 1, "local-g3", "local-owner", a1)
    l2 = G_R11C.G3BindingLinkV1("g2", :G2, "/g2", :thermal_load, Main.UNIT, :in, 1, "local-g3", "local-owner", a2)
    bridge = G_R11C.vnext_g3_binding_authority_bridge_local_v1(
        _r11c_recheck_to_v1(recheck, t, declarations, g3_record), expected, rs, cs, key;
        initial_links=(l1, l2))
    authority = (status=bridge.status, resolution=bridge.resolution,
        authority_verified=bridge.authority_verified, binding_state=bridge.binding_state,
        commitment_hash=expected.commitment_hash, expected_commitment=expected)
    parents = (G_R11C.vnext_t1_parent_commitment_v2(Main._T0L_CANDIDATE, t.declarations[1]),
        G_R11C.vnext_t1_parent_commitment_v2(Main._T0L_CANDIDATE, t.declarations[2]))
    input = G_R11C.VNextT1AdmissionInputV2(Main._T0L_CANDIDATE, t, recheck, parents,
        expected.commitment_hash, authority)
    (input=input, transport=t, recheck=recheck)
end

function _r11c_result_with_wire(r, wire)
    G_R11C.VNextAuthorityRecheckLocalV2Result(r.status, r.resolution, r.accepted,
        r.claim_ceiling, r.output, r.errors, r.reasons, wire, r.prior_bundle_sha256)
end

function _r11c_call(input)
    try
        (:returned, G_R11C.vnext_t1_admit_v2(input))
    catch error
        (:threw, error)
    end
end

const _R11C_FIXTURE = _r11c_fixture()

@testset "R11c public stale-recheck fail-closed ordering" begin
    f = _R11C_FIXTURE
    t_before = G_R11C.canonical_json(f.transport)
    expected_wire = G_R11C._vnext_ar_v2_carrier(f.transport)
    expected_bytes = G_R11C.copy_bytes(expected_wire)
    flipped = isempty(expected_bytes) ? UInt8[0x01] :
        vcat(UInt8[expected_bytes[1] ⊻ 0x01], expected_bytes[2:end])

    hash_wire = G_R11C.VNextT1CanonicalBytesV2(flipped)
    length_wire = ccall(:jl_new_struct, Any, (Any, Any, Any, Any),
        G_R11C.VNextT1CanonicalBytesV2,
        String(vcat(expected_bytes, UInt8[0x01])), expected_wire.sha256, expected_wire.encoding)
    bytes_wire = ccall(:jl_new_struct, Any, (Any, Any, Any, Any),
        G_R11C.VNextT1CanonicalBytesV2,
        String(vcat(UInt8[expected_bytes[1] ⊻ 0x01], expected_bytes[2:end])),
        expected_wire.sha256, expected_wire.encoding)

    cases = ((:hash, hash_wire, :t0_recheck_wire_hash_mismatch),
        (:length, length_wire, :t0_recheck_wire_length_mismatch),
        (:bytes, bytes_wire, :t0_recheck_wire_bytes_mismatch))
    for (label, wire, reason) in cases
        stale = _r11c_result_with_wire(f.recheck, wire)
        bad_input = G_R11C.VNextT1AdmissionInputV2(f.input.candidate_ref,
            f.transport, stale, f.input.parent_commitments,
            f.input.g3_expected_commitment, f.input.g3_authority)
        stale_before = G_R11C.copy_bytes(stale.prior_bundle_bytes)
        observed = _r11c_call(bad_input)
        @test observed[1] === :returned
        result = observed[2]
        @test result.status === :fail_closed
        @test result.resolution === :none
        @test result.accepted === false
        @test result.package === nothing
        @test result.errors === (reason,)
        @test G_R11C.canonical_json(f.transport) == t_before
        @test G_R11C.copy_bytes(stale.prior_bundle_bytes) == stale_before
        println("R11C_PUBLIC_FIRST_ERROR[", label, "] = ", first(result.errors))
    end
    println("R11C_PUBLIC_STALE_RECHECK_CASES=3")
end
