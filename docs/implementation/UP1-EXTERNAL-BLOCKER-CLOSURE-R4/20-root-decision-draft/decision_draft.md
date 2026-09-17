# UP1 external-blocker closure R4 — root decision draft

> **State: `decision_draft_pending_root_acceptance`**  
> This is a proposed root-owned scope decision. It is not a root acceptance,
> formal gate closure, external authority receipt, publication permission, or
> parent-goal closure.

## Proposed decision

| Scope | Proposed disposition | Meaning |
|---|---|---|
| Software | `PASS_LIMITED / ACCEPT_FOR_LOCAL_INTEGRATION` | The frozen local R4 seam and its negative/lock behavior are suitable for local integration within the declared offline scope. |
| Formal / external | `BLOCKED_NO_CREDIT` | No external authority, formal credit, publication permission, T0, T1, or T2 credit is present. |

The proposed decision is deliberately split. Local software evidence is not
promoted into external, physical, engineering, or parent-goal evidence.

## Frozen evidence basis

- R4 external scan: `26/26 typed_absent`, `usable_external_inputs=0`, no fresh
  delta in the checked locations, `new_ad=false`, `s3_rerun=false`.
- Final regression: R3 atomic focused suite `25 tests + 1 skipped`, exit 0,
  twice; R4 full tree `98 passed + 2 skipped`, exit 0, twice; static
  compile/import boundary passed.
- Source/test freeze: all `48` hashed Python files are unchanged
  (`before_count=48`, `after_count=48`, `changed=[]`, `missing=[]`,
  `added=[]`).
- The two former software P1 findings are closed in the local implementation:
  cross-stage binding conflicts fail closed and lexical reparse/TOCTOU checks
  are ordered and fail closed. Windows reparse runtime creation is still
  deferred, and R22 direct-wire acceptance is still incomplete.
- No network, external channel, Julia/DESC, solver, heavy lane, T0, or S3 was
  executed.

## Finding count and unresolved items

| Priority | Count | Current item | Required recovery |
|---|---:|---|---|
| P0 | 0 | None. | No P0 action. |
| P1 | 0 | No current software P1. | Keep the two repaired behaviors under regression; do not reclassify local passes as authority. |
| P2 | 1 | **P2-001 Windows reparse runtime** remains `test_scope_deferred`. | An authorized Windows host must create the relevant junction/symlink/reparse fixture and retain independent raw stdout/stderr, exit, and hash receipts. |
| P2 | 1 | **P2-002 R22 direct-wire** remains incomplete because the full wire envelope has the quarantine raw-digest self-reference limitation. | Repair or replace the direct-wire envelope with a fresh, non-self-referential raw digest and repeat the predicate/wire acceptance evidence. |

## Gates and authorizations that remain closed

The following are not passed by this draft or by the local regression:

- G7 external-present: no authenticated external owner/channel response for
  EHP-01..04;
- G8 source/environment/G2: no externally verified four-axis materials,
  candidate-bound lineage, authoritative G2 mapping, or independently
  verified environment/binary provenance;
- G9 recheck eligibility: no fresh mutually bound external receipts;
- G10/T0, G11/T1, and G12/T2: not authorized and not executed.

Accordingly, do not create a new AD, do not run S3, and do not change the
39-node DAG, R01–R10, or the parent goal. `T0_go=false` and `T1_go=false`
remain in force; T2 is consequently also not eligible. This draft does not
authorize any runtime or heavy-lane action.

## UP1 stage-by-stage handoff

Each row records the capability increment that can be handed to the next
local owner, the gate that is still not crossed, the responsible role, and the
condition for recovery. “Owner” names are role labels from the frozen
contracts; they are not verified external identities.

| UP1 stage | Capability increment handed over | Gate/not passed | Responsible party | Recovery condition |
|---|---|---|---|---|
| UP1-00 | Bounded R4 scan and absence inventory. | Fresh external material is absent: 26/26 typed absent. | External channel/intake owners. | Supply a fresh complete candidate-bound EHP set through a real authoritative channel. |
| UP1-01 | EHP-01..04 atomic input contract, typed-state taxonomy, and no-substitution rules. | G7 and authority transition to `externally_verified` are not crossed. | EHP owners, PKI/trust administrator, independent reviewer. | Deliver all four ordered packets plus signed set/review receipts and raw-byte hashes. |
| UP1-02 | Additive seven-stage integration contract and publication locks. | Contract presence is not integration or formal acceptance. | Root integration owner. | Root-owned acceptance after evidence satisfies the contract; no lock clearing by local tests. |
| UP1-03 | Environment closure observation, provenance boundary, and fail-closed path handling. | Candidate-bound environment/binary provenance and Windows reparse runtime are absent. | Environment/SBOM and binary-provenance owners. | Complete independently verifiable lock/channel, provenance, SBOM, and reparse-capable retest. |
| UP1-04 | Authoritative-intake structural boundary and quarantine/no-overwrite behavior. | No real owner acknowledgement or authenticated channel ACK. | Authoritative channel owner and intake operator. | Fresh authenticated transport, ACK/rejection receipt, and retained raw response. |
| UP1-05 | Freshness, trusted-time, replay, nonce/sequence, and CAS fail-closed checks. | External trusted time/revocation/replay authority is absent. | PKI, TSA/time-policy, revocation, and replay-ledger owners. | Fresh scope-bound signed time, revocation, nonce, sequence, idempotency, and CAS receipts. |
| UP1-06 | Predicate dispatch/absence instrumentation and negative boundary coverage. | R22 direct-wire acceptance remains P2/test_scope_deferred. | Predicate and external-wire owners. | Produce a fresh non-self-referential R22 envelope and repeat direct-wire acceptance. |
| UP1-07 | Candidate/source-bound G2 graph and mapping validation with structural inverse checks. | No externally authoritative, signed G2 mapping. | G2 mapping authority and independent attestor. | Complete signed bijective forward/reverse graph and mapping bound to candidate/source/run. |
| UP1-08 | Pinned-root chain, signature, time, algorithm, and revocation verification behavior. | No project trust root, external chain, or signed authority receipt. | Project PKI/trust administrator and attestor. | Publish fresh pinned root/policy, ordered chain, signature, trusted time, and revocation evidence. |
| UP1-09 | Source-axis binding, identity joins, drift detection, and non-evidence ceiling. | No fresh external source identity or four-axis material. | Source authority and independent attestor. | Supply same-candidate lineage/source digest and rebuild all downstream receipts on drift. |
| UP1-10 | G2 repair closes duplicate/unknown/alias/forged-field negative cases. | Positive external G2 authority remains deferred. | G2 authority/attestor. | Repeat the repaired validator against a fresh externally issued and independently reviewed bundle. |
| UP1-11 | Trust-chain repair gives explicit typed absence for missing evaluation time and preserves fail-closed checks. | Local cryptographic tests do not grant external trust. | PKI/time/revocation authority. | Fresh external trust/time/revocation receipts bound to exact payload bytes. |
| UP1-12 | Intake repair passes the focused local suite twice and preserves the no-publish ceiling. | Authenticated external send/ACK remains absent. | Channel owner and root intake reviewer. | Obtain and independently review a real channel exchange; retain raw response and receipts. |
| UP1-13 | Seven-stage offline orchestrator seam, typed-absent propagation, and lock preservation. | Local seam result is not G7–G9 or formal credit. | Root integration owner. | Root acceptance only after external bundle, trust, G2, environment, and replay receipts are complete. |
| UP1-14 | Canonical stage order is independently retested and aligned with the contract. | Ordering pass does not authorize execution. | Integration owner and independent reviewer. | Preserve the frozen order and attach it to a fresh accepted aggregate. |
| UP1-15 | Earlier full regression and 45-file hash closure. | Offline regression has no external authority or parent-goal effect. | Regression owner. | Re-run only after a separately authorized scope change; keep source/test hashes closed. |
| UP1-16 | Reparse/TOCTOU repair passes static and ordinary-file checks with typed failure paths. | Windows reparse runtime remains P2/test_scope_deferred. | Windows environment owner. | Run on a host permitting the relevant reparse fixture; retain raw and independent receipts. |
| UP1-17 | First cross-binding repair exposes all 15 tuple fields and hard conflict behavior. | Three public conflict fields failed the first repair retest; superseded, not accepted. | Integration implementation owner. | Use the UP1-18 repair result; do not reuse the UP1-17 fail-limited receipt as closure. |
| UP1-18 | Second binding repair passes the complete 33-test integration package twice and leaves conflict fields unset. | Software-only local acceptance; no external/formal credit. | Integration implementation owner and independent reviewer. | Keep source/test bytes frozen and obtain root acceptance for local integration only. |
| UP1-19 | Final two-run R3/R4 regression, static boundary check, and 48-file unchanged hash closure. | Formal/external remains blocked; T0/T1/T2 are not authorized. | Root owner for scope decision; external owners for missing material. | Root may sign only this split decision; later gates require fresh external evidence and a new decision. |

## Root acceptance checklist

Root acceptance, if granted, should sign only the split disposition above and
the local handoff boundary. It should preserve the exact marker
`decision_draft_pending_root_acceptance` until that signature is recorded, and
must not alter source, tests, the 39-node DAG, R01–R10, AD/S3 state, or the
parent-goal status.

Evidence sources are the frozen `00-external-delta-scan`, `01`–`02` contracts,
`16`–`19` retests/regression, and
`reviews/19-final-independent-review-r2/review.md`. The machine-readable
decision and hash manifest in this directory are the canonical handoff
artifacts for this draft.
