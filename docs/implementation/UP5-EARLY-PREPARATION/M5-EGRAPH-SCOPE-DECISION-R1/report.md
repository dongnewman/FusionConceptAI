# M5 ConditionalEGraph scope decision R1

## Decision

Sol/root records `authorized_not_started` for one isolated manufactured
ConditionalEGraph adapter. This is not UP5-01 and grants no UP5, search,
provider, solver, physical, engineering, semantic-edit, equivalence, or
R01–R10 credit.

The fixture may reuse the existing typed implementation references
`src/IR/ConditionalEGraphTypes.jl`,
`src/IR/ConditionalEGraphSaturation.jl`, and
`src/Canonical/ConditionalEGraphCanonical.jl`, together with the frozen M5-A
and M5-B manufactured outputs. It must not modify those existing e-graph
files, the shared entry, or the default registry.

## Allowed adapter contract

The adapter consumes a whole-program typed rewrite representation with
explicit conditions and deterministic replay/query. Conditions must cover
type, rank, domain, unit, port, owner, interface, and conservation. Under the
same configuration, canonicalization and saturation are deterministic and
the trace must replay 100%. A condition failure produces zero merge; a
bounded budget produces explicit `saturation_incomplete/terminal_deferred`;
contradictory conditions fail closed. Only synthetic e-graph equality and
screen-only behavior may be reported. This is not G1/G2/G3 semantic edit
proof, physical equivalence, provider evidence, or search proof.

The frozen manufactured inputs are M5-A source
`e6262a11ca47f527dfa67f08974febfd69a0334e1c64baeec7657249f0e1945a`,
composition hash
`722e59e841d6551fe9001e1279266e1aaf5a798ca0d16625d5a4fd81a59ab694`, and
M5-B source
`0445ec58f35ebbf5e34ae032611befab7050a0a65d2a376ccd37b71a0e9a936c`.
Changed inputs require a new freeze and independent review; unchanged inputs
must not trigger repeated S3 or a new AD.

Suggested future implementation is
`src/RuntimeV4/M4Isolated/ManufacturedConditionalEGraphV1.jl`, with test and
oracle paths under `test/RuntimeV4/M4Isolated/` and evidence under
`docs/implementation/UP5-EARLY-PREPARATION/M5-EGRAPH-R1/`. These files are not
created by this scope decision.

## Boundaries and roles

Do not alter task manifests, the 39-node graph, existing ConditionalEGraph
files, shared entry, registry, Project/Manifest, candidate/provider/solver
paths, physical/engineering evidence, or search state. Implementation,
test/oracle, integration, documentation, and independent review are five
pairwise-distinct Luna roles. Heavy replay is serial and must retain raw
stdout/stderr, PID, UTC, exit, input/output/artifact hashes and failures.

Decision authority is `Sol/root`; recorder is Luna `m4_scope_record`, model
`gpt-5.6-luna/high`. No code is run for this record. Formal re-entry remains
`T0 → authority recheck → T1 → T2 → aggregate → UP2-00 → UP1-04B → UP1-04 → UP2-01`.

