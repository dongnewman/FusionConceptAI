from pathlib import Path
import json,hashlib
arc=Path(__file__).parent
p=json.loads((arc/"adversarial_control_precheck_false.json").read_text(encoding="utf-8"))
p["record_kind"]="UP2-00E0-R3-static-control-precheck-failure"
(arc/"adversarial_control_precheck_false.json").write_text(json.dumps(p,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
