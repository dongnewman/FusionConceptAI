# UP2-00 independent review r18

## Verdict

`accepted_limited` for the N01/N02 schema/value projection slice only. This is an independent review of the frozen r18 author snapshot; it does not accept UP2-00 as a whole and does not change the author manifest (`accepted=false`, `review_pending`).

## Frozen inputs and command

The reviewed author hashes were:

- `src/GenomeV5/UP2/TypedPrecompilerContractV1.jl`: `b63258ee4c26bb686c7c8fc711449b9f22af0a8234dc5e1a33ff271849cae1e0`
- `src/GenomeV5/UP2/TypedPrecompilerValidatorV1.jl`: `0557532f9921afabbd6cdcc190e216496807227ef802b3898bd0292b1e98150b`
- `test/GenomeV5/UP2/up2_00_contract_tests.jl` (r18): `df202198941d02a57d856435c31f37db82b08e3459d6140368154b42f316e50e`
- `docs/implementation/UP2-00/evidence_manifest.json` (r18): `4b0b5413c810915a8aa8e78ec8dd4577961ee18eb3fa834596c7656495569398`

The independent command was:

`julia --startup-file=no --project=. test/GenomeV5/UP2/run_up2_00_contract.jl`

It was started with no Julia or DESC process present, as PID `45236` at `2026-09-14T07:51:58.5193250+08:00` (+08:00), with Julia `1.10.5`. The sealed exit bytes are `30-0D-0A` (`0`), stdout is nonempty, and stderr is zero bytes. The process and environment records are in this directory.

## Review findings

`up2_projection_from_a(package)` reads the actual A package fields: G1 equation input/output ranks and units, the G1 state tensor rank, G2 embedding dimension and field-space shape/unit, and G3 resource/entry units. `up2_input_from_a` re-derives that projection and rejects a package hash, candidate reference, or projection hash mismatch. This makes the reviewed entrance source-backed for the limited slice.

The r18 actual-A test now iterates all ten N01/N02 fixture rows and, for each row, asserts a derived `:invalid_type`, the exact frozen field path, a changed `mutated_input_hash`, and zero compile/provider/solver counters. The validator’s `_up2_real_classification` derives these outcomes from mutated typed values and source relationships; it does not use `spec.expected_error` as a classifier or router. The same test also rejects evidence reuse. The independent runner reported `UP2-00 actual A package projection slice | 78 78` and the full runner exit was `0`.

The preceding r17 independent review artifacts were not rewritten: r17 acceptance remains SHA256 `6165c0ee66e49695a3117da9c155a46b78d65dea5e8318a972bcdb80b74668fe`, and r17 evidence remains SHA256 `ff88aace8b5833350eb838ad5b31c902d62051f795813f46c9f7890aa4af6e8b`.

## Boundaries

This limited pass covers typed projection/schema validation for N01/N02. The mutation seam changes the UP2 typed wrapper; it is not proof that the underlying G1/G2/G3 component bodies were rebuilt. The low-level `UP2PrecompilerInputV1` constructor remains synthetic/unverified and is not B04-admissible. N05 remains `terminal_deferred` because authoritative paired flux port/unit provenance is absent; N03, N04, and N06-N10 remain pending, leaving 40 of 50 mutation rows pending. The result has no provider, mesh, engineering, physical, B00, B04, or R01-R10 credit. `claim_ceiling=none` and `resolution=terminal_deferred` remain required.

The focused run is execution evidence for this contract slice only. It does not establish solver/provider invocation, physical realization, or the UP1-04B mutation envelope required by AD-21.
