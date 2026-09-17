# PhysicalProviderAdmissionV4

This isolated contract admits a typed real external provider request only. It consumes and externally revalidates `ForwardChainContextV4` and `ConservativeMultiRegionContractV4`, derives control-graph observable requirements from the context subject/mission/bounds/scenario, and requires backend, version, code, dependency, input-schema, applicability, and independence declarations.

It performs no external solver execution and emits no evidence. Missing or ambiguous provider capability remains recoverable. Manufactured-control providers and legacy family/name/candidate-ID routing are rejected.

Legacy audit boundary: old equilibrium runners and `high_fidelity_solver_portfolio_v92` are extract-only for formulas/invariants; wrapping is limited to this new typed admission; test-only use is replay/negative intent; old Dict/status/authority, manufactured results as physical credit, and historical output as physical evidence are rejected.
