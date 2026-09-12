# DESC HELIOTRON external-simulation reference distributed in v0.17.3

This directory freezes the `HELIOTRON_output.h5` artifact distributed by the
official DESC `v0.17.3` release.  The artifact is source-backed and contains a
solved fixed-boundary equilibrium with boundary geometry, toroidal flux,
pressure, and rotational-transform profiles.  It is useful for N2
representation and same-subject code-to-code work.

The distribution tag is not the producer identity.  The HDF5 root and all four
family members embed `0.17.1+38.g53ea59ef0.dirty`; normalization selects member
index 3 and records that index, the family count, the embedded producer string,
and the separate DESC 0.17.3 loader runtime.  The old r1 result omitted this
distinction and must not be used as a trusted typed input.

It is not experimental data, an independent solver result, an inverse result,
or held-out validation.  The normalizer therefore fixes physical validation to
`unsupported`, inversion readiness to false, and credible-device count to zero.
Display names are outside the physics-bearing subject hash.

Run the normalization with the declared DESC loader runtime:

```powershell
& 'D:\006-Programing\LMC\outputs\fusion_concept_ai\.venv-desc\Scripts\python.exe' `
  benchmarks/desc_heliotron_v0173/normalize_reference.py `
  runs/<new-run>/n2_desc_heliotron_normalize/result.json
```

The source manifest records the official release URL, tag commit, MIT license,
artifact byte count, and SHA-256.  Any artifact or producer-version mismatch
fails before normalization.  The normalized result also reports conservative
L1 uniform pointwise bounds for every discarded profile and boundary term. Its
v2 schema carries the exact compact, sorted Python canonical subject JSON as a
wire field, allowing the Julia boundary to recompute the declared subject hash
without assuming that Julia and Python format floating-point JSON identically.

The separate `normalize_interior.py` freezes selected member 3's complete
source-owned Fourier-Zernike R/Z interior without dropping small modes. It
preserves every HDF5 `(l,m,n)` and coefficient in stored order, `fringe`
indexing, R cosine/Z sine symmetry, source resolution and exact canonical
subject wire. Run it in the pinned environment with a new output directory:

```powershell
& 'D:\006-Programing\LMC\outputs\fusion_concept_ai\.venv-desc\Scripts\python.exe' `
  benchmarks/desc_heliotron_v0173/normalize_interior.py `
  runs/<new-run>/n2_desc_heliotron_interior/result.json
```

This is source representation only. The radial degree `l` is not a `rho^l`
power law. No Julia typed Fourier-Zernike evaluator, geometry proof, DESC
reexecution, independent spatial comparison, inverse recovery, or physical
validation is granted by extracting these arrays.

`evaluate_interior.py` reconstructs scalar R/Z independently with SciPy Jacobi
polynomials and explicit DESC positive-cosine/negative-sine mode semantics.
`compare_interior.py` records five frozen internal/boundary nodes, compares
against the selected DESC basis evaluation with a predeclared `1e-9 m`
absolute tolerance, and exits 4 if any node fails. This is same-family
geometry-basis numerical verification only. It is not an independent
equilibrium solver, derivative proof, RuntimeV4 typed interpreter, or physical
validation.
