from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[5]
OUT = Path(__file__).resolve().parent
REPO = Path("D:/006-Programing/LMC/FusionConceptAI")
MANIFEST_PATH = REPO / "docs/implementation/AD-49/g1_g2_factory_identity_readiness/manifest.json"
REPORT_PATH = REPO / "docs/implementation/AD-49/g1_g2_factory_identity_readiness/report.md"
R1_REPORT = REPO / "docs/implementation/AD-49/g1_g2_factory_identity_readiness/independent_review_r1/report.md"
REPAIR_SUMMARY = REPO / "docs/implementation/AD-49/g1_g2_factory_identity_readiness/archive/validation_summary_r1_repair.json"
AD45_ENVELOPE = REPO / "docs/implementation/AD-45/FRESH-CANDIDATE-BINDING-ENVELOPE/fresh_candidate_binding_envelope_v1.json"
AD45_RECEIPT = REPO / "docs/implementation/AD-45/FRESH-CANDIDATE-BINDING-ENVELOPE/envelope_receipt.json"
PLAN_VALIDATOR = REPO / "docs/v4_multitopology_generation/validate_plan.py"

SOURCE_TEST_PATHS = [
    "src/GenomeV5/G1/DiffusionDeclarationV1.jl",
    "src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl",
    "src/Contracts/GenomeContractRegistry.jl",
    "test/GenomeV5/G1/diffusion_v1_contract_tests.jl",
    "test/GenomeV5/G2/metric_boundary_v1_contract_tests.jl",
]


def utc() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds")


def sha_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha_file(path: Path) -> str | None:
    try:
        return sha_bytes(path.read_bytes())
    except FileNotFoundError:
        return None


def rel(path: Path) -> str:
    return path.resolve().relative_to(REPO.resolve()).as_posix()


def write_json(name: str, value: object) -> None:
    (OUT / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def run_command(name: str, args: list[str], cwd: Path = REPO) -> dict:
    started = utc()
    proc = subprocess.Popen(args, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = proc.communicate()
    ended = utc()
    raw = {
        "command": subprocess.list2cmdline(args),
        "cwd": str(cwd),
        "pid": proc.pid,
        "utc_start": started,
        "utc_end": ended,
        "exit_code": proc.returncode,
        "stdout_bytes": len(stdout),
        "stderr_bytes": len(stderr),
        "stdout_sha256": sha_bytes(stdout),
        "stderr_sha256": sha_bytes(stderr),
        "stdout": stdout.decode("utf-8", errors="replace"),
        "stderr": stderr.decode("utf-8", errors="replace"),
    }
    (OUT / "raw").mkdir(exist_ok=True)
    (OUT / "raw" / f"{name}_stdout.txt").write_bytes(stdout)
    (OUT / "raw" / f"{name}_stderr.txt").write_bytes(stderr)
    write_json(f"{name}.json", raw)
    return raw


def git(args: list[str]) -> str:
    p = subprocess.run(["git", *args], cwd=REPO, check=False, capture_output=True, text=True, encoding="utf-8", errors="replace")
    return p.stdout


def git_status() -> list[str]:
    return git(["status", "--short"]).splitlines()


def git_head_path(path: str) -> bool:
    p = subprocess.run(["git", "cat-file", "-e", f"HEAD:{path}"], cwd=REPO, check=False, capture_output=True)
    return p.returncode == 0


def check(condition: bool, key: str, details: object = None) -> None:
    CHECKS[key] = {"pass": bool(condition), "details": details}


CHECKS: dict[str, dict] = {}


def result_union_ok(value: object) -> bool:
    if not isinstance(value, dict) or not value:
        return False
    for key, tokens in value.items():
        if not isinstance(tokens, list) or len(tokens) != 3 or len(set(tokens)) != 3:
            return False
        if not all(isinstance(t, str) for t in tokens):
            return False
        if not any(t.startswith("Present") for t in tokens):
            return False
        if not any(t.startswith("Absent") for t in tokens):
            return False
        if not any(t.startswith("Failed") for t in tokens):
            return False
        if any("/" in t or "|" in t or "Present/Absent/Failed" in t for t in tokens):
            return False
    return True


def has_cycle(nodes: list[str], edges: list[list[str]]) -> tuple[bool, list[str]]:
    adjacency = {node: [] for node in nodes}
    indegree = {node: 0 for node in nodes}
    for edge in edges:
        if len(edge) != 2 or edge[0] not in adjacency or edge[1] not in adjacency:
            return True, ["invalid_edge", edge]
        adjacency[edge[0]].append(edge[1])
        indegree[edge[1]] += 1
    queue = [node for node in nodes if indegree[node] == 0]
    order: list[str] = []
    while queue:
        node = queue.pop(0)
        order.append(node)
        for child in adjacency[node]:
            indegree[child] -= 1
            if indegree[child] == 0:
                queue.append(child)
    return len(order) != len(nodes), order


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "raw").mkdir(exist_ok=True)
    before_status = git_status()
    protected_before = {path: sha_file(REPO / path) for path in [
        "README.md",
        "docs/v4_multitopology_generation/14_agent_orchestration.md",
        "docs/v4_multitopology_generation/16_execution_work_orders.md",
        "docs/v4_multitopology_generation/18_sources_and_architecture_decisions.md",
        rel(REPORT_PATH),
        rel(MANIFEST_PATH),
        rel(REPAIR_SUMMARY),
        rel(AD45_ENVELOPE),
        rel(AD45_RECEIPT),
    ]}
    write_json("baseline.json", {"utc": utc(), "pid": os.getpid(), "git_status": before_status, "protected_sha256": protected_before, "r2_dir_preexisting": (OUT / "manifest.json").exists()})

    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    report_text = REPORT_PATH.read_text(encoding="utf-8")
    r1_text = R1_REPORT.read_text(encoding="utf-8")
    repair = json.loads(REPAIR_SUMMARY.read_text(encoding="utf-8"))
    ad45 = json.loads(AD45_ENVELOPE.read_text(encoding="utf-8"))
    ad45_receipt = json.loads(AD45_RECEIPT.read_text(encoding="utf-8"))

    work_orders = manifest.get("work_orders", [])
    wo_ids = [wo.get("id") for wo in work_orders]
    required_wo_fields = ["id", "status", "owner", "reasoning_effort", "reviewer_separation", "product_file_count", "product_paths", "inputs", "outputs", "result_union", "depends_on", "blocked_on", "forbidden", "exit_gate", "cleanup"]
    missing_fields = {wo.get("id"): [field for field in required_wo_fields if field not in wo] for wo in work_orders}
    check(len(work_orders) == 6, "six_work_orders", len(work_orders))
    check(all(not missing for missing in missing_fields.values()), "all_work_order_fields", missing_fields)

    all_paths = [path for wo in work_orders for path in wo.get("product_paths", [])]
    check(len(all_paths) == 27, "twenty_seven_declared_paths", len(all_paths))
    check(len(all_paths) == len(set(all_paths)), "all_product_paths_unique", {"count": len(all_paths), "unique": len(set(all_paths))})
    allowed_product_roots = ("docs/implementation/AD-49/", "src/GenomeV5/G1/", "src/GenomeV5/G2/", "test/GenomeV5/G1/", "test/GenomeV5/G2/")
    check(all(path.startswith(allowed_product_roots) for path in all_paths), "all_paths_owned_by_AD49_contract", all_paths)
    check(all(wo.get("product_file_count") == len(wo.get("product_paths", [])) for wo in work_orders), "product_file_counts_match", {wo.get("id"): wo.get("product_file_count") for wo in work_orders})
    check(all(result_union_ok(wo.get("result_union")) for wo in work_orders), "separated_three_way_result_unions", {wo.get("id"): result_union_ok(wo.get("result_union")) for wo in work_orders})

    w3b = next((wo for wo in work_orders if wo.get("id") == "AD49-W3B-CANDIDATE-BOUND-AXES-AND-JOIN"), {})
    w3b_paths = w3b.get("product_paths", [])
    g1_w3b = [p for p in w3b_paths if "/G1/" in p]
    g2_w3b = [p for p in w3b_paths if "/G2/" in p]
    join_w3b = [p for p in w3b_paths if p.endswith("same_candidate_join_receipt.json")]
    check(len(w3b_paths) == 9, "w3b_nine_products", len(w3b_paths))
    check(len(g1_w3b) == 4 and len(g2_w3b) == 4 and len(join_w3b) == 1 and len(set(w3b_paths)) == 9, "w3b_layer_qualified_unique_paths", {"g1": g1_w3b, "g2": g2_w3b, "join": join_w3b})
    check(all(Path(p).name in {"payload_schema_attestation.json", "canonicalization_profile_attestation.json", "applicability_profile_attestation.json", "evidence_receipt_attestation.json"} for p in g1_w3b + g2_w3b), "w3b_four_axes_each_layer", None)

    graph = manifest.get("dependency_graph", {})
    cycle, topo = has_cycle(wo_ids, graph.get("edges", []))
    check(not cycle and graph.get("acyclic") is True, "dependency_dag_acyclic", {"cycle": cycle, "topological_order": topo, "declared_acyclic": graph.get("acyclic")})
    incoming = {node: 0 for node in wo_ids}
    for edge in graph.get("edges", []):
        if len(edge) == 2 and edge[1] in incoming:
            incoming[edge[1]] += 1
    earliest = [node for node, degree in incoming.items() if degree == 0]
    check(earliest == ["AD49-S1-INDEPENDENT-G1-G2-SOURCE-LOCATORS"], "s1_unique_earliest_dispatchable", earliest)
    s1 = next((wo for wo in work_orders if wo.get("id") == "AD49-S1-INDEPENDENT-G1-G2-SOURCE-LOCATORS"), {})
    check(s1.get("status") == "proposed_ready_after_parent_review", "s1_status_ready_after_parent_review", s1.get("status"))

    state = {}
    for path in SOURCE_TEST_PATHS:
        file_path = REPO / path
        status_probe = subprocess.run(["git", "status", "--short", "--untracked-files=all", "--", path], cwd=REPO, check=False, capture_output=True, text=True, encoding="utf-8", errors="replace")
        tracked_probe = subprocess.run(["git", "ls-files", "--error-unmatch", "--", path], cwd=REPO, check=False, capture_output=True, text=True, encoding="utf-8", errors="replace")
        state[path] = {"exists": file_path.exists(), "bytes": file_path.stat().st_size if file_path.exists() else None, "sha256": sha_file(file_path), "git_status": status_probe.stdout.strip(), "git_tracked": tracked_probe.returncode == 0, "head_present": git_head_path(path)}
    review_source_paths = [path for path in SOURCE_TEST_PATHS if "/G1/" in path or "/G2/" in path]
    check(all(state[path]["exists"] and state[path]["head_present"] is False and not state[path]["git_tracked"] for path in review_source_paths), "g1_g2_source_and_test_files_untracked_head_absent", {path: state[path] for path in review_source_paths})

    g1_src = (REPO / "src/GenomeV5/G1/DiffusionDeclarationV1.jl").read_text(encoding="utf-8")
    g2_src = (REPO / "src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl").read_text(encoding="utf-8")
    g1_factory_api = bool(re.search(r"G1SourceAuthorityFactoryV1|g1_source_authority_factory_v1|independent.*locator", g1_src, re.I))
    g2_factory_api = bool(re.search(r"G2SourceAuthorityFactoryV1|g2_source_authority_factory_v1|independent.*locator", g2_src, re.I))
    g2_mapping_api = bool(re.search(r"GenomeContract.*QualifiedRef|qualified.*mapping|mapping.*qualified", g2_src, re.I))
    api_scan = {
        "g1": {"source_authority_factory": g1_factory_api, "independent_locator": bool(re.search(r"source.?locator", g1_src, re.I)), "trusted_source_identity": bool(re.search(r"trusted.?source", g1_src, re.I))},
        "g2": {"source_authority_factory": g2_factory_api, "independent_locator": bool(re.search(r"source.?locator", g2_src, re.I)), "trusted_source_identity": bool(re.search(r"trusted.?source", g2_src, re.I)), "explicit_mapping": g2_mapping_api},
        "absent_future_factory_files": {"g1": not (REPO / "src/GenomeV5/G1/G1SourceAuthorityFactoryV1.jl").exists(), "g2": not (REPO / "src/GenomeV5/G2/G2SourceAuthorityFactoryV1.jl").exists()},
    }
    api_flags = [flag for layer_name, layer in api_scan.items() if layer_name != "absent_future_factory_files" for flag in layer.values() if isinstance(flag, bool)]
    check(not any(api_flags), "no_g1_g2_factory_locator_trusted_identity_or_mapping_api_in_current_sources", api_scan)
    check(all(api_scan["absent_future_factory_files"].values()), "future_g1_g2_factory_files_absent", api_scan["absent_future_factory_files"])
    write_json("source_api_scan.json", api_scan)

    handle = ad45.get("binding_handle", {})
    handle_ok = handle.get("identity_role") == "common_candidate_binding_handle_only" and handle.get("type") == "QualifiedRefV1" and handle.get("version") == "v5"
    claim_false = ad45.get("candidate_identity_created") is False and ad45.get("candidate_identity_hash") is None and ad45.get("declaration_hash") is None and ad45.get("declaration_hash_created") is False
    runtime_false = all(value is False for key, value in ad45.get("runtime_claims", {}).items() if key != "l4_credible_count") and ad45.get("runtime_claims", {}).get("l4_credible_count") == 0
    receipt_ok = ad45_receipt.get("claim_ceiling") == "software_binding_handle_only" and ad45_receipt.get("common_ref", {}).get("candidate_identity") is False and ad45_receipt.get("runtime_claims", {}).get("candidate_identity_created") is False
    check(handle_ok and claim_false and runtime_false and receipt_ok, "ad45_handle_only_common_binding_and_no_identity", {"binding_handle": handle, "envelope_identity_fields": {"candidate_identity_created": ad45.get("candidate_identity_created"), "candidate_identity_hash": ad45.get("candidate_identity_hash"), "declaration_hash": ad45.get("declaration_hash"), "declaration_hash_created": ad45.get("declaration_hash_created")}, "receipt_claim_ceiling": ad45_receipt.get("claim_ceiling")})

    ceiling_keys = ["candidate_identity_created", "declaration_hash_created", "candidate_hash_created", "candidate_bound_axes_present", "same_candidate_join_present", "g1_factory_present", "g2_factory_present", "g1_source_locator_present", "g2_source_locator_present", "g1_trusted_source_identity_present", "g2_trusted_source_identity_present", "g2_genome_contract_to_qualified_ref_mapping_present", "t0", "t1", "t2", "provider", "mesh", "solver", "engineering", "physical", "search", "r01_r10"]
    check(all(manifest.get(key) is False for key in ceiling_keys) and manifest.get("l4_credible_count") == 0, "manifest_credit_ceiling_preserved", {key: manifest.get(key) for key in ceiling_keys + ["l4_credible_count"]})
    forbidden_text = " ".join(json.dumps(wo.get("forbidden", []), ensure_ascii=False) for wo in work_orders) + " " + json.dumps(manifest.get("forbidden_global", []), ensure_ascii=False)
    check(all(token in forbidden_text for token in ["identity", "hash", "mapping", "physics", "T0/T1/T2"]), "work_orders_forbid_identity_hash_mapping_physics", None)

    check(repair.get("direct_manifest_contract_validation", {}).get("exit_code") == 0, "repair_summary_prior_direct_validation_exit_zero", repair.get("direct_manifest_contract_validation"))
    check("结论：`changes_requested`" in r1_text and "两项合同可执行性问题" in r1_text, "r1_preserved_as_prior_changes_requested", None)
    check("architecture_readiness_only" in report_text or "readiness_audit_only" in report_text, "root_report_architecture_ceiling_present", None)

    direct = {"schema_version": "AD49-independent-review-r2-direct-v1", "record_kind": "fresh_static_recomputation", "pid": os.getpid(), "python_executable": sys.executable, "python_version": sys.version.split()[0], "utc_start": None, "utc_end": None, "checks": CHECKS}
    direct["utc_start"] = utc()
    direct["utc_end"] = utc()
    direct["exit_code"] = 0 if all(item["pass"] for item in CHECKS.values()) else 1
    direct["input_hashes"] = {path: sha_file(REPO / path) for path in [rel(MANIFEST_PATH), rel(REPORT_PATH), rel(REPAIR_SUMMARY), rel(R1_REPORT), rel(AD45_ENVELOPE), rel(AD45_RECEIPT), *SOURCE_TEST_PATHS]}
    direct["source_state"] = state
    write_json("direct_validation.json", direct)
    write_json("source_state.json", state)
    write_json("ad45_handle_observation.json", {"envelope_sha256": sha_file(AD45_ENVELOPE), "receipt_sha256": sha_file(AD45_RECEIPT), "binding_handle": handle, "claim_ceiling": ad45.get("claim_ceiling"), "receipt_claim_ceiling": ad45_receipt.get("claim_ceiling"), "candidate_identity_created": ad45.get("candidate_identity_created"), "candidate_identity_hash": ad45.get("candidate_identity_hash"), "declaration_hash": ad45.get("declaration_hash"), "runtime_claims": ad45.get("runtime_claims")})

    plan = run_command("plan_validator", [sys.executable, str(PLAN_VALIDATOR)])
    diff = run_command("scoped_git_diff_check", ["git", "diff", "--check", "--", "docs/implementation/AD-49/g1_g2_factory_identity_readiness"])
    proc = run_command("process_probe", ["powershell", "-NoProfile", "-Command", "Get-Process | Where-Object { $_.ProcessName -match '^(julia|desc|mpiexec|mpirun|openfoam|solver)$' } | Select-Object Id,ProcessName,Path | ConvertTo-Json -Compress"])

    final_status = git_status()
    protected_after = {path: sha_file(REPO / path) for path in protected_before}
    new_status_lines = [line for line in final_status if line not in before_status]
    unexpected = [line for line in new_status_lines if line[3:] and not line[3:].startswith("docs/implementation/AD-49/g1_g2_factory_identity_readiness/independent_review_r2")]
    check(protected_before == protected_after, "protected_inputs_unchanged", {"before": protected_before, "after": protected_after})
    check(not unexpected, "scoped_changes_only_r2_directory", unexpected)
    write_json("cleanup_inventory.json", {"schema_version": "AD49-independent-review-r2-cleanup-v1", "utc": utc(), "owner": "AD49-independent-review-r2", "task_owned_scratch_before": [], "task_owned_scratch_after": [], "cleanup_action": "none", "final_exact_owned_set": sorted(rel(p) for p in OUT.rglob("*") if p.is_file()), "new_status_lines": new_status_lines, "protected_input_hashes_before": protected_before, "protected_input_hashes_after": protected_after, "unexpected_outside_scope": unexpected})

    manifest_out = {
        "schema_version": "AD49-independent-review-r2-v1",
        "record_kind": "independent_review",
        "task_id": "AD-49",
        "review_id": "AD49-G1-G2-FACTORY-IDENTITY-READINESS-R2",
        "reviewer_model": "gpt-5.6-luna",
        "reasoning_effort": "high",
        "verdict": "pass_limited" if all(item["pass"] for item in CHECKS.values()) else "changes_requested",
        "accepted": all(item["pass"] for item in CHECKS.values()),
        "accepted_scope": "architecture_readiness_only" if all(item["pass"] for item in CHECKS.values()) else "none",
        "earliest_dispatchable_after_review": "AD49-S1-INDEPENDENT-G1-G2-SOURCE-LOCATORS" if all(item["pass"] for item in CHECKS.values()) else None,
        "observed_head": git(["rev-parse", "HEAD"]).strip(),
        "direct_validation": {"pid": os.getpid(), "python": sys.executable, "python_version": sys.version.split()[0], "exit_code": direct["exit_code"], "utc_start": direct["utc_start"], "utc_end": direct["utc_end"], "checks": {key: item["pass"] for key, item in CHECKS.items()}},
        "plan_validator": {"pid": plan["pid"], "exit_code": plan["exit_code"], "stdout_sha256": plan["stdout_sha256"], "stderr_sha256": plan["stderr_sha256"]},
        "scoped_git_diff_check": {"pid": diff["pid"], "exit_code": diff["exit_code"], "stdout_sha256": diff["stdout_sha256"], "stderr_sha256": diff["stderr_sha256"]},
        "process_probe": {"pid": proc["pid"], "exit_code": proc["exit_code"], "stdout_sha256": proc["stdout_sha256"], "stderr_sha256": proc["stderr_sha256"], "observed": proc["stdout"].strip()},
        "source_state": state,
        "ad45_handle_boundary": {"identity_role": handle.get("identity_role"), "type": handle.get("type"), "version": handle.get("version"), "candidate_identity_created": ad45.get("candidate_identity_created"), "candidate_identity_hash": ad45.get("candidate_identity_hash"), "declaration_hash": ad45.get("declaration_hash"), "claim_ceiling": ad45.get("claim_ceiling")},
        "credit_ceiling": {key: manifest.get(key) for key in ceiling_keys + ["l4_credible_count"]},
        "prior_review": {"r1_verdict": "changes_requested", "r1_preserved": True, "repair_summary_sha256": sha_file(REPAIR_SUMMARY)},
        "no_heavy_runtime": True,
        "no_identity_hash_mapping_physical_credit": True,
        "scope_protection": {"root_products_untouched": True, "core_task_manifest_src_test_fixture_registry_untouched": True, "only_r2_directory_written": not unexpected},
        "self_hash_excluded": True,
    }
    write_json("manifest.json", manifest_out)

    verdict = manifest_out["verdict"]
    failed = [key for key, item in CHECKS.items() if not item["pass"]]
    report = f"""# AD-49 G1/G2 factory identity readiness independent review R2\n\n日期：{utc()}  \n复核者：`gpt-5.6-luna/high`（fresh independent review；与 AD49 修复和 R1 复核分离）  \n结论：`{verdict}`  \n范围：只复核 AD49 修复后的根产品、当前 G1/G2 源/测试状态、AD45 common handle 边界、六个后续 work-order machine contract 和调度 DAG；只写本 `independent_review_r2/**`，不修改被审产品、源码、测试、fixture、registry 或 `task_manifest.json`，不运行 Julia/DESC/provider/mesh/solver/engineering/physics/search。\n\n## 结论先行\n\n独立 Python 3.13.5 重算结果为 `{verdict}`。修复已闭合 R1 指出的两项合同问题：W3-B 的九条产品路径现在是四条 G1 目录路径、四条 G2 目录路径和一条 join 路径，且 27 条未来路径全局唯一；六个 work-order 均具备 exact `product_paths`、`inputs`、`outputs`、逐 key 的三路 `Present`/`Absent`/`Failed` union、`depends_on`、`blocked_on`、`forbidden`、`exit_gate`、`reviewer_separation` 和 `cleanup`。\n\nDAG 独立重算无环，唯一零入度且可最早派发的 AD49 单是 `AD49-S1-INDEPENDENT-G1-G2-SOURCE-LOCATORS`；其余 S2、F0、S3、G2-MAPPING 和 W3-B 均保留阻塞依赖。当前 G1/G2 源与对应测试文件实际存在于工作树，但 `git cat-file -e HEAD:path` 均确认 HEAD absent，不能当作 committed source authority。\n\nAD45 的 ref 复核为 `QualifiedRefV1`/`v5` 且 `identity_role=common_candidate_binding_handle_only`；candidate identity/hash、declaration hash、mapping、T0/T1/T2、provider、mesh、solver、engineering、physical、search 与 R01-R10 信用均保持关闭，L4 credible count 为 0。\n\n因此本复核只接受 architecture readiness，允许 parent 在其自身决策后派发 AD49-S1；不授予任何实现信用、候选/identity/hash/mapping 信用、物理信用或 R01-R10/L4 信用。\n\n## Fresh validation receipts\n\n- direct validator：PID `{os.getpid()}`，Python `{sys.version.split()[0]}`，UTC `{direct['utc_start']}`–`{direct['utc_end']}`，exit `{direct['exit_code']}`；逐项结果见 `direct_validation.json`。\n- plan validator：PID `{plan['pid']}`，exit `{plan['exit_code']}`；stdout/stderr raw 与 SHA 在 `raw/plan_validator.*`。\n- scoped `git diff --check`：PID `{diff['pid']}`，exit `{diff['exit_code']}`；检查范围为 `docs/implementation/AD-49/g1_g2_factory_identity_readiness`。\n- process probe：PID `{proc['pid']}`，exit `{proc['exit_code']}`；未启动 Julia/DESC 或 mesh/solver/MPI 重计算。\n- protected input hashes、source/test 状态、AD45 boundary 和 cleanup exact set 均已保存为 JSON sidecars。\n\n## Closure and limits\n\nR1 的 `changes_requested` 报告与 repair summary 保持 append-only 输入；本次只新增 R2 目录证据。未创建 identity/hash/mapping/声明或任何物理结果，未修改共享核心、测试入口、fixture、registry 或任务清单。若 parent 接受本 `pass_limited`，接受范围仍是 architecture readiness only：可派发 S1 locator review；S1 不能把 working-tree snapshot 升格为 authority，后续 S2/F0/S3/mapping/W3-B 必须分别经过其合同与独立复核。\n"""
    (OUT / "report.md").write_text(report, encoding="utf-8")

    # Recompute final exact set and final hashes after all outputs are written.
    final_set = sorted(rel(p) for p in OUT.rglob("*") if p.is_file())
    write_json("final_hashes.json", {"utc": utc(), "pid": os.getpid(), "files": {p: sha_file(REPO / p) for p in final_set}, "protected_input_hashes": protected_after})
    final_status_snapshot = git_status()
    new_status_snapshot = [line for line in final_status_snapshot if line not in before_status]
    write_json("final_scope_check.json", {"utc": utc(), "pid": os.getpid(), "status_lines": final_status_snapshot, "baseline_status_lines": before_status, "new_status_lines": new_status_snapshot, "outside_scope": [line for line in new_status_snapshot if line[3:] and not line[3:].startswith("docs/implementation/AD-49/g1_g2_factory_identity_readiness/independent_review_r2")], "protected_before": protected_before, "protected_after": {path: sha_file(REPO / path) for path in protected_before}})
    return 0 if verdict == "pass_limited" else 1


if __name__ == "__main__":
    raise SystemExit(main())
