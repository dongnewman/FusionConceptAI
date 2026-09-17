# E0-INT independent integration QA

Verdict: `pass_limited`  
Captured: `2026-09-14T03:00:11.423560+00:00`

This is an independent read-only review of the E0-INT documentation integration. The five permitted target files project to the frozen pre-integration state plus the expected `accepted_limited` status/reference additions. The evidence manifest has no unexpected key changes. The author r10 manifest and independent R3 manifest match the required SHA256 values:

- author r10: `7b5bf78dacf7a7abcbf78639495c4ad4ca2d7d6a4cc5a2f61c52894b93b213e5`
- independent R3: `de4937a6c4c80b8640c39a593872d86592b1862c689fa894b0c0d726b00be5c1`

The frozen source/test/fixture/runner hashes all match the author r10 snapshot. `validate_plan.py` exited `0`, JSON parsing passed, control-character scans passed, and `git diff --check` exited `0` (with only the repository's existing LF-to-CRLF warnings). The final process probe observed no Julia/DESC process; no Julia or DESC command was started by this reviewer.

The preserved acceptance sentence “r7 is the current software execution receipt” is followed by an explicit E0-INT qualification identifying that earlier sentence as historical r7 draft state and recording the review requirement as satisfied by independent R3. It does not assert r7 is the sole execution, so the stale-current/unfinished-review ambiguity is resolved for this bounded integration.

The core v4 README had no correctly named content snapshot in `acceptance_integration/before/`; its before_freeze hash was independently reconstructed by reversing the exact integrator append and restoring the one CRLF lost by the LF rewrite. The implementation README snapshot is present as `before/README.md` and also reconstructs exactly. This line-ending normalization is recorded as an integration provenance detail.

This result is limited to documentation/index/provenance integration and software-contract status. N05/N06 declarations, UP2 total, UP1-04B, all 50 formal B04 receipts/checker/two-process replay, B00/B04, provider, mesh, engineering, physical, and R01-R10 remain pending or unaccepted.

Machine-readable command, stdout/stderr, exit-code, timestamp, hash, projection, and claim evidence is in [report.json](report.json) and [command_receipts.json](command_receipts.json). The reviewer script is [run_independent_qa.py](run_independent_qa.py).
