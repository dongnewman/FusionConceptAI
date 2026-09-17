"""Local development preflight and command execution; never scientific acceptance.

No external certification service, witness or PKI is consulted. This entry
checks scheduling and records actual input bytes. Task-specific semantic and
numerical validators remain required by each work order.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
from datetime import datetime, timezone


PLAN = Path("docs/v4_multitopology_generation")
POLICY_VERSION = "fusion-agent-local-execution-v1"
ALLOWED_TASK_STATUSES = frozenset({
    "planned", "ready", "running", "review_pending", "accepted",
    "changes_requested", "blocked_external",
})
# Only these states authorize a new dispatch.  In particular, a task that is
# already running, awaiting review, blocked, or accepted must be moved back to
# planned/ready by the scheduler before it can be launched again.
DISPATCHABLE_TASK_STATUSES = frozenset({"planned", "ready"})

# The local profile is deliberately a closed policy schema.  A policy field is
# either one of these exact values or it is rejected; silently ignoring a
# newly-added field would make the dispatch boundary ambiguous.
EXPECTED_POLICY = {
    "schema_version": POLICY_VERSION,
    "default_profile": "agent_local",
    "decision_date": "2026-09-17",
    "authority_basis": "explicit_user_instruction",
    "responsibility": {
        "architecture_and_acceptance": "sol_agent",
        "implementation_and_evidence": "luna_agent",
        "review": "different_luna_agent",
    },
    "external_approval_required": False,
    "external_certification_blocks_execution": False,
    "external_requirements": [],
    "local_requirements": [
        "actual_source_and_input_bytes",
        "content_hashes_and_versioned_candidate_lineage",
        "typed_units_closure_and_applicability_checks",
        "numerical_convergence_conservation_and_error_checks",
        "applicable_engineering_constraints",
        "reproducible_commands_artifacts_and_agent_review",
    ],
    "legacy_external_profile": "explicit_optional_compatibility_only",
    "candidate_identity_is_scientific_acceptance": False,
    "dag_node_count_frozen": False,
    "scientific_requirements": [f"R{i:02}" for i in range(1, 11)],
}


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def policy_errors(policy: dict) -> list[str]:
    errors: list[str] = []

    def compare(actual, expected, path: str) -> None:
        if isinstance(expected, dict):
            if type(actual) is not dict:
                errors.append(f"execution_policy_mismatch:{path}")
                return
            for key in actual:
                if key not in expected:
                    unknown = f"{path}.{key}" if path else key
                    errors.append(f"execution_policy_unknown_field:{unknown}")
            for key, expected_value in expected.items():
                child = f"{path}.{key}" if path else key
                if key not in actual:
                    errors.append(f"execution_policy_mismatch:{child}")
                else:
                    compare(actual[key], expected_value, child)
            return
        if type(actual) is not type(expected) or actual != expected:
            errors.append(f"execution_policy_mismatch:{path}")

    if type(policy) is not dict:
        return ["execution_policy_not_object"]
    compare(policy, EXPECTED_POLICY, "")
    return errors


def _repo_path(root: Path, value: str, *, kind: str, require_exists: bool = False) -> Path:
    """Resolve a repository-relative path without permitting traversal links."""
    if not isinstance(value, str) or not value:
        raise ValueError(f"{kind}_path_invalid:{value!r}")
    candidate = Path(value)
    if candidate.is_absolute() or ".." in candidate.parts:
        raise ValueError(f"{kind}_outside_repository:{value}")
    path = (root / candidate).resolve()
    if not path.is_relative_to(root):
        raise ValueError(f"{kind}_outside_repository:{value}")
    if require_exists and not path.is_file():
        raise FileNotFoundError(f"{kind}_missing:{value}")
    return path


def file_record(root: Path, value: str) -> dict:
    path = _repo_path(root, value, kind="input", require_exists=True)
    data = path.read_bytes()
    return {"path": path.relative_to(root).as_posix(), "size": len(data),
            "sha256": hashlib.sha256(data).hexdigest()}


def _manifest_errors(root: Path, manifest) -> tuple[list[str], dict[str, dict]]:
    errors: list[str] = []
    if type(manifest) is not dict:
        return ["manifest_not_object"], {}
    raw_tasks = manifest.get("tasks")
    if type(raw_tasks) is not list:
        return ["manifest_tasks_not_list"], {}

    tasks: dict[str, dict] = {}
    duplicate_ids: set[str] = set()
    for index, task in enumerate(raw_tasks):
        if type(task) is not dict:
            errors.append(f"manifest_task_not_object:{index}")
            continue
        task_id = task.get("id")
        if type(task_id) is not str or not task_id:
            errors.append(f"manifest_task_id_invalid:{index}")
            continue
        if task_id in tasks:
            duplicate_ids.add(task_id)
        else:
            tasks[task_id] = task
        status = task.get("status")
        if type(status) is not str or status not in ALLOWED_TASK_STATUSES:
            errors.append(f"manifest_illegal_status:{task_id}")
        dependencies = task.get("depends_on")
        if type(dependencies) is not list or any(type(dep) is not str for dep in dependencies):
            errors.append(f"manifest_dependencies_invalid:{task_id}")
        elif len(dependencies) != len(set(dependencies)):
            errors.append(f"manifest_duplicate_dependency:{task_id}")
        record = task.get("acceptance_record")
        if record is not None:
            try:
                _repo_path(root, record, kind="acceptance_record")
            except (TypeError, ValueError):
                errors.append(f"manifest_acceptance_record_outside_repository:{task_id}")
    for task_id in sorted(duplicate_ids):
        errors.append(f"manifest_duplicate_task_id:{task_id}")

    id_set = set(tasks)
    for task_id, task in tasks.items():
        dependencies = task.get("depends_on")
        if type(dependencies) is not list:
            continue
        for dep in dependencies:
            if dep not in id_set:
                errors.append(f"manifest_missing_dependency:{task_id}:{dep}")

    # Kahn's algorithm gives a direct fail-closed cycle check independent of
    # validate_plan.py, so callers cannot bypass the planning validator by
    # invoking this execution entry point directly.
    remaining = set(tasks)
    resolved: set[str] = set()
    while remaining:
        ready = {
            task_id for task_id in remaining
            if type(tasks[task_id].get("depends_on")) is list
            and all(dep in resolved for dep in tasks[task_id]["depends_on"])
        }
        if not ready:
            errors.append("manifest_dependency_cycle")
            break
        resolved.update(ready)
        remaining -= ready
    return errors, tasks


def preflight(root: Path, task_id: str | None = None) -> dict:
    root = root.resolve()
    policy = read_json(root / PLAN / "execution_policy.json")
    manifest = read_json(root / PLAN / "task_manifest.json")
    errors = policy_errors(policy)
    if type(manifest) is not dict:
        manifest_errors, tasks = _manifest_errors(root, manifest)
        errors.extend(manifest_errors)
        tasks = {}
    else:
        if manifest.get("execution_policy") != "execution_policy.json":
            errors.append("manifest_execution_policy_missing")
        manifest_errors, tasks = _manifest_errors(root, manifest)
        errors.extend(manifest_errors)
    if type(manifest) is dict and manifest.get("execution_entry") not in (None, "tools/agent_local_execution.py"):
        errors.append("manifest_execution_entry_mismatch")

    def blockers(task: dict) -> list[str]:
        missing = []
        for dep in task.get("depends_on", []):
            upstream = tasks.get(dep, {})
            record = upstream.get("acceptance_record")
            if upstream.get("status") != "accepted" or not record:
                missing.append(dep)
            else:
                try:
                    path = _repo_path(root, record, kind="acceptance_record")
                except (OSError, TypeError, ValueError):
                    # The manifest validator already reports traversal and
                    # symlink escapes; retain a blocker as defense in depth.
                    missing.append(dep)
                else:
                    if not path.is_file():
                        missing.append(dep)
        return sorted(set(missing))

    ready = [key for key, task in tasks.items()
             if task.get("status") in DISPATCHABLE_TASK_STATUSES and not blockers(task)]
    dependencies = []
    requested_status = None
    requested_non_dispatchable = False
    if task_id is not None:
        if task_id not in tasks:
            errors.append("unknown_task_id")
        else:
            requested_status = tasks[task_id].get("status")
            dependencies = blockers(tasks[task_id])
            if requested_status not in DISPATCHABLE_TASK_STATUSES and not errors:
                errors.append(f"non_dispatchable_task_status:{task_id}:{requested_status}")
                requested_non_dispatchable = True
    status = "invalid" if errors else "blocked_technical_dependency" if dependencies else "ready"
    if requested_non_dispatchable:
        status = "non_dispatchable_task_status"
    return {
        "schema_version": "fusion-agent-local-preflight-v1",
        "profile": "agent_local",
        "status": status,
        "task_id": task_id,
        "ready_tasks": ready,
        "unmet_technical_dependencies": dependencies,
        "errors": errors,
        "external_certification_required": False,
        "claim_scope": "development_dispatch_only",
        "scientific_acceptance": False,
        "records": [file_record(root, str(PLAN / name)) for name in
                    ("execution_policy.json", "task_manifest.json")],
    }


def verify_records(root: Path, records: list[dict]) -> None:
    for record in records:
        if file_record(root, record["path"]) != record:
            raise ValueError(f"input_changed:{record['path']}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--task")
    parser.add_argument("--input", action="append", default=[], help="Actual repository-relative input/source file; repeatable.")
    parser.add_argument("--output", type=Path, help="New run directory, required with --run; never overwrites an old run.")
    parser.add_argument("--timeout", type=float, default=300.0)
    parser.add_argument("--run", nargs=argparse.REMAINDER, help="Executable followed by arguments; no shell expansion.")
    args = parser.parse_args(argv)
    root = args.root.resolve()
    try:
        result = preflight(root, args.task)
        result["records"].extend(file_record(root, value) for value in args.input)
        if result["status"] != "ready":
            print(json.dumps(result, ensure_ascii=False, indent=2))
            return 2
        if args.run is not None:
            if not args.run or not args.task or not args.input or args.output is None or args.timeout <= 0:
                raise ValueError("run_requires_task_input_new_output_positive_timeout_and_command")
            destination = _repo_path(root, str(args.output), kind="output")
            verify_records(root, result["records"])
            destination.mkdir(parents=True, exist_ok=False)
            result.update(command=args.run, cwd=str(root), started_utc=datetime.now(timezone.utc).isoformat())
            with (destination / "stdout.txt").open("wb") as out, (destination / "stderr.txt").open("wb") as err:
                try:
                    process = subprocess.run(args.run, cwd=root, stdout=out, stderr=err,
                                             timeout=args.timeout, shell=False, check=False)
                    result.update(exit_code=process.returncode,
                                  status="command_completed" if process.returncode == 0 else "command_failed")
                except subprocess.TimeoutExpired:
                    result.update(exit_code=None, status="command_timeout")
                except OSError as exc:
                    result.update(exit_code=None, status="program_exception", execution_error=str(exc))
            try:
                verify_records(root, result["records"])
            except (OSError, ValueError) as exc:
                result.update(status="input_changed_during_execution", execution_error=str(exc))
            result["finished_utc"] = datetime.now(timezone.utc).isoformat()
            result["log_records"] = [file_record(root, str((destination / name).relative_to(root)))
                                     for name in ("stdout.txt", "stderr.txt")]
            (destination / "run.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0 if result["status"] in {"ready", "command_completed"} else 2
    except (OSError, ValueError, KeyError, TypeError) as exc:
        print(json.dumps({"status": "invalid", "error": str(exc), "scientific_acceptance": False}, ensure_ascii=False))
        return 2


if __name__ == "__main__":
    sys.exit(main())
