# N2 source-bound DESC replay (W22)

This is an additive, opt-in diagnostic path from the N2 candidate-bound G2
source representation to a **fresh** DESC fixed-boundary equilibrium solve.
It neither changes `default_operator_registry()` nor admits the older
single-power DESC interpreter to NFP 19 / L 24. The selected HDF5 member is
used to verify provenance and the representation; it is **not** loaded as the
replay's initial state. The replay therefore tests the same boundary, flux,
pressure and iota physical subject, not equality of initial interior states.

`N2SourceDESCReplayRequestV4.jl` rebinds the candidate and rereads source,
normalized, interior and raw-member-join artifacts. It freezes selected member
3 of 4, Fourier-Zernike `fringe`, surface `linear`, even-power profiles,
NFP 19, L/M/N 24/12/3, grid 36/18/6, the four R and three Z boundary modes,
1 Wb flux, and a force / lsq-exact replay capped at three optimizer iterations.
It rejects promoted authority, including forged request and member-receipt
flags. The emitted request is screen-only and has no provider evidence credit.

The Python adapter requires the independently frozen r2 request-file SHA256
`6b7dfba27172b52ca206b8bcbc6ea43aeafe08bba2e82706fef4826a4c981abe`.
The Julia canonical `request_hash` is recorded but not independently recomputed
by Python; the byte hash is the cross-language admission pin. The adapter
revalidates the raw HDF5 join, reconstructs an `Equilibrium` from normalized
fields, supplies explicit even profile powers, checks the constructed and
solved boundary/profile/flux/basis fields, writes a pre-solve checkpoint, then
performs only the bounded opt-in solve. It never substitutes source solved
interior coefficients or silently reduces resolution/field periods.

The recorded replay command (from the repository root, in PowerShell) was:

```powershell
& 'D:\006-Programing\LMC\outputs\fusion_concept_ai\.venv-desc\Scripts\python.exe' `
  benchmarks/desc_heliotron_v0173/source_replay_adapter.py `
  runs/goal_recovery_20260913_012528_cst/n2_source_desc_replay_request_r2/request.json `
  runs/goal_recovery_20260913_012528_cst/n2_source_desc_solve_r3 `
  --expected-request-sha256 6b7dfba27172b52ca206b8bcbc6ea43aeafe08bba2e82706fef4826a4c981abe --solve
```

## Recorded r3 outcome

- Julia request tests: 27/27 identity/input checks and 10/10 negative tests;
  process exit 0. Request writer process exit 0.
- Python DESC-v0.17.3 tests: 5/5, including fresh construction, saved-output
  reimport, and exact even-power pressure and iota functions; process exit 0. Construct-only r5
  process exit 0. Earlier r1-r4 construct attempts were diagnostic API/verification
  failures and are not acceptance artifacts.
- Bounded DESC solve r3 process exit 0, optimizer `success=false` after 3/3
  iterations with message "Maximum number of iterations has been exceeded."
  Its 4,940-element force residual vector is finite but has L2 norm
  0.11682848292227506 and maximum absolute component 0.012152898080190622.
  The result status is `solver_nonconverged_screen_only`.
- Independent reimport of the saved HDF5 exits 0 and matches the recorded
  HDF5 SHA256 `514ea7d911bacc378781e09b7105e922932adcfe438e0e98c7636b11eaec0b6e`.
  It reports NFP 19, L/M/N 24/12/3, grid 36/18/6, 1 Wb, `fringe`, even
  pressure/iota, pressure (18000, 10125, 0) Pa and iota (1, 1.375, 2.5)
  at rho (0, 0.5, 1). All 84 additional R and 84 additional Z surface
  basis coefficients remain exactly zero. Coefficient L2 distances to original source member 3
  are R 0.23047280850048268 and Z 0.10955878079378872; these are only
  same-family diagnostic distances, not an independent equilibrium validation.

The solver's normal **process** exit is not solver convergence. The current
result does not establish physical convergence, independent spatial agreement,
global chart admissibility (the closed polar chart is singular at the axis),
genuine inverse recovery, held-out prediction, measurement agreement, net
electricity, originality, or a credible device. R01-R10 remain unaccepted.
The next physics slice must specify a residual/convergence criterion and a
source-matched independent spatial map, while respecting the exact source
Fourier-Zernike and profile semantics.

Reproducibility caveat: this checkout has `core.autocrlf=true`, while the new
request and hash-bearing adapter/builder sources currently have LF working-tree
bytes and no path-specific Git EOL attribute. A fresh Windows checkout may
materialize CRLF bytes and invalidate the frozen request/source SHA pins.
This run is byte-reproducible on the recorded worktree, but not yet a portable
cross-checkout replay certificate. Any EOL policy adjustment should be audited
as a separate scoped change; do not silently accept rehashed inputs.
