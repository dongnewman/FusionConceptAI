using Test # R26 test-contract v7; preserves the frozen 63-target lineage and strengthens reviewed semantic deltas.
using FusionConceptAI

const _T1_ROOT = joinpath(@__DIR__, "..", "..", "..", "..")
const G = FusionConceptAI

# The transport helper is definition-only when included from this file.  It
# supplies the real G1/G2/G3 constructors and local source-backed fixture;
# this test then performs the complete local T0 transport -> recheck -> T1
# admission chain without loading either additive file into the main module.
Base.include(Main, joinpath(@__DIR__, "..", "vnext_declaration_transport_local_v1_tests.jl"))
Base.include(G, joinpath(_T1_ROOT, "src", "GenomeV5", "Integration",
    "VNextDeclarationAuthorityRecheckLocalV1.jl"))
Base.include(G, joinpath(_T1_ROOT, "src", "Contracts",
    "CandidateStatePackageV5Next.jl"))
Base.include(G, joinpath(_T1_ROOT, "src", "GenomeV5", "Integration",
    "VNextGenomeV5Integration.jl"))
Base.include(Main, joinpath(@__DIR__, "..", "vnext_t1_projection_diagnostic_v1.jl"))
Base.include(Main, joinpath(@__DIR__, "..", "VNextT1V1R18", "formal_contract_v2_checks.jl"))
Base.include(Main, joinpath(@__DIR__, "v1_semantic_contract_r26.jl"))
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

@noinline Base.@nospecializeinfer function _r26_byte_vector(
        @nospecialize(bytes::Tuple{Vararg{UInt8}}))
    copied = Vector{UInt8}(undef, length(bytes))
    @inbounds for index in eachindex(copied)
        copied[index] = bytes[index]
    end
    copied
end

_r26_byte_vector(bytes::Vector{UInt8}) = bytes

@noinline function _r26_vector_bytes_equal(
        left::Vector{UInt8}, right::Vector{UInt8})
    length(left) == length(right) || return false
    @inbounds for index in eachindex(left)
        left[index] == right[index] || return false
    end
    true
end

@noinline Base.@nospecializeinfer function _r26_bytes_equal(
        @nospecialize(left), @nospecialize(right))
    length(left) == length(right) || return false
    _r26_vector_bytes_equal(_r26_byte_vector(left), _r26_byte_vector(right))
end

function _r26_label_phase_begin(name::Symbol)
    println("R26_LABEL_ISOLATION_PHASE phase=", name, " event=begin")
    flush(stdout)
    time_ns()
end

function _r26_label_phase_end(name::Symbol, started::UInt64;
        bytes::Int=0, sha256=nothing)
    elapsed = (time_ns() - started) / 1.0e9
    println("R26_LABEL_ISOLATION_PHASE phase=", name, " event=end elapsed_seconds=",
        elapsed, " bytes=", bytes, " sha256=", sha256 === nothing ? "none" : sha256)
    flush(stdout)
    nothing
end

@noinline Base.@nospecializeinfer function _r26_label_isolation_observation(
        @nospecialize(original), @nospecialize(relabeled),
        @nospecialize(original_package), @nospecialize(relabeled_package))
    total_started = _r26_label_phase_begin(:observer_total)

    refs_started = _r26_label_phase_begin(:collect_refs)
    original_labels_items = Vector{Any}(undef, 3)
    relabeled_labels_items = Vector{Any}(undef, 3)
    original_body_bytes = Vector{Any}(undef, 3)
    relabeled_body_bytes = Vector{Any}(undef, 3)
    original_body_declared_sha256 = Vector{Any}(undef, 3)
    relabeled_body_declared_sha256 = Vector{Any}(undef, 3)
    original_package_body_bytes = Vector{Any}(undef, 3)
    relabeled_package_body_bytes = Vector{Any}(undef, 3)
    original_package_body_sha256 = Vector{Any}(undef, 3)
    relabeled_package_body_sha256 = Vector{Any}(undef, 3)
    original_source_identity_hashes = Vector{Any}(undef, 3)
    relabeled_source_identity_hashes = Vector{Any}(undef, 3)
    original_declaration_identity_hashes = Vector{Any}(undef, 3)
    relabeled_declaration_identity_hashes = Vector{Any}(undef, 3)
    original_package_source_identity_hashes = Vector{Any}(undef, 3)
    relabeled_package_source_identity_hashes = Vector{Any}(undef, 3)
    original_package_declaration_identity_hashes = Vector{Any}(undef, 3)
    relabeled_package_declaration_identity_hashes = Vector{Any}(undef, 3)
    for index in 1:3
        original_declaration = original.declarations[index]
        relabeled_declaration = relabeled.declarations[index]
        original_package_declaration = original_package.declarations[index]
        relabeled_package_declaration = relabeled_package.declarations[index]
        original_labels_items[index] = original_declaration.semantic_body.labels
        relabeled_labels_items[index] = relabeled_declaration.semantic_body.labels
        original_body_bytes[index] = original_declaration.semantic_body.bytes.bytes
        relabeled_body_bytes[index] = relabeled_declaration.semantic_body.bytes.bytes
        original_body_declared_sha256[index] =
            original_declaration.semantic_body.bytes.sha256
        relabeled_body_declared_sha256[index] =
            relabeled_declaration.semantic_body.bytes.sha256
        original_package_body_bytes[index] =
            original_package_declaration.semantic_body_bytes.bytes
        relabeled_package_body_bytes[index] =
            relabeled_package_declaration.semantic_body_bytes.bytes
        original_package_body_sha256[index] =
            original_package_declaration.semantic_body_bytes.sha256
        relabeled_package_body_sha256[index] =
            relabeled_package_declaration.semantic_body_bytes.sha256
        original_source_identity_hashes[index] =
            original_declaration.source_identity_hash
        relabeled_source_identity_hashes[index] =
            relabeled_declaration.source_identity_hash
        original_declaration_identity_hashes[index] =
            original_declaration.declaration_identity_hash
        relabeled_declaration_identity_hashes[index] =
            relabeled_declaration.declaration_identity_hash
        original_package_source_identity_hashes[index] =
            original_package_declaration.source_identity_hash
        relabeled_package_source_identity_hashes[index] =
            relabeled_package_declaration.source_identity_hash
        original_package_declaration_identity_hashes[index] =
            original_package_declaration.declaration_identity_hash
        relabeled_package_declaration_identity_hashes[index] =
            relabeled_package_declaration.declaration_identity_hash
    end
    original_prior_wire_bytes = original.recheck.prior_bundle_bytes
    relabeled_prior_wire_bytes = relabeled.recheck.prior_bundle_bytes
    original_prior_snapshot_bytes =
        original_package.t0_gate.prior_bundle.canonical_bytes.bytes
    relabeled_prior_snapshot_bytes =
        relabeled_package.t0_gate.prior_bundle.canonical_bytes.bytes
    original_output_bytes = original_package.t0_gate.output_bytes.bytes
    relabeled_output_bytes = relabeled_package.t0_gate.output_bytes.bytes
    original_output_projection = original_package.t0_gate.output_projection
    relabeled_output_projection = relabeled_package.t0_gate.output_projection
    _r26_label_phase_end(:collect_refs, refs_started)

    original_body_direct_sha256 = Vector{Any}(undef, 3)
    relabeled_body_direct_sha256 = Vector{Any}(undef, 3)
    for index in 1:3
        name = Symbol("body_sha_original_", index)
        started = _r26_label_phase_begin(name)
        original_body_direct_sha256[index] = G._vnext_t1_sha(original_body_bytes[index])
        _r26_label_phase_end(name, started; bytes=length(original_body_bytes[index]),
            sha256=original_body_direct_sha256[index])

        name = Symbol("body_sha_relabeled_", index)
        started = _r26_label_phase_begin(name)
        relabeled_body_direct_sha256[index] = G._vnext_t1_sha(relabeled_body_bytes[index])
        _r26_label_phase_end(name, started; bytes=length(relabeled_body_bytes[index]),
            sha256=relabeled_body_direct_sha256[index])
    end

    started = _r26_label_phase_begin(:prior_sha_original)
    original_prior_wire_sha256 = G._vnext_t1_sha(original_prior_wire_bytes)
    _r26_label_phase_end(:prior_sha_original, started;
        bytes=length(original_prior_wire_bytes), sha256=original_prior_wire_sha256)
    started = _r26_label_phase_begin(:prior_sha_relabeled)
    relabeled_prior_wire_sha256 = G._vnext_t1_sha(relabeled_prior_wire_bytes)
    _r26_label_phase_end(:prior_sha_relabeled, started;
        bytes=length(relabeled_prior_wire_bytes), sha256=relabeled_prior_wire_sha256)

    started = _r26_label_phase_begin(:output_sha_original)
    original_output_wire_sha256 = G._vnext_t1_sha(original_output_bytes)
    _r26_label_phase_end(:output_sha_original, started;
        bytes=length(original_output_bytes), sha256=original_output_wire_sha256)
    started = _r26_label_phase_begin(:output_sha_relabeled)
    relabeled_output_wire_sha256 = G._vnext_t1_sha(relabeled_output_bytes)
    _r26_label_phase_end(:output_sha_relabeled, started;
        bytes=length(relabeled_output_bytes), sha256=relabeled_output_wire_sha256)

    started = _r26_label_phase_begin(:output_projection_hash_original)
    original_output_projection_hash = G.canonical_hash(original_output_projection)
    _r26_label_phase_end(:output_projection_hash_original, started;
        sha256=original_output_projection_hash)
    started = _r26_label_phase_begin(:output_projection_hash_relabeled)
    relabeled_output_projection_hash = G.canonical_hash(relabeled_output_projection)
    _r26_label_phase_end(:output_projection_hash_relabeled, started;
        sha256=relabeled_output_projection_hash)

    semantic_body_bytes_equal = true
    package_body_bytes_equal = true
    package_body_original_source_bytes_equal = true
    package_body_relabeled_source_bytes_equal = true
    for index in 1:3
        name = Symbol("body_bytes_cross_", index)
        started = _r26_label_phase_begin(name)
        semantic_body_bytes_equal &= _r26_bytes_equal(
            original_body_bytes[index], relabeled_body_bytes[index])
        _r26_label_phase_end(name, started; bytes=length(original_body_bytes[index]))

        name = Symbol("package_body_bytes_cross_", index)
        started = _r26_label_phase_begin(name)
        package_body_bytes_equal &= _r26_bytes_equal(
            original_package_body_bytes[index], relabeled_package_body_bytes[index])
        _r26_label_phase_end(name, started;
            bytes=length(original_package_body_bytes[index]))

        name = Symbol("package_body_source_original_", index)
        started = _r26_label_phase_begin(name)
        package_body_original_source_bytes_equal &= _r26_bytes_equal(
            original_package_body_bytes[index], original_body_bytes[index])
        _r26_label_phase_end(name, started;
            bytes=length(original_package_body_bytes[index]))

        name = Symbol("package_body_source_relabeled_", index)
        started = _r26_label_phase_begin(name)
        package_body_relabeled_source_bytes_equal &= _r26_bytes_equal(
            relabeled_package_body_bytes[index], relabeled_body_bytes[index])
        _r26_label_phase_end(name, started;
            bytes=length(relabeled_package_body_bytes[index]))
    end

    started = _r26_label_phase_begin(:prior_wire_bytes_cross)
    prior_wire_bytes_equal = _r26_bytes_equal(
        original_prior_wire_bytes, relabeled_prior_wire_bytes)
    _r26_label_phase_end(:prior_wire_bytes_cross, started;
        bytes=length(original_prior_wire_bytes))
    started = _r26_label_phase_begin(:prior_snapshot_original_wire)
    prior_snapshot_original_bytes_equal = _r26_bytes_equal(
        original_prior_snapshot_bytes, original_prior_wire_bytes)
    _r26_label_phase_end(:prior_snapshot_original_wire, started;
        bytes=length(original_prior_snapshot_bytes))
    started = _r26_label_phase_begin(:prior_snapshot_relabeled_wire)
    prior_snapshot_relabeled_bytes_equal = _r26_bytes_equal(
        relabeled_prior_snapshot_bytes, relabeled_prior_wire_bytes)
    _r26_label_phase_end(:prior_snapshot_relabeled_wire, started;
        bytes=length(relabeled_prior_snapshot_bytes))
    started = _r26_label_phase_begin(:output_bytes_cross)
    output_bytes_equal = _r26_bytes_equal(original_output_bytes, relabeled_output_bytes)
    _r26_label_phase_end(:output_bytes_cross, started;
        bytes=length(original_output_bytes))

    metadata_started = _r26_label_phase_begin(:small_metadata)
    original_labels = (original_labels_items[1], original_labels_items[2],
        original_labels_items[3])
    relabeled_labels = (relabeled_labels_items[1], relabeled_labels_items[2],
        relabeled_labels_items[3])
    checks = (
        raw_labels_original_nonempty=all(x -> !isempty(x), original_labels),
        raw_labels_relabeled_nonempty=all(x -> !isempty(x), relabeled_labels),
        raw_labels_original_expected=all(x -> x == ("t1",), original_labels),
        raw_labels_relabeled_expected=all(
            x -> x == ("different-visible-label",), relabeled_labels),
        raw_labels_differ=original_labels != relabeled_labels,
        semantic_body_bytes_equal=semantic_body_bytes_equal,
        semantic_body_declared_sha256_equal=
            original_body_declared_sha256 == relabeled_body_declared_sha256,
        semantic_body_original_self_bound=
            original_body_declared_sha256 == original_body_direct_sha256,
        semantic_body_relabeled_self_bound=
            relabeled_body_declared_sha256 == relabeled_body_direct_sha256,
        package_body_bytes_equal=package_body_bytes_equal,
        package_body_sha256_equal=
            original_package_body_sha256 == relabeled_package_body_sha256,
        package_body_original_source_join=
            package_body_original_source_bytes_equal &&
            original_package_body_sha256 == original_body_direct_sha256,
        package_body_relabeled_source_join=
            package_body_relabeled_source_bytes_equal &&
            relabeled_package_body_sha256 == relabeled_body_direct_sha256,
        source_identity_hashes_equal=
            original_source_identity_hashes == relabeled_source_identity_hashes,
        declaration_identity_hashes_equal=original_declaration_identity_hashes ==
            relabeled_declaration_identity_hashes,
        package_original_identity_join=
            original_package_source_identity_hashes == original_source_identity_hashes &&
            original_package_declaration_identity_hashes ==
                original_declaration_identity_hashes,
        package_relabeled_identity_join=
            relabeled_package_source_identity_hashes == relabeled_source_identity_hashes &&
            relabeled_package_declaration_identity_hashes ==
                relabeled_declaration_identity_hashes,
        transport_bundle_body_digest_equal=
            original.transport.bundle_hash == relabeled.transport.bundle_hash,
        recheck_prior_body_digest_equal=
            original.recheck.prior_bundle_sha256 ==
                relabeled.recheck.prior_bundle_sha256,
        recheck_prior_body_digest_transport_join=
            original.recheck.prior_bundle_sha256 == original.transport.bundle_hash &&
            relabeled.recheck.prior_bundle_sha256 == relabeled.transport.bundle_hash,
        prior_wire_bytes_equal=prior_wire_bytes_equal,
        prior_wire_sha256_equal=
            original_prior_wire_sha256 == relabeled_prior_wire_sha256,
        prior_snapshot_original_wire_join=prior_snapshot_original_bytes_equal &&
            original_package.t0_gate.prior_bundle.canonical_bytes.sha256 ==
                original_prior_wire_sha256,
        prior_snapshot_relabeled_wire_join=prior_snapshot_relabeled_bytes_equal &&
            relabeled_package.t0_gate.prior_bundle.canonical_bytes.sha256 ==
                relabeled_prior_wire_sha256,
        prior_snapshot_body_digest_join=
            original_package.t0_gate.prior_bundle.bundle_hash ==
                original.recheck.prior_bundle_sha256 &&
            relabeled_package.t0_gate.prior_bundle.bundle_hash ==
                relabeled.recheck.prior_bundle_sha256,
        output_bytes_equal=output_bytes_equal,
        output_wire_sha256_equal=
            original_output_wire_sha256 == relabeled_output_wire_sha256,
        output_original_wire_join=
            original_package.t0_gate.output_bytes.sha256 ==
                original_output_wire_sha256,
        output_relabeled_wire_join=
            relabeled_package.t0_gate.output_bytes.sha256 ==
                relabeled_output_wire_sha256,
        output_hash_equal=original_package.t0_gate.output_hash ==
            relabeled_package.t0_gate.output_hash,
        output_original_projection_join=
            original_package.t0_gate.output_hash == original_output_projection_hash &&
            original_package.t0_gate.output_identity.output_hash ==
                original_package.t0_gate.output_hash,
        output_relabeled_projection_join=
            relabeled_package.t0_gate.output_hash == relabeled_output_projection_hash &&
            relabeled_package.t0_gate.output_identity.output_hash ==
                relabeled_package.t0_gate.output_hash,
        component_semantic_identity_equal=
            original_package.component_identity.semantic_identity ==
                relabeled_package.component_identity.semantic_identity,
        package_semantic_identity_equal=original_package.semantic_identity ==
            relabeled_package.semantic_identity,
        package_hash_equal=original_package.package_hash ==
            relabeled_package.package_hash,
        recheck_state_axes_equal=(original.recheck.status,
                original.recheck.resolution, original.recheck.accepted,
                original.recheck.claim_ceiling) ==
            (relabeled.recheck.status, relabeled.recheck.resolution,
                relabeled.recheck.accepted, relabeled.recheck.claim_ceiling),
        package_state_axes_equal=(original_package.status,
                original_package.resolution, original_package.accepted,
                original_package.claim_ceiling) ==
            (relabeled_package.status, relabeled_package.resolution,
                relabeled_package.accepted, relabeled_package.claim_ceiling),
    )
    actual = (
        original_labels=original_labels,
        relabeled_labels=relabeled_labels,
        original_semantic_body_bytes_lengths=(length(original_body_bytes[1]),
            length(original_body_bytes[2]), length(original_body_bytes[3])),
        relabeled_semantic_body_bytes_lengths=(length(relabeled_body_bytes[1]),
            length(relabeled_body_bytes[2]), length(relabeled_body_bytes[3])),
        original_semantic_body_sha256=(original_body_direct_sha256[1],
            original_body_direct_sha256[2], original_body_direct_sha256[3]),
        relabeled_semantic_body_sha256=(relabeled_body_direct_sha256[1],
            relabeled_body_direct_sha256[2], relabeled_body_direct_sha256[3]),
        source_identity_hashes=(original_source_identity_hashes[1],
            original_source_identity_hashes[2], original_source_identity_hashes[3]),
        declaration_identity_hashes=(original_declaration_identity_hashes[1],
            original_declaration_identity_hashes[2],
            original_declaration_identity_hashes[3]),
        transport_canonical_bytes=length(original_prior_wire_bytes),
        original_prior_body_digest=original.recheck.prior_bundle_sha256,
        relabeled_prior_body_digest=relabeled.recheck.prior_bundle_sha256,
        original_prior_wire_sha256=original_prior_wire_sha256,
        relabeled_prior_wire_sha256=relabeled_prior_wire_sha256,
        output_canonical_bytes=length(original_output_bytes),
        original_output_wire_sha256=original_output_wire_sha256,
        relabeled_output_wire_sha256=relabeled_output_wire_sha256,
        original_output_hash=original_package.t0_gate.output_hash,
        relabeled_output_hash=relabeled_package.t0_gate.output_hash,
        original_component_semantic_identity=
            original_package.component_identity.semantic_identity,
        relabeled_component_semantic_identity=
            relabeled_package.component_identity.semantic_identity,
        original_package_semantic_identity=original_package.semantic_identity,
        relabeled_package_semantic_identity=relabeled_package.semantic_identity,
        original_package_hash=original_package.package_hash,
        relabeled_package_hash=relabeled_package.package_hash,
    )
    _r26_label_phase_end(:small_metadata, metadata_started)
    _r26_label_phase_end(:observer_total, total_started)
    (checks=checks, actual=actual)
end

const _T1_HASH_DISPATCH_LENGTHS = (0, 1, 63, 64, 65, 1024)
const _T1_EXISTING_LARGE_PAYLOAD_LENGTH = 8_269_445

function _t1_fixed_pattern_vector(n::Int)
    UInt8[mod(i - 1, 251) for i in 1:n]
end

function _t1_assert_digest_dispatch(n::Int)
    vector_bytes = _t1_fixed_pattern_vector(n)
    tuple_bytes = Tuple(vector_bytes)
    tuple_hash = G._vnext_t1_sha(tuple_bytes)
    vector_hash = G._vnext_t1_sha(vector_bytes)
    @test tuple_hash == vector_hash
    owned = G.VNextT1CanonicalBytesV1(vector_bytes)
    @test owned.bytes == tuple_bytes
    @test typeof(owned.bytes) === typeof(tuple_bytes)
    @test owned.sha256 == vector_hash
    if !isempty(vector_bytes)
        before = owned.bytes
        vector_bytes[1] = xor(vector_bytes[1], UInt8(0xff))
        @test owned.bytes == before
        @test owned.sha256 == tuple_hash
    end
end

@testset "T1 direct SHA dispatch and owned bytes" begin
    for n in _T1_HASH_DISPATCH_LENGTHS
        _t1_assert_digest_dispatch(n)
    end

    # This is the fixed-pattern size that previously failed in the existing
    # T1 snapshot/projection path.  Keep it as a direct tuple/vector parity
    # check so the regression cannot be hidden by a smaller fixture.
    _t1_assert_digest_dispatch(_T1_EXISTING_LARGE_PAYLOAD_LENGTH)
end

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
    diagnostic = Main.vnext_t1_projection_diagnostic_v1(_t1_input(fixture))
    @test _r26_formal_diagnostic_contract_v3(diagnostic, fixture)
    @test diagnostic.stage isa Symbol
    @test diagnostic.exception_type isa Symbol
    @test diagnostic.message_digest isa G.Digest256
    println("UP1_04A_VNEXT_T1_DIAGNOSTIC_STATUS=$(diagnostic.status)")
    println("UP1_04A_VNEXT_T1_DIAGNOSTIC_STAGE=$(diagnostic.stage)")
    println("UP1_04A_VNEXT_T1_DIAGNOSTIC_EXCEPTION_TYPE=$(diagnostic.exception_type)")
    println("UP1_04A_VNEXT_T1_DIAGNOSTIC_MESSAGE_DIGEST=$(diagnostic.message_digest)")
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
        # Regression guard: the T0 declaration has no contract_identity field;
        # the factory result contract is joined through its factory receipt.
        @test _r18_formal_factory_contract_v2(declaration,
            fixture)
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
        # Raw labels differ and remain nonempty.  Every canonical carrier and
        # identity is label-erased, including the prior T0 transport snapshot.
        println("R26_LABEL_ISOLATION_CALL event=begin")
        flush(stdout)
        label_isolation = _r26_label_isolation_observation(fixture, relabeled,
            package, relabeled_result.package)
        println("R26_LABEL_ISOLATION_CALL event=end")
        flush(stdout)
        println("R26_LABEL_ISOLATION_ACTUAL=",
            G.canonical_json(label_isolation))
        flush(stdout)
        @test all(values(label_isolation.checks))
    end

    @testset "R26 directional mismatch and coherent typed absence" begin
        matrix = _r26_v1_semantic_matrix(fixture)
        _R26_LAST_V1_MATRIX[] = matrix
        _r26_emit_v1_semantic_actual(matrix)
        forward = matrix.present_bundle_absent_local
        @test forward.status === :fail_closed && forward.output === nothing
        @test forward.resolution === :none &&
            forward.errors === (:record_bundle_canonical_mismatch,) &&
            forward.reasons === (:record_bundle_canonical_mismatch,)
        absent_result = matrix.true_absence_admission
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

@testset "R26 reviewed V1 semantic supplement" begin
    matrix = _R26_LAST_V1_MATRIX[]
    matrix === nothing && (matrix = _r26_v1_semantic_matrix(_t1_fixture()))
    forward = matrix.present_bundle_absent_local
    reverse = matrix.absent_bundle_present_local
    honest = matrix.true_absence
    @test forward.status === :fail_closed && forward.resolution === :none &&
        forward.output === nothing &&
        forward.errors === (:record_bundle_canonical_mismatch,) &&
        forward.reasons === (:record_bundle_canonical_mismatch,)
    @test reverse.status === :fail_closed && reverse.resolution === :none &&
        reverse.output === nothing &&
        reverse.errors === (:record_bundle_canonical_mismatch,) &&
        reverse.reasons === (:record_bundle_canonical_mismatch,)
    @test honest.status === :typed_absent &&
        honest.resolution === :terminal_deferred && honest.accepted === false &&
        honest.claim_ceiling === :contract_only && honest.errors === () &&
        honest.reasons === (:missing_material, :g3_feedback_material_absent) &&
        honest.output isa G.VNextAuthorityRecheckLocalTypedAbsentV1 &&
        honest.output.g3_children_deferred
    @test honest.prior_bundle_sha256 == matrix.absent_transport.bundle_hash &&
        honest.prior_bundle_bytes ==
            Tuple(Vector{UInt8}(codeunits(G.canonical_json(matrix.absent_transport))))
    @test all(x -> x.status === :fail_closed && x.resolution === :none &&
            x.package === nothing && x.accepted === false &&
            x.claim_ceiling === :contract_only,
        (matrix.present_absent_admission, matrix.absent_present_admission,
            matrix.true_absence_admission)) &&
        matrix.true_absence_admission.errors === (:t0_recheck_gate_invalid,)
    @test _r26_v1_inputs_unchanged(matrix)
    @test matrix.invalid_absence.status === :fail_closed &&
        matrix.invalid_absence.output === nothing
end

println("UP1_04A_VNEXT_T1_LOCAL_STATUS=prepared_not_executed")
println("UP1_04A_VNEXT_T1_LOCAL_ACCEPTED=false")
println("UP1_04A_VNEXT_T1_LOCAL_CLAIM_CEILING=contract_only")
println("UP1_04A_VNEXT_T1_LOCAL_T2_UP2_R_CREDIT=false")
println("UP1_04A_VNEXT_T1_LOCAL_NEGATIVE_CASES=9")
