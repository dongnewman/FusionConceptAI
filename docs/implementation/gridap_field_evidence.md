# Gridap B3 evidence binding

B3 is an additive binding layer over the sealed B1 compilation and solver. It
constructs an exact candidate/prefix/scenario/edge/grid/protocol/lock/source
domain, a non-wildcard `CapabilitySignatureV4`, and a `ProviderManifestV4`
for the pinned Gridap weak-form executor. A materialized
`ExecutablePhysicalSubjectV4` and `SolverInputV4` carry those hashes into
`execute_once!`, whose store is the canonical replay cache.

The public factory revalidates the actual candidate, compiled prefix, and
Genome registry; mission and bounds are derived from that context rather than
accepted as caller-written hashes. The provider code identity combines the
SHA-256 of this source file, the B1 adapter source hash, and the pinned Gridap
dependency-lock hash, and is checked again inside the executor. A stable
provider/executor is cached by deterministic manifest inputs so repeated
public execution cannot rebind one manifest hash to different closures. Cache
verification and fresh-store execution are separate APIs.

The executor calls only `run_gridap_field_residual`; it never calls the native
finite-difference assembler. Runtime exceptions become `unknown` with no
fabricated metrics or artifacts and carry a nonempty failure reason; a B1
numerical failure remains `numerical_fail`. The
report remains `manufactured_control`/`screen_only`, with zero credible
physical candidates and `p5_ready=false`. Legacy VVUQ material is test-only,
and B2 is not consumed, so this module cannot claim Batch B completion.
