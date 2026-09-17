# M4-D coupled-solve control delivery R1

Status: `delivery_complete_review_pending`  
Recorder: documentation Luna `m4_scope_record` (`gpt-5.6-luna`, high)  
Scope basis: `../d_scope_decision_r1/` (`authorized_not_started`)  
Frozen HEAD: `b2c04d8339774635aaecd73651efcdb101e01b5d`

## Delivery boundary

This record aggregates the isolated manufactured two-region coupled algebraic
solve control for review. It consumes two identical-grid C payloads (default
`2x2x2`) through an identity interface mapping. Each matched cell uses the
fixed block

`[[2,-1],[-1,2]] * [a,b] = [1,0]`,

with determinant `3`, exact Fraction solution `a=2/3`, `b=1/3`, and block
residual `0` for all 8 identity-mapped cells.

The ceiling is `manufactured_coupled_solve_control` / `screen_only`. This is
not a production or iterative PDE solver, production coupling, candidate,
provider, physics, or engineering result. It grants no `UP2`, `B00`, `B04`,
`R01-R10`, `L4`, or parent credit; the 39-node DAG and all gates remain open.

## Frozen inputs and binding boundary

Final integration inputs were:

- A source SHA `0b456dcc0df3bd13a1941aa502a9cc5347912b2fa86cda6c65900449299b8e57`;
- B source SHA `0445ec58f35ebbf5e34ae032611befab7050a0a65d2a376ccd37b71a0e9a936c`;
- C source SHA `20804bafb5d42152d220a1d25897f6b460c7056b0c695dbaa5153c0d113710fa`;
- D source SHA `a26d8dd66ed8d639fddac16590ee398c6a6ff32847f5020ec7c322bdb853b465`;
- current frozen D test SHA `92CD4069D97C54A297DD00AB3A85A4FC9A0FC39458B744D57BB046E76DC75D88`;
- D oracle SHA `9ca3c1c012690c7c06579d0ab5ffd274666e340c900c59e49f7a93408a0fcbe3`.

Region identity, grid identity, interface bijection, units, equation/source,
source owner, conservation owner, and provenance are explicit. Typed
validation covers singular/non-SPD blocks, grid mismatch, non-bijective
interface, unit/owner/provenance mismatch, foreign C input, and nonzero
residual.

## Test-version history and failures

The test history is deliberately versioned. PID `86500` is a failed harness
macro-syntax attempt (exit 1) with no business assertion. PID `80804` is a
failed test-expectation attempt (exit 1: 106 pass, 4 fail, 1 error). PID
`63524` is a superseded `111/111` pass under the older test hash
`CF303AC006C7F2DD47F73487015A08DD27D376875065114B3B759AB63C828D2E`. PID
`24296` is also an old `111/111` run retained as superseded historical
evidence. The current frozen test SHA is `92CD4069...75D88`; the authoritative
current integration result is two `110/110` runs, not the old `111/111`
count.

The integration wrapper preflight accidentally bound PowerShell's automatic
`$args` variable. Child PIDs `44132` and `52116` were stopped after no-argument
interpreter launches; no exit or child output was observed. The raw event is
retained under `../integration_r1/archive/failure_history/` and is
non-counted. It is not an implementation or mathematical failure.

## Authoritative integration replay

The corrected integration replay ran four fresh processes and is authoritative
for the current test file: Python oracle twice, then Julia tests twice. All
exited zero; Python payloads are byte-identical and report determinant `3`,
solution `(2/3,1/3)`, zero residual, and 8 cells. Julia reports `110/110` on
both runs.

| process | PID | UTC interval | exit | result | combined SHA-256 |
|---|---:|---|---:|---|---|
| Python run 1 | 39276 | `08:55:47.3920366Z–08:55:47.4835220Z` | 0 | exact payload | `94b4f5a43a37c6fab2bcafeec25bab744be2f359180849f299d59dfaec318615` |
| Python run 2 | 7252 | `08:56:04.2854948Z–08:56:04.3611627Z` | 0 | exact payload | `94b4f5a43a37c6fab2bcafeec25bab744be2f359180849f299d59dfaec318615` |
| Julia run 1 | 110988 | `08:56:25.9369653Z–08:56:43.4757038Z` | 0 | `110/110` | `0dd3699bd0e9673292b0a3a3d7e2b16b7d576f41d5fddc033efba1531ffaf444` |
| Julia run 2 | 21024 | `08:57:03.3505908Z–08:57:22.1187591Z` | 0 | `110/110` | `f9a5d275db6b48b0b9387c9c654eae13bd696aeafe34dd6554e07ef7cdf8be73` |

Exact stdout/stderr/combined raw paths, input maps, and artifact hashes are
retained in the four adjacent integration receipts and both `raw/` and
`archive/raw/`. All four stderr streams have the empty-stream hash
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.

## Ownership and gates

Source implementation, test/oracle, integration, documentation, and
independent review are five pairwise-distinct Luna roles. The reviewer cannot
review their own change or another role's same change. No shared entrypoint,
registry, Project, Manifest, candidate, provider, or upstream A/B/C source was
modified by this delivery record. Existing dirty work and all historical raw
and failure evidence remain protected.

Independent review must distinguish the superseded `111/111` histories from
the current `92CD...75D88` test and authoritative integration `110/110`, verify
the exact direct solution and 8-cell residuals, binding/typed-validation
coverage, all PID/UTC/exit/raw/hash records, non-counted `$args` preflight,
role separation, and shared-tree isolation. If review passes, only a separate
Sol `accepted_limited` decision may accept D at the stated ceiling.

Formal re-entry remains exactly
`T0 → authority recheck → T1 → T2 → aggregate → UP2-00 → UP1-04B → UP1-04 → UP2-01`.
No local D artifact authorizes production solver/coupling or closes any parent
gate.

