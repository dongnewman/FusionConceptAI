# Findings

## F-01 [P1] Unknown fields are accepted at all tested boundaries

Mutating the root, a responsibility package, or a receipt with an unknown
field still returned `status=verified`, `resolution=eligible_for_authority_recheck`,
and `no_publish=false`. The nested-fingerprint unknown-field variant behaved
the same. `_fingerprints` and the package/receipt readers select known keys but
never reject the remaining keys (`aggregate_gate.py:66-79`, `106-152`). This
violates the frozen protocol's requirement that unknown fields be rejected at
every public and nested boundary. It permits an unversioned assertion to pass
through the aggregate boundary.

## F-02 [P1] `authority_verified=false` is ignored

Adding `authority_verified=false` at the root, the `source_authority` package,
or its receipt still returned `verified` and
`eligible_for_authority_recheck` with `no_publish=false`. The implementation
derives status only from `status`/marker flags and fingerprints
(`aggregate_gate.py:89-103`, `174-217`); it has no authority-verification
predicate. A receipt that explicitly says authority is not verified must not be
eligible for authority recheck as if verified.

## F-03 [P1] Responsibility identity is not validated

Replacing the required `g1`, `g2`, `g3`, and `source_authority` names with
`a`, `b`, `c`, and `d` produced a verified aggregate. The code checks only the
count (`aggregate_gate.py:267-283`), not the exact G1/G2/G3/source-authority
set or one-of-each condition. This violates the T0/aggregate same-layer
binding contract and allows four unrelated packages to satisfy the gate.

## F-04 [P1] Ordered transition can be bypassed and sequence jumps are accepted

`transition` with `event=aggregate` and no prior intake returned
`event=aggregated`, `phase=aggregated`, `status=verified`; a fresh intake
carrying `sequence=2` or `sequence=99` also returned verified and
reset output state to sequence `1`. `_validate_root` only checks that sequence
is a positive integer (`aggregate_gate.py:220-232`), while `transition` accepts
both events and invokes aggregation without requiring the ordered prior state
(`aggregate_gate.py:296-323`). This violates the frozen ordered route and
permits a caller to skip intake/ordering checks.

## F-05 [P1] Canonical output is not invariant under responsibility-map order

Two semantically identical fresh inputs with the same candidate/source/input
fingerprints and the same four packages, but reversed mapping insertion order,
both returned verified. Their canonical result hashes differed:

```text
hash_a=d146759cc96f8da6ea68d753069ee943b2b4aac2be1635054d8e42983a4adee6
hash_b=ccb72ec5c4960c5a90a3a290650dbd4489ba9f8f060a5af4cfc7af645a60e568
```

`_package_items` preserves mapping insertion order (`aggregate_gate.py:106-125`)
and `aggregate_document` appends in that order (`267-271`). This violates the
protocol's deterministic canonical serialization/permutation requirement and
can produce non-reproducible aggregate receipts.

## F-06 [P1] Duplicate JSON object keys are silently collapsed by the CLI

A raw CLI input containing duplicate `status` keys in one receipt exited `0`
and returned a verified aggregate. `_read_json` uses `json.loads` without an
`object_pairs_hook` (`aggregate_gate.py:326-329`), so duplicate keys disappear
before validation. The protocol requires duplicate keys after canonical
normalization to be rejected or retained as an attempted duplicate receipt;
this parser behavior makes the attack unobservable.

## F-07 [P2] Fingerprint syntax is not validated

When all package and receipt values consistently used arbitrary non-empty
strings `x`, `y`, and `z`, the aggregate returned verified. `_nonempty_text`
checks only non-empty string shape (`aggregate_gate.py:55-57`), and no digest
format/length check is applied. If these fields are intended to be SHA-256
fingerprints as required by the evidence protocol, malformed values must be
fail-closed. This is secondary to the identity and unknown-field defects.

## Controls that passed

- Candidate/source/input mismatch in each axis became `conflict`,
  `terminal_deferred`, `no_publish=true`.
- Missing receipt status/fingerprint did not pass; typed absence/conflict was
  terminal and non-publishable.
- All typed-absence receipts stayed `typed_absence`, terminal, and no-publish.
- Changed input with a prior state emitted `intake_changed`, empty packages,
  `no_publish=true`, and `ad_created=false`; no automatic AD was observed.
- Injected `claims` values were not copied; the output ceiling stayed false/zero.
- Identical baseline inputs in two independent Python `-B` processes matched
  byte-for-byte semantic output and hash.
