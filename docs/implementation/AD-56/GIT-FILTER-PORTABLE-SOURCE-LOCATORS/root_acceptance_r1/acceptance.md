# AD-56 root acceptance R1

Decision: `accepted_limited`

Accepted scope: **git-filter-portable source locator software repair**.

The implementation record, `independent_review_r1`, and `correction_review_r1` were read. The bounded repair makes G1/G2/G3 source locators derive canonical source evidence from `HEAD:path` blob bytes and compare a real working file through Git's filtered `hash-object --path` OID. Raw working bytes remain an existence/readability check; root, HEAD/tree, stage-zero tracking, index flags, porcelain cleanliness, canonical length/hash, filtered OID, path labels, and relabel controls remain fail closed.

The three serial focused test receipts are all passing: G1 `35/35`, G2 `35/35`, and G3 `356/356`, each exit `0`. Each layer includes the core.autocrlf=true portability fixture with LF canonical HEAD content and a platform checkout, plus mutation and negative controls. The independent adversarial probe passed `20/20`, exit `0`, covering valid present locators and source-length, source-hash, HEAD-blob, and HEAD relabel failures for realization, control, binding, and bundle.

The current checkout recheck finds all four G3 scopes present and clean: realization `src/GenomeV5/G3/RealizationGenomeV5.jl` (raw 33,751 bytes, canonical HEAD blob 33,750), control `ControlGenomeV5.jl` (raw 10,297, canonical 10,287), binding `CoupledRealizationControlBindingV2.jl` (10,904), and bundle `RealizationControlGenomeV5.jl` (6,704). For all four, the filtered working OID equals the corresponding `HEAD:path` blob OID. The raw byte differences in realization/control are the recorded Windows checkout condition and are handled by the repair.

The metadata correction is accepted as evidence maintenance only. The current raw task-manifest SHA-256 is `7d1700038f78dd1ea872cbc3fd6da29c5071596dae40d0c43b598b501195bae8`; the separate Git blob OID is `f514c155e2004378a61ee3efc4d0be9085eeb017`. Planning validation is `31` markdown files, `534` relative links, `39` tasks, and an acyclic DAG. The correction review records matching after-hashes, no source/test/18_sources changes, and no runtime tests during the correction.

The independent review's current S2 probe is retained as review evidence only. It does not substitute for the formal AD-55 fresh F0/S2 run. AD-55 fresh F0 and S2 remain required and must be rerun from fresh evidence after this portability repair; prior AD-55 failure history remains preserved.

The following remain false: source authority, trusted source identity, candidate identity, final identity, provider, mesh, solver, engineering readiness, physics, search, and `R01`–`R10`. `L4=0`. No source authority, trusted attestation, candidate/final identity, provider, mesh, solver, physics, engineering-readiness, search, or scientific/final acceptance is granted.

Cleanup and dirty protection passed. Review-owned temporary fixtures and probe/builder scripts were removed; no temporary directory, Python cache, or task-owned temporary artifact remains, while receipts, logs, failure history, and ambiguous pre-existing paths were retained. No Julia or DESC process was run by this root acceptance, and no source, test, registry, run, task manifest, old evidence, index, or commit was modified.
