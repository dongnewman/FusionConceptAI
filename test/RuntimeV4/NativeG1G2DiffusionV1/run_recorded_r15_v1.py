"""Recorded native G1/G2 Gridap r15 fail-closed RSS monitor runner.

The runner freezes the exact source closure, parses every active Julia file,
then executes primary and fresh replay processes serially. Each Julia stage
has an independent 480 second wall limit and a 2 GiB process-tree RSS sampled
stop trigger at 0.2 second intervals. The recorder stops after a sampled hit;
the sample series can miss transient peaks and observed overshoot is possible.
Process-tree enumeration/member read errors stop the stage as
`resource_monitor_incomplete`, preserving partial RSS/PIDs and raw exception
details so partial samples cannot clear the RSS threshold.
`--static-only` performs only Python/inventory checks and never starts Julia.
"""

from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
import argparse
import ast
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time

import psutil


ROOT = Path(__file__).resolve().parents[3]
TEST_DIR = Path(__file__).resolve().parent
EVIDENCE_ROOT = (
    ROOT
    / "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
      "native_g1g2_prelaunch_r15_v1"
).resolve()
GRIDAP_PROJECT = (ROOT / "tools/qualification/gridap").resolve()
JULIA_LOAD_PATH_ENTRIES = ("@", str(ROOT), "@stdlib")
R10_BASELINE_MANIFEST = (
    ROOT
    / "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/"
      "independent_r10_source_marker_review_20260923/frozen_protocol/"
      "static_preflight.json"
).resolve()
R10_BASELINE_PARSE_MANIFEST = (
    ROOT
    / "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/"
      "independent_r10_source_marker_review_20260923/frozen_protocol/"
      "parse_manifest.tsv"
).resolve()
R10_BASELINE_PROTOCOL = (
    ROOT
    / "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/"
      "independent_r10_source_marker_review_20260923/frozen_protocol/"
      "protocol.json"
).resolve()
R10_BASELINE_MANIFEST_SHA256 = (
    "eefb6b07e8d1a4d7ca67bcfe63a21e0c506adce2182124e579a06ee994a6d7bf"
)
R10_BASELINE_PARSE_MANIFEST_SHA256 = (
    "4abb91920481650c5fb7b6d8da6f2f4369dd9880c40e4a52735f939ccfada2f5"
)
R10_BASELINE_PROTOCOL_SHA256 = (
    "ab22013fa088cc6d68bcc175efcd5be8670ec1a0eee10663f5bdf0e6c543b1ae"
)
R10_BASELINE_PIN_COUNT = 115

R10_PRIOR_EVIDENCE_SHA256 = {
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/agent_r1_20260922/runtime_r10_actual_r1/protocol.json": "60d590bc83ab3465c71ce38a70096f9274937db9e7f2616f4bf5384caafa9446",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/agent_r1_20260922/runtime_r10_actual_r1/summary.json": "1781213362b2894e1885492da7c30df1f127b3623ecf283700c77b57632eeb46",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/agent_r1_20260922/runtime_r10_actual_r1/02_primary/final.json": "f653af01048c39af84fbebae9aa71f8ecf23542c3f67a83514ccf5ad1d5abeb2",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/agent_r1_20260922/runtime_r10_actual_r1/02_primary/stdout.raw": "c4edca785554ec75726f37199f9c759a4f80c3154703b8c57019fd9f9c8290d3",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/agent_r1_20260922/runtime_r10_actual_r1/02_primary/stderr.raw": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/agent_r1_20260922/runtime_r10_actual_r1/02_primary/samples.jsonl": "5f222225fcf59f51005c21a09809bdeb6449ef0e1fe82279532d171ae4efb2a8",
}
R11_PRIOR_EVIDENCE_SHA256 = {
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/root_native_r11_grant_20260923/grant.json": "4cfefe298a13ea0399a9bc768125fefc411b0fe3954c85a67431fbe9901b4650",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/root_native_r11_grant_20260923/observation.json": "f1202bbcb8171dd0d6583fb5117a6ced9681c5a4ba762fdbcb2715d136ce937e",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_precompile_r11_v1/r11_static_v1/protocol.json": "fc1170e86a63ca71e16e0d530fff824bb1bec7d5317e0e91fd52d2fbd11c1e6f",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_precompile_r11_v1/r11_actual_v1/protocol.json": "00ed4cccd1ae0d31ed56c5edab4044e836d8b4319b367e125cdb193b2d9a064d",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_precompile_r11_v1/r11_actual_v1/summary.json": "868b6a2b027bfbd444f32e24771105e9f77d55ec3d847f27816ce76fd4e2ba85",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_precompile_r11_v1/r11_actual_v1/02_primary/final.json": "1c08baf96505a6309df7d4bba21e8a6c34963eadf5cf2c6a9fea819656a42413",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_precompile_r11_v1/r11_actual_v1/02_primary/stdout.raw": "4098aaa4c099ae88fedd9848c11baeffbadcff31149226e281f37c75d864b132",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_precompile_r11_v1/r11_actual_v1/02_primary/stderr.raw": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_precompile_r11_v1/r11_actual_v1/02_primary/samples.jsonl": "c4a2e104e8273a291691049496ddf00fea6469fa154bffac0e99f6c012d7e6da",
}
R12_PRIOR_EVIDENCE_SHA256 = {
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_precompile_r12_v1/r12_static_v2/protocol.json": "b89d676db9161d81a19aed9ac1f988bd0809bd69a3c9f382cbf4bd2984aba9e3",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_precompile_r12_v1/r12_static_v2/static_preflight.json": "bab5d91e0aeaff3d416e1c3a9166d2e30240807ae9c05ffbadf3054765b34855",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_precompile_r12_v1/r12_static_v2/parse_manifest.tsv": "a9f8625483929b02b3e1d00b272199a9be1f385ce212eb4459c9887d5b783ffa",
    "test/RuntimeV4/NativeG1G2DiffusionV1/run_recorded_r12.py": "0f93760f1c80cb037d37e6d16d5db0dc44144a7cded75c7ab99d88854b4b1123",
    "test/RuntimeV4/NativeG1G2DiffusionV1/r12_prelaunch_preflight.py": "9098604b6963e45714be02c41583d65c2eee81590eadfc46e7442a5f1543f8e1",
    "test/RuntimeV4/NativeG1G2DiffusionV1/test_r12_prelaunch_preflight.py": "8e48449959243a313e56aed12a959fe7842e7f670974f392d12d35c580e6975d",
    "test/RuntimeV4/NativeG1G2DiffusionV1/focused_tests_r12_markers.jl": "7365639c802b3ff2ac5106bf368ea7ceea307afbe9bbfc78822907b186a99f78",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_precompile_r12_v1/r12_actual_v1/protocol.json": "9bc491f79ceedb947957b3cd6ea442c632bd633d5cd5b171cb076861ca68d45e",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_precompile_r12_v1/r12_actual_v1/prelaunch.stdout.raw": "acae313680dce3c7296ce930e451743b0f47ea6ff44aaa09272fd65455583c36",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_precompile_r12_v1/r12_actual_v1/prelaunch.stderr.raw": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_precompile_r12_v1/r12_actual_v1/prelaunch.exit.txt": "f1b2f662800122bed0ff255693df89c4487fbdcf453d3524a42d4ec20c3d9c04",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/root_native_r12_grant_20260923/grant.json": "b1cb769a76a9a982c082254a57f20bbcfd8de1bebe751d2ccd2e74a7e22d9716",
}
R12_PRIOR_FACTS = {
    "r12_prelaunch_setup_failure": {
        "status": "fail_closed",
        "prelaunch_exit_code": 1,
        "failure_class": "argv_identity_mismatch",
        "julia_started": False,
        "solver_run_observed": False,
        "argument_token_root_cause_claimed": False,
    },
}
R13_PRIOR_EVIDENCE_SHA256 = {
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_prelaunch_r13_v1/r13_static_v1/protocol.json": "622cc2ad4bfa32917b0690e0ec268ac408108a2ba83727416273e8d3d64b49a1",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_prelaunch_r13_v1/r13_actual_v1/protocol.json": "19a521ee7a7c59b44e6e379ccec32dcabeb9cb3081eeffc38ca28a8c0db02000",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_prelaunch_r13_v1/r13_actual_v1/summary.json": "e0ebc5cfd90ac36f4249af1022a2f05277c3e9850816244ca63bbb40ce1a5044",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_prelaunch_r13_v1/r13_actual_v1/02_primary/final.json": "81fd260954e9cb0e6d76d8e337c044e9f812456c283c694be7a57d29538e14a0",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_prelaunch_r13_v1/r13_actual_v1/02_primary/stdout.raw": "2a61130c55dc3f7d6886092c406d876bb0a2430e1ae0403dace93a0c357d6595",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_prelaunch_r13_v1/r13_actual_v1/02_primary/stderr.raw": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_prelaunch_r13_v1/r13_actual_v1/02_primary/samples.jsonl": "8f018ea7d4ae7e9f86b78229420f68d06d34b87f7b51d84207394b92810918af",
}
R13_PRIOR_FACTS = {
    "r13_primary_resource_failure": {
        "status": "process_tree_rss_limit",
        "outer_exit_code": 1,
        "stage_exit_code": 15,
        "stage_elapsed_seconds": 242.2365240000072,
        "peak_process_tree_rss_bytes": 2196549632,
        "rss_sampled_stop_threshold_bytes": 2147483648,
        "sampled_overshoot_bytes": 49065984,
        "last_flushed_marker": "NG12_STAGE stage=precompile.before elapsed_ms=8456 gc_live_bytes=56114510 jit_total_bytes=48814 process_maxrss_bytes=517369856 gc_time_ns=204766300 detail=target=ng12_primary signature=(String,)",
        "precompile_return_observed": False,
        "primary_function_entry_observed": False,
        "solver_run_observed": False,
        "fresh_replay_executed": False,
        "parse_all_exit_code": 0,
        "parse_all_files": 108,
        "numerical_status": "not_established",
    },
}
R13_STATIC_PROTOCOL = (
    ROOT
    / "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
      "native_g1g2_prelaunch_r13_v1/r13_static_v1/protocol.json"
).resolve()
R13_STATIC_PROTOCOL_SHA256 = (
    "622cc2ad4bfa32917b0690e0ec268ac408108a2ba83727416273e8d3d64b49a1"
)
R14_STATIC_PROTOCOL_REL = (
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
    "native_g1g2_prelaunch_r14_v1/r14_static_v8/protocol.json"
)
R14_STATIC_PROTOCOL_SHA256 = "cd9911821eefe688fcd01413c1d8f317dc26dc3d0bcd364a13632f802096b223"
R14_REVIEW_REPORT_REL = (
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
    "independent_native_g1g2_r14_static_review_20260924/review.md"
)
R14_REVIEW_REPORT_SHA256 = "27e2cc94943a8534d53e79b133258681b5a45f300867cfeb1cc38e2d9241f77f"
R14_REVIEW_MANIFEST_REL = (
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
    "independent_native_g1g2_r14_static_review_20260924/manifest.json"
)
R14_REVIEW_MANIFEST_SHA256 = "6faf7685da803a6e699422cc6853bab2f7b2d7b70bf3d7c3fc192c893e3b71d0"
R14_ANCESTOR_SOURCE_PINS = {
    "test/RuntimeV4/NativeG1G2DiffusionV1/run_recorded_r14_v8.py": "8db1ee94c4971433cfc0fdf94514c59c199d14d6e5a9a0086f850c45db5add8c",
    "test/RuntimeV4/NativeG1G2DiffusionV1/r14_prelaunch_preflight_v8.py": "b1d8773619565ab21f908778fef59cef20bb3c9fb101513a970ea8b00eae98fc",
    "test/RuntimeV4/NativeG1G2DiffusionV1/test_r14_prelaunch_preflight_v8.py": "150ba37b98bb5cfe66dec436837948e79b65c0e16cee38c88f703fce7ab537d6",
    "test/RuntimeV4/NativeG1G2DiffusionV1/report_r14_resource_outcome_v8.py": "8339db4502ce3ff0c264f00235c8262114c0bd3eec18594c49aff27b75d4bb30",
    "test/RuntimeV4/NativeG1G2DiffusionV1/test_r14_static_v8_resource_report.py": "5dd3e43f3a04b80aba5dbf8faec17a69dab89376168e2b91b1741a3732fd65fe",
}
R14_PARENT_RECORD = {
    "protocol_path": R14_STATIC_PROTOCOL_REL,
    "protocol_sha256": R14_STATIC_PROTOCOL_SHA256,
    "review_report_path": R14_REVIEW_REPORT_REL,
    "review_report_sha256": R14_REVIEW_REPORT_SHA256,
    "review_manifest_path": R14_REVIEW_MANIFEST_REL,
    "review_manifest_sha256": R14_REVIEW_MANIFEST_SHA256,
    "source_pins": R14_ANCESTOR_SOURCE_PINS,
}
PRIOR_RUN_FACTS = {
    "r10_first_call": {
        "status": "wall_timeout",
        "exit_code": 15,
        "elapsed_seconds": 300.30108749999636,
        "peak_process_tree_rss_bytes": 2014654464,
        "last_flushed_marker": "NG12_STAGE stage=dispatch.before elapsed_ms=16642",
        "function_body_entry_observed": False,
        "solver_run_observed": False,
    },
    "r11_explicit_precompile": {
        "status": "wall_timeout",
        "exit_code": 15,
        "elapsed_seconds": 300.51891890000115,
        "peak_process_tree_rss_bytes": 2102079488,
        "rss_limit_bytes": 2147483648,
        "rss_margin_bytes": 45404160,
        "peak_sample_elapsed_seconds": 147.04105659999914,
        "last_sample_elapsed_seconds": 300.232050300001,
        "last_sample_rss_bytes": 2029449216,
        "last_sample_cpu_user_seconds": 280.21875,
        "last_flushed_marker": "NG12_STAGE stage=precompile.before elapsed_ms=16649 target=ng12_primary signature=(String,)",
        "precompile_return_observed": False,
        "primary_function_entry_observed": False,
        "solver_run_observed": False,
        "fresh_replay_executed": False,
    },
}
PRELAUNCH_PREFLIGHT = (
    "test/RuntimeV4/NativeG1G2DiffusionV1/r15_prelaunch_preflight_v1.py"
)
PRELAUNCH_PREFLIGHT_TEST = (
    "test/RuntimeV4/NativeG1G2DiffusionV1/test_r15_prelaunch_preflight_v1.py"
)
RESOURCE_REPORTER = (
    "test/RuntimeV4/NativeG1G2DiffusionV1/report_r15_resource_outcome_v1.py"
)
RESOURCE_MONITOR_TEST = (
    "test/RuntimeV4/NativeG1G2DiffusionV1/test_r15_resource_monitor_v1.py"
)

TIMEOUT_SECONDS = 480.0
PROCESS_TREE_RSS_LIMIT_BYTES = 2_147_483_648
JULIA_HEAP_SIZE_HINT = "1G"
JULIA_HEAP_SIZE_HINT_BYTES = 1_073_741_824
HEAVY_NAMES = {
    "julia.exe", "julia", "desc.exe", "desc", "mesh.exe", "mesh",
    "mpiexec.exe", "mpiexec",
}

OWNED_FILES = (
    "src/RuntimeV4/NativeG1G2DiffusionCompilerV1.jl",
    "src/RuntimeV4/GridapNativeG1G2DiffusionAdapterV1.jl",
    "test/RuntimeV4/NativeG1G2DiffusionV1/fixture_and_oracle.jl",
    "test/RuntimeV4/NativeG1G2DiffusionV1/focused_tests_r14_compile_min.jl",
    "test/RuntimeV4/NativeG1G2DiffusionV1/run_recorded_r15_v1.py",
)

RESOURCE_MONITOR_POLICY = {
    "schema": "native-g1g2-process-tree-monitor-fail-closed-v1",
    "sample_completeness_required": True,
    "enumeration_or_member_read_error_disposition": "resource_monitor_incomplete",
    "no_such_process_race_disposition": "resource_monitor_incomplete",
    "partial_rss_can_clear_threshold": False,
    "preserve_partial_rss_pids_and_raw_exception": True,
    "monitor_incomplete_is_resource_failure": True,
    "numerical_credit_on_monitor_incomplete": False,
}

GENOME_V5_DYNAMIC_COMPONENTS = (
    "src/GenomeV5/G1/GrammarProfileV2.jl",
    "src/GenomeV5/G1/EquationPlanV2.jl",
    "src/GenomeV5/G1/MechanismGenomePayloadV2.jl",
    "src/GenomeV5/G1/MechanismGenomeV5.jl",
    "src/GenomeV5/G2/SpatialGrammarProfileV2.jl",
    "src/GenomeV5/G2/RegionInterfaceContractV2.jl",
    "src/GenomeV5/G2/FieldSpacePlanV2.jl",
    "src/GenomeV5/G2/FieldGeometryGenomeV5.jl",
    "src/GenomeV5/G3/RealizationGenomeV5.jl",
    "src/GenomeV5/G3/ControlGenomeV5.jl",
    "src/GenomeV5/G3/CoupledRealizationControlBindingV2.jl",
    "src/GenomeV5/G3/RealizationControlGenomeV5.jl",
)

T0_DEFINITION_DEPENDENCIES = (
    "test/GenomeV5/Integration/vnext_declaration_transport_local_v1_tests.jl",
    "src/GenomeV5/G1/DiffusionDeclarationV1.jl",
    "src/GenomeV5/G1/G1SourceAuthorityFactoryV1.jl",
    "src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl",
    "src/GenomeV5/G2/G2SourceAuthorityFactoryV1.jl",
    "src/GenomeV5/G3/G3SourceFeedbackLawV1.jl",
    "src/GenomeV5/G3/G3SourceAuthorityFactoryV1.jl",
    "src/GenomeV5/Integration/VNextDeclarationTransportLocalV1.jl",
)

V3_FIXTURE_DEPENDENCIES = (
    "test/GenomeV5/Integration/VNextT2ConcreteSourceWitnessV3/fixture_helpers.jl",
    "src/GenomeV5/Integration/VNextDeclarationAuthorityRecheckLocalV1.jl",
    "src/GenomeV5/Integration/VNextParentBaselineBindingLocalV1.jl",
    "src/GenomeV5/G3/G3RealizationChildEditabilityV1.jl",
    "src/GenomeV5/G3/G3ControlChildEditabilityV1.jl",
    "src/GenomeV5/G3/G3BindingChildEditabilityV1.jl",
    "src/GenomeV5/G3/G3BindingChildEditabilityV2.jl",
    "src/GenomeV5/Integration/VNextG3BindingAuthorityBridgeLocalV1.jl",
    "src/GenomeV5/Integration/VNextT2ConcreteSourceWitnessV3.jl",
)

T1_V2_DEPENDENCIES = (
    "src/Contracts/VNextT1CanonicalBytesV2.jl",
    "src/Contracts/VNextT1CandidateBindingV2.jl",
    "src/GenomeV5/Integration/VNextDeclarationAuthorityRecheckLocalV2.jl",
    "src/Contracts/CandidateStatePackageV5NextV2.jl",
    "src/GenomeV5/Integration/VNextGenomeV5IntegrationV2.jl",
    "src/Contracts/VNextT1PackageBindingAdapterV2.jl",
)

NUMERICAL_DEPENDENCIES = (
    "src/RuntimeV4/GridapFieldResidualAdapter.jl",
    "src/RuntimeV4/NativeG1G2DiffusionCompilerV1.jl",
    "src/RuntimeV4/GridapNativeG1G2DiffusionAdapterV1.jl",
    "test/RuntimeV4/NativeG1G2DiffusionV1/fixture_and_oracle.jl",
    "test/RuntimeV4/NativeG1G2DiffusionV1/focused_tests_r14_compile_min.jl",
)


def utc() -> str:
    return datetime.now(timezone.utc).isoformat()


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def receipt(path: Path) -> dict[str, object]:
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": sha256_bytes(data)}


def load_r10_baseline_pins() -> dict[str, dict[str, object]]:
    raw = R10_BASELINE_MANIFEST.read_bytes()
    observed = sha256_bytes(raw)
    if observed != R10_BASELINE_MANIFEST_SHA256:
        raise RuntimeError(
            "frozen r10 baseline manifest hash mismatch: " + observed
        )
    document = json.loads(raw)
    dependencies = document.get("dependencies")
    if not isinstance(dependencies, dict) or len(dependencies) != R10_BASELINE_PIN_COUNT:
        raise RuntimeError("frozen r10 baseline must contain exactly 115 pins")
    for relative, expected in dependencies.items():
        candidate = (ROOT / Path(*relative.split("/"))).resolve()
        try:
            candidate.relative_to(ROOT.resolve())
        except ValueError as error:
            raise RuntimeError("r10 baseline path escaped repository") from error
        if not candidate.is_file():
            raise FileNotFoundError("r10 baseline dependency missing: " + relative)
        current = receipt(candidate)
        if current != {"bytes": expected["bytes"], "sha256": expected["sha256"]}:
            raise RuntimeError("r10 baseline dependency changed: " + relative)
    return dependencies


def recorded_julia_environment(environment: dict[str, str]) -> dict[str, str]:
    """Return the complete, non-secret Julia execution environment contract."""

    keys = (
        "JULIA_LOAD_PATH", "JULIA_NUM_THREADS", "OPENBLAS_NUM_THREADS",
        "MKL_NUM_THREADS", "OMP_NUM_THREADS", "JULIA_PKG_OFFLINE",
        "JULIA_PKG_PRECOMPILE_AUTO",
    )
    return {key: environment[key] for key in keys}


def write_new(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, indent=2, sort_keys=True)
        stream.write("\n")


def fusion_package_source_paths() -> list[Path]:
    entry = ROOT / "src/FusionConceptAI.jl"
    text = entry.read_text(encoding="utf-8")
    includes = re.findall(
        r'^\s*include\("([^"\r\n]+\.jl)"\)\s*$', text, flags=re.MULTILINE
    )
    include_calls = len(re.findall(r"\binclude\(", text))
    if len(includes) != include_calls:
        raise RuntimeError(
            "unresolved FusionConceptAI include form: "
            f"resolved={len(includes)} calls={include_calls}"
        )
    return [entry, *(ROOT / "src" / relative for relative in includes)]


def runtime_package_source_paths() -> list[Path]:
    entry = ROOT / "src/RuntimeV4/FusionRuntimeV4.jl"
    text = entry.read_text(encoding="utf-8")
    includes = re.findall(
        r'^\s*include\("([^"\r\n]+\.jl)"\)\s*$', text, flags=re.MULTILINE
    )
    include_calls = len(re.findall(r"\binclude\(", text))
    if len(includes) != include_calls:
        raise RuntimeError(
            "unresolved FusionRuntimeV4 include form: "
            f"resolved={len(includes)} calls={include_calls}"
        )
    return [entry, *(ROOT / "src/RuntimeV4" / relative for relative in includes)]


def assert_loader_inventories() -> None:
    genome_loader = ROOT / "src/GenomeV5/Integration/GenomeV5Integration.jl"
    observed = set(re.findall(
        r'"([^"\r\n]+\.jl)"', genome_loader.read_text(encoding="utf-8")
    ))
    expected = {Path(item).name for item in GENOME_V5_DYNAMIC_COMPONENTS}
    if observed != expected:
        raise RuntimeError(
            "GenomeV5 dynamic loader inventory mismatch: "
            f"observed={sorted(observed)} expected={sorted(expected)}"
        )

    t0 = ROOT / T0_DEFINITION_DEPENDENCIES[0]
    preamble = t0.read_text(encoding="utf-8").split(
        "# Current factory APIs", 1
    )[0]
    observed = set(re.findall(r'"([^"\r\n]+\.jl)"', preamble))
    expected = {Path(item).name for item in T0_DEFINITION_DEPENDENCIES[1:]}
    if observed != expected or "load_genome_v5_components!()" not in preamble:
        raise RuntimeError(
            "T0 definition loader inventory mismatch: "
            f"observed={sorted(observed)} expected={sorted(expected)}"
        )

    v3_fixture = ROOT / V3_FIXTURE_DEPENDENCIES[0]
    preamble = v3_fixture.read_text(encoding="utf-8").split(
        "const V3_CANDIDATE", 1
    )[0]
    observed = set(re.findall(r'"([^"\r\n]+\.jl)"', preamble))
    expected = {
        Path(T0_DEFINITION_DEPENDENCIES[0]).name,
        *(Path(item).name for item in V3_FIXTURE_DEPENDENCIES[1:]),
    }
    if observed != expected:
        raise RuntimeError(
            "V3 fixture loader inventory mismatch: "
            f"observed={sorted(observed)} expected={sorted(expected)}"
        )

    fixture = (ROOT / NUMERICAL_DEPENDENCIES[-2]).read_text(encoding="utf-8")
    observed = set(re.findall(r'"([^"\r\n]+\.jl)"', fixture))
    required = {
        Path(V3_FIXTURE_DEPENDENCIES[0]).name,
        *(Path(item).name for item in T1_V2_DEPENDENCIES),
        Path(NUMERICAL_DEPENDENCIES[0]).name,
        Path(NUMERICAL_DEPENDENCIES[1]).name,
        Path(NUMERICAL_DEPENDENCIES[2]).name,
    }
    missing = required - observed
    if missing:
        raise RuntimeError(
            "native fixture lost an explicit dependency: " +
            json.dumps(sorted(missing))
        )


def runtime_julia_paths() -> list[Path]:
    assert_loader_inventories()
    paths = set(fusion_package_source_paths())
    paths.update(runtime_package_source_paths())
    for group in (
        GENOME_V5_DYNAMIC_COMPONENTS,
        T0_DEFINITION_DEPENDENCIES,
        V3_FIXTURE_DEPENDENCIES,
        T1_V2_DEPENDENCIES,
        NUMERICAL_DEPENDENCIES,
    ):
        paths.update(ROOT / item for item in group)
    missing = [str(path) for path in paths if not path.is_file()]
    if missing:
        raise FileNotFoundError(
            "runtime Julia dependency missing: " + json.dumps(missing)
        )
    return sorted(paths)


def dependency_paths() -> list[Path]:
    paths = set(runtime_julia_paths())
    paths.add(Path(__file__).resolve())
    paths.add(R10_BASELINE_MANIFEST)
    paths.add(R10_BASELINE_PARSE_MANIFEST)
    paths.add(R10_BASELINE_PROTOCOL)
    paths.add((ROOT / PRELAUNCH_PREFLIGHT).resolve())
    paths.add((ROOT / PRELAUNCH_PREFLIGHT_TEST).resolve())
    paths.add((ROOT / RESOURCE_REPORTER).resolve())
    paths.add((ROOT / RESOURCE_MONITOR_TEST).resolve())
    paths.add(R13_STATIC_PROTOCOL)
    paths.add((ROOT / R14_STATIC_PROTOCOL_REL).resolve())
    paths.add((ROOT / R14_REVIEW_REPORT_REL).resolve())
    paths.add((ROOT / R14_REVIEW_MANIFEST_REL).resolve())
    paths.update((ROOT / item).resolve() for item in R14_ANCESTOR_SOURCE_PINS)
    baseline = load_r10_baseline_pins()
    paths.update(
        (ROOT / Path(*relative.split("/"))).resolve()
        for relative in baseline
    )
    for path in (
        ROOT / "Project.toml",
        ROOT / "Manifest.toml",
        GRIDAP_PROJECT / "Project.toml",
        GRIDAP_PROJECT / "Manifest.toml",
        ROOT / "docs/implementation/GOAL-EXECUTION-20260922/"
        "ownership_delta13_native_g1g2_physics.json",
        ROOT / "docs/implementation/UP1-04A-VNEXT-T2-SOURCE-WITNESS-PREC/"
        "astra_physics_gap_review_r1_20260922/review.md",
    ):
        if path.is_file():
            paths.add(path)
    return sorted(paths)


def dependency_receipts() -> dict[str, dict[str, object]]:
    return {
        path.resolve().relative_to(ROOT.resolve()).as_posix(): receipt(path)
        for path in dependency_paths()
    }


def static_checks() -> dict[str, object]:
    runner = Path(__file__).read_text(encoding="utf-8")
    ast.parse(runner, filename=__file__)
    source = (ROOT / OWNED_FILES[0]).read_text(encoding="utf-8")
    adapter = (ROOT / OWNED_FILES[1]).read_text(encoding="utf-8")
    fixture = (ROOT / OWNED_FILES[2]).read_text(encoding="utf-8")
    tests = (ROOT / OWNED_FILES[3]).read_text(encoding="utf-8")
    r10_tests = (ROOT / "test/RuntimeV4/NativeG1G2DiffusionV1/focused_tests.jl").read_text(
        encoding="utf-8"
    )
    preflight = (ROOT / PRELAUNCH_PREFLIGHT).read_text(encoding="utf-8")
    preflight_tests = (ROOT / PRELAUNCH_PREFLIGHT_TEST).read_text(encoding="utf-8")
    reporter = (ROOT / RESOURCE_REPORTER).read_text(encoding="utf-8")
    monitor_tests = (ROOT / RESOURCE_MONITOR_TEST).read_text(encoding="utf-8")
    compact_tests = re.sub(r"\s+", " ", tests)
    dispatch_marker = 'ng12_stage("dispatch.before"; detail="mode=" * mode)\n'
    precompile_before = tests.find('ng12_stage("precompile.before"')
    precompile_call = tests.find("precompile(ng12_primary, (String,))")
    precompile_try = tests.rfind("try", 0, precompile_call)
    precompile_return = tests.find('ng12_stage("precompile.return"')
    precompile_catch = tests.find("catch error", precompile_call)
    precompile_caught = tests.find("precompile_exception = error", precompile_catch)
    precompile_exception_marker = tests.find('ng12_stage("precompile.exception"')
    precompile_after = tests.find('ng12_stage("precompile.after"')
    function_entry_marker = '    ng12_stage("primary.function.enter")\n'
    function_header = "function ng12_primary(artifact_path::AbstractString)\n"
    primary_entry = tests.find(function_entry_marker)
    primary_definition = tests.find(function_header)
    primary_fixture = tests.find('ng12_stage("primary.fixture.begin")')
    primary_call = tests.rfind("ng12_primary(artifact_path)")
    r12_prefix = tests.split(dispatch_marker, 1)[0]
    checks = {
        "typed_source_bytes": all(token in source for token in (
            "unknown_source_expression", "source_expression",
            "TypedASTProgramV1", "minus_div_k_grad_equals_f",
        )),
        "complete_program_projection": all(token in source for token in (
            "native_g1g2_program_bundle_v1",
            "program_semantic_projection_mismatch",
            "canonical_json(x) == canonical_json(expected)",
        )),
        "variable_k_residual": all(token in source for token in (
            "K_APPLY", "DIV_OP", "residual_operator_wiring_invalid",
            "p.k_slope",
        )),
        "unit_basis_profile": all(token in source for token in (
            'source_basis == "GenomeV5/native-length-first-partial-basis-v1"',
            'target_basis == "RuntimeV4/SI-kg-m-s-A-K-mol-cd-v1"',
            "source_length_axis", "target_length_axis", "scale == 1 // 1",
            "undocumented non-length axis",
            "translated_g2_flux_unit_mismatch",
        )),
        "actual_t1_package_carried": all(token in source for token in (
            "t1_package::CandidateStatePackageV5NextV2",
            "_ng12_t1_package_binding_errors",
            "vnext_t1_package_binding_adapter_v2",
        )),
        "runtime_subject_reconstructed": all(token in source for token in (
            "_ng12_runtime_projection_v1",
            "canonical_json(x.capability) == canonical_json(projected.capability)",
            "canonical_json(x.subject) == canonical_json(projected.subject)",
        )),
        "actual_gridap_weak_form": all(token in adapter for token in (
            "CartesianDiscreteModel", "AffineFEOperator", "LUSolver",
            "k_field", "native_g1g2_source_value_v1",
        )),
        "byte_carrier_numeric_hashes": all(token in adapter for token in (
            "rows=Vector{Int}(rows)", "columns=Vector{Int}(columns)",
            "values=Vector{Float64}(values)",
            "rhs_hash = canonical_hash(rhs)",
            "solution_hash = canonical_hash(free_values)",
        )) and "canonical_hash(Tuple(rhs))" not in adapter,
        "actual_discrete_balance": all(token in adapter for token in (
            "BoundaryTriangulation", "discrete_trace_conormal_integral",
            "_ng12_full_space_dof_partition",
            "boundary_reactions = full_reactions[dof_partition.boundary_to_full]",
            "interior_reactions = full_reactions[dof_partition.free_to_full]",
            "discrete_interior_residual_match_linf",
            "discrete_boundary_reaction_integral",
            "discrete_boundary_reaction_balance_defect",
        )) and "sum(full_reactions)" not in adapter,
        "no_global_provider_plan": "_NG12_ACTIVE_PROVIDER_PLAN" not in adapter,
        "provider_self_reconstructs": all(token in adapter for token in (
            "compile_result_hash=", "provider plan reconstruction mismatch",
            "_ng12_run_gridap_series(rebuilt_plan)",
        )),
        "independent_oracle": all(token in fixture for token in (
            "ng12_oracle_reference", "ng12_oracle_source",
            "ng12_oracle_continuous_balance",
        )),
        "three_grid_refinement":
            "((2, 3, 4), (4, 6, 8), (8, 12, 16))" in compact_tests,
        "recomputed_tamper": all(token in tests for token in (
            "ng12_rehashed_level", "ng12_rehashed_report",
            "forged_level", "foreign_report",
        )),
        "wrong_sign_negative": "run_native_g1g2_wrong_sign_control_v1" in tests,
        "wrong_sign_reaches_solver": all(token in tests for token in (
            "reversed.matrix_hash == report.levels[2].matrix_hash",
            "reversed.rhs_hash != report.levels[2].rhs_hash",
            "reversed.solution_hash != report.levels[2].solution_hash",
            "reversed.l2_error > report.levels[2].l2_error",
        )),
        "coherent_source_program_negative": all(token in tests for token in (
            "ng12_alternative_source_program_bundle",
            "program_semantic_projection_mismatch",
        )),
        "g2_mesh_and_quadrature_bound": all(token in tests for token in (
            "plan.protocol.cell_counts[1] == chain.g2.source.mesh.cells",
            "identity_bound_geometry_metadata_not_execution_rule",
        )),
        "fresh_before_deserialize": tests.index("fresh = NG12_R.execute") <
            tests.index("Serialization.deserialize", tests.index("function ng12_replay")),
        "formal_receipts_zero": "formal_t2_consumer_receipts=0" in tests,
        "preassert_checkpoints": all(token in tests for token in (
            'artifact_path * ".preassert.bin"',
            '".wrong-sign-preassert.bin"',
            'artifact_path * ".replay-preassert.bin"',
            "wrong_sign_level=reversed",
        )) and tests.index("primary.preassert_checkpoint.complete") <
            tests.index("primary.wrong_sign.begin"),
        "metric_units": all(token in tests for token in (
            "_ng12_si_length_unit(3 // 2)",
            "_ng12_si_length_unit(1 // 2)",
            "_ng12_si_length_unit(1)",
            ":max_interior_reaction_linf",
            ":max_interior_residual_match_linf",
            ":max_discrete_boundary_reaction_balance_defect",
        )),
        "error_budget_basis": all(token in adapter for token in (
            "cea_finest_h1_bound_m12=0.009487198126",
            "poincare_finest_l2_bound_m32=0.004639855187",
            "gridap_quadrature_degree=8", "_ng12_error_budget_applies",
            "p.k_base == b.k_base", "p.k_slope == b.k_slope",
        )) and all(token in tests for token in (
            "altered_k_programs", "altered_k_compile",
            '"error budget does not apply"',
        )),
        "actual_t2_link_validation": all(token in adapter for token in (
            "t2_input_hash", "_ng12_validate_actual_t2_ledger_v1",
            "VNextT2UP2BoundInputV2", "expected_stage_inputs",
            "vnext_t2_up2_validate_input_v2",
            ":VNextT2InvocationCountsV2)(1, 1, 1, 1, 1, 0, 0, 0)",
            "receipt.identity_hash == canonical_hash(body)",
            "ledger.input_hash",
        )) and "actual qualified T2 receipt ledger is invalid" in tests,
        "immutable_protocol_literals": all(token in tests for token in (
            "residual_abs_tol == 1e-9", "l2_order_interval == (1.4, 2.6)",
            "analytic_identity_abs_tol == 1e-12",
            "reaction_balance_abs_tol == 1e-9",
            "finest_h1_seminorm_max == 1e-2",
            "assembly_calls=6",
        )),
        "parse_gate_rejects_error_nodes": all(token in runner for token in (
            "function ng12_parse_issue(x)",
            "x.head in (:error,:incomplete)",
            'error("parse tree "*String(issue)*": "*relative)',
        )),
        "runtime_package_environment_stack": all(token in runner for token in (
            'JULIA_LOAD_PATH_ENTRIES = ("@", str(ROOT), "@stdlib")',
            '"JULIA_LOAD_PATH": os.pathsep.join(JULIA_LOAD_PATH_ENTRIES)',
            '"JULIA_PKG_OFFLINE": "true"',
            '"JULIA_PKG_PRECOMPILE_AUTO": "0"',
            '"primary_and_fresh_replay_identical": True',
            "recorded_julia_environment(environment)",
        )),
        "early_flushed_memory_observability": all(token in tests for token in (
            'ng12_stage("entry.before_imports"',
            'ng12_stage("entry.before_fixture_include")',
            'ng12_stage("entry.after_fixture_include")',
            'ng12_stage("dispatch.before"',
            "Base.gc_live_bytes", "Base.jit_total_bytes", "Sys.maxrss",
            "Base.gc_time_ns", "flush(stdout)",
        )) and all(token in fixture for token in (
            'ng12_stage("fixture.before_using_fusionconceptai")',
            'ng12_stage("fixture.after_using_fusionconceptai")',
            'ng12_stage("fixture.before_v3_fixture_include")',
            'ng12_stage("fixture.after_v3_fixture_include")',
            'ng12_stage("fixture.source_chain.begin")',
            'ng12_stage("fixture.compiler.begin")',
            'ng12_stage("fixture.plan.begin")',
            'ng12_stage("fixture.definitions.complete")',
        )) and "GC.gc(" not in tests + fixture,
        "documented_gc_hint_under_sampled_rss_stop_trigger": all(
            token in runner for token in (
                'JULIA_HEAP_SIZE_HINT = "1G"',
                "JULIA_HEAP_SIZE_HINT_BYTES = 1_073_741_824",
                'f"--heap-size-hint={JULIA_HEAP_SIZE_HINT}"',
                "PROCESS_TREE_RSS_LIMIT_BYTES = 2_147_483_648",
            )
        ),
        "sampled_rss_semantics_and_peak_sample_time": all(
            token in runner for token in (
                '"rss_enforcement_semantics": "sampled_stop_trigger"',
                '"sampled_overshoot_possible": True',
                '"sampled_threshold_hit_or_overshoot_disposition": "resource_failure"',
                '"peak_process_tree_rss_sample_index"',
                '"peak_process_tree_rss_sample_utc"',
                '"peak_process_tree_rss_sample_elapsed_seconds"',
            )
        ),
        "compile_min_is_the_only_compiler_argv_delta": (
            "--compile=min" in runner and
            julia_prefix("julia.exe").count("--compile=min") == 1 and
            all(
                command.count("--compile=min") == 1
                and "--optimize=0" not in command
                and "--inline=no" not in command
                for _, command in planned_stage_commands(
                    EVIDENCE_ROOT / "r15_actual_v1", "julia.exe"
                )
            )
        ),
        "r12_precompile_return_exception_and_entry_markers": (
            precompile_before >= 0 and
            precompile_before < precompile_try < precompile_call < precompile_return <
            precompile_catch < precompile_caught < precompile_exception_marker <
            precompile_after < primary_call and
            primary_definition >= 0 and
            primary_definition + len(function_header) == primary_entry < primary_fixture and
            tests.count(function_entry_marker) == 1 and
            tests.count(dispatch_marker) == 1 and
            'ng12_stage("dispatch.before"' in tests and
            "ng12_primary(artifact_path)" in tests and
            "ng12_replay(artifact_path)" in tests and
            "precompile.return" in tests and "precompile.exception" in tests and
            "precompile.after" in tests and
            "precompile_exception = nothing" in tests and
            "precompile_exception === nothing" not in tests
        ),
        "r12_test_body_matches_r10_with_only_entry_marker_delta": (
            r10_tests.count(dispatch_marker) == 1 and
            tests.count(dispatch_marker) == 1 and
            r10_tests.split(dispatch_marker, 1)[0] ==
                r12_prefix.replace(function_entry_marker, "", 1) and
            r12_prefix.count(function_entry_marker) == 1
        ),
        "r15_python_argv_role_prelaunch_verifier_and_tests": all(token in preflight for token in (
            "R10_BASELINE_PIN_COUNT = 115",
            "def verify_argv_identity(",
            "selected_expected_field",
            "observed_parent_argv",
            "expected_runtime_supervisor_argv",
            "planned_stage_commands(planned_output, julia)",
            "fixture_cases_or_mesh_levels_changed",
            "julia_started",
        )) and all(token in preflight_tests for token in (
            "test_static_invocation_role_accepts_exact_parent",
            "test_actual_runtime_role_accepts_exact_parent",
            "test_static_argv_is_not_accepted_for_actual_mode",
            "test_extra_actual_argv_fails_closed_with_diagnostic",
        )),
        "r15_protocol_argv_roles_are_explicit": all(token in runner for token in (
            '"runner_invocation_argv": [',
            '"expected_runtime_supervisor_argv": planned_expected_runtime_supervisor_argv',
            '"argv_identity_contract": {',
            '"static_only": "runner_invocation_argv"',
            '"actual": "expected_runtime_supervisor_argv"',
        )),
        "r12_r10_baseline_pin_constants": all(token in runner for token in (
            R10_BASELINE_MANIFEST_SHA256,
            R10_BASELINE_PARSE_MANIFEST_SHA256,
            R10_BASELINE_PROTOCOL_SHA256,
            "R10_BASELINE_PIN_COUNT = 115",
        )),
        "r10_115_frozen_pins_unchanged": (
            len(load_r10_baseline_pins()) == R10_BASELINE_PIN_COUNT
        ),
        "per_pid_tree_resource_attribution": all(token in runner for token in (
            '"process_tree_processes": processes', '"name": member.name()',
            '"cmdline": member.cmdline()', '"create_time": member.create_time()',
            '"rss_bytes": int(memory.rss)', '"cpu_user_seconds": float(cpu.user)',
            '"cpu_system_seconds": float(cpu.system)',
            '"per_pid_peak_resources": per_pid_peak',
        )),
        "r15_process_tree_monitor_fails_closed": all(token in runner for token in (
            '"process_tree_sample_complete": monitor["complete"]',
            '"process_tree_sample_errors": monitor["errors"]',
            '"partial_process_tree_rss_bytes": monitor["partial_rss_bytes"]',
            '"process_tree_discovered_pids": monitor["discovered_pids"]',
            '"resource_monitor_incomplete"',
            '"resource_monitor_complete": resource_monitor_complete',
            'RESOURCE_MONITOR_POLICY',
        )) and all(token in reporter for token in (
            '"resource_monitor_incomplete"',
            '"process_tree_sample_complete"',
            '"partial_process_tree_rss_bytes"',
            '"process_tree_sample_errors"',
            '"numerical_credit_on_monitor_incomplete": False',
        )) and all(token in monitor_tests for token in (
            'test_access_denied_member_read_is_incomplete',
            'test_access_denied_child_discovery_is_incomplete',
            'test_disappearing_child_is_incomplete',
            'test_reporter_preserves_partial_rss_pids_and_exception',
            'test_missing_completeness_marker_cannot_be_no_crossing',
        )),
    }
    failed = sorted(name for name, passed in checks.items() if not passed)
    if failed:
        raise RuntimeError("static checks failed: " + json.dumps(failed))
    return {
        "checks": checks,
        "check_count": len(checks),
        "julia_dependency_count": len(runtime_julia_paths()),
        "owned_files": {item: receipt(ROOT / item) for item in OWNED_FILES},
    }


def heavy_processes() -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for process in psutil.process_iter(["name", "cmdline", "create_time"]):
        name = (process.info.get("name") or "").lower()
        if name in HEAVY_NAMES:
            rows.append({
                "pid": process.pid,
                "name": process.info.get("name"),
                "cmdline": process.info.get("cmdline"),
                "create_time": process.info.get("create_time"),
            })
    return rows


def _resource_error_record(
    error: Exception | None,
    *,
    phase: str,
    pid: int | None,
    reason: str | None = None,
) -> dict[str, object]:
    if isinstance(error, psutil.AccessDenied):
        category = "access_denied"
    elif isinstance(error, psutil.NoSuchProcess):
        category = "process_disappeared_during_sample"
    elif isinstance(error, psutil.Error):
        category = "psutil_error"
    elif error is None:
        category = "monitor_identity_failure"
    else:
        category = "unexpected_sample_error"
    return {
        "phase": phase,
        "pid": pid,
        "category": category,
        "reason": reason,
        "exception_type": type(error).__name__ if error is not None else None,
        "exception_message": str(error) if error is not None else None,
        "exception_repr": repr(error) if error is not None else None,
    }


def tree_resources(process: psutil.Process) -> dict[str, object]:
    """Take one observable process-tree sample without hiding partial reads.

    ``complete`` means child enumeration succeeded and every enumerated member
    yielded RSS, CPU, and identity metadata in this sample. psutil does not
    provide an atomic OS-wide process snapshot, so this does not claim that a
    process could not appear between enumeration and measurement.
    """
    errors: list[dict[str, object]] = []
    members = [process]
    root_pid = getattr(process, "pid", None)
    enumeration_complete = True
    try:
        members.extend(process.children(recursive=True))
    except Exception as error:
        enumeration_complete = False
        errors.append(_resource_error_record(
            error, phase="children_enumeration", pid=root_pid
        ))

    discovered_pids: list[int] = []
    for member in members:
        try:
            discovered_pids.append(int(member.pid))
        except Exception as error:
            errors.append(_resource_error_record(
                error, phase="member_pid_read", pid=None
            ))

    partial_rss = 0
    rows: list[dict[str, object]] = []
    for member in members:
        try:
            member_pid = int(member.pid)
        except Exception:
            member_pid = None
        row: dict[str, object] = {
            "pid": member_pid,
            "name": None,
            "cmdline": None,
            "create_time": None,
            "rss_bytes": None,
            "cpu_user_seconds": None,
            "cpu_system_seconds": None,
        }
        try:
            with member.oneshot():
                memory = member.memory_info()
                row["rss_bytes"] = int(memory.rss)
                partial_rss += int(memory.rss)
                cpu = member.cpu_times()
                row["cpu_user_seconds"] = float(cpu.user)
                row["cpu_system_seconds"] = float(cpu.system)
                row["name"] = member.name()
                row["cmdline"] = member.cmdline()
                row["create_time"] = member.create_time()
        except Exception as error:
            errors.append(_resource_error_record(
                error, phase="member_resource_read", pid=member_pid
            ))
        rows.append(row)

    rows.sort(key=lambda row: (row["pid"] is None, row["pid"] or -1))
    discovered_pids = sorted(set(discovered_pids))
    measured_pids = sorted(
        int(row["pid"]) for row in rows
        if row["pid"] is not None and isinstance(row["rss_bytes"], int)
    )
    expected_count = len(members) if enumeration_complete else None
    measured_count = len(measured_pids)
    complete = (
        enumeration_complete and not errors and
        expected_count == len(rows) == measured_count and
        len(discovered_pids) == len(members)
    )
    return {
        "complete": complete,
        "partial_rss_bytes": partial_rss,
        "processes": rows,
        "discovered_pids": discovered_pids,
        "measured_pids": measured_pids,
        "expected_member_count": expected_count,
        "measured_member_count": measured_count,
        "errors": errors,
    }


def kill_tree(process: psutil.Process) -> None:
    try:
        children = process.children(recursive=True)
    except psutil.Error:
        children = []
    for child in reversed(children):
        try:
            child.kill()
        except psutil.Error:
            pass
    try:
        process.kill()
    except psutil.Error:
        pass


def write_parse_manifest(
    path: Path,
    snapshot: dict[str, dict[str, object]],
) -> dict[str, object]:
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        for source in runtime_julia_paths():
            relative = source.resolve().relative_to(ROOT.resolve()).as_posix()
            stream.write(f"{snapshot[relative]['sha256']}\t{relative}\n")
    return {"entries": len(runtime_julia_paths()), **receipt(path)}


def run_step(
    output: Path,
    index: int,
    name: str,
    command: list[str],
    snapshot: dict[str, dict[str, object]],
    environment: dict[str, str],
    artifacts: dict[str, dict[str, object]] | None = None,
) -> dict[str, object]:
    active = heavy_processes()
    if active:
        raise RuntimeError(
            f"heavy process lane is not exclusive before {name}: " +
            json.dumps(active, sort_keys=True)
        )
    stage = output / f"{index:02d}_{name}"
    stage.mkdir()
    write_new(stage / "checkpoint_before_assert.json", {
        "schema": "native-g1g2-recorded-checkpoint-v1",
        "created_utc": utc(),
        "stage": name,
        "command": command,
        "dependencies": snapshot,
        "artifacts": artifacts or {},
        "environment": recorded_julia_environment(environment),
        "timeout_seconds": TIMEOUT_SECONDS,
        "process_tree_rss_limit_bytes": PROCESS_TREE_RSS_LIMIT_BYTES,
        "julia_heap_size_hint": JULIA_HEAP_SIZE_HINT,
        "julia_heap_size_hint_bytes": JULIA_HEAP_SIZE_HINT_BYTES,
    })
    started = time.monotonic()
    started_utc = utc()
    stop_reason = "natural_exit"
    samples: list[dict[str, object]] = []
    resource_monitor_failure: dict[str, object] | None = None
    with (stage / "stdout.raw").open("xb") as stdout, \
            (stage / "stderr.raw").open("xb") as stderr:
        process = subprocess.Popen(
            command, cwd=ROOT, env=environment, stdout=stdout, stderr=stderr,
            creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
        )
        observed: psutil.Process | None = None
        create_time: float | None = None
        monitor_init_error: dict[str, object] | None = None
        try:
            observed = psutil.Process(process.pid)
            create_time = observed.create_time()
        except Exception as error:
            monitor_init_error = _resource_error_record(
                error, phase="root_process_identity", pid=process.pid
            )
        write_new(stage / "start.json", {
            "schema": "native-g1g2-recorded-stage-v1",
            "stage": name,
            "command": command,
            "cwd": str(ROOT),
            "pid": process.pid,
            "process_create_time": create_time,
            "resource_monitor_init_error": monitor_init_error,
            "started_utc": started_utc,
            "environment": recorded_julia_environment(environment),
            "timeout_seconds": TIMEOUT_SECONDS,
            "process_tree_rss_limit_bytes": PROCESS_TREE_RSS_LIMIT_BYTES,
            "julia_heap_size_hint": JULIA_HEAP_SIZE_HINT,
            "julia_heap_size_hint_bytes": JULIA_HEAP_SIZE_HINT_BYTES,
        })
        with (stage / "samples.jsonl").open(
            "x", encoding="utf-8", newline="\n", buffering=1
        ) as stream:
            while process.poll() is None:
                if monitor_init_error is not None or observed is None:
                    monitor = {
                        "complete": False,
                        "partial_rss_bytes": 0,
                        "processes": [],
                        "discovered_pids": [process.pid],
                        "measured_pids": [],
                        "expected_member_count": None,
                        "measured_member_count": 0,
                        "errors": [monitor_init_error or _resource_error_record(
                            None, phase="root_process_identity", pid=process.pid,
                            reason="process_monitor_object_unavailable",
                        )],
                    }
                else:
                    try:
                        observed_create_time = observed.create_time()
                        if observed_create_time != create_time:
                            monitor = {
                                "complete": False,
                                "partial_rss_bytes": 0,
                                "processes": [],
                                "discovered_pids": [process.pid],
                                "measured_pids": [],
                                "expected_member_count": None,
                                "measured_member_count": 0,
                                "errors": [_resource_error_record(
                                    None, phase="root_process_identity", pid=process.pid,
                                    reason="pid_ownership_invalid",
                                )],
                            }
                        else:
                            monitor = tree_resources(observed)
                    except Exception as error:
                        monitor = {
                            "complete": False,
                            "partial_rss_bytes": 0,
                            "processes": [],
                            "discovered_pids": [process.pid],
                            "measured_pids": [],
                            "expected_member_count": None,
                            "measured_member_count": 0,
                            "errors": [_resource_error_record(
                                error, phase="root_process_identity", pid=process.pid
                            )],
                        }
                rss = int(monitor["partial_rss_bytes"])
                errors = monitor["errors"]
                sample = {
                    "utc": utc(),
                    "elapsed_seconds": time.monotonic() - started,
                    "root_pid": process.pid,
                    "process_tree_sample_complete": monitor["complete"],
                    "process_tree_sample_errors": errors,
                    "process_tree_expected_member_count": monitor["expected_member_count"],
                    "process_tree_measured_member_count": monitor["measured_member_count"],
                    "process_tree_pids": monitor["discovered_pids"],
                    "process_tree_discovered_pids": monitor["discovered_pids"],
                    "process_tree_measured_pids": monitor["measured_pids"],
                    "process_tree_processes": monitor["processes"],
                    "process_tree_rss_bytes": rss,
                    "partial_process_tree_rss_bytes": rss,
                }
                samples.append(sample)
                stream.write(json.dumps(sample, sort_keys=True) + "\n")
                if not monitor["complete"]:
                    stop_reason = "resource_monitor_incomplete"
                    resource_monitor_failure = {
                        "failure_class": "resource_monitor_incomplete",
                        "sample_index": len(samples),
                        "partial_process_tree_rss_bytes": rss,
                        "process_tree_pids": monitor["discovered_pids"],
                        "process_tree_measured_pids": monitor["measured_pids"],
                        "process_tree_expected_member_count": monitor["expected_member_count"],
                        "process_tree_measured_member_count": monitor["measured_member_count"],
                        "raw_errors": errors,
                    }
                    break
                if rss >= PROCESS_TREE_RSS_LIMIT_BYTES:
                    stop_reason = "process_tree_rss_limit"
                    break
                if time.monotonic() - started >= TIMEOUT_SECONDS:
                    stop_reason = "wall_timeout"
                    break
                time.sleep(0.2)
            if not samples:
                no_sample_error = monitor_init_error or _resource_error_record(
                    None, phase="process_tree_sampling", pid=process.pid,
                    reason="no_process_tree_sample_observed",
                )
                sample = {
                    "utc": utc(),
                    "elapsed_seconds": time.monotonic() - started,
                    "root_pid": process.pid,
                    "process_tree_sample_complete": False,
                    "process_tree_sample_errors": [no_sample_error],
                    "process_tree_expected_member_count": None,
                    "process_tree_measured_member_count": 0,
                    "process_tree_pids": [process.pid],
                    "process_tree_discovered_pids": [process.pid],
                    "process_tree_measured_pids": [],
                    "process_tree_processes": [],
                    "process_tree_rss_bytes": 0,
                    "partial_process_tree_rss_bytes": 0,
                }
                samples.append(sample)
                stream.write(json.dumps(sample, sort_keys=True) + "\n")
                stop_reason = "resource_monitor_incomplete"
                resource_monitor_failure = {
                    "failure_class": "resource_monitor_incomplete",
                    "sample_index": 1,
                    "partial_process_tree_rss_bytes": 0,
                    "process_tree_pids": [process.pid],
                    "process_tree_measured_pids": [],
                    "process_tree_expected_member_count": None,
                    "process_tree_measured_member_count": 0,
                    "raw_errors": [no_sample_error],
                }
            if process.poll() is None and stop_reason != "natural_exit":
                if observed is not None:
                    kill_tree(observed)
                else:
                    try:
                        process.kill()
                    except OSError:
                        pass
            exit_code = process.wait()
    per_pid_peak: dict[str, dict[str, object]] = {}
    for sample in samples:
        for row in sample["process_tree_processes"]:
            if not isinstance(row.get("rss_bytes"), int):
                continue
            key = str(row["pid"])
            previous = per_pid_peak.get(key)
            if previous is None or int(row["rss_bytes"]) > int(
                previous["peak_rss_bytes"]
            ):
                per_pid_peak[key] = {
                    "pid": row["pid"],
                    "name": row["name"],
                    "cmdline": row["cmdline"],
                    "create_time": row["create_time"],
                    "peak_rss_bytes": row["rss_bytes"],
                    "cpu_user_seconds_at_peak": row["cpu_user_seconds"],
                    "cpu_system_seconds_at_peak": row["cpu_system_seconds"],
                }
    peak_sample_index: int | None = None
    peak_sample: dict[str, object] | None = None
    if samples:
        # max() selects the first sample on ties; preserve that exact sample time.
        peak_sample_index = max(
            range(len(samples)),
            key=lambda sample_index: int(samples[sample_index]["process_tree_rss_bytes"]),
        )
        peak_sample = samples[peak_sample_index]
    peak_sample_rss = (
        int(peak_sample["process_tree_rss_bytes"]) if peak_sample is not None else 0
    )
    final = {
        "schema": "native-g1g2-recorded-stage-v1",
        "index": index,
        "stage": name,
        "command": command,
        "started_utc": started_utc,
        "ended_utc": utc(),
        "elapsed_seconds": time.monotonic() - started,
        "exit_code": exit_code,
        "stop_reason": stop_reason,
        "resource_monitor_complete": resource_monitor_failure is None,
        "resource_monitor_status": (
            "complete" if resource_monitor_failure is None else "incomplete"
        ),
        "resource_monitor_failure": resource_monitor_failure,
        "julia_heap_size_hint": JULIA_HEAP_SIZE_HINT,
        "julia_heap_size_hint_bytes": JULIA_HEAP_SIZE_HINT_BYTES,
        "peak_process_tree_rss_bytes": peak_sample_rss,
        "peak_process_tree_rss_sample_index": (
            peak_sample_index + 1 if peak_sample_index is not None else None
        ),
        "peak_process_tree_rss_sample_utc": (
            peak_sample.get("utc") if peak_sample is not None else None
        ),
        "peak_process_tree_rss_sample_elapsed_seconds": (
            peak_sample.get("elapsed_seconds") if peak_sample is not None else None
        ),
        "peak_process_tree_rss_sample_bytes": peak_sample_rss,
        "per_pid_peak_resources": per_pid_peak,
        "sample_count": len(samples),
        "stdout": receipt(stage / "stdout.raw"),
        "stderr": receipt(stage / "stderr.raw"),
        "environment": recorded_julia_environment(environment),
    }
    write_new(stage / "final.json", final)
    return final


def locate_julia(requested: str | None) -> str:
    if requested:
        path = Path(requested).resolve()
        if not path.is_file():
            raise FileNotFoundError(f"Julia executable missing: {path}")
        return str(path)
    discovered = shutil.which("julia")
    if discovered is None:
        raise FileNotFoundError("Julia executable is not on PATH")
    return discovered


def parse_output_leaf(value: str) -> Path:
    output = Path(value)
    if not output.is_absolute():
        output = EVIDENCE_ROOT / output
    output = output.resolve()
    try:
        output.relative_to(EVIDENCE_ROOT)
    except ValueError as error:
        raise ValueError("output must remain inside the owned evidence root") from error
    if output.exists():
        raise FileExistsError(f"output leaf already exists: {output}")
    output.mkdir(parents=True)
    return output


def resolve_planned_output(value: str) -> Path:
    output = Path(value)
    if not output.is_absolute():
        output = EVIDENCE_ROOT / output
    output = output.resolve()
    try:
        output.relative_to(EVIDENCE_ROOT)
    except ValueError as error:
        raise ValueError(
            "planned output must remain inside the owned evidence root"
        ) from error
    if output.exists():
        raise FileExistsError(f"planned output already exists: {output}")
    return output


def parse_script_text() -> str:
    return (
        'using SHA; '
        'function ng12_parse_issue(x); '
        'x isa Expr || return nothing; '
        'x.head in (:error,:incomplete) && return x.head; '
        'for child in x.args; issue=ng12_parse_issue(child); '
        'issue===nothing || return issue; end; nothing; end; '
        'function main(args); manifest=args[1]; root=args[2]; count=0; '
        'for line in eachline(manifest); expected,relative=split(line,"\\t";limit=2); '
        'path=joinpath(root,split(relative,\'/\')...); '
        'bytes=read(path); bytes2hex(SHA.sha256(bytes))==expected || '
        'error("parse pin mismatch: "*relative); '
        'parsed=Meta.parseall(String(bytes)); issue=ng12_parse_issue(parsed); '
        'issue===nothing || error("parse tree "*String(issue)*": "*relative); '
        'count+=1; end; println("NG12_PARSE status=pass files=",count); end; '
        'main(ARGS)'
    )


def julia_prefix(julia: str) -> list[str]:
    return [
        julia,
        f"--project={GRIDAP_PROJECT}",
        "--startup-file=no",
        "--history-file=no",
        "--threads=1",
        "--compile=min",
        f"--heap-size-hint={JULIA_HEAP_SIZE_HINT}",
    ]


def planned_stage_commands(output: Path, julia: str) -> tuple[tuple[str, list[str]], ...]:
    prefix = julia_prefix(julia)
    parse_script = parse_script_text()
    artifact = output / "artifacts" / "primary.bin"
    return (
        ("parse_all", [*prefix, "-e", parse_script,
            str(output / "parse_manifest.tsv"), str(ROOT)]),
        ("primary", [*prefix, str(ROOT / OWNED_FILES[3]),
            "primary", str(artifact)]),
        ("fresh_replay", [*prefix, str(ROOT / OWNED_FILES[3]),
            "replay", str(artifact)]),
    )


def planned_expected_runtime_supervisor_argv(output: Path, julia: str) -> list[str]:
    return [
        str(Path(sys.executable).resolve()), "-B",
        str(Path(__file__).resolve()),
        "--output", output.relative_to(EVIDENCE_ROOT).as_posix(),
        "--julia", julia,
    ]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True,
        help="new leaf name or absolute path inside the owned evidence root")
    parser.add_argument("--julia", required=True)
    parser.add_argument("--planned-output",
        help="future actual-run leaf, required with --static-only")
    parser.add_argument("--static-only", action="store_true")
    args = parser.parse_args()

    julia = locate_julia(args.julia)
    output = parse_output_leaf(args.output)
    if args.static_only:
        if args.planned_output is None:
            raise ValueError("--planned-output is required with --static-only")
        planned_output = resolve_planned_output(args.planned_output)
    else:
        if args.planned_output is not None:
            raise ValueError("--planned-output is only valid with --static-only")
        planned_output = output
    static = static_checks()
    snapshot = dependency_receipts()
    manifest = write_parse_manifest(output / "parse_manifest.tsv", snapshot)
    commands = planned_stage_commands(planned_output, julia)
    preflight_path = (ROOT / PRELAUNCH_PREFLIGHT).resolve()
    preflight_command = [
        str(Path(sys.executable).resolve()), "-B", str(preflight_path),
        "--protocol", str(output / "protocol.json"),
        "--static-preflight", str(output / "static_preflight.json"),
        "--baseline-manifest", str(R10_BASELINE_MANIFEST),
        "--baseline-parse-manifest", str(R10_BASELINE_PARSE_MANIFEST),
        "--baseline-protocol", str(R10_BASELINE_PROTOCOL),
    ]
    preflight_relative = Path(PRELAUNCH_PREFLIGHT).as_posix()
    preflight_sha = str(snapshot[preflight_relative]["sha256"])
    protocol = {
        "schema": "native-g1g2-gridap-recorded-protocol-r15-v1",
        "run_revision": "r15_fail_closed_process_tree_monitor_test_only",
        "run_mode": "static_only" if args.static_only else "actual",
        "preparation_output": str(output),
        "created_utc": utc(),
        "ownership": OWNED_FILES,
        "model_record": {
            "requested_model": "gpt-6-luna",
            "requested_reasoning_effort": "max",
            "actual_model": "not_visible_to_worker",
        },
        "r10_baseline": {
            "static_preflight_path": str(R10_BASELINE_MANIFEST),
            "static_preflight_sha256": R10_BASELINE_MANIFEST_SHA256,
            "parse_manifest_path": str(R10_BASELINE_PARSE_MANIFEST),
            "parse_manifest_sha256": R10_BASELINE_PARSE_MANIFEST_SHA256,
            "protocol_path": str(R10_BASELINE_PROTOCOL),
            "protocol_sha256": R10_BASELINE_PROTOCOL_SHA256,
            "pinned_input_count": R10_BASELINE_PIN_COUNT,
        },
        "prior_run_lineage": {
            "files": {
                **{path: digest for path, digest in R10_PRIOR_EVIDENCE_SHA256.items()},
                **{path: digest for path, digest in R11_PRIOR_EVIDENCE_SHA256.items()},
                **{path: digest for path, digest in R12_PRIOR_EVIDENCE_SHA256.items()},
                **{path: digest for path, digest in R13_PRIOR_EVIDENCE_SHA256.items()},
            },
            **PRIOR_RUN_FACTS,
            **R12_PRIOR_FACTS,
            **R13_PRIOR_FACTS,
        },
        "argv_identity_contract": {
            "schema": "native-g1g2-argv-role-contract-v1",
            "runner_invocation_argv": "exact argv of the current r15 launcher process",
            "expected_runtime_supervisor_argv": "canonical actual-run supervisor command",
            "selected_expected_field_by_run_mode": {
                "static_only": "runner_invocation_argv",
                "actual": "expected_runtime_supervisor_argv",
            },
            "actual_mode_runner_invocation_must_equal_runtime_expected": True,
            "failure_diagnostic_fields": (
                "run_mode", "selected_expected_field", "expected_argv",
                "observed_parent_argv", "runner_invocation_argv",
                "expected_runtime_supervisor_argv", "protocol_path",
            ),
        },
        "prelaunch_guard": {
            "path": PRELAUNCH_PREFLIGHT,
            "sha256": preflight_sha,
            "command": preflight_command,
            "required_before_julia": True,
            "implementation": "python_only_no_julia_import_or_launch",
        },
        "julia_dependency_count": len(runtime_julia_paths()),
        "parse_manifest": manifest,
        "parse_gate": {
            "hash_pin_before_parse": True,
            "reject_expr_heads": ("error", "incomplete"),
            "reports_relative_filename": True,
        },
        "stage_order": ("parse_all", "primary", "fresh_replay"),
        "r15_budget_contract": {
            "r11_primary_timeout_seconds": 300.0,
            "wall_seconds_per_stage": 480.0,
            "process_tree_rss_limit_bytes_unchanged": 2_147_483_648,
            "fixtures_and_numerical_thresholds_unchanged": True,
            "rationale": (
                "r10 and r11 both ended at the first primary specialization before "
                "function-body entry; r11 was CPU-active near its 300s wall stop. "
                "This extends only the bounded diagnostic window. The 2 GiB RSS "
                "threshold is checked from 0.2-second process-tree samples; it is "
                "only the sampled stop trigger is enforced; the process may "
                "overshoot between samples. R11 "
                "left only 45,404,160 bytes below the threshold at its sampled peak, "
                "so the longer window is not evidence of memory safety."
            ),
            "diagnostic_only_not_solver_or_numerical_success": True,
        },
        "resource_monitor_policy": RESOURCE_MONITOR_POLICY,
        "r14_parent": R14_PARENT_RECORD,
        "resource_outcome_reporter": {
            "path": RESOURCE_REPORTER,
            "sha256": str(snapshot[Path(RESOURCE_REPORTER).as_posix()]["sha256"]),
            "required_to_interpret_rss_outcomes": True,
            "incomplete_sample_disposition": "resource_monitor_incomplete",
            "numerical_credit_on_incomplete_sample": False,
        },
        "limits_per_julia_stage": {
            "wall_seconds": TIMEOUT_SECONDS,
            "sampled_process_tree_rss_stop_threshold_bytes": PROCESS_TREE_RSS_LIMIT_BYTES,
            "rss_sample_interval_seconds": 0.2,
            "julia_threads": 1,
            "blas_threads": 1,
        },
        "memory_observability": {
            "julia_heap_size_hint": JULIA_HEAP_SIZE_HINT,
            "julia_heap_size_hint_bytes": JULIA_HEAP_SIZE_HINT_BYTES,
            "heap_hint_semantics": (
                "Julia GC pressure hint; it does not constrain process-tree RSS and is not evidence "
                "of an OOM root cause"
            ),
            "sampled_process_tree_rss_stop_threshold_bytes": PROCESS_TREE_RSS_LIMIT_BYTES,
            "rss_sample_interval_seconds": 0.2,
            "rss_enforcement_semantics": "sampled_stop_trigger",
            "sampled_overshoot_possible": True,
            "sampled_threshold_hit_or_overshoot_disposition": "resource_failure",
            "in_process_metrics": {
                "gc_live_bytes": "Julia live plus post-GC allocation bytes",
                "jit_total_bytes": "Julia JIT native code and data bytes",
                "process_maxrss_bytes": "current Julia process peak RSS bytes",
                "gc_time_ns": "current Julia process cumulative GC nanoseconds",
            },
            "recorder_metrics": (
                "per-process pid/name/cmdline/create-time/RSS/CPU plus "
                "whole-process-tree RSS"
            ),
            "forced_gc_at_markers": False,
            "root_cause_established_before_run": False,
        },
        "runtime_environment": {
            "active_project": str(GRIDAP_PROJECT),
            "load_path_entries": JULIA_LOAD_PATH_ENTRIES,
            "julia_load_path": os.pathsep.join(JULIA_LOAD_PATH_ENTRIES),
            "gridap_project_sha256": receipt(GRIDAP_PROJECT / "Project.toml")[
                "sha256"
            ],
            "gridap_manifest_sha256": receipt(GRIDAP_PROJECT / "Manifest.toml")[
                "sha256"
            ],
            "fusion_package_environment": str(ROOT),
            "fusion_project_sha256": receipt(ROOT / "Project.toml")["sha256"],
            "fusion_manifest_sha256": receipt(ROOT / "Manifest.toml")["sha256"],
            "primary_and_fresh_replay_identical": True,
        },
        "numerical_protocol": {
            "cell_counts": ((2, 3, 4), (4, 6, 8), (8, 12, 16)),
            "quadrature_degree": 8,
            "declared_g2_quadrature_role":
                "identity_bound_geometry_metadata_not_execution_rule",
            "residual_abs_tol": 1.0e-9,
            "residual_rel_tol": 1.0e-11,
            "boundary_abs_tol": 1.0e-10,
            "source_integral_abs_tol": 1.0e-10,
            "analytic_identity_abs_tol": 1.0e-12,
            "reaction_balance_abs_tol": 1.0e-9,
            "l2_order_interval": (1.4, 2.6),
            "h1_order_interval": (0.6, 1.4),
            "finest_l2_max": 5.0e-3,
            "finest_h1_seminorm_max": 1.0e-2,
            "error_budget_basis": {
                "derivation":
                    "tensor_q1_interpolation_plus_cea_ellipticity_and_box_poincare",
                "value_representation":
                    "rounded_decimal_approximations_of_fraction_integral_square_roots",
                "physical_lower_metres_rational": ("1/2", "1/3", "1/4"),
                "physical_upper_metres_rational": ("5/2", "10/3", "17/4"),
                "physical_lengths_metres_rational": ("2", "3", "4"),
                "k_base_rational": ("2", "3", "4"),
                "k_slope_rational": ("1/10", "1/20", "1/30"),
                "ellipticity_bounds_rational": ("41/20", "497/120"),
                "finest_interpolation_l2_m32": 0.000714216274,
                "finest_interpolation_h1_m12": 0.006674632049,
                "cea_finest_h1_bound_m12": 0.009487198126,
                "poincare_finest_l2_bound_m32": 0.004639855187,
                "stiffness_integrand_max_coordinate_degree": 2,
                "rhs_integrand_max_coordinate_degree": 3,
                "squared_error_integrand_max_coordinate_degree": 4,
                "gridap_quadrature_degree": 8,
            },
            "expected_invocations": {
                "t0_source_record_factory_calls": 3,
                "v3_source_witness_calls": 1,
                "t1_admission_calls": 1,
                "compiler_calls": 1,
                "provider_calls": 1,
                "mesh_calls": 3,
                "assembly_calls": 6,
                "solver_calls": 3,
                "formal_t2_consumer_receipts": 0,
            },
            "discrete_balance_ledger": {
                "strong_boundary_trace": "diagnostic_only",
                "boundary_reaction_subset":
                    "explicit_constrained_to_unconstrained_q1_dof_partition",
                "interior_reaction_check":
                    "mapped_against_reduced_algebraic_residual",
                "conservation_gate":
                    "assembled_source_plus_boundary_reaction",
            },
        },
        "checkpoint_order": (
            "positive_three_grid_preassert",
            "wrong_sign_preassert",
            "primary_artifact",
            "fresh_replay_preassert",
        ),
        "precompile_diagnostic": {
            "target": "ng12_primary(::String)",
            "request": "precompile(ng12_primary, (String,))",
            "markers": (
                "precompile.before", "precompile.return", "precompile.exception",
                "precompile.after", "primary.function.enter"
            ),
            "position": (
                "precompile outcome markers surround the explicit precompile call; "
                "primary.function.enter is the first ng12_primary body statement"
            ),
            "precompile_semantics": (
                "precompile requests compilation of ng12_primary(::String); it does "
                "not execute the function body or solver. The ordinary call follows "
                "after the explicit precompile attempt."
            ),
            "exception_policy": (
                "precompile.return is emitted only if the explicit request returns; "
                "precompile.exception is emitted if it throws; precompile.after "
                "records either outcome before continuing into ordinary ng12_primary"
            ),
            "replay_process": "no explicit precompile request; fresh replay unchanged",
            "interpretation_limit": (
                "diagnostic request for the primary method specialization; it does "
                "not prove all downstream dynamic dispatch has been compiled"
            ),
            "forced_gc": False,
            "numerical_thresholds_changed": False,
            "fixture_cases_or_mesh_levels_changed": False,
            "diagnostic_is_numerical_success": False,
        },
        "compiler_strategy": {
            "schema": "native-g1g2-compiler-resource-diagnostic-v2",
            "claim_scope": "compiler_resource_diagnostic",
            "mode": "--compile=min",
            "argv_delta_from_r13": "add exactly one --compile=min to each Julia stage argv",
            "precompile_marker_preserved": True,
            "numerical_fixtures_or_thresholds_changed": False,
            "sampled_rss_stop_threshold_bytes_unchanged": PROCESS_TREE_RSS_LIMIT_BYTES,
            "rss_sample_interval_seconds": 0.2,
            "rss_enforcement_semantics": "sampled_stop_trigger",
            "sampled_overshoot_possible": True,
            "sampled_threshold_hit_or_overshoot_disposition": "resource_failure",
            "diagnostic_is_numerical_success": False,
            "numerical_status_predeclared": "not_established",
            "physical_status_predeclared": "unknown",
        },
        "execution_plan": {
            "runtime_executed": not args.static_only,
            "julia_executable": {"path": julia, **receipt(Path(julia))},
            "supervisor_cwd": str(ROOT),
            "runner_invocation_argv": [
                str(Path(sys.executable).resolve()), "-B",
                str(Path(__file__).resolve()), *sys.argv[1:],
            ],
            "expected_runtime_supervisor_argv": planned_expected_runtime_supervisor_argv(planned_output, julia),
            "planned_actual_output": str(planned_output),
            "stage_commands": [
                {"stage": name, "argv": command}
                for name, command in commands
            ],
        },
        "formal_t2_consumer_receipts_assigned": 0,
        "acceptance_boundary": {
            "software": "pending_actual_run",
            "numerical": "pending_actual_run",
            "scientific": "not_accepted",
            "physical": "unknown",
            "resolution": "terminal_deferred",
        },
    }
    write_new(output / "protocol.json", protocol)
    write_new(output / "static_preflight.json", {
        "schema": "native-g1g2-static-preflight-v1",
        "created_utc": utc(),
        "r10_baseline": {
            "static_preflight_path": str(R10_BASELINE_MANIFEST),
            "static_preflight_sha256": R10_BASELINE_MANIFEST_SHA256,
            "parse_manifest_path": str(R10_BASELINE_PARSE_MANIFEST),
            "parse_manifest_sha256": R10_BASELINE_PARSE_MANIFEST_SHA256,
            "protocol_path": str(R10_BASELINE_PROTOCOL),
            "protocol_sha256": R10_BASELINE_PROTOCOL_SHA256,
            "pinned_input_count": R10_BASELINE_PIN_COUNT,
        },
        "static": static,
        "dependencies": snapshot,
    })
    preflight_run = subprocess.run(
        preflight_command, cwd=ROOT, capture_output=True, check=False
    )
    (output / "prelaunch.stdout.raw").write_bytes(preflight_run.stdout)
    (output / "prelaunch.stderr.raw").write_bytes(preflight_run.stderr)
    (output / "prelaunch.exit.txt").write_text(
        f"{preflight_run.returncode}\n", encoding="ascii"
    )
    if preflight_run.returncode != 0:
        raise RuntimeError(
            "r15 Python prelaunch source/argv verifier failed; Julia was not started"
        )
    prelaunch_receipt = json.loads(preflight_run.stdout.decode("utf-8"))
    if args.static_only:
        write_new(output / "summary.json", {
            "schema": "native-g1g2-run-summary-v1",
            "created_utc": utc(),
            "mode": "static_only",
            "runtime_executed": False,
            "status": "static_ready",
            "scientific_status": "not_accepted",
            "physical_status": "unknown",
            "resolution": "terminal_deferred",
            "prelaunch": prelaunch_receipt,
        })
        print(json.dumps({
            "status": "static_ready",
            "output": str(output),
            "julia_dependency_count": len(runtime_julia_paths()),
            "runtime_executed": False,
            "prelaunch_status": prelaunch_receipt["status"],
        }, sort_keys=True))
        return 0

    environment = os.environ.copy()
    environment.update({
        "JULIA_LOAD_PATH": os.pathsep.join(JULIA_LOAD_PATH_ENTRIES),
        "JULIA_NUM_THREADS": "1",
        "OPENBLAS_NUM_THREADS": "1",
        "MKL_NUM_THREADS": "1",
        "OMP_NUM_THREADS": "1",
        "JULIA_PKG_OFFLINE": "true",
        "JULIA_PKG_PRECOMPILE_AUTO": "0",
    })
    artifact = output / "artifacts" / "primary.bin"
    artifact.parent.mkdir()
    stages: list[dict[str, object]] = []
    failure: dict[str, object] | None = None
    for index, (name, command) in enumerate(commands, start=1):
        artifact_receipts: dict[str, dict[str, object]] = {}
        for label, path in (
            ("primary", artifact),
            ("primary_preassert", Path(str(artifact) + ".preassert.bin")),
            ("wrong_sign_preassert",
                Path(str(artifact) + ".wrong-sign-preassert.bin")),
            ("replay_preassert", Path(str(artifact) + ".replay-preassert.bin")),
        ):
            if path.is_file():
                artifact_receipts[label] = receipt(path)
        final = run_step(output, index, name, command, snapshot,
            environment, artifact_receipts)
        stages.append(final)
        stage_stdout = output / f"{index:02d}_{name}" / "stdout.raw"
        text = stage_stdout.read_text(encoding="utf-8", errors="replace")
        required_token = "NG12_PARSE status=pass" if name == "parse_all" else (
            f"NG12_RESULT mode={'primary' if name == 'primary' else 'replay'} status=pass"
        )
        if (final["exit_code"] != 0 or
                final["stop_reason"] != "natural_exit" or
                required_token not in text):
            failure = {"stage": name, "required_token": required_token,
                "final": final}
            break
        if name == "primary" and not artifact.is_file():
            failure = {"stage": name, "reason": "primary_artifact_missing"}
            break
        if name == "primary" and not Path(
                str(artifact) + ".preassert.bin").is_file():
            failure = {"stage": name,
                "reason": "primary_preassert_checkpoint_missing"}
            break
        if name == "primary" and not Path(
                str(artifact) + ".wrong-sign-preassert.bin").is_file():
            failure = {"stage": name,
                "reason": "wrong_sign_preassert_checkpoint_missing"}
            break
        if name == "fresh_replay" and not Path(
                str(artifact) + ".replay-preassert.bin").is_file():
            failure = {"stage": name,
                "reason": "replay_preassert_checkpoint_missing"}
            break

    after = dependency_receipts()
    unchanged = snapshot == after
    if not unchanged and failure is None:
        failure = {"stage": "postflight", "reason": "dependency_bytes_changed"}
    residual = heavy_processes()
    if residual and failure is None:
        failure = {"stage": "postflight", "reason": "residual_heavy_process",
            "processes": residual}
    complete = failure is None and len(stages) == 3
    resource_monitor_complete = (
        bool(stages) and all(stage.get("resource_monitor_complete") is True for stage in stages)
    )
    monitor_incomplete = any(
        stage.get("stop_reason") == "resource_monitor_incomplete" for stage in stages
    )
    summary_status = (
        "resource_monitor_incomplete" if monitor_incomplete else
        "pass" if complete else "fail"
    )
    final_artifacts: dict[str, dict[str, object]] = {}
    for label, path in (
        ("primary", artifact),
        ("primary_preassert", Path(str(artifact) + ".preassert.bin")),
        ("wrong_sign_preassert",
            Path(str(artifact) + ".wrong-sign-preassert.bin")),
        ("replay_preassert", Path(str(artifact) + ".replay-preassert.bin")),
    ):
        if path.is_file():
            final_artifacts[label] = receipt(path)
    summary = {
        "schema": "native-g1g2-run-summary-v1",
        "created_utc": utc(),
        "runtime_executed": True,
        "status": summary_status,
        "stages": stages,
        "failure": failure,
        "resource_monitor_complete": resource_monitor_complete,
        "resource_monitor_status": (
            "complete" if resource_monitor_complete else "incomplete"
        ),
        "dependencies_unchanged": unchanged,
        "dependencies_before": snapshot,
        "dependencies_after": after,
        "artifacts": final_artifacts,
        "software_status": "pass" if complete else "not_established",
        "numerical_status": "pass" if complete else "not_established",
        "scientific_status": "not_accepted",
        "physical_status": "unknown",
        "resolution": "terminal_deferred",
        "formal_t2_consumer_receipts_assigned": 0,
    }
    write_new(output / "summary.json", summary)
    print(json.dumps({
        "status": summary["status"],
        "output": str(output),
        "runtime_executed": True,
        "completed_stages": [stage["stage"] for stage in stages],
        "failure": failure,
    }, sort_keys=True))
    return 0 if complete else 1


if __name__ == "__main__":
    raise SystemExit(main())
