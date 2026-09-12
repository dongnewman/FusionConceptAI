# Reference-input registry and loader

This package is deliberately an input registry, not an inverse solver or a validation result. `iter_design_v1` records public ITER design targets from the [ITER FAQ](https://www.iter.org/faqs). ITER is explicitly a non-electricity-producing experimental design reference: its 500 MW, 50 MW and Q=10 values are targets, not measurements, and cannot earn net-electric or measurement-validation credit.

`fair_mast_shot_30421_v1` records a real public measured-data route. UKAEA describes FAIR MAST as a public archive with JSON metadata and Zarr diagnostics; the catalog documents signal metadata for shot 30421, including `t_e`, `n_e`, `beta_pol`, units and dimensions. The catalog reports `eV` for `n_e` (UUID `f0b586cd-11ea-5208-927b-4e4f057a6c44`), although density is expected in `m^-3`; this unresolved inconsistency blocks inversion/validation. The parquet URL is metadata only; the S3 Zarr route is recorded but `raw_data_obtained=false`.

`c2w_frc_public_reference_v1` is a materially different open-field/reversed-field capability reference, but remains `pending_data`: no usable shot artifact was obtained. A candidate page is not treated as data.

## What Sol must freeze before any inverse run

Only mappings supported by fields actually found are proposed: ITER design consistency can map `(P_fusion, P_aux, B_T, I_p, V_plasma)` to a forward-design observation vector; FAIR MAST may map shot/channel IDs to time-major-radius diagnostic arrays only after raw-data acquisition and unit resolution. Sol must freeze the parameter vector θ, known inputs, calibration y, held-out y, priors, tolerances, uncertainty model, and independent-shot/channel split after acquiring raw arrays and metadata. Minimum acquisition is: obtain the S3 Zarr arrays and calibration metadata, resolve the `n_e` unit discrepancy, obtain per-sample uncertainties and reconstruction versions, then reserve a distinct shot for held-out prediction. No complete θ or inverse problem is asserted here.

Run from this directory with `python test_load_reference.py` (standard library only).
