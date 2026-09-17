# UP1 R3 13-vector harness independent review R1

## Decision

**fail_limited**. This is an offline local software/prototype review only.
The harness repair does not establish UP1 closure, formal credit, external
authority, physical/engineering evidence, or publication readiness.

Observed result metadata and the production `_result` boundary retain
`formal_credit=none`, `authority_credit=false`, and `no_publish=true`. No
network, AD/S3, Julia/DESC/solver, credentials, external send, or production
file mutation was used. Only this review directory was written.

## Frozen inputs and execution

The production tool modules, focused tests, acceptance matrix, and submitted
`vector-receipt.json` were frozen in [freeze_manifest.json](freeze_manifest.json).
All eight files were re-hashed after the runs and remained unchanged.

The focused discovery command was run serially twice with `python -B`:

| run | PID | UTC | exit | result |
|---|---:|---|---:|---|
| 1 | 95960 | 2026-09-17T01:08:07.1276529Z to 2026-09-17T01:08:08.3811182Z | 0 | 24 tests, 1 host-privilege-limited skip |
| 2 | 46356 | 2026-09-17T01:08:17.0152633Z to 2026-09-17T01:08:18.2432688Z | 0 | 24 tests, 1 host-privilege-limited skip |

Raw bytes, PIDs, UTC intervals, exits, and SHA-256 values are in
[receipt-manifest.json](receipt-manifest.json) and `raw/`.

## Vector receipt audit

Independent parsing found 26 rows with all six required fields present. IDs,
input hashes, and mutation paths are each unique across all 26 rows; every
`called_function`, `actual_code`, and `actual_decision` field is populated.
Replaying the submitted builders produced an exact byte-for-byte receipt-row
match (`replay_exact=True`). R01 and R23 were then run through the public
`validate_bundle` API independently:

| vector | public result | decision | schema_ok | no_publish |
|---|---|---|---|---|
| R01 | `SCHEMA_INVALID` | `rejected_all` | false | true |
| R23 | `RAW_DUPLICATE_KEY` | `rejected_all` | false | true |

The full call audit is retained in `raw/production_call_audit.raw`.

## Findings

### P0

None observed within this offline scope.

### P1-01 — most claimed vectors do not call the production predicate

The package README claims that R02–R22, R24–R25 and D01 invoke the owning
production predicate and then the production result layer. The implementation
does not satisfy that claim for R02–R07, R24, R25, or D01.

In `test_atomic_bundle_vectors.py:271-289`, R02–R07 reproduce the checks with
local `if` statements and call only `impl._err`; they do not call
`validate_bundle` or an owning production predicate. In lines 317–332, R24 and
R25 only assign `fixture_status`/`security_ok`, while D01 compares against a
handwritten `derived_decision`. The receipt labels such as
`validate_bundle.packet_order` and `validate_bundle.security_and_decision ->
_result` are therefore descriptive metadata, not runtime call evidence.

The common `_finish_semantic` helper (`test_atomic_bundle_vectors.py:228-249`)
also hand-computes the decision precedence and calls `_result`; `_result` is a
production formatter/decision guard, but it cannot prove that the mutated
field reached the public validator or an owning predicate. Instrumentation
confirmed `_err -> _result` for R02–R07 and D01, `_result` only for R24/R25,
and no owning production predicate for those rows.

This is a material semantic-coverage gap, so the 26/26 receipt must not be
promoted beyond `fail_limited`. A real closure requires schema-valid baseline
construction or production helper extraction so each claimed mutation is
actually evaluated by the owning implementation and its decision layer.

### P2-01 — R22 is predicate-backed but not a direct replay of its mutated wire envelope

R22 does call production `_check_ehp04`, but lines 299–316 discard the original
wire-shaped EHP-04 payload and construct a separate clean temporary-root
payload. It demonstrates the `not_executed -> terminal_deferred` boundary,
not that the submitted R22 mutation reaches `_check_ehp04` in the original
envelope. Retain this as limited evidence.

### P2-02 — one focused test remains skipped by host capability

Both focused runs report one skip, the existing symlink/reparse test whose
host lacks the required privilege. This is a host-capability limitation, not
a claimed pass for Windows reparse behavior; preserve the limitation in any
downstream status.

## Requested spot checks

- **R02:** expected code/decision is reproduced by a handwritten packet-order
  branch; not production-predicate evidence (P1-01).
- **R04:** same gap for set-receipt bundle ID (P1-01).
- **R08:** directly calls production `_check_quarantine`; limited semantic
  predicate evidence.
- **R15:** directly calls production `_check_ehp03`; graph-bijection mutation
  is exercised, with no authority/publish credit.
- **R17:** directly calls production `_check_ehp04`; context-binding mutation
  is exercised, with no authority/publish credit.
- **R22:** calls `_check_ehp04` on a clean reconstructed deferred fixture;
  limited as P2-01.
- **R24:** no production security predicate; only handwritten clean-defer
  state followed by `_result` (P1-01).
- **R25:** no production security predicate; only handwritten internal
  acceptance-shaped state followed by `_result` (P1-01).
- **D01:** no production decision-consistency predicate; handwritten derived
  rejection followed by `_result` (P1-01).

## Fail-closed and authority boundary

Independent public calls on `{}`, `[]`, `null`, and duplicate-key JSON all
returned `rejected_all` with typed failure codes. Calling production `_result`
with an injected error and `decision_override="accepted_all"` still returned
`rejected_all`; a clean `not_executed` result returned only
`terminal_deferred`. Every observed result retained `formal_credit=none`,
`authority_credit=false`, and `no_publish=true`. The implementation’s final
error precedence and authority boundary are unchanged for this review.

## Final status

`fail_limited`; no P0, one P1 semantic-coverage blocker, and two P2 evidence
limitations above. Preserve the package’s `prototype_pass_limited` wording as
software-only and do not promote the vector receipt to external/authority
closure.
