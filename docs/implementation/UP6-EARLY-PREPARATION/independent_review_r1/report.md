# UP6-EARLY-PREPARATION independent review R1

Date: 2026-09-15
Reviewer: different Luna/high, read-only
Scope: seven JSON templates, architecture audit, validation report, cleanup
inventory, manifest inputs and the exact write boundary

## Verdict

`changes_requested`.

The package is a useful preparation-only template and keeps all UP6 and R01–R10
conclusions pending. Two contract details must be repaired before the package
can receive a limited preparation pass: the fifteen engineering rows need to be
fully typed row records, and each provider fresh receipt needs explicit
candidate/scenario/subject/input/provider/toolchain identity joins.

This review grants no UP6, provider, solver, mesh, physical, engineering,
VVUQ, net-output, originality, replay, L4, or R01–R10 credit. The only
acceptable scope after repair is early-preparation template structure; UP6 and
parent-goal closure remain pending.

## Checks that pass

The seven JSON files parse successfully. The engineering ledger contains 15
unique obligation IDs, including a dedicated `ENG-NET-LEDGER` row. The closeout
template contains exactly ten unique R01–R10 IDs; every row has
`status=pending`, `accepted=false`, `authority=FinalWholeDeviceAuthorityV4`,
and `claim_ceiling=contract_only`. The manifest records `l4_credible_count=0`,
`credible_candidate_count=0`, and `discovery_goal_achieved=false`.

The provider/toolchain field contract covers interpreter path/version/executable
hash, module import/version/source/hash, compiler/runtime/build command/build
hash, source tree revision/tree hash/license, channel and lock hash,
applicability dimensions, limitations, and raw fresh receipt fields. Its policy
explicitly rejects historical receipts as promotion evidence and maps missing
authority to `terminal_deferred`.

The VVUQ catalog separates verification, validation, discrepancy and
uncertainty. It requires source license/permission, version, content hash,
candidate and physical-subject binding, scenario/operating-point mapping,
calibration/validation separation, discrepancy propagation and uncertainty
coverage. No catalog item is populated.

The originality template records search date, databases, library versions,
exact query text, query date/version, raw-result hash slot, screening and
limitations, and separate mechanism/structure/behavior comparison axes. No
external search was performed and no originality result is inferred.

The replay protocol requires isolated environments, two independent executors
and independence groups, frozen commands, raw stdout/stderr/combined outputs,
exit codes, input/output/artifact hashes, and a comparison rule. Replay outcome
is empty and pending; historical receipts, mutable caches and solver swaps are
explicitly forbidden shortcuts.

The manifest lists 19 input paths; all listed files/directories exist. Ten
declared writable/deliverable paths exist in the package, and the cleanup
inventory reports no task-owned scratch/cache or deletion. Existing dirty
source, tests, scripts, runs, benchmarks, planning documents and other agent
files are protected.

## Blocking contract findings

### 1. Engineering obligations are not complete row contracts

`engineering_obligation_ledger_template.json` has a rich shared
`entry_contract`, but each of the 15 entries only contains:
`obligation_id`, `family`, `requirement`, `status`, `scenario_scope`,
`required_evidence`, and `authority_disposition`. The rows do not carry their
own typed `applicability`, `candidate_ref`, `scenario_refs`, quantity/unit and
threshold, owner, provider/data/model refs, verification, validation,
discrepancy, uncertainty, fresh receipt, limitation, or authority record.

This makes the declared ledger impossible to instantiate or audit row-by-row
without an undocumented merge of the shared template. It also leaves
`scenario_scope` as an untyped bare `pending` string. Expand every one of the
15 rows with the entry-contract fields (or make an explicit machine-readable
row schema and prove that each row validates against it), using typed pending
records with null values and reasons. Keep `ENG-NET-LEDGER` explicit for
gross-output minus source, conversion, cooling, fuel, control and auxiliary
demand, with storage delta, startup/shutdown/ramp/hold scope, uncertainty
interval and no-duplicate accounting.

### 2. Fresh provider receipts lack explicit identity joins

The provider field contract has the required raw receipt fields, but its
`fresh_receipt` object does not explicitly require the candidate reference,
scenario manifest/reference, physical-subject identity, solver/input identity,
provider identity, toolchain identity, applicability profile, or limitation
identity. The surrounding `provider_id` description says “candidate and
scenario bound,” and `input_hashes` is present, but a future checker could
accept a receipt without demonstrating those exact joins.

Add typed pending fields to `fresh_receipt` for at least
`candidate_ref`, `scenario_manifest_hash`, `physical_subject_hash`,
`solver_input_hash` (or explicit input manifest identity), `provider_id` and
provider/version identity, `toolchain_identity`, `source_tree_hash`,
`build_hash`, `channel_lock_hash`, applicability profile identity and
limitation identity. A historical environment inventory or the `pending://`
reference strings in `provider_records` must remain context only and must not
be accepted as a receipt.

## Boundary confirmation

No Julia, DESC, FreeGS, VMEX, Pleiades, CQL3D, provider, mesh, solver,
physical, net-output, replay, originality search, web search, download, or
external-data operation was run for this review. No reviewed file was modified.
The only review writes are this report and its companion review manifest.

After the two repairs, rerun the seven JSON parse, cross-reference, 19-path,
exact-owned diff, cleanup and pending-field checks, then obtain a new
independent review. Until then the package remains `review_pending`,
`accepted=false`, and `preparation_only`; UP6-01/02/03, provider admission,
engineering, VVUQ, net output, originality, replay, L4 and R01–R10 remain
pending/false.
