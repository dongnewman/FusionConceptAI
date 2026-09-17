# AD-52 G3 source-authority factory hardening — independent review R3

Verdict: `pass_limited`; `accepted=false`. This review credits only the
fail-closed source-stage software behavior observed under the frozen inputs.
It grants no source authority, trusted attestation, candidate identity, final
package identity, provider, mesh, solver, engineering, physical, search,
R01–R10, or L4 credit. `L4=0`.

The reviewed implementation source is SHA-256
`ceac9a33368606843337194ee446b6de6f2b7c6223cbc110229d5df17cf84d39` (35,491
bytes), and the focused test is SHA-256
`23155dd7e7c6440177fe666fe463f73603b2c63a4572796801cbcee7d99c1e5b` (21,883
bytes). HEAD remained `4b69f55f7f80240147a65a22809dc1207824dde2` throughout.
The parent AD-52 manifest remained `package_status=completed_review_pending`
and `accepted=false`; fresh S2/S3 evidence remains required.

The independent serial Julia probe (PID `94348`, exit `0`) constructed a real
temporary HEAD-tracked Git fixture. All four exact scopes were `present` (4/4)
with one stage-zero index entry, 40-hex HEAD/blob IDs, `show`/`cat-file` /
working-tree byte equality, clean porcelain, and no trusted/candidate/final
publication flags. The current repository's four implementation source files
were independently observed as untracked and absent from HEAD; all four
returned typed absence with no source declaration. Eighteen adversarial
controls failed closed: scope, repository root, HEAD, path, source bytes/hash,
HEAD blob, path/status relabels, declaration ref, common handle, contract,
version axes, invalid scope, assume-unchanged, skip-worktree, and a mutated
working tree. The registry hash remained
`4c2f4383140527613782288749283d268497846ec915df158164875125677f45`.

The repository focused Julia lane (PID `94924`, exit `0`) passed `356/356`.
The independent planning validator (PID `100124`, exit `0`) checked 31
Markdown files, 534 relative links, 39 tasks, and an acyclic DAG. Static JSON
validation checked all eight R3 JSON files and passed. The scoped audit found
the frozen source/test and parent package files unchanged, HEAD and index
diff exits `0`, no remaining Julia/DESC-like processes, and no temporary
probe files in the parent `raw/` directory.

The reviewer-owned probe script was temporary and removed after its SHA-256
was recorded in `cleanup_r3.json`; the fixture was removed by the probe's
`finally` block. Raw command streams, PIDs, UTC timestamps, exits and hashes
are in `raw/*_r3.receipt.json` alongside the output streams. No source, test,
index, HEAD, or parent AD-52 evidence was edited, staged, or committed.
