# UP1 external-closure R4 — independent G2 mapping test

## Scope and boundary

This is a black-box test of `tools/up1_external_closure_r4/g2_mapping/`.
The implementation directory was not edited.  The independent fixture builder
owns its own JSON canonicalisation and SHA-256 preimages; it does not import
R3 digest helpers.  The positive fixture uses the R3 EHP-03 schema and field
names, with both graph directions, both mapping directions, source/candidate
binding, row/edge/graph/mapping digests, issuer/signature/authority refs,
coverage and inverse relations.

The validator's intended positive result is structural validity only:
`decision=terminal_deferred`, `production_admissible=false`,
`authority_verified=false`, `no_publish=true`, `formal_credit=none`.
No cryptographic signature, trust root, trusted clock, revocation service, or
external authority is inferred.

## Reproduction

Run from the `FusionConceptAI` checkout:

```text
python -B -m unittest discover -s test/up1_external_closure_r4/g2_mapping -p "test_*.py"
python -B test/up1_external_closure_r4/g2_mapping/adversarial_probe.py
python -B test/up1_external_closure_r4/g2_mapping/serial_run.py
```

`serial_run.py` runs the unit suite and probe sequentially in one lane and
prints child PID, UTC start/end, exit code, and raw stdout/stderr SHA-256.
The two complete serial raw captures are:

* [serial_run_1.raw.txt](raw/serial_run_1.raw.txt) — runner PID `96092`,
  unit child PID `8576`, unit exit `0`, probe child PID `35904`, probe exit `0`,
  run window `2026-09-17T01:31:23.274660Z`–`2026-09-17T01:31:23.713172Z`,
  raw SHA-256 `242E5C8DDA2F897DAE6B4932AAACE4B7EE662770607737966A54BF3EB5DFBBA3`.
* [serial_run_2.raw.txt](raw/serial_run_2.raw.txt) — runner PID `112664`,
  unit child PID `91252`, unit exit `0`, probe child PID `100760`, probe exit `0`,
  run window `2026-09-17T01:31:30.848957Z`–`2026-09-17T01:31:31.254175Z`,
  raw SHA-256 `B960A4C6A7B65EB5D6C71AE6B25EE015FCB30CDE0D159D9CA1501F17D89E7FBF`.

Both unit runs report `Ran 15 tests ... OK`.  The stable unit stdout digest is
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.
The probe intentionally exits `0` when it completes; its JSON result, not its
process exit alone, is the acceptance signal.

## Adversarial result and conservative decision

The probe found five cases that should be fail-closed but returned the normal
present-payload `terminal_deferred` result instead:

1. Duplicate graph endpoint pair with a different `issued_at`.
2. Duplicate mapping endpoint pair with a different `issued_at`.
3. Unknown profile `status` token.
4. Conflicting `g2_mapping`/`mapping` aliases (the first alias silently wins).
5. Forged top-level `source_identity_sha256` differing from the recomputed
   `source_identity` digest.

In all five cases the output still had `no_publish=true` and
`formal_credit=none`; this prevents publication credit but does not satisfy a
strict structural fail-closed requirement.  Therefore the independent
conservative verdict is **FAIL-CLOSED GAP / not accepted for closure**.  The
positive R3-compatible path is only a limited structural test and must remain
`terminal_deferred`.

## Source hashes recorded after the run

These hashes identify the implementation inspected; no implementation file
was changed by this test task:

| file | SHA-256 |
| --- | --- |
| `tools/up1_external_closure_r4/g2_mapping/validator.py` | `688DFB2185731F3B6708F25700C57EC6C9649AAEE435DD8543F57DDD266A9591` |
| `tools/up1_external_closure_r4/g2_mapping/validate_g2_mapping.py` | `7D32AF36BA0ABB1B7D9B53287A124C5A1982224AA97B3F53701C8F4F98FEC2A9` |
| `tools/up1_external_closure_r4/g2_mapping/g2_mapping.py` | `CDE09870851512AC8D5E45961387B51EE9CB12DBD07717F51E409AEED9E34DDE` |

