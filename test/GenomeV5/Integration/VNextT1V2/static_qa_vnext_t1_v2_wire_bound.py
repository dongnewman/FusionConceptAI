"""Static QA for the R11b wire-bound V2 package successor."""

from pathlib import Path
import hashlib
import json


ROOT = Path(__file__).resolve().parents[4]
PACKAGE = ROOT / "src/Contracts/CandidateStatePackageV5NextV2.jl"
CHAIN = ROOT / "test/GenomeV5/Integration/VNextT1V2/vnext_t1_v2_same_chain_tests.jl"
REPLAY = ROOT / "test/GenomeV5/Integration/VNextT1V2/vnext_t1_v2_wire_bound_replay.jl"


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f"missing {label}: {needle}")


package = PACKAGE.read_text(encoding="utf-8")
chain = CHAIN.read_text(encoding="utf-8")
replay = REPLAY.read_text(encoding="utf-8")

require(package, '"digest-manifest-wire-bound-v2"', "canonicalization successor")
require(package, '"closed-no-legacy-digest-manifest-wire-bound-v2"', "profile successor")
require(package, "wire_sha256=wire.sha256", "semantic wire digest")
require(package, "wire_byte_length=length(copy_bytes(wire))", "semantic wire length")
require(package, "wire_sha256=package.wire.sha256", "package wire digest")
require(package, "wire_byte_length=length(copy_bytes(package.wire))", "package wire length")
require(package, "expected_wire = _vnext_ar_v2_carrier(transport)", "current transport wire recomputation")
require(package, "copy_bytes(wire) == copy_bytes(expected_wire)", "exact materialized wire comparison")
require(package, "isempty(copy_bytes(wire))", "constructor empty-wire guard")
require(package, "Digest256(repeat(\"0\", 64))", "all-zero digest guard")
require(package, "package.wire.sha256 == _vnext_ar_v2_sha(copy_bytes(package.wire))", "validator self-hash guard")
require(package, "package.status === :prepared_not_executed", "fixed lifecycle status")
require(package, "package.resolution === :terminal_deferred", "fixed lifecycle resolution")
require(package, "package.accepted === false", "fixed lifecycle acceptance")
require(package, "package.claim_ceiling == VNEXT_T1_PACKAGE_CLAIM_CEILING_V2", "fixed lifecycle ceiling")
if "package.wire.sha256 == package.bundle_hash" in package or "wire.sha256 == transport.bundle_hash" in package:
    raise AssertionError("R11b must not equate carrier SHA with transport bundle hash")

for needle, label in (
    ("R11B_FULL_RECOMPUTE_IS_NEW_IDENTITY=PASS", "recomputed identity boundary"),
    (":wire_empty", "empty-wire negative"),
    (":wire_hash_zero", "all-zero negative"),
    (":semantic_identity_mismatch", "foreign-wire negative"),
    (":canonicalization_version_mismatch", "stale canonicalization negative"),
    (":profile_version_mismatch", "stale profile negative"),
    (":status_conflict", "status negative"),
    (":resolution_conflict", "resolution negative"),
    (":accepted_conflict", "accepted negative"),
    (":claim_ceiling_conflict", "claim ceiling negative"),
):
    require(chain, needle, label)

require(replay, "agent_local_r11_wire_bound_package", "new replay artifact root")
require(replay, "agent_local_r9_g3_shape_guard", "historical R9 artifact")
require(replay, "agent_local_r7_negative_coverage", "historical R8 artifact")
require(replay, ":canonicalization_version_mismatch", "historical profile rejection")

protected = {
    "src/FusionConceptAI.jl",
    "src/GenomeV5/Integration/VNextDeclarationAuthorityRecheckLocalV2.jl",
    "src/GenomeV5/Integration/VNextGenomeV5IntegrationV2.jl",
    "src/Contracts/VNextT1PackageBindingAdapterV2.jl",
}
for path in protected:
    if not (ROOT / path).exists():
        raise AssertionError(f"protected path missing: {path}")

print("R11B_STATIC_QA=PASS")
print("R11B_PACKAGE_SHA256=" + hashlib.sha256(PACKAGE.read_bytes()).hexdigest())
print("R11B_CHAIN_SHA256=" + hashlib.sha256(CHAIN.read_bytes()).hexdigest())
print("R11B_REPLAY_SHA256=" + hashlib.sha256(REPLAY.read_bytes()).hexdigest())
print(json.dumps({"actual_model_route": "unavailable", "protected_scope": sorted(protected)}))
