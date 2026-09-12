# Regional force q=4 comparison report

The q4 ladder consumes and validates the real upstream q2/q3 execution chain,
executes fresh DESC field and basis providers at 64 nodes per declared region,
and records q2/q3/q4 regional and total forces plus both successive norm
differences. Its output artifact and runtime/source identities are sealed.

The protocol is `successive_q2_q3_q4_latest_pair_with_reduction`. The accepted
run produced:

- q2-to-q3 relative difference: `1.4432683785832432`;
- q3-to-q4 relative difference: `0.7209778257208969`;
- q4 total force (N):
  `(34238.997157592516, 24876.08755124405, 1.4402985470951535e-8)`;
- convergence status: `fail`.

The latest difference decreased, but it did not satisfy the declared `1e-3`
relative or `1e-6 N` absolute tolerance. The result therefore does not support
quadrature convergence.

Reproduction and acceptance evidence:

```text
julia --project=. test/runtime_v4_regional_force_observation_q4_comparison_tests.jl
Test Summary:                                   | Pass  Total     Time
real q2/q3/q4 regional-force convergence ladder |   33     33  6m41.9s
REGIONAL_FORCE_Q4_COMPARISON_FOCUSED_EXIT_CODE=0

julia --project=. scripts/run_v4_regional_force_observation_q4_comparison.jl
q2_q3_relative_difference=1.4432683785832432
q3_q4_relative_difference=0.7209778257208969
q4_total_force_N=(34238.997157592516, 24876.08755124405, 1.4402985470951535e-8)
q4_convergence_status=fail
REGIONAL_FORCE_Q4_COMPARISON_EXIT_CODE=0

julia --project=. test/runtests.jl
Q4_PACKAGE_REGRESSION_RETRY_EXIT_CODE=0
```

The focused test includes a separately written q4 replay artifact and compares
its force values and convergence decision with the primary q4 execution. It
also rejects missing, duplicate, and remapped nodes, forged force/status/
authority data, and foreign or missing provider/output receipt identities.
Canonical validation proves internal consistency; the full-chain validator is
required to bind the stored partition and q3 hashes to their concrete upstream
objects.

This remains `screen_only` with zero evidence credit and is not independent-code
validation, physical validation, UQ, promotion authority, or closure.
