# G-I1B source inventory commands

- Frozen input list and SHA256/bytes/UTC mtime into `input_hashes.json`.
- Captured pre-audit `git status --short` into `protected_dirty_status.txt`.
- Read current G-I1B source inputs, accepted-limited archives and G1/G2/G3 fixtures with `rg`/PowerShell JSON parsing only.
- Built the 50-row `source_matrix.json` from explicit source expressions and observed fixture values; no source/test/core file was written.
- No Julia/DESC command was run.
- Final QA results are in `qa.json`; archive artifact hashes are in `artifact_hashes.json`.
