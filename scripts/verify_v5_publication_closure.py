"""AD-53 V5 publication-closure verifier.

The verifier is deliberately a small, fail-closed Python boundary.  It
separates the tracked base of the current HEAD from the exact V5 overlay that
would be published, keeps feedback/editability optional, and never treats a
local receipt as source authority or physical evidence.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import stat
import shutil
import subprocess
import tempfile
from pathlib import Path, PurePosixPath
from typing import Any, Iterable


REPO_ROOT = Path(__file__).resolve().parents[1]

CORE_ENTRYPOINT = (
    "src/FusionConceptAI.jl",
    "src/Contracts/CandidateStatePackageV5.jl",
    "src/GenomeV5/Integration/GenomeV5Integration.jl",
    "src/GenomeV5/UP2/UP2ModuleEntryV1.jl",
)
CORE_LOADER = (
    "src/GenomeV5/G1/GrammarProfileV2.jl",
    "src/GenomeV5/G1/EquationPlanV2.jl",
    "src/GenomeV5/G1/MechanismGenomePayloadV2.jl",
    "src/GenomeV5/G1/MechanismGenomeV5.jl",
    "src/GenomeV5/G2/SpatialGrammarProfileV2.jl",
    "src/GenomeV5/G2/RegionInterfaceContractV2.jl",
    "src/GenomeV5/G2/FieldSpacePlanV2.jl",
    "src/GenomeV5/G2/FieldGeometryGenomeV5.jl",
    "src/GenomeV5/G3/RealizationGenomeV5.jl",
    "src/GenomeV5/G3/ControlGenomeV5.jl",
    "src/GenomeV5/G3/CoupledRealizationControlBindingV2.jl",
    "src/GenomeV5/G3/RealizationControlGenomeV5.jl",
)

CORE_DECLARATION_AND_FACTORIES = (
    "src/GenomeV5/G1/DiffusionDeclarationV1.jl",
    "src/GenomeV5/G1/G1SourceAuthorityFactoryV1.jl",
    "src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl",
    "src/GenomeV5/G2/G2SourceAuthorityFactoryV1.jl",
    "src/GenomeV5/G3/G3SourceAuthorityFactoryV1.jl",
)

CORE_PATHS = CORE_ENTRYPOINT + CORE_LOADER + CORE_DECLARATION_AND_FACTORIES
OPTIONAL_G3_FEEDBACK = "src/GenomeV5/G3/G3SourceFeedbackLawV1.jl"
OPTIONAL_PRODUCTS = {
    "g3_source_feedback": {"order": (OPTIONAL_G3_FEEDBACK,)},
    "g3_binding_editability": {
        "order": (
            OPTIONAL_G3_FEEDBACK,
            "src/GenomeV5/G3/G3RealizationChildEditabilityV1.jl",
            "src/GenomeV5/G3/G3ControlChildEditabilityV1.jl",
            "src/GenomeV5/G3/G3BindingChildEditabilityV1.jl",
        )
    },
}

_INCLUDE_RE = re.compile(r'\binclude\(\s*"([^"\n]+)"\s*\)')
_SHA_RE = re.compile(r"\b[0-9a-fA-F]{64}\b")
_TEXT_SUFFIXES = {".md", ".json", ".txt", ".log", ".py", ".jl"}


def normalized_path(value: str | Path) -> str:
    """Return a safe repository-relative POSIX path, rejecting globs/traversal."""

    text = str(value).replace("\\", "/")
    if not text or "*" in text or "?" in text or "[" in text or "]" in text:
        raise ValueError(f"path is not exact: {value!r}")
    p = PurePosixPath(text)
    if p.is_absolute() or any(part in ("", ".", "..") for part in p.parts):
        raise ValueError(f"path is not repository-relative: {value!r}")
    return p.as_posix()


def _run_git(repo: Path, *args: str, check: bool = False) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        ["git", "-C", str(repo), *args],
        text=True,
        capture_output=True,
        check=False,
    )
    if check and result.returncode:
        raise RuntimeError(f"git {' '.join(args)} failed: {result.stderr.strip()}")
    return result


def _sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _sha256_text(text: str) -> str:
    return _sha256_bytes(text.encode("utf-8"))


def _head(repo: Path) -> str:
    result = _run_git(repo, "rev-parse", "HEAD")
    return result.stdout.strip() if result.returncode == 0 else ""


def _tracked_at_head(repo: Path, path: str) -> bool:
    result = _run_git(repo, "cat-file", "-e", f"HEAD:{path}")
    return result.returncode == 0


def _literal_includes(repo: Path, start_paths: Iterable[str]) -> list[str]:
    """Follow only literal include("...") edges, with exact path guards."""

    seen: set[str] = set()
    queue = [normalized_path(p) for p in start_paths]
    found: list[str] = []
    while queue:
        current = queue.pop(0)
        if current in seen:
            continue
        seen.add(current)
        found.append(current)
        source = repo / Path(*current.split("/"))
        if not source.is_file():
            continue
        text = source.read_text(encoding="utf-8", errors="replace")
        parent = PurePosixPath(current).parent
        for literal in _INCLUDE_RE.findall(text):
            candidate = normalized_path((parent / literal).as_posix())
            if candidate.startswith("src/") and candidate not in seen:
                queue.append(candidate)
    return found


def _evidence_files(root: Path) -> list[Path]:
    if not root.exists():
        return []
    # The implementation tree contains very large raw streams.  Authority
    # records are the small named acceptance/review/manifest/report files;
    # excluding raw/archive/run payloads keeps the audit bounded and avoids
    # treating every historical receipt as a new authority record.
    names = ("acceptance", "manifest", "report", "review", "readme", "evidence", "hash", "status")
    result: list[Path] = []
    for directory, dirnames, filenames in os.walk(root):
        # Avoid traversing command streams and generated run forests.  The
        # named acceptance/review records below the remaining directories are
        # sufficient for this publication boundary.
        dirnames[:] = [
            d for d in dirnames
            if d.lower() not in {"raw", "archive", "runs"}
            and not d.lower().startswith(("focused_", "repair_", "independent_precheck", "independent_postrun"))
        ]
        for filename in sorted(filenames):
            p = Path(directory) / filename
            if p.suffix.lower() not in _TEXT_SUFFIXES:
                continue
            if any(part.lower() == "ad-53" for part in p.parts):
                continue
            if not any(token in p.name.lower() for token in names):
                continue
            try:
                if p.stat().st_size > 2_000_000:
                    continue
            except OSError:
                continue
            result.append(p)
    return result


def _status_for_evidence(evidence_root: Path, path: str, digest: str) -> tuple[str, list[str]]:
    """Classify at most three evidence records for one exact path."""

    path = normalized_path(path)
    matches: list[tuple[str, str, bool]] = []
    for file in _evidence_files(evidence_root):
        try:
            text = file.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        if path not in text:
            continue
        lower = text.lower()
        has_acceptance = "accepted_limited" in lower or "pass_limited" in lower
        has_exact = digest.lower() in lower
        matches.append((file.relative_to(evidence_root).as_posix(), text, has_acceptance and has_exact))

    def priority(item: tuple[str, str, bool]) -> tuple[int, str]:
        name = item[0].lower()
        if "root_acceptance_r1" in name:
            rank = 0
        elif "independent_review" in name:
            rank = 1
        elif name.endswith("acceptance.md"):
            rank = 2
        elif "manifest" in name:
            rank = 3
        elif "report" in name:
            rank = 4
        else:
            rank = 5
        return rank, name

    matches.sort(key=priority)
    selected = [name for name, _, _ in matches[:3]]
    if any(exact and "accepted_limited" in text.lower() for _, text, exact in matches):
        return "accepted_limited", selected
    if any("accepted_limited" in text.lower() and not exact for _, text, exact in matches):
        return "hash_drift", selected
    if any(exact for _, _, exact in matches):
        return "observed", selected
    if matches:
        return "unaccepted", selected
    return "no_evidence", selected


def _entry(repo: Path, path: str, evidence_root: Path, why: str) -> dict[str, Any]:
    full = repo / Path(*path.split("/"))
    exists = full.is_file()
    digest = _sha256_bytes(full.read_bytes()) if exists else None
    status, evidence = _status_for_evidence(evidence_root, path, digest or "")
    return {
        "path": path,
        "bytes": full.stat().st_size if exists else None,
        "sha256": digest,
        "tracked_at_head": _tracked_at_head(repo, path) if exists else False,
        "status": status,
        "why_required": why,
        "evidence": evidence[:3],
    }


def inspect_closure(repo: Path, evidence_root: Path) -> dict[str, Any]:
    """Inspect the exact core closure without modifying the repository."""

    repo = repo.resolve()
    evidence_root = evidence_root.resolve()
    literal = _literal_includes(repo, ("src/FusionConceptAI.jl",))
    base = [p for p in literal if p not in CORE_PATHS and _tracked_at_head(repo, p)]
    overlay = list(dict.fromkeys(list(CORE_PATHS) + [p for p in literal if p in CORE_PATHS]))
    missing = [p for p in overlay if not (repo / Path(*p.split("/"))).is_file()]
    unknown: list[str] = []
    entries = [_entry(repo, p, evidence_root, "required V5 core publication closure") for p in overlay]
    optional = {
        name: {
            "order": list(product["order"]),
            "paths_present": all((repo / Path(*p.split("/"))).is_file() for p in product["order"]),
            "independent": True,
        }
        for name, product in OPTIONAL_PRODUCTS.items()
    }
    return {
        "schema": "AD53.V5PublicationClosureVerifier.v2",
        "head": _head(repo),
        "core_closure_status": "complete" if not missing and not unknown else "changes_required",
        "missing_paths": missing,
        "unknown_paths": unknown,
        "rejected_paths": [],
        "base_head_tracked_dependencies": base,
        "overlay_publication_paths": overlay,
        "entries": entries,
        "optional_products": optional,
        "optional_feedback_excluded_from_core": OPTIONAL_G3_FEEDBACK not in overlay,
        "evidence_max_per_path": 3,
        "source_authority": False,
        "trusted_source_identity": False,
        "candidate_identity_created": False,
        "final_candidate_or_package_declaration_hash_created": False,
        "physical_search_and_engineering": False,
        "R01_R10": False,
        "L4_credible_count": 0,
    }


def _repo_snapshot(repo: Path) -> dict[str, str]:
    def digest(value: str) -> str:
        return _sha256_text(value)

    index = _run_git(repo, "ls-files", "--stage").stdout
    debug = _run_git(repo, "ls-files", "--debug").stdout
    cached = _run_git(repo, "diff", "--cached", "--binary").stdout
    status = _run_git(repo, "status", "--porcelain=v1", "--untracked-files=all").stdout
    return {
        "head": _head(repo),
        "index_sha256": digest(index),
        "index_debug_sha256": digest(debug),
        "cached_diff_sha256": digest(cached),
        "status_sha256": digest(status),
    }


def _process_receipt(command: list[str], cwd: Path, timeout: int = 180) -> dict[str, Any]:
    process = subprocess.Popen(command, cwd=str(cwd), text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    timed_out = False
    try:
        stdout, stderr = process.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        timed_out = True
        process.kill()
        stdout, stderr = process.communicate()
        stderr = (stderr or "") + f"\nprocess timeout after {timeout}s"
    return {
        "pid": process.pid,
        "exit": process.returncode,
        "command": command,
        "stdout": stdout,
        "stderr": stderr,
        "stdout_sha256": _sha256_text(stdout),
        "stderr_sha256": _sha256_text(stderr),
        "timed_out": timed_out,
    }


def _probe_command() -> list[str]:
    probe = r'''using FusionConceptAI
FusionConceptAI.load_genome_v5_components!()
@assert FusionConceptAI.genome_v5_component_layer_order() == (:G1, :G2, :G3)
Base.include(FusionConceptAI, joinpath(pwd(), "src", "GenomeV5", "G1", "DiffusionDeclarationV1.jl"))
Base.include(FusionConceptAI, joinpath(pwd(), "src", "GenomeV5", "G1", "G1SourceAuthorityFactoryV1.jl"))
Base.include(FusionConceptAI, joinpath(pwd(), "src", "GenomeV5", "G2", "MetricBoundaryDeclarationV1.jl"))
Base.include(FusionConceptAI, joinpath(pwd(), "src", "GenomeV5", "G2", "G2SourceAuthorityFactoryV1.jl"))
Base.include(FusionConceptAI, joinpath(pwd(), "src", "GenomeV5", "G3", "G3SourceAuthorityFactoryV1.jl"))
@assert FusionConceptAI.g1_source_factory_result_status(FusionConceptAI.g1_source_authority_factory_v1(nothing, nothing, nothing, nothing, nothing, nothing)) == :typed_absent
@assert FusionConceptAI.g2_source_factory_result_status(FusionConceptAI.g2_source_authority_factory_v1(nothing, nothing, nothing, nothing, nothing, nothing)) == :typed_absent
@assert FusionConceptAI.g3_factory_result_status(FusionConceptAI.g3_source_authority_factory_v1(:bundle, nothing, nothing, nothing, nothing, nothing)) == :typed_absent
println("V5_CLOSURE_PROBE=pass")
'''
    return ["julia", "--startup-file=no", "--project=.", "-e", probe]


def _copy_overlay(repo: Path, checkout: Path, paths: Iterable[str]) -> None:
    for raw in paths:
        path = normalized_path(raw)
        source = repo / Path(*path.split("/"))
        target = checkout / Path(*path.split("/"))
        if not source.is_file():
            raise FileNotFoundError(path)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)


def _remove_tree(path: Path) -> bool:
    """Remove a verifier-owned tree even when a clone marks files read-only."""

    if not path.exists():
        return True
    for child in [path, *path.rglob("*")]:
        try:
            os.chmod(child, stat.S_IWRITE | stat.S_IREAD)
        except OSError:
            pass
    shutil.rmtree(path, ignore_errors=True)
    return not path.exists()


def _run_temp_validation(repo: Path, closure: dict[str, Any]) -> dict[str, Any]:
    """Clone HEAD, overlay only the declared core, exact-commit, probe, clean up."""

    temp_root = Path(tempfile.mkdtemp(prefix="ad53_v5_closure_"))
    checkout = temp_root / "repo"
    result: dict[str, Any] = {
        "status": "fail_closed",
        "temporary_checkout": str(checkout),
        "temporary_checkout_cleaned": False,
        "cleanup": {"cleaned": False},
    }
    try:
        clone = subprocess.run(
            ["git", "clone", "--quiet", "--no-local", str(repo), str(checkout)],
            text=True,
            capture_output=True,
            check=False,
        )
        if clone.returncode:
            raise RuntimeError(clone.stderr.strip() or "git clone failed")
        paths = [normalized_path(p) for p in closure.get("overlay_publication_paths", [])]
        _copy_overlay(repo, checkout, paths)
        _run_git(checkout, "add", "--", *paths, check=True)
        commit = _run_git(
            checkout,
            "-c", "user.name=AD53 verifier",
            "-c", "user.email=ad53-verifier@example.invalid",
            "commit", "--quiet", "-m", "AD53 exact V5 publication closure",
        )
        if commit.returncode:
            raise RuntimeError(commit.stderr.strip() or "exact overlay commit failed")
        changed = _run_git(checkout, "diff-tree", "--no-commit-id", "--name-only", "-r", "HEAD").stdout.splitlines()
        if changed != sorted(paths):
            raise RuntimeError(f"commit path set mismatch: {changed!r}")
        receipt = _process_receipt(_probe_command(), checkout)
        result["probe"] = receipt
        if receipt["exit"] == 0 and "V5_CLOSURE_PROBE=pass" in receipt["stdout"]:
            result["status"] = "complete"
        else:
            result["gap"] = "core Julia probe did not pass"
    except Exception as error:  # fail closed while preserving a typed receipt
        result["error"] = f"{type(error).__name__}: {error}"
    finally:
        cleaned = _remove_tree(temp_root)
        result["temporary_checkout_cleaned"] = cleaned
        result["cleanup"] = {"cleaned": cleaned}
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, default=REPO_ROOT)
    parser.add_argument("--evidence-root", type=Path, default=None)
    parser.add_argument("--run-temp", action="store_true")
    parser.add_argument("--output", type=Path, default=None)
    args = parser.parse_args(argv)
    repo = args.repo.resolve()
    evidence = (args.evidence_root or repo / "docs" / "implementation").resolve()
    before = _repo_snapshot(repo)
    closure = inspect_closure(repo, evidence)
    report: dict[str, Any] = {"closure": closure, "original_repo_protection": {"before": before}}
    if args.run_temp:
        if closure["core_closure_status"] == "complete":
            report["temporary_validation"] = _run_temp_validation(repo, closure)
        else:
            report["temporary_validation"] = {
                "status": "not_executed",
                "reason": "core closure incomplete; no Julia receipt can be claimed",
                "temporary_checkout_cleaned": True,
                "cleanup": {"cleaned": True},
            }
    after = _repo_snapshot(repo)
    report["original_repo_protection"]["after"] = after
    report["original_repo_protection"]["unchanged"] = before == after
    report["implementation_status"] = "completed_review_pending"
    report["accepted"] = False
    report["physical_search_and_engineering"] = False
    report["R01_R10"] = False
    report["L4_credible_count"] = 0
    if closure["core_closure_status"] != "complete" or not report["original_repo_protection"]["unchanged"]:
        report["overall_status"] = "changes_required"
    elif args.run_temp and report.get("temporary_validation", {}).get("status") != "complete":
        report["overall_status"] = "changes_required"
    else:
        report["overall_status"] = "completed_review_pending"
    encoded = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(encoded, encoding="utf-8")
    else:
        print(encoded, end="")
    return 0 if report["overall_status"] != "changes_required" else 1


if __name__ == "__main__":
    raise SystemExit(main())
