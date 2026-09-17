# H0-A focused_r5 independent postrun

- **Verdict:** `changes_requested`
- **Serial next-run readiness:** `not_ready`
- **Acceptance:** `accepted=false`; `review_pending=true`
- **Scope:** independent static review of the preserved focused_r5 receipt and source/test control flow. No Julia or DESC was run by this review.

## Execution receipt and identity

focused_r5 ran exactly once at HEAD `4b69f55f7f80240147a65a22809dc1207824dde2`, PID `38540`, from `2026-09-14T21:37:45.1812844Z` through `2026-09-14T21:38:50.2558502Z`, with exit code `1`. The command was `julia --startup-file=no --project=. test/GenomeV5/UP2/run_n06_dimensioned_law.jl`. The raw stdout is 7,441 bytes, SHA-256 `db57bb87452c1ed6f89f2503ef787180bc0788627cb994dde6d9625efe2946c1`; raw stderr is 310 bytes, SHA-256 `2149b4bb35ceb6462f02bf37627b19b8ea47cd9bc28152d9822c9cbcaf072de3`.

The receipt records 303 dirty rows before and after, zero Julia/DESC processes before and after, and unchanged R11 input identities. The four inputs were source `f40e626bcdb8c981bb9355dbde49dc7f9302f5db558a0e758fdcc5b98681b251` (57,046 bytes), test `eadd8c19344a117edeaa5ffad4fbe6f9e1300d3c81388918b00c63876efa10e5` (38,431 bytes), fixture `779e29bac0a71c5072896301e24e74c9686c293609b89e250d0b0aff5bf0cc99` (1,451 bytes), and runner `da4c41517badd8c99f5f10e55c9219e2450afb223798eb7f7b4db2048ce293dc` (299 bytes). The current postrun workspace snapshot has 303 status lines and UTF-8/LF SHA-256 `e372f472539f77536e07ea47a6d549931251bafa6894c3df77937e721fa6bc1a`; no matching Julia/DESC process is present.

Focused_r4 remains preserved: its `report.json` is 2,432 bytes with SHA-256 `52e9729d47ed880ccfdef6947cdafecec5e2b95f46a609acca17e30f5d0c5b26`, and its raw stdout/stderr hashes remain `aff9a3413dab8137ea8a8df161496809d930f6cea29e551563f032505af201b3` and `a64e6d35d8d86249f2a54bdce3dc19890943cbc320899aa1ce2a73dcb15f1225`. No old receipt was overwritten.

## Failure and control-flow finding

All preceding suites passed, including G1 `47/47` and `21/21`, G2 `57/57`, `59/59`, and `8/8`, G3 `49/49`, `35/35`, and `23/23`, H0-A constructor dispatch `9/9`, fixture/schema `10/10`, and taxonomy `4/4`. The first failure was `H0-A actual-A source binding remains deferred` at test line 198: `1 pass, 2 fail, 4 error, 7 total`.

The source path is unambiguous from the current implementation. `n06_h0a_bind_actual_a` first builds the typed binding and validates E0, then enters one broad `try` around `_n06_h0a_project`, `_n06_h0a_endpoint_set`, and `_n06_h0a_validate_endpoint_semantics`. The expected missing-authority result is produced only inside the `!isempty(ec.gaps)` branch: it constructs `n06_h0a_absent(...)` and returns `:terminal_deferred`. Any exception escaping that block is translated by `_n06_h0a_translate_upstream` and classified `:program_exception`; the catch returns `_n06_h0a_result(status, nothing, (reason,))`.

The observed `program_exception` with `declaration === nothing` therefore came from the catch return, before the expected typed-absent declaration was returned. The focused receipt does not record `result.errors`, so it does not identify the inner exception or prove that the exception was the expected external-authority gap. Static evidence only narrows it to the wrapped projection/endpoint/semantic path; inventing a specific inner exception would exceed the receipt.

The four later errors are test cascades, not four independent production findings: lines 203–205 dereference `result.declaration` after the type assertion already failed, and line 207 calls `n06_h0a_validate(::Nothing)`. The test must guard those field assertions so the primary status/classification failure remains one actionable failure.

## Narrow repair and next exit gate

Production needs a narrow follow-up that exposes and fixes the first wrapped exception without downgrading `program_exception` to an authority gap. If the captured reason proves that the actual candidate lacks an authored authority, that source branch should raise the existing typed `N06H0AKnownGapError(:external_ref_required, ...)` or otherwise reach the existing `ec.gaps` terminal-deferred branch. If it proves an invariant/type/identity defect, retain `program_exception` and repair that defect instead. The current evidence is insufficient to choose between those two production repairs; a future focused receipt must preserve the returned `errors`/reason or add a static-only diagnostic before execution.

The narrow test repair is to gate lines 203–207 behind `result.status == :terminal_deferred && result.declaration isa G.N06H0ATypedAbsentV1` (or equivalent `if`), while asserting the primary status and declaration type first. This prevents `Nothing` field access from masking the source classification. It must not make the test pass while `result.status == :program_exception`.

The next serial focused run is held until the production classification is repaired or its exact reason is independently captured and reviewed, the test cascade is guarded, and a fresh four-input preflight is recorded. Any later exit 0 remains software-contract evidence only: no H0-A acceptance, B00/B04, physical, provider, engineering, R01-R10, or parent-goal credit.

