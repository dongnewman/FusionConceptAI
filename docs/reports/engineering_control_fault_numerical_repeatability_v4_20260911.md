# ECF numerical repeatability report

The new edge performs two isolated fresh-Julia executions of the current
candidate-bound trusted engineering-control/fault operational screen. Each
observation binds process ID, executable identity/version, Project/Manifest
hash, child source hash, current context/request/receipt identities, result and
trace hashes, and count observables. The parent validator independently
revalidates the registry, operational receipt, non-bridge, request and result;
it rejects process reuse, changed trace/result/count values, and authority
escalation.

This is manufactured operational repeatability only. It is not generic V&V/UQ,
physical validation, engineering qualification, whole-device closure or
promotion evidence. All such flags remain false, claim ceiling is
`screen_only`, and credible device count is zero.

Verification completed on 2026-09-12:

- `test/runtime_v4_ecf_numerical_repeatability_tests.jl`: 15/15, explicit focused exit marker, process exit 0.
- `scripts/run_v4_ecf_numerical_repeatability.jl`: two distinct Julia process IDs, `repeatability_passed=true`, explicit standalone exit marker, process exit 0.
- trusted ECF provider regression: 127/127, explicit exit marker, process exit 0.
- ECF/VVUQ whole-device non-bridge regression: 42/42, explicit exit marker, process exit 0.
- package-wide `test/runtests.jl`: process exit 0.

The exact trace repetition is software/numerical repeatability of the current
manufactured operational screen. It is not physical validation, engineering
qualification, generic V&V/UQ evidence, or whole-device closure.
