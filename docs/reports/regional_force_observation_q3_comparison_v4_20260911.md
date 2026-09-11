# Regional force q=3 comparison report

The q=3 run is a fresh candidate-bound execution through the existing DESC field and basis providers. It records per-region and total q=2/q=3 force vectors with absolute and relative differences. The result remains a numerical screen: no convergence, V&V/UQ evidence, physical validation, or promotion authority is granted.

## Accepted verification

- `julia --startup-file=no --project=. test/runtime_v4_regional_force_observation_q3_comparison_tests.jl`: 18/18 assertions, exit 0. The focused gate executes an independent provider replay under a distinct artifact path.
- `julia --startup-file=no --project=. scripts/run_v4_regional_force_observation_q3_comparison.jl`: exit 0 with `REGIONAL_FORCE_Q3_COMPARISON_EXIT_CODE=0`.
- The standalone run used a unique temporary root, so concurrent executions cannot overwrite the sealed upstream or q=3 artifacts.

The accepted standalone observation was:

- q=2 total force: `(-276831.53837849235, -201129.8857251238, 2.3792381398379803e-9) N`
- q=3 total force: `(122710.66715773735, 89154.5183300111, 6.461959856096655e-9) N`
- absolute difference: `493861.3259229757 N`
- relative difference: `1.4432683785832432`

The large q=2/q=3 change is evidence against claiming quadrature convergence. It is retained as a measured numerical non-closure signal. During acceptance, shared fixed run paths first triggered a valid receipt-tamper rejection; all nested provider paths were then isolated. The replay comparison also exposed and fixed unsupported tuple-level `isapprox` calls by comparing every vector component explicitly.
