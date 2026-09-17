# Multi-region coupling contract report — 2026-09-09

## Outcome

Added a sealed bounded typed admission contract under RuntimeV4. It stores and revalidates candidate prefix, candidate bundle, mission, bounds, and G1 mechanism graph identities. Exact region node and interface edge/node/output-port bindings are checked against typed AST/hyperedges, including ledger identity, `UnitSignature`, signs, opposite coefficients, and required channel declarations.

## Evidence boundary

The focused test uses a synthetic AST/hypergraph fixture solely to test type behavior and an actual public compiler fixture for candidate-bound negative admission. The public fixture does not preserve an interface edge, so the test records the precise recoverable `:deferred` gap instead of raw-constructing a fake compiled candidate. No legacy Genome or authority path is used.

## Exact gaps

The module does not assemble residuals, discretize regions, run a monolithic or domain-decomposed solve, audit numerical conservation values, provide material/geometry validity domains, or connect an evidence provider. Therefore integration remains `screen_only`; a real candidate with missing typed edges or backend capability returns `:deferred` and preserves typed gap strings.

## Integration acceptance

Include the module after RuntimeV4, construct it from the real `CompiledCandidatePrefixV4` and G1-bound `AtomicMIMOHyperedgeV1` objects, then validate. Acceptance must use an actual candidate and graph; the synthetic focused fixture must never be counted as physical evidence.
