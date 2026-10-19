"""Capture immutable R18 source baseline; never overwrite an earlier receipt."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[4]
OUT = ROOT / "docs/implementation/UP1-04A-VNEXT-T1/agent_local_r18_astra_t1_closeout"
OUT.mkdir(exist_ok=False)
paths = sorted(p for folder in ("src", "test", "docs/v4_multitopology_generation")
               for p in (ROOT / folder).rglob("*")
               if p.is_file() and "__pycache__" not in p.parts)
records = {}
for path in paths:
    raw = path.read_bytes()
    records[path.relative_to(ROOT).as_posix()] = {
        "bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()}
for rel in ("src/Contracts/CandidateStatePackageV5Next.jl",
            "src/GenomeV5/Integration/VNextGenomeV5Integration.jl",
            "src/GenomeV5/Integration/VNextDeclarationAuthorityRecheckLocalV1.jl",
            "test/GenomeV5/Integration/vnext_t1_candidate_state_package_v5_next_tests.jl"):
    dest = OUT / "before" / rel
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ROOT / rel, dest)
def git(*args):
    return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, check=True).stdout
(OUT / "git_status_before.raw").write_bytes(git("status", "--porcelain=v1"))
(OUT / "git_diff_before.raw").write_bytes(git("diff", "--binary"))
receipt = {"utc": datetime.now(timezone.utc).isoformat(),
           "head": git("rev-parse", "HEAD").decode().strip(),
           "requested_model": "gpt-6-astra", "requested_reasoning": "xhigh",
           "actual_model_attestation": "unavailable", "files": records}
(OUT / "baseline.json").write_text(json.dumps(receipt, indent=2), encoding="utf-8")
print(json.dumps({"root": str(OUT), "file_count": len(records), "head": receipt["head"]}))
