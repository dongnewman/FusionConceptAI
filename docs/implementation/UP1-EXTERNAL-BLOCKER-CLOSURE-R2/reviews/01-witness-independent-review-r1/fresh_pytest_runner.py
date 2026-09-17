from __future__ import annotations

import os
import subprocess
import sys
from datetime import datetime, timezone

started = datetime.now(timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z")
child = subprocess.Popen(
    [sys.executable, "-B", "-m", "pytest", "-q", "test/up1_external_closure_r2/witness_authority/test_witness_authority.py"],
    text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
)
child_stdout, child_stderr = child.communicate()
ended = datetime.now(timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z")
print(f"REVIEWER_PID={os.getpid()}")
print(f"CHILD_PID={child.pid}")
print(f"UTC_STARTED={started}")
print(f"UTC_ENDED={ended}")
print(f"EXIT={child.returncode}")
print("STDOUT_BEGIN")
print(child_stdout, end="")
print("STDOUT_END")
print("STDERR_BEGIN")
print(child_stderr, end="")
print("STDERR_END")
raise SystemExit(child.returncode)
