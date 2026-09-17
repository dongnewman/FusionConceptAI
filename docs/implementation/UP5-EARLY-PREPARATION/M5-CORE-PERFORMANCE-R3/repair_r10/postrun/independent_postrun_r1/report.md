# M5 core performance R3 R10 independent postrun precheck

## Decision

**PASS for the frozen R10 diagnostic receipt only.** The raw focused run is
`57/57`, exit code `0`, with empty stderr. It remains diagnostic and
`screen_only`; it grants no performance, acceptance, or R01--R10 credit.
The factorial performance root cause remains unresolved.

## Frozen authority and drift check

The authority for this postrun review is
`../diagnostic_julia_r8/run.json`, together with its raw `stdout.txt` and
`stderr.txt`, not any later working-tree interpretation. The run records
HEAD `c878404784d5d91e91b63bb2f2b2a87650dcdcb9`, the focused command, exit
code `0`, and `57 passed, 0 failed, 0 errored, 57 total`.

All five input SHA256 values recorded by that run were recomputed against the
current checkout and match exactly. Therefore no R11/later static-edit drift
is currently observable in these frozen inputs; if later edits occur, they
must be reported as postrun-later drift and must not retroactively alter this
R10 receipt.

Raw artifact checks:

- `run.json`: 1886 bytes,
  `c95969715d44f51469f31480acc5d5d66b233dca3a78843578f917cf1c199a2a`.
- `stdout.txt`: 124 bytes,
  `16909ef121dcf7be3b2189d09cb220fb4f86eb278752e1eca3c3fa9d52c39bbc`;
  it reports `M5 core performance R3 cache and key seam | 57 57`.
- `stderr.txt`: 0 bytes,
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.

## Claim boundary

The receipt is a successful focused diagnostic baseline only. It does not
close factorial optimization, performance measurement, two-process/fresh-
process evidence, or any R01--R10 gate. No Julia or DESC command was run by
this postrun reviewer, no product/test/manifest/run file was modified, and no
commit was created. The only writes are this report and its sibling manifest.
