# FAIR-MAST reference validation adapter v1

This directory is the executable preparation slice for
`UP4-03-REFERENCE-VALIDATION-PREC`. It consumes the protected source package in
`benchmarks/reference_data_v2/`; it does not alter its raw bytes, manifest, or
frozen shot split.

`reference_adapter.py` verifies every consumed source file, decodes the real
Zarr-v3 chunks, and maps the raw Zarr-encoded Level-2 Thomson profile arrays from
`[major_radius,time]` to canonical `[time,major_radius]`. The mapping is a
representation transpose driven only by the raw Zarr `dimension_names`.
Catalog rows are decoded separately with DuckDB and retained as conflicting
metadata: both snapshots report `[time,major_radius]`, different shapes, and
`eV` for `n_e`; their quality is `Not Checked`. The adapter neither reshapes to
the catalog nor assigns a cause to the conflict. The pinned Level-2 ingestion
mapping declares linear major-radius interpolation, so these values are
described as stored Level-2 profile cells rather than direct instrument
samples. The selected `n_e` unit comes from each acquired Zarr array's
attributes; the pinned `n_e` profile mapping does not declare that unit.

The public import surface is:

```python
load_reference_package(source_root, protocol_path)
load_mast_observation(shot_id, channel, split, source_root, protocol_path)
apply_thomson_sample_operator(observation, prediction, unit, radius, time)
validate_no_leakage(package)
validate_observation_integrity(observation)
validate_reference_package_integrity(package)
iter_canonical_samples(observation)
```

The operator is an idealized exact-grid sample projection. It selects the
finite stored Level-2 profile cells from a prediction already evaluated on identical time
and major-radius coordinates. It does not interpolate or implement a calibrated
spatial/temporal Thomson response. Those response terms and bound measurement
uncertainty are absent for the selected Level-2 profiles, so
`diagnostic_response_complete=false`, `likelihood_ready=false`, and formal `H`
is `terminal_deferred`.

First-party Level-1 products for shots 30421/30420 expose candidate AYC
error/covariance arrays on `[time,radial_index]` grids of `[284,131]` and
`[73,131]`; the selected Level-2 profiles use `[major_radius,time]` grids of
`[121,135]` and `[121,77]`. The Level-1
`ne_error`/`te_error` unit strings are blank, and the available metadata does
not establish sigma/covariance or calibration semantics for these Level-2
records. This adapter therefore prohibits index-based attachment and keeps
uncertainty typed absent within its stated Level-2 scope. A future binding must
be a new version with validated semantics and a provenance-preserving
alignment.

Run the real adapter from the repository root with a new output directory:

```powershell
python -B benchmarks/reference_validation_v1/reference_adapter.py `
  --source benchmarks/reference_data_v2 `
  --protocol benchmarks/reference_validation_v1/protocol.json `
  --output <new-empty-output-directory>

python -B -m unittest discover -s test/reference_validation_v1 -p "test_*.py" -v
```

The materialized package contains deterministic little-endian arrays, masks,
per-sample raw/canonical index maps and hashes, a decoded catalog snapshot, and
a split receipt. The split is disjoint by shot, observation response, time,
catalog row, and derived lineage. The two shots intentionally share an identical
major-radius coordinate artifact; this is declared as a non-response coordinate,
while the upstream strict any-artifact rule remains deferred. There is no
validation shot and the 8/4 formal minimum is unmet.

ITER remains a separate design reference and never appears in the MAST
measurement records. This slice does not run an inverse, construct a Genome,
claim B03/B07B/R02/R06 credit, or accept parent UP4-03.

First-party sources used for interpretation are frozen in
`source_evidence.json`, including the pinned UKAEA FAIR-MAST ingestion mapping
and the public Level-1 access documentation.

## Separate Level-1 error-data product

`level1_error_adapter.py` consumes the independently acquired shot packages in
`benchmarks/reference_data_level1_v1/`. It verifies each acquisition receipt,
Zarr metadata hash, compressed chunk hash, decoded raw-byte hash, shape,
dimensions, units, and recomputed finite-value statistics. It retains the
native `[time,radial_index]` layout and the dynamic two-dimensional `radius`
coordinate. It never joins these cells to the differently shaped Level-2
profiles.

The Level-1 public import surface is:

```python
load_level1_error_package(source_root, protocol_path)
validate_level1_observation(observation)
validate_level1_no_leakage(observations, protocol)
conditional_error_consistency(observation)
iter_level1_cells(observation)
write_level1_error_package(package, output)
```

The source contains real `ne_error`, `te_error`, and `covariance_ne_te` values.
The two error-unit strings are blank, and the pinned ingestion implementation
does not establish standard-deviation, confidence, or calibration semantics.
The adapter therefore labels these as present values with unknown statistical
semantics and rejects likelihood construction.

For inspection only, the adapter computes
`rho_star = covariance_ne_te / (ne_error * te_error)` under the explicit,
unsupported assumption that both errors are one-standard-deviation scales in
their signal units and that the covariance-labelled field is their covariance.
The acquired data have `|rho_star| > 1` at 191 of 15,863 eligible shot-30421
cells and 147 of 8,264 shot-30420 cells. These conditional failures reject that
complete assumption set at those cells; they do not identify the actual error
semantics or authorize a likelihood.

Run the separate Level-1 consumer with:

```powershell
python -B benchmarks/reference_validation_v1/level1_error_adapter.py `
  --source benchmarks/reference_data_level1_v1 `
  --protocol benchmarks/reference_validation_v1/level1_protocol.json `
  --output <new-empty-output-directory>
```
