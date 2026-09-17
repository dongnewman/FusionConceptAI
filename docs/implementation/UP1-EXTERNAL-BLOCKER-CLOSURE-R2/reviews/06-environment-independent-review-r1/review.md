# UP1 R2 environment provenance independent review R1

## Decision

`rework`. The implementation is cleanly offline and has useful fail-closed
shape checks, but a signed synthetic declaration can be promoted to
`present/admissible` after material identity, path, version and dependency
graph mutations. This is a false-admission boundary, not a documentation-only
gap. The package must not be used as an authority closure until the findings
below are fixed and independently re-run.

## Scope and method

Read-only review of:

* `tools/up1_external_closure_r2/environment_provenance/**`
* `test/up1_external_closure_r2/environment_provenance/**`
* `docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/06-environment-provenance/**`
* the factual, non-authoritative `10-environment-capture` package

Fresh commands:

* `python -B -m pytest -q test/up1_external_closure_r2/environment_provenance` → `6 passed`.
* `python -B -m py_compile` for validator, CLI and focused test → exit 0.
* Two independent validator calls returned byte-for-byte equal semantic
  receipts. CLI semantic fields were equal after removing intentionally
  volatile `pid` and `utc`; input SHA-256 was stable.
* 06 manifest: all 6 listed entries matched bytes and SHA-256. 10 capture
  manifest: all 47 artifact hashes matched. The 10 dependency lock hashes
  also matched the current files.

Raw outputs are in `raw/`.

## Findings

### F1 — high: path absence and substitution can be admitted

`_check_path_hash` hashes an existing path, but silently skips the check when
the path does not exist. A signed fixture with `binaries[0].path` changed to
`substituted.exe` still returned `present/admissible`. Absolute paths are also
accepted without containment under `--root`, so a receipt can name an
arbitrary host path. This breaks the required binary/runtime/lock identity
closure and permits path substitution. Require existence (or an explicit
typed absence that can never be `present`), canonicalize and constrain paths
to the declared root/candidate closure, and reject traversal/reparse or
absolute escapes as appropriate.

### F2 — high: declared versions are not bound to identity

Changing Julia's runtime version or a binary version to `9.9.9` still returned
`present/admissible`. Version is required syntactically but is not compared to
an authoritative executable observation, receipt, SBOM component, or another
candidate-bound record. Bind name/version/path/hash consistently, and reject
contradictions.

### F3 — high: duplicate lock and binary identities collapse silently

Adding a second `Project.toml` lock entry or a second `julia` binary entry
still returned `present/admissible`. `_validate_consistency` converts arrays
to dictionaries, so duplicate names are lost and the last value wins. Reject
duplicate normalized lock and binary names before dictionary conversion, and
define the complete required binary set.

### F4 — high: SBOM graph is only referentially shaped, not closed

An orphan component, an empty dependency-edge array, and a two-node cycle all
returned `present/admissible`. The validator checks that edge references are
known, but does not require all components to be reachable/covered, does not
check binary-to-component identity/hash/version linkage, and does not reject
cycles where the contract requires an acyclic dependency closure. Add explicit
coverage, linkage and cycle policy (or document and enforce the permitted
cycle semantics).

### F5 — high: publisher, receipt and recipe claims are not cryptographically
linked

Changing a binary publisher, download receipt digest, or build-recipe digest
to unrelated values still returns `present/admissible`. Required shapes and
`verified/signed=true` flags are checked, but no receipt digest is recomputed,
no receipt binds the binary hash/origin/version, no recipe digest binds the
recipe content or binary, and no signature is checked against a trust root.
The validator may remain offline, but it must require candidate-bound signed
payloads and verify their internal hash/linkage; otherwise classify the
closure typed-absent rather than present.

### F6 — medium: root status and claim ceiling are ignored

Changing root `status` to `fail_closed` and `claim_ceiling` to
`candidate_authority` still returns `present/admissible`; result status is
recomputed solely from fixture role and authority status. Enforce the allowed
root values and require the declared status/ceiling to agree with the result
and the contract's preparation-only ceiling. Never allow a document-provided
ceiling to uplift claims.

### F7 — medium: local observation payload has an unvalidated escape hatch

`local_observation.runtime_paths` is only checked to be a list; arbitrary
objects are accepted. The dedicated evidence-class guard correctly rejects
relabeling the whole observation as authority, but nested runtime-path records
could carry unvalidated authority-looking data. Define and validate the item
schema, or keep this field empty and reject non-empty untyped entries.

### F8 — medium: checked TEST_ONLY fixture is malformed and package manifest
is incomplete

`fixtures/test_only_typed_absence.json`, described as the checked synthetic
non-evidence fixture, is rejected before TEST_ONLY handling because its nested
`signed_receipt` contains duplicate `issuer` keys. Its CLI status is
`fail_closed`, not the documented `non_evidence`/typed-absence behavior. Fix
the fixture or explicitly relabel it as a duplicate-key negative fixture.
The 06 manifest hashes only 6 files while the inspected package tree contained
20 files (15 were not listed; this count includes generated `__pycache__`
files, as well as `__init__.py`, `__main__.py`, fixtures and closure docs), so
it does not demonstrate a complete package inventory. Either list the intended
owned set with a self-hash policy or state the narrower evidence subset.

## Positive controls

The following controls behaved as intended: duplicate JSON keys were rejected;
unknown root fields were rejected; relabeled local observation was rejected;
missing binary receipt, unverified signature and missing build recipe were
rejected; malformed hash-drift fixture was rejected. These controls do not
offset the false-admission findings above.

## Boundary with 10-environment-capture

The capture package correctly states `preparation_only/screen_only`, has
`candidate_ref=null`, records all four observed binaries as
`observed_not_candidate_bound`, and records six typed-absent authority gaps.
Its lock and raw artifact hashes are internally consistent. Those facts are
local observations only and must not be used to repair or promote the 06
authority proof. In particular, the capture explicitly records
`NO_AUTHORITY_FROM_LOCAL_OBSERVATION`, missing candidate freeze/import closure,
missing external binary provenance and missing trust root.

## Claim ceiling

This review grants no candidate, source-authority, provider, solver,
engineering, physical, B00, B04, UP1, R or parent-goal credit. Rework is
required before any `present` result can be considered admissible outside a
synthetic test.
