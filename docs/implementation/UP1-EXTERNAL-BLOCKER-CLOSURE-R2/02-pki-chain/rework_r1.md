# Limited rework report — independent review R1 findings

The six review findings are closed within the original ownership boundary:

1. Production keys now use a fixed policy: RSA must be at least 2048 bits; approved EC curves are secp256r1/secp384r1/secp521r1; Ed25519/Ed448 are allowed; DSA and weak certificate hashes are rejected.
2. Receipt `issued_at`/`expires_at` are strict UTC timestamps with ordering and evaluation/trusted `gen_time` window checks. Expired or malformed receipt/time windows fail closed.
3. RFC822 constraints use mailbox equality or domain label boundaries, so `notexample.com` cannot satisfy `example.com`.
4. Leaf `digitalSignature` is required and `keyCertSign`/`cRLSign` are forbidden.
5. Receipt/profile/revocation/trusted-time/replay objects have strict allowlists; JSON file decoding rejects duplicate keys before canonicalization. The CLI uses the same duplicate-key rejection.
6. Explicit caller mode, profile mode and certificate `TEST_ONLY` markers must agree; disagreement fails closed.

Fresh acceptance command:

```text
python -B -m unittest discover -s test/up1_external_closure_r2/pki_chain -p test_*.py -v
```

Result: 12 tests, exit 0. PID, UTC interval and raw streams are in `raw_fresh_r2/process.json`, `test.stdout.raw`, `test.stderr.raw`, and `test.exit`. Their SHA-256 values are recorded in `hashes.json`. Source and test hashes are recorded in `manifest.json`.

The production trust root, external attestor, signed revocation response and independent trusted-time authority remain absent. Synthetic production-shaped test chains are not external authority and do not change the parent `no_publish` boundary.
