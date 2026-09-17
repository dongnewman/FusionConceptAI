# UP2-01-G1-DIFFUSION-V1 independent static precheck R2

Verdict: `changes_requested`; `accepted=false`; runtime: `not_run`.

This read-only review covers the R2 repair at frozen HEAD
`4b69f55f7f80240147a65a22809dc1207824dde2`. R1's source-hash and K-expression
findings were read in full, together with `repair_r2/`, the current G1 source,
tests, fixture, static QA and the AD-28/G1 work-order boundary. The working
tree had 297 status rows and no matching Julia/DESC process at capture. Julia
and DESC were not run.

## R2 items verified statically

`G1DiffusionSourcePayloadV1` contains typed candidate-owned `u`, `K` and `f`
records plus `source_ref` and `source_version` (`DiffusionDeclarationV1.jl:341-362`).
`g1_diffusion_source_hash_v1` canonicalizes that payload. The declaration
constructor requires the payload, checks its ref/version and typed field hashes,
and compares the supplied `source_hash` to the recomputed payload hash
(`DiffusionDeclarationV1.jl:246-303`). The forged digest control is present in
the test (`diffusion_v1_contract_tests.jl:82-85`).

The new coefficient profile is the typed rational diagonal-affine expression
`K(x)=diag(b_i+s_i*x_i)` over a bounded non-degenerate 3-D box. It rejects a
constant expression and any non-positive diagonal lower enclosure, evaluates
only in-domain points, and returns exact diagonal lower/upper enclosures
(`DiffusionDeclarationV1.jl:78-118`). `G1DiffusionCoefficientFieldV1` requires
the exact enclosure as its stored bounds (`:135-165`). Tests cover a varying
profile, a midpoint evaluation, exact bounds, out-of-domain rejection,
constant rejection and negative-base rejection (`diffusion_v1_contract_tests.jl:45-58,71-75`).

The typed `residual_sign=-1`, GRAD/K_APPLY/DIV field chain and unit equations
remain present (`DiffusionDeclarationV1.jl:167-242,285-295,324-326`). Editing
`u`, `K` or `f` rebuilds the payload and changes both source and declaration
hashes; tests cover all three (`:93-108`). Missing external authority remains
`terminal_deferred`, the receipt is contract-only with no physical evidence,
and the fixture declares no current-A or provider result. Static QA executed
successfully with `julia_or_desc_executed=false`.

## Blocking findings

### 1. Forward type reference can prevent module loading

`G1DiffusionDeclarationV1` declares the field
`source_payload::G1DiffusionSourcePayloadV1` and uses that type in its
constructor at `DiffusionDeclarationV1.jl:246-303`, but
`G1DiffusionSourcePayloadV1` is defined only later at `:341-356`. Julia type
names in a struct field declaration must be defined when the struct is
evaluated. Without running Julia, this is a static load-order blocker: the
dedicated test includes the file at its line 5 and may fail before any testset
starts. Move the source-payload type and its semantic/hash methods before the
declaration, or otherwise remove the forward reference while preserving the
typed field contract.

### 2. Forged hash and K-domain contradictions are rejected by raw exceptions,
not a typed fail-closed outcome

The source-hash mismatch path throws `ArgumentError` at
`DiffusionDeclarationV1.jl:281-282`, and the test only asserts
`@test_throws ArgumentError` (`diffusion_v1_contract_tests.jl:82-85`). The
out-of-domain, constant and non-positive K controls similarly assert raw
constructor throws (`:58,74-75`). The R2 objective says forged hash must
`fail_closed`; the current public construction path has no typed status or
receipt for these contradictions. If the contract requires typed
classification, add an adapter/validation entry point that returns explicit
`fail_closed` with no declaration, and test that outcome separately from
unexpected program exceptions. Do not turn missing source authority into a
synthetic positive.

## Scope and credit boundary

The K expression is now an executable contract-level evaluator with a strict
conservative rational lower enclosure, but there is still no authoritative
external source, compiler, provider, mesh, solver, boundary execution or
physical result. The fixture is synthetic/schema-only. G2 remains responsible
for executable boundary/face ownership. No provider, mesh, engineering,
physical, B00, B04 or R01-R10 credit is granted.

Disposition: `changes_requested`; after the load-order and typed-classification
repairs, request a different-Luna static R3 review before any serial focused
runtime lane.

