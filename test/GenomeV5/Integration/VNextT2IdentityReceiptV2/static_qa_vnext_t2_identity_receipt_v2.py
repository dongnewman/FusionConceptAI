from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
FILES = {
    "adapter": ROOT / "src/GenomeV5/UP2/VNextT2UP2AdapterV2.jl",
    "projection": ROOT / "src/GenomeV5/UP2/VNextT2IdentityReceiptProjectionV2.jl",
    "integration": ROOT / "src/GenomeV5/Integration/VNextT2IdentityReceiptIntegrationV2.jl",
}
ORACLE = Path(__file__).with_name("oracle_v1.json")
FIXTURE = Path(__file__).with_name("fixture_helpers.jl")

FROZEN_T1 = {
    "src/Contracts/CandidateStatePackageV5Next.jl":
        "7ca5b0bfed97193053f157c2b9650624b54ba206784fad348f77fd791652c3b0",
    "src/Contracts/CandidateStatePackageV5NextV2.jl":
        "effac2e603d2a1af30605b70310a634e3659ac487634e164ab049851795c4f89",
    "src/Contracts/VNextT1PackageBindingAdapterV2.jl":
        "a7c6ac7065d84a18e541aa5743dc908f8d5304ec5875726d22d615b2c171e943",
    "src/Contracts/VNextT1CandidateBindingV2.jl":
        "b507f8e4f31baea7fd2c4e5be5b5c7026382d69a92b6235f863bd67433c243b2",
    "src/GenomeV5/Integration/VNextDeclarationAuthorityRecheckLocalV2.jl":
        "d68c61c20d359fd70a364ad70545845e540435b8b052fecf1a9ac1ab64e2008e",
    "src/GenomeV5/Integration/VNextGenomeV5IntegrationV2.jl":
        "37fc25612cccf94044f736984f7f4a730c7f6f078898c80849981add27f3bc86",
    "src/GenomeV5/Integration/VNextGenomeV5Integration.jl":
        "d9824756a1287f6ed7a7df0c5d06a1523b109b52f12a91d36b9aab5ec05ba501",
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def code_without_comments_and_strings(source: str) -> str:
    out: list[str] = []
    i = 0
    block_depth = 0
    quote: str | None = None
    while i < len(source):
        if block_depth:
            if source.startswith("#=", i):
                block_depth += 1
                i += 2
            elif source.startswith("=#", i):
                block_depth -= 1
                i += 2
            else:
                out.append("\n" if source[i] == "\n" else " ")
                i += 1
            continue
        if quote:
            if source.startswith(quote, i):
                out.extend(" " * len(quote))
                i += len(quote)
                quote = None
            elif source[i] == "\\" and quote == '"':
                out.extend("  ")
                i += 2
            else:
                out.append("\n" if source[i] == "\n" else " ")
                i += 1
            continue
        if source.startswith("#=", i):
            block_depth = 1
            out.extend("  ")
            i += 2
        elif source[i] == "#":
            end = source.find("\n", i)
            if end < 0:
                out.extend(" " * (len(source) - i))
                i = len(source)
            else:
                out.extend(" " * (end - i))
                i = end
        elif source.startswith('"""', i):
            quote = '"""'
            out.extend("   ")
            i += 3
        elif source[i] == '"':
            quote = '"'
            out.append(" ")
            i += 1
        else:
            out.append(source[i])
            i += 1
    if quote or block_depth:
        raise AssertionError("unterminated Julia string or block comment")
    return "".join(out)


def delimiter_check(path: Path, source: str) -> None:
    code = code_without_comments_and_strings(source)
    stack: list[tuple[str, int]] = []
    pairs = {")": "(", "]": "[", "}": "{"}
    for index, char in enumerate(code):
        if char in "([{":
            stack.append((char, index))
        elif char in pairs:
            assert stack and stack[-1][0] == pairs[char], (
                f"delimiter mismatch in {path} at byte {index}"
            )
            stack.pop()
    assert not stack, f"unclosed delimiter in {path}: {stack[-1]}"


def ordered(source: str, tokens: list[str]) -> None:
    positions = [source.index(token) for token in tokens]
    assert positions == sorted(positions), (tokens, positions)


def main() -> int:
    for path in FILES.values():
        assert path.is_file(), path
    oracle = json.loads(ORACLE.read_text(encoding="utf-8"))
    assert oracle["consumer_order"] == ["E0", "GI1A", "E1", "E2", "UP2_N10"]
    sources = {name: path.read_text(encoding="utf-8")
               for name, path in FILES.items()}
    fixture = FIXTURE.read_text(encoding="utf-8")
    fixture_code = code_without_comments_and_strings(fixture)
    code = {name: code_without_comments_and_strings(source)
            for name, source in sources.items()}
    for name, path in FILES.items():
        delimiter_check(path, sources[name])
        assert not re.search(r"\bAny\b", code[name]), (name, "Any")
        assert not re.search(r"\bCandidateStatePackageV5\b", code[name]), (
            name, "legacy package")
        assert "default_operator_registry" not in code[name]
        assert not re.search(r"\b(include|eval)\s*\(", code[name])

    adapter_required = [
        "struct VNextT2UP2BoundInputV2",
        "function vnext_t2_up2_input_from_t1_v2",
        "function vnext_t2_up2_validate_input_v2",
        "function up2_candidate_physical_binding_from_a",
        "function gi1_authority_context_from_a",
        "function e1_authority_slot_from_a",
        "function e2_authority_slot_from_a",
        "witness.g1.declaration",
        "witness.g2.declaration.source",
        "witness.g3.declaration",
        "witness.children.binding_state",
        "witness.feedback.binding_links",
        "witness.children.binding_state.editable_body.links",
        "evidence_kind::Symbol=:synthetic_local",
        "formal_t1_accepted::Bool=false",
        "function vnext_t2_up2_input_from_t1_admission_v2",
        "verify_present_t0_local_parent_bundle_v1",
        "function _vnext_t2_t1_recheck_projection_v2",
        "function _vnext_t2_t1_recheck_output_projection_v2",
    ]
    for token in adapter_required:
        assert token in sources["adapter"], token
    ordered(sources["adapter"], [
        ":t2_preflight_schema_id_mismatch",
        ":t2_preflight_schema_version_mismatch",
        ":t2_preflight_profile_mismatch",
        ":t2_preflight_wire_shape_invalid",
        ":t2_preflight_candidate_ref_mismatch",
        ":t2_preflight_source_carrier_mismatch",
        ":t2_preflight_declaration_carrier_mismatch",
        ":t2_preflight_semantic_carrier_mismatch",
        ":t2_preflight_axis_mismatch",
        ":t2_preflight_scenario_mismatch",
        ":t2_preflight_t0_bundle_mismatch",
        ":t2_preflight_t0_recheck_mismatch",
        ":t2_preflight_child_mismatch",
        ":t2_preflight_feedback_mismatch",
        ":t2_preflight_parent_commitment_mismatch",
        ":t2_preflight_g3_authority_mismatch",
        ":t2_preflight_semantic_identity_mismatch",
        ":t2_preflight_package_hash_mismatch",
        ":t2_preflight_reload_binding_mismatch",
    ])

    projection_required = [
        "function n10_identity_projection_from_a",
        "function vnext_t2_validate_identity_receipt_v2",
        "vnext_t1_package_v2_manifest_hash(input.package)",
        "input.adapter.binding.receipt_hash",
        "_vnext_t2_g3_binding_identity_actual_v2",
        "_vnext_t2_reload_binding_authoritative_v2",
    ]
    for token in projection_required:
        assert token in sources["projection"], token
    for row in oracle["n10_rows"]:
        assert row in sources["projection"], row
    for reason in oracle["n10_attack_reasons"]:
        assert reason in sources["projection"], reason

    integration = sources["integration"]
    assert integration.count("up2_candidate_physical_binding_from_a(input)") == 1
    assert integration.count("gi1_authority_context_from_a(input, e0)") == 1
    assert integration.count("e1_authority_slot_from_a(input, context)") == 1
    assert integration.count("e2_authority_slot_from_a(input, context)") == 1
    assert integration.count("n10_identity_projection_from_a(input)") == 1
    ordered(integration, [
        "e0 = up2_candidate_physical_binding_from_a(input)",
        "context = gi1_authority_context_from_a(input, e0)",
        "e1 = e1_authority_slot_from_a(input, context)",
        "e2 = e2_authority_slot_from_a(input, context)",
        "projection = n10_identity_projection_from_a(input)",
        "ledger = _vnext_t2_receipt_ledger_v2",
    ])
    assert "VNextT2InvocationCountsV2(1, 1, 1, 1, 1, 0, 0, 0)" in integration
    assert ":t2_preflight_duplicate_invocation" in integration
    assert "VNextT2AttemptTraceV2" in integration
    assert "prior_ledger" in integration

    assert fixture_code.count("T2_G.vnext_t1_admit_v2(admission_input)") == 1
    assert sources["adapter"].count(
        "rebuilt_admission = vnext_t1_admit_v2(admission_input)") == 1
    assert "t1_admission_invocation_count=2" in fixture_code
    for token in (
            "status=recheck.status", "resolution=recheck.resolution",
            "accepted=recheck.accepted", "claim_ceiling=recheck.claim_ceiling",
            "errors=recheck.errors", "reasons=recheck.reasons",
            "prior_bundle_bytes=recheck.prior_bundle_bytes",
            "prior_bundle_sha256=recheck.prior_bundle_sha256",
            "declarations=output.declarations", "children=output.children",
            "feedback=output.feedback",
            "g3_children_deferred=output.g3_children_deferred"):
        assert token in sources["adapter"], token
    assert "T2_G.CandidateStatePackageV5NextV2(" not in fixture_code
    assert "T2_G.vnext_t2_up2_input_from_t1_admission_v2(" in fixture_code
    assert "expected_commitment=source.expected" in fixture
    assert "synthetic_software_acceptance_receipt_hash" in fixture
    assert "synthetic_candidate_admission_receipt_hash" in fixture

    for relative, expected in FROZEN_T1.items():
        actual = sha256(ROOT / relative)
        assert actual == expected, (relative, expected, actual)

    print("VNEXT_T2_IDENTITY_RECEIPT_V2_STATIC_QA=PASS")
    for name, path in FILES.items():
        print(f"{name}_sha256={sha256(path)}")
    print("frozen_t1_sources=7")
    print("formal_t2_accepted=false")
    return 0


if __name__ == "__main__":
    sys.exit(main())
