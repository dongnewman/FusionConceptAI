"""R26 successor semantics for the frozen V1 test-contract targets.

This test-only file keeps the old checked-present package path and separates
the historical one-sided mismatch fixture from a coherent typed absence.
"""

const _R26_LAST_V1_MATRIX = Ref{Any}(nothing)

function _r26_rebuild_v1_transport(bundle; declarations=bundle.declarations,
        candidate=bundle.candidate_ref, children=bundle.children,
        feedback=bundle.feedback, status=bundle.status, errors=bundle.errors,
        gaps=bundle.gaps)
    body_hash = G.canonical_hash(G._vnl_t0_bundle_body_v1(candidate,
        declarations, children, feedback))
    G.VNextT0LocalTransportV1(candidate, Tuple(declarations), Tuple(children),
        Tuple(feedback), body_hash, status, errors, gaps)
end

function _r26_v1_input(candidate, recheck, transport)
    G.VNextT1AdmissionInputV1(candidate, recheck, transport, nothing)
end

function _r26_v1_result_metadata(result)
    (type_name=string(nameof(typeof(result))), status=result.status,
        resolution=result.resolution, accepted=result.accepted,
        claim_ceiling=result.claim_ceiling, errors=result.errors,
        reasons=result.reasons,
        output_type=result.output === nothing ? :Nothing :
            nameof(typeof(result.output)),
        prior_bundle_sha256=result.prior_bundle_sha256.value)
end

function _r26_v1_admission_metadata(result)
    (status=result.status, resolution=result.resolution,
        accepted=result.accepted, claim_ceiling=result.claim_ceiling,
        package_absent=result.package === nothing, errors=result.errors,
        gaps=result.gaps)
end

function _r26_v1_semantic_matrix(fixture)
    absent_g3 = G.VNextT0LocalAbsentDeclarationV1(:G3, _T1_CANDIDATE,
        :missing_material, :terminal_deferred)
    absent_records = (fixture.declarations[1], fixture.declarations[2], absent_g3)
    absent_transport = _r26_rebuild_v1_transport(fixture.transport;
        declarations=absent_records)
    before = (present_transport=G.canonical_hash(fixture.transport),
        absent_transport=G.canonical_hash(absent_transport),
        present_declarations=G.canonical_hash(fixture.declarations),
        absent_declarations=G.canonical_hash(absent_records))

    present_bundle_absent_local =
        G.vnext_declaration_authority_recheck_local_v1(
            G.VNextAuthorityRecheckLocalInputV1(_T1_CANDIDATE,
                fixture.transport, absent_records))
    absent_bundle_present_local =
        G.vnext_declaration_authority_recheck_local_v1(
            G.VNextAuthorityRecheckLocalInputV1(_T1_CANDIDATE,
                absent_transport, fixture.declarations))
    true_absence = G.vnext_declaration_authority_recheck_local_v1(
        G.VNextAuthorityRecheckLocalInputV1(_T1_CANDIDATE,
            absent_transport, absent_records))

    # These calls exercise the reviewed closed input boundary. Mismatch and
    # honest absence are different recheck results, but neither may construct
    # a V1 T1 package.
    present_absent_admission = G.vnext_t1_admit_skeleton_v1(
        _r26_v1_input(_T1_CANDIDATE, present_bundle_absent_local,
            fixture.transport))
    absent_present_admission = G.vnext_t1_admit_skeleton_v1(
        _r26_v1_input(_T1_CANDIDATE, absent_bundle_present_local,
            absent_transport))
    true_absence_admission = G.vnext_t1_admit_skeleton_v1(
        _r26_v1_input(_T1_CANDIDATE, true_absence, absent_transport))

    foreign = G.QualifiedRefV1("local://r26-foreign-absence", "v5")
    foreign_absent_g3 = G.VNextT0LocalAbsentDeclarationV1(:G3, foreign,
        :missing_material, :terminal_deferred)
    foreign_records = (fixture.declarations[1], fixture.declarations[2],
        foreign_absent_g3)
    foreign_transport = _r26_rebuild_v1_transport(fixture.transport;
        declarations=foreign_records)
    invalid_absence = G.vnext_declaration_authority_recheck_local_v1(
        G.VNextAuthorityRecheckLocalInputV1(_T1_CANDIDATE,
            foreign_transport, foreign_records))

    (absent_g3=absent_g3, absent_records=absent_records,
        absent_transport=absent_transport,
        present_bundle_absent_local=present_bundle_absent_local,
        absent_bundle_present_local=absent_bundle_present_local,
        true_absence=true_absence,
        present_absent_admission=present_absent_admission,
        absent_present_admission=absent_present_admission,
        true_absence_admission=true_absence_admission,
        invalid_absence=invalid_absence, before=before, fixture=fixture)
end

function _r26_emit_v1_semantic_actual(matrix)
    actual = (schema=:vnext_t1_v1_semantic_matrix_r26,
        present_bundle_absent_local=
            _r26_v1_result_metadata(matrix.present_bundle_absent_local),
        absent_bundle_present_local=
            _r26_v1_result_metadata(matrix.absent_bundle_present_local),
        true_absence=_r26_v1_result_metadata(matrix.true_absence),
        present_absent_admission=
            _r26_v1_admission_metadata(matrix.present_absent_admission),
        absent_present_admission=
            _r26_v1_admission_metadata(matrix.absent_present_admission),
        true_absence_admission=
            _r26_v1_admission_metadata(matrix.true_absence_admission),
        invalid_absence=_r26_v1_result_metadata(matrix.invalid_absence))
    println("R26_V1_SEMANTIC_ACTUAL=", G.canonical_json(actual))
    flush(stdout)
    actual
end

function _r26_v1_inputs_unchanged(matrix)
    after = (present_transport=G.canonical_hash(matrix.fixture.transport),
        absent_transport=G.canonical_hash(matrix.absent_transport),
        present_declarations=G.canonical_hash(matrix.fixture.declarations),
        absent_declarations=G.canonical_hash(matrix.absent_records))
    after == matrix.before
end

function _r26_formal_diagnostic_contract_v3(diagnostic, fixture)
    success = (status=:ok, stage=:complete, exception_type=:none,
        message_digest=G.canonical_hash((status=:ok, stage=:complete,
            exception_type=:none)))
    matrix = _r26_v1_semantic_matrix(fixture)
    mismatch = matrix.present_bundle_absent_local
    invalid = Main.vnext_t1_projection_diagnostic_v1(
        _r26_v1_input(_T1_CANDIDATE, mismatch, fixture.transport))
    failure = (status=:internal_failure, stage=:input_gate,
        exception_type=:ArgumentError,
        message_digest=G.canonical_hash((status=:internal_failure,
            stage=:input_gate, exception_type=:ArgumentError)))
    diagnostic == success && mismatch.status === :fail_closed &&
        mismatch.resolution === :none &&
        mismatch.errors === (:record_bundle_canonical_mismatch,) &&
        mismatch.reasons === (:record_bundle_canonical_mismatch,) &&
        invalid == failure
end
