# N06 focused R9 independent failure audit

Verdict: `failure_audit_open_gate`. This audit did not run Julia/DESC and did not modify R9/raw.

R9 receipt exit=1, baseline group `28/28`, typed occurrence group `3/3`, and source-derived mutation group `31/31`; shared owner/E0 group failed `37 pass / 1 fail / 38 total` at test line 263 because the fixture contains 14 static negative controls while the R9 test asserted 12.

The two selector controls `missing_source_selector` and `wrong_source_selector` are present in the 14-item fixture and have explicit test paths at lines 332-371, including selector restoration. They were not reached by this R9 run because line 263 fails first. The minimal safe test-only repair is to reconcile the stale count with an exact set assertion covering all 14 names, while preserving both selector test bodies; changing only a number without retaining/exercising those controls is insufficient.

Post-R9 provenance: the current test hash is `87b5375a2f33df3acaad503bfd5685c54187e95308139e68e15ac491af43b63b`, while the R9 execution input and repair_r10 before hash are `d88a1ed7965716eb4210c09fd5b89b3e4e27e8677c15ff8dcbe0721b8a373ca1`. This audit therefore treats the R9 raw result as immutable historical evidence and does not treat the later test-only repair as runtime-validated.

R9 source/test/fixture/runner hashes from `focused_r9/input_hashes.txt`, raw receipt/stdout/stderr, R8 exit1 evidence, and prior receipts were checked. JSON parse, `validate_plan.py`, `git diff --check`, and post-audit Julia/DESC sweep all exited 0. No claim credit is granted.
