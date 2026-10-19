# FAIR-MAST Level-1 expansion adapter v1

This additive adapter consumes the preselected M9 Level-1 AYC packages without
changing the frozen two-shot Level-1 or Level-2 adapters. It loads exactly one
released split per invocation:

- calibration: shots `30463, 30468, 30459, 30462, 30464, 30460, 30456, 30466`
- validation: shot `30469`
- held-out: shots `30471, 30467, 30457, 30458`, release required
- reserve: shots `30461, 30470, 30465`, release required

One shot-level paired AYC `ne`/`te` bundle is one combination. Channels and
cells do not inflate the combination count. The present package therefore has
8 calibration combinations and 1 validation combination. It does not have a
released held-out set and does not meet the formal reference-validation split.

## Frozen control plane

The loader requires these exact SHA-256 identities:

| Input | SHA-256 |
|---|---|
| `reference_data_level1_expansion_v1/selection.json` | `b962c135e1569457e80efb5ab05842d73b05347ffd56732bf465f8869fa04c78` |
| `acquisition_index.json` | `a3750fd5a7b0ad8fdfb865feeb981c05633cfab5b0d80bf8c4dd1f549bc7e045` |
| repaired Level-1 helper | `7dcdd5c49815e7fd166ad958a9441abd71e15ebf981fccaf3e0b37038635d9af` |
| `protocol.json` | `1331869e56117ff331decb8fb11c5bf863d3d9f190379e1cb624c3048d53878f` |

The acquisition index contains paths only for calibration and validation. A
held-out or reserve request raises `expansion_split_release_required` before
the protocol, selection, index, or source paths are opened. A future release
requires a new post-optimizer manifest and adapter version.

## Executed mapping and integrity

The adapter reuses the independently reviewed Level-1 raw decoder and hashing
helpers. For every indexed shot it verifies:

- acquisition receipt and consolidated Zarr metadata hashes;
- receipt metadata and attributes against the consolidated metadata;
- raw and compressed file hashes, little-endian float32 storage, chunk shape,
  dimensions, units, finite counts, and extrema;
- provider grids, increasing time, radial index, dynamic radius, and instrument
  coordinate arrays;
- a read-only boolean joint observation mask;
- live source records against the frozen acquisition index;
- live array bytes against the indexed raw hashes at every consumer boundary;
- canonical payload and per-cell lineage identities before iteration or output.

The identity mapping is
`canonical[time, radial_index] = raw[time, radial_index]`. There is no
resampling, imputation, scale, or offset.

The metadata-only index check finds no calibration/validation reuse of the five
response/error arrays (`ne`, `te`, `ne_error`, `te_error`,
`covariance_ne_te`). Coordinate and instrument artifacts are shared, so the
strict any-artifact policy remains `terminal_deferred`.

## Public API and CLI

`manifest_adapter.py` exposes:

- `inspect_selection_manifest(split)`
- `load_expansion_split(split, ...) -> ExpansionPackage`
- `validate_expansion_observation(observation)`
- `validate_expansion_no_leakage(observations, split)`
- `validate_expansion_package(package)`
- `iter_expansion_cells(observation)`
- `write_expansion_package(package, output)`

Run the two released splits separately:

```powershell
python -B benchmarks/reference_validation_expansion_v1/manifest_adapter.py `
  --split calibration `
  --source benchmarks/reference_data_level1_expansion_v1 `
  --output <new-calibration-output>

python -B benchmarks/reference_validation_expansion_v1/manifest_adapter.py `
  --split validation `
  --source benchmarks/reference_data_level1_expansion_v1 `
  --output <new-validation-output>
```

## Claim boundary

`ne_error`, `te_error`, and `covariance_ne_te` are consumed as reported values
on their own Level-1 grid. Blank error units and absent provider statistical
semantics are preserved. They are not standard deviations, covariance-ready
weights, or a likelihood. `require_likelihood_ready()` always rejects with
`expansion_error_semantics_unknown` after validating current content.

The adapter is data preparation only. Calibrated diagnostic response, formal
inverse execution, B03, B07B, physical independence, ITER measurement status,
and parent UP4-03 acceptance remain deferred.
