# Independent UP4 MAST 30421 source review

Date: 2026-10-08. Independent, read-only review of `up4_ayc_covariance_semantics_20261008.md` and retained first-party/public-consumer evidence. No live source or protocol was changed; no data were downloaded and no Julia, FreeGS, inverse, or likelihood run was started.

## Ruling

**GO for the narrow source/provenance description; typed_absent for every statistical or physical claim needed by the inverse consumer.** The Level-1 shot-30421 metadata identifies the candidate covariance field, its label, unit string, UUID, and acquired shape. It does not define the estimator or prove that the field contains statistical covariance. Neither it nor the separate edge Thomson paper supplies a Level-2 observation covariance. The current consumer must keep weighted likelihood and inverse readiness false.

## AYC evidence and product boundary

The pinned acquisition for Level-1 shot 30421 identifies `ayc/covariance_ne_te` by UUID `cb1608cd-212a-532e-b443-5238abd7fcef`, with label “fit covariance of ne Te”, declared unit `eV / m ** 3`, and quality “Not Checked”. Its chunk/stored array shape is `[284,131]`; the embedded `.zattrs.shape` is `[145,130]`. The `ne_error`/`te_error` metadata has blank unit strings and no stated estimator or statistical convention. These facts support a candidate field identity and dimensional-unit observation only. A covariance-compatible unit is not evidence of covariance semantics, calibration, validity, or likelihood weights.

The Level-2 adapter is a distinct product and contract. Its selected shot-30421 `thomson_scattering` arrays have `[major_radius,time]=[121,135]`; the adapter canonicalizes only by dimension-name permutation to `[time,major_radius]`, requires exact coordinate extents, and does no resampling. The Level-1 AYC arrays use `[time,radial_index]=[284,131]`; protocol status is `discovered_unbound_not_consumed`. There is no approved index, shape, time, or radius join between them. The Level-2 protocol scopes its absence claim to the selected acquired group, where uncertainty/covariance arrays are not present; it does not claim that FAIR-MAST has no error products elsewhere.

The retained conditional calculation `rho_star=covariance_ne_te/(ne_error*te_error)` rejects the *joint unsupported hypothesis* that both errors are 1-sigma and the named field is their covariance at 191 of 15,863 eligible shot-30421 cells. It does not reveal the actual meanings. Preserve that as a negative hypothesis check, not a decoded error model.

## What the papers establish

UKAEA's 2010 core 130-point Nd:YAG paper describes centralized `Te`/`ne` processing using calibration data, laser energy, and background light, and illustrates marginal errors for shot 24400. It gives no shot-30421 calibration/code binding or covariance/error-generation definition. The separate 2006 enhanced **edge** Thomson paper discusses covariance from a single-point `Te`/`ne` fit and use in its joint spectral-profile fitting method. Its 16-channel edge-system method is a non-applicable method comparator only; it does not bind the Level-1 core AYC product, selected Level-2 profiles, or shot-30421 field semantics.

## EFM boundary

No reviewed first-party record supplies a signed segment-current equation for shot-30421 `fcoil_circ`, `fcoil_xmult`, and `fcoil_turns`; a verified circuit-index base; the 101-current to 938-segment mapping; per-segment polarity/orientation; or an independent known-current response. The pinned FAIR-MAST map assigns the arrays to dimensions, and its EFM pipeline renames/merges/converts data, but does not define that assembly. Keep signed EFM segment-current observations and geometry-to-current mapping typed_absent. In particular, do not use a weight or turns field as a polarity.

The new targeted-search subsection in `up4_public_source_delta_20261003.md` is consistent with this ruling. I independently checked its linked materials: the UKAEA Open Data page is explicitly shot 29899 and presents the EFM field inventory with blank descriptions; it cannot establish a shot-30421 assembly. FAIR-MAST issue #231 is an open community request for reconstruction authorities, with no maintainer answer shown; it is evidence of an unanswered request, not a UKAEA algorithm statement. The 2025 paper identifies its setup as MAST-U, so any MAST-U winding-polarity convention is not transferable to classic MAST `fcoil_*`. The pinned ingestion README documents SSH `mastcodes` and UDA/VPN prerequisites; that explains why this public snapshot is not self-contained, but does not prove the private dependency contains an old-MAST assembly or authorize access/execution. These searches bound what was found in the reviewed public sources; they do not prove that no internal or unpublished algorithm exists.

## Consumer disposition

Retain the existing product-separated protocol and the statuses `likelihood_ready=false`, `no_likelihood`, `no_inverse`, and `not_executed`. Clearing this boundary requires shot/version-bound core AYC calibration, channel/position/validity mapping, uncertainty definitions and covariance estimator; a separate provider-supported Level-1-to-Level-2 alignment for any Level-2 likelihood; and the EFM circuit/sign/assembly recipe with an independent response check. Metadata labels, dimensional units, an adjacent diagnostic paper, and static/source retrieval do not promote inverse or physics credit.

Primary references: [UKAEA 2010 core Nd:YAG Thomson paper](https://scientific-publications.ukaea.uk/wp-content/uploads/Published/RSIVOL81p10d520.pdf); [UKAEA 2006 enhanced edge Thomson paper](https://scientific-publications.ukaea.uk/wp-content/uploads/Published/Miss53.pdf); pinned [FAIR-MAST source audit](up4_public_source_delta_20261003.md); [reviewed AYC source-bound note](up4_ayc_covariance_semantics_20261008.md).
