# Regional-force independent cubature V4

This milestone adds a separately written deterministic tensor cubature: five equal radial cells and five midpoint samples in each angular coordinate (125 nodes per partition region). It does not reuse q2/q3/q4 node construction, weights, or force reduction. The typed DESC field provider and candidate-owned metric/basis bridge are executed afresh and their request/result/receipt hashes are bound into the request and receipt.

The comparison is numerical screen evidence only. `independent_code_validation=false` because the provider and basis bridge remain shared upstream implementations; physical validation, UQ, promotion and terminal/device authority are explicitly false and `credible_device_count=0`.

The sealed request includes both comparison tolerances. The chain validator recomputes q4-versus-independent absolute/relative differences and the pass/fail decision, rejecting forged envelope values or q4 totals. The q2 receipt identity is always taken from `q2_result.receipt`.

Integration audit (2026-09-12): these historical `total_force` values use a
one-field-period Cartesian vector with scalar NFP weights. For NFP > 1 they are
sector-replicated proxies, not full-torus Cartesian force integrals. The
candidate validation propagation stage preserves them under that explicit
label and independently reconstructs each period's vector using the sampled
laboratory angle. Passing the proxy comparison alone cannot establish force
balance or numerical convergence of the full residual. The example now shares
the actual upstream provider-owner module; the isolated module lacked the
candidate-specific DESC types and returned exit 1 before integration repair.
