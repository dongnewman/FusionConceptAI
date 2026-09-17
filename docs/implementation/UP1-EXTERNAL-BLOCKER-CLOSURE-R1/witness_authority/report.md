# W1 external witness / authority-channel audit

## Result

The bounded audit is complete as `preparation_only` and `review_pending`. The
existing records establish software-limited source-stage evidence only: AD54 and
AD56 are limited local software decisions, while AD55 F0/S2 is a mixed HEAD plus
dirty-AD56 factory boundary. Fresh S3 remains
`blocked_external_trust_root_and_source_closure`.

The witness audit found no supplied independent identity, qualification,
independence/conflict disclosure, trust root, key/certificate chain, signed
attestation, trusted time, revocation/freshness policy, or independent verifier
receipt. The channel audit found no supplied endpoint, owner, acknowledgement
schema, retry/idempotence receipt, or rejection receipt. These are recorded as
typed absences with responsible party and recovery/expiry conditions in the JSON
registers; no URI, key, signature, nonce, provider, or receipt was invented.

## Evidence boundary

AD55's F0/S2 raw execution and independent review remain historical references;
this W1 package does not re-run or retroactively strengthen them. The six
source-owner paths and three AD56 factory files are input references only. A
fresh source closure must freeze all probes, harnesses, loaded dependencies and
environment before any future S3 attempt. Existing UP1/T0 scaffolds remain
typed-absent/contract-only and do not unlock T0/T1/T2 or B00/B04.

## Executable preparation

`authority_channel_contract.json` defines request/ack bindings, idempotence,
retry and rejection semantics. `witness_attestation_schema.json` defines the
required independent attestation fields. Placeholder examples are explicitly
`TEST/PLACEHOLDER` and cannot satisfy any field. The one direct Python command
performed only JSON parsing and static assertions; its stdout, stderr and
combined raw bytes plus SHA-256 are preserved under `archive/static_validation/`.

## Independent review requested

The reviewer must check role separation and conflicts, every absence's named
provider/owner/recovery/expiry, exact object/hash binding, rejection semantics,
placeholder non-evidence, raw/hash consistency, exact cleanup inventory, and
that no path outside this directory changed. Sol must retain the preparation-only
ceiling and the unchanged UP1/T0/T1/T2/B00/B04/R01-R10 state.

## Repair R1 disposition

The independent review's six findings were addressed in-place. The input
register now uses explicit non-null typed-absence provider/owner/authoritative
source/authority references and machine-checks them against gap IDs and
responsibility/recovery/expiry text. The witness schema has complete contracts,
including verifier and idempotency fields, canonical-preimage and digest
equalities, signature scope, trusted-time/freshness/revocation windows, and
replay controls. The channel contract now binds candidate ID, G1/G2/G3 exact
refs and hashes, four-axis refs/hashes, source/version and nonce/time. Positive
shape and negative placeholder/foreign-binding fixtures are included; the
placeholder retry policy has a dedicated negative fixture.

Four failed validator attempts are retained under `repair_r1/raw/` with
failure receipts. The corrected static validator completed with PID `93696`,
exit `0`, UTC `2026-09-16T15:33:27.540529Z`–`2026-09-16T15:33:27.543658Z`.

## Repair R2 disposition

The round-2 review required a stale report hash repair and an evaluator that
actually executes negative behavior. `repair_r1/static_validator.py` was
rewritten as an independent evaluator: it does not read fixture `expected`
fields. The redirected R2 run evaluated the production-present shape and
returned `typed_absence/ERR_NOT_PRESENT` for the TEST_ONLY shape,
`fail_closed/ERR_PLACEHOLDER_PRESENT` for placeholder-present,
`fail_closed/ERR_RETRY_BUDGET_PLACEHOLDER_OR_INVALID` for placeholder retry,
and `fail_closed/ERR_PLACEHOLDER_PRESENT` for the foreign layer/axis fixture.
All four observed decisions and error codes are retained in the R2 receipt and
raw streams. The package remains preparation-only; no production authority or
external input was created.

## Repair R3 disposition

The remaining foreign-binding finding was isolated without changing the
authority semantics. The layer fixture now uses valid non-placeholder refs and
64-hex hashes but mismatched layer candidate IDs; the separate axis fixture
uses valid layer bindings but a mismatched four-axis candidate ID. The fresh
`python -B` run independently observed
`ERR_FOREIGN_LAYER_CANDIDATE` and `ERR_FOREIGN_AXIS_CANDIDATE`, with no
`expected` field read. Prior R3 run raw evidence was retained before the
label-corrected rerun.
