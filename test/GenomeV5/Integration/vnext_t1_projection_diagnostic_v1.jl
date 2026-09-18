"""Additive first-failure diagnostic for the local T1 projection chain.

This file is test-only.  It is included by the focused test in ``Main`` and
never by ``FusionConceptAI.jl``.  The production admission function keeps its
closed error boundary; this helper mirrors its ordered internal calls so a
focused run can identify the first failing stage without changing that
boundary or retaining the exception text.
"""

const _VNEXT_T1_DIAGNOSTIC_G = FusionConceptAI

"""Return only the closed diagnostic tuple for one T1 admission input.

The returned named tuple has exactly four fields: ``status``, ``stage``,
``exception_type``, and ``message_digest``.  The exception object is never
stringified: the digest uses only the fixed status, stage, and exception type
fields.
"""
function vnext_t1_projection_diagnostic_v1(input)
    G = _VNEXT_T1_DIAGNOSTIC_G
    stage = :input_gate
    try
        input.candidate_ref.version == "v5" ||
            throw(ArgumentError("candidate version invalid"))
        input.t0_recheck === nothing &&
            throw(ArgumentError("T0 recheck required"))
        input.transport === nothing &&
            throw(ArgumentError("T0 transport required"))
        input.t0_recheck.status === :local_checked_present ||
            throw(ArgumentError("T0 status gate invalid"))
        input.t0_recheck.resolution === :resolved ||
            throw(ArgumentError("T0 resolution gate invalid"))
        input.t0_recheck.accepted == false ||
            throw(ArgumentError("T0 accepted gate invalid"))
        input.t0_recheck.claim_ceiling === :contract_only ||
            throw(ArgumentError("T0 claim ceiling gate invalid"))

        # Keep this sequence aligned with vnext_t1_admit_skeleton_v1.  Each
        # assignment marks the next production operation before it executes.
        stage = :snapshot
        prior = G._vnext_t1_snapshot(input)
        stage = :declarations
        declarations = G._vnext_t1_declaration_tuple(input.transport,
            input.candidate_ref)
        stage = :children
        children = G._vnext_t1_child_tuple(input.transport,
            input.candidate_ref)
        raw_declarations = ntuple(i ->
            input.transport.declarations[i]::G.VNextT0LocalPresentDeclarationV1, 3)
        raw_feedback = input.transport.feedback
        stage = :feedback_order
        G._vnext_t1_validate_feedback_order(raw_feedback)
        stage = :feedback
        typed_feedback = ntuple(i -> raw_feedback[i]::G.VNextT0LocalFeedbackV1,
            length(raw_feedback))
        feedback = G._vnext_t1_feedback_tuple(typed_feedback, raw_declarations,
            input.candidate_ref)
        axes = ntuple(i -> declarations[i].axes, 3)
        source_hashes = ntuple(i -> declarations[i].source_bytes.sha256, 3)
        declaration_hashes = ntuple(i -> declarations[i].declaration_bytes.sha256, 3)
        stage = :no_legacy
        no_legacy = input.no_legacy_receipt === nothing ?
            G.vnext_t1_no_legacy_receipt_v1(input.candidate_ref) :
            input.no_legacy_receipt
        G._vnext_t1_validate_no_legacy_receipt(no_legacy, input.candidate_ref)
        stage = :output_gate
        gate = G._vnext_t1_output_gate(input, prior, declarations, children, feedback)
        stage = :package
        G._vnext_t1_package(input.candidate_ref, declarations, children, axes,
            feedback, source_hashes, declaration_hashes, gate, no_legacy)
        return (status=:ok, stage=:complete, exception_type=:none,
            message_digest=G.canonical_hash((status=:ok, stage=:complete,
                exception_type=:none)))
    catch err
        exception_type = nameof(typeof(err))
        message_digest = G.canonical_hash((status=:internal_failure, stage=stage,
            exception_type=exception_type))
        return (status=:internal_failure, stage=stage,
            exception_type=exception_type, message_digest=message_digest)
    end
end
