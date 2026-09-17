# UP2-01-G1-DIFFUSION-V1 independent static precheck R1

Verdict: `changes_requested`; `accepted=false`; runtime: `not_run`.

This is a read-only static review at HEAD
`4b69f55f7f80240147a65a22809dc1207824dde2`. The review read AD-28, the v4
README/00/14/16 contracts, the G1 implementation README and evidence manifest,
the new source, test, fixture and static QA. Julia and DESC were not run. The
working tree had 297 status rows; no matching Julia/DESC process was present at
the capture.

## Verified contract surface

The source stores the PDE sign as typed `residual_sign::Int8`, accepts only the
integer value `-1` in `G1DiffusionOperatorChainV1`, includes the operator chain
in the declaration semantic body, and checks the sign again in
`g1_diffusion_validate` (`DiffusionDeclarationV1.jl:175-188,256-265,320-333`).
The positive residual-sign constructor control is present in the test
(`diffusion_v1_contract_tests.jl:65-66`). This is a real typed field included
in the declaration hash, not an equation-label-only assertion.

The constructors require 3-D scalar `u` and `f`, and a rank-2 3-D symmetric,
spatially dependent `K` with declared positive definiteness and finite ordered
positive bounds (`DiffusionDeclarationV1.jl:72-110`). GRAD, K_APPLY and DIV
bind their field IDs and close units through the length unit and coefficient
unit (`:113-171,219-229`). The test checks the positive declaration, dimensions,
spatial dependency, positive-definite declaration, bounds, bindings and
`residual_sign=-1` (`diffusion_v1_contract_tests.jl:37-54`). Boundary/face
ownership is correctly outside this G1 slice and belongs to the separate G2
work order; no G1 boundary or physical result is inferred.

Source refs are required to be `QualifiedRefV1` and all three fields must match
the declaration source ref. Source edits rebuild the declaration and change its
canonical declaration hash; the edited-K behavior test is present
(`DiffusionDeclarationV1.jl:213-236,273-281,336-353`; tests `:75-81`). The
receipt remains proposal-only, `accepted=false`, `terminal_deferred`,
`contract_only`, with zero compiler/provider/mesh/solver calls and no physical
evidence. The fixture and README preserve that ceiling. Static QA ran and
reported `static_qa=pass`; it did not invoke Julia or DESC.

## Blocking finding: source hash is not source-derived or verified

`G1DiffusionDeclarationV1` only checks that `source_hash` is already a
`Digest256` (`DiffusionDeclarationV1.jl:59-61,213-216`). It stores that supplied
digest and places it into the declaration body (`:259-265`), after which the
declaration hash seals the supplied value (`:273-281`). There is no source
payload, source canonicalization function, or equality check that recomputes
the digest from the declared source identity and source content.

The test supplies `_SOURCE_HASH = digest256_text("candidate-source-v1|u_candidate|K_candidate_x|f_candidate")`
(`diffusion_v1_contract_tests.jl:18-26`) but has no wrong-source-hash or
source-payload mutation control. Thus a self-consistent forged `Digest256`
would be accepted as the source hash and then included in a valid-looking
declaration hash. Declaration rehashing detects edits to the declaration; it
does not establish that `source_hash` is the real hash of an authoritative
source. This must be repaired before a pass: add a source-derived payload or
authority adapter with deterministic recomputation, reject a mismatched hash,
and add a behavioral negative control. Missing external authority must remain
`terminal_deferred`, and no synthetic source may be promoted.

## Scope and credit boundary

The K positive-definite/spatial claims are typed declaration constraints only;
no numeric K field, boundary data, provider, mesh, solver or physical execution
was supplied. The current fixture is synthetic and schema-only. AD-28 and the
G1 archive correctly keep actual-A authority absent and resolution
`terminal_deferred`, with contradictions `fail_closed`. No provider, mesh,
engineering, physical, B00, B04 or R01-R10 credit is granted.

Disposition: `changes_requested`; wait for an author repair and a different-Luna
static recheck before any serial focused runtime lane.

