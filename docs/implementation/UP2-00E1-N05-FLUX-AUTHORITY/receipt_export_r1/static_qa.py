import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    failures = []
    frozen = {
        "src/GenomeV5/UP2/N05FluxAuthorityProjectionV1.jl": "3697d0db47adb339d7ae11cced4c4cc2eed1e1bc2f8b314c3001d479fae0c9df",
        "test/GenomeV5/UP2/n05_flux_authority_tests.jl": "57b83ca321cf61b284656cd238356943b2521b4d80029e8a8424706117d42543",
        "test/GenomeV5/UP2/n05_flux_authority_fixtures.json": "049fcc585f97245a745737733dd9aae6904e80b4cc09067dbc37a9528ab81d81",
        "test/GenomeV5/UP2/run_n05_flux_authority.jl": "3d51de1a65d6c48afae0aa57877d63c29600d061799f324fcf48a436b8cebca3",
    }
    for rel, expected in frozen.items():
        if digest(ROOT / rel) != expected:
            failures.append("frozen_input_changed:" + rel)
    owned = [
        ROOT / "test/GenomeV5/UP2/n05_flux_receipt_exporter.jl",
        ROOT / "test/GenomeV5/UP2/n05_flux_receipt_checker.jl",
        ROOT / "test/GenomeV5/UP2/n05_flux_receipt_export_tests.jl",
        ROOT / "test/GenomeV5/UP2/run_n05_flux_receipt_export.jl",
    ]
    texts = {str(p): p.read_text(encoding="utf-8") for p in owned}
    joined = "\n".join(texts.values())
    for token in ("N05_RECEIPT_EXPORT_SCHEMA_V1", "original_value_hash", "attempted_value_hash",
                  "mutation_hash", "terminal_deferred", "invalid_closure", "invalid_type",
                  "expected_error", "compile_calls", "provider_calls", "solver_calls"):
        if token not in joined:
            failures.append("missing_token:" + token)
    if "expected_error" in texts[str(owned[1])]:
        failures.append("checker_reads_expected_error")
    if "spec.id" in texts[str(owned[0])]:
        failures.append("exporter_routes_by_spec_id")
    for path in list(OUT.glob("*.json")):
        try:
            json.loads(path.read_text(encoding="utf-8"))
        except Exception as exc:
            failures.append("json:" + path.name + ":" + type(exc).__name__)
    for path in list(OUT.glob("*")) + owned:
        if path.is_file():
            text = path.read_text(encoding="utf-8")
            if any(ord(ch) < 32 and ord(ch) not in (9, 10, 13) for ch in text):
                failures.append("control:" + str(path))
    result = {
        "work_order": "UP2-00E1-N05-FLUX-AUTHORITY-receipt-export-r1",
        "runtime": {"julia": "not run", "desc": "not run", "process_sweep": []},
        "frozen_inputs": {rel: {"sha256": digest(ROOT / rel), "bytes": (ROOT / rel).stat().st_size}
                          for rel in frozen},
        "owned_files": {str(p.relative_to(ROOT)): {"sha256": digest(p), "bytes": p.stat().st_size}
                        for p in owned},
        "checks": {"frozen_inputs": not any(x.startswith("frozen_input") for x in failures),
                    "json_parse": not any(x.startswith("json:") for x in failures),
                    "control_scan": not any(x.startswith("control:") for x in failures),
                    "contract_tokens": not any(x.startswith("missing_token") for x in failures),
                    "no_fixture_routing": not any(x in failures for x in ("checker_reads_expected_error", "exporter_routes_by_spec_id"))},
        "failures": failures,
        "status": "pass_static_preparation" if not failures else "changes_requested",
        "claim_ceiling": "schema_validation_only; no runtime or physical evidence",
    }
    (OUT / "static_qa.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, indent=2))
    raise SystemExit(1 if failures else 0)

if __name__ == "__main__":
    main()
