# UP1 external-blocker closure R4 — G2 repair independent retest

This directory contains an independent, black-box retest of the already
repaired G2 mapping implementation.  The implementation under
`tools/up1_external_closure_r4/g2_mapping/` and the existing tests under
`test/up1_external_closure_r4/g2_mapping/` were frozen and not edited by this
retest.  The prior `07-g2-independent-test` evidence was also retained and
hash-recorded.

The capture command was run from the `FusionConceptAI` checkout:

```text
python -B docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R4/10-g2-repair-independent-retest/capture_retest.py
```

It runs the existing serial unit-plus-adversarial lane twice, in order.  See
`capture_manifest.json` for semantic assertions and `raw/` for stdout,
stderr, PID, UTC, exit, and SHA-256 receipts.
