# UP1-04A-VNEXT-G3-BINDING-EDIT-PREC independent review R3

Date: 2026-09-15
Reviewer: different Luna/high
Review mode: independent read-only review; repair R2 and prior evidence were not modified
Observed HEAD: `4b69f55f7f80240147a65a22809dc1207824dde2`
Verdict: `pass_limited`

## Scope and execution

I re-read the current v4 contract path, AD-34 R4, AD-36, the six product
files, repair R2, archive rounds r0-r5, independent reviews R1-R2, and the G3
SourceFeedback V1 contract. Before execution there were no Julia, DESC, Gridap
or mesh processes. The unrelated Python process was preserved.

The direct static QA command passed with exit `0` (PID 71560,
2026-09-15T07:49:03.2696698Z–07:49:04.3064457Z). The direct focused Julia
command passed `70/70` with exit `0` (PID 78388,
2026-09-15T07:49:14.2672523Z–07:49:28.3014778Z). The interpreter identities
were Python 3.13.5 at `D:\\Users\\Newman\\anaconda3\\python.exe` and Julia
1.10.5 at `C:\\Users\\Newman\\AppData\\Local\\Programs\\Julia-1.10.5\\bin\\julia.exe`.
The captured outputs and the module-qualified direct constructor probe are in
`archive/independent_review_r3/`. The probe was run directly; its PID was not
exposed by the desktop wrapper and is recorded as unavailable rather than
invented.

## Contract checks

The module-qualified direct call
`FusionConceptAI.PresentChildBindingV1(:realization, valid_ref, valid_contract,
identity_hash, state_hash)` now deterministically throws
`ArgumentError: binding_authority_typed_absent` and exits `0` under the probe's
assertion. There is no generated public constructor path that bypasses the
inner rejecting constructor. The factory independently rejects caller-supplied
present slots with the same typed-absence error.

The 70-test focused run confirms that `complete=true` remains compatibility
only and yields typed-absent provenance and child slots; the legacy `:actual`
projection remains `:typed_absent`/`:terminal_deferred` with exact reason
`legacy_actual_without_declaration_authority`; and `insert_link`,
`replace_link`, and `delete_link` preserve canonical bytes, history, receipts
and all hash layers on disabled CAS failure. G1/G2 exact-one pairing,
duplicate/unknown/mismatch, stale and contradictory fail-closed cases remain
covered.

The six current product files remain exactly the six manifest paths and match
archive/r5's final artifact hashes:

| path | SHA-256 | bytes |
|---|---|---:|
| `src/GenomeV5/G3/G3BindingChildEditabilityV1.jl` | `a989b336f1607d69746c94f4636daad2225932fcc0192c2b6476feb6a7a7e0f4` | 24578 |
| `test/GenomeV5/G3/g3_binding_child_editability_v1_tests.jl` | `3db401be2f529f7d2a4b98fa42380b2964805d87ae3b85a57b1cc506fb7bf24b` | 11729 |
| `test/GenomeV5/G3/g3_binding_child_editability_v1_fixture.json` | `1c52682d1cb3844646d1301337e2995c0ed308ca5cdae1ce04428b86699d0b75` | 793 |
| `test/GenomeV5/G3/static_qa_g3_binding_child_editability_v1.py` | `d8ef7467209162d7e20286a8433691b00c16c881ee02fed8df79be836c4dd266` | 2730 |
| `docs/implementation/UP1-04A-VNEXT-G3-BINDING-EDIT-PREC/README.md` | `6ca26b9bee65c878a562f040c52d02f0132ce77c64445fb4c3232320c2264011` | 1309 |
| `docs/implementation/UP1-04A-VNEXT-G3-BINDING-EDIT-PREC/manifest.json` | `fdb96c866903b02ac8e34dca9320cf07fb1daf49001572b76ca4fc0fde8638d9` | 2510 |

Archive r0-r5 and independent reviews R1-R2 remain append-only. The repair
R2 cleanup inventory retains prior failures and evidence, and this review
created only its own report, manifest and evidence sidecars. No core, registry,
T0, T1, T2, launcher, provider, mesh, engineering or physical file was
modified.

## Acceptance ceiling

`pass_limited` accepts the local typed-absence software precursor and the
repair's constructor/factory fail-closed boundary only. It grants no checked-
present authority, actual binding, feedback, control, T0/T1/T2, provider, mesh,
engineering, physical, search, B00/B04 or R01-R10 credit. The machine task
remains `accepted=false`/`review_pending`; parent-goal R01-R10 status is
unchanged.

