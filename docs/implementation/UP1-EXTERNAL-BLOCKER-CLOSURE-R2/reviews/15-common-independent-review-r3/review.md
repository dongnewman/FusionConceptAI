# UP1 external closure R2 — common independent review R3

Verdict: **pass_limited**. The R2 common-library repairs close both previously
reported P2 identity/schema findings and the oversized-integer taxonomy issue.
No P1 or P2 finding remains in this independent replay. The result is limited
to the exercised API and Windows environment; it is not a claim of production
or hardware readiness.

## Scope and fresh verification

Only these review inputs were read:

* `tools/up1_external_closure_r2/common/**`
* `test/up1_external_closure_r2/common/**`
* `docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/15-common/**`

Only this R3 review directory was written. Fresh commands used Python 3.13.5
with bytecode disabled:

```text
python -B -m unittest discover -s test/up1_external_closure_r2/common -p 'test_*.py' -v
python -B docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/reviews/15-common-independent-review-r3/attack_review.py
python -B -m compileall -q tools/up1_external_closure_r2/common test/up1_external_closure_r2/common
```

The focused suite passed all 13 tests; the attack driver exited 0; and
compileall passed. The R1/R2 attack set was replayed, including duplicate
keys, invalid UTF-8, Unicode/lone surrogates, NaN/Inf/-0, numeric subclasses,
large Python and JSON integers, cycles, nested self-reference, path traversal,
bare strings, alias/domain/version/type collisions, forged fingerprints and
preimage digests, malformed error details/paths, exact-set omissions/additions,
hash mismatch, candidate/source separation, JSON error taxonomy, bounded
reads, and TOCTOU replacement.

The forged `Fingerprint` constructor now fails closed with `ValueError` when
the preimage digest is inconsistent; receipt-boundary checks also reject
forged mappings. Malformed error details/path are rejected as `invalid_error`,
and oversized JSON integers are classified as `non_canonical_number`. A
`canonical=False` identity retaining the same digest is intentional profile
metadata behavior and did not create a receipt identity collision.

Two independent child processes with different `PYTHONHASHSEED` values
produced byte-identical output, with distinct PIDs and empty stderr. A Windows
replacement pressure loop rejected 256/256 replacements with
`identity_mismatch` and leaked zero replacement bytes. Symlink creation was
attempted but unavailable under the current token (`WinError 1314`), so that
specific OS control is recorded as environment-limited rather than claimed as
executed. The implementation manifest and all input hashes matched. The raw
file is a compact capture; the complete JSONL is reproducible from
`attack_review.py`.

## Findings

No P1/P2 findings. No P3 correctness blocker was found in this R3 replay.
The only API-level observation is that forged direct `Fingerprint(...)`
construction reports a plain constructor `ValueError`, while receipt-shaped
external input reports the typed `identity_mismatch`/`invalid_field` taxonomy;
both paths reject the forgery and this is not a release blocker.

## Acceptance boundary

`pass_limited` covers the common package controls listed above, the focused
tests, deterministic subprocess replay, replacement pressure, and manifest /
raw closure at review time. It does not certify untested filesystems, symlink
privileges, or downstream consumers outside the declared scope.
