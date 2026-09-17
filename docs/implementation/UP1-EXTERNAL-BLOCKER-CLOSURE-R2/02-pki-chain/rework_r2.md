# Limited rework report — independent review R2 P1

The remaining R2 P1 acceptance path is closed within the original ownership boundary.

1. Production `algorithm` is an exact closed enum: `RSA`, `ECDSA`, `Ed25519`, or `Ed448`. `RSA-SHA1`, `RSA-MD5`, `RSA-SHA256`, case/spelling variants, MD2, and unknown values fail closed with `signature_profile_unknown`. Production digest, when present, must be the exact `SHA-256` policy value.
2. If a profile supplies both `algorithm` and `signature_algorithm`, they must be identical. TEST_ONLY keeps its existing `signature_algorithm` field, while any alias pair is still checked for equality.
3. Root, every intermediate, and leaf certificate are checked against the selected profile using the parsed certificate `signature_hash_algorithm` and signature OID. RSA/ECDSA require SHA-256 and their exact SHA-256 OID; Ed25519/Ed448 require their exact signature OID. Weak or unknown hashes/OIDs fail closed before acceptance.
4. Receipt `algorithm` and/or `signature_algorithm` declarations must exactly match the profile; both declarations, when present, must also match each other. Receipt verification dispatches only through the exact closed-enum algorithm and the fixed profile digest, so a string-only declaration cannot select a different verifier.

Regression coverage includes RSA-SHA1, RSA-MD5, unknown and spelling-variant production profiles, receipt declaration mismatch, profile alias mismatch, receipt alias mismatch, SHA-1/MD5/unknown certificate signature policy probes, plus the retained R1 failures. Fresh R3 execution:

```text
python -B -m unittest discover -s test/up1_external_closure_r2/pki_chain -p test_*.py -v
```

Result: 16 tests, exit `0`, PID `91884`, UTC interval `2026-09-16T18:32:29.9551153+00:00` to `2026-09-16T18:32:34.5200953+00:00`. Python `3.13.5`, `cryptography 44.0.1`, OpenSSL `3.0.18`. R3 raw/PID/UTC/exit evidence is under `raw_fresh_r3/`; R2 evidence remains under `raw_fresh_r2/`. Raw hashes are recorded in `hashes.json`; current source/test hashes are recorded in `manifest.json`.

The production trust root and external authority material remain absent. Therefore missing production trust remains `typed_absence` → `terminal_deferred`/`no_publish`; invalid certificates, signatures, algorithms, receipts, or policy inputs remain `fail_closed`. TEST_ONLY fixtures remain `non_evidence` and `no_publish=true`.
