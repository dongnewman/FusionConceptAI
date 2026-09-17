# UP1-04A additive V5 shared entry

`status: accepted` (`accepted_limited`) and `accepted: true`. The accepted scope is
`additive_v5_shared_entry_and_structural_same_candidate_join`; the claim ceiling is
`contract_only`. This record covers only the additive shared package and structural
same-candidate join. It grants no B00/B04,
provider, engineering, physical, or R01-R10 credit.

The implementation is authored by `gpt-5.6-luna/high` under the UP1-04A file
boundary. `CandidateStatePackageV5{G1T,G2T,G3T}` retains the concrete layer objects
after the three V5 constructors have been loaded by the owning layer harness or by
the explicit, idempotent `load_genome_v5_components!()` entry. The integration
entry requires `MechanismGenomeV5`, `FieldGeometryGenomeV5`, and
`RealizationControlGenomeV5` at runtime, checks their public v5 refs and real
`candidate_hash` values, binds G2 explicitly to the package candidate, and hashes
the three component hashes, all public refs, axes, G3 child feedback refs, and
candidate identity. G1 candidate URI equality is exact.

The shared join carries each child's `structural_status`, `provider_match`,
`resolution`, errors, and gaps. Exact same-candidate G1/G2 feedback refs can close
the G3 feedback-authority gap; provider, mesh, engineering, and physics gaps remain
in the package. Therefore the real constructor fixture is structurally valid but
`resolution=terminal_deferred` with `claim_ceiling=none`.

The A fixture rebuilds the G2 public ref under its own candidate URI namespace
from the same plan content, then recomputes the G2 component hash; the UP1-02
`urn:fusion:g2:*` identity is retained as historical input and is not aliased or
reused. Typed feedback equality still carries
`feedback_provenance_gap:typed_refs_without_external_receipt` until an external
authority receipt is supplied.

`integrate_genome_v5` is structural admission only and A always emits
`resolution=terminal_deferred` with `claim_ceiling=none`. A mismatch is reported as
`structural_status=:fail_closed`; an authority-pending URI or placeholder digest is
itself a structural rejection, while an old mapping gap is kept separately. A fresh
package uses a `:pending` receipt with no legacy records and is not
migration-complete. The caller may supply only that exact fresh factory receipt;
stale or foreign receipt identities are rejected before integration. V4 references
have no proven lossless field-semantic mapping in AD-19, so `legacy_refs=` creates
explicit `terminal_deferred` records sourced from typed `GenomeContractRef` inputs;
placeholder/synthetic refs are rejected and all remaining typed sources are marked
unverified in deferred provenance. No lossless/migrated record constructor is
exposed in A, so caller-supplied strings or self-filled hashes cannot create
positive migration evidence. Each package also carries a typed, candidate-specific
G2 binding containing the actual G2 component hash, even when the plan body is
reused.
The old V4 package and registry are untouched.

Validation evidence:

- `julia --startup-file=no --project=. -e 'using FusionConceptAI; println("UP1_04A_IMPORT_OK")'` exit `0`; see [import stdout](logs/import_r1.stdout.txt), [stderr](logs/import_r1.stderr.txt), and [exit](logs/import_r1.exit.txt).
- Julia parser smoke over the two new source files and the UP1-04A focused test exited `0`; see [parse stdout](logs/parse_r1.stdout.txt), [stderr](logs/parse_r1.stderr.txt), and [exit](logs/parse_r1.exit.txt).
- The explicit G1→G2→G3 component loader smoke exited `0`; it resolved all three concrete types without running fixtures or the heavy lane. See [loader stdout](logs/component_load_r1.stdout.txt), [stderr](logs/component_load_r1.stderr.txt), and [exit](logs/component_load_r1.exit.txt).
- The r2 loader smoke also exited `0`; see [stdout](logs/component_load_r2.stdout.txt), [stderr](logs/component_load_r2.stderr.txt), and [exit](logs/component_load_r2.exit.txt).
- The r3 loader/parser smoke exited `0`; see [loader stdout](logs/component_load_r3.stdout.txt) and [parser stdout](logs/parse_r3.stdout.txt).
- `python docs/v4_multitopology_generation/validate_plan.py` exit `0` (`checks=pass`, `task_count=24`).
- `git diff --check` exit `0`.

The A-only focused join test ran through isolated child fixture processes and passed
45/45, exit `0`; r12 is the current run and its raw command/stdout/stderr/exit are in
[up1_04a r12 logs](logs/). It records the runtime package hash, receipt hash, and
receipt-after identity. The added checks reject empty deferred receipts and forged
G3 child-reference identity. The child processes exercised existing G1/G2/G3
focused builders without loading their source twice in the A parent process. B00/B04
and Julia/DESC heavy execution were not run.
This package is not a physical realization and does not close the unchanged parent
goal.

## Limited acceptance decision

The different Luna independent review in
[UP1-04A independent_review_r12](independent_review_r12/acceptance.md) passed
with `pass_limited`. Sol accepts only the additive V5 shared entry and
structural same-candidate identity wiring described above. The author r12 run
and independent fresh run both report 45/45 with exit `0`; the independent
command, stdout, stderr and exit artifacts are retained in that archive.

`UP1-04B=false`, `B00=false`, `B04=false`, `provider=false`, `mesh=false`,
`engineering=false`, `physical=false`, and `R01-R10=false`. The UP1-04 total
gate remains unaccepted and requires UP2-00 plus UP1-04B formal receipts,
checker evidence, two-process replay and a separate independent review.
Historical r8 `program_exception` and r10/r11 `unknown` classifications remain
unchanged in the evidence manifest.
