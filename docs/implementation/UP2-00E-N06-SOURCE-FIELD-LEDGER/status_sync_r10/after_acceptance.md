# UP2-00E N06 source-field-ledger mapping

Status: `accepted_limited`; `accepted=true` for the bounded actual-A typed projection and local mutation slice only.


## Sol status sync R10

Sol adjudicated this slice `accepted_limited` after the authorized R10 focused run exited 0 and the different-Luna `independent_postrun_r10` review returned `pass_limited`. The accepted scope is limited to the actual-A typed projection, five source-derived mutation classifications, baseline unit/dimension contradiction as `fail_closed`, and absent cross-layer mapping as `terminal_deferred`. The five formal N06 obligations, dimensioned G1→G3 source/field/return/heat/ledger/owner law, UP2 total, B00/B04, provider, mesh, engineering, physical and R01–R10 remain open and false.

All R1–R9 failures and raw receipts remain historical and immutable. The historical paragraphs below retain their original attempt status; this section and the manifest record the current R10 disposition. No runner exit or contract test is treated as physical evidence.
This bounded implementation adds a candidate-owned, versioned typed mapping
contract for N06-01..N06-05. It consumes an actual `CandidateStatePackageV5`
and a source-validated E0 `UP2CandidatePhysicalBindingV1`. It keeps the
original package hash and E0 `bound_input_hash` unchanged. The new mapping
hash is downstream input for a future E0+E1+E2 combined identity.

The projection records actual A G1 equation/occurrence/closure, G2 region and
boundary patch, and G3 resource port, ledger entry, account, closure and
control-resource link fields. Authored joins additionally require explicit
source-to-field-to-return/heat/ledger/owner scope and a dimensioned conversion
law, with distinct role locators and exact owner-account scope. The current A
package still lacks authoritative cross-layer semantics, so even an exact
authored local join remains `terminal_deferred`. Missing authority remains `terminal_deferred`; contradictory typed
references, units, directions, kinds, capacity or closure values are
`fail_closed`; unexpected exceptions remain `program_exception`.

Shared G3 owners may own multiple accounts. Owner-string equality is not a
double-count proof; only an exact duplicate event plus ledger scope may reject
the mapping. G3 local balance is not cross-layer conservation evidence.

The author focused R1 and R2 runs are preserved as real `exit=1` failures.
R1 exposed an unsupported first-generator default; R2 reached the mapping
validator and rejected the then-invalid authored sample with
`owner_scope_accounts_duplicate` and
`conversion_offset_invalid_for_derived_dimension`. The sample construction
now uses the actual unique owner-account scope and zero offset for derived
conversion, while the fixture-driven test asserts both invalid forms as
fail-closed controls. No Julia/DESC or formal B04 run is claimed as successful.
No compiler/provider/solver/mesh/engineering/physical or R01-R10 credit is
claimed. The next serial focused run and acceptance decision remain pending.

## Owned files

* `src/GenomeV5/UP2/N06SourceFieldLedgerMappingV1.jl`
* `test/GenomeV5/UP2/n06_source_field_ledger_mapping_fixtures.json`
* `test/GenomeV5/UP2/n06_source_field_ledger_mapping_tests.jl`
* `test/GenomeV5/UP2/run_n06_source_field_ledger_mapping.jl`

See `evidence_manifest.json` for the protected E0 inputs and static evidence
boundary.
Each authored mapping contains four explicit role bindings: `source`, `field`,
`return`, and `heat`. Each role carries G1/G2/G3 locators, an energy-boundary
identifier, owner account scope, and a typed dimension rule; a single generic
port/entry locator cannot satisfy the mapping contract. Source projection
selection is candidate-bound and cardinality checked: typed IDs and semantic
role predicates determine the actual path, duplicate IDs or ambiguous matches
fail closed, and mutation specs must match the selected source locator and
source type. Conversion laws carry a versioned content hash; dimensional
checks are structural only and any missing cross-layer authority remains
`terminal_deferred`.
The `power_from_effort_flow` rule requires an exact typed flow endpoint,
effort partner, and dimensional sum; absent or foreign partners fail closed.
The local law content hash identifies this authored N06 contract only and is
not external physical-law provenance.

After the independent R1 precheck, the implementation was tightened to reject
ambiguous source IDs, derive nonzero collection indices from the selected
typed objects, and bind every mutation to its actual projection locator and
type. Reordered networks therefore produce different source paths while
preserving the selected semantic object. These changes require a fresh serial
focused run; R1-R3 failures remain immutable historical evidence.

The post-R3 static repair adds exact projection identities for the selected
G1 equation, occurrence, closure, and G2 region/boundary, together with a
typed effort-flow partner on the power join. The selected G3 link must target
the selected flow port. The authored law hash remains an internal N06
contract hash, never an external source claim; a missing authoritative
cross-layer relation remains `terminal_deferred`.

The current R4 static repair uses a versioned authored selector table for all
four complete G1 occurrence keys and the G2 interface-left/boundary selector;
selection is exact and unique against actual typed objects. E0 validation is
called before projection and admission. Mapping joins carry the selected G1
keys, exact G2 boundary identity, and selected G3 flow-link identity, while
mutation dispatch is bound to field path, mutation kind, source type/locator,
and the selected typed target. The public mutation boundary requires the
actual package and E0 binding, revalidates the E0 envelope and exact
projection/source identities, and rejects detached projections or foreign E0
bindings before creating a receipt. Mutation IDs are receipt labels only;
dispatch does not use them as the target selector. R4 remains pending
independent review and a fresh serial run; R1-R3 receipts are preserved.

The authorized focused R4 run was executed once and is preserved as a real
`exit=1` `program_exception`: the first projection attempt used dot access on
the authored selector `Dict` (`N06SourceFieldLedgerMappingV1.jl:310`), with
8 tests passed and 1 errored before mutation receipts. The minimal static fix
uses the explicit `:source` dictionary key and adds a regression assertion;
R4 must be rerun only after a new independent static gate. This failure gives
no physical, provider, engineering, B04, or R01-R10 credit.

The R7 static repair adds a fixture-backed missing-selector control. It
temporarily removes the authored `:source` selector, invokes the actual
projection path, asserts the explicit missing-selector `ArgumentError`, and
restores the mutable selector in `finally`. No R7 Julia run has occurred;
the next focused run requires a new independent static gate.

The authorized focused R5 run used the frozen R7 source, fixture, test, and
runner hashes and exited `1` after `10 passed, 1 error`. Its main PID was
`11624`, with UTC interval `2026-09-14T04:47:09.5734224Z` to
`2026-09-14T04:48:27.2260002Z`. The error is a `program_exception` in
`_n06_unique_index` at source line 271: the actual G1 occurrence identity is
the typed tuple `(ledger_id, equation_id, port_side, port_index)`, but the
index path attempted `String(tuple)`. Raw stdout, stderr, process snapshots,
exit, receipt, and postflight evidence are preserved under `focused_r5/` and
summarized in `r5_failure.md`. The protected dirty files remained unchanged,
the postflight Julia/DESC sweep was empty, and no retry occurred. This is an
implementation exception and gives no physical, provider, engineering, B00,
B04, or R01–R10 credit; status remains `review_pending`/`accepted=false`.

