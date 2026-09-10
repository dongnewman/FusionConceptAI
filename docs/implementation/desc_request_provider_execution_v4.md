# DESC request/provider execution v4

This edge consumes the already accepted `dgpi_context` and its analytic
compatibility certificate. `DESCExecutionRequestV4` contains a concrete
`DESCExecutionPayloadV4`: its context, candidate, certificate, controls, and
candidate-owned boundary/profile payload are canonical-hashed together. The
executor rebuilds both the geometry proof and the complete request from the
current context before starting a process, so direct access to an internal
constructor cannot admit a foreign or hand-written payload.

The adapter writes a candidate-bound JSON request and runs the discovered
project `.venv-desc` Python runtime (DESC 0.17.3) through a generated adapter
that constructs `FourierRZToroidalSurface`, `PowerSeriesProfile`, and
`Equilibrium`, then calls `eq.solve(..., copy=True)` and saves HDF5 output.
After the provider exits, a second fresh Python process reopens the HDF5 with
`desc.io.load`. It checks the equilibrium type, field periods, flux, spectral
and grid resolutions, Fourier boundary coefficients, pressure profile, and
iota profile against the emitted request. The receipt records the actual
provider and inspector exit codes and raw SHA-256 identities for the request,
HDF5 output, adapter, inspector, Python executable, and imported DESC module.
Replay validation rereads those files and rejects tampering.

This is real provider and solver execution with a structurally checked saved
result, but remains `screen_only`. The authority record explicitly grants no
physical or engineering validation, evidence, pass, promotion, P5, terminal,
or credible-device credit. Full multi-region composition remains downstream.
