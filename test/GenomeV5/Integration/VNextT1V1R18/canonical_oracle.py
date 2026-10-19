"""Independent Python byte-level oracle for the unchanged V1 canonical shape."""
from pathlib import Path
import hashlib
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[4]
evidence = ROOT / sys.argv[1]
log = (evidence / "stdout.raw").read_text(encoding="utf-8")
match = re.search(r"CANONICAL_KERNEL_LARGE length=(\d+) canonical_length=(\d+) seconds=(\S+) canonical_sha256=([0-9a-f]{64}) byte_sha256=([0-9a-f]{64})", log)
assert match, "large canonical result missing"
n, reported_length = map(int, match.group(1, 2))
assert n == 8_269_445
q, r = divmod(n, 251)
data = bytes(range(251)) * q + bytes(range(r))
byte_sha = hashlib.sha256(data).hexdigest()
cycle = b",".join(str(i).encode() for i in range(251))
body = (cycle + b",") * q + b",".join(str(i).encode() for i in range(r))
if r == 0:
    body = body[:-1]
canonical = b'{"bytes":[' + body + b'],"sha256":{"value":"' + byte_sha.encode() + b'"}}'
canonical_sha = hashlib.sha256(canonical).hexdigest()
assert len(canonical) == reported_length, (len(canonical), reported_length)
assert canonical_sha == match.group(4), (canonical_sha, match.group(4))
assert byte_sha == match.group(5), (byte_sha, match.group(5))
receipt = {"verdict": "pass", "input_bytes": n, "canonical_bytes": len(canonical),
           "byte_sha256": byte_sha, "canonical_sha256": canonical_sha,
           "implementation": "Python decimal-byte JSON construction and hashlib SHA256",
           "source_log_sha256": hashlib.sha256((evidence / "stdout.raw").read_bytes()).hexdigest()}
with (evidence / "independent_python_oracle.json").open("x", encoding="utf-8") as f:
    json.dump(receipt, f, indent=2)
print(json.dumps(receipt))
