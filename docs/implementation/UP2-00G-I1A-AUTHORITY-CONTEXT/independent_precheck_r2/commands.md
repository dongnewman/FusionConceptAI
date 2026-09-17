# G-I1A independent precheck R2

- Frozen current G-I1A source/test/fixture/runner, AD-26/core references, N05/N06/E0 sources and R1/repair archives into `input_hashes.json`.
- Read source and test text with `rg`/PowerShell only; no Julia/DESC was started.
- Checked constructor status logic, trusted source validator inputs, E1/E2 slot hashing, N06 admission and tests.
- Final JSON/control, input-drift, validate-plan and diff checks are recorded in `qa.json`.
