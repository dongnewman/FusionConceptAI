# M4-B residual lowering root acceptance R1

Decision authority: `Sol/root`  
Recorder: documentation Luna `m4_scope_record` (`gpt-5.6-luna`, high)  
Review basis: `independent_review_r1/pass_limited`  
Frozen HEAD: `b2c04d8339774635aaecd73651efcdb101e01b5d`

## Limited acceptance

Sol/root accepts the isolated M4-B manufactured residual-lowering slice as
`accepted_limited`, with claim ceiling
`manufactured_residual_lowering` / `screen_only`. The evidence chain is
preserved: initial Julia `51 pass / 2 error`, one causal typed-vector source
repair, final Python exact residual `0`, final Julia `53/53`, and the
independent review's `pass_limited` verdict. Integration then replayed Python
twice and Julia twice in strict serial order with zero exits.

The initial failure was a real implementation failure, not a test relaxation:
an empty `result.failures` collection became `Vector{Union{}}` before an
owner-binding push. The single source repair materialized a typed
`ManufacturedResidualLoweringFailureV1` vector. All initial failure receipts,
raw streams, repair receipts, and the integration preflight-capture collision
are retained by the delivery and review records.

## Ceiling and exclusions

This acceptance covers only analytic manufactured residual lowering. It does
not accept or credit mesh, discretization, matrix/vector assembly, topology
transfer, coupled solve, candidate identity, provider, physics, engineering,
`UP2-01`, `UP2`, `B00`, `B04`, `R01-R10`, or `L4`. It does not authorize C or
D; C requires its own scope decision and D remains unauthorized.

The frozen arithmetic is `1/10 + 1/20 + 1/30 = 11/60`, source `-11/60`, and
`R=-div-f=0`. Units, equation identity, source identity, conservation owner,
provenance, and explicit source-owner binding remain required. The distinction
between `source.owner` and `conservation_owner` is preserved; foreign or
mismatched owner/input references must remain typed failures.

## Ownership and shared-tree boundary

Source implementer, test/oracle owner, integration owner, documentation owner,
and independent reviewer are pairwise-distinct Luna roles. The reviewer cannot
review their own change or another role's same change. No shared RuntimeV4
entrypoint, registry, Project, Manifest, candidate/provider file, or A source
was modified by this acceptance. Existing dirty work and all prior raw and
failure histories remain protected.

## Formal gates

Formal re-entry remains exactly
`T0 → authority recheck → T1 → T2 → aggregate → UP2-00 → UP1-04B → UP1-04 → UP2-01`.
The 39-node dependency and every `R01-R10` gate remain open. Fresh authority,
trust, candidate, provider, B00/B04, solver, engineering and physical
evidence remain required at their owning gates. This local B acceptance is not
a downstream formal acceptance.

No Julia, Python, solver, mesh, or physical execution was performed for this
root acceptance record; upstream execution evidence is read-only and retained.

