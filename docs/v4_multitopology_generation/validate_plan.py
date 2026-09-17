"""Read-only planning checks; optional JSON report is documentation evidence only."""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from urllib.parse import unquote, urlsplit


PLAN = Path(__file__).resolve().parent
ROOT = PLAN.parents[1]
SNAPSHOT = ROOT / "docs/implementation/history/20260914_planning_baseline"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def without_fences(text: str) -> str:
    return re.sub(r"^```[^\n]*\n.*?^```\s*$", "", text, flags=re.M | re.S)


def anchors(text: str) -> set[str]:
    result = set(re.findall(r'<a\s+id="([^"]+)"', text))
    for title in re.findall(r"^#{1,6}\s+(.+)$", without_fences(text), flags=re.M):
        title = re.sub(r"[^\w\-\s]", "", title.lower()).strip().replace(" ", "-")
        result.add(title)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--delivery-protection", action="store_true",
                        help="Also verify pre-existing dirty files and implementation records from this documentation turn.")
    parser.add_argument("--report", type=Path, help="Optional output JSON; does not constitute implementation acceptance.")
    args = parser.parse_args()
    errors: list[str] = []
    checked_links = 0
    manifest = json.loads((PLAN / "task_manifest.json").read_text(encoding="utf-8"))
    tasks = manifest["tasks"]
    ids = [item["id"] for item in tasks]
    if len(ids) != len(set(ids)):
        errors.append("Duplicate task IDs")
    id_set = set(ids)
    by_id = {item["id"]: item for item in tasks}
    allowed_states = {"planned", "ready", "running", "review_pending", "accepted", "changes_requested", "blocked_external"}
    for item in tasks:
        if item["status"] not in allowed_states:
            errors.append(f"Invalid status: {item['id']}")
        if item["phase"] != item["id"].split("-")[0]:
            errors.append(f"Phase/ID mismatch: {item['id']}")
        for dep in item["depends_on"]:
            if dep not in id_set:
                errors.append(f"Missing dependency {dep} in {item['id']}")
        if not (PLAN / item["technical_doc"]).is_file():
            errors.append(f"Missing technical doc: {item['id']}")
        if item["implementation_model"] != "gpt-5.6-luna" or item["reasoning_effort"] != "high":
            errors.append(f"Worker model mismatch: {item['id']}")
        if not item["steps"] or not item["acceptance"] or not item["inputs"] or not item["write_scope"]:
            errors.append(f"Incomplete work order: {item['id']}")
        if item["status"] == "accepted":
            record = item.get("acceptance_record")
            if not record or not (ROOT / record).is_file():
                errors.append(f"Accepted without archive: {item['id']}")
            if not item.get("owner") or not item.get("reviewer") or item["owner"] == item["reviewer"]:
                errors.append(f"Accepted without different reviewer: {item['id']}")
        elif item["status"] in {"ready", "running", "review_pending"}:
            if any(by_id.get(dep, {}).get("status") != "accepted" for dep in item["depends_on"]):
                errors.append(f"Started before dependency acceptance: {item['id']}")

    done: set[str] = set()
    while True:
        ready = {item["id"] for item in tasks if set(item["depends_on"]) <= done} - done
        if not ready:
            break
        done |= ready
    if done != id_set:
        errors.append("Task dependency graph has a cycle or unresolved dependency")

    if manifest["primary"] != {"model": "gpt-5.6-sol", "reasoning_effort": "high"}:
        errors.append("Primary model mismatch")
    if manifest["workers"] != {"model": "gpt-5.6-luna", "reasoning_effort": "high"}:
        errors.append("Worker defaults mismatch")
    if manifest["goal"]["requirements"] != [f"R{i:02}" for i in range(1, 11)]:
        errors.append("Parent R01-R10 requirement list changed")

    work_orders = (PLAN / "16_execution_work_orders.md").read_text(encoding="utf-8")
    work_anchors = anchors(work_orders)
    benchmark_text = (PLAN / "13_acceptance_benchmarks_and_evidence.md").read_text(encoding="utf-8")
    for item in tasks:
        if item["id"].lower() not in work_anchors:
            errors.append(f"No work-order anchor: {item['id']}")
        if item["work_order_ref"] != f"16_execution_work_orders.md#{item['id'].lower()}":
            errors.append(f"Wrong work-order reference: {item['id']}")
        for benchmark in item["benchmarks"]:
            if benchmark not in benchmark_text:
                errors.append(f"Missing benchmark {benchmark} in {item['id']}")
        section = work_orders.split(f'<a id="{item["id"].lower()}"></a>', 1)[-1].split('<a id="', 1)[0]
        for entry in item["steps"] + item["acceptance"]:
            if entry not in section:
                errors.append(f"Manifest/text work-order drift: {item['id']}")

    prompt = (PLAN / "15_sol_system_prompt.md").read_text(encoding="utf-8").strip()
    if len(prompt) > 500:
        errors.append(f"Sol prompt exceeds 500 characters: {len(prompt)}")

    files = sorted(PLAN.glob("*.md")) + [ROOT / "README.md", ROOT / "AGENTS.md", ROOT / "docs/implementation/README.md",
        SNAPSHOT / "INDEX.md", ROOT / "docs/implementation/planning_update_20260914/acceptance.md"]
    for path in files:
        text = path.read_text(encoding="utf-8")
        if len(re.findall(r"^```", text, flags=re.M)) % 2:
            errors.append(f"Unclosed code fence: {path.relative_to(ROOT)}")
        if not text.strip():
            errors.append(f"Empty document: {path.relative_to(ROOT)}")
        if not text.startswith("#") and path.name != "15_sol_system_prompt.md":
            errors.append(f"Missing document title: {path.relative_to(ROOT)}")
        for raw in re.findall(r"\[[^\]\n]+\]\((<[^>]+>|[^)\n]+)\)", without_fences(text)):
            target = raw[1:-1] if raw.startswith("<") else raw
            if urlsplit(target).scheme:
                continue
            filename, _, fragment = unquote(target).partition("#")
            linked = (path.parent / filename).resolve() if filename else path
            checked_links += 1
            if not linked.exists():
                errors.append(f"Missing link from {path.relative_to(ROOT)}: {target}")
            elif fragment and linked.is_file() and linked.suffix == ".md":
                if fragment not in anchors(linked.read_text(encoding="utf-8")):
                    errors.append(f"Missing anchor from {path.relative_to(ROOT)}: {target}")

    snap = json.loads((SNAPSHOT / "snapshot_manifest.json").read_text(encoding="utf-8"))
    for filename, expected in snap["files"].items():
        path = SNAPSHOT / filename
        if not path.is_file() or sha256(path) != expected:
            errors.append(f"Historical snapshot changed: {filename}")
    protected_checked = 0
    if args.delivery_protection:
        for group in ("protected_dirty_files", "preexisting_implementation_records"):
            for filename, expected in snap[group].items():
                protected_checked += 1
                path = ROOT / filename
                if not path.is_file() or sha256(path) != expected:
                    errors.append(f"Pre-existing file changed during documentation work: {filename}")

    result = {
        "record_kind": "planning_document_validation_not_physics_or_implementation_acceptance",
        "plan_version": manifest["schema_version"],
        "checks": "pass" if not errors else "fail",
        "markdown_files_checked": len(files),
        "relative_links_checked": checked_links,
        "task_count": len(tasks),
        "task_dag_acyclic": done == id_set,
        "sol_prompt_characters": len(prompt),
        "snapshot_files_checked": len(snap["files"]),
        "preexisting_files_checked": protected_checked,
        "errors": errors,
    }
    if args.report:
        destination = args.report.resolve()
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if not errors else 1


if __name__ == "__main__":
    sys.exit(main())
