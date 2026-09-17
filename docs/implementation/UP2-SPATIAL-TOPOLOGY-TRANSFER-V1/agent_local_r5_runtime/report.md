# UP2 SpatialTopologyTransferContractV1 — agent-local R5 focused runtime

## Runtime receipt

This archive records the single authorized focused command observed for the
current R5 input bytes:

```text
julia --startup-file=no --history-file=no --project=. test/RuntimeV4/UP2SpatialTopologyTransfer/spatial_topology_transfer_contract_v1_tests.jl
```

The supplied UTC interval was
`2026-09-17T23:42:39.0178395Z` → `2026-09-17T23:42:43.5875139Z`.
The focused test reported exit code `0`, `70/70` Julia assertions, and `3.9s`.
Stderr was empty.

The Julia PID is unavailable because the PowerShell launcher collided with the
read-only built-in `$PID` variable. The command was not rerun; therefore this
archive does not claim a recoverable Julia PID or a stronger process-identity
receipt.

## Static context and current inputs

The earlier Python static QA record was `124/124`, exit `0`. That is a
different checker and assertion count from the focused Julia result; it is not
being merged into `70/70`.

The four current input bytes were rehashed while creating this archive:

| path | bytes | SHA-256 |
|---|---:|---|
| `src/RuntimeV4/SpatialTopologyTransferContractV1.jl` | 29346 | `57915e122e8d9211f732e9e8abea468fb20aa3b74d111fe938ff5e8584ebec34` |
| `test/RuntimeV4/UP2SpatialTopologyTransfer/spatial_topology_transfer_contract_v1_tests.jl` | 15350 | `920f0c0e43c103f93bc58991be04492d139fff8060e6d465c689343d43d6967c` |
| `test/RuntimeV4/UP2SpatialTopologyTransfer/spatial_topology_transfer_contract_v1_fixture.json` | 1636 | `4ddcb561170ba260f3ef73f7e2f68bf5dc3fd66a6be7a30260e93aead455593f` |
| `test/RuntimeV4/UP2SpatialTopologyTransfer/static_qa_spatial_topology_transfer_contract_v1.py` | 6613 | `fa79dda76894fe5d05a76cd59ecb4a04447724e5f6c7046f8249b6f5479466b2` |

## Claim ceiling

This remains `accepted=false`, `contract_only`, and `screen_only`. The focused
software assertions do not provide real conservation evidence or provider,
mesh, solver, UP2-total, or R01–R10 credit. No Julia/DESC rerun was performed;
no source, test, fixture, static-QA file, old manifest, index, or commit was
modified. Only this R5 archive's `report.md` and `manifest.json` were added.
