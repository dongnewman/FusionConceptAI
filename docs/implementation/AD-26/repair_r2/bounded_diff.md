--- AD-26 R2 bounded diff ---
File: docs/v4_multitopology_generation/18_sources_and_architecture_decisions.md
Scope: first AD-26 decision paragraph only.
Before:
Sol 裁决：E1 的 typed authored N05 declaration 与 E2 的 typed authored N06 mapping 只能在 actual A + accepted-limited E0 bound-input identity 之后作为 additive、candidate-owned、content-hashed extensions 产生。E0 v1 的 `n05`/`n06` 字段仍必须为 `nothing`；原 `CandidateStatePackageV5.candidate_hash`、E0 `binding_hash` 与 E0 `bound_input_hash` 不回写、不重算、不就地补字段。G-I1 可以定义独立、版本化的 authority-context hash；其输入必须显式包含完整 same-candidate A/E0 refs 与 hashes，以及 E1/E2 extension hashes，或带 schema/canonical/profile hash 的 typed absent marker。任何 ref、hash、extension、absent marker、schema、canonicalization 或 profile 变化都必须重建 context identity。

After:
Sol 裁决：E1 的 typed authored N05 declaration 与 E2 的 typed authored N06 mapping 只能在 actual A + accepted-limited E0 bound-input identity 之后作为 additive、candidate-owned、content-hashed extensions 产生。E0 v1 的 `n05`/`n06` 字段仍必须为 `nothing`；原 `CandidateStatePackageV5.candidate_hash`、E0 `binding_hash` 与 E0 `bound_input_hash` 不回写、不重算、不就地补字段。G-I1 可以定义独立、版本化的 authority-context hash；其输入必须显式包含完整 same-candidate A/E0 refs 与 hashes，以及独立的 E1/E2 extension content hashes。每个 present E1/E2 extension payload 与每个 typed absent marker 都必须在 context payload 中显式携带自身的 `schema_hash`、`canonicalization_hash` 与 `compatibility_profile_hash`；extension content hash 是独立输入，不能由这些字段的相似命名或隐式默认值代替。任何 ref、hash、extension content、absent marker、schema、canonicalization 或 profile 变化都必须重建 context identity。
