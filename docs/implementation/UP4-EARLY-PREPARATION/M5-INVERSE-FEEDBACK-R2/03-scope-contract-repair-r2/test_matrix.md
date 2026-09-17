# Static test matrix — repair R2

| Check | Expected | Evidence |
|---|---|---|
| JSON parse | all 8 contract/registry/checker JSON documents parse | `raw/static_audit.stdout.raw` |
| closed schemas | every object schema declares `additionalProperties=false` | `raw/static_audit.stdout.raw` |
| local resolver | every external ref is an absolute registered URN; registry paths and hashes are explicit | `resolver_registry.json`, static audit |
| valid screen gate | schema branch requires replay count 2, unique attempts, `[0,0]`, equal bytes/semantics and fresh authority | `output_schema.json`, `checker_contract.json` |
| canonical join | equality and canonical digest pointers are explicit and fail-closed | `checker_contract.json` |
| CAS/history | version, identity, sequence, digest and UTC invariants are explicit | `checker_contract.json`, `output_schema.json` |
| taxonomy closure | record and taxonomy enums must be exact same sets | static audit, `checker_contract.json` |
| dependency closure | 6 source/test/oracle + composition role + Project/Manifest hashes | `manifest.json` |
| dirty closure | review-start per-path baseline and review-end additive comparison are required | `manifest.json` |
| runtime prohibition | no Julia/DESC/S3/mesh/solver/provider/network/hardware command | raw/process receipt |

This is a contract audit. It is not an implementation, replay, scientific validation, engineering acceptance, or physical result.
