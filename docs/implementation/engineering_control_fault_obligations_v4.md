# Engineering/control/fault obligations V4

This isolated contract consumes a required, externally revalidated `ForwardChainContextV4`. It binds controller, actuator, and observation obligations to owned typed graph roles, and records limits, delay, dropout, fault mode, recovery timeout, provider capability, and evidence class.

Missing graph ownership or recovery remains `recoverable_gap`; callers cannot self-report evidence, promote, emit terminal unsupported, or claim a credible device. The contract is an execution request, not an evidence issuer.

The rejected prototype was audited read-only. Its optional context, caller-provided status/evidence references, and unsupported terminal decisions are not reused.
