# DESC static-MHD balance provider milestone

The provider is a fresh candidate-bound DESC 0.17.3 slice at exact
`c±epsilon` points. It checks native metadata, sealed surface positions and
upstream identities, maps `rtz` physical vectors to Cartesian, and
cross-checks DESC `F = J x B - grad(p)` through sealed-output replay.

Verification on 2026-09-11:

- focused test: `17/17`, definitive exit code `0`;
- standalone runner: `DESC_STATIC_MHD_BALANCE_PROVIDER_RUN_EXIT_CODE=0`;
- upstream ideal-MHD traction regression: `62/62`, definitive exit code `0`;
- real sample count: `2`;
- maximum `norm(F - (J x B - grad(p)))`: `2.917479820525012e-11 N m^-3`;
- sampled force-balance norms: `106281.21614425664` and
  `106649.52525967159 N m^-3`;
- independent read-only review: `ACCEPT`, with no P1/P2 blocker.

The large sampled force-balance norms are a measured non-closure signal, not
an equilibrium-validation result. Authority therefore remains `screen_only`:
regional PDE residual/Jacobian, solver convergence, multiregion closure,
physical/engineering validation, evidence, promotion, P5, terminal authority,
and device credit remain false/zero. No manufactured result is treated as
physical evidence.
