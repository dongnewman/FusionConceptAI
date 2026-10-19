using Test
using Serialization
using SHA
using FusionConceptAI

const _ROOT_V2 = joinpath(@__DIR__, "..", "..", "..", "..")
const G_V2 = FusionConceptAI

# The existing bridge fixture is an upstream producer fixture only.  It is
# included here to exercise the real T0 producer and G3 authority bridge.
Base.include(Main, joinpath(@__DIR__, "..", "vnext_g3_binding_authority_bridge_local_v1_tests.jl"))
Base.include(G_V2, joinpath(_ROOT_V2, "src", "Contracts", "VNextT1CanonicalBytesV2.jl"))
Base.include(G_V2, joinpath(_ROOT_V2, "src", "Contracts", "VNextT1CandidateBindingV2.jl"))
Base.include(G_V2, joinpath(_ROOT_V2, "src", "GenomeV5", "Integration", "VNextDeclarationAuthorityRecheckLocalV2.jl"))
Base.include(G_V2, joinpath(_ROOT_V2, "src", "Contracts", "CandidateStatePackageV5NextV2.jl"))
Base.include(G_V2, joinpath(_ROOT_V2, "src", "GenomeV5", "Integration", "VNextGenomeV5IntegrationV2.jl"))
Base.include(G_V2, joinpath(_ROOT_V2, "src", "Contracts", "VNextT1PackageBindingAdapterV2.jl"))

function _v2_chain_fixture()
    g1 = Main._t0l_g1(); g2 = Main._t0l_g2(); g3 = Main._t0l_g3()
    declarations = (Main._t0l_present(:G1, g1),
        Main._t0l_present(:G2, g2; path="src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl"),
        Main._t0l_present(:G3, g3; path="src/GenomeV5/G3/G3SourceFeedbackLawV1.jl"))
    children = (Main._t0l_child(:realization), Main._t0l_child(:control), Main._t0l_child(:binding))
    feedback = (Main._t0l_feedback("g1-residual", declarations[1].declaration_ref),
        Main._t0l_feedback("g2-thermal", declarations[2].declaration_ref))
    transport_admission = G_V2.vnext_declaration_transport_local_v1(Main._T0L_CANDIDATE,
        declarations, children, feedback)
    transport_admission.status === :valid || error("T0 producer fixture invalid")
    t = transport_admission.transport
    recheck = G_V2.vnext_declaration_authority_recheck_local_v2(
        G_V2.VNextAuthorityRecheckLocalV2Input(Main._T0L_CANDIDATE, t))
    recheck.status === :local_checked_present || error("V2 recheck fixture invalid")
    # The bridge only needs the checked declaration projection; build its
    # documented producer-shaped view directly from the V2 recheck output.
    g3_record = declarations[3]
    rs = Main._realization_state(g3_record); cs = Main._control_state(g3_record)
    ri, re = G_V2._vnext_g3_state_info(rs, :realization, Main._T0L_CANDIDATE,
        g3_record.declaration_ref, g3_record.declaration_identity_hash); re === nothing || error(re)
    ci, ce = G_V2._vnext_g3_state_info(cs, :control, Main._T0L_CANDIDATE,
        g3_record.declaration_ref, g3_record.declaration_identity_hash); ce === nothing || error(ce)
    rcommit = G_V2.VNextG3BindingChildExpectedCommitmentV1(ri.child_kind, ri.candidate_ref,
        ri.parent_g3_declaration_ref, ri.parent_g3_declaration_hash, ri.child_ref,
        ri.contract_ref, ri.source_record_ref, ri.source_record_hash,
        ri.source_content_hash, ri.child_identity_hash, ri.state_hash)
    ccommit = G_V2.VNextG3BindingChildExpectedCommitmentV1(ci.child_kind, ci.candidate_ref,
        ci.parent_g3_declaration_ref, ci.parent_g3_declaration_hash, ci.child_ref,
        ci.contract_ref, ci.source_record_ref, ci.source_record_hash,
        ci.source_content_hash, ci.child_identity_hash, ci.state_hash)
    expected = G_V2.vnext_g3_binding_expected_commitment_v1(Main._T0L_CANDIDATE,
        recheck.prior_bundle_sha256, g3_record.declaration_ref, g3_record.declaration_identity_hash,
        rcommit, ccommit)
    key = G_V2.G3BindingChildKeyV2(Main._T0L_CANDIDATE, g3_record.declaration_ref,
        g3_record.declaration_identity_hash, :binding, "binding-child-v2")
    a1 = G_V2.G3SFAuthorityV1(:G1, Main._T0L_CANDIDATE, nothing, nothing, :missing)
    a2 = G_V2.G3SFAuthorityV1(:G2, Main._T0L_CANDIDATE, nothing, nothing, :missing)
    l1 = G_V2.G3BindingLinkV1("g1", :G1, "/g1", :residual, Main.UNIT, :in, 1, "local-g3", "local-owner", a1)
    l2 = G_V2.G3BindingLinkV1("g2", :G2, "/g2", :thermal_load, Main.UNIT, :in, 1, "local-g3", "local-owner", a2)
    bridge = G_V2.vnext_g3_binding_authority_bridge_local_v1(recheck_to_v1(recheck, t, declarations, g3_record),
        expected, rs, cs, key; initial_links=(l1, l2))
    bridge.status === :local_checked_present || error("G3 bridge fixture invalid")
    authority = (status=bridge.status, resolution=bridge.resolution,
        authority_verified=bridge.authority_verified, binding_state=bridge.binding_state,
        commitment_hash=expected.commitment_hash, expected_commitment=expected)
    parents = (G_V2.vnext_t1_parent_commitment_v2(Main._T0L_CANDIDATE, t.declarations[1]),
        G_V2.vnext_t1_parent_commitment_v2(Main._T0L_CANDIDATE, t.declarations[2]))
    input = G_V2.VNextT1AdmissionInputV2(Main._T0L_CANDIDATE, t, recheck, parents,
        expected.commitment_hash, authority)
    (transport=t, recheck=recheck, expected=expected, authority=authority,
        input=input, admission=G_V2.vnext_t1_admit_v2(input))
end

"""Convert the V2 checked result to the bridge's documented V1 result shape.
The bridge is a producer; this wrapper does not invoke a legacy T1 path."""
function recheck_to_v1(x, t, declarations, g3_record)
    out = x.output
    o = (candidate_ref=t.candidate_ref, bundle_hash=t.bundle_hash,
        g1=declarations[1], g2=declarations[2], g3=g3_record,
        children=t.children, feedback=t.feedback)
    (; status=x.status, resolution=x.resolution, accepted=x.accepted,
        claim_ceiling=x.claim_ceiling, errors=x.errors, reasons=x.reasons,
        output=o, prior_bundle_sha256=x.prior_bundle_sha256)
end

const _V2_FIXTURE = _v2_chain_fixture()

@testset "V2 same-chain producer to reload adapter" begin
    fixture = _V2_FIXTURE
    input = fixture.input
    admission = fixture.admission
    @test admission.status === :prepared_not_executed
    @test admission.resolution === :terminal_deferred
    @test admission.package isa G_V2.CandidateStatePackageV5NextV2
    @test admission.package.g3_authority.authority_verified
    @test !isempty(G_V2.copy_bytes(admission.package.wire))
    @test admission.package.wire.sha256 == G_V2._vnext_ar_v2_sha(
        G_V2.copy_bytes(admission.package.wire))
    semantic_manifest = G_V2._vnext_t1_v2_identity_manifest(
        admission.package.candidate_ref, admission.package.bundle_hash,
        admission.package.declarations, admission.package.children,
        admission.package.feedback, admission.package.axes,
        admission.package.parent_commitments, admission.package.g3_authority,
        admission.package.wire)
    package_manifest = G_V2._vnext_t1_v2_package_manifest(admission.package)
    @test semantic_manifest.wire_sha256 == admission.package.wire.sha256
    @test semantic_manifest.wire_byte_length == length(G_V2.copy_bytes(admission.package.wire))
    @test package_manifest.wire_sha256 == admission.package.wire.sha256
    @test package_manifest.wire_byte_length == length(G_V2.copy_bytes(admission.package.wire))
    @test G_V2.vnext_t1_package_v2_validate(admission.package) === nothing
    @test admission.package.status === :prepared_not_executed
    @test admission.package.resolution === :terminal_deferred
    @test admission.package.accepted === false
    @test admission.package.claim_ceiling === :contract_only
    @test admission.package.children[1].status in (:typed_absent, :terminal_deferred)
    @test admission.package.children[2].status in (:typed_absent, :terminal_deferred)
    @test admission.package.children[3].status in (:typed_absent, :terminal_deferred)
    io = IOBuffer()
    Serialization.serialize(io, admission.package)
    serialized_bytes = take!(io)
    reloaded = Serialization.deserialize(IOBuffer(serialized_bytes))
    @test reloaded isa G_V2.CandidateStatePackageV5NextV2
    observed = G_V2.vnext_t1_package_binding_adapter_v2(reloaded)
    @test observed.status === :prepared_not_executed
    @test observed.input !== nothing
    binding = G_V2.vnext_t1_candidate_binding_v2(observed.input, (observed.input,))
    @test binding.status === :bound
    @test binding.reason === :exact_explicit_binding
    observed2 = G_V2.vnext_t1_package_binding_adapter_v2(reloaded, (observed.input,))
    @test observed2.binding.status === :bound
    @test admission.package.semantic_identity == reloaded.semantic_identity
    @test admission.package.package_hash == reloaded.package_hash
    @test admission.trace == (:t0_transport, :v2_recheck, :parent_authority, :g3_authority, :package)
    println("V2_CHAIN_STATUS=PASS")
    println("V2_CHAIN_TRACE=", admission.trace)
    println("V2_CHAIN_SEMANTIC_ID=", reloaded.semantic_identity.value)
    println("V2_CHAIN_PACKAGE_HASH=", reloaded.package_hash.value)
    println("V2_CHAIN_SERIALIZED_BYTES=", length(serialized_bytes))
    artifact_dir = joinpath(_ROOT_V2, "docs", "implementation", "UP1-04A-VNEXT-T1", "agent_local_r11_wire_bound_package")
    isdir(artifact_dir) || mkpath(artifact_dir)
    open(joinpath(artifact_dir, "candidate_state_package_v5_next_v2_r11.serialized"), "w") do io
        write(io, serialized_bytes)
    end
end

function _v2_rebuild_transport(t; candidate=t.candidate_ref,
        declarations=t.declarations, children=t.children, feedback=t.feedback,
        bundle_hash=nothing, status=t.status, errors=t.errors, gaps=t.gaps)
    body = (schema_id=G_V2.VNEXT_T0_LOCAL_SCHEMA_ID_V1,
        schema_version=G_V2.VNEXT_T0_LOCAL_SCHEMA_VERSION_V1, candidate_ref=candidate,
        declarations=Tuple(declarations), children=Tuple(children),
        feedback=Tuple(sort!(collect(feedback), by=x -> x.target_id)))
    h = bundle_hash === nothing ? G_V2.canonical_hash(body) : bundle_hash
    G_V2.VNextT0LocalTransportV1(candidate, Tuple(declarations), Tuple(children),
        Tuple(feedback), h, status, errors, gaps)
end

function _v2_record_with(d::G_V2.VNextT0LocalPresentDeclarationV1;
        source_bytes=d.source_bytes, declaration_bytes=d.declaration_bytes,
        semantic_body=d.semantic_body, factory_receipt=d.factory_receipt,
        declaration_receipt=d.declaration_receipt, source_locator=d.source_locator,
        source_identity_hash=d.source_identity_hash,
        declaration_identity_hash=d.declaration_identity_hash)
    G_V2.VNextT0LocalPresentDeclarationV1(d.layer, d.candidate_ref, d.source_ref,
        d.declaration_ref, source_identity_hash, declaration_identity_hash, d.axes,
        source_bytes, declaration_bytes, semantic_body, source_locator,
        factory_receipt, declaration_receipt)
end

_v2_flip(bytes) = isempty(bytes) ? UInt8[0x01] : vcat(UInt8[bytes[1] ⊻ 0x01], bytes[2:end])
_v2_digest(bytes) = G_V2.Digest256(bytes2hex(SHA.sha256(copy(Vector{UInt8}(bytes)))))
_v2_zero_digest() = G_V2.Digest256(repeat("0", 64))

function _v2_unsafe_receipt_with_bytes(x, bytes)
    vals = Any[bytes, x.candidate_ref, x.layer, x.source_ref, x.declaration_ref,
        x.axes, x.factory_axes, x.status, x.factory_api, x.factory_result,
        x.factory_result_hash]
    ccall(:jl_new_struct, Any,
        (Any, Any, Any, Any, Any, Any, Any, Any, Any, Any, Any, Any),
        typeof(x), vals[1], vals[2], vals[3], vals[4], vals[5], vals[6],
        vals[7], vals[8], vals[9], vals[10], vals[11])
end

function _v2_recheck_negative(name, transport, expected)
    before_json = G_V2.canonical_json(transport)
    before_hash = transport.bundle_hash
    result = G_V2.vnext_declaration_authority_recheck_local_v2(
        G_V2.VNextAuthorityRecheckLocalV2Input(transport.candidate_ref, transport))
    @test result.status === :fail_closed
    @test result.resolution === :none
    @test result.accepted === false
    @test result.output === nothing
    @test first(result.errors) === expected
    @test G_V2.canonical_json(transport) == before_json
    @test transport.bundle_hash == before_hash
    println("V2_NEGATIVE_FIRST_ERROR[", name, "] = ", first(result.errors))
    result
end

function _v2_package_with(p; kwargs...)
    vals = (schema_id=get(kwargs, :schema_id, p.schema_id),
        schema_version=get(kwargs, :schema_version, p.schema_version),
        canonicalization_version=get(kwargs, :canonicalization_version, p.canonicalization_version),
        profile_version=get(kwargs, :profile_version, p.profile_version),
        candidate_ref=get(kwargs, :candidate_ref, p.candidate_ref),
        bundle_hash=get(kwargs, :bundle_hash, p.bundle_hash),
        declarations=get(kwargs, :declarations, p.declarations), children=get(kwargs, :children, p.children),
        feedback=get(kwargs, :feedback, p.feedback), axes=get(kwargs, :axes, p.axes),
        parent_commitments=get(kwargs, :parent_commitments, p.parent_commitments),
        g3_authority=get(kwargs, :g3_authority, p.g3_authority), wire=get(kwargs, :wire, p.wire),
        semantic_identity=get(kwargs, :semantic_identity, p.semantic_identity),
        package_hash=get(kwargs, :package_hash, p.package_hash), status=get(kwargs, :status, p.status),
        resolution=get(kwargs, :resolution, p.resolution), accepted=get(kwargs, :accepted, p.accepted),
        claim_ceiling=get(kwargs, :claim_ceiling, p.claim_ceiling))
    G_V2.CandidateStatePackageV5NextV2(vals...)
end

function _v2_state_with_hash(state, hash)
    vals = Any[state.source_payload, state.editable_body, state.state_status,
        state.absence_reason, state.absence_digest, state.contract_admission,
        state.physical_resolution, state.source_record_hash, state.source_content_hash,
        state.binding_child_identity_hash, state.initial_body_hash,
        state.initial_source_state_hash, state.body_hash, state.operation_hash,
        hash, state.operation_history]
    ccall(:jl_new_struct, Any,
        (Any, Any, Any, Any, Any, Any, Any, Any, Any, Any, Any, Any, Any, Any, Any, Any, Any),
        typeof(state), vals[1], vals[2], vals[3], vals[4], vals[5], vals[6],
        vals[7], vals[8], vals[9], vals[10], vals[11], vals[12], vals[13],
        vals[14], vals[15], vals[16])
end

function _v2_child_with_hash(child, hash)
    vals = Any[child.child_kind, child.candidate_ref, child.parent_g3_declaration_ref,
        child.parent_g3_declaration_hash, child.child_ref, child.contract_ref,
        child.source_record_ref, child.source_record_hash, child.source_content_hash,
        child.child_identity_hash, hash]
    ccall(:jl_new_struct, Any,
        (Any, Any, Any, Any, Any, Any, Any, Any, Any, Any, Any, Any),
        typeof(child), vals[1], vals[2], vals[3], vals[4], vals[5], vals[6],
        vals[7], vals[8], vals[9], vals[10], vals[11])
end

function _v2_payload_with_slots(payload, realization_slot, control_slot)
    vals = Any[payload.key, payload.child_contract_ref, payload.source_uri,
        payload.source_version, payload.source_record, payload.immutable_binding_schema,
        payload.initial_links, realization_slot, control_slot, payload.source_content_hash]
    ccall(:jl_new_struct, Any,
        (Any, Any, Any, Any, Any, Any, Any, Any, Any, Any, Any),
        typeof(payload), vals[1], vals[2], vals[3], vals[4], vals[5], vals[6],
        vals[7], vals[8], vals[9], vals[10])
end

function _v2_state_with_payload(state, payload)
    vals = Any[payload, state.editable_body, state.state_status, state.absence_reason,
        state.absence_digest, state.contract_admission, state.physical_resolution,
        state.source_record_hash, state.source_content_hash,
        state.binding_child_identity_hash, state.initial_body_hash,
        state.initial_source_state_hash, state.body_hash, state.operation_hash,
        state.state_hash, state.operation_history]
    ccall(:jl_new_struct, Any,
        (Any, Any, Any, Any, Any, Any, Any, Any, Any, Any, Any, Any, Any, Any, Any, Any, Any),
        typeof(state), vals[1], vals[2], vals[3], vals[4], vals[5], vals[6],
        vals[7], vals[8], vals[9], vals[10], vals[11], vals[12], vals[13],
        vals[14], vals[15], vals[16])
end

function _v2_state_with_key(state, key)
    body = G_V2.G3BindingEditableBodyV2(key, state.editable_body.links)
    vals = Any[state.source_payload, body, state.state_status, state.absence_reason,
        state.absence_digest, state.contract_admission, state.physical_resolution,
        state.source_record_hash, state.source_content_hash,
        state.binding_child_identity_hash, state.initial_body_hash,
        state.initial_source_state_hash, state.body_hash, state.operation_hash,
        state.state_hash, state.operation_history]
    ccall(:jl_new_struct, Any,
        (Any, Any, Any, Any, Any, Any, Any, Any, Any, Any, Any, Any, Any, Any, Any, Any, Any),
        typeof(state), vals[1], vals[2], vals[3], vals[4], vals[5], vals[6],
        vals[7], vals[8], vals[9], vals[10], vals[11], vals[12], vals[13],
        vals[14], vals[15], vals[16])
end

function _v2_g3_shape_negative(name, authority, expected)
    f = _V2_FIXTURE; i = f.input
    result = G_V2.vnext_t1_admit_v2(G_V2.VNextT1AdmissionInputV2(
        i.candidate_ref, i.transport, i.t0_recheck, i.parent_commitments,
        i.g3_expected_commitment, authority))
    @test result.status === :fail_closed
    @test result.errors == (expected,)
    @test result.package === nothing
    @test result.accepted === false
    println("V2_R9_SHAPE_FIRST_ERROR[", name, "] = ", first(result.errors))
    result
end

@testset "R11b wire-bound package guards and identity witness boundary" begin
    p = _V2_FIXTURE.admission.package
    before_io = IOBuffer(); Serialization.serialize(before_io, p); before = take!(before_io)

    empty_wire = G_V2.VNextT1CanonicalBytesV2(UInt8[])
    r_empty = G_V2.vnext_t1_package_binding_adapter_v2(_v2_package_with(p; wire=empty_wire))
    @test r_empty.reason === :wire_empty
    @test r_empty.input === nothing
    @test r_empty.binding === nothing

    zero_wire = ccall(:jl_new_struct, Any, (Any, Any, Any, Any),
        G_V2.VNextT1CanonicalBytesV2, p.wire.raw, _v2_zero_digest(), p.wire.encoding)
    r_zero = G_V2.vnext_t1_package_binding_adapter_v2(_v2_package_with(p; wire=zero_wire))
    @test r_zero.reason === :wire_hash_zero
    @test r_zero.input === nothing
    @test r_zero.binding === nothing

    foreign_wire = G_V2.VNextT1CanonicalBytesV2(vcat(G_V2.copy_bytes(p.wire), UInt8[0x7f]))
    r_foreign = G_V2.vnext_t1_package_binding_adapter_v2(_v2_package_with(p; wire=foreign_wire))
    @test r_foreign.reason === :semantic_identity_mismatch
    @test r_foreign.input === nothing
    @test r_foreign.binding === nothing

    foreign_semantic = G_V2._vnext_t1_v2_manifest_digest(G_V2._vnext_t1_v2_identity_manifest(
        p.candidate_ref, p.bundle_hash, p.declarations, p.children, p.feedback, p.axes,
        p.parent_commitments, p.g3_authority, foreign_wire))
    foreign_pending = _v2_package_with(p; wire=foreign_wire, semantic_identity=foreign_semantic,
        package_hash=G_V2.digest256_text("pending-r11b-foreign"))
    foreign_package_hash = G_V2.vnext_t1_package_v2_manifest_hash(foreign_pending)
    fully_recomputed = _v2_package_with(foreign_pending; package_hash=foreign_package_hash)
    @test foreign_semantic != p.semantic_identity
    @test foreign_package_hash != p.package_hash
    @test G_V2.vnext_t1_package_v2_validate(fully_recomputed) === nothing
    @test G_V2.vnext_t1_package_binding_adapter_v2(fully_recomputed).input !== nothing
    println("R11B_FULL_RECOMPUTE_IS_NEW_IDENTITY=PASS")

    @test G_V2.vnext_t1_package_v2_validate(_v2_package_with(p;
        canonicalization_version="digest-manifest-v2")) === :canonicalization_version_mismatch
    @test G_V2.vnext_t1_package_v2_validate(_v2_package_with(p;
        profile_version="closed-no-legacy-digest-manifest-v2")) === :profile_version_mismatch
    for (field, value, reason) in ((:status, :terminal_deferred, :status_conflict),
            (:resolution, :resolved, :resolution_conflict),
            (:accepted, true, :accepted_conflict),
            (:claim_ceiling, :screen_only, :claim_ceiling_conflict))
        bad = field === :status ? _v2_package_with(p; status=value) :
            field === :resolution ? _v2_package_with(p; resolution=value) :
            field === :accepted ? _v2_package_with(p; accepted=value) :
            _v2_package_with(p; claim_ceiling=value)
        result = G_V2.vnext_t1_package_binding_adapter_v2(bad)
        @test result.reason === reason
        @test result.input === nothing
        @test result.binding === nothing
    end
    after_io = IOBuffer(); Serialization.serialize(after_io, p)
    @test take!(after_io) == before
    println("R11B_WIRE_NEGATIVE_CASES=9")
end

@testset "V2 fail-closed gates" begin
    f = _V2_FIXTURE; i = f.input; p = f.admission.package
    missing = G_V2.VNextT1AdmissionInputV2(i.candidate_ref, i.transport, nothing,
        i.parent_commitments, i.g3_expected_commitment, i.g3_authority)
    @test G_V2.vnext_t1_admit_v2(missing).gaps == (:t0_recheck_required,)
    foreign = G_V2.QualifiedRefV1("local://foreign", "v5")
    @test G_V2.vnext_t1_admit_v2(G_V2.VNextT1AdmissionInputV2(foreign, i.transport,
        i.t0_recheck, i.parent_commitments, i.g3_expected_commitment, i.g3_authority)).errors == (:foreign_candidate,)
    stale_parent = (G_V2.digest256_text("stale-parent"), i.parent_commitments[2])
    @test G_V2.vnext_t1_admit_v2(G_V2.VNextT1AdmissionInputV2(i.candidate_ref, i.transport,
        i.t0_recheck, stale_parent, i.g3_expected_commitment, i.g3_authority)).errors == (:parent_commitment_mismatch,)
    stale_g3 = G_V2.VNextT1AdmissionInputV2(i.candidate_ref, i.transport, i.t0_recheck,
        i.parent_commitments, G_V2.digest256_text("stale-g3"), i.g3_authority)
    @test G_V2.vnext_t1_admit_v2(stale_g3).errors == (:g3_expected_commitment_stale,)
    duplicate_input = G_V2.VNextT1CandidateBindingInputV2(p.candidate_ref,
        p.semantic_identity, p.package_hash, p.wire)
    duplicate_result = G_V2.vnext_t1_package_binding_adapter_v2(p,
        (duplicate_input, duplicate_input))
    @test duplicate_result.reason === :duplicate_conflict
    bad_package = G_V2.CandidateStatePackageV5NextV2(p.schema_id, p.schema_version,
        p.canonicalization_version, p.profile_version, p.candidate_ref, p.bundle_hash,
        p.declarations, p.children, p.feedback, p.axes, p.parent_commitments,
        p.g3_authority, p.wire, p.semantic_identity, G_V2.digest256_text("package-hash-tamper"), p.status,
        p.resolution, p.accepted, p.claim_ceiling)
    @test G_V2.vnext_t1_package_binding_adapter_v2(bad_package).reason === :package_hash_mismatch
    typed = merge(f.authority, (status=:typed_absent, resolution=:terminal_deferred,
        authority_verified=false, binding_state=nothing))
    typed_input = G_V2.VNextT1AdmissionInputV2(i.candidate_ref, i.transport, i.t0_recheck,
        i.parent_commitments, i.g3_expected_commitment, typed)
    @test G_V2.vnext_t1_admit_v2(typed_input).gaps == (:g3_typed_absent,)
    println("V2_NEGATIVE_CASES=PASS")
end

@testset "V2 R7 carrier byte/hash negative matrix" begin
    f = _V2_FIXTURE
    d = f.transport.declarations[1]
    fields = (
        (:source, d.source_bytes, :source_bytes_hash_mismatch, :source_locator_hash_mismatch,
            :source_locator_hash_mismatch,
            b -> _v2_record_with(d; source_bytes=b)),
        (:declaration, d.declaration_bytes, :declaration_bytes_hash_mismatch, :declaration_identity_hash_mismatch,
            :declaration_identity_hash_mismatch,
            b -> _v2_record_with(d; declaration_bytes=b)),
        (:semantic, d.semantic_body.bytes, :semantic_body_bytes_identity_mismatch, :semantic_body_hash_mismatch,
            :semantic_body_bytes_identity_mismatch,
            b -> _v2_record_with(d; semantic_body=G_V2.VNextT0LocalSemanticBodyV1(
                d.semantic_body.body, b, d.semantic_body.labels))),
        (:factory_receipt, d.factory_receipt.bytes, :factory_receipt_bytes_identity_mismatch,
            :factory_receipt_bytes_hash_mismatch, :factory_receipt_bytes_identity_mismatch,
            b -> _v2_record_with(d; factory_receipt=_v2_unsafe_receipt_with_bytes(
                d.factory_receipt, b))),
        (:declaration_receipt, d.declaration_receipt.bytes, :declaration_receipt_bytes_identity_mismatch,
            :declaration_receipt_bytes_hash_mismatch, :declaration_receipt_bytes_identity_mismatch,
            b -> _v2_record_with(d; declaration_receipt=_v2_unsafe_receipt_with_bytes(
                d.declaration_receipt, b))) )
    for (label, original, expected_bytes, expected_hash, expected_recomputed, rebuild) in fields
        old_claim = G_V2.VNextT0LocalBytesV1(_v2_flip(original.bytes), original.sha256)
        old_claim_t = _v2_rebuild_transport(f.transport;
            declarations=(_v2_record_with(d;
                source_bytes=label === :source ? old_claim : d.source_bytes,
                declaration_bytes=label === :declaration ? old_claim : d.declaration_bytes,
                semantic_body=label === :semantic ? G_V2.VNextT0LocalSemanticBodyV1(
                    d.semantic_body.body, old_claim, d.semantic_body.labels) : d.semantic_body,
                factory_receipt=label === :factory_receipt ? _v2_unsafe_receipt_with_bytes(d.factory_receipt, old_claim) : d.factory_receipt,
                declaration_receipt=label === :declaration_receipt ? _v2_unsafe_receipt_with_bytes(d.declaration_receipt, old_claim) : d.declaration_receipt),
                f.transport.declarations[2], f.transport.declarations[3]))
        _v2_recheck_negative(string(label, "_bytes_only"), old_claim_t, expected_bytes)

        bad_claim = G_V2.VNextT0LocalBytesV1(original.bytes, G_V2.digest256_text(string(label, "-hash-only")))
        bad_claim_t = _v2_rebuild_transport(f.transport;
            declarations=(_v2_record_with(d;
                source_bytes=label === :source ? bad_claim : d.source_bytes,
                declaration_bytes=label === :declaration ? bad_claim : d.declaration_bytes,
                semantic_body=label === :semantic ? G_V2.VNextT0LocalSemanticBodyV1(
                    d.semantic_body.body, bad_claim, d.semantic_body.labels) : d.semantic_body,
                factory_receipt=label === :factory_receipt ? _v2_unsafe_receipt_with_bytes(d.factory_receipt, bad_claim) : d.factory_receipt,
                declaration_receipt=label === :declaration_receipt ? _v2_unsafe_receipt_with_bytes(d.declaration_receipt, bad_claim) : d.declaration_receipt),
                f.transport.declarations[2], f.transport.declarations[3]))
        _v2_recheck_negative(string(label, "_hash_only"), bad_claim_t, expected_hash)

        new_bytes = _v2_flip(original.bytes)
        new_claim = G_V2.VNextT0LocalBytesV1(new_bytes, _v2_digest(new_bytes))
        recomputed_t = _v2_rebuild_transport(f.transport;
            declarations=(_v2_record_with(d;
                source_bytes=label === :source ? new_claim : d.source_bytes,
                declaration_bytes=label === :declaration ? new_claim : d.declaration_bytes,
                semantic_body=label === :semantic ? G_V2.VNextT0LocalSemanticBodyV1(
                    d.semantic_body.body, new_claim, d.semantic_body.labels) : d.semantic_body,
                factory_receipt=label === :factory_receipt ? _v2_unsafe_receipt_with_bytes(d.factory_receipt, new_claim) : d.factory_receipt,
                declaration_receipt=label === :declaration_receipt ? _v2_unsafe_receipt_with_bytes(d.declaration_receipt, new_claim) : d.declaration_receipt),
                f.transport.declarations[2], f.transport.declarations[3]))
        _v2_recheck_negative(string(label, "_bytes_recomputed_hash"), recomputed_t, expected_recomputed)
    end

    zero_bytes = G_V2.VNextT0LocalBytesV1(UInt8[], d.source_bytes.sha256)
    zero_t = _v2_rebuild_transport(f.transport;
        declarations=(_v2_record_with(d; source_bytes=zero_bytes),
            f.transport.declarations[2], f.transport.declarations[3]))
    _v2_recheck_negative("source_zero_bytes", zero_t, :source_size_mismatch)
    zero_hash = G_V2.VNextT0LocalBytesV1(d.source_bytes.bytes, _v2_zero_digest())
    zero_hash_t = _v2_rebuild_transport(f.transport;
        declarations=(_v2_record_with(d; source_bytes=zero_hash),
            f.transport.declarations[2], f.transport.declarations[3]))
    _v2_recheck_negative("source_all_zero_hash", zero_hash_t, :source_locator_hash_mismatch)
    println("V2_R7_CARRIER_MATRIX=15_CASES_EXECUTED")
end

@testset "V2 R7 transport duplicate and stale authority negatives" begin
    f = _V2_FIXTURE; i = f.input; t = f.transport; p = f.admission.package
    duplicate_feedback = _v2_rebuild_transport(t; feedback=(t.feedback[1], t.feedback[1]))
    _v2_recheck_negative("duplicate_feedback", duplicate_feedback, :duplicate_feedback)
    @test !hasfield(typeof(t), :observation)
    @test G_V2.VNextT0LocalFeedbackV1 isa DataType
    println("V2_OBSERVATION_NOT_APPLICABLE=VNextT0LocalFeedbackV1_is_the_only_feedback_type")

    stale_bundle = G_V2.VNextT0LocalTransportV1(t.candidate_ref, t.declarations,
        t.children, t.feedback, G_V2.digest256_text("stale-t0-bundle"), t.status, t.errors, t.gaps)
    _v2_recheck_negative("stale_t0_bundle", stale_bundle, :bundle_hash_mismatch)
    stale_recheck_input = G_V2.VNextT1AdmissionInputV2(i.candidate_ref, stale_bundle,
        i.t0_recheck, i.parent_commitments, i.g3_expected_commitment, i.g3_authority)
    stale_recheck = G_V2.vnext_t1_admit_v2(stale_recheck_input)
    @test stale_recheck.status === :fail_closed
    @test stale_recheck.errors == (:t0_bundle_recheck_mismatch,)
    @test stale_recheck.package === nothing

    stale_parent = (G_V2.digest256_text("r7-stale-parent"), i.parent_commitments[2])
    stale_parent_result = G_V2.vnext_t1_admit_v2(G_V2.VNextT1AdmissionInputV2(
        i.candidate_ref, t, i.t0_recheck, stale_parent, i.g3_expected_commitment, i.g3_authority))
    @test stale_parent_result.status === :fail_closed
    @test stale_parent_result.errors == (:parent_commitment_mismatch,)
    stale_g3 = G_V2.vnext_t1_admit_v2(G_V2.VNextT1AdmissionInputV2(i.candidate_ref,
        t, i.t0_recheck, i.parent_commitments, G_V2.digest256_text("r7-stale-g3"), i.g3_authority))
    @test stale_g3.status === :fail_closed
    @test stale_g3.errors == (:g3_expected_commitment_stale,)

    state0 = i.g3_authority.binding_state
    stale_payload = _v2_payload_with_slots(state0.source_payload,
        _v2_child_with_hash(state0.source_payload.realization_slot,
            G_V2.digest256_text("r7-stale-state")), state0.source_payload.control_slot)
    stale_state = merge(i.g3_authority, (binding_state=_v2_state_with_payload(
        state0, stale_payload),))
    stale_state_result = G_V2.vnext_t1_admit_v2(G_V2.VNextT1AdmissionInputV2(
        i.candidate_ref, t, i.t0_recheck, i.parent_commitments,
        i.g3_expected_commitment, stale_state))
    @test stale_state_result.status === :fail_closed
    @test stale_state_result.package === nothing
    @test first(stale_state_result.errors) === :g3_state_hash_mismatch

    original_key = i.g3_authority.binding_state.editable_body.key
    bad_key = G_V2.G3BindingChildKeyV2(i.candidate_ref,
        G_V2.QualifiedRefV1("local://stale-parent", "v1"),
        original_key.parent_g3_declaration_hash, :binding, "stale-key")
    stale_key = merge(i.g3_authority, (binding_state=_v2_state_with_key(
        i.g3_authority.binding_state, bad_key),))
    stale_key_result = G_V2.vnext_t1_admit_v2(G_V2.VNextT1AdmissionInputV2(
        i.candidate_ref, t, i.t0_recheck, i.parent_commitments,
        i.g3_expected_commitment, stale_key))
    @test stale_key_result.status === :fail_closed
    @test stale_key_result.package === nothing
    @test first(stale_key_result.errors) === :g3_key_parent_ref_mismatch
    println("V2_R7_STALE_AUTHORITY_CASES_EXECUTED")
end

@testset "V2 R9 G3 authority shape guards" begin
    f = _V2_FIXTURE; a = f.authority; state = a.binding_state
    missing_expected = (status=a.status, resolution=a.resolution,
        authority_verified=a.authority_verified, binding_state=state)
    _v2_g3_shape_negative("expected_commitment_missing", missing_expected,
        :g3_expected_commitment_missing)

    expected_no_realization = (commitment_hash=a.expected_commitment.commitment_hash,
        candidate_ref=a.expected_commitment.candidate_ref,
        bundle_hash=a.expected_commitment.bundle_hash,
        g3_declaration_ref=a.expected_commitment.g3_declaration_ref,
        g3_declaration_identity_hash=a.expected_commitment.g3_declaration_identity_hash,
        control=a.expected_commitment.control)
    _v2_g3_shape_negative("expected_realization_missing",
        merge(a, (expected_commitment=expected_no_realization,)),
        :g3_expected_realization_missing)

    _v2_g3_shape_negative("binding_state_missing",
        merge(a, (binding_state=nothing,)), :g3_binding_state_missing)
    state_no_hash = (editable_body=state.editable_body, source_payload=state.source_payload)
    _v2_g3_shape_negative("state_hash_missing",
        merge(a, (binding_state=state_no_hash,)), :g3_state_hash_missing)
    state_no_editable = (state_hash=state.state_hash, source_payload=state.source_payload)
    _v2_g3_shape_negative("editable_body_missing",
        merge(a, (binding_state=state_no_editable,)), :g3_editable_body_missing)
    editable_no_key = (links=state.editable_body.links,)
    state_no_key = (state_hash=state.state_hash, editable_body=editable_no_key,
        source_payload=state.source_payload)
    _v2_g3_shape_negative("key_missing",
        merge(a, (binding_state=state_no_key,)), :g3_key_missing)
    state_no_payload = (state_hash=state.state_hash, editable_body=state.editable_body)
    _v2_g3_shape_negative("source_payload_missing",
        merge(a, (binding_state=state_no_payload,)), :g3_source_payload_missing)
    payload_no_realization = (control_slot=state.source_payload.control_slot,)
    state_no_realization = (state_hash=state.state_hash, editable_body=state.editable_body,
        source_payload=payload_no_realization)
    _v2_g3_shape_negative("realization_slot_missing",
        merge(a, (binding_state=state_no_realization,)), :g3_realization_slot_missing)
    payload_no_control = (realization_slot=state.source_payload.realization_slot,)
    state_no_control = (state_hash=state.state_hash, editable_body=state.editable_body,
        source_payload=payload_no_control)
    _v2_g3_shape_negative("control_slot_missing",
        merge(a, (binding_state=state_no_control,)), :g3_control_slot_missing)
    bad_realization_slot = (not_state_hash=true,)
    payload_bad_realization = (realization_slot=bad_realization_slot,
        control_slot=state.source_payload.control_slot)
    state_bad_realization = (state_hash=state.state_hash, editable_body=state.editable_body,
        source_payload=payload_bad_realization)
    _v2_g3_shape_negative("realization_state_hash_missing",
        merge(a, (binding_state=state_bad_realization,)),
        :g3_realization_state_hash_missing)
    bad_control_slot = (not_state_hash=true,)
    payload_bad_control = (realization_slot=state.source_payload.realization_slot,
        control_slot=bad_control_slot)
    state_bad_control = (state_hash=state.state_hash, editable_body=state.editable_body,
        source_payload=payload_bad_control)
    _v2_g3_shape_negative("control_state_hash_missing",
        merge(a, (binding_state=state_bad_control,)),
        :g3_control_state_hash_missing)
    println("V2_R9_G3_SHAPE_GUARDS=11_CASES_PASS")
end

@testset "V2 R7 package wire and semantic tamper fail atomic" begin
    p = _V2_FIXTURE.admission.package
    before_io = IOBuffer(); Serialization.serialize(before_io, p); before = take!(before_io)
    bad_encoding = ccall(:jl_new_struct, Any, (Any, Any, Any, Any),
        G_V2.VNextT1CanonicalBytesV2, p.wire.raw, p.wire.sha256, :wrong_encoding)
    bad_wire_encoding = _v2_package_with(p; wire=bad_encoding)
    r1 = G_V2.vnext_t1_package_binding_adapter_v2(bad_wire_encoding)
    @test r1.status === :fail_closed
    @test r1.reason === :wire_encoding_conflict
    bad_wire_hash = ccall(:jl_new_struct, Any, (Any, Any, Any, Any),
        G_V2.VNextT1CanonicalBytesV2, p.wire.raw, G_V2.digest256_text("r7-wire-hash"), p.wire.encoding)
    r2 = G_V2.vnext_t1_package_binding_adapter_v2(_v2_package_with(p; wire=bad_wire_hash))
    @test r2.status === :fail_closed
    @test r2.reason === :wire_hash_mismatch
    r3 = G_V2.vnext_t1_package_binding_adapter_v2(_v2_package_with(p;
        semantic_identity=G_V2.digest256_text("r7-semantic-identity")))
    @test r3.status === :fail_closed
    @test r3.reason === :semantic_identity_mismatch
    r4 = G_V2.vnext_t1_package_binding_adapter_v2(_v2_package_with(p;
        package_hash=G_V2.digest256_text("r7-package-hash")))
    @test r4.status === :fail_closed
    @test r4.reason === :package_hash_mismatch
    for r in (r1, r2, r3, r4)
        @test r.input === nothing
        @test r.binding === nothing
    end
    after_io = IOBuffer(); Serialization.serialize(after_io, p)
    @test take!(after_io) == before
    @test p.semantic_identity == _V2_FIXTURE.admission.package.semantic_identity
    @test p.package_hash == _V2_FIXTURE.admission.package.package_hash
    println("V2_R7_PACKAGE_TAMPER_CASES_PASS=4")
    println("V2_PACKAGE_HISTORY_NOT_APPLICABLE=CandidateStatePackageV5NextV2_is_immutable_without_history")
end

println("V2_R7_NEGATIVE_COVERAGE=PASS")
