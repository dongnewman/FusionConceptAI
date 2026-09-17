# AD-39 G1/G2 publication input recovery audit — repair R1

Date: 2026-09-15  
Scope: append-only repair of the AD-39 audit after independent review R1
(`changes_requested`). The original AD-39 report, manifest, cleanup inventory,
review and all earlier receipts remain byte-for-byte preserved.

## Repair decisions

The AD-36 external policy is now current and accepted-limited. The frozen
current pair is:

- `docs/implementation/AD-36/manifest.json`: 5928 bytes,
  SHA-256 `4f71a9fc434362f3b37f1f5d7855b6c2e6558a6011b3fbd771bfc089022019e9`.
- `docs/implementation/AD-36/acceptance.md`: 3216 bytes,
  SHA-256 `aa8610dec1c4259730fd4639cb1531da7aa5d8fd0122f167e4424f3084664dc2`.
- `docs/implementation/AD-36/status_sync_r3/report.md`: 1689 bytes,
  SHA-256 `a9b751e785dbd17c79bd8975e610e2f383426d88fab0a01231734fb4c2975f32`.
- `docs/implementation/AD-36/status_sync_r3/manifest.json`: 8725 bytes,
  SHA-256 `5e1fe238e484d68bfdde6f50e0ea493358a222f4464ef55abf92636980b7aafd`.

The original AD-39 receipt recorded AD-36 as 6021 bytes with an earlier hash.
That pair is retained as historical receipt data and is not silently rewritten.
The R1 observation of a same-hash/size mismatch is treated as a receipt
metadata defect: authority is established only by the current recomputed
byte-count/SHA pair above. A stale receipt never promotes a source or a
candidate.

AD-36 being accepted removes only the evidence-sidecar policy blocker. It does
not create fresh source input, factory authority, provenance, candidate
identity, G2 mapping, present parent binding, T0, T1, T2, provider, mesh,
engineering, physical or R01-R10 evidence. Both publication work orders remain
`proposed_blocked_external` until their fresh inputs are produced and
independently reviewed.

## Exact semantic ownership and fresh-input contracts

The canonical input paths are the AD-37 paths under
`docs/implementation/AD-37/G1-PRESENT-BASELINE-PUBLISH/input/` and
`docs/implementation/AD-37/G2-PRESENT-BASELINE-PUBLISH/input/`. They are
future input paths; none currently exists. Each owner below is a proposed
producer boundary, not a new task-manifest node.

For both layers:

| Input | Canonical owner and producer | Required schema/hash/canonicalization | Missing or contradiction policy |
|---|---|---|---|
| `input/source_bytes.bin` | External source authority `EXT-<layer>-SOURCE-AUTHORITY` | Raw UTF-8/source bytes as supplied by the authority; SHA-256 over exact bytes; no text normalization; the hash must be repeated in `source_record.json` | Missing: typed absence/`terminal_deferred`; byte/hash mismatch: `fail_closed` |
| `input/source_record.json` | Same external source authority | `SourceRecordV1`; UTF-8 LF canonical JSON, lexicographic named keys; SHA-256 over canonical JSON; contains locator, source version, raw byte hash, semantic body hash and layer | Missing or absent locator: `terminal_deferred`; malformed or conflicting hash/locator: `fail_closed` |
| `input/candidate_binding.json` | Proposed `AD39-<layer>-CANDIDATE-BINDING` owner | `CandidateBindingV1`; canonical JSON SHA-256; exact fresh public `GenomeContractRef`/candidate ref equality, no suffix/alias matching | Missing: `terminal_deferred`; foreign candidate, layer or public ref: `fail_closed` |
| `input/provenance_axes.json` | Proposed `AD39-<layer>-PROVENANCE-ATTESTATION` owner, independently attested | `GenomeProvenanceAxesV1`; canonical JSON SHA-256; four exact axes: payload schema, canonicalization, applicability, evidence receipt, each bound to the same source/candidate | Missing axis: `terminal_deferred`; axis/source/candidate conflict: `fail_closed` |
| `input/factory_receipt.json` | Proposed `AD39-<layer>-SOURCE-BACKED-FACTORY-RECEIPT` owner | `FactoryConstructionReceiptV1` fields plus raw/semantic/declaration hashes; canonical JSON SHA-256; `source_backed_present`, exact binding, declaration hash recomputed | Missing: `terminal_deferred`; status, locator or recomputed hash conflict: `fail_closed` |
| `input/fresh_candidate_identity_review.json` | Different Luna `AD39-<layer>-FRESH-IDENTITY-REVIEW` reviewer | `FreshCandidateIdentityReviewV1`; canonical JSON SHA-256; independently rebuilds candidate, parent, child/state/receipt identities from the fresh inputs | Missing: `terminal_deferred`; stale/reused/foreign identity: `fail_closed` |

G1's semantic owner is **mechanism diffusion declaration and source body only**.
It owns no G2 mapping, G3 child, T0 authority or physical claim. Its exact
fresh input paths are:

- `docs/implementation/AD-37/G1-PRESENT-BASELINE-PUBLISH/input/source_bytes.bin`
- `docs/implementation/AD-37/G1-PRESENT-BASELINE-PUBLISH/input/source_record.json`
- `docs/implementation/AD-37/G1-PRESENT-BASELINE-PUBLISH/input/candidate_binding.json`
- `docs/implementation/AD-37/G1-PRESENT-BASELINE-PUBLISH/input/provenance_axes.json`
- `docs/implementation/AD-37/G1-PRESENT-BASELINE-PUBLISH/input/factory_receipt.json`
- `docs/implementation/AD-37/G1-PRESENT-BASELINE-PUBLISH/input/fresh_candidate_identity_review.json`

The proposed producers are respectively
`EXT-G1-SOURCE-AUTHORITY`,
`AD39-G1-CANDIDATE-BINDING`,
`AD39-G1-PROVENANCE-ATTESTATION`,
`AD39-G1-SOURCE-BACKED-FACTORY-RECEIPT`, and
`AD39-G1-FRESH-IDENTITY-REVIEW`. The factory producer depends on the first
four inputs; the identity reviewer depends on all six. The source and binding
records can be prepared in parallel, but no future publication implementation
may run before the exact inputs are frozen.

G2's semantic owner is **chart, metric, boundary, topology and
discretization declaration body only**. It owns no G1 mechanism, G3 source or
T0 authority claim. It uses the same six input classes under
`docs/implementation/AD-37/G2-PRESENT-BASELINE-PUBLISH/input/` and adds:

| Input | Canonical owner and producer | Required schema/hash/canonicalization | Missing or contradiction policy |
|---|---|---|---|
| `input/g2_candidate_mapping_receipt.json` | Proposed `AD39-G2-CANDIDATE-QUALIFIED-REF-MAPPING` owner, independently checked | `GenomeContractToQualifiedRefMappingReceiptV1`; canonical JSON SHA-256; exact source `GenomeContractRef` URI/version/schema/canonicalization/profile to common `QualifiedRefV1` id/version, candidate binding and algorithm/profile hash | Missing: `terminal_deferred`; URI alias, hash, layer or candidate mismatch: `fail_closed` |

Its exact fresh paths are the seven AD-37 G2 paths including
`g2_candidate_mapping_receipt.json`. Mapping depends on the fresh G2 public
contract and source record, and identity review depends on the mapping plus all
other inputs. G1 and G2 remain sibling work orders and cannot depend on one
another.

The G2 source declaration may still report independent
`mesh_authority`/`boundary_authority` `terminal_deferred` gaps when the
declared backend is absent. Publication of a source-backed declaration cannot
promote those gaps to mesh, provider, engineering or physical evidence.

## Preserved work-order boundary

The original 14 product files, three-way result union, outputs, dependency
lists, forbidden T0/authority-recheck/T1/T2 edges, direct-command rule,
independent review gate and task-owned cleanup rule are unchanged. This repair
only makes semantic ownership, producer ownership, exact input paths, schema,
hash/canonicalization and missing/conflict classifications explicit. It does
not create any future publication directory, source record, mapping record,
machine node or candidate hash.

The required result remains
`PresentBaselinePublicationV1 | AbsentBaselinePublicationV1 |
FailedBaselinePublicationV1`. A missing fresh input emits typed absence plus
`terminal_deferred`; an actual contradiction emits `fail_closed`; an
unexpected fault emits `program_exception`. Present remains false until an
independent fresh identity review accepts all required source-backed receipts.

## Validation and cleanup

The repair runs JSON parsing, current AD-36 byte/hash reconciliation, source
input hash rechecks, exact path scope, API symbol scan, control-character scan
and scoped diff validation. PID/UTC/exit/stdout/stderr and input/output hashes
are recorded in the task-owned `repair_r1/review/` sidecars permitted by
accepted-limited AD-36. No Julia, DESC, provider, mesh, solver or physical
command runs. Cleanup retains all previous receipts and removes no ambiguous
or foreign path.

