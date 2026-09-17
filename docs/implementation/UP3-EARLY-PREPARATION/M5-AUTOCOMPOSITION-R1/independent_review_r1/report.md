# M5-A auto-composition R1 — independent review

## Decision

`pass_limited`. The isolated manufactured fixture is internally consistent at
the declared boundary `manufactured_auto_composition/screen_only`. The ceiling
is `screen_only`; it is not UP3-01 and receives no formal credit. No product
source, test, oracle, registry, shared entry, candidate, provider, solver, or
formal evidence was changed or created by this review.

## Independent execution

The authoritative replay was one fresh strict serial lane from
`D:\\006-Programing\\LMC\\FusionConceptAI`, Python first and Julia second. The
launcher and exact raw streams are in `run_independent_r1.ps1` and `raw/`.
Earlier launcher probes that did not produce a complete pair are not used as
evidence.

| command | PID | UTC start → end | exit | raw bytes / SHA-256 |
|---|---:|---|---:|---|
| `python test\\RuntimeV4\\M4Isolated\\oracles\\auto_composition_oracle_v1.py` | 113620 | 2026-09-16T11:17:01.7645655Z → 2026-09-16T11:17:02.4939076Z | 0 | stdout 1598 / `bd23dd1e0b5ec3254cee7cfc6e15efebde553c85f3a01876205b3175a32e4ae7` |
| `julia --startup-file=no --history-file=no test\\RuntimeV4\\M4Isolated\\manufactured_auto_composition_v1_tests.jl` | 87320 | 2026-09-16T11:17:02.5949449Z → 2026-09-16T11:17:34.3997060Z | 0 | stdout 176 / `066e87c910960d5b6c5498ed2b828cc33f0876d565ff6b02416497aa01f3a66c` |

Both stderr streams are zero bytes with SHA-256
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`; combined
streams are stdout followed by stderr and have the stdout hash. Julia raw output
is `110 passed / 110 total` and
`M5-A-TESTS PASS manufactured_auto_composition/screen_only`.

## Recomputed maps and code review

- The independent standard-library oracle rebuilt the canonical manifest and
  obtained canonical hash
  `a0823a76ddac17bd193a03c8ed86945d06c4637649611f248a53383dd0d6f6fe`; the
  independently permuted stage/port/join input produced exactly the same hash.
- The AST map is `TypedASTProgramV1`: 8 nodes, roots `(5,6,7,8)`, input ports
  `(1,2,3)`. The graph map is `TypedOperatorHypergraphV1`: 7 nodes and 4
  edges, in `M5-A, M5-B, M5-C, M5-D` order. The frozen port sequence is
  `A.u, A.K, A.f, A.residual, B.residual, C.control, D.solution`; there are 4
  stages and 3 owner/interface joins.
- Source identities were recomputed as `sha256("M5A|stage|source_sha256")`:
  A=`3618508c98d614667c7f7412cf48a34497887b4ba5c9aee77e57c2d0776ee725`,
  B=`c45c26af8f0bc60fda844d390567d43e18a0853881126b1a2f2f4b692bb26451`,
  C=`aac0a6230dddbd5991fa6b400c30adc546ff1178a1c0a1fde0b218c333408a9a`,
  D=`25df8ef8a29c292570368691cf9ef97ab56b11ffd2547409098aa2596907b888`.
- `ManufacturedAutoCompositionV1.jl:236-246` constructs the global typed AST;
  `:285-296` constructs the 7-node/4-edge graph; `:341-394` checks frozen
  identities, ordering, units, rank and owner joins; `:415-459` sorts the
  metadata collections before hashing. The existing AST API derives manifest
  bindings and performs CSE only for pure/CSE-safe nodes
  (`src/IR/TypedAST.jl:239-271`), while the hypergraph API validates typed
  edge endpoint compatibility (`src/IR/OperatorHypergraph.jl:350-374`).
- Ports retain physical type, unit, domain, equation, source, conservation
  owner, interface owner, and source owner. The Julia rejection controls cover
  invalid A/B/C/D, foreign input, unit/rank/port/domain/owner/interface,
  foreign hash/identity, missing capability, and label/order mismatch.
- Provider dropout is handled before product construction at
  `ManufacturedAutoCompositionV1.jl:317-331`: it returns
  `terminal_deferred/provider_drop` and does not construct a provider. The
  source contains no registration call, provider invocation, candidate, or
  solver path. `default_operator_registry()` is only read as the existing IR
  registry default (`:276-280`); `git diff --quiet` for TypedAST,
  OperatorHypergraph, and OperatorRegistry exited 0, and the shared entry is
  unchanged.

## Evidence history, cleanup, and boundaries

The actual A-D/M5/test/oracle bytes match the frozen hashes recorded in
`manifest.json`. Existing delivery, integration, and test receipts were
rehashed and their SHA-256 values are recorded there. R1/R2 process times remain
`not_recorded`; they are preserved and not upgraded. R3 wrapper failures
(`attempt1_wrapper_failure`, `attempt2_exitcode_failure`, and
`attempt3_taskoutput_failure`) and the two integration setup failures remain
archived and are non-authoritative. Existing cleanup inventories report no
ambiguous or broad deletion; this review also performed no cleanup outside its
own `independent_review_r1/` directory.

Two bounded observations do not block this limited decision: the Python oracle
intentionally checks a smaller negative-control subset than the Julia suite,
and the four stage edges use the existing legacy `TypedHyperedge`/`TypedAST`
compatibility form while the composition-level program is `TypedASTProgramV1`.
Also, a bare standalone include of M5 without the test adapter lacks
`_typed_ast_cse_key`; package context supplies the canonical helper and the
isolated test explicitly supplies its deterministic adapter. This is a harness
boundary, not a product mutation or an expanded claim.
These observations do not expand the claim ceiling; any formal re-entry still needs
the separate authority, candidate, provider, solver, and evidence gates.

## Reproduction index

See `manifest.json` for all frozen source/test/oracle hashes, current core API
hashes, receipt hashes, map values, role separation, and exact process records.
Raw outputs and process metadata are byte-preserved under `raw/`.
