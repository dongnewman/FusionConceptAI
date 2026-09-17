# M5 core performance R3 repair R10

R10 removes an invalid test assumption about immutable Julia values.  A
separately constructed `WholeProgramConditionalRewriteV1` with equal fields
may be treated as identical by `===`; it is not a valid way to assert
non-identical identity for an immutable cache key.

The focused test no longer constructs or asserts an equal/non-identical rule.
It retains the authoritative receipt invariant: forged `rule_bytes` hints
(including a real artifact-owned key and a different-rule-ref key) do not
change `_ceg_attempt_bytes`, while direct `_ceg_cached_rule_bytes` forged-read
negatives still reject.

No product code was changed.  Julia/DESC is not run in this lane.  Status
remains `screen_only / performance implementation pending runtime`; factorial
root cause remains unresolved.
