"""Build G1/G2/G3 schema locators from one active, verified UP1 snapshot.

This reports frozen source observations only. It does not query Git, attest a
trusted source, or establish candidate physical/engineering authority.
"""
function up4_r2_build_factory_locators(context::NativeGitReadCompatibilityV1.UP1FrozenSourceContextV1)
    identity = UP4_R2_IDENTITY
    context.candidate_ref == identity.candidate_ref.id ||
        throw(ArgumentError("UP1 snapshot candidate does not match authored UP4 R2 design"))
    context.scenario_id == identity.scenario_id ||
        throw(ArgumentError("UP1 snapshot scenario does not match authored UP4 R2 design"))

    frozen(path) = begin
        entry = NativeGitReadCompatibilityV1.frozen_source(context, path)
        entry === nothing && throw(ArgumentError("UP1 frozen input is missing: " * path))
        entry
    end
    candidate_dir = "benchmarks/candidate_designs/local-authored-up4-g123-20260928-r2"
    candidate_inputs = (
        design_identity=frozen(candidate_dir * "/design_identity.json"),
        scenario=frozen(candidate_dir * "/scenario.json"),
        identity=frozen(candidate_dir * "/identity.jl"),
        G1_design=frozen(candidate_dir * "/g1_source.jl"),
        G1_expressions=frozen(candidate_dir * "/native_mms_source_expressions.json"),
        G2_design=frozen(candidate_dir * "/g2_source.jl"),
        G3_design=frozen(candidate_dir * "/g3_source.jl"),
        G3_child_design=frozen(candidate_dir * "/g3_child_design_source.jl"),
        candidate_manifest=frozen(candidate_dir * "/manifest.json"),
        adapter_source=frozen(candidate_dir * "/factory_locators.jl"),
    )

    g1_path = G1_SOURCE_AUTHORITY_FACTORY_SOURCE_PATH_V1
    g2_path = G2_SOURCE_AUTHORITY_FACTORY_SOURCE_PATH_V1
    g1_source = frozen(g1_path)
    g2_source = frozen(g2_path)
    g1_ad45_path = G1_AD45_ENVELOPE_RELATIVE_PATH_V1
    g2_ad45_path = G2_AD45_ENVELOPE_RELATIVE_PATH_V1
    g1_ad45_path == g2_ad45_path ||
        throw(ArgumentError("G1/G2 AD45 envelope paths differ"))
    g1_ad45_sha = G1_AD45_ENVELOPE_SHA256_V1
    g2_ad45_sha = G2_AD45_ENVELOPE_SHA256_V1
    g1_ad45_sha == g2_ad45_sha ||
        throw(ArgumentError("G1/G2 AD45 envelope pins differ"))
    ad45 = frozen(g1_ad45_path)
    ad45.role == "binding_envelope" ||
        throw(ArgumentError("UP1 frozen AD45 input has the wrong role"))
    Digest256(bytes2hex(SHA.sha256(ad45.bytes))) == g1_ad45_sha ||
        throw(ArgumentError("UP1 frozen AD45 input hash differs from factory pin"))

    snapshot_head = "up1:" * context.snapshot_id
    no_git_observation = (:not_observed, :not_observed, :not_observed)
    g1_locator = G1IndependentSourceLocatorV1(context.source_root, snapshot_head,
        g1_path, g1_source.byte_count,
        Digest256(g1_source.sha256), no_git_observation[1], no_git_observation[2],
        no_git_observation[3], nothing, :up1_frozen_snapshot)
    g2_locator = G2IndependentSourceLocatorV1(context.source_root, snapshot_head,
        g2_path, g2_source.byte_count,
        Digest256(g2_source.sha256), no_git_observation[1], no_git_observation[2],
        no_git_observation[3], nothing, :up1_frozen_snapshot)
    g3_locator(scope) = begin
        path = _g3s_expected_source(scope)
        source = frozen(path)
        G3IndependentSourceLocatorV1(scope, context.source_root, snapshot_head,
            path, source.byte_count, Digest256(source.sha256),
            no_git_observation[1], no_git_observation[2],
            no_git_observation[3], nothing)
    end
    g3 = (realization=g3_locator(:realization),
        control=g3_locator(:control), binding=g3_locator(:binding),
        bundle=g3_locator(:bundle))
    g3_sources = (realization=frozen(_g3s_expected_source(:realization)),
        control=frozen(_g3s_expected_source(:control)),
        binding=frozen(_g3s_expected_source(:binding)),
        bundle=frozen(_g3s_expected_source(:bundle)))

    return (candidate_id=identity.candidate_id,
        candidate_ref=identity.candidate_ref, scenario_id=identity.scenario_id,
        snapshot_id=context.snapshot_id, manifest_sha256=context.manifest_sha256,
        G1=g1_locator, G2=g2_locator, G3=g3,
        audit_inputs=(candidate=candidate_inputs,
            schema=(G1=g1_source, G2=g2_source, G3=g3_sources), ad45=ad45),
        audit_scope=:candidate_input_pins_not_factory_or_formal_result_identity)
end
