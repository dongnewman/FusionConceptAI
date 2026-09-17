# UP1-04A-VNEXT-G3-BINDING-EDIT-PREC independent review R1

Date: 2026-09-15
Reviewer: different Luna/high
Review mode: independent read-only review; reviewed product files and prior evidence were not modified
Observed HEAD: `4b69f55f7f80240147a65a22809dc1207824dde2`
Verdict: `changes_requested`

## Scope and evidence

I read `AGENTS.md`, the v4 README, 00, 10, 14, 16, 17 and 18, the task
manifest node, AD-34 repair R4/acceptance, AD-36 acceptance/independent R3,
the six product files, the G3 SourceFeedback V1 contract, and all existing
binding archive rounds r0-r3. Before the focused run, no Julia, DESC, Gridap
or mesh process was present. The unrelated Python process was left running.

The six product paths are exactly the six paths in the task manifest and their
current hashes match the frozen r3 receipt:

| path | SHA-256 | bytes |
|---|---|---:|
| `src/GenomeV5/G3/G3BindingChildEditabilityV1.jl` | `16454897a8f9c0ac7ca2f9af3c0e7ce970a66e33ce6afd39e883ed235e7a0fd5` | 23968 |
| `test/GenomeV5/G3/g3_binding_child_editability_v1_tests.jl` | `ca749fa7d471e0c06e31bba1561306a9036ac16432c0b7e5e7234a2e59c4e67b` | 10076 |
| `test/GenomeV5/G3/g3_binding_child_editability_v1_fixture.json` | `1c52682d1cb3844646d1301337e2995c0ed308ca5cdae1ce04428b86699d0b75` | 793 |
| `test/GenomeV5/G3/static_qa_g3_binding_child_editability_v1.py` | `aea9c89b5bbc63429e043101a02237a6f184b890249bcd3c8ee69cc09eab4f08` | 2408 |
| `docs/implementation/UP1-04A-VNEXT-G3-BINDING-EDIT-PREC/README.md` | `e5c843aef87e49950ae95d7a79e181c415f9cf0827d2ca4aeea44df4e5662ba2` | 1005 |
| `docs/implementation/UP1-04A-VNEXT-G3-BINDING-EDIT-PREC/manifest.json` | `7f0495ae8f80df74beb6c6b35ae11d44edb012ebca34802f64754b60a58a6de8` | 2211 |

The direct static QA command exited `0` with `PASS` (PID 25380,
2026-09-15T07:22:04.9773027Z–07:22:06.0088526Z). The direct focused Julia
command exited `0` with `62/62` tests (PID 61348,
2026-09-15T07:22:15.5773096Z–07:22:30.6050940Z). Julia was
`C:\\Users\\Newman\\AppData\\Local\\Programs\\Julia-1.10.5\\bin\\julia.exe`,
version 1.10.5; Python was `D:\\Users\\Newman\\anaconda3\\python.exe`,
version 3.13.5. The raw captured outputs and supplementary probes are in
`archive/independent_review_r1/`; the earlier r0-r3 evidence remains present.

The implementation has the requested typed source payload, immutable tuple
`initial_links`, editable body, separate source/child/body/source-state/
operation/state hash fields, typed operation digest, typed child union, exact
G1/G2 pairing checks, typed absence, and fail-atomic disabled CAS. Existing
tests cover hash formulas, byte/state identity on all three disabled CAS
operations, exact-one G1/G2 pairing, duplicate/unknown/mismatch negatives,
stale/contradictory fail-closed statuses, and legacy `:actual` remaining
typed absent. No product, core, registry, launcher, T0, T1, T2, provider,
mesh, or physical execution path was changed by this review.

## Blocking findings

1. The current typed-absence scaffold can construct a present child slot
   without a checked-present T0 authority recheck. In
   `G3BindingChildEditabilityV1.jl:170-171`,
   `g3_binding_source_payload_v1` accepts caller-supplied
   `realization_slot`/`control_slot`; the constructor only checks the union
   type. A fresh direct Julia probe passed a fabricated
   `PresentChildBindingV1(:realization, QualifiedRefV1("fake-child", "v1"),
   GenomeContractRef("urn:fake", ...), ...)` and returned a payload with a
   `PresentChildBindingV1` slot, exit `0`. This conflicts with the AD-34 R4
   gate and the task manifest's current-only `AbsentChildBindingV1` scope.

2. The same factory accepts `complete=true` and emits four `:present`
   source-provenance slots whose references are synthetic
   `fusionconceptai://evidence/binding/...` values and whose hashes are derived
   only from slot names. A direct probe returned
   `(:present, :present, :present, :present)`, exit `0`. This can fabricate
   source provenance before a fresh T0-owned receipt exists. The current
   scaffold must not expose a construction path that looks source-backed.

3. AD-34 R4 freezes a legacy status mapping in which a paired `:actual`
   projection returns `:typed_absent`/`:terminal_deferred` with reason
   `legacy_actual_without_declaration_authority`. The implementation's
   `g3_binding_pairing_v1` only checks stale and contradictory statuses before
   returning the successful typed-absent result (`:154-163`); an exact paired
   `:actual` case returns an empty error tuple. It therefore preserves the
   typed-absence ceiling, but does not emit the frozen deterministic reason.

The first two findings are implementation-contract blockers, despite the
focused test pass. The current tests do not exercise present-slot injection,
`complete=true`, or the required legacy-actual reason.

## Required repair and re-review gate

The implementer should make the current factory unconditionally typed absent,
or require a future checked-present authority object that is outside this
precursor's current admission path. `complete=true` must be removed or fail
closed until that future authority exists; synthetic slot-name hashes must not
be accepted as source evidence. Add direct negative tests showing that
present-slot injection and `complete=true` are rejected and that all existing
absent/CAS fail-atomic hashes remain unchanged. Add the deterministic
`legacy_actual_without_declaration_authority` error while retaining
`legacy_actual` as non-authoritative.

Until a repair and a new independent review pass, this task remains
`implemented_pending_independent_review`, `accepted=false`,
`contract_only_typed_absence_scaffold`, and `review_pending`. This review
grants no actual binding, feedback, control, T0/T1/T2, provider, mesh,
engineering, physical, search, B00/B04, or R01-R10 credit.

