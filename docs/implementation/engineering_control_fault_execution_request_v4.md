# EngineeringControlFaultExecutionRequestV4

This isolated request contract consumes a required externally revalidated `ForwardChainContextV4` and a validated `ConservativeMultiRegionContractV4`. Fault cases seal the context hash and `canonical_hash(context.scenario)`. Sites are derived from context-owned realization/control graphs, including node, AtomicMIMO edge, AST-root, and output identities. Capabilities are selected from context obligations; callers cannot inject a capability or site digest.

The request only matches typed provider manifests exactly and returns `ready_for_execution` or `recoverable_gap` for missing/ambiguous/foreign providers. It emits no evidence, pass, promotion, terminal unsupported, or credible-device status. No external solver runs.

Legacy equilibrium manifests/runners are extract-only for formulas and invariants; wrapping is limited to this typed request, test-only usage covers replay/negative controls, and old Dict/status/authority or manufactured outputs as physical evidence are rejected.
