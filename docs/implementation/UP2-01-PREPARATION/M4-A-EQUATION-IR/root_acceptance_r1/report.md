# M4-A equation IR root acceptance R1

Decision authority: `Sol/root`  
Recorder: documentation Luna `m4_scope_record` (`gpt-5.6-luna`, high)  
Review basis: `independent_review_r1/pass_limited`  
Frozen HEAD: `b2c04d8339774635aaecd73651efcdb101e01b5d`

## Limited acceptance

Sol/root accepts the M4-A manufactured equation declaration and isolated IR
control as `accepted_limited`, with claim ceiling
`manufactured_control` / `screen_only`. The accepted evidence is the
independent Fraction oracle result `div(K grad(u)) = 11/60`, `f = -11/60`,
exact residual `0`, and the isolated Julia result `42/42`, together with the
four-role separation and unchanged shared entry boundary recorded by
`independent_review_r1`.

This acceptance is limited to the declaration/IR control. It is not residual
lowering, discretization, matrix/vector assembly, topology transfer, coupled
solve, candidate identity, provider evidence, physics, or engineering
evidence. It does not close or credit `UP2-01`, `UP2`, `B00`, `B04`, provider,
mesh, engineering, physical gates, `R01-R10`, or `L4`. B, C, and D are not
authorized by this A acceptance.

## Boundary and ownership observation

The reviewer observed that `source.owner` is required to be explicit and
nonempty but is not required to equal `conservation_owner`. This is a
nonblocking observation for the current A declaration because source
ownership and conservation ownership are explicit fields and the conservation
owner is checked across the IR. It must not be interpreted as provider,
source-authority, trust-root, or external-attestation evidence.

The source implementer, test/oracle owner, independent reviewer, and
integration/documentation owner are pairwise-distinct Luna roles. The
reviewer cannot review their own change or another role's same change. No
source, test, oracle, shared entrypoint, registry, Project, Manifest,
candidate, or provider file was changed by this acceptance record.

## Frozen A evidence

The reviewed inputs and hashes are retained in
`../delivery_r1/manifest.json` and `../independent_review_r1/manifest.json`:

- source `ManufacturedEquationIRV1.jl`: `0b456dcc0df3bd13a1941aa502a9cc5347912b2fa86cda6c65900449299b8e57`;
- test `manufactured_equation_ir_v1_tests.jl`: `654c2c06d0ab0d9a12a20c602a422b35ab84b2a9d00cda034a15beb79d558634`;
- oracle `equation_ir_oracle_v1.py`: `0c975eabec07ff1263139636e31a36ccae27f3c437f80b8e9a667e1da329129e`.

The exact mathematical control is
`R(u)=-div(K grad(u))-f=0` on `[0,1 m]^3`, with
`u=x/L+y/L+z/L`, `K=diag(2+0.1x/L,3+0.05y/L,4+z/(30L)) m^2`,
`L=1 m`, `div(K grad(u))=11/60`, `f=-11/60`, and `R=0`. Time and
multifield remain `terminal_deferred`.

## Re-entry and preserved gates

The exact formal route remains
`T0 → authority recheck → T1 → T2 → aggregate → UP2-00 → UP1-04B → UP1-04 → UP2-01`.
The 39-node dependency and all `R01-R10` acceptance gates remain open.
Fresh authority/trust, candidate identity, provider, B00/B04, solver-input,
engineering, and physical evidence remain required at their owning gates.

No Julia, Python, solver, mesh, or physical run was made for this root
acceptance. Existing A implementation, test, oracle, delivery, integration,
review, raw evidence, and failure history remain protected.

