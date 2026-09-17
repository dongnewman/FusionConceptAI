# UP4-EARLY-PREPARATION independent review R2

## Verdict

`pass_limited` for the repaired early-preparation template package.

Repair R1 corrected the malformed observed digest without changing the source artifact. The current normalized result is 7849 bytes with SHA-256 `2f4aa65c01a05634c86c8f50cf15f5e5688a0548b51166b32ab90547b5096e25`; the catalog value and the repair manifest's corrected value now match this 64-character digest. The original R1 blocker is closed.

This pass covers only the additive UP4 preparation templates and their software/provenance checks. It does not accept UP4 execution, inverse realization, engineering, physical evidence, B07A/B07B results, or R01-R10 credit.

## Repair R1 and cross-reference audit

The repair manifest is valid JSON, remains `review_pending`/`accepted=false`/`claim_ceiling=contract_only`, points to the parent package manifest, and identifies the corrected record and source path. The six repair-owned files all exist:

1. `reference_data_catalog_template.json`
2. `manifest.json`
3. `validation_report.md`
4. `cleanup_inventory.md`
5. `repair_r1/report.md`
6. `repair_r1/manifest.json`

The repair report, parent validation report, cleanup inventory, catalog, and repair manifest agree on the corrected digest and the exact repair scope. The source artifact itself remains unchanged. The parent manifest remains `review_pending`, `accepted=false`, `preparation_only`, and `claim_ceiling=contract_only`; it declares eight core deliverables and ten writable paths after adding the two repair records. The eight core deliverables remain present.

Current SHA-256 values for the repair-owned set are:

| file | bytes | SHA-256 |
|---|---:|---|
| `reference_data_catalog_template.json` | 11014 | `0693c0c78096e9e4b00b8871beaf28c1c28891d860a9e731aeb1e3f16ceea82a` |
| `manifest.json` | 6695 | `5b945eafe184981819db8b99a6cb37830ec8032a59d36c1af8810aea5f68363f` |
| `validation_report.md` | 4375 | `f885dda056a51ea47c82be89b17fdc937e6060be12d9b051d2026f5047d06aca` |
| `cleanup_inventory.md` | 2503 | `8bfeb949f5af9d35d7adcd3a145e806fcaf70f5b90abf95bc392e844e171a923` |
| `repair_r1/report.md` | 1636 | `c922abea0285144f6e8dc8cf957f46687fd39309426626a3c112aa9ff3edb948` |
| `repair_r1/manifest.json` | 2123 | `e4e727b314e3bab9e538c0cf0e1ab9c686a29ad9e4e7ce6fd607bb6267bf993a` |

The new independent review directory is this review's output and is not part of the repair-owned set.

## Recomputed validation

All five core JSON files plus the Repair R1 manifest parse successfully. Recursive pending validation found no errors: every `state=pending` record has `value=null` and a nonempty reason. All 30 parent input paths, all ten current writable paths, and all eight core deliverable paths exist. No future candidate, scenario, physical-subject, solver-input, provider, or transform authority hash has been invented.

The catalog's two observed local source hashes were rechecked. The HELIOTRON artifact digest remains matching. The normalized-result digest now matches exactly. The catalog still keeps owner, license, parser, units/frame, calibration, split, candidate binding, and independence authority pending where required.

## Original R1 findings that remain closed and unchanged

The package still defines SI base dimensions, typed units, coordinate axis/basis/handedness and normal ownership, explicit transform direction and inverse identity, determinant/parity rules, inverse-transpose normal handling, normalization round-trip requirements, and negative controls for axis permutation, handedness, normal reversal, silent unit conversion, dimension mismatch, noninvertible/negative-parity transforms, and static flux used as EMF.

Source/coil/actuator preparation still covers finite geometry, return closure, current/density, voltage/power/energy ledgers, thermal/cooling, material/structure, manufacturing/maintenance, actuator/control, and safety/fault boundaries. Each future constraint remains pending with required authority and negative controls. Missing authority remains `unknown` plus `terminal_deferred`; contradictory typed input remains `fail_closed`; `program_exception`, `not_executed`, numerical failure, and physical failure remain distinct.

B07A remains the synthetic-target/source-hardware branch with finite source/return/power/thermal/material/manufacturing/control domains and an independent forward checker. B07B remains the provenance-complete true-reference hidden-parameter branch with hidden-answer protection, candidate-independent calibration/validation/held-out split, identifiability, uncertainty, round-trip and held-out evidence. Neither branch has a result or credit. Cross-branch leakage remains prohibited.

Candidate, scenario, physical subject, solver input, provider, source dataset, artifact and receipt bindings remain exact and candidate-bound. No provider, inverse, engineering, mesh, solver, physical, download, Julia, or DESC work was performed for this review. The cleanup inventory still reports no task-local scratch/cache/unrelated code and no removals; dirty and historical evidence remain protected.

## Final boundary

The package may be accepted only as an early-preparation template with `review_pending`/`accepted=false` at the machine/package level. This `pass_limited` result does not authorize or credit UP4 execution, actual engineering, physical validation, B07A, B07B, R02, R04, R05, or R01-R10.
