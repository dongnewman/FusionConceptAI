"""Narrow, read-only static gate for the frozen UP2 replay-only V21 candidate.

This test validates pinned identities, retained failure evidence, and the
successive pre-output guard repairs. It does not launch Julia or grant runtime authority.
"""

from __future__ import annotations

import copy
import hashlib
import importlib.util
import json
import re
import tempfile
import unittest
import zipfile
from pathlib import Path, PurePosixPath


ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
V21_CANONICAL_PREIMAGE = ROOT / "runs/e/up2_v8_historical_inventory_resolver_20260928_r3/integration_preimages/run_replay_staged_v21.py"
V21_CANONICAL_PREIMAGE_BYTES = 307849
V21_CANONICAL_PREIMAGE_SHA256 = "8fdbf6b38e53ac3ab4ea65310587587707a643f16e76d2623b23601239f05579"
R4_HISTORICAL_RUNNER_PREIMAGE = ROOT / "runs/e/up2_v10_exact_declaration_fix_20260927_r1/run_replay_staged_v21_r4.py"
R4_HISTORICAL_RUNNER_PREIMAGE_BYTES = 101059
R4_HISTORICAL_RUNNER_PREIMAGE_SHA256 = "fcbbcca1f34ac1f5229d1e8ef3874c844dcda3c60ed79b087cb5c4f205462e75"
R4_HISTORICAL_TEST_PREIMAGE = ROOT / "runs/e/up2_v8_historical_inventory_resolver_20260928_r4/root_integration_r1/preimage/test_independent_static_v21.py"
R4_HISTORICAL_TEST_PREIMAGE_BYTES = 177578
R4_HISTORICAL_TEST_PREIMAGE_SHA256 = "77d4788e4471f8d13f38c0c36bb7a510db3145d5f4ccab4146a1aa94ff31783b"
R6_HISTORICAL_TEST_PREIMAGE = ROOT / "runs/e/up2_r7_static_successor_20260929_r1/r6_preimage/test_independent_static_v21.py"
R6_HISTORICAL_TEST_PREIMAGE_BYTES = 191068
R6_HISTORICAL_TEST_PREIMAGE_SHA256 = "e77acfb8432eae59469d028c37508f1cdf1284782bc38f37bd68ccaf2044d96e"
R6_HISTORICAL_WRAPPER_PREIMAGE = ROOT / "runs/e/up2_r7_static_successor_20260929_r1/r6_preimage/run_replay_staged_v21_r4.py"
PROTOCOL = HERE / "replay_protocol_v21.json"
RUNNER = HERE / "run_replay_staged_v21.py"
JULIA_ENTRY = HERE / "replay_staged_v21.jl"
PROTOCOL_SHA256 = "113fa02eb54d5b2aa870f2b9c07024def18427fa353c485f30568e50125c4b2e"
ARCHIVE_SHA256 = "c84743bc55dc749bbcc43e936c278027ad9bce9b437c09e176be587f75ff2bb7"
V20_PROTOCOL_SHA256 = "26690948566c5191994e2d2ae3cbf94e7d9f481f8adf7e88962b128792d61dc2"
CASE_STATE_HASH = "b36d2109eba29fdced93e09f2730fb785860f203d4cf9d39f2dedf43e94fb5d7"
FINAL_VECTOR_HASH = "464534cafdcecbbf215c656843349faa88a4ea3120e58d4cf79345a71bd89662"
R2_BUILDER = HERE / "build_protocol_v21_r2.py"
R2_RUNNER = HERE / "run_replay_staged_v21_r2.py"
R2_OVERLAY_SPEC = HERE / "controller_overlay_spec_v21_r2.json"
R2_JULIA_ENTRY = HERE / "replay_staged_v21_r2.jl"
R2_PROTOCOL = HERE / "replay_protocol_v21_r2.json"
R2_PROTOCOL_SHA256 = "e6a6917bc720b7f61a48707aea60d5377b67c3c61c30c817eeacfb1dfa9b0659"
R2_TEST_SHA256 = "8bb1937ce0def915a94e2f0c45f95b3980a34b59ad5f5980af3d3baad7b43f59"
R2_TEST_BYTES = 19706
R2_PROTOCOL_BYTES = 973773
R2_SNAPSHOT_DIR = ROOT / "runs/UP2ClosureReplayOnlyV21/runtime_launcher_r21_r2_20260926_r1/independent_static_r2_source_snapshot_r1"
R2_TEST_SNAPSHOT = R2_SNAPSHOT_DIR / "test_independent_static_v21_r2_e6_executed.py"
R2_PROTOCOL_SNAPSHOT = R2_SNAPSHOT_DIR / "replay_protocol_v21_r2_e6_frozen.json"
R2_SNAPSHOT_MANIFEST = R2_SNAPSHOT_DIR / "added_sources_manifest.json"
R2_SNAPSHOT_MANIFEST_SHA256 = "4c1b395e316c716287f0fb0f1f96c256aad6efd524eef01edc6447fe015fea6e"
R2_TEST_RECEIPT = ROOT / "runs/UP2ClosureReplayOnlyV21/input_closure_r2_tests_20260926_r2/receipt_manifest.json"
R2_TEST_RECEIPT_SHA256 = "1894ad3ec64eb0bf3ca0fa935a3b8a32d2a4037f35465d3aac7aed2a9aea3ddd"
R2_FILE_SHA256 = {
    "run_replay_staged_v21_r2.py": "666c255aa2904eb55e90083b1ab59c32aed4fe4b5d005ef45afcc118905a3457",
    "controller_overlay_spec_v21_r2.json": "369202ad82fa5669a5a1749117214f36bee9f01f953109ec53d6d9da39d3a345",
    "replay_staged_v21_r2.jl": "cb70e7e508510a251379509b8cd07a5d7afd580226409c06f4cab22618ab398e",
}
R2_OUTPUT_ROOT = Path(r"D:\006-Programing\LMC\FusionConceptAI_cleanup_20260926\up2_replay_v21_r2")
R2_MIRROR = R2_OUTPUT_ROOT / "archive_mirror"
R2_OUTPUT_LEAF = R2_OUTPUT_ROOT / "runtime_replay_r21_r2"

R3_BUILDER = HERE / "build_protocol_v21_r3.py"
R3_RUNNER = HERE / "run_replay_staged_v21_r3.py"
R3_OVERLAY_SPEC = HERE / "controller_overlay_spec_v21_r3.json"
R3_JULIA_ENTRY = HERE / "replay_staged_v21_r3.jl"
R3_PROTOCOL = HERE / "replay_protocol_v21_r3.json"
R3_PROTOCOL_SHA256 = "1688c51f96cf87ebaec3df75409954f21ac11ca22ecc589ae72634f69c402119"
R3_FILE_SHA256 = {
    "build_protocol_v21_r3.py": "f00fc8b32176dfd8af6b086a15a31e02cbe734696986d918d38931c1dab20905",
    "run_replay_staged_v21_r3.py": "eab064af3761ebce10e7d44d096f98640fbb1b28d4b3ddf8f3f2d06b1fbf39ee",
    "controller_overlay_spec_v21_r3.json": "58b951ad8a7bb660e6ce297fafc31090fd72bc2bc6e644c826326de308b833d5",
    "replay_staged_v21_r3.jl": "01024630a438ac9502e0a2b0b6a20ecdf3e1da0263f58b7d996fd6baf77d5dcc",
}
R3_OUTPUT_ROOT = Path(r"D:\006-Programing\LMC\FusionConceptAI_cleanup_20260926\up2_replay_v21_r3")
R3_MIRROR = R3_OUTPUT_ROOT / "archive_mirror"
R3_OUTPUT_LEAF = R3_OUTPUT_ROOT / "runtime_replay_r21_r3"
R3_TEST_SNAPSHOT = ROOT / "runs/UP2ClosureReplayOnlyV21/runtime_launcher_r21_r3_20260926_r1/independent_source_snapshot_pre_v20check_r1/test_independent_static_v21.actual_run.py"
R3_TEST_SNAPSHOT_SHA256 = "ec8e611fa730d90961a8a565b9433842ae81a6dc120d311881f8b0684b67b883"
R3_TEST_SNAPSHOT_BYTES = 38506
R3_TEST_SNAPSHOT_REL = "runs/UP2ClosureReplayOnlyV21/runtime_launcher_r21_r3_20260926_r1/independent_source_snapshot_pre_v20check_r1/test_independent_static_v21.actual_run.py"
R3_SOURCE_SNAPSHOT_MANIFEST = R3_TEST_SNAPSHOT.parent / "source_snapshot_manifest.json"
R3_SOURCE_SNAPSHOT_MANIFEST_SHA256 = "3238055aa7608a5ca0619ec82c3cc78e8208e490db3600e875373c56b5e3f30e"
R3_SOURCE_SNAPSHOT_MANIFEST_BYTES = 2914
R3_SOURCE_SNAPSHOT_MANIFEST_REL = "runs/UP2ClosureReplayOnlyV21/runtime_launcher_r21_r3_20260926_r1/independent_source_snapshot_pre_v20check_r1/source_snapshot_manifest.json"
R3_ACTUAL_EXIT_RECEIPT = ROOT / "runs/UP2ClosureReplayOnlyV21/runtime_launcher_r21_r3_20260926_r1/external_exit_receipt.json"
R3_ACTUAL_EXIT_RECEIPT_SHA256 = "ccacd39c6e060f145879b8bfd147f4cfa9569b6c4f19477f7dab8cc1de8dfcdb"
R3_ACTUAL_EXIT_RECEIPT_REL = "runs/UP2ClosureReplayOnlyV21/runtime_launcher_r21_r3_20260926_r1/external_exit_receipt.json"
R3_RAW_MANIFEST = ROOT / "runs/UP2ClosureReplayOnlyV21/runtime_launcher_r21_r3_20260926_r1/manifest.json"
R3_RAW_MANIFEST_SHA256 = "dd6ed92fc004ee358166c06c435a1bc2f3ff1359b70870b040c20e954c11888b"
R3_RAW_MANIFEST_BYTES = 2992
R3_RAW_MANIFEST_REL = "runs/UP2ClosureReplayOnlyV21/runtime_launcher_r21_r3_20260926_r1/manifest.json"
R3_STATIC_EXIT_RECEIPT = ROOT / "runs/UP2ClosureReplayOnlyV21/runtime_launcher_r21_r3_static_qa_20260926_r3/external_exit_receipt.json"
R3_STATIC_EXIT_RECEIPT_SHA256 = "788ad2d467190d3d866e9ab4be30b74382cd7f69c653cb63c74b8c865f93d97c"
R3_STATIC_EXIT_RECEIPT_BYTES = 863
R3_STATIC_EXIT_RECEIPT_REL = "runs/UP2ClosureReplayOnlyV21/runtime_launcher_r21_r3_static_qa_20260926_r3/external_exit_receipt.json"
R3_MONITOR_SUMMARY = (
    "Only an exact pinned Popen leader confirmed exited after a complete RSS sample may enter the V21 "
    "NoSuchProcess race branch; every previously observed descendant and current PPID table is still audited."
)
R3_PROCESS_TREE_NEGATIVES = [
    "inject descendant enumeration AccessDenied and require an incomplete sample with no RSS total returned",
    "inject descendant memory_info AccessDenied after a root sample and require the partial bytes be diagnostic only",
    "inject incomplete monitor status in run_stage and require resource_interruption/124 with consumer blocked",
    "inject wait_procs exceptions during terminate and kill waits and require candidates retained and termination_confirmed false",
    "inject missing or duplicate root identities and require the complete RSS sample be rejected",
    "inject root/descendant PID reuse and require fail-closed without signaling the recycled process",
    "make the leader exit with a live descendant and require interruption/124 with consumer blocked",
    "inject descendant lookup AccessDenied and terminate/kill errors; unknown residuals must remain unconfirmed",
    "confirm Popen exit after a complete root sample and require no post-exit RSS lookup plus a complete identity and PPID descendant audit",
    "make Popen exit before any complete root sample and require process-tree observation failure/124",
    "inject an unobserved child in the final PPID snapshot and require interruption/124, identity pinning, and no consumer launch",
    "inject PPID snapshot failure or a root PID still present/reused after confirmed exit and require fail-closed status",
    "inject unconfirmed bounded cleanup with zero measured overrun and require cleanup_unconfirmed/124 rather than aggregate_cleanup_overrun",
    "accept and ignore only the exact Windows PID 0/PPID 0 sentinel; reject PID 0 with nonzero PPID and all other invalid process-table identities",
]
R4_BUILDER = HERE / "build_protocol_v21_r4.py"
R4_RUNNER = HERE / "run_replay_staged_v21_r4.py"
R4_OVERLAY_SPEC = HERE / "controller_overlay_spec_v21_r4.json"
R4_JULIA_ENTRY = HERE / "replay_staged_v21_r4.jl"
R4_PROTOCOL = HERE / "replay_protocol_v21_r4.json"
R4_PROTOCOL_SHA256 = "d4b221074907f5e79d063012f48d97c41a73acaee8e6c9260dd7cb4dd5846a0f"
R4_ABSENCE_HELPER = HERE / "historical_absent_output_slots_v21_r4.py"
R4_ABSENCE_HELPER_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/historical_absent_output_slots_v21_r4.py"
R4_ABSENCE_HELPER_SHA256 = "557df466f0b78364c2c9b75dd590ef3e9c64f0b2d5d384431f249f0ad0daff1e"
R4_ABSOLUTE_ARCHIVE_ROUTE_KEY = "r4_checked_path_absolute_archive_file_route"
R4_ABSOLUTE_ARCHIVE_ROUTE_SCHEMA = "mms-v21-r4-exact-absolute-archive-file-route-v1"
R4_FILE_SHA256 = {
    "run_replay_staged_v21_r4.py": "fcbbcca1f34ac1f5229d1e8ef3874c844dcda3c60ed79b087cb5c4f205462e75",
    "controller_overlay_spec_v21_r4.json": "e057248e6acff70594d71d023d362b3c79a92535d2b85f923377ee429b0a5e18",
    "replay_staged_v21_r4.jl": "84c2b35f9bba09cb3f6fe8adefb6b46f45e3118d6aeae164bbc941c076955534",
    "historical_absent_output_slots_v21_r4.py": R4_ABSENCE_HELPER_SHA256,
}
R4_V9_RAW_SIDECAR_FILES = (
    ("docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/replay_only_continuation_r9/"
     "static_contract_check_v9_r1/exit_code.txt", 2,
     "9a271f2a916b0b6ee6cecb2426f0b3206ef074578be55d9bc94f6f3fe3ab86aa"),
    ("docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/replay_only_continuation_r9/"
     "static_contract_check_v9_r1/stderr.raw", 1955,
     "d23970e5b2b2dbf3774419757dd46382090fd1dcf3f4c808566202a210c62acd"),
    ("docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/replay_only_continuation_r9/"
     "static_contract_check_v9_r1/stdout.raw", 0,
     "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"),
)
R4_V9_SIDECAR_KEY = "r4_v9_static_raw_output_sidecar"
R4_V9_SIDECAR_ROUTE_KEY = "r4_checked_path_v9_raw_sidecar_route"
R4_V9_SIDECAR_SCHEMA = "mms-v21-r4-v9-static-raw-output-sidecar-v1"
R4_V6_SCOPEFIX_KEY = "r4_v6_postrun_scopefix_closure_addendum"
R4_V6_SCOPEFIX_SCHEMA = "mms-v21-r4-v6-postrun-scopefix-transitive-closure-addendum-v1"
R4_V6_SCOPEFIX_ROUTE_KEY = "r4_checked_path_v6_scopefix_addendum_route"
R4_V6_SCOPEFIX_ROUTE_SCHEMA = "mms-v21-r4-v6-postrun-scopefix-addendum-route-v1"
R4_V6_SCOPEFIX_MATERIALIZATION_KEY = "r4_v6_postrun_scopefix_addendum_materialization"
R4_V6_SCOPEFIX_MATERIALIZATION_SCHEMA = "mms-v21-r4-v6-postrun-scopefix-addendum-materialization-v1"
R4_V10_PATH_BINDING_KEY = "r4_v10_recorded_path_binding_addendum"
R4_V10_PATH_BINDING_SCHEMA = "mms-v21-r4-v10-recorded-path-binding-addendum-v1"
R4_V10_PATH_BINDING_BASE_SHA256 = "aaf246b0c55413794293eefab1d7a133a79952a2e55388074775ef401a8757eb"
R4_V10_PATH_BINDING_FINAL_SHA256 = "4beb273fd286d00cae5b0d5de64b51f5322f54e197cebe841deeab53d0ed56a9"
R4_V10_PATH_BINDING_REPLACEMENTS = [
    {
        "old_line": "                str(path.resolve()), path.stat().st_size, digest(path)):",
        "new_line": '                str(_r4_v10_original_path_binding(root, runtime[f"{key}_path"], path, "file")), path.stat().st_size, digest(path)):',
    },
    {
        "old_line": '        str((runtime_root / "producer_process/numerical").resolve()),',
        "new_line": '        str(_r4_v10_original_path_binding(root, runtime["root"], runtime_root, "directory") / "producer_process" / "numerical"),',
    },
]
R4_V10_RUNTIME_ROOT = (
    "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/"
    "replay_only_continuation_r10/runtime_replay_r10"
)
R4_V10_STREAM_FILES = (
    (R4_V10_RUNTIME_ROOT + "/producer_process/stdout.raw", 53,
     "cd7c4c8671a183f7dd138c1e013df3902c129ab34a7e7e314e8682ab2723159b"),
    (R4_V10_RUNTIME_ROOT + "/producer_process/stderr.raw", 115,
     "64f69179d9bf4556fd9690a9e0b1a58b5fbf2416d6fbedd3fef5633379c7f6a0"),
)
R4_V10_PREFIX_EXPECTED = {
    "archive_member_count": 17,
    "archive_member_bytes": 261867,
    "archive_member_manifest_sha256": "5f0ef35b77e5491e8e1dc28c4917823e9ea03bdab6100d458bd6206d7bb78735",
    "mapped_descendant_count": 17,
    "mapped_descendant_bytes": 261867,
    "mapped_descendant_manifest_sha256": "3e78e6e60af360af53c9790889284566290eeed7cd55667fb9acbf4683ee45cb",
    "workspace_file_count": 0,
    "workspace_bytes": 0,
    "workspace_manifest_sha256": "37517e5f3dc66819f61f5a7bb8ace1921282415f10551d2defa5c3eb0985b570",
    "workspace_state": "absent",
}
R4_V10_ROOT_OBSERVATION_ADDENDUM_KEY = "r4_v10_root_observation_input_addendum"
R4_V10_ROOT_OBSERVATION_ADDENDUM_SCHEMA = "mms-v21-r4-v10-root-observation-input-addendum-v1"
R4_V10_ROOT_OBSERVATION_ROUTE_KEY = "r4_checked_path_v10_root_observation_input_route"
R4_V10_ROOT_OBSERVATION_ROUTE_SCHEMA = "mms-v21-r4-v10-root-observation-input-route-v1"
R4_V10_ROOT_OBSERVATION_MATERIALIZATION_KEY = "r4_v10_root_observation_input_materialization"
R4_V10_ROOT_OBSERVATION_MATERIALIZATION_SCHEMA = "mms-v21-r4-v10-root-observation-input-materialization-v1"
V10_REVIEW_MANIFEST_REL = (
    "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/"
    "independent_replay_v10_postrun_review_20260924/review_manifest.json"
)
V10_REVIEW_MANIFEST_BYTES = 4013
V10_REVIEW_MANIFEST_SHA256 = "7093aa4b07bf545c4b85a9436564b46bbc4bc50d15881eaf93e44ac29263cce5"
V10_ROOT_OBSERVATION_PATH = (
    "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/"
    "root_replay_v10_grant_20260924/observation.json"
)
V10_ROOT_OBSERVATION_BYTES = 8230
V10_ROOT_OBSERVATION_SHA256 = "864b2fc5eacfcb8a44114fa5023f3125c9ff2fb08dce3b44b970dfe85eb0d5f9"
R4_V10_ROOT_OBSERVATION_FILES = (
    (V10_ROOT_OBSERVATION_PATH, 8230,
     "864b2fc5eacfcb8a44114fa5023f3125c9ff2fb08dce3b44b970dfe85eb0d5f9",
     V10_REVIEW_MANIFEST_REL, 4013,
     "7093aa4b07bf545c4b85a9436564b46bbc4bc50d15881eaf93e44ac29263cce5",
     "/root_observation"),
    ("docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/root_replay_v10_grant_20260924/grant.json",
     3065, "ac07074745769abee598904e2c87f1ac62fbb649ff1b54787cee898f7aa3a5b6",
     V10_ROOT_OBSERVATION_PATH, 8230,
     "864b2fc5eacfcb8a44114fa5023f3125c9ff2fb08dce3b44b970dfe85eb0d5f9", "/grant"),
    ("docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/root_replay_v10_grant_20260924/controller.exit.txt",
     2, "8722616204217eddb39e7df969e0698aed8e599ba62ed2de1ce49b03ade0fede",
     V10_ROOT_OBSERVATION_PATH, 8230,
     "864b2fc5eacfcb8a44114fa5023f3125c9ff2fb08dce3b44b970dfe85eb0d5f9",
     "/controller_sidecars/controller.exit.txt"),
    ("docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/root_replay_v10_grant_20260924/controller.stderr.raw",
     0, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
     V10_ROOT_OBSERVATION_PATH, 8230,
     "864b2fc5eacfcb8a44114fa5023f3125c9ff2fb08dce3b44b970dfe85eb0d5f9",
     "/controller_sidecars/controller.stderr.raw"),
    ("docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/root_replay_v10_grant_20260924/controller.stdout.raw",
     320, "4029ec84fb491bdcd440d88c1e7e6894fdbc2e1ae6adca30b130d404c568cadc",
     V10_ROOT_OBSERVATION_PATH, 8230,
     "864b2fc5eacfcb8a44114fa5023f3125c9ff2fb08dce3b44b970dfe85eb0d5f9",
     "/controller_sidecars/controller.stdout.raw"),
)
R4_V6_SCOPEFIX_MANIFEST = (
    "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/"
    "replay_only_v6_postrun_review_scopefix_20260923/SHA256SUMS.txt"
)
R4_V6_SCOPEFIX_MANIFEST_BYTES = 6618
R4_V6_SCOPEFIX_MANIFEST_SHA256 = "d4c677725763cb374bf663ca736e59262781b37d9289136af974d15c27ce9873"
R4_V6_SCOPEFIX_FILES = (
    ("docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/"
     "replay_only_v6_postrun_independent_review_20260923/postrun_review.md", 7495,
     "34a967955a1c06be8527a3c929f3bb4a41452ec92c44e4ed44ab798f31809839"),
    ("docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/"
     "replay_only_v6_postrun_independent_review_20260923/commands_and_exits.txt", 1337,
     "c13070f88f652037521edfbe4ee223585e9ef88c3dd7543d480615c6d7c33303"),
    ("docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/"
     "replay_only_v6_postrun_independent_review_20260923/scope_violation.md", 915,
     "b0da5b1ee21d82d97059dcf6a90e61dd2c5cbac100f089d08c1a1ee85f0c7cbc"),
    ("docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/"
     "replay_only_v6_postrun_independent_review_20260923/SHA256SUMS.txt", 4986,
     "03cc15ab00f543e4a74c7fe5d8fcc79a9e0625b9a60558a914aaeb4039a4674b"),
    ("docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/"
     "replay_only_continuation_r6/static_contract_check_v6_r1/receipt.json", 819,
     "3d48bad224ad2fab000b68bfcd388b558a95b4e9eff7158b71dcd72d84a998f9"),
)
R4_V6_PROTOCOL = {
    "path": "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/"
            "replay_only_continuation_r6/replay_protocol_v6.json",
    "bytes": 73040,
    "sha256": "9d28384297942eb3cec2fd788e88ac17fb1868e25b55fc7dbe85d3c97d79fca9",
}
R4_OUTPUT_ROOT = Path(r"D:\006-Programing\LMC\FusionConceptAI_cleanup_20260926\up2_replay_v21_r4_scopefix_addendum_r1")
R4_MIRROR = R4_OUTPUT_ROOT / "archive_mirror"
R4_OUTPUT_LEAF = R4_OUTPUT_ROOT / "runtime_replay_r21_r4_v10inputs_20260927_01"
R5_PROTOCOL = HERE / "replay_protocol_v21_r5.json"
R5_OUTPUT_ROOT = Path(r"D:\006-Programing\LMC\FusionConceptAI_cleanup_20260926\up2_replay_v21_r5")
R5_MIRROR = R5_OUTPUT_ROOT / "archive_mirror"
R5_OUTPUT_LEAF = R5_OUTPUT_ROOT / "runtime_replay_r21_r5"
R6_PROTOCOL = HERE / "replay_protocol_v21_r6.json"
R6_PROTOCOL_SHA256 = "8ae9b6d15292d0dff2dc352c38c12ce564dbd6cc5567b4caccd3bc19f7d79fb3"
R6_RUNNER = HERE / "run_replay_staged_v21_r4.py"
R7_PROTOCOL = HERE / "replay_protocol_v21_r7.json"
R7_RUNNER = R6_RUNNER
R6_BUILDER = HERE / "build_protocol_v21_r6.py"
R6_SPEC = HERE / "controller_overlay_spec_v21_r6.json"
R6_MUTABLE_FROM_R5 = frozenset({
    "test/RuntimeV4/UP2ClosureReplayOnlyV21/run_replay_staged_v21_r4.py",
    "test/RuntimeV4/UP2ClosureReplayOnlyV21/test_independent_static_v21.py",
})
R6_OUTPUT_ROOT = Path(r"D:\006-Programing\LMC\FusionConceptAI_cleanup_20260926\up2_replay_v21_r6")
R6_MIRROR = R6_OUTPUT_ROOT / "archive_mirror"
R6_OUTPUT_LEAF = R6_OUTPUT_ROOT / "runtime_replay_r21_r6"
R2_MIRROR_BASELINE: dict[str, object] | None = None
R3_MIRROR_BASELINE: dict[str, object] | None = None


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def canonical_json_bytes(value: object) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def archived_json(archive: zipfile.ZipFile, path: str) -> dict:
    value = json.loads(archive.read(path))
    if not isinstance(value, dict):
        raise AssertionError(f"expected JSON object in archive member {path}")
    return value


class TestIndependentStaticV21(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.protocol_bytes = PROTOCOL.read_bytes()
        cls.protocol = json.loads(cls.protocol_bytes)
        cls.runner = RUNNER.read_text(encoding="utf-8")
        cls.julia = JULIA_ENTRY.read_text(encoding="utf-8")

    def test_frozen_protocol_and_v21_source_inventory(self) -> None:
        self.assertEqual(sha256(self.protocol_bytes), PROTOCOL_SHA256)
        p = self.protocol
        self.assertEqual((p["schema"], p["version"], p["classification"]),
                         ("mms-replay-only-continuation-protocol-v21", 21,
                          "test_only_continuation"))
        self.assertIs(p["runtime_grant"], False)
        self.assertEqual(p["static_test_contract"]["status"],
                         "pending_independent_test_assignment")
        rows = p["owned_source_files"]
        self.assertEqual(len(rows), 3)
        self.assertEqual(p["owned_source_files_by_path"],
                         {row["path"]: row["sha256"] for row in rows})
        for row in rows:
            path = (V21_CANONICAL_PREIMAGE if row["path"] ==
                    "test/RuntimeV4/UP2ClosureReplayOnlyV21/run_replay_staged_v21.py"
                    else ROOT.joinpath(*PurePosixPath(row["path"]).parts))
            self.assertEqual(path.stat().st_size, row["bytes"], row["path"])
            self.assertEqual(sha256_file(path), row["sha256"], row["path"])
        self.assertEqual((V21_CANONICAL_PREIMAGE.stat().st_size,
                          sha256_file(V21_CANONICAL_PREIMAGE)),
                         (V21_CANONICAL_PREIMAGE_BYTES, V21_CANONICAL_PREIMAGE_SHA256))

    def test_v20_archive_closes_the_frozen_failure_and_review(self) -> None:
        archive_ref = self.protocol["archived_input_source"]
        archive_path = Path(archive_ref["archive_path"])
        self.assertEqual(sha256_file(archive_path), ARCHIVE_SHA256)
        self.assertEqual(archive_ref["archive_sha256"], ARCHIVE_SHA256)
        parent = self.protocol["parent_v20_actual_failure"]

        with zipfile.ZipFile(archive_path, "r") as archive:
            names = {info.filename for info in archive.infolist() if not info.is_dir()}
            v20_bytes = archive.read(parent["protocol"]["path"])
            self.assertEqual(len(v20_bytes), parent["protocol"]["bytes"])
            self.assertEqual(sha256(v20_bytes), V20_PROTOCOL_SHA256)
            self.assertEqual(sha256(v20_bytes), parent["protocol"]["sha256"])
            v20 = json.loads(v20_bytes)
            self.assertEqual((v20["schema"], v20["version"], v20["runtime_grant"]),
                             ("mms-replay-only-continuation-protocol-v20", 20, False))

            for key, expected_count in (("runtime_entries", 21), ("review_entries", 8)):
                rows = parent[key]
                self.assertEqual(len(rows), expected_count)
                listed = {row["path"] for row in rows}
                self.assertEqual(len(listed), expected_count)
                for row in rows:
                    payload = archive.read(row["path"])
                    self.assertEqual(len(payload), row["bytes"], row["path"])
                    self.assertEqual(sha256(payload), row["sha256"], row["path"])
                if key == "runtime_entries":
                    prefix = parent["output_leaf"].rstrip("/") + "/"
                else:
                    prefix = parent["review_json_path"].rsplit("/", 1)[0] + "/"
                archived = {name for name in names if name.startswith(prefix)}
                self.assertEqual(archived, listed)

            for row in parent["source_files"]:
                path = ROOT.joinpath(*PurePosixPath(row["path"]).parts)
                self.assertEqual(path.stat().st_size, row["bytes"], row["path"])
                self.assertEqual(sha256_file(path), row["sha256"], row["path"])

    def test_v20_root_race_is_pinned_and_v21_recovery_is_exact(self) -> None:
        parent = self.protocol["parent_v20_actual_failure"]
        with zipfile.ZipFile(self.protocol["archived_input_source"]["archive_path"], "r") as archive:
            final = archived_json(archive, parent["final_path"])
            process = archived_json(archive, parent["process_path"])
            self.assertEqual((final["controller_exit_code"], final["classification"],
                              final["solver_exit_code"], final["numerical_status"],
                              final["stopping_reason"], final["authority"],
                              final["physical_validation"]),
                             (124, "resource_interruption", 2, "fail",
                              "stationary_nonzero_residual", "no_publish", "unsupported"))
            self.assertEqual((process["exit_code"], process["stop_reason"],
                              process["rss_complete_sample_count"],
                              process["rss_sampling_complete"]),
                             (1, "cleanup_unconfirmed", 934, False))
            pid = process["pid"]
            self.assertEqual(process["root_process_identity"]["pid"], pid)
            self.assertTrue(any(
                item.get("error_type") == "NoSuchProcess" and
                item.get("root_pid") == pid and item.get("process_pid") == pid
                for item in process["rss_observation_errors"]))
            cleanup = process["cleanup"]
            self.assertIs(cleanup["termination_confirmed"], False)
            self.assertTrue(any(item.get("stage") == "root_process_lookup" and
                                item.get("error_type") == "NoSuchProcess" and
                                item.get("pid") == pid
                                for item in cleanup["termination_verification_errors"]))

        recovery = self.runner[self.runner.index("root_missing_after_confirmed_exit = ("):
                               self.runner.index("if root_missing_after_confirmed_exit:")]
        for required in (
            "late_exit_code is not None", "root_identity[0] == int(proc.pid)",
            "rss_complete_sample_count > 0", "exc.evidence.get(\"root_pid\") == int(proc.pid)",
            "exc.evidence.get(\"process_pid\") == int(proc.pid)",
            "exc.evidence.get(\"error_type\") == \"NoSuchProcess\"",
        ):
            with self.subTest(guard=required):
                self.assertIn(required, recovery)
        recovery_action = self.runner[self.runner.index("if root_missing_after_confirmed_exit:"):
                                      self.runner.index("rss_sampling_complete = False",
                                                        self.runner.index("if root_missing_after_confirmed_exit:"))]
        self.assertIn('record_confirmed_leader_exit(late_exit_code, "popen_exit_during_rss_race"',
                      recovery_action)
        exit_audit = self.runner[self.runner.index("def record_confirmed_leader_exit"):
                                 self.runner.index("while stop_reason == \"exited\"")]
        self.assertIn("audit_descendants_after_leader_exit(identities, root_identity)", exit_audit)
        self.assertIn("rss_complete_sample_count == 0", exit_audit)

    def test_vector_digest_and_case_bound_hash_remain_separate(self) -> None:
        parent = self.protocol["parent_v20_actual_failure"]
        ref = self.protocol["replay_inputs"]["numerical_result"]
        with zipfile.ZipFile(self.protocol["archived_input_source"]["archive_path"], "r") as archive:
            numerical_bytes = archive.read(ref["path"])
        self.assertEqual(len(numerical_bytes), ref["bytes"])
        self.assertEqual(sha256(numerical_bytes), ref["sha256"])
        numerical = json.loads(numerical_bytes)
        case_hash = numerical["cases"][0]["state_hash"]["value"]
        vector_hash = self.protocol["preserved_identity"]["state_after_hash"]
        self.assertEqual(case_hash, CASE_STATE_HASH)
        self.assertEqual(case_hash, parent["case_state_hash"])
        self.assertEqual(vector_hash, FINAL_VECTOR_HASH)
        self.assertNotEqual(case_hash, vector_hash)

        self.assertIn("canonical_hash(Tuple(c.final_state))", self.julia)
        self.assertIn("protocol.preserved_identity.state_after_hash", self.julia)
        self.assertIn("case_state_hash = canonical_hash((candidate_hash=result.candidate_hash, context_hash=result.context_hash,",
                      self.julia)
        self.assertIn("string(c.state_hash) == string(case_state_hash) == String(protocol.preserved_identity.case_state_hash)",
                      self.julia)

    def test_resource_and_typed_status_invariants_remain_fail_closed(self) -> None:
        p = self.protocol
        self.assertEqual(p["stage_limits"], {
            "seconds": 480, "working_set_bytes": 2147483648,
            "memory_measurement": "sampled aggregate process-tree RSS; not a continuous OS hard cap",
        })
        self.assertEqual(p["total_child_wall_limit_seconds"], 960)
        self.assertEqual(p["controller_overhead_seconds_limit"], 120)
        self.assertIs(p["resource_contract"]["cleanup_unconfirmed_prevents_consumer"], True)
        self.assertIs(p["resource_contract"]["shared_aggregate_child_wall_deadline_enforced"], True)
        self.assertEqual(p["preserved_numerical_status"], {
            "authority": "no_publish", "physical_validation": "unsupported",
            "solver_exit_code": 2, "status": "fail",
            "stopping_reason": "stationary_nonzero_residual",
        })
        self.assertEqual(p["static_contract_run"], {
            "julia_started": False, "output_leaf_must_remain_absent": True,
            "producer_consumer_started": False, "status": "not_run",
        })

        tokens = self.julia[self.julia.index("const HYDRATION_SYMBOL_TOKENS"):
                            self.julia.index("hydration_normalized_path")]
        for required in (
            '"cases[#].status" => Set(["fail", "unsupported", "converged"])',
            '"cases[#].diagnostics.numerical_status" => Set(["full_discrete_residual_converged", "program_exception", "resource_limit", "numerical_fail"])',
            '"cases[#].diagnostics.manufactured_loads.external_closure_status" => Set(["terminal_deferred"])',
            '"execution.authority" => Set(["no_publish"])',
        ):
            with self.subTest(token=required):
                self.assertIn(required, tokens)
        self.assertIn("value isa AbstractString && String(value) in allowed", self.julia)
        self.assertIn("Symbol(String(value))", self.julia)
        self.assertIn('classification = "resource_interruption"', self.runner)
        self.assertIn('controller_exit = resource_exit', self.runner)

        # R5 non-doc V10 resolver control: historical bytes may be read from
        # one exact archive /files/<logical-path> member when the live source
        # has drifted. Ambiguous aliases and mismatched bytes must fail closed.
        source_spec = importlib.util.spec_from_file_location(
            "up2_v21_canonical_source_resolver", RUNNER)
        self.assertIsNotNone(source_spec)
        self.assertIsNotNone(source_spec.loader)
        source_module = importlib.util.module_from_spec(source_spec)
        source_spec.loader.exec_module(source_module)
        logical_source = "src/RuntimeV4/UP2ResolverFixture.jl"
        historical_bytes = b"# pinned historical V10 source\n"
        row = {
            "path": logical_source,
            "bytes": len(historical_bytes),
            "sha256": hashlib.sha256(historical_bytes).hexdigest(),
        }
        with tempfile.TemporaryDirectory(prefix="up2_r5_source_resolver_") as temp:
            test_root = Path(temp)
            source_root = test_root / "historical_workspace"
            drifted_source = source_root.joinpath(*PurePosixPath(logical_source).parts)
            drifted_source.parent.mkdir(parents=True)
            drifted_source.write_bytes(b"# changed live source\n")
            exact_archive = test_root / "exact_historical_source.zip"
            with zipfile.ZipFile(exact_archive, "w", compression=zipfile.ZIP_STORED) as archive:
                archive.writestr("retained/files/" + logical_source, historical_bytes)
            resolved = source_module.resolve_non_doc_v10_input(source_root, exact_archive, row)
            self.assertEqual(
                (resolved["logical_path"], resolved["bytes"], resolved["sha256"],
                 resolved["resolved_from"], resolved["archive_member"], resolved["content"]),
                (logical_source, len(historical_bytes), row["sha256"],
                 "verified_unique_zip_files_source", "retained/files/" + logical_source,
                 historical_bytes),
            )

            duplicate_archive = test_root / "ambiguous_historical_source.zip"
            with zipfile.ZipFile(duplicate_archive, "w", compression=zipfile.ZIP_STORED) as archive:
                archive.writestr("retained/files/" + logical_source, historical_bytes)
                archive.writestr("second/files/" + logical_source, historical_bytes)
            with self.assertRaisesRegex(FileNotFoundError, "no unique exact ZIP `/files/` source"):
                source_module.resolve_non_doc_v10_input(source_root, duplicate_archive, row)

            alias_archive = test_root / "case_alias_historical_source.zip"
            with zipfile.ZipFile(alias_archive, "w", compression=zipfile.ZIP_STORED) as archive:
                archive.writestr("retained/files/" + logical_source, historical_bytes)
                archive.writestr("retained/files/" + logical_source.upper(), historical_bytes)
            with self.assertRaisesRegex(FileNotFoundError, "no unique exact ZIP `/files/` source"):
                source_module.resolve_non_doc_v10_input(source_root, alias_archive, row)

            tampered_archive = test_root / "tampered_historical_source.zip"
            with zipfile.ZipFile(tampered_archive, "w", compression=zipfile.ZIP_STORED) as archive:
                archive.writestr("retained/files/" + logical_source, historical_bytes + b"tamper")
            with self.assertRaisesRegex(ValueError, "ZIP source differs from its exact V10 row"):
                source_module.resolve_non_doc_v10_input(source_root, tampered_archive, row)

        r5_wire = R5_PROTOCOL.read_bytes()
        r5_protocol = json.loads(r5_wire)
        r5_rows = r5_protocol["owned_source_files"]
        r5_by_path = {row["path"]: row["sha256"] for row in r5_rows}
        self.assertEqual(r5_protocol["owned_source_files_by_path"], r5_by_path)
        self.assertEqual(len(r5_rows), 22)
        self.assertEqual((r5_protocol["schema"], r5_protocol["version"],
                          r5_protocol["classification"], r5_protocol["runtime_grant"]),
                         ("mms-replay-only-continuation-protocol-v21", 21,
                          "test_only_continuation", False))
        self.assertEqual(r5_protocol["parent_r4_protocol"], {
            "path": "test/RuntimeV4/UP2ClosureReplayOnlyV21/replay_protocol_v21_r4.json",
            "bytes": R4_PROTOCOL.stat().st_size,
            "sha256": R4_PROTOCOL_SHA256,
        })
        self.assertEqual(r5_protocol["r5_exact_input_resolution"], {
            "schema": "mms-v21-r5-exact-v10-workspace-input-resolution-v1",
            "non_doc_rows": 71, "docs_rows": 18, "total_v10_rows": 89,
            "resolver_symbol": "resolve_non_doc_v10_input",
            "source_path": "test/RuntimeV4/UP2ClosureReplayOnlyV21/run_replay_staged_v21.py",
            "source_sha256": r5_by_path["test/RuntimeV4/UP2ClosureReplayOnlyV21/run_replay_staged_v21.py"],
            "runtime_grant": False, "numerical_credit": False,
            "physical_credit": False, "r4_protocol_unchanged": True,
        })
        for row in r5_rows:
            # R6 has an explicit two-file successor allowance. Keep the R5
            # protocol and its immutable inputs exact, then bind these current
            # wrapper/test bytes to the distinct R6 protocol below.
            if row["path"] in R6_MUTABLE_FROM_R5:
                continue
            pinned_path = ROOT.joinpath(*PurePosixPath(row["path"]).parts)
            self.assertEqual((pinned_path.stat().st_size, sha256_file(pinned_path)),
                             (row["bytes"], row["sha256"]), row["path"])

        r6_builder_text = R6_BUILDER.read_text(encoding="utf-8")
        self.assertIn('WRAPPER_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/run_replay_staged_v21_r4.py"',
                      r6_builder_text)
        self.assertIn('TEST_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/test_independent_static_v21.py"',
                      r6_builder_text)
        self.assertIn("MUTABLE_FROM_R5 = {WRAPPER_REL, TEST_REL}", r6_builder_text)
        r6_protocol = json.loads(R6_PROTOCOL.read_bytes())
        r6_rows = r6_protocol["owned_source_files"]
        r6_by_path = {row["path"]: row for row in r6_rows}
        self.assertEqual(len(r6_rows), 25)
        self.assertEqual(r6_protocol["parent_r5_protocol"], {
            "path": "test/RuntimeV4/UP2ClosureReplayOnlyV21/replay_protocol_v21_r5.json",
            "bytes": len(r5_wire), "sha256": sha256(r5_wire),
        })
        r7_protocol = json.loads(R7_PROTOCOL.read_bytes())
        self.assertEqual(r7_protocol["parent_r6_protocol"], {
            "path": "test/RuntimeV4/UP2ClosureReplayOnlyV21/replay_protocol_v21_r6.json",
            "bytes": len(R6_PROTOCOL.read_bytes()), "sha256": R6_PROTOCOL_SHA256,
        })
        self.assertEqual(r7_protocol["r7_static_successor"], {
            "scope": "static_precheck_only", "runtime_grant": False,
            "runtime_execution_started": False, "numerical_credit": False,
            "physical_credit": False,
        })
        r7_rows = r7_protocol["r7_current_source_files"]
        r7_by_path = {row["path"]: row for row in r7_rows}
        self.assertEqual(r7_protocol["r7_current_source_files_by_path"],
                         {row["path"]: row["sha256"] for row in r7_rows})
        self.assertEqual(set(r7_by_path), {
            "test/RuntimeV4/UP2ClosureReplayOnlyV21/run_replay_staged_v21_r4.py",
            "test/RuntimeV4/UP2ClosureReplayOnlyV21/test_independent_static_v21.py",
        })
        for relative, row in r7_by_path.items():
            current_path = ROOT.joinpath(*PurePosixPath(relative).parts)
            self.assertEqual((current_path.stat().st_size, sha256_file(current_path)),
                             (row["bytes"], row["sha256"]), relative)
        self.assertEqual(r7_protocol["coverage_contract"], r6_protocol["coverage_contract"])
        self.assertEqual(r7_protocol["stage_limits"], r6_protocol["stage_limits"])
        self.assertEqual(r7_protocol["total_child_wall_limit_seconds"],
                         r6_protocol["total_child_wall_limit_seconds"])

        r6_test_row = r6_by_path["test/RuntimeV4/UP2ClosureReplayOnlyV21/test_independent_static_v21.py"]
        self.assertEqual((R6_HISTORICAL_TEST_PREIMAGE.stat().st_size,
                          sha256_file(R6_HISTORICAL_TEST_PREIMAGE)),
                         (R6_HISTORICAL_TEST_PREIMAGE_BYTES, R6_HISTORICAL_TEST_PREIMAGE_SHA256))
        self.assertEqual((r6_test_row["bytes"], r6_test_row["sha256"]),
                         (R6_HISTORICAL_TEST_PREIMAGE_BYTES, R6_HISTORICAL_TEST_PREIMAGE_SHA256))
        r6_wrapper_row = r6_by_path["test/RuntimeV4/UP2ClosureReplayOnlyV21/run_replay_staged_v21_r4.py"]
        self.assertEqual((R6_HISTORICAL_WRAPPER_PREIMAGE.stat().st_size,
                          sha256_file(R6_HISTORICAL_WRAPPER_PREIMAGE)),
                         (r6_wrapper_row["bytes"], r6_wrapper_row["sha256"]))
        for relative in R6_MUTABLE_FROM_R5 - {
                "test/RuntimeV4/UP2ClosureReplayOnlyV21/test_independent_static_v21.py",
                "test/RuntimeV4/UP2ClosureReplayOnlyV21/run_replay_staged_v21_r4.py"}:
            pinned_path = ROOT.joinpath(*PurePosixPath(relative).parts)
            row = r6_by_path[relative]
            self.assertEqual((pinned_path.stat().st_size, sha256_file(pinned_path)),
                             (row["bytes"], row["sha256"]), relative)

        wrapper_spec = importlib.util.spec_from_file_location(
            "up2_v21_r5_current_wrapper", R4_RUNNER)
        self.assertIsNotNone(wrapper_spec)
        self.assertIsNotNone(wrapper_spec.loader)
        wrapper_module = importlib.util.module_from_spec(wrapper_spec)
        wrapper_spec.loader.exec_module(wrapper_module)
        self.assertFalse(R5_OUTPUT_ROOT.exists())
        self.assertFalse(R5_MIRROR.exists())
        self.assertFalse(R5_OUTPUT_LEAF.exists())
        with self.assertRaisesRegex(ValueError, "CLI --protocol-sha256 differs from actual protocol bytes"):
            wrapper_module.verify_v10_closure_before_mirror(
                R6_PROTOCOL, "0" * 64, r6_protocol, root=ROOT,
                non_doc_v10_resolver=source_module.resolve_non_doc_v10_input)
        self.assertFalse(R5_OUTPUT_ROOT.exists())
        self.assertFalse(R5_MIRROR.exists())
        self.assertFalse(R5_OUTPUT_LEAF.exists())


def _r2_mirror_snapshot(protocol: dict) -> dict[str, object]:
    contract = protocol["archived_input_source"]
    mirror = Path(contract["staging_root"]).resolve()
    if not mirror.is_dir():
        raise AssertionError(f"preserved R2 archive mirror is missing: {mirror}")
    expected_files = {
        row["logical_path"]: {"bytes": row["bytes"], "sha256": row["sha256"]}
        for row in contract["entries"]
    }
    if len(expected_files) != 613:
        raise AssertionError("R2 protocol no longer declares its exact 613-file mirror")
    prefix_rows = contract["directory_prefixes"]
    expected_prefixes = {row["logical_path"] for row in prefix_rows}
    if len(prefix_rows) != 31 or len(expected_prefixes) != 31:
        raise AssertionError("R2 protocol must retain 31 distinct mapped directory-prefix rows")
    expected_directories: set[str] = set()
    for logical_path in expected_files:
        parts = PurePosixPath(logical_path).parts
        expected_directories.update(PurePosixPath(*parts[:index]).as_posix()
                                    for index in range(1, len(parts)))
    actual_files: dict[str, dict[str, object]] = {}
    actual_directories: set[str] = set()
    for path in mirror.rglob("*"):
        relative = path.relative_to(mirror).as_posix()
        if path.is_symlink():
            raise AssertionError(f"unexpected symlink in preserved R2 mirror: {relative}")
        if path.is_dir():
            actual_directories.add(relative)
        elif path.is_file():
            actual_files[relative] = {"bytes": path.stat().st_size, "sha256": sha256_file(path)}
        else:
            raise AssertionError(f"unexpected non-file entry in preserved R2 mirror: {relative}")
    if actual_files != expected_files:
        raise AssertionError("preserved R2 mirror file paths, byte counts, or SHA-256 values differ from its protocol")
    if actual_directories != expected_directories:
        raise AssertionError("preserved R2 mirror physical directories differ from the exact mapped-file ancestors")
    positive_prefixes = [row for row in prefix_rows if row["mapped_descendant_count"] > 0]
    empty_prefixes = [row for row in prefix_rows if row["mapped_descendant_count"] == 0]
    if len(positive_prefixes) != 30 or len(empty_prefixes) != 1:
        raise AssertionError("R2 protocol must retain 30 materialized and one empty mapped prefix")
    if any(row["logical_path"] not in actual_directories for row in positive_prefixes):
        raise AssertionError("a protocol prefix with mapped descendants is missing from the R2 mirror")
    for prefix_row in prefix_rows:
        prefix = prefix_row["logical_path"].rstrip("/") + "/"
        mapped = sorted((item for item in expected_files if item.startswith(prefix)))
        mapped_manifest = [{"logical_path": logical, **expected_files[logical]} for logical in mapped]
        if (len(mapped), sum(int(row["bytes"]) for row in mapped_manifest),
                sha256(canonical_json_bytes(mapped_manifest))) != (
                prefix_row["mapped_descendant_count"], prefix_row["mapped_descendant_bytes"],
                prefix_row["mapped_descendant_manifest_sha256"]):
            raise AssertionError(f"preserved R2 mirror prefix map changed: {prefix_row['logical_path']}")
        if prefix_row["mapped_descendant_count"] == 0:
            empty_path = PurePosixPath(prefix_row["logical_path"])
            empty_fs_path = mirror.joinpath(*empty_path.parts)
            empty_prefix = empty_path.as_posix().rstrip("/") + "/"
            if prefix_row["mapped_descendant_bytes"] != 0 or \
                    prefix_row["mapped_descendant_manifest_sha256"] != sha256(canonical_json_bytes([])) or \
                    prefix_row.get("mirror_scope") != "explicitly_mapped_descendants_only" or \
                    empty_fs_path.exists() or \
                    any(path == empty_path.as_posix() or path.startswith(empty_prefix)
                        for path in actual_directories) or \
                    any(path == empty_path.as_posix() or path.startswith(empty_prefix)
                        for path in actual_files):
                raise AssertionError(f"zero-descendant R2 prefix must remain absent: {empty_path.as_posix()}")
    manifest = canonical_json_bytes({"files": actual_files, "directories": sorted(actual_directories)})
    return {
        "file_count": len(actual_files),
        "bytes": sum(int(row["bytes"]) for row in actual_files.values()),
        "directory_count": len(actual_directories),
        "directory_prefix_count": len(expected_prefixes),
        "inventory_sha256": sha256(manifest),
        "files": actual_files,
        "directories": sorted(actual_directories),
    }


def _assert_r2_mirror_unchanged() -> None:
    if R2_MIRROR_BASELINE is None:
        raise AssertionError("R2 mirror baseline was not captured before the static suite")
    protocol = json.loads(R2_PROTOCOL.read_bytes())
    if _r2_mirror_snapshot(protocol) != R2_MIRROR_BASELINE:
        raise AssertionError("R2 mirror changed during the static suite")


def _r3_mirror_snapshot(protocol: dict) -> dict[str, object]:
    contract = protocol["archived_input_source"]
    mirror = Path(contract["staging_root"]).resolve()
    if mirror != R3_MIRROR.resolve() or not mirror.is_dir():
        raise AssertionError(f"preserved R3 archive mirror is missing or moved: {mirror}")
    expected_files = {
        row["logical_path"]: {"bytes": row["bytes"], "sha256": row["sha256"]}
        for row in contract["entries"]
    }
    if len(expected_files) != 613:
        raise AssertionError("R3 protocol no longer declares its exact 613-file mirror")
    prefix_rows = contract["directory_prefixes"]
    expected_prefixes = {row["logical_path"] for row in prefix_rows}
    if len(prefix_rows) != 31 or len(expected_prefixes) != 31:
        raise AssertionError("R3 protocol must retain 31 distinct mapped directory-prefix rows")
    expected_directories: set[str] = set()
    for logical_path in expected_files:
        parts = PurePosixPath(logical_path).parts
        expected_directories.update(PurePosixPath(*parts[:index]).as_posix()
                                    for index in range(1, len(parts)))
    actual_files: dict[str, dict[str, object]] = {}
    actual_directories: set[str] = set()
    for path in mirror.rglob("*"):
        relative = path.relative_to(mirror).as_posix()
        if path.is_symlink():
            raise AssertionError(f"unexpected symlink in preserved R3 mirror: {relative}")
        if path.is_dir():
            actual_directories.add(relative)
        elif path.is_file():
            actual_files[relative] = {"bytes": path.stat().st_size, "sha256": sha256_file(path)}
        else:
            raise AssertionError(f"unexpected non-file entry in preserved R3 mirror: {relative}")
    if actual_files != expected_files:
        raise AssertionError("preserved R3 mirror file paths, byte counts, or SHA-256 values differ from its protocol")
    if actual_directories != expected_directories:
        raise AssertionError("preserved R3 mirror physical directories differ from the exact mapped-file ancestors")
    positive_prefixes = [row for row in prefix_rows if row["mapped_descendant_count"] > 0]
    empty_prefixes = [row for row in prefix_rows if row["mapped_descendant_count"] == 0]
    if len(positive_prefixes) != 30 or len(empty_prefixes) != 1:
        raise AssertionError("R3 protocol must retain 30 materialized and one empty mapped prefix")
    if any(row["logical_path"] not in actual_directories for row in positive_prefixes):
        raise AssertionError("a protocol prefix with mapped descendants is missing from the R3 mirror")
    for prefix_row in prefix_rows:
        prefix = prefix_row["logical_path"].rstrip("/") + "/"
        mapped = sorted((item for item in expected_files if item.startswith(prefix)))
        mapped_manifest = [{"logical_path": logical, **expected_files[logical]} for logical in mapped]
        if (len(mapped), sum(int(row["bytes"]) for row in mapped_manifest),
                sha256(canonical_json_bytes(mapped_manifest))) != (
                prefix_row["mapped_descendant_count"], prefix_row["mapped_descendant_bytes"],
                prefix_row["mapped_descendant_manifest_sha256"]):
            raise AssertionError(f"preserved R3 mirror prefix map changed: {prefix_row['logical_path']}")
        if prefix_row["mapped_descendant_count"] == 0:
            empty_path = PurePosixPath(prefix_row["logical_path"])
            empty_fs_path = mirror.joinpath(*empty_path.parts)
            empty_prefix = empty_path.as_posix().rstrip("/") + "/"
            if prefix_row["mapped_descendant_bytes"] != 0 or \
                    prefix_row["mapped_descendant_manifest_sha256"] != sha256(canonical_json_bytes([])) or \
                    prefix_row.get("mirror_scope") != "explicitly_mapped_descendants_only" or \
                    empty_fs_path.exists() or \
                    any(path == empty_path.as_posix() or path.startswith(empty_prefix)
                        for path in actual_directories) or \
                    any(path == empty_path.as_posix() or path.startswith(empty_prefix)
                        for path in actual_files):
                raise AssertionError(f"zero-descendant R3 prefix must remain absent: {empty_path.as_posix()}")
    manifest = canonical_json_bytes({"files": actual_files, "directories": sorted(actual_directories)})
    return {
        "file_count": len(actual_files),
        "bytes": sum(int(row["bytes"]) for row in actual_files.values()),
        "directory_count": len(actual_directories),
        "directory_prefix_count": len(expected_prefixes),
        "inventory_sha256": sha256(manifest),
        "files": actual_files,
        "directories": sorted(actual_directories),
    }


def _assert_r3_mirror_unchanged() -> None:
    if R3_MIRROR_BASELINE is None:
        raise AssertionError("R3 mirror baseline was not captured before the static suite")
    protocol = json.loads(R3_PROTOCOL.read_bytes())
    if _r3_mirror_snapshot(protocol) != R3_MIRROR_BASELINE:
        raise AssertionError("preserved R3 archive mirror changed during the static suite")
    if not R3_OUTPUT_ROOT.is_dir() or not R3_MIRROR.is_dir() or R3_OUTPUT_LEAF.exists():
        raise AssertionError("preserved R3 root/mirror or absent runtime-leaf state changed")


def _assert_r4_outputs_absent() -> None:
    for path in (R4_OUTPUT_ROOT, R4_MIRROR, R4_OUTPUT_LEAF):
        if path.exists():
            raise AssertionError(f"R4 static gate unexpectedly created an external output: {path}")


def _assert_r6_outputs_absent() -> None:
    for path in (R6_OUTPUT_ROOT, R6_MIRROR, R6_OUTPUT_LEAF):
        if path.exists():
            raise AssertionError(f"R6 static gate unexpectedly created an external output: {path}")


def _r4_protocol_for_existing_r3_mirror(protocol: dict) -> dict:
    adapted = copy.deepcopy(protocol)
    adapted["archived_input_source"]["staging_root"] = str(R3_MIRROR.resolve())
    expected = copy.deepcopy(protocol)
    expected["archived_input_source"]["staging_root"] = str(R3_MIRROR.resolve())
    if adapted != expected:
        raise AssertionError("R4 test input-provider adapter changed fields beyond the physical staging root")
    return adapted


class TestIndependentStaticV21R2Lineage(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        global R2_MIRROR_BASELINE
        cls.protocol_bytes = R2_PROTOCOL.read_bytes()
        cls.protocol = json.loads(cls.protocol_bytes)
        cls.protocol_sha256 = sha256(cls.protocol_bytes)
        spec = importlib.util.spec_from_file_location("up2_closure_v21_r2_static_runner", R2_RUNNER)
        if spec is None or spec.loader is None:
            raise RuntimeError("could not load the pinned R2 pre-mirror gate")
        cls.runner_module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.runner_module)
        snapshot = _r2_mirror_snapshot(cls.protocol)
        if R2_MIRROR_BASELINE is not None and R2_MIRROR_BASELINE != snapshot:
            raise AssertionError("R2 mirror differs from the already captured pre-suite inventory")
        R2_MIRROR_BASELINE = snapshot
        if R2_OUTPUT_ROOT != Path(cls.protocol["r2_output_ownership"]["raw_external_root"]).resolve():
            raise AssertionError("R2 external root differs from its frozen ownership contract")
        if R2_OUTPUT_LEAF.exists():
            raise AssertionError("R2 runtime output leaf must remain absent after its pre-output failure")

    @classmethod
    def tearDownClass(cls) -> None:
        _assert_r2_mirror_unchanged()

    def test_r2_protocol_and_exact_pre_r3_source_snapshot_remain_pinned(self) -> None:
        p = self.protocol
        self.assertEqual(self.protocol_sha256, R2_PROTOCOL_SHA256)
        self.assertEqual(len(self.protocol_bytes), R2_PROTOCOL_BYTES)
        self.assertEqual((p["schema"], p["version"], p["classification"], p["runtime_grant"]),
                         ("mms-replay-only-continuation-protocol-v21", 21,
                          "test_only_continuation", False))
        rows = p["owned_source_files"]
        self.assertEqual(p["owned_source_files_by_path"],
                         {row["path"]: row["sha256"] for row in rows})
        self.assertEqual(len(rows), 9)
        static_test_rel = "test/RuntimeV4/UP2ClosureReplayOnlyV21/test_independent_static_v21.py"
        self.assertEqual(p["owned_source_files_by_path"][static_test_rel], R2_TEST_SHA256)
        self.assertEqual(R2_TEST_SNAPSHOT.stat().st_size, R2_TEST_BYTES)
        self.assertEqual(sha256_file(R2_TEST_SNAPSHOT), R2_TEST_SHA256)
        self.assertEqual(R2_PROTOCOL_SNAPSHOT.stat().st_size, R2_PROTOCOL_BYTES)
        self.assertEqual(sha256_file(R2_PROTOCOL_SNAPSHOT), R2_PROTOCOL_SHA256)
        self.assertEqual(sha256_file(R2_SNAPSHOT_MANIFEST), R2_SNAPSHOT_MANIFEST_SHA256)
        self.assertEqual(sha256_file(R2_TEST_RECEIPT), R2_TEST_RECEIPT_SHA256)
        for row in rows:
            if row["path"] == static_test_rel:
                path = R2_TEST_SNAPSHOT
            elif row["path"] == "test/RuntimeV4/UP2ClosureReplayOnlyV21/run_replay_staged_v21.py":
                path = V21_CANONICAL_PREIMAGE
            else:
                path = ROOT.joinpath(*PurePosixPath(row["path"]).parts)
            self.assertEqual(path.stat().st_size, row["bytes"], row["path"])
            self.assertEqual(sha256_file(path), row["sha256"], row["path"])
        self.assertEqual((V21_CANONICAL_PREIMAGE.stat().st_size,
                          sha256_file(V21_CANONICAL_PREIMAGE)),
                         (V21_CANONICAL_PREIMAGE_BYTES, V21_CANONICAL_PREIMAGE_SHA256))
        for filename, expected_sha in R2_FILE_SHA256.items():
            path = HERE / filename
            self.assertEqual(sha256_file(path), expected_sha, filename)
            self.assertEqual(p["owned_source_files_by_path"][f"test/RuntimeV4/UP2ClosureReplayOnlyV21/{filename}"],
                             expected_sha)
        self.assertEqual(p["controller"], "test/RuntimeV4/UP2ClosureReplayOnlyV21/run_replay_staged_v21_r2.py")
        self.assertEqual(p["entrypoint"], "test/RuntimeV4/UP2ClosureReplayOnlyV21/replay_staged_v21_r2.jl")

        contract = p["archived_input_source"]
        summary = contract["closure_summary"]
        self.assertEqual((len(contract["entries"]), len(contract["referenced_paths"]),
                          len(contract["directory_prefixes"])), (613, 645, 31))
        self.assertEqual(summary["witnessed_expected_absences"], 1)
        self.assertEqual((summary["v10_pinned_input_count"], summary["v10_pinned_docs_input_count"],
                          summary["v10_pinned_workspace_input_count"],
                          summary["v10_docs_inputs_added_to_archive_map"],
                          summary["v10_docs_input_bytes_added"]), (89, 18, 71, 18, 246953))
        self.assertEqual((p["saved_producer_tree"]["file_count"], p["saved_producer_tree"]["bytes"]),
                         (119, 6590185))
        self.assertEqual(p["stage_limits"], {
            "seconds": 480, "working_set_bytes": 2147483648,
            "memory_measurement": "sampled aggregate process-tree RSS; not a continuous OS hard cap",
        })
        self.assertEqual(p["total_child_wall_limit_seconds"], 960)
        self.assertEqual(p["controller_overhead_seconds_limit"], 120)
        self.assertEqual(p["preserved_numerical_status"], {
            "authority": "no_publish", "physical_validation": "unsupported",
            "solver_exit_code": 2, "status": "fail",
            "stopping_reason": "stationary_nonzero_residual",
        })
        self.assertFalse(p["runtime_grant"])
        self.assertEqual(_r2_mirror_snapshot(p), R2_MIRROR_BASELINE)
        self.assertTrue(R2_OUTPUT_ROOT.is_dir())
        self.assertTrue(R2_MIRROR.is_dir())
        self.assertFalse(R2_OUTPUT_LEAF.exists())

    def test_r2_pre_mirror_gate_refuses_the_real_nonempty_preserved_root(self) -> None:
        p = self.protocol
        snapshot = _r2_mirror_snapshot(p)
        self.assertEqual((snapshot["file_count"], snapshot["bytes"], snapshot["directory_prefix_count"]),
                         (613, 31564478, 31))
        with self.assertRaisesRegex(FileExistsError, "external root"):
            self.runner_module.verify_v10_closure_before_mirror(
                R2_PROTOCOL, self.protocol_sha256, p, root=ROOT)
        self.assertEqual(_r2_mirror_snapshot(p), snapshot)
        self.assertFalse(R2_OUTPUT_LEAF.exists())


class TestIndependentStaticV21R3(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        global R3_MIRROR_BASELINE
        cls.protocol_bytes = R3_PROTOCOL.read_bytes()
        cls.protocol = json.loads(cls.protocol_bytes)
        cls.protocol_sha256 = sha256(cls.protocol_bytes)
        spec = importlib.util.spec_from_file_location("up2_closure_v21_r3_static_runner", R3_RUNNER)
        if spec is None or spec.loader is None:
            raise RuntimeError("could not load the frozen R3 read-only gate")
        cls.runner_module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.runner_module)
        cls.runner_module.ORIGINAL_CONTROLLER = V21_CANONICAL_PREIMAGE
        cls.controller, loaded_protocol = cls.runner_module._load_frozen_controller()
        if loaded_protocol != cls.protocol:
            raise AssertionError("R3 controller loader returned bytes different from the pinned R3 protocol")
        cls.julia = R3_JULIA_ENTRY.read_text(encoding="utf-8")
        current_mirror = _r2_mirror_snapshot(json.loads(R2_PROTOCOL.read_bytes()))
        if current_mirror != R2_MIRROR_BASELINE:
            raise AssertionError("R2 archive mirror changed between R2 lineage checks and R3 setup")
        current_r3_mirror = _r3_mirror_snapshot(cls.protocol)
        if R3_MIRROR_BASELINE is not None and R3_MIRROR_BASELINE != current_r3_mirror:
            raise AssertionError("R3 archive mirror differs from its previously captured inventory")
        R3_MIRROR_BASELINE = current_r3_mirror
        _assert_r3_mirror_unchanged()

    @classmethod
    def tearDownClass(cls) -> None:
        _assert_r2_mirror_unchanged()
        _assert_r3_mirror_unchanged()

    def test_r3_protocol_pins_sources_closure_and_unchanged_acceptance_limits(self) -> None:
        p = self.protocol
        self.assertEqual(self.protocol_sha256, R3_PROTOCOL_SHA256)
        self.assertEqual((p["schema"], p["version"], p["classification"], p["runtime_grant"]),
                         ("mms-replay-only-continuation-protocol-v21", 21,
                          "test_only_continuation", False))
        rows = p["owned_source_files"]
        self.assertEqual(len(rows), 14)
        self.assertEqual(p["owned_source_files_by_path"],
                         {row["path"]: row["sha256"] for row in rows})
        static_test_rel = "test/RuntimeV4/UP2ClosureReplayOnlyV21/test_independent_static_v21.py"
        self.assertEqual(p["owned_source_files_by_path"][static_test_rel], R3_TEST_SNAPSHOT_SHA256)
        self.assertEqual(R3_TEST_SNAPSHOT.stat().st_size, R3_TEST_SNAPSHOT_BYTES)
        self.assertEqual(sha256_file(R3_TEST_SNAPSHOT), R3_TEST_SNAPSHOT_SHA256)
        self.assertEqual(sha256_file(R3_SOURCE_SNAPSHOT_MANIFEST),
                         R3_SOURCE_SNAPSHOT_MANIFEST_SHA256)
        self.assertEqual(R3_SOURCE_SNAPSHOT_MANIFEST.stat().st_size, R3_SOURCE_SNAPSHOT_MANIFEST_BYTES)
        self.assertEqual(sha256_file(R3_ACTUAL_EXIT_RECEIPT), R3_ACTUAL_EXIT_RECEIPT_SHA256)
        self.assertEqual(sha256_file(R3_STATIC_EXIT_RECEIPT), R3_STATIC_EXIT_RECEIPT_SHA256)
        self.assertEqual(R3_STATIC_EXIT_RECEIPT.stat().st_size, R3_STATIC_EXIT_RECEIPT_BYTES)
        for row in rows:
            if row["path"] == static_test_rel:
                path = R3_TEST_SNAPSHOT
            elif row["path"] == "test/RuntimeV4/UP2ClosureReplayOnlyV21/run_replay_staged_v21.py":
                path = V21_CANONICAL_PREIMAGE
            else:
                path = ROOT.joinpath(*PurePosixPath(row["path"]).parts)
            self.assertEqual(path.stat().st_size, row["bytes"], row["path"])
            self.assertEqual(sha256_file(path), row["sha256"], row["path"])
        self.assertEqual((V21_CANONICAL_PREIMAGE.stat().st_size,
                          sha256_file(V21_CANONICAL_PREIMAGE)),
                         (V21_CANONICAL_PREIMAGE_BYTES, V21_CANONICAL_PREIMAGE_SHA256))
        for filename, expected_sha in R3_FILE_SHA256.items():
            path = HERE / filename
            self.assertEqual(sha256_file(path), expected_sha, filename)
            self.assertEqual(p["owned_source_files_by_path"][
                f"test/RuntimeV4/UP2ClosureReplayOnlyV21/{filename}"], expected_sha)

        self.assertEqual(p["controller"],
                         "test/RuntimeV4/UP2ClosureReplayOnlyV21/run_replay_staged_v21_r3.py")
        self.assertEqual(p["entrypoint"],
                         "test/RuntimeV4/UP2ClosureReplayOnlyV21/replay_staged_v21_r3.jl")
        self.assertEqual(Path(p["output_leaf"]).resolve(), R3_OUTPUT_LEAF.resolve())
        self.assertEqual(Path(p["archived_input_source"]["staging_root"]).resolve(), R3_MIRROR.resolve())
        self.assertEqual(p["parent_r2_protocol"]["sha256"], R2_PROTOCOL_SHA256)
        contract = p["archived_input_source"]
        r2_contract = json.loads(R2_PROTOCOL.read_bytes())["archived_input_source"]
        self.assertEqual(contract["entries"], r2_contract["entries"])
        self.assertEqual(contract["referenced_paths"], r2_contract["referenced_paths"])
        self.assertEqual(contract["expected_absent"], r2_contract["expected_absent"])
        self.assertEqual((len(contract["entries"]), len(contract["referenced_paths"]),
                          len(contract["directory_prefixes"])), (613, 645, 31))
        summary = contract["closure_summary"]
        self.assertEqual((summary["v10_pinned_input_count"], summary["v10_pinned_docs_input_count"],
                          summary["v10_pinned_workspace_input_count"],
                          summary["v10_docs_inputs_added_to_archive_map"],
                          summary["v10_docs_input_bytes_added"]), (89, 18, 71, 18, 246953))
        self.assertEqual((p["saved_producer_tree"]["file_count"], p["saved_producer_tree"]["bytes"]),
                         (119, 6590185))
        self.assertEqual(p["stage_limits"], {
            "seconds": 480, "working_set_bytes": 2147483648,
            "memory_measurement": "sampled aggregate process-tree RSS; not a continuous OS hard cap",
        })
        self.assertEqual(p["total_child_wall_limit_seconds"], 960)
        self.assertEqual(p["controller_overhead_seconds_limit"], 120)
        self.assertEqual(p["preserved_numerical_status"], {
            "authority": "no_publish", "physical_validation": "unsupported",
            "solver_exit_code": 2, "status": "fail",
            "stopping_reason": "stationary_nonzero_residual",
        })
        self.assertEqual(p["coverage_contract"]["process_tree_resource_monitor_summary"],
                         R3_MONITOR_SUMMARY)
        self.assertEqual(p["coverage_contract"]["process_tree_resource_monitor_negative_controls"],
                         R3_PROCESS_TREE_NEGATIVES)
        self.assertEqual(len(R3_PROCESS_TREE_NEGATIVES), 14)
        self.assertIs(p["r3_repair"]["strict_controller_validator_unchanged"], True)
        _assert_r3_mirror_unchanged()

    def test_r3_pre_mirror_gate_rejects_occupied_root_and_wrong_cli_sha(self) -> None:
        p = self.protocol
        snapshot = _r3_mirror_snapshot(p)
        with self.assertRaises(FileExistsError):
            self.runner_module.audit_v10_input_closure_before_mirror(p, root=ROOT)
        with self.assertRaises(FileExistsError):
            self.runner_module.verify_v10_closure_before_mirror(
                R3_PROTOCOL, self.protocol_sha256, p, root=ROOT)
        with self.assertRaisesRegex(ValueError, "CLI --protocol-sha256"):
            self.runner_module.verify_v10_closure_before_mirror(
                R3_PROTOCOL, "0" * 64, p, root=ROOT)
        self.assertEqual(_r3_mirror_snapshot(p), snapshot)
        self.assertFalse(R3_OUTPUT_LEAF.exists())
        _assert_r3_mirror_unchanged()

    def test_r3_actual_pre_output_pure_gates_cover_monitor_through_exit_guard(self) -> None:
        p = self.protocol
        controller = self.controller
        source = controller.R3_TRANSFORMED_CONTROLLER_SOURCE

        controller.verify_frozen_resource_contract(p)
        overhead = controller.validate_controller_overhead_contract(p)
        self.assertEqual(overhead["limit_seconds"], 120.0)
        aggregate = controller.validate_aggregate_child_wall_contract(p)
        self.assertEqual((aggregate["total_limit_seconds"], aggregate["stage_limit_seconds"]),
                         (960.0, 480.0))
        self.assertEqual(controller.validate_process_tree_monitor_contract(p),
                         p["process_tree_monitor_contract"])
        self.assertEqual(p["coverage_contract"]["process_tree_resource_monitor_negative_controls"],
                         R3_PROCESS_TREE_NEGATIVES)
        output = controller.resolve_output_target(ROOT, p["output_leaf"], p["output_leaf"])
        self.assertEqual(output, R3_OUTPUT_LEAF.resolve())
        controller.verify_child_command_contract(p)
        context = controller.verify_context_builder_contract(ROOT, p)
        self.assertEqual(context["entrypoint_path"], R3_JULIA_ENTRY.resolve())
        controller.verify_hydration_contract_text(self.julia)
        controller.verify_process_exit_race_contract_text(source)

        start = source.index("def verify_pre_output_contract(")
        end = source.index("\ndef ", start + 5)
        pre_output = source[start:end]
        ordered_calls = (
            "verify_frozen_resource_contract(protocol)",
            "validate_controller_overhead_contract(protocol)",
            "validate_aggregate_child_wall_contract(protocol)",
            "validate_process_tree_monitor_contract(protocol)",
            "resolve_output_target(ROOT, output_arg, protocol.get(\"output_leaf\"))",
            "verify_child_command_contract(protocol)",
            "verify_context_builder_contract(ROOT, protocol)",
            "verify_hydration_contract_text(",
            "verify_process_exit_race_contract_text(",
        )
        positions = [pre_output.index(call) for call in ordered_calls]
        self.assertEqual(positions, sorted(positions))
        _assert_r3_mirror_unchanged()
        _assert_r2_mirror_unchanged()


class TestIndependentStaticV21R4(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        global R3_MIRROR_BASELINE
        cls.protocol_bytes = R4_PROTOCOL.read_bytes()
        cls.protocol = json.loads(cls.protocol_bytes)
        cls.protocol_sha256 = sha256(cls.protocol_bytes)
        if (R4_HISTORICAL_RUNNER_PREIMAGE.stat().st_size,
                sha256_file(R4_HISTORICAL_RUNNER_PREIMAGE)) != (
                R4_HISTORICAL_RUNNER_PREIMAGE_BYTES, R4_HISTORICAL_RUNNER_PREIMAGE_SHA256):
            raise AssertionError("preserved R4 runner preimage differs from its frozen source pin")
        if (R4_HISTORICAL_TEST_PREIMAGE.stat().st_size,
                sha256_file(R4_HISTORICAL_TEST_PREIMAGE)) != (
                R4_HISTORICAL_TEST_PREIMAGE_BYTES, R4_HISTORICAL_TEST_PREIMAGE_SHA256):
            raise AssertionError("preserved R4 test preimage differs from its frozen source pin")
        spec = importlib.util.spec_from_file_location(
            "up2_closure_v21_r4_static_runner", R4_HISTORICAL_RUNNER_PREIMAGE)
        if spec is None or spec.loader is None:
            raise RuntimeError("could not load the preserved historical R4 runner bytes")
        cls.runner_module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.runner_module)
        cls.runner_module.BASE = HERE
        cls.runner_module.R4_PROTOCOL_PATH = R4_PROTOCOL
        cls.runner_module.ORIGINAL_CONTROLLER = V21_CANONICAL_PREIMAGE
        cls.runner_module.OVERLAY_SPEC_PATH = R4_OVERLAY_SPEC
        cls.controller, loaded_protocol = cls.runner_module._load_frozen_controller()
        if loaded_protocol != cls.protocol:
            raise AssertionError("R4 controller loader returned bytes different from the pinned R4 protocol")
        cls.r6_protocol_bytes = R6_PROTOCOL.read_bytes()
        cls.r6_protocol = json.loads(cls.r6_protocol_bytes)
        cls.r6_protocol_sha256 = sha256(cls.r6_protocol_bytes)
        cls.r7_protocol_bytes = R7_PROTOCOL.read_bytes()
        cls.r7_protocol = json.loads(cls.r7_protocol_bytes)
        cls.r7_protocol_sha256 = sha256(cls.r7_protocol_bytes)
        r7_spec = importlib.util.spec_from_file_location("up2_closure_v21_r7_current_wrapper", R7_RUNNER)
        if r7_spec is None or r7_spec.loader is None:
            raise RuntimeError("could not load the current R7 consumer wrapper")
        cls.r7_wrapper_module = importlib.util.module_from_spec(r7_spec)
        r7_spec.loader.exec_module(cls.r7_wrapper_module)
        cls.r7_controller, loaded_r7_protocol = cls.r7_wrapper_module._load_frozen_controller(
            R7_PROTOCOL, cls.r7_protocol_sha256)
        if loaded_r7_protocol != cls.r7_protocol:
            raise AssertionError("R7 consumer loaded protocol bytes different from the frozen R7 protocol")
        cls.julia = R4_JULIA_ENTRY.read_text(encoding="utf-8")
        cls.r3_protocol = json.loads(R3_PROTOCOL.read_bytes())
        current_r3_mirror = _r3_mirror_snapshot(cls.r3_protocol)
        if R3_MIRROR_BASELINE is not None and R3_MIRROR_BASELINE != current_r3_mirror:
            raise AssertionError("R3 mirror changed between R3 lineage checks and R4 setup")
        R3_MIRROR_BASELINE = current_r3_mirror
        _assert_r4_outputs_absent()
        _assert_r6_outputs_absent()
        _assert_r2_mirror_unchanged()
        _assert_r3_mirror_unchanged()

    @classmethod
    def tearDownClass(cls) -> None:
        _assert_r4_outputs_absent()
        _assert_r6_outputs_absent()
        _assert_r2_mirror_unchanged()
        _assert_r3_mirror_unchanged()

    def test_r4_protocol_pins_sources_r3_failure_and_unchanged_limits(self) -> None:
        p = self.protocol
        self.assertEqual((p["schema"], p["version"], p["classification"], p["runtime_grant"]),
                         ("mms-replay-only-continuation-protocol-v21", 21,
                          "test_only_continuation", False))
        rows = p["owned_source_files"]
        self.assertEqual(len(rows), 20)
        self.assertEqual(p["owned_source_files_by_path"],
                         {row["path"]: row["sha256"] for row in rows})
        static_test_rel = "test/RuntimeV4/UP2ClosureReplayOnlyV21/test_independent_static_v21.py"
        self.assertEqual((R4_HISTORICAL_TEST_PREIMAGE.stat().st_size,
                          sha256_file(R4_HISTORICAL_TEST_PREIMAGE)),
                         (R4_HISTORICAL_TEST_PREIMAGE_BYTES, R4_HISTORICAL_TEST_PREIMAGE_SHA256))
        self.assertEqual(p["owned_source_files_by_path"][static_test_rel],
                         R4_HISTORICAL_TEST_PREIMAGE_SHA256)
        for row in rows:
            historical = {
                static_test_rel: R4_HISTORICAL_TEST_PREIMAGE,
                "test/RuntimeV4/UP2ClosureReplayOnlyV21/run_replay_staged_v21.py": V21_CANONICAL_PREIMAGE,
                "test/RuntimeV4/UP2ClosureReplayOnlyV21/run_replay_staged_v21_r4.py": R4_HISTORICAL_RUNNER_PREIMAGE,
            }
            path = historical.get(row["path"],
                                  ROOT.joinpath(*PurePosixPath(row["path"]).parts))
            self.assertEqual(path.stat().st_size, row["bytes"], row["path"])
            self.assertEqual(sha256_file(path), row["sha256"], row["path"])
        for filename, expected_sha in R4_FILE_SHA256.items():
            path = (R4_HISTORICAL_RUNNER_PREIMAGE if filename == "run_replay_staged_v21_r4.py"
                    else HERE / filename)
            self.assertEqual(sha256_file(path), expected_sha, filename)
            self.assertEqual(p["owned_source_files_by_path"][
                f"test/RuntimeV4/UP2ClosureReplayOnlyV21/{filename}"], expected_sha)
        self.assertEqual(p["owned_source_files_by_path"][R4_ABSENCE_HELPER_REL],
                         R4_ABSENCE_HELPER_SHA256)
        absence = p["r4_historical_absent_output_slots"]
        self.assertEqual(absence["schema"], "mms-v21-r4-historical-absent-output-slots-v1")
        self.assertEqual((absence["classification"], absence["credit"]),
                         ("source_bound_historical_absence_test_only", "none"))
        self.assertEqual(absence["source_protocol"], {
            "path": R3_PROTOCOL.relative_to(ROOT).as_posix(),
            "bytes": 989227,
            "sha256": R3_PROTOCOL_SHA256,
        })
        self.assertEqual(absence["archive"], {
            "path": str(Path(r"D:\006-Programing\LMC\FusionConceptAI_cleanup_20260926\precleanup_docs_runs_tmp.zip")),
            "bytes": 472888641,
            "sha256": ARCHIVE_SHA256,
            "member_count_including_directories": 23151,
            "directory_member_count": 0,
            "windows_name_collision_groups": 0,
        })
        self.assertEqual(absence["source_mirror_root"], str(R3_MIRROR))
        self.assertEqual(absence["source_map_summary"], {
            "entries": 613, "referenced_paths": 645, "directory_prefixes": 31,
            "expected_absent": 1, "restored_entries": 0, "restored_directories": 0,
        })
        absence_slots = absence["slots"]
        expected_absence_slots = [
            ("v6-r6-runtime-replay", "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/replay_only_continuation_r6/runtime_replay_r6", 6),
            ("v9-r9-runtime-replay", "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/replay_only_continuation_r9/runtime_replay_r9", 9),
            ("v12-r12-runtime-replay", "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/replay_only_continuation_r12/runtime_replay_r12", 12),
            ("v13-r13-runtime-replay", "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/replay_only_continuation_r13/runtime_replay_r13", 13),
        ]
        self.assertEqual([(row["slot_id"], row["logical_path"], row["parent_version"])
                          for row in absence_slots], expected_absence_slots)
        self.assertEqual(sum(len(row["evidence"]) for row in absence_slots), 13)
        for row in absence_slots:
            self.assertTrue(row["workspace_target_absent_at_build"])
            self.assertTrue(row["r3_mirror_target_absent_at_build"])
            self.assertEqual(row["r3_map_overlap_count"], 0)
            self.assertEqual(row["archive_prefix_inventory"], {
                "exact_member_count_including_directories": 0,
                "descendant_member_count_including_directories": 0,
                "windows_alias_member_count": 0,
                "total_prefix_member_count": 0,
            })
        self.assertEqual(p["r4_checked_path_absence_route"], {
            "schema": "mms-v21-r4-historical-absent-output-route-v1",
            "helper_path": R4_ABSENCE_HELPER_REL,
            "helper_sha256": R4_ABSENCE_HELPER_SHA256,
            "fixed_slot_count": 4,
            "consumer": "original checked_path followed by the original real Path.exists assertion",
            "all_other_paths_use_original_checked_path": True,
            "materializes_archive_or_output_paths": False,
            "overrides_path_exists_or_is_file": False,
            "changes_v16_expected_absent_semantics": False,
            "changes_original_eight_source_overlays": False,
            "runtime_grant": False,
        })
        sidecar = p[R4_V9_SIDECAR_KEY]
        self.assertEqual((sidecar["schema"], sidecar["classification"], sidecar["credit"]),
                         (R4_V9_SIDECAR_SCHEMA,
                          "source_bound_v9_static_raw_sidecar_test_only", "none"))
        self.assertEqual(sidecar["source_protocol"], {
            "path": R3_PROTOCOL.relative_to(ROOT).as_posix(),
            "bytes": 989227,
            "sha256": R3_PROTOCOL_SHA256,
        })
        self.assertEqual(sidecar["archive"], absence["archive"])
        self.assertEqual(sidecar["v9_parent_protocol"], {
            "role": "v9_parent_protocol",
            "path": "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/"
                   "replay_only_continuation_r9/replay_protocol_v9.json",
            "bytes": 102476,
            "sha256": "37ecd51c875dbd71461c3ef71900c66cd30ae6a14a04e3a3e795e4bef8cb56dd",
        })
        self.assertEqual(sidecar["v9_static_receipt"], {
            "role": "v9_static_receipt",
            "path": "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/"
                   "replay_only_continuation_r9/static_contract_check_v9_r1/receipt.json",
            "bytes": 2135,
            "sha256": "36de483509879e3f0ce164783895b64fbaefa4def319d7b7be507c4a222e5cf2",
        })
        self.assertEqual(sidecar["source_mirror_root"], str(R3_MIRROR))
        self.assertEqual(sidecar["source_map_summary"], absence["source_map_summary"])
        sidecar_rows = sidecar["files"]
        self.assertEqual([(row["logical_path"], row["bytes"], row["sha256"])
                          for row in sidecar_rows], list(R4_V9_RAW_SIDECAR_FILES))
        archive_path = Path(sidecar["archive"]["path"])
        self.assertEqual(archive_path, Path(p["archived_input_source"]["archive_path"]))
        with zipfile.ZipFile(archive_path, "r") as archive:
            infos = archive.infolist()

            def normalized_member(name: str) -> str | None:
                parts: list[str] = []
                for component in name.replace("\\", "/").split("/"):
                    if component in ("", "."):
                        continue
                    if component == "..":
                        if not parts:
                            return None
                        parts.pop()
                        continue
                    component = component.rstrip(" .")
                    if not component:
                        return None
                    parts.append(component)
                return "/".join(parts).casefold() if parts else None

            for row in sidecar_rows:
                logical_path = row["logical_path"]
                exact = [info for info in infos if info.filename == logical_path]
                aliases = [info for info in infos
                           if normalized_member(info.filename) == logical_path.casefold()]
                self.assertEqual(len(exact), 1, logical_path)
                self.assertEqual(aliases, exact, logical_path)
                self.assertEqual((exact[0].file_size, f"{exact[0].CRC:08x}"),
                                 (row["bytes"], row["zip_crc32"]), logical_path)
                payload = archive.read(exact[0])
                self.assertEqual((len(payload), sha256(payload)),
                                 (row["bytes"], row["sha256"]), logical_path)
                self.assertEqual((row["zip_exact_file_member_count"],
                                  row["zip_windows_alias_member_count"],
                                  row["r3_map_overlap_count"],
                                  row["workspace_target_absent_at_build"],
                                  row["r3_mirror_target_absent_at_build"]), (1, 0, 0, True, True))
        self.assertEqual(p[R4_V9_SIDECAR_ROUTE_KEY], {
            "schema": "mms-v21-r4-v9-static-raw-sidecar-route-v1",
            "helper_path": R4_ABSENCE_HELPER_REL,
            "helper_sha256": R4_ABSENCE_HELPER_SHA256,
            "proof_key": R4_V9_SIDECAR_KEY,
            "proof_schema": R4_V9_SIDECAR_SCHEMA,
            "logical_paths": [path for path, _, _ in R4_V9_RAW_SIDECAR_FILES],
            "precedence": ["exact_three_v9_static_raw_sidecar",
                           "four_historical_absent_output_slots", "original_checked_path"],
            "nonmatching_paths": "existing_four_absence_route_then_original_checked_path",
            "changes_613_file_map": False,
            "changes_645_reference_set": False,
            "changes_31_directory_prefixes": False,
            "changes_four_absence_proofs": False,
            "changes_original_eight_source_overlays": False,
            "changes_runtime_grant": False,
            "runtime_grant": False,
        })
        v6_addendum = p[R4_V6_SCOPEFIX_KEY]
        self.assertEqual(v6_addendum["schema"], R4_V6_SCOPEFIX_SCHEMA)
        self.assertEqual((v6_addendum["classification"], v6_addendum["runtime_grant"],
                          v6_addendum["numerical_credit"], v6_addendum["physical_credit"]),
                         ("test_only_continuation", False, False, False))
        self.assertEqual(v6_addendum["manifest"], {
            "logical_path": R4_V6_SCOPEFIX_MANIFEST,
            "bytes": R4_V6_SCOPEFIX_MANIFEST_BYTES,
            "sha256": R4_V6_SCOPEFIX_MANIFEST_SHA256,
        })
        self.assertEqual(v6_addendum["archive"], {
            "path": str(Path(p["archived_input_source"]["archive_path"]).resolve()),
            "sha256": ARCHIVE_SHA256,
        })
        self.assertEqual(v6_addendum["parent_r3_protocol"], {
            "path": R3_PROTOCOL.relative_to(ROOT).as_posix(),
            "sha256": R3_PROTOCOL_SHA256,
        })
        self.assertEqual(v6_addendum["parent_v6_protocol"], {
            "path": R4_V6_PROTOCOL["path"], "sha256": R4_V6_PROTOCOL["sha256"],
        })
        base_contract = p["archived_input_source"]
        base_rows = base_contract["entries"]
        base_references = base_contract["referenced_paths"]
        base_prefixes = base_contract["directory_prefixes"]
        self.assertEqual(v6_addendum["base_map"], {
            "entries_count": 613,
            "entries_sha256": sha256(canonical_json_bytes(base_rows)),
            "referenced_paths_count": 645,
            "referenced_paths_sha256": sha256(canonical_json_bytes(base_references)),
            "directory_prefixes_count": 31,
            "directory_prefixes_sha256": sha256(canonical_json_bytes(base_prefixes)),
        })
        self.assertEqual(v6_addendum["row_count"], 5)
        self.assertEqual(set(v6_addendum), {
            "schema", "classification", "runtime_grant", "numerical_credit", "physical_credit",
            "manifest", "archive", "parent_r3_protocol", "parent_v6_protocol", "base_map",
            "row_count", "rows",
        })

        # Independently derive the exact manifest rows from the pinned ZIP bytes.
        # This checks physical line ordinals and raw-line hashes without trusting the builder helper.
        with zipfile.ZipFile(Path(base_contract["archive_path"]), "r") as archive:
            infos = archive.infolist()
            manifest_matches = [info for info in infos if info.filename == R4_V6_SCOPEFIX_MANIFEST]
            self.assertEqual(len(manifest_matches), 1)
            manifest_bytes = archive.read(manifest_matches[0])
            self.assertEqual((len(manifest_bytes), sha256(manifest_bytes)),
                             (R4_V6_SCOPEFIX_MANIFEST_BYTES, R4_V6_SCOPEFIX_MANIFEST_SHA256))
            manifest_lines = manifest_bytes.splitlines(keepends=True)
            self.assertEqual(len(manifest_lines), 34)
            target_pins = {path: (byte_count, digest)
                           for path, byte_count, digest in R4_V6_SCOPEFIX_FILES}
            independently_derived_rows = []
            independently_derived_all_rows = []
            for ordinal, raw_line in enumerate(manifest_lines, start=1):
                if raw_line.endswith(b"\r\n"):
                    raw_content = raw_line[:-2]
                elif raw_line.endswith(b"\n"):
                    raw_content = raw_line[:-1]
                else:
                    raw_content = raw_line
                fields = raw_content.decode("utf-8").split("  ", 2)
                self.assertEqual(len(fields), 3)
                digest, logical_path, byte_field = fields
                self.assertTrue(byte_field.startswith("bytes="))
                parsed_row = {
                    "manifest_ordinal": ordinal,
                    "logical_path": logical_path,
                    "archive_member": logical_path,
                    "bytes": int(byte_field.removeprefix("bytes=")),
                    "sha256": digest,
                    "manifest_row_sha256": sha256(raw_content),
                }
                independently_derived_all_rows.append(parsed_row)
                if logical_path in target_pins:
                    independently_derived_rows.append(parsed_row)
            self.assertEqual({(row["logical_path"], row["bytes"], row["sha256"])
                              for row in independently_derived_rows}, set(R4_V6_SCOPEFIX_FILES))
            expected_non_docs_rows = [
                (14, "test/RuntimeV4/UP2ClosureReplayOnlyV6/review_support/"
                     "independent_receipt_recheck_v1/recheck_v6_receipts.ps1", 3967,
                 "f13f6b8604efeb51dd9a967fe7a4847e2fe866430efdd48e352f5c3c6fa32647"),
                (23, "test/RuntimeV4/UP2ClosureReplayOnlyV6/replay_staged_v6.jl", 16820,
                 "22329280b2e0555d853a68a53a58dd2290fbcba21e8b65fb1b92eebb785183ad"),
                (24, "test/RuntimeV4/UP2ClosureReplayOnlyV6/run_replay_staged_v6.py", 40409,
                 "11c1ebd2d8bf897e8b96dcc87e1f97e11ad42759bc0ab72997e283090040f8c7"),
                (25, "test/RuntimeV4/UP2ClosureReplayOnlyV6/test_contract_v6.py", 16826,
                 "d694c1d49018c8004e4be0c1c44199b9d38c229ca8c0d862cb71f2cd5c5f5cb9"),
            ]
            actual_non_docs_rows = [
                (row["manifest_ordinal"], row["logical_path"], row["bytes"], row["sha256"])
                for row in independently_derived_all_rows if row["logical_path"].startswith("test/")
            ]
            self.assertEqual(actual_non_docs_rows, expected_non_docs_rows)
            builder_spec = importlib.util.spec_from_file_location(
                "up2_closure_v21_r4_static_builder", R4_BUILDER)
            if builder_spec is None or builder_spec.loader is None:
                raise RuntimeError("could not load the pinned R4 protocol builder parser")
            builder_module = importlib.util.module_from_spec(builder_spec)
            builder_spec.loader.exec_module(builder_module)
            self.assertEqual(builder_module._parse_v6_scopefix_manifest(manifest_bytes),
                             independently_derived_all_rows)
            self.assertEqual(self.runner_module._parse_v6_scopefix_manifest(manifest_bytes),
                             independently_derived_all_rows)

            v10_binding = p[R4_V10_PATH_BINDING_KEY]
            self.assertEqual(set(v10_binding), {
                "schema", "base_transformed_source_sha256", "replacement_count",
                "replacements", "transformed_source_sha256",
            })
            self.assertEqual(v10_binding, {
                "schema": R4_V10_PATH_BINDING_SCHEMA,
                "base_transformed_source_sha256": R4_V10_PATH_BINDING_BASE_SHA256,
                "replacement_count": 2,
                "replacements": R4_V10_PATH_BINDING_REPLACEMENTS,
                "transformed_source_sha256": R4_V10_PATH_BINDING_FINAL_SHA256,
            })
            self.assertEqual(v10_binding["base_transformed_source_sha256"],
                             p["r4_controller_overlay"]["transformed_source_sha256"])
            original_source = self.runner_module._read_pinned(
                self.runner_module.ORIGINAL_CONTROLLER,
                self.runner_module.ORIGINAL_CONTROLLER_SHA256,
                "original controller for the V10 path-binding test")
            eight_overlay_source = self.runner_module._apply_exact_line_overlay(
                original_source, self.runner_module._load_spec())
            self.assertEqual(sha256(eight_overlay_source), R4_V10_PATH_BINDING_BASE_SHA256)
            final_source = self.runner_module._apply_r4_v10_path_binding_addendum(
                eight_overlay_source, v10_binding)
            self.assertEqual((len(final_source), sha256(final_source)),
                             (308106, R4_V10_PATH_BINDING_FINAL_SHA256))
            self.assertEqual(self.controller.R4_TRANSFORMED_CONTROLLER_SOURCE.encode("utf-8"),
                             final_source)
            self.assertEqual(v10_binding["replacement_count"], len(v10_binding["replacements"]))

            invalid_bindings = []
            wrong_base = copy.deepcopy(v10_binding)
            wrong_base["base_transformed_source_sha256"] = "0" * 64
            invalid_bindings.append(("base sha", wrong_base, eight_overlay_source))
            wrong_replacements = copy.deepcopy(v10_binding)
            wrong_replacements["replacements"][0]["old_line"] += " "
            invalid_bindings.append(("replacement source line", wrong_replacements,
                                     eight_overlay_source))
            wrong_source = copy.deepcopy(v10_binding)
            wrong_source["transformed_source_sha256"] = "0" * 64
            invalid_bindings.append(("transformed sha", wrong_source, eight_overlay_source))
            invalid_bindings.append(("base bytes", v10_binding, eight_overlay_source + b"x"))
            for label, invalid, source_bytes in invalid_bindings:
                with self.subTest(v10_binding_negative=label), self.assertRaisesRegex(
                        ValueError, "R4 V10 recorded-path addendum"):
                    self.runner_module._apply_r4_v10_path_binding_addendum(source_bytes, invalid)
            self.assertEqual(v6_addendum["rows"], independently_derived_rows)
            self.assertEqual([set(row) for row in v6_addendum["rows"]], [{
                "manifest_ordinal", "logical_path", "archive_member", "bytes", "sha256",
                "manifest_row_sha256",
            }] * 5)

            def normalize_v6_member(name: str) -> str | None:
                parts: list[str] = []
                for component in name.replace("\\", "/").split("/"):
                    if component in ("", "."):
                        continue
                    if component == "..":
                        if not parts:
                            return None
                        parts.pop()
                        continue
                    component = component.rstrip(" .")
                    if not component:
                        return None
                    parts.append(component)
                return "/".join(parts).casefold() if parts else None

            existing_paths = [row["logical_path"] for key in
                              ("entries", "referenced_paths", "directory_prefixes",
                               "expected_absent", "restored_entries", "restored_directories")
                              for row in base_contract.get(key, [])]
            existing_folded = {path.casefold() for path in existing_paths}
            for row in v6_addendum["rows"]:
                logical_path = row["logical_path"]
                folded = logical_path.casefold()
                self.assertNotIn(folded, existing_folded)
                for prefix in base_contract["directory_prefixes"]:
                    prefix_path = prefix["logical_path"].rstrip("/").casefold()
                    self.assertFalse(folded == prefix_path or folded.startswith(prefix_path + "/"))
                exact = [info for info in infos if info.filename == logical_path]
                aliases = [info for info in infos if normalize_v6_member(info.filename) == folded]
                self.assertEqual(len(exact), 1, logical_path)
                self.assertEqual(aliases, exact, logical_path)
                self.assertFalse(any((normalized := normalize_v6_member(info.filename)) is not None and
                                     normalized.startswith(folded + "/") for info in infos), logical_path)
                self.assertEqual(archive.read(exact[0]), archive.read(logical_path))
                workspace_file = ROOT.joinpath(*PurePosixPath(logical_path).parts)
                r3_file = R3_MIRROR.joinpath(*PurePosixPath(logical_path).parts)
                self.assertFalse(workspace_file.exists())
                self.assertFalse(r3_file.exists())

            validated_addendum = self.runner_module._validate_v6_scopefix_closure_addendum(
                p, root=ROOT, archive=archive)
            self.assertEqual(validated_addendum["proof"], v6_addendum)
            self.assertEqual(validated_addendum["rows"], independently_derived_rows)
            self.assertEqual({path: (len(payload), sha256(payload))
                              for path, payload in validated_addendum["payloads"].items()},
                             {path: (byte_count, digest)
                              for path, byte_count, digest in R4_V6_SCOPEFIX_FILES})

            def reject_v6_addendum(mutated: dict, *, root: Path = ROOT) -> None:
                with self.assertRaisesRegex(ValueError, "R4 V6 scopefix addendum"):
                    self.runner_module._validate_v6_scopefix_closure_addendum(
                        mutated, root=root, archive=archive)

            for index in range(5):
                missing = copy.deepcopy(p)
                missing[R4_V6_SCOPEFIX_KEY]["rows"].pop(index)
                with self.subTest(v6_addendum_mutation=f"missing_row_{index}"):
                    reject_v6_addendum(missing)
            extra = copy.deepcopy(p)
            extra[R4_V6_SCOPEFIX_KEY]["rows"].append(
                copy.deepcopy(extra[R4_V6_SCOPEFIX_KEY]["rows"][0]))
            with self.assertRaisesRegex(ValueError, "R4 V6 scopefix addendum"):
                self.runner_module._validate_v6_scopefix_closure_addendum(
                    extra, root=ROOT, archive=archive)
            for mutation in ("duplicate", "path", "member", "size", "sha256", "ordinal", "raw_row_sha"):
                changed = copy.deepcopy(p)
                row = changed[R4_V6_SCOPEFIX_KEY]["rows"][0]
                if mutation == "duplicate":
                    changed[R4_V6_SCOPEFIX_KEY]["rows"][1] = copy.deepcopy(row)
                elif mutation == "path":
                    row["logical_path"] = "../outside/scope_violation.md"
                elif mutation == "member":
                    row["archive_member"] = "../outside/scope_violation.md"
                elif mutation == "size":
                    row["bytes"] += 1
                elif mutation == "sha256":
                    row["sha256"] = "0" * 64
                elif mutation == "ordinal":
                    row["manifest_ordinal"] += 1
                else:
                    row["manifest_row_sha256"] = "0" * 64
                with self.subTest(v6_addendum_mutation=mutation):
                    reject_v6_addendum(changed)
            for mutation in ("manifest_path", "manifest_size", "manifest_sha", "archive_path",
                             "archive_sha", "r3_parent", "v6_parent", "parent_v6_path",
                             "parent_v6_sha", "entries_digest", "references_digest",
                             "prefix_digest", "row_count"):
                changed = copy.deepcopy(p)
                proof = changed[R4_V6_SCOPEFIX_KEY]
                if mutation == "manifest_path":
                    proof["manifest"]["logical_path"] = "docs/escape/SHA256SUMS.txt"
                elif mutation == "manifest_size":
                    proof["manifest"]["bytes"] += 1
                elif mutation == "manifest_sha":
                    proof["manifest"]["sha256"] = "0" * 64
                elif mutation == "archive_path":
                    proof["archive"]["path"] = str(ROOT.parent / "other_archive.zip")
                elif mutation == "archive_sha":
                    proof["archive"]["sha256"] = "0" * 64
                elif mutation == "r3_parent":
                    proof["parent_r3_protocol"]["sha256"] = "0" * 64
                elif mutation == "v6_parent":
                    proof["parent_v6_protocol"]["sha256"] = "0" * 64
                elif mutation == "parent_v6_path":
                    changed["parent_v6_protocol"]["path"] = "docs/escape/replay_protocol_v6.json"
                elif mutation == "parent_v6_sha":
                    changed["parent_v6_protocol"]["sha256"] = "0" * 64
                elif mutation == "entries_digest":
                    proof["base_map"]["entries_sha256"] = "0" * 64
                elif mutation == "references_digest":
                    proof["base_map"]["referenced_paths_sha256"] = "0" * 64
                elif mutation == "prefix_digest":
                    proof["base_map"]["directory_prefixes_sha256"] = "0" * 64
                else:
                    proof["row_count"] = 6
                with self.subTest(v6_addendum_mutation=mutation):
                    reject_v6_addendum(changed)
            target_path = R4_V6_SCOPEFIX_FILES[0][0]
            target_parent = target_path.rsplit("/", 1)[0]
            overlap_variants = (
                ("exact", target_path),
                ("case_alias", target_path.swapcase()),
                ("entry_ancestor", target_parent),
                ("entry_descendant", target_path + "/child.txt"),
            )
            for label, overlapping_path in overlap_variants:
                overlap = copy.deepcopy(p)
                overlap["archived_input_source"]["entries"][0]["logical_path"] = overlapping_path
                overlap[R4_V6_SCOPEFIX_KEY]["base_map"]["entries_sha256"] = sha256(
                    canonical_json_bytes(overlap["archived_input_source"]["entries"]))
                with self.subTest(v6_addendum_mutation=f"base_map_{label}"):
                    with self.assertRaisesRegex(ValueError, "R4 V6 scopefix addendum path overlaps"):
                        self.runner_module._validate_v6_scopefix_closure_addendum(
                            overlap, root=ROOT, archive=archive)
            with self.assertRaisesRegex(ValueError, "R4 V6 scopefix addendum"):
                self.runner_module._validate_v6_scopefix_closure_addendum(
                    p, root=ROOT.parent, archive=archive)

        v6_route = p[R4_V6_SCOPEFIX_ROUTE_KEY]
        self.assertEqual((v6_route["schema"], v6_route["proof_key"], v6_route["proof_schema"]),
                         (R4_V6_SCOPEFIX_ROUTE_SCHEMA, R4_V6_SCOPEFIX_KEY, R4_V6_SCOPEFIX_SCHEMA))
        self.assertEqual(v6_route["logical_paths"], [path for path, _, _ in R4_V6_SCOPEFIX_FILES])
        self.assertEqual(v6_route["precedence"], [
            "exact_three_v9_static_raw_sidecar", "four_historical_absent_output_slots",
            "exact_613_absolute_archive_file_alias", "exact_five_v6_scopefix_addendum",
            "exact_five_v10_root_observation_addendum",
            "original_checked_path",
        ])
        self.assertEqual(v6_route["nonmatching_paths"],
                         "existing V9 sidecar, four absence, 613 exact aliases, V6 and V10 addenda, then original checked_path")
        self.assertEqual(Path(v6_route["materialization_root"]).resolve(),
                         Path(p["r4_output_ownership"]["archive_mirror_root"]).resolve())
        for flag in ("exact_relative_paths_only", "materializes_only_addendum_rows"):
            self.assertIs(v6_route[flag], True)
        for flag in ("absolute_addendum_aliases", "materializes_inside_repository_docs",
                     "changes_613_file_map", "changes_645_reference_set", "changes_31_directory_prefixes",
                     "changes_four_absence_proofs", "changes_v15_or_v16_evidence",
                     "changes_original_eight_source_overlays", "numerical_credit", "physical_credit",
                     "runtime_grant"):
            self.assertIs(v6_route[flag], False)

        v10_addendum = p[R4_V10_ROOT_OBSERVATION_ADDENDUM_KEY]
        self.assertEqual(set(v10_addendum), {
            "schema", "classification", "runtime_grant", "numerical_credit", "physical_credit",
            "archive", "parent_review_manifest", "root_observation", "base_map", "row_count", "rows",
        })
        self.assertEqual((v10_addendum["schema"], v10_addendum["classification"],
                          v10_addendum["runtime_grant"], v10_addendum["numerical_credit"],
                          v10_addendum["physical_credit"]),
                         (R4_V10_ROOT_OBSERVATION_ADDENDUM_SCHEMA, "test_only_continuation",
                          False, False, False))
        self.assertEqual(v10_addendum["archive"], {
            "path": str(Path(p["archived_input_source"]["archive_path"]).resolve()),
            "sha256": ARCHIVE_SHA256,
        })
        self.assertEqual(v10_addendum["parent_review_manifest"], {
            "logical_path": V10_REVIEW_MANIFEST_REL,
            "bytes": V10_REVIEW_MANIFEST_BYTES,
            "sha256": V10_REVIEW_MANIFEST_SHA256,
        })
        self.assertEqual(v10_addendum["root_observation"], {
            "logical_path": V10_ROOT_OBSERVATION_PATH,
            "bytes": V10_ROOT_OBSERVATION_BYTES,
            "sha256": V10_ROOT_OBSERVATION_SHA256,
        })
        self.assertEqual(v10_addendum["base_map"], v6_addendum["base_map"])
        self.assertEqual(v10_addendum["row_count"], 5)
        self.assertEqual(p["parent_v10_independent_postrun_review"]["manifest_path"],
                         V10_REVIEW_MANIFEST_REL)
        self.assertEqual(p["parent_v10_independent_postrun_review"]["manifest_sha256"],
                         V10_REVIEW_MANIFEST_SHA256)

        expected_v10_files = [(path, size, digest)
                              for path, size, digest, _, _, _, _ in R4_V10_ROOT_OBSERVATION_FILES]
        self.assertEqual(len(R4_V10_ROOT_OBSERVATION_FILES), 5)
        self.assertEqual(len({path for path, _, _ in expected_v10_files}), 5)
        self.assertTrue(set(path for path, _, _ in expected_v10_files).isdisjoint(
            {path for path, _, _ in R4_V9_RAW_SIDECAR_FILES}))
        self.assertTrue(set(path for path, _, _ in expected_v10_files).isdisjoint(
            {path for path, _, _ in R4_V6_SCOPEFIX_FILES}))
        v10_route = p[R4_V10_ROOT_OBSERVATION_ROUTE_KEY]
        self.assertEqual(v10_route, {
            "schema": R4_V10_ROOT_OBSERVATION_ROUTE_SCHEMA,
            "proof_key": R4_V10_ROOT_OBSERVATION_ADDENDUM_KEY,
            "proof_schema": R4_V10_ROOT_OBSERVATION_ADDENDUM_SCHEMA,
            "logical_paths": [path for path, _, _ in expected_v10_files],
            "precedence": ["exact_three_v9_static_raw_sidecar", "four_historical_absent_output_slots",
                           "exact_613_absolute_archive_file_alias", "exact_five_v6_scopefix_addendum",
                           "exact_five_v10_root_observation_addendum", "original_checked_path"],
            "nonmatching_paths": "existing V9 sidecar, four absence, 613 exact aliases, V6 and V10 addenda, then original checked_path",
            "exact_relative_paths_only": True,
            "absolute_addendum_aliases": False,
            "materialization_root": p["archived_input_source"]["staging_root"],
            "materializes_only_addendum_rows": True,
            "materializes_inside_repository_docs": False,
            "changes_613_file_map": False,
            "changes_645_reference_set": False,
            "changes_31_directory_prefixes": False,
            "changes_four_absence_proofs": False,
            "changes_v15_or_v16_evidence": False,
            "changes_original_eight_source_overlays": False,
            "numerical_credit": False,
            "physical_credit": False,
            "runtime_grant": False,
        })

        def collect_protocol_paths(value: object) -> set[str]:
            found: set[str] = set()
            if isinstance(value, str):
                if value.startswith(("docs/", "test/")):
                    found.add(value)
            elif isinstance(value, dict):
                logical = value.get("logical_path")
                if isinstance(logical, str):
                    found.add(logical)
                for child in value.values():
                    found.update(collect_protocol_paths(child))
            elif isinstance(value, (list, tuple)):
                for child in value:
                    found.update(collect_protocol_paths(child))
            return found

        closure_paths: set[str] = set()
        for key in ("entries", "referenced_paths", "directory_prefixes", "expected_absent",
                    "restored_entries", "restored_directories"):
            closure_paths.update(collect_protocol_paths(p["archived_input_source"].get(key, [])))
        for key in ("r4_historical_absent_output_slots", R4_V9_SIDECAR_KEY, R4_V6_SCOPEFIX_KEY):
            closure_paths.update(collect_protocol_paths(p.get(key)))
        folded_closure = {path.rstrip("/").casefold() for path in closure_paths}
        for logical_path, _, _ in expected_v10_files:
            folded = logical_path.casefold()
            self.assertFalse(any(folded == path or folded.startswith(path + "/") or
                                 path.startswith(folded + "/") for path in folded_closure), logical_path)
            for prefix in p["archived_input_source"]["directory_prefixes"]:
                prefix_path = prefix["logical_path"].rstrip("/").casefold()
                self.assertFalse(folded == prefix_path or folded.startswith(prefix_path + "/") or
                                 prefix_path.startswith(folded + "/"), logical_path)
            self.assertFalse(ROOT.joinpath(*PurePosixPath(logical_path).parts).exists(), logical_path)
            self.assertFalse(R3_MIRROR.joinpath(*PurePosixPath(logical_path).parts).exists(), logical_path)

        def source_pointer_value(document: dict, pointer: str) -> object:
            self.assertTrue(pointer.startswith("/"))
            value: object = document
            for raw_token in pointer[1:].split("/"):
                token = raw_token.replace("~1", "/").replace("~0", "~")
                self.assertIsInstance(value, dict)
                value = value[token]
            return value

        with zipfile.ZipFile(Path(p["archived_input_source"]["archive_path"]), "r") as v10_archive:
            v10_infos = v10_archive.infolist()

            def read_v10_exact_member(logical_path: str, byte_count: int, expected_sha: str) -> bytes:
                exact = [info for info in v10_infos if info.filename == logical_path and not info.is_dir()]
                aliases = [info for info in v10_infos if info.filename.casefold() == logical_path.casefold()]
                self.assertEqual(len(exact), 1, logical_path)
                self.assertEqual(aliases, exact, logical_path)
                self.assertFalse(any(info.filename.replace("\\", "/").rstrip("/").casefold().startswith(
                    logical_path.casefold() + "/") for info in v10_infos), logical_path)
                payload = v10_archive.read(exact[0])
                self.assertEqual((len(payload), sha256(payload)), (byte_count, expected_sha), logical_path)
                return payload

            manifest_wire = read_v10_exact_member(
                V10_REVIEW_MANIFEST_REL, V10_REVIEW_MANIFEST_BYTES, V10_REVIEW_MANIFEST_SHA256)
            observation_wire = read_v10_exact_member(
                V10_ROOT_OBSERVATION_PATH, V10_ROOT_OBSERVATION_BYTES, V10_ROOT_OBSERVATION_SHA256)
            review_manifest = json.loads(manifest_wire)
            observation = json.loads(observation_wire)
            documents = {V10_REVIEW_MANIFEST_REL: review_manifest,
                         V10_ROOT_OBSERVATION_PATH: observation}
            independent_rows = []
            for logical, byte_count, expected_sha, source_path, source_bytes, source_sha, pointer \
                    in R4_V10_ROOT_OBSERVATION_FILES:
                payload = read_v10_exact_member(logical, byte_count, expected_sha)
                source_node = source_pointer_value(documents[source_path], pointer)
                self.assertIsInstance(source_node, dict)
                if pointer == "/root_observation":
                    # The pinned review manifest declares the observation by path+SHA only.
                    # Its byte count belongs to the independently pinned ZIP member, not this object.
                    self.assertEqual(set(source_node), {"path", "sha256"})
                    self.assertIs(type(source_node["path"]), str)
                    self.assertIs(type(source_node["sha256"]), str)
                    self.assertNotIn("bytes", source_node)
                    self.assertEqual((source_node["path"], source_node["sha256"]),
                                     (logical, expected_sha))
                else:
                    self.assertEqual(set(source_node), {"relative_path", "bytes", "sha256"})
                    self.assertIs(type(source_node["relative_path"]), str)
                    self.assertIs(type(source_node["bytes"]), int)
                    self.assertIs(type(source_node["sha256"]), str)
                    self.assertEqual((source_node["relative_path"], source_node["bytes"],
                                      source_node["sha256"]), (logical, byte_count, expected_sha))
                independent_rows.append({
                    "logical_path": logical, "archive_member": logical, "bytes": byte_count,
                    "sha256": expected_sha, "source_document_path": source_path,
                    "source_document_bytes": source_bytes, "source_document_sha256": source_sha,
                    "source_json_pointer": pointer,
                })
                self.assertEqual((len(payload), sha256(payload)), (byte_count, expected_sha))
            self.assertEqual(v10_addendum["rows"], independent_rows)

            self.assertEqual(builder_module._v10_root_observation_rows(review_manifest, observation),
                             independent_rows)
            self.assertEqual(self.runner_module._v10_root_observation_rows(review_manifest, observation),
                             independent_rows)

            for mutation in ("missing_path", "missing_sha256", "extra_bytes", "wrong_path", "wrong_sha256"):
                changed_manifest = copy.deepcopy(review_manifest)
                root_row = changed_manifest["root_observation"]
                if mutation == "missing_path":
                    del root_row["path"]
                elif mutation == "missing_sha256":
                    del root_row["sha256"]
                elif mutation == "extra_bytes":
                    root_row["bytes"] = V10_ROOT_OBSERVATION_BYTES
                elif mutation == "wrong_path":
                    root_row["path"] = "docs/implementation/observation.json"
                else:
                    root_row["sha256"] = "0" * 64
                with self.subTest(v10_parent_declaration_mutation=mutation):
                    with self.assertRaisesRegex(ValueError, "R4 V10"):
                        builder_module._v10_root_observation_rows(changed_manifest, observation)

            for mutation in ("missing_path", "missing_sha256", "extra_bytes", "wrong_path", "wrong_sha256"):
                changed_manifest = copy.deepcopy(review_manifest)
                root_row = changed_manifest["root_observation"]
                if mutation == "missing_path":
                    del root_row["path"]
                elif mutation == "missing_sha256":
                    del root_row["sha256"]
                elif mutation == "extra_bytes":
                    root_row["bytes"] = V10_ROOT_OBSERVATION_BYTES
                elif mutation == "wrong_path":
                    root_row["path"] = "docs/implementation/observation.json"
                else:
                    root_row["sha256"] = "0" * 64
                with self.subTest(v10_wrapper_parent_declaration_mutation=mutation):
                    with self.assertRaisesRegex(ValueError, "R4 V10"):
                        self.runner_module._v10_root_observation_rows(changed_manifest, observation)

            observation_mutations = (
                ("grant_missing_bytes", "/grant"),
                ("grant_extra_field", "/grant"),
                ("grant_wrong_sha256", "/grant"),
                ("exit_missing_bytes", "/controller_sidecars/controller.exit.txt"),
                ("stderr_boolean_bytes", "/controller_sidecars/controller.stderr.raw"),
                ("stderr_string_bytes", "/controller_sidecars/controller.stderr.raw"),
                ("stdout_missing_path", "/controller_sidecars/controller.stdout.raw"),
                ("stdout_wrong_sha256", "/controller_sidecars/controller.stdout.raw"),
            )
            for mutation, pointer in observation_mutations:
                changed_observation = copy.deepcopy(observation)
                source_node = source_pointer_value(changed_observation, pointer)
                if mutation == "grant_missing_bytes":
                    del source_node["bytes"]
                elif mutation == "grant_extra_field":
                    source_node["unexpected"] = "not-pinned"
                elif mutation == "grant_wrong_sha256":
                    source_node["sha256"] = "0" * 64
                elif mutation == "exit_missing_bytes":
                    del source_node["bytes"]
                elif mutation == "stderr_boolean_bytes":
                    source_node["bytes"] = False
                elif mutation == "stderr_string_bytes":
                    source_node["bytes"] = "0"
                elif mutation == "stdout_missing_path":
                    del source_node["relative_path"]
                else:
                    source_node["sha256"] = "0" * 64
                with self.subTest(v10_observation_declaration_mutation=mutation):
                    with self.assertRaisesRegex(ValueError, "R4 V10"):
                        builder_module._v10_root_observation_rows(review_manifest, changed_observation)
                    with self.assertRaisesRegex(ValueError, "R4 V10"):
                        self.runner_module._v10_root_observation_rows(review_manifest, changed_observation)

            validated_v10 = self.runner_module._validate_v10_root_observation_input_addendum(
                p, root=ROOT, archive=v10_archive)
            self.assertEqual(validated_v10["proof"], v10_addendum)
            self.assertEqual(validated_v10["rows"], independent_rows)
            self.assertEqual({path: (len(payload), sha256(payload))
                              for path, payload in validated_v10["payloads"].items()},
                             {path: (byte_count, digest)
                              for path, byte_count, digest in expected_v10_files})
            self.assertEqual(builder_module.build_v10_root_observation_input_addendum(p), v10_addendum)

            def reject_v10_addendum(mutated: dict, *, root: Path = ROOT) -> None:
                with self.assertRaisesRegex(ValueError, "R4 V10"):
                    self.runner_module._validate_v10_root_observation_input_addendum(
                        mutated, root=root, archive=v10_archive)

            for index in range(5):
                missing = copy.deepcopy(p)
                missing[R4_V10_ROOT_OBSERVATION_ADDENDUM_KEY]["rows"].pop(index)
                with self.subTest(v10_addendum_mutation=f"missing_row_{index}"):
                    reject_v10_addendum(missing)
            for mutation in ("extra", "duplicate", "path", "member", "size", "sha256",
                             "boolean_zero_size", "source_path", "source_bytes", "source_sha256",
                             "source_pointer"):
                changed = copy.deepcopy(p)
                rows = changed[R4_V10_ROOT_OBSERVATION_ADDENDUM_KEY]["rows"]
                if mutation == "extra":
                    rows.append(copy.deepcopy(rows[0]))
                elif mutation == "duplicate":
                    rows[1] = copy.deepcopy(rows[0])
                elif mutation == "path":
                    rows[0]["logical_path"] = "../outside/observation.json"
                elif mutation == "member":
                    rows[0]["archive_member"] = "../outside/observation.json"
                elif mutation == "size":
                    rows[0]["bytes"] += 1
                elif mutation == "boolean_zero_size":
                    rows[3]["bytes"] = False
                elif mutation == "sha256":
                    rows[0]["sha256"] = "0" * 64
                elif mutation == "source_path":
                    rows[0]["source_document_path"] = "docs/escape/review_manifest.json"
                elif mutation == "source_bytes":
                    rows[1]["source_document_bytes"] += 1
                elif mutation == "source_sha256":
                    rows[1]["source_document_sha256"] = "0" * 64
                else:
                    rows[2]["source_json_pointer"] = "/controller_sidecars/wrong.txt"
                with self.subTest(v10_addendum_mutation=mutation):
                    reject_v10_addendum(changed)
            for mutation in ("archive_path", "archive_sha", "manifest_path", "manifest_sha",
                             "observation_path", "observation_sha", "parent_manifest_sha",
                             "entries_digest", "references_digest", "prefix_digest", "row_count",
                             "route_paths", "route_stage", "runtime_grant"):
                changed = copy.deepcopy(p)
                proof = changed[R4_V10_ROOT_OBSERVATION_ADDENDUM_KEY]
                if mutation == "archive_path":
                    proof["archive"]["path"] = str(ROOT.parent / "wrong_archive.zip")
                elif mutation == "archive_sha":
                    proof["archive"]["sha256"] = "0" * 64
                elif mutation == "manifest_path":
                    proof["parent_review_manifest"]["logical_path"] = "docs/escape/review_manifest.json"
                elif mutation == "manifest_sha":
                    proof["parent_review_manifest"]["sha256"] = "0" * 64
                elif mutation == "observation_path":
                    proof["root_observation"]["logical_path"] = "docs/escape/observation.json"
                elif mutation == "observation_sha":
                    proof["root_observation"]["sha256"] = "0" * 64
                elif mutation == "parent_manifest_sha":
                    changed["parent_v10_independent_postrun_review"]["manifest_sha256"] = "0" * 64
                elif mutation == "entries_digest":
                    proof["base_map"]["entries_sha256"] = "0" * 64
                elif mutation == "references_digest":
                    proof["base_map"]["referenced_paths_sha256"] = "0" * 64
                elif mutation == "prefix_digest":
                    proof["base_map"]["directory_prefixes_sha256"] = "0" * 64
                elif mutation == "row_count":
                    proof["row_count"] = 4
                elif mutation == "route_paths":
                    changed[R4_V10_ROOT_OBSERVATION_ROUTE_KEY]["logical_paths"].pop()
                elif mutation == "route_stage":
                    changed[R4_V10_ROOT_OBSERVATION_ROUTE_KEY]["materialization_root"] = str(ROOT / "docs")
                else:
                    proof["runtime_grant"] = True
                with self.subTest(v10_addendum_mutation=mutation):
                    reject_v10_addendum(changed)
            with self.assertRaisesRegex(ValueError, "R4 V10"):
                self.runner_module._validate_v10_root_observation_input_addendum(
                    p, root=ROOT.parent, archive=v10_archive)

            legacy_audit = {
                "v10_inputs_verified": 89, "v10_docs_inputs": 18, "v10_workspace_inputs": 71,
                "archive_rows_verified": 613, "archive_bytes_verified": 31564478,
                "directory_prefixes_verified": 31, "materialization_started": False,
            }
            carrier = self.runner_module._R4PreMirrorAudit(legacy_audit, validated_addendum, validated_v10)
            self.assertEqual(dict(carrier), legacy_audit)
            self.assertEqual(json.loads(json.dumps(carrier)), legacy_audit)
            self.assertIsNone(carrier.get(R4_V10_ROOT_OBSERVATION_ADDENDUM_KEY))
            self.assertEqual(carrier._validated_v10_addendum, validated_v10)

        mapped_rows = p["archived_input_source"]["entries"]
        self.assertEqual(p[R4_ABSOLUTE_ARCHIVE_ROUTE_KEY], {
            "schema": R4_ABSOLUTE_ARCHIVE_ROUTE_SCHEMA,
            "repository_root": str(ROOT),
            "mapped_file_count": 613,
            "mapped_rows_sha256": sha256(canonical_json_bytes(mapped_rows)),
            "mapping_rule": "exact root plus canonical logical file path; separator normalization only",
            "consumer": "original checked_path and original ArchivedInputResolver size/SHA checks",
            "changes_613_file_map": False,
            "changes_v15_evidence": False,
            "changes_four_absence_or_three_sidecar_routes": False,
            "runtime_grant": False,
        })
        builder_text = R4_BUILDER.read_text(encoding="utf-8")
        match = re.search(r'^R4_TEST_SHA256 = "([0-9a-f]{64})"$', builder_text, re.MULTILINE)
        self.assertIsNotNone(match, "R4 builder must keep a single one-way pin to the frozen test bytes")
        self.assertEqual(match.group(1), R4_HISTORICAL_TEST_PREIMAGE_SHA256)
        self.assertEqual(p["owned_source_files_by_path"][
            "test/RuntimeV4/UP2ClosureReplayOnlyV21/build_protocol_v21_r4.py"],
            sha256_file(R4_BUILDER))

        self.assertEqual(p["controller"],
                         "test/RuntimeV4/UP2ClosureReplayOnlyV21/run_replay_staged_v21_r4.py")
        self.assertEqual(p["entrypoint"],
                         "test/RuntimeV4/UP2ClosureReplayOnlyV21/replay_staged_v21_r4.jl")
        self.assertEqual(Path(p["output_leaf"]).resolve(), R4_OUTPUT_LEAF.resolve())
        self.assertEqual(Path(p["archived_input_source"]["staging_root"]).resolve(), R4_MIRROR.resolve())
        self.assertEqual((len(p["archived_input_source"]["entries"]),
                          len(p["archived_input_source"]["referenced_paths"]),
                          len(p["archived_input_source"]["directory_prefixes"])), (613, 645, 31))
        self.assertEqual(p["parent_r2_protocol"]["sha256"], R2_PROTOCOL_SHA256)
        parent_r3 = p["parent_r3_protocol"]
        self.assertEqual((parent_r3["path"], parent_r3["bytes"], parent_r3["sha256"]),
                         ("test/RuntimeV4/UP2ClosureReplayOnlyV21/replay_protocol_v21_r3.json",
                          989227, R3_PROTOCOL_SHA256))
        self.assertIs(parent_r3["R3_run_no_credit"], True)
        self.assertEqual(parent_r3["actual_run_ancestry"], {
            "protocol_path": "test/RuntimeV4/UP2ClosureReplayOnlyV21/replay_protocol_v21_r3.json",
            "protocol_bytes": 989227,
            "protocol_sha256": R3_PROTOCOL_SHA256,
            "actual_failure_receipt_path": R3_ACTUAL_EXIT_RECEIPT_REL,
            "actual_failure_receipt_bytes": 1958,
            "actual_failure_receipt_sha256": R3_ACTUAL_EXIT_RECEIPT_SHA256,
            "actual_failure_stderr_path": "runs/UP2ClosureReplayOnlyV21/runtime_launcher_r21_r3_20260926_r1/stderr.raw",
            "actual_failure_stderr_bytes": 1228,
            "actual_failure_stderr_sha256": "ecf6ce659d814cdf9dda764f00142a40f67c0cda072a4577355664d841bb80ed",
            "static_suite_receipt_path": R3_STATIC_EXIT_RECEIPT_REL,
            "static_suite_receipt_bytes": R3_STATIC_EXIT_RECEIPT_BYTES,
            "static_suite_receipt_sha256": R3_STATIC_EXIT_RECEIPT_SHA256,
            "static_suite_stderr_path": "runs/UP2ClosureReplayOnlyV21/runtime_launcher_r21_r3_static_qa_20260926_r3/stderr.raw",
            "static_suite_stderr_bytes": 1795,
            "static_suite_stderr_sha256": "a536c48133978dca3572b33186956fac6a4e3fcd87a0d1d1cc5a6931cda0c7ad",
            "static_suite_tests_passed": 10,
            "raw_manifest_path": R3_RAW_MANIFEST_REL,
            "raw_manifest_sha256": R3_RAW_MANIFEST_SHA256,
            "source_snapshot_manifest_path": R3_SOURCE_SNAPSHOT_MANIFEST_REL,
            "source_snapshot_manifest_sha256": R3_SOURCE_SNAPSHOT_MANIFEST_SHA256,
            "executed_test_snapshot_path": R3_TEST_SNAPSHOT_REL,
            "executed_test_snapshot_bytes": R3_TEST_SNAPSHOT_BYTES,
            "executed_test_snapshot_sha256": R3_TEST_SNAPSHOT_SHA256,
            "actual_child_os_exit_code": 1,
            "julia_started": False,
            "raw_failure_outputs_untouched": True,
        })
        self.assertEqual(parent_r3["mirror_preservation"], {
            "root": str(R3_MIRROR.resolve()), "file_count": 613, "bytes": 31564478,
            "directory_prefix_count": 31, "referenced_path_count": 645,
        })
        self.assertEqual(parent_r3["prior_r2_mirror_preservation"], {
            "root": str(R2_MIRROR.resolve()), "file_count": 613, "bytes": 31564478,
            "directory_prefix_count": 31, "referenced_path_count": 645,
        })
        self.assertEqual((sha256_file(R3_TEST_SNAPSHOT), R3_TEST_SNAPSHOT.stat().st_size),
                         (R3_TEST_SNAPSHOT_SHA256, R3_TEST_SNAPSHOT_BYTES))
        self.assertEqual((R3_SOURCE_SNAPSHOT_MANIFEST.stat().st_size,
                          sha256_file(R3_SOURCE_SNAPSHOT_MANIFEST)),
                         (R3_SOURCE_SNAPSHOT_MANIFEST_BYTES, R3_SOURCE_SNAPSHOT_MANIFEST_SHA256))
        self.assertEqual((R3_RAW_MANIFEST.stat().st_size, sha256_file(R3_RAW_MANIFEST)),
                         (R3_RAW_MANIFEST_BYTES, R3_RAW_MANIFEST_SHA256))
        self.assertEqual((R3_ACTUAL_EXIT_RECEIPT.stat().st_size, sha256_file(R3_ACTUAL_EXIT_RECEIPT)),
                         (1958, R3_ACTUAL_EXIT_RECEIPT_SHA256))
        self.assertEqual((R3_STATIC_EXIT_RECEIPT.stat().st_size, sha256_file(R3_STATIC_EXIT_RECEIPT)),
                         (R3_STATIC_EXIT_RECEIPT_BYTES, R3_STATIC_EXIT_RECEIPT_SHA256))
        actual_receipt = json.loads(R3_ACTUAL_EXIT_RECEIPT.read_bytes())
        self.assertEqual((actual_receipt["schema"], actual_receipt["actual_child_os_exit_code"],
                          actual_receipt["protocol_sha256"], actual_receipt["source_pins_unchanged"],
                          actual_receipt["julia_exit_not_inferred"], actual_receipt["physical_acceptance_credit"],
                          actual_receipt["stderr"]["bytes"], actual_receipt["stderr"]["sha256"]),
                         ("root-up2-v21-r3-actual-external-exit-r1", 1, R3_PROTOCOL_SHA256, True, True, False,
                          1228, "ecf6ce659d814cdf9dda764f00142a40f67c0cda072a4577355664d841bb80ed"))
        self.assertEqual(actual_receipt["argv"], [
            r"D:\Users\Newman\anaconda3\python.exe", "-B",
            "test/RuntimeV4/UP2ClosureReplayOnlyV21/run_replay_staged_v21_r3.py",
            "--protocol", "test/RuntimeV4/UP2ClosureReplayOnlyV21/replay_protocol_v21_r3.json",
            "--protocol-sha256", R3_PROTOCOL_SHA256,
            "--output", str(R3_OUTPUT_LEAF), "--root-serial-slot-granted",
        ])
        self.assertEqual((actual_receipt["cwd"], actual_receipt["outer_timeout"],
                          actual_receipt["global_heavy_processes_after"], actual_receipt["external_output_leaf"]),
                         (str(ROOT), False, [], str(R3_OUTPUT_LEAF)))
        snapshot_manifest = json.loads(R3_SOURCE_SNAPSHOT_MANIFEST.read_bytes())
        self.assertEqual((snapshot_manifest["schema"], snapshot_manifest["original_external_exit_receipt_sha256"],
                          snapshot_manifest["original_raw_manifest_sha256"],
                          snapshot_manifest["raw_failure_outputs_untouched"]),
                         ("up2-r3-actual-wrapper-run-source-snapshot-v1", R3_ACTUAL_EXIT_RECEIPT_SHA256,
                          R3_RAW_MANIFEST_SHA256, True))
        snapshot_test_row = next(row for row in snapshot_manifest["sources"]
                                 if row["source_path"] ==
                                 "test/RuntimeV4/UP2ClosureReplayOnlyV21/test_independent_static_v21.py")
        self.assertEqual((snapshot_test_row["snapshot_path"], snapshot_test_row["bytes"],
                          snapshot_test_row["sha256"], snapshot_test_row["source_sha256_before"],
                          snapshot_test_row["source_sha256_after"]),
                         (R3_TEST_SNAPSHOT_REL, R3_TEST_SNAPSHOT_BYTES, R3_TEST_SNAPSHOT_SHA256,
                          R3_TEST_SNAPSHOT_SHA256, R3_TEST_SNAPSHOT_SHA256))
        static_receipt = json.loads(R3_STATIC_EXIT_RECEIPT.read_bytes())
        self.assertEqual((static_receipt["schema"], static_receipt["actual_direct_python_os_exit_code"],
                          static_receipt["protocol_sha256"], static_receipt["julia_started"],
                          static_receipt["replay_runner_started"], static_receipt["numerical_credit"],
                          static_receipt["wall_seconds"], static_receipt["stderr_sha256"]),
                         ("root-up2-r3-independent-suite-actual-exit-r3", 0, R3_PROTOCOL_SHA256,
                          False, False, False, 13.1818881,
                          "a536c48133978dca3572b33186956fac6a4e3fcd87a0d1d1cc5a6931cda0c7ad"))
        self.assertEqual(static_receipt["argv"], [
            r"D:\Users\Newman\anaconda3\python.exe", "-B",
            "test/RuntimeV4/UP2ClosureReplayOnlyV21/test_independent_static_v21.py", "-v",
        ])

        self.assertEqual(p["r4_output_ownership"], {
            "schema": "mms-v21-r4-external-raw-root-ownership-v1",
            "owner": "UP2ClosureReplayOnlyV21 R4 logical inventory ordering repair",
            "raw_external_root": str(R4_OUTPUT_ROOT.resolve()),
            "archive_mirror_root": str(R4_MIRROR.resolve()),
            "runtime_output_leaf": str(R4_OUTPUT_LEAF.resolve()),
            "outside_repository_docs": True,
            "mirror_contents": "The exact unchanged 613-row map plus separately proved exact-three V9 raw sidecars, exact-five V6 scopefix rows, and exact-five V10 root-observation inputs; no other paths are materialized. R2 and R3 mirrors remain preserved.",
            "builder_creates_mirror_or_output": False,
            "pre_mirror_gate_requires_all_r4_roots_absent": True,
            "r2_r3_roots_are_read_only_preserved": True,
        })
        self.assertEqual(p["r4_inventory_order_repair"], {
            "schema": "mms-v21-r4-v20-inventory-logical-order-repair-v1",
            "function": "verify_v20_actual_failure",
            "only_changed_condition": "file_inventory(runtime_root) != runtime_entries",
            "comparison": "sorted(actual, key=logical POSIX path) == sorted(frozen, key=logical POSIX path)",
            "preserved_checks": ["row paths", "bytes", "SHA-256", "entry count", "duplicate rejection",
                                 "missing rows", "extra rows"],
            "historical_v20_entries_changed": False,
            "file_inventory_global_order_changed": False,
            "r2_r3_r4_runtime_resource_or_numerical_limits_changed": False,
            "runtime_grant": False,
        })
        self.assertEqual(p["r4_pre_output_order_contract"], {
            "schema": "mms-v21-r4-pre-output-logical-inventory-order-v1",
            "original_runtime_rows": 21,
            "original_runtime_bytes": 3365672,
            "same_path_byte_hash_differences": 0,
            "failure_cause": "Windows Path component ordering differed from the archived logical POSIX string order only.",
            "comparison_key": "row['path'] logical POSIX string",
            "full_row_equality_after_sort": True,
            "duplicate_missing_extra_and_content_drift_still_fail": True,
            "no_resource_or_numerical_threshold_change": True,
        })
        self.assertEqual(p["stage_limits"], {
            "seconds": 480, "working_set_bytes": 2147483648,
            "memory_measurement": "sampled aggregate process-tree RSS; not a continuous OS hard cap",
        })
        self.assertEqual(p["total_child_wall_limit_seconds"], 960)
        self.assertEqual(p["controller_overhead_seconds_limit"], 120)
        self.assertEqual(p["preserved_numerical_status"], {
            "authority": "no_publish", "physical_validation": "unsupported",
            "solver_exit_code": 2, "status": "fail",
            "stopping_reason": "stationary_nonzero_residual",
        })
        self.assertEqual(p["coverage_contract"]["process_tree_resource_monitor_negative_controls"],
                         R3_PROCESS_TREE_NEGATIVES)
        self.assertEqual(self.controller.ROOT.resolve(), ROOT.resolve())
        source = self.controller.R4_TRANSFORMED_CONTROLLER_SOURCE
        sorted_inventory_check = 'if sorted(file_inventory(runtime_root), key=lambda item: item["path"]) != sorted(runtime_entries, key=lambda item: item["path"]):'
        v15_start = source.index("def verify_v15_actual_failure(")
        v15_end = source.index("\ndef ", v15_start + 5)
        v15_source = source[v15_start:v15_end]
        self.assertIn("    if file_inventory(runtime_root) != runtime_entries:", v15_source)
        self.assertNotIn(sorted_inventory_check, v15_source)
        v20_start = source.index("def verify_v20_actual_failure(")
        v20_end = source.index("\ndef ", v20_start + 5)
        v20_source = source[v20_start:v20_end]
        self.assertEqual(v20_source.count(sorted_inventory_check), 1)
        self.assertNotIn("if file_inventory(runtime_root) != runtime_entries:", v20_source)
        self.assertEqual(source.count("    if file_inventory(runtime_root) != runtime_entries:"), 1)
        _assert_r4_outputs_absent()
        _assert_r3_mirror_unchanged()

    def test_r4_fresh_pre_mirror_gate_checks_89_inputs_and_four_closure_faults(self) -> None:
        # R7 explicitly binds the corrected source and the unchanged R6 closure contract.
        p = self.r7_protocol
        mirror_snapshot = _r3_mirror_snapshot(self.r3_protocol)
        _assert_r6_outputs_absent()
        resolver = self.r7_controller.resolve_non_doc_v10_input
        result = self.r7_wrapper_module.verify_v10_closure_before_mirror(
            R7_PROTOCOL, self.r7_protocol_sha256, p, root=ROOT,
            non_doc_v10_resolver=resolver)
        self.assertEqual(result, {
            "v10_inputs_verified": 89, "v10_docs_inputs": 18, "v10_workspace_inputs": 71,
            "archive_rows_verified": 613, "archive_bytes_verified": 31564478,
            "directory_prefixes_verified": 31, "materialization_started": False,
        })
        _assert_r6_outputs_absent()

        docs_row = next(row for row in p["archived_input_source"]["entries"]
                        if any(str(field).startswith("$.v10_protocol.inputs[")
                               for field in row.get("source_fields", [])))
        docs_path = docs_row["logical_path"]
        docs_source = next(field for field in docs_row["source_fields"]
                           if field.startswith("$.v10_protocol.inputs["))
        input_index = int(re.search(r"inputs\[(\d+)\]", docs_source).group(1))

        missing_reference = copy.deepcopy(p)
        missing_reference["archived_input_source"]["referenced_paths"] = [
            row for row in missing_reference["archived_input_source"]["referenced_paths"]
            if row["logical_path"] != docs_path]
        with self.assertRaisesRegex(ValueError,
                                    "exactly 613 archive rows and 645 references|referenced-path table|V10 docs input"):
            self.r7_wrapper_module.audit_v10_input_closure_before_mirror(
                missing_reference, root=ROOT, non_doc_v10_resolver=resolver)

        tampered_bytes = copy.deepcopy(p)
        target = next(row for row in tampered_bytes["archived_input_source"]["entries"]
                      if row["logical_path"] == docs_path)
        target["sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "ZIP bytes|exact ZIP"):
            self.r7_wrapper_module.audit_v10_input_closure_before_mirror(
                tampered_bytes, root=ROOT, non_doc_v10_resolver=resolver)

        missing_source = copy.deepcopy(p)
        target_ref = next(row for row in missing_source["archived_input_source"]["referenced_paths"]
                          if row["logical_path"] == docs_path)
        target_ref["source_fields"] = [field for field in target_ref["source_fields"]
                                       if field != f"$.v10_protocol.inputs[{input_index}].path"]
        with self.assertRaisesRegex(ValueError, "classification/source"):
            self.r7_wrapper_module.audit_v10_input_closure_before_mirror(
                missing_source, root=ROOT, non_doc_v10_resolver=resolver)

        with self.assertRaisesRegex(ValueError, "CLI --protocol-sha256"):
            self.r7_wrapper_module.verify_v10_closure_before_mirror(
                R7_PROTOCOL, "0" * 64, p, root=ROOT,
                non_doc_v10_resolver=resolver)

        _assert_r6_outputs_absent()
        self.assertEqual(_r3_mirror_snapshot(self.r3_protocol), mirror_snapshot)
        _assert_r3_mirror_unchanged()
        _assert_r2_mirror_unchanged()

    def test_r4_historical_absent_slots_bind_four_paths_and_reject_drift(self) -> None:
        controller = self.controller
        protocol = self.protocol
        helper = self.runner_module._load_historical_absence_helper(protocol)
        proof = copy.deepcopy(protocol["r4_historical_absent_output_slots"])
        mirror_snapshot = _r3_mirror_snapshot(self.r3_protocol)
        expected_slots = [
            ("v6-r6-runtime-replay", "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/replay_only_continuation_r6/runtime_replay_r6"),
            ("v9-r9-runtime-replay", "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/replay_only_continuation_r9/runtime_replay_r9"),
            ("v12-r12-runtime-replay", "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/replay_only_continuation_r12/runtime_replay_r12"),
            ("v13-r13-runtime-replay", "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/replay_only_continuation_r13/runtime_replay_r13"),
        ]
        with tempfile.TemporaryDirectory(prefix="up2_r4_absence_slots_") as temporary_root:
            test_root = Path(temporary_root)
            source_protocol = test_root.joinpath(*PurePosixPath(helper.R3_PROTOCOL_REL).parts)
            source_protocol.parent.mkdir(parents=True)
            source_protocol.write_bytes(R3_PROTOCOL.read_bytes())
            stage_root = test_root / "actual_stage"
            stage_root.mkdir()
            adapted = copy.deepcopy(protocol)
            adapted["archived_input_source"]["staging_root"] = str(stage_root.resolve())

            for (slot_id, logical_path), proof_row in zip(expected_slots, proof["slots"]):
                with self.subTest(slot=slot_id):
                    self.assertEqual((proof_row["slot_id"], proof_row["logical_path"]),
                                     (slot_id, logical_path))
                    resolved = helper.resolve_historical_absent_output_slot_v21_r4(
                        test_root, adapted, stage_root, logical_path, proof)
                    expected_path = test_root.joinpath(*PurePosixPath(logical_path).parts)
                    self.assertEqual(resolved, expected_path)
                    self.assertFalse(expected_path.exists())

            self.assertIsNone(helper.resolve_historical_absent_output_slot_v21_r4(
                test_root, adapted, stage_root, expected_slots[0][1] + "/extra", proof))
            changed_proof = copy.deepcopy(proof)
            changed_proof["slots"][0]["slot_id"] += "-tampered"
            with self.assertRaisesRegex(ValueError, "supplied absence proof differs"):
                helper.resolve_historical_absent_output_slot_v21_r4(
                    test_root, adapted, stage_root, expected_slots[0][1], changed_proof)
            with self.assertRaisesRegex(ValueError, "staging root differs"):
                helper.resolve_historical_absent_output_slot_v21_r4(
                    test_root, adapted, test_root, expected_slots[0][1], proof)

            wrong_source = copy.deepcopy(adapted)
            wrong_source["archived_input_source"]["archive_sha256"] = "0" * 64
            with self.assertRaisesRegex(ValueError, "archive identity differs"):
                helper.resolve_historical_absent_output_slot_v21_r4(
                    test_root, wrong_source, stage_root, expected_slots[0][1], proof)

            zip_overlap = copy.deepcopy(adapted)
            zip_overlap_row = zip_overlap["archived_input_source"]["entries"][0]
            zip_overlap_row["logical_path"] = expected_slots[0][1]
            zip_overlap_row["archive_member"] = expected_slots[0][1]
            with self.assertRaisesRegex(ValueError, "maps differ from the frozen R3 source map"):
                helper.resolve_historical_absent_output_slot_v21_r4(
                    test_root, zip_overlap, stage_root, expected_slots[0][1], proof)

            workspace_target = test_root.joinpath(*PurePosixPath(expected_slots[0][1]).parts)
            workspace_target.mkdir(parents=True)
            with self.assertRaisesRegex(ValueError, "present in workspace"):
                helper.resolve_historical_absent_output_slot_v21_r4(
                    test_root, adapted, stage_root, expected_slots[0][1], proof)
            workspace_target.rmdir()

            stage_target = stage_root.joinpath(*PurePosixPath(expected_slots[0][1]).parts)
            stage_target.mkdir(parents=True)
            with self.assertRaisesRegex(ValueError, "present in actual R4 resolver mirror"):
                helper.resolve_historical_absent_output_slot_v21_r4(
                    test_root, adapted, stage_root, expected_slots[0][1], proof)

        sidecar_proof = copy.deepcopy(protocol[R4_V9_SIDECAR_KEY])
        self.assertEqual(sidecar_proof["schema"], R4_V9_SIDECAR_SCHEMA)
        self.assertEqual([(row["logical_path"], row["bytes"], row["sha256"])
                          for row in sidecar_proof["files"]], list(R4_V9_RAW_SIDECAR_FILES))
        mirror_receipt_path = sidecar_proof["v9_static_receipt"]["path"]
        mapped_receipt_row = next(row for row in protocol["archived_input_source"]["entries"]
                                  if row["logical_path"] == mirror_receipt_path)
        mirror_receipt_source = R3_MIRROR.joinpath(*PurePosixPath(mirror_receipt_path).parts)
        self.assertEqual((mirror_receipt_source.stat().st_size, sha256_file(mirror_receipt_source)),
                         (mapped_receipt_row["bytes"], mapped_receipt_row["sha256"]))
        controller = self.controller
        original_checked_path = controller.checked_path
        original_archive_inputs = controller.ARCHIVE_INPUTS
        original_sidecar_helper = getattr(controller, "_r4_v9_static_raw_sidecar_helper", None)
        original_sidecar_materialization = getattr(
            controller, "_r4_v9_static_raw_sidecar_materialization", None)
        fallback_calls: list[str] = []
        with tempfile.TemporaryDirectory(prefix="up2_r4_v9_sidecar_") as temporary_root:
            stage_root = Path(temporary_root) / "actual_stage"
            stage_root.mkdir()
            adapted = copy.deepcopy(protocol)
            stage_text = str(stage_root.resolve())
            adapted["archived_input_source"]["staging_root"] = stage_text
            adapted["r4_output_ownership"]["archive_mirror_root"] = stage_text
            adapted["r4_output_ownership"]["raw_external_root"] = str(stage_root.parent.resolve())
            adapted[R4_V6_SCOPEFIX_ROUTE_KEY]["materialization_root"] = stage_text
            staged_receipt = stage_root.joinpath(*PurePosixPath(mirror_receipt_path).parts)
            staged_receipt.parent.mkdir(parents=True)
            staged_receipt.write_bytes(mirror_receipt_source.read_bytes())

            class RouteResolverProbe:
                def __init__(self, current_stage: Path) -> None:
                    self.stage_root = current_stage

                def resolve(self, root: Path, relative: str) -> Path:
                    fallback_calls.append(relative)
                    if relative == mirror_receipt_path:
                        return staged_receipt
                    return (root / relative).resolve()

            install_absent_slots = self.runner_module._install_historical_absent_output_slots
            try:
                install_absent_slots(controller, adapted)
                route_helper = controller._r4_v9_static_raw_sidecar_helper
                controller.ARCHIVE_INPUTS = RouteResolverProbe(stage_root)
                materialized = route_helper.materialize_v9_static_raw_output_sidecar_v21_r4(
                    ROOT, adapted, stage_root, sidecar_proof)
                self.assertEqual(len(materialized), 3)
                for row, (logical_path, byte_count, expected_sha) in zip(
                        materialized, R4_V9_RAW_SIDECAR_FILES, strict=True):
                    staged_path = stage_root.joinpath(*PurePosixPath(logical_path).parts)
                    self.assertEqual((row["logical_path"], row["archive_member"], row["bytes"],
                                      row["sha256"], Path(row["staged_path"]).resolve()),
                                     (logical_path, logical_path, byte_count, expected_sha,
                                      staged_path.resolve()))
                    self.assertEqual((staged_path.stat().st_size, sha256_file(staged_path)),
                                     (byte_count, expected_sha))
                    self.assertEqual(controller.checked_path(ROOT, logical_path), staged_path.resolve())
                    self.assertFalse(ROOT.joinpath(*PurePosixPath(logical_path).parts).exists())
                    self.assertFalse(R3_MIRROR.joinpath(*PurePosixPath(logical_path).parts).exists())

                self.assertIsNone(route_helper.resolve_v9_static_raw_output_sidecar_v21_r4(
                    ROOT, adapted, stage_root, R4_V9_RAW_SIDECAR_FILES[0][0] + "/extra", sidecar_proof))
                for mutation in ("missing", "duplicate", "sha256"):
                    changed = copy.deepcopy(sidecar_proof)
                    if mutation == "missing":
                        changed["files"].pop()
                    elif mutation == "duplicate":
                        changed["files"][1] = copy.deepcopy(changed["files"][0])
                    else:
                        changed["files"][0]["sha256"] = "0" * 64
                    with self.subTest(sidecar_proof_mutation=mutation), self.assertRaisesRegex(
                            ValueError, "supplied V9 raw-sidecar proof differs"):
                        route_helper.resolve_v9_static_raw_output_sidecar_v21_r4(
                            ROOT, adapted, stage_root, R4_V9_RAW_SIDECAR_FILES[0][0], changed)

                wrong_archive = copy.deepcopy(adapted)
                wrong_archive["archived_input_source"]["archive_sha256"] = "0" * 64
                with self.assertRaisesRegex(ValueError, "archive identity differs"):
                    route_helper.resolve_v9_static_raw_output_sidecar_v21_r4(
                        ROOT, wrong_archive, stage_root, R4_V9_RAW_SIDECAR_FILES[0][0], sidecar_proof)

                wrong_stage = Path(temporary_root) / "different_stage"
                wrong_stage.mkdir()
                with self.assertRaisesRegex(ValueError, "staging root differs"):
                    route_helper.resolve_v9_static_raw_output_sidecar_v21_r4(
                        ROOT, adapted, wrong_stage, R4_V9_RAW_SIDECAR_FILES[0][0], sidecar_proof)

                map_overlap = copy.deepcopy(adapted)
                overlap_row = map_overlap["archived_input_source"]["entries"][0]
                overlap_row["logical_path"] = R4_V9_RAW_SIDECAR_FILES[0][0]
                overlap_row["archive_member"] = R4_V9_RAW_SIDECAR_FILES[0][0]
                with self.assertRaisesRegex(ValueError, "map|overlap"):
                    route_helper.resolve_v9_static_raw_output_sidecar_v21_r4(
                        ROOT, map_overlap, stage_root, R4_V9_RAW_SIDECAR_FILES[0][0], sidecar_proof)

                absent_path = expected_slots[0][1]
                fallback_count = len(fallback_calls)
                self.assertEqual(controller.checked_path(ROOT, absent_path),
                                 ROOT.joinpath(*PurePosixPath(absent_path).parts))
                self.assertEqual(len(fallback_calls), fallback_count,
                                 "the exact four-slot absence route must run before original lookup")
                self.assertEqual(controller.checked_path(ROOT, mirror_receipt_path), staged_receipt.resolve())
                self.assertEqual(fallback_calls[-1], mirror_receipt_path,
                                 "a non-sidecar mapped input must reach the original resolver")

                changed_stage_file = stage_root.joinpath(
                    *PurePosixPath(R4_V9_RAW_SIDECAR_FILES[1][0]).parts)
                original_bytes = changed_stage_file.read_bytes()
                self.assertEqual(len(original_bytes), R4_V9_RAW_SIDECAR_FILES[1][1])
                changed_stage_file.write_bytes(bytes([original_bytes[0] ^ 1]) + original_bytes[1:])
                with self.assertRaisesRegex(ValueError, "staged file hash changed"):
                    route_helper.resolve_v9_static_raw_output_sidecar_v21_r4(
                        ROOT, adapted, stage_root, R4_V9_RAW_SIDECAR_FILES[1][0], sidecar_proof)
            finally:
                controller.checked_path = original_checked_path
                controller.ARCHIVE_INPUTS = original_archive_inputs
                if original_sidecar_helper is None:
                    delattr(controller, "_r4_v9_static_raw_sidecar_helper")
                else:
                    controller._r4_v9_static_raw_sidecar_helper = original_sidecar_helper
                if original_sidecar_materialization is None:
                    delattr(controller, "_r4_v9_static_raw_sidecar_materialization")
                else:
                    controller._r4_v9_static_raw_sidecar_materialization = original_sidecar_materialization

        self.assertEqual(_r3_mirror_snapshot(self.r3_protocol), mirror_snapshot)
        _assert_r4_outputs_absent()
        _assert_r3_mirror_unchanged()
        _assert_r2_mirror_unchanged()

    def test_r4_complete_pre_output_chain_uses_strict_read_only_r3_mirror_provider(self) -> None:
        historical_controller = self.controller
        mirror_snapshot = _r3_mirror_snapshot(self.r3_protocol)
        _assert_r4_outputs_absent()
        historical_resolver = historical_controller.ArchivedInputResolver
        historical_provider_calls: list[tuple[Path, dict]] = []

        def historical_provider_must_not_run(root: Path, protocol: dict) -> object:
            historical_provider_calls.append((Path(root), protocol))
            raise AssertionError("historical R4 preimage must reject the successor protocol before provider use")

        historical_controller.ArchivedInputResolver = historical_provider_must_not_run
        try:
            with self.assertRaisesRegex(
                    ValueError, "only the V21-directory replay_protocol_v21.json is accepted"):
                historical_controller.verify_pre_output_contract(
                    R4_PROTOCOL, self.protocol_sha256, R4_OUTPUT_LEAF)
        finally:
            historical_controller.ArchivedInputResolver = historical_resolver
        self.assertEqual(historical_provider_calls, [])
        self.assertEqual(_r3_mirror_snapshot(self.r3_protocol), mirror_snapshot)
        _assert_r4_outputs_absent()

        # The complete provider/materialization chain must exercise the current
        # loader with its selected R7 protocol path and exact protocol digest.
        controller = self.r7_controller
        p = self.r7_protocol
        protocol_bytes = self.r7_protocol_bytes
        protocol_sha256 = self.r7_protocol_sha256
        runner_module = self.r7_wrapper_module
        output_leaf = Path(p["output_leaf"]).resolve()
        self.assertEqual(sha256(protocol_bytes), protocol_sha256)
        self.assertEqual(p["archived_input_source"]["entries"],
                         self.protocol["archived_input_source"]["entries"])
        self.assertEqual(p[R4_V9_SIDECAR_KEY], self.protocol[R4_V9_SIDECAR_KEY])
        self.assertEqual(p[R4_V6_SCOPEFIX_KEY], self.protocol[R4_V6_SCOPEFIX_KEY])
        self.assertEqual(p[R4_V10_ROOT_OBSERVATION_ADDENDUM_KEY],
                         self.protocol[R4_V10_ROOT_OBSERVATION_ADDENDUM_KEY])
        _assert_r6_outputs_absent()
        mirror_snapshot = _r3_mirror_snapshot(self.r3_protocol)
        original_resolver = controller.ArchivedInputResolver
        previous_archive_inputs = controller.ARCHIVE_INPUTS
        install_absent_slots = runner_module._install_historical_absent_output_slots
        factory_calls: list[tuple[Path, dict, Path]] = []
        expected_rows = {path: (byte_count, digest) for path, byte_count, digest
                         in R4_V9_RAW_SIDECAR_FILES}
        expected_v6_rows = {path: (byte_count, digest)
                            for path, byte_count, digest in R4_V6_SCOPEFIX_FILES}
        expected_v10_rows = {path: (byte_count, digest)
                             for path, byte_count, digest, _, _, _, _ in R4_V10_ROOT_OBSERVATION_FILES}
        v6_checked_paths: list[str] = []
        v10_input_checked_paths: list[str] = []
        original_v10_binding_helper = controller._r4_v10_original_path_binding
        v10_binding_calls: list[tuple[Path, str, Path, str, Path]] = []

        def observe_v10_binding(root_arg: Path, logical_path: object,
                                physical_path: Path, kind: str) -> Path:
            identity = original_v10_binding_helper(root_arg, logical_path, physical_path, kind)
            v10_binding_calls.append((Path(root_arg), str(logical_path), Path(physical_path),
                                      kind, Path(identity)))
            return identity

        controller._r4_v10_original_path_binding = observe_v10_binding
        original_v6_staged_paths = getattr(controller, "_r4_v6_scopefix_staged_paths", None)
        original_v6_materialization = getattr(
            controller, "_r4_v6_scopefix_addendum_materialization", None)
        original_v10_staged_paths = getattr(controller, "_r4_v10_root_observation_staged_paths", None)
        original_v10_materialization = getattr(controller, "_r4_v10_root_observation_materialization", None)

        def strict_r3_source_to_fresh_stage_provider(root: Path, protocol: dict) -> object:
            self.assertEqual(Path(root).resolve(), ROOT.resolve())
            self.assertEqual(protocol, p)
            self.assertEqual(sha256(protocol_bytes), protocol_sha256)
            self.assertEqual(protocol, json.loads(protocol_bytes))
            adapted = copy.deepcopy(protocol)
            stage_text = str(stage_root.resolve())
            adapted["archived_input_source"]["staging_root"] = stage_text
            adapted["r4_output_ownership"]["archive_mirror_root"] = stage_text
            adapted["r4_output_ownership"]["raw_external_root"] = str(stage_root.parent.resolve())
            adapted[R4_V6_SCOPEFIX_ROUTE_KEY]["materialization_root"] = stage_text
            adapted[R4_V10_ROOT_OBSERVATION_ROUTE_KEY]["materialization_root"] = stage_text
            self.assertEqual(adapted["archived_input_source"]["entries"],
                             protocol["archived_input_source"]["entries"])
            self.assertEqual(adapted["archived_input_source"]["referenced_paths"],
                             protocol["archived_input_source"]["referenced_paths"])
            self.assertEqual(adapted["archived_input_source"]["directory_prefixes"],
                             protocol["archived_input_source"]["directory_prefixes"])
            self.assertEqual(adapted["r4_output_ownership"]["archive_mirror_root"],
                             adapted["archived_input_source"]["staging_root"])
            self.assertEqual(Path(adapted["r4_output_ownership"]["raw_external_root"]).resolve(),
                             stage_root.parent.resolve())
            self.assertEqual(adapted["r4_output_ownership"]["runtime_output_leaf"],
                             protocol["r4_output_ownership"]["runtime_output_leaf"])
            self.assertEqual(adapted["output_leaf"], protocol["output_leaf"])
            install_absent_slots(controller, adapted)
            with zipfile.ZipFile(Path(adapted["archived_input_source"]["archive_path"]), "r") as archive:
                validated_v6 = runner_module._validate_v6_scopefix_closure_addendum(
                    adapted, root=ROOT, archive=archive)
                validated_v10 = runner_module._validate_v10_root_observation_input_addendum(
                    adapted, root=ROOT, archive=archive)
            mismatched_stage = Path(stage_root.parent) / "wrong_v6_addendum_stage"
            mismatched_stage.mkdir()
            with self.assertRaisesRegex(ValueError, "R4 V6 scopefix addendum"):
                runner_module._materialize_v6_scopefix_closure_addendum(
                    root, adapted, mismatched_stage, validated_v6)
            mismatched_v10_stage = Path(stage_root.parent) / "wrong_v10_addendum_stage"
            mismatched_v10_stage.mkdir()
            with self.assertRaisesRegex(ValueError, "R4 V10 materializer"):
                runner_module._materialize_v10_root_observation_input_addendum(
                    root, adapted, mismatched_v10_stage, validated_v10)
            self.assertFalse(any(stage_root.joinpath(*PurePosixPath(path).parts).exists()
                                 for path in expected_v6_rows))
            self.assertFalse(any(mismatched_v10_stage.joinpath(*PurePosixPath(path).parts).exists()
                                 for path in expected_v10_rows))
            resolver = original_resolver(root, adapted)
            self.assertIs(type(resolver), original_resolver,
                          "test provider must construct the original ArchivedInputResolver class")
            controller.ARCHIVE_INPUTS = resolver
            with self.assertRaisesRegex(ValueError, "exact repository root and resolver"):
                controller.checked_path(ROOT.parent, next(iter(expected_v6_rows)))
            v6_materialization = runner_module._materialize_v6_scopefix_closure_addendum(
                root, adapted, resolver.stage_root, validated_v6)
            self.assertEqual((v6_materialization["schema"], v6_materialization["proof_sha256"],
                              v6_materialization["materialized_count"]),
                             (R4_V6_SCOPEFIX_MATERIALIZATION_SCHEMA,
                              sha256(canonical_json_bytes(adapted[R4_V6_SCOPEFIX_KEY])), 5))
            controller._r4_v6_scopefix_staged_paths = {
                row["logical_path"]: Path(row["staged_path"])
                for row in v6_materialization["rows"]
            }
            controller._r4_v6_scopefix_addendum_materialization = dict(v6_materialization)
            with self.assertRaisesRegex(ValueError, "exact repository root and resolver stage"):
                controller.checked_path(ROOT.parent, next(iter(expected_v10_rows)))
            original_route_checked_path = controller.checked_path

            def record_addendum_checked_path(check_root: Path, relative: str) -> Path:
                resolved = original_route_checked_path(check_root, relative)
                if relative in expected_v6_rows:
                    v6_checked_paths.append(relative)
                if relative in expected_v10_rows:
                    v10_input_checked_paths.append(relative)
                return resolved

            controller.checked_path = record_addendum_checked_path
            alias_map = runner_module._absolute_archive_file_aliases(ROOT, adapted)
            self.assertEqual(len(alias_map), 613)
            v15 = adapted["parent_v15_actual_failure"]
            process_logical = v15["process"]["path"]
            process_path = resolver.resolve(root, process_logical)
            process_record = json.loads(process_path.read_text(encoding="utf-8"))
            expected_streams = {
                "stdout": (
                    v15["runtime_root"] + "/producer_process/stdout.raw", 53,
                    "3be5fee13a05ba5c65f46dae6d25c098a61871ef7fba5251dd15d562f344e72d"),
                "stderr": (
                    v15["runtime_root"] + "/producer_process/stderr.raw", 134,
                    "9d682a7d4613b23a9fdc7a16e3367a2d39687a5cfe1de994348101fd8bbf1179"),
            }
            rows_by_path = {row["logical_path"]: row
                            for row in adapted["archived_input_source"]["entries"]}
            for label, (logical_path, byte_count, expected_sha) in expected_streams.items():
                ref = process_record[label]
                absolute_path = ref["path"]
                alias_key = absolute_path.replace("\\", "/")
                self.assertTrue(Path(absolute_path).is_absolute())
                self.assertEqual((ref["bytes"], ref["sha256"]), (byte_count, expected_sha))
                self.assertEqual(alias_map[alias_key], logical_path)
                self.assertEqual((rows_by_path[logical_path]["bytes"],
                                  rows_by_path[logical_path]["sha256"]),
                                 (byte_count, expected_sha))
                staged_raw = controller.checked_path(ROOT, absolute_path)
                self.assertEqual(staged_raw.resolve(), resolver.staged[logical_path].resolve())
                raw_bytes = staged_raw.read_bytes()
                self.assertEqual((len(raw_bytes), sha256(raw_bytes)), (byte_count, expected_sha))
                if label == "stdout":
                    polluted = bytes([raw_bytes[0] ^ 1]) + raw_bytes[1:]
                    self.assertEqual(len(polluted), len(raw_bytes))
                    staged_raw.write_bytes(polluted)
                    try:
                        self.assertEqual(staged_raw.stat().st_size, byte_count)
                        self.assertNotEqual(sha256_file(staged_raw), expected_sha)
                        with self.assertRaisesRegex(
                                FileNotFoundError, "V21 mapped historical input is missing or changed"):
                            controller.checked_path(ROOT, absolute_path)
                    finally:
                        staged_raw.write_bytes(raw_bytes)
                    self.assertEqual((staged_raw.stat().st_size, sha256_file(staged_raw)),
                                     (byte_count, expected_sha))

            stdout_absolute = process_record["stdout"]["path"]
            stdout_logical = expected_streams["stdout"][0]
            outside_root_alias = str(ROOT.parent / "outside_fusionconceptai" /
                                     PurePosixPath(stdout_logical))
            self.assertNotIn(outside_root_alias.replace("\\", "/"), alias_map)
            with self.assertRaisesRegex(ValueError, "protocol path escapes repository"):
                controller.checked_path(ROOT, outside_root_alias)

            logical_parts = PurePosixPath(stdout_logical).parts
            dot_alias = str(ROOT.joinpath(logical_parts[0], "..", *logical_parts))
            case_alias = stdout_absolute.replace(
                "\\UP2-04-CLOSURE-REPAIR-PREC\\", "\\up2-04-closure-repair-prec\\", 1)
            self.assertNotIn(dot_alias.replace("\\", "/"), alias_map)
            self.assertNotIn(case_alias.replace("\\", "/"), alias_map)
            for label, alias in (("dot traversal", dot_alias), ("case alias", case_alias)):
                with self.subTest(noncanonical_alias=label):
                    self.assertNotEqual(controller.checked_path(ROOT, alias).resolve(),
                                        resolver.staged[stdout_logical].resolve())
                    self.assertFalse(controller.checked_path(ROOT, alias).is_file())

            wrong_root = copy.deepcopy(adapted)
            with self.assertRaisesRegex(ValueError, "exact repository root"):
                runner_module._absolute_archive_file_aliases(ROOT.parent, wrong_root)
            wrong_proof = copy.deepcopy(adapted)
            wrong_proof[R4_ABSOLUTE_ARCHIVE_ROUTE_KEY]["changes_613_file_map"] = True
            with self.assertRaisesRegex(ValueError, "source-bound file map"):
                runner_module._absolute_archive_file_aliases(ROOT, wrong_proof)
            missing_row = copy.deepcopy(adapted)
            missing_row["archived_input_source"]["entries"].pop()
            with self.assertRaisesRegex(ValueError, "unchanged 613 file map"):
                runner_module._absolute_archive_file_aliases(ROOT, missing_row)
            duplicate_row = copy.deepcopy(adapted)
            duplicate_rows = duplicate_row["archived_input_source"]["entries"]
            duplicate_rows[-1] = copy.deepcopy(duplicate_rows[0])
            duplicate_row[R4_ABSOLUTE_ARCHIVE_ROUTE_KEY]["mapped_rows_sha256"] = sha256(
                canonical_json_bytes(duplicate_rows))
            with self.assertRaisesRegex(ValueError, "alias is ambiguous"):
                runner_module._absolute_archive_file_aliases(ROOT, duplicate_row)

            helper = controller._r4_v9_static_raw_sidecar_helper
            materialized = helper.materialize_v9_static_raw_output_sidecar_v21_r4(
                root, adapted, resolver.stage_root, adapted[R4_V9_SIDECAR_KEY])
            self.assertEqual(len(materialized), 3)
            materialized_by_path = {row["logical_path"]: row for row in materialized}
            self.assertEqual(set(materialized_by_path), set(expected_rows))
            for logical_path, (byte_count, expected_sha) in expected_rows.items():
                row = materialized_by_path[logical_path]
                staged_path = stage_root.joinpath(*PurePosixPath(logical_path).parts).resolve()
                self.assertEqual((row["bytes"], row["sha256"], row["archive_member"],
                                  row["staged_path"]),
                                 (byte_count, expected_sha, logical_path, str(staged_path)))
                self.assertTrue(staged_path.is_relative_to(stage_root.resolve()))
                self.assertEqual((staged_path.stat().st_size, sha256_file(staged_path)),
                                 (byte_count, expected_sha))
                workspace_path = ROOT.joinpath(*PurePosixPath(logical_path).parts)
                r3_path = R3_MIRROR.joinpath(*PurePosixPath(logical_path).parts)
                self.assertFalse(workspace_path.exists())
                self.assertFalse(r3_path.exists())

            sidecar_receipt = {
                "schema": R4_V9_SIDECAR_SCHEMA,
                "proof_sha256": sha256(canonical_json_bytes(adapted[R4_V9_SIDECAR_KEY])),
                "materialized_count": 3,
                "rows": [dict(materialized_by_path[path])
                         for path, _, _ in R4_V9_RAW_SIDECAR_FILES],
            }
            controller._r4_v9_static_raw_sidecar_materialization = sidecar_receipt
            v10_materialization = runner_module._materialize_v10_root_observation_input_addendum(
                root, adapted, resolver.stage_root, validated_v10)
            self.assertEqual((v10_materialization["schema"], v10_materialization["proof_sha256"],
                              v10_materialization["materialized_count"]),
                             (R4_V10_ROOT_OBSERVATION_MATERIALIZATION_SCHEMA,
                              sha256(canonical_json_bytes(adapted[R4_V10_ROOT_OBSERVATION_ADDENDUM_KEY])), 5))
            self.assertEqual([{key: row[key] for key in row if key != "staged_path"}
                              for row in v10_materialization["rows"]],
                             adapted[R4_V10_ROOT_OBSERVATION_ADDENDUM_KEY]["rows"])
            controller._r4_v10_root_observation_staged_paths = {
                row["logical_path"]: Path(row["staged_path"])
                for row in v10_materialization["rows"]
            }
            controller._r4_v10_root_observation_materialization = dict(v10_materialization)
            original_resolution_receipt = resolver.resolution_receipt

            def resolution_receipt_with_v9_sidecar() -> dict:
                receipt = original_resolution_receipt()
                self.assertNotIn(R4_V9_SIDECAR_KEY, receipt)
                receipt[R4_V9_SIDECAR_KEY] = dict(sidecar_receipt)
                self.assertNotIn(R4_V6_SCOPEFIX_MATERIALIZATION_KEY, receipt)
                receipt[R4_V6_SCOPEFIX_MATERIALIZATION_KEY] = dict(v6_materialization)
                self.assertNotIn(R4_V10_ROOT_OBSERVATION_MATERIALIZATION_KEY, receipt)
                receipt[R4_V10_ROOT_OBSERVATION_MATERIALIZATION_KEY] = dict(v10_materialization)
                return receipt

            resolver.resolution_receipt = resolution_receipt_with_v9_sidecar
            factory_calls.append((Path(root).resolve(), adapted, stage_root.resolve()))
            self.assertEqual(_r3_mirror_snapshot(self.r3_protocol), mirror_snapshot)
            return resolver

        with tempfile.TemporaryDirectory(prefix="up2_r4_full_preoutput_stage_") as temporary_root:
            stage_root = Path(temporary_root) / "archive_mirror"
            self.assertFalse(stage_root.exists())
            try:
                controller.ArchivedInputResolver = strict_r3_source_to_fresh_stage_provider
                result = controller.verify_pre_output_contract(
                    R7_PROTOCOL, protocol_sha256, output_leaf)
            finally:
                controller._r4_v10_original_path_binding = original_v10_binding_helper
                controller.ArchivedInputResolver = original_resolver
                controller.ARCHIVE_INPUTS = previous_archive_inputs
                install_absent_slots(controller, p)
                if original_v6_staged_paths is None:
                    delattr(controller, "_r4_v6_scopefix_staged_paths")
                else:
                    controller._r4_v6_scopefix_staged_paths = original_v6_staged_paths
                if original_v6_materialization is None:
                    delattr(controller, "_r4_v6_scopefix_addendum_materialization")
                else:
                    controller._r4_v6_scopefix_addendum_materialization = original_v6_materialization
                if original_v10_staged_paths is None:
                    delattr(controller, "_r4_v10_root_observation_staged_paths")
                else:
                    controller._r4_v10_root_observation_staged_paths = original_v10_staged_paths
                if original_v10_materialization is None:
                    delattr(controller, "_r4_v10_root_observation_materialization")
                else:
                    controller._r4_v10_root_observation_materialization = original_v10_materialization

            self.assertEqual(len(factory_calls), 1)
            self.assertEqual(factory_calls[0][0], ROOT.resolve())
            adapted = factory_calls[0][1]
            self.assertEqual(factory_calls[0][2], stage_root.resolve())
            self.assertEqual(adapted["archived_input_source"]["staging_root"], str(stage_root.resolve()))
            self.assertEqual(adapted["r4_output_ownership"]["archive_mirror_root"],
                             str(stage_root.resolve()))
            self.assertEqual(adapted["archived_input_source"]["entries"],
                             p["archived_input_source"]["entries"])
            self.assertEqual(adapted["archived_input_source"]["referenced_paths"],
                             p["archived_input_source"]["referenced_paths"])
            self.assertEqual(adapted["archived_input_source"]["directory_prefixes"],
                             p["archived_input_source"]["directory_prefixes"])
            self.assertEqual(result["protocol_sha256"], protocol_sha256)
            self.assertEqual(Path(result["output"]).resolve(), output_leaf)
            self.assertEqual(result["stage_limit"], 480.0)
            self.assertEqual(result["memory_limit"], 2147483648)
            self.assertEqual(result["aggregate_wall_contract"]["total_limit_seconds"], 960.0)
            self.assertEqual(result["controller_overhead_contract"]["limit_seconds"], 120.0)
            self.assertEqual(result["process_tree_monitor_contract"], p["process_tree_monitor_contract"])
            archive_resolution = result["archive_resolution"]
            self.assertEqual(Path(archive_resolution["staging_root"]).resolve(), stage_root.resolve())
            self.assertEqual((len(archive_resolution["entries"]),
                              sum(row["bytes"] for row in archive_resolution["entries"]),
                              len(archive_resolution["directory_prefixes"]),
                              len(archive_resolution["expected_absent"]),
                              len(archive_resolution["restored_workspace_entries"]),
                              len(p["archived_input_source"]["referenced_paths"])),
                             (613, 31564478, 31, 1, 0, 645))
            mapped_paths = {row["logical_path"] for row in archive_resolution["entries"]}
            self.assertTrue(mapped_paths.isdisjoint(expected_rows))
            self.assertTrue(mapped_paths.isdisjoint(expected_v6_rows))
            sidecar_receipt = archive_resolution[R4_V9_SIDECAR_KEY]
            self.assertEqual((sidecar_receipt["schema"], sidecar_receipt["proof_sha256"],
                              sidecar_receipt["materialized_count"]),
                             (R4_V9_SIDECAR_SCHEMA,
                              sha256(canonical_json_bytes(p[R4_V9_SIDECAR_KEY])), 3))
            self.assertEqual([(row["logical_path"], row["archive_member"], row["bytes"], row["sha256"])
                              for row in sidecar_receipt["rows"]],
                             [(path, path, byte_count, digest)
                              for path, byte_count, digest in R4_V9_RAW_SIDECAR_FILES])
            self.assertTrue(all(Path(row["staged_path"]).is_relative_to(stage_root.resolve())
                                for row in sidecar_receipt["rows"]))
            v6_receipt = archive_resolution[R4_V6_SCOPEFIX_MATERIALIZATION_KEY]
            self.assertEqual((v6_receipt["schema"], v6_receipt["proof_sha256"],
                              v6_receipt["materialized_count"]),
                             (R4_V6_SCOPEFIX_MATERIALIZATION_SCHEMA,
                              sha256(canonical_json_bytes(p[R4_V6_SCOPEFIX_KEY])), 5))
            self.assertEqual({(row["logical_path"], row["archive_member"], row["bytes"], row["sha256"])
                              for row in v6_receipt["rows"]},
                             {(path, path, byte_count, digest)
                              for path, byte_count, digest in R4_V6_SCOPEFIX_FILES})
            self.assertEqual([row["logical_path"] for row in v6_receipt["rows"]],
                             [row["logical_path"] for row in p[R4_V6_SCOPEFIX_KEY]["rows"]])
            expected_v6_row_by_path = {row["logical_path"]: row
                                       for row in p[R4_V6_SCOPEFIX_KEY]["rows"]}
            for row in v6_receipt["rows"]:
                logical_path = row["logical_path"]
                byte_count, expected_sha = expected_v6_rows[logical_path]
                proof_row = expected_v6_row_by_path[logical_path]
                self.assertEqual((row["manifest_ordinal"], row["manifest_row_sha256"]),
                                 (proof_row["manifest_ordinal"], proof_row["manifest_row_sha256"]))
                staged_path = stage_root.joinpath(*PurePosixPath(logical_path).parts).resolve()
                self.assertEqual(Path(row["staged_path"]).resolve(), staged_path)
                self.assertTrue(staged_path.is_relative_to(stage_root.resolve()))
                self.assertEqual((staged_path.stat().st_size, sha256_file(staged_path)),
                                 (byte_count, expected_sha))
                workspace_file = ROOT.joinpath(*PurePosixPath(logical_path).parts)
                r3_file = R3_MIRROR.joinpath(*PurePosixPath(logical_path).parts)
                self.assertFalse(workspace_file.exists())
                self.assertFalse(r3_file.exists())
            self.assertEqual(set(v6_checked_paths), set(expected_v6_rows))
            self.assertEqual(set(v10_input_checked_paths), set(expected_v10_rows))
            self.assertGreaterEqual(len(v10_input_checked_paths), len(expected_v10_rows))

            expected_v10_calls = {(path, "file") for path, _, _ in R4_V10_STREAM_FILES}
            expected_v10_calls.add((R4_V10_RUNTIME_ROOT, "directory"))
            self.assertEqual(len(v10_binding_calls), 3)
            self.assertEqual({(logical, kind) for _, logical, _, kind, _ in v10_binding_calls},
                             expected_v10_calls)
            for call_root, logical, physical, kind, identity in v10_binding_calls:
                self.assertEqual(call_root.resolve(), ROOT.resolve())
                staged_identity = stage_root.joinpath(*PurePosixPath(logical).parts)
                repository_identity = ROOT.joinpath(*PurePosixPath(logical).parts)
                self.assertEqual(physical.resolve(), staged_identity.resolve())
                self.assertTrue(physical.resolve().is_relative_to(stage_root.resolve()))
                self.assertEqual(identity, repository_identity)
                if kind == "file":
                    _, expected_bytes, expected_sha = next(
                        row for row in R4_V10_STREAM_FILES if row[0] == logical)
                    self.assertEqual((physical.stat().st_size, sha256_file(physical)),
                                     (expected_bytes, expected_sha))
                else:
                    self.assertEqual((logical, kind), (R4_V10_RUNTIME_ROOT, "directory"))
                    self.assertTrue(physical.is_dir())
            v10_receipt = archive_resolution[R4_V10_ROOT_OBSERVATION_MATERIALIZATION_KEY]
            self.assertEqual((v10_receipt["schema"], v10_receipt["proof_sha256"],
                              v10_receipt["materialized_count"]),
                             (R4_V10_ROOT_OBSERVATION_MATERIALIZATION_SCHEMA,
                              sha256(canonical_json_bytes(p[R4_V10_ROOT_OBSERVATION_ADDENDUM_KEY])), 5))
            self.assertEqual([row["logical_path"] for row in v10_receipt["rows"]],
                             [row["logical_path"] for row in p[R4_V10_ROOT_OBSERVATION_ADDENDUM_KEY]["rows"]])
            proof_rows = p[R4_V10_ROOT_OBSERVATION_ADDENDUM_KEY]["rows"]
            self.assertEqual([{key: row[key] for key in proof_row}
                              for row, proof_row in zip(v10_receipt["rows"], proof_rows, strict=True)],
                             proof_rows)
            for row in v10_receipt["rows"]:
                logical_path = row["logical_path"]
                expected_stage_path = stage_root.joinpath(*PurePosixPath(logical_path).parts).resolve()
                self.assertEqual(Path(row["staged_path"]).resolve(), expected_stage_path)
                self.assertTrue(expected_stage_path.is_relative_to(stage_root.resolve()))
                byte_count, expected_sha = expected_v10_rows[logical_path]
                self.assertEqual((expected_stage_path.stat().st_size, sha256_file(expected_stage_path)),
                                 (byte_count, expected_sha))
                self.assertFalse(ROOT.joinpath(*PurePosixPath(logical_path).parts).exists())
                self.assertFalse(R3_MIRROR.joinpath(*PurePosixPath(logical_path).parts).exists())
            v10_prefix = next(
                row for row in adapted["archived_input_source"]["directory_prefixes"]
                if row["logical_path"] == R4_V10_RUNTIME_ROOT)
            self.assertEqual({key: v10_prefix[key] for key in R4_V10_PREFIX_EXPECTED},
                             R4_V10_PREFIX_EXPECTED)
            self.assertEqual(v10_prefix["archive_member_prefix"], R4_V10_RUNTIME_ROOT)
            self.assertEqual(v10_prefix["archive_sha256"], ARCHIVE_SHA256)
            self.assertEqual(v10_prefix["mirror_scope"], "explicitly_mapped_descendants_only")
            v6_review_result = result["v6_failure"]["postrun_review"]
            self.assertGreaterEqual(v6_review_result["manifest_entry_count"], 10)
            self.assertTrue(v6_review_result["report_path"].is_file())
            self.assertTrue(v6_review_result["manifest_path"].is_file())
            self.assertFalse(output_leaf.exists())
            self.assertEqual(_r3_mirror_snapshot(self.r3_protocol), mirror_snapshot)

        self.assertFalse(stage_root.exists(), "the isolated temporary stage clone must be removed")

        # This isolated helper control checks the exact restored-workspace route only.
        # The formal full-chain gate above uses the real ROOT, 613-row resolver, and staged inputs.
        with tempfile.TemporaryDirectory(prefix="up2_v10_path_binding_unit_") as fixture_temp:
            fixture_base = Path(fixture_temp)
            fixture_root = (fixture_base / "repository").resolve()
            fixture_stage_root = (fixture_base / "archive_mirror").resolve()
            fixture_root.mkdir()
            fixture_stage_root.mkdir()
            logical_path, byte_count, expected_sha = R4_V10_STREAM_FILES[0]
            payload_source = R3_MIRROR.joinpath(*PurePosixPath(logical_path).parts)
            payload = payload_source.read_bytes()
            self.assertEqual((len(payload), sha256(payload)), (byte_count, expected_sha))
            workspace_target = fixture_root.joinpath(*PurePosixPath(logical_path).parts)
            staged_target = fixture_stage_root.joinpath(*PurePosixPath(logical_path).parts)
            workspace_target.parent.mkdir(parents=True)
            staged_target.parent.mkdir(parents=True)
            workspace_target.write_bytes(payload)
            staged_target.write_bytes(payload)

            class FixtureResolver:
                def __init__(self) -> None:
                    self.root = fixture_root
                    self.archive_sha256 = ARCHIVE_SHA256
                    self.stage_root = fixture_stage_root
                    self.entries = {
                        logical_path: {
                            "logical_path": logical_path,
                            "archive_member": logical_path,
                            "archive_sha256": ARCHIVE_SHA256,
                            "bytes": byte_count,
                            "sha256": expected_sha,
                        }
                    }
                    self.staged = {logical_path: staged_target}
                    self.directories = {}

                def logical_path(self, candidate: Path) -> str | None:
                    if Path(candidate) in (workspace_target, staged_target):
                        return logical_path
                    return None

            class FixtureController:
                pass

            fixture_controller = FixtureController()
            fixture_controller.ARCHIVE_INPUTS = FixtureResolver()
            pinned_runner_root = runner_module.ROOT
            runner_module.ROOT = fixture_root
            try:
                workspace_identity = runner_module._r4_v10_original_path_binding(
                    fixture_controller, fixture_root, logical_path, workspace_target, "file")
                staged_identity = runner_module._r4_v10_original_path_binding(
                    fixture_controller, fixture_root, logical_path, staged_target, "file")
                expected_identity = fixture_root.joinpath(*PurePosixPath(logical_path).parts)
                self.assertEqual(workspace_identity, expected_identity)
                self.assertEqual(staged_identity, expected_identity)

                with self.assertRaisesRegex(ValueError, "exact repository root"):
                    runner_module._r4_v10_original_path_binding(
                        fixture_controller, fixture_root.parent, logical_path, staged_target, "file")
                wrong_stage_target = fixture_base.joinpath(
                    "wrong_stage", *PurePosixPath(logical_path).parts)
                with self.assertRaisesRegex(ValueError, "exact workspace or staged target"):
                    runner_module._r4_v10_original_path_binding(
                        fixture_controller, fixture_root, logical_path, wrong_stage_target, "file")
                with self.assertRaisesRegex(ValueError, "exact workspace or staged target"):
                    runner_module._r4_v10_original_path_binding(
                        fixture_controller, fixture_root,
                        R4_V10_STREAM_FILES[1][0], staged_target, "file")
                staged_target.write_bytes(payload + b"x")
                with self.assertRaisesRegex(ValueError, "frozen archive row"):
                    runner_module._r4_v10_original_path_binding(
                        fixture_controller, fixture_root, logical_path, staged_target, "file")
            finally:
                runner_module.ROOT = pinned_runner_root

        source = controller.R4_TRANSFORMED_CONTROLLER_SOURCE
        start = source.index("def verify_pre_output_contract(")
        end = source.index("\ndef ", start + 5)
        pre_output = source[start:end]
        ordered_calls = (
            "ARCHIVE_INPUTS = ArchivedInputResolver(ROOT, protocol)",
            "verify_frozen_resource_contract(protocol)",
            "validate_controller_overhead_contract(protocol)",
            "validate_aggregate_child_wall_contract(protocol)",
            "validate_process_tree_monitor_contract(protocol)",
            "resolve_output_target(ROOT, output_arg, protocol.get(\"output_leaf\"))",
            "verify_child_command_contract(protocol)",
            "verify_context_builder_contract(ROOT, protocol)",
            "verify_hydration_contract_text(",
            "verify_process_exit_race_contract_text(R4_TRANSFORMED_CONTROLLER_SOURCE)",
            "verify_v20_actual_failure(ROOT, protocol.get(\"parent_v20_actual_failure\"))",
            "verify_v8_context_rebuild_failure(ROOT, protocol)",
            "verify_v9_static_no_go_ancestry(ROOT, protocol)",
            "verify_v7_no_go_ancestry(",
            "verify_v14_actual_failure_ancestry(",
            "verify_v14_postrun_audit(",
            "verify_v15_actual_failure(",
            "verify_v16_actual_failure(",
            "verify_v17_actual_failure(",
            "verify_v18_actual_failure(",
            "verify_v19_actual_failure(",
            "verify_inventory(source_files)",
            "verify_inventory(evidence_docs)",
            "verify_v6_root_preflight_failure(",
            "verify_v10_timeout_receipts(",
            "verify_v10_replay_failure(",
            "verify_v11_actual_failure(",
            "verify_v12_static_no_go(",
            "verify_v13_static_candidate_and_no_go(",
        )
        positions = [pre_output.index(call) for call in ordered_calls]
        self.assertEqual(positions, sorted(positions))
        wrapper_source = R7_RUNNER.read_text(encoding="utf-8")
        route_start = wrapper_source.index("    def checked_path_with_fixed_absent_output_slots(")
        route_end = wrapper_source.index("\n    controller.checked_path =", route_start)
        checked_path_route = wrapper_source[route_start:route_end]
        route_calls = (
            "if isinstance(relative, str) and relative in R4_V6_SCOPEFIX_PATHS and",
            "raise ValueError(\"R4 V6 scopefix addendum route requires the exact repository root and resolver\")",
            "if relative in R4_V9_STATIC_RAW_PATHS:",
            "helper.resolve_v9_static_raw_output_sidecar_v21_r4(",
            "helper.resolve_historical_absent_output_slot_v21_r4(",
            "absolute_aliases.get(relative.replace(\"\\\\\", \"/\"))",
            "if logical is not None:",
            "return original(root, logical)",
            "if isinstance(relative, str) and relative in R4_V6_SCOPEFIX_PATHS:",
            "staged_paths = controller._r4_v6_scopefix_staged_paths",
            "return target",
            "if isinstance(relative, str) and relative in R4_V10_ROOT_OBSERVATION_PATHS:",
            "raise ValueError(\"R4 V10 root observation route requires the exact repository root and resolver stage\")",
            "staged_paths = controller._r4_v10_root_observation_staged_paths",
            "return target",
            "return original(root, relative)",
        )
        route_positions = [checked_path_route.index(call) for call in route_calls]
        self.assertEqual(route_positions, sorted(route_positions))
        wrapper_main = wrapper_source[wrapper_source.index("def main() -> int:"):]
        wrapper_dispatch_calls = (
            "preflight = verify_v10_closure_before_mirror(",
            "resolver = original_resolver(root, protocol)",
            'validated_addendum = preflight.get("r4_v6_scopefix_closure_addendum")',
            "_materialize_v6_scopefix_closure_addendum(",
            "controller._r4_v6_scopefix_staged_paths = {",
            "controller._r4_v6_scopefix_addendum_materialization = addendum_receipt",
            "helper.materialize_v9_static_raw_output_sidecar_v21_r4(",
            "validated_v10_addendum = preflight._validated_v10_addendum",
            "_materialize_v10_root_observation_input_addendum(",
            "controller._r4_v10_root_observation_staged_paths = {",
            "controller._r4_v10_root_observation_materialization = v10_receipt",
            "receipt[R4_V10_ROOT_OBSERVATION_MATERIALIZATION_KEY] = dict(v10_receipt)",
            "resolver.resolution_receipt = resolution_receipt_with_r4_addenda",
            "controller.ArchivedInputResolver = resolver_with_read_only_preflight",
        )
        wrapper_dispatch_positions = [wrapper_main.index(call) for call in wrapper_dispatch_calls]
        self.assertEqual(wrapper_dispatch_positions, sorted(wrapper_dispatch_positions))
        _assert_r6_outputs_absent()
        self.assertEqual(_r3_mirror_snapshot(self.r3_protocol), mirror_snapshot)
        _assert_r3_mirror_unchanged()
        _assert_r2_mirror_unchanged()

    def test_r4_v20_inventory_accepts_only_logical_order_and_exact_rows(self) -> None:
        controller = self.controller
        p = self.protocol
        evidence = p["parent_v20_actual_failure"]
        mirror_snapshot = _r3_mirror_snapshot(self.r3_protocol)
        adapted = _r4_protocol_for_existing_r3_mirror(p)
        original_archive_inputs = controller.ARCHIVE_INPUTS
        resolver = controller.ArchivedInputResolver(ROOT, adapted)
        controller.ARCHIVE_INPUTS = resolver
        try:
            from_workspace_context = controller.verify_v20_actual_failure(ROOT, evidence)
            from_mapped_mirror_context = controller.verify_v20_actual_failure(R3_MIRROR, evidence)
            self.assertEqual(from_workspace_context["runtime_entries"], evidence["runtime_entries"])
            self.assertEqual(from_mapped_mirror_context["runtime_entries"], evidence["runtime_entries"])
            self.assertEqual(controller.logical_path_for_path(Path(from_workspace_context["runtime_root"])),
                             evidence["output_leaf"])
            self.assertEqual(controller.logical_path_for_path(Path(from_mapped_mirror_context["runtime_root"])),
                             evidence["output_leaf"])
            actual_rows = controller.file_inventory(Path(from_mapped_mirror_context["runtime_root"]))
            self.assertEqual((len(actual_rows), sum(row["bytes"] for row in actual_rows)), (21, 3365672))
            self.assertEqual({row["path"]: (row["bytes"], row["sha256"]) for row in actual_rows},
                             {row["path"]: (row["bytes"], row["sha256"])
                              for row in evidence["runtime_entries"]})

            reordered = copy.deepcopy(evidence)
            reordered["runtime_entries"] = list(reversed(reordered["runtime_entries"]))
            reordered_result = controller.verify_v20_actual_failure(ROOT, reordered)
            self.assertEqual(reordered_result["runtime_entries"], reordered["runtime_entries"])

            original_rows = evidence["runtime_entries"]
            duplicate = copy.deepcopy(evidence)
            duplicate["runtime_entries"][0] = copy.deepcopy(duplicate["runtime_entries"][1])
            missing = copy.deepcopy(evidence)
            missing["runtime_entries"].pop(0)
            runtime_prefix = str(PurePosixPath(evidence["output_leaf"]).as_posix()).rstrip("/") + "/"
            external_archive_row = next(
                row for row in p["archived_input_source"]["entries"]
                if not row["logical_path"].startswith(runtime_prefix))
            extra = copy.deepcopy(evidence)
            extra["runtime_entries"].append({
                "path": external_archive_row["logical_path"],
                "bytes": external_archive_row["bytes"],
                "sha256": external_archive_row["sha256"],
            })
            size = copy.deepcopy(evidence)
            size["runtime_entries"][0]["bytes"] += 1
            digest_change = copy.deepcopy(evidence)
            digest_change["runtime_entries"][0]["sha256"] = "0" * 64
            for label, changed in (("duplicate", duplicate), ("missing", missing), ("extra", extra),
                                   ("size", size), ("sha256", digest_change)):
                with self.subTest(control=label), self.assertRaises((ValueError, FileNotFoundError)):
                    controller.verify_v20_actual_failure(ROOT, changed)
            self.assertEqual(evidence["runtime_entries"], original_rows)
        finally:
            controller.ARCHIVE_INPUTS = original_archive_inputs
        _assert_r4_outputs_absent()
        self.assertEqual(_r3_mirror_snapshot(self.r3_protocol), mirror_snapshot)
        _assert_r3_mirror_unchanged()
        _assert_r2_mirror_unchanged()


if __name__ == "__main__":
    unittest.main(verbosity=2)
