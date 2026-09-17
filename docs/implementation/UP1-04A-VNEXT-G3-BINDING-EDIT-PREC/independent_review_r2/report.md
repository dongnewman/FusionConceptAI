# UP1-04A-VNEXT-G3-BINDING-EDIT-PREC independent review R2

Date: 2026-09-15
Reviewer: different Luna/high
Review mode: independent read-only review; repair R1 and prior evidence were not modified
Observed HEAD: `4b69f55f7f80240147a65a22809dc1207824dde2`
Verdict: `changes_requested`

## Scope and execution

I re-read the current v4 contract path, AD-34 R4, AD-36, the six current
product files, repair R1, archive rounds r0-r4, independent review R1, and the
G3 SourceFeedback V1 contract. Before execution there were no Julia, DESC,
Gridap or mesh processes. Existing unrelated work was preserved.

The direct static QA command passed with exit `0` (PID 68812,
2026-09-15T07:36:45.1893087Z–07:36:46.2255119Z). The direct focused Julia
command passed `69/69` with exit `0` (PID 67896,
2026-09-15T07:36:54.8935196Z–07:37:10.9325724Z). The interpreter identities
were Python 3.13.5 at `D:\\Users\\Newman\\anaconda3\\python.exe` and Julia
1.10.5 at `C:\\Users\\Newman\\AppData\\Local\\Programs\\Julia-1.10.5\\bin\\julia.exe`.
The captured outputs and direct probes are in
`archive/independent_review_r2/`.

The focused 69-test result confirms the repair R1 claims for the public factory:
caller-supplied present slots are rejected with
`ArgumentError("binding_authority_typed_absent")`; `complete=true` still
produces typed-absent source provenance and child slots; paired legacy
`:actual` reports `reason == "legacy_actual_without_declaration_authority"`
with `:typed_absent` and `:terminal_deferred`. The three disabled CAS
operations remain fail-atomic, and the existing G1/G2 duplicate, missing,
unknown, candidate, target-key, stale and contradictory negatives remain
covered.

The current six product files match archive/r4's hashes and remain exactly the
manifest's six paths. Archive r0-r4 and independent review R1 are still
present; the r4 cleanup inventory reports 35 retained paths, no removed paths,
no ambiguous cleanup, and no broad cleanup. No core, registry, T0, T1, T2,
provider, mesh, launcher, or physical file was changed by this review.

## Blocking finding

The R1 repair only closes admission through the payload constructor and the
factory. The exported `PresentChildBindingV1` constructor itself still accepts
fabricated values without any authority or source receipt. A fresh direct Julia
probe constructed
`PresentChildBindingV1(:realization, QualifiedRefV1("fake-child", "v1"),
GenomeContractRef("urn:fake", ...), identity_hash, state_hash)` and printed
`PresentChildBindingV1` with exit `0`.

This remains inconsistent with the requested R2 gate that fabricated
`PresentChildBindingV1` be rejected in both constructor and factory, and with
AD-34 R4's statement that the current precursor “cannot construct
`PresentChildBindingV1`” before checked-present T0 authority. The factory probe
does reject the same slot with the deterministic
`binding_authority_typed_absent` error, so the gap is specifically the public
present-slot value constructor.

This is a software-contract finding only. It does not create present authority
or any physical evidence, and all actual/T0/T1/T2/provider/mesh/engineering/
physical/search/B00/B04/R01-R10 credits remain false.

## Required repair

The implementer must close or quarantine the exported present-slot constructor
until a checked-present authority path exists. The current six-file precursor
must retain only typed absence and deterministic fail-closed admission. Add an
owned negative test that directly invokes the present-slot constructor and
asserts the agreed error, then rerun the existing 69-test suite and the static
QA. Preserve the R1/R2 history and all prior raw receipts append-only.

Until that repair receives a further independent review, the task remains
`accepted=false`, `review_pending`, and limited to the typed-absence software
ceiling.

