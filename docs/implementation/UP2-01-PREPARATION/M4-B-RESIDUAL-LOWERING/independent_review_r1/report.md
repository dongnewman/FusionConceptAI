# M4-B residual lowering independent review R1

Decision: `pass_limited` for the isolated M4-B manufactured residual-lowering
slice only. Reviewer: independent Luna `/root/m4b_review` (`gpt-5.6-luna`,
high). This review did not edit any source, test, oracle, shared entrypoint,
registry, project file, candidate, provider, or upstream evidence.

## Frozen inputs and review basis

Frozen HEAD is `b2c04d8339774635aaecd73651efcdb101e01b5d`. The reviewed final
inputs are:

- `src/RuntimeV4/M4Isolated/ManufacturedEquationIRV1.jl` —
  `0b456dcc0df3bd13a1941aa502a9cc5347912b2fa86cda6c65900449299b8e57`;
- `src/RuntimeV4/M4Isolated/ManufacturedResidualLoweringV1.jl` —
  `0445ec58f35ebbf5e34ae032611befab7050a0a65d2a376ccd37b71a0e9a936c`;
- `test/RuntimeV4/M4Isolated/manufactured_residual_lowering_v1_tests.jl` —
  `c7032beecfcca29db8a751eec4aaf4797eadfed66b12e8da611c392783740f73`;
- `test/RuntimeV4/M4Isolated/oracles/residual_lowering_oracle_v1.py` —
  `0d89c69ab3689a0cf7cde9756f95a76b8f7e4c8fc93a7a99ed9aa460bd5781fd`.

M4-A is independently `accepted_limited` at
`../M4-A-EQUATION-IR/root_acceptance_r1/`, with its ceiling still
`manufactured_control/screen_only`. The delivery, repaired test execution,
and integration records were read in full for their scope, ownership, raw
evidence, and failure history.

## Code and contract review

The B source is isolated behind a guarded include of M4-A and produces only a
declaration-level analytic residual. It does not define or invoke mesh,
discrete, assembly, coupling, solver, topology transfer, candidate, provider,
physics, or engineering paths. The typed failure type has stable `code`,
`path`, and `detail` fields. The repaired two-input validator materializes
`result.failures` as a typed `ManufacturedResidualLoweringFailureV1` vector
before appending owner-binding failures; this is the causal fix for the
preserved initial `Vector{Union{}}` error.

Owner review passed: source owner is copied from `ir.source.owner`, the
conservation owner is required to be the sole input conservation owner, and
foreign source/conservation owner controls return `:owner_mismatch`. The
intentional distinction between `M4-A-manufactured-source` and
`M4-A-equation-balance` is retained and tested.

The independent Fraction oracle recomputes the exact terms
`1/10`, `1/20`, `1/30`, total `11/60`, source `-11/60`, and residual `0`.
The B implementation and tests bind these exact manufactured-control values,
including sign, units, provenance, deterministic payload, and deferred
time/multifield scopes. This is an analytic frozen control, not a claim of
general symbolic PDE lowering; that limitation is within the authorized
screen-only ceiling.

The first B test history is preserved and causally consistent: Julia exit 1,
`51 pass / 2 error`, caused by collecting an empty failure tuple as
`Vector{Union{}}` before the owner-binding `push!`. One typed-vector source
repair was made by the separate source role; no test relaxation occurred.
The upstream integration preflight PowerShell capture collision is retained
under `../integration_r1/archive/harness_capture_abort_20260916T0718Z/` and
is explicitly non-counted.

## Fresh independent execution

Fresh processes were run strictly serially, Python before Julia:

| sequence | PID | exit | result | combined SHA-256 |
|---:|---:|---:|---|---|
| Python oracle | 75120 | 0 | exact Fraction payload | `4e1d41a4704d27f9809f458e973672bd9b743127a01b958fa5cba8f4531a80b3` |
| Julia B tests | 94064 | 0 | `53/53` | `11f8ac5615e49c620a822fda6ab497709a9b33a695abdcd4227d0bca4cabe10f` |

Both stderr streams are empty. Exact commands, cwd, UTC intervals, PIDs,
exit codes, input hashes, output hashes, and raw paths are in the adjacent
receipts; the static boundary/hash audit is retained in `raw/`.

## Independence, cleanup, and decision boundary

The source implementer, test/oracle owner, integration owner, documentation
owner, and this independent reviewer are pairwise-distinct Luna roles. The
review is independent of all product authors. The current target files are
untracked additions at this frozen HEAD, while `git diff` for
`src/RuntimeV4/RuntimeV4.jl`, `Project.toml`, and `Manifest.toml` is empty;
unrelated dirty worktree state was preserved. No broad cleanup, staging,
revert, or deletion was performed.

This `pass_limited` does not accept or credit `UP2-01`, `UP2`, B00, B04,
provider, mesh, engineering, physical evidence, R01-R10, or L4. It grants no
authorization for M4-C or M4-D; both remain unauthorized. The formal route
remains `T0 → authority recheck → T1 → T2 → aggregate → UP2-00 → UP1-04B →
UP1-04 → UP2-01`. Separate Sol/root `accepted_limited` acceptance is still
required.

