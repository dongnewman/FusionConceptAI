# Trusted provider registry V4

## Scope and threat boundary

`TrustedProviderRegistryV4.jl` is an isolated provenance and integrity layer
for repository-owned executor dispatch. It prevents an arbitrary
`ProviderManifestV4` plus a caller closure from becoming ready merely because
the public manifest fields match a capability.

This is not a hostile same-process security sandbox. Julia code running in the
same process can inspect private names, mutate method tables, alter files, or
terminate the process. The trust assumption is an explicit bootstrap performed
against a pinned checkout before untrusted extension code runs. Revalidation
then detects source, method-table, descriptor, registry, manifest, context, and
receipt drift. OS process isolation, signatures, and deployment-time policy
remain future outer controls.

Private constructors and `Val(:trusted_repository_bootstrap)` communicate API
intent; neither is treated as security authority. Authority comes from the
fixed repository descriptor and identities recomputed from the validated
bootstrap root.

## Trust construction

The bootstrap has no caller descriptor parameter. It resolves the built-in
descriptor from the fixed repository-relative source path and entrypoint, then
recomputes:

- source-file SHA-256;
- loaded executor method module, signature, repository-relative source path,
  and source line;
- `Project.toml` and package-entry source hashes;
- descriptor, repository, registration, and registry content hashes.

The current built-in executor is deliberately harmless and `test_only`; it
exists to exercise the trust mechanism without claiming a physics provider.
Adding a production provider requires an independently reviewed built-in
descriptor and is not authorized by caller input.

## ProviderManifest separation

The package-level `ProviderManifestV4.manifest_hash` excludes the executor, and
its global executor binding can be first-bound by earlier code. The trusted
layer therefore does not trust either a claimed `code_hash` or the manifest's
executor field:

1. code hash must equal freshly hashed repository source bytes;
2. backend, revision, independence group, kind, model class, and complete
   context/subject/scenario domain must equal the descriptor policy;
3. manifest executor identity must equal the descriptor-resolved repository
   function, and the current descriptor function's method-table hash must equal
   the bootstrapped runtime hash;
4. execution dispatches the descriptor executor, never a function chosen from
   caller input.

If a caller first-binds an otherwise identical manifest hash to a stub, later
trusted construction fails closed because the package registry detects the
conflicting executor. This can cause denial of service within that process, but
the stub is never substituted into a trusted registration.

## Context and readiness

Registration requires a capability that occurs exactly once in a fully
revalidated `ForwardChainContextV4`; its applicability bounds must equal the
compiled context bounds. The manifest domain seals the exact context,
materialized subject, selected scenario, descriptor, and model class.

`TrustedProviderDispatchRequestV4` accepts no manifest or executor. It becomes
`ready_for_dispatch` only when the validated registry contains one exact
registration for the context and capability. Missing or foreign-context
registrations remain `recoverable_gap`.

## Operational receipts and authority firewall

`execute_trusted_provider` revalidates the registry, context, registration, and
request immediately before resolving and calling the descriptor executor. Its
sealed `TrustedProviderExecutionReceiptV4` binds:

- registry and request hashes;
- provider registration and manifest hashes;
- input and output content hashes;
- operational exit code and `completed`/`executor_error` status.

These statuses describe process execution only. The receipt is not scientific
evidence and carries no physical-validation credit, closure, promotion, P5, or
terminal authority. External request and receipt validators require the
original registry/context inputs; one-argument validation fails closed.

## Legacy disposition

| Disposition | Material | Decision |
|---|---|---|
| Extract | RuntimeV4 exact capability matching and complete domain matching | Reuse only after adding a separately attested repository executor identity. |
| Extract | ForwardChainContext candidate/subject/scenario reconstruction | Make it mandatory at registration, request, and dispatch boundaries. |
| Wrap | repository source hashing and deterministic canonical hashes used by current providers | Wrap in a fixed descriptor and immutable registry chain. |
| Test-only | the built-in identity executor and declared structural-screen fixture | Exercises success and receipt binding; it confers no physical or scientific credit. |
| Reject | arbitrary caller descriptors, caller executors, or caller code hashes | They cannot enter the bootstrap descriptor set or trusted registration. |
| Reject | `ProviderManifestV4.manifest_hash` as executor attestation | It excludes the executor and is insufficient as a trust root. |
| Reject | legacy result/pass/unsupported decisions | Registry receipts contain operational status only. |
