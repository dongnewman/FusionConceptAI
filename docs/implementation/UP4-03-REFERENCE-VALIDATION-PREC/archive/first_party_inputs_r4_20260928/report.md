# UP4 MAST 30421 first-party source-input lookup r4

Date: 2026-09-28 (UTC retrieval during task; read-only)
Repo HEAD observed: `63792ca22958ffca8c3fa8e642256eb9f7240724`. The worktree was already broadly dirty; this leaf is isolated evidence only. No canonical docs, source, task manifest, old receipt, or existing evidence was edited. No Julia, DESC, FreeGS, solver, inverse, or bulk-data run/download was performed.

## Questions and result

The lookup targeted only inputs that block UP4-03: a shot-30421 first-party EFM/P6 signed segment-current assembly/polarity definition and an AYC Thomson shot/channel identity, calibration, and defensible uncertainty/covariance definition.

**Verified, but insufficient:** FAIR-MAST publishes shot-specific Level 1 consolidated metadata, with EFM geometry/current-related fields and AYC analyzed diagnostic fields. The UKAEA-pinned Level 2 mapping defines field names/units and broad mappings. UKAEA says the FAIR-MAST data archive/metadata/site are CC BY-SA 4.0 except where noted, and describes the curated archive as restriction-free public access. Public metadata and Level 2 mappings do not provide the exact missing reconstruction/calibration algorithms.

**Still `typed_absent`:**

- EFM/P6: signed per-segment current assembly/index/order and sign convention; physical coil polarity mapping (including P6 to model basis); and a known-current response fixture/measurement that independently validates the convention.
- AYC: raw core per-channel observation bytes with shot-specific UUID/channel lineage and ordering; scheduler/calibration script/version plus coefficients/validity rules for shot 30421; and a source-backed uncertainty/error-generation definition (including whether/how the fitted `covariance_ne_te` is valid for the selected observations). A covariance field's presence in metadata is not an error model.

Therefore `F/H/y/Sigma` cannot be frozen as an accepted likelihood input; formal likelihood/inverse remain `no_likelihood`, `no_inverse`, `not_executed`. No inverse/physics credit is claimed.

## First-party sources checked

1. UKAEA's [FAIR MAST service and licence page](https://www.ukaea.org/service/fair-mast/) says the public archive exposes shot metadata and public Zarr data, and that archive data/site/metadata are CC BY-SA 4.0 except where otherwise noted. FAIR-MAST access is public and described as restriction-free for curated data. This describes the curated data route; it does not establish unrestricted access to internal UDA/source scheduler scripts.
2. MAST Data Catalog [Level 1 documentation](https://mastapp.site/level1-data.html) explicitly describes Level 1 examples as unprocessed (no preprocessing, interpolation, calibration, or cropping), including shot 30421; it identifies `ayc` as core Thomson data and `efm` as EFIT data. It shows dataset groups and signal metadata, not the signed segment-current algorithm or AYC calibration/uncertainty procedure.
3. MAST Data Catalog [Level 2 documentation](https://mastapp.site/level2-data.html) says Level 2 includes cropping, interpolation, calibration and mapping toward IMAS naming. It is a curated derivative; the documentation does not provide the shot-specific AYC calibration recipe or EFM/P6 signed segment recipe needed here.
4. UKAEA's pinned public [`fair-mast-ingestion` Level 2 mapping](https://github.com/ukaea/fair-mast-ingestion/blob/608419fde2969ae05ef6f095c323589c24047a2e/mappings/level2/mast.yml) confirms `EFM_FCOIL_(X)`/`(C)` measured/reconstructed field mappings (A) and AYC field mappings for the applicable shot range. The file maps names to Level 2 fields; it does not specify circuit/turn/multiplier to signed segment current, coil sign/polarity, raw channel UUID lineage, calibration coefficients, bad-channel rules, or an uncertainty-generation algorithm. Do not infer formulas from `fcoil_circ`, `fcoil_turns`, or `fcoil_xmult` names.
5. UKAEA maintainer issue [#140, “Raw Core Thomson channel data”](https://github.com/ukaea/fair-mast-ingestion/issues/140), opened 2026-08-07, states raw core Thomson channel data was not believed to be in Level 1 and says scheduler scripts may preserve calibration details worth checking. This is a first-party lead, not proof that the data/scripts are absent from all archives; it identifies the concrete request path.
6. The repo README/source's earlier pinned audit (see `docs/implementation/GOAL-EXECUTION-20260926/up4_first_party_mapping_delta.md`) says source UDA access requires certificate/permission and UKAEA VPN/internal network, and points to internal `mastcodes`. No authenticated UDA access was attempted here. Open Data request pages are not proof that the exact files have been granted or retrieved.

## Retrieval commands and actual outcomes

Read-only `Invoke-WebRequest -UseBasicParsing -TimeoutSec 30`, with response bodies held in memory; SHA-256 computed over returned response bytes. No payload was saved or signal chunks requested.

| URL | Actual result | SHA-256 |
|---|---|---|
| `https://s3.echo.stfc.ac.uk/mast/level1/shots/30421.zarr/.zmetadata` | HTTP 200; 1,714,135 response bytes; matches the existing pinned shot-30421 metadata record | `362932d6cfeb62f01109a56b825b235b7daaedc928c17340be59c7a1398e7db1` |
| `https://raw.githubusercontent.com/ukaea/fair-mast-ingestion/608419fde2969ae05ef6f095c323589c24047a2e/mappings/level2/mast.yml` | HTTP 200; 183,455 response bytes; pinned commit | `70bb5fedfea1c9c2ac3ca5fe5980a5932233d40f7572d50f1f1fc9f6a229a295` |
| `https://api.github.com/repos/ukaea/fair-mast-ingestion/issues/140` | HTTP 200; 2,741 response bytes | `7a4e893e7a52eae022ab65ba9a70e39a69d464ce1288589b65404ec50532111e` |

The web-read pages also returned the UKAEA service licence/access description, Level 1/2 explanations, and issue #140 content. They were not signal-array retrievals. No local MAST input files were modified.

## Next input gate

Resume this semantic input branch only when first-party deliverables are obtained and byte/version bound:

1. EFM/P6 source algorithm or authoritative mapping with circuit-to-segment index/order, signed weighting, direction/polarity, plus an independent known-current response fixture/trace.
2. AYC shot-30421 raw channel payload and stable IDs/order, its scheduler calibration script/version and coefficients/validity handling, and authoritative uncertainty/error model with covariance construction/interpretation for the chosen channel product.
3. Recompute hashes and lineage from the retrieved originals. Then validate EFM polarity against the independent response before using it in `F/H`; freeze the same-candidate `F/H/y/Sigma` and split before any three-Genome inverse or heldout work.

Until all required items arrive, preserve `typed_absent/no_likelihood/no_inverse/not_executed`; neither public metadata, catalog UUIDs, download success, nor an inferred sign/calibration formula closes the gate.
