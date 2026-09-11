# Static ideal-MHD interface residual/Jacobian slice

Legacy reuse audit: no accepted candidate-bound local traction residual/Jacobian provider was found. Existing generic residual/Jacobian declarations are compiler/ownership contracts and do not provide this interface physics, so they are not wrapped.

This isolated edge consumes one exact, sealed traction-result subset. The request binds the traction request/result hashes, candidate hash, and ordered interface specification hashes. Execution rejects a foreign candidate/result, reordered or replaced interface identities, and state-count mismatch.

For state order `(p-, Bx-, By-, Bz-, p+, Bx+, By+, Bz+)`, the residual is the three-component outward-normal traction sum plus the common-orientation normal-field jump. The analytic 4x8 Jacobian uses `d t_i / d B_j = (n_i B_j - delta_ij (B dot n) - B_i n_j) / mu0`.

Independent central differences use per-column perturbations of `1e-3 Pa` for pressure and `1e-4 T` for magnetic components, with frozen maximum absolute derivative discrepancy `1e-5`. Result validation recomputes every residual, analytic Jacobian, FD Jacobian, and hash from the sealed inputs.

The states remain finite-offset `c-epsilon`/`c+epsilon` proxies, not boundary limits. This slice owns only the local interface subset. It does not validate all jump conditions, assemble regional/global residuals, run a solver, establish multiregion closure, or grant physical, engineering, evidence, promotion, P5, terminal, or device authority.
