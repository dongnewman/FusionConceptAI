# UP1 R3 atomic bundle prototype independent adversarial review R1

## Decision

`fail_limited`. No P0 external-authority emission was observed, but the
prototype is not safe to treat as an acceptance-capable verifier. The active
canonical fallback is non-injective, quarantine evidence is not independently
bound or cryptographically verified, and malformed envelopes can terminate
the API with an exception instead of a fail-closed result. These are P1
blockers. EHP-03/EHP-04 closure and R01--R25/D01 execution remain incomplete
and are P2 gaps. The prototype's explicit `authority_credit=false`,
`formal_credit=none`, and `no_publish=true` ceiling remains intact in the
returned result; this review grants no UP1, B00, B04, parent, external,
engineering, physical, publication, or formal credit.

## Scope and safety boundary

Read-only review of:

- `tools/up1_external_closure_r3/atomic_bundle/{canonical.py,bundle.py}`;
- `test/up1_external_closure_r3/atomic_bundle/{test_atomic_bundle.py,fixtures/test_only_ed25519.json}`;
- 03 contract schemas/verifier contract;
- 04 repaired schemas/verifier contract;
- 05 prototype README, preimage/error-code tables, matrix and existing raw
  receipts.

No network or external send was used. AD/S3, Julia/DESC, solver, credentials,
ambient trust stores, external endpoints, and production source/test mutation
were not used. Only this review directory was written.

## P0/P1/P2 findings

### P0 — none observed

No code path directly publishes or grants external authority: `_result`
returns `authority_credit=false`, `no_publish=true`, `formal_credit=none`
(`bundle.py:363-364`). This is a boundary observation, not acceptance
evidence.

### P1-01 — canonical fallback is hash-colliding, not fail-closed

`canonical.py:101-117` strips all trailing zeroes from fixed notation after
converting an exponent-form float. On the supported host the active profile
is `RFC8785-limited-ecmascript-safe-fallback`; the probe returned
`canonical_bytes({"n":1e20}) == b'{"n":1}'`, exactly equal to the bytes for
`{"n":1}`. `validate_value` accepts that large float
(`canonical.py:82-87`), so this is an actual digest/preimage collision, not a
rejected unsupported number. Packet, set, review and bundle hashes all depend
on `canonical_bytes` (`bundle.py:34-35,92-99,329-350`). A future caller with
`security_ok=true` could therefore verify the wrong preimage under the same
digest. The advertised limited fallback must either use a tested JCS encoder
or reject every number outside a proven subset; it cannot report a passing
canonical computation for this collision.

### P1-02 — submitted quarantine receipt is not bound to the durable receipt

`validate_bundle` durably writes a local receipt (`bundle.py:150-169`), but
`_check_quarantine` only compares the submitted locator to `q["cas_path"]`
(`bundle.py:196-199`). It does not compare the submitted
`raw_receipt_id`, `cas_transaction_id`, receipt digest, or receipt contents to
`q["receipt"]`; it only requires non-empty strings and a self-consistent
submitted receipt digest (`bundle.py:185-207`). It also checks only that
`receiver_signature.signature_b64` is non-empty and never verifies its key,
signature digest, or preimage (`bundle.py:204-207`). The adversarial probe
passed `[]` for a receipt with `raw_receipt_id=attacker`,
`cas_transaction_id=attacker-txn`, fake signature bytes and wrong signature
digests, while the actual q receipt had a different transaction. The
`durable_commit_utc <= verification_started_utc <= decision_utc` test is thus
only a claim in attacker-controlled fields, not independent durable-before-
verify evidence. Bind the exact generated receipt/transaction and verify the
receiver signature with a pinned TEST_ONLY key (or reject it) before deriving
any acceptance result.

### P1-03 — malformed envelopes crash instead of returning fail-limited

The schema is checked, but predicate execution continues on untyped values.
`packet_digest` indexes `packet["payload"]` and assumes a mapping at
`bundle.py:92-99`; `validate_bundle` invokes it before any type guard at
`bundle.py:302-313`. Review and receipt values are likewise used through
`.get()` at `bundle.py:323-350`, and EHP-03 predicates assume mapping-shaped
source/graph/G2 values at `bundle.py:210-243`. The probe produced
`KeyError('payload')` for a packet missing payload, and
`AttributeError: 'int' object has no attribute 'get'` for scalar signature and
review fields. There is no result, failure code, or `no_publish` marker on
these paths. Catch predicate/type/canonical failures after quarantine and map
them to stable `SCHEMA_INVALID`/typed failure outcomes; never run a
cross-field predicate on a structure that failed schema typing.

### P1-04 — CAS root and object are not protected as immutable, contained storage

`quarantine_raw` accepts an arbitrary caller root and constructs
`base / "cas" / digest` without resolving and rejecting symlink/reparse-point
parents (`bundle.py:150-154`). `immutable_locator` is merely a resolved
string. A junction/symlink supplied as `root` can redirect the CAS outside the
intended quarantine directory. `_write_durable` uses unconditional
`os.replace(tmp, path)` (`bundle.py:127-147`), so an existing object at the
content-addressed path is overwritten; the probe preseeded the hash path with
`b"evil"` and observed it replaced by `b"abc"`. That contradicts immutable
CAS semantics and removes an independent collision/replay check. The fixed
PID temporary name can also collide under concurrent same-process calls and
leave a denial-of-service orphan. Resolve and containment-check every parent,
reject symlink/reparse components, atomically create-or-verify existing CAS
objects, and use unique temporary names. On Windows the directory `fsync`
failure is explicitly swallowed (`bundle.py:137-144`), so durable-before-
verify must be represented by an OS-supported durable transaction receipt,
not just timestamps.

## P2 closure gaps

### P2-01 — preimage field coverage does not exactly implement the 03/04 contract

`packet_owner_preimage` removes `payload_sha256` but retains a reduced
`signature` object (`bundle.py:70-74`), whereas the frozen table requires the
signature field itself to be removed and the payload digest recomputed. More
importantly, `bundle_preimage` applies `_without` recursively to every nested
object (`bundle.py:56-67`), so a payload field named `signature_sha256`,
`owner_preimage_sha256`, or `bundle_canonical_sha256` is silently removed even
though the contract says payload bytes remain in the bundle preimage. The
preimage profile is documentation/table data and is not parsed or checked as
an implementation input. Freeze path-scoped removal sets and add independent
preimage golden vectors.

### P2-02 — EHP-03 mapping/graph closure is still partial

The graph identity/inverse and duplicate-edge checks are present and the
existing duplicate/inverse test passes. However, G2 inverse checking compares
only `(from_id,to_id)` pairs (`bundle.py:241-243`): two duplicate logical pairs
with different row IDs/hashes/issuer references pass. The probe returned
`EHP03_MAPPING_DUP_PAIR_ERRORS []`. Axis validation compares only axis IDs
(`bundle.py:234-237`), and no graph/row `edge_sha256`/`mapping_sha256`, issuer,
namespace/version, or authority-receipt closure is recomputed. Thus EHP-03
does not establish the full source/axis/G2 evidence identity required by 03/04.

### P2-03 — EHP-04 identity/SBOM/binary/fixture closure is partial

The prototype checks runtime names, duplicate import/lockfile tuples,
component IDs/endpoints, binary candidate/subject, and executed fixture
shape (`bundle.py:246-280`). It does not bind runtime version/path/hash,
imports/lockfiles to a frozen context, SBOM document/component/edge digests,
binary `sbom_refs`/download receipt references, or actual fixture stream
bytes/owner ACL evidence. A probe with tampered runtime versions and SBOM
document/edge digests returned `not_executed` with no EHP-04 errors before
schema validation. This is only schema/predicate shape evidence.

### P2-04 — TEST_ONLY separation is metadata-only, and acceptance vectors are not executed

The implementation generates a hard-coded TEST_ONLY receiver key and accepts
any caller-supplied `public_keys` mapping (`bundle.py:107-124,159-166`); the
derivation can return internal `accepted_all` when `security_ok=true` and the
fixture is executed (`bundle.py:351-360`). There is no explicit rejection of
TEST_ONLY owner/profile/key material or a `non_evidence` result field. The
current `authority_credit=false`/`no_publish=true` limits the prototype, but
isolation depends on every downstream caller honoring those flags. Keep
TEST_ONLY keys untrusted and make promotion impossible by construction.

The matrix merely registers R01--R25 and D01; the test suite only asserts that
the IDs exist (`test_atomic_bundle.py:121-124`). Existing focused evidence is
9 tests, exit 0, twice; no R-series mutation is actually run, including D01
decision disagreement. Therefore the claimed negative-vector coverage is
`fail_limited`, not a test pass.

### P2-05 — decision/error-code consistency is not independently evidenced

The code does append `DECISION_DISAGREEMENT` after deriving a decision
(`bundle.py:351-359`), which is a useful bounded check. It does not have a
valid four-packet fixture exercising set/review disagreement, and the 04
machine predicate index omits the implementation-emitted
`DECISION_NOT_BOUND_TO_QUARANTINE` code. The 05 error-code list contains it,
but the split registries and unexecuted D01 leave the stable-code contract
unproven. The AST inventory found 47 literal `_err` codes; the 05 registry
contained all except the pre-parse/runtime-raised classes are not discoverable
through `_err`, while the 04 predicate table omits
`DECISION_NOT_BOUND_TO_QUARANTINE`. Register one authoritative code index and
execute each vector against observed codes and derived result.

## Pass-limited observations

| Area | Independent judgment |
|---|---|
| Strict duplicate-key, non-finite, UTF-8 preparse | `pass_limited`; focused tests pass, but no complete R23 vector harness |
| Draft 2020-12 schema references/closed packet wrappers | `pass_limited`; static/schema design is present, no R01 instance vector |
| EHP-03 duplicate/inverse graph identities | `pass_limited`; selected identities are checked and existing negative test passes |
| EHP-04 names, tuple duplicates, endpoints, binary subject | `pass_limited`; selected relations only |
| local write+flush+file fsync+replace | `pass_limited`; no OS-level reparse/atomicity race receipt |
| no network/external send/heavy lane | `pass_limited`; static import scan and scoped execution show none |
| result boundary flags | `pass_limited`; no_publish/authority/formal flags are explicit, but TEST_ONLY promotion guard is absent |

## Execution receipts

- Repository: `D:\006-Programing\LMC\FusionConceptAI`
- Reviewed HEAD: `b2c04d8339774635aaecd73651efcdb101e01b5d`
- Focused command: `python -B -m unittest discover -s test/up1_external_closure_r3/atomic_bundle -p 'test_*.py'`
- Focused result: exit `0`, 9 tests, existing receipt PID `103052`, UTC
  `2026-09-16T23:07:52.6548490Z`.
- The repeated focused run also exited `0` with PID `34732` at
  `2026-09-16T23:07:53.7069984Z`; its existing raw output hash is
  `95b2870df5fec80dec4ec8c60b0e120eecd3e5bbf6bb23537beb22dbd3389a79`.
- Adversarial probe: `python -B -` (stdlib/AST/temp local CAS only), PID
  `88180`, UTC `2026-09-16T23:16:15.006193Z`, exit `0`.
- Probe raw output/hash: `raw/adversarial_probe.stdout.raw`, SHA-256
  `a551c522a7ffbe65bd6730265903113fafe8fe638c6087980c8dc1eb8dd59214`.
- Existing focused raw hashes: run 1
  `bc9f6d02175dccb906252321e8ea7acea7d9839e9b515cd8bfbe39c90a222103`;
  run 2 `95b2870df5fec80dec4ec8c60b0e120eecd3e5bbf6bb23537beb22dbd3389a79`.
- Reviewed input hashes and receipt metadata are in
  `evidence_manifest.json`; no reviewed file was modified.

## Required closure before acceptance-verifier authorization

1. Replace or strictly narrow the fallback canonicalizer and add golden
   collision/number vectors.
2. Bind the exact durable receipt and CAS object, verify receiver signature,
   harden root/reparse/overwrite/race handling, and produce durable event
   evidence before any predicate.
3. Convert malformed predicate paths to typed fail-closed results.
4. Implement exact path-scoped preimages and full EHP-03/EHP-04 digest,
   inverse, issuer and fixture closure.
5. Add explicit TEST_ONLY non-evidence isolation and execute concrete R01--R25
   plus D01 vectors with one authoritative error-code registry.
