"""Deterministic JSON runner for the independent R4 freshness test suite."""
from __future__ import annotations

import contextlib
import hashlib
import io
import json
import pathlib
import sys
import unittest
from datetime import datetime, timezone

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[3]
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(ROOT))

import test_freshness_independent as tests  # noqa: E402


class _RecordingResult(unittest.TextTestResult):
    def __init__(self, stream, descriptions, verbosity):
        super().__init__(stream, descriptions, verbosity)
        self.rows = []

    def addSuccess(self, test):
        super().addSuccess(test)
        self.rows.append({"test": test.id(), "status": "pass"})

    def addSkip(self, test, reason):
        super().addSkip(test, reason)
        self.rows.append({"test": test.id(), "status": "skip", "reason": reason})

    def addFailure(self, test, err):
        super().addFailure(test, err)
        self.rows.append({"test": test.id(), "status": "fail", "error": self._exc_info_to_string(err, test)})

    def addError(self, test, err):
        super().addError(test, err)
        self.rows.append({"test": test.id(), "status": "error", "error": self._exc_info_to_string(err, test)})


class _RecordingRunner(unittest.TextTestRunner):
    resultclass = _RecordingResult


def main() -> int:
    suite = unittest.defaultTestLoader.loadTestsFromModule(tests)
    stream = io.StringIO()
    with contextlib.redirect_stderr(stream), contextlib.redirect_stdout(stream):
        result = _RecordingRunner(stream=stream, verbosity=0).run(suite)
    raw = stream.getvalue().encode("utf-8")
    report = {
        "utc": datetime.now(timezone.utc).isoformat(),
        "pid": __import__("os").getpid(),
        "exit": 0 if result.wasSuccessful() else 1,
        "raw_sha256": hashlib.sha256(raw).hexdigest(),
        "tests": sorted(result.rows, key=lambda row: row["test"]),
        "counts": {"run": result.testsRun, "failures": len(result.failures), "errors": len(result.errors), "skipped": len(result.skipped)},
        "network_access": False,
        "formal_credit": "none",
        "no_publish": True,
        "implementation_frozen": str(tests.SOURCE),
        "raw_output": stream.getvalue(),
    }
    print(json.dumps(report, ensure_ascii=False, sort_keys=True, indent=2))
    return report["exit"]


if __name__ == "__main__":
    raise SystemExit(main())
