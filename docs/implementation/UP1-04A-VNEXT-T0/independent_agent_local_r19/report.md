# T0 LocalV1 independent R19 review

## Verdict

**GO for one serial agent_local Julia recheck.** This is only a runtime-gate
recommendation; acceptance remains `false` and `contract_only`. This review did
not run Julia/DESC and did not edit product/test files.

R18's exact failure was `source edit locator ref mismatch` at the product
boundary. The current test calls the product helper exactly:

```julia
G._vnl_t0_edit_ref(declarations[1].source_ref, edited_source.sha256, :source)
```

It also constructs the old `#r8-source-` spelling separately and asserts it is
different from the product-derived ref. R18 internal diagnostic,
`catch_backtrace()` logging, public `errors == ()`, valid/non-`nothing` guards,
and original success expectations remain present. Static QA requires all of
these tokens.

## Evidence

```text
python -B docs/implementation/UP1-04A-VNEXT-T0/static_qa_local_v1.py
exit=0
status=pass
accepted=false
claim_ceiling=contract_only
julia_executed=false
desc_executed=false
fixture_authority=false
```

R18 raw artifact hashes were independently recomputed from
`runs/agent_local_up1_04a_vnext_t0_20260918_r18_diagnostic`:

- `run.json`: `fbcdf94d74f5c75a0e1981e6f475fac06edd1ce06996c345d2ff858dda7aa18e`
- `stdout.txt`: `f4b500e55a35307cec642b3962b314da0ee5635e8250322c9cfc8b4991221089`
- `stderr.txt`: `07e90bf767712c1668b7677555eb4d7cc39d7e86d93c5b52a7c372e3e00b9e2a`

The current R19 ten input hashes match the R19 agent freeze. Product source
hash remains the R16 value `efeae311...ec8e`; legacy T0/shared entry/registry/
task manifest hashes remain unchanged. No commit was made.

## Permitted next command

```text
julia --startup-file=no --history-file=no --project=. test/GenomeV5/Integration/vnext_declaration_transport_local_v1_tests.jl
```

Run once, serially, into a fresh output directory. No T0/T1/T2 or R01-R10
credit is implied.

## Current ten input hashes

| path | SHA-256 |
|---|---|
| `src/GenomeV5/Integration/VNextDeclarationTransportLocalV1.jl` | `efeae3112009b0e8d4b0902bb0c0da305b49bba40a919b1c4fd24b68f336ec8e` |
| `test/GenomeV5/Integration/vnext_declaration_transport_local_v1_tests.jl` | `f288da66084e74739629e54d80c83c286848f50aa9ad49b6e47f05a19e602f34` |
| `docs/implementation/UP1-04A-VNEXT-T0/vnext_declaration_transport_local_v1_fixture.json` | `b1028b4d21ad690491a24549e73de5507af31edf3b70bf9357b25c3a09c24460` |
| `docs/implementation/UP1-04A-VNEXT-T0/static_qa_local_v1.py` | `1879616b2ce1a800c1e39f01abe8c7c321cc6a2fd8f353ccf43747a13cb4d14e` |
| `src/GenomeV5/Integration/VNextDeclarationTransportV1.jl` | `9cf9563b2e3b16b4c9111492a147581945809ccd982ec4e711f85682659ab716` |
| `test/GenomeV5/Integration/vnext_declaration_transport_v1_tests.jl` | `807837ce2a4aef4c196d0f4e2635201e9843f3532bc1afd94d667865569a976b` |
| `src/FusionConceptAI.jl` | `e3fa8638ed9c5c5f468ae9a8f797416f2bec19b432cc10a9c1aea81ec3460783` |
| `src/IR/OperatorRegistry.jl` | `4c2f4383140527613782288749283d268497846ec915df158164875125677f45` |
| `src/Contracts/GenomeContractRegistry.jl` | `ee57228623e314897a3e34f3bfd387e8cce4d89c2b0dfaaf29d227076a08495c` |
| `docs/v4_multitopology_generation/task_manifest.json` | `84af082ba5fff336dd89ae506f6b8e680f96f0af2e657ae926d6e9cc666fd6ad` |
