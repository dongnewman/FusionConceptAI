# G-I0 R5 dependency reconciliation commands

- Current SHA-256 read-only inventory: `input_hashes.json`; included AD-26 core status, FusionConceptAI/Integration, G-I0 entry/test/runner/probe, every UP2 source loaded by the entry, N05/N06 source inputs, external E1/E2 test-only files, and R1/R2/R3/hold records.
- JSON parse of the new archive and protected historical manifests: exit `0`.
- Control-character scan: exit `0`; bad count `0`.
- Protected dirty-hash comparison against `protected_dirty_hashes.json`: exit `0`; 19 files, 0 mismatches.
- `python docs/v4_multitopology_generation/validate_plan.py`: exit `0`; 31 markdown files, 329 relative links, acyclic DAG.
- Scoped `git diff --check`: exit `0`; existing line-ending warnings only.
- Process sweeps: first QA sweep observed `2` transient Julia/DESC entries, immediate identity sweep `0`, final `Get-Process` sweep `0`; no runtime was started.

This is a static gate. The serial runner must repeat the process and hash preflight immediately before any launch.
