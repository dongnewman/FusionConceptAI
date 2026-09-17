# E1 N05 receipt-export focused R5 independent postrun review

Verdict: `pass_limited`; `accepted=false`. This review did not run Julia/DESC and did not modify focused R5, source, tests, or core documents.

The positive envelope is `22402` bytes with SHA-256 `777d120fc9bdfb10933e296b28b8d04cac97009d9998ae2073bcc2d075c35fea`, containing five authored typed and five absent-authority rows. Independent parsing checks candidate/package/E0/declaration identities, source locator paths/types/refs/hashes, typed canonical value hashes, mutation hashes, field/error paths, authored `invalid_closure`/`invalid_type` fail-closed rows, and absent `authority_gap` terminal-deferred rows with unchanged values.

All seven forged files match their manifest bytes/SHA and differ from the positive envelope only at their named target field (the omitted-row control changes only the authored row count). Manifest messages are targeted: source recomputation, mutation hash, candidate, package, E0 binding, declaration hash, and authored count. The test path writes each forged file and calls the file-read checker.

The real focused receipt records exit `0`, N05 `24/24`, wrapper PID `53928`, Julia PID `56492`, UTC `2026-09-14T06:04:56.2585284Z` to `2026-09-14T06:05:55.3162399Z`, empty stderr, protected before/after equality, and empty postflight. R1/R2/R3 failures and R4 history remain preserved.

Local source-bound serialization/file-read scope passes. The full gate remains `changes_requested`: the trusted expected-row recomputation shares exporter helper `_n05e_row`, and no separately audited checker/two-process independence boundary is established. Shared `_n05e_row` is therefore a formal B04/full-gate independence limitation, not a reason to discard the local receipt-export evidence. No B04, provider, mesh, engineering, physical, two-process, or R credit is granted.
