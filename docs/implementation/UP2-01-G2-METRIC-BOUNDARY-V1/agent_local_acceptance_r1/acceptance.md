# UP2-01-G2-METRIC-BOUNDARY-V1 agent-local acceptance R1

- task: `UP2-01-G2-METRIC-BOUNDARY-V1`
- current product HEAD: `8dbbb68b065c3ccd9a9f0f97a879aae8665eb2e9`
- status: `accepted`
- scope_status: `accepted_local_contract`
- resolution: `accepted_local_contract`
- claim_ceiling: `contract_only`
- acceptance record: this directory

## Accepted evidence

The versioned G2 chart/metric/boundary declaration contract is accepted for
local software scope. The complete semantic face-owner sort key is stored
canonically, candidate-owned mesh and face fields are typed, duplicate owner
orders are deterministic, and contradiction/missing-authority behavior is
closed. The R2 receipt reports static QA exit 0 and focused Julia exit 0 with
seven testsets and `85/85` assertions (`20/20 + 10/10 + 16/16 + 5/5 + 14/14
+ 15/15 + 5/5`).

The different-Luna R2 review verdict was `pass`; it independently rehashed
the product inputs, reran static QA read-only, and found no blocking issue.
The independent agent-local wrapper R3 exited 0 and independently parsed the
same `85/85` totals.

## Wrapper provenance

The wrapper input baseline was
`cfc745939a02fd023854dd04e9bb6d04ccadf9ee`; current product HEAD is recorded
separately because the policy checkpoint advanced HEAD without changing these
four product hashes.

| input | bytes | SHA-256 |
|---|---:|---|
| `src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl` | 31706 | `a52ea1a60a207027c9f8029f0928af2b8bcc543f0e9ae37b88b87c9767c337b3` |
| `test/GenomeV5/G2/metric_boundary_v1_contract_tests.jl` | 16491 | `61602826511df825ca6e3958fd4c42a84193acb0c3f24236cfa67086e8c83636` |
| `test/GenomeV5/G2/metric_boundary_v1_fixture.json` | 4629 | `c7b417e33819bae64c59f22ac9b70b089d8315c52517eaa7af8fd5f63aa8a3f5` |
| `test/GenomeV5/G2/static_qa_metric_boundary_v1.py` | 8844 | `b329b50fe03d6fc6daee86973399dabf949a9214a02235653bd78024f70dd94b` |

The wrapper output `stdout.txt` is 1338 bytes,
`275f6ffb447513e88454643ba68da7cf0dd72e8947e9ec15d74c7ee45e264c71`, and
`stderr.txt` is empty with SHA-256
`e3b0c44298fc1c149af4c8996fb92427ae41e4649b934ca495991b7852b855`.
The wrapper's policy/task input hashes are
`4c148ca007b30431856ddf6fd5217eea23071ed80f8920742eea18b362dc4015` and
`3223f122e90385568997b3057fad7122fc7daafb86fc2fa2440e00dd2a33f2de`.

## Claim boundary and next gate

This acceptance is only the G2 declaration schema plus candidate/source
metadata contract and local software replay. It does not establish actual
metric/mesh authority, executable spatial discretization, conservation,
provider execution, or physical validity; T0/recheck must bind and verify
local source/declaration bytes and receipts. It grants no compiler, mesh,
provider, solver, numerical, physical, engineering, search, B00, B04,
UP2-01-total, or R01--R10 credit. T0 remains `planned` and unaccepted; no
downstream status is changed by this record.
