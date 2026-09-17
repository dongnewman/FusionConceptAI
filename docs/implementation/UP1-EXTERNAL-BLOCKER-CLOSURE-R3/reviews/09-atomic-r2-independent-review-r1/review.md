# UP1 R3 atomic prototype repair R2 — independent adversarial review R1

## Decision

**fail_limited**. The repaired prototype remains software-only and cannot
produce authority credit or publish output: `authority_credit=false`,
`formal_credit=none`, and `no_publish=true` are fixed in the result envelope,
including an acceptance-shaped internal decision. No P0 was observed. This is
not UP1, B00/B04, external, physical, engineering, or publication evidence.

The independent probe and two focused reruns were offline and local only. No
network, external send, AD/S3, Julia/DESC/solver lane, credentials, or
production mutation was used. The probe's temporary files were removed by the
temporary-directory lifecycle. The only persistent files written by this
review are this directory's report, manifest, probe, and raw receipts.

## P1 findings

### P1-01 — EHP-04 containment and receipt binding is incomplete

`bundle.py:738-744` makes `artifact_root` optional, and
`bundle.py:566-588` only applies the containment test when that root is
provided. The probe wrote an absolute runtime byte file outside the intended
root: with `artifact_root` supplied it correctly returned
`EHP04_RUNTIME_ARTIFACT_UNAVAILABLE`, but with no root it returned no runtime
availability error. Thus “contained local bytes” is not enforced at the public
boundary. In addition, SBOM documents and download receipts are accepted from
submitted digest/ref claims; unlike runtime/binary bytes and executed fixture
streams, no local SBOM or download-receipt bytes are opened and bound. This is
the residual 07 P2-03 class and blocks acceptance-level EHP-04 closure.

### P1-02 — R01–R25/D01 are still not semantic mutation coverage

`test_atomic_bundle_repair.py:120-141` creates R01–R25 from one dictionary
comprehension whose only varying value is a string, and assigns every vector
the expected pair `rejected_all/SCHEMA_INVALID`. The matrix has 25 vectors
whose expected codes are not `SCHEMA_INVALID` (R02–R25 and D01), including
CAS, G2, EHP-04, security, and decision-disagreement predicates. The builders
are byte-distinct, but not mutation-distinct, and the assertions do not test
their stated error codes. This residual is the 07 P2-05 class despite the 09
README claim that all 26 IDs have independent expected assertions.

### P1-03 — Error registry is stale and one emitted code is silently remapped

The independent set comparison found 76 codes in `bundle.ERROR_CODES` versus
72 in `07-atomic-prototype-repair-r1/error-registry.json`. The registry omits
`CAS_HARDLINK_REJECTED`, `EHP04_RUNTIME_ARTIFACT_UNAVAILABLE`,
`EHP04_BINARY_ARTIFACT_UNAVAILABLE`, and `EHP04_FIXTURE_RECEIPT_UNBOUND`.
Moreover `bundle.py:399` calls `_err(...,
"DECISION_NOT_BOUND_TO_QUARANTINE", ...)`, but that string is absent from
`ERROR_CODES`; `_err` therefore converts it to the generic
`TYPED_VALIDATION_FAILURE`. This leaves the claimed authoritative error
registry and stable vector-code mapping false (residual 07 P2-06).

## P2 findings and limited closures

- **07 P1-01 CAS hardlink:** `pass_limited`. An existing external hardlink
  object and a predictably-created hardlink receipt both returned
  `CAS_HARDLINK_REJECTED`; different-byte collision returned
  `CAS_COLLISION_FAIL_CLOSED`; equal-byte replay was idempotent.
- **07 P1-02 G2 inverse row hash:** `pass_limited`. A schema-shaped helper
  positive with distinct directional `row_sha256` values returned no EHP-03
  G2 errors. Inverse issuer tampering returned
  `EHP03_G2_REF_MISMATCH` (also row/mapping mismatch), showing issuer/time and
  directional digest checks are active. This is helper-level evidence, not a
  signed full-bundle acceptance.
- **07 P1-03 reparse-before-mkdir:** `pass_limited`. The implementation
  checks each existing component before mkdir and rechecks created components
  and final containment. A directory symlink probe was a real host skip
  (`WinError 1314`, privilege unavailable), so symlink behavior is not
  promoted to a host-demonstrated pass; hardlink/path checks remain local
  software evidence only.
- **07 P1-04 decision precedence:** `pass_limited`. An injected predicate
  error plus `not_executed` returned `rejected_all`; a clean
  `not_executed` result returned `terminal_deferred`. The result contract
  still explicitly denies authority and publication.
- **07 P2-01 TEST_ONLY boundary:** `pass_limited`. The pinned local receiver
  receipt emits `TEST_ONLY_NON_EVIDENCE`, and public context rejects
  caller-only `public_keys`/TEST_ONLY trust material before any acceptance
  result. This does not create an external trust root.
- **07 P2-02 graph authority references:** `pass_limited`. The helper positive
  binds graph and G2 issuer/signature references and `issued_at`; an inverse
  issuer mutation was rejected. Complete signed-envelope and external issuer
  evidence remain absent.
- **07 P2-04 preimages:** `fail_limited`. Direct path-scoped exclusion behavior
  is present, but no independent golden-byte fixtures cover all packet, set,
  review, and quarantine preimages.
- No schema-valid, fully signed four-packet positive envelope was independently
  accepted. The 20-test focused suite therefore demonstrates regression
  execution only, not acceptance closure.

## Receipts and reproducibility

The exact input and raw-output SHA-256/size manifest is
`manifest.json`. The primary probe receipt is
`raw/adversarial_probe.stdout.raw` (PID **92100**, UTC
**2026-09-17T00:12:28.267884Z**, exit **0**, SHA-256
`269e8a44949665f162a965d18eda84708cdab3dc828f842c17d60c4245d84b6e`). Its
records include CAS hardlink/collision/idempotence, pre/post reparse behavior,
G2 directional digest and issuer binding, decision precedence, TEST_ONLY,
EHP-04 containment, vector-builder and registry comparisons.

Focused command (two serial runs):

`python -B -m unittest discover -s test/up1_external_closure_r3/atomic_bundle -p 'test_*.py'`

Both exited **0**, each reporting `Ran 20 tests ... OK (skipped=1)`; the skip
is the host privilege-limited symlink/reparse creation probe. Process IDs,
UTC, exits, and raw hashes are in `raw/focused_runs.process.json` and
`manifest.json`. Python compilation of the three package modules plus this
probe exited **0**; its process receipt is `raw/py_compile.process.json`.

## Required next closure

Make EHP-04 require a pinned, validated artifact root and bind actual SBOM /
download-receipt bytes; replace the 26 placeholder builders with one
schema-valid baseline plus one semantic mutation and expected code per matrix
ID; synchronize one registry with every emitted code; add independent golden
preimage vectors and a signed full-envelope positive/negative corpus. Until
then retain `fail_limited`, `formal_credit=none`, `authority_credit=false`,
and `no_publish=true`.
