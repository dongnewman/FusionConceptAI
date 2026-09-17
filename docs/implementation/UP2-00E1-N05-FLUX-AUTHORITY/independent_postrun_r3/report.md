# Independent post-run review: N05 receipt export R3

Verdict: **changes_requested** for the full receipt-export exit gate.

The bounded runtime evidence itself is internally consistent. The R3 process
receipt records main PID `77828`, observed Julia children `49160`, `47440`,
and `77596`, UTC interval `2026-09-14T05:19:30.8090262Z` to
`2026-09-14T05:20:49.0116095Z`, and real exit `0`. The raw stdout is 1459
bytes with SHA-256
`dde3b6d2c443ceb9c24df4b3eeb32c8afa8791749d87e367ca8e2de86ff98786`; raw
stderr is empty with SHA-256
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.
The postflight sweep reports zero Julia/DESC processes and the protected E1
inputs are unchanged. `test_summary.json` records nine groups and `316/316`
passes; the serialized envelope test itself reports `17/17`.

R1 and R2 remain correctly retained as program exceptions. R1 was the
nonexistent `.status` test-harness access and exited 1 before export. R2
successfully wrote the 22,402-byte envelope but failed on Julia 1.10
`merge(JSON3.Object, NamedTuple)` while constructing a forgery control and
also exited 1. Their raw files and correction notes remain unchanged.

## Receipt and source-bound checks

The R3 envelope is JSON3-readable, has schema
`UP2-00E1-N05-receipt-envelope-v1`, scope `schema_validation_only`, exactly
five authored and five absent-authority rows, and SHA-256
`777d120fc9bdfb10933e296b28b8d04cac97009d9998ae2073bcc2d075c35fea`.
Independent parsing verified all ten IDs (`N05-01` through `N05-05` in each
mode), required locator/value/hash fields, internal original/attempted value
hashes, mutation hashes, common candidate/package/E0 identity, and zero
compile/provider/solver counters.

The authored rows are source-derived and classify as follows:

| rows | selected source path/type | observed class | resolution |
|---|---|---|---|
| N05-01 | `/n05/left_endpoint/endpoint_ref`, `AuthoredFluxEndpointV1` | `invalid_closure` | `fail_closed` |
| N05-02 | `/n05/right_endpoint/endpoint_ref`, `AuthoredFluxEndpointV1` | `invalid_closure` | `fail_closed` |
| N05-03 | `/n05/left_endpoint/sign`, `AuthoredFluxEndpointV1` | `invalid_closure` | `fail_closed` |
| N05-04 | `/n05/right_endpoint/sign`, `AuthoredFluxEndpointV1` | `invalid_closure` | `fail_closed` |
| N05-05 | `/n05/right_endpoint/unit`, `AuthoredFluxLawUnitV1` | `invalid_type` | `fail_closed` |

The absent rows retain zero-valued placeholder typed values, zero declaration
hashes, `missing_authority` source type, `authority_gap` error, and
`terminal_deferred` resolution. They are not physical or provider evidence.
No receipt row contains fixture `expected_error` or `expected_resolution` as
an output field. The production mutation path classifies from observed typed
errors; the export test reads fixture expectations only when constructing
specifications, and its R3 assertions do not route classifications from those
labels.

## File-read and negative-control boundary

The test executes the file-read path positively: lines 125–127 of
`test/GenomeV5/UP2/n05_flux_receipt_export_tests.jl` call `JSON3.read(read(path,
String))` and pass that parsed envelope to the trusted overload with the actual
package, E0, authored/absent authorities, and specs. The one-argument
`n05_check_receipt_file(path)` path is also exercised, but it only performs the
schema-level envelope check in `n05_flux_receipt_checker.jl:123–125`.

The five forged/omitted negative controls at test lines 137–157 are instead
passed directly to the trusted in-memory overload. They cover authored
mutation hash, absent mutation hash, candidate ref, package hash, E0 binding
hash, declaration hash, and omitted authored row, but none is serialized to a
new file and re-read through a file-read trusted API. Thus R3 proves positive
file round-trip plus in-memory source-bound rejection; it does not prove
file-read negative rejection. This is the minimum change requested before
calling the receipt-export boundary complete.

The checker and exporter share `_n05e_row`: exporter construction is at
`n05_flux_receipt_exporter.jl:36–62`, while trusted checker recomputation calls
the same helper at `n05_flux_receipt_checker.jl:98–117`. This gives useful
source-bound comparison but is not fully independent serialization logic; a
future formal B04 checker must be independent and run in a separate process.

## Scope decision

Acceptable limited evidence: R3 is a reproducible contract-only run with
316/316 focused assertions, ten internally consistent source-bound rows,
zero downstream counters, real exit 0, and protected-input/postflight
receipts. The full N05 receipt-export acceptance remains `changes_requested`
until the forged/omitted controls pass through a file-read trusted path and
an independent checker/two-process replay is performed. B00/B04, provider,
mesh, engineering, physical, and R01–R10 credit remain false.
