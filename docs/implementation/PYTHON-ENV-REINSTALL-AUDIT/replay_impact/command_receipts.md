# Command receipts

所有命令均为只读检查或不会写入目标文件的 CLI help/JSON parse。工作目录均为 `D:\006-Programing\LMC\FusionConceptAI`，时间为 2026-09-15。

| 命令 | exit | 关键输出 |
|---|---:|---|
| `conda env list` | 0 | project-local entries: `.conda-cql3d-build`, `.conda-pleiades-public`, `.conda-vmex`; named `base`, `newquant`, `test`; the two `.venv-*` directories are not listed by conda. |
| `D:\Users\Newman\anaconda3\python.exe docs/v4_multitopology_generation/validate_plan.py --help` | 0 | argparse help displayed; no `--report` supplied. |
| `...\.venv-desc\Scripts\python.exe benchmarks/desc_heliotron_v0173/normalize_reference.py --help` | 0 | argparse help displayed; no output argument supplied. |
| `...\.venv-freegs\Scripts\python.exe scripts/runtime_v4_freegs_axisymmetric_runner.py --help` | 0 | argparse help displayed; no input/output supplied. |
| `...\.conda-pleiades-public\python.exe -c 'json.load(task_manifest.json); print(json_parse=ok)'` | 0 | `json_parse=ok`. |
| `.venv-desc python -m pip check` | 1 | `desc-opt 0.17.3 requires jax-finufft, which is not installed.` |
| `.venv-freegs python -m pip check` | 0 | `No broken requirements found.` |
| `.conda-vmex python -m pip check` | 0 | `No broken requirements found.` |
| `.conda-pleiades-public python -m pip check` | 0 | `No broken requirements found.` |
| `git rev-parse HEAD` | 0 | `4b69f55f7f80240147a65a22809dc1207824dde2` |
| `git status --short --untracked-files=all | Measure-Object` | 0 | 3547 existing dirty/untracked entries at audit time. |

The environment inventory also used read-only `python -c` metadata/version probes, `python -m pip list --format=freeze`, `conda-meta` JSON reads, `Get-FileHash`, and `direct_url.json` reads. No install, update, remove, solver, Julia, DESC, FreeGS, VMEX, Pleiades, or CQL3D execution was issued.

Relevant current digests:

- DESC interpreter: `cec2fab4b3258900cc330346de8c664e57fa04227406920a6edb06f0efeeebb1`.
- FreeGS interpreter: same `cec2fab4b3258900cc330346de8c664e57fa04227406920a6edb06f0efeeebb1`.
- VMEX interpreter: `0937d5ac6dd108c73b0fad5d25c8da700038673f212242dbae4901fce8573de6`.
- Pleiades interpreter: `3c573165deb67c2af3ab3495044a04bfb0d895edb2611ebe3e9cb77a6629715b`.
- `requirements-desc-windows-fixed-boundary.txt`: `1594a1452ec9de87b03e1567af6228e512e312661f81196b42602adb4c4a2ac0`.
- `requirements-freegs.txt`: `cfa05df8e8b113948947770add1f088116f2865c4662111a26a3b446229681ae`.
- `requirements-pleiades-public.txt`: `4bd8959df90c3ddf33fb08819b290719031657bfa9753c4f6140040918960d57`.

