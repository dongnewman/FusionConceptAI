# AD-53 V5 publication closure verifier: root acceptance r1

Root architectural decision: **accepted_limited** with `accepted=true` only for
`publication_closure_verifier_engineering_only`.

The frozen implementation evidence establishes an exact 21-path V5 overlay on
top of 44 tracked base dependencies. In a temporary clean clone the overlay
was loadable, and the serial core probe loaded the G1, G2, and G3 factories and
returned `V5_CLOSURE_PROBE=pass` with typed-absent results. That evidence is
accepted as commit-set engineering closure. The G3 feedback and G3 editability
groups are optional and are excluded from the core closure claim.

The frozen inputs are script
`scripts/verify_v5_publication_closure.py` (SHA-256
`f3193c843417cdb6cff60b0e658586a693bff8611390117c762bb070cb962475`), test
`test/GenomeV5/Integration/verify_v5_publication_closure_tests.py` (SHA-256
`0e0133c58c1ea56e974803d50cccccf404b7ff40ba9528ce55014df7e5a8733d`), and
repository HEAD `4b69f55f7f80240147a65a22809dc1207824dde2`.

This acceptance does not establish actual source publication, source
authority, trusted source identity, candidate identity, final identity,
physics, search, or R01-R10. The credible L4 count remains 0. Actual
selective commit and fresh S2/S3 remain pending. The implementation and
independent review are therefore retained as limited engineering evidence,
not as publication or scientific acceptance.

Attempt 1 PID 96060 and the early Python failure boundary remain preserved in
the implementation evidence and are not counted as successful validation.
The independent review remains `pass_limited` with `accepted=false`; this root
decision narrows and records the authorized limited scope without changing
those historical boundaries.

This root acceptance writes only this directory. No frozen source, core
documentation, task manifest, prior evidence, runs, index, or HEAD was
modified, and no Julia or DESC process was run for this acceptance.
