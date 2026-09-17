# AD-28 acceptance — limited architecture boundary

Status: `accepted_limited`  
Scope: architecture, acyclic scheduling and evidence boundary only  
Runtime: not run  
Accepted: `true` for the limited scope above

Different Luna R2 review is `pass_limited`. Sol accepts AD-28 only as the
architecture and no-cycle schedule for UP2-01 preparation, together with its
evidence boundaries.

The accepted DAG is:

`UP1-01/02/03 → {UP2-01-G1-DIFFUSION-V1, UP2-01-G2-METRIC-BOUNDARY-V1, UP2-01-G3-SOURCE-FEEDBACK-V1} → UP1-04A-VNEXT → UP2-00 → UP1-04B → UP1-04 → UP2-01`。

The three upstream work orders remain preparation declarations, and
`UP1-04A-VNEXT` remains a planned new-candidate rebinding gate. All four task
nodes remain `planned`/`proposal` with `accepted=false`. UP2-00 total, formal
B00/B04, complete UP1-04, UP2-01 compiler, mesh, provider, physical and
R01–R10 remain unaccepted and uncredited.

Actual A still lacks candidate-owned G1 `u/K(x)/f`, executable G2
metric/mesh/face ownership and G3 feedback authority. Missing authority stays
typed `terminal_deferred`; contradictions remain `fail_closed`. The current
N06 authority-gap fixture is 1451 bytes with SHA256
`779e29bac0a71c5072896301e24e74c9686c293609b89e250d0b0aff5bf0cc99`.

Old UP1-04A, G-I1A, N05, N06 and UP2 local `accepted_limited` receipts remain
historical for their original candidate and cannot be reused for the new
candidate's formal B00/B04. Any upstream Genome change requires fresh
candidate identity/receipt/hash reconstruction and a new formal B00/B04
freeze. This acceptance does not change source, compiler, provider, mesh,
solver, physical evidence, the parent R01–R10 goal or old archives.
