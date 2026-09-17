# AD49-F0 R2 repair record

R1 review feedback was addressed without changing the four product paths or
any upstream source, registry, entrypoint, manifest or old declaration schema.
Each factory now derives its repository anchor from its own module location
(`@__DIR__` → realpath → `git rev-parse --show-toplevel`). A locator marked
`:repository_head` must name that exact anchor; an unavailable anchor or a
fixture relabeled as repository head fails closed. Temporary repositories are
accepted only as `:isolated_test_fixture`, and Present output remains
`synthetic_test_only=true` with `trusted=false` and no identity/final-hash
credit.

Before Present construction, each factory independently checks current working
tree bytes and SHA-256, HEAD path, HEAD object, `git show HEAD:path` bytes,
`git cat-file blob` bytes, HEAD byte length/SHA-256, locator byte length/source
SHA/head SHA, exact current HEAD, tracked path and clean porcelain. The tests
exercise absent main-repository locators, foreign/relabelled roots, anchor
probe absence, assume-unchanged mutation, skip-worktree mutation, and HEAD
blob mismatch. The binding remains a distinct source-stage value with the
exact AD45 handle/envelope hash, public contract, four axes and temporary
binding role.

Fresh serialized validation:

| check | result | PID | UTC | exit |
|---|---:|---:|---|---:|
| G1 focused R2 | 31/31 | 64112 | 2026-09-15T17:04:00.7584431Z–2026-09-15T17:04:12.7966009Z | 0 |
| G2 focused R2 | 31/31 | 41448 | 2026-09-15T17:04:24.2893323Z–2026-09-15T17:04:37.0826709Z | 0 |
| G1 existing regression | 47/47 + 21/21 | 28828 | 2026-09-15T17:04:46.8913803Z–2026-09-15T17:04:55.9897928Z | 0 |
| G2 existing regression | 57/57 + 59/59 + 8/8 | 70205 | 2026-09-15T17:05:08.0446332Z–2026-09-15T17:05:16.6788165Z | 0 |

The `fatal: not a git repository` line in focused output is the intentional
anchor-unavailable negative control; the Julia process exited 0 and no Julia
process remained afterward.
