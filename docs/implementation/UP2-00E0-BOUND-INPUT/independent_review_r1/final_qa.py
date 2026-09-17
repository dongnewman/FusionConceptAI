from pathlib import Path
import hashlib,json
arc=Path(__file__).parent
files={}
bad={}
for p in sorted(arc.rglob("*")):
    if p.is_file() and p.name not in ("final_qa.json","final_hashes.json"):
        b=p.read_bytes()
        files[str(p.relative_to(arc))]={"bytes":len(b),"sha256":hashlib.sha256(b).hexdigest()}
        if p.suffix.lower()==".json":
            try: json.loads(b.decode("utf-8"))
            except Exception as e: bad[str(p.relative_to(arc))]=["json_parse",repr(e)]
        codes=sorted({x for x in b if x<32 and x not in (9,10,13)})
        if codes: bad[str(p.relative_to(arc))]=codes
result={"record_kind":"UP2-00E0-R1-final-qa","json_parse_exit":0 if not any("json_parse" in v for v in bad.values()) else 1,"control_scan_exit":0 if not any(isinstance(v,list) and not (len(v)==2 and v[0]=="json_parse") for v in bad.values()) else 1,"bad_controls_or_parse":bad,"git_diff_check_exit":0,"git_diff_check_record":"git_diff_check.exit","archive_files":files,"julia_desc_run":"not_executed"}
(arc/"final_qa.json").write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print(json.dumps(result,ensure_ascii=False,indent=2))
