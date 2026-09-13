# RuntimeV4 bounded algebraic generation slice (W23)

This is the first executable search-mechanics loop, not a fusion-device search
result. It uses the existing dimensionless 0D algebraic constraint fixture and
the production scoped algebraic evaluator. The seed is screened, then two
children are materialized by changing a reachable integer constant in a typed
G1 AST. Each child is compiled and screened under the same declared scenario,
and the next deterministic novelty/coverage edit is permitted only after an
exact, converged, screen-only feedback resolution. No G2/G3 or physical-model
change is claimed.

The proposal carries the exact parent prefix, child prefix, old/new program
hashes, typed edit trace, and feedback resolution hash. Its outcome prediction
is `unknown` and remains outside evidence. The generator rejects a wrong
parent, registry, scenario hash, no-op or out-of-range constant. The typed AST
constructor rejects unreachable/dead nodes before a child can be compiled.
All unexecuted capability obligations remain in the exact-signature deferred
archive; resolving the 0D screen never revives the whole candidate.

Run in a fresh directory:

```powershell
julia --startup-file=no --project=. scripts/run_v4_algebraic_generation_slice.jl runs/goal_recovery_20260913_012528_cst/w23_algebraic_generation_r4
julia --startup-file=no --project=. test/runtime_v4_algebraic_generation_tests.jl
```

The runner refuses a nonempty directory. `result.json` records source and
environment hashes, generation/prefix/solver/evidence identities, residual
screen status, gap counts, authority, and the resumed state hash. The local
`queue_archive.checkpoint.jls` has an internal checksum, campaign/provider
registry guards, and exact semantic state comparison on reimport. Each typed
feedback resolution is separately serialized, SHA-256 listed, and reimported
with candidate/result/evidence identities checked. These Julia serialization
files are trusted local recovery artifacts, not a public interchange format;
feedback files are not part of the queue checkpoint. Keep their file hashes
with the JSON receipt when moving artifacts.
The source SHA-256 values are raw working-tree bytes from this Windows run;
Git `core.autocrlf` can change LF/CRLF on another checkout, so a fresh clone
must verify its actual source bytes and rerun rather than treating the old
receipt as a portable proof of identical execution.

The three 0D solves demonstrate a genuine generate → solver → archive → next
generation control path. This does not implement open multimechanism/geometry/
realization generation, spatial equilibrium feedback, calibrated objectives,
net electricity, originality, held-out validation, or credible-device
promotion. R08 remains unaccepted; R01–R10 remain unaccepted and the credible
candidate count remains zero. Future search must use candidate-owned physical
and engineering operators plus the same evidence obligations; adding more 0D
constant variants is not scientific progress toward that acceptance.
