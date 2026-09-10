# RuntimeV4 3-D physical-input composition report — 2026-09-10

## Result

The five accepted typed 3-D input slices now compose through one candidate,
compiled prefix, scenario, and physical subject. Region laws come only from
the committed exact-cover `ThreeDRegionLawSetCompilerV4`: the manufactured
fixture owns two oriented regions and six independent laws. It also owns a
typed physical-to-region support mapping declaration and binding, two exactly
covered state nodes, one oriented interface, and five matched discrete spaces.

The mapping seals the physical coordinate/metric support and exactly maps every
oriented region ID to its declared support ref. This is structural ownership,
not proof of coordinate transforms, containment, overlap, or other geometric
compatibility. Residual/Jacobian state coverage is compared by keyed state-node
ID, identity hash, and physical type; valid tuple permutations do not change
exact-cover semantics. The positive fixture puts G2 state nodes in right/left
order while the oriented declaration remains left/right, so successful full
composition exercises the keyed comparison rather than tuple equality.

The generic fixture is expected to expose 15 ordered recoverable gaps. Missing,
partial, duplicate, unrelated, foreign-context, and forged inputs are intended
to fail closed.

## Verification

- focused tests: 157/157, exit code 0;
- standalone runner: 157/157 plus
  `THREE_D_PHYSICAL_INPUT_COMPOSITION_OK`, exit code 0;
- standalone example: exit code 0, reporting 15 generic gaps,
  `input_complete`, two regions, two states, one interface, five spaces, and
  all execution, evidence, and authority flags false;
- RuntimeV4 core: 26/26, exit code 0;
- RuntimeV4 spine: 54/54, exit code 0.

Two pre-final focused runs exposed defects rather than acceptance evidence.
One read a nonexistent `state_node_id` from a compiled region ref; the keyed
comparison now joins oriented declaration state IDs with compiled ref identity
and type. The other separated a multiline exception expression from
`@test_throws`; those assertions now use explicit `begin` blocks. The results
above are from the final frozen pass.

## Boundary

`input_complete` is structural input composition only. No provider was selected
or executed, no solver ran, and no evidence or pass was emitted. P5, promotion,
validation, and terminal authority remain false. The claim ceiling is
`screen_only`; credible physical-device count remains **0**.
