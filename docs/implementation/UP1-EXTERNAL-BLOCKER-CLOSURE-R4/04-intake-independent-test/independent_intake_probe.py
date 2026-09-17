"""Independent, read-only adversarial probe for the frozen R4 intake code.

This is intentionally separate from the focused unittest module.  It emits a
small JSON receipt and exits non-zero on any security-boundary failure.  The
probe never sends bytes, contacts an endpoint, or writes outside a temporary
spool.
"""
from __future__ import annotations

import hashlib
import json
import os
import socket
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT))

from tools.up1_external_closure_r4.authoritative_intake import (
    AuthorityIntake,
    IntakeError,
    atomic_quarantine,
)
from tools.up1_external_closure_r4.authoritative_intake import intake as intake_impl


def digest(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def identity(channel: str = "channel-r4", real: bool = True) -> dict[str, object]:
    return {"channel_id": channel, "owner_id": "owner-r4", "transport": "offline-spool", "endpoint": "local-only://r4", "real_channel": real}


def policy(channel: str = "channel-r4", required: tuple[str, ...] = (), signature: bool = False) -> dict[str, object]:
    return {"channel_id": channel, "required_packet_ids": list(required), "max_packet_count": 8, "max_packet_bytes": 4096, "require_signature": signature}


def packet(packet_id: str, value: str = "r4") -> bytes:
    return (f'{{"packet_id":"{packet_id}","value":"{value}"}}').encode()


def record(name: str, passed: bool, observed: object, expected: object, **extra: object) -> dict[str, object]:
    return {"name": name, "pass": passed, "observed": observed, "expected": expected, **extra}


def main() -> int:
    rows: list[dict[str, object]] = []

    with tempfile.TemporaryDirectory(prefix="up1-r4-intake-") as td:
        try:
            AuthorityIntake(td, identity("a"), policy("b"))
            observed = "constructed"
        except IntakeError as exc:
            observed = exc.code
        rows.append(record("channel_identity_policy_mismatch", observed == "channel_identity_policy_mismatch", observed, "channel_identity_policy_mismatch"))

        absent = AuthorityIntake(Path(td) / "absent").receive(packet("EHP-01"))
        rows.append(record("typed_absent_without_channel_config", absent["authority_status"] == "typed_absent", absent["authority_status"], "typed_absent", decision=absent["decision"]))

        unverified = AuthorityIntake(Path(td) / "unverified", identity(), policy(signature=True), signature_verifier=lambda _raw, _sig: True).receive(packet("EHP-01"), signature={"local": "sig"})
        rows.append(record("typed_unverified_even_local_signature_passes", unverified["authority_status"] == "typed_unverified" and not unverified["receipt"]["authority_claim"], {"status": unverified["authority_status"], "authority_claim": unverified["receipt"]["authority_claim"]}, {"status": "typed_unverified", "authority_claim": False}))

        raw = b'{"packet_id":"EHP-01","value":"\xe4\xb8\xad"}\r\n'
        exact = atomic_quarantine(raw, Path(td) / "exact")
        target = Path(td) / "exact" / exact["quarantine_locator"]
        expected_meta = {"sha256": digest(raw), "size": len(raw), "bytes_equal": target.read_bytes() == raw, "locator": exact["quarantine_locator"]}
        expected_exact = {"sha256": digest(raw), "size": len(raw), "bytes_equal": True, "locator": "quarantine/" + digest(raw) + ".bin"}
        rows.append(record("raw_bytes_hash_size_locator", expected_meta == expected_exact, expected_meta, expected_exact))

        replay_a = atomic_quarantine(raw, Path(td) / "replay")
        replay_b = atomic_quarantine(raw, Path(td) / "replay")
        rows.append(record("equal_byte_replay_idempotence", replay_a == replay_b, {"first": replay_a, "second": replay_b}, "identical metadata"))

        collision_root = Path(td) / "collision"
        collision_target = collision_root / "quarantine" / f"{digest(raw)}.bin"
        collision_target.parent.mkdir(parents=True)
        collision_target.write_bytes(b"different")
        try:
            atomic_quarantine(raw, collision_root)
            collision_observed = "accepted"
        except IntakeError as exc:
            collision_observed = exc.code
        rows.append(record("different_byte_collision_fail_closed", collision_observed == "immutable_collision", collision_observed, "immutable_collision", target_unchanged=collision_target.read_bytes() == b"different"))

        hard_root = Path(td) / "hardlink"
        hard_raw = packet("EHP-01", "hardlink")
        hard_source = hard_root / "outside.bin"
        hard_target = hard_root / "quarantine" / f"{digest(hard_raw)}.bin"
        hard_target.parent.mkdir(parents=True)
        hard_source.write_bytes(hard_raw)
        try:
            os.link(hard_source, hard_target)
        except (OSError, NotImplementedError) as exc:
            rows.append(record("hardlink_digest_alias_rejected", "SKIP", "hardlink unavailable", "immutable_collision or reparse_path", reason=str(exc)))
        else:
            try:
                atomic_quarantine(hard_raw, hard_root)
                hard_observed = "accepted"
            except IntakeError as exc:
                hard_observed = exc.code
            rows.append(record("hardlink_digest_alias_rejected", hard_observed in {"immutable_collision", "reparse_path"}, hard_observed, "immutable_collision or reparse_path", samefile=os.path.samefile(hard_source, hard_target)))

        traversal_root = Path(td) / "traversal" / "spool"
        traversal_root.mkdir(parents=True)
        escaped = traversal_root / ".." / "escape"
        try:
            try:
                intake_impl._ensure_regular_parent(escaped, traversal_root)
                traversal_observed = "accepted"
            except IntakeError as exc:
                traversal_observed = exc.code
            rows.append(record("path_traversal_component_rejected", traversal_observed == "path_escape", traversal_observed, "path_escape", outside_created=(Path(td) / "traversal" / "escape").exists()))
        finally:
            created = Path(td) / "traversal" / "escape"
            if created.is_dir() and not created.is_symlink():
                created.rmdir()

        set_root = Path(td) / "set"
        mixed = AuthorityIntake(set_root, identity(), policy(required=("EHP-01", "EHP-03"))).receive_packet_set([("EHP-01", packet("EHP-01")), ("EHP-02", packet("EHP-02"))], request_id="set-r4")
        rows.append(record("all_or_reject_no_partial_ack", mixed["decision"] == "rejected_all" and not mixed["ack"]["authority_claim"] and not mixed["ack"]["external_ack_sent"] and len(mixed["quarantine"]) == 2, {"decision": mixed["decision"], "authority_claim": mixed["ack"]["authority_claim"], "external_ack_sent": mixed["ack"]["external_ack_sent"], "quarantine_count": len(mixed["quarantine"])}, {"decision": "rejected_all", "authority_claim": False, "external_ack_sent": False, "quarantine_count": 2}))

        net_root = Path(td) / "network"
        net = AuthorityIntake(net_root, identity(), policy()).receive(packet("EHP-01"))
        with mock.patch.object(socket, "socket", side_effect=AssertionError("network attempted")):
            net = AuthorityIntake(net_root / "patched", identity(), policy()).receive(packet("EHP-01"))
        rows.append(record("no_external_send_or_authority_claim", not net["receipt"]["authority_claim"] and net["receipt"]["no_network_or_message_sent"] and not net["receipt"]["transport_receipt"]["external_ack"], {"authority_claim": net["receipt"]["authority_claim"], "no_network_or_message_sent": net["receipt"]["no_network_or_message_sent"], "external_ack": net["receipt"]["transport_receipt"]["external_ack"]}, {"authority_claim": False, "no_network_or_message_sent": True, "external_ack": False}))

    output = {"schema": "UP1.authoritative-intake-r4.independent-probe.v1", "pid": os.getpid(), "utc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"), "records": rows, "pass_count": sum(bool(row["pass"]) for row in rows), "record_count": len(rows)}
    print(json.dumps(output, ensure_ascii=True, sort_keys=True, indent=2))
    return 0 if output["pass_count"] == output["record_count"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
