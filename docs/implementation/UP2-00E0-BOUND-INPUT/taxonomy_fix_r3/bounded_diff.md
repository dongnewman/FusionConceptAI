# E0 taxonomy correction r3 bounded difference

The protected parent E0 r1-r7, taxonomy r8, and taxonomy r9 artifacts are unchanged. This r3 source/test snapshot contains the second propagation correction after r9: the expected-identity overload delegates to `_up2e0_check_expected_with_checker`, and that helper returns the checker `program_exception` status before combining identity errors. Production uses `_up2e0_identity_checker`, which calls the same inspector seam as the primary checker. The test injects an exception through that seam on an actual A package and asserts the expected-identity path remains `program_exception`; the existing source-derived version-axis contradiction remains a `fail_closed` control. All reported counters remain zero.

| artifact | r9 reference | r10 frozen SHA-256 |
|---|---|---|
| source | `069a07bf00ee0570ac960f820077f3ffe53481b2f67aa35b110913bef4c379a0` | `804cf2cb3522eceefe37664737934bcffdad15ba2d5d2a28c0a70bcf1fca1f6d` |
| test | `9aa782ad85fa0240421304f4ad419db3924a2e6ea26a307617a3f248319033d2` | `856cde12b95b011ca1e3f1e34f5a544ca48ffb9c8de3a94c8ec38bca06ea945e` |
| runner | unchanged | `08a6235e37e7c8fc538bf94dc2ef080492610538961b57cfca22c288fb3be92a` |
| fixture | unchanged | `5de4cc133087f4d09bbc8b0334c50486b5f2ba1f479366a81f07c4822597731a` |
