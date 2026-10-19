# T2 attempt 11 retry 8: root runtime grant

Decision: **GO for one exact bounded controller invocation only**. This is not T2 acceptance, scientific acceptance, or authority credit.

## Frozen inputs and independent review

- HEAD: `63792ca22958ffca8c3fa8e642256eb9f7240724`.
- Protocol SHA-256: `e5ddc50030d82c1532dd18538f06adabcc7b10d3500241075c4062a813c5b965`; command SHA-256: `a18d3cc0b4f9ceb158ae53cb59c9d47b75ce1f71ade13456eaa1ff775c608768`; snapshot SHA-256: `8da9bce3f77842417ac9fb8fcd51fe461fb312bcadac056c5171f56b93aa9701`; static QA SHA-256: `ed0e3ad8a800cd6647bcb3acca1405025c6b65631f662c26c509bfba178ed92a`.
- Reviewer `/root/t2_review` sealed GO for one bounded attempt: `independent_attempt11_retry8_preflight_review_20260924_r1/review.json` SHA-256 `0915889499fee7714e8db951ef0af0f2ac331984acd9da3332e8c24b7ea46b81`; 166/166 static controls, 26/26 direct fakes, 459 pins, 214 source locations.
- Independent tester `/root/t2_independent_tests` sealed GO for one bounded attempt: `independent_t2_attempt11_retry8_static_tester_20260924_v3/independent_review_receipt.json` SHA-256 `1ded64af9c6f21bcb2cc701774b277d1e5a0d4d64e4897b5a3b962816828a789`; 459/459 pins and 166/166 QA controls. Earlier tester-only errors remain preserved in their own leaves.
- Root preflight: protected dirty tracked files 40/40 match baseline; HEAD matches; planned output leaf is absent. Retry 7 remains revoked and untouched.

## Execution scope

Run the exact `command_argv.json` through this leaf's `run_once.py` with `D:\Users\Newman\anaconda3\python.exe -B` from the repository root. The launcher rechecks protocol, command, snapshot, static QA, 459 input pins, 40 dirty pins, HEAD, output absence, environment, argv and empty heavy lane immediately before invocation. It writes raw stdout/stderr, child exit code, command and invocation receipts in this leaf. The frozen controller enforces 480 s ordinary phase, 600 s preflight, 2400 s authority phase/case, sampled 2 GiB process tree, and Julia/BLAS thread counts of one. The 30 phase caps sum to 16,440 s plus setup/interphase/finalization; there is no single end-to-end controller timeout. No second invocation is granted by this decision.

After the controller exits, inspect actual source hits, case results, process-tree audit, hashes and failure classifications. Any nonzero or incomplete run stays as failure evidence. No acceptance is inferred from the process exit code alone.
