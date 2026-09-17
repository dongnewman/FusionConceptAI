# H0-A local software contract precursor acceptance R1

Status: **`accepted_limited` for the local H0-A software contract precursor
only**. H0-A total acceptance remains **`accepted=false`** and
`review_pending=true`.

This append-only record follows the R8 focused run and its independent postrun.
It does not edit the existing [acceptance boundary](acceptance.md), total
[evidence manifest](evidence_manifest.json), source, tests, fixture, runner, or
historical receipts.

## Evidence chain

- [focused R6](focused_r6/report.md) is the retained exit-1 historical run.
- [focused R7](focused_r7/report.md) is the retained exit-1 run that exposed
the production role-sign defect.
- [repair R20](repair_r20/report.md) records the source-only sign projection
repair and static verification.
- [focused R8](focused_r8/report.md) is the single post-repair run: exit 0,
75 observed summary blocks, and 11 H0-A groups all passing.
- [independent R6 postrun](independent_postrun_r6/report.md) and [independent
R7 postrun](independent_postrun_r7/report.md) remain historical
`changes_requested` reviews.
- [independent R8 postrun](independent_postrun_r8/report.md) grants the same
limited local software precursor scope and keeps the parent gates closed.

R8 passed the tested local constructor, source selector classification,
identity/provenance, typed outcome, R20 role-sign projection, and negative
control paths. The trusted semantic and G2 provenance group passed `39/39`,
and the actual-A source-binding group passed `7/7` while remaining deferred.
The complete raw streams and all observed summaries are retained in
[focused_r8](focused_r8/), including [group_summaries.txt](focused_r8/group_summaries.txt).

The runner does not print structured actual-A status, declaration type, or
compile/provider/solver counters. These fields remain explicitly
`not_printed_by_runner`; the `7/7` group summary cannot be promoted to
candidate authority or a positive declaration.

## Hash record

The manifest [software_precursor_evidence_manifest_r1.json](software_precursor_evidence_manifest_r1.json)
contains program-calculated SHA-256 and byte counts for the current source,
test, fixture, runner, R6/R7/R8 raw receipts, independent postrun records, and
the existing acceptance boundary. The R8 input hashes were identical before
and after execution.

Current implementation inputs:

| artifact | bytes | SHA-256 |
|---|---:|---|
| source | 59585 | `c317ce62e8ec1252491bfbf195daccda6ba05cc2a847bcfd311f391916cc8d1d` |
| test | 48902 | `58e1293fe7f7504cbb1f63a5fa9cd11734704e5ad742ce30607a00825d6b15f8` |
| fixture | 1451 | `779e29bac0a71c5072896301e24e74c9686c293609b89e250d0b0aff5bf0cc99` |
| runner | 299 | `da4c41517badd8c99f5f10e55c9219e2450afb223798eb7f7b4db2048ce293dc` |

R8 runtime: PID `25164`, UTC
`2026-09-15T00:01:45.3282274Z`–`2026-09-15T00:07:20.0290209Z`, exit `0`;
stdout `10342` bytes SHA-256
`9c97f086a3b5f9dadce1be39656b84c949b7ba494f63630ac9f405363b06d820`, stderr `0` bytes SHA-256
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.

## Acceptance ceiling

This record grants no N06 actual candidate authority, dimensioned-law authority,
UP2 total completion, B00, B04, provider execution or authority, mesh/DESC
physical result, physical validation, engineering readiness, or R01–R10
credit. Actual-A remains source-authority deferred. The parent H0-A total gate
and all higher evidence gates remain false. No Julia/DESC run was performed to
create this document; the only runtime cited is the already preserved R8
receipt.
