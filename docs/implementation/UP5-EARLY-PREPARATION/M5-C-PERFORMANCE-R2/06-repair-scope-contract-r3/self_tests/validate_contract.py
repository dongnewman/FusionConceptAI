"""Independent JSON-schema and cross-field contract oracle for M5-C R3.
No Julia or implementation module is imported or executed."""
from __future__ import annotations
import base64, copy, hashlib, json, pathlib, sys
from datetime import datetime, timezone
from jsonschema import Draft202012Validator, FormatChecker

ROOT = pathlib.Path(__file__).resolve().parents[1]
SCHEMAS = ROOT / "schemas"
ZERO = "0" * 64
NOW = "2026-09-17T04:00:00Z"
FC = FormatChecker()
RESULTS = []

def sha(b: bytes) -> str: return hashlib.sha256(b).hexdigest()
def b64(b: bytes) -> str: return base64.b64encode(b).decode()
def check(name, schema_name, value, good=True):
    schema = json.loads((SCHEMAS / schema_name).read_text(encoding="utf-8"))
    Draft202012Validator.check_schema(schema)
    errs = list(Draft202012Validator(schema, format_checker=FC).iter_errors(value))
    ok = not errs
    if ok != good:
        raise AssertionError(f"{name}: expected valid={good}, errors={[e.message for e in errs]}")
    RESULTS.append({"name": name, "schema": schema_name, "valid": ok, "expected": good})
    return value

def h(i: int) -> str: return f"{i:064x}"

def condition():
    kinds = ["type","rank","domain","unit","port","owner","interface","conservation"]
    return {"schema":"M5CAvailableConditionEnvelopeV3","envelope_version":"v3","envelope_id":"env-1","candidate_id":"cand-1","m5a_source_hash":h(1),"m5b_inverse_hash":h(2),"catalog_ref":"catalog-1","catalog_hash":h(3),"canonical_bytes":b64(b"env"),"canonical_sha256":h(4),"producer_owner":"m5c_adapter","required_all_met":True,"aggregate":"conditions_met","aggregate_reason":"met","precedence_index":13,"conditions":[{"kind":k,"ref":f"{k}-ref","expected_hash":h(10+i),"required":True,"fact_status":"met","fact_value":True,"fact_hash":h(20+i),"evidence_ref":f"evidence/{k}"} for i,k in enumerate(kinds)]}

def layer(kind, names):
    return {"layer":kind,"expected_field_names":names,"fields":[{"name":n,"present":True,"exact_bytes":True,"sha256":True,"owner_ref":True,"object_relation":True} for n in names],"status":"bound","typed_code":("binding."+kind)}

def binding():
    ls=[layer("m5a",["source_identity","canonical_source","canonical_program","composition_hash"]),layer("m5b",["source_identity","inverse_hash","m5a_upstream_hash"]),layer("owner_provenance",["owner_id","provenance_bytes","provenance_hash","provenance_ref"]),layer("catalog",["records","catalog_ref","catalog_hash","canonical_bytes","canonical_hash"]),layer("envelope",["version","candidate_id","m5a_hash","m5b_hash","results","required_closure"]),layer("rewrite",["rewrite_set_id","rule_id","rule_hash","checker","source_program"]),layer("derivation",["derivation_id","source_hash","budget","profile","usage","trace","provenance","artifact"]),layer("graph",["graph_id","source_hash","members","conditions","artifact_bytes","artifact_hash"]),layer("adapter",["schema","claim_ceiling","scope","status"])]
    return {"schema":"M5CFullBindingReceiptV3","receipt_id":"bind-1","candidate_id":"cand-1","layers":ls,"artifact_object_relation":"same_object","artifact_bytes":b64(b"graph"),"artifact_sha256":h(30),"graph_artifact_hash":h(30),"canonical_hash_relation":"equal","aggregate":"binding_ok","producer_owner":"m5c_adapter"}

def budget(rel):
    common={"schema":"M5CBudgetReceiptV3","requested_budget":None,"sealed_budget":None,"effective_budget":8,"budget_relation":rel,"budget_applied":"omitted_identity_preserve","budget_reason":"budget_omitted","sealed_budget_hash":ZERO,"result_status":"no_op","priority_rank":6,"input_overload":False,"sealed_product":False}
    if rel=="equal": common.update(requested_budget=8,sealed_budget=8,budget_applied="equal_identity_preserve",budget_reason="budget_equal",priority_rank=5,sealed_product=True)
    if rel=="sealed_budget_mismatch": common.update(requested_budget=9,sealed_budget=8,budget_applied="reject_sealed_mismatch",budget_reason="sealed_budget_mismatch",result_status="budget_mismatch",priority_rank=2,sealed_product=True)
    if rel=="over_limit": common.update(budget_applied="defer_over_limit",budget_reason="over_limit",result_status="terminal_deferred",priority_rank=3)
    if rel=="input_overload": common.update(budget_applied="rebuild_input_overload",budget_reason="input_overload",result_status="rebuilt",priority_rank=4,input_overload=True)
    if rel=="invalid": common.update(budget_applied="reject_invalid",budget_reason="invalid_budget",result_status="fail_closed",priority_rank=1)
    return common

def collision():
    a=b"M5C-A"; b=b"M5C-B"; ka=b"key-A"; kb=b"key-B"
    hostile={"pid":42,"utc":NOW,"exit_code":0,"stdout_path":"raw/h.out","stderr_path":"raw/h.err","combined_path":"raw/h.combined","stdout_bytes":1,"stderr_bytes":0,"combined_bytes":1,"stdout_sha256":h(40),"stderr_sha256":h(41),"combined_sha256":h(42),"status":"completed"}
    return {"schema":"M5CCollisionReceiptV3","protocol":"M5CTestDigestV1","injection":{"protocol":"M5CTestDigestV1","forced_digest":h(50),"deterministic":True,"seed":"fixed"},"payload_a":{"bytes":b64(a),"sha256":sha(a),"key_domain":"proposal"},"payload_b":{"bytes":b64(b),"sha256":sha(b),"key_domain":"proposal"},"forced_digest":h(50),"digest_equal":True,"bucket_id":"bucket-1","full_key_a":b64(ka),"full_key_b":b64(kb),"full_key_sha256_a":sha(ka),"full_key_sha256_b":sha(kb),"full_key_equal":False,"outcome":"key_collision","aggregate":"fail_closed","domain_outcomes":[{"domain":"proposal","emitted_id":"p-1","result":"key_collision"},{"domain":"member","emitted_id":"m-1","result":"key_collision"},{"domain":"visited","emitted_id":"v-1","result":"key_collision"}],"emitted_ids":{"proposal":["p-1"],"member":["m-1"],"visited":["v-1"]},"hostile_supervisor_receipt":hostile}

def supervisor():
    return {"schema":"M5CSupervisorReceiptV3","run_id":"run-1","stage":"query","command":["julia","--startup-file=no","--history-file=no"],"startup_file_flag":"--startup-file=no","history_file_flag":"--history-file=no","cwd":"D:/FusionConceptAI","host":"local","supervisor_pid":99,"child_pid":100,"child_parent_pid":99,"pre_process_count":0,"post_process_count":0,"utc_start":NOW,"utc_end":"2026-09-17T04:00:01Z","deadline_utc":"2026-09-17T04:00:10Z","supervisor_wall_seconds":1.0,"supervisor_exit_code":0,"supervisor_exit_relation":"zero","raw_exit_code":0,"termination":"completed","timeout_class":"within_deadline","stdout_path":"raw/query.stdout.raw","stderr_path":"raw/query.stderr.raw","combined_path":"raw/query.combined.raw","stdout_bytes":1,"stdout_sha256":h(60),"stderr_bytes":0,"stderr_sha256":h(61),"combined_bytes":1,"combined_sha256":h(62),"input_artifact_hash":h(63),"output_artifact_hash":h(64),"status":"completed","receipt_sha256":h(65)}

def cache():
    return {"schema":"M5CCacheReceiptV3","derivation_id":"d-1","product_id":"p-1","cache_owner":"m5c_adapter","cache_id":"cache-1","entry_count":1,"entries":[{"entry_id":"e-1","owner_derivation_id":"d-1","owner_product_id":"p-1","immutable_key_bytes":b64(b"key"),"immutable_key_sha256":sha(b"key"),"payload_bytes":b64(b"payload"),"payload_sha256":sha(b"payload"),"canonical_bytes":b64(b"canonical"),"canonical_sha256":sha(b"canonical"),"validation_receipt_bytes":b64(b"validation"),"validation_sha256":sha(b"validation"),"sealed":True}],"shared_entry_ids":[],"escape_detected":False,"cross_derivation_hit":False,"cross_product_hit":False,"alias_detected":False,"mutation_after_seal":False,"clear_drop_reuse":False,"payload_hash":h(70),"canonical_hash":h(71),"validation_hash":h(72),"cache_status":"cache_same_identity"}

def preflight():
    R={"n":2,"rule_count":1,"projected_members":2,"projected_trace_steps":3,"projected_provenance_bytes":4,"factorial_order_upper_bound":2,"projected_canonical_bytes":5}
    lim={"max_members":10,"max_trace_steps":10,"max_provenance_bytes":10,"max_factorial_order":10,"max_canonical_bytes":10,"max_budget":10}
    return {"receipt_id":"pre-1","schema":"M5CPreflightReceiptV3","derivation_input_hash":h(80),"candidate_id":"cand-1","m5a_source_hash":h(81),"m5b_inverse_hash":h(82),"R":R,"limits":lim,"requested_budget":2,"effective_budget":2,"arithmetic":{"base":"UInt128","cap":11,"saturated_fields":[],"overflow":False,"nonfinite":False},"decision":"admit","result_status":"admitted","reason":"within_limits","guard_phase":"before_rewrite_set_and_canonical","canonical_writer_called":False,"rewrite_set_constructor_called":False,"utc":NOW,"producer_owner":"m5c_adapter"}

def stage(): return {"schema":"M5CStageReceiptV3","stage":"include","raw_line_ids":["probe.stdout.raw:L3"],"observed_count":8,"corrected_count":8,"status":"historical_raw_supported","input_hash":h(90),"receipt_sha256":h(91)}

def freeze():
    paths=["src/RuntimeV4/M4Isolated/ManufacturedConditionalEGraphV1.jl","test/RuntimeV4/M4Isolated/manufactured_conditional_egraph_v1_tests.jl","test/RuntimeV4/M4Isolated/oracles/conditional_egraph_oracle_v1.py","test/RuntimeV4/M4Isolated/m5c_perf_r2/profile_probe.jl","src/IR/ConditionalEGraphTypes.jl","src/IR/ConditionalEGraphSaturation.jl","src/Canonical/ConditionalEGraphCanonical.jl","src/Canonical/TypedASTProgramCanonical.jl","src/RuntimeV4/M4Isolated/ManufacturedAutoCompositionV1.jl","src/RuntimeV4/M4Isolated/ManufacturedInverseFeedbackV1.jl"]
    cur=[{"path":p,"bytes":1,"sha256":h(100+i)} for i,p in enumerate(paths)]
    hist=[{"path":f"historical/{i}","bytes":None,"sha256":h(120+i),"historical_only":True} for i in range(6)]
    return {"schema":"M5CFreezeReceiptV3","run_id":"freeze-1","mode":"read_only_static_fresh_freeze","capture_command":"read-only freeze","command_exit":0,"cwd":"D:/FusionConceptAI","host":"local","powershell_pid":1,"utc_start":NOW,"utc_end":"2026-09-17T04:00:01Z","head":"a"*40,"branch":"main","pre_process_count":{"julia":0},"post_process_count":{"julia":0},"execution":{"julia_started":False,"desc_started":False,"s3_started":False,"solver_started":False,"mesh_started":False,"search_started":False,"physical_started":False},"current_inputs":cur,"historical_inputs":hist,"raw_row_mapping_ref":"acceptance_matrix.md#2-raw-row-corrected-count-mapping","raw_row_mapping_sha256":h(130),"receipt_sha256":"excluded_until_manifest_seal"}

def artifact(path, owner="scope_owner", role="schema"):
    return {"owner":owner,"relative_path":path,"creation_utc":NOW,"source_run_id":"r3-self-test","overwrites":[],"bytes":1,"sha256":h(140),"role":role}

def manifest():
    frozen=[artifact(p,o,"current_frozen_input") for p,o in [("src/RuntimeV4/M4Isolated/ManufacturedConditionalEGraphV1.jl","m5c_adapter"),("test/RuntimeV4/M4Isolated/manufactured_conditional_egraph_v1_tests.jl","m5c_test"),("test/RuntimeV4/M4Isolated/oracles/conditional_egraph_oracle_v1.py","m5c_oracle"),("test/RuntimeV4/M4Isolated/m5c_perf_r2/profile_probe.jl","m5c_probe")]]
    return {"schema":"M5CPerformanceRepairManifestV3","contract_id":"M5-C-PERFORMANCE-R2-REPAIR-SCOPE-CONTRACT-R3","status":"review_pending","implementation_authorized":False,"not_implemented":True,"scope":"manufactured_conditional_egraph/screen_only","claim_ceiling":"synthetic_egraph_equality/screen_only","formal_credit":"none","write_root":"docs/implementation/UP5-EARLY-PREPARATION/M5-C-PERFORMANCE-R2/06-repair-scope-contract-r3/**","artifacts":[artifact("schemas/condition_envelope_schema.json")],"frozen_inputs":frozen,"manifest_self_hash":"excluded_by_policy"}

def custom_checks():
    # Cross-field equalities not expressible in JSON Schema.
    c=condition(); assert [x["kind"] for x in c["conditions"]]==["type","rank","domain","unit","port","owner","interface","conservation"]
    b=binding(); assert len({x["layer"] for x in b["layers"]})==9 and b["artifact_sha256"]==b["graph_artifact_hash"]
    p=preflight(); assert p["arithmetic"]["cap"] > max(p["limits"].values()) and p["decision"]=="admit"
    x=collision(); assert sha(base64.b64decode(x["payload_a"]["bytes"]))==x["payload_a"]["sha256"] and sha(base64.b64decode(x["payload_b"]["bytes"]))==x["payload_b"]["sha256"] and x["full_key_sha256_a"]!=x["full_key_sha256_b"]
    s=supervisor(); assert s["child_parent_pid"]==s["supervisor_pid"] and s["post_process_count"]==0
    k=cache(); assert k["entry_count"]==len(k["entries"]) and all(e["owner_derivation_id"]==k["derivation_id"] and e["owner_product_id"]==k["product_id"] for e in k["entries"])
    base=json.loads((ROOT/"baseline_capture_contract.json").read_text(encoding="utf-8")); assert base["typed_status"]=="typed_absent" and base["source_run_id"] is None and base["baseline_receipt_path"] is None
    RESULTS.append({"name":"custom_cross_field_relations","valid":True,"expected":True})

def main():
    check("receipt-bundle-positive","receipt_schema.json",{"schema":"M5CReceiptSchemaBundleV3","status_enum":["conditions_met","condition_unmet","fail_closed","terminal_deferred","not_measured","program_exception","human_interruption","not_executed"],"aggregate_precedence":["malformed","foreign","duplicate","wrong_link","detached","altered","status_mismatch","evaluator_fault","contradiction","unknown","not_applicable","absent","unmet","met"],"stage_enum":["include","upstream_first_compile_plus_build","upstream_warm_build","prepare_condition_catalog","prepare_rhs","prepare_source_cold_hash","prepare_rewrite_set","saturate_budget_2_4_1_2","saturate_budget_3_8_2_3","saturate_budget_4_16_3_4","saturate_budget_8_32_4_8","query","replay","validate"],"budget_priority":["invalid","sealed_budget_mismatch","over_limit","input_overload","equal","omitted"],"schemas":{"preflight":"M5CPreflightReceiptV3","condition_envelope":"M5CAvailableConditionEnvelopeV3","binding":"M5CFullBindingReceiptV3","budget":"M5CBudgetReceiptV3","collision":"M5CCollisionReceiptV3","supervisor":"M5CSupervisorReceiptV3","cache":"M5CCacheReceiptV3","freeze":"M5CFreezeReceiptV3","stage":"M5CStageReceiptV3"},"baseline_gate":"typed_absent_until_fresh_unrepaired_sealed_baseline_capture"})
    check("condition-positive","condition_envelope_schema.json",condition())
    check("condition-order-negative","condition_envelope_schema.json",{**condition(),"conditions":list(reversed(condition()["conditions"]))},False)
    check("binding-positive","binding_schema.json",binding())
    check("binding-layer-negative","binding_schema.json",{**binding(),"layers":binding()["layers"][:8]},False)
    for rel in ["omitted","equal","sealed_budget_mismatch","over_limit","input_overload","invalid"]: check("budget-"+rel,"budget_schema.json",budget(rel))
    check("collision-positive","collision_schema.json",collision())
    check("collision-branch-negative","collision_schema.json",{**collision(),"outcome":"dedup_allowed"},False)
    check("supervisor-positive","supervisor_schema.json",supervisor())
    check("supervisor-post-process-negative","supervisor_schema.json",{**supervisor(),"post_process_count":1},False)
    check("cache-positive","cache_schema.json",cache())
    check("cache-entry-negative","cache_schema.json",{**cache(),"entries":[{**cache()["entries"][0],"payload_bytes":None}]},False)
    check("preflight-positive","preflight_schema.json",preflight())
    check("preflight-writer-negative","preflight_schema.json",{**preflight(),"canonical_writer_called":True},False)
    check("stage-positive","stage_receipt_schema.json",stage())
    check("stage-not-measured","stage_receipt_schema.json",{**stage(),"status":"not_measured","observed_count":None,"corrected_count":None})
    check("freeze-positive","freeze_schema.json",freeze())
    check("manifest-positive","manifest_schema.json",manifest())
    custom_checks()
    print(json.dumps({"schema":"M5C-R3-CONTRACT-SELF-TEST-V1","status":"pass","test_count":len(RESULTS),"tests":RESULTS,"julia_process_count":0,"implementation_started":False},ensure_ascii=False,indent=2))

if __name__ == "__main__":
    try: main()
    except Exception as exc:
        print(json.dumps({"schema":"M5C-R3-CONTRACT-SELF-TEST-V1","status":"fail","error":str(exc),"julia_process_count":0,"implementation_started":False},ensure_ascii=False,indent=2)); sys.exit(1)
