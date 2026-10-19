"""Record only R18's delta against the frozen dirty baseline, never stage it."""
from pathlib import Path
import difflib
import hashlib
import json

ROOT = Path(__file__).resolve().parents[4]
EVIDENCE = ROOT / "docs/implementation/UP1-04A-VNEXT-T1/agent_local_r18_astra_t1_closeout"
REL = "src/Contracts/CandidateStatePackageV5Next.jl"
before = (EVIDENCE / "before" / REL).read_bytes()
after = (ROOT / REL).read_bytes()
delta = "".join(difflib.unified_diff(before.decode().splitlines(keepends=True),
                                  after.decode().splitlines(keepends=True),
                                  fromfile="frozen-dirty-baseline/" + REL,
                                  tofile="r18/" + REL))
with (EVIDENCE / "product_delta_01.patch").open("x", encoding="utf-8", newline="") as f:
    f.write(delta)
with (EVIDENCE / "product_delta_01.json").open("x", encoding="utf-8") as f:
    json.dump({"path": REL, "before": hashlib.sha256(before).hexdigest(),
               "after": hashlib.sha256(after).hexdigest(),
               "preexisting_dirty_suffix_unchanged":
               before[before.index(b'"""Canonical T0 bundle snapshot'):]
               == after[after.index(b'"""Canonical T0 bundle snapshot'):],
               "scope": "tuple SHA and two V1 canonical-byte constructors only"}, f, indent=2)
print(delta)
