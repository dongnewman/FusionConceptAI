# M1 independent review R2

Decision: `changes_requested` (`review_pending`; no acceptance).

The R2 repair fixed the raw sidecar hashes and exact cleanup enumeration, but it did not satisfy the mandatory receipt schema. The R2 `validation_receipt.json` only embeds six references and omits `command`, `cwd`, `input_hashes`, `output_hashes`, `artifact_hashes`, and uses `exit` rather than `exit_code`. Its referenced `archive/repair_r2/command_receipts.json` has exact commands, in-process markers, UTC times, raw sidecar/hash maps and hash maps, but all six entries omit `cwd` and use `exit` rather than `exit_code`. Therefore the required exact command/cwd/exit contract is still unmet.

Independent checks confirm all six R2 stdout/stderr/combined sidecar hashes match disk, combined equals stdout with empty stderr, and the command-receipts file hash is `63ae6b2b856ccfd8663bf217f19fd5683d19ad783e351c50fc404d4b8c59435a`. Cleanup has 66 exact rows: 44 executor-owned plus 22 reviewer references, union 66, intersection 0, and zero glob paths. However, its `probe_path` checks `docs/implementation/AD-55/.../probe.txt`; no row records the earlier M1 `probe.txt` deletion, so that specific cleanup proof is incomplete.

HEAD, branch, index, six owners, three dirty AD56 factories, and the 12/47/0 static closure agree with the frozen inputs. AD55 S2 run2 has PID 83504, exit 0, stdout SHA-256 `81036d5a60f5c15455c9e80915b0a11c432000e91d2ee07875f67b93aa16a14d`, stderr SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`; the 18 canonical outputs remain reference-only. The report correctly says the Julia ban was a scoped work-order/review prohibition. No Julia/S3/DESC/mesh/solver was run.

Required repair: append a new receipt round preserving R2, with exact `command`, `cwd`, `pid_or_in_process`, `started_utc`, `ended_utc`, `exit_code`, raw/hash maps, and explicit input/output/artifact hash maps in the validation receipt and command-receipts record; and add an exact row proving the actual M1 scratch probe deletion (or explicitly reference the prior R1 row without mislabeling the AD55 path). Keep all parent gates, 39-node DAG, R01–R10 and claim ceiling unchanged.
