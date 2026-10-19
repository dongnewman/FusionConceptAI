from __future__ import annotations

import ast
import hashlib
from pathlib import Path
import sys

from formal_t1_software_manifest_v1 import (
    EXPECTED_BINDING_CASE_IDS,
    EXPECTED_PROTOCOL_PATH,
    EXPECTED_T1_SOURCES,
    EXPECTED_V1_CARRIER_BYTES,
    EXPECTED_V1_CARRIER_SHA256,
    EXPECTED_V1_TARGET_IDS,
    EXPECTED_V2_EXTRA_TESTSETS,
    EXPECTED_V2_FORMAL_HARNESS_BYTES,
    EXPECTED_V2_FORMAL_HARNESS_PATH,
    EXPECTED_V2_FORMAL_HARNESS_SHA256,
    EXPECTED_V2_LEGACY_TESTSETS,
)
from formal_t2_controller import (
    COMBINED_JULIA_PARSE_PATH_COUNT,
    MANAGED_EXECUTION_SOURCE_PATHS,
    MANAGED_JULIA_PARSE_PATHS,
    MANAGED_JULIA_PARSE_PATH_COUNT,
    MANAGED_LIFECYCLE_SOURCE_PATHS,
    ORIGINAL_JULIA_PARSE_PATH_COUNT,
    POSITIVE_JULIA_THREADS,
    POSITIVE_MAX_SAMPLE_ATTEMPTS,
    POSITIVE_PHASE_ORDER,
    POSITIVE_PHASE_TIMEOUT_SECONDS,
    POSITIVE_PROTOCOL_SCHEMA,
    POSITIVE_RSS_LIMIT_BYTES,
    POSITIVE_SAMPLE_INTERVAL_SECONDS,
    R3_HISTORICAL_RECEIPTS,
    R3_RUNTIME_PARSE_MANIFEST_PATH,
    T1_SOFTWARE_MANIFEST,
    T1_SOFTWARE_MANIFEST_SHA256,
    T2_LOADER_DEFINITIONS,
    EXPECTED_MIGRATION_CHANGED_PATHS,
    T1_HISTORICAL_ARCHIVE_BYTES,
    T1_HISTORICAL_ARCHIVE_PATH,
    T1_HISTORICAL_ARCHIVE_SHA256,
    T1_HISTORICAL_DATA_SCHEMA,
    T1_HISTORICAL_IDENTITY_COUNT,
    T1_HISTORICAL_INDEX_BYTES,
    T1_HISTORICAL_INDEX_RELATIVE,
    T1_HISTORICAL_INDEX_SHA256,
    T1_HISTORICAL_SNAPSHOT_ID,
    V3_QUALIFICATION,
    V3_QUALIFICATION_EVIDENCE,
    V3_QUALIFICATION_SHA256,
    V3_QUALIFIED_SOURCE,
    V3_QUALIFIED_SOURCE_SHA256,
    fusion_package_source_paths,
    managed_source_receipts,
    _read_r3_runtime_parse_paths,
    runtime_dependency_paths,
    runtime_julia_paths,
)
from static_qa_vnext_t2_identity_receipt_v2 import delimiter_check


ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
POSITIVE_CONTROLLER_PATH = ROOT / (
    "test/GenomeV5/Integration/VNextT2IdentityReceiptV2/"
    "formal_t2_controller.py")
POSITIVE_CONTROLLER_BYTES = 98_847
POSITIVE_CONTROLLER_SHA256 = (
    "ce9ada4e20ce18832b11191062b2d70d21ee93edb1cd258b00028c656825356b")
EXPECTED_MANAGED_EXECUTION_PATHS = (
    "test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
    "independent_negative_controller_r23.py",
    "test/RuntimeV4/NativeG1G2DiffusionV1/native_process_table_r23_v1.py",
    "test/RuntimeV4/NativeG1G2DiffusionV1/supervise_r16_root_audit_r23_v1.py",
    "tools/execution/windows_process_lifecycle.py",
    "src/GenomeV5/Integration/ManagedExternalProcessV1.jl",
    "src/GenomeV5/Integration/NativeGitReadCompatibilityV1.jl",
    "tools/execution/t2_source_inputs.py",
    "tools/workspace_sources.py",
)
EXPECTED_MANAGED_LIFECYCLE_PATHS = (
    "tools/execution/windows_process_lifecycle.py",
    "src/GenomeV5/Integration/ManagedExternalProcessV1.jl",
    "src/GenomeV5/Integration/NativeGitReadCompatibilityV1.jl",
)
EXPECTED_MANAGED_JULIA_PARSE_PATHS = (
    "src/GenomeV5/Integration/ManagedExternalProcessV1.jl",
    "src/GenomeV5/Integration/NativeGitReadCompatibilityV1.jl",
)
MANAGED_PYTHON_FILES = tuple(
    ROOT / relative for relative in EXPECTED_MANAGED_EXECUTION_PATHS
    if relative.endswith(".py"))
MANAGED_JULIA_FILES = tuple(
    ROOT / relative for relative in EXPECTED_MANAGED_JULIA_PARSE_PATHS)
PYTHON_FILES = (
    HERE / "formal_t1_software_manifest_v1.py",
    HERE / "formal_t2_controller.py",
    HERE / "static_qa_formal_t2_execution_v1.py",
)
JULIA_FILES = (
    HERE / "formal_candidate_driver.jl",
    HERE / "module_entry_clean_load.jl",
    HERE / "vnext_t2_package_full_content_projection_r1.jl",
)
EXTERNAL_JULIA_FILES = (
    ROOT / "test/GenomeV5/Integration/VNextT2ConcreteSourceWitnessV3/parse_gate.jl",
)
FROZEN_T2 = {
    "src/GenomeV5/UP2/VNextT2IdentityReceiptProjectionV2.jl":
        "077a8634754c435caf8364d6bdc1325d56412ae256c181f9fb2a6a6da7084823",
    "src/GenomeV5/UP2/VNextT2UP2AdapterV2.jl":
        "4ff71f2d2e9863b04572a2f2f37df9e52ace948b3f90c10b2823a8fe2567a725",
    "src/GenomeV5/Integration/VNextT2IdentityReceiptIntegrationV2.jl":
        "64b1582c05cad8775af58d6ba35b1e50162e5394acbd92f0460b304b3195cf0b",
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require_tokens(source: str, tokens: tuple[str, ...], label: str) -> None:
    for token in tokens:
        assert token in source, (label, token)


def assert_whole_sample_retry_cap_binding(source: str) -> None:
    tree = ast.parse(source)
    cap_name = "R20_MAX_WHOLE_SAMPLE_ATTEMPTS"
    assignments = [
        node for node in tree.body
        if isinstance(node, ast.Assign) and len(node.targets) == 1 and
        isinstance(node.targets[0], ast.Name) and
        node.targets[0].id == cap_name,
    ]
    functions = [
        node for node in tree.body
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and
        node.name == "require_natural",
    ]
    assert len(assignments) == 1 and len(functions) == 1
    cap_value = ast.literal_eval(assignments[0].value)
    assert type(cap_value) is int and cap_value == 2
    names = [node for node in ast.walk(functions[0]) if isinstance(node, ast.Name)]
    assert any(node.id == cap_name and isinstance(node.ctx, ast.Load)
               for node in names)
    assert not any(node.id == "_R20_MAX_WHOLE_SAMPLE_ATTEMPTS" and
                   isinstance(node.ctx, ast.Load) for node in names)
    assert not any(node.id == cap_name and isinstance(node.ctx, ast.Store)
                   for node in names)


def main() -> int:
    assert PYTHON_FILES[1].resolve() == POSITIVE_CONTROLLER_PATH.resolve()
    assert POSITIVE_CONTROLLER_PATH.stat().st_size == POSITIVE_CONTROLLER_BYTES
    assert sha256(POSITIVE_CONTROLLER_PATH) == POSITIVE_CONTROLLER_SHA256
    for path in (*PYTHON_FILES, *MANAGED_PYTHON_FILES):
        ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    for path in (*JULIA_FILES, *EXTERNAL_JULIA_FILES, *MANAGED_JULIA_FILES):
        source = path.read_text(encoding="utf-8")
        delimiter_check(path, source)

    verifier = PYTHON_FILES[0].read_text(encoding="utf-8")
    controller = PYTHON_FILES[1].read_text(encoding="utf-8")
    driver = JULIA_FILES[0].read_text(encoding="utf-8")
    clean_load = JULIA_FILES[1].read_text(encoding="utf-8")
    projection_regression = JULIA_FILES[2].read_text(encoding="utf-8")
    adapter = (ROOT / "src/GenomeV5/UP2/VNextT2UP2AdapterV2.jl").read_text(
        encoding="utf-8")

    assert len(EXPECTED_T1_SOURCES) == 7
    assert len(EXPECTED_V1_TARGET_IDS) == len(set(EXPECTED_V1_TARGET_IDS)) == 70
    assert tuple(EXPECTED_V1_TARGET_IDS[:63]) == tuple(
        f"r18v2-{index:03d}" for index in range(1, 64))
    assert tuple(EXPECTED_V1_TARGET_IDS[63:]) == tuple(
        f"r26-extra-{index:03d}" for index in range(1, 8))
    assert len(EXPECTED_V2_LEGACY_TESTSETS) == 7
    assert len(EXPECTED_V2_EXTRA_TESTSETS) == 4
    assert len(EXPECTED_BINDING_CASE_IDS) == \
        len(set(EXPECTED_BINDING_CASE_IDS)) == 16
    assert EXPECTED_PROTOCOL_PATH.endswith("protocol_r26_v9.json")
    assert EXPECTED_V1_CARRIER_BYTES == 8_269_571
    assert EXPECTED_V1_CARRIER_SHA256 == \
        "1abdd43b057c6f6ba7dc020cf3c4a9239823cc2081f00583a405f7d0d91645f8"
    assert EXPECTED_V2_FORMAL_HARNESS_PATH.endswith("v2_formal_r26.jl")
    assert EXPECTED_V2_FORMAL_HARNESS_BYTES == 27_776
    assert EXPECTED_V2_FORMAL_HARNESS_SHA256 == \
        "9a640613875d79b973fb2a42b96a1d2135281ddd9c439228eec550a8567d4cb1"
    require_tokens(verifier, (
        'SCHEMA = "vnext-t1-software-acceptance-manifest-r1"',
        '"working_set_limit_bytes": 2_147_483_648',
        '"carrier_limit_seconds": 10',
        '"package_integrator_limit_seconds": 30',
        '"reload_adapter_limit_seconds": 30',
        'target_ids != list(EXPECTED_V1_TARGET_IDS)',
        'binding.get("case_ids") != list(EXPECTED_BINDING_CASE_IDS)',
        'verify_json_receipt(',
        'verify_recorded_stage(',
        'verify_stage_command(',
        '"r26_exact_input_run_v1"',
        '"vnext_t1_independent_formal_r26_single_merge_v8"',
        '"test/GenomeV5/Integration/VNextT1FormalR26/protocol_r26_v9.json"',
        '"vnext_t1_v2_formal_r26_ledger_v3"',
        '"vnext_t1_binding_cross_product_r26_ledger_v1"',
        'verify_v1_carrier_ledgers(',
        '"vnext_t1_v1_source_carrier_resource_r26_v1"',
        'observation.get("first_call_count") != 1',
        'ledger.get("pid") != stage_rows[stage]["identity"]["pid"]',
        '"actual_bytes": EXPECTED_V1_CARRIER_BYTES',
        'measured_v2_resources = {',
        'harness_text.count(f\'@testset "{title}"\') != 1',
        'primary["stable_projection"] != replay["stable_projection"]',
        'manifest.get("actual_model_attestation") != "unavailable"',
    ), "verifier")
    require_tokens(controller, (
        "def _verify_t1_manifest(verifier: Any, reader_module: Any,",
        "return verifier.verify_manifest(",
        "historical_reader_module=reader_module,",
        "historical_index_path=ROOT.joinpath(",
        "historical_index_sha256=T1_HISTORICAL_INDEX_SHA256,",
        "historical_archive_path=T1_HISTORICAL_ARCHIVE_PATH)",
        "_verify_t1_manifest(t1_verifier, historical_reader_module,",
        "_verify_t1_manifest(",
        "v3_verification = verify_v3_qualification(",
        "v3_verification_after = verify_v3_qualification(",
        'parser.add_argument("--v3-qualification", required=True)',
        'parser.add_argument("--v3-qualification-sha256", required=True)',
        '"verified_before_julia": True',
        '"verified_after_replay": True',
        '"source_witness_qualification_verification.json"',
        "runtime_julia_paths()",
        '"test/GenomeV5/Integration/vnext_declaration_transport_local_v1_tests.jl"',
        '"vnext_t2_package_full_content_projection_r1.jl"',
        "fusion_package_source_paths()",
        "assert_shared_entry_connected(static_includes)",
        '"parse_gate", julia_common',
        '"runtime_parse_manifest.tsv"',
        'output / "pipeline_start.json"',
        'output / "pipeline_final.json"',
        'finally:',
        'inputs_after_final = runtime_receipts()',
        '"pinned_input_changes": input_changes_final',
        "if head_before != EXPECTED_HEAD:",
        'environment["JULIA_NUM_THREADS"] = "1"',
        '"--threads=1"',
        '"clean_load", julia_common + [str(CLEAN_LOAD_DRIVER)',
        '"clean_load_natural_exit_before_candidate_start": True',
        '"process_overlap": False',
        '"fresh_process_identity_distinct": True',
        '"stable_projection_equal": True',
        '"fresh_replay_deserialized_producer_artifact": True',
        '"candidate_package_serialized_sha256"',
        '"result_serialized_sha256"',
        '"result_reload_identity_hash"',
        '"formal-candidate-driver-r5"',
        'value.get("publication_committed") is not True',
        'output / "replay_uncommitted_attempt.json"',
        '"formal_t2_accepted": False',
        '"actual_model_attestation": "unavailable"',
    ), "controller")
    assert controller.index('"parse_gate", julia_common') < \
        controller.index('"clean_load", julia_common') < \
        controller.index('"producer", base') < controller.index('"replay", base')
    assert controller.index(
        "v3_verification = verify_v3_qualification(") < \
        controller.index('"parse_gate", julia_common')
    require_tokens(controller, (
        'POSITIVE_PROTOCOL_SCHEMA = "vnext-t2-positive-managed-execution-protocol-r2"',
        'ORIGINAL_JULIA_PARSE_PATH_COUNT = 92',
        'MANAGED_JULIA_PARSE_PATH_COUNT = 2',
        'COMBINED_JULIA_PARSE_PATH_COUNT = 94',
        'POSITIVE_PHASE_TIMEOUT_SECONDS = 300.0',
        'POSITIVE_RSS_LIMIT_BYTES = 2_147_483_648',
        'POSITIVE_SAMPLE_INTERVAL_SECONDS = 0.2',
        'POSITIVE_MAX_SAMPLE_ATTEMPTS = 2',
        'POSITIVE_JULIA_THREADS = 1',
        'parser.add_argument("--freeze-only", action="store_true")',
        'parser.add_argument("--freeze-dir")',
        'parser.add_argument("--protocol-sha256")',
        'raise ValueError("positive run requires --protocol and --protocol-sha256")',
        '_assert_r3_runtime_parse_inventory(julia_paths)',
        '_R23_RUNTIME.configure_managed_lifecycle(protocol, protocol_sha256)',
        'return _R23_RUNTIME.run_phase(',
        '_R23_RUNTIME.require_natural(phase, exit_zero=True)',
        'receipt_key="head_initial"',
        'receipt_key="head_success"',
        'receipt_key="head_finally"',
        'required_receipt_keys = {',
        '"command", "phase", "stdout", "stderr",',
        'head = stdout_path.read_bytes().decode("ascii", errors="strict").strip()',
        'not re.fullmatch(r"[0-9a-f]{40}", head)',
        '"head_value_sha256"',
        '"managed_execution_dependencies"',
        '"managed_process_lifecycle_source_pins"',
        '"schema": "vnext-t2-positive-managed-snapshot-r2",',
        '"historical_unchanged_count": 97,',
        '"changed_count": 7,',
        '"formal_t2_accepted": False',
        '"physical_acceptance": False',
        '"scientific_acceptance": False',
        '"actual_model_attestation": "unavailable"',
    ), "positive-managed-controller")
    assert controller.count("_verify_t1_manifest(") == 4
    assert controller.count("verifier.verify_manifest(") == 1
    require_tokens(controller, (
        'set(input_groups) != {',
        '"t1_historical_data"',
        'input_groups["t1_historical_data"] != historical_t1_data',
        'T1_HISTORICAL_INDEX_RELATIVE in runtime_pins',
        'T1_HISTORICAL_INDEX_RELATIVE in managed',
        'protocol_inputs != {**runtime_pins, **managed}',
        'def _t1_historical_data_group(reader_module: Any)',
        'strict_subset=True',
        '"indexed_identity_count": T1_HISTORICAL_IDENTITY_COUNT',
        '"archive": {',
        '"t1_historical_data": historical_t1_data,',
    ), "positive-managed-source-groups")
    assert "subprocess.run(" not in controller
    assert "subprocess.Popen(" not in controller
    assert tuple(POSITIVE_PHASE_ORDER) == (
        "parse_gate", "clean_load", "producer", "replay")
    assert POSITIVE_PHASE_TIMEOUT_SECONDS == 300.0
    assert POSITIVE_RSS_LIMIT_BYTES == 2_147_483_648
    assert POSITIVE_SAMPLE_INTERVAL_SECONDS == 0.2
    assert POSITIVE_MAX_SAMPLE_ATTEMPTS == 2
    assert POSITIVE_JULIA_THREADS == 1
    assert ORIGINAL_JULIA_PARSE_PATH_COUNT == 92
    assert MANAGED_JULIA_PARSE_PATH_COUNT == 2
    assert COMBINED_JULIA_PARSE_PATH_COUNT == 94
    assert POSITIVE_PROTOCOL_SCHEMA == "vnext-t2-positive-managed-execution-protocol-r2"
    assert controller.count('"schema": "vnext-t2-positive-managed-snapshot-r2"') == 2
    assert tuple(MANAGED_EXECUTION_SOURCE_PATHS) == EXPECTED_MANAGED_EXECUTION_PATHS
    assert tuple(MANAGED_LIFECYCLE_SOURCE_PATHS) == EXPECTED_MANAGED_LIFECYCLE_PATHS
    assert tuple(MANAGED_JULIA_PARSE_PATHS) == EXPECTED_MANAGED_JULIA_PARSE_PATHS
    assert len(set(MANAGED_EXECUTION_SOURCE_PATHS)) == 8
    assert len(set(MANAGED_LIFECYCLE_SOURCE_PATHS)) == 3
    assert len(set(MANAGED_JULIA_PARSE_PATHS)) == 2
    assert controller.index(
        "_load_managed_runtime(protocol, args.protocol_sha256.lower(),") < \
        controller.index("head_before_query = git_head(") < \
        controller.index('"parse_gate", julia_common')
    assert controller.index('"replay", base') < \
        controller.index('receipt_key="head_success"') < \
        controller.index('receipt_key="head_finally"')
    assert controller.count("phases.append(") == 4
    assert controller.count("require_phase_pass(") >= 4
    assert '"process_create_time_100ns"' in controller
    assert '"all_process_generations_distinct"' in controller
    require_tokens(driver, (
        "manifest_document = JSON3.read",
        "verification_document = JSON3.read",
        "manifest_document.formal_t1_software_accepted === true",
        "verification_document.verified === true",
        "producer_candidate_package_expected_admission_mismatch",
        "_vnext_t2_t1_package_content_equal_v2(",
        "_vnext_t2_t1_package_content_hash_v2(package)",
        "producer_bytes = read(producer_path)",
        "producer_expected_sha256 = lowercase(ARGS[10])",
        "function _formal_t2_canonical_artifact(value)",
        'const FORMAL_T2_DRIVER_VERSION = "formal-candidate-driver-r5"',
        "const FORMAL_T2_OWNED_ARTIFACTS = (",
        "function _formal_t2_require_output_leaf_available(output::String)",
        "_formal_t2_require_output_leaf_available(FORMAL_T2_OUTPUT)",
        "_formal_t2_path_occupied(path::String) = ispath(path) || islink(path)",
        "mv(temp_path, path; force=false)",
        "function _formal_t2_serialized_artifact(value)",
        "function _formal_t2_uncommitted_attempt(stage::Symbol",
        "function _formal_t2_pre_material_uncommitted_attempt(stage::Symbol",
        ":producer_artifact_hash_precondition",
        ":producer_artifact_deserialize_precondition",
        ":raw_sha256_mismatch",
        ":deserialize_error",
        ":type_invalid",
        ":expected_admission_mismatch",
        "producer_artifact_unchanged=",
        "caller_package_sha256_before=nothing",
        '"replay_uncommitted_attempt.json"',
        ":candidate_receipt_precondition",
        ":serialized_result_postcondition",
        ":stable_projection_postcondition",
        "authority_input_accepted=false",
        "authority_input_accepted=true",
        "publication_committed=false",
        "published_artifacts=()",
        "canonical_body_bytes=length(body_artifact.bytes)",
        "canonical_body_sha256=body_artifact.sha256",
        "length(ARGS) in (6, 11)",
        "result_reload_identity_hash = FusionConceptAI.canonical_hash(",
        "package_artifact_origin=FORMAL_T2_MODE === :produce ?",
        "evidence_kind=:formal_t1_actual",
        "formal_t1_accepted=true",
        "t1_admission_invocation_count=2",
        "VNextT2InvocationCountsV2(1, 1, 1, 1, 1, 0, 0, 0)",
        "function _formal_t2_method_receipts()",
        "Base.functionloc(method)",
        "consumer_method_receipts=method_receipts",
        "invocation_receipts=Tuple(FusionConceptAI.semantic_view(receipt)",
        "attempt_events=Tuple(FusionConceptAI.semantic_view(event)",
        "publication_committed=true",
        'published_artifacts=("candidate_package.jls"',
        "formal_t2_accepted=false",
        "actual_model_attestation=\"unavailable\"",
    ), "driver")
    candidate_guard = \
        "candidate_artifact.sha256 != lowercase(ARGS[7])"
    stable_guard = \
        "stable_projection_hash.value != lowercase(ARGS[8])"
    result_reload_guard = \
        "result_reload_identity_hash.value != lowercase(ARGS[11])"
    assert driver.index(candidate_guard) < driver.index(
        "gate = FusionConceptAI.vnext_t2_formal_gate_identity_v2")
    assert driver.index(":producer_artifact_hash_precondition") < \
        driver.index("reloaded = try") < driver.index(
            ":producer_artifact_deserialize_precondition") < \
        driver.index(candidate_guard)
    assert driver.index(
        "_formal_t2_require_output_leaf_available(FORMAL_T2_OUTPUT)") < \
        driver.index("manifest_raw = _formal_t2_verify_raw")
    publish_start = driver.index(
        "function _formal_t2_publish_artifact(path::String, artifact)")
    publish_end = driver.index(
        "function _formal_t2_file_receipt(relative::String)")
    publish_body = driver[publish_start:publish_end]
    assert publish_body.index("_formal_t2_path_occupied(path)") < \
        publish_body.index("mktemp(parent; cleanup=false)") < \
        publish_body.index("mv(temp_path, path; force=false)")
    assert 'open(path, "w")' not in publish_body
    assert driver.index(
        "result = FusionConceptAI.vnext_t2_rebind_identity_receipts_v2") < \
        driver.index(result_reload_guard) < driver.index(stable_guard) < \
        driver.index(
            "package_file = _formal_t2_publish_artifact")
    assert 'joinpath(FORMAL_T2_OUTPUT, "candidate_package.jls")' not in \
        driver[:driver.index(stable_guard)]
    assert "synthetic_local" not in driver
    assert "function timed(label, f)" not in driver
    assert "FusionConceptAI.semantic_view(package)" not in driver
    require_tokens(adapter, (
        "function _vnext_t2_t1_package_projection_v2(",
        'domain="vnext-t2-t1-package-full-content-projection-v2"',
        "function _vnext_t2_t1_package_content_equal_v2(",
        "_vnext_t2_t1_package_content_hash_v2(",
        "function _vnext_t2_t1_admission_projection_v2(",
        'domain="vnext-t2-t1-admission-full-content-projection-v2"',
        "function _vnext_t2_t1_admission_content_equal_v2(",
        "admission=_vnext_t2_t1_admission_projection_v2(admission)",
        "reloaded_package_content_hash=",
        "_vnext_t2_t1_admission_content_equal_v2(rebuilt_admission, admission)",
        "_vnext_t2_t1_package_content_equal_v2(admission.package,",
        "source_bytes=semantic_view(declaration.source_bytes)",
        "wire=semantic_view(package.wire)",
    ), "adapter")
    assert "semantic_view(x::CandidateStatePackageV5NextV2)" not in adapter
    require_tokens(clean_load, (
        "state_before === :unloaded",
        "FusionConceptAI.load_vnext_t2_components_v2!()",
        "load_invocation_count=2",
        "registry_after == registry_before",
        "fixture_loaded=false",
        "shared_loader_clean_load_verified=true",
        "formal_t2_accepted=false",
    ), "clean-load")
    assert clean_load.count("FusionConceptAI.load_vnext_t2_components_v2!()") == 2
    assert "fixture_helpers" not in clean_load
    require_tokens(projection_regression, (
        'length(ARGS) == 1',
        'schema="vnext-t2-package-full-content-projection-actual-r1"',
        'status="actual_observed"',
        'status="program_exception"',
        'classification="supplemental_product_regression"',
        'recorded_before_assertions=true',
        'planned_test_sites=24',
        'assertion_sites_completed=0',
        'reload_content_equivalence=(planned_sites=8, observed_values=8',
        'wire_byte_tamper_detection=(planned_sites=7, observed_values=7',
        'source_byte_tamper_detection=(planned_sites=7, observed_values=7',
        'admission_envelope_projection=(planned_sites=2, observed_values=2',
        't2_write_package_projection_observation(actual)',
        'VNEXT_T2_PACKAGE_PROJECTION_REGRESSION=PASS sites=24 groups=4',
        '_vnext_t2_t1_package_content_equal_v2(original, reloaded)',
        'admission_package_projection_full_content_equal =',
        'admission_group.package_projection_full_content_equal',
        't2_preflight_t1_reloaded_package_mismatch',
    ), "package-projection-regression")
    assert projection_regression.index(
        "t2_write_package_projection_observation(actual)") < \
        projection_regression.index(
            '@testset "VNext T2 full T1 package content projection"')
    assert projection_regression.count("@test ") == 24
    assert projection_regression.index("tampered_wire =") < \
        projection_regression.index("tampered_wire = nothing") < \
        projection_regression.index("tampered_source =")

    julia_paths = runtime_julia_paths()
    dependency_paths = runtime_dependency_paths()
    original_parse_paths = _read_r3_runtime_parse_paths()
    observed_original_parse_paths = [
        path.relative_to(ROOT).as_posix() for path in julia_paths]
    combined_parse_paths = [*original_parse_paths, *MANAGED_JULIA_PARSE_PATHS]
    managed_receipts = managed_source_receipts()
    assert R3_HISTORICAL_RECEIPTS["runtime_parse_manifest.tsv"] == (
        10_142,
        "07b7b41bbf63fca831bc0608024c83e6079641552bd3dbbca0ff2071cfd8713f")
    assert R3_RUNTIME_PARSE_MANIFEST_PATH.stat().st_size == 10_142
    assert sha256(R3_RUNTIME_PARSE_MANIFEST_PATH) == \
        "07b7b41bbf63fca831bc0608024c83e6079641552bd3dbbca0ff2071cfd8713f"
    assert len(original_parse_paths) == 92
    assert len(observed_original_parse_paths) == 92
    assert observed_original_parse_paths == original_parse_paths
    assert len(combined_parse_paths) == 94
    assert len(set(combined_parse_paths)) == 94
    assert not set(original_parse_paths).intersection(MANAGED_JULIA_PARSE_PATHS)
    assert len(dependency_paths) == 104
    assert set(managed_receipts) == set(EXPECTED_MANAGED_EXECUTION_PATHS)
    assert len(managed_receipts) == 8
    assert EXPECTED_MIGRATION_CHANGED_PATHS == {
        "Project.toml",
        "src/GenomeV5/G1/G1SourceAuthorityFactoryV1.jl",
        "src/GenomeV5/G2/G2SourceAuthorityFactoryV1.jl",
        "src/GenomeV5/G3/G3SourceAuthorityFactoryV1.jl",
        "test/GenomeV5/Integration/vnext_declaration_transport_local_v1_tests.jl",
        "test/GenomeV5/Integration/VNextT2IdentityReceiptV2/formal_t2_controller.py",
        "test/GenomeV5/Integration/VNextT2IdentityReceiptV2/formal_t1_software_manifest_v1.py",
    }
    assert len(EXPECTED_MIGRATION_CHANGED_PATHS) == 7
    assert T1_HISTORICAL_DATA_SCHEMA == "vnext-t2-positive-t1-historical-data-r1"
    assert T1_HISTORICAL_INDEX_RELATIVE == \
        "test/fixtures/historical_sources/t1_manifest_index.json"
    assert T1_HISTORICAL_INDEX_BYTES == 36_185
    assert T1_HISTORICAL_INDEX_SHA256 == \
        "57a3ddad571af1f4915c421af60231506474571d3bf355c2a51247113b95e07c"
    assert T1_HISTORICAL_ARCHIVE_PATH.as_posix() == (
        "D:/006-Programing/LMC/FusionConceptAI_cleanup_20260926/"
        "precleanup_docs_runs_tmp.zip")
    assert T1_HISTORICAL_ARCHIVE_BYTES == 472_888_641
    assert T1_HISTORICAL_ARCHIVE_SHA256 == \
        "c84743bc55dc749bbcc43e936c278027ad9bce9b437c09e176be587f75ff2bb7"
    assert T1_HISTORICAL_SNAPSHOT_ID == "t1-r26-precleanup-20260926"
    assert T1_HISTORICAL_IDENTITY_COUNT == 49
    t1_index_path = ROOT.joinpath(*T1_HISTORICAL_INDEX_RELATIVE.split("/"))
    assert t1_index_path.stat().st_size == T1_HISTORICAL_INDEX_BYTES
    assert sha256(t1_index_path) == T1_HISTORICAL_INDEX_SHA256
    assert t1_index_path not in dependency_paths
    assert T1_HISTORICAL_INDEX_RELATIVE not in managed_receipts
    assert set(EXPECTED_MANAGED_LIFECYCLE_PATHS).issubset(managed_receipts)
    for relative, receipt in managed_receipts.items():
        assert receipt == {
            "path": relative,
            "bytes": (ROOT / relative).stat().st_size,
            "sha256": sha256(ROOT / relative),
        }
    assert_whole_sample_retry_cap_binding(
        (ROOT / EXPECTED_MANAGED_EXECUTION_PATHS[0]).read_text(encoding="utf-8"))
    _, fusion_includes = fusion_package_source_paths()
    assert len(T2_LOADER_DEFINITIONS) == 24
    assert any(path.name == "vnext_declaration_transport_local_v1_tests.jl"
               for path in julia_paths)
    assert any(path.name == "vnext_t2_package_full_content_projection_r1.jl"
               for path in julia_paths)
    assert len(julia_paths) == len(set(julia_paths))
    assert len(dependency_paths) == len(set(dependency_paths))
    assert set(julia_paths).issubset(dependency_paths)
    assert V3_QUALIFICATION in dependency_paths
    assert T1_SOFTWARE_MANIFEST in dependency_paths
    assert sha256(T1_SOFTWARE_MANIFEST) == T1_SOFTWARE_MANIFEST_SHA256
    assert ROOT / V3_QUALIFIED_SOURCE in dependency_paths
    assert sha256(V3_QUALIFICATION) == V3_QUALIFICATION_SHA256
    assert sha256(ROOT / V3_QUALIFIED_SOURCE) == V3_QUALIFIED_SOURCE_SHA256
    for relative, byte_count, expected in V3_QUALIFICATION_EVIDENCE.values():
        path = ROOT / relative
        assert path in dependency_paths
        assert path.stat().st_size == byte_count
        assert sha256(path) == expected
    shared_entry_connected = \
        "GenomeV5/Integration/VNextT2ModuleEntryV2.jl" in fusion_includes

    for relative, expected in EXPECTED_T1_SOURCES.items():
        assert sha256(ROOT / relative) == expected, relative
    for relative, expected in FROZEN_T2.items():
        assert sha256(ROOT / relative) == expected, relative

    print("VNEXT_T2_FORMAL_EXECUTION_STATIC_QA=PASS")
    for path in (*PYTHON_FILES, *MANAGED_PYTHON_FILES,
                 *JULIA_FILES, *EXTERNAL_JULIA_FILES, *MANAGED_JULIA_FILES):
        print(f"{path.relative_to(ROOT).as_posix()}={sha256(path)}")
    print("frozen_t1_sources=7")
    print("frozen_t2_sources=3")
    print("original_runtime_inputs=104")
    print("managed_execution_dependencies=8")
    print("historical_julia_parse_paths=92")
    print("managed_julia_parse_paths=2")
    print("combined_julia_parse_paths=94")
    print(f"positive_controller_sha256={POSITIVE_CONTROLLER_SHA256}")
    print("formal_t2_accepted=false")
    print(f"shared_entry_connected={str(shared_entry_connected).lower()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
