from __future__ import annotations

import hashlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f"missing {label}: {needle}")


expected_immutable = {
    ROOT / "test/GenomeV5/Integration/VNextT1V1R25/input_boundary_probe.jl":
        "F6C5CB9B15AAE76B14EFA49B7787D3A1A9F9C8B62A82BDAAD4F4B61F87348345",
    ROOT / "test/GenomeV5/Integration/vnext_t1_candidate_state_package_v5_next_formal_v2_tests.jl":
        "A1D590ED3BF7A125C3A90A36F509ED24D4A653BD74F7371FDBF36ABA3CFACE72",
}
for path, expected in expected_immutable.items():
    observed = sha256(path)
    if observed != expected:
        raise AssertionError(f"immutable source drift: {path}: {observed}")

package_v1 = (ROOT / "src/Contracts/CandidateStatePackageV5Next.jl").read_text(
    encoding="utf-8")
integration_v1 = (ROOT / "src/GenomeV5/Integration/VNextGenomeV5Integration.jl").read_text(
    encoding="utf-8")
recheck_v2 = (ROOT /
    "src/GenomeV5/Integration/VNextDeclarationAuthorityRecheckLocalV2.jl").read_text(
    encoding="utf-8")
integration_v2 = (ROOT /
    "src/GenomeV5/Integration/VNextGenomeV5IntegrationV2.jl").read_text(
    encoding="utf-8")
package_v2 = (ROOT / "src/Contracts/CandidateStatePackageV5NextV2.jl").read_text(
    encoding="utf-8")
binding_v2 = (ROOT / "src/Contracts/VNextT1CandidateBindingV2.jl").read_text(
    encoding="utf-8")

require(package_v1, "const VNextT1AdmissionRecheckInputV1 = Union{",
        "closed V1 input alias")
require(package_v1,
        "VNextAuthorityRecheckLocalResultV1{VNextAuthorityRecheckLocalTypedAbsentV1}",
        "typed-absence V1 member")
require(package_v1, "VNextAuthorityRecheckLocalResultV1{Nothing}",
        "fail-closed V1 member")
require(integration_v1, "Union{Nothing,VNextT1AdmissionRecheckInputV1}",
        "V1 public field boundary")
require(recheck_v2, "d isa VNextT0LocalAbsentDeclarationV1",
        "V2 absent declaration validation")
require(recheck_v2, "_vnext_ar_v2_absence_reasons", "V2 actual absence reasons")
require(integration_v2, "_vnext_t1_v2_recheck_envelope_error",
        "V2 closed envelope validator")
require(integration_v2, "(:t0_recheck_typed_absent,)",
        "V2 coherent absence branch")
require(integration_v2, "(:entry, :recheck, :upstream_fail_closed)",
        "V2 failure preservation branch")
require(package_v2, "recheck.status === :local_checked_present",
        "direct package constructor present-only guard")
require(binding_v2, "_VNEXT_T1_BINDING_WIRE_HASH_REQUIRED_REASONS_V2",
        "binding wire-dependent reason set")
require(binding_v2,
        "reason in _VNEXT_T1_BINDING_WIRE_HASH_REQUIRED_REASONS_V2",
        "binding receipt conditional wire invariant")

if "Any" in package_v1[package_v1.index("const VNextT1AdmissionRecheckInputV1"):][:400]:
    raise AssertionError("V1 admission alias widened to Any")

bundle_join = integration_v2.index("r.prior_bundle_sha256 == t.bundle_hash")
absence_branch = integration_v2.index("r.status === :typed_absent")
if bundle_join >= absence_branch:
    raise AssertionError("V2 absence is trusted before the transport/recheck bundle join")

print("R26_STATIC_QA_PASS checks=16 immutable=2")
