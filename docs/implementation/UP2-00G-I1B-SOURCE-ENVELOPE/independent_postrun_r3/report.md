# GI1B focused_r3 independent postrun review

Verdict: `changes_requested` for the focused test run, with the failure
attributed to a test expected-manifest mismatch. No deeper production-source
bug was found in the N10-03 accessor or its source identity.

The preserved focused_r3 run exited `1`: 2014/2024 GI1B assertions passed and
10 failed, with five failures in the E1-present context and five in the
both-absent context. All ten failures are the same N10-03 semantic mismatch;
the upstream 598/598 testsets passed and no later testset ran.

N10-03 is the typed G3 binding child ref, not the outer G3 bundle ref. The
production row spec and source path are explicit:
`/g3/binding/contract_binding/contract_ref`, with a source locator that compares
the value to `component_identity.g3_child_refs.binding`. The N10 projection
independently checks that the child is a `GenomeContractRef` with version `v2`
and URI ending in `/binding`, and constructs N10-03 from that child. The outer
G3 bundle remains a separate public `v5` ref.

The focused test helper at
`test/GenomeV5/UP2/gi1b_source_envelope_tests.jl:160` instead expects
`package.g3.contract_binding.contract_ref`, which is the outer bundle `v5`
ref. The production accessor returns the correct child `v2` value, and the
generic mutation rule correctly produces the child URI with
`/gi1b-foreign`. Therefore the original value, attempted value, original hash,
attempted hash and mutation hash all diverge from the test's v5 expectation in
both contexts. The GI1B row's `source_ref` remains the outer G3 layer ref and
component hash, which is the source-owner identity used by this envelope; it
does not change the typed N10-03 field value.

The narrow repair is one test expected-manifest edit: replace the N10-03 value
expression with
`package.g3.binding.contract_binding.contract_ref`. Do not change the source,
fixture, runner, N10 schema, source-owner identity, or prior focused evidence.
After an independent static diff/hash review of that test-only edit, a fresh
serial focused run is permitted. Preserve this exit-1 run and write the next
run to a new receipt directory. Even after a passing rerun, this remains local
contract software evidence with zero compiler/provider/solver calls and grants
no formal B00/B04, engineering, physical or parent-goal credit.

This read-only review was performed at HEAD
`4b69f55f7f80240147a65a22809dc1207824dde2`, branch `main`; current status had
296 entries. Julia and DESC were not run by this review.
