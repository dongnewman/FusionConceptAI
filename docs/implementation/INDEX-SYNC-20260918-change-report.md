# Core index sync change report — 2026-09-18

Status: documentation-only working-tree update; no commit created. Root-agent
review is required before staging or committing. No additional Julia/DESC
runtime was run by this synchronization; existing receipts were read-only
inputs.

## Baseline and scope

The synchronized baseline is the existing checkout at HEAD
`94e4598d209c2d424c2e7affaeef0df171dd67da`. Only status/index sections of
these eight files were changed:

- `docs/implementation/README.md`: refreshed the HEAD/date banner and replaced
  the stale four-row contract-only block with the ten-record wave index.
- `docs/reports/current_progress_index.md`: refreshed the HEAD/date banner and
  replaced the stale current-repository block with the ten-record wave index.
- `docs/v4_multitopology_generation/16_execution_work_orders.md`: refreshed
  the non-runtime index-sync block with the ten-record wave index.
- `docs/v4_multitopology_generation/21_next_execution_batches.md`: synchronized
  the current T0/T1/G1-G2-G3/EngineeringFeedback execution boundary.
- `docs/implementation/INDEX-SYNC-20260918-change-report.md`: recorded this
  eight-file synchronization and its verification boundary.
- `docs/implementation/UP1-04A-VNEXT-T0-AUTHORITY-RECHECK-PREC/README.md` and
  `acceptance.md`: recorded the R21 interrupted/incomplete receipt and preserved
  the typed-absent/accepted-false boundary.

The existing historical spatial narrative, navigation, work orders, and other
unrelated edits were preserved. The current boundary is explicit: R01–R10 are
`pending`, `L4=0`, the parent goal is open, and these receipts do not close any
UP label. No completion percentage is inferred.

## Exact wave receipt index

| Record | Commit | Receipt/status boundary |
|---|---|---|
| T0 LocalV1 | `87f0263` (`87f02636347a5d65d309f256b2d10914f39cc25a`) | committed |
| T0 authority recheck | `94e4598` / R21 | `interrupted_incomplete`; negative dispatch `0/25`, negative-object snapshots `0/100`; no retry; no authority published |
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
| EngineeringFeedback | R14 code / R15 runtime | R14 code; R15 runtime `77/77`; `screen_only`; `accepted=false`; `component_load=false`; no formal credits |

The latest T0 authority recheck R21 is `interrupted_incomplete`: it reached
negative dispatch `0/25` and negative-object snapshots `0/100`, published no
`Test Summary` or authority, and was not retried. T1 R5 is static `16` and
`prepared_not_executed`. Spatial R9 is `54/54` but `screen_only`. G1/G2/G3 R22
has an authoritative nested `39/39 + 13/13` receipt, while the package
manifest remains `preflight_only`; it grants no formal credit. EngineeringFeedback
R14 code/R15 runtime `77/77` remains `screen_only`, `accepted=false`,
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
6f638d472d2cd9f09556a124955f1c3b15996fe44b32833c978b2e5c04ca3d49  docs/implementation/README.md
70243dfa752a9d62f477b41a1b758131fbff0c586524fb1922edb7f4e3e12567  docs/reports/current_progress_index.md
67acf43447b92ef27120043bf7481c88c6d9a3c93d19b71ff9be2875d38a2e2d  docs/v4_multitopology_generation/README.md
2c85ca7667a7538283d00650dd882593d234853db1ce7a9a080ae955d847c71a  docs/v4_multitopology_generation/16_execution_work_orders.md
e5102279f97ad9be01e45c95e713ffa1d2c824eec3a9e605d02f3e903cbd6940  docs/v4_multitopology_generation/21_next_execution_batches.md
4280725fac42d2dbff33bcefacbee41cf0931bf37153ccb5f15857abad00c950  docs/implementation/UP1-04A-VNEXT-T0-AUTHORITY-RECHECK-PREC/README.md
8336304bf63f635ce2bef3ccbd4b45e29cc4bb67533aaf56ea1408598f52adbb  docs/implementation/UP1-04A-VNEXT-T0-AUTHORITY-RECHECK-PREC/acceptance.md
```

## Verification and exclusions

Performed only textual link/path checks and `git diff`/hash inspection. No
additional provider/physics Julia/DESC runtime was run by this synchronization;
focused Julia contract tests from the listed receipts were acknowledged as
read-only inputs and not rerun here. No build, source/test, task-manifest, run, or evidence execution was
performed. No `task_manifest`, source, tests, or `runs` content was modified;
the pre-existing dirty/untracked artifacts remain outside this index update.
