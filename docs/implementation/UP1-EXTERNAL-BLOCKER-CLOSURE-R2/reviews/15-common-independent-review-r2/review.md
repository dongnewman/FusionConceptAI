# UP1 external closure R2 — common independent review R2

Verdict: **rework**. The R1 fixes hold for all previously reported attacks,
including numeric subclasses, nested/cyclic fingerprint payloads, receipt
domain/alias/status/timestamp checks, JSON error taxonomy, bare manifest
strings, and pathname replacement races. However, two new identity-boundary
issues remain, plus one taxonomy consistency issue. Therefore this review does
not qualify for `pass_limited`.

## Scope and fresh verification

Only these were read:

* `tools/up1_external_closure_r2/common/**`
* `test/up1_external_closure_r2/common/**`
* `docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/15-common/**`

Only this R2 review directory was written. Fresh commands used Python 3.13.5:

```text
python -B -m unittest discover -s test/up1_external_closure_r2/common -p 'test_*.py' -v
python -B docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/reviews/15-common-independent-review-r2/attack_review.py
python -B -m compileall -q tools/up1_external_closure_r2/common test/up1_external_closure_r2/common
```

The focused suite passed all 11 tests; compileall passed; the attack driver
exited 0. Two independent child processes with different `PYTHONHASHSEED`
values produced byte-identical canonical/fingerprint/receipt output. A
Windows replacement pressure loop rejected 256/256 replacements with
`identity_mismatch` and leaked zero replacement bytes. Symlink creation was
attempted but unavailable under the current Windows token (`WinError 1314`),
so the existing lstat control was not bypassed by a real symlink in this run.
The implementation manifest verified `ok=true`, and all nine input hashes
matched. `raw/stdout.raw` is a compact capture; the complete JSONL is
reproducible from `attack_review.py`.

## Open findings

1. **MEDIUM (P2) — a forged `Fingerprint` object is accepted without checking
   its preimage digest** (`identity.py:58-73`, `receipt.py:41-72`). A caller can
   instantiate `Fingerprint("up1:candidate", "v1", "00...00", b"forged", ...)`
   and `build_receipt` emits it as a valid candidate identity. `_fp` validates
   shape, domain, version and profile, but never checks
   `sha256(preimage) == digest`; the dataclass has no invariant either. This
   permits a receipt's candidate/source digest to be detached from the bytes
   that supposedly generated it. Validate the dataclass invariant and recheck
   object inputs at the receipt boundary, or accept only freshly constructed
   fingerprints. Serialized mappings need an explicit policy: either carry a
   verifiable preimage or be labeled as an unverified external assertion.

2. **MEDIUM (P2) — malformed typed-error fields are accepted**
   (`receipt.py:85-116`). `_validate_error` checks only code and message. A
   mapping with `details: []` or a non-string `path` is emitted and hashed as a
   typed error even though `TypedError.details` is a mapping and `path` is
   declared as text. Enforce `path` as string/null and `details` as a string-key
   mapping with canonical values; reject malformed shapes with `invalid_error`.

3. **LOW/API — oversized JSON integers use the syntax error code**
   (`canonical.py:193-205`). A 5000-digit JSON integer is rejected, but Python's
   integer conversion limit is surfaced as `SyntaxJSONError`/`invalid_json_syntax`
   rather than the dedicated `non_canonical_number`. This is fail-closed but
   makes error routing inconsistent with direct canonicalization. Wrap the
   parser's integer conversion limit as `NonCanonicalNumberError`.

`content_identity(..., canonical=False)` deliberately produces the same
canonical bytes/digest while omitting the profile marker. This was recorded as
an API observation, not treated as a blocker because the existing API documents
the flag only through the returned metadata.

## Acceptance boundary

No R1 finding regressed. Duplicate keys, Unicode/lone surrogates, invalid UTF-8,
NaN/Inf/-0, numeric subclasses, large Python integers, ordinary and cyclic
values, nested self-hash, candidate/source separation, domain collision and
alias mismatch, unknown status/error, reverse UTC, exact-set duplicate/missing/
extra/hash mismatch, path traversal, bare strings, bounded reads, replacement
TOCTOU, cross-process determinism, and manifest/raw/hash closure were exercised.
R3 must close the two P2 identity/schema findings before acceptance.
