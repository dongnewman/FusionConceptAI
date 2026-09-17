# M4-C discrete control root acceptance R1

Decision authority: `Sol/root`  
Recorder: documentation Luna `m4_scope_record` (`gpt-5.6-luna`, high)  
Review basis: `independent_review_r1/pass_limited`  
Frozen HEAD: `b2c04d8339774635aaecd73651efcdb101e01b5d`

## Limited acceptance

Sol/root accepts the isolated M4-C manufactured discrete-control slice as
`accepted_limited`, with ceiling `manufactured_discrete_control` /
`screen_only`. The independent review checked both required grids cell by
cell using Fraction arithmetic: `2x2x2` (8 cells, 48 faces) and `3x4x5` (60
cells, 360 faces). Every cell has directional terms `1/10`, `1/20`, `1/30`,
divergence `11/60`, source `-11/60`, and exact residual `0`. The isolated Julia
test result is `537/537`.

The accepted evidence also includes the final integration/test receipts and
two replay families, while preserving the non-counted metadata-capture and
static-audit failure histories. Julia stdout hashes may differ only because of
human-readable duration lines; semantic `537/537` remains equal.

## Exclusions and ownership

This acceptance is only a manufactured six-face discrete assembly control. It
does not accept or credit solver, coupling, candidate, provider, physics,
engineering, `UP2`, `B00`, `B04`, `R01-R10`, or `L4`. It does not authorize D;
D requires its own scope contract. The 39-node DAG and all parent gates stay
open.

Source implementation, test/oracle, integration, documentation, and
independent review are five pairwise-distinct Luna roles. The reviewer cannot
review their own change or another role's same change. No shared RuntimeV4
entrypoint, registry, Project, Manifest, A/B source, candidate or provider
file was changed by this acceptance. Existing dirty work and all raw/failure
history remain protected.

## Frozen evidence and formal route

The reviewed A/B/C hashes, exact Fraction results, independent review raw,
test execution raw, integration raw, PIDs, UTC intervals, exits, and artifact
hashes remain at `../independent_review_r1/`, `../test_execution_r1/`, and
`../integration_r1/`. The independent review's fresh Python PID was `7200`
and Julia PID `72084`, both exit `0`; its Julia result was `537/537`.

Formal re-entry remains exactly
`T0 → authority recheck → T1 → T2 → aggregate → UP2-00 → UP1-04B → UP1-04 → UP2-01`.
No local C artifact substitutes for fresh authority/trust, candidate,
provider, B00/B04, solver, engineering, physical, or R01-R10 evidence.

No Julia, Python, solver, mesh, coupling, or physical run was made for this
root acceptance record; upstream evidence was read-only.

