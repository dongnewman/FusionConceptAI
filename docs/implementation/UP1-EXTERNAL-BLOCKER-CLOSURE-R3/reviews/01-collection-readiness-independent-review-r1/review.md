# UP1 R3 collection-readiness independent review R1

## Decision

`audit_facts_confirmed`; `not_ready_for_one_shot_external_delivery`.

The R3 collection-readiness audit is materially accurate about the frozen R2
package and its claim ceiling. The 26/26 crosswalk, four packet split, typed
absence boundary, missing atomic-set controls, and the EHP-01..04 closure gaps
are reproducible from the R2 files. The proposed additive patch is directionally
fail-closed and does not itself mint authority, but it is not yet an
implementable acceptance contract: the P1 items below must be closed before a
future schema/verifier can be treated as a one-shot delivery gate.

No external request, network access, AD/S3/Julia/DESC/solver action, production
test run, source edit, test edit, registry edit, or R2/R3 audit edit was made.
Only this review directory was written.

## Independent facts

Repository paths below are repository-relative; `raw/*` paths are relative to
this review directory.

| Check | Result | Basis |
| --- | --- | --- |
| R2 request crosswalk | 26 listed, 26 unique | `request_packets.json:12-15` |
| Packet assignment | 26 listed, 26 unique, same ID set as crosswalk | R2 packet `packets[*].absence_ids` |
| Responsibility coverage | expected 26, listed 26, unique 26 | `responsibility_matrix.json:15-18` |
| Packet set | exactly `EHP-01`, `EHP-02`, `EHP-03`, `EHP-04` | R2 `request_packets.json:17-45` |
| R2 claim/state | preparation-only; not sent; no external mutation; no new AD/S3 | R2 manifest/request packet |
| Atomic-set controls | no `bundle_id`, packet-set digest, bundle digest, `accepted_all`, or `rejected_all` key | recursive key scan of R2 request |
| Channel | endpoint/transport values remain typed absence | R2 request common binding and templates |
| EHP-02 verifier | top-level `verifier` object absent | EHP-02 template; R2 request asks for verifier release at `request_packets.json:27-30` |
| EHP-03 closure | source fields required by R2 contract are absent; evidence edges are scalar strings; no mapping/reverse rows | R2 source contract `contract.json:9-21`; EHP-03 template |
| EHP-04 closure | binary lacks `download_receipt`, `sbom_refs`, `license`; SBOM lacks `spec_version`, `document_sha256`, `components`, `dependency_edges`; imports/lockfiles are strings | R2 environment schema `schema.json:7-20`; EHP-04 template |

R2's component contracts support these interpretations: witness closure requires
all three layers, four axes, evidence rows and candidate-bound signature/ack
(`01-witness-authority/contract.md:38-52`); source closure requires HEAD/tree,
dirty/untracked/submodule closure and exact bidirectional edge objects
(`04-source-axis-binding/contract.json:9-21`); environment provenance requires
the binary/SBOM closure fields listed above (`06-environment-provenance/schema.json:7-20`).

The target R3 artifacts also pass their own recorded integrity claims: the R3
manifest's 17 listed files recompute to their recorded byte counts and SHA-256
values. The prior R3 raw validations report exit `0`, with collection-readiness
PID `93748` at `2026-09-16T21:49:31.654679Z`, artifact-validation PID `109696`
at `2026-09-16T21:54:39.360859Z`, and final-validation PID `38944` at
`2026-09-16T21:56:42.044022Z`. These are integrity receipts only, not external
authority.

## Findings

### P1-01 — Atomic acceptance is not formally computable

The proposal names an ordered four-packet set, per-packet digests, a bundle
digest and an “all-four completeness predicate” (`contract_patch_proposal.md:5-11`),
but does not define the predicate or the digest preimage. It omits the exact
canonical serialization rules (key ordering, whitespace/LF, number policy),
self-field exclusions, domain separation, treatment of duplicate/extra packet
IDs, and whether `packet_digests` is an ordered array or an unconstrained map.
Consequently two verifiers can compute different bundle digests or accept a
caller-supplied completeness boolean over a partial/extra set. This defeats the
central atomic-set guarantee.

Required closure: a machine-readable closed schema must derive completeness
from exactly four distinct packet IDs in the fixed order; define exact UTF-8
canonical bytes and all self/signature exclusions; reject duplicate/unknown
keys, extra/missing packets, non-finite numbers and digest disagreement before
any acceptance decision. The completeness result must be derived, not trusted
from an input boolean.

### P1-02 — Per-packet authority/signature coverage is ambiguous

The proposal requires every response and the set receipt to repeat a shared
binding tuple (`contract_patch_proposal.md:13-21`) and asks for a signed ack,
but it does not explicitly require each packet payload to be signed by its
declared external owner, state which signer/certificate covers which bytes, or
bind the set receipt to all four packet signatures and the same trust/profile
inputs. A single set-level signature or a signed ack over packet digests could
therefore authenticate references without authenticating the EHP payloads.
That would allow an apparently complete set to carry unsigned or foreign
EHP-01..04 data.

Required closure: define one closed signed preimage per packet (owner identity,
packet ID/version, payload digest, shared binding, signer key/profile and
trusted-time/revocation/replay references), then define the set receipt as a
signature over the ordered four packet receipts/digests and the exact shared
binding. Require signer-role separation and reject missing, duplicate, foreign
or unbound signatures.

### P1-03 — `not_executed` fixture can be confused with complete acceptance

The proposal allows EHP-04 to contain a structured foreign-owner fixture receipt
“or explicit `not_executed` deferral” (`contract_patch_proposal.md:34-37`) while
also defines an all-four completeness predicate and atomic `accepted_all`
decision (`contract_patch_proposal.md:39-47`). R2 explicitly classifies an
unavailable foreign-owner fixture as `typed_absence/terminal_deferred` and does
not allow it to satisfy authority. Without an explicit implication that
`not_executed` forces set status `terminal_deferred` and forbids
`accepted_all`/promotion, a syntactically complete four-packet set could be
mistaken for a successful closure.

Required closure: make fixture status part of the derived set decision;
`not_executed` may be carried for bookkeeping only and must force
`accepted_all=false`, `terminal_deferred`, `no_publish`, and no authority credit.
Only an owner/ACL/command/exit/UTC/stream-hash receipt under the declared
privilege boundary can make that sub-obligation present.

### P2-01 — Recovery does not define fresh replay identity

The proposal says repair requires a fresh complete signed set and unchanged
inputs forbid a new AD/S3 rerun (`contract_patch_proposal.md:49-53`), but does
not specify which identifiers must be fresh after partial/mismatched/stale
responses, nor how sequence, nonce and idempotency conflict are handled. A
repair could accidentally reuse a consumed nonce or collide with an earlier
bundle while still being called “fresh”. Require an explicit recovery matrix:
new request/bundle ID and nonce when policy requires it, strictly valid
sequence/idempotency behavior, and a preserved link to the rejected set.

### P2-02 — Independent-review receipt is not itself closed/bound

The proposal lists reviewer identity/separation, verifier/hash, recomputed
hashes and raw receipt paths (`contract_patch_proposal.md:39-47`), but does not
require a signed review receipt, exact set/request digest in its preimage, raw
receipt hashes (rather than paths only), or a closed result taxonomy. A path
string or unsigned report is bookkeeping and must not be an acceptance proof.
Require a canonical, signed review receipt bound to the set receipt and all
four packet digests, with `accepted_all`/`rejected_all`/`terminal_deferred`/
`fail_closed` derived from recomputed outcomes.

### P2-03 — “Atomic ack” lacks receiver transaction/quarantine semantics

The proposal forbids partial acceptance but does not say when the receiver may
emit `accepted_all`, whether all packet bytes are durably quarantined before
the ack, or how per-packet receipts are withheld from promotion after a set
failure. Add an explicit state machine: receive complete raw set, verify all
four, durably retain raw bytes, then emit exactly one set decision; any timeout,
missing packet or mismatch yields `rejected_all`/`fail_closed` (or typed absence
when no channel exists) and never partial promotion.

### P2-04 — Closure requirements remain prose, not an enforceable schema

The packet-closure bullets are well-directed (`contract_patch_proposal.md:23-37`)
but do not identify exact field names, closed nested objects, cardinalities,
unknown-key behavior, or cross-reference constraints. This is especially
material for the already scalar EHP-03 edge placeholders and EHP-04 import/SBOM
maps. Keep the additive design, but publish a versioned JSON schema plus a
deterministic verifier contract before implementation.

### P2-05 — Repeating full source closure in every packet is not minimal

The proposal requires every packet to repeat HEAD/tree and dirty closure
(`contract_patch_proposal.md:15-18`). That is safe if actually signed, but it
duplicates the large EHP-03 source identity and creates another drift surface.
The minimum secure form is one shared binding containing the source-identity
digest/closure reference, repeated and signed by each packet; EHP-03 alone
contains the full HEAD/tree/dirty/untracked/submodule object. If full repetition
is retained, exact byte equality and duplicate-field canonicalization must be
specified.

## Proposal assessment

The patch is additive and preserves the important boundaries: no R2 rewrite,
no local spool as authority, no system-store trust, explicit fail-closed
language, and no new AD/S3 action on unchanged frozen inputs. It does not itself
create a key, owner, endpoint, certificate, signature, receipt, candidate, or
authority credit. Those are positive properties.

It is not yet “minimal and sufficient” as a contract because the central
atomicity and authority-binding portions are stated as prose. Address P1-01
through P1-03 first; then close P2-01 through P2-04. P2-05 is a simplification
recommendation, not a reason to weaken binding. Until then, retain the overall
R3 decision as `not_ready_for_one_shot_external_delivery` and preserve all
typed-absence/no-publish semantics.

## Review execution receipt

- Repository: `D:\006-Programing\LMC\FusionConceptAI`
- Reviewed HEAD: `b2c04d8339774635aaecd73651efcdb101e01b5d`
- Independent command: `python -B -` (in-memory JSON parse/count/type/key/hash checks)
- Independent command PID: `102192`
- Independent command UTC: `2026-09-16T22:01:35.733860Z`
- Independent command exit: `0`
- Raw stdout: `raw/independent_static.stdout.raw`, `raw/schema_gap_check.stdout.raw`
- Prior R3 raw validation receipts: `../01-collection-readiness-audit/raw/*.raw|*.txt`
- No network/external send; no AD/S3/Julia/DESC/solver; no production test execution.

The independent command output and schema-gap probe are preserved verbatim in
`raw/`. The hash manifest records all review files and the frozen inputs used
for the conclusions; its own hash is excluded to avoid a self-reference.
