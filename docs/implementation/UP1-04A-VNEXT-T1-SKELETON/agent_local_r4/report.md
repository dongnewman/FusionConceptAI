# UP1-04A VNext T1 skeleton — agent-local R5

Status: `prepared_not_executed`; claim ceiling: `contract_only`.

This repair is limited to the two additive T1 declarations and this agent-local
static QA directory. No Julia, DESC, provider, mesh, solver, or runtime test was
run, and no commit was made. Existing dirty worktree paths were preserved.

## Contract repairs (R5)

- `_vnext_t1_snapshot` accepts exactly `()` or
  `(:g3_child_terminal_deferred,)`; unknown, duplicate, multiple, or
  child/gap-inconsistent states fail closed. The accepted child gap remains a
  typed absence boundary.
- The package and admission result use the closed
  `VNextT1NoLegacyReceiptV1`, with zero legacy refs, candidate-identity hash,
  receipt hash, and candidate join. No old v5 migration receipt or factory is
  referenced.
- Package-owned schema, canonicalization, and profile versions and hashes are
  explicit fields and are included in `package_hash`, independently of the
  three layer-derived hash tuples.
- Feedback is required to be a unique, target-id canonical tuple before T1
  projection. Present child envelopes require closed kind/source/source-hash
  joins (and validate optional typed candidate/child/declaration refs); absent
  children retain only the typed status/reason/receipt/source-path boundary.
- A known child gap requires exactly three children in
  `realization/control/binding` order and all three must be typed-absent; no-gap
  requires the same order with all three typed-present. Mixed or reordered child
  states fail closed.
- T1 independently checks fixed factory IDs/versions and frozen per-layer
  contract refs (including the three frozen G3 child contracts) before
  accepting either receipt, so a self-consistent forged receipt is rejected.
- Every T1 receipt/declaration/child projection owns immutable tuple bytes via
  `VNextT1CanonicalBytesV1`; mutable T0 `Vector{UInt8}` fields are not retained,
  and the owned byte hash is rechecked.

## Static evidence

Command (PowerShell only):

```text
pwsh -NoProfile -File docs/implementation/UP1-04A-VNEXT-T1-SKELETON/agent_local_r4/static_qa.ps1
exit=0
STATIC_NEGATIVE_MATRIX=16
STATIC_QA=PASS
RUNTIME=NOT_RUN
T0=UNRESOLVED
T1=PREPARED_NOT_EXECUTED
```

The matrix is assertion-only. It does not fabricate a valid package and gives
no runtime, physical, engineering, provider, or authority credit.

## SHA-256

| path | SHA-256 |
|---|---|
| `src/Contracts/CandidateStatePackageV5Next.jl` | `43792D4EB0A5B7E7777A8BF649E104A212DAA72DDCA368588104C4B001F3FC53` |
| `src/GenomeV5/Integration/VNextGenomeV5Integration.jl` | `77E331E39619CAC34A1699A2C7C84237F312F413784004F9F1BFFADC1DED55A9` |
| `agent_local_r4/static_qa.ps1` | `D763869775B48DA37D2F7B75E7D64B78844E68AFAAB11A41557D9C610B7125D0` |
