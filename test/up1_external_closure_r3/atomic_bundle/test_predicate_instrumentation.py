"""Independent call instrumentation/adversarial probe for the R4 vector slice.

This test wraps the newly-owned production predicates with a transparent trap.
The trap records invocation and delegates to the original implementation; it
cannot supply an error code or decision.  A vector that bypassed its predicate
would therefore fail the invocation assertion below.
"""
from __future__ import annotations

import unittest
from unittest.mock import patch

from test_atomic_bundle_vectors import (
    _CALLED_FUNCTION,
    _OWNED_PREDICATES,
    _json_bytes,
    _semantic_execute,
    all_vectors,
)
from tools.up1_external_closure_r3.atomic_bundle import bundle as impl


class PredicateInstrumentationTests(unittest.TestCase):
    def test_owned_predicates_are_reached_by_adversarial_traps(self):
        vectors = {vector.vector_id: vector for vector in all_vectors()}
        for vector_id, function_name in _OWNED_PREDICATES.items():
            vector = vectors[vector_id]
            built = vector.build()
            raw = _json_bytes(built)
            observed: list[str] = []
            original = getattr(impl, function_name)

            def trap(*args, _original=original, _name=function_name, **kwargs):
                observed.append(_name)
                return _original(*args, **kwargs)

            with self.subTest(vector=vector_id):
                with patch.object(impl, function_name, trap):
                    actual_code, called_function, result = _semantic_execute(vector, built, raw)
                expected_code = None if vector.expected in {"no_failure_code", "internal accepted_all only"} else vector.expected
                self.assertEqual(observed, [function_name])
                self.assertEqual(called_function, function_name)
                self.assertEqual(actual_code, expected_code)
                self.assertEqual(result["decision"], vector.decision)
                self.assertTrue(result["no_publish"])
                self.assertNotEqual(result["failure_codes"], ["SCHEMA_INVALID"])
                self.assertEqual(_CALLED_FUNCTION[vector_id], function_name)


if __name__ == "__main__":
    unittest.main()
