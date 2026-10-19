# Independent T2 R18 preflight review

Verdict: GO for one serialized bounded formal attempt only. This is not T2 acceptance; this reviewer did not run Julia.

The retry2 protocol, coverage map, controller, freezer, static QA, and host probe hashes were checked. The fresh Python static QA exited 0 with 580 current inputs, 30 negative controls, and 5 positive controls. An independent PowerShell SHA-256 audit also matched all 580 paths, byte lengths, and hashes.

R18 fixes retry7 at both consumers. The baseline calls the strict helper before any Julia phase. The final global-heavy audit calls the same helper. The helper rejects malformed or incomplete receipts, nonempty process/controller/native-identity/error lists, and invalid native snapshots. These failures make the final audit incomplete and prevent a clean phase result.

Host smoke r4 records a natural Python child exit 0 with an exact terminal-sample-race receipt and confirmed wait through the original root handle. The timeout child exits 15 with phase_wall_timeout, verified termination, and complete final audit. R18 retry1 and earlier R17 host failures remain pinned.

Coverage remains 30 phases, 45 formal cases, 60 unique cases, 68 case hits, 214 assertion-site IDs, and 622 planned hits. Authority remains 175 sites / 75 nonzero / 118 planned hits; transport remains 23 / 92; projection remains 24. Resource gates remain 480 s default, 600 s preflight-only, 2400 s authority phase and case, 2 GiB sampled process-tree working-set stop threshold, and one Julia plus one BLAS thread.

The planned output directory is absent. The freeze archive has 11 data files (7 JSON and 4 raw), no executable/source payload, and command_argv is data. Runtime hits and acceptance remain pending.

The freezer command and exit 0 are recorded from the owner handoff; the frozen snapshot reports status pass. The owner leaf does not include raw freezer stdout or stderr sidecars.
