using Test
using FusionConceptAI

const _T1_ROOT = joinpath(@__DIR__, "..", "..", "..")
const G = FusionConceptAI

# The transport helper is definition-only when included from this file.  It
# supplies the real G1/G2/G3 constructors and local source-backed fixture;
# this test then performs the complete local T0 transport -> recheck -> T1
# admission chain without loading either additive file into the main module.
Base.include(Main, joinpath(@__DIR__, "vnext_declaration_transport_local_v1_tests.jl"))
Base.include(G, joinpath(_T1_ROOT, "src", "GenomeV5", "Integration",
    "VNextDeclarationAuthorityRecheckLocalV1.jl"))
Base.include(G, joinpath(_T1_ROOT, "src", "Contracts",
    "CandidateStatePackageV5Next.jl"))
Base.include(G, joinpath(_T1_ROOT, "src", "GenomeV5", "Integration",
    "VNextGenomeV5Integration.jl"))

const _T1_CANDIDATE = Main._T0L_CANDIDATE

function _t1_fixture(; labels=("t1",))
    g1, g2, g3 = Main._t0l_g1(), Main._t0l_g2(), Main._t0l_g3()
    declarations = (Main._t0l_present(:G1, g1; label=labels[1]),
        Main._t0l_present(:G2, g2;
            label=labels[1], path="src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl"),
        Main._t0l_present(:G3, g3;
            label=labels[1], path="src/GenomeV5/G3/G3SourceFeedbackLawV1.jl"))
    children = (Main._t0l_child(:realization), Main._t0l_child(:control),
        Main._t0l_child(:binding))
    # T1 performs a second, stricter feedback-body join than T0.  Preserve the
    # actual G3 target objects while adding the candidate/source/declaration
    # joins required by that later boundary.
    feedback = ntuple(i -> begin
        id = i == 1 ? "g1-residual" : "g2-thermal"
        target = i == 1 ? declarations[1].declaration_ref : declarations[2].declaration_ref
        layer = i == 1 ? :G1 : :G2
        raw_target = only(filter(x -> x.target_id == id, g3.feedback_targets))
        body = (candidate_ref=_T1_CANDIDATE, source_ref=
            (i == 1 ? declarations[1].source_ref : declarations[2].source_ref),
            declaration_ref=(i == 1 ? declarations[1].declaration_ref : declarations[2].declaration_ref),
            target_ref=target, feedback_targets=(raw_target,))
        G.VNextT0LocalFeedbackV1(id, layer, _T1_CANDIDATE, target, body,
            G.canonical_hash(body))
    end, 2)
    transport_admission = G.vnext_declaration_transport_local_v1(
        _T1_CANDIDATE, declarations, children, feedback)
    transport_admission.status === :valid ||
        error("T1 fixture transport failed: $(transport_admission.errors)")
    transport = transport_admission.transport
    recheck = G.vnext_declaration_authority_recheck_local_v1(
        G.VNextAuthorityRecheckLocalInputV1(_T1_CANDIDATE, transport, declarations))
    (transport=transport, declarations=declarations, children=children,
        feedback=feedback, recheck=recheck)
end

_t1_input(x; candidate=_T1_CANDIDATE, t0=x.recheck, no_legacy=nothing) =
    G.VNextT1AdmissionInputV1(candidate, t0, x.transport, no_legacy)

function _t1_rebuild_transport(x; candidate=x.transport.candidate_ref,
        declarations=x.transport.declarations, children=x.transport.children,
        feedback=x.transport.feedback, bundle_hash=x.transport.bundle_hash,
        status=x.transport.status, errors=x.transport.errors, gaps=x.transport.gaps)
    G.VNextT0LocalTransportV1(candidate, Tuple(declarations), Tuple(children),
        Tuple(feedback), bundle_hash, status, errors, gaps)
end

@testset "UP1-04A VNext T1 local-contract focused admission" begin
    fixture = _t1_fixture()
    @test fixture.recheck.status === :local_checked_present
    @test fixture.recheck.resolution === :resolved
    @test fixture.recheck.accepted === false
    @test fixture.recheck.claim_ceiling === :contract_only
    @test fixture.transport.status === :valid
    @test fixture.transport.gaps == (:g3_child_terminal_deferred,)

    admitted = G.vnext_t1_admit_skeleton_v1(_t1_input(fixture))
    @test admitted.status === :prepared_not_executed
    @test admitted.resolution === :terminal_deferred
    @test admitted.accepted === false
    @test admitted.claim_ceiling === :contract_only
    @test admitted.package isa G.CandidateStatePackageV5Next
    package = admitted.package
    @test package.candidate_ref == _T1_CANDIDATE
    @test package.component_count_receipt.component_count == 3
    @test package.component_count_receipt.declaration_count == 3
    @test package.component_count_receipt.child_count == 3
    @test package.component_count_receipt.feedback_ids ==
        ("g1-residual", "g2-thermal")
    @test Tuple(x.target_id for x in package.feedback) ==
        ("g1-residual", "g2-thermal")
    @test package.no_legacy_receipt.legacy_refs == ()
    @test package.no_legacy_receipt.status === :no_legacy_mapping
    @test package.t0_gate.prior_bundle.bundle_hash == fixture.transport.bundle_hash
    @test package.t0_gate.prior_bundle.canonical_bytes.bytes ==
        Tuple(Vector{UInt8}(codeunits(G.canonical_json(fixture.transport))))
    @test package.semantic_identity == package.component_identity.semantic_identity
    @test package.package_hash isa G.Digest256
    round_trip = deepcopy(package)
    @test G.canonical_json(package) == G.canonical_json(round_trip)
    @test package.t0_gate.output_bytes.sha256 ==
        G._vnext_t1_sha(package.t0_gate.output_bytes.bytes)
    for declaration in package.declarations
        @test declaration.source_bytes.sha256 ==
            G._vnext_t1_sha(declaration.source_bytes.bytes)
        @test declaration.declaration_bytes.sha256 ==
            G._vnext_t1_sha(declaration.declaration_bytes.bytes)
        @test declaration.semantic_body_bytes.sha256 ==
            G._vnext_t1_sha(declaration.semantic_body_bytes.bytes)
    end

    @testset "label-erased component identity" begin
        relabeled = _t1_fixture(labels=("different-visible-label",))
        relabeled_result = G.vnext_t1_admit_skeleton_v1(_t1_input(relabeled))
        @test relabeled_result.package isa G.CandidateStatePackageV5Next
        @test relabeled_result.package.component_identity.semantic_identity ==
            package.component_identity.semantic_identity
        @test relabeled_result.package.semantic_identity == package.semantic_identity
        # The prior T0 snapshot is intentionally still part of package_hash;
        # only the label-erased component identity is required to be stable.
        @test relabeled_result.package.package_hash != package.package_hash
    end

    @testset "typed absence fails closed" begin
        absent_g3 = G.VNextT0LocalAbsentDeclarationV1(:G3, _T1_CANDIDATE,
            :missing_material, :terminal_deferred)
        absent_recheck = G.vnext_declaration_authority_recheck_local_v1(
            G.VNextAuthorityRecheckLocalInputV1(_T1_CANDIDATE,
                fixture.transport, (fixture.declarations[1], fixture.declarations[2], absent_g3)))
        @test absent_recheck.status === :typed_absent
        @test absent_recheck.resolution === :terminal_deferred
        absent_result = G.vnext_t1_admit_skeleton_v1(_t1_input(fixture;
            t0=absent_recheck))
        @test absent_result.status === :fail_closed
        @test absent_result.package === nothing
        @test absent_result.accepted === false
        @test absent_result.claim_ceiling === :contract_only
    end

    @testset "negative input matrix" begin
        @test G.vnext_t1_admit_skeleton_v1(G.VNextT1AdmissionInputV1(
            _T1_CANDIDATE, nothing, fixture.transport)).status === :terminal_deferred
        @test G.vnext_t1_admit_skeleton_v1(G.VNextT1AdmissionInputV1(
            _T1_CANDIDATE, fixture.recheck, nothing)).status === :terminal_deferred

        foreign = G.QualifiedRefV1("local://foreign-t1-candidate", "v5")
        @test G.vnext_t1_admit_skeleton_v1(_t1_input(fixture;
            candidate=foreign)).status === :fail_closed
        @test G.vnext_t1_admit_skeleton_v1(_t1_input(fixture;
            no_legacy=G.vnext_t1_no_legacy_receipt_v1(foreign))).status === :fail_closed
        bad_transport = _t1_rebuild_transport(fixture; status=:invalid)
        @test G.vnext_t1_admit_skeleton_v1(G.VNextT1AdmissionInputV1(
            _T1_CANDIDATE, fixture.recheck, bad_transport)).status === :fail_closed

        reversed_feedback = (fixture.feedback[2], fixture.feedback[1])
        reordered = _t1_rebuild_transport(fixture; feedback=reversed_feedback)
        @test G.vnext_t1_admit_skeleton_v1(G.VNextT1AdmissionInputV1(
            _T1_CANDIDATE, fixture.recheck, reordered)).status === :fail_closed
        duplicate_feedback = _t1_rebuild_transport(fixture;
            feedback=(fixture.feedback[1], fixture.feedback[1]))
        @test G.vnext_t1_admit_skeleton_v1(G.VNextT1AdmissionInputV1(
            _T1_CANDIDATE, fixture.recheck, duplicate_feedback)).status === :fail_closed

        wrong_bundle = _t1_rebuild_transport(fixture;
            bundle_hash=G.digest256_text("wrong-t1-bundle-hash"))
        @test G.vnext_t1_admit_skeleton_v1(G.VNextT1AdmissionInputV1(
            _T1_CANDIDATE, fixture.recheck, wrong_bundle)).status === :fail_closed
        @testset "legacy status/identity constructor boundary dispatch" begin
            valid_receipt = G.vnext_t1_no_legacy_receipt_v1(_T1_CANDIDATE)
            # The closed constructor rejects :legacy_mapping before an object
            # can exist. The forged legacy receipt ID is the representable
            # boundary mutation and must still traverse T1 admission.
            forged_legacy = G.VNextT1NoLegacyReceiptV1(
                G.QualifiedRefV1("legacy://GenomeV5/T1/migration", "v1"),
                valid_receipt.candidate_ref, (), valid_receipt.status,
                valid_receipt.candidate_identity_hash)
            legacy_result = G.vnext_t1_admit_skeleton_v1(_t1_input(fixture;
                no_legacy=forged_legacy))
            @test legacy_result.status === :fail_closed
            @test legacy_result.resolution === :none
            @test legacy_result.package === nothing
            @test legacy_result.accepted === false
            @test legacy_result.errors === (:t1_projection_invalid,)
            @test_throws ArgumentError G.VNextT1NoLegacyReceiptV1(
                G.QualifiedRefV1(G.VNEXT_T1_NO_LEGACY_RECEIPT_ID_V1, "v1"),
                _T1_CANDIDATE, (), :legacy_mapping,
                G.canonical_hash((kind=:candidate_identity,
                    candidate_ref=_T1_CANDIDATE)))
        end
    end
end

println("UP1_04A_VNEXT_T1_LOCAL_STATUS=prepared_not_executed")
println("UP1_04A_VNEXT_T1_LOCAL_ACCEPTED=false")
println("UP1_04A_VNEXT_T1_LOCAL_CLAIM_CEILING=contract_only")
println("UP1_04A_VNEXT_T1_LOCAL_T2_UP2_R_CREDIT=false")
println("UP1_04A_VNEXT_T1_LOCAL_NEGATIVE_CASES=9")
