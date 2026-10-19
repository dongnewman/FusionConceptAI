# UP4-03-REFERENCE-VALIDATION-PREC public metadata audit

Observed 2026-09-30 from `63792ca22958ffca8c3fa8e642256eb9f7240724` in a broadly dirty worktree. This is a read-only source audit and a new, scoped audit helper. Existing raw arrays, catalog snapshots, split, protocols, adapters, and historical receipts were not changed. No signal chunks, Julia, DESC, FreeGS, inverse, or physical solve were run.

## Reproduction and actual exit codes

From the repository root:

```powershell
python -B benchmarks/reference_validation_v1/audit_public_metadata.py
# exit 0; 20 JSON lines; every HTTP response 200

python -B -m unittest discover -s test/reference_validation_v1 -p "test_*.py" -q
# exit 0; 44 tests in 9.655 s
```

The helper only reads frozen local metadata and performs bounded HTTP GETs of public `.zarray`, `.zattrs`, Level-2 `zarr.json`, and catalog Parquet bytes. It prints URL, response size, SHA-256, field identity, and comparison with the frozen input. Exit 0 means the audit completed; it does **not** mean source identities agree or scientific semantics are established. Source mappings and the helper's exact code should receive a separate review before use in any formal consumer.

## Observed identities

| Shot | Source/field | Public shape and order | Frozen shape | Catalog shape and order |
|---|---|---|---|---|
| 30421 | Level 1 `ayc/ne`, `te`, `ne_error`, `te_error`, `covariance_ne_te` | `[284,131]` `[time,radial_index]` | same | different Level-2 product |
| 30420 | same Level 1 fields | `[73,131]` `[time,radial_index]` | same | different Level-2 product |
| 30421 | Level 1 `efm/fcoil_c`, `fcoil_x` | `[120,101]` `[time,fcoil_n]` | same | not a signed P6 segment map |
| 30420 | same EFM fields | `[64,101]` `[time,fcoil_n]` | same | not a signed P6 segment map |
| 30421 | Level 2 `thomson_scattering/n_e`, `t_e` | `[120,283]` `[major_radius,time]` | `[121,135]` | `[146,120]` `[time,major_radius]` |
| 30420 | same Level 2 fields | `[120,73]` `[major_radius,time]` | `[121,77]` | `[88,120]` `[time,major_radius]` |

All 28 public Level-1 `.zarray/.zattrs` responses matched the frozen consolidated Level-1 metadata by decoded JSON value. The live Level-2 `zarr.json` differs in bytes from both frozen shot snapshots: 30421 `b6ffe2e2e0ebae184419de63e3db6977c7c921304f9ce0162b40f5944dcc3bea` (791009 bytes), 30420 `b1f29c28f0c25f5768a21889f2ec45ebc4243e626aa4743845dc58eb33ccd637` (783496 bytes). The current catalog Parquet bytes **still match** the frozen files: 30421 `9acf41968cac2f3fa84d0a1b05342d60140e5878985fb8bec2f25a6c8867cadd` (19913 bytes), 30420 `cded31bbb75166fa90a789e1590952892d6281717dac894843025b018d1a2cb7` (19599 bytes). No cause or ingestion sequence follows from these comparisons.

The Level-2 catalog assigns `n_e` unit `eV` and UUIDs `f0b586cd-11ea-5208-927b-4e4f057a6c44` (30421), `840b0b88-f61e-5cff-be2f-a1efd94a608b` (30420); both live and frozen Level-2 arrays declare `1 / m ** 3` and have no `uuid` attribute at the array node. The catalog `t_e` unit is `eV`; its UUIDs are `6e2f4faf-7eb6-5f9e-a8a3-f0869af4abbf` and `c7262bd0-cba4-5bf4-b0bf-4dfb16c0c207`. The Level-1 `ayc/ne` UUIDs are `11d48997-7fcf-527b-8b99-7646b57db603` and `0141808d-ccda-5bce-917c-2eebd553f22f`. These are different products; equality across Level 1 and Level 2 is not an identity rule. Catalog UUIDs cannot resolve the mismatched Level-2 shapes or identify a raw channel ordering.

The Level-1 `ne_error` and `te_error` unit strings remain empty for both shots. The `covariance_ne_te` label carries `eV / m ** 3`, but the current public metadata does not define its estimator, calibration, confidence convention, or applicability to the selected Level-2 profiles. `efm/fcoil_c` and `fcoil_x` declare amperes and `[time,fcoil_n]`, without a signed circuit-to-segment/P6 polarity rule.

## One-party source interpretation and boundary

The [UKAEA FAIR-MAST service](https://www.ukaea.org/service/fair-mast/) describes the public catalog and Zarr archive. The pinned [UKAEA Level-2 ingestion mapping](https://github.com/ukaea/fair-mast-ingestion/blob/608419fde2969ae05ef6f095c323589c24047a2e/mappings/level2/mast.yml) (raw response SHA-256 `70bb5fedfea1c9c2ac3ca5fe5980a5932233d40f7572d50f1f1fc9f6a229a295`, HTTP 200) maps `EFM_FCOIL_(X)/(C)` and `AYC_NE/TE/R` names but does not define signed P6 assembly, shot channel lineage, detector calibration, or covariance construction. The maintainer's [raw core Thomson issue #140](https://github.com/ukaea/fair-mast-ingestion/issues/140) remained open on inspection and identifies scheduler scripts as a potential calibration source, not a retrieved definition.

The existing frozen adapter can supply shot/split/channel IDs, raw and canonical shapes, axis permutation, `n_e`/`t_e` values, finite masks, time/radius coordinates, source/catalog hashes, per-sample lineage, an exact-grid sample projection, and explicit Level-1 error-labelled values with unknown statistical semantics. These are preparation fields for a future formal UP4-03 loader. Its Level-2 values remain bound to the **frozen** raw chunks, not the changed public Zarr identity. The existing 30421 calibration and 30420 held-out split has no validation shot and remains below the frozen 8/4 formal minimum.

Still required before `F/H/y/Sigma` or a weighted likelihood: a first-party EFM/P6 signed per-segment current/index/polarity definition and independent known-current response; AYC shot-specific channel IDs/order and source bytes; calibration script/version, coefficients and validity rules; error and covariance estimator, units/statistical convention and applicable observation alignment; provider explanation/version binding for the conflicting catalog, frozen Level-2 and live Level-2 identities; and the required validation/held-out coverage. No live arrays were joined to frozen arrays. Status remains `typed_absent`, `no_likelihood`, `no_inverse`, with formal UP4-03 and parent Goal unaccepted. Independent review of this audit and any later semantic binding is pending.
