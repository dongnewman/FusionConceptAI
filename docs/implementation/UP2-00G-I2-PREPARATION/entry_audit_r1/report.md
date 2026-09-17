# G-I2 / B04 entry audit R1

## Verdict

`changes_requested`; `ready_for_focused=false`; `status=review_pending`; `accepted=false`.
This is a read-only entry audit. No Julia, DESC, provider, mesh, solver, engineering, physical, or R01–R10 evidence was produced. The 50-row G-I1B matrix is an input inventory and is not a formal B04 receipt set.

The repository was inspected at HEAD `4b69f55f7f80240147a65a22809dc1207824dde2`. The worktree is substantially dirty (`288` status lines, UTF-8 status digest `9677C5034EA791CB1998E0F23D48651FE4EC51CC2DD16AB69926696B375F914F`); those bytes were protected. No repository Julia/DESC process was present at the audit preflight. Frozen input hashes are recorded in `command_receipts.json` and `evidence_manifest.json`.

## Formal 50-receipt contract required before B04

There must be five fresh, candidate-bound rows for each N01–N10. Each row must be independently derived from the frozen actual A package and its validated upstream context, not selected by a fixture label. The receipt envelope must include, at minimum:

* candidate/package identity: complete candidate ref, package hash, complete G1/G2/G3 five-field public refs, three component hashes, four version axes, E0 binding/bound-input hash, and the G-I1 authority-context hash;
* slot identity and source: N-class/row key, typed field path, source type, exact source ref or owner ref, source path/locator, component/content hash, schema hash, canonicalization hash, compatibility-profile hash, original typed value and hash, attempted typed value and hash;
* mutation identity and result: canonical mutation payload/hash, source-derived error code, error path, resolution (`fail_closed`, `terminal_deferred`, or a separately preserved `program_exception`), and the authority gaps applicable to that row;
* execution evidence: compile/provider/solver/mesh counters (zero for contract-only rejection), checker version/hash, frozen input manifest/hash, command, process/environment metadata, stdout/stderr/exit artifacts, and receipt schema version.

N09 and N10 retain their special deferred/provenance rules. A present but deferred E1/E2 mapping must retain its typed content and independent schema/canonical/profile hashes; it must not be collapsed to an absent slot. Unexpected internal faults remain `program_exception`, distinct from a known source contradiction (`fail_closed`). `expected_error`, `expected_path`, row IDs, or fixture class labels may be test oracles only and cannot drive production classification.

The protocol's suggested mutation names are not runnable JSON pointers. Before the first B04 run, every row needs a frozen typed source accessor and an actual attempted value. The matrix currently does not provide that complete receipt.

## Independent checker contract

The formal checker must be a separate implementation and process boundary. It must read the serialized JSON from disk, reconstruct the actual package/E0/context and the authored or typed-absent slots, then recompute each source locator, value hash, mutation hash, classification, path, resolution, and counter expectation from production invariants. It must reject foreign or stale package/E0/context refs, altered candidate/axis/component hashes, forged source ref/path/type/hash, duplicated or omitted rows, changed canonical payloads, and forged absent/present metadata. It must also assert the exact N01–N10 by-five cardinality and the B00 F0–F5 receipt set.

The current N05 local checker is not this checker: its trusted overload reuses exporter `_n05e_row` to construct expected rows (`test/GenomeV5/UP2/n05_flux_receipt_checker.jl`, current SHA recorded in the manifest), while its one-argument path is only an envelope-structure check. Reusing an exporter expected-row helper would allow exporter and checker bugs to agree. The future checker must have independently written recomputation code or a separately trusted source manifest, and its tests must include forged source fields and content hashes after a file write/read round trip.

## Two-process replay contract

Process A and process B must be fresh, separately started Julia processes. Both consume the same frozen input manifest, fixture/schema/context hashes and candidate package bytes, but write to disjoint receipt/output directories. Each process loads each source path exactly once, emits its own command/environment/stdout/stderr/exit and receipt hash, and runs the independent checker. A canonical comparison then requires equality of candidate/package/E0/context/extension hashes, all 50 row identities and source/value/mutation/result fields, B00 F0–F5 fields, and checker result. Attempt ID, PID, wall-clock, and per-process log hashes may differ and must remain visible. A shared temp directory, in-memory object handoff, or a single runner loading exporter and checker in one process does not satisfy replay.

Both processes must finish the contract-only rejection path before any provider, mesh, solver, or physical claim. Formal B04 replay is downstream of a frozen schema and independent checker; runner exit zero by itself is not an exit gate.

## Dependency and exit gates

* **G-I1A:** The current author source is newer than the frozen independent R3 review. The author manifest remains `review_pending`/`accepted=false`, and no current independent review or focused runtime exists. The prior R3 `changes_requested` report cannot be reused as acceptance of the newer bytes.
* **G-I1B:** R2 is a `pass_limited` source inventory only. Its 50 rows are useful inputs, including the corrected N05-05 provenance, but the matrix is not a receipt, checker, or two-process run. N06 law/authority, N09 provider matching, and N10 fresh identity/receipt provenance remain bounded/deferred as documented.
* **UP2/UP1-04A:** UP2 remains review-pending overall. UP1-04A is accepted-limited for its additive structural entry/join scope; it explicitly leaves B00/B04, provider, mesh, engineering, physical, and R gates false.
* **B00/UP1-04B:** Before first B04 execution, freeze B00 F0–F5 and all 50 fresh candidate-bound mutation receipts, then run the independent checker and two-process replay. Only successful fresh receipts plus checker and replay evidence can open the formal UP1-04B gate; the complete UP1-04 acceptance and physical/provider gates remain separate.

## Current evidence and blockers

The repository has no formal UP1-04B 50-row receipt archive, no independent 50-row checker, no two-process replay, and no B00 F0–F5 execution. The existing UP2 fixture is explicitly `schema_validation_only`; its later rows include provisional/pending labels and its historical test uses synthetic reference input for part of the suite. The local N05 export is only 5 authored plus 5 absent rows and its checker shares the exporter row helper. UP1-04A's 45/45 evidence is an A-layer structural slice, not B04. No observed artifact supplies provider/mesh/solver/physical evidence.

Accordingly the exact blockers are: current G-I1A independent gate unresolved; UP2 total/schema freeze unresolved; fresh candidate-bound 50 receipts absent; independent checker absent; two-process replay absent; B00 F0–F5 absent; and all provider/mesh/engineering/physical/R gates remain false. The audit cannot authorize a focused B04 run and does not grant any parent-goal credit.

## Frozen evidence index

The machine-readable manifest records the inspected core contracts, AD-26, G-I1A current bytes and stale independent review, G-I1B R2 matrix/review, current UP2/N05 local assets, and UP1-04A evidence. `command_receipts.json` records the exact read-only commands and QA commands. This archive itself is append-only for this audit; no existing dirty file, run, source, test, core document, or prior archive was modified.
