"""Focused process-generation regression for the R29 Gridap consumer."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import run_native_g1g2_gridap_consumer_r29_v1 as r29
import test_native_g1g2_gridap_consumer_r28_v1 as fixture_support


# Reuse the existing deterministic R28 process-table and stage fixtures while
# exercising only the R29 recovery implementation.
fixture_support.r28 = r29


class _ReusedParentDisappearsTable(fixture_support._R28OrphanChainTable):
    """B exits; B' briefly reuses B's PID; C keeps the stale PPID after B' exits."""

    def __init__(self) -> None:
        super().__init__()
        self.new_child = (742, self.tracked_child[1] + 2)
        self.grandchild = (743, self.tracked_child[1] + 3)
        self.replacement_parent = (self.tracked_child[0], self.tracked_child[1] + 1)
        self.exit_codes[self.new_child] = 0
        self.exit_codes[self.grandchild] = 0
        self.history: list[dict[str, object]] = []

    def query_native_process_table(self) -> fixture_support._R28Snapshot:
        self.snapshot_calls += 1
        n = self.snapshot_calls
        rows: list[fixture_support._R28Row] = []
        if n == 1:
            pass  # prelaunch inventory
        elif n == 2:
            rows = [self._row(self.root_identity, 1, "julia.exe")]
        elif n in (3, 4):
            rows = [self._row(self.root_identity, 1, "julia.exe"),
                    self._row(self.tracked_child, self.root_identity[0], "tracked-helper.exe")]
        else:
            if self.root_identity not in self.exited:
                rows.append(self._row(self.root_identity, 1, "julia.exe"))
            # The failed sample and the subsequent recovery view both retain
            # C's stale PPID=B. B' exists only in the natural-exit receipt view.
            if self.new_child not in self.exited:
                rows.append(self._row(self.new_child, self.tracked_child[0], "git.exe"))
            if self.grandchild not in self.exited:
                rows.append(self._row(self.grandchild, self.new_child[0], "orphan-helper.exe"))
            if n == 6 and self.replacement_parent not in self.exited:
                rows.append(self._row(self.replacement_parent, self.root_identity[0], "reused-helper.exe"))
        rows.sort(key=lambda row: row.identity.pid)
        self.history.append({
            "snapshot_index": n,
            "rows": [{"pid": row.identity.pid,
                      "create_time_100ns": row.identity.create_time_100ns,
                      "ppid": row.ppid,
                      "name": row.name}
                     for row in rows],
        })
        return fixture_support._R28Snapshot(rows)


class R29NaturalExitPidReuseTests(unittest.TestCase):
    def _run_stage(self, table: _ReusedParentDisappearsTable) -> tuple[dict, object, list[dict]]:
        audit = fixture_support._R28OrphanChainAudit(table)
        process = fixture_support._R28Process(table, table.root_handle)
        with tempfile.TemporaryDirectory(prefix="native-g1g2-r29-parent-reuse-") as temp:
            output = Path(temp)

            def finish_processes(*_args: object) -> None:
                table.exited.update({table.root_identity, table.new_child, table.grandchild})

            with patch.object(r29.subprocess, "Popen", return_value=process), \
                    patch.object(r29.time, "sleep", side_effect=finish_processes), \
                    patch.object(r29, "_native_resource_reader", return_value={
                        "rss_bytes": 10, "cpu_user_seconds": 0.0,
                        "cpu_system_seconds": 0.0, "cmdline": ["fake"]}):
                stage = r29._run_stage(output, 1, "primary", ["fake-julia"], {}, table, audit)
            attempts = [json.loads(line) for line in
                        (output / "01_primary" / "sample_attempts.jsonl").read_text().splitlines()]
        return stage, audit, attempts

    def test_parent_pid_reuse_then_disappearance_fails_closed_without_retry(self) -> None:
        table = _ReusedParentDisappearsTable()
        stage, audit, attempts = self._run_stage(table)

        self.assertEqual(table.tracked_child[0], table.replacement_parent[0])
        self.assertGreater(table.replacement_parent[1], table.tracked_child[1])
        self.assertGreater(table.new_child[1], table.replacement_parent[1])
        self.assertEqual(len(attempts), 1)
        self.assertEqual(audit.sample_calls, 1)
        self.assertEqual(stage["sample_recovery_count"], 0)
        self.assertEqual(stage["stop_reason"], "resource_monitor_incomplete")
        self.assertFalse(stage["resource_monitor_complete"])
        self.assertFalse(stage["numerical_credit"])
        self.assertFalse(stage["physical_credit"])
        final_residual = stage["final_residual_audit"]
        self.assertFalse(final_residual["residual_clear"])
        self.assertTrue(final_residual["cleanup_unconfirmed"])
        self.assertTrue(final_residual["orphan_uncertainty"])

        recovery = attempts[0]["recovery"]
        self.assertFalse(recovery["complete"])
        self.assertEqual(recovery["reason"],
                         "missing_tracked_generation_pid_reused_after_natural_exit")
        self.assertFalse(recovery["residual_clear"])
        self.assertFalse(recovery["retry_authorized"])
        self.assertEqual(recovery["retry_count"], 0)
        receipt = recovery["pid_reuse_exit_receipt"]
        self.assertEqual(receipt["identity"], {
            "pid": table.tracked_child[0],
            "create_time_100ns": table.tracked_child[1],
        })
        self.assertTrue(receipt["pid_reused_after_exit"])
        self.assertEqual(receipt["replacement_create_time_100ns"],
                         table.replacement_parent[1])
        self.assertTrue(recovery["exit_receipts"][0]["complete"])
        self.assertEqual(recovery["exit_receipts"][0]["replacement_create_time_100ns"],
                         table.replacement_parent[1])

        unaccounted = recovery["unaccounted_observed_generations"]
        self.assertIn({"pid": table.replacement_parent[0],
                       "create_time_100ns": table.replacement_parent[1],
                       "reason": "replacement_generation_observed_after_missing_parent_exit"},
                      unaccounted)
        self.assertIn({"pid": table.new_child[0],
                       "create_time_100ns": table.new_child[1],
                       "reason": "descendant_ancestry_ambiguous_after_parent_pid_reuse"},
                      unaccounted)
        # Select the replacement receipt snapshot, then its immediately next
        # SPI call; preserve raw PPID so stale-parent ambiguity is explicit.
        receipt_snapshots = [snapshot for snapshot in table.history
            if any(row["pid"] == table.replacement_parent[0] and
                   row["create_time_100ns"] == table.replacement_parent[1]
                   for row in snapshot["rows"])]
        self.assertEqual(len(receipt_snapshots), 1)
        receipt_snapshot = receipt_snapshots[0]
        receipt_index = table.history.index(receipt_snapshot)
        self.assertLess(receipt_index + 1, len(table.history))
        next_spi = table.history[receipt_index + 1]
        self.assertEqual(next_spi["snapshot_index"], receipt_snapshot["snapshot_index"] + 1)
        next_rows = {row["pid"]: row for row in next_spi["rows"]}
        self.assertNotIn(table.replacement_parent[0], next_rows)
        self.assertNotIn(table.tracked_child[0], next_rows)
        self.assertEqual(next_rows[table.new_child[0]]["create_time_100ns"],
                         table.new_child[1])
        self.assertEqual(next_rows[table.new_child[0]]["ppid"], table.tracked_child[0])

    def test_genuine_parent_exit_without_pid_reuse_keeps_one_retry(self) -> None:
        stage, table, audit, attempts = \
            fixture_support.R28OrphanChainRecoveryTests()._run_orphan_stage()
        self.assertEqual(stage["stop_reason"], "natural_exit")
        self.assertTrue(stage["resource_monitor_complete"])
        self.assertEqual(stage["sample_recovery_count"], 1)
        self.assertEqual(audit.sample_calls, 2)
        self.assertTrue(attempts[0]["recovery"]["complete"])
        self.assertFalse(stage["numerical_credit"])
        self.assertFalse(stage["physical_credit"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
