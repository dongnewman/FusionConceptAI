# Regional force q=3 numerical comparison

Legacy audit: c405398 is retained as the q=2 real observation and is consumed through its public field/basis request and execution entrypoints. No old result is relabelled as q=3 and no provider output is fabricated. The new source owns q=3 Gauss-Legendre radial nodes and midpoint3 angular nodes, runs the real providers in a fresh run directory, and compares per-region and total force to q=2.

This is a numerical screen only. It does not establish mesh convergence, V&V/UQ evidence, physical validation, or pass/promotion authority. Process and provider receipt hashes are retained in the comparison identity. Focused acceptance executes a second provider run under a distinct path and compares its nodes, regional and total forces, and q=2/q=3 differences within the declared tolerances; this independent numerical replay still does not create validation or promotion evidence.
