# VNext T1 candidate binding V2 local profile R1 preflight

Status: `preflight_only`; accepted: `false`; claim ceiling: `contract_only`.

This immutable profile is frozen against baseline `f324d56`. It protects 19
unique input files: the eight binding assets,
`VNextT1CanonicalBytesV2.jl`, `CandidateStatePackageV5Next.jl`,
`FusionConceptAI.jl`, `Project.toml`, `Manifest.toml`, and the six existing
tracked dirty files, all by exact byte size and SHA-256. The runner itself is a
separate self-contract (not a protected input and not recursively listed in
`protected_files`): `runner.ps1` (`runner_self_bytes=14696`), with canonical
`runner_self_sha256`
`d9299ae4e8aadfeac96a753e1671505ad602632c6b7417709c2579024732cfb9` fixed
in `manifest.json`. At startup it verifies its raw byte size and canonical
SHA-256 after replacing only that fixed hash literal with 64 zeroes, avoiding
manifest/self-hash recursion.

No Julia/DESC process was started during preflight. No `runtime.lock` or
`run_*` receipt directory exists yet; those are expected one-time attempt
outputs created only when the runner is explicitly invoked. The runner permits
exactly one invocation:

`julia --startup-file=no --history-file=no --project=. test/GenomeV5/Integration/VNextT1CandidateBindingV2/vnext_t1_candidate_binding_v2_tests.jl`

It forces `JULIA_NUM_THREADS=1`, atomically creates `runtime.lock` with
`FileMode.CreateNew`, refuses any existing lock or `run_*` receipt, uses a 300
second `WaitForExit(milliseconds)` bound without retry, requires zero
Julia/DESC processes before launch, terminates only its own process tree after
timeout, and requires two zero-process postflight observations 250 ms apart.

Static validation performed without Julia:

- static QA: PASS, 23 checks; `integration=NOT_CONNECTED`, `runtime=NOT_RUN`;
- independent Python oracle: PASS, 13 checks;
- PowerShell AST parse, exact command/policy checks, JSON parse and frozen
  19-file hash/size contract: PASS;
- no `runtime.lock` or `run_*` receipt exists in this directory.

This preflight grants no T1, integration or UP1 runtime credit. Acceptance
requires a separately executed immutable receipt and independent review.
