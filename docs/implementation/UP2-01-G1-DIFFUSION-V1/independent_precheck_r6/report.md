# UP2-01-G1-DIFFUSION-V1 independent static precheck R6

Verdict: `pass_limited`; `accepted=false`; `review_pending=true`.
Serial focused lane: `ready_for_serial_focused=true`.
Runtime in this precheck: `not_run`.

The R6 provenance erratum closes the R5 finding. The actual receipt chain is
path-correct and hash-consistent:

| path | bytes | SHA-256 |
|---|---:|---|
| `repair_r2/report.md` | 3482 | `0956b606e576ad8979fec115fd679f0f6465659f5be51f84e9c07786fbc9d44c` |
| `repair_r2/evidence_manifest.json` | 2032 | `0faed4835e7b52a9de28a5964bc30e695fdb99d642fc3710972d56d149ec44c2` |
| `repair_r3/report.md` | 3554 | `7e1ab164339f782a83b7819cca39c5a31276782e5b66ddc0e0262531356f1560` |
| `repair_r3/evidence_manifest.json` | 2499 | `2beb6360023fce345760e618b845d8dca66f0de964c0f1d230e812188f63b813` |
| `repair_r4/report.md` | 3745 | `43f793be1e1cc5b895ef7c92312743c5984cfcd44d0cf691d8d308eb37ae09e0` |
| `repair_r4/evidence_manifest.json` | 2850 | `907dbc104f02878b6f600954a33639aefea3bb4c4f98abb8274dad19f8cad28e` |
| `repair_r5/report.md` | 3187 | `ee0986149fda19d060e53320f4e64377c75c8b6f4d88ecce295309acdf3baaf4` |
| `repair_r5/evidence_manifest.json` | 3070 | `22f850682478efe8e0d5499860ed45816d0fb5b3599494a65cb9a7a63930c857` |

R5's misreference is resolved: `0956b606...` / `0faed483...` are the R2
pair, while R3 has its own actual pair above. R6 records this distinction
additively and does not rewrite any old receipt. R4 and R5 hashes match their
current files. The R6 manifest has `review_pending=true`, `accepted=false`,
`target_mutation_in_r6=false`, and a documentation-only scope.

The four target files independently match the required hashes and byte counts;
R6 before and after are equal. The permitted static QA exited `0` with
`static_qa=pass`, and the target JSON/hash assertion exited `0`. No Julia/DESC
command was run during this precheck and no matching process was present at
the frozen check. This clears only the software focused lane. It grants no
compiler, provider, mesh, solver, physical, engineering, current-A, B00, B04,
or R01-R10 credit. The focused run must preserve raw stdout/stderr, exit code,
PID, UTC, process and dirty-state receipts and must remain `accepted=false`
pending independent postrun review.

## Frozen evidence

- HEAD/branch: `4b69f55f7f80240147a65a22809dc1207824dde2` / `main`.
- Pre-write dirty snapshot: 3,685 entries; UTF-8/LF status SHA-256
  `82c0228ed98c2bf80448f424823e9a349f45ce2706914ab69aa8e6951da3fbe5`.
- Targets: source 31,743 bytes `14d26ee556029bd1fcf2477f3dbe9599622d37a3f5704d1c0bb1dd9ea31dbf1a`;
  Julia test 9,655 bytes `34bfaf76f30d5fe2684035d810b36a5c3bc045a0d8d278e3f0af5dc5b888c4a6`;
  fixture 1,582 bytes `7b580bf9ad875ed70ffc3aa0ee2e27cbe124c413ec7dad0a8fcd3410c6864641`;
  static QA 4,499 bytes `87f511f5402224df06928a9e78c0d3213d2330da5b91021b628acd51d7536066`.

