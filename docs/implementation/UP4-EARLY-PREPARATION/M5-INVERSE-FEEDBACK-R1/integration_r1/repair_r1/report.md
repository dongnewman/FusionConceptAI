# M5 inverse-feedback integration repair R1

The repaired source/test/oracle freeze is `f0dcf8aa…53976`,
`f2279400…03ea2`, and unchanged oracle `6e13536a…9d0ab`. This repair lane
changed no source, test, oracle, shared entry, registry, Project, Manifest, or
evidence authority; its status is `review_pending`.

From `D:\\006-Programing\\LMC\\FusionConceptAI`, four authoritative child
processes ran strictly serially: Python oracle twice, then the current Julia
tests twice. Python both exited 0 with identical 2,174-byte raw/combined hash
`183b4eec…0647`. Julia both exited 0 and reported `203/203`; duration-only
raw hashes are `efe652a3…6a96d` and `b0202162…54299`, with empty stderr.
Every stream has an exact archive/raw copy.

The repaired test's independent probe ran separately and exited 0: 25 stored
derived-field and nested identity mutations all returned typed failures with
zero exceptions. It covered outer recovered parameters, all forward snapshot
fields, determinant/eigen/margin/roundtrip/seed/deletion ledgers, foreign
M5-A composition hash, nested M5-A hash/identity/owner/provenance, nested M4-D
owner/provenance, and joint owner/provenance mutations. It independently
recomputed the M5-A composition hash as
`722e59e841d6551fe9001e1279266e1aaf5a798ca0d16625d5a4fd81a59ab694`.

The exact expected semantic values remain target `(2/3,1/3)`, recovered
`(2,1)`, determinant `3`, eigenvalues `(1,3)`, margin `1/3`, round-trip `(0,0)`,
deletion response `(1/2,0)`, and delta `(1/6,1/3)`. The prior 103/103 record,
wrong-sequence attempts, timeout, and the probe path-resolution failure are
retained and explicitly non-authoritative; only this final captured
Python×2 → Julia×2 sequence plus the successful independent probe is current.

The ceiling is `manufactured_inverse_engineering_feedback/screen_only`, with
no formal UP4 credit and no optimizer, real-reference, candidate, provider,
solver, engineering, or physical evidence claim.
