# UP4-EARLY-PREPARATION independent review R1

## Verdict

`changes_requested`.

The package is well bounded as an additive preparation-only template: it keeps `review_pending`, `accepted=false`, `scope_status=preparation_only`, and `claim_ceiling=contract_only`; it does not run inverse, engineering, provider, mesh, solver, physical, Julia, DESC, or download work. The five JSON files parse, all pending records use `value=null` with a nonempty reason, the manifest has exactly eight deliverables, and all 30 listed input paths are present.

One provenance defect blocks a limited pass. In `reference_data_catalog_template.json`, the observed hash for `local_n2_normalized_result_context` is only 62 hexadecimal characters and does not equal the SHA-256 of the referenced local result. The recorded value is `2f4aa65c01a05634c86f50cf15f5e5688a0548b51166b32ab90547b5096e25`; the current file's SHA-256 is `2f4aa65c01a05634c86c8f50cf15f5e5688a0548b51166b32ab90547b5096e25`. The companion HELIOTRON artifact hash is 64 characters and matches its current bytes. This is a source-catalog evidence error, not a reason to run or download anything.

## Package state and exact paths

The manifest and companion documents preserve the intended boundary:

- `status=review_pending`, `accepted=false`, `all_conclusions=pending`, and `resolution=pending_independent_review`.
- Execution policy forbids inverse solve, engineering back-substitution, closed-loop work, Julia, DESC, provider, mesh, solver, physical execution, download/external data, shared registry edits, and final-package edits.
- The manifest declares exactly eight writable/deliverable files under this directory. All eight exist, and all 30 input-document paths exist.
- The existing cleanup inventory reports no task-local scratch/cache/unrelated code, no removals, and preservation of dirty and historical evidence. The independent review directory is this review's output and is outside the package's eight declared deliverables.

Current delivery hashes were recomputed:

| file | bytes | SHA-256 |
|---|---:|---|
| `architecture_audit.md` | 9803 | `8122dafe3688642fe353ebdf3a7197853f7508bea8911ba4033cd8b6bc5af4b8` |
| `cleanup_inventory.md` | 1951 | `6650d088b709b8753baa48c126de93ce4667f3b8c444de01bcaa2e920e7aeb99` |
| `inverse_problem_input_template.json` | 9788 | `2850d7fd39be64c974a2f68876b4eb90698d02c49de2da4e38343f5367daf62c` |
| `manifest.json` | 5688 | `fdf1076c61d4cd343dd3b030bd6e3da152dc9380887762d383f00eb78ca755d3` |
| `reference_data_catalog_template.json` | 10985 | `8fa11d5913d30d32516cd6b3cbc43115703342b66cb33136ff488ee71b6fc825` |
| `source_coil_actuator_constraints.json` | 9659 | `aa2be2d58420209f4f5adc51633e327a4eaf3ea69fe8de088a49e2e8a6f82db6` |
| `units_coordinate_transform_contract.json` | 8280 | `4da6451031065f7898e76e247a73ed6e6ee2ec97f65d281f892aea9bbc5b312c` |
| `validation_report.md` | 3295 | `fbf8ac19195cbe01bf58f3e70366514619bb66521087114b2bb41ffb56d87944` |

The hashes above describe the current package and are not future candidate or solver authority.

## Reference-data provenance

The catalog has the required fields for source path, source kind, owner, license/usage rights, version/release, observation date, exact bytes hash, parser revision, units/frame, calibration/uncertainty, applicability domain, split owner, candidate/scenario binding, and independence group. It clearly distinguishes read-only local context from a future reference dataset slot.

The HELIOTRON artifact at `benchmarks/desc_heliotron_v0173/HELIOTRON_output.h5` has a recorded 64-character SHA-256 that matches its current bytes. The normalized N2 result at `runs/goal_recovery_20260913_012528_cst/n2_desc_heliotron_normalize_r3/result.json` has the mismatch described above. Its owner/license/parser/units/calibration/split/binding/independence fields remain pending, so the package correctly keeps it out of B07B authority; the bad observed digest still needs correction because it is presented as a byte identity.

The catalog also keeps the existing `SpatialPickupEngineeringV4` declaration as observed context with exact future source hash still pending, labels it exploratory, and prohibits use as a generic source inverse provider, total external field, nonzero static EMF, or manufacturing qualification. No future candidate hash is invented.

## Units, coordinates, transforms, and signs

The SI contract declares seven rational base exponents in kg/m/s/A/K/mol/cd order and records canonical units and dimensions for length, time, angle, magnetic field, current, current density, surface current, flux, voltage/EMF, power, temperature, stress, resistance, and inductance. Normalization preserves original/SI units, scales and transform identity; round-trip tolerance remains pending.

Frame authority is pending for frame ID, axis order, origin, basis, handedness, normal orientation, and same-candidate G2 authority. The Cartesian right-handed and N2 unit-turn charts are explicitly observed context, not future defaults. Transform records require direction, affine translation, basis convention, determinant, explicit inverse, scale, uncertainty, and hash. The contract requires inverse-transpose treatment for normals, rejects negative parity without proof/sign update, and includes negative controls for axis permutations, handedness, normal reversal, degrees/radians, silent metric conversions, dimension mismatch, noninvertibility, wrong normal transformation, round-trip failure, and static flux used as EMF.

## Source, coil, actuator, and engineering constraints

The source/coil/actuator contract separates declarations from providers, solved sources, manufactured components, and engineering passes. Candidate, scenario, physical-subject, and future solver/provider bindings remain typed pending. The observed pickup slice records finite geometry and conditional RL values only as legacy context; external coils, outer-sheet current, total external field, return closure, thermal boundary, material qualification, manufacturing domain, control dynamics, and safety/fault evidence remain unresolved.

Future records cover geometry/support/clearance, current/density, voltage/power/energy, thermal/cooling, material/structure, manufacturing/maintenance, actuator/control, and safety/fault boundaries. Each has units, a hard gate, required authority, and a negative control. Missing authority resolves to `unknown` plus `terminal_deferred`; structural contradictions are `fail_closed`; numerical, physical, interruption, and program-exception classifications are kept distinct.

## B07A/B07B and binding review

B07A is explicitly the synthetic-target/source-hardware branch. It requires finite source/return/power/thermal/material/manufacturing/control domains, multi-start traces, an independent forward checker, scenario coverage, rank/conditioning and ledgers. Its credit boundary excludes R02 real-reference inverse credit.

B07B is explicitly the provenance-complete true-reference hidden-parameter branch. It requires source/license/version/hash provenance, source-owned geometry and basis, hidden-parameter withholding, candidate-independent calibration/validation/held-out splits, identifiability, uncertainty, representation round-trip, and held-out prediction. Synthetic targets, self-generated MMS, benchmark labels, and answer leakage are prohibited. The package keeps B07A and B07B adapters, manifests, independence groups, and evidence envelopes separate.

Candidate, scenario, physical subject, solver input, provider manifest, source dataset, artifact, and receipt joins are required to be exact and candidate-bound. G1/G2/G3 edits rebuild identity; provider results cannot clear a missing feedback authority gap. The required future chain remains target → finite source → field → circuit/power → thermal/material/structure → control/fault → field feedback.

## Cleanup and boundary

The package's own cleanup inventory reports no scratch/cache/unrelated code and no removals, and protects `src/`, `test/`, `scripts/`, `runs/`, `benchmarks/`, v4 documents, task manifest, registries, final package, and external implementation records. No Julia/DESC/provider/mesh/solver/physical execution, download, or external write was performed in this review.

Minimum repair: replace the malformed 62-character normalized-result digest with the verified current SHA, update the package's affected file hash and any package-local validation/cleanup references, then obtain a fresh independent review. Do not promote the record to source authority or execute inverse/physical work as part of that repair.

Until then, this package remains `review_pending`, `accepted=false`, and `preparation_only`. UP4, actual engineering, physical, B07A, B07B, R02, R04, R05, and R01-R10 credits remain false.
