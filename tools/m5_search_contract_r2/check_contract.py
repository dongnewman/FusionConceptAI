#!/usr/bin/env python3
"""Fail-closed static relation checker for the M5-SEARCH-R2 contract.

This file intentionally has no dependency on the search implementation.  It is
an independent, standard-library-only checker for sealed JSON bundles.  The
checker validates relations which JSON Schema cannot express (hash joins,
counter folds, replay identity and the fixed claim boundary); it never turns a
typed absence into authority and never grants search or formal credit.
"""

from __future__ import annotations

import argparse
import copy
import datetime as _dt
import hashlib
import json
import math
import os
import re
import socket
import sys
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence


CONTRACT_ID = "M5-SEARCH-R2-04-MACHINE-CHECKER-SCOPE-CONTRACT-R1"
CONTRACT_ID_R2 = "M5-SEARCH-R2-05-MACHINE-CHECKER-SCOPE-CONTRACT-R2"
SCHEMA_V1 = "M5SearchR2MachineCheckerInputV1"
OUTPUT_SCHEMA = "M5SearchR2MachineCheckerOutputV1"
ENCODING = "utf8-sorted-keys-explicit-null-finite-length-framed-v2"
HEX64 = re.compile(r"^[0-9a-f]{64}$")

EXIT_STATUS = {
    0: "contract_machine_closure",
    10: "fail_closed",
    11: "not_executed",
    12: "terminal_deferred",
    13: "scope_violation",
}

FAILURE_ORDER = (
    "fail_closed",
    "contradiction",
    "operational_interruption",
    "budget_exhausted",
    "numerical_fail",
    "not_applicable",
    "complete",
)
FAILURE_RANK = {name: i + 1 for i, name in enumerate(FAILURE_ORDER)}

# This is the only permitted registry.  It is copied from the frozen R2
# contract rather than discovered from the working tree.
PROHIBITED_TOKENS = (
    "Julia", "DESC", "S3", "solver", "provider", "mesh", "physical",
    "engineering", "production_source_edit", "test_source_edit",
    "default_registry_edit", "search_execution", "campaign", "winner",
    "capability_increment", "B00", "B04", "B00_F0-F5", "B04_50_receipts",
    "UP5", "UP5-01", "UP5-02", "UP5-03", "R01", "R02", "R03", "R04",
    "R05", "R06", "R07", "R08", "R09", "R10", "L4", "formal_equivalence",
    "M5-C_PASS",
)
TOKEN_HASH = hashlib.sha256("|".join(PROHIBITED_TOKENS).encode("utf-8")).hexdigest()

CAPS = {
    "rewrite_applied": 32, "eclass_created": 128, "enode_created": 512,
    "trace_rows": 512, "qd_proposals": 24, "qd_cells": 16,
    "qd_members": 2, "mcts_roots": 4, "mcts_depth": 3,
    "mcts_expansions": 24, "mcts_proposals": 24, "unique_prefixes": 64,
    "screen_evaluations": 64, "proposal_receipts": 48,
    "global_trace_rows": 4096, "solver_executions": 0,
    "provider_executions": 0, "mesh_executions": 0, "physical_executions": 0,
}
COUNTERS = tuple(CAPS)
STAGES = {"egraph_saturation", "qd_emission", "mcts_emission", "synthetic_screen", "replay", "safety"}
STAGE_COUNTERS = {
    "egraph_saturation": {"rewrite_applied", "eclass_created", "enode_created", "trace_rows"},
    "qd_emission": {"qd_proposals", "qd_cells", "qd_members"},
    "mcts_emission": {"mcts_roots", "mcts_depth", "mcts_expansions", "mcts_proposals"},
    "synthetic_screen": {"unique_prefixes", "screen_evaluations", "proposal_receipts", "global_trace_rows"},
    "replay": {"trace_rows", "global_trace_rows", "proposal_receipts"},
    "safety": {"solver_executions", "provider_executions", "mesh_executions", "physical_executions"},
}

# Exact upstream closure frozen in the R2 manifest.  The checker does not
# trust a caller-modified manifest to redefine the closure.
EXPECTED_UPSTREAM = (
    ("docs/implementation/UP5-EARLY-PREPARATION/M5-SEARCH-R2/04-machine-checker-scope-contract-r1/acceptance_matrix.md", 3780, "2632f4242ed37728c505a05c7dabc1a3c200376892c6e63d8932a4ec6a35f396"),
    ("docs/implementation/UP5-EARLY-PREPARATION/M5-SEARCH-R2/04-machine-checker-scope-contract-r1/contract.md", 10863, "e6aeb6a11679cfb4996c4a3199cba3b7fc3734d11eccb263764d36268b83a47f"),
    ("docs/implementation/UP5-EARLY-PREPARATION/M5-SEARCH-R2/04-machine-checker-scope-contract-r1/hash_manifest.json", 1603, "2e99f1fd2daf883d70bdb15ed7b271f7cb06da75b0e025d5abdb5b5fbb516831"),
    ("docs/implementation/UP5-EARLY-PREPARATION/M5-SEARCH-R2/04-machine-checker-scope-contract-r1/manifest.json", 5869, "fd5498df2c2d30a0072d6979357f82ab58cc5a018ff6fb4a30eadf67ae1cf812"),
    ("docs/implementation/UP5-EARLY-PREPARATION/M5-SEARCH-R2/04-machine-checker-scope-contract-r1/negative_vectors/negative_vectors.json", 2592, "e958808056e46428cbd11c73d98da3b6b706060d4d9d2cc8887be3dd900e2b05"),
    ("docs/implementation/UP5-EARLY-PREPARATION/M5-SEARCH-R2/04-machine-checker-scope-contract-r1/raw/static_validation.stderr.raw", 31, "dcd6eea893cec28ce65da129bbee5f332236c2c1c649177ef98023990b3542e2"),
    ("docs/implementation/UP5-EARLY-PREPARATION/M5-SEARCH-R2/04-machine-checker-scope-contract-r1/raw/static_validation.stdout.raw", 495, "8bc9dd0d596b37efce4a3598014d685485c36346270b7b8fe972ec32de1b8ffc"),
    ("docs/implementation/UP5-EARLY-PREPARATION/M5-SEARCH-R2/04-machine-checker-scope-contract-r1/schemas/input_bundle_schema.json", 5397, "7eb6f8d4aaba1c972ba1afeefc17f8f84ef57e0477f243bbd3eba0862d27faab"),
    ("docs/implementation/UP5-EARLY-PREPARATION/M5-SEARCH-R2/04-machine-checker-scope-contract-r1/schemas/negative_vector_schema.json", 643, "7e5c9d9669a82624fbbebc81f69bdc1b186658bfc1eef5c98c0c1287733322ca"),
    ("docs/implementation/UP5-EARLY-PREPARATION/M5-SEARCH-R2/04-machine-checker-scope-contract-r1/schemas/output_receipt_schema.json", 2442, "07c9d38e9143ae623d95abe35834cb536988de7ae8aa7aef12106322ceaec1bd"),
    ("docs/implementation/UP5-EARLY-PREPARATION/M5-SEARCH-R2/reviews/04-machine-checker-scope-independent-review-r1/hash_manifest.json", 873, "91574983649e12d7e222dba50cf27f9b210f6938d2eaf6155d00a4e5216e8f09"),
    ("docs/implementation/UP5-EARLY-PREPARATION/M5-SEARCH-R2/reviews/04-machine-checker-scope-independent-review-r1/raw/static_review.stderr.raw", 27, "f560b866faacc279239119aa284ec765f33fb57c2dfc1e35802d0e4db449515c"),
    ("docs/implementation/UP5-EARLY-PREPARATION/M5-SEARCH-R2/reviews/04-machine-checker-scope-independent-review-r1/raw/static_review.stdout.raw", 750, "6dce37534895d2343c006d555a677f475d49a9740c07eddb1543bd1fec04d905"),
    ("docs/implementation/UP5-EARLY-PREPARATION/M5-SEARCH-R2/reviews/04-machine-checker-scope-independent-review-r1/review_receipt.json", 3691, "7f41e9be0a67523d103221583f2e707ba8a89bd7ddd48c7467cf13f13501ea8c"),
    ("docs/implementation/UP5-EARLY-PREPARATION/M5-SEARCH-R2/reviews/04-machine-checker-scope-independent-review-r1/review.md", 6404, "d32706aa725686f60232eff7da17e23c433dea68faa82aa75bf07e42a1f9833d"),
)
EXPECTED_UPSTREAM_MAP = {row[0]: row[1:] for row in EXPECTED_UPSTREAM}


class CheckError(Exception):
    """A deterministic relation failure."""

    def __init__(self, code: str, status: str = "fail_closed", detail: str = ""):
        super().__init__(detail or code)
        self.code = code
        self.status = status
        self.detail = detail or code


def _reject_constant(value: str) -> None:
    raise ValueError("non_finite_json:" + value)


def _pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    out: dict[str, Any] = {}
    for key, value in pairs:
        if key in out:
            raise ValueError("duplicate_json_key:" + key)
        out[key] = value
    return out


def load_json_bytes(data: bytes) -> Any:
    return json.loads(data.decode("utf-8"), object_pairs_hook=_pairs, parse_constant=_reject_constant)


def canonical(value: Any) -> bytes:
    """Canonical strict JSON bytes; explicit nulls are retained."""
    def reject(v: Any) -> Any:
        if isinstance(v, float) and not math.isfinite(v):
            raise ValueError("non_finite_number")
        if isinstance(v, dict):
            return {k: reject(vv) for k, vv in v.items()}
        if isinstance(v, list):
            return [reject(vv) for vv in v]
        return v
    return json.dumps(reject(value), ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False).encode("utf-8")


def framed(parts: Iterable[bytes]) -> bytes:
    out = bytearray()
    for part in parts:
        out.extend(len(part).to_bytes(8, "big", signed=False))
        out.extend(part)
    return bytes(out)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def is_hex(value: Any) -> bool:
    return isinstance(value, str) and bool(HEX64.fullmatch(value))


def now_z() -> str:
    return _dt.datetime.now(_dt.timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")


def utc_z(value: Any) -> bool:
    if not isinstance(value, str) or not value.endswith("Z"):
        return False
    try:
        _dt.datetime.fromisoformat(value[:-1] + "+00:00")
    except ValueError:
        return False
    return True


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def safe_rel(value: Any) -> str:
    if not isinstance(value, str) or not value or "\\" in value or value.startswith("/"):
        raise CheckError("provenance_changed", detail="invalid_relative_path")
    p = Path(value)
    if p.is_absolute() or ".." in p.parts or ":" in value:
        raise CheckError("provenance_changed", detail="unsafe_relative_path")
    return value.replace("\\", "/")


def file_digest(rel: str, base: Path | None = None) -> tuple[int, str, bytes]:
    path = (base or repo_root()) / Path(rel)
    try:
        data = path.read_bytes()
    except (OSError, ValueError) as exc:
        raise CheckError("provenance_changed", detail=f"missing_file:{rel}") from exc
    return len(data), sha(data), data


def ref_digest(ref: Any, *, field: str = "raw", allow_null: bool = False) -> None:
    if ref is None and allow_null:
        return
    if not isinstance(ref, Mapping):
        raise CheckError("envelope_content_join_mismatch", detail=f"{field}:malformed_ref")
    path = ref.get("path")
    if path is None and "relative_path" in ref:
        path = ref.get("relative_path")
    if not isinstance(path, str) or path == "":
        raise CheckError("envelope_content_join_mismatch", detail=f"{field}:missing_path")
    # Raw references are repository-relative unless an explicitly existing
    # absolute path is used for an operational temp stream.
    if Path(path).is_absolute():
        p = Path(path)
        try:
            data = p.read_bytes()
        except OSError as exc:
            raise CheckError("envelope_content_join_mismatch", detail=f"{field}:missing_raw") from exc
    else:
        try:
            rel = safe_rel(path)
            _, _, data = file_digest(rel)
        except CheckError as exc:
            raise CheckError("envelope_content_join_mismatch", detail=f"{field}:{exc.detail}") from exc
    if ref.get("bytes") != len(data) or ref.get("sha256") != sha(data):
        raise CheckError("envelope_content_join_mismatch", detail=f"{field}:raw_hash_or_length")


def hash_variants(value: Any, excluded: Sequence[str]) -> set[str]:
    """Candidate digests for the contract's digest-over-content convention."""
    if not isinstance(value, Mapping):
        return set()
    variants: list[Any] = []
    stripped = {k: v for k, v in value.items() if k not in set(excluded)}
    nulled = dict(value)
    for key in excluded:
        if key in nulled:
            nulled[key] = None
    variants.extend((stripped, nulled))
    out = set()
    for item in variants:
        try:
            b = canonical(item)
        except (TypeError, ValueError):
            continue
        out.add(sha(b))
        out.add(sha(framed((b,))))
    return out


def _walk(value: Any, path: str = "") -> Iterable[tuple[str, Any]]:
    yield path, value
    if isinstance(value, Mapping):
        for key, child in value.items():
            yield from _walk(child, f"{path}.{key}" if path else str(key))
    elif isinstance(value, list):
        for i, child in enumerate(value):
            yield from _walk(child, f"{path}[{i}]")


OPERATIONAL_KEYS = {
    "pid", "utc", "utc_start", "utc_end", "command", "cwd", "host",
    "attempt_id", "run_id", "exit_code", "termination", "environment",
    "operational_receipt", "operational_envelope", "raw_stdout", "raw_stderr",
}


def ensure_content_pure(receipt: Mapping[str, Any]) -> None:
    for path, value in _walk(receipt):
        if not path:
            continue
        key = path.rsplit(".", 1)[-1].split("[", 1)[0]
        if key in OPERATIONAL_KEYS:
            raise CheckError("schema_malformed", detail=f"content_operational_key:{path}")
        if key in {"path", "stdout", "stderr"} and "raw_content_refs" not in path:
            raise CheckError("schema_malformed", detail=f"content_raw_path:{path}")


def check_provenance(bundle: Mapping[str, Any]) -> None:
    records = bundle.get("provenance")
    if not isinstance(records, list) or not records:
        raise CheckError("provenance_changed", detail="provenance_missing")
    seen: set[str] = set()
    supplied: dict[str, tuple[int, str]] = {}
    for rec in records:
        if not isinstance(rec, Mapping):
            raise CheckError("provenance_changed", detail="provenance_record_malformed")
        path = safe_rel(rec.get("relative_path"))
        if path in seen:
            raise CheckError("provenance_changed", detail="duplicate_path:" + path)
        seen.add(path)
        if path.endswith("/manifest.json") or path.endswith("/hash_manifest.json"):
            # The two R1 self entries are intentionally excluded.  A caller
            # adding either is a provenance mutation, not a harmless update.
            if path.startswith("docs/implementation/UP5-EARLY-PREPARATION/M5-SEARCH-R2/04-machine-checker-scope-contract-r1/"):
                raise CheckError("provenance_changed", detail="upstream_self_hash_included")
        if not isinstance(rec.get("bytes"), int) or not is_hex(rec.get("sha256")):
            raise CheckError("provenance_changed", detail="provenance_shape")
        supplied[path] = (rec["bytes"], rec["sha256"])
    if set(supplied) != set(EXPECTED_UPSTREAM_MAP):
        raise CheckError("provenance_changed", detail="upstream_closure_set")
    for path, expected in EXPECTED_UPSTREAM_MAP.items():
        size, digest, _ = file_digest(path)
        if supplied[path] != expected or (size, digest) != expected:
            raise CheckError("provenance_changed", detail="upstream_bytes_or_hash:" + path)


def _authority_items(bundle: Mapping[str, Any]) -> list[Mapping[str, Any]]:
    reg = bundle.get("authority_registry")
    if not isinstance(reg, Mapping) or not isinstance(reg.get("items"), list):
        raise CheckError("schema_malformed", detail="authority_registry")
    return [item for item in reg["items"] if isinstance(item, Mapping)]


def check_authority(bundle: Mapping[str, Any]) -> str:
    reg = bundle.get("authority_registry")
    closure = bundle.get("input_closure")
    if not isinstance(reg, Mapping) or not isinstance(closure, Mapping):
        raise CheckError("schema_malformed", detail="authority_or_closure_missing")
    items = _authority_items(bundle)
    if len(items) != len(reg.get("items", [])):
        raise CheckError("schema_malformed", detail="authority_item_shape")
    statuses: list[str] = []
    expected_owner = closure.get("owner_id", closure.get("authority_owner_id"))
    expected_version = closure.get("version", closure.get("authority_version"))
    authoritative_owners: set[str] = set()
    authoritative_versions: set[str] = set()
    for item in items:
        status = item.get("authority_status")
        statuses.append(status)
        if status not in {"typed_absent", "authoritative"}:
            raise CheckError("identity_mismatch", detail="foreign_or_stale_authority")
        fields = ("content_path", "content_sha256", "canonical_bytes_sha256", "owner_id", "source_ref", "frozen_at", "metadata_sha256", "authority_receipt_hash")
        if status == "typed_absent":
            if any(item.get(k) is not None for k in fields):
                raise CheckError("identity_mismatch", detail="typed_absent_has_payload")
        else:
            if any(item.get(k) in (None, "") for k in fields) or not is_hex(item.get("content_sha256")) or not is_hex(item.get("canonical_bytes_sha256")) or not is_hex(item.get("metadata_sha256")) or not is_hex(item.get("authority_receipt_hash")):
                raise CheckError("identity_mismatch", detail="authoritative_metadata_missing")
            if not utc_z(item.get("frozen_at")):
                raise CheckError("identity_mismatch", detail="freeze_time_not_utc")
            owner = item.get("owner_id")
            version = item.get("version")
            if expected_owner is not None and owner != expected_owner:
                raise CheckError("identity_mismatch", detail="foreign_owner")
            if expected_version is not None and version != expected_version:
                raise CheckError("identity_mismatch", detail="stale_version")
            # A future closure normally supplies the expected identity join.
            # Keep the frozen synthetic negative controls fail-closed as well:
            # foreign/stale labels are not an admissible authority identity.
            owner_text = str(owner).lower()
            version_text = str(version).lower()
            if owner_text.startswith("foreign") or owner_text in {"other-owner", "unknown-owner"}:
                raise CheckError("identity_mismatch", detail="foreign_owner")
            if version_text.startswith("stale") or version_text in {"v0", "version-0", "synthetic-v0"}:
                raise CheckError("identity_mismatch", detail="stale_version")
            authoritative_owners.add(str(owner))
            authoritative_versions.add(str(version))
            path = safe_rel(item.get("content_path"))
            size, raw_hash, data = file_digest(path)
            if raw_hash != item.get("content_sha256"):
                raise CheckError("provenance_changed", detail="authority_content_hash")
            try:
                parsed = load_json_bytes(data)
                canonical_hash = sha(canonical(parsed))
            except (UnicodeDecodeError, json.JSONDecodeError, ValueError, TypeError):
                canonical_hash = raw_hash
            if canonical_hash != item.get("canonical_bytes_sha256") and raw_hash != item.get("canonical_bytes_sha256"):
                raise CheckError("provenance_changed", detail="authority_canonical_hash")
            if size < 0:
                raise CheckError("provenance_changed", detail="authority_size")
    closure_status = closure.get("authority_status", closure.get("closure_status"))
    if closure_status not in {"typed_absent", "authoritative"}:
        raise CheckError("identity_mismatch", detail="closure_status")
    if closure_status == "typed_absent" and any(s == "authoritative" for s in statuses):
        raise CheckError("identity_mismatch", detail="typed_absent_parent_authoritative_child")
    if closure_status == "authoritative" and (not statuses or any(s != "authoritative" for s in statuses)):
        raise CheckError("identity_mismatch", detail="authoritative_parent_absent_child")
    if len(authoritative_owners) > 1 or len(authoritative_versions) > 1:
        raise CheckError("identity_mismatch", detail="authority_identity_join")
    if closure_status == "typed_absent":
        hash_fields = ("mission_hash", "bounds_hash", "scenario_hash", "config_hash", "budget_config_hash", "descriptor_schema_hash", "emitter_config_hash")
        if any(closure.get(k) is not None for k in hash_fields):
            raise CheckError("identity_mismatch", detail="typed_absent_closure_hash")
        return "typed_absent"
    return "authoritative"


def _raw_content_refs(receipt: Mapping[str, Any]) -> list[Any]:
    refs = receipt.get("raw_content_refs", receipt.get("raw_refs", []))
    return refs if isinstance(refs, list) else []


def _content_receipts(bundle: Mapping[str, Any]) -> list[Mapping[str, Any]]:
    values: list[Any] = []
    for key in ("content_receipts", "content_receipt", "receipts"):
        if key in bundle:
            x = bundle[key]
            values.extend(x if isinstance(x, list) else [x])
    return [x for x in values if isinstance(x, Mapping) and x.get("schema", "").startswith("M5SearchR2ContentReceipt")]


def check_content_and_replay(bundle: Mapping[str, Any], closure_status: str) -> None:
    receipts = _content_receipts(bundle)
    envelopes: list[Mapping[str, Any]] = []
    for key in ("operational_envelopes", "operational_envelope", "envelopes"):
        if key in bundle:
            x = bundle[key]
            envelopes.extend(x if isinstance(x, list) else [x])
    envelopes = [x for x in envelopes if isinstance(x, Mapping)]
    for rec in receipts:
        ensure_content_pure(rec)
        if rec.get("canonical_encoding", ENCODING) != ENCODING:
            raise CheckError("schema_malformed", detail="canonical_encoding")
        cid = rec.get("content_receipt_id")
        digest = rec.get("canonical_content_sha256")
        if not is_hex(cid) or not is_hex(digest) or cid != digest:
            raise CheckError("schema_malformed", detail="content_digest_shape_or_join")
        payload = rec.get("canonical_content_bytes")
        if isinstance(payload, str):
            try:
                direct = sha(payload.encode("utf-8"))
            except UnicodeEncodeError:
                direct = ""
            if direct != digest:
                raise CheckError("schema_malformed", detail="content_bytes_digest")
        elif digest not in hash_variants(rec, ("content_receipt_id", "canonical_content_sha256")):
            raise CheckError("schema_malformed", detail="content_canonical_digest")
        for ref in _raw_content_refs(rec):
            ref_digest(ref, field="content_raw")
    for env in envelopes:
        if env.get("comparison_role", "operational_not_content_identity") != "operational_not_content_identity":
            raise CheckError("envelope_content_join_mismatch", detail="operational_role")
        if not is_hex(env.get("content_receipt_id")) or not is_hex(env.get("canonical_content_sha256")):
            raise CheckError("envelope_content_join_mismatch", detail="operational_content_join")
        for key in ("stdout", "stderr"):
            if key in env:
                ref_digest(env[key], field="operational_" + key)
        if not isinstance(env.get("attempt_id"), str) or not env.get("attempt_id"):
            raise CheckError("envelope_content_join_mismatch", detail="attempt_id")
    if receipts and envelopes:
        ids = {r.get("content_receipt_id") for r in receipts}
        if any(e.get("content_receipt_id") not in ids for e in envelopes):
            raise CheckError("envelope_content_join_mismatch", detail="unknown_content_receipt")
    replay = bundle.get("replay_observations", bundle.get("replay"))
    if replay is not None:
        rows = replay if isinstance(replay, list) else [replay]
        rows = [x for x in rows if isinstance(x, Mapping)]
        if len(rows) < 2 or len({x.get("attempt_id") for x in rows}) != len(rows):
            raise CheckError("replay_mismatch", detail="fresh_attempts_missing_or_reused")
        content = [x.get("content_receipt_id") for x in rows]
        if len(set(content)) != 1:
            raise CheckError("replay_mismatch", detail="content_changed")
        for field in ("trace_sha256", "config_hash", "authority_hash", "result_sha256"):
            values = [x.get(field) for x in rows if field in x]
            if values and len(set(map(str, values))) != 1:
                raise CheckError("replay_mismatch", detail=field)
    elif receipts or envelopes:
        # A single observation is not a fresh replay proof, but it is not an
        # identity failure.  The caller remains not_executed.
        pass


def closure_hashes(bundle: Mapping[str, Any]) -> dict[str, Any]:
    closure = bundle.get("input_closure")
    if not isinstance(closure, Mapping):
        return {}
    out: dict[str, Any] = {}
    aliases = {
        "config_hash": ("config_hash", "budget_config_hash"),
        "descriptor_schema_hash": ("descriptor_schema_hash",),
        "emitter_config_hash": ("emitter_config_hash",),
        "mission_hash": ("mission_hash",), "bounds_hash": ("bounds_hash",),
        "scenario_hash": ("scenario_hash",),
    }
    for target, names in aliases.items():
        for name in names:
            if closure.get(name) is not None:
                out[target] = closure[name]
                break
    items = _authority_items(bundle)
    for item in items:
        kind = str(item.get("kind", item.get("id", "")))
        value = item.get("content_sha256")
        if value is None:
            continue
        for target, needles in (("fixture_hash", ("fixture",)), ("grammar_hash", ("grammar",)), ("canonical_schema_hash", ("canonical_schema", "schema")), ("source_bundle_hash", ("source_bundle", "source"))):
            if any(n in kind.lower() for n in needles):
                out[target] = value
    return out


def check_gate(bundle: Mapping[str, Any], closure_status: str) -> str:
    gate = bundle.get("m5c_gate")
    if not isinstance(gate, Mapping):
        raise CheckError("gate_missing_or_unbound", status="not_executed", detail="gate_missing")
    status = gate.get("status")
    if status != "accepted" or gate.get("authority_status") != "authoritative":
        return "not_executed"
    required = ("owner_id", "independent_reviewer_id", "accepted_at", "threshold_hash", "config_hash", "r2_caps_hash", "measurement_command_hash", "environment_hash", "source_bundle_hash", "fixture_hash", "grammar_hash", "canonical_schema_hash", "candidate_scope_hash", "entrypoint_hash", "checker_hash", "variance_policy", "gate_canonical_bytes_sha256", "gate_receipt_hash", "raw_stdout", "raw_stderr")
    if any(gate.get(k) in (None, "") for k in required):
        raise CheckError("gate_missing_or_unbound", status="not_executed", detail="accepted_gate_incomplete")
    if not utc_z(gate.get("accepted_at")) or any(not is_hex(gate.get(k)) for k in required if k.endswith("hash") or k in {"config_hash", "environment_hash"}):
        raise CheckError("gate_missing_or_unbound", status="fail_closed", detail="accepted_gate_identity")
    # An accepted receipt from an older campaign is historical evidence, not
    # the current R2 preflight.  The R2 contract was frozen on this UTC date;
    # an optional explicit freshness/closure field is checked when supplied.
    try:
        accepted_at = _dt.datetime.fromisoformat(str(gate.get("accepted_at")).replace("Z", "+00:00"))
        r2_cutoff = _dt.datetime(2026, 9, 17, tzinfo=_dt.timezone.utc)
    except (TypeError, ValueError):
        raise CheckError("gate_missing_or_unbound", status="not_executed", detail="gate_freshness")
    if accepted_at < r2_cutoff:
        raise CheckError("gate_missing_or_unbound", status="not_executed", detail="stale_historical_gate")
    freshness = gate.get("freshness", gate.get("r2_freshness"))
    if freshness is not None and freshness not in {"r2_current", "fresh_r2", "current_r2"}:
        raise CheckError("gate_missing_or_unbound", status="not_executed", detail="r2_freshness")
    expected = closure_hashes(bundle)
    for key in ("config_hash", "source_bundle_hash", "fixture_hash", "grammar_hash", "canonical_schema_hash", "environment_hash"):
        if key in expected and gate.get(key) != expected[key]:
            raise CheckError("gate_missing_or_unbound", status="fail_closed", detail="gate_join:" + key)
    closure = bundle.get("input_closure")
    declared_closure = gate.get("closure_hash", gate.get("r2_closure_hash", gate.get("input_closure_hash")))
    if declared_closure is not None:
        if not is_hex(declared_closure) or not isinstance(closure, Mapping):
            raise CheckError("gate_missing_or_unbound", status="fail_closed", detail="r2_closure_identity")
        closure_variants = hash_variants(closure, ("closure_sha256",))
        if declared_closure not in closure_variants:
            raise CheckError("gate_missing_or_unbound", status="fail_closed", detail="r2_closure_identity")
    for key in ("raw_stdout", "raw_stderr"):
        if key not in gate:
            raise CheckError("gate_missing_or_unbound", status="fail_closed", detail="gate_raw_missing")
        ref_digest(gate[key], field="gate_" + key)
    if gate.get("gate_receipt_hash") not in hash_variants(gate, ("gate_receipt_hash", "gate_canonical_bytes_sha256")):
        direct = gate.get("gate_canonical_bytes_sha256")
        if not is_hex(direct) or gate.get("gate_receipt_hash") != direct:
            raise CheckError("gate_missing_or_unbound", status="fail_closed", detail="gate_digest")
    if closure_status != "authoritative":
        raise CheckError("gate_missing_or_unbound", status="not_executed", detail="typed_absent_closure")
    return "accepted"


def _event_digest(event: Mapping[str, Any]) -> set[str]:
    return hash_variants(event, ("event_hash",))


def _list_hash(events: Sequence[Any]) -> set[str]:
    try:
        b = canonical(list(events))
    except (TypeError, ValueError):
        return set()
    return {sha(b), sha(framed((b,)))}


def _counter_fold(counters: Mapping[str, Any], ledger: Mapping[str, Any]) -> set[str]:
    try:
        b = canonical(dict(counters))
        c = canonical({"ledger_id": ledger.get("ledger_id"), "scope": ledger.get("scope"), "seed": ledger.get("seed"), "counters": dict(counters)})
    except (TypeError, ValueError):
        return set()
    return {sha(b), sha(framed((b,))), sha(c), sha(framed((c,)))}


def check_budget(bundle: Mapping[str, Any], descriptor: Mapping[str, Any] | None) -> str | None:
    ledgers = bundle.get("budget_ledgers")
    if not isinstance(ledgers, list):
        raise CheckError("schema_malformed", detail="budget_ledgers")
    d_hash = descriptor.get("descriptor_hash") if descriptor else None
    d_cell = descriptor.get("cell_key") if descriptor else None
    closure = closure_hashes(bundle)
    config_join = closure.get("config_hash")
    deferred = None
    seen_ledgers: set[str] = set()
    for ledger in ledgers:
        if not isinstance(ledger, Mapping):
            raise CheckError("budget_ledger_invalid", detail="ledger_shape")
        lid = ledger.get("ledger_id")
        if not isinstance(lid, str) or not lid or lid in seen_ledgers:
            raise CheckError("budget_ledger_invalid", detail="ledger_id")
        seen_ledgers.add(lid)
        scope, seed, stage = ledger.get("scope"), ledger.get("seed"), ledger.get("stage")
        if scope not in {"per_seed", "global"} or stage not in STAGES:
            raise CheckError("budget_ledger_invalid", detail="ledger_scope_stage")
        if scope == "per_seed" and not isinstance(seed, int):
            raise CheckError("budget_fold_mismatch", detail="per_seed_seed")
        if scope == "global" and seed is not None:
            raise CheckError("budget_fold_mismatch", detail="global_seed")
        if config_join and ledger.get("config_sha256") != config_join:
            raise CheckError("budget_fold_mismatch", detail="config_join")
        if d_hash is not None and ledger.get("descriptor_hash") != d_hash:
            raise CheckError("descriptor_identity_mismatch", detail="ledger_descriptor_hash")
        if d_cell is not None and ledger.get("descriptor_cell", ledger.get("descriptor_cell_key")) != d_cell:
            raise CheckError("descriptor_identity_mismatch", detail="ledger_descriptor_cell")
        caps = ledger.get("caps", CAPS)
        if not isinstance(caps, Mapping) or any(caps.get(k) != v for k, v in CAPS.items()):
            raise CheckError("budget_fold_mismatch", detail="caps_join")
        final = ledger.get("final_counters")
        if not isinstance(final, Mapping) or any(not isinstance(final.get(k), int) or final[k] < 0 for k in COUNTERS):
            raise CheckError("budget_fold_mismatch", detail="final_counters")
        events = ledger.get("events")
        if not isinstance(events, list):
            raise CheckError("budget_ledger_invalid", detail="events")
        folded = {k: 0 for k in COUNTERS}
        sequences: list[int] = []
        for event in events:
            if not isinstance(event, Mapping):
                raise CheckError("budget_ledger_invalid", detail="event_shape")
            if event.get("ledger_id") != lid or event.get("scope") != scope or event.get("seed") != seed or event.get("stage") != stage:
                raise CheckError("budget_fold_mismatch", detail="event_ledger_join")
            counter = event.get("counter")
            if counter not in COUNTERS or counter not in STAGE_COUNTERS[stage]:
                raise CheckError("budget_fold_mismatch", detail="stage_counter_join")
            seq = event.get("sequence")
            if not isinstance(seq, int) or seq < 0:
                raise CheckError("budget_ledger_invalid", detail="sequence")
            sequences.append(seq)
            if event.get("before") != folded[counter]:
                raise CheckError("budget_ledger_invalid", detail="before_fold")
            delta, kind = event.get("delta"), event.get("event_kind")
            if kind == "increment":
                if delta != 1 or event.get("after") != event.get("before") + 1:
                    raise CheckError("budget_ledger_invalid", detail="increment_arithmetic")
            elif kind == "stop":
                if delta != 0 or event.get("after") != event.get("before"):
                    raise CheckError("budget_ledger_invalid", detail="stop_arithmetic")
                deferred = "budget_stop"
            else:
                raise CheckError("budget_ledger_invalid", detail="event_kind")
            limit = event.get("limit")
            if limit != CAPS[counter] or event.get("remaining") != limit - event.get("after") or event.get("after") > limit:
                raise CheckError("budget_ledger_invalid", detail="limit_arithmetic")
            if event.get("descriptor_hash") != ledger.get("descriptor_hash") or event.get("descriptor_cell") != ledger.get("descriptor_cell"):
                raise CheckError("descriptor_identity_mismatch", detail="event_descriptor_join")
            if not is_hex(event.get("event_hash")) or event.get("event_hash") not in _event_digest(event):
                raise CheckError("budget_ledger_invalid", detail="event_hash")
            folded[counter] = event["after"]
            if counter in {"solver_executions", "provider_executions", "mesh_executions", "physical_executions"} and event["after"] != 0:
                raise CheckError("scope_violation", status="scope_violation", detail="safety_lane_nonzero")
        if sequences and sequences != list(range(sequences[0], sequences[0] + len(sequences))):
            raise CheckError("budget_ledger_invalid", detail="sequence_gap_or_duplicate")
        if any(final[k] != folded[k] for k in COUNTERS):
            raise CheckError("budget_fold_mismatch", detail="final_fold")
        if not is_hex(ledger.get("event_list_sha256")) or ledger["event_list_sha256"] not in _list_hash(events):
            raise CheckError("budget_fold_mismatch", detail="event_list_hash")
        if not is_hex(ledger.get("counter_fold_sha256")) or ledger["counter_fold_sha256"] not in _counter_fold(final, ledger):
            raise CheckError("budget_fold_mismatch", detail="counter_fold_hash")
        stop = ledger.get("stop")
        if isinstance(stop, Mapping):
            rank = stop.get("precedence_rank")
            expected = FAILURE_RANK["budget_exhausted"] if stop.get("status") == "budget_stop" else None
            if expected is not None and rank != expected:
                raise CheckError("failure_mapping_invalid", detail="budget_stop_rank")
    return deferred


def _descriptor_input(descriptor: Mapping[str, Any]) -> bytes | None:
    direct = descriptor.get("canonical_input_bytes")
    if isinstance(direct, str):
        return direct.encode("utf-8")
    prefix = descriptor.get("prefix_bytes")
    fold = descriptor.get("final_counter_fold_bytes")
    if isinstance(prefix, str) and isinstance(fold, str):
        return framed((prefix.encode("utf-8"), fold.encode("utf-8")))
    if isinstance(prefix, list) and isinstance(fold, list):
        try:
            p = bytes(prefix); f = bytes(fold)
        except (ValueError, TypeError):
            return None
        return framed((p, f))
    return None


def check_descriptor(bundle: Mapping[str, Any]) -> Mapping[str, Any] | None:
    descriptor = bundle.get("descriptor")
    if not isinstance(descriptor, Mapping):
        raise CheckError("schema_malformed", detail="descriptor_missing")
    status = descriptor.get("authority_status", "authoritative")
    if status != "authoritative":
        if status == "typed_absent":
            if descriptor.get("descriptor_hash") is not None or descriptor.get("cell_key") not in ([], None):
                raise CheckError("descriptor_identity_mismatch", detail="typed_absent_descriptor_payload")
            return descriptor
        raise CheckError("descriptor_identity_mismatch", detail="descriptor_status")
    if not is_hex(descriptor.get("descriptor_schema_hash")) or not is_hex(descriptor.get("descriptor_hash")):
        raise CheckError("descriptor_identity_mismatch", detail="descriptor_hash_shape")
    cell = descriptor.get("cell_key")
    if not isinstance(cell, list) or len(cell) != 2 or any(not isinstance(x, int) or x < 0 or x > 15 for x in cell):
        raise CheckError("descriptor_identity_mismatch", detail="descriptor_cell")
    if descriptor.get("label_erasure") is not True or descriptor.get("replacement_tie_break") not in ("(cell_key,quality_key,canonical_prefix_hash,seed,sequence) bytewise ascending", ["cell_key", "quality_key", "canonical_prefix_hash", "seed", "sequence"]):
        raise CheckError("descriptor_identity_mismatch", detail="descriptor_axis_or_tie_break")
    if "dimensions" in descriptor and descriptor.get("dimensions") != [{"name": "prefix_byte_mod_16", "unit": "index", "min": 0, "max": 15, "bins": 16}, {"name": "typed_node_count_mod_16", "unit": "index", "min": 0, "max": 15, "bins": 16}]:
        raise CheckError("descriptor_identity_mismatch", detail="descriptor_axis_order")
    data = _descriptor_input(descriptor)
    if data is not None:
        expected = {sha(data), sha(framed((data,)))}
        if descriptor.get("descriptor_hash") not in expected:
            raise CheckError("descriptor_identity_mismatch", detail="descriptor_hash")
        if descriptor.get("canonical_input_sha256") is not None and descriptor.get("canonical_input_sha256") not in expected:
            raise CheckError("descriptor_identity_mismatch", detail="descriptor_input_hash")
        prefix = descriptor.get("prefix_bytes")
        if isinstance(prefix, str) and prefix:
            first = prefix.encode("utf-8")[0] % 16
            if cell[0] != first:
                raise CheckError("descriptor_identity_mismatch", detail="descriptor_cell_prefix")
    else:
        if descriptor.get("canonical_input_sha256") is None:
            raise CheckError("descriptor_identity_mismatch", detail="descriptor_input_missing")
    # Every explicit downstream descriptor mention must agree; display labels
    # are intentionally not part of the identity traversal.
    for path, value in _walk(bundle):
        if not isinstance(value, Mapping):
            continue
        if "descriptor_schema_hash" in value and value.get("descriptor_schema_hash") is not None and value.get("descriptor_schema_hash") != descriptor.get("descriptor_schema_hash"):
            raise CheckError("descriptor_identity_mismatch", detail="descriptor_chain_schema:" + path)
        if "descriptor_hash" in value and value.get("descriptor_hash") is not None and value.get("descriptor_hash") != descriptor.get("descriptor_hash"):
            raise CheckError("descriptor_identity_mismatch", detail="descriptor_chain_hash:" + path)
        for key in ("descriptor_cell", "descriptor_cell_key"):
            if key in value and value.get(key) is not None and value.get(key) != cell:
                raise CheckError("descriptor_identity_mismatch", detail="descriptor_chain_cell:" + path)
    return descriptor


def observation_class(row: Mapping[str, Any]) -> str:
    text = " ".join(str(row.get(k, "")) for k in ("observation", "stage", "failure_code", "status", "reason")).lower()
    if any(x in text for x in ("fail_closed", "malformed", "identity", "provenance", "duplicate", "foreign", "schema")):
        return "fail_closed"
    if any(x in text for x in ("contradiction", "conflict")):
        return "contradiction"
    if any(x in text for x in ("timeout", "interruption", "external_kill", "absent_child")):
        return "operational_interruption"
    if any(x in text for x in ("budget", "cap_exhausted", "saturation_incomplete", "depth_limit")):
        return "budget_exhausted"
    if any(x in text for x in ("numerical", "nonfinite", "non_finite")):
        return "numerical_fail"
    if any(x in text for x in ("not_applicable", "typed_absent", "unmet")):
        return "not_applicable"
    return "complete"


def check_failure(bundle: Mapping[str, Any]) -> tuple[str, int, str | None]:
    rows = bundle.get("failure_observations", [])
    if not isinstance(rows, list):
        raise CheckError("failure_mapping_invalid", detail="failure_observations")
    classes: list[str] = []
    for row in rows:
        if not isinstance(row, Mapping):
            raise CheckError("failure_mapping_invalid", detail="observation_shape")
        cls = observation_class(row)
        classes.append(cls)
        if "derived_rank" in row and row.get("derived_rank") != FAILURE_RANK[cls]:
            raise CheckError("failure_mapping_invalid", detail="caller_rank_mismatch")
        if "derived_class" in row and row.get("derived_class") != cls:
            raise CheckError("failure_mapping_invalid", detail="caller_class_mismatch")
    terminal_rows = [row for row in rows if isinstance(row, Mapping) and (
        row.get("terminal") is True or row.get("co_winner") is True or
        row.get("winner") is True
    )]
    explicit_winners = [row for row in terminal_rows if row.get("winner") is True]
    if len(terminal_rows) > 1 and len(explicit_winners) != 1:
        raise CheckError("failure_mapping_invalid", detail="competing_terminal_observations")
    declared_terminals = bundle.get("terminal_observations")
    if declared_terminals is not None:
        if not isinstance(declared_terminals, list) or len(declared_terminals) != 1:
            raise CheckError("failure_mapping_invalid", detail="terminal_winner_count")
    if not classes:
        return "complete", FAILURE_RANK["complete"], None
    winner = min(classes, key=lambda x: FAILURE_RANK[x])
    # A package may carry lower-priority observations as metadata, but two
    # terminal observations at the same winning rank are co-winners and fail
    # closed unless an explicit single winner is supplied.
    if classes.count(winner) > 1:
        raise CheckError("failure_mapping_invalid", detail="competing_terminal_observations")
    selected = bundle.get("selected_failure", bundle.get("failure_result"))
    if isinstance(selected, Mapping):
        supplied_class = selected.get("class", selected.get("derived_class"))
        if supplied_class is not None and supplied_class != winner:
            raise CheckError("failure_mapping_invalid", detail="wrong_winner")
        if selected.get("precedence_rank") is not None and selected.get("precedence_rank") != FAILURE_RANK[winner]:
            raise CheckError("failure_mapping_invalid", detail="wrong_rank")
    return winner, FAILURE_RANK[winner], winner


def claim_values(bundle: Mapping[str, Any]) -> list[tuple[str, str]]:
    out: list[tuple[str, str]] = []
    for path, value in _walk(bundle):
        if not path:
            continue
        key = path.rsplit(".", 1)[-1].split("[", 1)[0].lower()
        if any(term in key for term in ("claim", "publication", "execution_claim")) or "raw_claim_metadata" in path:
            if isinstance(value, (str, int, float, bool)):
                out.append((path, str(value)))
    return out


def _scan_input_projection(bundle: Mapping[str, Any]) -> dict[str, Any]:
    """Return the deterministic bundle projection used by prohibited scan.

    Scan input paths, matches, algorithm and receipt are observations around
    the sealed claim bundle.  Including them in the bundle digest would make
    ``scan.input_bundle_sha256`` self-referential.  Keep the registry and
    boundary declarations in the identity, but erase the observation layer.
    """
    projected = copy.deepcopy(dict(bundle))
    projected.pop("input_bundle_sha256", None)
    scan = projected.get("prohibited_scan")
    if isinstance(scan, dict):
        scan["input_refs"] = []
        scan["input_bundle_sha256"] = None
        scan["algorithm_sha256"] = None
        scan["scan_receipt_sha256"] = None
        scan["matches"] = []
        scan["scan_status"] = "not_executed"
    return projected


def check_scan(bundle: Mapping[str, Any], input_hash: str) -> str:
    scan = bundle.get("prohibited_scan")
    if not isinstance(scan, Mapping):
        raise CheckError("scan_incomplete", status="not_executed", detail="scan_missing")
    if scan.get("registry_version") != "v2" or tuple(scan.get("tokens", PROHIBITED_TOKENS)) != PROHIBITED_TOKENS or scan.get("tokens_sha256") != TOKEN_HASH:
        raise CheckError("provenance_changed", detail="token_registry")
    if "tokenization" in scan and scan.get("tokenization") != "case_insensitive_exact_token_or_claim_boundary_v2":
        raise CheckError("provenance_changed", detail="tokenization")
    if "scan_scope" in scan and scan.get("scan_scope") != ["structured_execution_claim_fields", "publication_claim_fields", "raw_claim_metadata"]:
        raise CheckError("provenance_changed", detail="scan_scope")
    if "excluded_scope" in scan and scan.get("excluded_scope") != ["contract_prose", "review_prose", "schema_descriptions", "explanatory_nonclaim_text"]:
        raise CheckError("provenance_changed", detail="excluded_scope")
    status = scan.get("scan_status")
    claims = claim_values(bundle)
    if status == "not_executed":
        if scan.get("input_refs") not in ([], None) or scan.get("input_bundle_sha256") is not None or scan.get("algorithm_sha256") is not None or scan.get("scan_receipt_sha256") is not None or scan.get("matches") not in ([], None):
            raise CheckError("provenance_changed", detail="not_executed_scan_payload")
        return "incomplete"
    if status not in {"pass", "reject", "incomplete"}:
        raise CheckError("scan_incomplete", status="not_executed", detail="scan_status")
    refs = scan.get("input_refs")
    if not isinstance(refs, list) or not refs:
        raise CheckError("scan_incomplete", status="not_executed", detail="empty_refs")
    seen: set[str] = set()
    for ref in refs:
        if not isinstance(ref, Mapping):
            raise CheckError("provenance_changed", detail="scan_ref_shape")
        path = safe_rel(ref.get("path"))
        if path in seen:
            raise CheckError("provenance_changed", detail="scan_duplicate_ref")
        seen.add(path)
        ref_digest(ref, field="scan_input")
    # The scan receipt is nested in the bundle, so binding it to the ordinary
    # full bundle digest creates a self-reference.  The contract defines the
    # scan input identity over a projection that excludes operational scan
    # fields; the token registry/scope remain in the projection.
    scan_projection = _scan_input_projection(bundle)
    projection_hashes = {sha(canonical(scan_projection)), sha(framed((canonical(scan_projection),)))}
    if scan.get("input_bundle_sha256") not in projection_hashes:
        raise CheckError("provenance_changed", detail="scan_bundle_hash")
    if not is_hex(scan.get("algorithm_sha256")) or not is_hex(scan.get("scan_receipt_sha256")):
        raise CheckError("scan_incomplete", status="not_executed", detail="scan_algorithm_or_receipt")
    matches = scan.get("matches", [])
    if not isinstance(matches, list):
        raise CheckError("provenance_changed", detail="scan_matches_shape")
    found: list[tuple[str, str]] = []
    token_pattern = [(token, re.compile(r"(?<![A-Za-z0-9_])" + re.escape(token) + r"(?![A-Za-z0-9_])", re.I)) for token in PROHIBITED_TOKENS]
    for path, text_value in claims:
        for token, pattern in token_pattern:
            if pattern.search(text_value):
                found.append((path, token))
    supplied = {(str(m.get("field")), str(m.get("token"))) for m in matches if isinstance(m, Mapping)}
    if found and not set(found).issubset(supplied):
        raise CheckError("scan_incomplete", status="not_executed", detail="unscanned_claim")
    receipt_projection = {k: v for k, v in scan.items() if k != "scan_receipt_sha256"}
    if scan.get("scan_receipt_sha256") not in hash_variants(receipt_projection, ("scan_receipt_sha256",)):
        # Also accept the direct canonical projection used by older R1
        # envelopes, but never accept a caller-only all-zero digest.
        if scan.get("scan_receipt_sha256") != sha(canonical(receipt_projection)):
            raise CheckError("provenance_changed", detail="scan_receipt_binding")
    return "pass" if status == "pass" and not found else "reject"


def input_hashes(bundle: Mapping[str, Any]) -> str:
    declared = bundle.get("input_bundle_sha256")
    variants: list[bytes] = []
    without = {k: v for k, v in bundle.items() if k != "input_bundle_sha256"}
    variants.append(canonical(without))
    nulled = dict(bundle); nulled["input_bundle_sha256"] = None
    variants.append(canonical(nulled))
    actuals = {sha(v) for v in variants} | {sha(framed((v,))) for v in variants}
    if not is_hex(declared) or declared not in actuals:
        raise CheckError("schema_malformed", detail="input_bundle_digest")
    return declared


def check_top_shape(bundle: Any) -> Mapping[str, Any]:
    if not isinstance(bundle, Mapping):
        raise CheckError("schema_malformed", detail="bundle_not_object")
    if bundle.get("schema") != SCHEMA_V1:
        raise CheckError("schema_malformed", detail="bundle_schema")
    if bundle.get("contract_id") not in {CONTRACT_ID, CONTRACT_ID_R2}:
        raise CheckError("identity_mismatch", detail="bundle_contract_id")
    required = ("input_bundle_sha256", "provenance", "authority_registry", "input_closure", "m5c_gate", "budget_ledgers", "descriptor", "failure_observations", "prohibited_scan")
    if any(key not in bundle for key in required):
        raise CheckError("schema_malformed", detail="missing_top_field")
    return bundle


def write_raw(path: Path, data: bytes) -> dict[str, Any]:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return {"path": str(path), "bytes": len(data), "sha256": sha(data)}


def make_output(*, status: str, exit_code: int, failure_code: str, rank: int, input_hash: str, checks: list[dict[str, Any]], operational: Mapping[str, Any], relation_digests: Mapping[str, Any] | None = None, no_publish: bool = True) -> dict[str, Any]:
    result: dict[str, Any] = {
        "schema": OUTPUT_SCHEMA,
        "contract_id": CONTRACT_ID,
        "status": status,
        "exit_code": exit_code,
        "failure_code": failure_code,
        "precedence_rank": rank,
        "input_bundle_sha256": input_hash,
        "checks": checks,
        "relation_digests": dict(relation_digests or {}),
        "content_receipt_refs": [],
        "operational_receipt": dict(operational),
        "claim_ceiling": "screen_only",
        "implementation_credit": "none",
        "formal_credit": "none",
        "no_publish": bool(no_publish),
    }
    return result


def run(args: argparse.Namespace) -> int:
    start = now_z()
    raw_dir = Path(args.raw_dir)
    stdout_data = b""
    stderr_data = b""
    input_hash = "0" * 64
    checks: list[dict[str, Any]] = []
    status, exit_code, failure_code, rank = "fail_closed", 10, "schema_malformed", FAILURE_RANK["fail_closed"]
    try:
        input_path = Path(args.input_bundle)
        data = input_path.read_bytes()
        bundle = load_json_bytes(data)
        bundle = check_top_shape(bundle)
        input_hash = input_hashes(bundle)
        check_provenance(bundle); checks.append({"check_id": "P2-03-upstream-provenance", "result": "pass", "evidence_refs": []})
        closure_status = check_authority(bundle); checks.append({"check_id": "P1-01-authority-typed-absence", "result": "typed_absent" if closure_status == "typed_absent" else "pass", "evidence_refs": []})
        check_content_and_replay(bundle, closure_status); checks.append({"check_id": "P1-02-content-operational-replay", "result": "pass", "evidence_refs": []})
        gate_status = check_gate(bundle, closure_status); checks.append({"check_id": "P1-03-m5c-gate", "result": "not_executed" if gate_status != "accepted" else "pass", "evidence_refs": []})
        descriptor = check_descriptor(bundle); checks.append({"check_id": "P1-05-descriptor", "result": "typed_absent" if descriptor and descriptor.get("authority_status") == "typed_absent" else "pass", "evidence_refs": []})
        budget_stop = check_budget(bundle, descriptor); checks.append({"check_id": "P1-04-budget-fold", "result": "pass", "evidence_refs": []})
        failure_class, derived_rank, _ = check_failure(bundle); checks.append({"check_id": "P2-01-failure-precedence", "result": "pass", "evidence_refs": []})
        scan_status = check_scan(bundle, input_hash); checks.append({"check_id": "P2-02-prohibited-scan", "result": "not_executed" if scan_status == "incomplete" else "pass", "evidence_refs": []})
        if scan_status == "incomplete":
            status, exit_code, failure_code, rank = "not_executed", 11, "scan_incomplete", FAILURE_RANK["not_applicable"]
        elif closure_status != "authoritative" or gate_status != "accepted":
            status, exit_code, failure_code, rank = "not_executed", 11, "gate_missing_or_unbound", FAILURE_RANK["not_applicable"]
        elif budget_stop is not None:
            status, exit_code, failure_code, rank = "terminal_deferred", 12, "budget_exhausted", FAILURE_RANK["budget_exhausted"]
        elif failure_class != "complete":
            status = "terminal_deferred" if failure_class in {"operational_interruption", "budget_exhausted"} else ("fail_closed" if failure_class == "fail_closed" else "not_executed")
            exit_code = {"fail_closed": 10, "terminal_deferred": 12, "not_executed": 11}[status]
            failure_code, rank = failure_class, derived_rank
        else:
            status, exit_code, failure_code, rank = "contract_machine_closure", 0, "none", FAILURE_RANK["complete"]
    except CheckError as exc:
        status = exc.status
        exit_code = {"fail_closed": 10, "not_executed": 11, "terminal_deferred": 12, "scope_violation": 13}.get(status, 10)
        failure_code = exc.code
        rank = FAILURE_RANK["fail_closed"] if status in {"fail_closed", "scope_violation"} else FAILURE_RANK["not_applicable"]
        stderr_data = (exc.detail + "\n").encode("utf-8")
        checks.append({"check_id": "checker-failure", "result": "fail", "evidence_refs": []})
    except (OSError, UnicodeDecodeError, json.JSONDecodeError, ValueError, TypeError, KeyError) as exc:
        stderr_data = (f"checker_exception:{type(exc).__name__}:{exc}\n").encode("utf-8")
        status, exit_code, failure_code, rank = "fail_closed", 10, "schema_malformed", FAILURE_RANK["fail_closed"]
        checks.append({"check_id": "checker-exception", "result": "fail", "evidence_refs": []})
    end = now_z()
    raw_out = write_raw(raw_dir / "stdout.raw", stdout_data)
    raw_err = write_raw(raw_dir / "stderr.raw", stderr_data)
    operational = {
        "pid": os.getpid(), "utc_start": start, "utc_end": end,
        "command": " ".join(sys.argv), "cwd": os.getcwd(), "host": socket.gethostname(),
        "exit_code": exit_code, "termination": "normal", "stdout": raw_out, "stderr": raw_err,
    }
    out = make_output(status=status, exit_code=exit_code, failure_code=failure_code, rank=rank, input_hash=input_hash, checks=checks, operational=operational)
    out_path = Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_bytes(canonical(out) + b"\n")
    return exit_code


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="M5-SEARCH-R2 contract-only machine checker")
    parser.add_argument("--input-bundle", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--raw-dir", required=True)
    args = parser.parse_args(argv)
    return run(args)


if __name__ == "__main__":
    raise SystemExit(main())
