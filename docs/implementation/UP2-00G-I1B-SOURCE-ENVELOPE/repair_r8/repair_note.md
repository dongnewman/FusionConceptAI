# G-I1B-A narrow repair R8

Status remains `review_pending`; `accepted=false`. The preserved
`focused_r3/` evidence reports exit 1 with ten semantic assertion failures,
all in N10-03 across the E1-present and both-absent factory paths. The
failure was in the independent expected manifest: it read the outer G3 bundle
contract reference (`package.g3.contract_binding.contract_ref`, version v5),
while the production source locator `/g3/binding/contract_binding/contract_ref`
reads the binding child (`package.g3.binding.contract_binding.contract_ref`,
version v2).

The test-only repair changes exactly that expected-manifest accessor. It does
not change the production source, fixture, runner, core loader, actual-A
factory paths, independent attempted/hash calculation, 50-row assertions,
classification checks, zero downstream counters, or any prior evidence.
The focused_r3 command, stdout/stderr, input manifest and protected hash
record remain immutable. R8 is static-only by instruction; Julia and DESC
were not started, and the next serial focused run requires a different-Luna
static review first.
