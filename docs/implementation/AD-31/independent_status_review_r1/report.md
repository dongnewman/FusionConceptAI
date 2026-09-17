# AD-31 core and machine work-order synchronization: independent review R1

Date: 2026-09-15  
Repository: `D:\\006-Programing\\LMC\\FusionConceptAI`  
HEAD observed: `4b69f55f7f80240147a65a22809dc1207824dde2`  
Reviewer: different `gpt-5.6-luna` / high

## Verdict

`changes_requested`; `accepted=false`; `review_pending=true`.

The AD-31 synchronization is substantively correct on status, dependency
boundary and evidence ceiling: the machine node is `planned`/`proposal`/
`accepted=false`; it depends on the G3 V1 preparation and records AD-31 as its
architecture input; it is parallel to T0 without importing or redefining T0;
and T0/T1/T2 remain separate `planned`/`accepted=false` nodes. The realization-
only fixed `replace_source_payload` scope, typed identities/provenance,
source/state hash separation, dual status axes, excluded control/binding/
feedback work, old V5/package/registry read-only rule and all false credit
flags are present.

One material synchronization defect remains: the reviewed R3 proposal names a
different implementation file set and work-order ID from AD-31, core 18/16,
the implementation index and `task_manifest.json`. A second, lower-severity
metadata defect leaves the AD-31 manifest's own post-sync validation fields at
`pending_after_all_core_sync` even though the independent JSON, plan, link and
diff checks now pass. Resolve the file naming/identity conflict and refresh
that validation metadata before dispatching the implementation node.

No Julia, DESC, provider, mesh, solver or physical command was run.

## Synchronization checks that pass

The AD-31 acceptance and manifest consistently limit acceptance to the
architecture and finite work-order boundary. The acceptance record says the
implementation and actual child remain unaccepted and keeps provider,
engineering, physical and downstream credits false. The manifest has
`status=accepted_limited` only at the architecture record, while its work order
is `planned`, `scope_status=proposal`, `accepted=false`, `claim_ceiling=contract_only`.

The machine task
`UP1-04A-VNEXT-G3-REALIZATION-EDIT-PREC` at
`task_manifest.json:443-479` has the same planned/proposal/false status. Its
machine dependency is only `UP2-01-G3-SOURCE-FEEDBACK-V1`; AD-31 is correctly
bound as a non-task architecture prerequisite through `architecture_decision_ref`
and the task input string. It is therefore not inserted into the DAG as a
fake task dependency. The manifest records `parallel_to=UP1-04A-VNEXT-T0`.

The current DAG audit gives:

`G3 V1 -> AD-31 contract boundary -> realization precursor`, in a side lane,
while the main VNEXT route remains
`UP1-04A + G1/G2/G3 -> T0 -> T1 -> T2 -> UP1-04A-VNEXT -> UP2-00`.

The machine records for T0, T1, T2 and the post-T2 aggregate are all
`planned`/`proposal`/`accepted=false`/`review_pending`; no AD-31 edge closes,
replaces or bypasses them. The core README and architecture decision repeat
that AD-31 cannot complete T0/T1/T2 and does not grant implementation, actual
child, T0/T1 mapping, provider, mesh, engineering, physical, search, B00/B04
or R01-R10 credit. The implementation index links the same acceptance,
manifest, R3 proposal and independent R3 review.

The synchronized contract text preserves the required first slice: a closed
typed realization source body, typed parent G3 declaration ref/hash, additive
child contract identity, closed four-slot provenance or typed absence,
independent source-record/source-content/initial-state/operation/state hashes,
fixed atomic `replace_source_payload`, stale source/state `fail_closed`, and
separate `contract_admission`/`physical_resolution`. Control, binding and
feedback children remain later work. Old V5/package/registry, historical
receipts and core planning semantics are explicitly read-only.

## Blocking synchronization defect: file and work-order identity

The R3 proposal uses:

* `src/GenomeV5/G3/G3RealizationSourceEditV1.jl`;
* `test/GenomeV5/G3/g3_realization_source_edit_v1_tests.jl`; and
* `docs/implementation/UP1-04A-VNEXT-G3-REALIZATION-SOURCE-EDIT-R3/`,
  with suggested ID `UP1-04A-VNEXT-G3-REALIZATION-SOURCE-EDIT-R3`.

AD-31 acceptance, core architecture/work-order text, the implementation index
and the machine manifest instead freeze:

* `src/GenomeV5/G3/G3RealizationChildEditabilityV1.jl`;
* `test/GenomeV5/G3/g3_realization_child_editability_v1_tests.jl`; and
* `docs/implementation/UP1-04A-VNEXT-G3-REALIZATION-EDIT-PREC/`,
  with ID `UP1-04A-VNEXT-G3-REALIZATION-EDIT-PREC`.

These are not equivalent paths for a file-owned work order. An implementer
following the R3 proposal can write a different file set from the one protected
by AD-31 and the task manifest, while a reviewer following the manifest can
miss the R3-owned paths. This violates the requested single ownership gate.

Before dispatch, the architecture owner must choose one canonical file set and
one task ID, then record the R3-to-AD-31 rename explicitly in the acceptance or
proposal history. The chosen names must match in AD-31 acceptance, AD-31
manifest, core 18, core 16, implementation README and task manifest. No source
or test should be created as part of this status review.

## Validation metadata requiring refresh

The AD-31 manifest's `protected_core_after_sync` hashes exactly match the
current five core files. That proves the recorded sync snapshot is current.
However, its `validation` object still says `json_tool`, `plan_validator` and
`link_check` are `pending_after_all_core_sync`. This is stale after the checks
performed for this review. It does not change the task status or grant any
implementation credit, but the acceptance archive should either record these
actual receipts or explicitly state that the independent R1 report owns them.

## Independent lightweight evidence

The following checks were run from the repository root:

* `python -m json.tool docs/implementation/AD-31/manifest.json`: exit `0`;
* `python docs/v4_multitopology_generation/validate_plan.py`: exit `0`,
  31 Markdown files, 384 relative links, 35 tasks and an acyclic DAG;
* `git diff --check`: exit `0` (only normal LF/CRLF conversion warnings);
* all acceptance/manifest/proposal/review links named by AD-31 exist; and
* every value in the AD-31 manifest `credits` object is `false`.

Recomputed current hashes are:

| path | bytes | SHA-256 |
|---|---:|---|
| `docs/implementation/AD-31/acceptance.md` | 2422 | `846e2d76d498657c517aeaba2750c3fb9e185efe7d6669e851a4d109ec6506ba` |
| `docs/implementation/AD-31/manifest.json` | 4081 | `578e5c696bc9efcc2b4d58ca2ef088afa7bc538a14a2676bde7e7d19d969be69` |
| `docs/v4_multitopology_generation/README.md` | 29839 | `0fabc88c530c61dc561750313fb8b213e164e48520f072e06ca484fe630590d5` |
| `docs/v4_multitopology_generation/16_execution_work_orders.md` | 76318 | `7dfb31d718ff24dcac5554dcc388f8c947bbd70fd23b219e17596cd79dac5e61` |
| `docs/v4_multitopology_generation/18_sources_and_architecture_decisions.md` | 60153 | `2c68142ec7c5835a208a9cd192f6e2ca8463a2081b35ca4bfd7ba918917f9ebc` |
| `docs/implementation/README.md` | 15122 | `dec3861bd3d1f0becb9ed200b96791f0bb6e9de4fea1df304e3cb1a39b1cbc82` |
| `docs/v4_multitopology_generation/task_manifest.json` | 66914 | `e05ffba7ac21b8aec2485e25e06aa60acd5e2e6543798826ac63aa5f7ce4b25a` |
| `docs/implementation/AD-30/g3_children_editability_audit/repair_r3/revised_proposal.md` | 11732 | `7026596ca52d5ece571ada5515689fdc0251e67f73e6f9c525a34e80ee45022c` |
| `docs/implementation/AD-30/g3_children_editability_independent_review_r3/report.md` | 7253 | `e15d68252517de196fd5f0c1bb37f029e7d2c2d7cb88158bbe118c50ff5cf9b4` |

The worktree contained 305 porcelain rows at the pre-write snapshot. This
review does not attribute concurrent dirty changes to AD-31 or modify them.
All R01-R10 obligations remain present, and no credit is promoted by these
static checks.

