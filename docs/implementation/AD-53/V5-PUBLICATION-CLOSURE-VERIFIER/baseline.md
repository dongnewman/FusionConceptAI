# AD-53 V5 publication closure verifier baseline

Observed baseline: the working tree contains a dirty `src/FusionConceptAI.jl`
that includes `CandidateStatePackageV5.jl`, `GenomeV5Integration.jl`, and
`UP2ModuleEntryV1.jl`, while the GenomeV5 source tree and authority factories
are mostly untracked. A selective commit of only the entry point can therefore
leave a clean checkout unable to load the V5 seam.

The verifier owns an explicit, repository-relative closure. It records bytes,
SHA-256, tracking state, evidence status, and the reason each path is required.
It overlays only those paths into a temporary clone of the current HEAD,
commits there, and probes the package entry, loader, and manually included
G1/G2/G3 factories. Missing paths fail closed. G3SourceFeedbackLaw is listed
as an optional independent product and cannot satisfy the four-scope closure.

This baseline grants no source authority, physical/search/engineering credit,
or R01-R10 credit. The intended implementation state is
`completed_review_pending` with `accepted=false` and `L4=0`.
