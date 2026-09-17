These include negative controls. `invalid_hash_drift.json` intentionally has
an illegal root field; `test_only_typed_absence.json` is explicitly a
duplicate-key negative control (despite its historical filename) and is not
the checked positive fixture. `test_only_positive.json` is the complete
synthetic fixture and must return `non_evidence`. The positive and signed test
objects also compute declaration hashes, never hand-wave them.
