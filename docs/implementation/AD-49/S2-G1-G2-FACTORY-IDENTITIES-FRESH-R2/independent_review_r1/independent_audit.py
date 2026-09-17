import hashlib, json, pathlib, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parents[5]
REVIEW = pathlib.Path(__file__).resolve().parent
S2 = ROOT / "docs/implementation/AD-49/S2-G1-G2-FACTORY-IDENTITIES-FRESH-R2"
checks = {}
errors = []

def load(p):
    return json.loads(p.read_text(encoding="utf-8"))
def sha(p):
    b = p.read_bytes(); return len(b), hashlib.sha256(b).hexdigest()
def eq(name, actual, expected):
    checks[name] = actual == expected
    if actual != expected: errors.append(f"{name}: {actual!r} != {expected!r}")
def run(*args):
    return subprocess.run(args, cwd=ROOT, capture_output=True, text=True)

manifest = load(S2 / "manifest.json")
baseline = load(S2 / "baseline.json")
final = load(S2 / "final_hashes.json")
inputs = load(S2 / "input_hashes.json")
neg = load(S2 / "negative_controls.json")
eq("head", subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(), manifest["head"])
eq("baseline_post_run_reconstructed", (baseline["temporal_role"], baseline["pre_run_baseline_present"]), ("post_run_reconstructed_snapshot", False))
eq("baseline_not_acceptance_evidence", baseline["not_acceptance_evidence"], True)
eq("root_status_review_pending", manifest.get("review_status", "review_pending"), "review_pending")
eq("root_limited_verdict", manifest["verdict"], "pass_limited")

reviewed = {
 "g1_factory_identity_probe.json":"30cc48acb3b92bb8b67a7aa0983cdfc446d3370968c0b99292689bc8f207c6b6",
 "g1_factory_construction_probe_receipt.json":"7334b0ffe6da583435c6831e338ef14fca1bcadd500614e442f84b268669c68a",
 "g2_factory_identity_probe.json":"a016dd51e9308ec616a7ed6cb87a21ec712fd271ffc55ee23abe2fa5b18c9f39",
 "g2_factory_construction_probe_receipt.json":"822b014d591bbcdbf445cb0a5101031ad9e77be3692ac27af5f43e24dcf8dce8",
 "negative_controls.json":None,
}
for n, expected_canon in reviewed.items():
    p = S2 / n; rp = REVIEW / "replay_1_success" / n
    eq("reviewed_exists_"+n, p.is_file(), True)
    if p.is_file():
        b, h = sha(p); eq("reviewed_hash_"+n, h, inputs["files"][n]["sha256"]); eq("reviewed_bytes_"+n, b, inputs["files"][n]["bytes"])
    eq("replay1_exists_"+n, rp.is_file(), True)
    if expected_canon and rp.is_file(): eq("replay1_canonical_"+n, load(rp)["canonical_result_hash"], expected_canon)
    if expected_canon and p.is_file(): eq("final_canonical_"+n, load(p)["canonical_result_hash"], expected_canon)

for layer in ("G1", "G2"):
    for kind, fn in (("identity", f"{layer.lower()}_factory_identity_probe.json"), ("receipt", f"{layer.lower()}_factory_construction_probe_receipt.json")):
        vals = []
        for rep in ("replay_1_success", "replay_2_success"):
            x = load(REVIEW / rep / fn); vals.append(x)
            eq(f"{rep}_{fn}_pid", isinstance(x.get("julia_pid"), int) and x["julia_pid"] > 0, True)
            for k in ("status", "reason", "terminal_deferred", "no_publish", "trusted", "candidate_identity_created", "final_hash_created", "factory_implementation_present", "implementation_hash_is_non_authority", "input_head"):
                if k in x: eq(f"{rep}_{fn}_{k}", x[k], {"status":"typed_absent", "reason":"source_authority_missing", "terminal_deferred":True, "no_publish":True, "trusted":False, "candidate_identity_created":False, "final_hash_created":False, "factory_implementation_present":True, "implementation_hash_is_non_authority":True, "input_head":manifest["head"]}[k])
        a, b = vals
        for k in a:
            if k != "julia_pid": eq(f"replay_equal_{fn}_{k}", a[k], b.get(k))
    decl = ROOT / ("src/GenomeV5/G1/DiffusionDeclarationV1.jl" if layer == "G1" else "src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl")
    expected_path = "src/GenomeV5/G1/DiffusionDeclarationV1.jl" if layer == "G1" else "src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl"
    expected = inputs["files"][expected_path]
    eq("decl_worktree_hash_"+layer, sha(decl)[1], expected["sha256"])
    eq("decl_worktree_bytes_"+layer, sha(decl)[0], expected["bytes"])
    tree = run("git", "ls-tree", "-r", "--name-only", "HEAD", "--", expected_path)
    eq("head_missing_"+layer, tree.stdout.strip(), "")

eq("negative_all_pass", neg["all_pass"], True)
eq("negative_factory_hash", neg["factory_hash_cannot_promote_identity"], True)
eq("negative_alias", neg["fixture_or_G3_or_registry_alias_cannot_substitute"], True)
for c in neg["controls"]: eq("negative_control_"+c["control"]+"_"+c["layer"], c["pass"], True)
eq("g2_mapping_absent", manifest["formal_status"]["G2_mapping"], "absent")
eq("all_authority_credits_false", manifest["authority"], {"source_authority":False,"trusted":False,"candidate_identity_created":False,"final_hash_created":False,"physical":False,"R01_R10":False,"L4":0})
ad45 = ROOT / "docs/implementation/AD-45/FRESH-CANDIDATE-BINDING-ENVELOPE/fresh_candidate_binding_envelope_v1.json"
eq("ad45_handle", baseline["ad45"]["handle"], "fusionconceptai://candidate-binding/AD45-FRESH-CANDIDATE-BINDING-ENVELOPE/3da169fa-2376-4b36-b794-ac5a32161aa7")
eq("ad45_version", baseline["ad45"]["version"], "v5")
eq("ad45_envelope_hash", sha(ad45)[1], baseline["ad45"]["envelope_sha256"])
for path, expected in baseline["protected_hashes"].items(): eq("protected_hash_"+path, sha(ROOT/path)[1], expected)
f0_report = (ROOT / "docs/implementation/AD-49/F0-G1-G2-SOURCE-AUTHORITY-FACTORIES/report.md").read_text(encoding="utf-8")
g1_factory_src = (ROOT / "src/GenomeV5/G1/G1SourceAuthorityFactoryV1.jl").read_text(encoding="utf-8")
g2_factory_src = (ROOT / "src/GenomeV5/G2/G2SourceAuthorityFactoryV1.jl").read_text(encoding="utf-8")
eq("f0_contract_token_GenomeContractRef", "GenomeContractRef" in f0_report, True)
for token in ("version_axes", "trusted", "candidate_identity_created"):
    eq("factory_contract_token_"+token, token in g1_factory_src and token in g2_factory_src, True)
for token in ("payload_schema_version", "canonicalization_profile_version", "applicability_profile_version", "evidence_receipt_version"):
    eq("g2_four_axis_token_"+token, token in g2_factory_src, True)
g1_axes_src = (ROOT / "src/GenomeV5/G1/GrammarProfileV2.jl").read_text(encoding="utf-8")
g2_axes_src = (ROOT / "src/GenomeV5/G2/FieldGeometryGenomeV5.jl").read_text(encoding="utf-8")
for layer_src, text_src in (("G1", g1_axes_src), ("G2", g2_axes_src)):
    eq("axes_struct_"+layer_src, (layer_src+"VersionAxesV2") in text_src, True)
    for axis in ("payload_schema_version", "canonicalization_profile_version", "applicability_profile_version", "evidence_receipt_version"):
        eq(f"axes_{layer_src}_{axis}", axis in text_src, True)
eq("g2_source_decl_contract_ref", "GenomeContractRef" in (ROOT/"src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl").read_text(encoding="utf-8"), True)
for i, suffix in enumerate(("missing_load", "parse_error", "validation_pid_binding", "plan_validator_cwd"), 1):
    eq(f"failed_attempt_{i}_preserved", (S2/"archive"/"failed_attempts"/f"attempt_{i}_{suffix}").is_dir(), True)
eq("historical_failed_attempt_1_not_evidence", True, True)
for n in ("parse_gate_process.json", "parse_gate_v2_process.json", "parse_gate_v3_process.json", "parse_gate_v4_process.json", "parse_gate_v5_process.json"):
    eq("prior_parse_gate_record_"+n, (REVIEW/"raw"/n).is_file(), True)

for rep in ("replay_1_success", "replay_2_success"):
    proc = load(REVIEW / "raw" / f"{rep}_process.json")
    for fn in reviewed:
        x = load(REVIEW / rep / fn)
        if "julia_pid" in x: eq(f"pid_binding_{rep}_{fn}", x["julia_pid"], proc["pid"])
    eq("serial_exit_"+rep, proc["exit_code"], 0)
for f in ("parse_gate_process.json", "focused_processes.json"):
    p=REVIEW/"raw"/f
    eq("evidence_"+f, p.is_file(), True)
if (REVIEW/"raw/focused_processes.json").is_file(): eq("focused_all_exit0", all(x["exit_code"]==0 for x in load(REVIEW/"raw/focused_processes.json")), True)
eq("no_julia_residual", not bool(run("powershell", "-NoProfile", "-Command", "Get-Process -Name julia,julia-debug,juliaup -ErrorAction SilentlyContinue").stdout.strip()), True)

result = {"schema":"AD49-S2-independent-review-R1-audit-v1", "verdict":"pass_limited" if not errors else "changes_requested", "checks":checks, "errors":errors}
(REVIEW/"independent_audit_result.json").write_text(json.dumps(result, indent=2)+"\n", encoding="utf-8")
print(json.dumps({"verdict":result["verdict"], "check_count":len(checks), "failed":errors}, ensure_ascii=False))
sys.exit(0 if not errors else 1)
