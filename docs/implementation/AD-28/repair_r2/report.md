# AD-28 core synchronization repair R2

Verdict: `ready_for_independent_review_r2_no_execution`.

This narrow repair addresses exactly the two `independent_review_r1`
`changes_requested` findings. The README now marks its earlier
`UP1-01/02/03 → UP1-04A → UP2-00 → UP1-04B → UP1-04 → UP2-01` chain as the
historical chain for the old candidate and states the AD-28 new-candidate
machine route with the three parallel upstream declarations and
`UP1-04A-VNEXT`. Core16 now describes UP2-00 as a `planned` machine node with a
`review_pending` total gate, `accepted=false`, scoped `accepted_limited` local
slices, and a dependency on VNEXT/new-candidate rebinding.

The R1 repair did not touch `18_sources_and_architecture_decisions.md` or
`task_manifest.json`; their before and after bytes and SHA256 are identical.
No source, old evidence, prior review, AD28 original proposal/manifest/QA, or
protected dirty file was modified. Only this `repair_r2/` directory is newly
written. Julia and DESC were not run.

AD-28 remains `proposal` / `review_pending` with `accepted=false`. The R4
N06/H0 fixture drift remains recorded: current N06 is 1451 bytes with SHA256
`779e29bac0a71c5072896301e24e74c9686c293609b89e250d0b0aff5bf0cc99`; this
repair does not promote the actual-A gap or the R4 audit manifest.

Static validation covers JSON parsing, the machine DAG, `validate_plan.py`,
`git diff --check`, exact before/after hashes, protected hashes and final
Julia/DESC process absence. The repair is ready for a different Luna R2 review
and subsequent Sol decision.
