# RuntimeV4 3-D discretization-controls report — 2026-09-10

## Result

The fourth accepted `ThreeDPhysicalProviderInputV4` gap now has an isolated
typed compiler slice. Generic G2 remains a recoverable gap. The manufactured
fixture returns `input_complete` only after matching all five declared controls
to current oriented volume/trace/multiplier spaces and reconstructing the exact
candidate, G2, oriented-interface, mission, bounds, scenario, and subject-
binding identities.

The declaration includes bounded mesh resolution and orders, explicit
nonlinear/Jacobian and linear/preconditioner policies, finite positive
tolerances, bounded iterations, and an explicit refinement policy.

## Verification

- focused tests: 106/106, exit code 0;
- standalone example: probe exit code 0;
- standalone runner: 106/106, exit code 0;
- RuntimeV4 core: 26/26, exit code 0;
- RuntimeV4 spine: 54/54, exit code 0;
- owned-slice whitespace validation: clean.

## Boundary

`input_complete` is manufactured input compilation only. No provider or solver
was selected or executed; no evidence or pass was emitted; no P5, validation,
promotion, or terminal authority was granted. Credible physical-device count
remains **0**.
