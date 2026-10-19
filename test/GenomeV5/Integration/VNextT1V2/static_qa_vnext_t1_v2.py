"""Static contract gate for the additive V2 T1 lane."""
from __future__ import annotations
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
OWNED = [
    ROOT / "src/GenomeV5/Integration/VNextDeclarationAuthorityRecheckLocalV2.jl",
    ROOT / "src/Contracts/CandidateStatePackageV5NextV2.jl",
    ROOT / "src/GenomeV5/Integration/VNextGenomeV5IntegrationV2.jl",
    ROOT / "src/Contracts/VNextT1PackageBindingAdapterV2.jl",
]
TEST = Path(__file__).with_name("vnext_t1_v2_same_chain_tests.jl")
TESTS = [
    TEST,
    Path(__file__).with_name("vnext_t1_v2_replay.jl"),
    Path(__file__).with_name("vnext_t1_v2_perf_probe.jl"),
    Path(__file__).with_name("static_qa_vnext_t1_v2.py"),
]
# Split literals so the self-scan does not report its own rule table.  The
# joined values are still exact and are applied to every owned test/probe.
FORBIDDEN = (
    "_ar_" + "local_snapshot",
    "vnext_t1_admit_" + "skeleton_v1",
    "_vnext_t1_" + "package(",
    "vnext_t1_package_binding_" + "adapter_v1",
    "vnext_declaration_authority_recheck_" + "local_v1",
    "Tuple(Vector{UInt8}(" + "codeunits(",
    "canonical_hash(" + "package)",
    "NTuple{N," + "UInt8}",
)
EXPECTED = {
    ROOT / "src/Contracts/CandidateStatePackageV5Next.jl": "18182801DFE14B9AE06F3240E71549DF026268F74ECC2188AAB7A0AF292976FA",
    ROOT / "src/Contracts/VNextT1PackageBindingAdapterV1.jl": "50A48E49633B238206FFF9210B4FB1B0528AA411584FCE7043393CF16ABC50D0",
    ROOT / "src/GenomeV5/Integration/VNextGenomeV5Integration.jl": "77E331E39619CAC34A1699A2C7C84237F312F413784004F9F1BFFADC1DED55A9",
}

def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()

def main() -> int:
    report = {"owned_files": {}, "forbidden": {}, "protected": {}, "status": "pass"}
    for path in OWNED + TESTS:
        text = path.read_text(encoding="utf-8")
        hits = [token for token in FORBIDDEN if token in text]
        report["owned_files"][str(path.relative_to(ROOT))] = {"exists": path.exists(), "bytes": path.stat().st_size}
        report["forbidden"][str(path.relative_to(ROOT))] = hits
        if hits:
            report["status"] = "fail"
    for path, expected in EXPECTED.items():
        actual = sha(path)
        report["protected"][str(path.relative_to(ROOT))] = {"expected": expected, "actual": actual, "match": actual == expected}
        if actual != expected:
            report["status"] = "fail"
    # Do not allow the versioned entry to be hidden behind the legacy entry.
    integration = (ROOT / "src/GenomeV5/Integration/VNextGenomeV5IntegrationV2.jl").read_text(encoding="utf-8")
    for required in ("vnext_t1_admit_v2", "VNextT1AdmissionInputV2", "parent_commitments", "g3_expected_commitment"):
        if required not in integration:
            report["status"] = "fail"
    print(json.dumps(report, indent=2, sort_keys=True))
    print("STATIC_QA_VNEXT_T1_V2_STATUS=" + report["status"].upper())
    return 0 if report["status"] == "pass" else 1

if __name__ == "__main__":
    raise SystemExit(main())
