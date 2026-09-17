# Commit scope audit — 2026-09-17

只读审计快照，供本轮临时文件/临时测试代码清理后做 selective staging。审计未执行 `git add`、`git commit`、删除或既有文件修改；机器可读清单见 [`commit_scope.json`](commit_scope.json)。

## HEAD 与工作树

- repository: `D:/006-Programing/LMC/FusionConceptAI`
- branch: `main`
- HEAD: `b2c04d8339774635aaecd73651efcdb101e01b5d` (`feat: publish Genome V5 source closure`)
- `git status --porcelain=v1 --untracked-files=all`: 10,868 entries = 27 tracked modifications + 10,841 untracked files.
- tracked diff: 27 files, `803 insertions / 469 deletions`; current worktree bytes of those 27 files: 319,175.

## 规模与分类

| 分类 | 文件数 | 字节 | 建议 |
|---|---:|---:|---|
| tracked modifications | 27 | 319,175 | 逐文件复核；除 `runs/**/task_queue.json` 外可作为当前波候选 |
| `docs/implementation/**` | 8,416 | 169,591,144 | 保留正式合同、复核、失败/raw；过滤临时日志/退出标记后再纳入 |
| `runs/**` | 1,384 | 580,381,851 | 保留在磁盘，不纳入本次 commit；禁止整树暂存 |
| untracked source/tests/tools/docs | 339 | 3,437,691 | 仅纳入当前波实际拥有、已复核的代码/测试/合同 |
| cache/bytecode | 68 | 1,030,467 | 清理候选；不提交 |
| temporary test outputs | 627 | 605,601 | 清理候选；不提交 |
| other/unknown | 7 | 7,480 | 先判定归属，不默认提交 |

其中 `docs/implementation` 的大体积内容不应被“临时文件清理”误删：正式失败、raw 输出、哈希/manifest、独立复核和当前波合同需要保留。相反，`*.log`、`*.exit*`、`*.stdout`、`*.stderr`、`*.pid`、`*.lock`、`*.out`、`__pycache__`、`*.pyc`、`tmp/**` 等列入排除清单。

## 建议 commit 边界

优先候选是当前波的 `src/GenomeV5/**`、`src/RuntimeV4/**`、相应 `test/**`、`tools/up1_external_closure_r{2,3,4}/**`、`test/up1_external_closure_r{2,3,4}/**`、相关 `scripts/**`/`benchmarks/**`，以及已复核的核心 v4 文档和 implementation 合同/复核/正式失败/raw。`AGENTS.md` 属于项目治理文件，若确认是本波新增则可纳入。

以下始终不应进入本次 commit：

- `runs/**` 全部运行目录；不要通过 `git add runs/` 或等价整树 pathspec。
- Python/pytest 缓存、Julia/测试缓存、临时日志/退出码/标准输出、`tmp/**`、根目录探针输出。
- 未确认归属的根目录 `0`、`1`、`FusionConceptAI/**`、`M4-SCOPE-DECISION-R1/**`、`independent_postrun_r5/**`、`independent_precheck_r9/**`；先核对 provenance，再决定是否移动到正式 implementation 档案并单独纳入。

`runs/goal_recovery_20260913_012528_cst/task_queue.json` 虽然是 tracked modification，默认仍排除；只有确认它是本波需要版本化的合同而非运行状态后才可单文件加入。

完整 include/exclude/review-only pathspec、27 个 tracked 文件名和清理策略已写入 [`commit_scope.json`](commit_scope.json)。

## 潜在 secret 扫描

对 status 中的 10,868 个路径执行模式扫描；10 个超过 120 MiB 的文件跳过，未发现 PEM 私钥、AWS `AKIA`、GitHub、Slack 或 `sk-` 高置信度模式。1 个文件命中通用 credential-like key/value 模式（仅报告路径和行号，不回显值）：

`test/up1_external_closure_r4/environment_closure/test_environment_closure_independent.py`，行 97、204；当前判断更像测试 fixture/synthetic token，提交前人工确认。

## 给父任务的执行顺序

1. 先按 `commit_scope.json` 排除项清理确认的 cache/temp/test output，保留 runs 和正式失败/raw。
2. 清理后重新采集 `git status`、大小、secret scan；不要复用本快照的数量作为最终状态。
3. 只对复核后的当前波 pathspec selective stage，单独检查 staged diff；然后再 commit。
