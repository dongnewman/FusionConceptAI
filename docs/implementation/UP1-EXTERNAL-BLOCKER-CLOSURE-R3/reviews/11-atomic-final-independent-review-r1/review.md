# UP1 R3 atomic prototype — final independent adversarial review R1

## Decision

**fail_limited**. This is a local software/prototype audit only. The repair
does not establish UP1, formal credit, external authority, physical or
engineering evidence, R01–R10 closure, or publication readiness.

`authority_credit=false`, `formal_credit=none`, `no_publish=true`, and
`claim_scope=software_only` remained fixed in all result paths observed. No
network, external send, AD/S3, Julia/DESC/solver, credential, or production
mutation was used. The frozen implementation and test inputs were unchanged.

## P1 findings

### P1-01 — 26 builders are still not executed as semantic mutation coverage

`test_atomic_bundle_vectors.py:181-204` checks that named builders have
distinct paths/bytes and that their metadata agrees with the matrix. It does
not validate each built envelope against its expected failure code. The
boundary test in `test_atomic_bundle_repair.py:119-138` only requires
`no_publish` and a generic `rejected_all`/`terminal_deferred` decision.

Independent replay of all 26 named builders (`raw/vector_replay.stdout.raw`)
produced only two expected matches: R01=`SCHEMA_INVALID/rejected_all` and
R23=`RAW_DUPLICATE_KEY/rejected_all`. R02–R22, R24, R25, and D01 all returned
the same `SCHEMA_INVALID/rejected_all`, not their matrix predicates. R22 and
R24 cannot demonstrate clean deferral from the deliberately incomplete base;
R25 cannot demonstrate the “internal accepted_all only” path because its
`security_ok` value is placed where the schema rejects it. Thus byte/path
distinctness is real, but semantic coverage and expected-code assertion are
not closed.

### P1-02 — EHP-04 root identity is resolved, but a root reparse alias is not
closed at the public boundary

`bundle.py:846-852` resolves `context["artifact_root"]` before passing it to
`_check_ehp04`; `_artifact_bytes` then checks `_reparse(root_resolved)`, not
the original root path. A symlink/junction artifact root can therefore resolve
to a normal directory and be accepted as the root. The host could not create a
Windows symlink without `SeCreateSymbolicLinkPrivilege`, so this is a static
boundary finding, not a fabricated host pass. Existing ordinary escape-path,
missing-root, and contained-byte probes did pass.

## P2 findings / limited closures

### P2-01 — EHP-04 input artifact hardlinks are not identity-checked

The independent probe created an outside file and a root-contained hardlink
(`st_nlink=2`). `_artifact_bytes` returned the shared bytes and emitted no
error. CAS objects correctly reject external hardlinks, but runtime/SBOM/
binary/download input material does not use the same single-link identity
check. This limits containment to path/reparse semantics rather than inode
identity and should remain `pass_limited` until the intended policy is explicit.

### P2-02 — Download receipt bytes are hash-bound but not parsed/bound to their
declared subject

With a root-contained receipt containing arbitrary non-JSON bytes and the
correct declared receipt hash, `_check_ehp04` returned no errors because the
envelope `subject_sha256` matched the binary. Hash tampering was rejected.
The result is a real-bytes/hash check, but not evidence that the bytes are a
download receipt whose content names the binary; retain this as a software
ceiling, not acceptance evidence.

### Limited closures

- **CAS hardlink:** `pass_limited`; an actual external hardlink produced
  `CAS_HARDLINK_REJECTED`. Collision and idempotent replay were covered by the
  serial focused suite.
- **CAS reparse:** `pass_limited`; the existing symlink test remains a real
  host-privilege skip (`skipped=1`), while ordinary injected/available path
  checks are not promoted to a Windows reparse pass.
- **G2 directional rows and authority tamper:** `pass_limited`; independent
  forward/reverse row digests were distinct, and inverse issuer tampering
  emitted `EHP03_G2_REF_MISMATCH` plus row/mapping errors. Unrelated helper
  graph/source errors were recorded and not hidden.
- **Decision precedence:** `pass_limited`; an injected real error rejected
  before `not_executed` defer, while a clean `not_executed` result deferred.
- **TEST_ONLY:** `pass_limited`; the public context path returned typed
  `SCHEMA_INVALID` with `no_publish=true`, and implementation paths retain
  `TEST_ONLY_NON_EVIDENCE`. This is not an external trust root.
- **Error registry:** `pass_limited`; serialized R3 registry and
  implementation `ERROR_CODES` matched exactly (82/82), and an injected
  unknown code was preserved and forced `rejected_all`. The JSON artifact is
  still a separately stored snapshot; runtime use does not automatically
  regenerate or verify that file.
- **Authority/publish surface:** `pass_limited`; static scan found no network,
  send, upload, or publisher implementation. Every observed result retained
  `authority_credit=false`, `formal_credit=none`, `no_publish=true`.

## Regression receipt

Command, run serially twice:

`python -B -m unittest discover -s test/up1_external_closure_r3/atomic_bundle -p test_*.py`

Both runs exited **0**, each reported `Ran 23 tests ... OK (skipped=1)`.
The skip is the host privilege-limited symlink/reparse creation test. Exact
PIDs, UTCs, raw sizes, and SHA-256 values are in `receipt-manifest.json`;
raw stdout/stderr are retained under `raw/`. `freeze_manifest.json` records
the pre-run hashes and a post-run comparison found every frozen input
`unchanged=true`.

Independent probe command:

`python -B docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R3/reviews/11-atomic-final-independent-review-r1/independent_attack_probe.py`

It exited **0** (PID **112920**, UTC
**2026-09-17T00:50:14.1470076Z–2026-09-17T00:50:16.2031659Z**). Its raw stdout
SHA-256 is
`21d810b76cda70a90ad10f4e2d5a85671f5be958a0d644e1abc03a0bc178b8ce`.
The probe performed no external I/O and used temporary directories cleaned by
their context managers.

## Required next closure

Build one schema-valid baseline envelope with each R01–R25/D01 mutation
asserting its expected predicate and decision against fresh raw bytes;
exercise root reparse identity at the public boundary (or make the skip an
explicit host capability gate); decide whether EHP-04 input artifacts require
CAS-style hardlink identity; and parse/bind download/SBOM receipt content if
their semantic evidence is intended. Until then retain `fail_limited`,
`formal_credit=none`, `authority_credit=false`, and `no_publish=true`.
