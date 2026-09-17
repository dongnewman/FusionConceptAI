"""Independent static and fail-closed probes for the frozen R4 verifier."""

from __future__ import annotations

import ast
import json
import socket
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
COMPONENT = ROOT / "tools" / "up1_external_closure_r4" / "trust_chain" / "verifier.py"
TEST = ROOT / "test" / "up1_external_closure_r4" / "trust_chain" / "test_trust_chain_independent.py"
sys.path.insert(0, str(ROOT))
from tools.up1_external_closure_r4.trust_chain import verifier  # noqa: E402


def main() -> int:
    source = COMPONENT.read_text(encoding="utf-8")
    tree = ast.parse(source)
    imports: set[str] = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            imports.update(alias.name.split(".")[0] for alias in node.names)
        elif isinstance(node, ast.ImportFrom) and node.module:
            imports.add(node.module.split(".")[0])

    forbidden = {"socket", "ssl", "urllib", "requests", "httpx", "certifi", "subprocess"}
    assert not imports & forbidden, sorted(imports & forbidden)
    assert "datetime.now" not in source
    assert "datetime.utcnow" not in source
    assert "time.time" not in source
    assert "load_default_certs" not in source
    assert "create_default_context" not in source
    assert "urlopen" not in source
    assert "EVALUATION_TIME_ABSENT" in source

    old_connect = socket.create_connection
    old_socket = socket.socket
    def blocked(*args, **kwargs):
        raise AssertionError("network used")
    socket.create_connection = blocked
    try:
        result = verifier.verify_request({})
    finally:
        socket.create_connection = old_connect
        socket.socket = old_socket
    assert result["status"] == "typed_absence", result
    assert result["error_code"] == "EVALUATION_TIME_ABSENT", result
    assert result["no_publish"] is True and result["authoritative"] is False, result

    explicit_none = verifier.verify_request({"evaluation_time": None})
    assert explicit_none["status"] == "typed_absence", explicit_none
    assert explicit_none["error_code"] == "EVALUATION_TIME_ABSENT", explicit_none

    test_source = TEST.read_text(encoding="utf-8")
    required_vectors = {
        "der_and_pem": "test_der_and_pem_hash_raw_bytes_but_share_der_identity",
        "root_pin": "test_root_pin_is_required_and_exact_raw_bytes",
        "chain": "test_order_issuer_and_certificate_signature_are_checked",
        "algorithm": "test_algorithm_downgrade_and_weak_key_are_rejected",
        "detached": "test_detached_signature_is_checked_without_granting_authority",
        "test_only": "test_test_only_is_non_evidence_and_never_authoritative",
    }
    for label, marker in required_vectors.items():
        assert marker in test_source, label

    print(json.dumps({
        "static_imports": sorted(imports),
        "forbidden_imports": [],
        "wall_clock_fallback_literals": [],
        "missing_evaluation_time": {"status": result["status"], "error_code": result["error_code"], "no_publish": result["no_publish"]},
        "explicit_none_evaluation_time": {"status": explicit_none["status"], "error_code": explicit_none["error_code"]},
        "required_regression_vectors": required_vectors,
        "decision": "PASS",
    }, sort_keys=True, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
