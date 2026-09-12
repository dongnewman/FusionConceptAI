# Regional-force independent cubature report (2026-09-12)

The runner uses the current 17-entry candidate/partition/DESC chain and fresh provider executions. The independent formulation maps each rho interval to five equal cells and uses cell midpoints for rho, theta, and zeta. Each node weight is `(rho_upper-rho_lower)/5 * 4*pi^2/25`; this is independently implemented from q4's Gauss-4 radial rule.

Focused test command:

`julia --project=. test/runtime_v4_regional_force_independent_cubature_tests.jl`

Standalone command:

`julia --project=. scripts/run_v4_regional_force_independent_cubature.jl`

The exact exit-code markers are emitted by both commands. Numerical status is computed against q4 with explicit `relative_tolerance=1e-3` and `absolute_tolerance_N=1e-6`; the result is honestly `pass` or `fail` according to those values. Regardless of numerical status, this artifact remains `screen_only`, with zero validation/UQ/promotion/device authority and no independent-code-validation credit because DESC provider and basis bridge code are shared.

The initially running focused process finished with **exit 1**, because the
isolated `Main.RFIC` module lacked `DESCFieldSamplePointV4`. The example's module
ownership is repaired for the shared candidate runner; no duplicate focused
provider chain was started. Additionally, its vector totals are now identified
as sector-replicated Cartesian proxies for NFP > 1. They are retained for
reproducibility, while `CandidateValidationPropagationV4.jl` performs the
independent periodic vector reconstruction and scalar local-residual diagnostic.

Shared-run acceptance: the repaired upstream chain has emitted exit marker 0,
and the downstream real-chain validation receipt checks passed 12/12. The two
Julia periodic reconstructions passed 10/10 agreement checks, with maximum
regional force-vector difference `1.0196054494538394e-11 N`; main accounting
passed 24/24. These are shared-data implementation checks, not independent
physics validation. The independent-cubature checks then passed **25/25** in
that same real-provider run; the complete integration suite passed **108/108**.
Both `integrated.exit` and `runner.exit` are **0**, and the execution manifest
was generated. The pre-repair isolated focused **exit 1** remains part of the
preserved history; the shared checks establish the repair without launching a
duplicate provider chain. The actual scientific verdict remains numerical
**fail**, physical validation/UQ **unsupported**, and whole-device **deferred**,
with no device credibility. Separate spine/package regressions were still
running at component handoff and are reported by the main acceptance report.
The detailed numerical failure and Python raw-output cross-check appear in
`candidate_validation_propagation_v4_20260912.md`.
