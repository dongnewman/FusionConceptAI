# VNext T1 candidate binding V2 local profile R2 preflight

Status: `preflight_only`; accepted: `false`; claim ceiling: `contract_only`.

This immutable R2 profile is frozen against baseline `6bfdc6c`. It protects 19
unique input files: the eight current binding assets,
`VNextT1CanonicalBytesV2.jl`, `CandidateStatePackageV5Next.jl`,
`FusionConceptAI.jl`, `Project.toml`, `Manifest.toml`, and the six existing
tracked dirty files, all by exact byte size and SHA-256. The runner is a
separate self-contract and is not recursively listed in `protected_files`:
`runner.ps1` (`runner_self_bytes=14696`), with canonical
`runner_self_sha256`
`2ee39852b5a389ab8436027c3bb3b9e2ffc018cbb26ea16da7d2094931146b2f`
fixed in `manifest.json`. Before creating its lock, it verifies raw byte size
and SHA-256 after replacing only that fixed hash literal with 64 ASCII zeroes.

No Julia/DESC process is started by this preflight. No `runtime.lock` or
`run_*` receipt directory exists yet. The runner permits exactly one explicit
invocation:

`julia --startup-file=no --history-file=no --project=. test/GenomeV5/Integration/VNextT1CandidateBindingV2/vnext_t1_candidate_binding_v2_tests.jl`

It forces `JULIA_NUM_THREADS=1`, atomically creates an R2-local
`runtime.lock`, refuses any existing lock or `run_*` receipt, uses a 300-second
`WaitForExit(milliseconds)` bound without retry, requires zero Julia/DESC
processes before launch, terminates only its owned process tree on timeout, and
requires two zero-process postflight observations 250 ms apart. Runtime
metadata uses the independent R2 schemas
`VNextT1CandidateBindingV2R2RunMetadataV1` and
`VNextT1CandidateBindingV2R2CaptureFailureV1`.

Static validation performed without Julia:

- binding static QA expected: PASS, 26 checks;
- independent Python oracle expected: PASS, 14 checks;
- PowerShell AST parse, exact command/policy checks, JSON parse, runner
  canonical self-hash and frozen 19-file hash/size contract: PASS;
- no `runtime.lock` or `run_*` receipt exists in this R2 directory.

This preflight grants no T1, integration or UP1 runtime credit. Acceptance
requires the separately authorized single immutable runtime attempt and an
independent review.
