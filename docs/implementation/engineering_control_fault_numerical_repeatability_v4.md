# ECF numerical repeatability V4

This additive edge consumes the current trusted G3 operational request/receipt
and the typed `ecf-vuq-nonbridge-v1` record. It launches the repository child
runner twice in fresh Julia processes. Each process returns a typed-line
observation containing process identity, Julia executable/version and hashes of
the child source and Project/Manifest pair, plus trace/result/count
observables. The parent reconstructs the request, validates the registry,
receipt and non-bridge, and requires distinct process IDs with identical
trace/result/count observables.

The result is a manufactured operational repeatability screen only. It grants
zero physical validation, numerical V&V/UQ, whole-device closure, evidence,
promotion or terminal authority; `claim_ceiling=screen_only` and credible
device count remain zero. Repeatability of this deterministic control trace is
not generic VVUQ evidence.

Reuse decision: extract the existing trusted ECF registry/request/receipt
validators and trace fields; wrap them in a new typed repeatability request,
observation and result; reject coercion of the non-bridge into generic VVUQ
evidence or reuse of historical campaign outputs.

Commands:

```text
julia --startup-file=no --project=. test/runtime_v4_ecf_numerical_repeatability_tests.jl
julia --startup-file=no --project=. scripts/run_v4_ecf_numerical_repeatability.jl
```
