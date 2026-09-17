"""Static QA for UP2-01-G1-DIFFUSION-V1; does not invoke Julia or DESC."""
from __future__ import annotations

import hashlib
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "src" / "GenomeV5" / "G1" / "DiffusionDeclarationV1.jl"
TEST = Path(__file__).with_name("diffusion_v1_contract_tests.jl")
FIXTURE = Path(__file__).with_name("diffusion_v1_fixture.json")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    source = SOURCE.read_text(encoding="utf-8")
    test = TEST.read_text(encoding="utf-8")
    fixture = FIXTURE.read_text(encoding="utf-8")
    required = (
        "G1DiffusionScalarFieldV1", "G1DiffusionCoefficientFieldV1",
        "G1DiffusionSourcePayloadV1", "G1DiffusionDiagonalAffineKFieldV1",
        "G1TypedGradV1", "G1TypedKApplyV1", "G1TypedDivV1",
        "terminal_deferred", "fail_closed", "g1_diffusion_edit_source",
        "g1_diffusion_source_hash_v1", "g1_diffusion_k_eval", "g1_diffusion_k_enclosure",
        "canonical_hash", "physical_evidence=false", "residual_sign=-1",
        "G1DiffusionAdmissionResultV1", "g1_diffusion_admit_v1",
        "g1_diffusion_admit_source_v1", "g1_diffusion_admit_k_v1",
        "g1_diffusion_admit_chain_v1", ":program_exception",
        ":unexpected_exception", "error_path", "_g1d_admit_v1_impl",
        "_g1d_admit_v1_fault_probe", "K_probe_point_malformed",
    )
    missing = [token for token in required if token not in source]
    if missing:
        raise SystemExit("missing source tokens: " + ", ".join(missing))
    if "Digest256(" in test or "repeat(" in test:
        raise SystemExit("test contains raw Digest256/repeated literal construction")
    if "occursin(" in source or "showerror" in source:
        raise SystemExit("admission classification must not inspect exception text")
    if "g1_diffusion_admit_v1(declaration::Any) = _g1d_admit_v1_impl(declaration, g1_diffusion_validate)" not in source:
        raise SystemExit("public admission must fix the production validator")
    if "K_probe_point_malformed" not in source or "_g1d_admission_program_exception(\"/K/probe_point\"" in source:
        raise SystemExit("malformed K probe must be fail-closed, not program_exception")
    source_payload_at = source.index("struct G1DiffusionSourcePayloadV1")
    declaration_at = source.index("struct G1DiffusionDeclarationV1")
    operator_at = source.index("struct G1DiffusionOperatorChainV1")
    if not source_payload_at < operator_at < declaration_at:
        raise SystemExit("source payload type must precede all typed declaration users")
    if source.count("struct G1DiffusionSourcePayloadV1") != 1:
        raise SystemExit("source payload type must have one definition")
    local_structs = {match.group(1): match.start()
                     for match in re.finditer(r"\bstruct\s+([A-Za-z_]\w*)", source)}
    for field in re.finditer(r"(?m)^\s*[A-Za-z_]\w*::([A-Za-z_]\w*)", source):
        field_type = field.group(1)
        owner_candidates = [name for name, at in local_structs.items() if at < field.start()]
        owner = max(owner_candidates, key=lambda name: local_structs[name], default=None)
        if owner is not None and field_type in local_structs and local_structs[field_type] > local_structs[owner]:
            raise SystemExit(f"forward typed field reference: {owner}::{field_type}")
    for token in ("positive declaration", "fail-closed", "source edit changes identity",
                  "program_fault", "program_exception", "unexpected_exception",
                  "K_probe_point_malformed"):
        if token not in test:
            raise SystemExit(f"missing test coverage marker: {token}")
    for token in ("missing_authoritative_source", "manufactured_solution_as_authority", "contract_only",
                  "source_hash_mismatch", "K_lower_bound_mismatch", "K_domain_out_of_bounds",
                  "malformed_K_probe_point_fail_closed", "expected_residual_sign_not_negative",
                  "grad_unit_mismatch", "program_exception_internal_fault_seam"):
        if token not in fixture:
            raise SystemExit(f"missing fixture negative/control token: {token}")
    print("static_qa=pass")
    print(f"source_sha256={sha256(SOURCE)}")
    print(f"test_sha256={sha256(TEST)}")
    print(f"fixture_sha256={sha256(FIXTURE)}")
    print("julia_or_desc_executed=false")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
