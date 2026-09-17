# M5 core performance R3 repair R6

R6 is a minimal focused-test repair after the R5 diagnostic failure.  The
proposal identity mutation and proposal sort-key mutation negatives now use
two independent fresh `_CEGDerivationCacheV1` instances, so the first
intentional corruption cannot poison the setup for the second assertion.
Product sources and test intent are unchanged.

The referenced diagnostic reported `18 passed, 0 failed, 1 errored` because
the sort-key setup reused the deliberately corrupted proposal-identity cache.
Julia is not run in this lane; the next diagnostic is parent-owned.

Status remains `screen_only / performance implementation pending runtime`.
