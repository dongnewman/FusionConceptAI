"""Static-only QA for the additive local-input T0 transport.

This script reads source/test/fixture only.  It never starts Julia, DESC,
providers, a mesh or a solver.
"""
from pathlib import Path
import hashlib
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "src" / "GenomeV5" / "Integration" / "VNextDeclarationTransportLocalV1.jl"
TEST = ROOT / "test" / "GenomeV5" / "Integration" / "vnext_declaration_transport_local_v1_tests.jl"
FIXTURE = ROOT / "docs" / "implementation" / "UP1-04A-VNEXT-T0" / "vnext_declaration_transport_local_v1_fixture.json"

def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def require(text: str, token: str, path: Path) -> None:
    if token not in text:
        raise AssertionError(f"missing {token!r} in {path}")

def _strip_julia_comments_and_strings(text: str) -> str:
    """Keep line structure while blanking strings and line/block comments."""
    out = []
    i = 0
    state = "code"
    block_depth = 0
    quote = ""
    while i < len(text):
        c = text[i]
        n = text[i + 1] if i + 1 < len(text) else ""
        nn = text[i + 2] if i + 2 < len(text) else ""
        if state == "code":
            if c == "#" and n == "=":
                state = "block_comment"
                block_depth = 1
                out.extend((" ", " "))
                i += 2
            elif c == "#":
                state = "line_comment"
                out.append(" ")
                i += 1
            elif c == '"':
                quote = '"""' if n == '"' and nn == '"' else '"'
                state = "string"
                out.extend(" " for _ in quote)
                i += len(quote)
            elif c == "'":
                quote = "'"
                state = "string"
                out.append(" ")
                i += 1
            else:
                out.append(c)
                i += 1
        elif state == "line_comment":
            if c == "\n":
                out.append(c)
                state = "code"
            else:
                out.append(" ")
            i += 1
        elif state == "block_comment":
            if c == "#" and n == "=":
                block_depth += 1
                out.extend((" ", " "))
                i += 2
            elif c == "=" and n == "#":
                block_depth -= 1
                out.extend((" ", " "))
                i += 2
                if block_depth == 0:
                    state = "code"
            else:
                out.append("\n" if c == "\n" else " ")
                i += 1
        else:  # string or character literal
            if quote == '"""' and text.startswith('"""', i):
                out.extend(" " for _ in quote)
                i += 3
                state = "code"
            elif quote == '"' and c == '"' and (i == 0 or text[i - 1] != "\\"):
                out.append(" ")
                i += 1
                state = "code"
            elif quote == "'" and c == "'" and (i == 0 or text[i - 1] != "\\"):
                out.append(" ")
                i += 1
                state = "code"
            else:
                out.append("\n" if c == "\n" else " ")
                i += 1
    return "".join(out)

def _assert_g_alias_layout(test: str) -> None:
    code = _strip_julia_comments_and_strings(test)
    aliases = list(re.finditer(
        r"(?m)^\s*const\s+G\s*=\s*FusionConceptAI\s*$", code))
    if len(aliases) != 1:
        raise AssertionError(f"expected exactly one executable G alias, found {len(aliases)}")
    first_g_use = re.search(r"\bG\.", code)
    if first_g_use is None or aliases[0].start() > first_g_use.start():
        raise AssertionError("executable G alias must precede first G. use")

def main() -> int:
    source = SOURCE.read_text(encoding="utf-8")
    test = TEST.read_text(encoding="utf-8")
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    _assert_g_alias_layout(test)
    try:
        _assert_g_alias_layout(test + "\nconst G = FusionConceptAI\n")
    except AssertionError as exc:
        if "exactly one executable G alias" not in str(exc):
            raise AssertionError("G alias duplicate mutation was not classified structurally") from exc
    else:
        raise AssertionError("G alias duplicate mutation was not rejected")
    if fixture.get("authority") is not False:
        raise AssertionError("fixture must not be an authority")
    required_negative_controls = {
        "g2_typed_source_hash_tamper",
        "g2_self_consistent_typed_source_fabrication",
        "terminal_deferred_resolution",
    }
    if not required_negative_controls.issubset(set(fixture.get("negative_controls", []))):
        raise AssertionError("fixture is missing R16 typed-source or deferred-resolution controls")
    source_paths = fixture.get("source_paths", [])
    if source_paths[2] != "src/GenomeV5/G3/G3SourceFeedbackLawV1.jl":
        raise AssertionError("fixture G3 source path drifted from declaration source")
    for path in source_paths:
        if not (ROOT / path).is_file():
            raise AssertionError(f"fixture source path missing: {path}")
    for layer, paths in fixture.get("factory_dependencies", {}).items():
        for path in paths:
            if not (ROOT / path).is_file():
                raise AssertionError(f"factory dependency missing for {layer}: {path}")
    for token in (
        "VNextT0LocalBytesV1", "VNextT0LocalSourceLocatorV1",
        "observed_head", "head_path_status", "working_tree_path_status",
        "working_tree_status", "head_blob_sha256", "repository_root",
        "VNextT0LocalSemanticBodyV1", "VNextT0LocalFactoryReceiptV1",
        "VNextT0LocalG2CandidateEnvelopeV1", "candidate_envelope",
        "VNextT0LocalDeclarationReceiptV1", "VNextT0LocalChildPresentV1",
        "VNextT0LocalChildAbsentV1", "VNextT0LocalPresentDeclarationV1",
        "VNextT0LocalAbsentDeclarationV1", "VNextT0LocalTransportV1",
        "VNextT0LocalAdmissionV1", "source_bytes_hash_mismatch",
        "declaration_bytes_hash_mismatch", "source_locator_hash_mismatch",
        "_vnl_t0_locator_bytes", "realpath", "source_locator.source_ref",
        "source_uri_ref_mismatch", "semantic_body_bytes_mismatch",
        "VNEXT_T0_LOCAL_AXIS_IDS_V1", "axes_identity_or_order_invalid",
        "vnext_t0_local_source_edit_v1", "vnext_t0_local_bundle_hash_recompute_v1",
        "source_identity_hash", "declaration_identity_hash",
        "feedback_target_ref_mismatch", "child_identity_hash_mismatch",
        "factory_result_hash", "factory_result_type_invalid", "factory_api",
        "factory_result_candidate_mismatch", "factory_result_source_ref_mismatch",
        "factory_result_status_mismatch",
        "factory_result_source_content_mismatch",
        "factory_result_source_ref_mismatch", "factory_result_declaration_ref_mismatch",
        "_vnl_t0_validate_g3_feedback_projection_v1",
        "_vnl_t0_g3_feedback_semantic_rebind_v1",
        "_vnl_t0_g3_rebind_authority_v1",
        "g3_feedback_authority_status_not_rebindable",
        "g3_feedback_authority_materialized_without_fresh_receipt",
        "g3_feedback_upstream_candidate_projection_mismatch",
        "g3_feedback_target_candidate_projection_mismatch",
        "present_g3_child_requires_fresh_receipt",
        "_vnl_t0_rebind_absent_child_v1", "_vnl_t0_rebind_feedback_item_v1",
        "feedback_target_ref_ambiguous", "feedback_target_ref_unknown",
        "source_match", "declaration_match", "feedback_body_hash_mismatch",
        "factory_result_declaration_hash_mismatch", "factory_receipt_bytes_mismatch",
        "factory_result_contract_mismatch",
        "factory_result_axes_invalid", "factory_result_axes_duplicate",
        "_vnl_t0_factory_result_bytes", "_vnl_t0_factory_pair",
        "VNextT0LocalFactoryResultV1",
        "vnext_t0_local_normalize_factory_result_v1",
        "upstream_receipt_bytes", "upstream_receipt_hash",
        "source_size", "content_identity",
        "child_id", "child_layer_invalid", "child_source_uri_mismatch",
        "vnext_t0_local_rebuild_after_source_edit_v1", "new_source_locator",
        "_vnl_t0_semantic_rebind_candidate", "G1 semantic body shape is incomplete",
        "G1 semantic rebind requires a fresh source_ref",
        "G1 semantic body source payload candidate binding is stale",
        "G1 semantic body source payload source binding is stale",
        "G1 semantic body u source binding is stale",
        "G1 semantic body K source binding is stale",
        "G1 semantic body f source binding is stale",
        "G1 semantic body source_version must be typed",
        "G1 semantic body source hash is stale",
        "G1 semantic body declaration is not rebindable",
        "old_validation_status, old_validation_errors = g1_diffusion_validate(old_declaration)",
        "G1DiffusionSourcePayloadV1(candidate, source_ref",
        "fresh_source_hash = g1_diffusion_source_hash_v1(fresh_payload)",
        "g1_diffusion_validate(fresh_declaration)",
        "source_payload=fresh_payload",
        "G2 semantic body shape is incomplete", "G2 semantic rebind requires a fresh source_ref",
        "G2 semantic body candidate_envelope must be typed",
        "G2 semantic body source must be typed", "G2 semantic body contract_ref must be typed",
        "G2 semantic body contract_ref is not the expected G2 contract",
        "G2 semantic body envelope/source ref mismatch",
        "G2 semantic body envelope/source hash mismatch",
        "G2 semantic body source candidate/contract domains are confused",
        "G2 semantic body typed source hash is stale",
        "G2 semantic body schema hash is stale",
        "G2 semantic body canonicalization hash is stale",
        "G2 semantic body profile hash is stale",
        "G2 semantic body declaration hash is stale",
        "fresh_source = g2mb_source_v1(source_ref, source.source_version, contract_ref",
        "fresh_declaration = g2mb_declaration_v1(contract_ref, fresh_source)",
        "fresh_envelope = VNextT0LocalG2CandidateEnvelopeV1(candidate, contract_ref",
        "declaration_hash=fresh_declaration.declaration_hash",
        "factory_builder", "fresh source edit requires an explicit factory_builder",
        "source edit rebuild requires fresh factory_builder",
        "factory_builder must return (factory_result, declaration_factory_result)",
        "factory_builder returned unnormalized factory_result",
        "factory_builder source binding mismatch",
        "factory_builder source bytes binding mismatch",
        "factory_builder locator binding mismatch",
        "factory_builder_fail_closed",
        "_vnl_t0_rebuild_after_source_edit_impl_v1",
        "factory_result_source_size_mismatch",
        "factory_result_id_mismatch", "factory_result_version_mismatch",
        "factory_result_axes_mismatch", "factory_result_locator_provenance_mismatch",
        "factory_result_locator_root_mismatch", "factory_result_locator_head_mismatch",
        "factory_result_locator_path_mismatch", "factory_result_locator_head_blob_mismatch",
        "factory_result_outer_axes_mismatch", "factory_result_locator_mismatch",
        "factory_axes", "factory_result.axes",
        "declaration hash does not cover declaration bytes",
        "factory_result_candidate_envelope_invalid",
        "factory_result_typed_source_invalid",
        "factory_result_typed_source_binding_invalid",
        "factory_result_typed_declaration_mismatch",
        "factory_result_declaration_content_mismatch", "factory_dependency_missing",
        "locator_provenance", "isolated_test_fixture",
        "candidate_ref=child.candidate_ref", "layer=child.layer",
        "child_id == String(kind)", "receipt_candidate_mismatch", "foreign_candidate", "layer_set_invalid",
        "child_factory_receipt_hash_mismatch",
        "terminal_deferred", "fail_closed", "canonical_hash", "SHA.sha256",
        "sort!(collect(declarations)", "sort!(collect(children)",
    ):
        require(source, token, SOURCE)
    for token in (
        "source_bytes_hash_mismatch", "foreign_candidate", "layer_set_invalid",
        "stale-source-claim", "feedback_target_ref_mismatch", "child_body_hash_mismatch",
        "tampered-content", "child_locator_bytes_mismatch", "symlink(",
        "vnext_t0_local_source_edit_v1", "vnext_t0_local_bundle_hash_recompute_v1",
        "vnext_t0_local_rebuild_after_source_edit_v1",
        "G.g1_diffusion_declaration_v1", "G.g2mb_declaration_v1", "G.g3_sf_declaration_v1",
        "G.G1DiffusionSourcePayloadV1(candidate, source, \"local-g1-source-v1\", u, k, f)",
        "payload.candidate_ref == candidate", "payload.source_ref == source",
        "payload.u.source_ref == source", "payload.K.source_ref == source",
        "payload.f.source_ref == source",
        "G.G1_DIFFUSION_CLOSURE_ID_V1", "G.G1_DIFFUSION_PROFILE_VERSION_V1",
        "G.G1_DIFFUSION_APPLICABILITY_ID_V1", "declaration.closure_ref == closure_ref",
        "declaration.applicability_ref == applicability_ref",
        "g1_source_authority_factory_v1", "g2_source_authority_factory_v1", "G.g3_source_authority_factory_v1",
        "_t0l_factory_result", "_t0l_factory_builder", "_t0l_expect_code",
        "_t0l_factory_locator", "G1IndependentSourceLocatorV1",
        "G2IndependentSourceLocatorV1", "G3IndependentSourceLocatorV1",
        "factory_result_candidate_mismatch", "factory_result_source_ref_mismatch",
        "factory_result_id_mismatch", "factory_result_version_mismatch",
        "factory_result_axes_mismatch", "factory_result_declaration_content_mismatch",
        "stale_result", "stale_admission", "factory_result_content_identity_mismatch",
        "tampered_locator", "tampered_admission", "factory_result_locator_provenance_mismatch",
        "wrong-child-key",
        "G3SourceFeedbackLawV1.jl", "RealizationGenomeV5.jl", "g2-fresh-candidate-envelope-mismatch",
        "ControlGenomeV5.jl", "CoupledRealizationControlBindingV2.jl",
        "VNextT0LocalChildAbsentV1", "terminal_deferred", "candidate_identity_created=false",
        "tampered-content", "variant=true", "g3_feedback_body_source_ref_mismatch",
        "source_id = \"local-g3-source\"", "source_id,owner,a1", "source_id,owner,a2",
        "target.source_id == source_id", "target.source_id == declaration.source_id",
        "@test a.errors == ()", "a.status === :valid && a.transport !== nothing",
        "b.status === :valid && b.transport !== nothing",
        "source_path", "symlink", "@test_throws ArgumentError", "G.canonical_hash(one) == G.canonical_hash(two)",
        "fresh source edit rebuilds all declarations with honest deferred children",
        "old_identity_attempt", "candidate_identity_created == false",
        "accepted === false", "VNEXT_T0_LOCAL_JULIA_OR_DESC_EXECUTED=false",
        "G3SourceFeedbackLawV1.jl",
        "@test b.errors == ()", "@test b.status === :valid",
        "@test b.accepted === false", "@test b.claim_ceiling === :contract_only",
        'local T0 R20c G3 feedback projection is strict and deterministic',
        "actual/materialized authority", "present_g3_child_requires_fresh_receipt",
        "mapped_source.target_ref", "mapped_declaration.target_ref",
        "G3 feedback projection", "status in (:missing, :historical_absent)",
        "function _t0l_feedback(id, target_ref; target_layer=nothing",
        "feedback target_layer must be G1 or G2",
        "feedback target_layer does not match target id",
        "function _t0l_rekey_present(record, source_ref, declaration_ref)",
        "fresh_g1_source", "fresh_g2_declaration",
        "@test fresh_declarations[1].source_ref != old_declarations[1].source_ref",
        "@test fresh_declarations[2].declaration_ref != old_declarations[2].declaration_ref",
        'target_layer=:G1', 'target_layer=:G2',
        'target_layer=:G3', 'r20c-stale-feedback-body-hash',
        "feedback_layer_invalid",
        'ambiguous_ref = G.QualifiedRefV1("local://g1/ambiguous-r20c", "v1")',
        "feedback_target_ref_ambiguous",
        "@test b.resolution === :terminal_deferred",
        "@test a.resolution === :terminal_deferred",
        "@test :g3_child_terminal_deferred in a.gaps",
        "@test :g3_child_terminal_deferred in b.gaps",
        "@test rebuilt.admission.resolution === :terminal_deferred",
        "@test :g3_child_terminal_deferred in rebuilt.admission.gaps",
        '@testset "local T0 R20a G1 nested semantic rebind" begin',
        "old_candidate_payload", "r20a-stale-source-hash", "r20a-stale-input-hash",
        "r20a-stale-nested-candidate",
        'stale_ref = G.QualifiedRefV1("local://g1/r20a-stale-" * String(field), "v1")',
        "@test_throws ArgumentError G._vnl_t0_semantic_rebind_candidate",
        "@test body.source_hash == G.g1_diffusion_source_hash_v1(payload)",
        "@test body.u.source_ref == fresh_source", "@test body.K.source_ref == fresh_source",
        "@test body.f.source_ref == fresh_source",
        "@test G.g1_diffusion_validate(fresh_declaration) == (:valid, ())",
        "@test rebound.bytes.bytes == rebound_again.bytes.bytes",
        "for field in (:u, :K, :f)",
        "_vnl_t0_rebuild_after_source_edit_impl_v1",
        "G._vnl_t0_edit_ref(\n        declarations[1].source_ref, edited_source.sha256, :source)",
        "legacy_edited_source_ref", "@test edited_source_ref != legacy_edited_source_ref",
        "@error \"fresh source edit internal rebuild diagnostic failed\" exception=(err, catch_backtrace())",
        "@test internal_rebuild !== nothing",
        "@test rebuilt.admission.errors == ()",
        "@test rebuilt.admission.transport !== nothing",
        "if rebuilt.admission.status === :valid && rebuilt.admission.errors == () &&",
        '@testset "g2_typed_source_hash_tamper" begin',
        '@testset "g2_self_consistent_typed_source_fabrication" begin',
        "tampered-g2-typed-source-hash", "typed-source-hash-tamper",
        "self-consistent-typed-source", "fake_admission",
        ":factory_result_typed_declaration_mismatch",
        ":factory_result_source_content_mismatch in tampered_admission.errors",
        '@testset "local T0 R20b G2 typed source and envelope semantic rebind" begin',
        "r20b-stale-typed-source-ref", "r20b-stale-source-hash",
        "r20b-envelope-source-mismatch", "r20b-contract-domain-confusion",
        '"r20b-stale-" * String(field)',
        "@test body.source.candidate_ref == body.contract_ref",
        "@test body.candidate_envelope.source_hash == body.source.source_hash",
        "@test body.declaration_hash == fresh_declaration.declaration_hash",
    ):
        require(test, token, TEST)
    if 'G.G1DiffusionSourcePayloadV1(source, "local-g1-source-v1", u, k, f)' in test:
        raise AssertionError("legacy five-argument G1 payload construction remains")
    if 'G.QualifiedRefV1("local://g1/closure", "v1")' in test:
        raise AssertionError("G1 local fake closure ref remains")
    if '"local-g3",owner,a1' in test or '"local-g3",owner,a2' in test:
        raise AssertionError("G3 feedback targets still use a source id different from the declaration")
    forbidden = ("include(\"Contracts/CandidateStatePackageV5.jl\")", "default_operator_registry(",
                 "run(`julia", "run(`desc")
    for token in forbidden:
        if token in source:
            raise AssertionError(f"forbidden execution/integration token {token!r}")
    require(source, "axis.version == VNEXT_T0_LOCAL_AXIS_VERSION_V1", SOURCE)
    if 'axis.version == "v5"' in source:
        raise AssertionError("local T0 axis validator still contains v5")
    require(test, 'VNEXT_T0_LOCAL_AXIS_IDS_V1[i], "v1"', TEST)
    g2_binding_start = source.index("\n    if r.factory_api === :G2")
    g2_binding_end = source.index("\n    elseif r.factory_api === :G3", g2_binding_start)
    g2_binding = source[g2_binding_start:g2_binding_end]
    for token in ("typed_source isa G2MBSourceV1", "typed_source.source_ref == r.source_ref",
                  "typed_source.candidate_ref == r.contract_ref",
                  "envelope.source_hash == typed_source.source_hash",
                  "typed_declaration = g2mb_declaration_v1(r.contract_ref, typed_source)",
                  "typed_declaration_bytes == r.declaration_bytes.bytes",
                  "factory_result_typed_declaration_mismatch"):
        require(g2_binding, token, SOURCE)
    if "envelope.source_hash == r.source_bytes.sha256" in g2_binding:
        raise AssertionError("G2 envelope source hash is incorrectly compared with source file bytes")
    r20b_start = source.index("    # R20b: G2 carries two candidate identity domains")
    r20b_end = source.index("    rebound = merge(body.body, (candidate_ref=candidate,))", r20b_start)
    r20b = source[r20b_start:r20b_end]
    for forbidden in ("g2_source_authority_factory_v1", "run(`", "desc"):
        if forbidden in r20b:
            raise AssertionError(f"R20b semantic rebind contains forbidden runtime call/token {forbidden!r}")
    if fixture.get("version") != "v1" or any("v5" in str(x) for x in fixture.get("axes", [])):
        raise AssertionError("fixture axis/version contract is not v1")
    if set(fixture.get("factory_dependencies", {})) != {"G1", "G2", "G3"}:
        raise AssertionError("fixture must enumerate all three factory dependencies")
    expected_g3_paths = {
        "src/GenomeV5/G3/G3SourceFeedbackLawV1.jl",
        "src/GenomeV5/G3/RealizationGenomeV5.jl",
        "src/GenomeV5/G3/ControlGenomeV5.jl",
        "src/GenomeV5/G3/CoupledRealizationControlBindingV2.jl",
    }
    if not expected_g3_paths.issubset(set(source_paths)):
        raise AssertionError("fixture must enumerate feedback and all three G3 child sources")
    rebind = source[source.index("function _vnl_t0_rebind_record"):source.index('"""Rebind a source edit', source.index("function _vnl_t0_rebind_record"))]
    if "factory_api=x.factory_receipt.factory_api" not in rebind or \
       "factory_result::VNextT0LocalFactoryResultV1=x.factory_receipt.factory_result" not in rebind or \
       "factory_result=nothing" in rebind:
        raise AssertionError("rebind does not preserve a real factory api/result")
    for call in (
        "g1_source_authority_factory_v1(nothing",
        "g2_source_authority_factory_v1(nothing",
    ):
        if call in test:
            raise AssertionError(f"present test still uses typed-absent factory input: {call}")
    if "factory_results=" in test or "declaration_factory_results=" in test:
        raise AssertionError("source-edit test still accepts old result tuples")
    rebuild_start = source.index("function _vnl_t0_rebuild_after_source_edit_impl_v1")
    rebuild_end = source.index('"""Public source-edit boundary', rebuild_start)
    rebuild = source[rebuild_start:rebuild_end]
    require(rebuild, "present_g3_child_requires_fresh_receipt", SOURCE)
    require(rebuild, "_vnl_t0_rebind_absent_child_v1", SOURCE)
    require(rebuild, "_vnl_t0_rebind_feedback_item_v1", SOURCE)
    if "VNextT0LocalChildPresentV1(child.kind, fresh_candidate" in rebuild:
        raise AssertionError("source-edit rebuild still blindly swaps candidate on present G3 children")
    mapping_start = source.index("function _vnl_t0_rebind_feedback_item_v1")
    mapping_end = source.index("function vnext_t0_local_bundle_hash_recompute_v1", mapping_start)
    mapping = source[mapping_start:mapping_end]
    for token in ("source_match", "declaration_match", "feedback_target_ref_ambiguous",
                  "feedback_target_ref_unknown", "canonical_hash(body)"):
        require(mapping, token, SOURCE)
    g3_rebind_start = source.index("function _vnl_t0_g3_feedback_semantic_rebind_v1")
    g3_rebind_end = source.index("function _vnl_t0_bundle_body_v1", g3_rebind_start)
    g3_rebind = source[g3_rebind_start:g3_rebind_end]
    for token in ("g3_sf_validate_v1",
                  "feedback_targets=fresh_targets", "upstream_authority=fresh_authorities"):
        require(g3_rebind, token, SOURCE)
    if "occursin(" in source:
        raise AssertionError("factory binding must not use text occursin fallback")
    builder_start = test.index("function _t0l_factory_builder")
    builder_end = test.index("function _t0l_present", builder_start)
    builder = test[builder_start:builder_end]
    if "_t0l_factory_result(" in builder:
        raise AssertionError("fresh builder still reuses the historical factory helper")
    for token in ("G.g1_source_authority_factory_v1", "G.g2_source_authority_factory_v1",
                  "G.g3_sf_declaration_v1"):
        require(builder, token, TEST)
    for forbidden in ("factory_result::Any", "nameof(typeof", "factory_api=:unknown",
                     "factory_result=nothing"):
        if forbidden in source:
            raise AssertionError(f"closed factory evidence still contains {forbidden!r}")
    print(json.dumps({
        "record_kind": "AD-30_T0_local_static_qa",
        "status": "pass",
        "accepted": False,
        "claim_ceiling": "contract_only",
        "screen_only": True,
        "r01_r10_credit": False,
        "julia_executed": False,
        "desc_executed": False,
        "source_sha256": sha256(SOURCE),
        "test_sha256": sha256(TEST),
        "fixture_sha256": sha256(FIXTURE),
        "fixture_authority": False,
    }, sort_keys=True))
    return 0

if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, OSError, UnicodeError, json.JSONDecodeError) as exc:
        print(f"static_qa_error={exc}", file=sys.stderr)
        raise SystemExit(1)
