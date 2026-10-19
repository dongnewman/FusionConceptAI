# UP4-03 reference-data v2

This directory is a versioned preparation handoff for `UP4-03-REFERENCE-DATA`.
It is not an inverse solver and it does not close formal UP4-03, B03, B07B, or
the parent goal.  `reference_manifest.json` binds the acquired first-party
bytes to source URLs, UTC access time, file sizes and SHA-256 hashes.

## Acquired first-party bytes

FAIR MAST shot 30421 and the independent shot 30420 were obtained from the
official catalog and S3 endpoint:

* [shot 30421 metadata](https://mastapp.site/json/shots/30421)
* [shot 30421 signal catalog](https://mastapp.site/parquet/level2/signals?shot_id=30421)
* [shot 30421 Zarr schema](https://s3.echo.stfc.ac.uk/mast/level2/shots/30421.zarr/zarr.json)
* [shot 30420 metadata](https://mastapp.site/json/shots/30420)
* [shot 30420 Zarr schema](https://s3.echo.stfc.ac.uk/mast/level2/shots/30420.zarr/zarr.json)

Each shot includes raw Zarr-v3 chunks for `thomson_scattering/n_e`, `t_e`,
`major_radius`, and `time`, not only metadata.  The acquired raw schema reports:

| array | raw unit | dimensions | status |
|---|---|---|---|
| `n_e` | `1 / m ** 3` | `major_radius,time` | real raw chunk acquired |
| `t_e` | `eV` | `major_radius,time` | real raw chunk acquired |
| `major_radius` | `m` | `major_radius` | real raw chunk acquired |
| `time` | `s` | `time` | real raw chunk acquired |

The catalog parquet still reports `eV` for `n_e`.  This package preserves that
conflict instead of rewriting it.  The raw Zarr unit is usable for a future
loader (`m^-3`, identity conversion); no raw normalization or scale field is
declared.  The root cause of the catalog conflict is not proven by these
responses, so measurement uncertainty and formal inversion remain
`typed_absent`/`not_executed`.

The catalog/raw identity also differs in shape and dimension order for shot
30421: the catalog listing reports `[146, 120]` with `[time, major_radius]`,
while raw Zarr reports `[121, 135]` with `[major_radius, time]`.  For shot
30420 the catalog parquet bytes were acquired but did not decode with the
local parquet reader, so catalog shape/dimensions remain typed absent while
raw Zarr reports `[121, 77]`.  Both records carry
`root_cause_status=unproven`; no reshape, transpose, resampling,
normalization, or scale is applied.

Shot 30420 is reserved as an independent held-out shot.  The current package
has two calibration observations and two held-out observations, no validation
shot, and therefore does not meet the formal minimum of eight calibration and
four held-out combinations.  No held-out score is reported.

## Layer and protocol boundary

`inverse_protocol.json` freezes known coordinates, unknown `theta` slots,
G1/G2/G3 field mapping, observation-operator names, units, raw-NaN masking,
eight multi-start initializers, optimizer stop rules, leakage rules,
identifiability outputs and the split.  It deliberately contains no fitted
parameters, posterior, recovery error, optimization trace, forward receipt or
held-out prediction.

The G3 metadata mapping names only raw keys actually present in the acquired
shot JSON: `plasma_max_current` and `plasma_time_avg_current`.  Their values
are not copied into theta or a Genome, and their units remain unresolved.

* ITER remains a first-party design reference with `electrical_generation=false`;
  its 500 MW/50 MW/Q=10 values are design targets, not measurements.
* DESC HELIOTRON remains a numerical reference only.
* C-2W is `typed_absent` because no machine-readable shot or diagnostic schema
  was obtained.

## Reproducible checks

From the FusionConceptAI repository root:

```powershell
python -B benchmarks/reference_data_v2/validate_reference_data.py
python -B -m unittest benchmarks/reference_data_v2/test_validate_reference_data.py -v
```

The checker validates every raw-file hash and byte count, shot IDs, Zarr-v3
schema, units/dimensions, non-empty chunks, candidate-independent split, and
anchor-copy rejection.  A successful checker result is a preparation-package
receipt only; the formal observation/inverse consumer has not been run.
