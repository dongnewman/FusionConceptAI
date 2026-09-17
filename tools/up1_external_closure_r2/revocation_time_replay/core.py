"""Offline, fixture-only revocation, trusted-time and durable replay checks."""
from __future__ import annotations

import copy
import hashlib
import hmac
import json
import math
import os
import re
import stat
import shutil
import subprocess
import tempfile
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Mapping

SCHEMA = "UP1-R2.revocation-time-replay.v1"
PROFILE = "TEST_ONLY-W2-R1"
CLAIM_CEILING = "TEST_ONLY non_evidence"
REQUIRED_RECEIPT = ("verification_id", "nonce", "challenge", "scope", "source", "source_version", "sequence", "issued_at", "expires_at", "idempotency_key")
TOP_FIELDS = {"schema", "profile", "test_only", "receipt", "receipt_signature_valid", "attestor_signature", "clock_skew_seconds", "replay_window", "trusted_time_receipt", "revocation_receipt", "expected_scope", "expected_source_version", "ledger_namespace", "candidate_binding", "axes", "input_fingerprint", "fixture_id"}
ATTESTOR_FIELDS = {"signature_valid"}
RECEIPT_FIELDS = set(REQUIRED_RECEIPT) | {"payload"}
SCOPE_FIELDS = {"candidate", "source"}
VERSION_FIELDS = {"version", "hash"}
REV_FIELDS = {"available", "kind", "status", "issuer", "serial", "this_update", "next_update", "produced_at", "signature_valid", "issuer_binding_valid", "nonce_required", "nonce", "responder_signature_valid", "chain_valid", "crl_number", "certificate_serial", "thisUpdate", "nextUpdate", "producedAt", "signatureValid", "issuerBindingValid"}
TIME_FIELDS = {"available", "profile", "gen_time", "genTime", "receipt_digest", "receiptDigest", "message_imprint", "messageImprint", "nonce", "challenge", "policy", "valid_from", "valid_to", "validFrom", "validTo", "signature_valid", "signatureValid", "chain_valid", "chainValid", "revocation_valid", "revocationValid"}
WINDOW_FIELDS = {"duration_seconds", "trusted_time_basis", "ledger_retention_seconds", "clock_skew_seconds"}
_BROAD_WINDOWS_PRINCIPALS = {"EVERYONE", "NT AUTHORITY\\AUTHENTICATED USERS", "BUILTIN\\USERS", "USERS", "AUTHENTICATED USERS", "BUILTIN\\GUESTS", "GUESTS", "INTERACTIVE", "LOCAL", "NETWORK", "S-1-1-0", "S-1-5-11", "S-1-5-32-545", "S-1-5-32-546", "S-1-5-4", "S-1-2-0", "S-1-5-2", "S-1-15-2-1", "S-1-15-2-2"}


class ReceiptInputError(ValueError):
    def __init__(self, message: str, code: str = "input_invalid"):
        super().__init__(message)
        self.code = code


def evaluate_windows_acl(detail: Any) -> None:
    """Pure validation of provider-returned owner/DACL/SDDL data."""
    if not isinstance(detail, Mapping):
        raise ReceiptInputError("Windows ACL provider returned a non-object", "trusted_key_acl_invalid")
    required = {"owner_sid", "current_sid", "owner_ok", "sddl", "protected", "access_rules"}
    if not required.issubset(set(detail)) or set(detail) - (required | {"owner", "bad_allow_identities"}):
        raise ReceiptInputError("Windows ACL provider returned malformed fields", "trusted_key_acl_invalid")
    sid_pattern = r"^S-\d(?:-\d+)+$"
    if not isinstance(detail["owner_sid"], str) or not re.fullmatch(sid_pattern, detail["owner_sid"], re.IGNORECASE) or not isinstance(detail["current_sid"], str) or not re.fullmatch(sid_pattern, detail["current_sid"], re.IGNORECASE):
        raise ReceiptInputError("Windows ACL provider returned malformed owner SID", "trusted_key_acl_invalid")
    if not isinstance(detail["owner_ok"], bool) or not isinstance(detail["sddl"], str) or not detail["sddl"] or not isinstance(detail["protected"], bool) or not isinstance(detail["access_rules"], list):
        raise ReceiptInputError("Windows ACL provider returned malformed owner/DACL types", "trusted_key_acl_invalid")
    owner_allowed = detail["owner_sid"].upper() in {detail["current_sid"].upper(), "S-1-5-18", "S-1-5-32-544"}
    if not owner_allowed or detail["owner_ok"] is not True:
        raise ReceiptInputError("Windows ACL owner result is inconsistent", "trusted_key_acl_invalid")
    broad_allow: list[str] = []
    for rule in detail["access_rules"]:
        if not isinstance(rule, Mapping) or set(rule) != {"identity", "type", "inherited"} or not isinstance(rule["identity"], str) or not isinstance(rule["type"], str) or not isinstance(rule["inherited"], bool):
            raise ReceiptInputError("Windows ACL provider returned malformed access rule", "trusted_key_acl_invalid")
        if rule["type"].upper() == "ALLOW" and rule["identity"].upper() in _BROAD_WINDOWS_PRINCIPALS:
            broad_allow.append(rule["identity"])
    if broad_allow:
        raise ReceiptInputError(f"trusted key DACL has broad Allow identities: {broad_allow}", "trusted_key_acl_invalid")


def validate_acl_provider(path: Path, provider: Any) -> None:
    """Invoke an injected ACL provider and classify unsupported vs malformed output."""
    if not callable(provider):
        raise ReceiptInputError("Windows ACL provider unavailable", "trusted_key_acl_unsupported")
    try:
        detail = provider(path)
    except ReceiptInputError:
        raise
    except (OSError, RuntimeError, ValueError, TypeError) as exc:
        raise ReceiptInputError(f"Windows ACL provider unsupported: {exc}", "trusted_key_acl_unsupported") from exc
    evaluate_windows_acl(detail)


def canonical_bytes(value: Any) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False).encode("utf-8")


def canonical_digest(value: Any) -> str:
    return hashlib.sha256(canonical_bytes(value)).hexdigest()


def parse_json_strict(raw: str) -> Any:
    def pairs(items: list[tuple[str, Any]]) -> dict[str, Any]:
        result: dict[str, Any] = {}
        for key, value in items:
            if key in result:
                raise ReceiptInputError(f"duplicate JSON key at $: {key}", "duplicate_field")
            result[key] = value
        return result
    def constant(value: str) -> Any:
        raise ReceiptInputError(f"non-finite JSON number: {value}", "nonfinite_number")
    try:
        return json.loads(raw, object_pairs_hook=pairs, parse_constant=constant)
    except ReceiptInputError:
        raise
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ReceiptInputError(f"invalid JSON: {exc}") from exc


def _dt(value: Any) -> datetime | None:
    if not isinstance(value, str) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})", value):
        return None
    try:
        text = value[:-1] + "+00:00" if value.endswith("Z") else value
        parsed = datetime.fromisoformat(text)
        return parsed.astimezone(timezone.utc) if parsed.tzinfo else None
    except (TypeError, ValueError, OverflowError):
        return None


def _finite(value: Any) -> bool:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return False
    try:
        return math.isfinite(float(value))
    except (TypeError, ValueError, OverflowError):
        return False


def _td(seconds: Any) -> timedelta:
    if not _finite(seconds):
        raise ValueError("non-finite seconds")
    return timedelta(seconds=float(seconds))


def _scope_key(scope: Any) -> str:
    return canonical_bytes(scope).decode("utf-8")


def _error(code: str, detail: str, *, digest: str | None = None, extra: Mapping[str, Any] | None = None) -> dict[str, Any]:
    absence = code in {"revocation_status_unavailable", "trusted_time_absent", "replay_ledger_absent", "replay_window_absent", "trusted_key_acl_unsupported"}
    result = "typed_absent" if absence else "fail_closed"
    out: dict[str, Any] = {"schema": SCHEMA, "result": result, "status": result, "resolution": "terminal_deferred" if absence else "fail_closed", "error_code": code, "detail": detail, "claim_ceiling": CLAIM_CEILING, "network_access": False, "trusted_clock_basis": "signed_receipt_only"}
    if code == "replay_ledger_absent":
        out["no_publish"] = True
    if digest is not None:
        out["canonical_receipt_digest"] = digest
    if extra:
        out.update(copy.deepcopy(dict(extra)))
    return out


def _check_fields(value: Any, allowed: set[str], path: str) -> tuple[str | None, str]:
    if not isinstance(value, Mapping):
        return "receipt_type_invalid", f"{path} must be an object"
    unknown = sorted(set(value) - allowed)
    return ("unknown_field", f"unknown field at {path}: {unknown[0]}") if unknown else (None, "ok")


def _alias(value: Mapping[str, Any], canonical: str, alias: str) -> tuple[str | None, Any]:
    if canonical in value and alias in value:
        return "unknown_field", f"conflicting aliases: {canonical}/{alias}"
    return None, value.get(canonical, value.get(alias))


def _validate_structure(receipt: Any) -> tuple[str | None, str]:
    code, detail = _check_fields(receipt, RECEIPT_FIELDS, "$.receipt")
    if code:
        return code, detail
    for key in REQUIRED_RECEIPT:
        if key not in receipt or receipt[key] is None or receipt[key] == "":
            return ("nonce_absent" if key == "nonce" else "source_version_binding_absent" if key == "source_version" else "receipt_field_absent"), f"missing receipt field: {key}"
    if not isinstance(receipt["verification_id"], str) or not isinstance(receipt["challenge"], str) or not isinstance(receipt["nonce"], str) or not receipt["nonce"] or not isinstance(receipt["idempotency_key"], str) or not receipt["idempotency_key"]:
        return "receipt_type_invalid", "verification_id/challenge/nonce/idempotency_key must be non-empty strings"
    if not isinstance(receipt["source"], str) or not receipt["source"]:
        return "receipt_type_invalid", "source must be a non-empty string"
    version = receipt["source_version"]
    if not isinstance(version, Mapping) or set(version) != VERSION_FIELDS or not all(isinstance(version[k], str) and version[k] for k in VERSION_FIELDS):
        return "source_version_binding_mismatch", "source_version must be {version,hash} strings"
    scope = receipt["scope"]
    if not isinstance(scope, Mapping) or set(scope) != SCOPE_FIELDS or not all(isinstance(scope[k], str) and scope[k] for k in SCOPE_FIELDS):
        return "scope_binding_mismatch", "scope must be {candidate,source} strings"
    if receipt["source"] != scope["source"]:
        return "scope_binding_mismatch", "receipt source must equal scope.source"
    if not isinstance(receipt["sequence"], int) or isinstance(receipt["sequence"], bool) or receipt["sequence"] < 0:
        return "sequence_invalid", "sequence must be a non-negative integer"
    for key in ("issued_at", "expires_at"):
        if _dt(receipt[key]) is None:
            return "timestamp_invalid", f"invalid {key}"
    if "payload" in receipt and not isinstance(receipt["payload"], Mapping):
        return "receipt_type_invalid", "payload must be an object"
    return None, "ok"


def _validate_revocation(rev: Any, as_of: datetime, skew: float, receipt_nonce: str) -> tuple[str | None, str]:
    if not isinstance(rev, Mapping):
        return "revocation_status_unavailable", "revocation source unavailable; no network lookup performed"
    code, detail = _check_fields(rev, REV_FIELDS, "$.revocation_receipt")
    if code:
        return code, detail
    rev = dict(rev)
    if "available" not in rev or not isinstance(rev["available"], bool):
        return "revocation_status_invalid", "revocation available must be boolean"
    if rev["available"] is False:
        return "revocation_status_unavailable", "revocation source unavailable; no network lookup performed"
    for flag in ("available", "signature_valid", "issuer_binding_valid", "responder_signature_valid", "chain_valid", "nonce_required"):
        if flag in rev and not isinstance(rev[flag], bool):
            return "revocation_status_invalid", f"{flag} must be boolean"
    for canonical, alias in (("this_update", "thisUpdate"), ("next_update", "nextUpdate"), ("produced_at", "producedAt"), ("signature_valid", "signatureValid"), ("issuer_binding_valid", "issuerBindingValid")):
        code, _ = _alias(rev, canonical, alias)
        if code:
            return code, f"conflicting aliases: {canonical}/{alias}"
        if canonical not in rev and alias in rev:
            rev[canonical] = rev[alias]
    kind = rev.get("kind")
    if kind not in ("crl", "ocsp"):
        return "revocation_status_invalid", "kind must be crl or ocsp"
    required = ("issuer", "serial", "this_update", "next_update", "signature_valid", "issuer_binding_valid") + (("produced_at", "responder_signature_valid", "chain_valid") if kind == "ocsp" else ("crl_number", "certificate_serial"))
    for key in required:
        if key not in rev or rev[key] in (None, ""):
            return "revocation_status_unavailable", f"revocation receipt field absent: {key}"
    if not isinstance(rev["issuer"], str) or not isinstance(rev["serial"], str):
        return "revocation_status_invalid", "issuer and serial must be strings"
    if rev["signature_valid"] is not True:
        return "certificate_signature_invalid", "revocation receipt signature is invalid"
    if rev["issuer_binding_valid"] is not True:
        return "scope_binding_mismatch", "revocation issuer binding is invalid"
    if kind == "ocsp" and (rev["responder_signature_valid"] is not True or rev["chain_valid"] is not True):
        return "certificate_signature_invalid", "OCSP responder signature chain is invalid"
    this_update, next_update = _dt(rev["this_update"]), _dt(rev["next_update"])
    produced = _dt(rev.get("produced_at")) if kind == "ocsp" else this_update
    if not this_update or not next_update or not produced:
        return "timestamp_invalid", "revocation receipt time invalid"
    try:
        tolerance = _td(skew)
    except ValueError:
        return "timestamp_invalid", "clock skew is non-finite"
    if this_update > next_update or produced > as_of + tolerance or as_of < this_update - tolerance or as_of > next_update + tolerance:
        return "revocation_response_stale", "revocation receipt is stale or outside freshness bounds"
    if kind == "ocsp" and rev.get("nonce_required", False) and not isinstance(rev.get("nonce"), str):
        return "nonce_absent", "OCSP nonce required by profile but absent"
    if kind == "ocsp" and rev.get("nonce") is not None and rev.get("nonce") != receipt_nonce:
        return "nonce_replayed", "OCSP nonce does not bind receipt nonce"
    if rev.get("status") not in ("good", "revoked", "unknown"):
        return "revocation_status_invalid", "status must be good, revoked, or unknown"
    if rev.get("status") == "revoked":
        return "certificate_revoked", "revocation receipt explicitly says revoked"
    if rev.get("status") == "unknown":
        return "revocation_status_unknown", "revocation receipt explicitly says unknown"
    if rev.get("status") != "good":
        return "revocation_status_unavailable", "revocation status absent"
    return None, "good"


def _validate_time(ts: Any, digest: str, receipt: Mapping[str, Any], skew: float) -> tuple[str | None, str, datetime | None]:
    if not isinstance(ts, Mapping):
        return "trusted_time_absent", "trusted time receipt unavailable; OS clock is not used", None
    code, detail = _check_fields(ts, TIME_FIELDS, "$.trusted_time_receipt")
    if code:
        return code, detail, None
    ts = dict(ts)
    if "available" not in ts or not isinstance(ts["available"], bool):
        return "timestamp_invalid", "trusted time available must be boolean", None
    if ts["available"] is False:
        return "trusted_time_absent", "trusted time receipt unavailable; OS clock is not used", None
    for flag in ("available", "signature_valid", "chain_valid", "revocation_valid"):
        if flag in ts and not isinstance(ts[flag], bool):
            return "timestamp_invalid", f"{flag} must be boolean", None
    for canonical, alias in (("gen_time", "genTime"), ("receipt_digest", "receiptDigest"), ("message_imprint", "messageImprint"), ("valid_from", "validFrom"), ("valid_to", "validTo"), ("signature_valid", "signatureValid"), ("chain_valid", "chainValid"), ("revocation_valid", "revocationValid")):
        code, _ = _alias(ts, canonical, alias)
        if code:
            return code, f"conflicting aliases: {canonical}/{alias}", None
        if canonical not in ts and alias in ts:
            ts[canonical] = ts[alias]
    if ts.get("profile") not in ("rfc3161", "equivalent_signed_time"):
        return "timestamp_invalid", "unsupported trusted-time profile", None
    gen = _dt(ts.get("gen_time"))
    if gen is None:
        return "timestamp_invalid", "trusted-time genTime invalid", None
    for name in ("valid_from", "valid_to"):
        if name in ts and _dt(ts[name]) is None:
            return "timestamp_invalid", f"invalid trusted-time {name}", None
    if ts.get("signature_valid") is not True or ts.get("chain_valid") is not True or ts.get("revocation_valid") is not True:
        return "timestamp_invalid", "TSA signature, chain, or revocation is not valid", None
    if ts.get("receipt_digest") != digest or ts.get("message_imprint") != digest:
        return "receipt_digest_mismatch", "timestamp does not bind canonical receipt digest", None
    if ts.get("nonce") not in (None, receipt.get("nonce")) or ts.get("challenge") not in (None, receipt.get("challenge")):
        return "timestamp_invalid", "timestamp nonce/challenge does not bind receipt", None
    if not isinstance(ts.get("policy"), str) or not ts["policy"]:
        return "timestamp_invalid", "trusted-time policy absent", None
    try:
        tolerance = _td(skew)
    except ValueError:
        return "timestamp_invalid", "clock skew is non-finite", None
    valid_from, valid_to = _dt(ts.get("valid_from")), _dt(ts.get("valid_to"))
    if valid_from and gen < valid_from - tolerance or valid_to and gen > valid_to + tolerance:
        return "timestamp_expired", "trusted-time receipt outside validity interval", None
    return None, "trusted", gen


def _empty_state() -> dict[str, Any]:
    return {"nonces": {}, "sequences": {}, "idempotency": {}, "entries": []}


def _state_hash(state: Mapping[str, Any]) -> str:
    return hashlib.sha256(canonical_bytes(state)).hexdigest()


class PersistentReplayLedger:
    """Authenticated durable ledger with lock and atomic compare-and-swap."""
    def __init__(self, path: str | os.PathLike[str], *, key_path: str | os.PathLike[str] | None = None, namespace: str = "UP1-R2", acl_provider: Any | None = None):
        self.path = Path(os.path.abspath(os.fspath(path)))
        self.namespace = namespace
        self.key_path = Path(os.path.abspath(os.fspath(key_path))) if key_path is not None else None
        self.acl_provider = acl_provider
        self.lock_path = self.path.with_name(self.path.name + ".lock")

    @staticmethod
    def _reject_reparse(path: Path, label: str, *, require_regular: bool = False) -> None:
        """Reject symlinks/reparse points and (for key) non-regular files."""
        probe = path
        while True:
            if probe.is_symlink() or os.path.islink(str(probe)):
                raise ReceiptInputError(f"{label} path is a symlink/reparse point", "ledger_corrupt")
            try:
                st = os.stat(str(probe), follow_symlinks=False)
            except FileNotFoundError:
                probe = probe.parent
                if probe == probe.parent:
                    break
                continue
            if getattr(st, "st_file_attributes", 0) & 0x400:
                raise ReceiptInputError(f"{label} path is a reparse point", "ledger_corrupt")
            if probe == path and require_regular and not stat.S_ISREG(st.st_mode):
                raise ReceiptInputError(f"{label} must be a regular file", "ledger_corrupt")
            if probe == probe.parent:
                break
            probe = probe.parent
        if path.exists() and os.path.normcase(os.path.abspath(str(path))) != os.path.normcase(os.path.realpath(str(path))):
            raise ReceiptInputError(f"{label} final path resolves elsewhere", "ledger_corrupt")

    @staticmethod
    def _powershell_acl_provider(path: Path) -> Mapping[str, Any]:
        """Collect Windows owner/DACL/SDDL using the host's PowerShell implementation."""
        # PowerShell 7 is preferred: Windows PowerShell's security module may be
        # unavailable in a non-interactive child; absence is never treated as valid.
        executable = shutil.which("pwsh") or shutil.which("powershell.exe") or shutil.which("powershell")
        if not executable:
            raise ReceiptInputError("Windows ACL verifier unavailable", "trusted_key_acl_unsupported")
        script = r"""
$ErrorActionPreference = 'Stop'
$p = $env:UP1_R2_ACL_PATH
$a = Get-Acl -LiteralPath $p
$owner = [string]$a.Owner
$ownerSid = ''
try { $ownerSid = ([System.Security.Principal.NTAccount]$owner).Translate([System.Security.Principal.SecurityIdentifier]).Value } catch {}
$currentSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$ownerOk = ($ownerSid -eq $currentSid) -or ($ownerSid -eq 'S-1-5-18') -or ($ownerSid -eq 'S-1-5-32-544')
$broad = @('Everyone','NT AUTHORITY\Authenticated Users','BUILTIN\Users','Users','Authenticated Users','BUILTIN\Guests','Guests','INTERACTIVE','LOCAL','NETWORK','S-1-1-0','S-1-5-11','S-1-5-32-545','S-1-5-32-546','S-1-5-4','S-1-2-0','S-1-5-2','S-1-15-2-1','S-1-15-2-2')
$bad = @()
foreach ($r in $a.Access) {
  $id = [string]$r.IdentityReference
  if (($r.AccessControlType -eq 'Allow') -and (($broad -contains $id) -or ($broad -contains $id.ToUpperInvariant()))) {
    $bad += [string]$id
  }
}
$out = [pscustomobject]@{ owner=$owner; owner_sid=$ownerSid; current_sid=$currentSid; owner_ok=$ownerOk; sddl=[string]$a.Sddl; protected=[bool]$a.AreAccessRulesProtected; bad_allow_identities=@($bad); access_rules=@($a.Access | ForEach-Object { [pscustomobject]@{ identity=[string]$_.IdentityReference; type=[string]$_.AccessControlType; inherited=[bool]$_.IsInherited } }) }
$out | ConvertTo-Json -Compress
"""
        try:
            env = os.environ.copy()
            env["UP1_R2_ACL_PATH"] = str(path)
            completed = subprocess.run([executable, "-NoProfile", "-NonInteractive", "-Command", script], capture_output=True, text=True, timeout=10, check=False, env=env)
        except (OSError, subprocess.SubprocessError) as exc:
            raise ReceiptInputError(f"Windows ACL verifier unsupported: {exc}", "trusted_key_acl_unsupported") from exc
        stdout = completed.stdout.strip()
        if not stdout:
            raise ReceiptInputError("Windows ACL verifier returned no result", "trusted_key_acl_unsupported")
        try:
            detail = json.loads(stdout)
        except (TypeError, ValueError, json.JSONDecodeError) as exc:
            raise ReceiptInputError("Windows ACL verifier returned malformed SDDL result", "trusted_key_acl_invalid") from exc
        if completed.returncode != 0:
            raise ReceiptInputError(f"Windows ACL verifier failed: {completed.stderr.strip()}", "trusted_key_acl_unsupported")
        return detail

    @staticmethod
    def _windows_key_acl(path: Path, acl_provider: Any | None = None) -> None:
        if os.name != "nt" and acl_provider is None:
            return
        validate_acl_provider(path, acl_provider or PersistentReplayLedger._powershell_acl_provider)

    def _key(self) -> bytes:
        if self.key_path is None:
            raise ReceiptInputError("explicit trusted ledger key is absent", "replay_ledger_absent")
        self._reject_reparse(self.key_path, "trusted key", require_regular=True)
        if not self.key_path.exists():
            raise ReceiptInputError("explicit trusted ledger key is absent", "replay_ledger_absent")
        try:
            st = self.key_path.stat()
            if hasattr(os, "getuid") and st.st_uid != os.getuid():
                raise ReceiptInputError("trusted key owner mismatch", "ledger_corrupt")
            if os.name == "nt":
                self._windows_key_acl(self.key_path, self.acl_provider)
            elif self.acl_provider is not None:
                self._windows_key_acl(self.key_path, self.acl_provider)
            elif st.st_mode & 0o077:
                raise ReceiptInputError("trusted key permissions are too broad", "ledger_corrupt")
            key = self.key_path.read_bytes()
        except OSError as exc:
            raise ReceiptInputError(f"trusted key unreadable: {exc}", "replay_ledger_absent") from exc
        if len(key) != 32:
            raise ReceiptInputError("ledger authentication key has invalid length", "ledger_corrupt")
        return key

    def _lock(self) -> int:
        self._reject_reparse(self.path, "replay ledger")
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self._reject_reparse(self.lock_path, "replay lock")
        deadline = time.monotonic() + 10.0
        while True:
            try:
                return os.open(self.lock_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            except FileExistsError:
                if time.monotonic() >= deadline:
                    raise TimeoutError("replay ledger lock timeout")
                time.sleep(0.005)

    def _unlock(self, fd: int) -> None:
        os.close(fd)
        try:
            self.lock_path.unlink()
        except FileNotFoundError:
            pass

    def _envelope(self, state: Mapping[str, Any], key: bytes) -> dict[str, Any]:
        base = {"schema": "UP1-R2.replay-ledger.v1", "version": 1, "namespace": self.namespace, "state": state, "state_hash": _state_hash(state)}
        base["auth_tag"] = hmac.new(key, canonical_bytes(base), hashlib.sha256).hexdigest()
        return base

    @staticmethod
    def _check_state(state: Any) -> None:
        if not isinstance(state, Mapping) or set(state) != {"nonces", "sequences", "idempotency", "entries"} or not all(isinstance(state[k], (dict if k != "entries" else list)) for k in state):
            raise ReceiptInputError("replay ledger state shape invalid", "ledger_corrupt")
        nonces: dict[str, list[str]] = {}
        sequences: dict[str, int] = {}
        idem: dict[str, dict[str, str]] = {}
        seen_nonces: set[str] = set()
        seen_idempotency: set[str] = set()
        seen_source_sequence: set[tuple[str, int]] = set()
        if any(not isinstance(scope, str) or not isinstance(values, list) or any(not isinstance(nonce, str) for nonce in values) for scope, values in state["nonces"].items()):
            raise ReceiptInputError("replay ledger nonce index shape invalid", "ledger_corrupt")
        if any(not isinstance(scope, str) or not isinstance(sequence, int) or isinstance(sequence, bool) or sequence < 0 for scope, sequence in state["sequences"].items()):
            raise ReceiptInputError("replay ledger sequence index shape invalid", "ledger_corrupt")
        if any(not isinstance(key, str) or not isinstance(value, Mapping) or set(value) != {"canonical_digest", "result_digest"} or not all(isinstance(value[k], str) for k in ("canonical_digest", "result_digest")) for key, value in state["idempotency"].items()):
            raise ReceiptInputError("replay ledger idempotency index shape invalid", "ledger_corrupt")
        for row in state["entries"]:
            fields = {"scope", "source", "nonce", "sequence", "idempotency_key", "canonical_digest", "result_digest"}
            if not isinstance(row, Mapping) or set(row) != fields or not all(isinstance(row[k], str) for k in ("scope", "source", "nonce", "idempotency_key", "canonical_digest", "result_digest")) or not isinstance(row["sequence"], int) or isinstance(row["sequence"], bool) or row["sequence"] < 0:
                raise ReceiptInputError("replay ledger entry invalid", "ledger_corrupt")
            try:
                scope_obj = json.loads(row["scope"])
            except (TypeError, ValueError, json.JSONDecodeError) as exc:
                raise ReceiptInputError("replay ledger scope is not canonical JSON", "ledger_corrupt") from exc
            if not isinstance(scope_obj, Mapping) or set(scope_obj) != SCOPE_FIELDS or scope_obj.get("source") != row["source"] or not all(isinstance(scope_obj[k], str) and scope_obj[k] for k in SCOPE_FIELDS) or _scope_key(scope_obj) != row["scope"]:
                raise ReceiptInputError("replay ledger scope/source binding invalid", "ledger_corrupt")
            if row["nonce"] in seen_nonces:
                raise ReceiptInputError("duplicate replay ledger nonce", "ledger_corrupt")
            if row["idempotency_key"] in seen_idempotency:
                raise ReceiptInputError("duplicate replay ledger idempotency key", "ledger_corrupt")
            source_sequence = (row["source"], row["sequence"])
            if source_sequence in seen_source_sequence:
                raise ReceiptInputError("duplicate replay ledger source/sequence", "ledger_corrupt")
            if len(row["canonical_digest"]) != 64 or len(row["result_digest"]) != 64 or any(c not in "0123456789abcdef" for c in row["canonical_digest"] + row["result_digest"]):
                raise ReceiptInputError("replay ledger digest invalid", "ledger_corrupt")
            seen_nonces.add(row["nonce"]); seen_idempotency.add(row["idempotency_key"]); seen_source_sequence.add(source_sequence)
            nonces.setdefault(row["scope"], []).append(row["nonce"])
            sequences[row["scope"]] = row["sequence"]
            idem[row["idempotency_key"]] = {"canonical_digest": row["canonical_digest"], "result_digest": row["result_digest"]}
        if state["nonces"] != nonces or state["sequences"] != sequences or state["idempotency"] != idem:
            raise ReceiptInputError("replay ledger indexes disagree with entries", "ledger_corrupt")

    def _read_unlocked(self, key: bytes) -> dict[str, Any]:
        self._reject_reparse(self.path, "replay ledger", require_regular=self.path.exists())
        if not self.path.exists():
            return self._envelope(_empty_state(), key)
        try:
            envelope = parse_json_strict(self.path.read_text(encoding="utf-8"))
        except ReceiptInputError as exc:
            raise ReceiptInputError(f"replay ledger unreadable: {exc}", "ledger_corrupt") from exc
        except (OSError, UnicodeError, json.JSONDecodeError) as exc:
            raise ReceiptInputError(f"replay ledger unreadable: {exc}", "ledger_corrupt") from exc
        fields = {"schema", "version", "namespace", "state", "state_hash", "auth_tag"}
        if not isinstance(envelope, Mapping) or set(envelope) != fields:
            raise ReceiptInputError("replay ledger envelope shape invalid", "ledger_corrupt")
        base = {k: envelope[k] for k in ("schema", "version", "namespace", "state", "state_hash")}
        expected = hmac.new(key, canonical_bytes(base), hashlib.sha256).hexdigest()
        if not isinstance(envelope["auth_tag"], str) or not hmac.compare_digest(envelope["auth_tag"], expected):
            raise ReceiptInputError("replay ledger authentication failed", "ledger_corrupt")
        if envelope["schema"] != "UP1-R2.replay-ledger.v1" or envelope["version"] != 1 or envelope["namespace"] != self.namespace or envelope["state_hash"] != _state_hash(envelope["state"]):
            raise ReceiptInputError("replay ledger integrity hash or binding failed", "ledger_corrupt")
        self._check_state(envelope["state"])
        return dict(envelope)

    def check_and_commit(self, *, scope: str, source: str, nonce: str, sequence: int, key: str, digest: str, result_digest: str) -> tuple[str, dict[str, Any]]:
        lock_fd = self._lock()
        try:
            auth_key = self._key()
            envelope = self._read_unlocked(auth_key)
            state = copy.deepcopy(envelope["state"])
            prior = state["idempotency"].get(key)
            if prior is not None:
                return ("idempotent_replay" if prior.get("canonical_digest") == digest else "idempotency_conflict"), envelope
            for other_scope, values in state["nonces"].items():
                if nonce in values:
                    return ("scope_binding_mismatch" if other_scope != scope else "nonce_replayed"), envelope
            if any(row.get("source") == source and row.get("sequence") == sequence for row in state["entries"]):
                return "sequence_invalid", envelope
            prior_sequence = state["sequences"].get(scope)
            if prior_sequence is not None:
                if sequence <= prior_sequence:
                    return "sequence_invalid", envelope
                if sequence != prior_sequence + 1:
                    return "sequence_gap", envelope
            state["nonces"].setdefault(scope, []).append(nonce)
            state["sequences"][scope] = sequence
            state["idempotency"][key] = {"canonical_digest": digest, "result_digest": result_digest}
            state["entries"].append({"scope": scope, "source": source, "nonce": nonce, "sequence": sequence, "idempotency_key": key, "canonical_digest": digest, "result_digest": result_digest})
            self._check_state(state)
            new_envelope = self._envelope(state, auth_key)
            fd, temp_name = tempfile.mkstemp(prefix=self.path.name + ".", suffix=".tmp", dir=str(self.path.parent), text=True)
            try:
                with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as stream:
                    json.dump(new_envelope, stream, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
                    stream.flush(); os.fsync(stream.fileno())
                os.replace(temp_name, self.path)
            finally:
                if os.path.exists(temp_name):
                    os.unlink(temp_name)
            return "committed", new_envelope
        finally:
            self._unlock(lock_fd)


def validate(payload: Mapping[str, Any], *, ledger: PersistentReplayLedger | None = None) -> dict[str, Any]:
    if not isinstance(payload, Mapping):
        return _error("receipt_type_invalid", "input must be an object")
    unknown = sorted(set(payload) - TOP_FIELDS)
    if unknown:
        return _error("unknown_field", f"unknown field at $: {unknown[0]}")
    if payload.get("schema") != SCHEMA or payload.get("profile") != PROFILE or payload.get("test_only") is not True:
        return _error("signature_profile_unknown", "schema/profile must exactly match TEST_ONLY-W2-R1 and test_only must be bool true")
    receipt = payload.get("receipt")
    digest = canonical_digest(receipt) if receipt is not None else None
    code, detail = _validate_structure(receipt)
    if code:
        return _error(code, detail, digest=digest)
    if payload.get("expected_scope") is not None:
        if not isinstance(payload["expected_scope"], Mapping) or set(payload["expected_scope"]) != SCOPE_FIELDS or not all(isinstance(payload["expected_scope"][k], str) and payload["expected_scope"][k] for k in SCOPE_FIELDS):
            return _error("scope_binding_mismatch", "expected_scope must be {candidate,source} strings", digest=digest)
        if payload["expected_scope"] != receipt["scope"]:
            return _error("scope_binding_mismatch", "receipt scope differs from expected verifier scope", digest=digest)
    if payload.get("expected_source_version") is not None:
        if not isinstance(payload["expected_source_version"], Mapping) or set(payload["expected_source_version"]) != VERSION_FIELDS or not all(isinstance(payload["expected_source_version"][k], str) and payload["expected_source_version"][k] for k in VERSION_FIELDS):
            return _error("source_version_binding_mismatch", "expected_source_version must be {version,hash} strings", digest=digest)
        if payload["expected_source_version"] != receipt["source_version"]:
            return _error("source_version_binding_mismatch", "receipt source version differs from expected binding", digest=digest)
    attestor = payload.get("attestor_signature")
    if attestor is not None:
        code, detail = _check_fields(attestor, ATTESTOR_FIELDS, "$.attestor_signature")
        if code:
            return _error(code, detail, digest=digest)
    if payload.get("receipt_signature_valid") is not True and not (isinstance(attestor, Mapping) and attestor.get("signature_valid") is True):
        return _error("certificate_signature_invalid", "canonical receipt has no valid TEST_ONLY attestor signature", digest=digest)
    skew = payload.get("clock_skew_seconds", 0)
    if not _finite(skew) or float(skew) < 0:
        return _error("timestamp_invalid", "clock skew must be finite and non-negative", digest=digest)
    window = payload.get("replay_window")
    if not isinstance(window, Mapping):
        return _error("replay_window_absent", "replay freshness window unavailable", digest=digest)
    code, detail = _check_fields(window, WINDOW_FIELDS, "$.replay_window")
    if code:
        return _error(code, detail, digest=digest)
    if "duration_seconds" not in window or "trusted_time_basis" not in window:
        return _error("replay_window_absent", "replay window lacks signed-time basis or duration", digest=digest)
    if not _finite(window["duration_seconds"]) or float(window["duration_seconds"]) <= 0 or window["trusted_time_basis"] != "signed_receipt":
        return _error("replay_window_invalid", "replay window duration/basis invalid", digest=digest)
    for name in ("ledger_retention_seconds", "clock_skew_seconds"):
        if name in window and (not _finite(window[name]) or float(window[name]) < 0):
            return _error("replay_window_invalid", f"replay window {name} must be finite and non-negative", digest=digest)
    code, detail, as_of = _validate_time(payload.get("trusted_time_receipt"), digest, receipt, float(skew))
    if code:
        return _error(code, detail, digest=digest)
    assert as_of is not None
    issued, expires = _dt(receipt["issued_at"]), _dt(receipt["expires_at"])
    try:
        tolerance, duration = _td(float(skew)), _td(float(window["duration_seconds"]))
    except ValueError:
        return _error("timestamp_invalid", "time window contains non-finite number", digest=digest)
    if expires < issued:
        return _error("timestamp_invalid", "receipt interval is invalid", digest=digest)
    if issued > as_of + tolerance:
        return _error("timestamp_invalid", "receipt is from the future relative to signed time", digest=digest)
    if expires < as_of - tolerance:
        return _error("timestamp_expired", "receipt expired relative to signed time", digest=digest)
    if (as_of - issued).total_seconds() > duration.total_seconds() + tolerance.total_seconds():
        return _error("replay_window_expired", "receipt is outside replay freshness window", digest=digest)
    code, detail = _validate_revocation(payload.get("revocation_receipt"), as_of, float(skew), receipt["nonce"])
    if code:
        return _error(code, detail, digest=digest)
    if ledger is None:
        return _error("replay_ledger_absent", "durable authenticated replay ledger is required", digest=digest)
    namespace_value = payload.get("ledger_namespace", "UP1-R2")
    if not isinstance(namespace_value, str) or not namespace_value:
        return _error("scope_binding_mismatch", "ledger namespace must be a non-empty string", digest=digest)
    namespace = namespace_value
    if ledger.namespace != namespace:
        return _error("scope_binding_mismatch", "ledger namespace does not match verifier namespace", digest=digest)
    scope = _scope_key(receipt["scope"])
    result_digest = hashlib.sha256(canonical_bytes({"ok": True, "digest": digest})).hexdigest()
    try:
        disposition, envelope = ledger.check_and_commit(scope=scope, source=receipt["source"], nonce=receipt["nonce"], sequence=receipt["sequence"], key=receipt["idempotency_key"], digest=digest, result_digest=result_digest)
    except (OSError, ReceiptInputError, TimeoutError) as exc:
        return _error(getattr(exc, "code", "replay_ledger_invalid"), str(exc), digest=digest)
    if disposition != "committed":
        if disposition == "idempotent_replay":
            return {"schema": SCHEMA, "result": "fail_closed", "status": "replayed", "resolution": "fail_closed", "error_code": "nonce_replayed", "idempotent_replay": True, "canonical_receipt_digest": digest, "claim_ceiling": CLAIM_CEILING, "network_access": False, "trusted_clock_basis": "signed_receipt_only", "replay_ledger": envelope}
        return _error(disposition, f"durable replay ledger rejected receipt: {disposition}", digest=digest, extra={"replay_ledger": envelope})
    return {"schema": SCHEMA, "result": "valid_for_declared_scope", "status": "valid_for_declared_scope", "resolution": "valid_for_declared_scope", "error_code": None, "canonical_receipt_digest": digest, "trusted_as_of": as_of.isoformat().replace("+00:00", "Z"), "revocation": "good", "claim_ceiling": CLAIM_CEILING, "network_access": False, "trusted_clock_basis": "signed_receipt_only", "replay_ledger": envelope}
