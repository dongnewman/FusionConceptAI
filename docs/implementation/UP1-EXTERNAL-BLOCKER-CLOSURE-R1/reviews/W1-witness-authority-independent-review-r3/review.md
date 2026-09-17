# W1 witness/authority repair R1 — round-3 independent review

## Decision

`rework_required`. Round2 P1 hash closure is complete and the evaluator no longer reads fixture `expected` fields. The current package has an exact 41-file cleanup set and all current manifest/validation hashes match. However, the foreign-layer fixture is intercepted by the generic `TEST/FOREIGN` placeholder branch and returns `ERR_PLACEHOLDER_PRESENT`; the evaluator never reaches `ERR_FOREIGN_LAYER_CANDIDATE` or an independent axis-binding check. Foreign binding rejection is therefore not independently observed.

Claim ceiling remains `preparation_only`; no UP1, T0/T1/T2, B00/B04, R01–R10, L4, trusted authority, or parent-goal credit is granted.

## Scope and boundary

Read-only review of `docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R1/witness_authority/**` and prior W1 reviews. Only this r3 review directory is written. No witness input, source, test, AD, registry, key, certificate, timestamp, CRL/OCSP response, or production trust material was changed.

## Checks performed

- The recursive directory contains 41 files. It exactly equals `cleanup_inventory.final_exact_owned_set`; all 41 cleanup hashes match, with only the documented manifest/cleanup self-hash exclusions.
- `manifest.product_hashes_at_manifest_preimage` now matches the current report and every listed product/raw. `validation_receipt.repair_r2` input/output/artifact hashes also match.
- All JSON parsed with a duplicate-key rejecting hook. Four prior failures remain exit 1 with explicit `collection_failure:pid_not_exposed_by_exec_capture` and timestamp markers; no PID/UTC was inferred. Prior successful PID 93696 and repair-r2 PID 100080/raw hashes remain recorded.
- `python -B` validator rerun: PID 27876, UTC 2026-09-16T15:55:57.363971+00:00–15:55:57.466484+00:00, exit 0, stdout SHA `0899d9954345669ab6b7911b0a76bfda44c1f0279e5d3489f1f227e8178262ed`, stderr empty SHA `e3b0c442...`.
- The evaluator source contains no `expected` field read. Observations are: positive shape → `typed_absence/ERR_NOT_PRESENT`; placeholder → `fail_closed/ERR_PLACEHOLDER_PRESENT`; retry placeholder → `fail_closed/ERR_RETRY_BUDGET_PLACEHOLDER_OR_INVALID`; foreign fixture → `fail_closed/ERR_PLACEHOLDER_PRESENT` before layer/axis checks.
- Independent audit PID 105712 ran 2026-09-16T15:56:22.850622+00:00–15:56:22.876477+00:00, exit 0, raw SHA `57b37465d6312d22ca2cd5449fbb219fbd052666a501d5f5f38ea39798b02ad8`.

## Regression decision

The original F001–F006 contract closures, round2 report-hash closure, typed absence/no-publish boundary, canonical/digest/request binding, freshness/revocation/trusted-time fields, and failure retention remain present. The unresolved point is narrower: the foreign negative fixture needs a non-placeholder valid-shape payload so the independent candidate/axis mismatch branch is actually exercised.

## Required rework

Use foreign fixture values that are not placeholder markers, assert `ERR_FOREIGN_LAYER_CANDIDATE` (and a separate `ERR_FOREIGN_AXIS_CANDIDATE` case), rerun with `-B`, and retain raw/PID/UTC/exit/hash. Do not open any formal gate or create a synonymous AD while the external inputs remain unchanged.
