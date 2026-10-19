# Root read-only UP4 pin check

Working directory: `D:\006-Programing\LMC\FusionConceptAI`.

Actual command (PowerShell; executed 2026-09-25):

```powershell
& 'D:\Users\Newman\anaconda3\python.exe' -B -c 'import json,hashlib,pathlib; root=pathlib.Path("docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC"); leaf=root/"archive/agent_local_reference_gate_summary_r1_20260925"; pins=json.loads((leaf/"source_pins.json").read_text()); manifest=json.loads((leaf/"archive_manifest.json").read_text()); items=[(root/x["path"],x["sha256"],None) for x in pins["prior_evidence"]]+[(leaf/x["path"],x["sha256"],x["bytes"]) for x in manifest["payloads"]]; bad=[str(p) for p,h,n in items if not p.is_file() or hashlib.sha256(p.read_bytes()).hexdigest()!=h or (n is not None and p.stat().st_size!=n)]; print("source_payload_pins",len(items),"bad",len(bad)); print(*bad,sep="\n"); raise SystemExit(bool(bad))'; exit $LASTEXITCODE
```

Actual stdout: `source_payload_pins 7 bad 0`. Shell exit code: **0**. This verifies five prior evidence hashes and two payload hashes/byte counts only. It starts no inverse, likelihood, Julia or FreeGS consumer and does not change `typed_absent`.
