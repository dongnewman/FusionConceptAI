# M4-D delivery repair R1

Status: `delivery_complete_review_pending`  
Recorder: documentation Luna `m4_scope_record` (`gpt-5.6-luna`, high)  
Parent current-state index: `../manifest.json`

## Repair scope

This repair record updates the delivery index to the repaired D source
`EC7E82E282F1D1292DDD4B7902E4CED641D926AF82119298267011D304A55785` and
current test
`1EB0E26E79B9899CC5A3CB2742545CBAA811FA6683FDCFA1EE4DD31DFF081686`.
The test role changed only the test file; the source role supplied the source
repair. The oracle remains SHA
`9CA3C1C012690C7C06579D0AB5FFD274666E340C900C59E49F7A93408A0FCBE3`.

The repair closes the identified nested-right-hand C binding bypass and adds
typed regressions for foreign nested owners, invalid nested C, grid-count
mismatches, solution/interface pair order, missing/duplicate pairs, and
non-identity cell indices. It does not widen the manufactured screen-only
ceiling.

## Execution history and authoritative result

The repair test execution ran Python first and Julia second. Python PID
`31732`, exit `0`, UTC `09:32:17.9126555Z–09:32:18.9498896Z`, determinant `3`,
solution `(2/3,1/3)`, residual `(0,0)`, 8 identity cells, combined SHA
`94b4f5a43a37c6fab2bcafeec25bab744be2f359180849f299d59dfaec318615`.
Julia PID `106944`, exit `0`, UTC
`09:34:18.2805500Z–09:34:43Z`, `158/158`, combined SHA
`c6b315172cdce1b20744478efd74fd4f47ec6c1ffffbb3129e9b4944ad613484`.
Both stderr streams are empty and all raw/receipts remain in the parent
`test_execution_r1/repair_r1/` directory.

The corrected integration replay has two Python exits `0` (PIDs `100124` and
`58752`) and two authoritative Julia exits `0` with `158/158` (PIDs `33500`
and `88136`). Python combined SHA is
`94b4f5a43a37c6fab2bcafeec25bab744be2f359180849f299d59dfaec318615` for both;
Julia combined SHA values are
`82f8dad7421cef2695c9c70e8ed5c574ab01b572c418044e35acb2813fb8b043` and
`4a1bc927c3b6d3c854d8741c8dbce47d9fcd1b7d4367a25b27448df067fbb9a5`.
Exact UTC intervals, raw stdout/stderr/combined paths and hashes are retained
in `../integration_r1/repair_r1/` receipts and `raw/`/`archive/raw/`.

The intermediate Julia repair R2 capture-timeout produced a completed raw
`158/158` stream but lost PID/exit metadata; it is non-authoritative and
retained at
`../integration_r1/repair_r1/command_05_julia_tests_repair_r2_capture_timeout.receipt.json`.
The old `110/110`, old `111/111`, prior failures, and review-bypass probe are
not overwritten.

## Historical preservation, roles, and ceiling

The historical test failures PID `86500` and `80804`, superseded pass PID
`63524`, old `111/111` PID `24296`, and integration `$args` wrapper preflight
PIDs `44132/52116` remain preserved and separately classified in the original
delivery record. The repair is not a retroactive relabeling of those results.

Source implementation, test/oracle, integration, documentation, and
independent review remain five pairwise-distinct Luna roles. The repaired
source/test/oracle are isolated; shared entrypoints, registries, Project,
Manifest, candidate/provider files and pre-existing dirty work were not
modified.

Claim ceiling remains `manufactured_coupled_solve_control` / `screen_only`.
No production solver, PDE solver, coupling, candidate, provider, physics,
engineering, `UP2`, `B00`, `B04`, `R01-R10`, `L4`, or parent credit is granted.
Independent review and separate Sol acceptance remain required.

