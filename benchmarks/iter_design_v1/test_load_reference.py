import copy
import json
import unittest
from pathlib import Path
from load_reference import load_registry, validate_registry, inversion_ready

REGISTRY = Path(__file__).parents[1] / "reference_registry_v1.json"

class RegistryTests(unittest.TestCase):
    def test_real_registry_loads_and_is_not_validation(self):
        obj = load_registry(REGISTRY)
        self.assertEqual(obj["references"][0]["evidence_class"], "simulation")
        self.assertEqual(obj["references"][1]["evidence_class"], "design_target")
        self.assertFalse(obj["validation_pass"])

    def test_label_neutral_mission_not_name(self):
        obj = json.loads(REGISTRY.read_text(encoding="utf-8"))
        ref = copy.deepcopy(obj["references"][1])
        ref["device_name"] = "ordinary_candidate"
        obj["references"] = [ref]
        self.assertEqual(validate_registry(obj), [])

    def test_design_target_cannot_be_measurement(self):
        obj = json.loads(REGISTRY.read_text(encoding="utf-8"))
        obj["references"][1]["evidence_class"] = "measurement"
        self.assertTrue(any("mislabeled measurement" in e for e in validate_registry(obj)))

    def test_artifact_and_channel_leakage_rejected(self):
        obj = json.loads(REGISTRY.read_text(encoding="utf-8"))
        ref = obj["references"][2]
        ref["data_split"]["held_out_artifact_ids"].append(ref["data_split"]["calibration_artifact_ids"][0])
        ref["data_split"]["held_out_channel_ids"].append("t_e")
        errors = validate_registry(obj)
        self.assertTrue(any("artifact leakage" in e for e in errors))
        self.assertTrue(any("channel leakage" in e for e in errors))

    def test_unknown_cannot_be_silent_zero(self):
        obj = json.loads(REGISTRY.read_text(encoding="utf-8"))
        field = obj["references"][1]["fields"]["major_radius"]
        field["value"] = None; field["missing_reason"] = None
        self.assertTrue(any("unknown without reason" in e for e in validate_registry(obj)))

    def test_unresolved_unit_blocks_measurement_readiness(self):
        obj = load_registry(REGISTRY)
        self.assertFalse(inversion_ready(obj["references"][2]))

    def test_raw_data_false_blocks_measurement_readiness(self):
        obj = json.loads(REGISTRY.read_text(encoding="utf-8"))
        ref = obj["references"][2]
        ref["fields"]["electron_density_signal"]["unit_consistency"] = "resolved"
        self.assertFalse(inversion_ready(ref))

if __name__ == "__main__":
    unittest.main()
