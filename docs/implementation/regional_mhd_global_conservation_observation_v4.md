# Regional MHD global conservation observation v4

This production slice is candidate-bound to the complete q=2 -> q=3 chain,
the exact partition, and the static MHD interface jump ledger. It records real
volume accounting in N (`F_xyz * sqrt(g)` with NFP applied once) and an
explicitly oriented internal-interface ledger in Pa. Interface jump proxies
are finite-offset diagnostics only: they are not surface integrals and are
never added to the volume total, avoiding algebraic double counting.

Typed request/result/receipt envelopes bind candidate, context, q=3,
partition, and ledger hashes. Execution rechecks cardinality, ordering,
request/result identity, finite values, and independently recomputes the
regional sum. Tampering or foreign identities fail closed. A typed helper
`execute_regional_mhd_global_conservation_observation_typed` exposes the
envelopes and replay hash.

External boundary-limit traces, external flux, and a global weak form remain
missing; global residual and norm are therefore `nothing`/unassessed. Status
is `nonclosure_deferred`, `screen_only`, with zero evidence credit: this slice
does not claim convergence, closure, validation, solve completion, or device
authority.

The older `RegionalMHDWeakResidualV4` implementation was audited as
extract/wrap/test-only: it is not used as a provider or as a substitute for
the q=3 or static-ledger identities.
