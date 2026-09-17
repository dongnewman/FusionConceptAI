"""Strict offline orchestration boundary for UP1 external-closure R2.

Every stage is sent to its version-pinned public validator. A component result
which does not carry an independently bound receipt is unavailable, not
verified. This layer never grants UP1/T0 credit.
"""
from __future__ import annotations
import copy, hashlib, json, os, tempfile, time, subprocess, stat
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Mapping

SCHEMA_VERSION = "UP1-R2.integration-slice.v2"
PIPELINE_VERSION = "up1-r2-integration-r2"
STAGES = ("common", "witness", "pki", "revocation", "source_axis", "g2", "environment", "intake", "aggregate")
ROOT_KEYS = frozenset({"schema", "version", "candidate_id", "source_ref", "source_version", "candidate_fingerprint", "source_fingerprint", "input_fingerprint", "witness", "pki", "revocation", "source_axis", "g2", "environment", "intake", "intake_path", "fixture_role"})
ABSENCE = {"typed_absent", "typed_absence", "terminal_deferred", "not_applicable", "unsupported", "non_evidence"}
INVALID = {"invalid", "fail_closed", "replayed", "stale", "conflict", "program_exception"}

_RECEIPT_EXCLUDE = {"receipt_sha256", "receipt_hash", "state_hash", "auth_tag", "started_at_utc", "ended_at_utc", "receipt_created_at_utc", "pid", "parent_pid"}

def receipt_preimage(value: Mapping[str, Any]) -> dict[str, Any]:
    """Canonical receipt preimage, explicitly excluding self and process metadata."""
    return _semantic({k: v for k, v in value.items() if k not in _RECEIPT_EXCLUDE})

def receipt_digest(value: Mapping[str, Any]) -> str:
    return canonical_digest(receipt_preimage(value))

def state_digest(value: Mapping[str, Any]) -> str:
    return canonical_digest({k: v for k, v in value.items() if k not in {"state_hash", "auth_tag"}})

def _state_equal(left: Mapping[str, Any], right: Mapping[str, Any]) -> bool:
    """Compare complete authenticated states, allowing only ledger auth tag."""
    rhs = {k: v for k, v in right.items() if k != "auth_tag"}
    return _canonical(left) == _canonical(rhs)

class _LedgerConflict(RuntimeError):
    pass

class _StorageUnavailable(RuntimeError):
    pass

def _check_storage_path(path: Path, label: str) -> None:
    """Reject symlink/reparse substitution in the ledger/key parent chain."""
    current = path if path.exists() else path.parent
    while True:
        if current.is_symlink(): raise ValueError(f"{label}_reparse_or_symlink")
        if os.name == "nt":
            try:
                import ctypes
                attrs = ctypes.windll.kernel32.GetFileAttributesW(str(current))
                if attrs != 0xFFFFFFFF and attrs & 0x0400: raise ValueError(f"{label}_reparse_point")
            except AttributeError:
                raise _StorageUnavailable(f"{label}_identity_capability_unavailable")
            try:
                facts = os.stat(current)
                if not hasattr(facts, "st_uid") or not (facts.st_mode & stat.S_IRUSR):
                    raise _StorageUnavailable(f"{label}_owner_acl_unavailable")
                acl = subprocess.run(["icacls", str(current)], stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False, text=True)
                if acl.returncode != 0 or not acl.stdout.strip():
                    raise _StorageUnavailable(f"{label}_owner_acl_unavailable")
            except FileNotFoundError:
                raise _StorageUnavailable(f"{label}_owner_acl_unavailable")
        if current.parent == current: break
        current = current.parent

def _canonical(value: Any) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False).encode("utf-8")

def canonical_digest(value: Any) -> str:
    return hashlib.sha256(_canonical(value)).hexdigest()

def _utc() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z")

def _jsonable(value: Any) -> Any:
    if hasattr(value, "as_dict") and callable(value.as_dict): return value.as_dict()
    if isinstance(value, Mapping): return {str(k): _jsonable(v) for k, v in value.items()}
    if isinstance(value, (list, tuple)): return [_jsonable(v) for v in value]
    return value

def _semantic(value: Any) -> Any:
    if isinstance(value, Mapping):
        return {k: _semantic(v) for k, v in value.items() if k not in {"started_at_utc", "ended_at_utc", "receipt_created_at_utc", "pid", "parent_pid"}}
    if isinstance(value, list): return [_semantic(v) for v in value]
    return value

def _classify(result: Any) -> str:
    if not isinstance(result, Mapping): return "fail_closed"
    raw = result.get("status", result.get("decision", result.get("outcome")))
    if not isinstance(raw, str): return "fail_closed"
    raw = raw.strip().lower()
    if raw in {"test_only", "test-only", "non_evidence", "non-evidence", "admitted_non_evidence"}: return "non_evidence"
    if raw in {"typed_absent", "typed_absence"}: return "typed_absence"
    if raw in {"terminal_deferred", "unsupported", "not_applicable"}: return raw
    if raw in {"valid", "verified", "present", "admitted", "admissible", "accepted_local", "valid_for_declared_scope"}: return "verified"
    return "fail_closed"

def _stage_record(name: str, result: Any, *, error: str | None = None, skipped: bool = False) -> dict[str, Any]:
    result = _jsonable(result); state = "terminal_deferred" if skipped else _classify(result)
    digest = canonical_digest({"stage": name, "status": state, "result": _semantic(result), "error": error})
    return {"stage": name, "status": state, "error": error, "skipped": skipped, "result": result, "receipt_sha256": digest, "receipt_hash": digest, "claim_ceiling": "contract_software_preparation_only", "no_publish": True}

def _missing(stage: str, detail: str) -> dict[str, Any]:
    return _stage_record(stage, {"status": "typed_absent", "resolution": "terminal_deferred", "error_code": "input_absent", "detail": detail})

def _strict_root(package: Any) -> tuple[dict[str, Any] | None, str | None]:
    if not isinstance(package, Mapping): return None, "package_not_object"
    unknown = sorted(set(package) - ROOT_KEYS)
    if unknown: return None, f"unknown_root_field:{unknown[0]}"
    if package.get("schema") != "UP1-R2.integration-input.v1": return None, "schema_mismatch"
    if package.get("version") != "v1": return None, "version_mismatch"
    for key in ("candidate_id", "source_ref", "source_version"):
        if not isinstance(package.get(key), str) or not package[key].strip(): return None, f"missing_or_invalid:{key}"
    if package.get("fixture_role", "PRODUCTION") not in {"PRODUCTION", "TEST_ONLY"}: return None, "fixture_role_invalid"
    for stage in STAGES[1:-1]:
        if stage in package and stage != "intake" and not isinstance(package[stage], Mapping): return None, f"stage_not_object:{stage}"
    if "intake" in package and not isinstance(package["intake"], (str, Mapping)): return None, "stage_invalid:intake"
    for key in ("candidate_fingerprint", "source_fingerprint", "input_fingerprint"):
        val = package.get(key)
        if val is not None and (not isinstance(val, str) or len(val) != 64 or any(c not in "0123456789abcdef" for c in val)): return None, f"invalid_fingerprint:{key}"
    return dict(package), None

def _package_fingerprint(package: Mapping[str, Any], anchors: Mapping[str, Any] | None = None) -> tuple[str, dict[str, str]]:
    body = {k: v for k, v in package.items() if k != "input_fingerprint"}; inp = canonical_digest(body)
    anchored_candidate = _anchor(anchors, "candidate_fingerprint")
    anchored_source = _anchor(anchors, "source_fingerprint")
    candidate = anchored_candidate
    source = anchored_source
    if not isinstance(candidate, str) or len(candidate) != 64: candidate = canonical_digest({"candidate_id": package["candidate_id"]})
    if not isinstance(source, str) or len(source) != 64: source = canonical_digest({"source_ref": package["source_ref"], "source_version": package["source_version"]})
    hex64 = lambda value: isinstance(value, str) and len(value) == 64 and all(c in "0123456789abcdef" for c in value)
    if isinstance(anchored_candidate, str) and not hex64(anchored_candidate): raise ValueError("candidate_fingerprint_anchor_invalid")
    if isinstance(anchored_source, str) and not hex64(anchored_source): raise ValueError("source_fingerprint_anchor_invalid")
    if isinstance(anchors, Mapping) and "candidate_context" in anchors and canonical_digest(anchors["candidate_context"]) != candidate: raise ValueError("candidate_context_digest_mismatch")
    if isinstance(anchors, Mapping) and "source_identity" in anchors and canonical_digest(anchors["source_identity"]) != source: raise ValueError("source_identity_digest_mismatch")
    if isinstance(anchored_candidate, str) and package.get("candidate_fingerprint") is not None and package["candidate_fingerprint"] != candidate: raise ValueError("candidate_fingerprint_anchor_mismatch")
    if isinstance(anchored_source, str) and package.get("source_fingerprint") is not None and package["source_fingerprint"] != source: raise ValueError("source_fingerprint_anchor_mismatch")
    if package.get("input_fingerprint") is not None and package["input_fingerprint"] != inp: raise ValueError("input_fingerprint_mismatch")
    return inp, {"candidate": candidate, "source": source, "input": inp}

def _anchor(anchors: Mapping[str, Any] | None, name: str) -> Any:
    return anchors.get(name) if isinstance(anchors, Mapping) else None

def _validate_bound_result(stage: str, result: Any, fp: Mapping[str, str], role: str) -> dict[str, Any]:
    result = _jsonable(result); state = _classify(result)
    if not isinstance(result, Mapping): return _stage_record(stage, {"status": "fail_closed", "error_code": "component_result_not_object"})
    if stage == "intake" and state == "verified" and role != "TEST_ONLY":
        return _stage_record(stage, {"status": "typed_absent", "error_code": "local_intake_is_not_authority"})
    # TEST_ONLY still executes the real validator, but its software success is
    # deliberately reduced before any production receipt checks.
    if role == "TEST_ONLY" and state == "verified":
        return _stage_record(stage, {**result, "status": "non_evidence", "non_evidence": True})
    if state == "verified":
        if not isinstance(result.get("schema"), str) or not result.get("schema"):
            return _stage_record(stage, {"status": "typed_absent", "error_code": "component_schema_absent"})
        if result.get("authority_verified") is not True:
            return _stage_record(stage, {"status": "typed_absent", "error_code": "component_authority_absent"})
        for key, expected in (("candidate_fingerprint", fp["candidate"]), ("source_fingerprint", fp["source"]), ("input_fingerprint", fp["input"])):
            if result.get(key) != expected: return _stage_record(stage, {"status": "typed_absent", "error_code": "component_receipt_binding_absent", "error_path": key})
        supplied_hash = result.get("receipt_sha256", result.get("receipt_hash"))
        if not isinstance(supplied_hash, str) or result.get("receipt_sha256", supplied_hash) != supplied_hash or result.get("receipt_hash", supplied_hash) != supplied_hash:
            return _stage_record(stage, {"status": "typed_absent", "error_code": "component_receipt_hash_absent"})
        unsigned = {k: v for k, v in result.items() if k not in {"receipt_sha256", "receipt_hash"}}
        if supplied_hash != canonical_digest(unsigned):
            return _stage_record(stage, {"status": "fail_closed", "error_code": "component_receipt_hash_mismatch"})
        if result.get("claim_ceiling") not in {"contract_software_preparation_only", "preparation_only", "environment_provenance_only", "TEST_ONLY non_evidence"}: return _stage_record(stage, {"status": "fail_closed", "error_code": "claim_ceiling_invalid"})
    return _stage_record(stage, result)

class _IntegrationLedger:
    def __init__(self, path: str | os.PathLike[str], key_path: str | os.PathLike[str]): self.path, self.key_path = Path(path), Path(key_path)
    def _key(self) -> bytes:
        _check_storage_path(self.key_path, "replay_key")
        if self.key_path.is_symlink() or not self.key_path.is_file(): raise ValueError("replay_key_not_regular")
        key = self.key_path.read_bytes()
        if not key: raise ValueError("replay_key_empty")
        return key
    @contextmanager
    def _lock(self):
        lock = Path(str(self.path) + ".lock")
        deadline = time.monotonic() + 10.0
        fd = None
        while fd is None:
            try:
                lock.parent.mkdir(parents=True, exist_ok=True)
                fd = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
            except FileExistsError:
                if time.monotonic() >= deadline: raise TimeoutError("integration_ledger_lock_timeout")
                time.sleep(0.01)
        try:
            os.write(fd, str(os.getpid()).encode("ascii")); os.close(fd); fd = None
            yield
        finally:
            if fd is not None: os.close(fd)
            try: lock.unlink()
            except FileNotFoundError: pass
    def load(self) -> dict[str, Any] | None:
        _check_storage_path(self.path, "integration_ledger")
        with self._lock():
            return self._read_unlocked()
    def _read_unlocked(self) -> dict[str, Any] | None:
        if not self.path.exists(): return None
        raw = json.loads(self.path.read_text(encoding="utf-8")); latest = raw.get("latest") if isinstance(raw, Mapping) and raw.get("schema") == "UP1-R2.integration-ledger.v1" else None
        if not isinstance(latest, Mapping): raise ValueError("integration_ledger_schema_invalid")
        body = {k: v for k, v in latest.items() if k != "auth_tag"}
        if latest.get("auth_tag") != hashlib.sha256(self._key() + _canonical(body)).hexdigest(): raise ValueError("integration_ledger_auth_invalid")
        if latest.get("receipt_sha256") != receipt_digest(latest) or latest.get("receipt_hash") != latest.get("receipt_sha256"):
            raise ValueError("integration_receipt_hash_invalid")
        if latest.get("state_hash") != state_digest(latest): raise ValueError("integration_state_hash_invalid")
        return dict(latest)
    def commit(self, output: Mapping[str, Any], *, expected_receipt: str | None, expected_sequence: int) -> None:
        _check_storage_path(self.path, "integration_ledger")
        with self._lock():
            current = self._read_unlocked()
            current_receipt = current.get("receipt_sha256") if current else None
            current_sequence = int(current.get("sequence", 0)) if current else 0
            if current_receipt != expected_receipt or current_sequence + 1 != expected_sequence:
                raise _LedgerConflict("integration_ledger_compare_and_swap_conflict")
            self.path.parent.mkdir(parents=True, exist_ok=True); latest = dict(output); latest["sequence"] = expected_sequence; latest["state_hash"] = state_digest(latest); latest["auth_tag"] = hashlib.sha256(self._key() + _canonical({k: v for k, v in latest.items() if k != "auth_tag"})).hexdigest(); body = {"schema": "UP1-R2.integration-ledger.v1", "latest": latest}
            fd, temp_name = tempfile.mkstemp(prefix=self.path.name + ".", suffix=".tmp", dir=str(self.path.parent), text=True)
            try:
                with os.fdopen(fd, "w", encoding="utf-8", newline="") as stream: stream.write(_canonical(body).decode()); stream.flush(); os.fsync(stream.fileno())
                os.replace(temp_name, self.path)
            finally:
                if os.path.exists(temp_name): os.unlink(temp_name)

def _component(stage: str, value: Any, *, package: Mapping[str, Any], fp: Mapping[str, str], kwargs: Mapping[str, Any]) -> dict[str, Any]:
    if value is None: return _missing(stage, "stage input absent")
    try:
        if stage == "witness":
            from ..witness_authority.validator import validate; result = validate(value, now=kwargs.get("now"))
        elif stage == "pki":
            from ..pki_chain.verifier import verify_request; result = verify_request(value)
        elif stage == "revocation":
            from ..revocation_time_replay.core import PersistentReplayLedger, validate; result = validate(value, ledger=PersistentReplayLedger(kwargs["ledger_path"], key_path=kwargs["key_path"]))
        elif stage == "source_axis":
            from ..source_axis_binding.source_axis_binding import validate_bundle; result = validate_bundle(value, _anchor(kwargs.get("anchors"), "observed_source_identity"))
        elif stage == "g2":
            from ..g2_mapping.production_g2_mapping import evaluate; result = evaluate(value, _anchor(kwargs.get("anchors"), "g2_expected_binding"))
        elif stage == "environment":
            from ..environment_provenance.validator import validate_document; result = validate_document(value, root=kwargs.get("repo_root"), expected_context=kwargs["expected_context"], expected_context_sha256=_anchor(kwargs.get("anchors"), "expected_context_sha256"), trust_anchor=_anchor(kwargs.get("anchors"), "trust_anchor"), trust_anchor_sha256=_anchor(kwargs.get("anchors"), "trust_anchor_sha256"))
        elif stage == "intake":
            from ..authority_intake.adapter import AuthorityIntakeAdapter; result = AuthorityIntakeAdapter(kwargs["intake_spool"]).intake(value)
        else: return _missing(stage, "unknown component stage")
        return _validate_bound_result(stage, result, fp, str(package.get("fixture_role", "PRODUCTION")))
    except Exception as exc: return _stage_record(stage, {"status": "program_exception", "error_code": "program_exception"}, error=f"{type(exc).__name__}: {exc}")

def _aggregate_document(fp: Mapping[str, str], records: Mapping[str, Any]) -> dict[str, Any]:
    def one(stage: str, responsibility: str) -> dict[str, Any]:
        r = records[stage]
        return {"responsibility": responsibility, "fingerprints": dict(fp), "receipts": [{"receipt_id": "integration/" + stage, "component": stage, "status": "verified", "fingerprints": dict(fp), "authority_verified": True}]}
    return {"schema_version": "UP1-EXTERNAL-CLOSURE-R2-AGGREGATE-V1", "event": "intake", "sequence": 1, "fingerprints": dict(fp), "fingerprint_domains": {"candidate":"candidate", "source":"source", "input":"input"}, "responsibility_packages": {"g1": one("witness", "g1"), "g2": one("g2", "g2"), "g3": one("environment", "g3"), "source_authority": one("intake", "source_authority")}, "authority_verified": True}

def run_pipeline(package: Mapping[str, Any], *, expected_context: Mapping[str, Any] | None = None, anchors: Mapping[str, Any] | None = None, ledger_path: str | os.PathLike[str] | None = None, key_path: str | os.PathLike[str] | None = None, prior_state: Mapping[str, Any] | None = None, repo_root: str | os.PathLike[str] | None = None, intake_spool: str | os.PathLike[str] | None = None, now: str | None = None) -> dict[str, Any]:
    started = _utc(); root, error = _strict_root(package)
    if error: return _failure(error, started)
    assert root is not None
    role = root.get("fixture_role", "PRODUCTION")
    try: input_hash, fp = _package_fingerprint(root, anchors)
    except (TypeError, ValueError) as exc: return _failure(str(exc), started)
    missing = []
    if expected_context is None: missing.append("expected_context")
    for name in ("candidate_fingerprint", "source_fingerprint", "expected_context_sha256", "trust_anchor", "trust_anchor_sha256"):
        if _anchor(anchors, name) is None: missing.append(name)
    if ledger_path is None: missing.append("ledger_path")
    if key_path is None: missing.append("replay_key")
    if intake_spool is None: missing.append("intake_spool")
    if missing: return _finish(root, fp, input_hash, {"common": _stage_record("common", {"status": "verified", "canonical_input_sha256": input_hash}), **{s: _missing(s, "independent_anchor_missing:" + ",".join(missing)) for s in STAGES[1:]}}, started, "terminal_deferred", event="intake")
    try: ledger = _IntegrationLedger(ledger_path, key_path); latest = ledger.load()
    except _StorageUnavailable as exc: return _deferred(str(exc), started)
    except (OSError, ValueError, json.JSONDecodeError) as exc: return _failure(f"integration_ledger_invalid:{exc}", started)
    if prior_state is not None and (not isinstance(prior_state, Mapping) or latest is None or not _state_equal(prior_state, latest)): return _failure("prior_state_not_in_authenticated_ledger", started)
    if latest is not None and latest.get("input_fingerprint") == input_hash:
        if latest.get("new_ad") is not False or latest.get("no_publish") is not True or latest.get("status") == "eligible_for_authority_recheck": return _failure("ledger_prior_promotion_invalid", started)
        out = copy.deepcopy(latest); out.pop("auth_tag", None); out.update({"schema": SCHEMA_VERSION, "event": "deterministic_noop", "input_unchanged": True, "new_ad": False, "no_publish": True, "sequence": int(latest.get("sequence", 0)) + 1, "prev_receipt_sha256": latest.get("receipt_sha256"), "started_at_utc": started, "ended_at_utc": _utc(), "pid": os.getpid(), "parent_pid": os.getppid()})
        out["receipt_sha256"] = receipt_digest(out); out["receipt_hash"] = out["receipt_sha256"]; out["state_hash"] = state_digest(out)
        try: ledger.commit(out, expected_receipt=latest.get("receipt_sha256"), expected_sequence=int(latest.get("sequence", 0)) + 1)
        except _LedgerConflict as exc: return _failure(str(exc), started)
        except _StorageUnavailable as exc: return _deferred(str(exc), started)
        except (OSError, ValueError) as exc: return _failure(f"integration_ledger_commit_failed:{exc}", started)
        return out
    changed = latest is not None and latest.get("input_fingerprint") != input_hash; records = {"common": _stage_record("common", {"status": "verified", "canonical_input_sha256": input_hash})}; blocked = False
    for stage in STAGES[1:-1]:
        if changed or blocked: records[stage] = _stage_record(stage, {"status": "terminal_deferred", "error_code": "input_fingerprint_changed" if changed else "upstream_blocked"}, skipped=True)
        else: records[stage] = _component(stage, root.get(stage) if stage != "intake" else root.get("intake_path", root.get("intake")), package=root, fp=fp, kwargs={"expected_context": expected_context, "anchors": anchors, "ledger_path": ledger_path, "key_path": key_path, "repo_root": repo_root, "intake_spool": intake_spool, "now": now})
        if records[stage]["status"] in INVALID or records[stage]["status"] in ABSENCE: blocked = True
    if changed:
        records["aggregate"] = _stage_record("aggregate", {"status": "terminal_deferred", "error_code": "input_fingerprint_changed"}, skipped=True); return _finish(root, fp, input_hash, records, started, "terminal_deferred", event="intake_changed", ledger=ledger, expected_receipt=latest.get("receipt_sha256") if latest else None, expected_sequence=int(latest.get("sequence", 0)) + 1 if latest else 1)
    if not blocked and all(records[s]["status"] == "verified" for s in STAGES[1:-1]):
        try:
            from ..aggregate_gate.aggregate_gate import aggregate_document
            records["aggregate"] = _stage_record("aggregate", aggregate_document(_aggregate_document(fp, records)))
        except Exception as exc:
            records["aggregate"] = _stage_record("aggregate", {"status": "program_exception", "error_code": "program_exception"}, error=f"{type(exc).__name__}: {exc}")
    else:
        records["aggregate"] = _stage_record("aggregate", {"status": "terminal_deferred", "error_code": "upstream_not_authority_verified"}, skipped=True)
    aggregate_status = records["aggregate"]["status"]
    status = "eligible_for_authority_recheck" if aggregate_status == "verified" and role == "PRODUCTION" else ("fail_closed" if any(r["status"] in INVALID for r in records.values()) else "terminal_deferred")
    return _finish(root, fp, input_hash, records, started, status, event="intake", ledger=ledger, expected_receipt=latest.get("receipt_sha256") if latest else None, expected_sequence=int(latest.get("sequence", 0)) + 1 if latest else 1)

def _finish(root: Mapping[str, Any], fp: Mapping[str, str], input_hash: str, records: Mapping[str, Any], started: str, status: str, *, event: str, ledger: _IntegrationLedger | None = None, expected_receipt: str | None = None, expected_sequence: int = 1) -> dict[str, Any]:
    out = {"schema": SCHEMA_VERSION, "pipeline_version": PIPELINE_VERSION, "event": event, "sequence": expected_sequence, "prev_receipt_sha256": expected_receipt, "status": status, "resolution": "fail_closed" if status == "fail_closed" else ("intake_changed" if event == "intake_changed" else "terminal_deferred"), "terminal_deferred": status != "fail_closed", "no_publish": True, "claim_ceiling": "contract_software_preparation_only", "TEST_ONLY": root.get("fixture_role", "PRODUCTION") == "TEST_ONLY", "non_evidence": root.get("fixture_role", "PRODUCTION") == "TEST_ONLY" or any(r["status"] == "non_evidence" for r in records.values()), "input_fingerprint": input_hash, "fingerprints": dict(fp), "stages": dict(records), "started_at_utc": started, "ended_at_utc": _utc(), "pid": os.getpid(), "parent_pid": os.getppid(), "network_access": False, "heavy_lane": "forbidden", "new_ad": False}
    out["receipt_sha256"] = receipt_digest(out); out["receipt_hash"] = out["receipt_sha256"]; out["state_hash"] = state_digest(out)
    if ledger is not None:
        try: ledger.commit(out, expected_receipt=out.get("prev_receipt_sha256"), expected_sequence=int(out.get("sequence", 1)))
        except _LedgerConflict as exc: return _failure(str(exc), started)
        except _StorageUnavailable as exc: return _deferred(str(exc), started)
        except (OSError, ValueError) as exc: return _failure(f"integration_ledger_commit_failed:{exc}", started)
    return out

def _failure(code: str, started: str) -> dict[str, Any]:
    return {"schema": SCHEMA_VERSION, "pipeline_version": PIPELINE_VERSION, "event": "rejected", "status": "fail_closed", "resolution": "fail_closed", "terminal_deferred": False, "no_publish": True, "new_ad": False, "claim_ceiling": "contract_software_preparation_only", "error_code": code, "started_at_utc": started, "ended_at_utc": _utc(), "pid": os.getpid(), "parent_pid": os.getppid()}

def _deferred(code: str, started: str) -> dict[str, Any]:
    return {"schema": SCHEMA_VERSION, "pipeline_version": PIPELINE_VERSION, "event": "deferred", "status": "terminal_deferred", "resolution": "terminal_deferred", "terminal_deferred": True, "no_publish": True, "new_ad": False, "claim_ceiling": "contract_software_preparation_only", "error_code": code, "started_at_utc": started, "ended_at_utc": _utc(), "pid": os.getpid(), "parent_pid": os.getppid()}

class IntegrationAdapter:
    def adapt(self, stage: str, value: Any, **kwargs: Any) -> dict[str, Any]: return _component(stage, value, package=kwargs.get("package", {}), fp=kwargs["fingerprints"], kwargs=kwargs)

class PipelineRunner:
    version = PIPELINE_VERSION
    def run(self, package: Mapping[str, Any], **kwargs: Any) -> dict[str, Any]: return run_pipeline(package, **kwargs)

run = run_pipeline
