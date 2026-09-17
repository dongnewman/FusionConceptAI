# UP1 external-blocker closure R4 — root-decision draft independent review R1

Review date: 2026-09-17 (Windows, read-only). I inspected the 20 root-decision
draft, the 00–19 evidence directories, `reviews/19-final-independent-review-r2`,
the final run manifest, the 26-input contract/inventory, the integration-gate
contract, and the current 39-node plan. No draft, source, test, or prior review
was modified; only this review directory was written.

## Decision

**`changes_requested`**.

The proposed split disposition is substantively supported, but the draft has
one count contradiction that must be repaired before root acceptance:

- `decision_draft.json` declares `p2=2` and contains exactly two items,
  `P2-001` and `P2-002`.
- `decision_draft.md:41` labels the P2-001 row `count=2`, and `:42` labels the
  P2-002 row `count=2`. Read as a finding-count column, the table reports four
  P2 findings while the JSON and the prose say two.

Required repair is documentation-only: make each item row count `1`, or remove
the per-row count and retain a single explicit total of `2`; then refresh the
20-draft hash manifest. No change to source, tests, external status, or gate
state is requested.

## Independent consistency checks

### Regression and hash closure

The 19 final manifest agrees with the draft:

| Evidence | Observed | Draft | Result |
|---|---:|---:|---|
| R3 atomic serial runs | 2 runs; 25 tests; 1 skipped; exits 0,0 | same | match |
| R4 full serial runs | 2 runs; 98 passed of 100; 2 skipped; exits 0,0 | same | match |
| static compile/import | 1 run; exit 0; 48 AST compile and 11 imports | boundary PASS | match |
| source/test closure | before 48, after 48, changed/missing/added empty | same | match |

The two files listed by `20-root-decision-draft/hash_manifest.json` each match
their recorded byte length and SHA-256. The final `hash_comparison.json` also
reports `unchanged=true` with 48/48 files.

### External absence and formal boundary

The 00 inventory and 01 contract both report `count=26`,
`typed_absent_count=26`, and `usable_count=0`. The bounded scan is explicitly
not a global remote-channel claim. Its disposition remains
`terminal_deferred -> no_publish`, with `new_ad=false` and `s3_rerun=false`.

The draft correctly preserves `formal_credit=none`, `authority_credit=false`,
`no_publish=true`, and false network, Julia/DESC, heavy-lane, T0, T1, and T2
authorization/execution flags. It does not turn local software passes into
external authority, physical, engineering, or parent-goal credit.

### Gate order and typed-state rules

The 02 gate contract is cumulative. The draft's not-passed list preserves the
required order: `G7-EXTERNAL-PRESENT` -> `G8-SOURCE-ENV-G2` ->
`G9-RECHECK-ELIGIBILITY` -> `G10-T0` -> `G11-T1` -> `G12-T2`.
The absence of G7/G8 keeps G9 closed; consequently T0/T1/T2 remain neither
authorized nor executed. The draft also preserves the R22 limitation (clean
semantic EHP-04 harness only; complete wire envelope has the quarantine
raw-digest self-reference issue) and the Windows reparse
`test_scope_deferred` state. No typed absence is silently upgraded to
`externally_verified`.

### 39-node DAG and R01–R10

The current `task_manifest.json` has 39 tasks. The read-only plan validator
returned `checks=pass`, `task_count=39`, `task_dag_acyclic=true`, and no errors.
Its output is planning validation only, not implementation or physics
acceptance. The manifest goal still enumerates R01 through R10,
`credible_candidate_count=0`, and `discovery_goal_achieved=false`; the current
README states that UP1 is not wholly accepted and R01–R10 remain open.

The retained `environment_gate.task_count_unchanged=false` field is explicitly
documented by AD-36 as the historical comparison with an earlier 31-task
baseline, not a current DAG mutation. The current live count/acyclic result
supports the draft's `dag_39_changed=false`; neither the draft nor this review
changes the manifest or R01–R10 ledger.

### UP1 handoff

The 00–19 stage handoff rows are consistent with the contracts and evidence:
UP1-00 carries the bounded absence scan; UP1-01/04/05/07/08/09 carry only
contract or local structural increments pending external owner/channel,
trust/time/revocation, G2, source-axis, and environment evidence; UP1-10/11/12
record repaired local behavior without authority; UP1-13/14 preserve the
offline seven-stage seam and ordering without execution authorization;
UP1-16 retains the Windows reparse gap; UP1-17 is correctly superseded by the
33/33 two-run UP1-18 repair; and UP1-19 is correctly limited to local final
regression plus a new root scope decision. Responsible parties and recovery
conditions are role labels and fresh-receipt conditions, not invented external
identities or credentials.

## Boundary conclusion

After the P2 table count is corrected, the draft is otherwise suitable for the
proposed `PASS_LIMITED / ACCEPT_FOR_LOCAL_INTEGRATION` software disposition
paired with `BLOCKED_NO_CREDIT` formal/external disposition. This review does
not authorize AD creation, S3, T0/T1/T2, source/test edits, DAG edits, or parent
goal closure.

## Evidence hashes

SHA-256 and byte lengths were recomputed for the principal inputs:

| Path | Bytes | SHA-256 |
|---|---:|---|
| `20-root-decision-draft/decision_draft.md` | 10218 | `5daed6fbed0374f9b96c4ac11555fbbd49e86bd42942493191e7c5602b3c9834` |
| `20-root-decision-draft/decision_draft.json` | 8598 | `969ca171e7ba2219f5315a09f10bee204f78fed78899b2652bb0f103516283ce` |
| `00-external-delta-scan/manifest.json` | 2280 | `6a50704624b7f7a7345812c49743187032d11779fb755c61b3d73191bb41ae3f` |
| `00-external-delta-scan/external_material_inventory.json` | 9939 | `642bea6650370acc8c5a3052abcb7264540ba9fd1bf831df163be216cc0b2421` |
| `01-external-input-contract/external_input_contract_r4.json` | 36200 | `a60a16bb82ac325764cab1f3a72619ebc1065c9ea82053e7961d622e37d1e9a0` |
| `02-integration-contract/integration-acceptance-gates.md` | 6900 | `aa5cb75c68d9c468ca2fd2a76b8a142d33798971fbea1a35743e3c8ab598cbf2` |
| `19-final-full-regression/run_manifest.json` | 5901 | `784c805285cf214bc84c3581adec43102d00cd581029068074789613aaac2e77` |
| `19-final-full-regression/hash_comparison.json` | 254 | `030ecc51efc8796ecbb4f797c6406b2878dab76cfc121f620048dae8c015109e` |
| `reviews/19-final-independent-review-r2/review.md` | 4840 | `2f37e14594e2c6c9d3fefe02a20a15150ff3538139c81f89f337c005f4047f10` |
| `docs/v4_multitopology_generation/task_manifest.json` | 91208 | `7d1700038f78dd1ea872cbc3fd6da29c5071596dae40d0c43b598b501195bae8` |

