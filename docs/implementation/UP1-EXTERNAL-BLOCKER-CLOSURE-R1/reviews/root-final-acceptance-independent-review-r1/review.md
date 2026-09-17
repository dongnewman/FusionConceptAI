# UP1 root-final acceptance independent review R1

## Decision

`pass_limited`. The root-final acceptance increment is internally consistent
with final integration R2 and preserves the frozen scope boundary. No P1/P2
finding remains.

## Checks

- Root-final actual files, owned files and declared product files are equal
  at 8/8; all six stable non-self hashes and cleanup hashes recompute exactly.
- The recorded basis includes final integration R2 `pass_limited`; R2's own
  route and boundary checks remain consistent.
- Usable external inputs remain `0`; UP1 blockers are explicitly unresolved.
  W1/W2/W3/W4 owners and authority channels remain `typed_absent`, and the
  request package remains `not_sent` with no invented endpoint, identity,
  credential or authority.
- Fresh S3 remains G1/G2/G3 `typed_absent`, then `terminal_deferred` and
  `no_publish`. Unchanged input still forbids a new AD and S3 rerun.
- The formal route is the complete 9-node route with 8 transitions:
  `T0 -> authority_recheck -> T1 -> T2 -> aggregate -> UP2-00 -> UP1-04B -> UP1-04 -> UP2-01`.
  R01-R10, the 39-node DAG, B00/B04, L4 and parent remain open/locked with no
  credit.
- M5-C remains `deferred_performance_blocked` with no formal credit.
- Runtime fields remain not-run for Julia, S3, DESC and solver; no external
  operation was performed. Git hygiene remains non-destructive and read-only.

## Process evidence

The first fresh invocation (PID 80932, exit 1) exposed only a review-harness
literal-match mistake (`do not rerun S3` versus the package's `no S3 rerun`);
its raw output is retained. After correcting the reviewer predicate, the
second fresh invocation PID 78704 exited 0 with all checks passing. Neither
invocation ran Julia, S3, DESC or a solver.

## Boundary

This is `accepted_limited` scope evidence only. It does not resolve UP1
external blockers, promote any formal gate, create an AD, rerun S3 or close
the parent goal.
