# UP1 external closure R2 — common independent review R1

Verdict: **rework**. The package is a useful dependency-free baseline, and its
ordinary tests plus the 15-common evidence manifest are reproducible, but the
identity/receipt boundary is not fail-closed against the requested adversarial
inputs. The findings below are sufficient to block acceptance of common as an
identity authority.

## Scope and replay

Read-only review scope was limited to:

* `tools/up1_external_closure_r2/common/**`
* `test/up1_external_closure_r2/common/**`
* `docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/15-common/**`

The only files written by this review are in this review directory. Fresh
commands (Python 3.13.5, `-B`) were:

```text
python -B -m unittest discover -s test/up1_external_closure_r2/common -p 'test_*.py' -v
python -B docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/reviews/15-common-independent-review-r1/attack_review.py
python -B -m compileall -q tools/up1_external_closure_r2/common test/up1_external_closure_r2/common docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/reviews/15-common-independent-review-r1/attack_review.py
```

Baseline: 8 tests passed. Compileall passed. `verify_manifest` over 15-common
returned `ok: true`; all nine source/test hashes in `input_hashes.json` matched
the current bytes. The attack-driver JSONL and empty stderr are in `raw/`.

## Findings

1. **HIGH — canonical JSON accepts numeric subclasses and emits invalid JSON**
   (`canonical.py:50-64`, `93-119`). `_validate` uses `isinstance` and
   `_number` then trusts `str()`/`repr()`. A float subclass whose `repr` is
   `NaN`, or an int subclass whose `str` is `NaN`, returns the literal `NaN`
   instead of rejecting it. This breaks the promise that canonical bytes are
   JSON and can poison every content/fingerprint digest. Require exact builtin
   numeric types (or normalize through a type-safe conversion), and return the
   dedicated typed error at file/API boundaries.

2. **HIGH — nested identity fields bypass the self-reference guard; cycles do
   not fail with a typed error** (`fingerprint.py:18-30`, `50-63`). The guard
   intersects only top-level payload keys, so
   `{"nested":{"candidate_fingerprint":"x"}}` is accepted. A cyclic payload
   recurses inside `_without` and raises `RecursionError` before canonical's
   cycle check. Recursively inspect identity fields with cycle protection before
   stripping, and reject cycles as `cyclic_value`/`unsupported_value` rather
   than leaking an interpreter exception.

3. **HIGH — receipt fingerprint mappings are not bound to their slot or
   canonical schema** (`receipt.py:41-54`, `124-125`). `_fp` checks only one
   lowercase 64-hex digest. A candidate slot accepts `domain: up1:source`, and
   conflicting `digest`/`sha256` aliases are preserved without rejection. A
   caller can therefore construct a syntactically valid candidate receipt with
   a source identity or ambiguous digest. Require the expected domain, version,
   algorithm and canonicalization, and reject conflicting aliases/unknown
   fields (or accept only `Fingerprint`).

4. **MEDIUM — receipt status/error vocabulary is not enforced**
   (`receipt.py:92-97`, `128-131`). Any non-empty string, including `banana`, is
   emitted as a status despite the versioned `Status` enum and `INVALID_STATUS`/
   `INVALID_ERROR` taxonomy. Arbitrary error mappings are copied without
   schema/code validation. Enforce the declared enum or explicitly version an
   extension mechanism, and validate typed error shape/codes.

5. **HIGH — regular-file and size checks are TOCTOU-unsafe**
   (`files.py:37-66`, `manifest.py:78-110`). The implementation stats and
   checks a pathname, then opens that pathname later. A replacement between the
   check and open is consumed; the review driver replaces a two-byte file with
   `EVIL` and `read_bytes_limited` returns the replacement. The same race exists
   between manifest walk/symlink checks and later hashing. Use a securely opened
   handle with no-follow semantics where available and verify the opened handle
   (or document a platform-specific fail-closed fallback); do not rely on a
   second pathname lookup.

6. **LOW/API — iterable path input accepts a bare string** (`manifest.py:101-110`).
   `verify_exact_set(root, "a")` treats the string as an iterable of one-character
   paths. Reject `str`/`bytes` as an expected iterable and require a mapping or
   sequence of path records, preventing accidental under-declaration.

7. **MEDIUM/taxonomy — JSON file errors lose the dedicated error codes**
   (`files.py:69-81`). Invalid UTF-8 and lone surrogates are collapsed to
   `invalid_field`; `invalid_utf8`, `non_canonical_number`, `cyclic_value`, and
   `unsupported_value` are defined but not consistently surfaced. Preserve the
   canonical exception cause/code mapping at the `read_json_file` boundary.

## Acceptance boundary

Path traversal, absolute/drive-qualified paths, duplicate normalized manifest
paths, unexpected/missing/hash-mismatched files, bounded reads, duplicate JSON
keys, non-finite numbers, lone surrogates, ordinary cycles, Unicode escaping,
candidate/source domain separation, deterministic receipts, and the declared
manifest/input hashes were exercised. Those controls are positive evidence but
do not offset findings 1–5. Re-review is required after the fixes, with fresh
tests for all findings and a platform-appropriate replacement/symlink race.
