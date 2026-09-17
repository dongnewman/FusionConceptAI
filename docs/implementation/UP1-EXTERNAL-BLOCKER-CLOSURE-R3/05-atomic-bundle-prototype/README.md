# UP1 R3 bounded atomic bundle prototype

This additive package is an offline, local-only prototype. It validates the
R1 repaired Draft 2020-12 schemas, rejects duplicate keys/non-finite numbers/
invalid UTF-8/unsupported numbers, recomputes payload, owner, set, review and
bundle digests, and exercises EHP-03/EHP-04 cross-field relations. The
canonical exclusion and preimage definitions are machine-readable in
`preimage-profile.json`; `signature_digest` and `payload_digest` are rejected
aliases.

`validate_bundle` durably writes the exact received bytes to a local
content-addressed quarantine file using write+flush+fsync+atomic replace and
returns its immutable locator, raw size/hash, and CAS transaction. It never
contacts an endpoint, reads an ambient trust store, runs Julia/DESC/solver, or
creates credentials. TEST_ONLY Ed25519 fixtures are software controls and are
always `non_evidence`.

The implementation deliberately reports only `prototype_pass_limited` or
`fail_limited`; `formal_credit` is `none`, `authority_credit` is `false`, and
`no_publish` is `true` for every result. An internal `decision=accepted_all`
therefore never means external acceptance. `not_executed` is always
`terminal_deferred`.

The wire contract's embedded exact-raw digest is self-referential if treated
as the hash of the complete JSON envelope. The prototype retains and hashes
the complete raw envelope independently, then fail-closes when the submitted
wire receipt cannot bind to it; it does not solve that circularity by
silently hashing a different object.

Run the focused tests twice, offline, with:

```text
python -B -m unittest discover -s test/up1_external_closure_r3/atomic_bundle -p "test_*.py"
```

The acceptance vector inventory is `acceptance-test-matrix.json` and includes
R01-R25 plus D01 decision disagreement. It is an implementation inventory,
not external authority or parent-goal evidence.
