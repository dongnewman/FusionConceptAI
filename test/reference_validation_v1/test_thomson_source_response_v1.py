from __future__ import annotations

import dataclasses
import sys
import unittest
from pathlib import Path
from types import MappingProxyType

import numpy as np


ROOT = Path(__file__).resolve().parents[2]
ADAPTER_DIR = ROOT / "benchmarks" / "reference_validation_v1"
sys.path.insert(0, str(ADAPTER_DIR))

import level1_error_adapter as level1  # noqa: E402
import reference_adapter as core  # noqa: E402
import thomson_source_response_v1 as response  # noqa: E402


class ThomsonSourceResponseV1Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.source = response.load_thomson_source_response_source_v1()
        cls.level1_package = level1.load_level1_error_package()
        cls.diagnostic = response.diagnose_thomson_source_response_v1(
            cls.level1_package, cls.source
        )

    def candidate(self) -> response.CandidateSpectralPredictionV1:
        values = np.ascontiguousarray(
            self.source.array("ayc/aspectra").values, dtype="<f8"
        )
        mask = np.ascontiguousarray(np.isfinite(values), dtype=np.bool_)
        values.setflags(write=False)
        mask.setflags(write=False)
        return response.CandidateSpectralPredictionV1(
            candidate_id="test-candidate-source-response-v1",
            values=values,
            dimensions=response.SPECTRAL_CANONICAL_DIMENSIONS,
            time_s=self.source.array("ayc/time").values,
            radial_index=self.source.array("ayc/radial_index").values,
            spectral_index=self.source.array("ayc/spectral_index").values,
            finite_mask=mask,
            unit="V",
            unit_semantics_source="candidate typed declaration test fixture",
        )

    def rehash_diagnostic(
        self, diagnostic: response.ThomsonSourceResponseDiagnosticV1
    ) -> response.ThomsonSourceResponseDiagnosticV1:
        body = response._diagnostic_body(
            diagnostic.source,
            diagnostic.level1_observation,
            diagnostic.fitted_channel_residuals,
            diagnostic.candidate_channel_residuals,
            diagnostic.pressure,
            diagnostic.conditional_spectral_fit,
            diagnostic.candidate_prediction,
            diagnostic.spectral_masks,
            diagnostic.profile_masks,
            diagnostic.auxiliary_inventory,
        )
        return dataclasses.replace(
            diagnostic, diagnostic_sha256=response._canonical_hash(body)
        )

    def test_all_twenty_raw_sources_and_chunk_identities_are_consumed(self) -> None:
        source = self.source
        self.assertEqual(tuple(source.arrays), response.SOURCE_ARRAY_NAMES)
        self.assertEqual(len(source.raw_source_identities), 20)
        self.assertEqual(sum(len(item.chunks) for item in source.raw_source_identities), 26)
        self.assertEqual(source.acquisition_sha256, response.EXPECTED_ACQUISITION_SHA256)
        self.assertEqual(source.selection_sha256, response.EXPECTED_SELECTION_SHA256)
        self.assertEqual(source.zmetadata_sha256, response.EXPECTED_ZMETADATA_SHA256)
        self.assertEqual(
            response.validate_thomson_source_response_source_v1(source)["status"],
            "pass",
        )
        for array in source.arrays.values():
            self.assertFalse(array.values.flags.writeable)
            self.assertFalse(array.finite_mask.flags.writeable)
            self.assertEqual(array.values.shape, array.shape)
            self.assertEqual(array.identity.assembled_sha256,
                             response._array_sha256(array.values))

    def test_actual_spectral_residuals_keep_roles_masks_and_no_score_credit(self) -> None:
        diagnostic = self.diagnostic
        result = response.validate_thomson_source_response_diagnostic_v1(diagnostic)
        self.assertEqual(result["spectral_finite_count"], 72_500)
        self.assertEqual(len(diagnostic.fitted_channel_residuals), 4)
        self.assertEqual(len(diagnostic.candidate_channel_residuals), 0)
        spectra = self.source.array("ayc/spectra").values
        fitted = self.source.array("ayc/aspectra").values
        for channel_index, item in enumerate(diagnostic.fitted_channel_residuals):
            self.assertEqual(item.channel_label, float(channel_index + 1))
            self.assertEqual(item.source_role, "acquired_raw_spectra")
            self.assertEqual(
                item.comparator_role, "acquired_provider_fitted_spectra"
            )
            self.assertFalse(item.calibrated_response)
            self.assertFalse(item.selection_authorized)
            self.assertEqual(int(item.mask.sum()), 18_125)
            np.testing.assert_array_equal(
                item.residual_values[item.mask],
                (
                    spectra[:, :, channel_index].astype(np.float64)
                    - fitted[:, :, channel_index].astype(np.float64)
                )[item.mask],
            )
        conditional = diagnostic.conditional_spectral_fit
        self.assertEqual(conditional["eligible_cell_count"], 15_863)
        self.assertEqual(conditional["relative_error_le_1e_5_count"], 11_632)
        self.assertEqual(conditional["relative_error_gt_1e_2_count"], 3_515)
        self.assertEqual(conditional["relative_error_gt_1_count"], 2_399)
        self.assertFalse(conditional["likelihood_ready"])
        self.assertFalse(conditional["selection_authorized"])

    def test_conditional_pressure_keeps_both_baselines_and_all_bad_cells(self) -> None:
        pressure = self.diagnostic.pressure
        self.assertEqual(pressure.psd_invalid_count, 191)
        self.assertEqual(pressure.negative_variance_count, 7)
        self.assertEqual(pressure.positive_variance_comparison_count, 15_856)
        self.assertEqual(pressure.positive_variance_psd_invalid_count, 184)
        self.assertEqual(
            int(pressure.positive_variance_psd_invalid_mask.sum()), 184
        )
        self.assertTrue(
            np.all(
                ~pressure.positive_variance_psd_invalid_mask
                | pressure.psd_invalid_mask
            )
        )
        self.assertTrue(
            np.all(
                ~pressure.positive_variance_psd_invalid_mask
                | pressure.positive_variance_comparison_mask
            )
        )
        self.assertAlmostEqual(
            pressure.observed_coefficient_median, 1.6090000610211631e-19
        )
        self.assertFalse(
            np.array_equal(
                pressure.pressure_residual_fingerprint[
                    pressure.profile_mask
                ],
                pressure.pressure_residual_exact_si[pressure.profile_mask],
            )
        )
        self.assertEqual(pressure.pressure_unit, "unknown_blank_source_unit")
        self.assertEqual(
            pressure.pressure_error_unit, "unknown_blank_source_unit"
        )
        self.assertFalse(pressure.producer_formula_confirmed)
        self.assertFalse(pressure.correction_applied)
        self.assertFalse(pressure.likelihood_ready)

    def test_level1_cell_ids_are_reused_and_spectral_cells_are_traceable(self) -> None:
        profile = next(
            response.iter_joined_level1_profile_cells_v1(self.diagnostic)
        )
        original = next(
            level1.iter_level1_cells(self.diagnostic.level1_observation)
        )
        self.assertEqual(profile["sample_id"], original["sample_id"])
        self.assertEqual(profile["sample_sha256"], original["sample_sha256"])
        self.assertEqual(profile["raw_index"], profile["canonical_index"])
        self.assertFalse(profile["likelihood_ready"])
        spectral = next(
            response.iter_source_spectral_residual_cells_v1(self.diagnostic)
        )
        self.assertEqual(spectral["raw_index"], spectral["canonical_index"])
        self.assertEqual(len(spectral["sample_sha256"]), 64)
        self.assertEqual(spectral["comparator_role"],
                         "acquired_provider_fitted_spectra")
        self.assertFalse(spectral["calibrated_response"])

    def test_candidate_prediction_remains_a_distinct_uncalibrated_role(self) -> None:
        candidate = self.candidate()
        diagnostic = response.diagnose_thomson_source_response_v1(
            self.level1_package,
            self.source,
            candidate_prediction=candidate,
        )
        self.assertEqual(len(diagnostic.candidate_channel_residuals), 4)
        self.assertNotEqual(
            diagnostic.diagnostic_sha256, self.diagnostic.diagnostic_sha256
        )
        for fitted, predicted in zip(
            diagnostic.fitted_channel_residuals,
            diagnostic.candidate_channel_residuals,
            strict=True,
        ):
            self.assertEqual(fitted.comparator_role,
                             "acquired_provider_fitted_spectra")
            self.assertEqual(predicted.comparator_role,
                             "uncalibrated_candidate_prediction")
            self.assertFalse(predicted.calibrated_response)
            self.assertFalse(predicted.selection_authorized)
        manifest = diagnostic.manifest_entry()
        self.assertEqual(
            manifest["spectral"]["candidate_role"],
            "uncalibrated_candidate_prediction",
        )
        self.assertFalse(manifest["selection_authorized"])

    def test_coordinate_mismatch_is_rejected_without_interpolation(self) -> None:
        candidate = self.candidate()
        time_s = candidate.time_s.copy()
        time_s[0] = np.nextafter(time_s[0], np.float32(np.inf))
        foreign = dataclasses.replace(candidate, time_s=time_s)
        with self.assertRaisesRegex(core.AdapterError, "candidate_time_grid_error"):
            response.diagnose_thomson_source_response_v1(
                self.level1_package,
                self.source,
                candidate_prediction=foreign,
            )

    def test_candidate_coordinate_comparison_precedes_any_narrowing(self) -> None:
        candidate = self.candidate()
        promoted = dataclasses.replace(
            candidate,
            time_s=candidate.time_s.astype("<f8"),
            radial_index=candidate.radial_index.astype("<f8"),
            spectral_index=candidate.spectral_index.astype("<f8"),
        )
        accepted = response.diagnose_thomson_source_response_v1(
            self.level1_package,
            self.source,
            candidate_prediction=promoted,
        )
        self.assertEqual(len(accepted.candidate_channel_residuals), 4)
        for field, code in (
            ("time_s", "candidate_time_grid_error"),
            ("radial_index", "candidate_radial_grid_error"),
            ("spectral_index", "candidate_spectral_grid_error"),
        ):
            values = np.asarray(getattr(promoted, field), dtype="<f8").copy()
            values.flat[0] = np.nextafter(values.flat[0], np.float64(np.inf))
            forged = dataclasses.replace(promoted, **{field: values})
            with self.assertRaisesRegex(core.AdapterError, code):
                response.diagnose_thomson_source_response_v1(
                    self.level1_package,
                    self.source,
                    candidate_prediction=forged,
                )

    def test_spectral_label_permutation_is_rejected(self) -> None:
        candidate = self.candidate()
        permuted = dataclasses.replace(
            candidate, spectral_index=candidate.spectral_index[::-1].copy()
        )
        with self.assertRaisesRegex(
            core.AdapterError, "candidate_spectral_grid_error"
        ):
            response.diagnose_thomson_source_response_v1(
                self.level1_package,
                self.source,
                candidate_prediction=permuted,
            )

    def test_missing_unit_semantics_is_valid_raw_absence_but_rejected_for_claims(self) -> None:
        self.assertEqual(self.source.array("ayc/pe").unit, "")
        self.assertEqual(self.source.array("ayc/pe_error").unit, "")
        self.assertEqual(self.source.array("ayc/spectra_error").unit, "")
        with self.assertRaisesRegex(
            core.AdapterError, "source_unit_semantics_missing"
        ):
            response.diagnose_thomson_source_response_v1(
                self.level1_package,
                self.source,
                require_calibrated_units=True,
            )
        missing = dataclasses.replace(
            self.candidate(), unit_semantics_source=""
        )
        with self.assertRaisesRegex(
            core.AdapterError, "candidate_unit_semantics_missing"
        ):
            response.diagnose_thomson_source_response_v1(
                self.level1_package,
                self.source,
                candidate_prediction=missing,
            )

    def test_candidate_finite_mask_mismatch_is_rejected(self) -> None:
        candidate = self.candidate()
        mask = candidate.finite_mask.copy()
        mask.flat[0] = ~mask.flat[0]
        forged = dataclasses.replace(candidate, finite_mask=mask)
        with self.assertRaisesRegex(
            core.AdapterError, "candidate_finite_mask_mismatch"
        ):
            response.diagnose_thomson_source_response_v1(
                self.level1_package,
                self.source,
                candidate_prediction=forged,
            )

    def test_raw_source_value_tamper_is_rejected_against_identity(self) -> None:
        original = self.source.array("ayc/spectra")
        values = original.values.copy()
        index = tuple(np.argwhere(np.isfinite(values))[0])
        values[index] = np.nextafter(values[index], np.float32(np.inf))
        values.setflags(write=False)
        forged_array = dataclasses.replace(original, values=values)
        arrays = dict(self.source.arrays)
        arrays[original.name] = forged_array
        forged_source = dataclasses.replace(
            self.source, arrays=MappingProxyType(arrays)
        )
        with self.assertRaisesRegex(core.AdapterError,
                                    "source_array_identity_error"):
            response.validate_thomson_source_response_source_v1(forged_source)

    def test_profile_mask_keys_and_contents_are_independently_rebuilt(self) -> None:
        missing = self.rehash_diagnostic(
            dataclasses.replace(
                self.diagnostic, profile_masks=MappingProxyType({})
            )
        )
        with self.assertRaisesRegex(
            core.AdapterError, "source_response_profile_mask_integrity_error"
        ):
            response.validate_thomson_source_response_diagnostic_v1(missing)

        masks = dict(self.diagnostic.profile_masks)
        changed = masks["conditional_psd_invalid"].copy()
        changed.flat[0] = ~changed.flat[0]
        changed.setflags(write=False)
        masks["conditional_psd_invalid"] = changed
        foreign = self.rehash_diagnostic(
            dataclasses.replace(
                self.diagnostic, profile_masks=MappingProxyType(masks)
            )
        )
        with self.assertRaisesRegex(
            core.AdapterError, "source_response_profile_mask_integrity_error"
        ):
            response.validate_thomson_source_response_diagnostic_v1(foreign)

    def test_pressure_scalars_and_semantics_are_independently_rebuilt(self) -> None:
        for changes in (
            {"positive_variance_comparison_count": 0},
            {"error_semantics": "exact_joint_Gaussian_variance_confirmed"},
        ):
            pressure = dataclasses.replace(self.diagnostic.pressure, **changes)
            foreign = self.rehash_diagnostic(
                dataclasses.replace(self.diagnostic, pressure=pressure)
            )
            with self.assertRaisesRegex(
                core.AdapterError, "conditional_pressure_recomputation_error"
            ):
                response.validate_thomson_source_response_diagnostic_v1(foreign)

    def test_channel_unit_semantics_provenance_is_independently_rebuilt(self) -> None:
        channel = dataclasses.replace(
            self.diagnostic.fitted_channel_residuals[0],
            unit_semantics_source="",
        )
        residuals = (
            channel,
            *self.diagnostic.fitted_channel_residuals[1:],
        )
        foreign = self.rehash_diagnostic(
            dataclasses.replace(
                self.diagnostic, fitted_channel_residuals=residuals
            )
        )
        with self.assertRaisesRegex(
            core.AdapterError, "source_response_channel_integrity_error"
        ):
            response.validate_thomson_source_response_diagnostic_v1(foreign)

    def test_weights_likelihood_and_calibrated_response_requests_fail_closed(self) -> None:
        for keyword, code in (
            ({"request_weights": True}, "covariance_weights_prohibited"),
            ({"request_likelihood": True},
             "source_response_likelihood_prohibited"),
        ):
            with self.assertRaisesRegex(core.AdapterError, code):
                response.diagnose_thomson_source_response_v1(
                    self.level1_package, self.source, **keyword
                )
        with self.assertRaisesRegex(core.AdapterError,
                                    "covariance_weights_prohibited"):
            self.diagnostic.require_covariance_weights()
        with self.assertRaisesRegex(
            core.AdapterError, "source_response_likelihood_prohibited"
        ):
            self.diagnostic.require_likelihood_ready()

    def test_no_instrument_or_scattering_length_registration_is_inferred(self) -> None:
        manifest = self.diagnostic.manifest_entry()
        self.assertEqual(
            manifest["registration_gaps"][
                "instrument_time_20_to_measurement_time_284"
            ],
            "typed_absent",
        )
        self.assertEqual(
            manifest["registration_gaps"][
                "scat_length_130_to_radial_index_131"
            ],
            "typed_absent",
        )
        self.assertFalse(
            manifest["registration_gaps"]["inference_or_index_shift_applied"]
        )
        self.assertEqual(len(self.diagnostic.auxiliary_inventory), 20)
        self.assertTrue(
            all(
                item["interpretation"]
                == "raw_source_identity_and_population_only"
                for item in self.diagnostic.auxiliary_inventory
            )
        )


if __name__ == "__main__":
    unittest.main()
