# Repair R1 failure history

This append-only sidecar records one repair-local static check failure. The
first post-repair static QA asserted the literal `complete=true` in the source
file, while that compatibility call is exercised in the owned Julia test. The
static QA was corrected to inspect the source and owned test together. No
product scope or prior r0-r3 evidence was overwritten.

The focused Julia run after the repair passed 69/69. The final r4 receipt
contains the direct Python and Julia raw streams and their SHA256 values.
