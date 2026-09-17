# M4-D root acceptance R1

## Decision

Sol/root accepts the D manufactured coupled-solve control on the basis of
`independent_review_r2/pass_limited`. The recorded status is
`accepted_limited`; the claim ceiling is
`manufactured_coupled_solve_control/screen_only`.

Within that ceiling, the isolated M4 A→D slice is `complete_limited`: A
declaration/IR, B residual lowering, C discrete control, and D direct
two-region manufactured algebraic control have each passed their bounded,
independent review contract. This is a test-only numerical control slice, not
a production result.

## Evidence and preserved history

The review record remains the authority for the evidence and failure history:
`../independent_review_r2/{report.md,manifest.json,validation_receipt.json}`.
The D repair is source SHA
`ec7e82e282f1d1292ddd4b7902e4ced641d926af82119298267011d304a55785`, current
test SHA `1eb0e26e79b9899cc5a3cb2742545cbaa811fa6683fdcfa1ee4dd31dff081686`,
and oracle SHA
`9ca3c1c012690c7c06579d0ab5ffd274666e340c900c59e49f7a93408a0fcbe3`.
The D repair/158 history, authoritative integration Julia runs PID 33500 and
88136, Python exact checks, old 110/110 and superseded 111/111 records,
initial failures, bypass `changes_requested` probe, and non-authoritative
capture-timeout/$args preflight records are retained append-only under the
existing delivery, review, test, and integration archives.

## Boundaries

This decision does not grant credit, close, or waive UP2-01, UP2, B00, B04,
provider/mesh/engineering/physical gates, R01–R10, L4, or the parent goal. It
does not accept a production PDE solver, production coupling, candidate,
provider, physics, engineering, or external evidence. C and D remain
manufactured controls only. The existing shared entry, default registry, and
unrelated dirty `SpatialRuntimeV4` work are unchanged.

The formal re-entry route remains exactly:
`T0 → authority recheck → T1 → T2 → aggregate → UP2-00 → UP1-04B → UP1-04 → UP2-01`.
Fresh upstream identity and receipts are required at re-entry; this record is
not a substitute for those gates.

## Roles and authority

Decision authority is `Sol/root`; recorder is Luna `m4_scope_record` (model
`gpt-5.6-luna`, effort `high`). D source implementation, test/oracle,
integration, documentation, and independent review were performed by
pairwise-distinct Luna roles. The reviewer did not review its own or another
role's implementation. No Julia, Python, solver, or project runtime was run
for this documentation record; the raw sidecars are documentation-only.

