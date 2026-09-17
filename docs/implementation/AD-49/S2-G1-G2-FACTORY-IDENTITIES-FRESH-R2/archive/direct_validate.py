from __future__ import annotations

import hashlib
import json
import subprocess
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[5]
TARGET = ROOT / "docs/implementation/AD-49/S2-G1-G2-FACTORY-IDENTITIES-FRESH-R2"

EXPECTED_HEAD = "4b69f55f7f80240147a65a22809dc1207824dde2"
FACTORIES = {
    "G1": ("src/GenomeV5/G1/G1SourceAuthorityFactoryV1.jl", "23684a9e6bb267d6fdfe06df5acc8f7c8cf299ac8c8bf8433ae601c9fdb4331b", "840ec00d25e069b13af1562a9e4ebb7ab1b2896a0818dc1fa15a3c7167c770a5"),
    "G2": ("src/GenomeV5/G2/G2SourceAuthorityFactoryV1.jl", "5b5d013a0ad5ee6eb07f714480e36911be9aa96636a3d3f368f38163240409c8", "439a2d496be0e7c6bd8bbefb7790f4f45f577e7b3954901a5914a5276b5294fa"),
}
PROTECTED = {
    "src/Contracts/GenomeContractRegistry.jl": "ee57228623e314897a3e34f3bfd387e8cce4d89c2b0dfaaf29d227076a08495c",
    "src/FusionConceptAI.jl": "e3fa8638ed9c5c5f468ae9a8f797416f2bec19b432cc10a9c1aea81ec3460783",
    "src/IR/OperatorRegistry.jl": "4c2f4383140527613782288749283d268497846ec915df158164875125677f45",
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git(*args: str) -> str:
    return subprocess.run(["git", *args], cwd=ROOT, check=False, capture_output=True, text=True).stdout.strip()


def check(name: str, ok: bool, detail: str) -> dict[str, object]:
    return {"name": name, "pass": bool(ok), "detail": detail}


def main() -> int:
    checks: list[dict[str, object]] = []
    checks.append(check("head_frozen", git("rev-parse", "HEAD") == EXPECTED_HEAD, git("rev-parse", "HEAD")))
    for layer, (path, expected_factory, expected_s1) in FACTORIES.items():
        checks.append(check(f"{layer}_factory_hash_closure", sha(ROOT / path) == expected_factory, sha(ROOT / path)))
        tracked = git("ls-files", "--", path)
        tree = git("ls-tree", "-r", "--name-only", "HEAD", "--", path)
        checks.append(check(f"{layer}_declaration_not_head_tracked", not tree and not tracked, f"ls-files={tracked!r}; ls-tree={tree!r}"))
        loc_path = TARGET / f"{layer.lower()}_factory_identity_probe.json"
        rec_path = TARGET / f"{layer.lower()}_factory_construction_probe_receipt.json"
        loc = json.loads(loc_path.read_text(encoding="utf-8"))
        rec = json.loads(rec_path.read_text(encoding="utf-8"))
        for kind, obj in (("identity", loc), ("receipt", rec)):
            checks.append(check(f"{layer}_{kind}_typed_absent", obj["status"] == "typed_absent", obj["status"]))
            checks.append(check(f"{layer}_{kind}_deferred_no_publish", obj["terminal_deferred"] and obj["no_publish"], "terminal_deferred/no_publish"))
            checks.append(check(f"{layer}_{kind}_no_identity_credit", not obj.get("candidate_identity_created", False) and not obj.get("final_hash_created", False) and not obj.get("trusted", False), "candidate/final/trusted=false"))
            checks.append(check(f"{layer}_{kind}_factory_software_only", obj["factory_implementation_present"] and not obj.get("source_construction_identity_present", obj.get("constructed_declaration_present", False)), "implementation_present=true; constructed=false"))
            checks.append(check(f"{layer}_{kind}_factory_hash_bound", obj["factory_implementation_hash"] == expected_factory == obj["f0_factory_hash"], obj["factory_implementation_hash"]))
            checks.append(check(f"{layer}_{kind}_s1_hash_bound", obj["s1_locator_hash"] == expected_s1, obj["s1_locator_hash"]))
            checks.append(check(f"{layer}_{kind}_replay_canonical_equal", obj["canonical_result_hash"] == obj["replay_canonical_result_hash"], obj["canonical_result_hash"]))
            checks.append(check(f"{layer}_{kind}_head_bound", obj["input_head"] == EXPECTED_HEAD, obj["input_head"]))
        if layer == "G1":
            checks.append(check("G1_locator_repository_head_absent", loc["locator"] == {"record_path":"docs/implementation/AD-49/G1-SOURCE-LOCATOR/g1_source_locator_v1.json", "status":"typed_absent", "provenance":"repository_head", "head_path_closure":"absent"}, str(loc["locator"])))
        else:
            checks.append(check("G2_locator_repository_head_absent", loc["locator"] == {"record_path":"docs/implementation/AD-49/G2-SOURCE-LOCATOR/g2_source_locator_v1.json", "status":"typed_absent", "provenance":"repository_head", "head_path_closure":"absent"}, str(loc["locator"])))

    g1 = json.loads((TARGET / "g1_factory_identity_probe.json").read_text(encoding="utf-8"))
    g2 = json.loads((TARGET / "g2_factory_identity_probe.json").read_text(encoding="utf-8"))
    checks.append(check("layer_bound_result_hashes", g1["canonical_result_hash"] != g2["canonical_result_hash"], f"G1={g1['canonical_result_hash']}; G2={g2['canonical_result_hash']}"))
    neg = json.loads((TARGET / "negative_controls.json").read_text(encoding="utf-8"))
    names = {x["control"] for x in neg["controls"]}
    required = {"locator_missing", "anchor_unavailable", "foreign_or_conflicting_handle", "factory_hash_cannot_promote_identity", "fixture_G3_registry_alias_cannot_substitute"}
    checks.append(check("negative_controls_all_pass", neg["all_pass"] and all(x["pass"] for x in neg["controls"]), "all_pass=true"))
    checks.append(check("negative_controls_required", required <= names, ",".join(sorted(names))))
    for path, expected in PROTECTED.items():
        checks.append(check(f"protected_{path}", sha(ROOT / path) == expected, sha(ROOT / path)))
    success = json.loads((TARGET / "raw/formal_s2_probe_r2_success_process.json").read_text(encoding="utf-8"))
    replay2 = json.loads((TARGET / "raw/formal_s2_probe_r2_replay2_process.json").read_text(encoding="utf-8"))
    checks.append(check("formal_success_exit0", success["exit_code"] == 0, str(success["exit_code"])))
    checks.append(check("formal_replay2_exit0", replay2["exit_code"] == 0, str(replay2["exit_code"])))
    for label, receipt in (("success", success), ("replay2", replay2)):
        try:
            start = datetime.fromisoformat(receipt["utc_start"].replace("Z", "+00:00"))
            end = datetime.fromisoformat(receipt["utc_end"].replace("Z", "+00:00"))
            ok = end > start
        except (KeyError, ValueError):
            ok = False
        checks.append(check(f"formal_{label}_utc_range", ok, f"{receipt.get('utc_start')}..{receipt.get('utc_end')}"))
    formal_names = ("g1_factory_identity_probe.json", "g1_factory_construction_probe_receipt.json", "g2_factory_identity_probe.json", "g2_factory_construction_probe_receipt.json", "negative_controls.json")
    replay1_products = [json.loads((TARGET / "archive/replay_1" / path).read_text(encoding="utf-8")) for path in formal_names]
    current_products = [json.loads((TARGET / path).read_text(encoding="utf-8")) for path in formal_names]
    checks.append(check("replay1_products_bind_success_pid", all(str(x.get("julia_pid")) == str(success["pid"]) for x in replay1_products if "julia_pid" in x), str(success["pid"])))
    checks.append(check("current_products_bind_replay2_pid", all(str(x.get("julia_pid")) == str(replay2["pid"]) for x in current_products if "julia_pid" in x), str(replay2["pid"])))
    def without_process_metadata(obj: dict[str, object]) -> dict[str, object]:
        return {k: v for k, v in obj.items() if k not in {"julia_pid"}}

    for path in formal_names:
        first = json.loads((TARGET / "archive/replay_1" / path).read_text(encoding="utf-8"))
        current = json.loads((TARGET / path).read_text(encoding="utf-8"))
        if path == "negative_controls.json":
            ok = without_process_metadata(first) == without_process_metadata(current)
            detail = "semantic JSON equal"
        else:
            ok = without_process_metadata(first) == without_process_metadata(current)
            detail = current["canonical_result_hash"]
        checks.append(check(f"replay1_replay2_{path}", ok, detail))
    result = {"schema_version":"AD49-S2-direct-validation-v1", "all_pass": all(x["pass"] for x in checks), "checks": checks}
    print(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    return 0 if result["all_pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
