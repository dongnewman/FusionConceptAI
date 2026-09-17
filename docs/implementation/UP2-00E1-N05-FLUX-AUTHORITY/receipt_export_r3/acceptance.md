# UP2-00E1 N05 receipt export R3

Status: `review_pending`; `accepted=false`.

R3 adds a file-read trusted-check path and candidate-bound forgery controls to
the new receipt-export test. The test writes one append-only JSON envelope,
re-reads it with JSON3, and invokes the production trusted checker overload.
It then submits forged candidate/package/E0/declaration identity fields, a
forged source hash, a forged absent mutation hash, and an omitted authored row
to that same overload; each must be rejected from the actual package/E0/
authority reconstruction. The existing five authored fail-closed and five
absent terminal-deferred row boundary, exact absent hash formula, and zero
downstream counters remain unchanged.

Only the new receipt-export test was edited. The R4 N05 source/test/fixture/
runner, receipt exporter/checker, receipt-export runner, and old R1/R2 archives
are protected and hash-checked. No Julia/DESC execution occurred. This archive
is a static repair handoff for independent R3 review, not runtime acceptance.
