# M5 core performance R3 repair R4

Repair R4 closes the independent R3 authority findings without running Julia.
The cache remains an unexported, derivation-local performance hint and never
selects a proposal or supplies final receipt authority.

Changes:

- Rule cache hits re-canonicalize the current rule and cross-check current
  rule bytes, rule reference and stored side hashes; a same-fingerprint forged
  entry is rejected.
- Proposal source/target/rule identity and winner ordering use current AST,
  current rule, and current condition canonical material.  Cache maps are only
  accepted after that revalidation.
- Authority receipt writing (derivation and query receipts) receives the
  current rewrite set and source root. Each member provenance trace is checked
  against the current rule reference, rule hash, orientation, source/target
  hash chain, conditions, owner, and current target before emission.
- Focused negatives cover same-fingerprint forged rules, forged winner keys,
  foreign trace rules, cross-rule/provenance injection, and final receipt
  rejection of a forged rule-cache entry.

The tradeoff is explicit: current-rule validation leaves the exact factorial
`_tac_permutations` search, and may retain canonicalization cost in proposal
loops.  No factorial-root-cause, runtime, allocation, speed, or formal credit
claim is made.  Status remains `screen_only / performance implementation
pending runtime`.
