# E1-N05 independent post-run review R1

Verdict: **pass_limited**. This is an independent review of the author's focused R4 run; it does not promote acceptance.

The four frozen inputs match exactly: source `3697d0db47adb339d7ae11cced4c4cc2eed1e1bc2f8b314c3001d479fae0c9df`, test `57b83ca321cf61b284656cd238356943b2521b4d80029e8a8424706117d42543`, fixture `049fcc585f97245a745737733dd9aae6904e80b4cc09067dbc37a9528ab81d81`, and runner `3d51de1a65d6c48afae0aa57877d63c29600d061799f324fcf48a436b8cebca3`. The immutable receipt records main PID `76372`, UTC `04:15:52.7396002Z` to `04:22:36.4267490Z`, real exit `0`, stdout `9906` bytes with SHA256 `499225ca2dab794155405b4ae7546954c553833e765aa7e9501d179bf300c268`, stderr `0` bytes with SHA256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`, and an empty post-process sweep.

The raw stdout contains the seven E1 groups with exact results `9/9`, `30/30`, `22/22`, `61/61`, `7/7`, `3/3`, and `1/1`. Independent source/test review confirms actual A plus E0 binding construction, baseline validation before mutation receipts, candidate/package/G1/G2 identity joins, typed law and separate authored unit provenance, exact four-field G1 occurrence matching, receipt source paths and zero compile/provider/solver counters, deferred authority gaps, and adversarial foreign/duplicate/relabelled-ID cases.

The current root evidence remains `status=review_pending`, `accepted=false`, and contract-only. B00/B04, provider, mesh, engineering, physical, and R01-R10 claims remain false. Focused R1-R3 failures and their raw artifacts remain present; they are historical evidence and were not overwritten.

This review did not start Julia/DESC or rerun the runner. The runner's stdout and tests verify receipt fields and counters, but no separate per-mutation receipt JSON is emitted, so this remains `pass_limited` review evidence rather than acceptance.

Structured checks are in [report.json](report.json), raw command evidence is in [command_receipts.json](command_receipts.json), and the author receipt is [focused_r4/receipt.json](../focused_r4/receipt.json). Any frozen-input change invalidates this review.
