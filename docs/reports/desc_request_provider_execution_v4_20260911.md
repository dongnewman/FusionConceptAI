# DESC request/provider execution report

Environment probing found `D:\006-Programing\LMC\outputs\fusion_concept_ai\.venv-desc` with DESC 0.17.3. The accepted `dgpi_context` and analytic compatibility certificate were bound into a strongly typed `DESCExecutionRequestV4`. The executor rebuilt the proof and the candidate-owned request payload before the real DESC Python process ran.

Reproduction:

    julia --project=. test/runtime_v4_desc_request_provider_execution_tests.jl

Focused result: 70/70 assertions passed, `DESC_REQUEST_PROVIDER_EXECUTION_FOCUSED_EXIT_CODE=0`, and the test process exited 0. The recorded provider process exited 0 and emitted `DESC_PROVIDER_EXECUTED=1`. A second fresh Python process exited 0 after reopening the saved HDF5 and comparing its equilibrium type, NFP, Psi, spectral/grid resolutions, Fourier surface coefficients, pressure, and iota to the emitted request. The request JSON, HDF5 output, adapter, and output inspector are under `runs/desc_request_provider_execution/`.

The receipt stores raw SHA-256 identities for those four artifacts plus the Python executable and imported DESC module. Focused adversarial tests reject altered request, output, adapter, or inspector bytes; reject a well-hashed but non-candidate-owned request; reject non-finite payload data; and preserve an actual synthetic provider exit code of 7.

The claim ceiling remains `screen_only`: provider and solver execution are true, while physical validation, engineering validation, evidence emission, pass, promotion, P5, terminal authority, and credible physical-device count remain false or zero. Full multi-region composition is explicitly still a downstream gap.
