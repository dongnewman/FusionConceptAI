# Independent review of H0-A local software precursor acceptance R1

- **Verdict:** `pass_limited`
- **Reviewed scope:** `accepted_limited` for the local H0-A software contract
  precursor only
- **H0-A total acceptance:** `accepted=false`; `review_pending=true`
- **Method:** read-only rehash and cross-check of the R1 acceptance record,
  R6/R7/R8 receipts, current inputs, and existing acceptance boundaries. No
  Julia/DESC was run and no old file, core file, source, test, fixture, runner,
  or receipt was modified.

## Acceptance record and boundaries

The current [software precursor acceptance record](../software_precursor_acceptance_r1.md)
is append-only and correctly limits its status to the local H0-A software
contract precursor. The current [H0-A acceptance boundary](../acceptance.md)
still says `status=review_pending` and `accepted=false`; the current total
[evidence manifest](../evidence_manifest.json) likewise remains
`status=review_pending`, `accepted=false`. Their current byte counts and
SHA-256 values match the R1 manifest:

| file | bytes | SHA-256 |
|---|---:|---|
| `software_precursor_acceptance_r1.md` | 3628 | `0ebdd6fc1d289743c2a5b4d55f9302b79e792529850d15e0aab36a75965fcb69` |
| `software_precursor_evidence_manifest_r1.json` | 7122 | `35132725225e7e35eb3b7a631c9049c1505d8bc36fe78f626d77c0e9702663e7` |
| `acceptance.md` | 882 | `d1e715fac20e863d18a9be53360adbe7cb969db9992a2521a1a36d24f1a6d38b` |
| `evidence_manifest.json` | 4027 | `9c004d6c6063b3ad577bdba24bf98871c78a604584db6872b9e960b1947128a2` |

The R1 manifest JSON parsed successfully. All hash entries it records for the
current source/test/fixture/runner, R6/R7/R8 raw receipts, independent postrun
records, and the two existing acceptance boundary files matched on disk.

## Runtime chain recheck

The three runtime chains are preserved with their original byte hashes and
real exit codes:

| run | PID | UTC interval | exit | summary evidence |
|---|---:|---|---:|---|
| R6 | 48048 | `2026-09-14T22:34:23.8569218Z`–`2026-09-14T22:38:10.8831794Z` | 1 | protected receipt records 46 assertion groups; raw stream also retains the terminal failed-group summary header |
| R7 | 41736 | `2026-09-14T23:43:38.2366289Z`–`2026-09-14T23:48:36.0156943Z` | 1 | 65 observed summary blocks; role-sign defect preserved |
| R8 | 25164 | `2026-09-15T00:01:45.3282274Z`–`2026-09-15T00:07:20.0290209Z` | 0 | 75 observed summary blocks, 11 H0-A groups all pass |

For R6, the structured receipt's `assertion_group_summary_count` is 46 and
the raw stream is unchanged. A literal raw `Test Summary:` header scan counts
the final failed group's header as an additional formatting block; this does
not alter the receipt's recorded 46 assertion-group count or the historical
failure. R7 and R8 raw scan counts agree with their receipts.

Raw evidence rehash:

| artifact | bytes | SHA-256 |
|---|---:|---|
| R6 `stdout.raw` | 8091 | `7607f6d7200b30e2018e1d349e514a3c25e332a727b88c7f06bb2fe5d8131c2b` |
| R6 `stderr.raw` | 311 | `71eddcba500bf2c1b4dfe1bf9dfe53461f13e51faced6547744fdcae54d4d565` |
| R7 `stdout.raw` | 9857 | `c114cc2c4fced2acadbb5c822227daf1fff954e4e784150e0c213dafec5320bc` |
| R7 `stderr.raw` | 311 | `73824bf33e176701c1e568a6af07c77665bad3bc89f6d60125ffc493efa8de45` |
| R8 `stdout.raw` | 10342 | `9c97f086a3b5f9dadce1be39656b84c949b7ba494f63630ac9f405363b06d820` |
| R8 `stderr.raw` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |

R6 receipt SHA-256 is
`c0885913a747a1c099e535730463676f5d2c11b7355a371bee853f7d4e8d4b66`; R7
receipt SHA-256 is
`0a749eaedf89463f76b2c857e576cbf72003ba843de1f7726f4bb8a17bbf5ced`; R8
receipt SHA-256 is
`67c718afdada6e16dbab5245b0c9480f10da4b542585bd2b798dce111d54708a`.
The R6 and R7 exit-1 histories remain present and were not replaced by R8.

## Input and local contract result

The four current R8 inputs and their before/after hashes are stable:

| input | bytes | SHA-256 |
|---|---:|---|
| `src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl` | 59585 | `c317ce62e8ec1252491bfbf195daccda6ba05cc2a847bcfd311f391916cc8d1d` |
| `test/GenomeV5/UP2/n06_dimensioned_law_tests.jl` | 48902 | `58e1293fe7f7504cbb1f63a5fa9cd11734704e5ad742ce30607a00825d6b15f8` |
| `test/GenomeV5/UP2/n06_dimensioned_law_fixtures.json` | 1451 | `779e29bac0a71c5072896301e24e74c9686c293609b89e250d0b0aff5bf0cc99` |
| `test/GenomeV5/UP2/run_n06_dimensioned_law.jl` | 299 | `da4c41517badd8c99f5f10e55c9219e2450afb223798eb7f7b4db2048ce293dc` |

R8's all-pass result is consistent with the R20 source repair and the R7
failure attribution. It supports only local constructor, source-selector
classification, identity/provenance, typed outcome, editable hash, negative
control, and role-sign contract behavior exercised by this runner.

The actual-A group is `7/7`, but the runner does not print structured
actual-A status, declaration type, or compile/provider/solver counters. Every
one of these fields remains `not_printed_by_runner`; the group count cannot be
promoted to authority or a positive actual-A declaration.

## Credit ceiling

The R1 record and current acceptance boundaries consistently keep the following
false:

- N06 actual candidate-owned law or feedback authority;
- UP2 total completion;
- B00 and B04;
- provider execution or provider authority;
- mesh/DESC result;
- engineering readiness;
- physical validation;
- R01-R10 credit.

No source, test, fixture, runner, acceptance boundary, total manifest, or old
receipt was changed during this review. The limited R1 status is supportable as
an `accepted_limited` local software precursor only. It does not accept H0-A's
total gate or close any parent goal.
