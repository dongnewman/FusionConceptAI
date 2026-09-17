# G-I1A focused R1 independent post-run failure audit

## Verdict

`program_exception/repair_required`; `accepted=false`; `runtime_pass=false`.
This is a read-only audit of the frozen run evidence in `focused_r1/`. No Julia or DESC was started by this review, and no source, test, core document, prior receipt, or original focused artifact was modified. No GI1A, B00, B04, provider, mesh, engineering, physical, or R01–R10 credit is granted.

## Frozen run evidence

The sealed receipt is the `run=r2` attempt stored under `focused_r1/`: command `julia --startup-file=no --project=. test/GenomeV5/UP2/run_gi1_authority_context.jl`, PID `86884`, child PIDs `87392` and `82752`, UTC `2026-09-14T07:51:09.2641543Z` through `2026-09-14T07:51:27.3945691Z`, real exit `1`.

The raw output files match the receipt: `stdout_r2.txt` is 1,668 bytes, SHA256 `05EC6DA5B713CB7CE046CB9D4D563354943DF4D2473862584A286288B94386F8`; `stderr_r2.txt` is 314 bytes, SHA256 `AFB5C02F68E8F66E406EBA80528CD7333B301C6CD15243442E1BE2A6B44546EA`.

The output shows the preceding G1 groups actually ran and passed: `UP1-01 G1 V2 contract and fixture-driven component core` **47/47**, and `UP1-01 G1 fail-closed negative controls` **21/21**. The G-I1A group then produced **0 passed, 0 failed, 1 errored**. Stderr is a real `LoadError` with exit 1, not an empty or truncated success receipt.

The first capture record is separately preserved as `capture_error_unknown`: PowerShell assignment to the automatic read-only `$PID` variable prevented sealing that attempt. Its zero-byte `stdout.txt`/`stderr.txt` is explicitly marked as an unsealed capture error and is not treated as a runtime result. It was not misrepresented as a successful run.

## Exact failure and source comparison

The raw stdout stack trace identifies `UndefVarError: G1GenomeContractRef not defined` at `test/GenomeV5/UP2/gi1_authority_context_tests.jl:22`, in `_gi1_package`, reached by the first G-I1A test group. The frozen test input hash at run time was 19,198 bytes, SHA256 `1A4737ACF6A7457B95F5B33B689AAF97866F5F7946BAABB0116200D9FB7472D6`.

The production G1 code defines `G1GenomeContractRefV2` at `src/GenomeV5/G1/GrammarProfileV2.jl:50` and aliases only `GenomeContractRefV2` at line 104. There is no production `G1GenomeContractRef` type. The focused failure therefore is a test/production API name mismatch and is correctly classified as `program_exception`, requiring repair before a valid focused result.

The current worktree test has since drifted to 19,200 bytes, SHA256 `83D765EC5A7FF5867F5E80D1BF4CE2DF2CAB21F55E82D63E4BA579C219A8B1AF`; current line 22 uses `G1GenomeContractRefV2`. The sealed postflight protected hash still records the old 19,198-byte input, so this is post-run workspace drift/repair evidence, not a rerun result. No current pass is inferred from that repair.

## Protected files and process sweep

The receipt's input manifest matched the run-time files for all inputs at capture time. The postflight sweep records empty Julia and DESC process lists. Production GI1A source, fixture, and runner still match their protected after hashes; the test file is the one current post-run drift described above. The focused receipt records source/test/core unchanged by the run itself, and the current process sweep is empty.

## Gate boundary

The only supported conclusion is a real focused runtime `program_exception` caused by the stale test type name, with `repair_required` and a fresh focused run still required. The previous `$PID` capture failure remains historical and separate. This evidence does not establish GI1A acceptance or any downstream B00/B04/physical authority.
