# M5-A auto-composition scope decision R1

## Scope decision

Sol/root records `authorized_not_started` for one isolated manufactured
auto-composition fixture. This is a scope contract only; it is not UP3-01,
does not alter `task_manifest.json` or the 39-node dependency graph, and
does not grant UP3 credit.

The future fixture may map the already accepted-limited M4 A–D controls into
the existing `src/IR/TypedAST.jl` and `src/IR/OperatorHypergraph.jl` canonical
program/graph representation. The mapping must preserve deterministic node
and edge order and labels, and must not silently normalize away contract
metadata. It must expose typed ports, units, conservation owner, interface
owner, and provenance for every mapped stage. The M4 source hashes frozen for
this decision are:

| stage | source SHA256 |
|---|---|
| A manufactured equation IR | `0b456dcc0df3bd13a1941aa502a9cc5347912b2fa86cda6c65900449299b8e57` |
| B manufactured residual lowering | `0445ec58f35ebbf5e34ae032611befab7050a0a65d2a376ccd37b71a0e9a936c` |
| C manufactured discrete control | `20804bafb5d42152d220a1d25897f6b460c7056b0c695dbaa5153c0d113710fa` |
| D manufactured coupled solve control | `ec7e82e282f1d1292ddd4b7902e4ced641d926af82119298267011d304a55785` |

The corresponding D test and oracle hashes retained as input evidence are
`1eb0e26e79b9899cc5a3cb2742545cbaa811fa6683fdcfa1ee4dd31dff081686` and
`9ca3c1c012690c7c06579d0ab5ffd274666e340c900c59e49f7a93408a0fcbe3`.
The source acceptance statuses are A, B, C, and D respectively
`accepted_limited` with ceilings `manufactured_control/screen_only`,
`manufactured_residual_lowering/screen_only`,
`manufactured_discrete_control/screen_only`, and
`manufactured_coupled_solve_control/screen_only`.

## Required contract and typed rejection

Composition must retain each stage's typed ports and explicit unit,
conservation-owner, interface-owner, source-owner, and provenance bindings.
Stable ordering/labels are an invariant. Invalid unit, invalid port, invalid
owner, provider dropout, foreign input, or identity/hash mismatch must be a
typed reject; no best-effort graph is publishable. The fixture consumes only
the frozen manufactured controls and may not infer provider or source
authority from them.

Suggested future implementation ownership is
`src/RuntimeV4/M4Isolated/ManufacturedAutoCompositionV1.jl`, with tests at
`test/RuntimeV4/M4Isolated/manufactured_auto_composition_v1_tests.jl`, an
independent oracle at
`test/RuntimeV4/M4Isolated/oracles/auto_composition_oracle_v1.py`, and
evidence under
`docs/implementation/UP3-EARLY-PREPARATION/M5-A-AUTOCOMPOSITION-R1/`.
Those files are not created by this scope record.

The fixture must not modify `default_operator_registry`, any shared entry,
`Project.toml`, `Manifest.toml`, task manifest, or existing core planning
files. It must not perform candidate generation, provider resolution, a
production solver, physical/engineering validation, or publish formal
evidence. The claim ceiling is
`manufactured_auto_composition/screen_only`.

## Execution and re-entry boundaries

Implementation, test/oracle, integration, documentation, and independent
review are five pairwise-distinct Luna roles. This recorder performs no code
execution (`runtime_execution=not_run`, `exit_code=not_applicable`). Any
future run must freeze inputs and file ownership, serialize recomputation, and
retain raw stdout/stderr, PID, UTC, exit, input/output/artifact hashes and
failures. Input unchanged means no repeated S3 or new AD.

Formal re-entry remains exactly:
`T0 → authority recheck → T1 → T2 → aggregate → UP2-00 → UP1-04B → UP1-04 → UP2-01`.
Fresh G1/G2/G3, candidate identity, receipts, and solver input hashes are
required before any return to the formal chain. A successful fixture would
still not close UP2, B00, B04, R01–R10, L4, or the parent goal.

Decision authority: `Sol/root`. Recorder: Luna `m4_scope_record`, model
`gpt-5.6-luna`, effort `high`. Existing UP3 early-preparation products and
all protected repository files remain unchanged.

