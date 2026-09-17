# UP1 R2 test collection fix regression report

## Result

The pre-fix 18-full-regression runs deterministically failed at collection in
`witness_authority/test_witness_authority.py`. The test package's short name
shadowed the production namespace. The one-line namespace correction was
applied within test ownership only.

The required command, run serially twice, now succeeds:

```text
python -B -m pytest -q test/up1_external_closure_r2
```

Both fresh runs report `148 passed, 3 skipped` and exit code `0`. Their raw
stdout/stderr and process receipts are in `raw/fresh_fixed_r1.*` and
`raw/fresh_fixed_r2.*`.

## Component matrix

| component | result |
|---|---:|
| aggregate_gate | 22 passed |
| authority_intake | 17 passed, 2 skipped |
| common | 13 passed |
| environment_provenance | 16 passed |
| g2_mapping | 15 passed |
| integration | 11 passed |
| pki_chain | 16 passed |
| revocation_time_replay | 13 passed, 1 skipped |
| source_axis_binding | 13 passed |
| witness_authority | 12 passed |
| **total** | **148 passed, 3 skipped; all exit 0** |

Each matrix run has a process receipt and exact stdout/stderr hash in `raw/`.
The prior failures remain in `raw/prior_failure_*` and are not overwritten.

## Boundaries

This closes only the pytest package-shadow collection blocker. It does not
upgrade any component's review status or claim ceiling, nor does it infer
external authority, publishability, UP1 credit, or R01-R10 closure.
