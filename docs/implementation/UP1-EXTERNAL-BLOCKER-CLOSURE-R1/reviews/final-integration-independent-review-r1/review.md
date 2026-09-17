# UP1 final integration independent review R1

## Decision

`rework`. The four latest work-package reviews, root adjudication, external
handoff controls, absence coverage, exact hashes, and read-only hygiene state
are internally consistent. One P1 integration defect prevents
`pass_limited`: the handoff conditional schedule does not explicitly preserve
the frozen route after T2.

## Confirmed boundary

- W1/W2/W3/W4 latest independent reviews are respectively r7/r3/r4/r3 and
  each records `pass_limited` with a preparation/discovery-only ceiling.
- Root records exactly zero usable external inputs and fresh S3 as
  `typed_absent -> terminal_deferred -> no_publish`; unchanged inputs prohibit
  a new AD or fresh S3 rerun.
- No formal credit is present. R01-R10, the 39-node DAG, B00/B04, L4 and the
  parent goal remain open. HEAD is
  `b2c04d8339774635aaecd73651efcdb101e01b5d`.
- The four handoff packets cover all 26 W1/W2/W3 lossless external absence
  IDs. Extra W1 gap aliases and environment-closure aliases are traceability
  labels, not invented external facts. `not_sent=true`, no credentials are
  requested, and no endpoint/name/authority is invented.
- Git hygiene is read-only; no deletion or mutation occurred. The four
  unowned historical W1 raw streams are consistently retained.
- The fresh validator was run with `python -B` in a separate process and
  retained PID/UTC/exit/stdout/stderr/hash evidence in `raw/`.

## P1 finding

`reviews/external-handoffs-r1/conditional_schedule.json` has only S0, S1, T0,
recheck, T1, T2 and a collapsed `B00_or_B04_review` stage. Its `ordering`
string is `T0 -> recheck -> T1 -> T2 -> B00/B04`; it omits the required explicit
sequence `aggregate -> UP2-00 -> UP1-04B -> UP1-04 -> UP2-01`.

Repair the owned handoff schedule by adding explicit ordered stage entries and
success/failure transitions for all five omitted nodes, preserving the exact
route `T0 -> recheck -> T1 -> T2 -> aggregate -> UP2-00 -> UP1-04B -> UP1-04 -> UP2-01`.
Recompute that package's manifest/cleanup hashes and obtain a new independent
integration review. Do not send packets, create an AD, rerun S3, or grant a
formal gate while repairing.

## Acceptance boundary

Until the P1 repair is independently reviewed, this package is `rework`; it
grants no formal gate credit and does not alter the frozen parent goal.
