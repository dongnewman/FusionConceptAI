# Spatial pickup engineering execution record — 2026-09-13

The engineering stage actually consumed the J=`curl(B)/mu0` volume currents and
interface K artifacts produced by all four failed spatial states. Transfer and
circuit computations completed with exit 0, while every case remains scientific
`fail` because `physical_upstream_valid=false`.

## Actual transfer and circuit results

| Case | Static linkage (Wb) | Reciprocity relative difference | Nominal peak current | Short peak current | Engineering exit / status |
| --- | ---: | ---: | ---: | ---: | --- |
| nominal_coarse | -1.37600894e-5 | 5.76176e-14 | 0.0676371 mA | 0.685408 mA | 0 / fail |
| nominal_fine | -1.87299636e-5 | 4.23291e-14 | 0.0920663 mA | 0.932964 mA | 0 / fail |
| flux_low_coarse | -1.29970922e-5 | 5.93056e-14 | 0.0638866 mA | 0.647402 mA | 0 / fail |
| flux_high_coarse | -1.37598689e-5 | 5.98346e-14 | 0.0676360 mA | 0.685397 mA | 0 / fail |

For each case, input identity admission, Biot-Savart finite-disk transfer,
independent unit-loop reciprocity, analytic RL flow and fixed 10 us protection
logic executed. Transfer exit and circuit exit are both 0. No case tripped.
Stationary-field induced EMF is exactly zero by the declared static model; the
listed currents belong only to the separately declared prescribed-ramp design
scenario and are not solved plasma dynamics.

The declared candidate geometry gives a conservative analytic clearance lower
bound of 0.045 m. The actual samples give 0.429182 m, and the separately computed
continuous DESC spectral R bound is 5.97002582 m. The ideal aperture fits those
declared/spectral bounds, but this does not prove a complete manufactured hardware
envelope. No line was silently moved.

The independent 256-bit circuit replay passed for all four cases. For nominal
coarse, the largest current difference is `2.71e-20 A`; energy terms agree within
`1.04e-25 J`, and the maximum segment identity error agrees within `8.82e-28 J`.
Focused engineering tests pass 76/76, process exit 0.

## Scientific boundary and recovery

The computed linkage is the contribution of the supplied plasma volume/sheet
currents. External coils, outer K, return-current closure, applicable component
and environment data, self-consistent transients, parasitic/switch/thermal models
and physical calibration are absent. Therefore computation exit 0 does not mean
engineering qualification. Recovery requires converged applicable physics plus
those missing current and hardware declarations/data; the existing diagnostic
transfer remains replayable but cannot be promoted.

The stage artifacts are under
`runs/spatial_chain_20260912_r1/engineering/`, with the aggregate seal in
`engineering.json`. The unified reproduction command is documented in the
integrated execution report.
