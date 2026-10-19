# R18 versioned test-contract checks. Production types and admission are not
# modified. These functions return real conjunctions to the two original
# lexical @test targets; no original assertion is replaced by a constant.

function _r18_formal_diagnostic_contract_v2(diagnostic, fixture)
    success = (status=:ok, stage=:complete, exception_type=:none,
        message_digest=G.canonical_hash((status=:ok, stage=:complete,
            exception_type=:none)))

    # This is exactly the existing "typed absence fails closed" fixture from
    # the frozen test, not a synthetic diagnostic-only shortcut.
    absent_g3 = G.VNextT0LocalAbsentDeclarationV1(:G3, _T1_CANDIDATE,
        :missing_material, :terminal_deferred)
    absent_recheck = G.vnext_declaration_authority_recheck_local_v1(
        G.VNextAuthorityRecheckLocalInputV1(_T1_CANDIDATE,
            fixture.transport, (fixture.declarations[1], fixture.declarations[2], absent_g3)))
    invalid = Main.vnext_t1_projection_diagnostic_v1(_t1_input(fixture;
        t0=absent_recheck))
    failure = (status=:internal_failure, stage=:input_gate,
        exception_type=:ArgumentError,
        message_digest=G.canonical_hash((status=:internal_failure,
            stage=:input_gate, exception_type=:ArgumentError)))
    diagnostic == success && absent_recheck.status === :typed_absent &&
        absent_recheck.resolution === :terminal_deferred && invalid == failure
end

function _r18_formal_factory_contract_v2(declaration, fixture)
    source = only(filter(d -> d.layer === declaration.layer,
        fixture.transport.declarations))
    original_receipt = source.factory_receipt
    original_result = original_receipt.factory_result
    projected = declaration.factory_receipt

    # Independent field projection assembled from the original T0 receipt.
    # Reusing projected.bytes here is sound only with the explicit full byte
    # equality and SHA joins below; no production projection helper is called.
    expected_projection = (kind=:factory, bytes=projected.bytes,
        candidate_ref=original_receipt.candidate_ref,
        layer=original_receipt.layer, source_ref=original_receipt.source_ref,
        declaration_ref=original_receipt.declaration_ref,
        axes=original_receipt.axes, factory_axes=original_receipt.factory_axes,
        status=original_receipt.status, factory_api=original_receipt.factory_api,
        factory_result_hash=original_receipt.factory_result_hash)

    declaration.contract_identity.contract_ref == original_result.contract_ref &&
        projected.factory_result_hash == original_receipt.factory_result_hash &&
        projected.factory_result_hash == G.canonical_hash(original_result) &&
        projected.candidate_ref == source.candidate_ref == declaration.candidate_ref &&
        projected.layer === source.layer === declaration.layer &&
        projected.source_ref == source.source_ref == declaration.source_ref &&
        projected.declaration_ref == source.declaration_ref == declaration.declaration_ref &&
        projected.bytes.bytes == Tuple(original_receipt.bytes.bytes) &&
        projected.bytes.sha256 == original_receipt.bytes.sha256 &&
        projected.bytes.sha256 == G._vnext_t1_sha(original_receipt.bytes.bytes) &&
        G.canonical_hash(projected) == G.canonical_hash(expected_projection)
end
