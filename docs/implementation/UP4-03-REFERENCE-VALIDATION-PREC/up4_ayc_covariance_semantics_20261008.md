# UP4 AYC shot 30421 covariance semantics boundary

Date: 2026-10-08. Read-only source/consumer audit. No arrays were downloaded, no source or protocol was modified, and no Julia, FreeGS, inverse, or likelihood run was started.

## First-party fact established

The already acquired shot-30421 Level-1 `.zmetadata` is pinned at SHA-256 `362932d6cfeb62f01109a56b825b235b7daaedc928c17340be59c7a1398e7db1`; its acquisition receipt is `benchmarks/reference_data_level1_v1/shot30421_r1/acquisition.json`, SHA-256 `b517dcd2929f46968d78970f8107645d5082a128b5e9b5267e525803032742b7`. The receipt binds `ayc/covariance_ne_te` (UUID `cb1608cd-212a-532e-b443-5238abd7fcef`) to the official shot-30421 Level-1 Zarr object. The field label is `fit covariance of ne Te`, declared unit is `eV / m ** 3`, and the acquisition metadata marks quality `Not Checked`. Its stored array is `[284,131]`, while its own `.zattrs.shape` says `[145,130]`. `ne_error` and `te_error` have blank unit strings and no corresponding UUID or stated statistical convention in the retained metadata. Their arrays are also stored as `[284,131]`; the acquisition statuses are `decoded_raw_values_no_uncertainty_interpretation`.

The metadata establishes field identity, a provider label and a dimensional unit candidate. It does not establish whether either reported error is a standard deviation, a confidence interval, a fit-parameter uncertainty, or another quantity; nor does it state the estimator, fitting model, covariance convention, channel validity rule, or applicable calibration version. A covariance label by itself is not enough to construct a likelihood covariance matrix.

## First-party method context and limit

UKAEA's [2010 core Nd:YAG Thomson paper](https://scientific-publications.ukaea.uk/wp-content/uploads/Published/RSIVOL81p10d520.pdf) describes the 130-polychromator/130-fibre core system and its central processing path. It says the central MAST loop derives `Te` and `ne` from signal integrals using detailed calibration data, laser energy and slow sampled background light (pp. 2–3, PDF lines 233–244), and gives an example fit with marginal `Te` and `ne` errors for shot 24400 (Fig. 5). It does not define how those marginal errors or a `ne`–`Te` covariance are calculated or show that the shot-30421 Level-1 fields use that method.

The separate UKAEA [enhanced edge Thomson paper](https://scientific-publications.ukaea.uk/wp-content/uploads/Published/Miss53.pdf) states that a single-point fit yields covariance between `Te` and `ne` and that a joint spectral-profile fit can use the term, whereas independently fitting the profiles discards it (Section V). This establishes a relevant method for that edge system and paper. It does not bind the shot-30421 core AYC covariance field to the method, fit software, calibration, or observation product; it cannot supply the missing core uncertainty semantics.

The pinned UKAEA FAIR-MAST ingestion sources are mappings and array transforms, not the central fitting implementation. The existing first-party search is summarized in `docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/up4_public_source_delta_20261003.md`; it found no public shot-applicable AYC calibration/error-generation routine. No new download or search for duplicate metadata was made in this pass.

## Consumer mapping and reproducible status

Keep these two product contracts separate:

- Level 1 `benchmarks/reference_validation_v1/level1_protocol.json`: shot 30421 observation/error arrays are `[time,radial_index]=[284,131]`, bound to the Level-1 acquisition receipt. The protocol labels `ne_error`/`te_error` as unknown semantics, covariance as candidate unknown semantics, and `likelihood_ready=false`. The existing `level1_error_adapter.py::conditional_error_consistency` computes only the conditional statistic `rho_star=covariance_ne_te/(ne_error*te_error)` under an explicitly unsupported hypothesis: both errors are one-standard-deviation values and the covariance field is their covariance. The retained report records `|rho_star|>1` in 191/15,863 eligible cells for shot 30421 (and 147/8,264 for shot 30420). These cells reject that complete hypothesis at those cells; they do not identify the actual meanings.
- Level 2 `benchmarks/reference_validation_v1/protocol.json`: the selected shot-30421 profiles are `[major_radius,time]=[121,135]`, and the acquired Level-1 error arrays are explicitly `discovered_unbound_not_consumed`. Level 2 has no uncertainty/covariance field in the selected acquired `thomson_scattering` group. The protocol prohibits attaching Level-1 cells by index, shape, time, or radius without a versioned provenance-preserving mapping. Thus the Level-1 covariance cannot be supplied as Level-2 `Sigma`.

The existing reproducible typed-absence record is already encoded in `level1_protocol.json` (`error_semantics.status=present_values_unknown_statistical_semantics`, `likelihood_ready=false`) and `protocol.json` (`candidate_level1_error_arrays.status=discovered_unbound_not_consumed`, selected Level-2 errors absent, weighted likelihood rejected). This pass does not change those records. Labels and declared units remain metadata facts; `sigma`, covariance semantics for a selected observation, aligned Level-2 `Sigma`, and likelihood readiness remain `typed_absent`.

## Input needed to clear this boundary

A first-party artifact must bind the shot-30421 core AYC field production to: the central fit/calibration code and revision; shot-applicable calibration and validity/bad-channel inputs; the exact definitions and units of `ne_error`/`te_error`; and the estimator, units and scope of `covariance_ne_te`. For the selected Level-2 consumer, a provider-supported mapping with explicit time/channel/major-radius lineage is additionally required. Until then retain `no_likelihood`, `no_inverse`, and `not_executed`; do not infer an error model from field names or copy Level-1 arrays into Level-2.
