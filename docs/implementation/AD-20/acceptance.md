# AD-20 acceptance record

- task: `AD-20`
- status: `accepted_limited`
- accepted: `true`
- accepted_scope: `g2_public_ref_authority_and_staged_up1_04_schedule_architecture_only`
- base HEAD: `4b69f55f7f80240147a65a22809dc1207824dde2`
- owner: `gpt-5.6-luna/high` (architecture documentation)
- independent reviewer: different Luna (pass)
- Sol decision: AD-20 is limited to the new G2 ref authority and staged scheduling boundary. It grants no implementation, provider, B00/B04, mesh, engineering, physical, or R01–R10 credit.

AD-20 requires each new UP1-04A candidate to construct a fresh public G2 `GenomeContractRef` in the `fusionconceptai://GenomeV5/G2/` namespace from accepted G2 plan content, then recompute the G2 and typed package identities. Historical UP1-02 `urn:fusion:g2:*` fixture/ref/hash/evidence remains immutable and is not reused or aliased. The explicit route is `UP1-01/02/03 → UP1-04A → UP2-00 → UP1-04B → UP1-04 → UP2-01`; UP1-04A is currently `review_pending` and may only later unlock UP2-00 through A-only evidence and independent review at a limited scope.

UP2-00 is contract-only typed precompiler schema/validator work covering real B04 N01–N10 fields, pre-registered error classes, and compile-before-provider/invocation-count interfaces. UP1-04B freezes and executes B00 F0–F5 plus all 50 formal B04 mutations, receipts, checker, and two-process replay before the UP1-04 total gate can be accepted. R01–R10 remain unchanged.

## Provenance

The four allowed core documents were copied byte-for-byte before editing under [`before/`](before/) and after editing under [`after/`](after/). [`bounded_diff.patch`](bounded_diff.patch) contains the bounded before/after changes; metadata records exact SHA256, byte counts, and seven-digit mtime values. [`protected_dirty_inventory.json`](protected_dirty_inventory.json) records the inherited dirty-file inventory source and hashes.

Validation commands and exits are recorded in [`evidence_manifest.json`](evidence_manifest.json). This archive is accepted_limited architecture/scheduling evidence only; it contains no Julia/DESC run, provider invocation, mesh result, engineering result, physical result, or parent-goal credit.
AD-20 r1 保留首轮归档。独立复核发现 README 链遗漏 UP1-04 总门，已只修一处为 UP1-04B → UP1-04 → UP2-01。原始 before/after/bounded diff 未覆盖；r1 before/after/bounded diff 另存。

- r1 status: `review_pending`; accepted: `false`
- reviewer: different Luna；首轮发现：README chain omitted UP1-04 total gate
- 修复范围：README 单一链字符串；18、16、task_manifest 与 A 源码/测试/归档未改
- r1 before SHA256: `62d44b615b0d7f61bf1039d00cf328c5fd5321282566050d111c04204e1ea1e8`
- r1 after SHA256: `0031cb30155958e3d3def0fa82735d24f46f1ccf3397ead6d80d21bb771d82ee`
- 当前仍不授实现、provider、B00/B04、mesh、工程、物理或 R01–R10 信用。

## Limited acceptance

The independent Luna review passed. Sol accepts only the current AD-20 G2 public-ref authority and staged schedule decision, plus the preserved initial/r1 and index before/after/bounded-diff provenance. This does not accept UP1-04A implementation, UP2-00 implementation, UP1-04B execution, provider, B00/B04, mesh, engineering, physical, or R01–R10 credit. UP1-04A remains `review_pending` in the task manifest.
