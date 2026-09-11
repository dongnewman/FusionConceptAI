# Regional force numerical V&V assessment

This wrapper consumes the committed q2/q3 comparison together with the complete
upstream and q3 execution chain, calling q3 validation without replay and
storing q3 request/result/receipt identities. Declared relative/absolute tolerances are
`1e-3` and `1e-6 N`; the measured relative difference is `1.4432683785832432`
and absolute difference is `493861.3259229757 N`, so status is explicitly
`:fail`. The next layer is `:q4_required`, with a recoverable
`:independent_code_validation_required` gap. This is numerical screen evidence
only, not independent code verification, physical validation, UQ, or promotion
evidence. The canonical validator independently recomputes the norm differences
and status: pass means the absolute difference is within tolerance OR the
relative difference is within tolerance; fail means both exceed. The measured
default-tolerance result is fail.
