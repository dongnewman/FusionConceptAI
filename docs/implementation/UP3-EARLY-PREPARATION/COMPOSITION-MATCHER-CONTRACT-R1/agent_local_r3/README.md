# UP3 CompositionMatcher contract-only R3

R3 closes the failure-identity seam found after R2. `_cmc_failure_key` is
defined before every use, retains typed `code/path/detail`, erases diagnostic
input/port labels, and uses an explicit stable sort key. Static QA also checks
that the definition precedes its use and that direct helper assertions exist.

```text
python -B test/RuntimeV4/static_qa_composition_matcher_contract_v1.py
exit=0, PASS static_qa_composition_matcher_contract_v1_r3
```

This remains an additive contract-only slice. Julia/DESC and the executable
Julia test were not run; no shared entry, task manifest, provider, mesh,
solver, numerical, physical, or engineering status is changed.
