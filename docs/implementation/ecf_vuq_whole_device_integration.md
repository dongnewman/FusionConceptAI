# G3 ECF to VVUQ and whole-device integration boundary

## Audit of `outputs/fusion_concept_ai`

| disposition | reuse decision |
|---|---|
| extract | preserve the candidate/subject/scenario binding and zero-credit evidence ceiling used by the existing G3 operational provider |
| wrap | use a typed bridge record and a typed whole-device integration request; both retain receipt hashes and refuse cross-context reuse |
| test-only | deterministic control/fault trace, dropout schedule, and actuator bounds remain operational screen checks only |
| reject | do not coerce `TrustedEngineeringControlFaultOperationalReceiptV4` into `TrustedProviderExecutionReceiptV4`; do not treat its trace as validation, UQ, manufactured evidence, promotion, or terminal authority |

The dedicated G3 receipt has a separate registry/executor/receipt schema.  The
new bridge therefore records an explicit recoverable non-bridge gap instead of
silently adapting it.  The whole-device request binds the same context,
subject, scenario and receipt, but remains `screen_only_deferred` with zero
evidence credit and withheld closure authority.

The bridge carries an `UpstreamProviderResultIdentityV4` for the dedicated ECF
execution only: provider id is `engineering-control-fault`, request/result
hashes bind to the ECF request and receipt, and execution/schema flags are true.
All validation/evidence/pass/promotion/P5/terminal fields remain false and the
credible physical device count is zero. Foreign provider, request, or result
identities are rejected.

The full-chain validator revalidates the dedicated registry, request and
operational receipt before reconstructing the bridge. Canonical bridge checks
also validate the nested identity hash and require an executed,
schema-validated ECF identity, so a canonical outer hash cannot hide a foreign
or unexecuted nested identity.

Remaining explicit gaps are a real multi-region provider, held-out physical
validation and UQ artifacts, and whole-device closure/terminal authority.

Reproduction:

```text
julia --project=. test/runtime_v4_ecf_vuq_whole_device_integration_tests.jl
julia --project=. examples/runtime_v4_ecf_vuq_whole_device_integration.jl
```
