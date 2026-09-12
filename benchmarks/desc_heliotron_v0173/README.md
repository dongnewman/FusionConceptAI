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
L1 uniform pointwise bounds for every discarded profile and boundary term.
