import copy
import hashlib
import json
import unittest
from pathlib import Path

from normalize_reference import canonical_bytes, sha256_file, subject_hash, validate_normalized


ROOT = Path(__file__).resolve().parent


def valid_record():
    subject = {
        "schema_version": "n2-label-neutral-equilibrium-subject-v1",
        "source_class": "external_simulation",
        "source_artifact_sha256": "a" * 64,
        "toroidal_flux": {"value": 1.0, "unit": "Wb"},
        "pressure_profile": {"quantity": "pressure", "unit": "Pa",
                             "coefficients_by_power": [1.0, -1.0]},
        "rotational_or_current_profile": {"quantity": "iota", "unit": "1",
                                           "coefficients_by_power": [0.5]},
        "boundary": {"radial_modes": [
            {"m": 0, "n": 0, "coefficient_m": 2.0}]},
    }
    return {
        "schema_version": "n2-normalized-reference-v1",
        "reference": {"reference_id": "display-a", "display_name": "A"},
        "subject": subject,
        "subject_hash": hashlib.sha256(canonical_bytes(subject)).hexdigest(),
        "authority": {"physical_validation": "unsupported",
                      "independent_solver": False, "measurement": False,
                      "inversion_ready": False,
                      "held_out_prediction_ready": False,
                      "credible_device_count": 0},
    }


class NormalizationContractTests(unittest.TestCase):
    def test_downloaded_artifact_matches_frozen_hash(self):
        manifest = json.loads((ROOT / "source.json").read_text(encoding="utf-8"))
        artifact = ROOT / manifest["artifact"]["path"]
        self.assertEqual(sha256_file(artifact), manifest["artifact"]["sha256"])
        self.assertEqual(artifact.stat().st_size, manifest["artifact"]["bytes"])

    def test_display_labels_do_not_change_subject_hash(self):
        record = valid_record()
        changed = copy.deepcopy(record)
        changed["reference"] = {"reference_id": "renamed", "display_name": "B"}
        self.assertEqual(subject_hash(record), subject_hash(changed))

    def test_source_hash_tampering_fails_closed(self):
        record = valid_record()
        with self.assertRaisesRegex(ValueError, "source hash"):
            validate_normalized(record, expected_source_hash="b" * 64)

    def test_measurement_relabel_fails_closed(self):
        record = valid_record()
        record["subject"]["source_class"] = "measurement"
        record["subject_hash"] = hashlib.sha256(canonical_bytes(record["subject"])).hexdigest()
        with self.assertRaisesRegex(ValueError, "promoted or relabeled"):
            validate_normalized(record)

    def test_authority_promotion_fails_closed(self):
        record = valid_record()
        record["authority"]["physical_validation"] = "supported"
        with self.assertRaisesRegex(ValueError, "authority ceiling"):
            validate_normalized(record)

    def test_invalid_pressure_profile_fails_closed(self):
        record = valid_record()
        record["subject"]["pressure_profile"]["coefficients_by_power"] = [1.0, 1.0]
        record["subject_hash"] = hashlib.sha256(canonical_bytes(record["subject"])).hexdigest()
        with self.assertRaisesRegex(ValueError, "not closed"):
            validate_normalized(record)


if __name__ == "__main__":
    unittest.main()
