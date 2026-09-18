# Local T0 authority recheck R10

R10 is a corrective, static-only receipt for the R9 semantic regression.
The authority adapter is restored to the pre-R6 transport-validation call;
the R6 prepared-evidence replacement is removed.  The only retained
performance change is test-side snapshot reuse for an unmutated object.
Including the transport helper is now definition-only; executing the helper
file directly retains its historical testsets.

No Julia/DESC execution, runtime authority claim, or commit is included.
