# Regional MHD global conservation observation v4

Candidate-bound inputs are the real q=2 -> q=3 comparison, exact partition,
and static jump ledger. The accepted real-DESC chain reports a total-force
norm of `342182.59975165897 N` (component values are preserved in the runner
artifact). The regional sum is
independently recomputed; NFP is applied exactly once. Internal entries retain
finite-offset jump proxies in Pa with the declared minus-outward/plus-inward
sign convention, but they are not surface contributions and are not included
in the volume total.

Typed request/result/receipt hashes, candidate/context identity, interface
ordering, cardinality, and tamper rejection are enforced. External
boundary-limit traces, external flux, and global weak-form assembly remain
unavailable, so global residual and norm are `nothing`. Status is
`nonclosure_deferred`, `screen_only`, evidence credit `0`; no convergence,
closure, validation, solve, or device-authority claim is made.
