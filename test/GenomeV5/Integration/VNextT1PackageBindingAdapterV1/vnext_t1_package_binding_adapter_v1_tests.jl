using Test
using FusionConceptAI

const _PACKAGE_ADAPTER_ROOT = joinpath(@__DIR__, "..", "..", "..", "..")
const _PACKAGE_ADAPTER = FusionConceptAI

# The existing local T0 helper is definition-only when included from this
# test (its historical testsets are guarded by PROGRAM_FILE).  It supplies
# the source-backed declarations, child receipts, and real local transport.
Base.include(Main, joinpath(_PACKAGE_ADAPTER_ROOT, "test", "GenomeV5",
    "Integration", "vnext_declaration_transport_local_v1_tests.jl"))
Base.include(_PACKAGE_ADAPTER, joinpath(_PACKAGE_ADAPTER_ROOT, "src",
    "GenomeV5", "Integration", "VNextDeclarationAuthorityRecheckLocalV1.jl"))
Base.include(_PACKAGE_ADAPTER, joinpath(_PACKAGE_ADAPTER_ROOT, "src",
    "Contracts", "CandidateStatePackageV5Next.jl"))
Base.include(_PACKAGE_ADAPTER, joinpath(_PACKAGE_ADAPTER_ROOT, "src",
    "GenomeV5", "Integration", "VNextGenomeV5Integration.jl"))
if !isdefined(_PACKAGE_ADAPTER, :VNextT1CanonicalBytesV2)
    Base.include(_PACKAGE_ADAPTER, joinpath(_PACKAGE_ADAPTER_ROOT, "src",
        "Contracts", "VNextT1CanonicalBytesV2.jl"))
end
if !isdefined(_PACKAGE_ADAPTER, :VNextT1CandidateBindingInputV2)
    Base.include(_PACKAGE_ADAPTER, joinpath(_PACKAGE_ADAPTER_ROOT, "src",
        "Contracts", "VNextT1CandidateBindingV2.jl"))
end
Base.include(_PACKAGE_ADAPTER, joinpath(_PACKAGE_ADAPTER_ROOT, "src",
    "Contracts", "VNextT1PackageBindingAdapterV1.jl"))

const A = _PACKAGE_ADAPTER
const REF = A.QualifiedRefV1("local://candidate/up1-04a", "v5")
const DIGEST = A.Digest256(repeat("1", 64))
const PACKAGE_HASH = A.Digest256(repeat("2", 64))
const WIRE = A.VNextT1CanonicalBytesV2(UInt8[0x00, 0xff, 0x10, 0x20, 0x7f])
const INPUT = A.VNextT1CandidateBindingInputV2(REF, DIGEST, PACKAGE_HASH, WIRE)

function _adapter_real_package(; g3_child_status=:terminal_deferred)
    candidate = Main._T0L_CANDIDATE
    g1, g2, g3 = Main._t0l_g1(), Main._t0l_g2(), Main._t0l_g3()
    declarations = (Main._t0l_present(:G1, g1),
        Main._t0l_present(:G2, g2), Main._t0l_present(:G3, g3))
    children = (Main._t0l_child(:realization), Main._t0l_child(:control),
        Main._t0l_child(:binding))
    if g3_child_status === :typed_absent
        child = children[1]
        bytes = child.factory_receipt_bytes
        children = (A.VNextT0LocalChildAbsentV1(child.kind, child.candidate_ref,
            child.layer, child.child_id, :typed_absent, child.reason,
            child.candidate_identity_created, child.factory_api, bytes,
            child.factory_receipt_hash, child.source_path), children[2], children[3])
    end
    feedback = ntuple(i -> begin
        id = i == 1 ? "g1-residual" : "g2-thermal"
        target = i == 1 ? declarations[1].declaration_ref : declarations[2].declaration_ref
        layer = i == 1 ? :G1 : :G2
        raw_target = only(filter(x -> x.target_id == id, g3.feedback_targets))
        body = (candidate_ref=candidate,
            source_ref=(i == 1 ? declarations[1].source_ref : declarations[2].source_ref),
            declaration_ref=(i == 1 ? declarations[1].declaration_ref : declarations[2].declaration_ref),
            target_ref=target, feedback_targets=(raw_target,))
        A.VNextT0LocalFeedbackV1(id, layer, candidate, target, body,
            A.canonical_hash(body))
    end, 2)
    transport_admission = A.vnext_declaration_transport_local_v1(
        candidate, declarations, children, feedback)
    transport_admission.status === :valid ||
        error("adapter fixture transport failed: $(transport_admission.errors)")
    recheck = A.vnext_declaration_authority_recheck_local_v1(
        A.VNextAuthorityRecheckLocalInputV1(candidate,
            transport_admission.transport, declarations))
    input = A.VNextT1AdmissionInputV1(candidate, recheck,
        transport_admission.transport, nothing)
    admitted = A.vnext_t1_admit_skeleton_v1(input)
    admitted.status === :prepared_not_executed ||
        error("adapter fixture package admission failed: $(admitted.status)")
    admitted.package
end

@testset "VNext T1 package binding adapter result boundary" begin
    receipt_hash = A._vnext_t1_package_binding_adapter_receipt_hash_v1(
        :prepared_not_executed, :terminal_deferred,
        :mapped_prepared_not_executed, :prepared_not_executed,
        :terminal_deferred, REF, DIGEST, PACKAGE_HASH, WIRE.sha256)
    receipt = A.VNextT1PackageBindingAdapterResultV1(
        A.VNEXT_T1_PACKAGE_BINDING_ADAPTER_DOMAIN_V1,
        A.VNEXT_T1_PACKAGE_BINDING_ADAPTER_SCHEMA_V1,
        A.VNEXT_T1_PACKAGE_BINDING_ADAPTER_VERSION_V1,
        :prepared_not_executed, :terminal_deferred,
        :mapped_prepared_not_executed, :prepared_not_executed,
        :terminal_deferred, REF, DIGEST, PACKAGE_HASH, WIRE.sha256, INPUT,
        false, :contract_only, receipt_hash)
    @test receipt.input === INPUT
    @test receipt.candidate_digest == DIGEST
    @test receipt.source_package_hash == PACKAGE_HASH
    @test receipt.package_status === :prepared_not_executed
    @test receipt.package_resolution === :terminal_deferred
    @test receipt.accepted === false
    @test receipt.claim_ceiling === :contract_only
    @test receipt.receipt_hash != receipt.source_package_hash

    absent_hash = A._vnext_t1_package_binding_adapter_receipt_hash_v1(
        :terminal_deferred, :terminal_deferred, :g3_typed_absent,
        :prepared_not_executed, :terminal_deferred, REF, DIGEST,
        PACKAGE_HASH, WIRE.sha256)
    absent = A.VNextT1PackageBindingAdapterResultV1(
        A.VNEXT_T1_PACKAGE_BINDING_ADAPTER_DOMAIN_V1,
        A.VNEXT_T1_PACKAGE_BINDING_ADAPTER_SCHEMA_V1,
        A.VNEXT_T1_PACKAGE_BINDING_ADAPTER_VERSION_V1,
        :terminal_deferred, :terminal_deferred, :g3_typed_absent,
        :prepared_not_executed, :terminal_deferred, REF, DIGEST,
        PACKAGE_HASH, WIRE.sha256, nothing, false, :contract_only, absent_hash)
    @test absent.input === nothing
    @test absent.status === :terminal_deferred
    @test_throws ArgumentError A.VNextT1PackageBindingAdapterResultV1(
        absent.domain, absent.schema, absent.version, absent.status,
        absent.resolution, absent.reason, absent.package_status,
        absent.package_resolution, absent.candidate_ref, absent.candidate_digest,
        absent.source_package_hash, absent.wire_hash, INPUT, false,
        absent.claim_ceiling, absent.receipt_hash)
end

@testset "VNext T1 package binding adapter real package" begin
    package = _adapter_real_package()
    result = A.vnext_t1_package_binding_adapter_v1(package; wire=WIRE)
    @test result.status === :prepared_not_executed
    @test result.resolution === :terminal_deferred
    @test result.reason === :mapped_prepared_not_executed
    @test result.input isa A.VNextT1CandidateBindingInputV2
    @test result.input.candidate_ref == package.candidate_ref
    @test result.input.candidate_digest == package.semantic_identity
    @test result.input.source_package_hash == package.package_hash
    @test result.input.wire === WIRE
    @test result.accepted === false
    @test result.claim_ceiling === :contract_only

    stale_layers = A.CandidateStatePackageV5Next(
        package.candidate_ref, package.declarations, package.children,
        package.axes, package.feedback, package.source_hashes,
        package.declaration_hashes, package.layer_contracts,
        ntuple(i -> package.schema_hashes[mod1(i + 1, 3)], 3),
        package.canonicalization_hashes, package.profile_hashes,
        package.component_identity, package.component_count_receipt,
        package.semantic_identity, package.no_legacy_receipt, package.t0_gate,
        package.status, package.resolution, package.accepted,
        package.claim_ceiling, package.package_schema_version,
        package.package_schema_hash, package.package_canonicalization_version,
        package.package_canonicalization_hash, package.package_profile_version,
        package.package_profile_hash, package.package_hash)
    @test A.vnext_t1_package_binding_adapter_v1(stale_layers).status === :fail_closed

    stale_metadata = deepcopy(package)
    stale_metadata = A.CandidateStatePackageV5Next(
        stale_metadata.candidate_ref, stale_metadata.declarations,
        stale_metadata.children, stale_metadata.axes, stale_metadata.feedback,
        stale_metadata.source_hashes, stale_metadata.declaration_hashes,
        stale_metadata.layer_contracts, stale_metadata.schema_hashes,
        stale_metadata.canonicalization_hashes, stale_metadata.profile_hashes,
        stale_metadata.component_identity, stale_metadata.component_count_receipt,
        stale_metadata.semantic_identity, stale_metadata.no_legacy_receipt,
        stale_metadata.t0_gate, stale_metadata.status, stale_metadata.resolution,
        stale_metadata.accepted, stale_metadata.claim_ceiling, "stale-v1",
        stale_metadata.package_schema_hash, stale_metadata.package_canonicalization_version,
        stale_metadata.package_canonicalization_hash, stale_metadata.package_profile_version,
        stale_metadata.package_profile_hash, stale_metadata.package_hash)
    @test A.vnext_t1_package_binding_adapter_v1(stale_metadata).status === :fail_closed

    count = A.VNextT1ComponentCountReceiptV1((:G1, :G2, :G3),
        (:realization, :control, :binding), ("g2-thermal", "g1-residual"))
    stale_count = A.CandidateStatePackageV5Next(
        package.candidate_ref, package.declarations, package.children,
        package.axes, package.feedback, package.source_hashes,
        package.declaration_hashes, package.layer_contracts,
        package.schema_hashes, package.canonicalization_hashes,
        package.profile_hashes, package.component_identity, count,
        package.semantic_identity, package.no_legacy_receipt, package.t0_gate,
        package.status, package.resolution, package.accepted,
        package.claim_ceiling, package.package_schema_version,
        package.package_schema_hash, package.package_canonicalization_version,
        package.package_canonicalization_hash, package.package_profile_version,
        package.package_profile_hash, package.package_hash)
    @test A.vnext_t1_package_binding_adapter_v1(stale_count).status === :fail_closed

    bad_gate = A.VNextT1T0GateV1(package.t0_gate.prior_bundle,
        A.QualifiedRefV1("local://candidate/foreign-gate", "v5"),
        :local_checked_present, :resolved, false,
        :contract_only, package.t0_gate.output_projection,
        package.t0_gate.output_bytes, package.t0_gate.output_identity,
        package.t0_gate.output_hash)
    stale_gate = A.CandidateStatePackageV5Next(
        package.candidate_ref, package.declarations, package.children,
        package.axes, package.feedback, package.source_hashes,
        package.declaration_hashes, package.layer_contracts,
        package.schema_hashes, package.canonicalization_hashes,
        package.profile_hashes, package.component_identity,
        package.component_count_receipt, package.semantic_identity,
        package.no_legacy_receipt, bad_gate, package.status,
        package.resolution, package.accepted, package.claim_ceiling,
        package.package_schema_version, package.package_schema_hash,
        package.package_canonicalization_version,
        package.package_canonicalization_hash, package.package_profile_version,
        package.package_profile_hash, package.package_hash)
    @test A.vnext_t1_package_binding_adapter_v1(stale_gate).status === :fail_closed

    typed_absent = _adapter_real_package(g3_child_status=:typed_absent)
    deferred = A.vnext_t1_package_binding_adapter_v1(typed_absent; wire=WIRE)
    @test deferred.status === :terminal_deferred
    @test deferred.reason === :g3_typed_absent
    @test deferred.input === nothing
end

println("VNEXT_T1_PACKAGE_BINDING_ADAPTER_V1_REPLAY",
    " schema=", A.VNEXT_T1_PACKAGE_BINDING_ADAPTER_SCHEMA_V1,
    " status=", :prepared_not_executed,
    " resolution=", :terminal_deferred,
    " candidate_digest=", DIGEST.value,
    " source_package_hash=", PACKAGE_HASH.value,
    " wire_hash=", WIRE.sha256.value,
    " accepted=false")
