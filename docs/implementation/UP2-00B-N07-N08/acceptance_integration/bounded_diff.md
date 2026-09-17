# Bounded integration change set

- `UP2-00B-N07-N08/acceptance.md`: status changed from review pending to accepted_limited, with the exact ten-row actual-A/current-admitted-G2 scope and preserved limitations.
- `UP2-00B-N07-N08/evidence_manifest.json`: accepted flag/scope and independent r3 provenance added; all B00/B04, UP2-total, mesh, provider, engineering, physical, and R01-R10 fields remain false.
- `docs/implementation/README.md`: one navigation row added.
- `docs/v4_multitopology_generation/README.md`: one limited-scope navigation paragraph added.
- The index edits initially contained PowerShell backtick control-character corruption; `control_char_repair_before.json` preserves those bad-version hashes, and `control_char_repair_after.json` records the literal replacement and zero-control scan.

The before snapshot contains hashes/metadata only; no before bytes were available for a byte-level patch. All source, test, fixture, old run, reviewer archive, core18, and task-manifest files remained outside this write set.
