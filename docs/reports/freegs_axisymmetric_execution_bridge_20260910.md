# Runtime V4 FreeGS axisymmetric bridge execution report — 2026-09-10

## Result

The new isolated bridge executed the pinned local FreeGS 0.8.2 process on a
canonical solver input derived from the current typed G2 declaration in the
current `ForwardChainContextV4.subject.bindings`. The integration command and
the backend both exited 0, and the output artifact status is
`physical_model_screen`.

This is a physical-model execution screen for one manufactured current
fixture. `physical_validation=false`, `engineering_validation=false`,
`p5_ready=false`, `terminal_authority=false`, and the claim ceiling is
`screen_only`. The credible physical-device count remains zero.

## Current subject binding

- context hash: `7cd47afac3d66aaeee98e25358df4cbfef7055dc22506d831f8fca51778ea91a`
- physical subject hash: `a808316bba196c0611267290d8e6e49e1812d2f6b5ad6bcee2761094f2afd6a3`
- G2 graph hash: `6e7f49b91455bd0863dc48a8d8a390268e27acc8394dd01896802cd0e4d9e15a`
- typed subject binding hash: `ade7129ab96319dc58743ea3b00eae343228101e679b59d0844c56eb2832c8c2`

The declaration is owned by the current G2 `fields` tuple. The subject binding
adds the exact G2 graph/forward-graph identity and frozen mission, bounds, and
scenario hashes. The canonical JSON is generated only after full external
revalidation of `ForwardChainContextV4`; no historical candidate result is an
input.

## Real execution

Command:

```powershell
julia --startup-file=no --project=. scripts/run_v4_freegs_axisymmetric_execution.jl
```

Definitive Julia exit: `0`. Backend exit recorded in the receipt: `0`.
Artifact status: `physical_model_screen`. FreeGS version: `0.8.2`.

Captured identities:

- controlled runner code SHA-256: `e7d7881e1454490ec61a445ae70aebecbdcac953d6fa1614a66fe1b40b5447f0`
- environment hash: `227f3a383b03e6538bfb6963bd7f519ed9fb0bbc41fb6c2f359af41311b5c8c9`
- exact canonical input SHA-256: `20a0baf6b577178471dd4c7607739534b0c732e93d7263cc2692f500cae45e59`
- exact output SHA-256: `69265b169c16ff309fd273fe107ccc8971cc5169dfbd3bcaf6c78271f3af51e9`
- receipt hash: `fc8bbb78458599eaf3264d1ce75efcda2b21807f80790ea9a23076c085221866`

The runner emitted the same exact-output SHA-256 on stdout. Julia recomputed
it from the bytes read from `solver_output.json`; equality was required before
the artifact could receive `physical_model_screen`.

Numerical output:

| Metric | Value |
|---|---:|
| nonlinear iterations | 44 |
| final relative flux change | `6.520571334556568e-5` |
| independent plasma GS residual, relative L2 | `0.0038256324736742047` |
| magnetic axis R | `1.2761720582450737 m` |
| magnetic axis Z | `0.03944858937557901 m` |
| plasma current | `999999.9999999999 A` |
| plasma volume | `5.167506682676912 m^3` |
| q95 | `0.7786646698939796` |
| betaN | `0.2433488675999888` |

These values show that the controlled process really executed the declared
model. They do not establish agreement with experiment, solver independence,
grid convergence, stability, transport, coupled multi-region closure,
engineering feasibility, or device validation.

## Verification

The focused test executes the real pinned interpreter; it has no solver test
double in its integration evidence.

```text
typed G2 axisymmetric declaration and subject binding: 11/11 pass
strict typed FreeGS input and negative boundaries:      16/16 pass
real pinned FreeGS integration is screen-only:          15/15 pass
focused command exit:                                   0
ForwardChainContext focused regression:                  72/72 pass, exit 0
conservative multi-region focused regression:           117/117 pass, exit 0
controlled Python source syntax check:                   pass, exit 0
```

The added negative check mutates the output text after capture and confirms
that the stdout/output hash mismatch is rejected before success.

If the pinned interpreter, FreeGS dependency, or controlled runner is missing,
or if the solver/output cannot be accepted, the bridge records
`recoverable_gap_unknown`. It never emits terminal `unsupported` or permanent
pruning.
