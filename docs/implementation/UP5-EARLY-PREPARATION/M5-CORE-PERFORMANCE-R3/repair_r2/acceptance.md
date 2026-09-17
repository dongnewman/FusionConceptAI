# Repair R2 acceptance record

Status: `superseded_by_repair_r3 / screen_only / performance implementation pending runtime`.

Static closure performed:

1. Four core source files retain the legacy one-argument canonical writers and
   historical field order.
2. The former shadow-seal design is not an authority boundary under hostile
   same-module reflection.  Current acceptance requires the repair_r3
   canonical-output revalidation path.
3. Cached trace/provenance fragments validate their digest against sealed bytes
   and preserve orientation, coordinates, condition-chain, and replay checks.
4. The focused test contains cold/hot receipt comparisons, query/replay checks,
   mutation and forged-hash negatives, forced digest-collision witnesses, and
   insertion-order-independent sorted projection checks.

Commands allowed in this lane and completed:

```text
git diff --check
Python static source/allowlist inspection (no Julia invocation)
```

Julia execution, frozen byte/hash comparison against the HEAD baseline,
fresh-process determinism, and performance measurement remain parent-owned
serial-lane work.  Any runtime exception or byte/hash mismatch is
`terminal_deferred`/`fail_closed`, not a performance acceptance.
