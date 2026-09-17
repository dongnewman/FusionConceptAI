# Stable cleanup inventory R1

Captured at `2026-09-15T04:32:13.8384524Z` after the final receipt list was fixed in `manifest.json`. The machine readable inventory is [cleanup_inventory_stable_r1.json](cleanup_inventory_stable_r1.json).

The owned set contains the four dispatched source/test/fixture/static-QA files and every existing file in this work order's implementation archive. Each entry records its exact byte length, SHA-256, UTC modification time, and `kept` disposition. The current manifest is included explicitly: 6096 bytes, SHA-256 `67ace1b6cca32076d52df3685b3b5a1c3a4c659d65897be7de578545370b1812`.

No scratch, cache, unrelated code, or attributable temporary file was found. Nothing was removed or deferred. Existing dirty work, historical run and cleanup receipts, raw evidence, and protected PIDs 65224 and 58068 were preserved. PID 66044 had already exited; the prior process evidence records that no termination was issued.

The manifest SHA before adding the stable receipt pointers was `2d2be77961f34e0d1601b25c1fac37763ed23846f71c86dbcaaddae8f6a784e4`; after the pointer update and before this inventory capture it was `67ace1b6cca32076d52df3685b3b5a1c3a4c659d65897be7de578545370b1812`. The stable JSON and this explanatory report are excluded from the owned-set hash calculation to avoid self-reference, and the manifest's `manifest_self_hash` field remains explicitly excluded.
