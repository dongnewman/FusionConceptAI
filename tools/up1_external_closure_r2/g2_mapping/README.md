# UP1 external-closure R2 — production G2 mapping

`production_g2_mapping.py` is a standard-library, strict JSON evaluator. It
rejects duplicate keys and unknown fields at every object, checks all G2
security and anti-replay fields, and checks the bidirectional chain
`source <-> candidate <-> four-axis evidence <-> G2`.

Present profiles must be checked against a separate frozen
`expected_binding.json`; local self-consistent candidate/source edges are not
ownership proof. The evaluator recomputes domain-separated source-identity,
canonical-declaration, and signature-payload hashes, then requires declaration
values, signature payload, and receipt to agree. The expected binding is never
read from the profile itself.

The component is structural: it does not create or verify an external trust
root. A missing authority is a typed absence; `TEST_ONLY` positive fixtures are
accepted only as `non_evidence`.

Run in a fresh interpreter with bytecode disabled:

```text
python -B tools/up1_external_closure_r2/g2_mapping/validate_g2_mapping.py PROFILE.json --expected EXPECTED_BINDING.json
```
