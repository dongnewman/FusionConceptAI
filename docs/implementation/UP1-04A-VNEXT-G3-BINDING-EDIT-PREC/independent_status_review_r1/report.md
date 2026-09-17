# UP1-04A-VNEXT-G3-BINDING-EDIT-PREC independent status review R1

Date: 2026-09-15  
Reviewer: different Luna/high  
Review mode: independent read-only status review  
Observed HEAD: `4b69f55f7f80240147a65a22809dc1207824dde2`  
Verdict: `pass_limited`

## Review boundary

I read `AGENTS.md`, the v4 README and common contract path, AD-34, AD-36,
the task README and manifest, all six product files, archive r5, the r3
independent review, and the complete status-sync-r1 manifest/report/raw
receipts. Existing archive/review/status evidence was treated as append-only
and was not modified. No Julia, DESC, Gridap or mesh process was present at
the fresh-run precheck.

The task README and manifest accurately state a local
`accepted_limited` software precursor with `claim_ceiling` limited to
contract-only typed absence. The machine node remains
`planned`/`proposal`/`accepted=false`/`review_pending`; the current binding
is `AbsentChildBindingV1` with `authority_recheck_not_published`,
`terminal_deferred`, and `actual_binding_authority=false`. The task manifest
and parent goal continue to report actual, T0, T1, T2, provider, mesh,
engineering, physical, search, B00, B04 and R01-R10 credits as false.

## Product and provenance checks

The four frozen code products match archive r5 and the status-sync-r1
manifest byte-for-byte: source `a989b336f1607d69746c94f4636daad2225932fcc0192c2b6476feb6a7a7e0f4`
(24578 bytes), focused test
`3db401be2f529f7d2a4b98fa42380b2964805d87ae3b85a57b1cc506fb7bf24b`
(11729 bytes), fixture
`1c52682d1cb3844646d1301337e2995c0ed308ca5cdae1ce04428b86699d0b75`
(793 bytes), and static QA
`d8ef7467209162d7e20286a8433691b00c16c881ee02fed8df79be836c4dd266`
(2730 bytes). The README and manifest are the two status-sync product
documents; their current hashes are recorded in `product_hashes.json` and
match the current status-sync-r1 manifest. The older r5 document hashes are
historical and were superseded by the status-sync-r1 state update; no source,
test, fixture or static-QA product was changed.

The exact product count remains six. Evidence sidecars are under this task's
archive/review/status roots, are evidence-only and append-only under AD-36,
and do not smuggle source, tests, fixtures, static QA, launchers or product
deliverables. Existing r0-r5 archive rounds, independent reviews r1-r3,
status-sync-r1 and the malformed-probe failure are preserved. The review's
cleanup inventory reports no removals and no ambiguous cleanup.

## Fresh software evidence

The direct static-QA command exited `0` and printed `PASS` at
`2026-09-15T08:01:22.8451269Z`–`08:01:22.9628530Z`. The direct focused Julia
command exited `0` with `70/70` at
`2026-09-15T08:01:34.6152248Z`–`08:01:50.4617223Z`. The module-qualified
direct present-constructor probe exited `0` after asserting
`ArgumentError: binding_authority_typed_absent` at
`2026-09-15T08:02:01.7858046Z`–`08:02:03.7623669Z`. The desktop execution
wrapper did not expose child PIDs; all three review receipts record this as
`unavailable_by_desktop_exec_wrapper`, with no PID invented. Raw stdout and
stderr are retained in this review directory.

The focused run confirms typed absence, compatibility `complete=true`, the
legacy `:actual` terminal-deferred projection, fail-closed pairing cases, and
atomic disabled-CAS failures. The direct probe confirms caller-supplied
present construction remains rejected. These are local software-contract
facts and do not establish checked-present authority, a physical realization,
or any parent-goal credit.

The scoped JSON/path/hash check exited `0` with `CHECKS=PASS`. This review
did not modify the source, test, fixture, static-QA product, core planning,
registry, old evidence, or any other agent's files.

## Decision

`pass_limited`: the current status synchronization is accurate for the local
typed-absence software precursor and preserves the required evidence and
claim ceiling. It does not promote the machine node or any actual/T0/T1/T2,
provider, mesh, engineering, physical, search, B00, B04 or R01-R10 result.
The checked-present authority recheck and same-candidate upstream source
children remain open gates.
