"""Mechanical byte-exact scope witness; never edits source or old evidence."""
from pathlib import Path
import hashlib
import json
import difflib

ROOT = Path(__file__).resolve().parents[4]
OUT = ROOT / "docs/implementation/UP1-04A-VNEXT-T1/agent_local_r23_owned_deepcopy_delta04"
PRODUCT = ROOT / "src/Contracts/CandidateStatePackageV5Next.jl"
BEFORE = ROOT / "docs/implementation/UP1-04A-VNEXT-T1/agent_local_r18_astra_t1_closeout/product_before_04.jl"
HARNESS = ROOT / "test/GenomeV5/Integration/VNextT1V1R19/static_selection_harness.jl"
insertion = b"""
# This closed V1 family contains only recursively immutable value fields.
# Sharing preserves deepcopy value semantics; no mutable payload can alias.
# See the generic closure/native-copy/canonical parity evidence in R22/R22b.
@noinline Base.@nospecializeinfer function Base.deepcopy_internal(
        @nospecialize(x::CandidateStatePackageV5Next), stackdict::IdDict)
    x
end

"""
before, after = BEFORE.read_bytes(), PRODUCT.read_bytes()
assert after.count(insertion) == 1
assert after.replace(insertion, b"", 1) == before
suffix = b"semantic_view(x::CandidateStatePackageV5Next) ="
assert before[before.index(suffix):] == after[after.index(suffix):]
old_harness = (OUT / "r19_harness_before_pin_refresh.jl").read_bytes()
new_harness = HARNESS.read_bytes()
old_pin = b'54490, "8D11DAF91A34E5F0A3257ED13424956B479D0CED426C6F4AB749A7C4F769DF0B"'
new_pin = b'54870, "3FB79DCB4EF81D30FA299AE2D24165F9CD77C220CCB831B79796B0E6E3CAF95C"'
assert old_harness.count(old_pin) == new_harness.count(new_pin) == 1
assert old_harness.replace(old_pin, new_pin, 1) == new_harness
sha = lambda data: hashlib.sha256(data).hexdigest().upper()
receipt = {
    "product_before_sha256": sha(before), "product_after_sha256": sha(after),
    "product_before_bytes": len(before), "product_after_bytes": len(after),
    "only_exact_owned_method_insertion": True,
    "removing_inserted_bytes_restores_entire_preimage": True,
    "all_preexisting_dirty_bytes_unchanged": True,
    "suffix_from_package_semantic_view_unchanged": True,
    "r18_delta04_broad_suffix_flags": "false because those broad regions include this authorized insertion; exact byte reconstruction is the authoritative isolation proof",
    "harness_before_sha256": sha(old_harness), "harness_after_sha256": sha(new_harness),
    "harness_only_product_hash_and_size_pin_changed": True,
    "formal_T1": False,
}
with (OUT / "delta04_scope.json").open("x", encoding="utf-8") as stream:
    json.dump(receipt, stream, indent=2)
with (OUT / "r19_pin_refresh.patch").open("x", encoding="utf-8", newline="") as stream:
    stream.write("".join(difflib.unified_diff(
        old_harness.decode().splitlines(keepends=True),
        new_harness.decode().splitlines(keepends=True),
        fromfile="before/R19_static_selection_harness.jl",
        tofile="after/R19_static_selection_harness.jl")))
print(json.dumps(receipt))
