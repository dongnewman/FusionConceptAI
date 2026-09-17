# Aggregate gate independent review R1

Verdict: `rework`.

This is a fresh-process, read-only attack review of `aggregate_gate`; no
production or test file was modified. The focused author suite is green
(`9/9`, exit `0`), and the three candidate/source/input mismatch attacks,
missing status/fingerprint cases, typed absence, changed-input/no-AD behavior,
claim injection, and two-process baseline replay were independently exercised.

The implementation is fail-closed for fingerprint mismatch and typed absence,
keeps the claim ceiling at `T0/T1/T2/B00/B04/parent=false, L4=0`, and does not
create an AD. However, the attack suite found locally repairable contract
defects: unknown fields are silently ignored; `authority_verified=false` is
ignored; arbitrary responsibility names can become a verified aggregate;
sequence jumps and a direct `event=aggregate` bypass ordered intake; and
reordering the responsibility map changes canonical output/hash. A CLI JSON
with a duplicate `status` key also exits `0` and verifies because the standard
JSON parser collapses duplicate keys.

These defects prevent `pass_limited` for the aggregate component until repaired.
No external authority, provider, Julia/DESC/solver, mesh, or heavy lane was run;
this review grants no T0/T1/T2/B00/B04/L4/parent credit.

## Scope and ownership

- Source under review: `tools/up1_external_closure_r2/aggregate_gate/aggregate_gate.py`.
- Test under inspection: `test/up1_external_closure_r2/aggregate_gate/test_aggregate_gate.py`.
- Frozen references: R2 contract-freeze `interface_contracts.json`,
  `gate_ceiling.json`, and review protocol `review_protocol.md`.
- Reviewer process: Python `-B`, independent script; `TEST_ONLY=true`,
  `non_evidence=true`.
- Only this review directory is written.

