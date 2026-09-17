from pathlib import Path
import json
root=Path(__file__).parents[4]
arc=Path(__file__).parent
src=(root/"src/GenomeV5/UP2/UP2CandidatePhysicalBindingV1.jl").read_text(encoding="utf-8")
test=(root/"test/GenomeV5/UP2/up2_candidate_physical_binding_tests.jl").read_text(encoding="utf-8")
checks={}
checks["inspector_seam_program_exception"]="return up2e0_classify_exception(error)" in src and "status=:program_exception" in src
checks["ordinary_checker_same_seam"]="_up2e0_check_package_with_inspector(package, expected_candidate_ref" in src
helper_start=src.find("function _up2e0_validate_binding_with_checker(binding::UP2CandidatePhysicalBindingV1,")
helper=src[helper_start:] if helper_start>=0 else ""
checks["source_join_helper_present"]=helper_start>=0
checks["source_join_preserves_program_exception"]="source.status == :program_exception" in helper and "return (status=:program_exception" in helper
checks["source_join_compares_refs_hashes_axes"]=all(x in helper for x in ("source_candidate_ref_mismatch","source_package_hash_mismatch","source_G1_ref_mismatch","source_G2_ref_mismatch","source_G3_ref_mismatch","source_G1_component_hash_mismatch","source_G2_component_hash_mismatch","source_G3_component_hash_mismatch","source_version_axes_mismatch"))
checks["factory_does_not_relabel_program_exception"]='check.status == :program_exception' in src and 'throw(ErrorException("UP2E0 program_exception:' in src
checks["bound_input_contains_binding_hash"]="profile_hash=profile_hash, binding_hash=binding_hash" in src
checks["n05_n06_require_typed_content_hash"]="later typed, content-hashed implementation" in src
checks["adversarial_injection_crosses_production_seam"]="injected = (args...) -> throw(ErrorException" in test and "_up2e0_check_package_with_inspector" in test
checks["adversarial_source_join_assertion"]="source_package_hash_mismatch" in test
pre=json.loads((arc/"precheck.json").read_text(encoding="utf-8"))
checks["lane_empty_before_run"]=pre.get("julia_desc_count")==0 and pre.get("run_started") is False
result={"record_kind":"UP2-00E0-R3-adversarial-static-control","verdict":"ready_for_focused_run" if all(checks.values()) else "changes_requested","checks":checks,"locations":{"inspector":"src/GenomeV5/UP2/UP2CandidatePhysicalBindingV1.jl:186-214","factory":"src/GenomeV5/UP2/UP2CandidatePhysicalBindingV1.jl:338-343","source_join_helper":"src/GenomeV5/UP2/UP2CandidatePhysicalBindingV1.jl:392-417","source_join_public":"src/GenomeV5/UP2/UP2CandidatePhysicalBindingV1.jl:419-422","injection_test":"test/GenomeV5/UP2/up2_candidate_physical_binding_tests.jl:189-193"},"limitation":"Static control and focused software runner cannot grant N05/N06, provider, B04, mesh, engineering, physical, or R credit."}
(arc/"adversarial_control.json").write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print(json.dumps(result,ensure_ascii=False,indent=2))
