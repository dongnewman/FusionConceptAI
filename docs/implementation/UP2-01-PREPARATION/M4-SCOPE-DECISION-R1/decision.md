# M4 isolated manufactured/analytic development scope decision R1

Decision origin: current Sol architecture adjudication (gpt-5.6-sol, high). This is a bounded preparation decision, not a new AD, task, node, edge, acceptance record, or UP2 execution result. It is recorded under the existing `UP2-01-PREPARATION` implementation archive.

## Decision

When the external trust root is unavailable, an isolated manufactured/analytic development lane is authorized. The lane is deliberately detached from real candidates, source authority, provider manifests, and formal evidence. It may prepare and validate only slice A, **declaration → equation/residual IR**, using explicit manufactured or analytic input. Slice A must receive an independent review by a different Luna (high), followed by Sol acceptance, before any slice B work may be dispatched.

Slice B (real discrete matrix/vector) is contingent future scope only. Slices C (topology transfer) and D (coupled solve) are not dispatched by this decision. The sequence remains `A review → Sol acceptance → B protocol/dispatch decision`; C and D remain deferred. No local pass closes a parent task or stage.

## Frozen boundary and inputs

The only permitted M4 lane inputs are explicit, immutable manufactured/analytic declarations and the frozen equation below. They are development controls, not actual candidates, experimental sources, trusted source authority, or authority-bearing provenance.

Frozen HEAD/source context:

- checkout HEAD: `b2c04d8339774635aaecd73651efcdb101e01b5d`;
- task manifest raw-file SHA256: `7d1700038f78dd1ea872cbc3fd6da29c5071596dae40d0c43b598b501195bae8`;
- AD55 R2 source-stage archive: `docs/implementation/AD-55/CURRENT-HEAD-F0-S2-SOURCE-FACTORY/f0_s2_execution_r2/`;
- AD56 archive: `docs/implementation/AD-56/GIT-FILTER-PORTABLE-SOURCE-LOCATORS/`;
- AD56 dirty execution closure: `src/GenomeV5/G1/G1SourceAuthorityFactoryV1.jl`, `src/GenomeV5/G2/G2SourceAuthorityFactoryV1.jl`, and `src/GenomeV5/G3/G3SourceAuthorityFactoryV1.jl`, together with their import closure, direct tests/probes, and environment identity. The three files are working-tree executors, not silently attributed to HEAD.

M4 A exact future ownership is frozen to these paths:

- `src/RuntimeV4/M4Isolated/ManufacturedEquationIRV1.jl` (A implementer Luna);
- `test/RuntimeV4/M4Isolated/manufactured_equation_ir_v1_tests.jl` (different test/review Luna);
- `test/RuntimeV4/M4Isolated/oracles/equation_ir_oracle_v1.py` (independent oracle owner);
- `docs/implementation/UP2-01-PREPARATION/M4-A-EQUATION-IR/**` (integration/documentation owner).

Those files are future A ownership only; this R1 decision creates none of them. The current task writes only the three R1 products and evidence sidecars in this task directory.

The lane must not create `CandidateStatePackageV5`, `ForwardChainContextV4`, or `RuntimeEvidenceV4`, nor a formal provider manifest or candidate identity. These names are explicitly prohibited here even as manufactured aliases; no same-shape package may be used to smuggle formal authority into the isolated lane.

### M1 dependency boundary

This decision depends on the current M1 execution-closure record at `docs/implementation/UP0-01/m1_execution_closure_r1/`, specifically `report.md`, `execution_input_manifest.json`, `environment_manifest.json`, and `validation_receipt.json`. The four files currently state `status=review_pending`; their claim ceiling is `execution_input_reproducibility_preparation` only. M1 is not accepted by this R1 decision. It can become an accepted input only after a different Luna independently recomputes/reviews it and Sol issues a separate acceptance decision.

The M1 record freezes HEAD `b2c04d8339774635aaecd73651efcdb101e01b5d` and the following current dirty AD56 factory working-tree SHA-256 values: G1 `de5a0d14d71c02244df6344c1a339a56d3dc051f115d975a4072a260d0204bf2`, G2 `2e15b97676e8cef51af62c47f83f0bce061e98366e42d3d68bb2a120876436fc`, and G3 `d07805ce5b708be33232fccd25fd491ef4bd8a05c6320ccef4b274ef4644b05e`. Its recorded environment identities are PowerShell 7.5.5 (`C:\Program Files\PowerShell\7\pwsh.exe`), Python 3.13.5 (`D:\Users\Newman\anaconda3\python.exe`, SHA-256 `388fe2cffda8a134e7d7dc4e978f7c478857ece6b69694daecbed25e51ec633a`), and Julia 1.10.5 (`C:\Users\Newman\AppData\Local\Programs\Julia-1.10.5\bin\julia.exe`, SHA-256 `8e86e2d48c574393c37bbfb6e922ea4176ba8e1a83f956826f3da24948e389ad`), with Julia not executed in that freeze.

The static import closure recorded by M1 is probe imports `SHA`, `JSON3`, `Dates`, and `FusionConceptAI`; `src/GenomeV5/Integration/GenomeV5Integration.jl` loads 12 G1/G2/G3 component files in dependency order and the probe explicitly includes the two V1 declarations plus three dirty factories. Factory include directives are zero. Julia package resolution/runtime method dispatch and external module binary/dependency provenance remain unknown/deferred. This is a dependency description, not an authority or acceptance upgrade.

### External trust blockers (typed absence)

The following required external inputs are currently unknown or missing; absence is typed and cannot be promoted to `present` by local hashes, tests, or review:

| Required input | Current state | Responsible party / recovery condition |
|---|---|---|
| provider and source owner designation | unknown / unspecified | external source/provider owner; provide authoritative named owner and scope, then fresh freeze and independent verification |
| independent attestor basis | unknown | external independent attestor; provide attestation basis and independence statement, then verify |
| trust root, public-key fingerprint, and authentication chain | missing | external trust authority; provide root/fingerprint/chain and validate against a pinned verifier |
| certificate, signature, and algorithm | missing | signing authority; provide unexpired certificate/signature and algorithm metadata |
| verifier identity/version | unknown | verification owner; provide exact verifier version and reproducible invocation |
| validity, revocation, trusted time, freshness, nonce/anti-replay | unknown / missing | trust authority and verifier operator; provide time/revocation/freshness/anti-replay evidence |
| source/version binding | unknown | source owner; provide immutable source/version binding to the declared object |
| G2 mapping and four axes | unknown / missing | G2 owner; provide candidate-bound mapping and all four axes |
| acceptance command and contact channel | unknown / missing | Sol/project owner plus external provider; provide exact command, contact, and response/receipt channel |

Recovery requires real external material to change, followed by a new freeze and independent verification. If inputs do not change, do not repeat S3 and do not create a new AD. Until recovered, the external trust result remains typed absence/`terminal_deferred`; no source authority or candidate claim is allowed.

## Mathematical and semantic freeze for A

Use steady scalar diffusion only:

```text
domain: [0,1 m]^3
L = 1 m
u(x,y,z) = x/L + y/L + z/L
K(x,y,z) = diag(2 + 0.1 x/L,
                 3 + 0.05 y/L,
                 4 + z/(30 L)) m^2
R(u) = -div(K grad u) - f = 0
f = -11/60 dimensionless, with L=1 m
```

The implementation must preserve explicit units, coordinate/domain scope, source ownership, operator names, and residual sign. The oracle must independently use Python `fractions` and independent structural traversal; it must not call production lowering. Recommended exact-term error is `<= 1e-12`; canonical output and hashes must be deterministic.

Required positive/negative controls include missing operator, wrong units, non-positive or non-SPD `K`, duplicate conservation owner, missing boundary/closure, and foreign source reference. A failure is `unknown_operator`, `unit_closure_failure`, `non_unique_source_owner`, `input_hash_changed`, or `program_exception` as applicable and is not converted to a numerical/physical pass.

Time-dependent and multifield cases are `terminal_deferred` for this scope. No actual-candidate, source-authority, provider, mesh, solver, engineering, physical, search, B00, B04, or R01–R10 claim may be emitted. The highest possible result is `manufactured_control` / `screen_only`.

## Formal-chain preservation

The original 39-node dependency DAG and all R01–R10 and acceptance gates remain frozen. This decision does not modify `task_manifest.json`, 16, 20, 21, shared entry points, registries, old V4/evidence/runs, or any parent status. It does not close `UP2-01`, `UP2`, `B00`, `B04`, any provider/mesh/engineering/physical gate, or any R01–R10 item. A manufactured control is not candidate-bound evidence and cannot unlock the formal chain.

If external trust conditions later become valid, the formal re-entry sequence is exactly `T0 → authority recheck → T1 → T2 → aggregate → UP2-00 → UP1-04B → UP1-04 → UP2-01`; UP1-04B still requires 50 fresh receipts, an independent checker, and two-process replay. Fresh G1/G2/G3, candidate identity, B00/B04, and solver-input hashes must be re-verified at their owning gates. No R1 artifact is a substitute for those inputs.

## Execution and stop rules

Every execution attempt is serial and must retain raw stdout/stderr, PID (or explicit in-process marker), UTC start/end, exit code, input/output/artifact SHA256, and deterministic output hashes. The same unchanged input hash must not create another AD or repeat a run. A changed input or environment creates a new explicitly named execution attempt after a fresh freeze. Heavy Julia/DESC/mesh/solver work remains on the single serialized lane.

A stops before B on unknown operator or failed unit closure, non-unique source owner, input-hash change, or program exception. Missing trust root is a typed absence, not a present/failed source result. B may be considered only after A's independent Luna review and Sol acceptance; C and D remain unassigned until a new scope decision and all formal prerequisites are satisfied.

## Separation of duties and handoff

The A source implementer, A test/oracle owner, A independent reviewer, and A integration/documentation owner must be four pairwise-distinct Luna agents. The reviewer cannot review their own change or the same change performed by any of the other three roles. Sol is the only acceptance adjudicator. Each handoff records actual model and reasoning effort, exact frozen inputs, file ownership, claims, unmet gates, raw receipts, cleanup inventory, and remaining wake-up conditions. The M4 decision itself is documentation-only; `code_tests=not_applicable`.

Cleanup is limited to this task's own exact temporary paths. No ambiguous path is deleted; it is recorded as `cleanup_deferred_ambiguous`. Existing dirty files, AD55/AD56 archives, R01–R10 raw receipts, historical runs, shared entries, registries, source, tests, and formal manifests are protected.
