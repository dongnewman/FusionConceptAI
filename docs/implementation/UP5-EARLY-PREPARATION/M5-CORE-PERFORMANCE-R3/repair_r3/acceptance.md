# Repair R3 acceptance record

Status: `screen_only / performance implementation pending runtime`.

Static closure:

1. The focused test no longer accesses removed `program_bytes`, hash, or
   shadow fields.  It exercises the current `canonical.entries` and helper
   APIs.
2. Cache hints have no authority.  Current canonical bytes/hash are regenerated
   by authoritative receipt writers; injected same-digest/different-bytes
   entries fail at that boundary.
3. Every conditional cache hit has structural/current-key validation, and
   guarded trace/provenance fragments bind owner tokens and verify rule bytes,
   rule hash, and rule reference.
4. A two-process fresh-process harness plan is recorded in
   `fresh_process_plan.md`; it was not executed in this no-Julia worker lane.

Allowed checks completed:

```text
git diff --check
JSON parse of repair_r3/evidence_manifest.json
static allowlist/source scans (no Julia invocation)
```

This repair does not claim frozen HEAD equivalence, query/replay runtime
success, speed, allocation reduction, factorial-root-cause resolution, or
formal DAG/stage credit.
