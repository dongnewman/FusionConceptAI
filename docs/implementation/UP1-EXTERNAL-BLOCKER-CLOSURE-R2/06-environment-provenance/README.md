# Environment provenance R2

Implementation: `tools/up1_external_closure_r2/environment_provenance/`.
Tests: `test/up1_external_closure_r2/environment_provenance/`.

Run:

```text
python -B -m pytest -q test/up1_external_closure_r2/environment_provenance
python -B tools/up1_external_closure_r2/environment_provenance/cli.py <closure.json> [--root <path>] \
  [--expected-context <context.json> --expected-context-sha256 <sha256>] \
  [--trust-anchor <anchor.json> --trust-anchor-sha256 <sha256>]
```

`fixtures/test_only_positive.json` is synthetic, uses an isolated runtime
Ed25519 chain, and must return `non_evidence`. Missing production project
Independent expected-context and trust-anchor objects are required for signed
production validation, and each must be supplied with a caller-frozen SHA-256.
Bundle `expected_context` fields are forbidden. Missing production anchors or
signed publisher material remains `typed_absent`; forged signatures,
identity drift, and hash drift are `fail_closed`. Only a complete, verified
external receipt can produce `present`.

Declaration and signed payloads additionally authenticate receipt origin and
retrieval time, authority identity and verification time, binary licenses, and
SBOM supplier/license metadata through one exact authenticated closure.
