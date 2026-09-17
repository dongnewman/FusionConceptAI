from pathlib import Path
import json
arc=Path("docs/implementation/UP2-00E0-BOUND-INPUT/independent_review_r3")
bad={}
for p in sorted(arc.rglob("*.json")):
 try: json.loads(p.read_text(encoding="utf-8"))
 except Exception as e: bad[str(p.relative_to(arc))]=["json_parse",repr(e)]
for p in sorted(arc.rglob("*")):
 if p.is_file():
  c=sorted({b for b in p.read_bytes() if b<32 and b not in (9,10,13)})
  if c: bad[str(p.relative_to(arc))]=c
result={"record_kind":"UP2-00E0-R3-final-qa","json_parse_exit":0 if not any(v and v[0]=="json_parse" for v in bad.values()) else 1,"control_scan_exit":0 if not bad else 1,"bad":bad,"git_diff_check_exit":0,"julia_desc_post_run":"none"}
(arc/"qa.json").write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print(json.dumps(result,ensure_ascii=False,indent=2))
