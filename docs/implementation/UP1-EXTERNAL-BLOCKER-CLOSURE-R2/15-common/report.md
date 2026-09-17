# UP1 external closure R2 — common evidence foundation

Scope is limited to the isolated `common` package and its parameterized Python
tests.  The package has no network, system-clock, trust-store, credential, or
gate-credit authority.  It supplies versioned strict canonical JSON,
SHA-256/content identity, typed status/error values, exact-set manifest checks,
bounded regular-file reads, domain-separated candidate/source fingerprints,
and deterministic receipt construction.

## Contract boundaries

* `UP1-R2-CJSON-1` rejects duplicate object keys, non-finite values, negative
  zero, non-UTF-8/lone-surrogate strings, unsupported values, cycles, and
  non-canonical JSON bytes.  Numeric integral floats are represented once
  (`1.0` is canonicalized to `1`); alternate input bytes are rejected by
  `parse_canonical_json`.
* Identity preimages are domain/version tagged and are never populated from a
  clock or external service.  Candidate/source payloads containing identity
  fields fail closed unless the caller explicitly declares the omission.
* Manifest checking compares an explicit normalized POSIX path set and hashes
  only regular non-symlink files.  Reads are bounded by `16 MiB` by default and
  use an over-read guard in addition to the initial size check.
* Receipt hashes exclude only the explicitly listed self-hash fields.  PID,
  UTC observations, exit code, command, raw stdout/stderr and artifact hashes
  are all caller-supplied and are not trusted time or external authority.

## Verification

The fresh process command was:

```text
python -B -m unittest discover -s test/up1_external_closure_r2/common -p test_*.py -v
```

The run used Python 3.13.5, launcher PID `110268`, UTC observation interval
`2026-09-16T18:43:38.176127+00:00` to
`2026-09-16T18:43:38.375669+00:00`, and exit code `0`.  Thirteen tests passed,
including positive round trips, duplicate-key/non-finite/non-canonical numeric
negative controls, numeric subclasses, JSON error taxonomy, bounded reads,
exact-set mismatch, bare-string rejection, replacement race detection, domain
separation, self-reference rejection, status/error validation, receipt replay,
and serializer-subclass/closed-field rejection.

Raw stream material and the machine-readable run record are in `raw/`; all
hashes are recorded in `manifest.json`.  This is software contract evidence
only and does not establish external trust, source authority, provider
capability, B00/B04, physical evidence, or R01–R10 credit.

## R1 rework replay

The independent attack driver was replayed with fresh `python -B` (latest
capture PID `30120`, exit `0`). Numeric subclasses, nested/cyclic identity payloads, wrong
fingerprint domains, conflicting digest aliases, unknown statuses, reverse UTC
intervals, normalized duplicate manifest paths, and implementation
hash/manifest checks are retained in `raw/rework_review.*` and
`rework_review_run.json`. The original R1 failure artifacts remain untouched
under `reviews/15-common-independent-review-r1/`.
