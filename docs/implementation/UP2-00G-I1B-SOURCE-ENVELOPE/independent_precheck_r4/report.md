# G-I1B-A independent static precheck R4

Verdict: `changes_requested`.

This is an independent Luna/high static review of repair R4. Julia, DESC,
compiler, provider, solver, mesh, and physical processes were not started.
The freeze is HEAD `4b69f55f7f80240147a65a22809dc1207824dde2`, branch `main`,
with 3427 current dirty porcelain entries, status snapshot SHA256
`abca186d32edbd1f9b29cfb427cf67661ca4a838cf2ceff6b037dbf732ee9f3a`, and
zero matching Julia/DESC processes. Only this R4 review directory was written.
The result carries no B00, B04, physical, engineering, provider, mesh, or
parent-goal credit.

R4 closes the three R3 static gaps. The ordinary E1-present/E2-absent and
E1-absent/E2-absent factory calls now assert row and envelope downstream
counters are zero. The test-only expected attempted manifest derives typed
attempted values from independently read source originals and frozen mutation
rules, then independently recomputes original, attempted, and mutation hashes
without using production `_gi1b_attempt`, `_gi1b_hash_typed`, or the production
mutation assembly helper. The factory fault injection checks a real
`program_exception` row, aggregate precedence, retained exception and
fail-closed error entries, and zero counters. N05 E1 absence metadata and the
N06/N09/N10 gap classifications remain asserted.

## Blocking finding

### GI1B-R4-01 — public factory accepts an arbitrary row builder (P1)

`src/GenomeV5/UP2/GI1BSourceMutationEnvelopeV1.jl:618-626` exposes
`row_builder::Function` as a keyword on the public
`gi1b_source_mutation_envelope` entry point. `_gi1b_build_rows` trusts each
returned row (`:589-595`), while `_gi1b_assemble_envelope` only assembles the
rows and checks aggregate fields (`:597-616`); it does not re-read actual
source values or validate each returned row against its spec, source locator,
typed original, attempted value, source identity, or hashes. A caller can
therefore provide 50 fabricated `GI1BMutationEnvelopeRowV1` values with valid
outer shape and bypass source-derived classification, identity, and hashes.
The current test at `test/GenomeV5/UP2/gi1b_source_envelope_tests.jl:306-321`
proves controlled fault capture through the same public seam, but also
demonstrates that this production bypass remains callable.

Move fault injection to an internal/test-only helper, for example
`_gi1b_source_mutation_envelope_with_row_builder`, and keep the public factory
fixed to `_gi1b_row`; or make the public path reject non-default builders and
independently validate every supplied row against actual source access before
assembly. Preserve the controlled exception test through the internal helper.

## Static QA and freeze

The fixture has 50 unique rows and five rows per N01-N10 group. JSON parsing,
repair R4 static QA, planning validation, targeted diff checks, source-only
routing scans, and the zero matching-process sweep passed. The protected
current hashes are recorded in `evidence_manifest.json`; the prior full R3
inventory remains referenced there. The verdict is limited to source/fixture/
test/runner static review and does not establish formal B04 or physical
readiness. A focused serial Julia run remains pending until the public seam is
closed.

