# AD-31 status repair R2: canonical work-order and validation sync

Date: 2026-09-15  
Repository: `D:\\006-Programing\\LMC\\FusionConceptAI`  
HEAD observed: `4b69f55f7f80240147a65a22809dc1207824dde2`

## Purpose and decision

This is a limited documentation synchronization record responding to the
independent AD-31 status review R1. It preserves the R1 audit, R2 proposal and
R3 proposal/review as historical records. It does not implement the
realization source-edit slice and does not change the accepted AD-31 scope.

The canonical machine node is
`UP1-04A-VNEXT-G3-REALIZATION-EDIT-PREC`. It remains
`planned`/`proposal`/`accepted=false`/`review_pending`, is a parallel
contract-only precursor beside T0, and has no edge that can complete T0, T1,
T2 or the `UP1-04A-VNEXT` aggregate gate.

## Canonical naming reconciliation

R3's earlier suggested names are retained in the R3 proposal and are mapped
here to the single machine-owned file set:

| R3 historical suggestion | Canonical AD-31 machine name |
|---|---|
| `UP1-04A-VNEXT-G3-REALIZATION-SOURCE-EDIT-R3` | `UP1-04A-VNEXT-G3-REALIZATION-EDIT-PREC` |
| `src/GenomeV5/G3/G3RealizationSourceEditV1.jl` | `src/GenomeV5/G3/G3RealizationChildEditabilityV1.jl` |
| `test/GenomeV5/G3/g3_realization_source_edit_v1_tests.jl` | `test/GenomeV5/G3/g3_realization_child_editability_v1_tests.jl` |
| `docs/implementation/UP1-04A-VNEXT-G3-REALIZATION-SOURCE-EDIT-R3/` | `docs/implementation/UP1-04A-VNEXT-G3-REALIZATION-EDIT-PREC/` |

The canonical names are now identical in AD-31 acceptance, core 18, core 16,
the core and implementation indexes, and `task_manifest.json`. No file is
renamed or deleted; the historical R3 text remains byte-preserved.

## Scope and status checks

The canonical future implementation owns only the new source, test and
same-ID archive listed above. Its contract remains realization-only: closed
typed source body, typed parent G3 declaration ref/hash, additive child
contract identity, closed provenance or typed absence, separate five-hash
layers, fixed `replace_source_payload`, and separate
`contract_admission`/`physical_resolution` statuses. Control, binding and
feedback are excluded. T0 is neither imported nor redefined. Old V5,
`CandidateStatePackageV5`, registry, core receipts and historical evidence
remain read-only.

## Actual validation receipts

The following checks were executed after the canonical synchronization:

| Check | Command | Exit | Result |
|---|---|---:|---|
| Task manifest JSON | `python -m json.tool docs/v4_multitopology_generation/task_manifest.json` | 0 | parsed successfully |
| AD-31 manifest JSON | `python -m json.tool docs/implementation/AD-31/manifest.json` | 0 | parsed successfully |
| Plan and link validator | `python docs/v4_multitopology_generation/validate_plan.py` | 0 | `markdown_files_checked=31`, `relative_links_checked=391`, `task_count=35`, `task_dag_acyclic=true`, `sol_prompt_characters=493`, `errors=[]` |
| Scoped whitespace check | `git diff --check -- docs/v4_multitopology_generation/18_sources_and_architecture_decisions.md docs/v4_multitopology_generation/16_execution_work_orders.md docs/v4_multitopology_generation/README.md docs/implementation/README.md docs/v4_multitopology_generation/task_manifest.json docs/implementation/AD-31/acceptance.md docs/implementation/AD-31/manifest.json docs/implementation/AD-31/status_repair_r2/` | 0 | no blocking diff-check output |

The plan validator's `relative_links_checked=391` is the recorded lightweight
link evidence. No Julia, DESC, provider, mesh, solver, engineering or
physical command was run. These document checks do not accept the future
implementation or an actual child.

## Evidence ceiling

AD-31 remains `accepted_limited` for architecture/work-order scope only. The
implementation node remains `accepted=false`; actual child authority, T0/T1
mapping, provider, mesh, engineering, physical, search, B00/B04 and R01–R10
remain false. This repair only makes the names and validation receipts
reviewable before dispatch.
