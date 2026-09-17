# Integration acceptance gates

These are cumulative gates for a future implementation. The presence of this
document is not evidence that any gate passes.

| Gate | Required evidence | Failure state / consequence |
|---|---|---|
| `G0-SCOPE` | Only this additive contract directory changes; no 39-DAG, R01–R10, source, test, registry, AD, credential, or heavy-lane mutation | Scope violation → reject the integration package |
| `G1-R3-WIRE` | R3 schema, canonical preimage, EHP-01..04 order, packet/set/review digests, and exact raw-byte CAS receipt all agree | Any mismatch → `rejected_all`; no partial packet survives |
| `G2-R4-LOCAL-SEAMS` | Each R4 module emits its documented typed shape and retains input/output hashes and errors | Missing seam or untyped exception → `fail_closed`; local pass is not authority |
| `G3-CROSS-BINDING` | One candidate/source/run/request/bundle scope; source-axis, G2, environment, trust, freshness, and R3 refs all match exact digests | Foreign or stale binding → `fail_closed` |
| `G4-ALL-OR-REJECT` | A set is admitted only as one decision after every packet/material/receipt is checked | Any member failure → `rejected_all`; no per-member promotion |
| `G5-CAS-RECEIPTS` | Raw bytes are durably quarantined before verification; bundle/set/review and replay receipts bind to that CAS object; ledger CAS uses expected hash/version and lock | Unbound receipt, collision, replay, or CAS conflict → unchanged state plus typed failure |
| `G6-LOCKS` | Every aggregate and receipt states `formal_credit=none`, `authority_credit=false`, `no_publish=true` | Any attempted lock clear → `PUBLICATION_LOCK` / fail closed |
| `G7-EXTERNAL-PRESENT` | Real external owner/channel response for all required EHPs; authenticated transport ACK; pinned trust root and valid chain/signature; trusted time, revocation, replay, independent reviewer separation | `typed_absent`/`typed_unverified`/local receipt → no recheck |
| `G8-SOURCE-ENV-G2` | Fresh observed source identity equals bound digest; raw `EXTERNAL_ISSUED` four-axis input has passed the separate external-authority adapter and is derived as `externally_verified`; all four axes are candidate/run/source bound; complete bijective G2 graph/mapping has external authority; environment has exact lock/freeze plus independently verified binary provenance | Missing/ambiguous/unverified material, `TEST_ONLY`, or local product → `terminal_deferred`; malformed/contradictory material → `fail_closed` |
| `G9-RECHECK-ELIGIBILITY` | T0 bytes and SHA remain unchanged; all G1–G8 receipts are fresh, mutually bound, independently reviewed, and no failure is present | Without this, `T1_go=false` and no recheck execution may start |
| `G10-T0` | Separate root-owned review accepts the checked-present recheck against the frozen T0 snapshot | Local contract/test pass does not grant T0 credit |
| `G11-T1` | T0 accepted, recheck accepted, candidate identity and authority receipts carried forward unchanged | T1 remains blocked if either predecessor is absent |
| `G12-T2` | T1 accepted and its own required evidence/authority gate passes | T2 cannot be inferred from T1 planning or implementation |

## External-input condition before recheck

The recheck may be called only if all of the following are true in one
immutable aggregate:

1. The complete R3 atomic bundle has one exact CAS raw-byte receipt and no
   structural, digest, decision, security, or reviewer error.
2. R4 intake has a real, authenticated channel/owner response for the required
   packet set; a local spool receipt, configured endpoint, or
   `real_channel=true` flag alone is insufficient.
3. Trust-chain verification has caller-pinned root bytes, valid ordered chain,
   allowed algorithms, validity/time checks, and a detached signature bound to
   the same payload; trust/revocation/time receipts are fresh and scope-bound.
4. Source-axis binding has a fresh observed source identity with identical
   digest to the bundle and exactly the required four candidate/run/source
   axis materials. Raw `EXTERNAL_ISSUED` is accepted only as the input to the
   separate external-authority adapter; that adapter must emit
   `externally_verified` with pinned trust, chain/signature, trusted time,
   revocation, freshness/replay, G2 and independent-review receipts. No
   `TEST_ONLY`, local fixture/product, typed absence, or source drift remains.
5. G2 forward/reverse evidence and mapping are non-empty exact bijections with
   no ambiguity and the same candidate/source/authority refs.
6. Environment closure has exact lock/channel freeze plus binary source,
   signature, download, SBOM, and build-recipe provenance, each independently
   verified or explicitly recorded as an external gap (a gap blocks recheck).
7. Freshness validation and replay CAS commit succeed for the same scope,
   nonce, sequence, idempotency key, canonical input digest, and result digest;
   no replay, sequence gap, stale window, or `cas_conflict` exists.
8. An independent reviewer is distinct from packet owners, channel receiver,
   and verifier publisher, and recomputes the same packet/bundle/set digests.

If any item is absent or unverified, return the unchanged T0 snapshot plus a
typed gap. Do not retry by mutating the old receipt. Supply fresh external
inputs and, for changed bytes, fresh bundle/request/nonce/sequence/
idempotency identity before a later recheck attempt.

## External source-axis state transition

The only positive source-axis route is:

```text
raw state=EXTERNAL_ISSUED
  + provenance_class=external_issued
  + exact candidate/source/run/four-axis bytes
  -> local structural and join checks
  -> external-authority envelope verification
  -> derived state=externally_verified
```

The derived state requires raw-byte retention and mutually bound receipts for
the trust root, ordered chain, signature, trusted time, revocation,
freshness/replay, G2, and independent review. `TEST_ONLY`, local observed
hashes, local spool/CAS receipts, system trust-store entries, and historical
or synthetic artifacts cannot enter this transition. If required bytes or
verification capability are unavailable, use `typed_absence` and
`terminal_deferred`; if bytes are present but authority/review is incomplete,
use `unverified` and `terminal_deferred`; if a contradiction is proved, use
`invalid` and `fail_closed`. The current R4 package emits none of these
positive external receipts, so G8/G9 and consequently T1/T2 remain blocked.

## Acceptance evidence required from a future implementation

The eventual implementation must provide deterministic focused tests for each
negative class, a two-run independent replay of the merge, raw stdout/stderr
and exit receipts, exact input/output hashes, and a review of this manifest.
Those artifacts are prerequisites for acceptance; they are not supplied by
this contract draft.
