from pathlib import Path
import difflib
import hashlib
import json
import sys

ROOT = Path(__file__).resolve().parents[4]
EVIDENCE = ROOT / "docs/implementation/UP1-04A-VNEXT-T1/agent_local_r18_astra_t1_closeout"
REL = "src/Contracts/CandidateStatePackageV5Next.jl"
number, mode = sys.argv[1:3]
target = EVIDENCE / ("product_before_" + number + ".jl")
current = (ROOT / REL).read_bytes()
if mode == "before":
    with target.open("xb") as f:
        f.write(current)
    print("BEFORE", number, hashlib.sha256(current).hexdigest())
elif mode == "after":
    before = target.read_bytes()
    patch = "".join(difflib.unified_diff(before.decode().splitlines(keepends=True),
                                      current.decode().splitlines(keepends=True),
                                      fromfile="before-delta-" + number + "/" + REL,
                                      tofile="after-delta-" + number + "/" + REL))
    with (EVIDENCE / ("product_delta_" + number + ".patch")).open("x", encoding="utf-8", newline="") as f:
        f.write(patch)
    receipt = {"path": REL, "before": hashlib.sha256(before).hexdigest(),
               "after": hashlib.sha256(current).hexdigest(),
               "preexisting_dirty_suffix_unchanged":
               before[before.index(b'"""Canonical T0 bundle snapshot'):]
               == current[current.index(b'"""Canonical T0 bundle snapshot'): ],
               "preexisting_three_dirty_hunks_region_unchanged":
               before[before.index(b'struct CandidateStatePackageV5Next{'):]
               == current[current.index(b'struct CandidateStatePackageV5Next{'): ]}
    with (EVIDENCE / ("product_delta_" + number + ".json")).open("x", encoding="utf-8") as f:
        json.dump(receipt, f, indent=2)
    print(patch)
    print(json.dumps(receipt))
else:
    raise ValueError(mode)
