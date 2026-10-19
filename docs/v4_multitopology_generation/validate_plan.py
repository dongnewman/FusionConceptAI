"""Validate current planning only; never scientific or execution acceptance."""
from __future__ import annotations
import argparse
import hashlib
import json
import re
import sys
import zipfile
from pathlib import Path
from urllib.parse import unquote, urlsplit

PLAN = Path(__file__).resolve().parent
ROOT = PLAN.parents[1]
PRIMARY_MODEL = {"model": "gpt-6-sol", "reasoning_effort": "high"}
SUBAGENT_MODEL = {"model": "gpt-6-luna", "reasoning_effort": "high"}
MAX_CONCURRENT_SUBAGENTS = 9


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def preexisting_normative_amendment_matches(path: Path, expected: str) -> bool:
    """Allow only the exact pre-cleanup Jn addition, preserving the old contract."""
    if path.name != "00_normative_contracts_and_state_model.md":
        return False
    record_path = ROOT / "docs/implementation/WORKSPACE-CONSOLIDATION-20261019/normative_cleanup_baseline.json"
    try:
        record = json.loads(record_path.read_text(encoding="utf-8"))
        addition = record["only_content_addition"]
        text = path.read_text(encoding="utf-8")
        if (record["file"] != path.name or record["historical_protection_sha256"] != expected
                or (record["current_sha256"] != sha256(path)
                    and record["current_sha256"] != hashlib.sha256(text.encode("utf-8")).hexdigest())
                or not record["unchanged_since_cleanup_baseline"]
                or record["prior_line_endings"] != "CRLF_except_final_LF"
                or text.count(addition + "\n\n") != 1):
            return False
        prior = text.replace(addition + "\n\n", "", 1).replace("\n", "\r\n")
        if prior.endswith("\r\n"):
            prior = prior[:-2] + "\n"
        return hashlib.sha256(prior.encode("utf-8")).hexdigest() == expected
    except (OSError, ValueError, KeyError, TypeError):
        return False


class HistoricalEvidence:
    """Read archived documentation without restoring or authorizing runtime inputs."""

    def __init__(self, metadata: dict):
        self.metadata = metadata
        self.archive = None
        self.entries = {}
        self.verified = {}

    def _key(self, path: Path) -> str | None:
        try:
            key = path.resolve().relative_to(ROOT).as_posix()
        except ValueError:
            return None
        if not key.startswith(("docs/implementation/", "docs/reports/", "runs/", "tmp/")):
            return None
        return key

    def _load(self) -> None:
        if self.archive is not None:
            return
        archive_path = (ROOT / self.metadata["zip_relative_to_repo"]).resolve()
        manifest_path = (ROOT / self.metadata["manifest_relative_to_repo"]).resolve()
        if sha256(archive_path) != self.metadata["zip_sha256"]:
            raise ValueError("Cleanup recovery ZIP hash mismatch")
        if sha256(manifest_path) != self.metadata["manifest_sha256"]:
            raise ValueError("Cleanup recovery manifest hash mismatch")
        entries = {}
        for line in manifest_path.read_text(encoding="utf-8").splitlines():
            row = json.loads(line)
            key = row["path"]
            if key in entries or self._key(ROOT / key) != key:
                raise ValueError(f"Duplicate or unsafe cleanup archive entry: {key}")
            entries[key] = row
        archive = zipfile.ZipFile(archive_path)
        names = archive.namelist()
        if len(names) != len(set(names)) or set(names) != set(entries):
            archive.close()
            raise ValueError("Cleanup ZIP and exact manifest entry sets differ")
        self.entries = entries
        self.archive = archive

    def read_bytes(self, path: Path) -> bytes:
        if path.is_file():
            return path.read_bytes()
        key = self._key(path)
        if key is None:
            raise FileNotFoundError(path)
        self._load()
        if key not in self.entries:
            raise FileNotFoundError(path)
        if key not in self.verified:
            raw = self.archive.read(key)
            expected = self.entries[key]
            if len(raw) != expected["bytes"] or hashlib.sha256(raw).hexdigest() != expected["sha256"]:
                raise ValueError(f"Archived historical evidence hash mismatch: {key}")
            self.verified[key] = raw
        return self.verified[key]

    def read_text(self, path: Path) -> str:
        return self.read_bytes(path).decode("utf-8")

    def is_file(self, path: Path) -> bool:
        try:
            self.read_bytes(path)
            return True
        except FileNotFoundError:
            return False

    def exists(self, path: Path) -> bool:
        if path.exists():
            return True
        if self.is_file(path):
            return True
        key = self._key(path)
        return key is not None and any(name.startswith(key.rstrip("/") + "/") for name in self.entries)


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
    parser.add_argument("--report", type=Path)
    parser.add_argument("--delivery-protection", action="store_true",
                        help="Check this planning turn's original contracts and unrelated protected files.")
    args = parser.parse_args()
    errors: list[str] = []
    evidence_holds: list[str] = []
    manifest = json.loads((PLAN / "task_manifest.json").read_text(encoding="utf-8"))
    sys.path.insert(0, str(ROOT))
    from tools.agent_local_execution import policy_errors, _manifest_errors
    errors.extend(policy_errors(json.loads((PLAN / "execution_policy.json").read_text(encoding="utf-8"))))
    graph_errors, by_id = _manifest_errors(ROOT, manifest)
    errors.extend(graph_errors)
    tasks = manifest["tasks"]
    historical = HistoricalEvidence(manifest["evidence_archive"])
    if manifest.get("execution_policy") != "execution_policy.json" or manifest.get("execution_entry") != "tools/agent_local_execution.py":
        errors.append("Current local execution entry/policy drift")
    if manifest.get("primary") != PRIMARY_MODEL or manifest.get("workers") != SUBAGENT_MODEL:
        errors.append("Requested root/worker model drift")
    if manifest.get("max_concurrent_subagents") != MAX_CONCURRENT_SUBAGENTS:
        errors.append("Concurrent subagent limit drift")
    if manifest["goal"]["requirements"] != [f"R{i:02}" for i in range(1, 11)]:
        errors.append("R01-R10 requirements drift")
    if manifest["goal"].get("discovery_goal_achieved") or manifest["goal"].get("credible_candidate_count") != 0:
        errors.append("No terminal discovery acceptance evidence exists for this planning turn")
    policy = manifest["dispatch_policy"]
    if policy.get("heavy_execution") != "serialized_single_lane" or policy.get("shared_entry_owner") != "root" or policy.get("resource_memory_gib") != 4:
        errors.append("Serialized heavy lane/root ownership/current resource cap drift")
    if manifest["documentation_contract"].get("current_task_count") != len(tasks):
        errors.append("Task count mismatch")
    if manifest["execution_dispositions"]["t2_formal"].get("formal_t2_accepted") is not False:
        errors.append("Historical T2 must remain unaccepted")
    retired = {t["id"] for t in tasks if t.get("active") is False}
    if retired != {"UP1-04A-VNEXT-T2"}:
        errors.append("Unexpected retired task")
    if any(dep in retired for t in tasks if t.get("active") is not False for dep in t["depends_on"]):
        errors.append("Active dependency on retired T2")
    work = (PLAN / "16_execution_work_orders.md").read_text(encoding="utf-8")
    bench = (PLAN / "13_acceptance_benchmarks_and_evidence.md").read_text(encoding="utf-8")
    work_anchors = anchors(work)
    for task in tasks:
        tid = task["id"]
        if task["phase"] != tid.split("-")[0] or tid.lower() not in work_anchors:
            errors.append(f"Task phase/anchor mismatch: {tid}")
        if task["work_order_ref"] != f"16_execution_work_orders.md#{tid.lower()}":
            errors.append(f"Wrong work-order reference: {tid}")
        for key in ("technical_doc", "acceptance_protocol_ref"):
            if not (PLAN / task[key]).is_file():
                errors.append(f"Missing guidance {key}: {tid}")
        for ref in task.get("guidance_refs", []):
            if not (PLAN / ref.split("#", 1)[0]).is_file():
                errors.append(f"Missing task guidance: {tid}: {ref}")
        if any(b not in bench for b in task["benchmarks"]):
            errors.append(f"Missing benchmark: {tid}")
        section = work.split(f'<a id="{tid.lower()}"></a>', 1)[-1].split('<a id="', 1)[0]
        contract_section = section
        if task["status"] == "accepted":
            # Completed detail lives in implementation records; the exact
            # original acceptance terms remain protected below.
            contract_ref = task.get("acceptance_contract_ref")
            if contract_ref:
                filename, _, fragment = contract_ref.partition("#")
                contract_path = (ROOT / filename).resolve()
                if (not contract_path.is_relative_to(ROOT / "docs/implementation")
                        or not contract_path.is_file() or fragment != tid.lower()):
                    errors.append(f"Invalid archived acceptance contract: {tid}")
                else:
                    contract_text = contract_path.read_text(encoding="utf-8")
                    marker = f'<a id="{fragment}"></a>'
                    if marker not in contract_text:
                        errors.append(f"Missing archived acceptance anchor: {tid}")
                    contract_section = contract_text.split(marker, 1)[-1].split('<a id="', 1)[0]
            if task.get("steps") or not task.get("acceptance_record"):
                errors.append(f"Completed steps remain or no historical evidence pointer: {tid}")
            elif not historical.is_file(ROOT / task["acceptance_record"]):
                if task.get("acceptance_record_status") == "historical_original_missing_HOLD_if_required_by_actual_consumer":
                    evidence_holds.append(f"Historical original missing, current consumer must HOLD if required: {tid}")
                else:
                    errors.append(f"Current accepted evidence is missing: {tid}")
            if not task.get("owner") or not task.get("reviewer") or task["owner"] == task["reviewer"]:
                errors.append(f"Accepted record missing independent review: {tid}")
        elif task.get("active") is not False:
            for key in ("inputs", "write_scope", "steps"):
                if not task.get(key): errors.append(f"Incomplete remaining work order: {tid}/{key}")
            integration = task.get("integration_contract", {})
            for key in ("producer", "consumer", "shared_entry", "required_runtime_evidence", "parent_scope_remaining"):
                if not integration.get(key): errors.append(f"Missing integration contract: {tid}/{key}")
            assignment = task.get("execution_assignment", {})
            for role in ("implementer", "tester", "reviewer"):
                chosen = assignment.get(role, {})
                if {k:chosen.get(k) for k in ("model","reasoning_effort")} != SUBAGENT_MODEL:
                    errors.append(f"Worker model mismatch: {tid}/{role}")
            if assignment.get("integrator", {}).get("owner") != "root" or not assignment.get("distinct_implementer_tester_reviewer"):
                errors.append(f"Root integration/independent role mismatch: {tid}")
            if re.findall(r"^- 前置：(.*)。$", section, flags=re.M) != ["、".join(task["depends_on"]) or "无"]:
                errors.append(f"Prose dependency drift: {tid}")
        if task.get("active") is not False:
            for entry in task.get("steps", []) + task["acceptance"]:
                if entry not in contract_section: errors.append(f"Work-order contract drift: {tid}")
        if not task["acceptance"]: errors.append(f"Missing acceptance: {tid}")
    for lane in manifest["work_lines"]:
        for key in ("inputs", "outputs", "wiring", "gap", "gap_classification", "roles", "latest_evidence", "next_gate", "short_check"):
            if not lane.get(key):errors.append(f"Incomplete consumer interface: {lane['id']}/{key}")
        for value in lane["inputs"] + lane["latest_evidence"]:
            if not (ROOT / value).exists():errors.append(f"Missing actual consumer input/evidence: {lane['id']}: {value}")
        roles=lane["roles"]
        if len({roles["implementer"],roles["tester"],roles["reviewer"]}) != 3 or roles["integrator"] != "root":
            errors.append(f"Overlapping line roles: {lane['id']}")
    worker = (PLAN / "17_luna_worker_prompt.md").read_text(encoding="utf-8")
    try:
        template=json.loads(re.findall(r"```json\s*\n(.*?)\n```",worker,flags=re.S)[-1])
        if any(k not in template for k in manifest["worker_receipt_contract"]["fields"]):
            errors.append("Missing formal inverse receipt structures")
        for layer in ("g1","g2","g3"):
            if not {"typed_body_ref","source_hash","content_hash","canonical_hash","theta_field_mapping_ref"} <= set(template["genome_bundle"][layer]):
                errors.append(f"Incomplete formal inverse Genome mapping: {layer}")
    except (KeyError, IndexError, ValueError):errors.append("Invalid worker inverse template")
    checked_links = 0
    files = sorted(PLAN.glob("*.md"))
    for path in files:
        text = path.read_text(encoding="utf-8")
        if (not text.startswith("#") and path.name != "15_sol_system_prompt.md") or len(re.findall(r"^```",text,flags=re.M)) % 2:
            errors.append(f"Invalid title/code fence: {path.name}")
        for raw in re.findall(r"\[[^\]\n]+\]\((<[^>]+>|[^)\n]+)\)",without_fences(text)):
            target=raw[1:-1] if raw.startswith("<") else raw
            if urlsplit(target).scheme:continue
            filename,_,fragment=unquote(target).partition("#")
            linked=(path.parent/filename).resolve() if filename else path
            checked_links+=1
            if not historical.exists(linked):
                if linked.is_relative_to(ROOT / "docs/implementation/history/20260914_planning_baseline"):
                    evidence_holds.append(f"Unavailable historical snapshot link, not current guidance: {path.name}: {target}")
                else:
                    errors.append(f"Missing current link: {path.name}: {target}")
            elif fragment and historical.is_file(linked) and linked.suffix==".md" and fragment not in anchors(historical.read_text(linked)):
                errors.append(f"Missing anchor: {path.name}: {target}")
    protection=json.loads((ROOT/"docs/implementation/planning_refresh_20261009.json").read_text(encoding="utf-8"))
    for tid,expected in protection["original_acceptance_contracts"].items():
        if by_id.get(tid,{}).get("acceptance") != expected:errors.append(f"Original acceptance contract changed: {tid}")
        if by_id.get(tid,{}).get("status") != protection["original_task_states"][tid]:errors.append(f"Task promoted by planning edit: {tid}")
    amendments_verified = []
    for name,expected in protection["normative_00_to_09_before"].items():
        if sha256(PLAN/name) != expected:
            if preexisting_normative_amendment_matches(PLAN/name, expected):
                amendments_verified.append(name)
            else:
                errors.append(f"Normative R/physics contract changed: {name}")
    if args.delivery_protection:
        for row in protection["protected_before"]:
            path=ROOT/row["path"]
            if not path.is_relative_to(PLAN) and sha256(path)!=row["sha256"]:
                errors.append(f"Unrelated protected file changed: {row['path']}")
    current=by_id["UP1-04A-VNEXT"]
    current_path=ROOT/current["acceptance_record"]
    try:
        record=json.loads(current_path.read_text(encoding="utf-8"))
        if (record.get("root_decision") != "accepted_limited_software_scope"
            or record.get("accepted_scope") != current.get("accepted_scope")
            or record.get("claim_ceiling") != "screen_only"
            or record.get("physical_status") != "unknown"
            or record.get("whole_UP2_physical") is not False or record.get("R01_R10") is not False):
            errors.append("Actual current UP1 accepted scope drift")
        for key in ("actual_source_pair","actual_native_pair"):
            artifact=ROOT/record[key]
            if not artifact.is_file() or sha256(artifact)!=record[key+"_sha256"]:
                errors.append(f"Actual current UP1 result missing/changed: {key}")
    except (OSError,ValueError,KeyError):errors.append("Current UP1 actual acceptance record invalid")
    state=manifest["current_state"]
    declared_execution = manifest.get("execution_state")
    expected_goal = {"paused_by_user_planning_update_only": "paused",
                     "active_after_explicit_user_resume": "active"}.get(declared_execution)
    if expected_goal is None or state.get("goal") != expected_goal:
        errors.append("Declared execution and goal states disagree; validator is not a runtime dispatch guard")
    if state.get("q1_8_original_gate") != 1e-6 or state.get("q1_8_scaledmax") != 1.5257218976168253e-5:
        errors.append("Original Q1_8 numerical failure/user limited acceptance changed")
    b00=(PLAN/"19_up0_02_contract_freeze.md").read_text(encoding="utf-8")
    if any(f"F{i}" not in b00 for i in range(6)) or any(f"N{i:02}" not in b00 for i in range(1,11)) or "50" not in b00:
        errors.append("B00 F0-F5/B04 50 coverage missing")
    prompt=(PLAN/"15_sol_system_prompt.md").read_text(encoding="utf-8").strip()
    if len(prompt)>500:errors.append("Root system prompt exceeds retained 500-character limit")
    result={"record_kind":"planning_validation_not_scientific_acceptance","checks":"pass" if not errors else "fail",
            "task_count":len(tasks),"task_dag_acyclic":not graph_errors,"accepted_scope_records":sum(t["status"]=="accepted" for t in tasks),
            "consumer_interfaces":len(manifest["work_lines"]),"relative_links_checked":checked_links,
            "historical_document_bytes_verified":len(historical.verified),"old_plan_revision_hash_chain_required":False,
            "goal":state.get("goal"),"execution_state":declared_execution,"runtime_dispatch_guard":False,
            "preexisting_normative_amendments_exact_delta_verified":amendments_verified,
            "historical_evidence_holds":evidence_holds,"errors":errors}
    if args.report:
        args.report.parent.mkdir(parents=True,exist_ok=True)
        args.report.write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(result,ensure_ascii=False,indent=2))
    return 0 if not errors else 1


if __name__ == "__main__":
    sys.exit(main())
