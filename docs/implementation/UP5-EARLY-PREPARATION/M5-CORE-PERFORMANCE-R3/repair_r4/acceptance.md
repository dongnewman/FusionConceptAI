# Repair R4 acceptance record

Status: `screen_only / performance implementation pending runtime`.

Static closure:

1. Rule cache hits compare the hint with current canonical rule bytes and
   current rule identity before returning it.
2. Saturation proposal matching, deduplication, winner selection, and
   provenance source/target hashes use current canonical program/rule bytes;
   cache content cannot choose a different winner without being rejected.
3. Cache-aware derivation and query receipt emission passes the current rewrite
   set/source root and validates every trace step against that authority before
   bytes are emitted.
4. Focused tests include forged same-fingerprint rule entries, winner-key
   injection, foreign-rule traces, cross-rule provenance, and final receipt
   rejection.

No Julia process was started.  The two-process fresh-process plan remains
deferred to a parent-owned runner.  Any runtime exception, byte/hash mismatch,
trace authority mismatch, timeout, or missing probe artifact is
`terminal_deferred`/`fail_closed`.
