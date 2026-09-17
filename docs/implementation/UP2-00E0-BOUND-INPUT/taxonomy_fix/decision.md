# E0 taxonomy correction

This append-only correction separates known, source-derived candidate identity contradictions from unexpected internal/source exceptions. A foreign or stale candidate reference, package hash, component reference/hash, or version axis remains `fail_closed`. An internal exception from the source inspection path is reported as `program_exception` and is not relabeled as a structural contradiction. The factory propagates that distinction.

This correction does not alter the old E0 r1–r7 evidence. It adds one typed exception-classification negative control and retains the existing contradiction controls. Scope remains contract-only with `review_pending`, `accepted=false`, and no B00/B04/provider/mesh/engineering/physical/R credit.
