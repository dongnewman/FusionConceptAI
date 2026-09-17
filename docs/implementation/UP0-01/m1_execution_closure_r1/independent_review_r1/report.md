# M1 independent review r1

Decision: `changes_requested`.

Scope: independent review of `m1_execution_closure_r1/**` and its cited read-only AD55/AD35/AD36 inputs. No Julia, S3, DESC, mesh, solver, or physical recomputation was run. This review does not modify the existing M1 directory, source, tests, index, commit, or old archive.

## Findings

1. The independent disk recomputation matches the six HEAD-bound owner rows in the M1 input manifest. HEAD is `b2c04d8339774635aaecd73651efcdb101e01b5d`, branch `main`, and index SHA-256 is `6fb570961008194812a3c260d0c2be840800271fe82a1820d7760459bfddb8e0`. Current status was independently observed as 27 tracked-modified and 7058 untracked paths; this is a later capture than the executor's 7023 untracked count and must not be treated as a contradiction or cleaned.

2. The six owner layers and three AD56 dirty factories remain separate. Owner filtered working OIDs equal their HEAD blob OIDs, including the two raw working-byte line-ending/byte-count differences in G3 realization/control. The three factories are `M` and have distinct filtered working OIDs from their HEAD blobs. No factory working hash was substituted into a HEAD canonical/blob field.

3. Static counts are accurate: the AD55 `s2_probe.jl` imports `SHA`, `JSON3`, `Dates`, and `FusionConceptAI`, has two declaration plus three factory explicit includes; `load_genome_v5_components!` names 12 files in G1/G2/G3 order; `src/FusionConceptAI.jl` has 47 include directive lines; each factory has zero include directive lines. Runtime package resolution, method dispatch, and external dependency provenance remain deferred.

4. AD55 historical F0 PID 106008, S2 run1 PID 103996, and S2 run2 PID 83504 each have exit 0 and raw stdout/stderr hashes in their historical receipts. The 18 deterministic identity/declaration/receipt outputs are referenced only; they are not backfilled as fresh S3 or current authority evidence. The M1 abbreviated historical list omits S2 run2 raw hashes even though the cited AD55 receipt contains them.

5. Environment and process records are non-secret and no Julia/DESC process was captured. The phrase `user forbade Julia execution` is too broad: the prohibition was the scoped M1 execution/review work order, not a global user prohibition; replace it with that scoped wording.

6. Cleanup probe absence is confirmed. However, the existing M1 cleanup inventory and `final_exact_owned_set` use aggregate globs (`archive/**`, `*.json`) instead of exact path rows, contrary to AD35/AD36. Existing files and dirty paths were not modified by this review.

7. Mandatory receipt fields are missing. All six M1 `validation_receipt.json` command entries lack `pid_or_in_process`, `started_utc`, `ended_utc`, `stdout_raw_and_sha256`, `stderr_raw_and_sha256`, `combined_raw_and_sha256`, `input_hashes`, `output_hashes`, and `artifact_hashes`; `raw` is only a wildcard reference. The archive command receipt uses non-contract names (`argv`, `pid`, `start_utc`, `end_utc`), has no input/output/artifact hash maps, and several combined sidecars are summaries rather than raw command output. Command 01 explicitly retained only a bounded status summary. This is a hard AD35 failure even where the content hashes are otherwise consistent.

## Required repair before acceptance

- Re-record all six M1 commands with exact command/cwd, `pid_or_in_process`, UTC start/end, real stdout/stderr/combined raw files and SHA-256, exit code, and explicit input/output/artifact hash maps. Combined raw must be the actual concatenation/capture, not a prose summary; preserve the earlier evidence and append a new round.
- Replace wildcard raw references with exact sidecar paths and correct field names. Include the omitted S2 run2 historical raw hashes in the reference record, without converting historical evidence into fresh S3.
- Replace `archive/**` and `*.json` in the existing cleanup inventory/final set with one exact row per path; preserve all ambiguous and pre-existing paths.
- Narrow `user forbade Julia execution` to the M1 scoped work-order/review prohibition.

Claim ceiling remains `execution_input_reproducibility_preparation`; no source authority, trust root, candidate/final identity, provider, mesh, solver, engineering, physical, search, B00/B04, R01–R10, or L4 credit is granted. The 39-node DAG, R01–R10, and all parent gates remain open.
