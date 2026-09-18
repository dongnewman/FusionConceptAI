# Core index sync change report — 2026-09-18

Status: documentation-only working-tree update; no commit created. Root-agent
review is required before staging or committing. The R22 Julia receipt and the
DCCE Python receipts were read-only inputs to this synchronization; no
additional Julia/DESC runtime was run by the index update itself.

## Baseline and scope

The synchronized baseline is the existing checkout at HEAD `345bafb`. Only
status/index sections of these six files plus this change report were
changed:

- `docs/implementation/README.md`: refreshed the baseline and inserted the R22
  runtime and DCCE screen boundaries.
- `docs/v4_multitopology_generation/README.md`: synchronized the core planning
  index with the same R22 and DCCE boundaries.
- `docs/v4_multitopology_generation/16_execution_work_orders.md`: refreshed
  the non-runtime index-sync block with the ten-record wave index.
- `docs/v4_multitopology_generation/21_next_execution_batches.md`: synchronized
  the current T0/T1/G1-G2-G3/EngineeringFeedback execution boundary.
- `docs/implementation/INDEX-SYNC-20260918-change-report.md`: recorded this
  synchronization and its verification boundary.
- `docs/implementation/UP1-04A-VNEXT-T0-AUTHORITY-RECHECK-PREC/README.md` and
  `acceptance.md`: recorded the R22 runtime receipt, preserved the R21
  interrupted/incomplete history, and retained
  the typed-absent/accepted-false boundary.

The existing historical spatial narrative, navigation, work orders, and other
unrelated edits were preserved. The current boundary is explicit: R01–R10 are
`pending`, `L4=0`, the parent goal is open, and these receipts do not close any
UP label. No completion percentage is inferred.

## Exact wave receipt index

| Record | Commit | Receipt/status boundary |
|---|---|---|
| T0 LocalV1 | `87f0263` (`87f02636347a5d65d309f256b2d10914f39cc25a`) | committed |
| T0 authority recheck | `94e4598` / R21 | historical `interrupted_incomplete`; negative dispatch `0/25`; no retry; no authority published |
| T0 authority recheck | `345bafb` / R22 | `runtime_complete`; Julia `310/310`; `25` runtime negative dispatches; `accepted=false`; `contract_only`; no T1/T2 credit; `100 snapshots` static-only derivation |
| T1 package/edit/round-trip | `62d9a61` / R5 | static `16`; `prepared_not_executed`; no runtime receipt |
| Spatial composition | `e5e44bd` / R9 | `54/54`; `screen_only`; `accepted=false`; no formal credit |
| G1/G2/G3 execution | `7c82e95` / R22 | nested receipt authoritative: `39/39 + 13/13`; package manifest `preflight_only`; `screen_only`; no formal credit |
| UP2 spatial transfer | `ca5fef9` (`ca5fef9233fcd3f906485aedea6c107097830549`) | 70/70 `contract_only` |
| UP3 composition solve plan | `a1ad8cc` (`a1ad8ccfea6e2f1ac453ad31c86b24938e9378a2`) | 161/161 `contract_only` |
| UP4 SHIR | `5d9d651` (`5d9d6513b0d80bc2622597bc6e25a561b1f21b0f`) | 547/547 `prepared_not_measured` |
| UP4 engineering bridge | `5ea78c0` (`5ea78c0272273a474d88f83177f722773e973501`) | 189/189 `contract_only` |
| UP5 conditional egraph | `cd52ee3` (`cd52ee34978c642cf301fe2b1c5a7bf3cb392af2`) | `contract_only` conditional egraph; label not closed |
| UP5 bounded structure | `f9612bd` (`f9612bdef6752895363f0f5041df9192f667cf85`) | 94/94 `contract_only` |
| UP6 final ledger | `67a4e87` (`67a4e879ffc7e3d8956fd0fef11fc8865fed36d9`) | 123/123 `contract_only`; no final authority |
| UP2 executable screen | `348b061` (`348b0611b9c8afd20bab0fb706528733c3fa0d7d`) | 68/68 `manufactured_numerical_screen` |
| DCCE declared diffusion compile-execute | `09cf7d1` | Python static QA/oracle pass; `screen_only`; `accepted=false`; Julia not run; no UP2-01/R credit |
| EngineeringFeedback | R14 code / R15 runtime | R14 code; R15 runtime `77/77`; `screen_only`; `accepted=false`; `component_load=false`; no formal credits |

The latest T0 authority recheck R22 is `runtime_complete`: direct Julia
`310/310`, `25` runtime negative dispatches, `accepted=false`, `contract_only`,
and no T1/T2 credit. The `100 snapshots` value is only the static 25×4
derivation; it is not an independent runtime count. R21 remains preserved as
historical interruption. T1 R5 is static `16` and `prepared_not_executed`.
Spatial R9 is `54/54` but `screen_only`. G1/G2/G3 R22 has an authoritative
nested `39/39 + 13/13` receipt, while the package manifest remains
`preflight_only`; it grants no formal credit. DCCE `09cf7d1` has only Python
static QA/oracle evidence, remains `screen_only` and `accepted=false`, and was
not run under Julia; it grants no UP2-01 or R credit. EngineeringFeedback R14
code/R15 runtime `77/77` remains `screen_only`, `accepted=false`,
`component_load=false`, with no formal credits. The records above provide no
provider/physics Julia/DESC runtime, physical, engineering, or final-authority
credit. R01–R10 remain `pending`, `L4=0`, and the parent goal is open. Five
untracked `pyc` files were removed during cleanup. Dirty `runs`, `tmp`, evidence,
and protected state were preserved.

## Post-patch file hashes

SHA-256 values are for the seven synchronized files other than this
change-report; the change-report file is intentionally excluded from this
self-referential list.

```text
7f7c32a900bb59818e5134f33005f8267eb785b10444629062e95c8f733aefa3  docs/implementation/README.md
cd6a22a48b78fa7339a2a9fc08722ebace15d1b6139031ed769ce3791b45d6e2  docs/v4_multitopology_generation/README.md
ed474415b6365d1a88405a50b6c80ffef91d873ac2cb45760182d6207b9bcf9d  docs/v4_multitopology_generation/16_execution_work_orders.md
1869c750bfa123e28a4a87f3187565a93f28d6153ad960cd0ad8667938a2eb7a  docs/v4_multitopology_generation/21_next_execution_batches.md
afb6a7eee5425e8812be4ffbfcc9e33cdca102ef70d63c42542c0d08a8e593ca  docs/implementation/UP1-04A-VNEXT-T0-AUTHORITY-RECHECK-PREC/README.md
ff6bab3cd1754e250cbc4a0e1010f30fb548f762513bf8c938780b6247bcfd45  docs/implementation/UP1-04A-VNEXT-T0-AUTHORITY-RECHECK-PREC/acceptance.md
```

## Verification and exclusions

Performed only textual link/path checks and `git diff`/hash inspection. No
additional provider/physics Julia/DESC runtime was run by this synchronization;
focused Julia contract tests from the listed receipts were acknowledged as
read-only inputs and not rerun here. No build, source/test, task-manifest, run, or evidence execution was
performed. No `task_manifest`, source, tests, or `runs` content was modified;
the pre-existing dirty/untracked artifacts remain outside this index update.
