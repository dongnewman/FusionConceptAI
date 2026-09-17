"""Repository-only metadata discovery for UP1 W4 repair R2.

The scanner never emits file contents. It records path, suffix/type, byte size,
SHA-256 and classification. The local_input_discovery directory is excluded
from its input universe so reruns do not scan their own generated evidence.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path


HERE = Path(__file__).resolve().parents[1]
REPO = HERE.parents[3]
OUT = HERE
EXCLUDED_PREFIXES = (
    Path(".git"),
    Path("docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R1/local_input_discovery"),
    Path("docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R1/reviews"),
)
PATH_HIT = re.compile(
    r"(?:AD[-_ ]?(?:44|45|55|56)|authority|candidate|trust|signature|signed|receipt|attest|witness|"
    r"g2|environment|binary|provenance|sbom|certificate|cert|nonce|revocation|ocsp|crl)",
    re.IGNORECASE,
)
SENSITIVE = re.compile(r"(?:private|secret|token|credential|password|passwd|\.pem$|\.key$|\.p12$|\.pfx$|\.env$)", re.IGNORECASE)
TARGET = re.compile(
    r"(?:^docs/implementation/AD-(?:42|43|44|45|47|48|55|56)/|"
    r"^docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R1/(?:witness_authority|trust_chain|source_g2_environment)/|"
    r"(?:candidate_binding|authority|attestation|trust|receipt|provenance|environment|binary).*(?:\.json|\.md|\.toml|\.raw|\.txt)$)",
    re.IGNORECASE,
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def rel(path: Path) -> str:
    return path.relative_to(REPO).as_posix()


def classify(path: str, sensitive: bool) -> tuple[str, str]:
    if sensitive:
        return "excluded", "sensitive_metadata_only_unopened"
    if TARGET.search(path):
        return "candidate", "authority_or_candidate_looking_record_in_declared_scope"
    if path.endswith(("Project.toml", "Manifest.toml")):
        return "candidate", "environment_lock_metadata_only"
    return "excluded", "repository_path_hit_not_an_external_input"


def main() -> int:
    started = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    files = []
    for path in REPO.rglob("*"):
        if not path.is_file():
            continue
        relative = Path(rel(path))
        if any(relative == prefix or prefix in relative.parents for prefix in EXCLUDED_PREFIXES):
            continue
        text_path = relative.as_posix()
        if not PATH_HIT.search(text_path):
            continue
        sensitive = bool(SENSITIVE.search(text_path))
        kind, reason = classify(text_path, sensitive)
        stat = path.stat()
        files.append(
            {
                "path": text_path,
                "type": path.suffix.lower() or "<none>",
                "bytes": stat.st_size,
                "sha256": sha256(path),
                "classification": kind,
                "category": reason,
                "sensitive_unopened": sensitive,
                "content_emitted": False,
            }
        )
    files.sort(key=lambda item: item["path"])
    candidates = [item for item in files if item["classification"] == "candidate"]
    excluded = [item for item in files if item["classification"] == "excluded"]
    raw_path = OUT / "raw/metadata_scan_r2.jsonl"
    raw_path.parent.mkdir(parents=True, exist_ok=True)
    with raw_path.open("w", encoding="utf-8", newline="\n") as stream:
        for item in files:
            stream.write(json.dumps(item, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n")

    scan = {
        "schema": "UP1.W4.metadata-scan-r2.v1",
        "repo_root": str(REPO).replace("\\", "/"),
        "head": subprocess.run(["git", "rev-parse", "HEAD"], cwd=REPO, capture_output=True, text=True, check=True).stdout.strip(),
        "scope": "repository_only",
        "excluded_from_universe": [
            ".git",
            "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R1/local_input_discovery/**",
            "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R1/reviews/**",
        ],
        "path_hit_rule": PATH_HIT.pattern,
        "hit_count": len(files),
        "candidate_count": len(candidates),
        "excluded_count": len(excluded),
        "sensitive_unopened_count": sum(1 for item in files if item["sensitive_unopened"]),
        "raw": "raw/metadata_scan_r2.jsonl",
        "started_utc": started,
        "ended_utc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "pid": os.getpid(),
    }
    (OUT / "repair_r2").mkdir(parents=True, exist_ok=True)
    (OUT / "repair_r2/metadata_scan_summary.json").write_text(json.dumps(scan, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (OUT / "repair_r2/metadata_scan_candidates.json").write_text(json.dumps({"schema": "UP1.W4.metadata-scan-candidates-r2.v1", "records": candidates}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (OUT / "repair_r2/metadata_scan_excluded.json").write_text(json.dumps({"schema": "UP1.W4.metadata-scan-excluded-r2.v1", "records": excluded}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
