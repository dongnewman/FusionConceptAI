# AD49-F0 G1/G2 source-authority factories — independent review R2

Date: 2026-09-15 UTC  
Reviewer: `different gpt-5.6-luna/high`  
Decision: `pass_limited`  
Scope: factory software capability only. This review writes only this
`independent_review_r2/` directory and does not modify the four products,
source declarations, registries, entrypoint, task manifest, or R1 history.

## Decision

The R1 `changes_requested` defects are closed by the reviewed repair. Both
factories derive their repository anchor from their own module `@__DIR__`,
resolve it through `realpath`, and require a `repository_head` locator to name
that exact anchor. An unavailable anchor and a fixture relabeled
`repository_head` fail closed. A locator marked `isolated_test_fixture` may
produce `Present` only as `synthetic_test_only=true`.

Before a committed source can be Present, each factory independently reads the
working bytes, `git show HEAD:path`, and `git cat-file blob <HEAD blob>` and
compares bytes, lengths, SHA-256 values, locator fields, observed HEAD, tracked
path, and clean porcelain. Fresh focused tests cover main-repository typed
absence, unavailable anchor, relabeled fixture, `assume-unchanged` mutation,
`skip-worktree` mutation, and an incorrect HEAD blob digest. All controls fail
closed as required. G2 preserves `GenomeContractRef` and has no contract to
`QualifiedRefV1` mapping API.

The source-stage binding contains the exact AD45 temporary handle and envelope
hash, public contract, four version axes, binding digest, source-content digest,
declaration digest, and factory identity/receipt digest. Present receipts keep
`trusted=false`, `candidate_identity_created=false`, and
`final_hash_created=false`. No identity or final candidate/package hash is
created.

## Fresh execution evidence

The serialized run started after a no-existing-Julia-process check. Every
process exited zero and no Julia process remained afterward.

| check | result | PID | UTC | exit |
|---|---:|---:|---|---:|
| G1 focused R2, including adversarial controls | 31/31 | 95000 | 17:15:59.7415810–17:16:13.7227597 | 0 |
| G2 focused R2, including adversarial controls | 31/31 | 95028 | 17:16:13.7472522–17:16:25.3844310 | 0 |
| G1 diffusion regression | 32/32 + 34/34 + 5/5 | 79940 | 17:16:25.3884344–17:16:31.2738637 | 0 |
| G1 UP1 regression | 47/47 + 21/21 | 67024 | 17:16:31.2773843–17:16:42.1808377 | 0 |
| G2 metric regression | 20/20 + 10/10 + 5/5 + 14/14 + 15/15 | 96780 | 17:16:42.1858366–17:16:49.5705329 | 0 |
| G2 UP1 regression | 57/57 + 59/59 + 8/8 | 94308 | 17:16:49.5735360–17:16:58.1993024 | 0 |

Raw stdout/stderr and per-process PID/UTC/exit records are retained under
`raw/`. The intentional unavailable-anchor probe emits the expected Git
diagnostic while its Julia test process exits zero.

The independent Python validator completed with exit 0 after checking all four
product files, all required closure/control tokens, current main-repository
typed absence, G2 mapping absence, protected hashes, upstream input hashes,
the plan validator, and review-directory scope. The plan validator and scoped
`git diff --check` both exited zero.

## Source and credit boundary

HEAD is `4b69f55f7f80240147a65a22809dc1207824dde2`. The current G1 declaration
`src/GenomeV5/G1/DiffusionDeclarationV1.jl` and G2 declaration
`src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl` remain `??` working-tree
files; `git ls-files` and `git cat-file -e HEAD:path` confirm typed absence for
both. Thus this review does not publish source authority, even though isolated
fixtures exercise the Present software path.

The four F0 product hashes are frozen in `final_hashes.json`; registry,
entrypoint, and declaration-source protected hashes are unchanged. R1 remains
append-only history. This result permits the root to perform a fresh S2 probe
according to its own contract. It grants no trusted source authority, T0,
provider, mesh, solver, engineering, physics, search, R01–R10, or L4 credit;
`L4_credible_count=0`.
