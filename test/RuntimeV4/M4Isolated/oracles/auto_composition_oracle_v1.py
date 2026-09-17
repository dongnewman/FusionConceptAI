"""Independent standard-library oracle for the M5-A manufactured fixture.

The oracle deliberately does not import Julia, FusionConceptAI, or any project
module.  It rebuilds the canonical manifest, typed-port ledger, owner joins,
and frozen A-D source identities, then checks the same typed rejection classes
used by the isolated Julia lane.
"""

from copy import deepcopy
import hashlib
import json


FROZEN_SOURCE_HASHES = {
    "A": "0b456dcc0df3bd13a1941aa502a9cc5347912b2fa86cda6c65900449299b8e57",
    "B": "0445ec58f35ebbf5e34ae032611befab7050a0a65d2a376ccd37b71a0e9a936c",
    "C": "20804bafb5d42152d220a1d25897f6b460c7056b0c695dbaa5153c0d113710fa",
    "D": "ec7e82e282f1d1292ddd4b7902e4ced641d926af82119298267011d304a55785",
}
FROZEN_D_TEST = "1eb0e26e79b9899cc5a3cb2742545cbaa811fa6683fdcfa1ee4dd31dff081686"
FROZEN_D_ORACLE = "9ca3c1c012690c7c06579d0ab5ffd274666e340c900c59e49f7a93408a0fcbe3"


def stage_identity(stage, source_hash):
    return hashlib.sha256(f"M5A|{stage}|{source_hash}".encode()).hexdigest()


def canonical_bytes(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()


def canonical_hash(value):
    return hashlib.sha256(canonical_bytes(value)).hexdigest()


def make_manifest():
    owner = "M4-A-equation-balance"
    interface_owner = owner
    source_owner = "M4-A-manufactured-source"
    ports = [
        {"stage": "A", "id": "A.u", "side": "input", "index": 1, "unit": "1"},
        {"stage": "A", "id": "A.K", "side": "input", "index": 2, "unit": "m^2"},
        {"stage": "A", "id": "A.f", "side": "input", "index": 3, "unit": "1"},
        {"stage": "A", "id": "A.residual", "side": "output", "index": 1, "unit": "1"},
        {"stage": "B", "id": "B.residual", "side": "output", "index": 1, "unit": "1"},
        {"stage": "C", "id": "C.control", "side": "output", "index": 1, "unit": "1"},
        {"stage": "D", "id": "D.solution", "side": "output", "index": 1, "unit": "1"},
    ]
    for p in ports:
        p.update({
            "physical_type": {"value_kind": "scalar_field", "tensor_rank": 0, "spatial_dimension": 3},
            "domain_id": "Omega", "equation_id": "M4-MANUFACTURED-DIFFUSION-V1",
            "source_id": "f", "conservation_owner": owner,
            "interface_owner": interface_owner, "source_owner": source_owner,
        })
    stage_specs = (
        ("A", "M5 A manufactured equation", "M5-A", ("A.u", "A.K", "A.f"), ("A.residual",)),
        ("B", "M5 B manufactured residual lowering", "M5-B", ("A.residual",), ("B.residual",)),
        ("C", "M5 C manufactured discrete control", "M5-C", ("B.residual",), ("C.control",)),
        ("D", "M5 D manufactured coupled solve", "M5-D", ("C.control",), ("D.solution",)),
    )
    stages = []
    for stage, label, edge_id, inputs, outputs in stage_specs:
        stages.append({
            "stage": stage, "label": label, "edge_id": edge_id,
            "inputs": inputs, "outputs": outputs,
            "domain_id": "Omega", "equation_id": "M4-MANUFACTURED-DIFFUSION-V1", "source_id": "f",
            "conservation_owner": owner, "interface_owner": interface_owner, "source_owner": source_owner,
            "source_sha256": FROZEN_SOURCE_HASHES[stage],
            "typed_identity": stage_identity(stage, FROZEN_SOURCE_HASHES[stage]),
        })
    joins = [
        {"from": "A.residual", "to": "B.residual", "interface_owner": interface_owner},
        {"from": "B.residual", "to": "C.control", "interface_owner": interface_owner},
        {"from": "C.control", "to": "D.solution", "interface_owner": interface_owner},
    ]
    return {
        "schema": "M5-A-MANUFACTURED-AUTO-COMPOSITION-V1",
        "claim_ceiling": "manufactured_auto_composition", "evidence_scope": "screen_only",
        "stages": stages, "ports": ports, "owner_interface_joins": joins,
        "source_hashes": FROZEN_SOURCE_HASHES.copy(),
        "typed_identities": {k: stage_identity(k, v) for k, v in FROZEN_SOURCE_HASHES.items()},
        "d_test_sha256": FROZEN_D_TEST, "d_oracle_sha256": FROZEN_D_ORACLE,
    }


def normalize(manifest):
    out = deepcopy(manifest)
    out["stages"] = sorted(out["stages"], key=lambda x: x["stage"])
    out["ports"] = sorted(out["ports"], key=lambda x: x["id"])
    out["owner_interface_joins"] = sorted(out["owner_interface_joins"], key=lambda x: (x["from"], x["to"]))
    return out


def reject(manifest, provider_drop=False):
    if provider_drop:
        return {"status": "terminal_deferred", "code": "provider_drop", "provider_constructed": False}
    if manifest["source_hashes"] != FROZEN_SOURCE_HASHES:
        return {"status": "typed_failure", "code": "foreign_hash"}
    if manifest["typed_identities"] != {k: stage_identity(k, v) for k, v in FROZEN_SOURCE_HASHES.items()}:
        return {"status": "typed_failure", "code": "foreign_identity"}
    for p in manifest["ports"]:
        if p["unit"] not in ("1", "m^2"):
            return {"status": "typed_failure", "code": "unit_mismatch"}
        if p["id"] not in {"A.u", "A.K", "A.f", "A.residual", "B.residual", "C.control", "D.solution"}:
            return {"status": "typed_failure", "code": "port_mismatch"}
        if p["conservation_owner"] != "M4-A-equation-balance" or p["interface_owner"] != "M4-A-equation-balance":
            return {"status": "typed_failure", "code": "owner_mismatch"}
    return {"status": "valid", "code": None}


def main():
    manifest = make_manifest()
    normalized = normalize(manifest)
    permuted = deepcopy(manifest)
    permuted["stages"] = list(reversed(permuted["stages"]))
    permuted["ports"] = [permuted["ports"][6], permuted["ports"][1], permuted["ports"][3], permuted["ports"][0], permuted["ports"][5], permuted["ports"][2], permuted["ports"][4]]
    permuted["owner_interface_joins"] = list(reversed(permuted["owner_interface_joins"]))
    assert reject(manifest)["status"] == "valid"
    assert canonical_hash(normalized) == canonical_hash(normalize(permuted))
    assert all(stage_identity(k, v) == manifest["typed_identities"][k] for k, v in FROZEN_SOURCE_HASHES.items())

    cases = {}
    for name, code, mutate in (
        ("invalid_unit", "unit_mismatch", lambda x: x["ports"][0].__setitem__("unit", "kg")),
        ("invalid_port", "port_mismatch", lambda x: x["ports"][0].__setitem__("id", "A.foreign")),
        ("invalid_owner", "owner_mismatch", lambda x: x["ports"][0].__setitem__("interface_owner", "foreign")),
        ("foreign_hash", "foreign_hash", lambda x: x["source_hashes"].__setitem__("A", "foreign")),
        ("foreign_identity", "foreign_identity", lambda x: x["typed_identities"].__setitem__("A", "foreign")),
    ):
        bad = deepcopy(manifest)
        mutate(bad)
        got = reject(bad)
        assert got["status"] == "typed_failure" and got["code"] == code
        cases[name] = got
    cases["provider_drop"] = reject(manifest, provider_drop=True)
    assert cases["provider_drop"]["status"] == "terminal_deferred"
    assert not cases["provider_drop"]["provider_constructed"]

    payload = {
        "schema": "M5-A-INDEPENDENT-AUTO-COMPOSITION-ORACLE-V1",
        "source_hashes": FROZEN_SOURCE_HASHES,
        "d_test_sha256": FROZEN_D_TEST, "d_oracle_sha256": FROZEN_D_ORACLE,
        "stage_count": len(manifest["stages"]), "port_count": len(manifest["ports"]),
        "owner_interface_join_count": len(manifest["owner_interface_joins"]),
        "canonical_hash": canonical_hash(normalized),
        "permuted_canonical_hash": canonical_hash(normalize(permuted)),
        "typed_identities": manifest["typed_identities"], "invalid_cases": cases,
        "status": "pass", "claim_ceiling": "manufactured_auto_composition/screen_only",
    }
    print(json.dumps(payload, sort_keys=True, separators=(",", ":")))


if __name__ == "__main__":
    main()
