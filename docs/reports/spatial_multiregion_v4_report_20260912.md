# Spatial physics implementation handoff — execution pending

The spatial implementation is staged independently of the sealed reduced r3
source. This document does not claim execution of a spatial candidate yet.

Implemented: full-torus Q1 BR/Bphi/BZ/p fields; merged regular axis trial/tests;
all local weak volume/source/face terms; exterior traction/Bn and toroidal flux;
full sparse analytic state Jacobian; feasible sparse QR nonlinear attempts for
coarse/fine and flux endpoints; current-field curl/gradient diagnostics; actual
J/K CSV production and replay; continuous coefficient-based DESC R enclosure.

Measured lightweight checks, with no DESC or Julia imported/launched:

* Python AST and pure sampler mesh audit: exit 0. Coarse has 90 nodes, 2160
  volume quadrature rows and 2160 unique-face rows. Fine has 660 nodes, 17280
  volume rows and 17280 unique-face rows.
* Independent exact-rational manufactured enclosure control: exit 0.
  R=3+0.1*Z_2^0 gives the conservative upward bound 3.3000000000000003 m.
  This is a software-only control and is not a candidate geometry result.

Main-queue Julia focused execution: the first attempt exited 1 on ambiguous
decimal-dot/boolean-operator syntax. After correcting both occurrences, the
second run passed 33/33 assertions and exited 0, recorded in
`runs/spatial_chain_20260912_audit/physics_focused_r2.log` and its exit file.
The subsequent failure-evidence patch adds actual attempt/trial records,
update-count checks, deterministic test-only QR/line-search failure injection,
and replay assertions. The recorded 33/33 result predates this final patch; the
current source and expanded focused suite have not been rerun and remain owned
by the main queue.

Not yet executed in this branch: real fresh DESC sampling,
360/2640-unknown nonlinear solves, actual current artifacts or independent
spatial verification. The main agent owns those queued executions and definitive
exit codes. A source file, mesh count or lightweight check cannot satisfy the
original complete-field execution goal.

Remaining model/data limits even after execution: pressure/current-topology
uniqueness, full exterior electromagnetic/current-return closure, transport and
time-dependent plasma equations, heterogeneous material interfaces, experimental
physical validation and model-discrepancy evidence. Numeric rank failure,
boundary incompatibility, local residual, divergence, quadrature consistency and
solver budget/failure must be reported separately when actual results arrive.
