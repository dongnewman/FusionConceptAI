# UP1 R3 repaired atomic prototype independent adversarial review R1

## Decision

**fail_limited**. No P0 publication or external-authority path was observed,
and the canonical-number collision from reviews/05 is closed on this host.
The repair is not acceptance-capable: a schema-conformant directional G2
inverse is rejected by the row-hash comparison, CAS accepts an external
hardlink as an existing immutable object, and the decision/TEST_ONLY boundary
still permits internal acceptance-shaped results under caller-controlled
security material. EHP-04 identity is claim-based for missing runtime files.
R01--R25/D01 are inventory IDs, not concrete mutation executions.

No formal, UP1, B00, B04, parent, physical, engineering, publication, or
external credit is granted. The implementation's authority_credit=false,
formal_credit=none, and no_publish=true limits remain intact.

## Scope and safety

Read-only review of the repaired implementation
tools/up1_external_closure_r3/atomic_bundle/{canonical.py,bundle.py}, its
repair tests, the 03/04 contract schemas and predicate index, the 05 review,
and 07 manifests/receipts. The probe used only Python stdlib/cryptography,
temporary local files, and direct helper calls. No network, external send,
AD/S3, Julia/DESC, solver, credentials, or production mutation was used.
Only this review directory was written.

## P0

None observed. bundle.py:593-594 always emits authority_credit=false,
formal_credit=none, and no_publish=true, including when a caller forces an
accepted_all override into _result. This is a ceiling observation, not
acceptance evidence.

## P1 findings

### P1-01 — CAS hardlink is accepted as immutable content

bundle.py:205-207 accepts an existing regular file when its bytes equal the
incoming bytes. It does not reject an existing hardlink whose other name is
outside the quarantine root. The probe created root/cas/<sha256> as a
hardlink to outside, and quarantine_raw returned successfully with
samefile=true. This defeats contained immutable-CAS identity even though
different-byte overwrite is correctly fail-closed. Reject hardlinked objects
(and hardlinked receipt files) or install with an OS primitive that proves
the object has the intended inode/file identity.

### P1-02 — a normal inverse row hash makes valid G2 fail

bundle.py:410 compares the forward tuple's row_sha256 to the reverse tuple's
row_sha256 while also swapping from_id/to_id. The schema defines row_sha256
over the row body, so directional inverse rows necessarily have different
hashes. A fully populated direct probe produced distinct hashes
2d34ff...0e962 and a6e429...0c9, and emitted
EHP03_G2_MAPPING_MISMATCH. The repair's own broader probe therefore reports
ehp03_valid_closure as FAIL. Compare a canonical inverse relation (or
explicit counterpart IDs) while verifying each row hash independently; do not
require directional row digests to be equal.

### P1-03 — root reparse validation occurs after following the root

_safe_root calls root.mkdir(parents=True, exist_ok=True) at bundle.py:188-190
before walking and rejecting reparse components at 188-196. A supplied
symlink/junction parent can therefore be followed while creating the
directory before rejection. The junction probe was rejected, but symlink
creation was unavailable (WinError 1314), so symlink-root behavior
is not independently demonstrated. Validate every existing parent before
any mkdir, create each component with no-follow semantics, then verify
containment.

### P1-04 — decision precedence contradicts the fail-closed contract

At bundle.py:581-590, missing security_ok is appended as
SECURITY_OUTCOME_UNAVAILABLE, but an executed fixture then derives
rejected_all rather than the contract's terminal_deferred. Conversely,
fixture_status == not_executed takes precedence over other predicate errors,
so a mismatched/not-executed envelope can remain terminal_deferred instead of
rejected_all. The implementation needs an explicit precedence table:
malformed/mismatch/error => rejected_all; valid not-executed or missing
security outcome => terminal_deferred; only executed plus a pinned security
outcome may reach internal accepted_all.

## P2 findings

### P2-01 — TEST_ONLY is not enforced across all trust material

Only packet owner/profile strings are checked at bundle.py:542-543.
_check_quarantine verifies and accepts the pinned receiver profile
TEST_ONLY-R3 at 328-342 without emitting TEST_ONLY_NON_EVIDENCE; the
caller-supplied context.public_keys is also accepted by _verify_signature at
161-168. The probe showed a valid TEST_ONLY receiver receipt with errors=[].
Keep TEST_ONLY keys/receipts explicitly non-evidence, reject them before any
derived acceptance result, and make the security context pinned rather than
caller-selected.

### P2-02 — EHP-03 graph bijection omits issuer/signature references

Graph identity at bundle.py:368 and inverse comparison at 379-384 omit
edge_id, issuer_ref, signature_ref, issued_at, and edge_sha256. Each edge
digest is checked independently, but a forward/reverse pair with different
issuer/signature references can still be treated as the same relation. This
is below the 05 P2 requirement for full graph authority closure. Compare the
complete canonical edge identity and bind authority receipt references.

### P2-03 — EHP-04 runtime/SBOM/binary/fixture evidence is still claim-based

Missing runtime paths are hashed from the path string at bundle.py:439-445;
the probe returned status=not_executed, errors=[] for nonexistent Julia and
Python paths. SBOM and binary checks only compare submitted document/subject
digests (450-478), and an executed fixture verifies a self-referential
receipt digest without reading the command streams or ACL evidence (479-484).
Require existing, contained runtime/binary bytes and durable receipts/stream
hashes, or classify them not_executed/unsupported.

### P2-04 — preimage scope is repaired but not independently golden-tested

The probe confirms bundle_preimage retains a nested payload field named
signature while removing packet/set/review signature material. This is
pass_limited: the code is path-scoped (bundle.py:95-108), but the 07 vectors
are documentation-only and do not compare complete independent golden bytes
for all four preimages.

### P2-05 — R01--R25/D01 execution is not actual vector coverage

test_atomic_bundle_repair.py:68-79 loops over 26 IDs but rotates only six raw
inputs (70-73). The independent mapping observed 26 IDs, only six unique raw
hashes, two code sets; R25 received RAW_INVALID_JSON and D01 received
SCHEMA_INVALID, so neither executed its stated mutation. The claimed two
14-test runs (exit 0) prove harness execution only, not expected error/decision
behavior. Build one concrete baseline and one mutation per ID, assert the
expected code and decision, and include a real disagreement fixture.

### P2-06 — registry equality does not prove observable code coverage

The 07 registry and bundle.ERROR_CODES have equal sets of 72 codes, which is
a useful pass_limited static check. It does not show that all codes are
reachable and stable: many new CAS/EHP04/TEST_ONLY codes have no concrete
R-vector assertion, and the 04 predicate index remains a separate
implementation_status=not_implemented document. Keep one authoritative
registry plus an observed-code ledger.

## Pass-limited observations

| Area | Result |
|---|---|
| RFC8785 boundary | pass_limited: absent RFC8785 rejects all floats/exponents and negative zero; 1e20 collision is closed. RFC8785-active behavior remains untested here. |
| malformed public inputs | pass_limited: focused 14 tests and five malformed shapes return typed SCHEMA_INVALID with no_publish=true; no full schema-valid malformed-predicate corpus. |
| receipt/hash/signature tamper | pass_limited: exact in-memory receipt equality, raw bytes/size, receipt digest, pinned Ed25519 signature, locator and transaction checks reject the tested tamper cases. The persisted receipt file is not re-read/bound independently. |
| CAS overwrite/idempotence | pass_limited: different-byte collision rejects and equal-byte repeat is idempotent; hardlink containment fails as P1-01. |
| path checks | pass_limited: traversal resolves inside intended root and junction rejection passed; symlink-root case was unavailable on this host. |
| payload preimages | pass_limited: nested payload is opaque in the direct probe; full golden vectors absent. |
| no heavy/external lanes | pass_limited: this review used no network, external send, AD/S3, Julia/DESC, solver, or production files. |

## Receipts

- Repository: D:\006-Programing\LMC\FusionConceptAI
- Probe command: python -B -c <stdlib/cryptography direct adversarial probe>
- Probe PID: 90204
- Probe UTC: 2026-09-16T23:44:10.783701Z
- Probe exit: 0
- Focused command: python -B -m unittest discover -s test/up1_external_closure_r3/atomic_bundle -p 'test_*.py'
- Focused wrapper PID: 112260
- Focused UTC: 2026-09-16T23:44:48.086670Z
- Focused exit: 0; Ran 14 tests ... OK
- Raw files and their hashes are enumerated in evidence_manifest.json; all raw
  outputs are local and contain no external communication.

## Required next closure

1. Reject hardlinks and pre-check all reparse parents before creation.
2. Repair G2 inverse comparison and add a schema-valid positive closure.
3. Define decision precedence and enforce TEST_ONLY non-evidence globally.
4. Require actual runtime/binary/fixture receipts and full graph/issuer closure.
5. Replace the six-input loop with one concrete R01--R25+D01 mutation harness
   and maintain an observed-code ledger.
