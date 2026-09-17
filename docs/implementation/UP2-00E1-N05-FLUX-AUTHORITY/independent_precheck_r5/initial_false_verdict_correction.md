# R5 reviewer script correction record

The first execution of the R5 reviewer script produced a provisional `changes_requested` result. Its aggregate blocker was a reviewer-script false negative: the exact source assertions for the authored endpoint locator and G1 locator did not match the source's actual function/path spelling, and the classifier sentence was split across a comment line break. The source and tests were not changed. After manually inspecting source lines 299-304, 343-430, and 598-613, the assertions were corrected to the actual implementation paths and rerun.

The corrected run reports `ready_for_focused_r4`, with the same four frozen input hashes and all static QA command exits zero. The initial provisional `report.json` and command receipt bytes were overwritten by the corrected run; this note preserves the history and explicitly records that the first false verdict is not an independently hashable prior artifact.
