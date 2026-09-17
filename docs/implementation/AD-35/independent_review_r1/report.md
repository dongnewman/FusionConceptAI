# AD-35 task closeout and cleanup independent review R1

Date: 2026-09-15  
Reviewer: different Luna/high (`/root/g3_control_arch_independent_review`)  
Records reviewed: `acceptance.md`, `manifest.json`, `status_sync_r1/`, core
README, v4 README/task manifest, core 14/16/18, implementation README and
current dirty protection  
Decision: `changes_requested`  
Scope: read-only contract and status-sync review; no implementation acceptance

## Checks performed

The AD-35 acceptance and manifest correctly say `review_pending`,
`accepted=false`, `sol_decision=pending`, and
`claim_ceiling=collaboration_contract_only`. They explicitly preserve the
existing parent objective and do not create a mainline task or grant physical,
provider, mesh, engineering, search, B00, B04 or R01–R10 credit.

The task manifest contains 37 unique tasks. A read-only dependency check found
zero missing dependency IDs and zero dependency cycles. The AD-35 links in the
core README, implementation index, orchestration/work-order documents, and
architecture decision are present. The reviewed JSON files parse successfully,
and the scoped `git diff --check` returned exit code 0.

The status-sync record correctly marks this work as a documentation-validation
task with `code_tests=not_applicable_for_contract_documentation`; it does not
pretend that static validation is code, physical, or implementation evidence.
Its recorded JSON/plan validation and diff validation are applicable in kind,
and the recorded point-in-time hashes for the six authorized core document
targets and the four AD-35 delivery records match the current checkout.

## Required corrections

### 1. Static command receipts do not satisfy the frozen receipt fields

The AD-35 contract requires each applicable command receipt to retain cwd,
argv, PID when available, raw output or a content summary, exit code, and
input/output or artifact hashes. `status_sync_r1/manifest.json` records exit
codes and cwd/argv, but the `validate_plan.py` command says its raw output was
not persisted, gives no raw hash, and provides no input/output hash fields.
The diff command has an empty-output hash but also lacks explicit input/output
hash fields. The report summary cannot replace a reproducible raw artifact or
an explicit content-summary/hash record when the contract requires it.

For this pure documentation task the correct repair is to keep
`code_tests=not_applicable`, retain the applicable JSON/link/diff/format/static
checks, and add a real receipt for each command: exact input paths and hashes,
output/artifact paths and hashes, raw stdout/stderr or a bounded content
summary with its hash, and `pid=not_applicable` only where the direct static
launcher cannot provide one. No code-test or physical claim is needed.

### 2. The cleanup inventory is not exact and omits an owned delivery path

`final_exact_owned_set` has ten paths, including
`docs/implementation/AD-35/status_sync_r1/manifest.json`, but
`cleanup_inventory` has no row for that manifest. It has a single aggregate
row named `all other pre-existing dirty files, source, tests, runs, old
receipts and accepted artifacts`, with placeholder hash text rather than
exact paths and hashes. That is incompatible with the contract's per-path
inventory and makes an independent protected-file review impossible.

The repair must add the missing status-sync manifest row with its before/after
existence and SHA-256 (or explicit self-hash exclusion while retaining the
path), and replace the aggregate protected row with a frozen exact path list or
a separately content-hashed dirty/protected inventory. Preserve every
pre-existing, other-agent, failure-receipt, accepted-artifact and ambiguous
path. No glob, recursive cleanup or global revert is authorized.

### 3. Closeout identity is not fully frozen

The AD-35 manifest records `base_commit` only as the short value `4b69f55`,
while the observed checkout resolves to
`4b69f55f7f80240147a65a22809dc1207824dde2`. The status-sync manifest does not
record a base commit, actual model/reasoning effort, or a complete protected
before/after hash set. The contract's minimum closeout fields require these
values. Add the full commit ID and the missing task metadata to the status-sync
receipt, without rewriting any historical evidence.

## Boundaries that are correct

The implementation-task requirement for task-specific positive and negative
tests is present and is not incorrectly applied as a fake test to this
documentation task. The distinction between `pass`, program/numerical/
physical failure, interruption, not-executed, unsupported and deferred states
is present. Cleanup is explicitly after validation, exact-owned only, and
ambiguous ownership is supposed to be preserved. Different-Luna review,
serial heavy execution, protection of old failure evidence and no-credit
boundaries are all stated correctly.

The core task count, dependency graph, links and current AD-35 status do not
need a planning change. The needed changes are confined to the closeout
receipt's completeness and exact protection inventory.

## Cleanup inventory for this independent review

This review created no temporary or scratch file. The only intended new paths
are this report and its manifest. No existing dirty file, implementation
artifact, receipt, run, source or test was cleaned, reverted or touched.

## Ruling

`changes_requested`. After the three receipt/inventory corrections, a
different Luna may re-review the closeout contract. Even then AD-35 can only
be accepted as a collaboration contract/documentation-validation boundary;
it must not mark any implementation task accepted or raise physical or
R01–R10 credit.
