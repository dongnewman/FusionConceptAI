# W1 witness/authority independent review — round 4

## Decision

`rework_required` for package closure, with `W1-R2-P2-001` itself closed.

The fresh `python -B` run PID `34140` independently observes the two required
foreign-binding decisions: `ERR_FOREIGN_LAYER_CANDIDATE` and
`ERR_FOREIGN_AXIS_CANDIDATE`. The evaluator reports `EXPECTED_FIELDS_READ=0`.
Both fixtures contain complete valid-shape fields and the mismatch is isolated
to the corresponding layer or axis candidate binding. Prior safety contracts
and negative controls show no regression.

The package-level exact-set requirement is not satisfied: 51 files are present,
the cleanup inventory owns 49, and two R3 raw files are unowned:
`repair_r3/raw/static_validator.stdout.raw` and
`repair_r3/raw/static_validator.stderr.raw`. This also does not match the
requested 48-file closure. No deletion or witness modification was performed.

Claim ceiling remains `preparation_only`; no UP1, T0/T1/T2, B00/B04, R01-R10,
L4, trusted authority, or parent-goal credit is granted.

## Scope and checks

Only this review directory is written. The witness package, source, tests, ADs,
registries, and shared documents were read-only. All package JSON parsed with a
duplicate-key rejecting parser. Cleanup hashes for all 49 owned rows match; the
two unowned raw files are byte-identical copies of the retained run01 stream
and have hashes recorded in `findings.json`.

The R3 fixtures are non-placeholder valid-shape records: the layer fixture has
all G1/G2/G3 and four-axis refs, hashes, candidate IDs, source revision,
version, nonce, and trusted time, with only layer candidate IDs foreign. The
axis fixture has matching layer IDs and only the schema-axis candidate foreign.
The positive typed-absence, placeholder, retry, and prior safety-contract
checks remain present and pass in the PID34140 output.

## Required recovery

Reconcile the witness exact set to the task's 48-file target (or record an
explicit revised contract before acceptance), remove/archive only with an
authorized exact-path decision, update cleanup/manifest/hash ledgers, and
independently recheck JSON uniqueness. Keep PID34140 and all prior raw evidence
immutable. Do not create an AD or open a formal gate.
