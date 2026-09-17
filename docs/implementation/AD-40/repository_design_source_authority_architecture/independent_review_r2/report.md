# AD-40 RepositoryDesignSourceAuthorityV1 independent review R2

Date: 2026-09-15  
Reviewer: different Luna/high, read-only  
Verdict: `pass_limited`

## Scope and basis

This review checks AD-40 `repair_r1` against the v4 plan, common contract,
orchestration and work-order rules, AD-30/33/34/36/37/39 boundaries, the
original AD-40 proposal and manifest, current G1/G2 and integration source,
and all repair-owned evidence. The original proposal, original manifest,
repair R1 report/manifest, raw streams, initial failed attempt and prior
independent review remain unchanged.

The observed HEAD is
`4b69f55f7f80240147a65a22809dc1207824dde2`. The worktree is already dirty
outside this review. No source, test, fixture, core plan, task manifest,
candidate payload, candidate hash, machine node or runtime artifact was
created or modified by this review.

## Receipt closure result

The repair closes the R1 finding `AD40-R1-AD35-RECEIPT-CLOSURE`.

- All 15 frozen input paths exist and their declared byte counts and SHA-256
  values match the current files.
- All 6 validation runs have an interpreter, command, cwd, positive PID,
  UTC start/end, and exit code `0`.
- Each run has stdout, stderr and combined raw stream records. All 18 stream
  paths exist and their declared byte counts and SHA-256 values match the raw
  bytes.
- All 16 declared outputs exist. The report and every raw sidecar have
  matching byte/SHA records. The repair manifest has the declared
  `self_hash_excluded=true` rule and its byte count is still recorded.
- The repair's final scoped recheck confirms the original AD-40 product and
  historical receipt paths were not rewritten, and the repair files stay
  inside the task-owned `repair_r1/` directory.

The R1 receipt repair also records command, interpreter, cwd, PID, UTC,
exit, input hashes, output hashes, stdout/stderr/combined paths, bytes and
SHA values. The historical `validation_scope_attempt1.json`, original
`validation_receipt.json`, original `validation_receipt_r2.json` and all R1
review artifacts remain present. The repair's exact product scope is its
report and manifest; raw files remain evidence-only sidecars.

## Independent reruns

The plan validator was rerun from the repository root with Python and exited
`0` (PID `81352`). It reported 31 markdown files, 485 relative links, 39
tasks and an acyclic DAG. The independent repair revalidation ran in
PowerShell PID `70776` and exited `0`; it rechecked JSON, 15 input hashes,
6-run metadata, all 18 stream hashes, all 16 output records, control
characters, false claim flags and preserved inputs. The task-owned scope
recheck ran in PowerShell PID `80072` and exited `0`; it found no forbidden
source/test/fixture/static-QA/launcher/candidate payload path and no file
outside `repair_r1/`.

These checks establish only evidence and software-scope closure. They do not
execute Julia, DESC, provider, mesh, solver or physical workloads.

## Architecture and claim boundary

The original AD-40 architecture remains unchanged and coherent. The seven
future work orders still separate schema/factory source from candidate
declaration payload and software source receipts, require exact repository
HEAD/path/bytes, public contract, fresh candidate binding, four provenance
axes, factory reconstruction and different-Luna identity review, and retain
the fixture/synthetic/legacy/historical reuse prohibitions. The future work
order DAG and forbidden edges were not widened by the repair.

The software-only ceiling remains
`authority_class=repository_design_source` and
`claim_ceiling=software_source_provenance_only`. The repair does not create
or promote candidate identity, source-backed present, T0, T1, T2, provider,
mesh, solver, engineering, physical, search, B00, B04 or R01–R10 credit.
The original AD-40 flags remain false and no machine node or task-manifest
entry was added.

## Decision and cleanup

`pass_limited` is granted for the append-only receipt repair and independent
evidence-closure review only. It does not accept AD-40 implementation or
dispatch any future payload-authoring, authority-record, binding, factory,
identity-review or AD-37 publication work order. Those remain subject to the
original work-order gates and fresh candidate-bound evidence.

The only new paths are this review's report, manifest and raw validation
sidecars under `independent_review_r2/`. No ambiguous or unrelated path was
removed, and all historical failure/evidence artifacts remain protected.

