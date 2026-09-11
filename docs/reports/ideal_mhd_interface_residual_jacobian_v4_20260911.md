# Ideal-MHD interface residual/Jacobian report

Implemented an isolated, candidate-bound static magnetostatic interface subset. It evaluates `(t_minus + t_plus, B_minus dot n_minus + B_plus dot n_plus)` in residual units `(Pa, Pa, Pa, T)` and an analytic 4x8 Jacobian for the ordered two-sided pressure/magnetic state.

Verification on 2026-09-11:

- focused test: `12/12`, definitive exit code `0`;
- standalone runner: `IDEAL_MHD_INTERFACE_RESIDUAL_JACOBIAN_RUN_EXIT_CODE=0`;
- adversarial controls reject a foreign candidate, replaced interface subset, and canonical-rehashed altered residual;
- independent read-only review: `ACCEPT`, with no P1/P2 blocker.

Authority remains `screen_only`. Full jump conditions, regional/global residuals, solver convergence, `multiregion_closure`, physical/engineering validation, evidence, promotion, P5, terminal authority, and credible physical-device count remain false/zero.
