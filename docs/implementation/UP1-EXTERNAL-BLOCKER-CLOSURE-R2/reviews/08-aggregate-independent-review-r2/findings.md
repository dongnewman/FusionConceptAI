# Findings

## F-01 [P1] Untrusted prior state permits cross-process aggregate/state bypass

The implementation extracts `input_fingerprint`, `state.sequence`, and
`state.phase` from the caller-provided `prior_state` and uses them as the
ordering authority (`aggregate_gate.py:394-416`). It does not require a
canonical prior-result hash, validate that `prior_state` was emitted by the
gate, verify its package list and fingerprints, or bind it to a prior receipt.

Independent fresh child processes using identical valid 64-hex inputs showed:

```text
fabricated phase=validated, sequence=3 + event=aggregate, sequence=4
=> event=aggregated, status=verified, resolution=eligible_for_authority_recheck,
   no_publish=false, phase=aggregated, sequence=4

fabricated same-input status=verified, no_publish=false, phase=terminal_deferred
=> event=deterministic_noop, status=verified,
   resolution=eligible_for_authority_recheck, no_publish=false, packages=[]
```

The aggregate branch explicitly accepts `prior_phase == validated` and then
calls `aggregate_document` (`aggregate_gate.py:417-433`); the deterministic
no-op branch copies status/resolution/terminal/no-publish/packages from the
untrusted prior (`aggregate_gate.py:434-435`). This bypasses the ordered
intake/validated predecessor and can mark an empty fabricated lineage as
publishable. A cross-process state receipt must be authenticated or fully
revalidated and must fail closed on missing/foreign/tampered lineage.

## R2 attack matrix: all other requested attacks passed

- Candidate/source/input mismatch: `conflict`, terminal deferred,
  `no_publish=true`.
- Unknown root/package/receipt fields: rejected or invalid/conflict,
  `no_publish=true`.
- `authority_verified=false` at root/package/receipt: typed absence, terminal,
  `no_publish=true`.
- Arbitrary package names: responsibility-set mismatch, conflict,
  `no_publish=true`.
- Typed absence: remains terminal and non-publishable.
- Sequence 2/99 at fresh intake and direct aggregate: invalid order.
- Uppercase/non-64-hex fingerprint and wrong domain: invalid and no-publish.
- Duplicate list receipt IDs and duplicate JSON keys: conflict/error, no-publish.
- Reversed responsibility map: canonical output/hash equal.
- Injected claims: rejected as unknown; no gate credit or AD.
- Changed input: `intake_changed`, terminal, no automatic AD.

