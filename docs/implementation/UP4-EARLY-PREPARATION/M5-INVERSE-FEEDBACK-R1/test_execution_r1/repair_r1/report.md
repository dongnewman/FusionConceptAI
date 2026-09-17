# M5 inverse-feedback repair R1

Status: pass (203/203 Julia tests). This repair adapts only the Julia test to the P1 source
layout with retained nested M4-D/M5-A snapshots. The independent Python
oracle and all parent R1 evidence remain unchanged.

The repair adds typed no-exception corruption regressions for every stored
derived field, composition hash, nested source/hash/identity/owner/provenance,
and joint owner/provenance mutations. It remains
`manufactured_inverse_feedback/screen_only`, with no UP4-01/02 formal credit.

Fresh serial execution: Python PID 87684 exited 0 at
2026-09-16T12:41:32.0296190Z; Julia PID 113120 then exited 0 at
2026-09-16T12:43:05.0933110Z. Raw stdout/stderr are retained in both `raw/`
and `archive/raw/`, with hashes and input/output maps in
`execution_summary.json` and per-process receipts. The P1 source SHA256 is
`f0dcf8aa0dc199a4e3404ecec1a4f516b899e1cfd523454d698f9afe91553976`.
