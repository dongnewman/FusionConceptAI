# UP1 R2 source/axis binding — independent attack review r2

Decision: **rework**. This is a `TEST_ONLY`/`non_evidence` review. No
authority, candidate, provider, engineering, physical or formal-gate credit is
claimed. Only the returned source-axis implementation/tests/evidence and the
R2 contract/source-capture inputs were read; only this review directory was
written.

## Fresh execution

- Frozen checkout observed: `HEAD=b2c04d8339774635aaecd73651efcdb101e01b5d`,
  `HEAD^{tree}=e28da2ff057201c2257f6b879d3860b7a49cb428`.
- Fresh `python -B -m unittest discover -s test/up1_external_closure_r2/source_axis_binding -p test_*.py -v`: exit 0, 12/12 passed.
- Fresh CLI typed-absence replay in two processes: both exit 0, stdout SHA-256
  `d50df29c6f39dab794620ff09ac247aac9eaec4e194335b4806d7a5e2e40c094`,
  distinct PIDs, equal stderr/stdout bytes. Raw streams and process metadata
  are in `run_receipt.json`.
- The 15-case attack matrix reproduces all prior attacks and adds full
  authority prerequisites, AD56 rejection, fresh-observed drift, and state/
  schema nesting checks. Hash/line-ending/raw checks are recorded in
  `evidence_manifest.json` and `verification.json`.

## Findings

### F1 — P1: fail-closed results still carry `authority_evidence=true`

The issuer-only attack now correctly returns `valid=false` with
`missing_external_authority`, but the same receipt still reports
`authority_evidence=true`. `authority_evidence` is computed at
`source_axis_binding.py:258-262` before structural errors and emitted at
`392-398` without requiring `not errors`. The AD56 escalation attack has the
same leak: it is `fail_closed` yet reports authority evidence true. A
fail-closed receipt must never contain a positive authority bit, otherwise a
downstream consumer that checks the bit rather than `valid` can promote an
invalid external-looking bundle. Set the output authority bit false whenever
any error exists, and test this invariant directly.

### F2 — P2: strict schema is not enforced at nested identity level

Top-level unknown fields and scalar entries are now rejected, but
`source_identity.submodule_closure` is only checked for `applicable` and
optionally `digest` at `source_axis_binding.py:220-224`; nested unknown keys
are not rejected. `NESTED-IDENTITY-UNKNOWN-FIELD` adds an arbitrary nested key,
recomputes the identity digest and still returns valid `TEST_ONLY`. The frozen
contract and manifest advertise `strict_schema=true`; define and enforce the
allowed nested closure schema (and any nested payload schema) rather than
accepting unknown fields at depth.

### F3 — P2: identity schema version value is not checked

The validator checks that `source_identity` is an object and its fields are
known, but never requires `identity_schema_version ==
UP1-R2.source-identity.v1` (`source_axis_binding.py:207-216`). A bundle with
`identity_schema_version="evil-schema"`, recomputed hashes/edges, and a
matching fresh observation is accepted. `IDENTITY-SCHEMA-VERSION-UNKNOWN`
reproduces this. Schema strictness must include exact version values, not only
key names.

### F4 — P2: unknown state/provenance labels are admitted

There is no allowed-value check for `state` or `provenance_class` at
`source_axis_binding.py:254-262` and `305-307`. `UNKNOWN-STATE` is admitted as
`status=valid`; `UNKNOWN-PROVENANCE` is admitted as a valid `TEST_ONLY`
receipt. This creates an untyped state-machine path and is inconsistent with
the frozen absence/TEST_ONLY/EXTERNAL_ISSUED contract. Reject unknown labels
before admission and test TEST_ONLY cannot be relabeled into an unrecognized
state.

## Controls that now pass

- issuer-only and incomplete authority prerequisites are rejected;
- all five explicit authority prerequisite booleans plus per-axis signature
  references are accepted as the intended externally validated structural
  path;
- foreign material source digest is rejected;
- top-level unknown fields, scalar material/edge entries and duplicate JSON
  keys are fail-closed;
- error ordering is invariant under axis permutation;
- capture now includes `HEAD^{tree}`, sorted untracked path/content records,
  and an untracked-content digest;
- fresh observed source is mandatory and drift is rejected;
- AD56 cannot escalate authority; and
- component raw CLI paths exist and their recorded SHA-256 values match.

Required disposition: fix F1–F4, then rerun this matrix and obtain another
independent Luna review. Until then this component remains `rework`; no
external authority or downstream UP1 credit is implied.
