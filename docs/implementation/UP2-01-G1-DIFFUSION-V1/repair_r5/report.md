# UP2-01-G1-DIFFUSION-V1 repair R5 hash-correction erratum

Status: `changes_ready_for_independent_r5_review`; `review_pending=true`; `accepted=false`.
Runtime status: `not_run`; Julia and DESC were not invoked.

This additive erratum corrects only the evidence hash ledger identified by the
independent R4 precheck. The source, Julia test, fixture and static-QA files
were not changed in R5. The R3 and R4 reports/manifests remain historical
receipts and were not overwritten.

## R4 manifest error and correction

The R4 report ledger and current target bytes agree. The R4 manifest crossed
the fixture and static-QA `r3_before`/`r4_after` entries and retained stale
after hashes. The following table records the original values and the correct
values obtained from the current files with PowerShell `Get-FileHash -Algorithm
SHA256` and `Get-Item .Length`:

| target | bytes | R4 manifest before (original) | R4 manifest after (original) | correct R5 before/after from `Get-FileHash` |
|---|---:|---|---|---|
| `src/GenomeV5/G1/DiffusionDeclarationV1.jl` | 31743 | `2d668cdc5ad40b55ca628af766273b4824e973ca5f77bb2172e7bc52fa5dd9a9` | `14d26ee556029bd1fcf2477f3dbe9599622d37a3f5704d1c0bb1dd9ea31dbf1a` | `14d26ee556029bd1fcf2477f3dbe9599622d37a3f5704d1c0bb1dd9ea31dbf1a` |
| `test/GenomeV5/G1/diffusion_v1_contract_tests.jl` | 9655 | `29bd3225a9a0fe6498fe5cdcc01ed44ef405bc2b11835f2d457e9982e590a48c` | `34bfaf76f30d5fe2684035d810b36a5c3bc045a0d8d278e3f0af5dc5b888c4a6` | `34bfaf76f30d5fe2684035d810b36a5c3bc045a0d8d278e3f0af5dc5b888c4a6` |
| `test/GenomeV5/G1/diffusion_v1_fixture.json` | 1582 | `7b580bf9ad875ed70ffc3aa0ee2e27cbe124c413ec7dad0a8fcd3410c6864641` | `1dba965964c8d9b4792ebb8f5dae68bb6fdb85b6f8d315d83a73a2bc5ae9a152` | `7b580bf9ad875ed70ffc3aa0ee2e27cbe124c413ec7dad0a8fcd3410c6864641` |
| `test/GenomeV5/G1/static_qa_diffusion_v1.py` | 4499 | `87f511f5402224df06928a9e78c0d3213d2330da5b91021b628acd51d7536066` | `b8fe5945558fefb22d6ec08c5ad7a5861f9e87d8dc50dea51a6ad8335bd36626` | `87f511f5402224df06928a9e78c0d3213d2330da5b91021b628acd51d7536066` |

Because R5 changes documentation only, each correct R5 before/after value is
identical. The R4 historical manifest remains unchanged at SHA-256
`907dbc104f02878b6f600954a33639aefea3bb4c4f98abb8274dad19f8cad28e` as
captured in the prior review record. The R4 report remains unchanged at
`43f793be1e1cc5b895ef7c92312743c5984cfcd44d0cf691d8d308eb37ae09e0`.

## Verification

The current target manifest is
`repair_r5/evidence_manifest.json`. Its JSON and target hash assertion exited
`0` with `hash_and_json_check=pass`. The existing Python static QA was rerun
with:

```text
D:\Users\Newman\anaconda3\python.exe test/GenomeV5/G1/static_qa_diffusion_v1.py
```

It exited `0` with `static_qa=pass` and
`julia_or_desc_executed=false`. No Julia/DESC command was run. No compiler,
provider, mesh, solver, physical, current-A, B00, B04 or R01-R10 credit is
claimed.

An independent Luna R5 static review should verify the four current hashes and
byte counts against `Get-FileHash`/`Get-Item.Length`, confirm the R4 archive is
untouched, parse the new manifest, and rerun only the static checks before any
serial focused lane.
