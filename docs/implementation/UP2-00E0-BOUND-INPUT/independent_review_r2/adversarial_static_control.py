from pathlib import Path
import hashlib,json,re
root=Path(__file__).parents[4]
arc=Path(__file__).parent
src=(root/"src/GenomeV5/UP2/UP2CandidatePhysicalBindingV1.jl").read_text(encoding="utf-8")
checks={}
checks["inspector_exception_program_exception"]="return up2e0_classify_exception(error)" in src and "status=:program_exception" in src
checks["ordinary_checker_uses_same_seam"]="_up2e0_check_package_with_inspector(package, expected_candidate_ref" in src
checks["factory_propagates_program_exception"]='check.status == :program_exception' in src and 'throw(ErrorException("UP2E0 program_exception:' in src
checks["package_join_compares_refs_hashes_axes"]=all(x in src for x in ("source_candidate_ref_mismatch","source_package_hash_mismatch","source_G1_ref_mismatch","source_G2_ref_mismatch","source_G3_ref_mismatch","source_G1_component_hash_mismatch","source_G2_component_hash_mismatch","source_G3_component_hash_mismatch","source_version_axes_mismatch"))
checks["binding_hash_participates_bound_input"]="profile_hash=profile_hash, binding_hash=binding_hash" in src
join_start=src.find("function up2e0_validate_binding(binding::UP2CandidatePhysicalBindingV1,\n")
join_end=src.find("\nend",join_start)
join=src[join_start:] if join_start>=0 else ""
checks["adversarial_source_join_status_conflation"]=join_start>=0 and "source = up2e0_check_package(package)" in join and "isempty(errors) ? (status=:valid" in join and "status=:fail_closed" in join
checks["r8_receipt_exit0"]= (root/"docs/implementation/UP2-00E0-BOUND-INPUT/taxonomy_fix/focused_r8.exit").read_text(encoding="utf-8").strip()=="0"
def sh(rel):
 b=(root/rel).read_bytes()
 return {"path":rel,"bytes":len(b),"sha256":hashlib.sha256(b).hexdigest()}
current={rel:sh(rel) for rel in ["src/GenomeV5/UP2/UP2CandidatePhysicalBindingV1.jl","test/GenomeV5/UP2/up2_candidate_physical_binding_tests.jl","test/GenomeV5/UP2/up2_candidate_physical_binding_fixtures.json","test/GenomeV5/UP2/run_up2_candidate_physical_binding.jl"]}
result={"record_kind":"UP2-00E0-R2-independent-static-control","verdict":"changes_requested","blocker":"public source-package join collapses program_exception to fail_closed","locations":{"inspector_seam":"src/GenomeV5/UP2/UP2CandidatePhysicalBindingV1.jl:186-197","checker":"src/GenomeV5/UP2/UP2CandidatePhysicalBindingV1.jl:201-206","factory":"src/GenomeV5/UP2/UP2CandidatePhysicalBindingV1.jl:324-329","source_join":"src/GenomeV5/UP2/UP2CandidatePhysicalBindingV1.jl:378-390"},"checks":checks,"current_hashes":current,"r8_evidence":"taxonomy_fix/focused_r8 exit0 is preserved author evidence; no independent R2 run","minimum_repair":"In up2e0_validate_binding(binding, package), preserve source.status=:program_exception (and its zero-call counters) as program_exception; only known source contradictions may become fail_closed. Add an injected-inspector control that reaches this public package-join overload.","claim_ceiling":{"contract_only":False,"N05_N06":False,"B00":False,"B04":False,"provider":False,"mesh":False,"engineering":False,"physical":False,"R01_R10":False}}
(arc/"adversarial_static_control.json").write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print(json.dumps(result,ensure_ascii=False,indent=2))
