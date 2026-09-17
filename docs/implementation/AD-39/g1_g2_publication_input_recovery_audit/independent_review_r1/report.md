# AD-39 G1/G2 publication input recovery audit — independent review R1

Date: 2026-09-15  
Reviewer: different Luna/high, read-only  
Verdict: `changes_requested`

## Scope and basis

This review independently rechecks the AD-39 read-only audit and its two
proposed publication work orders against the current repository, the v4
README, the common contract, the orchestration/work-order rules, AD-36 and
AD-37, and the cited G1/G2 source, tests, fixtures and integration seams.
The reviewed AD-39 files and all prior records remain unchanged. This review
does not run Julia, DESC, provider, mesh, solver or physical execution.

The current HEAD is `4b69f55f7f80240147a65a22809dc1207824dde2`, matching the
AD-39 observed head. The audit's core source hashes still match. The only
audited-input hash entry that fails the recorded byte-count check is
`docs/implementation/AD-36/manifest.json`: AD-39 records 6021 bytes, while
the current file has 5928 bytes; the recorded SHA-256 is unchanged.

## Findings

1. **The frozen AD-39 input receipt is internally inconsistent.** The AD-36
   manifest entry has a byte-count mismatch. Its hash matches, so this is a
   receipt metadata defect rather than evidence of a source-content change,
   but the audit's advertised input/hash/size recheck is not fully reproducible.

2. **The AD-36 state recorded by AD-39 and AD-37 is stale.** The current
   `docs/implementation/AD-36/manifest.json` is
   `status=accepted_limited`, `accepted=true`, with scope
   `mandatory_evidence_sidecar_scope_contract_only`. AD-39 still says the
   policy is `review_pending/accepted=false` and uses that statement to explain
   why no evidence sidecar was created. AD-37 repair R2 also retains the old
   AD-36 status and old AD-36 acceptance/manifest hashes. Fresh publication
   inputs are still absent, so the publication work orders remain blocked, but
   their current blocker must distinguish the accepted sidecar contract from
   the missing external source/binding/provenance/receipt inputs.

3. **The AD-39 work-order records do not make ownership exact enough for
   dispatch.** They enumerate product paths and the required input classes,
   but they do not carry a `semantic_owner` or an input-owner/path mapping.
   Their `required_fresh_inputs` use abstract `input/...` paths rather than
   the canonical AD-37 work-order input paths. Add explicit G1/G2 semantic
   ownership and exact owner/path records for every fresh input producer before
   dispatch. This is a contract-boundary repair; it must not create the future
   publication directories or source-backed records.

## Independent positive findings

The source and call-site audit supports AD-39's central absence conclusion.
G1 has a typed source payload, declaration constructor and contract receipt,
but its current construction call sites are the focused synthetic test and the
source definition; its authority check remains `terminal_deferred`.
G2 has typed source/declaration/receipt constructors and a separate mapping
type in `VNextDeclarationTransportV1`, but the mapping occurrences are
synthetic transport tests and no fresh mapping receipt is present. The G2
fixture remains `contract_only`, `not_executed`, with `no_match` mesh and
boundary authority.

The parent binding seam rejects fixture/ref-only/synthetic admission and its
public `admit_present_parent` paths still end in
`source_backed_receipt_unavailable`. The current checkout has no non-fixture
source bytes/source record, fresh candidate binding, four-axis source
attestation, source-backed factory/declaration receipt or fresh identity
review. The G1/G2 publication output directories and all listed future product
paths are absent. No fixture, synthetic value, legacy receipt, or mapping type
was promoted to authority.

The proposed work orders otherwise preserve the three-way result union, eight
hash fields, four provenance axes, typed absence plus `terminal_deferred`,
`fail_closed` contradiction handling, `program_exception`, 14-file product
scope, sibling separation, forbidden T0/authority-recheck/T1/T2 edges, direct
command policy and task-owned cleanup. The G2 mesh/boundary capability gap is
kept separate. No candidate hash was created, no machine node was added, and
present, T0, T1, T2, provider, mesh, solver, engineering, physical, search,
B00, B04 and R01–R10 credits remain false.

## Required repair and exit decision

Create an append-only AD-39 repair round that freezes the current AD-36
accepted-limited manifest/acceptance hashes and byte counts, updates the AD-36
blocker wording, and replaces the abstract fresh-input paths with explicit
canonical owner/path records. Re-run JSON, hash, path, API, control-character
and diff-scope checks with a raw PID/UTC/exit receipt under the task-owned
review or status sidecar. Preserve this original audit, its inline receipt,
and all prior evidence byte-for-byte.

Until that repair is independently reviewed, AD-39 is `changes_requested`.
Even after a passing repair, its scope can accept only the static absence audit
and finite future work-order boundary. It cannot authorize present G1/G2
publication, source-backed authority, T0/T1/T2, UP2, physical execution or
any R01–R10 credit.
