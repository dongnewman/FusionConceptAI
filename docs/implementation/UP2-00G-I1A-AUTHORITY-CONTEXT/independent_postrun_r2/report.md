# G-I1A focused_r2 independent postrun audit

Verdict: `pass_limited`.

This independent postrun audit accepts only the bounded G-I1A contract and
software-test evidence produced by the serialized `focused_r2` run. It does
not accept implementation completion, UP2 total, B00/B04, provider, mesh,
engineering, physical, or R01-R10 evidence. All such credits remain false.

The repository was at HEAD
`4b69f55f7f80240147a65a22809dc1207824dde2` with 292 dirty-status lines. The
focused input transcript names the same HEAD and all 11 current input files
were independently rehashed with matching byte counts and SHA-256 values.
The four protected files (G-I1A source, fixture, test, and runner) also match
their before and after hashes. No source/test/core file was changed by the
run; unrelated dirty worktree content was preserved.

The real serialized process receipt is internally coherent: command
`julia --startup-file=no --project=. test/GenomeV5/UP2/run_gi1_authority_context.jl`,
PID `88464`, UTC `2026-09-14T08:01:43.4775914Z` through
`2026-09-14T08:04:41.9573335Z`, exit code `0`, stdout 4896 bytes and stderr 0
bytes. Independent hashes are stdout
`C82E92F2E46AB52E7B8B55E4E9C0D41F03CEFB367B298DE3B013498FB42AB27C` and empty
stderr `E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855`.
The raw stdout contains the G1/G2/G3 repeated child-fixture groups and the
four G-I1A groups: 30/30 typed authority, 19/19 constructor/N06 boundary,
10/10 absent slots, and 20/20 tamper controls, totaling 79/79. The receipt
also records G1 47/47 core plus 21/21 negative, G2 57/57 legal plus 59/59
negative plus 8/8 boundary, and G3 49/49 identity plus 35/35 resource plus
23/23 references. stderr is empty.

The actual-A E1-present/E2-absent path is source-bound in the test: the test
constructs candidate `fusionconceptai://candidate/gi1-a`, builds G1/G2/G3,
derives E0 with `up2_candidate_physical_binding_from_a`, creates an N05
declaration/authority, and calls `gi1_authority_context_from_a` with N05 and
no N06 (`test/GenomeV5/UP2/gi1_authority_context_tests.jl:18-58,93-95,110-148`).
The assertions check candidate, package/component refs and hashes, E0
identity, typed E1 present and E2 absent slots, E2 missing-authority reason,
terminal-deferred contract/physical status, identity hash, trusted source
binding, and zero compile/provider/solver counters. The implementation
records slot provenance as `actual_A_E0`, preserves typed absent content and
its schema/canonical/profile/projection hashes, and derives E2 absence through
`n06_mapping_admission` (`src/GenomeV5/UP2/GI1AuthorityContextV1.jl:389-417`).

The actual-A both-absent path constructs candidate
`fusionconceptai://candidate/gi1-b`, derives the same E0 binding, omits N05 and
N06, and verifies both typed absent E1/E2 slots, independently recomputed slot
hashes, valid schema/trusted validation, and terminal-deferred contract status
(`gi1_authority_context_tests.jl:236-251`). The factory source-binds the
package refs and component hashes in the same context body; this test's direct
assertions focus on the two absence slots and their identity. This is absence
evidence only and does not imply a physical law.

The typed E2-present/deferred branch is synthetic schema/admission coverage
only. The test creates a candidate/E0-bound `N06SourceFieldLedgerMappingV1`,
wraps it with `_gi1_make_n06_present`, and checks the shared
`_gi1_overall_admission` outcomes for deferred and consistent inputs
(`gi1_authority_context_tests.jl:161-180`). It does not claim source-backed
N06 physical authority. The implementation retains the typed mapping and its
mapping/content/schema/canonical/profile hashes even for terminal-deferred
admission (`GI1AuthorityContextV1.jl:210-224,419-437`).

Dynamic taxonomy coverage is present. A trusted N05 authority rebuilt with
`:program_exception` reaches `gi1_validate_authority_context` and returns
program_exception with all downstream counters zero; constructor controls
cover valid and fail-closed branches, missing errors, and invalid N06 mapping
(`gi1_authority_context_tests.jl:150-233`). Source validation maps unexpected
non-ArgumentError faults to `GI1ProgramException`, while structural source
contradictions remain fail-closed (`GI1AuthorityContextV1.jl:52-60,440-463,495-536`).

R6's old API repair is present in the executed input: the test uses
`G.G1GenomeContractRefV2` at line 22, the independent stale-token scan found
zero owned matches, and the current source/fixture/test/runner hashes match
focused_r2 and the R6 static precheck. The immutable focused_r1 evidence is a
real exit-1 LoadError caused by `UndefVarError: G1GenomeContractRef`; focused_r2
reaches and passes all G-I1A groups, so runner exit is supported by test-group
stdout and source-bound assertions rather than used as sole evidence.

R5 and R6 were read as static prechecks with `ready_for_serial_focused` and
runtime pending; their protected hashes and coverage claims are preserved.
AD-26 is `accepted_limited` for architecture/evidence protocol only. AD-27's
decision boundary is `accepted_limited` for architecture only, while its
implementation/runtime evidence remains proposal-only and not run. Both
retain the contract-admission/physical-resolution separation and no physical
or parent-goal credit.

Postflight evidence records an empty Julia/DESC process sweep. The independent
sweep also found no Julia/DESC process. JSON parsing, stale-token scan,
`validate_plan.py`, and `git diff --check` passed; the latter emitted only
pre-existing line-ending warnings. The planning validator is recorded as
planning QA, not as physics or implementation acceptance.

Exact scope of this verdict: one real serialized focused_r2 Julia process,
its raw process/stdout/stderr/receipt/QA/postflight evidence, independent
hash reconstruction, and the source/test paths cited above. No Julia or DESC
process was started by this audit, and no existing file outside this new
`independent_postrun_r2` directory was modified.
