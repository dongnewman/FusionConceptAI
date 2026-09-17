# UP1 R4 trust-chain independent test

## Scope and boundary

The implementation under test was treated as frozen:
`tools/up1_external_closure_r4/trust_chain/`. No implementation file was
edited. The independent suite is
`test/up1_external_closure_r4/trust_chain/test_trust_chain_independent.py`.
Fixtures are generated in the test process with `cryptography`; the tests do
not use verifier helpers to construct certificates, do not load an OS trust
store, and do not access the network.

Coverage includes:

- exact raw-byte SHA-256 for PEM and DER, plus DER identity reporting;
- caller-pinned root and raw hash declarations;
- ordered chain, issuer matching, certificate signatures, AKI/SKI;
- CA, key-usage, RSA key strength, and path-length constraints;
- explicit RFC3339 trusted evaluation time and timezone rejection;
- unknown critical extensions and algorithm-policy downgrade;
- detached RSA-SHA256 signatures, invalid signatures, and absent signatures;
- `cryptography` absent (`python -S`) as typed unavailable;
- `TEST_ONLY` as `non_evidence`, never authoritative;
- static no-system-store/no-network surface and runtime network tripwire.

## Commands and evidence

Environment: Windows, Python 3.13.5, cryptography 44.0.1. The command was
run twice serially, not concurrently:

```text
python -m unittest discover -s test/up1_external_closure_r4/trust_chain -p "test_*.py" -v
```

Run 1: `PID=90620`, UTC `2026-09-17T01:32:36.8152421Z` to
`2026-09-17T01:32:43.9777708Z`, process exit `1`.

Run 2: `PID=71500`, UTC `2026-09-17T01:32:53.6066681Z` to
`2026-09-17T01:33:01.3335300Z`, process exit `1`.

Both runs were deterministic: 12 tests passed and the same one adversarial
test failed. The failing assertion is intentionally conservative:

```text
test_validity_uses_explicit_trusted_time_and_rejects_naive_time ... FAIL
AssertionError: 'unverified' != 'typed_absence'
expected error_code: EVALUATION_TIME_ABSENT
observed: status=unverified, error_code=None
```

The verifier currently calls wall-clock `datetime.now(timezone.utc)` when
`evaluation_time` is absent. Therefore the suite does not grant full
acceptance: an explicit trusted time is required before validity can be used
for an authority-like decision. This is the sole observed finding; the
remaining vectors passed, including typed `CRYPTOGRAPHY_UNAVAILABLE` with
CLI exit 2 and all invalid vectors remaining `no_publish`.

## Conservative decision

`INDEPENDENT_TEST=PARTIAL_FAIL`; `TRUST_CHAIN_RELEASE=DEFERRED` until missing
explicit trusted evaluation time is typed as unavailable/absent. Passing
local cryptographic checks remain `unverified`, `authoritative=false`, and
`no_publish=true`; they are software behavior only and are not external
authority evidence.

## Frozen implementation hashes (post-run snapshot)

```text
9082A2FF7C34DACC88BF2DDC7C53D276AC1315398B22E677FAAA1C8AAC30F73E  __init__.py
935A1C1166B0C1EA35A82256345000BF2C73DED718D77773BC27A71ECCE28F7D  __main__.py
26B074AB7859A4C2766DBA7FBFF5B895B3337E9BCBE8BFB7C7A7BC141A2134BA  cli.py
7E900386412AE7E157B58C89B76B53A8BB66A2AD9256DECE628030C6C496139A  README.md
E7F6FF4BCDD73BC22331200B8A7AAE70FA5BC7BE690D94426408F72ED4055E6C  verifier.py
```
