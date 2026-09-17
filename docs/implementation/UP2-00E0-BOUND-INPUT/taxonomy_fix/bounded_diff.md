# E0 taxonomy correction bounded evidence

The protected parent E0 r1-r7 archive and its manifest are unchanged. This correction has one source and one test delta; the runner and fixture were frozen unchanged for r8.

| artifact | prior reference | current frozen SHA-256 |
|---|---|---|
| source | parent E0 r7 source `25621a87a005ea37502686ff2f1e5419b8c71fa3cd877ca875f0e6dd397ec321` | `1261df1fe2faf0d68414db99b96496bbf29a43f429ec93e5f61a583fefad2323` |
| test | parent E0 r7 test `b82c2a5deabc098253302ef589541dc2627db77d8ba0f3d1fa2745f19311104b` | `336dbd637fa63fe8008f7ffa7c96e21e070acd50e184dcfb98b160d4878e4e2d` |
| runner | unchanged | `08a6235e37e7c8fc538bf94dc2ef080492610538961b57cfca22c288fb3be92a` |
| fixture | unchanged | `5de4cc133087f4d09bbc8b0334c50486b5f2ba1f479366a81f07c4822597731a` |

The source delta adds `_up2e0_check_package_with_inspector`, which catches only exceptions raised by the injected/source inspector and classifies them as `program_exception`. The ordinary identity inspector still derives known candidate/ref/hash/axis contradictions and returns `fail_closed`. The factory propagates `program_exception` separately. The test invokes this same production checker seam with an actual A package and an injected unexpected exception, and retains a source-derived version-axis contradiction as the fail-closed control. Both paths report zero compile/provider/solver calls.

The r8 runner is the exact focused command in the receipt. Its actual output is 45/45 actual A envelope, 9/9 reusable G2 plan, 13/13 fail-closed identity mutations including the catch-path injection, and 3/3 typed extension boundary. This proves taxonomy software behavior only; no B00/B04, provider, mesh, engineering, physical, or R01-R10 credit is claimed.
