using Test, Serialization, SHA

const R26_V2_ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", ".."))
const R26_V2_FIXTURE_SOURCE = joinpath(R26_V2_ROOT,
    "test/GenomeV5/Integration/VNextT1V2/vnext_t1_v2_same_chain_tests.jl")
const R26_V2_OMISSIONS = Dict("testsets" => 0, "printlns" => 0)

# Load the current same-chain producers and helpers without executing or
# rewriting their historical testsets/artifact writer.
Base.include(Main, R26_V2_FIXTURE_SOURCE) do expression
    if expression isa Expr
        if expression.head === :macrocall && string(expression.args[1]) == "@testset"
            R26_V2_OMISSIONS["testsets"] += 1
            return nothing
        elseif expression.head === :call && expression.args[1] === :println
            R26_V2_OMISSIONS["printlns"] += 1
            return nothing
        end
    end
    expression
end

function r26_v2_result_with(r; status=r.status, resolution=r.resolution,
        accepted=r.accepted, claim_ceiling=r.claim_ceiling, output=r.output,
        errors=r.errors, reasons=r.reasons,
        prior_bundle_bytes=r.prior_bundle_bytes,
        prior_bundle_sha256=r.prior_bundle_sha256)
    G_V2.VNextAuthorityRecheckLocalV2Result(status, resolution, accepted,
        claim_ceiling, output, Tuple(errors), Tuple(reasons),
        prior_bundle_bytes, prior_bundle_sha256)
end

function r26_v2_input(f, transport, recheck)
    G_V2.VNextT1AdmissionInputV2(f.input.candidate_ref, transport, recheck,
        f.input.parent_commitments, f.input.g3_expected_commitment,
        f.input.g3_authority)
end

function r26_v2_absent_transport(t; candidate=Main._T0L_CANDIDATE,
        reason=:missing_material, status=:terminal_deferred)
    absent = G_V2.VNextT0LocalAbsentDeclarationV1(:G3, candidate, reason, status)
    _v2_rebuild_transport(t;
        declarations=(t.declarations[1], t.declarations[2], absent))
end

@testset "R26 V2 coherent absence and failure separation" begin
    @test R26_V2_OMISSIONS == Dict("testsets" => 7, "printlns" => 1)
    f = _V2_FIXTURE
    t = f.transport

    absent_t = r26_v2_absent_transport(t)
    absent_r = G_V2.vnext_declaration_authority_recheck_local_v2(
        G_V2.VNextAuthorityRecheckLocalV2Input(Main._T0L_CANDIDATE, absent_t))
    @test absent_r.status === :typed_absent
    @test absent_r.resolution === :terminal_deferred
    @test absent_r.accepted === false
    @test absent_r.claim_ceiling === :contract_only
    @test absent_r.errors === ()
    @test absent_r.reasons == (:missing_material, :g3_feedback_material_absent)
    @test absent_r.output isa G_V2.VNextAuthorityRecheckLocalV2TypedAbsent
    @test absent_r.output.candidate_ref == Main._T0L_CANDIDATE
    @test absent_r.output.bundle_hash == absent_t.bundle_hash
    @test absent_r.output.g3_children_deferred

    absent_admission = G_V2.vnext_t1_admit_v2(r26_v2_input(f, absent_t, absent_r))
    @test absent_admission.status === :terminal_deferred
    @test absent_admission.resolution === :terminal_deferred
    @test absent_admission.errors === ()
    @test absent_admission.gaps == (:t0_recheck_typed_absent,)
    @test absent_admission.package === nothing
    @test absent_admission.trace == (:entry, :recheck, :typed_absence)
    @test_throws ArgumentError G_V2.CandidateStatePackageV5NextV2(
        f.input.candidate_ref, absent_t, absent_r, f.input.parent_commitments,
        f.input.g3_authority, f.input.g3_expected_commitment)

    # Pairing an honest absence with another bundle must fail its join before
    # the semantic absence branch is trusted.
    stale_absence = G_V2.vnext_t1_admit_v2(r26_v2_input(f, t, absent_r))
    @test stale_absence.status === :fail_closed
    @test stale_absence.errors == (:t0_bundle_recheck_mismatch,)
    @test stale_absence.package === nothing
    reverse_stale = G_V2.vnext_t1_admit_v2(r26_v2_input(f, absent_t, f.recheck))
    @test reverse_stale.status === :fail_closed
    @test reverse_stale.errors == (:t0_bundle_recheck_mismatch,)
    @test reverse_stale.package === nothing

    foreign = G_V2.QualifiedRefV1("local://r26-foreign", "v5")
    malformed_cases = (
        (:candidate, r26_v2_absent_transport(t; candidate=foreign), :candidate_mismatch),
        (:status, r26_v2_absent_transport(t; status=:present), :absence_status_invalid),
        (:reason, r26_v2_absent_transport(t; reason=:invented), :absence_reason_invalid),
    )
    for (_, bad_t, expected) in malformed_cases
        bad_r = G_V2.vnext_declaration_authority_recheck_local_v2(
            G_V2.VNextAuthorityRecheckLocalV2Input(Main._T0L_CANDIDATE, bad_t))
        @test bad_r.status === :fail_closed
        @test bad_r.errors == (expected,)
        rejected = G_V2.vnext_t1_admit_v2(r26_v2_input(f, bad_t, bad_r))
        @test rejected.status === :fail_closed
        @test rejected.package === nothing

        # A caller cannot relabel the same malformed transport as typed absent
        # even after recomputing its bundle, wire and absence reason metadata.
        reasons = G_V2._vnext_ar_v2_absence_reasons(bad_t.declarations)
        forged_output = G_V2.VNextAuthorityRecheckLocalV2TypedAbsent(
            Main._T0L_CANDIDATE, bad_t.bundle_hash, reasons, true)
        forged_absence = G_V2.VNextAuthorityRecheckLocalV2Result(
            :typed_absent, :terminal_deferred, false, :contract_only,
            forged_output, (), reasons, bad_r.prior_bundle_bytes,
            bad_r.prior_bundle_sha256)
        forged_result = G_V2.vnext_t1_admit_v2(
            r26_v2_input(f, bad_t, forged_absence))
        @test forged_result.status === :fail_closed
        @test forged_result.errors == (expected,)
        @test forged_result.package === nothing
    end
    candidate_failure_t = malformed_cases[1][2]
    candidate_failure_r = G_V2.vnext_declaration_authority_recheck_local_v2(
        G_V2.VNextAuthorityRecheckLocalV2Input(Main._T0L_CANDIDATE,
            candidate_failure_t))
    propagated = G_V2.vnext_t1_admit_v2(
        r26_v2_input(f, candidate_failure_t, candidate_failure_r))
    @test propagated.errors == (:candidate_mismatch,)
    @test propagated.trace == (:entry, :recheck, :upstream_fail_closed)
end

@testset "R26 V2 canonical output joins survive reconstruction" begin
    f = _V2_FIXTURE
    io = IOBuffer()
    Serialization.serialize(io, f.recheck)
    detached = Serialization.deserialize(IOBuffer(take!(io)))
    @test detached !== f.recheck
    @test detached.output !== f.recheck.output
    reconstructed = G_V2.vnext_t1_admit_v2(
        r26_v2_input(f, f.transport, detached))
    @test reconstructed.status === :prepared_not_executed
    @test reconstructed.package isa G_V2.CandidateStatePackageV5NextV2

    direct = G_V2.CandidateStatePackageV5NextV2(f.input.candidate_ref,
        f.transport, detached, f.input.parent_commitments,
        f.input.g3_authority, f.input.g3_expected_commitment)
    @test direct isa G_V2.CandidateStatePackageV5NextV2

    tamper_io = IOBuffer()
    Serialization.serialize(tamper_io, f.recheck)
    tampered = Serialization.deserialize(IOBuffer(take!(tamper_io)))
    tampered.output.declarations[1].source_bytes.bytes[1] = xor(
        tampered.output.declarations[1].source_bytes.bytes[1], UInt8(0x01))
    rejected = G_V2.vnext_t1_admit_v2(
        r26_v2_input(f, f.transport, tampered))
    @test rejected.status === :fail_closed
    @test rejected.errors == (:t0_recheck_output_declarations_mismatch,)
    @test rejected.package === nothing

    absent_t = r26_v2_absent_transport(f.transport)
    absent_r = G_V2.vnext_declaration_authority_recheck_local_v2(
        G_V2.VNextAuthorityRecheckLocalV2Input(Main._T0L_CANDIDATE, absent_t))
    checked_output = G_V2.VNextAuthorityRecheckLocalV2Checked(
        Main._T0L_CANDIDATE, absent_t.bundle_hash, absent_t.declarations,
        absent_t.children, absent_t.feedback, true)
    contradictory = r26_v2_result_with(absent_r;
        status=:local_checked_present, resolution=:resolved,
        output=checked_output, errors=(), reasons=())
    @test_throws ArgumentError G_V2.CandidateStatePackageV5NextV2(
        f.input.candidate_ref, absent_t, contradictory,
        f.input.parent_commitments, f.input.g3_authority,
        f.input.g3_expected_commitment)
    rejected_checked = G_V2.vnext_t1_admit_v2(
        r26_v2_input(f, absent_t, contradictory))
    @test rejected_checked.status === :fail_closed
    @test rejected_checked.errors == (:t0_recheck_presence_mismatch,)
    @test rejected_checked.package === nothing
end

@testset "R26 V2 contradictory recheck envelopes fail closed" begin
    f = _V2_FIXTURE
    r = f.recheck
    cases = (
        (:accepted, r26_v2_result_with(r; accepted=true), :t0_recheck_accepted_invalid),
        (:ceiling, r26_v2_result_with(r; claim_ceiling=:physical),
            :t0_recheck_claim_ceiling_invalid),
        (:resolution, r26_v2_result_with(r; resolution=:terminal_deferred),
            :t0_recheck_resolution_invalid),
        (:errors, r26_v2_result_with(r; errors=(:forged,)), :t0_recheck_errors_invalid),
        (:reasons, r26_v2_result_with(r; reasons=(:forged,)), :t0_recheck_reasons_invalid),
        (:output, r26_v2_result_with(r; output=nothing), :t0_recheck_output_invalid),
        (:status, r26_v2_result_with(r; status=:invented), :t0_recheck_status_invalid),
        (:failed_without_error, r26_v2_result_with(r; status=:fail_closed,
            resolution=:none, output=nothing, errors=(), reasons=()),
            :t0_recheck_errors_invalid),
        (:failed_reason_conflict, r26_v2_result_with(r; status=:fail_closed,
            resolution=:none, output=nothing, errors=(:a,), reasons=(:b,)),
            :t0_recheck_reasons_invalid),
    )
    for (_, forged, expected) in cases
        rejected = G_V2.vnext_t1_admit_v2(r26_v2_input(f, f.transport, forged))
        @test rejected.status === :fail_closed
        @test rejected.resolution === :none
        @test rejected.errors == (expected,)
        @test rejected.package === nothing
    end

    absent_output = G_V2.VNextAuthorityRecheckLocalV2TypedAbsent(
        Main._T0L_CANDIDATE, f.transport.bundle_hash,
        (:missing_material, :g3_feedback_material_absent), true)
    forged_absence = r26_v2_result_with(r; status=:typed_absent,
        resolution=:terminal_deferred, output=absent_output, errors=(),
        reasons=(:missing_material, :g3_feedback_material_absent))
    rejected_absence = G_V2.vnext_t1_admit_v2(
        r26_v2_input(f, f.transport, forged_absence))
    @test rejected_absence.status === :fail_closed
    @test rejected_absence.errors == (:t0_recheck_absence_mismatch,)
    @test rejected_absence.package === nothing

    foreign = G_V2.QualifiedRefV1("local://r26-output-foreign", "v5")
    foreign_output = G_V2.VNextAuthorityRecheckLocalV2Checked(foreign,
        f.recheck.output.bundle_hash, f.recheck.output.declarations,
        f.recheck.output.children, f.recheck.output.feedback,
        f.recheck.output.g3_children_deferred)
    foreign_envelope = r26_v2_result_with(r; output=foreign_output)
    rejected_foreign = G_V2.vnext_t1_admit_v2(
        r26_v2_input(f, f.transport, foreign_envelope))
    @test rejected_foreign.status === :fail_closed
    @test rejected_foreign.errors == (:t0_recheck_output_candidate_mismatch,)
    @test rejected_foreign.package === nothing
end

@testset "R26 V2 present package reload adapter binding" begin
    f = _V2_FIXTURE
    @test f.admission.status === :prepared_not_executed
    @test f.admission.package isa G_V2.CandidateStatePackageV5NextV2
    io = IOBuffer()
    Serialization.serialize(io, f.admission.package)
    serialized = take!(io)
    reloaded = Serialization.deserialize(IOBuffer(serialized))
    @test G_V2.vnext_t1_package_v2_validate(reloaded) === nothing
    adapter = G_V2.vnext_t1_package_binding_adapter_v2(reloaded)
    @test adapter.status === :prepared_not_executed
    @test adapter.input !== nothing
    binding = G_V2.vnext_t1_candidate_binding_v2(adapter.input, (adapter.input,))
    @test binding.status === :bound
    @test binding.reason === :exact_explicit_binding
    @test reloaded.semantic_identity == f.admission.package.semantic_identity
    @test reloaded.package_hash == f.admission.package.package_hash
end

println("R26_V2_SEMANTICS_PASS formal_T1=false")
