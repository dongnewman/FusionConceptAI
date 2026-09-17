# AD-37 G1/G2 present-baseline audit — independentR1 repair

Date: 2026-09-15
Repository: `D:\\006-Programing\\LMC\\FusionConceptAI`
Scope: repair of the original audit only. The original `report.md`,
`manifest.json` and `cleanup_inventory.md` remain preserved byte-for-byte.

## Decision remains unchanged

There is no non-fixture, candidate-bound, source-backed G1 or G2 V1
declaration instance, factory construction receipt, or declaration receipt in
the inspected checkout. The present gate is therefore NO-GO for both layers.
The repository can construct structurally valid typed declarations from local
values in focused tests. Those values are synthetic contract inputs and cannot
establish source authority, candidate binding, a fresh factory receipt, or
four-axis provenance. The baseline scaffold remains typed-absent only; T0
authority recheck remains typed-absent or fail-closed; all implementation,
actual, physical, provider, mesh, solver, engineering, search, B00, B04 and
R01–R10 credits remain false.

This repair is documentation-only. It adds exactly the two files in this
`repair_r1` directory. It does not create a future publication directory or an
archive directory, and it does not modify core, source, test, fixture,
static-QA, launcher, old receipt or task-manifest files. Julia, DESC, provider,
mesh and physical execution were not run, and no candidate hash was created.

## Evidence-scope repair

Each future G1 or G2 publication has one exact archive owner:
`archive/evidence_index.json`. The index is append-only and is the only
enumeration of evidence sidecars. A sidecar is in scope only when its exact
relative path is registered before or in the same operation with all of these
fields: `path`, `kind`, `round`, `bytes`, `sha256` and `immutable=true`.
Allowed `kind` values are `raw_stdout`, `raw_stderr`, `exit`, `process`,
`input_output_receipt`, `negative_summary`, `repair`, `cleanup`,
`independent` and `status`. Product, source, test, fixture, static-QA and
launcher material is forbidden as an evidence sidecar. An unregistered
sidecar is a `scope_violation`. When the failure round is unknown, a new index
entry may be appended with its actual round label; an old entry may never be
overwritten. The repair manifest contains this contract without a path
wildcard.

## What can be made locally and what still needs authority

Repository-only inputs can produce a structural G1 `G1DiffusionDeclarationV1`
or G2 `G2MBDeclarationV1`, recompute their local canonical hashes, exercise
negative controls, and emit a typed absence or failure result. That is useful
contract evidence. It cannot turn a fixture into an authority, turn a URI into
a candidate binding, or prove that a factory consumed authoritative bytes.

The external or independently attested inputs still required for a present
publication are the fresh candidate/public-contract identity, authoritative
source bytes and locator, a factory construction receipt, four provenance-axis
records with attestations, and a fresh candidate identity review. G2 also
requires a receipt mapping the source `GenomeContractRef` to the fresh common
`QualifiedRefV1`; URI parsing, copied schema seeds and fixture labels are not
that mapping. G2 `mesh=no_match` and `not_executed` remain separate capability
gaps and cannot be promoted by a declaration receipt.

## Layer-separated additive work orders

The two proposals in `manifest.json` are independent and additive. Their
semantic owners remain disjoint: G1 owns diffusion mechanism/source body;
G2 owns chart, metric, boundary, topology and discretization body. Neither
proposal changes the baseline scaffold or T0/T1/T2. A changed G1 or G2 source
requires a new candidate identity and fresh downstream receipts.

Each proposal has the exact result union
`PresentBaselinePublicationV1 | AbsentBaselinePublicationV1 |
FailedBaselinePublicationV1`. The present branch carries typed candidate and
public-contract binding, source locator, factory and declaration receipts,
raw/semantic/source/declaration hashes, parent/child/state receipts and all
four provenance axes. The absent branch carries the requested identity,
absence reason/domain/digest, terminal-deferred admission and archive index,
with no fabricated source or factory receipt. The failed branch carries the
requested identity when known, a closed failure code, failure record and
failure digest, with `published=false` and fail-closed or program-exception
admission. Outputs are listed one by one in the manifest; fixtures are never
outputs.

The machine dependencies are explicit. Each proposal depends on accepted
limited-scope `UP1-01`, `UP1-02`, `UP1-03`, the accepted limited parent binding
requirement `PARENT-BASELINE-BIND-PREC`, and its own reviewed G1 or G2 V1
declaration task. These are requirements for admissible scope, not evidence
that a present authority already exists. The current parent scaffold remains
`accepted=false` as an implementation node even though its local typed-absence
contract is accepted. The own V1 task is still `planned/review_pending`.
Each proposal is blocked on fresh candidate/source/factory/four-axis inputs.
No edge is permitted to the sibling publication or to T0, T1 or T2; the
manifest includes an acyclic local DAG assertion.

## Exit boundary

An eventual present result requires exact candidate/public-contract binding,
fresh source bytes, source locator and factory identity, recomputed raw,
semantic, source-content and declaration hashes, parent/child/state/receipt
hashes, all four present provenance records, a fresh identity review, and
registered process evidence. Missing authority yields typed absence with
`terminal_deferred`; contradiction yields `fail_closed`; unexpected faults
yield `program_exception`. Static QA, JSON validation, focused contract
execution with raw stdout/stderr, PID/UTC, exit code and input/output hashes,
and independent review are exit gates. These gates remain contract-only and
do not grant provider, mesh, solver or physical credit.
