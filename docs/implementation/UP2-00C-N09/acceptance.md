# UP2-00C N09 provider-gap projection

Status: `accepted_limited`
Accepted: `true`
Accepted scope: `actual_a_five_provider_match_declarations_and_11_changing_provider_gap_mutations`
Claim ceiling: `contract_only`

Sol accepts this slice after an independent Luna/high r2 review returned `pass_limited`. The accepted evidence is limited to five provider_match declarations projected from the actual CandidateStatePackageV5 and eleven fixture-driven mutations whose provider_match values actually changed. The declarations are the G1 operator, G2 grammar, G2 exterior, G3 realization, and G3 control entries. Each carries candidate/ref/hash provenance and a stable source path/type. Actual baselines are G1 operator `unique_match`, G2 grammar/exterior `unique_match`, and G3 realization/control `no_match`.

The accepted mutation evidence reports 11 changing rows, 144/144 mutation assertions, 24/24 source projection checks, and 2/2 metadata checks. The corrected r2 run has PID 19840, exit `0`, stdout SHA256 `82402c8b44f12ab573e2c0478ecc739f6cc043b3526b7ead5e83659506d750b9`, empty stderr, and no remaining Julia/DESC process. The author r1 baseline mismatch remains preserved with exact exit `unknown` and `program_exception`; it was not inferred from stderr or overwritten. The independent r2 review used PID 63304, exit `0`, stdout SHA256 `215ade810de1e20918d6283a5938155206a3a485b84e5d85e69e584d81d63d0f`, and no remaining process.

The low-level N09 constructor is outside the accepted provenance scope. The fixed provider_match/terminal_deferred oracle domain and the absence of an expected_error reversal control do not receive general classification or B04 credit. No provider is resolved, no prior evidence or receipt is reused, and compile/provider/solver invocation counts remain zero.

B04, provider execution or resolution, mesh, engineering, physical, and R01-R10 claims remain false. This record does not accept UP2-00 as a whole.

Acceptance record: `docs/implementation/UP2-00C-N09/acceptance.md`
Evidence manifest: `docs/implementation/UP2-00C-N09/evidence_manifest.json`
Independent review: `docs/implementation/UP2-00C-N09/independent_review_r2/report.md`
