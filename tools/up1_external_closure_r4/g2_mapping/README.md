# UP1 external-closure R4 — independent G2 mapping prototype

This component is an independent structural checker for the R3-compatible
EHP-03 payload shape.  It verifies source/candidate binding, both graph
directions, endpoint coverage, duplicate rejection, edge and row digests,
mapping identity, and issuer/signature/authority reference consistency.

It does not verify cryptographic signatures, trust roots, trusted-time
services, or revocation services.  Therefore a structurally valid present
mapping is `terminal_deferred`; absent authority is represented explicitly as
`typed_absent` or `terminal_deferred`.  Every result has `no_publish=true` and
`formal_credit="none"`.  Any missing, malformed, duplicate, or conflicting
field is `fail_closed`.

Run in an isolated interpreter:

```text
python -B tools/up1_external_closure_r4/g2_mapping/validate_g2_mapping.py PROFILE.json
```
