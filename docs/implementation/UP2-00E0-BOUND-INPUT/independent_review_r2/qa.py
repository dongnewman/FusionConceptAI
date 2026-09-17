from pathlib import Path
import json,hashlib
arc=Path(__file__).parent
bad={}
for p in sorted(arc.rglob("*.json")):
    try: json.loads(p.read_text(encoding="utf-8"))
    except Exception as e: bad[str(p.relative_to(arc))]=["json_parse",repr(e)]
for p in sorted(arc.rglob("*")):
    if p.is_file():
        codes=sorted({b for b in p.read_bytes() if b<32 and b not in (9,10,13)})
        if codes: bad[str(p.relative_to(arc))]=codes
result={"record_kind":"UP2-00E0-r8-precheck-qa","json_parse_exit":0 if not any("json_parse" in v for v in bad.values()) else 1,"control_scan_exit":0 if not bad else 1,"bad":bad,"julia":"not_executed"}
(arc/"qa.json").write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print(json.dumps(result,ensure_ascii=False,indent=2))
