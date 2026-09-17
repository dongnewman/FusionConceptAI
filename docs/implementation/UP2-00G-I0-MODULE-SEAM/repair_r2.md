# G-I0 repair R2 provenance

The independent R1 review requested two executable behavior checks. R2 adds
them without changing the loader source: `run_up2_module_entry.jl` manually
includes the real `PrecompilerInvocationCounterV1.jl` before the shared entry,
then asserts that the exact preloaded type identity is reused after loading
all UP2 definitions and after the second idempotent call. A separate fresh
process probe supplies the correct G1/G2/G3 order and a no-op component loader;
the real counter definition is included, then the next real contract include
fails because its base types are intentionally absent. The probe asserts the
first exception, the partial sentinel, terminal `:failed` state, and same
process retry refusal with the documented fresh-process message.

The existing loader source already sets `:failed` in its catch and rejects a
retry before any include. No source change was needed. The counter checks in
the shared test remain explicitly limited to constructor/static wiring; they
are not a downstream spy and provide no execution evidence.

`repair_r2_before.json` records the prewrite hashes and mtimes available before
the core-note/archive update. The original G-I0 `prewrite_snapshot.json`,
`after_snapshot.json`, and independent R1 archive remain unchanged. The new
`repair_r2_after.json` records current bytes after this repair. Because the
focused runtime is still blocked behind E1/E2 freeze and Sol's serial gate,
R2 remains `review_pending` and `accepted=false`.

Static validation only: `python docs/v4_multitopology_generation/validate_plan.py`
must pass; JSON parsing, control scan and protected unrelated-file checks are
required. Julia/DESC are not run by this repair.
