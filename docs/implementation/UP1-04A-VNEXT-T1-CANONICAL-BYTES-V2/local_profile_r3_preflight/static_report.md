# VNext T1 canonical bytes V2 local profile R3 preflight

Status: `preflight_only`; accepted: `false`; claim ceiling: `contract_only`.

This R3 profile is frozen against baseline `123e6e4`. Its `runner.ps1` is the
R2 runner with the R2 revision/schema markers replaced exactly by R3 markers;
the manifest re-freezes the current 18 protected assets by byte size and
SHA-256.

No Julia/DESC process was started and no runtime lock or receipt directory was
created during this preflight. The runner is frozen for exactly one invocation:

`julia --startup-file=no --history-file=no --project=. test/GenomeV5/Integration/VNextT1CanonicalBytesV2/vnext_t1_canonical_bytes_v2_tests.jl`

The runner forces `JULIA_NUM_THREADS=1`, refuses a pre-existing atomic
`FileMode.CreateNew` lock or `run_*` receipt, has a 300 second bounded wait and
no retry, records preflight zero Julia/DESC processes, terminates only its own
process tree on timeout, and requires two postflight zero observations 250 ms
apart. It freezes the eight updated V2 assets, `CandidateStatePackageV5Next.jl`,
`FusionConceptAI.jl`, `Project.toml`, `Manifest.toml`, and the five existing
tracked dirty files (including root `README.md`) by byte size and SHA-256.

Static validation performed without launching Julia:

- `python -B .../static_qa_vnext_t1_canonical_bytes_v2.py`: PASS, 28 checks;
  `integration=NOT_CONNECTED`, `runtime=NOT_RUN`.
- `python -B .../independent_oracle_vnext_t1_canonical_bytes_v2.py`: PASS,
  9 cases / 31 checks; `integration=NOT_CONNECTED`, `runtime=NOT_RUN`.
- PowerShell AST parser and manifest/hash contract: PASS; 18 unique protected
  files matched frozen sizes and hashes, and no `runtime.lock` or `run_*`
  receipt artifact exists in this preflight directory.

This preflight grants no T1 or UP1 runtime credit. Runtime acceptance requires
the separately executed immutable runner receipt and independent review.
