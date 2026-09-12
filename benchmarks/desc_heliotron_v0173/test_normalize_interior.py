import copy
import hashlib
import json
import unittest
from pathlib import Path

import h5py
import numpy as np

from normalize_reference import canonical_bytes
from normalize_interior import normalize_interior, validate_interior


ROOT = Path(__file__).resolve().parent


class SourceInteriorContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.record = normalize_interior(ROOT / "source.json")

    def test_exact_selected_member_and_full_stored_modes(self):
        subject = self.record["subject"]
        self.assertEqual(subject["selected_equilibrium_index"], 3)
        self.assertEqual(subject["source_resolution"],
                         {"L": 24, "M": 12, "N": 3, "NFP": 19})
        self.assertEqual((subject["R"]["coefficient_count"],
                          subject["Z"]["coefficient_count"]), (598, 585))
        self.assertEqual((subject["R"]["symmetry"], subject["Z"]["symmetry"]),
                         ("cos", "sin"))
        self.assertEqual(subject["R"]["terms"][0].keys(),
                         {"l", "m", "n", "coefficient_m"})

    def test_repeated_mn_keeps_distinct_radial_degrees(self):
        terms = self.record["subject"]["R"]["terms"]
        pairs = [(term["m"], term["n"]) for term in terms]
        self.assertLess(len(set(pairs)), len(pairs))
        self.assertGreater(max(term["l"] for term in terms), 12)

    def test_selected_member_arrays_match_raw_hdf5_not_previous_member(self):
        artifact = ROOT / "HELIOTRON_output.h5"
        with h5py.File(artifact, "r") as stream:
            selected = stream["_equilibria"]["3"]
            previous = stream["_equilibria"]["2"]
            for name in ("R", "Z"):
                terms = self.record["subject"][name]["terms"]
                modes = selected[f"_{name}_basis"]["_modes"][()]
                values = selected[f"_{name}_lmn"][()]
                self.assertEqual([tuple(int(v) for v in mode) for mode in modes],
                                 [(term["l"], term["m"], term["n"])
                                  for term in terms])
                self.assertEqual([float(v) for v in values],
                                 [term["coefficient_m"] for term in terms])
                self.assertFalse(np.array_equal(values,
                                                previous[f"_{name}_lmn"][()]))

    def test_canonical_wire_and_authority_fail_closed(self):
        changed = copy.deepcopy(self.record)
        changed["subject_canonical_json"] += " "
        with self.assertRaisesRegex(ValueError, "canonical subject wire"):
            validate_interior(changed)
        changed = copy.deepcopy(self.record)
        changed["subject"]["R"]["terms"][0]["coefficient_m"] *= 2
        with self.assertRaisesRegex(ValueError, "canonical subject wire"):
            validate_interior(changed)
        changed = copy.deepcopy(self.record)
        changed["authority"]["measurement"] = True
        with self.assertRaisesRegex(ValueError, "authority ceiling"):
            validate_interior(changed)

    def test_selected_member_and_basis_forgery_fail_closed(self):
        changed = copy.deepcopy(self.record)
        changed["subject"]["selected_equilibrium_index"] = 2
        wire = canonical_bytes(changed["subject"])
        changed["subject_canonical_json"] = wire.decode("utf-8")
        changed["subject_hash"] = hashlib.sha256(wire).hexdigest()
        with self.assertRaisesRegex(ValueError, "selected-member identity"):
            validate_interior(changed)
        changed = copy.deepcopy(self.record)
        changed["subject"]["R"]["spectral_indexing"] = "unknown"
        wire = canonical_bytes(changed["subject"])
        changed["subject_canonical_json"] = wire.decode("utf-8")
        changed["subject_hash"] = hashlib.sha256(wire).hexdigest()
        with self.assertRaisesRegex(ValueError, "basis contract"):
            validate_interior(changed)


if __name__ == "__main__":
    unittest.main()
