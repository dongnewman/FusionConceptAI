# DESC field provider v4

This provider consumes the candidate-bound DESC execution result and receipt,
revalidates the receipt, then uses a fresh DESC 0.17.3 process to reopen the
HDF5 equilibrium and sample only stable quantities: B, |B|, pressure, iota,
sqrt(g), and force-balance residual. `DESCFieldProviderRequestV4` binds the
current context/candidate, upstream request/result/receipt, HDF5 SHA-256, exact
sample points, quantity schema, and units. Execution rebuilds that request
before starting the process.

The adapter checks DESC's own quantity metadata, output shapes, and finite
values before emitting a strict TSV schema. Julia parses that schema into
typed `DESCFieldSampleV4` records, checks point order and identities, scalar
ranges, and `norm(B)`, and replays the output during result validation. The
receipt seals the request, result, adapter, upstream HDF5, Python executable,
and DESC module bytes and rereads them when replayed. It remains screen-only:
no solver-convergence, material, multi-region interface, physical-validation,
engineering, evidence, pass, promotion, P5, terminal, or credible-device claim
is emitted.

Old implementation reuse classification:

- extract: stable DESC compute keys and quantity metadata checks from
  `outputs/fusion_concept_ai/scripts/desc_fourier_runner.py`;
- wrap: field/result hashing and fixed-boundary identity intent only;
- test-only: old v93/v116 manufactured multi-region assembly tests;
- reject: packaged W7-X output, family routing, old Genome/authority, and the
  assumption that one global equilibrium supplies material/interface physics.
