# E2-N06 independent static precheck R4

Verdict: **changes_requested**. Julia/DESC and the N06 runner were not started.

All four frozen hashes match: source `a9d78114db29a0ff16b785fe08318884c073e6a433ec16a4c403445ada004ec8`, fixture `9cc85ec2cf0f4e00cf4f613705cca15fd2cd5be23d56042eeb3a96d3fcb80f44`, tests `9a19b54ae2c92f8b557ffc79e144e4bf8e6cc4e2fa1bf04f50ae871f66a31783`, runner `9410e2edbb7afc70599e183f30a2ef9836b7e84a1834296e27d96b881b1f86af`. The fixture is schema validation only, with four complete G1 selectors and five mutation rows.

The current source does call `up2e0_validate_binding` before `_n06_actual_fields`, uses unique typed G1/G2/G3 selectors, derives boundary paths from selected objects, checks effort/flow dimensions and selected flow-link identity, and preserves the contract-only exception/claim ceiling. The tests contain detached/foreign/wrong-kind, duplicate, dimension, flow-partner, source-locator/type, and identity negatives.

Two blockers remain in the frozen source. First, `_n06_validate_spec_binding` uses a hard-coded `Dict("N06-01" => ...)` and `_n06_field(p, spec.id)`, while `_n06_mutate` routes on `(field.id, target.mutation_kind)`. This keeps `id` as a dispatch key and does not satisfy field_path + mutation_kind + source locator/type dispatch. Second, `n06_validate_mutation` accepts only a projection and spec; because `N06LedgerProjectionV1` has an ordinary public constructor, a detached projection can reach mutation validation without a fresh full `up2e0_validate_binding` call. The mutation boundary must be sealed or receive package/E0 and revalidate before receipt generation.

Structured checks are in [report.json](report.json) and command evidence with real exit/stdout/stderr/timestamps is in [command_receipts.json](command_receipts.json). JSON parse, `validate_plan.py`, and `git diff --check` exited 0. This is not an acceptance verdict.
