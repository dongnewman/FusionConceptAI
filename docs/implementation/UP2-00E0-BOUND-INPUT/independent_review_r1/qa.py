from pathlib import Path
import json
arc=Path(__file__).parent
json_results={}
for p in sorted(arc.rglob("*.json")):
    try:
        json.loads(p.read_text(encoding="utf-8"))
        json_results[str(p.relative_to(arc))]={"parse":"pass"}
    except Exception as e:
        json_results[str(p.relative_to(arc))]={"parse":"fail","error":repr(e)}
bad={}
for p in sorted(arc.rglob("*")):
    if p.is_file():
        data=p.read_bytes()
        codes=sorted({b for b in data if b < 32 and b not in (9,10,13)})
        if codes: bad[str(p.relative_to(arc))]=codes
result={"record_kind":"UP2-00E0-R1-archive-qa","json_parse_exit":0 if all(v["parse"]=="pass" for v in json_results.values()) else 1,"json_files":json_results,"control_scan_exit":0 if not bad else 1,"bad_controls":bad,"note":"git diff --check is recorded separately; no Julia/DESC run."}
(arc/"qa.json").write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print(json.dumps(result,ensure_ascii=False,indent=2))
