# AD-30 status and DAG independent review R3

- `review_id`: `AD-30-independent-status-review-r3`
- `reviewer`: different Luna/high
- `review_date`: `2026-09-15`
- `verdict`: `changes_requested`
- `review_scope`: read-only review of AD-30 acceptance_r2, the active DAG, core indexes, GI1B limited scope, and current static evidence

## Verdict

The AD-30 R2 limited architecture acceptance is substantively bounded correctly:
it preserves the lossless VNEXT contract, keeps T0/T1/T2 as unaccepted planned
work, keeps the old V5/package/registry/receipts read-only, and grants no
provider, mesh, engineering, physical, search, B00/B04, or R01-R10 credit.
The machine task manifest currently has the requested dependency route:

`UP1-04A + {UP2-01-G1-DIFFUSION-V1, UP2-01-G2-METRIC-BOUNDARY-V1, UP2-01-G3-SOURCE-FEEDBACK-V1} → T0 → T1 → T2 → UP1-04A-VNEXT → UP2-00`.

The review cannot be `pass_limited` because the core architecture decision
document and implementation index still contain stale or contradictory status
text. These are documentation/index synchronization defects that must be
repaired before the AD-30 status is treated as internally coherent. No source,
test, Julia, DESC, provider, mesh, or physical execution was performed.

## Checks that pass

1. `python docs/v4_multitopology_generation/validate_plan.py` exited `0` on the
   current checkout: 31 Markdown files, 367 relative links, 34 tasks, and an
   acyclic DAG. `python -m json.tool` exited `0` for the current task manifest
   and AD-30 R2 evidence manifest. The current DAG rows were read directly from
   `docs/v4_multitopology_generation/task_manifest.json`:

   - `UP1-04A` depends on `UP1-01 + UP1-02 + UP1-03` and is
     `accepted=true` only for its limited contract scope.
   - G1/G2/G3 V1 each depend on `UP1-01 + UP1-02 + UP1-03` and remain
     `planned`, `accepted=false`, `resolution=review_pending`.
   - `UP1-04A-VNEXT-T0` depends on `UP1-04A + G1 + G2 + G3` and remains
     `planned`, `accepted=false`.
   - T1 depends on T0, T2 depends on T1, `UP1-04A-VNEXT` depends on T2, and
     `UP2-00` depends on `UP1-04A-VNEXT`; each remains `accepted=false`.

2. The active work-order section in
   `docs/v4_multitopology_generation/16_execution_work_orders.md:294-365`
   agrees with the manifest. It states that the existing
   `UP1-04A-VNEXT` node is a post-T2 aggregation and independent-review gate,
   not a duplicate implementation of T0/T1/T2. It also preserves the later
   UP2-00, UP1-04B, B00/B04, and physical evidence gates.

3. The AD-30 R2 acceptance and its manifest correctly state
   `accepted_limited`, `execution_authorized=false`, T0/T1/T2 unaccepted, and
   all credit flags false. The acceptance conditions correctly retain the typed
   G2 candidate envelope, independently sourced four axes, and G3 complete
   declaration-body hash requirement.

4. The current GI1B archive is itself bounded correctly:
   `docs/implementation/UP2-00G-I1B-SOURCE-ENVELOPE/acceptance.md` and its
   evidence manifest report only actual-A source-envelope software behavior and
   typed authority-gap handling. They explicitly keep N06 actual authority,
   UP2-total, B00/B04, compiler, provider, mesh, solver, engineering, physical,
   current-A readiness, and R01-R10 outside the accepted scope. The manifest's
   credit boundary is consistent with those statements.

## Changes requested

### 1. Remove or label stale direct DAG text in the architecture decision index

`docs/v4_multitopology_generation/18_sources_and_architecture_decisions.md:256-260`
still presents the AD-28 route as

`UP1-01/02/03 → {G1,G2,G3} → UP1-04A-VNEXT → UP2-00 ...`

and `:272` repeats the same direct route under AD-29. The later AD-30 section
(:276 onward) and the current work order/manifest correctly insert
`UP1-04A → T0 → T1 → T2 → UP1-04A-VNEXT`. The older lines may remain as a
historical AD-28/AD-29 baseline only if they are explicitly labelled
superseded and linked to AD-30; otherwise they contradict the active dependency
contract and can dispatch work around T0/T1/T2.

The README also retains older direct-chain statements at
`docs/v4_multitopology_generation/README.md:71,77`. Its newer active route at
`:105-107` is correct, but the earlier wording should be labelled historical
or rewritten so the core index has one unambiguous active DAG.

### 2. Synchronize the implementation index for GI1B

`docs/implementation/README.md:65` still says the GI1B “local acceptance
archive” is pending and links only focused R5 and independent postrun R5.
That is stale: the archive now contains `acceptance.md`,
`evidence_manifest.json`, and `independent_acceptance_r3/report.md`, with
`accepted_limited` already recorded. Update the row to link the current
acceptance and R3 review, while preserving the exact limited scope and all
false credit boundaries. This is an index synchronization repair only; it must
not upgrade GI1B into N06 authority, UP2 total, B00/B04, provider, mesh,
engineering, physical, or R01-R10 credit.

## Current hash and evidence snapshot

The directly recomputed current SHA-256 values are:

| path | bytes | SHA-256 |
|---|---:|---|
| `docs/v4_multitopology_generation/README.md` | 27830 | `8d76d1ade5963574b572dc3fcd6a726383b6a879658a396eaca1a05a28d1d367` |
| `docs/v4_multitopology_generation/16_execution_work_orders.md` | 73348 | `011533c4c174feb77636aab3d96d5b3d05457d7eaae26f3d52db08a622809280` |
| `docs/v4_multitopology_generation/18_sources_and_architecture_decisions.md` | 57032 | `8e40f19055512661c991408fa33d1c2f27f1b24a087cd44cd306ced8ec907f4f` |
| `docs/v4_multitopology_generation/task_manifest.json` | 63912 | `b149ffa8a725c2a8e9c62bcd3c81becbca92bae9e3b49b3eef9360aef4a9fab5` |
| `docs/implementation/README.md` | 14387 | `d21c82db64c4aff0679f93a51843ec1e326ea49ba126f81667a776d74192cd67` |
| `docs/implementation/UP2-00G-I1B-SOURCE-ENVELOPE/acceptance.md` | 3030 | `612cebd62c36da0782c6e08d26e183f1e0df778de7d77eebd36e3795d1ca45a1` |
| `docs/implementation/UP2-00G-I1B-SOURCE-ENVELOPE/evidence_manifest.json` | 5226 | `35c71012ba44d98de3426ff008625df1ea35f2e6e62aefcf3304e822aa41904f` |

The worktree was already dirty; concurrent status drift is not attributed to
this review. Only this review directory is owned by this task. The required
core/index repairs should be performed by the root scheduler through a separate
status-sync task, then independently rechecked.
