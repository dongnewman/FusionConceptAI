# Local T0 authority recheck R12

R12 is a static-only correction to the typed-absence test contract after the
runtime reached that assertion.  The product is unchanged: the absent G3
record contributes `:missing_material`, followed by the authority boundary's
`:g3_feedback_material_absent` reason.  The exact ordered tuple is now frozen
in the test and fixture.

The R12 runtime remains NO-GO: it timed out after reaching the typed-absence
assertion, and the 25-negative dispatches were not reached (`0/25`).  No
Julia/DESC execution was performed for this correction and no commit was
created.
