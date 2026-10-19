"""Verify formal T1 software evidence, then run T2 producer/replay serially.

This controller stays small while each Julia child is alive.  It never keeps a
Julia object graph between phases, and it does not create or infer a T1
software-acceptance manifest.  The root-issued manifest and its independently
supplied raw SHA-256 are mandatory inputs.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import traceback
import types
from typing import Any

import psutil


ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
EVIDENCE_ROOT = (ROOT / "runs/UP1-04A-VNEXT-T2").resolve()
R3_DISPATCH_ROOT = (ROOT /
    "docs/implementation/UP1-04A-VNEXT-T2/formal_t2_dispatch_r3").resolve()
R3_RUNTIME_INPUTS_PATH = R3_DISPATCH_ROOT / "runtime_inputs.json"
R3_PROTOCOL_PATH = R3_DISPATCH_ROOT / "protocol.json"
R3_DISPATCH_PATH = R3_DISPATCH_ROOT / "dispatch.json"
R3_SNAPSHOT_PATH = R3_DISPATCH_ROOT / "snapshot.json"
R3_COMMAND_PATH = R3_DISPATCH_ROOT / "command.txt"
R3_RUNTIME_PARSE_MANIFEST_PATH = (ROOT /
    "docs/implementation/UP1-04A-VNEXT-T2/formal_t2_serial_replay_r3/"
    "runtime_parse_manifest.tsv").resolve()
R3_HISTORICAL_RECEIPTS = {
    "runtime_inputs.json": (25_331,
        "279310d67e5f151578b9a141893a4f8b197973379cad93c0a1f90444d2360538"),
    "protocol.json": (9_884,
        "a849e32bb5fa94d2667ca9bc1cc0760bdd4362013f54e7ce0b6e50481ad15e9e"),
    "dispatch.json": (9_753,
        "4eb241995d58739ecef15429893a72eef4016e6a77654fba63c60f8cf66da748"),
    "snapshot.json": (1_165,
        "412ef07a312cd3d3a7d83f891daba3f73d8e78eff897a1c7a54e0aec7954efec"),
    "command.txt": (947,
        "4f187f1d55b5bb819c70436ce5cbd4c9320fdc360edf64d70075dcd403be72fe"),
    "runtime_parse_manifest.tsv": (10_142,
        "07b7b41bbf63fca831bc0608024c83e6079641552bd3dbbca0ff2071cfd8713f"),
}
ORIGINAL_JULIA_PARSE_PATH_COUNT = 92
MANAGED_JULIA_PARSE_PATH_COUNT = 2
COMBINED_JULIA_PARSE_PATH_COUNT = 94
POSITIVE_PROTOCOL_SCHEMA = "vnext-t2-positive-managed-execution-protocol-r2"
R23_CONTROLLER_RELATIVE = (
    "test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
    "independent_negative_controller_r23.py")
R23_TABLE_RELATIVE = (
    "test/RuntimeV4/NativeG1G2DiffusionV1/native_process_table_r23_v1.py")
R23_SUPERVISOR_RELATIVE = (
    "test/RuntimeV4/NativeG1G2DiffusionV1/supervise_r16_root_audit_r23_v1.py")
R23_LIFECYCLE_RELATIVE = "tools/execution/windows_process_lifecycle.py"
T2_SOURCE_INPUTS_RELATIVE = "tools/execution/t2_source_inputs.py"
WORKSPACE_SOURCES_RELATIVE = "tools/workspace_sources.py"
MANAGED_CLIENT_RELATIVE = "src/GenomeV5/Integration/ManagedExternalProcessV1.jl"
NATIVE_GIT_RELATIVE = "src/GenomeV5/Integration/NativeGitReadCompatibilityV1.jl"
MANAGED_EXECUTION_SOURCE_PATHS = (
    R23_CONTROLLER_RELATIVE,
    R23_TABLE_RELATIVE,
    R23_SUPERVISOR_RELATIVE,
    R23_LIFECYCLE_RELATIVE,
    MANAGED_CLIENT_RELATIVE,
    NATIVE_GIT_RELATIVE,
    T2_SOURCE_INPUTS_RELATIVE,
    WORKSPACE_SOURCES_RELATIVE,
)
MANAGED_LIFECYCLE_SOURCE_PATHS = (
    R23_LIFECYCLE_RELATIVE,
    MANAGED_CLIENT_RELATIVE,
    NATIVE_GIT_RELATIVE,
)
MANAGED_JULIA_PARSE_PATHS = (MANAGED_CLIENT_RELATIVE, NATIVE_GIT_RELATIVE)
EXPECTED_MIGRATION_CHANGED_PATHS = {
    "Project.toml",
    "src/GenomeV5/G1/G1SourceAuthorityFactoryV1.jl",
    "src/GenomeV5/G2/G2SourceAuthorityFactoryV1.jl",
    "src/GenomeV5/G3/G3SourceAuthorityFactoryV1.jl",
    "test/GenomeV5/Integration/vnext_declaration_transport_local_v1_tests.jl",
    "test/GenomeV5/Integration/VNextT2IdentityReceiptV2/formal_t2_controller.py",
    "test/GenomeV5/Integration/VNextT2IdentityReceiptV2/formal_t1_software_manifest_v1.py",
}
POSITIVE_PHASE_ORDER = ("parse_gate", "clean_load", "producer", "replay")
POSITIVE_PHASE_TIMEOUT_SECONDS = 300.0
POSITIVE_RSS_LIMIT_BYTES = 2_147_483_648
POSITIVE_SAMPLE_INTERVAL_SECONDS = 0.2
POSITIVE_MAX_SAMPLE_ATTEMPTS = 2
POSITIVE_JULIA_THREADS = 1
T1_VERIFIER_RELATIVE = (
    "test/GenomeV5/Integration/VNextT2IdentityReceiptV2/"
    "formal_t1_software_manifest_v1.py")
T1_HISTORICAL_INDEX_RELATIVE = (
    "test/fixtures/historical_sources/t1_manifest_index.json")
T1_HISTORICAL_INDEX_BYTES = 36_185
T1_HISTORICAL_INDEX_SHA256 = (
    "57a3ddad571af1f4915c421af60231506474571d3bf355c2a51247113b95e07c")
T1_HISTORICAL_ARCHIVE_PATH = Path(
    "D:/006-Programing/LMC/FusionConceptAI_cleanup_20260926/"
    "precleanup_docs_runs_tmp.zip")
T1_HISTORICAL_ARCHIVE_BYTES = 472_888_641
T1_HISTORICAL_ARCHIVE_SHA256 = (
    "c84743bc55dc749bbcc43e936c278027ad9bce9b437c09e176be587f75ff2bb7")
T1_HISTORICAL_SNAPSHOT_ID = "t1-r26-precleanup-20260926"
T1_HISTORICAL_IDENTITY_COUNT = 49
T1_HISTORICAL_DATA_SCHEMA = "vnext-t2-positive-t1-historical-data-r1"
EXPECTED_T1_SOURCE_PATHS = (
    "src/Contracts/CandidateStatePackageV5Next.jl",
    "src/Contracts/CandidateStatePackageV5NextV2.jl",
    "src/Contracts/VNextT1PackageBindingAdapterV2.jl",
    "src/Contracts/VNextT1CandidateBindingV2.jl",
    "src/GenomeV5/Integration/VNextDeclarationAuthorityRecheckLocalV2.jl",
    "src/GenomeV5/Integration/VNextGenomeV5IntegrationV2.jl",
    "src/GenomeV5/Integration/VNextGenomeV5Integration.jl",
)
HEX64 = re.compile(r"^[0-9a-f]{64}$")
_T1_VERIFIER: Any | None = None
_HISTORICAL_READER_MODULE: Any | None = None
_R23_RUNTIME: Any | None = None
_R23_PROTOCOL_SHA256: str | None = None
_POSITIVE_PROTOCOL: dict[str, Any] | None = None
DRIVER = HERE / "formal_candidate_driver.jl"
CLEAN_LOAD_DRIVER = HERE / "module_entry_clean_load.jl"
PACKAGE_PROJECTION_REGRESSION = \
    HERE / "vnext_t2_package_full_content_projection_r1.jl"
PARSE_GATE = ROOT / (
    "test/GenomeV5/Integration/VNextT2ConcreteSourceWitnessV3/parse_gate.jl")
FUSION_ENTRY = ROOT / "src/FusionConceptAI.jl"
T2_LOADER = ROOT / "src/GenomeV5/Integration/VNextT2ModuleEntryV2.jl"
T1_SOFTWARE_MANIFEST = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T1/"
    "formal_software_acceptance_r26_v9_r1/software_acceptance_manifest.json")
T1_SOFTWARE_MANIFEST_SHA256 = \
    "11f411be3feba7e2be9f11047cd33cf8de56e26d8c8af93545f791a04d2d5c1e"
V3_QUALIFICATION = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2-SOURCE-WITNESS-PREC/"
    "software_acceptance_runtime_r5_r1/software_qualification.json")
V3_QUALIFICATION_SCHEMA = \
    "vnext-t2-source-witness-software-qualification-r1"
V3_QUALIFICATION_SHA256 = \
    "b3361b6ff968452e5ca94471ba9b9a72e7a9d198cd8818f81d4c918f7c5018c2"
V3_QUALIFIED_SOURCE = \
    "src/GenomeV5/Integration/VNextT2ConcreteSourceWitnessV3.jl"
V3_QUALIFIED_SOURCE_SHA256 = \
    "f381f4ed8e48dba499ddbe877d638838240cf4fcf99d4718ba177c2b5d7b2bd9"
V3_QUALIFICATION_EVIDENCE = {
    "review": (
        "docs/implementation/UP1-04A-VNEXT-T2-SOURCE-WITNESS-PREC/"
        "astra_runtime_r5_review_r1_20260922/actual_review.json",
        78_236,
        "97a22a469b1fe60185513a52dc082825a01a1c09b59052abbcaa2a1f1afc4946",
    ),
    "pipeline": (
        "docs/implementation/UP1-04A-VNEXT-T2-SOURCE-WITNESS-PREC/"
        "agent_r1_20260922/runtime_r5/pipeline_final.json",
        46_759,
        "c01892c882a499a24f3063e6b37d70c302c92822ee4043b50a44586c3b944314",
    ),
    "controller": (
        "docs/implementation/UP1-04A-VNEXT-T2-SOURCE-WITNESS-PREC/"
        "agent_r1_20260922/runtime_r5_external_launch/final.json",
        860,
        "f15f8d2e855d1cc9de99cd9fa292eebd3e1194ba6594d2b6b0ae6590c1c6b4e2",
    ),
    "coverage": (
        "docs/implementation/UP1-04A-VNEXT-T2-SOURCE-WITNESS-PREC/"
        "agent_r1_20260922/runtime_r5/shard_runtime_coverage.json",
        4_568,
        "11401f06213acd03d2dae8c5451350ff94eed73123b5149bbf2945bf3ba3488b",
    ),
}
HEAVY_NAMES = {
    "julia.exe", "julia", "desc.exe", "desc", "mesh.exe", "mesh",
    "mpiexec.exe", "mpiexec",
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
V3_EXPLICIT_SOURCE_DEPENDENCIES = (
    "src/GenomeV5/Integration/VNextDeclarationAuthorityRecheckLocalV1.jl",
    "src/GenomeV5/Integration/VNextParentBaselineBindingLocalV1.jl",
    "src/GenomeV5/G3/G3RealizationChildEditabilityV1.jl",
    "src/GenomeV5/G3/G3ControlChildEditabilityV1.jl",
    "src/GenomeV5/G3/G3BindingChildEditabilityV1.jl",
    "src/GenomeV5/G3/G3BindingChildEditabilityV2.jl",
    "src/GenomeV5/Integration/VNextG3BindingAuthorityBridgeLocalV1.jl",
)
T2_LOADER_DEFINITIONS = (
    ("GenomeV5/G1/DiffusionDeclarationV1.jl", "G1DiffusionDeclarationV1"),
    ("GenomeV5/G1/G1SourceAuthorityFactoryV1.jl", "G1SourceFactoryConstructionResultV1"),
    ("GenomeV5/G2/MetricBoundaryDeclarationV1.jl", "G2MBDeclarationV1"),
    ("GenomeV5/G2/G2SourceAuthorityFactoryV1.jl", "G2SourceFactoryConstructionResultV1"),
    ("GenomeV5/G3/G3SourceFeedbackLawV1.jl", "G3SFDeclarationV1"),
    ("GenomeV5/G3/G3SourceAuthorityFactoryV1.jl", "G3FactoryConstructionResultV1"),
    ("GenomeV5/Integration/VNextDeclarationTransportLocalV1.jl", "VNextT0LocalTransportV1"),
    ("GenomeV5/Integration/VNextDeclarationAuthorityRecheckLocalV1.jl", "VNextAuthorityRecheckLocalResultV1"),
    ("GenomeV5/Integration/VNextParentBaselineBindingLocalV1.jl", "T0LocalParentBaselineBindResultV1"),
    ("GenomeV5/G3/G3RealizationChildEditabilityV1.jl", "G3RealizationSourceStateV1"),
    ("GenomeV5/G3/G3ControlChildEditabilityV1.jl", "G3ControlStateV1"),
    ("GenomeV5/G3/G3BindingChildEditabilityV1.jl", "G3BindingStateV1"),
    ("GenomeV5/G3/G3BindingChildEditabilityV2.jl", "G3BindingStateV2"),
    ("GenomeV5/Integration/VNextG3BindingAuthorityBridgeLocalV1.jl", "VNextG3BindingAuthorityExpectedCommitmentV1"),
    ("GenomeV5/Integration/VNextT2ConcreteSourceWitnessV3.jl", "VNextT2ConcreteSourceWitnessV3"),
    ("Contracts/VNextT1CanonicalBytesV2.jl", "VNextT1CanonicalBytesV2"),
    ("Contracts/VNextT1CandidateBindingV2.jl", "VNextT1CandidateBindingInputV2"),
    ("GenomeV5/Integration/VNextDeclarationAuthorityRecheckLocalV2.jl", "VNextAuthorityRecheckLocalV2Input"),
    ("Contracts/CandidateStatePackageV5NextV2.jl", "CandidateStatePackageV5NextV2"),
    ("GenomeV5/Integration/VNextGenomeV5IntegrationV2.jl", "VNextT1AdmissionInputV2"),
    ("Contracts/VNextT1PackageBindingAdapterV2.jl", "VNextT1PackageBindingAdapterResultV2"),
    ("GenomeV5/UP2/VNextT2UP2AdapterV2.jl", "VNextT2UP2BoundInputV2"),
    ("GenomeV5/UP2/VNextT2IdentityReceiptProjectionV2.jl", "VNextT2IdentityProjectionV2"),
    ("GenomeV5/Integration/VNextT2IdentityReceiptIntegrationV2.jl", "VNextT2ReceiptLedgerV2"),
)


def utc() -> str:
    return datetime.now(timezone.utc).isoformat()


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def digest_value(value: Any, label: str) -> str:
    if isinstance(value, dict) and set(value) == {"value"}:
        value = value["value"]
    if not isinstance(value, str) or not HEX64.fullmatch(value):
        raise RuntimeError(f"{label} is not a canonical Digest256 value")
    return value


def file_receipt(path: Path) -> dict[str, Any]:
    data = path.read_bytes()
    return {"path": path.relative_to(ROOT).as_posix(), "bytes": len(data),
            "sha256": sha256_bytes(data)}


def verify_v3_qualification(path: Path,
                            expected_sha256: str) -> dict[str, Any]:
    if path != V3_QUALIFICATION:
        raise RuntimeError("source-witness qualification path mismatch")
    if expected_sha256 != V3_QUALIFICATION_SHA256:
        raise RuntimeError("source-witness qualification expected hash mismatch")
    if not path.is_file():
        raise FileNotFoundError(
            f"source_witness_software_qualification_absent: {path}")
    receipt = file_receipt(path)
    if receipt["sha256"] != expected_sha256:
        raise RuntimeError("source-witness qualification raw hash mismatch")
    document = json.loads(path.read_text(encoding="utf-8"))
    expected_scalars = {
        "schema": V3_QUALIFICATION_SCHEMA,
        "task": "UP1-04A-VNEXT-T2-SOURCE-WITNESS-PREC",
        "accepted_by": "root",
        "software_qualified": True,
        "acceptance_scope":
            "exact_frozen_V3_source_witness_software_capability",
        "claim_ceiling": "contract_only",
        "runtime_protocol_sha256":
            "524fd391ea2fc826a4985cb617aadfcbb68e26721013fa80bedf01e49ff5525e",
        "historical_dependencies": 91,
        "parse_files": 84,
        "syntactic_sites": 103,
        "runtime_hits": 115,
        "natural_stages": 11,
        "controller_natural_exit": 0,
        "independent_review_checks": 253,
        "implementer": "source_witness",
        "independent_executor": "parallel_independent_tests",
        "independent_reviewer": "t1_semantics_review",
        "formal_T2_accepted": False,
        "UP2_accepted": False,
        "physical_coupling_accepted": False,
        "scientific_acceptance": False,
        "R01_R10_complete": False,
    }
    for key, expected in expected_scalars.items():
        if document.get(key) != expected:
            raise RuntimeError(
                f"source-witness qualification field mismatch: {key}")
    expected_gaps = [
        "g1_g2_coordinate_pullback_missing",
        "g1_g3_feedback_conversion_missing",
        "g2_thermal_target_material_missing",
    ]
    if document.get("preserved_gaps") != expected_gaps:
        raise RuntimeError("source-witness qualification gap set mismatch")
    qualified_source = document.get("qualified_source")
    if qualified_source != {
            "path": V3_QUALIFIED_SOURCE,
            "sha256": V3_QUALIFIED_SOURCE_SHA256}:
        raise RuntimeError("source-witness qualified source mismatch")
    source_receipt = file_receipt(ROOT / V3_QUALIFIED_SOURCE)
    if source_receipt["sha256"] != V3_QUALIFIED_SOURCE_SHA256:
        raise RuntimeError("source-witness qualified source changed")
    evidence = document.get("evidence")
    if not isinstance(evidence, dict) or \
            set(evidence) != set(V3_QUALIFICATION_EVIDENCE):
        raise RuntimeError("source-witness qualification evidence set mismatch")
    evidence_receipts: dict[str, dict[str, Any]] = {}
    for label, (relative, byte_count, sha256) in \
            V3_QUALIFICATION_EVIDENCE.items():
        expected = {"path": relative, "bytes": byte_count, "sha256": sha256}
        if evidence.get(label) != expected:
            raise RuntimeError(
                f"source-witness qualification evidence mismatch: {label}")
        actual = file_receipt(ROOT / relative)
        if actual != expected:
            raise RuntimeError(
                f"source-witness qualification evidence changed: {label}")
        evidence_receipts[label] = actual
    return {
        "schema": "vnext-t2-source-witness-qualification-verification-r1",
        "verified": True,
        "qualification": receipt,
        "qualified_source": source_receipt,
        "evidence": evidence_receipts,
        "software_qualified": True,
        "formal_t2_accepted": False,
        "physical_acceptance": False,
        "scientific_acceptance": False,
    }


def fusion_package_source_paths() -> tuple[list[Path], tuple[str, ...]]:
    """Return the exact static include closure loaded by `using FusionConceptAI`."""
    text = FUSION_ENTRY.read_text(encoding="utf-8")
    includes = tuple(re.findall(
        r'^\s*include\("([^"\r\n]+\.jl)"\)\s*$', text,
        flags=re.MULTILINE,
    ))
    include_call_count = len(re.findall(r"\binclude\(", text))
    if len(includes) != include_call_count:
        raise RuntimeError(
            "unresolved FusionConceptAI include form: "
            f"resolved={len(includes)} calls={include_call_count}")
    return [FUSION_ENTRY, *(ROOT / "src" / item for item in includes)], includes


def assert_explicit_runtime_inventory() -> None:
    genome_loader = ROOT / "src/GenomeV5/Integration/GenomeV5Integration.jl"
    loader_names = set(re.findall(
        r'"([^"\r\n]+\.jl)"', genome_loader.read_text(encoding="utf-8")))
    expected_loader_names = {
        Path(item).name for item in GENOME_V5_DYNAMIC_COMPONENTS}
    if loader_names != expected_loader_names:
        raise RuntimeError(
            "GenomeV5 dynamic component inventory mismatch: "
            f"observed={sorted(loader_names)} expected={sorted(expected_loader_names)}")

    t0_helper = ROOT / T0_DEFINITION_DEPENDENCIES[0]
    t0_preamble = t0_helper.read_text(encoding="utf-8").split(
        "# Current factory APIs", 1)[0]
    t0_names = set(re.findall(r'"([^"\r\n]+\.jl)"', t0_preamble))
    expected_t0_names = {
        Path(item).name for item in T0_DEFINITION_DEPENDENCIES[1:]}
    if t0_names != expected_t0_names or \
            "load_genome_v5_components!()" not in t0_preamble:
        raise RuntimeError(
            "T0 definition include inventory mismatch: "
            f"observed={sorted(t0_names)} expected={sorted(expected_t0_names)}")

    v3_fixture = ROOT / (
        "test/GenomeV5/Integration/VNextT2ConcreteSourceWitnessV3/fixture_helpers.jl")
    v3_preamble = v3_fixture.read_text(encoding="utf-8").split(
        "const V3_CANDIDATE", 1)[0]
    v3_names = set(re.findall(r'"([^"\r\n]+\.jl)"', v3_preamble))
    expected_v3_names = {
        Path(T0_DEFINITION_DEPENDENCIES[0]).name,
        "VNextT2ConcreteSourceWitnessV3.jl",
        *(Path(item).name for item in V3_EXPLICIT_SOURCE_DEPENDENCIES),
    }
    if v3_names != expected_v3_names:
        raise RuntimeError(
            "V3 fixture include inventory mismatch: "
            f"observed={sorted(v3_names)} expected={sorted(expected_v3_names)}")

    loader_text = T2_LOADER.read_text(encoding="utf-8")
    loader_rows = tuple(re.findall(
        r'^\s*\("([^"\r\n]+\.jl)",\s*:([A-Za-z0-9_]+)\),\s*$',
        loader_text, flags=re.MULTILINE))
    if loader_rows != T2_LOADER_DEFINITIONS or \
            loader_text.count("Base.include(@__MODULE__") != 1:
        raise RuntimeError("T2 definition loader inventory/order mismatch")

    t2_fixture = HERE / "fixture_helpers.jl"
    t2_names = set(re.findall(
        r'"([^"\r\n]+\.jl)"', t2_fixture.read_text(encoding="utf-8")))
    expected_t2_names = {
        "fixture_helpers.jl",
        *(Path(relative).name for relative, _ in T2_LOADER_DEFINITIONS[15:]),
    }
    if t2_names != expected_t2_names:
        raise RuntimeError(
            "T2 fixture include inventory mismatch: "
            f"observed={sorted(t2_names)} expected={sorted(expected_t2_names)}")
    driver_includes = set(re.findall(
        r'include\(joinpath\(@__DIR__,\s*"([^"\r\n]+\.jl)"\)\)',
        DRIVER.read_text(encoding="utf-8"), flags=re.MULTILINE))
    if driver_includes != {"fixture_helpers.jl"}:
        raise RuntimeError(f"formal candidate driver include drift: {driver_includes}")


def assert_shared_entry_connected(static_includes: tuple[str, ...]) -> None:
    expected = "GenomeV5/Integration/VNextT2ModuleEntryV2.jl"
    if expected not in static_includes:
        raise RuntimeError(
            "shared_entry_not_connected: FusionConceptAI.jl does not include "
            "VNextT2ModuleEntryV2.jl")


def runtime_julia_paths() -> list[Path]:
    assert_explicit_runtime_inventory()
    package_paths, _ = fusion_package_source_paths()
    paths = set(package_paths)
    paths.update(ROOT / item for item in GENOME_V5_DYNAMIC_COMPONENTS)
    paths.update(ROOT / item for item in T0_DEFINITION_DEPENDENCIES)
    paths.update(ROOT / item for item in V3_EXPLICIT_SOURCE_DEPENDENCIES)
    paths.update(ROOT / "src" / relative
                 for relative, _ in T2_LOADER_DEFINITIONS)
    paths.update((
        T2_LOADER,
        ROOT / "test/GenomeV5/Integration/VNextT2ConcreteSourceWitnessV3/fixture_helpers.jl",
        HERE / "fixture_helpers.jl",
        DRIVER,
        CLEAN_LOAD_DRIVER,
        PACKAGE_PROJECTION_REGRESSION,
        PARSE_GATE,
    ))
    missing = [str(path) for path in paths if not path.is_file()]
    if missing:
        raise FileNotFoundError(
            "formal runtime Julia dependency missing: " + json.dumps(missing))
    return sorted(path.resolve() for path in paths)


def runtime_dependency_paths() -> list[Path]:
    paths = set(runtime_julia_paths())
    paths.update((
        ROOT / T1_VERIFIER_RELATIVE,
        HERE / "formal_t2_controller.py",
        ROOT / "Project.toml",
        ROOT / "Manifest.toml",
        T1_SOFTWARE_MANIFEST,
        V3_QUALIFICATION,
        ROOT / V3_QUALIFIED_SOURCE,
    ))
    paths.update(ROOT / relative
                 for relative, _, _ in V3_QUALIFICATION_EVIDENCE.values())
    paths.update(ROOT / relative for relative in EXPECTED_T1_SOURCE_PATHS)
    missing = [str(path) for path in paths if not path.is_file()]
    if missing:
        raise FileNotFoundError(
            "formal runtime dependency missing: " + json.dumps(missing))
    return sorted(path.resolve() for path in paths)


def runtime_receipts() -> dict[str, dict[str, Any]]:
    return {
        path.relative_to(ROOT).as_posix(): file_receipt(path)
        for path in runtime_dependency_paths()
    }


def relative_source_receipt(relative: str) -> dict[str, Any]:
    if not isinstance(relative, str) or not relative or \
            "\\" in relative or relative.startswith("/") or \
            any(part in {"", ".", ".."} for part in relative.split("/")):
        raise ValueError(f"managed source path is not canonical: {relative!r}")
    path = ROOT.joinpath(*relative.split("/"))
    data = path.read_bytes()
    return {"path": relative, "bytes": len(data), "sha256": sha256_bytes(data)}


def runtime_input_pins(receipts: dict[str, dict[str, Any]]) -> dict[str, dict[str, Any]]:
    if type(receipts) is not dict or len(receipts) != 104:
        raise RuntimeError("original positive runtime_receipts must remain exactly 104")
    rows: dict[str, dict[str, Any]] = {}
    for relative, receipt in sorted(receipts.items()):
        if type(relative) is not str or not isinstance(receipt, dict) or \
                type(receipt.get("bytes")) is not int or receipt["bytes"] < 0 or \
                type(receipt.get("sha256")) is not str or \
                not HEX64.fullmatch(receipt["sha256"]):
            raise RuntimeError(f"original runtime receipt is malformed: {relative!r}")
        rows[relative] = {"path": relative, "bytes": receipt["bytes"],
                          "sha256": receipt["sha256"]}
    return rows


def managed_source_receipts() -> dict[str, dict[str, Any]]:
    return {relative: relative_source_receipt(relative)
            for relative in MANAGED_EXECUTION_SOURCE_PATHS}


def _load_exact_source_module(name: str, relative: str,
                              expected: dict[str, Any]) -> Any:
    """Compile only bytes whose canonical path, size, and SHA were preverified."""
    if type(expected) is not dict or set(expected) != {"path", "bytes", "sha256"} or \
            expected.get("path") != relative or \
            type(expected.get("bytes")) is not int or expected["bytes"] < 0 or \
            type(expected.get("sha256")) is not str or \
            not HEX64.fullmatch(expected["sha256"]):
        raise RuntimeError(f"pinned source row is malformed: {relative}")
    path = ROOT.joinpath(*relative.split("/"))
    source = path.read_bytes()
    if len(source) != expected["bytes"] or \
            sha256_bytes(source) != expected["sha256"]:
        raise RuntimeError(f"pinned source drift before compile/exec: {relative}")
    existing = sys.modules.get(name)
    if existing is not None:
        if getattr(existing, "__file__", None) != str(path.resolve()) or \
                getattr(existing, "__source_sha256__", None) != expected["sha256"]:
            raise RuntimeError(f"preloaded module identity is not pinned: {name}")
        return existing
    module = types.ModuleType(name)
    module.__file__ = str(path.resolve())
    module.__source_sha256__ = expected["sha256"]
    module.__package__ = name.rpartition(".")[0]
    sys.modules[name] = module
    try:
        if str(ROOT) not in sys.path:
            sys.path.insert(0, str(ROOT))
        exec(compile(source, str(path), "exec"), module.__dict__)
    except BaseException:
        sys.modules.pop(name, None)
        raise
    after = path.read_bytes()
    if len(after) != expected["bytes"] or \
            sha256_bytes(after) != expected["sha256"] or \
            module.__file__ != str(path.resolve()) or \
            module.__source_sha256__ != expected["sha256"]:
        sys.modules.pop(name, None)
        raise RuntimeError(f"pinned source drift after compile/exec: {relative}")
    return module


def _ensure_managed_namespace_packages() -> None:
    for package_name, package_path in (
            ("tools", ROOT / "tools"),
            ("tools.execution", ROOT / "tools" / "execution")):
        existing = sys.modules.get(package_name)
        expected_package_path = str(package_path.resolve())
        if existing is None:
            namespace = types.ModuleType(package_name)
            namespace.__path__ = [expected_package_path]
            namespace.__package__ = package_name
            sys.modules[package_name] = namespace
        else:
            module_paths = [str(Path(item).resolve())
                            for item in getattr(existing, "__path__", ())]
            if module_paths != [expected_package_path] or \
                    getattr(existing, "__file__", None) is not None:
                raise RuntimeError(f"namespace package path is not pinned: {package_name}")


def _t1_historical_data_group(reader_module: Any) -> dict[str, Any]:
    index_path = ROOT.joinpath(*T1_HISTORICAL_INDEX_RELATIVE.split("/"))
    archive_path = T1_HISTORICAL_ARCHIVE_PATH
    reader_type = getattr(reader_module, "HistoricalSourceReader", None)
    if reader_type is None:
        raise RuntimeError("pinned T1 historical reader is unavailable")
    with reader_type(index_path, T1_HISTORICAL_INDEX_SHA256, archive_path,
                     strict_subset=True) as reader:
        identities = reader.indexed_identities
        if type(identities) is not frozenset or \
                len(identities) != T1_HISTORICAL_IDENTITY_COUNT or \
                any(type(identity) is not tuple or len(identity) != 2 or
                    type(identity[0]) is not str or
                    type(identity[1]) is not str or
                    identity[1] != T1_HISTORICAL_SNAPSHOT_ID
                    for identity in identities):
            raise RuntimeError("T1 historical index identity set differs")
    index_raw = index_path.read_bytes()
    index_receipt = {
        "path": T1_HISTORICAL_INDEX_RELATIVE,
        "bytes": len(index_raw),
        "sha256": sha256_bytes(index_raw),
    }
    if index_receipt != {
            "path": T1_HISTORICAL_INDEX_RELATIVE,
            "bytes": T1_HISTORICAL_INDEX_BYTES,
            "sha256": T1_HISTORICAL_INDEX_SHA256}:
        raise RuntimeError("T1 historical index receipt differs from its fixed pin")
    return {
        "schema": T1_HISTORICAL_DATA_SCHEMA,
        "snapshot_id": T1_HISTORICAL_SNAPSHOT_ID,
        "indexed_identity_count": T1_HISTORICAL_IDENTITY_COUNT,
        "index": index_receipt,
        "archive": {
            "path": archive_path.as_posix(),
            "bytes": T1_HISTORICAL_ARCHIVE_BYTES,
            "sha256": T1_HISTORICAL_ARCHIVE_SHA256,
        },
    }


def _verify_t1_manifest(verifier: Any, reader_module: Any,
                        manifest_path: Path, expected_sha256: str) -> dict[str, Any]:
    if reader_module is None:
        raise RuntimeError("pinned T1 historical reader module was not loaded")
    return verifier.verify_manifest(
        manifest_path, expected_sha256,
        historical_reader_module=reader_module,
        historical_index_path=ROOT.joinpath(
            *T1_HISTORICAL_INDEX_RELATIVE.split("/")),
        historical_index_sha256=T1_HISTORICAL_INDEX_SHA256,
        historical_archive_path=T1_HISTORICAL_ARCHIVE_PATH)


def _read_r3_runtime_parse_paths() -> list[str]:
    expected_bytes, expected_sha256 = R3_HISTORICAL_RECEIPTS[
        "runtime_parse_manifest.tsv"]
    raw = R3_RUNTIME_PARSE_MANIFEST_PATH.read_bytes()
    if len(raw) != expected_bytes or sha256_bytes(raw) != expected_sha256:
        raise RuntimeError("frozen original R3 runtime parse manifest bytes changed")
    if not raw.endswith(b"\n") or b"\r" in raw:
        raise RuntimeError("frozen original R3 runtime parse manifest line endings changed")
    try:
        lines = raw.decode("ascii", errors="strict").splitlines()
    except UnicodeDecodeError as exc:
        raise RuntimeError("frozen original R3 runtime parse manifest is not ASCII") from exc
    if len(lines) != ORIGINAL_JULIA_PARSE_PATH_COUNT:
        raise RuntimeError(
            "frozen original R3 runtime parse manifest row count changed")
    paths: list[str] = []
    for ordinal, line in enumerate(lines, start=1):
        fields = line.split("\t")
        if len(fields) != 2:
            raise RuntimeError(
                f"frozen original R3 parse row {ordinal} is malformed")
        source_sha256, relative = fields
        parts = relative.split("/")
        if not HEX64.fullmatch(source_sha256) or \
                not relative or "\\" in relative or relative.startswith("/") or \
                any(part in {"", ".", ".."} for part in parts) or \
                ":" in parts[0] or not relative.endswith(".jl"):
            raise RuntimeError(
                f"frozen original R3 parse row {ordinal} is noncanonical")
        paths.append(relative)
    if len(set(paths)) != ORIGINAL_JULIA_PARSE_PATH_COUNT:
        raise RuntimeError("frozen original R3 runtime parse paths are duplicated")
    return paths


def _assert_r3_runtime_parse_inventory(runtime_paths: list[Path]) -> None:
    historical_paths = _read_r3_runtime_parse_paths()
    try:
        current_paths = [path.relative_to(ROOT).as_posix()
                         for path in runtime_paths]
    except ValueError as exc:
        raise RuntimeError("original runtime parse path escapes the repository") from exc
    if current_paths != historical_paths:
        raise RuntimeError(
            "current original Julia parse paths differ from the exact frozen R3 rows")


def _verify_r3_history() -> tuple[dict[str, Any], dict[str, dict[str, Any]]]:
    paths = {
        "runtime_inputs.json": R3_RUNTIME_INPUTS_PATH,
        "protocol.json": R3_PROTOCOL_PATH,
        "dispatch.json": R3_DISPATCH_PATH,
        "snapshot.json": R3_SNAPSHOT_PATH,
        "command.txt": R3_COMMAND_PATH,
        "runtime_parse_manifest.tsv": R3_RUNTIME_PARSE_MANIFEST_PATH,
    }
    receipts: dict[str, dict[str, Any]] = {}
    for name, path in paths.items():
        size, digest = R3_HISTORICAL_RECEIPTS[name]
        data = path.read_bytes()
        if len(data) != size or sha256_bytes(data) != digest:
            raise RuntimeError(f"frozen original R3 {name} bytes changed")
        receipts[name] = {"path": path.relative_to(ROOT).as_posix(),
                          "bytes": size, "sha256": digest}
    old_runtime = json.loads(R3_RUNTIME_INPUTS_PATH.read_bytes().decode("utf-8"))
    old_protocol = json.loads(R3_PROTOCOL_PATH.read_bytes().decode("utf-8"))
    old_dispatch = json.loads(R3_DISPATCH_PATH.read_bytes().decode("utf-8"))
    old_snapshot = json.loads(R3_SNAPSHOT_PATH.read_bytes().decode("utf-8"))
    expected_runtime_receipt = receipts["runtime_inputs.json"]
    if old_runtime.get("schema") != "vnext-t2-formal-runtime-inputs-r3" or \
            old_runtime.get("runtime_dependency_count") != 104 or \
            type(old_runtime.get("inputs")) is not dict or \
            len(old_runtime["inputs"]) != 104 or \
            old_protocol.get("schema") != "vnext-t2-formal-execution-protocol-r3" or \
            old_protocol.get("runtime_inputs") != expected_runtime_receipt or \
            old_dispatch.get("schema") != "vnext-t2-formal-execution-dispatch-r3" or \
            old_dispatch.get("protocol") != receipts["protocol.json"] or \
            old_dispatch.get("command_receipt") != receipts["command.txt"] or \
            old_snapshot.get("schema") != "vnext-t2-formal-dispatch-snapshot-r3" or \
            old_snapshot.get("protocol") != receipts["protocol.json"] or \
            old_snapshot.get("dispatch") != receipts["dispatch.json"] or \
            old_snapshot.get("runtime_inputs") != expected_runtime_receipt:
        raise RuntimeError("original positive R3 metadata lineage is inconsistent")
    for relative, row in old_runtime["inputs"].items():
        if type(relative) is not str or type(row) is not dict or \
                set(row) != {"path", "bytes", "sha256"} or \
                row.get("path") != relative or type(row.get("bytes")) is not int or \
                row["bytes"] < 0 or type(row.get("sha256")) is not str or \
                not HEX64.fullmatch(row["sha256"]):
            raise RuntimeError(f"original R3 runtime input row malformed: {relative!r}")
    return old_runtime, receipts


def _assert_historical_r3_head(expected_head: str) -> None:
    raw = R3_PROTOCOL_PATH.read_bytes()
    if len(raw) != R3_HISTORICAL_RECEIPTS["protocol.json"][0] or \
            sha256_bytes(raw) != R3_HISTORICAL_RECEIPTS["protocol.json"][1]:
        raise RuntimeError("frozen original R3 protocol bytes changed")
    historical = json.loads(raw.decode("utf-8"))
    if historical.get("repository_head") != expected_head:
        raise RuntimeError("current expected HEAD differs from historical R3 protocol")


def _build_migration_record(old_runtime: dict[str, Any],
                            current_pins: dict[str, dict[str, Any]],
                            old_receipts: dict[str, dict[str, Any]]) -> dict[str, Any]:
    old_pins = old_runtime["inputs"]
    if set(old_pins) != set(current_pins):
        raise RuntimeError("original R3 and current runtime input path sets differ")
    changed = sorted(relative for relative in old_pins
                     if old_pins[relative] != current_pins[relative])
    if set(changed) != EXPECTED_MIGRATION_CHANGED_PATHS or \
            len(changed) != 7 or len(old_pins) - len(changed) != 97:
        raise RuntimeError(
            "positive R3-to-current migration is not exactly the five existing "
            "input drifts, T1 verifier source, and this controller source")
    return {
        "schema": "vnext-t2-positive-r3-to-current-input-migration-r1",
        "historical_schema": old_runtime["schema"],
        "historical_input_count": 104,
        "current_input_count": 104,
        "historical_unchanged_count": 97,
        "changed_count": 7,
        "changed_paths": changed,
        "historical_runtime_inputs": old_receipts["runtime_inputs.json"],
        "historical_protocol": old_receipts["protocol.json"],
        "historical_runtime_parse_manifest":
            old_receipts["runtime_parse_manifest.tsv"],
        "original_runtime_julia_parse_path_count":
            ORIGINAL_JULIA_PARSE_PATH_COUNT,
        "managed_runtime_julia_parse_path_count":
            MANAGED_JULIA_PARSE_PATH_COUNT,
        "combined_runtime_julia_parse_path_count":
            COMBINED_JULIA_PARSE_PATH_COUNT,
        "actual_head_verified": False,
        "status": "source_migration_prepared_pending_managed_execution",
        "formal_t2_accepted": False,
        "scientific_acceptance": False,
        "physical_acceptance": False,
    }


def _verify_positive_protocol(protocol_path: Path, expected_sha256: str,
                              args: argparse.Namespace,
                              current_receipts: dict[str, dict[str, Any]],
                              managed_receipts: dict[str, dict[str, Any]],
                              historical_t1_data: dict[str, Any]) -> dict[str, Any]:
    raw = protocol_path.read_bytes()
    digest = sha256_bytes(raw)
    if type(expected_sha256) is not str or not HEX64.fullmatch(expected_sha256) or \
            digest != expected_sha256:
        raise RuntimeError("positive managed protocol raw SHA-256 mismatch")
    protocol = json.loads(raw.decode("utf-8"))
    if type(protocol) is not dict or \
            protocol.get("schema") != POSITIVE_PROTOCOL_SCHEMA or \
            protocol.get("protocol_sha256_mode") != "external_raw_bytes_argument" or \
            protocol.get("actual_head_verified") is not False or \
            protocol.get("formal_t2_accepted") is not False or \
            protocol.get("scientific_acceptance") is not False or \
            protocol.get("physical_acceptance") is not False:
        raise RuntimeError("positive managed protocol schema/credit boundary mismatch")
    if protocol_path.name != "protocol.json" or \
            protocol_path.parent.parent != EVIDENCE_ROOT or \
            protocol_path.parent.resolve() == Path(args.evidence_dir).resolve() or \
            protocol.get("protocol_path") != protocol_path.relative_to(ROOT).as_posix():
        raise RuntimeError("positive managed protocol path is not a fresh direct run leaf")
    runtime_pins = runtime_input_pins(current_receipts)
    managed = {relative: relative_source_receipt(relative)
               for relative in MANAGED_EXECUTION_SOURCE_PATHS}
    if managed != managed_receipts:
        raise RuntimeError("managed execution source changed during positive preflight")
    protocol_inputs = protocol.get("inputs")
    input_groups = protocol.get("input_groups")
    lifecycle_pins = protocol.get("managed_process_lifecycle_source_pins")
    if type(input_groups) is not dict or set(input_groups) != {
            "original_runtime_inputs", "managed_execution_dependencies",
            "t1_historical_data"} or \
            input_groups["original_runtime_inputs"] != runtime_pins or \
            input_groups["managed_execution_dependencies"] != managed or \
            input_groups["t1_historical_data"] != historical_t1_data or \
            T1_HISTORICAL_INDEX_RELATIVE in runtime_pins or \
            T1_HISTORICAL_INDEX_RELATIVE in managed or \
            set(runtime_pins).intersection(managed) or \
            type(protocol_inputs) is not dict or \
            protocol_inputs != {**runtime_pins, **managed} or \
            type(lifecycle_pins) is not dict or \
            set(lifecycle_pins) != set(MANAGED_LIFECYCLE_SOURCE_PATHS) or \
            lifecycle_pins != {relative: protocol_inputs[relative]
                               for relative in MANAGED_LIFECYCLE_SOURCE_PATHS}:
        raise RuntimeError("positive protocol input closure or managed source pins differ")
    if protocol.get("runtime_dependency_count") != 104 or \
            protocol.get("runtime_inputs_schema") != "vnext-t2-formal-runtime-inputs-r3" or \
            protocol.get("managed_execution_dependency_count") != len(managed) or \
            protocol.get("phase_order") != list(POSITIVE_PHASE_ORDER) or \
            protocol.get("phase_command_templates") != _phase_command_templates(args) or \
            protocol.get("resource_gates") != {
                "phase_wall_seconds": POSITIVE_PHASE_TIMEOUT_SECONDS,
                "process_tree_rss_bytes": POSITIVE_RSS_LIMIT_BYTES,
                "sample_interval_seconds": POSITIVE_SAMPLE_INTERVAL_SECONDS,
                "max_sample_attempts": POSITIVE_MAX_SAMPLE_ATTEMPTS,
                "julia_threads": POSITIVE_JULIA_THREADS,
            }:
        raise RuntimeError("positive protocol runtime/phase contract differs")
    if type(protocol.get("expected_repository_head")) is not str or \
            not re.fullmatch(r"[0-9a-f]{40}",
                             protocol["expected_repository_head"]) or \
            protocol.get("planned_evidence_dir") != \
                Path(args.evidence_dir).resolve().relative_to(ROOT).as_posix():
        raise RuntimeError("positive protocol head/output binding differs")
    runtime_receipt = protocol.get("runtime_inputs")
    runtime_path = protocol_path.parent / "runtime_inputs.json"
    runtime_raw = runtime_path.read_bytes()
    if type(runtime_receipt) is not dict or \
            set(runtime_receipt) != {"path", "bytes", "sha256"} or \
            runtime_receipt.get("path") != runtime_path.relative_to(ROOT).as_posix() or \
            type(runtime_receipt.get("bytes")) is not int or \
            runtime_receipt["bytes"] != len(runtime_raw) or \
            runtime_receipt.get("sha256") != sha256_bytes(runtime_raw):
        raise RuntimeError("positive runtime_inputs raw receipt mismatch")
    runtime_inputs = json.loads(runtime_raw.decode("utf-8"))
    if type(runtime_inputs) is not dict or \
            runtime_inputs.get("schema") != "vnext-t2-formal-runtime-inputs-r3" or \
            runtime_inputs.get("runtime_dependency_count") != 104 or \
            runtime_inputs.get("inputs") != runtime_pins:
        raise RuntimeError("positive runtime_inputs.json current 104 rows differ")
    sidecar_rows = protocol.get("metadata_sidecars")
    expected_sidecar_names = {"dispatch.json", "snapshot.json", "command.txt"}
    if type(sidecar_rows) is not dict or set(sidecar_rows) != expected_sidecar_names:
        raise RuntimeError("positive protocol sidecar receipt set differs")
    sidecar_values: dict[str, bytes] = {}
    for name in sorted(expected_sidecar_names):
        sidecar_path = protocol_path.parent / name
        raw_sidecar = sidecar_path.read_bytes()
        row = sidecar_rows[name]
        if type(row) is not dict or set(row) != {"path", "bytes", "sha256"} or \
                row.get("path") != sidecar_path.relative_to(ROOT).as_posix() or \
                type(row.get("bytes")) is not int or \
                row["bytes"] != len(raw_sidecar) or \
                row.get("sha256") != sha256_bytes(raw_sidecar):
            raise RuntimeError(f"positive protocol sidecar receipt mismatch: {name}")
        sidecar_values[name] = raw_sidecar
    expected_argv = protocol.get("run_command_argv_template")
    if not isinstance(expected_argv, list) or not expected_argv or \
            expected_argv.count("{protocol_sha256}") != 1:
        raise RuntimeError("positive protocol run argv template is malformed")
    expected_dispatch = {
        "schema": "vnext-t2-positive-managed-dispatch-r1",
        "protocol_path": protocol_path.relative_to(ROOT).as_posix(),
        "planned_evidence_dir": protocol["planned_evidence_dir"],
        "expected_repository_head": protocol["expected_repository_head"],
        "run_command_argv_template": expected_argv,
        "actual_head_verified": False,
        "formal_t2_accepted": False,
    }
    expected_snapshot = {
        "schema": "vnext-t2-positive-managed-snapshot-r2",
        "protocol_path": protocol_path.relative_to(ROOT).as_posix(),
        "runtime_inputs": runtime_receipt,
        "original_runtime_inputs": runtime_pins,
        "managed_execution_dependencies": managed,
        "t1_historical_data": historical_t1_data,
        "historical_r3_migration": protocol["historical_r3_migration"],
        "actual_head_verified": False,
        "formal_t2_accepted": False,
    }
    dispatch = json.loads(sidecar_values["dispatch.json"].decode("utf-8"))
    snapshot = json.loads(sidecar_values["snapshot.json"].decode("utf-8"))
    if dispatch != expected_dispatch or snapshot != expected_snapshot:
        raise RuntimeError("positive protocol dispatch/snapshot content differs")
    command_raw = sidecar_values["command.txt"]
    expected_command_raw = (json.dumps(expected_argv, separators=(",", ":")) + "\n").encode()
    if command_raw != expected_command_raw:
        raise RuntimeError("positive protocol command sidecar differs")
    old_runtime, old_receipts = _verify_r3_history()
    expected_migration = _build_migration_record(old_runtime, runtime_pins,
                                                 old_receipts)
    if protocol.get("historical_r3_migration") != expected_migration:
        raise RuntimeError("positive protocol historical R3 migration record drift")
    manifest_row = protocol.get("root_issued_inputs", {}).get("software_manifest")
    qualification_row = protocol.get("root_issued_inputs", {}).get(
        "source_witness_qualification")
    if manifest_row != {"path": T1_SOFTWARE_MANIFEST.relative_to(ROOT).as_posix(),
                        "sha256": T1_SOFTWARE_MANIFEST_SHA256} or \
            qualification_row != {
                "path": V3_QUALIFICATION.relative_to(ROOT).as_posix(),
                "sha256": V3_QUALIFICATION_SHA256}:
        raise RuntimeError("positive protocol root-issued T1/V3 bindings differ")
    actual_argv = [sys.executable, *sys.argv]
    expanded_argv = [expected_sha256 if item == "{protocol_sha256}" else item
                     for item in expected_argv]
    if actual_argv != expanded_argv:
        raise RuntimeError("positive run argv differs from the frozen protocol")
    return protocol


def _load_managed_runtime(protocol: dict[str, Any],
                          protocol_sha256: str,
                          runtime_pins: dict[str, dict[str, Any]],
                          managed_pins: dict[str, dict[str, Any]]) -> None:
    global _T1_VERIFIER, _HISTORICAL_READER_MODULE, _R23_RUNTIME
    global _R23_PROTOCOL_SHA256, _POSITIVE_PROTOCOL
    if _T1_VERIFIER is not None or _R23_RUNTIME is not None:
        raise RuntimeError("positive managed runtime was already loaded")
    _T1_VERIFIER = _load_exact_source_module(
        "formal_t1_software_manifest_v1", T1_VERIFIER_RELATIVE,
        runtime_pins[T1_VERIFIER_RELATIVE])
    _ensure_managed_namespace_packages()
    _HISTORICAL_READER_MODULE = _load_exact_source_module(
        "tools.workspace_sources", WORKSPACE_SOURCES_RELATIVE,
        managed_pins[WORKSPACE_SOURCES_RELATIVE])
    _load_exact_source_module("tools.execution.t2_source_inputs",
                              T2_SOURCE_INPUTS_RELATIVE,
                              managed_pins[T2_SOURCE_INPUTS_RELATIVE])
    _R23_RUNTIME = _load_exact_source_module(
        "vnext_t2_positive_managed_r23", R23_CONTROLLER_RELATIVE,
        managed_pins[R23_CONTROLLER_RELATIVE])
    if runtime_input_pins(runtime_receipts()) != runtime_pins or \
            managed_source_receipts() != managed_pins:
        raise RuntimeError("source closure drifted while loading exact-byte modules")
    expected = _R23_RUNTIME.EXPECTED_HEAD
    if protocol.get("expected_repository_head") != expected or \
            protocol.get("expected_repository_head") != \
                _T1_VERIFIER.EXPECTED_HEAD:
        raise RuntimeError("positive protocol expected HEAD differs from pinned T1 sources")
    _assert_historical_r3_head(expected)
    _R23_RUNTIME.configure_managed_lifecycle(protocol, protocol_sha256)
    _R23_PROTOCOL_SHA256 = protocol_sha256
    _POSITIVE_PROTOCOL = protocol


def _current_input_snapshots() -> tuple[dict[str, dict[str, Any]],
                                        dict[str, dict[str, Any]]]:
    original = runtime_receipts()
    if len(original) != 104:
        raise RuntimeError(f"original positive input set drifted: {len(original)}")
    managed = managed_source_receipts()
    if set(original).intersection(managed):
        raise RuntimeError("managed source closure overlaps original runtime inputs")
    return original, managed


def _phase_command_templates(args: argparse.Namespace) -> dict[str, list[str]]:
    julia_common = [str(Path(args.julia).resolve()), "--project=" + str(ROOT),
        "--startup-file=no", "--history-file=no", "--threads=1"]
    producer = julia_common + [str(DRIVER), "produce", str(T1_SOFTWARE_MANIFEST),
        T1_SOFTWARE_MANIFEST_SHA256, "{manifest_verification_path}",
        "{manifest_verification_sha256}", "{producer_dir}"]
    replay = julia_common + [str(DRIVER), "replay", str(T1_SOFTWARE_MANIFEST),
        T1_SOFTWARE_MANIFEST_SHA256, "{manifest_verification_path}",
        "{manifest_verification_sha256}", "{replay_dir}",
        "{candidate_receipt_sha256}", "{stable_projection_sha256}",
        "{producer_package_path}", "{producer_package_sha256}",
        "{result_reload_identity_sha256}"]
    return {
        "parse_gate": julia_common + [str(PARSE_GATE), "{runtime_parse_manifest}"],
        "clean_load": julia_common + [str(CLEAN_LOAD_DRIVER),
                                      "{clean_load_receipt_path}"],
        "producer": producer,
        "replay": replay,
    }


def _freeze_positive(args: argparse.Namespace) -> int:
    if args.freeze_dir is None or args.protocol is not None or \
            args.protocol_sha256 is not None:
        raise ValueError("freeze-only requires --freeze-dir and forbids run protocol arguments")
    freeze_dir = Path(args.freeze_dir).resolve()
    output = Path(args.evidence_dir).resolve()
    if freeze_dir.parent != EVIDENCE_ROOT or output.parent != EVIDENCE_ROOT or \
            freeze_dir == output or freeze_dir in output.parents or \
            output in freeze_dir.parents or freeze_dir.exists() or output.exists():
        raise ValueError("freeze and planned output must be fresh direct evidence leaves")
    if args.phase_timeout != POSITIVE_PHASE_TIMEOUT_SECONDS or \
            args.working_set_limit != POSITIVE_RSS_LIMIT_BYTES:
        raise ValueError("positive freeze requires the original exact phase budget")
    julia_paths = runtime_julia_paths()
    _assert_r3_runtime_parse_inventory(julia_paths)
    runtime_receipt_map, managed = _current_input_snapshots()
    runtime_pins = runtime_input_pins(runtime_receipt_map)
    _ensure_managed_namespace_packages()
    historical_reader_module = _load_exact_source_module(
        "tools.workspace_sources", WORKSPACE_SOURCES_RELATIVE,
        managed[WORKSPACE_SOURCES_RELATIVE])
    historical_t1_data = _t1_historical_data_group(historical_reader_module)
    t1_verifier = _load_exact_source_module(
        "formal_t1_software_manifest_v1", T1_VERIFIER_RELATIVE,
        runtime_pins[T1_VERIFIER_RELATIVE])
    expected_head = t1_verifier.EXPECTED_HEAD
    if type(expected_head) is not str or not re.fullmatch(r"[0-9a-f]{40}", expected_head):
        raise RuntimeError("frozen T1 verifier expected HEAD is malformed")
    old_runtime, old_receipts = _verify_r3_history()
    _assert_historical_r3_head(expected_head)
    migration = _build_migration_record(old_runtime, runtime_pins, old_receipts)
    manifest_hash = args.manifest_sha256.lower()
    v3_hash = args.v3_qualification_sha256.lower()
    if manifest_hash != T1_SOFTWARE_MANIFEST_SHA256 or \
            v3_hash != V3_QUALIFICATION_SHA256:
        raise RuntimeError("positive freeze root-issued input pin mismatch")
    _verify_t1_manifest(t1_verifier, historical_reader_module,
                        T1_SOFTWARE_MANIFEST, manifest_hash)
    historical_t1_data_after = \
        _t1_historical_data_group(historical_reader_module)
    if historical_t1_data_after != historical_t1_data:
        raise RuntimeError("T1 historical data changed during positive freeze")
    verify_v3_qualification(V3_QUALIFICATION, v3_hash)
    protocol_path = freeze_dir / "protocol.json"
    runtime_path = freeze_dir / "runtime_inputs.json"
    runtime_document = {
        "schema": "vnext-t2-formal-runtime-inputs-r3",
        "runtime_dependency_count": 104,
        "inputs": runtime_pins,
    }
    runtime_bytes = (json.dumps(runtime_document, indent=2, sort_keys=True) + "\n").encode()
    run_argv = [sys.executable, str(Path(__file__).resolve()),
        "--julia", str(Path(args.julia).resolve()),
        "--project", str(ROOT),
        "--manifest", str(T1_SOFTWARE_MANIFEST),
        "--manifest-sha256", manifest_hash,
        "--v3-qualification", str(V3_QUALIFICATION),
        "--v3-qualification-sha256", v3_hash,
        "--evidence-dir", str(output),
        "--phase-timeout", "300",
        "--working-set-limit", str(POSITIVE_RSS_LIMIT_BYTES),
        "--protocol", str(protocol_path),
        "--protocol-sha256", "{protocol_sha256}"]
    sidecar_base = {
        "protocol_path": protocol_path.relative_to(ROOT).as_posix(),
        "planned_evidence_dir": output.relative_to(ROOT).as_posix(),
        "expected_repository_head": expected_head,
        "run_command_argv_template": run_argv,
        "actual_head_verified": False,
        "formal_t2_accepted": False,
    }
    dispatch = {"schema": "vnext-t2-positive-managed-dispatch-r1",
                **sidecar_base}
    runtime_receipt = {"path": runtime_path.relative_to(ROOT).as_posix(),
                       "bytes": len(runtime_bytes),
                       "sha256": sha256_bytes(runtime_bytes)}
    snapshot = {
        "schema": "vnext-t2-positive-managed-snapshot-r2",
        "protocol_path": protocol_path.relative_to(ROOT).as_posix(),
        "runtime_inputs": runtime_receipt,
        "original_runtime_inputs": runtime_pins,
        "managed_execution_dependencies": managed,
        "t1_historical_data": historical_t1_data,
        "historical_r3_migration": migration,
        "actual_head_verified": False,
        "formal_t2_accepted": False,
    }
    sidecar_bytes = {
        "dispatch.json": (json.dumps(dispatch, indent=2, sort_keys=True) + "\n").encode(),
        "snapshot.json": (json.dumps(snapshot, indent=2, sort_keys=True) + "\n").encode(),
        "command.txt": (json.dumps(run_argv, separators=(",", ":")) + "\n").encode(),
    }
    metadata_sidecars = {
        name: {"path": (freeze_dir / name).relative_to(ROOT).as_posix(),
               "bytes": len(data), "sha256": sha256_bytes(data)}
        for name, data in sidecar_bytes.items()}
    protocol = {
        "schema": POSITIVE_PROTOCOL_SCHEMA,
        "protocol_path": protocol_path.relative_to(ROOT).as_posix(),
        "protocol_sha256_mode": "external_raw_bytes_argument",
        "runtime_inputs_schema": "vnext-t2-formal-runtime-inputs-r3",
        "runtime_dependency_count": 104,
        "managed_execution_dependency_count": len(managed),
        "runtime_inputs": runtime_receipt,
        "metadata_sidecars": metadata_sidecars,
        "input_groups": {
            "original_runtime_inputs": runtime_pins,
            "managed_execution_dependencies": managed,
            "t1_historical_data": historical_t1_data,
        },
        "inputs": {**runtime_pins, **managed},
        "managed_process_lifecycle_source_pins": {
            path: managed[path] for path in MANAGED_LIFECYCLE_SOURCE_PATHS},
        "expected_repository_head": expected_head,
        "planned_evidence_dir": output.relative_to(ROOT).as_posix(),
        "phase_order": list(POSITIVE_PHASE_ORDER),
        "phase_command_templates": _phase_command_templates(args),
        "resource_gates": {
            "phase_wall_seconds": POSITIVE_PHASE_TIMEOUT_SECONDS,
            "process_tree_rss_bytes": POSITIVE_RSS_LIMIT_BYTES,
            "sample_interval_seconds": POSITIVE_SAMPLE_INTERVAL_SECONDS,
            "max_sample_attempts": POSITIVE_MAX_SAMPLE_ATTEMPTS,
            "julia_threads": POSITIVE_JULIA_THREADS,
        },
        "run_command_argv_template": run_argv,
        "historical_r3_migration": migration,
        "root_issued_inputs": {
            "software_manifest": {
                "path": T1_SOFTWARE_MANIFEST.relative_to(ROOT).as_posix(),
                "sha256": T1_SOFTWARE_MANIFEST_SHA256},
            "source_witness_qualification": {
                "path": V3_QUALIFICATION.relative_to(ROOT).as_posix(),
                "sha256": V3_QUALIFICATION_SHA256},
        },
        "actual_head_verified": False,
        "formal_t2_accepted": False,
        "physical_acceptance": False,
        "scientific_acceptance": False,
        "actual_model_attestation": "unavailable",
    }
    protocol_bytes = (json.dumps(protocol, indent=2, sort_keys=True) + "\n").encode()
    freeze_dir.mkdir(parents=False, exist_ok=False)
    try:
        for path, data in ((runtime_path, runtime_bytes),
                           *((freeze_dir / name, data)
                             for name, data in sidecar_bytes.items()),
                           (protocol_path, protocol_bytes)):
            with path.open("xb") as stream:
                stream.write(data)
                stream.flush()
                os.fsync(stream.fileno())
    except BaseException:
        raise
    print(json.dumps({"status": "prepared", "protocol": file_receipt(protocol_path),
        "runtime_inputs": file_receipt(runtime_path),
        "metadata_sidecars": {name: file_receipt(freeze_dir / name)
                              for name in sidecar_bytes},
        "expected_repository_head": expected_head,
        "actual_head_verified": False,
        "formal_t2_accepted": False}, sort_keys=True), flush=True)
    return 0


def changed_inputs(before: dict[str, Any], after: dict[str, Any]) -> list[str]:
    return sorted(
        set(before) ^ set(after) |
        {path for path in set(before) & set(after)
         if before[path] != after[path]})


def write_parse_manifest(path: Path, runtime_paths: list[Path],
                         snapshot: dict[str, dict[str, Any]]) -> dict[str, Any]:
    lines: list[str] = []
    for runtime_path in runtime_paths:
        relative = runtime_path.relative_to(ROOT).as_posix()
        receipt = snapshot.get(relative)
        if receipt is None:
            raise RuntimeError(f"parse input is absent from snapshot: {relative}")
        lines.append(f"{receipt['sha256']}\t{relative}\n")
    data = "".join(lines).encode("utf-8")
    with path.open("xb") as stream:
        stream.write(data)
        stream.flush()
        os.fsync(stream.fileno())
    return file_receipt(path)


def git_head(output: Path, *, timeout_seconds: float,
             receipts: dict[str, Any], receipt_key: str) -> dict[str, Any]:
    if _R23_RUNTIME is None or _R23_PROTOCOL_SHA256 is None:
        raise RuntimeError("managed Git HEAD query requires a verified protocol")
    output = output.resolve()
    output.relative_to(EVIDENCE_ROOT)
    if output == EVIDENCE_ROOT:
        raise RuntimeError("managed Git HEAD query requires a dedicated output leaf")
    if type(receipts) is not dict or type(receipt_key) is not str or \
            not receipt_key or receipt_key in receipts:
        raise RuntimeError("managed Git HEAD receipt map/key is invalid or reused")
    result = _R23_RUNTIME.git_head(
        output=output, timeout_seconds=timeout_seconds,
        receipts=receipts, receipt_key=receipt_key)
    if receipt_key not in receipts:
        raise RuntimeError("managed Git HEAD helper did not publish its receipt")
    phase_path = output / "phase.json"
    stdout_path = output / "stdout.raw"
    if not phase_path.is_file() or not stdout_path.is_file():
        raise RuntimeError("managed Git HEAD query lacks its R23 phase receipt")
    phase = json.loads(phase_path.read_bytes().decode("utf-8"))
    _R23_RUNTIME.require_natural(phase, exit_zero=True)
    if phase.get("name") != "repository_head" or \
            phase.get("schema") != "vnext-t2-independent-negative-phase-r6-native-r23":
        raise RuntimeError("managed Git HEAD query returned the wrong R23 phase")
    head = stdout_path.read_bytes().decode("ascii", errors="strict").strip()
    if type(result) is not str or result != head or \
            not re.fullmatch(r"[0-9a-f]{40}", head):
        raise RuntimeError("managed Git HEAD result differs from raw stdout")
    head_digest = sha256_bytes(head.encode("ascii"))
    receipt = receipts[receipt_key]
    required_receipt_keys = {
        "schema", "output_leaf", "command", "phase", "stdout", "stderr",
        "exit_code", "stop_reason", "process_tree_sample_count",
        "process_tree_samples_complete", "head_value_sha256"}
    if type(receipt) is not dict or set(receipt) != required_receipt_keys or \
            receipt.get("schema") != "vnext-t2-managed-repository-head-query-r1" or \
            receipt.get("output_leaf") != output.relative_to(ROOT).as_posix() or \
            receipt.get("command") != ["git", "rev-parse", "HEAD"] or \
            receipt.get("phase") != file_receipt(phase_path) or \
            receipt.get("stdout") != file_receipt(stdout_path) or \
            receipt.get("stderr") != file_receipt(output / "stderr.raw") or \
            type(receipt.get("exit_code")) is not int or \
            receipt["exit_code"] != 0 or \
            type(receipt.get("head_value_sha256")) is not str or \
            receipt["head_value_sha256"] != head_digest or \
            receipt.get("stop_reason") != "natural_exit" or \
            type(receipt.get("process_tree_sample_count")) is not int or \
            receipt["process_tree_sample_count"] <= 0 or \
            receipt.get("process_tree_samples_complete") is not True:
        raise RuntimeError("managed Git HEAD query receipt is incomplete or inconsistent")
    return {"receipt_key": receipt_key, "head": head,
            "query_receipt": receipt, "phase": phase,
            "phase_receipt": file_receipt(phase_path),
            "stdout": file_receipt(stdout_path),
            "stderr": file_receipt(output / "stderr.raw")}


def heavy_processes() -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for process in psutil.process_iter(["name", "cmdline", "create_time"]):
        try:
            name = (process.info.get("name") or "").lower()
            if name in HEAVY_NAMES:
                rows.append({"pid": process.pid, "name": process.info["name"],
                    "cmdline": process.info.get("cmdline"),
                    "create_time": process.info.get("create_time")})
        except psutil.Error:
            continue
    return rows


def write_json_new(path: Path, value: Any) -> None:
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, indent=2, sort_keys=True)
        stream.write("\n")


def run_phase(name: str, command: list[str], output: Path, *,
              timeout_seconds: float, working_set_limit_bytes: int,
              environment: dict[str, str]) -> dict[str, Any]:
    if _R23_RUNTIME is None or _R23_PROTOCOL_SHA256 is None:
        raise RuntimeError("business phases require a verified managed protocol")
    return _R23_RUNTIME.run_phase(
        name, command, output.resolve(), timeout_seconds=timeout_seconds,
        working_set_limit_bytes=working_set_limit_bytes,
        environment=environment)


def require_phase_pass(phase: dict[str, Any]) -> None:
    if _R23_RUNTIME is None:
        raise RuntimeError("phase verification requires the R23 controller")
    _R23_RUNTIME.require_natural(phase, exit_zero=True)
    if phase["exit_code"] != 0 or phase["stop_reason"] != "natural_exit":
        raise RuntimeError(
            f"{phase['name']} failed: exit={phase['exit_code']} "
            f"reason={phase['stop_reason']}")
    if phase["residual_heavy_processes"]:
        raise RuntimeError(
            f"{phase['name']} left heavy processes: "
            f"{phase['residual_heavy_processes']}")


def load_run_receipt(output: Path, mode: str) -> dict[str, Any]:
    if (output / "replay_uncommitted_attempt.json").exists():
        raise RuntimeError(
            f"{mode} published both final and uncommitted replay evidence")
    path = output / "run_receipt.json"
    value = json.loads(path.read_text(encoding="utf-8"))
    if value.get("schema") != "vnext-t2-formal-candidate-execution-receipt-r1":
        raise RuntimeError(f"{mode} run receipt schema mismatch")
    if value.get("driver_version") != "formal-candidate-driver-r5":
        raise RuntimeError(f"{mode} driver version mismatch")
    if value.get("mode") != mode:
        raise RuntimeError(f"{mode} run receipt mode mismatch")
    if value.get("evidence_kind") != "formal_t1_actual" or \
            value.get("formal_gate_verified") is not True:
        raise RuntimeError(f"{mode} did not use a verified actual formal T1 gate")
    if value.get("formal_t2_accepted") is not False:
        raise RuntimeError(f"{mode} overclaimed formal T2 acceptance")
    if value.get("julia_threads") != 1:
        raise RuntimeError(f"{mode} Julia thread count is not one")
    expected_origin = "local_producer" if mode == "produce" else "producer_artifact"
    if value.get("package_artifact_origin") != expected_origin or \
            value.get("independent_expected_admission_rebuilt") is not True:
        raise RuntimeError(f"{mode} package artifact origin/rebuild mismatch")
    expected_artifacts = ["candidate_package.jls",
        "candidate_t1_admission_receipt.json", "t2_result.jls",
        "run_receipt.json"]
    if value.get("publication_committed") is not True or \
            value.get("published_artifacts") != expected_artifacts:
        raise RuntimeError(f"{mode} final artifact publication mismatch")
    caller_before = value.get("caller_package_sha256_before")
    caller_after = value.get("caller_package_sha256_after")
    if not isinstance(caller_before, str) or not HEX64.fullmatch(caller_before) or \
            caller_after != caller_before:
        raise RuntimeError(f"{mode} caller package changed during execution")
    return value


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--julia", required=True)
    parser.add_argument("--project", required=True)
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--manifest-sha256", required=True)
    parser.add_argument("--v3-qualification", required=True)
    parser.add_argument("--v3-qualification-sha256", required=True)
    parser.add_argument("--evidence-dir", required=True)
    parser.add_argument("--phase-timeout", type=float, required=True)
    parser.add_argument("--working-set-limit", type=int,
                        default=2_147_483_648)
    parser.add_argument("--freeze-only", action="store_true")
    parser.add_argument("--freeze-dir")
    parser.add_argument("--protocol")
    parser.add_argument("--protocol-sha256")
    args = parser.parse_args()

    project = Path(args.project).resolve()
    if project != ROOT:
        raise ValueError(f"project must resolve to repository root: {ROOT}")
    julia_path = Path(args.julia).resolve()
    if not julia_path.is_file():
        raise FileNotFoundError(f"Julia executable is absent: {julia_path}")
    args.julia = str(julia_path)
    manifest = Path(args.manifest).resolve()
    manifest.relative_to(ROOT)
    if manifest != T1_SOFTWARE_MANIFEST:
        raise ValueError("formal T1 software manifest path mismatch")
    v3_qualification = Path(args.v3_qualification).resolve()
    v3_qualification.relative_to(ROOT)
    if v3_qualification != V3_QUALIFICATION:
        raise ValueError("source-witness qualification path mismatch")
    output = Path(args.evidence_dir).resolve()
    if output.parent != EVIDENCE_ROOT or output == EVIDENCE_ROOT:
        raise ValueError("formal run requires one fresh direct evidence leaf")
    if args.phase_timeout != POSITIVE_PHASE_TIMEOUT_SECONDS or \
            args.working_set_limit != POSITIVE_RSS_LIMIT_BYTES:
        raise ValueError("formal phases require exactly 300 seconds and 2 GiB")
    if args.freeze_only:
        return _freeze_positive(args)
    if args.freeze_dir is not None or args.protocol is None or \
            args.protocol_sha256 is None:
        raise ValueError("positive run requires --protocol and --protocol-sha256")
    protocol_path = Path(args.protocol).resolve()
    if protocol_path.parent.parent != EVIDENCE_ROOT or \
            protocol_path.parent.resolve() == output or \
            protocol_path.name != "protocol.json":
        raise ValueError("positive protocol must be a separate direct evidence leaf")
    if output.exists():
        raise FileExistsError(f"positive evidence leaf already exists: {output}")
    runtime_paths = runtime_julia_paths()
    _assert_r3_runtime_parse_inventory(runtime_paths)
    inputs_before, managed_before = _current_input_snapshots()
    _ensure_managed_namespace_packages()
    historical_reader_module = _load_exact_source_module(
        "tools.workspace_sources", WORKSPACE_SOURCES_RELATIVE,
        managed_before[WORKSPACE_SOURCES_RELATIVE])
    historical_t1_data_before = \
        _t1_historical_data_group(historical_reader_module)
    manifest_hash = args.manifest_sha256.lower()
    if manifest_hash != T1_SOFTWARE_MANIFEST_SHA256:
        raise ValueError("formal T1 software manifest expected hash mismatch")
    v3_qualification_hash = args.v3_qualification_sha256.lower()
    if v3_qualification_hash != V3_QUALIFICATION_SHA256:
        raise ValueError("source-witness qualification expected hash mismatch")
    protocol = _verify_positive_protocol(
        protocol_path, args.protocol_sha256.lower(), args, inputs_before,
        managed_before, historical_t1_data_before)
    runtime_pins = runtime_input_pins(inputs_before)
    managed_pins = managed_source_receipts()
    if managed_pins != managed_before:
        raise RuntimeError("managed source closure changed during preflight")
    _load_managed_runtime(protocol, args.protocol_sha256.lower(),
                          runtime_pins, managed_pins)
    output.mkdir(parents=False, exist_ok=False)
    baseline_heavy = heavy_processes()
    head_queries: list[dict[str, Any]] = []
    head_query_receipts: dict[str, Any] = {}
    head_before_query = git_head(
        output / "repository_head_before", timeout_seconds=args.phase_timeout,
        receipts=head_query_receipts, receipt_key="head_initial")
    head_queries.append({"position": "before", **head_before_query})
    head_before = head_before_query["head"]
    manifest_hash = args.manifest_sha256.lower()
    phases: list[dict[str, Any]] = []
    pipeline_marked_pass = False
    failure: dict[str, Any] | None = None
    result_fields: dict[str, Any] = {}
    pipeline_final: dict[str, Any] = {}
    v3_verification: dict[str, Any] | None = None
    write_json_new(output / "pipeline_start.json", {
        "schema": "vnext-t2-formal-pipeline-start-r1",
        "created_utc": utc(),
        "repository_head": head_before,
        "expected_repository_head": protocol["expected_repository_head"],
        "actual_head_verified":
            head_before == protocol["expected_repository_head"],
        "repository_head_query": head_before_query,
        "repository_head_query_receipts": head_query_receipts,
        "software_manifest": file_receipt(manifest) if manifest.is_file() else None,
        "software_manifest_expected_sha256": manifest_hash,
        "source_witness_qualification": file_receipt(v3_qualification)
            if v3_qualification.is_file() else None,
        "source_witness_qualification_expected_sha256":
            v3_qualification_hash,
        "managed_execution_protocol": file_receipt(protocol_path),
        "managed_execution_protocol_sha256_external": args.protocol_sha256.lower(),
        "managed_execution_protocol_schema": protocol["schema"],
        "runtime_julia_files": [
            path.relative_to(ROOT).as_posix() for path in runtime_paths],
        "runtime_julia_file_count": len(runtime_paths),
        "historical_runtime_parse_manifest": {
            "path": R3_RUNTIME_PARSE_MANIFEST_PATH.relative_to(ROOT).as_posix(),
            "bytes": R3_HISTORICAL_RECEIPTS[
                "runtime_parse_manifest.tsv"][0],
            "sha256": R3_HISTORICAL_RECEIPTS[
                "runtime_parse_manifest.tsv"][1],
        },
        "managed_julia_parse_paths": list(MANAGED_JULIA_PARSE_PATHS),
        "managed_julia_parse_path_count": len(MANAGED_JULIA_PARSE_PATHS),
        "combined_julia_parse_path_count":
            len(runtime_paths) + len(MANAGED_JULIA_PARSE_PATHS),
        "inputs_before": inputs_before,
        "managed_execution_dependencies_before": managed_before,
        "t1_historical_data_before": historical_t1_data_before,
        "baseline_heavy_processes": baseline_heavy,
        "phase_timeout_seconds": args.phase_timeout,
        "process_tree_working_set_limit_bytes": args.working_set_limit,
        "julia_threads": 1,
        "formal_t2_accepted": False,
        "actual_model_attestation": "unavailable",
    })

    try:
        if not manifest.is_file():
            raise FileNotFoundError(
                f"formal_t1_software_manifest_absent: {manifest}")
        if not HEX64.fullmatch(manifest_hash):
            raise ValueError("software manifest expected SHA-256 is invalid")
        if not HEX64.fullmatch(v3_qualification_hash):
            raise ValueError(
                "source-witness qualification expected SHA-256 is invalid")
        if baseline_heavy:
            raise RuntimeError("serialized Julia lane is occupied: " +
                               json.dumps(baseline_heavy, sort_keys=True))
        if head_before != protocol["expected_repository_head"]:
            raise RuntimeError(
                "repository HEAD does not match formal T1 acceptance HEAD")
        _, static_includes = fusion_package_source_paths()
        assert_shared_entry_connected(static_includes)

        if _T1_VERIFIER is None:
            raise RuntimeError("pinned T1 verifier was not loaded")
        verification = _verify_t1_manifest(
            _T1_VERIFIER, _HISTORICAL_READER_MODULE, manifest, manifest_hash)
        verification_path = output / "software_manifest_verification.json"
        verification_bytes = (json.dumps(
            verification, sort_keys=True, separators=(",", ":")) + "\n").encode()
        with verification_path.open("xb") as stream:
            stream.write(verification_bytes)
            stream.flush()
            os.fsync(stream.fileno())
        verification_hash = sha256_bytes(verification_bytes)

        v3_verification = verify_v3_qualification(
            v3_qualification, v3_qualification_hash)
        v3_verification_path = output / \
            "source_witness_qualification_verification.json"
        write_json_new(v3_verification_path, v3_verification)

        parse_manifest_path = output / "runtime_parse_manifest.tsv"
        parse_paths = [*runtime_paths,
            *(ROOT / relative for relative in MANAGED_JULIA_PARSE_PATHS)]
        if len(runtime_paths) != ORIGINAL_JULIA_PARSE_PATH_COUNT or \
                len(MANAGED_JULIA_PARSE_PATHS) != MANAGED_JULIA_PARSE_PATH_COUNT or \
                len(parse_paths) != COMBINED_JULIA_PARSE_PATH_COUNT or \
                len({path.resolve() for path in parse_paths}) != \
                    COMBINED_JULIA_PARSE_PATH_COUNT:
            raise RuntimeError(
                "managed Julia parse path set is not the frozen 92 plus two pinned clients")
        parse_snapshot = {**inputs_before, **managed_before}
        parse_manifest_receipt = write_parse_manifest(
            parse_manifest_path, parse_paths, parse_snapshot)
        environment = os.environ.copy()
        environment["JULIA_NUM_THREADS"] = "1"
        julia_common = [str(Path(args.julia).resolve()), "--project=" + str(project),
            "--startup-file=no", "--history-file=no", "--threads=1"]

        parse_dir = output / "parse_gate"
        parse_phase = run_phase(
            "parse_gate", julia_common + [str(PARSE_GATE),
                str(parse_manifest_path)], parse_dir,
            timeout_seconds=args.phase_timeout,
            working_set_limit_bytes=args.working_set_limit,
            environment=environment,
        )
        phases.append(parse_phase)
        require_phase_pass(parse_phase)

        clean_load_dir = output / "clean_load"
        clean_load_receipt_path = clean_load_dir / "clean_load_receipt.json"
        clean_load = run_phase(
            "clean_load", julia_common + [str(CLEAN_LOAD_DRIVER),
                str(clean_load_receipt_path)], clean_load_dir,
            timeout_seconds=args.phase_timeout,
            working_set_limit_bytes=args.working_set_limit,
            environment=environment,
        )
        phases.append(clean_load)
        require_phase_pass(clean_load)
        clean_load_receipt = json.loads(
            clean_load_receipt_path.read_text(encoding="utf-8"))
        if clean_load_receipt.get("schema") != \
                "vnext-t2-shared-module-clean-load-receipt-r1":
            raise RuntimeError("clean-load receipt schema mismatch")
        if clean_load_receipt.get("state_before") != "unloaded" or \
                clean_load_receipt.get("state_after_first") != "loaded" or \
                clean_load_receipt.get("state_after_second") != "loaded":
            raise RuntimeError("clean-load state transition mismatch")
        if clean_load_receipt.get("load_invocation_count") != 2 or \
                clean_load_receipt.get("registry_unchanged") is not True or \
                clean_load_receipt.get("fixture_loaded") is not False or \
                clean_load_receipt.get(
                    "shared_loader_clean_load_verified") is not True:
            raise RuntimeError("clean-load invariants failed")

        base = julia_common + [str(DRIVER)]
        producer_dir = output / "producer"
        producer = run_phase(
            "producer", base + ["produce", str(manifest), manifest_hash,
                str(verification_path), verification_hash, str(producer_dir)],
            producer_dir, timeout_seconds=args.phase_timeout,
            working_set_limit_bytes=args.working_set_limit,
            environment=environment,
        )
        phases.append(producer)
        require_phase_pass(producer)
        producer_receipt = load_run_receipt(producer_dir, "produce")
        candidate_path = producer_dir / "candidate_t1_admission_receipt.json"
        producer_package_path = producer_dir / "candidate_package.jls"
        producer_package_receipt = file_receipt(producer_package_path)
        if digest_value(producer_receipt.get(
                "candidate_package_serialized_sha256"),
                "producer candidate package artifact hash") != \
                producer_package_receipt["sha256"]:
            raise RuntimeError(
                "producer candidate package publication hash mismatch")
        producer_result_receipt = file_receipt(producer_dir / "t2_result.jls")
        if digest_value(producer_receipt.get("result_serialized_sha256"),
                "producer result artifact hash") != \
                producer_result_receipt["sha256"]:
            raise RuntimeError("producer result publication hash mismatch")
        candidate_receipt = json.loads(
            candidate_path.read_text(encoding="utf-8"))
        candidate_hash = sha256_bytes(candidate_path.read_bytes())
        stable_hash = digest_value(
            producer_receipt.get("stable_projection_hash"),
            "producer stable projection hash")
        result_reload_identity_hash = digest_value(
            producer_receipt.get("result_reload_identity_hash"),
            "producer result reload identity hash")
        if candidate_receipt.get("schema") != \
                "vnext-t2-candidate-t1-admission-receipt-r1":
            raise RuntimeError(
                "candidate-specific T1 admission receipt schema mismatch")
        if candidate_receipt.get("producer_version") != \
                "formal-candidate-driver-r5":
            raise RuntimeError("candidate-specific T1 driver version mismatch")
        if candidate_receipt.get("evidence_kind") != "formal_t1_actual":
            raise RuntimeError("candidate receipt evidence domain mismatch")
        if digest_value(candidate_receipt.get(
                "software_acceptance_manifest_sha256"),
                "candidate software manifest hash") != manifest_hash:
            raise RuntimeError(
                "candidate receipt lost the software manifest join")
        if digest_value(candidate_receipt.get(
                "software_acceptance_verification_sha256"),
                "candidate software verification hash") != verification_hash:
            raise RuntimeError(
                "candidate receipt lost the manifest verification join")
        if candidate_receipt.get(
                "producer_t1_admission_invocation_count") != 1 or \
                candidate_receipt.get("handoff_revalidation_required") is not True:
            raise RuntimeError(
                "candidate receipt T1 invocation accounting mismatch")

        replay_dir = output / "replay"
        replay = run_phase(
            "replay", base + ["replay", str(manifest), manifest_hash,
                str(verification_path), verification_hash, str(replay_dir),
                candidate_hash, stable_hash, str(producer_package_path),
                producer_package_receipt["sha256"],
                result_reload_identity_hash], replay_dir,
            timeout_seconds=args.phase_timeout,
            working_set_limit_bytes=args.working_set_limit,
            environment=environment,
        )
        phases.append(replay)
        require_phase_pass(replay)
        replay_receipt = load_run_receipt(replay_dir, "replay")
        replay_candidate_path = replay_dir / \
            "candidate_t1_admission_receipt.json"
        replay_package_path = replay_dir / "candidate_package.jls"
        replay_candidate_hash = sha256_bytes(replay_candidate_path.read_bytes())
        replay_package_receipt = file_receipt(replay_package_path)
        if digest_value(replay_receipt.get(
                "candidate_package_serialized_sha256"),
                "replay candidate package artifact hash") != \
                replay_package_receipt["sha256"]:
            raise RuntimeError(
                "replay candidate package publication hash mismatch")
        replay_result_receipt = file_receipt(replay_dir / "t2_result.jls")
        if digest_value(replay_receipt.get("result_serialized_sha256"),
                "replay result artifact hash") != replay_result_receipt["sha256"]:
            raise RuntimeError("replay result publication hash mismatch")
        if digest_value(replay_receipt.get("result_reload_identity_hash"),
                "replay result reload identity hash") != \
                result_reload_identity_hash:
            raise RuntimeError("replay result reload identity changed")
        phase_identities = {
            (phase["pid"], phase["process_create_time_100ns"])
            for phase in phases}
        if len(phase_identities) != 4:
            raise RuntimeError(
                "parse, clean-load, producer, and replay identities are not distinct")
        if replay_candidate_hash != candidate_hash:
            raise RuntimeError(
                "candidate-specific T1 receipt changed in replay")
        if replay_package_receipt["sha256"] != \
                producer_package_receipt["sha256"]:
            raise RuntimeError(
                "producer package artifact bytes changed in replay")
        if digest_value(replay_receipt.get("stable_projection_hash"),
                "replay stable projection hash") != stable_hash or \
                replay_receipt.get("stable_projection") != \
                producer_receipt.get("stable_projection"):
            raise RuntimeError("T2 stable replay projection changed")

        verification_after = _verify_t1_manifest(
            _T1_VERIFIER, _HISTORICAL_READER_MODULE, manifest, manifest_hash)
        v3_verification_after = verify_v3_qualification(
            v3_qualification, v3_qualification_hash)
        inputs_after = runtime_receipts()
        input_changes = changed_inputs(inputs_before, inputs_after)
        managed_after = managed_source_receipts()
        managed_input_changes = changed_inputs(managed_before, managed_after)
        head_after_query = git_head(
            output / "repository_head_after_success",
            timeout_seconds=args.phase_timeout, receipts=head_query_receipts,
            receipt_key="head_success")
        head_queries.append({"position": "after_success", **head_after_query})
        head_after = head_after_query["head"]
        residual = heavy_processes()
        if verification_after != verification:
            raise RuntimeError(
                "software manifest verification changed during T2 run")
        if v3_verification_after != v3_verification:
            raise RuntimeError(
                "source-witness qualification changed during T2 run")
        if input_changes:
            raise RuntimeError(f"formal runtime input drift: {input_changes}")
        if managed_input_changes:
            raise RuntimeError(
                f"managed execution source drift: {managed_input_changes}")
        if head_after != head_before:
            raise RuntimeError("repository HEAD changed during T2 run")
        if residual:
            raise RuntimeError("formal T2 run left heavy processes: " +
                               json.dumps(residual, sort_keys=True))

        final = {
            "schema": "vnext-t2-formal-serial-candidate-replay-r1",
            "status": "pass", "repository_head": head_after,
            "repository_head_queries": head_queries,
            "repository_head_query_receipts": head_query_receipts,
            "expected_repository_head": protocol["expected_repository_head"],
            "actual_head_verified": True,
            "software_acceptance_manifest": {
                "path": str(manifest), "sha256": manifest_hash,
                "verification_path": str(verification_path),
                "verification_sha256": verification_hash,
                "verified": True, "candidate_specific": False,
            },
            "source_witness_software_qualification": {
                "path": str(v3_qualification),
                "sha256": v3_qualification_hash,
                "verification": file_receipt(v3_verification_path),
                "qualified_source": v3_verification["qualified_source"],
                "verified_before_julia": True,
                "verified_after_replay": True,
            },
            "candidate_t1_admission_receipt": {
                "producer": file_receipt(candidate_path),
                "replay": file_receipt(replay_candidate_path),
                "stable": True, "candidate_specific": True,
            },
            "candidate_package_artifact": {
                "producer": producer_package_receipt,
                "replay_copy": file_receipt(replay_package_path),
                "fresh_replay_deserialized_producer_artifact": True,
                "independent_expected_admission_rebuilt": True,
            },
            "parse_gate": parse_phase,
            "runtime_parse_manifest": parse_manifest_receipt,
            "clean_load": clean_load, "producer": producer, "replay": replay,
            "clean_load_receipt": file_receipt(clean_load_receipt_path),
            "parse_gate_natural_exit_before_clean_load_start": True,
            "clean_load_natural_exit_before_candidate_start": True,
            "producer_natural_exit_before_replay_start": True,
            "process_overlap": False,
            "fresh_process_identity_distinct": True,
            "stable_projection_equal": True,
            "stable_projection_hash": stable_hash,
            "inputs_before": inputs_before, "inputs_after": inputs_after,
            "managed_execution_dependencies_before": managed_before,
            "managed_execution_dependencies_after": managed_after,
            "t1_historical_data_before": historical_t1_data_before,
            "pinned_input_changes": input_changes,
            "managed_source_changes": managed_input_changes,
            "residual_heavy_processes": residual,
            "formal_gate_evidence_kind": "formal_t1_actual",
            "formal_gate_verified": True,
            "t1_admission_invocations_per_process": 2,
            "five_consumer_invocations_per_process": {
                "e0": 1, "gi1a": 1, "e1": 1, "e2": 1, "n10": 1,
            },
            "formal_t2_accepted": False,
            "physical_acceptance": False,
            "scientific_acceptance": False,
            "actual_model_attestation": "unavailable",
        }
        final_path = output / "formal_t2_serial_replay.json"
        write_json_new(final_path, final)
        result_fields = {
            "clean_load_pid": clean_load["pid"],
            "producer_pid": producer["pid"],
            "replay_pid": replay["pid"],
            "candidate_receipt_sha256": candidate_hash,
            "result_reload_identity_hash": result_reload_identity_hash,
            "stable_projection_hash": stable_hash,
            "final": file_receipt(final_path),
        }
        pipeline_marked_pass = True
    except BaseException as error:
        message = str(error)
        if "formal_t1_software_manifest_absent" in message:
            classification = "formal_t1_software_manifest_absent"
        elif "source_witness_software_qualification_absent" in message:
            classification = "source_witness_software_qualification_absent"
        elif "shared_entry_not_connected" in message:
            classification = "shared_entry_not_connected"
        elif "failed: exit=" in message:
            classification = "julia_phase_failure"
        elif "serialized Julia lane is occupied" in message:
            classification = "serialized_lane_occupied"
        else:
            classification = "program_exception"
        failure = {
            "classification": classification,
            "type": type(error).__name__,
            "message": message,
            "traceback": "".join(traceback.format_exception(error)),
        }
        raise
    finally:
        after_error: dict[str, str] | None = None
        managed_after_final: dict[str, dict[str, Any]] = {}
        managed_after_error: dict[str, str] | None = None
        historical_t1_data_after_final: dict[str, Any] | None = None
        historical_t1_data_after_error: dict[str, str] | None = None
        try:
            inputs_after_final = runtime_receipts()
        except BaseException as snapshot_error:
            inputs_after_final = {}
            after_error = {
                "type": type(snapshot_error).__name__,
                "message": str(snapshot_error),
            }
        try:
            managed_after_final = managed_source_receipts()
        except BaseException as snapshot_error:
            managed_after_final = {}
            managed_after_error = {
                "type": type(snapshot_error).__name__,
                "message": str(snapshot_error),
            }
        try:
            historical_t1_data_after_final = \
                _t1_historical_data_group(_HISTORICAL_READER_MODULE)
        except BaseException as snapshot_error:
            historical_t1_data_after_error = {
                "type": type(snapshot_error).__name__,
                "message": str(snapshot_error),
            }
        input_changes_final = changed_inputs(
            inputs_before, inputs_after_final) if after_error is None else \
            ["<runtime_snapshot_failed>"]
        managed_input_changes_final = changed_inputs(
            managed_before, managed_after_final) if managed_after_error is None else \
            ["<managed_snapshot_failed>"]
        historical_t1_data_changes_final = (
            [] if historical_t1_data_after_error is None and
            historical_t1_data_after_final == historical_t1_data_before else
            ["<t1_historical_data_snapshot_failed>" if
             historical_t1_data_after_error is not None else
             "<t1_historical_data_drift>"])
        head_query_error: dict[str, str] | None = None
        try:
            head_after_final_query = git_head(
                output / "repository_head_final",
                timeout_seconds=args.phase_timeout, receipts=head_query_receipts,
                receipt_key="head_finally")
            head_queries.append({"position": "finally", **head_after_final_query})
            head_after_final = head_after_final_query["head"]
        except BaseException as head_error:
            head_after_final = None
            head_query_error = {"type": type(head_error).__name__,
                                "message": str(head_error)}
        expected_head_receipt_keys = {
            "head_initial", "head_success", "head_finally"}
        head_query_sequence_complete = (
            [item.get("position") for item in head_queries] ==
            ["before", "after_success", "finally"] and
            set(head_query_receipts) == expected_head_receipt_keys)
        process_generation_rows = [
            (item.get("phase", {}).get("pid"),
             item.get("phase", {}).get("process_create_time_100ns"))
            for item in head_queries]
        process_generation_rows.extend(
            (phase.get("pid"), phase.get("process_create_time_100ns"))
            for phase in phases)
        all_generations_complete = all(
            type(pid) is int and type(ticks) is int and ticks > 0
            for pid, ticks in process_generation_rows)
        all_generations_distinct = (
            all_generations_complete and
            len(set(process_generation_rows)) == len(process_generation_rows))
        residual_final = heavy_processes()
        guard_pass = pipeline_marked_pass and failure is None and \
            after_error is None and not input_changes_final and \
            managed_after_error is None and not managed_input_changes_final and \
            historical_t1_data_after_error is None and \
            not historical_t1_data_changes_final and \
            head_query_error is None and head_query_sequence_complete and \
            all_generations_distinct and \
            head_after_final == head_before and not residual_final
        if not guard_pass and failure is None:
            if after_error is not None:
                guard_classification = "runtime_snapshot_failed"
            elif input_changes_final:
                guard_classification = "runtime_input_drift"
            elif managed_after_error is not None or managed_input_changes_final:
                guard_classification = "managed_source_drift"
            elif historical_t1_data_after_error is not None:
                guard_classification = "t1_historical_data_snapshot_failed"
            elif historical_t1_data_changes_final:
                guard_classification = "t1_historical_data_drift"
            elif head_query_error is not None or not head_query_sequence_complete or \
                    not all_generations_distinct:
                guard_classification = "managed_repository_head_query_failed"
            elif head_after_final != head_before:
                guard_classification = "repository_head_drift"
            elif residual_final:
                guard_classification = "residual_heavy_process"
            else:
                guard_classification = "pipeline_incomplete"
            failure = {"classification": guard_classification,
                       "type": None, "message": None, "traceback": None}
        pipeline_final = {
            "schema": "vnext-t2-formal-pipeline-final-r1",
            "status": "pass" if guard_pass else "fail",
            "classification": "formal_candidate_replay_completed"
                if guard_pass else failure["classification"],
            "started_repository_head": head_before,
            "ended_repository_head": head_after_final,
            "managed_execution_protocol": file_receipt(protocol_path),
            "managed_execution_protocol_sha256_external": args.protocol_sha256.lower(),
            "expected_repository_head": protocol["expected_repository_head"],
            "actual_head_verified": head_query_error is None and
                head_after_final == protocol["expected_repository_head"],
            "repository_head_queries": head_queries,
            "repository_head_query_receipts": head_query_receipts,
            "repository_head_process_generations": process_generation_rows,
            "repository_head_query_sequence_complete": head_query_sequence_complete,
            "all_process_generations_distinct": all_generations_distinct,
            "repository_head_query_error": head_query_error,
            "inputs_before": inputs_before,
            "inputs_after": inputs_after_final,
            "inputs_after_error": after_error,
            "pinned_input_changes": input_changes_final,
            "managed_execution_dependencies_before": managed_before,
            "managed_execution_dependencies_after": managed_after_final,
            "managed_execution_dependencies_after_error": managed_after_error,
            "managed_source_changes": managed_input_changes_final,
            "t1_historical_data_before": historical_t1_data_before,
            "t1_historical_data_after": historical_t1_data_after_final,
            "t1_historical_data_after_error": historical_t1_data_after_error,
            "t1_historical_data_changes": historical_t1_data_changes_final,
            "phases": phases,
            "source_witness_qualification_expected_sha256":
                v3_qualification_hash,
            "source_witness_qualification_verified":
                v3_verification is not None,
            "residual_heavy_processes": residual_final,
            "failure": None if guard_pass else failure,
            "formal_t2_accepted": False,
            "physical_acceptance": False,
            "scientific_acceptance": False,
            "actual_model_attestation": "unavailable",
        }
        write_json_new(output / "pipeline_final.json", pipeline_final)

    if pipeline_final["status"] != "pass":
        raise RuntimeError(
            "formal T2 pipeline final evidence guard did not pass")
    print(json.dumps({
        "status": "pass", **result_fields,
        "formal_t2_accepted": False,
        "pipeline_final": file_receipt(output / "pipeline_final.json"),
    }, sort_keys=True), flush=True)
    print("VNEXT_T2_FORMAL_SERIAL_REPLAY=PASS", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
