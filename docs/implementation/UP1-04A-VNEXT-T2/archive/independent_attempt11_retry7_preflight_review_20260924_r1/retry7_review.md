# T2 attempt11 retry7 独立静态预审

审阅时间：2026-09-24 UTC（精确时间见 `retry7_static_audit.json`）。审阅者：`/root/t2_review`。

## 裁决

**NO-GO：不建议按 retry7 冻结包启动一次有界 Julia 执行。** 发现 controller r12 对畸形 RSS/CPU/子进程身份数据的校验不完整，`kill_tree` 也接受布尔 PID 并可能把它解析为 PID 1。retry7 的 153 项静态 QA 通过，但没有覆盖这些反例。另外，retry5/retry6 的失败工件虽仍在磁盘上，却没有进入 retry7 protocol 的哈希闭包或显式 lineage。此结论仅针对执行就绪，不代表 T2 接受；本审阅未启动 Julia。

## 冻结身份与独立命令

- Protocol `c271961cdf6d5549a3167a1ce17527688f63a3a39688a07ca6e4b16db145f8b3`；coverage map r10 `d7f79b06d3f0cbf505d5321857767f40157ae0d38dc2706b989edaf8d97449c6`。
- Controller r12 `04c85a30d4f7a1f15c8c9016cc1b4000259d89a2a1b0ea337867e5e2a52e85ac`；driver r6 `5a71c6417cadd04c3f36f8461134de46f455debdf7c6e9f804181c589c3b590e`；projection validator r5 `4cc51a6e16591d2e55a93a1bc5fb6dde6752ee808419d6768b372e5abe510849`。
- Map builder r10 `3c106dd2f2852347ca2fb94b0c6b61e5d13cc1167444296ca55fbb46a31ffdb1`（r11 lineage builder input pin `56bd41f83e5354b19d18d19494b2dd9b7690f224b1c023a38beb502ec5fe38a9`）；static QA source r12 `f196e0bfc79d40d70875fdf2644774715483f02dc57ebcb64404b614bb3adf4`；freezer r12 `cdc2545d84caf8093fa3fd916011b77b654c19b3b5ac56b4bd51f42d4933aeda`.
- Static QA result `dbe55ad3a92839fa72abe37b48409d28b42b60f86e51ac93176b058e92b7a19a`；snapshot `3a70e551d862258a58a1469437ecc60b2f731fa756f3c6892877b4971da2a8d7`。
- 从 repo root 独立重跑：`python -B test/GenomeV5/Integration/VNextT2FormalIndependentR1/static_qa_independent_negative_r12.py --protocol docs/implementation/UP1-04A-VNEXT-T2/archive/r2_protocol_freeze_20260924_t2_protocol_attempt11_preflight_600s_retry7/protocol.json --protocol-sha256 c271961cdf6d5549a3167a1ce17527688f63a3a39688a07ca6e4b16db145f8b3 --dispatch docs/implementation/UP1-04A-VNEXT-T2/archive/r2_protocol_freeze_20260924_t2_protocol_attempt11_preflight_600s_retry7/dispatch.json --command docs/implementation/UP1-04A-VNEXT-T2/archive/r2_protocol_freeze_20260924_t2_protocol_attempt11_preflight_600s_retry7/command_argv.json --report docs/implementation/UP1-04A-VNEXT-T2/archive/independent_attempt11_retry7_preflight_review_20260924_r1/static_qa_rerun.json`，exit 0，153 negative controls / 13 groups，Julia false，actual site hits pending。

## 已核门

- 独立重哈希：393/393 当前输入 pins、104/104 positive R3 pins、9/9 active guidance pins 匹配。Positive 和 guidance 记录均与当前输入 pin 完全一致。两个排除的 r3 `.pyc` 仍在磁盘、精确哈希不变且未清理；`-B` 静态 QA 复跑前后 cache 清单相同。retry7 archive 只有 JSON/raw 数据，无可执行载荷。
- Coverage map r10 与 attempt7 的 case/site ID 集、source text SHA、multiplicity、phase hit plan 相同。完整目标为 45 formal summary cases、60 个 unique cases、68 个 planned case hits、214 个 site IDs、622 个 planned site hits、30 个 controller phases。214 个当前 assertion 定位的物理起始行均与规范化完整断言文本前缀相符，source text SHA 匹配；relocation ledger 214 项中 175 项 path/line 改动、39 项不变。没有把 path/line byte equality 当成通过条件。
- Actual formal driver 的 12 个模式命令均为 16 个参数，coverage map path/hash 在第 15/16 位；包括三个固定负链模式和 9 个 authority case。Authority 计划为 9 cases、175 个 site IDs、75 个非零 site IDs、118 hits；context transport 23 个 site IDs、四个正式 phase 共 92 hits。部分或未终止的 case receipt 不可 join，record 前缀仅供观察，case 顺序和 resume ancestry 由静态 QA 检查。
- Projection reuse：157 个历史输入中 151 个精确相交、6 个逐项排除，159 项依赖子集；Python preflight natural exit 0，`T2_PROJECTION24_REUSE=PASS sites=24 groups=4`，reuse receipt 24/24 sites。
- Resource gates保持 full scope：普通 phase 480s，唯一 preflight phase 600s，authority phase/case 各 2400s，process-tree RSS sampled threshold 2 GiB，Julia 与 OpenBLAS 均单线程。静态 QA 报告 coverage thresholds 未变。Frozen command 只有数据形态的 `command_argv.json`；计划输出叶在磁盘上不存在，未发现 Julia 进程。Protocol 明确 `formal_t2_accepted=false`、`actual_source_site_hits=pending_julia_execution`。

## 阻断项

### 1. process-tree sampler 会把畸形读数标为 complete

在 [independent_negative_controller_r12.py](/D:/006-Programing/LMC/FusionConceptAI/test/GenomeV5/Integration/VNextT2FormalIndependentR1/independent_negative_controller_r12.py:632) 子进程 create_time 入枚举时没有检查类型/有限正值；行 649 和 657 的读取/校验处（[controller](/D:/006-Programing/LMC/FusionConceptAI/test/GenomeV5/Integration/VNextT2FormalIndependentR1/independent_negative_controller_r12.py:649)） 只对 root 做 identity 比较，RSS 用 `isinstance(rss, int)`，CPU 只检查是 `int/float`。因此 bool 被当作 int，且 CPU 没有 finite/nonnegative 约束。独立纯内存 fake 调用 `process_tree_sample` 得到 `sample_complete=true`、`errors=[]`：`rss=True` 计为 1 byte；user/system 为 bool、NaN/+Inf 或负值都被接受；子进程 create_time 为 True、0、-1 或 +Inf 也被接受。NaN create_time 因自比较不等而被拒绝。 Static QA 的 process monitor controls 检查 launch-root malformed timestamp、AccessDenied、PID generation 与终止/残余审计，但没有覆盖上述 RSS/CPU/descendant timestamp 取值域。

`run_phase` 在 行 989、996 与 999 处（[controller](/D:/006-Programing/LMC/FusionConceptAI/test/GenomeV5/Integration/VNextT2FormalIndependentR1/independent_negative_controller_r12.py:989)） 先记录并信任 `sample_complete`，再按 RSS 累计量比较阈值。因此 RSS 畸形为 bool 时，小值会通过 2 GiB 门；无效 identity/CPU 也能进入所谓 complete receipt。上述是 validator 对合成畸形输入的实测，不是实际 psutil 读数或运行期超限结论。

### 2. kill_tree 接受 bool PID 并依赖 create_time 二次比较

kill_tree 行 810 和 818（[controller](/D:/006-Programing/LMC/FusionConceptAI/test/GenomeV5/Integration/VNextT2FormalIndependentR1/independent_negative_controller_r12.py:810)） 用 `isinstance(pid, int)`，会接受 `True`，随后把它传给 `psutil.Process(pid)`；发信号的行 868（[controller](/D:/006-Programing/LMC/FusionConceptAI/test/GenomeV5/Integration/VNextT2FormalIndependentR1/independent_negative_controller_r12.py:868)） 发出 kill。隔离 fake 使 `Process(True)` 解析到 fake pid 1，且 create_time 等于 tracked 时间，结果 target fake kill 被调用，`complete=true`、`verified=true`、`errors=[]`。本审阅没有真实进程被创建或发送信号；当前 Windows 上单独只读构造 `psutil.Process(True)` 返回 NoSuchProcess（无 PID 1）。这仍是跨宿主/畸形 tracked identity 的 fail-closed 缺口，应在调用 Process 前拒绝 bool/非正 PID，并验证有限正 create_time。

### 3. retry5/retry6 失败没有绑定到 retry7 冻结闭包

retry5 和 retry6 失败目录各有 10 个 JSON/raw 工件，仍在 archive 中；retry5 QA fail（`attempt9b static QA failure details are inconsistent`），retry6 QA fail（`authority case resource contract mismatch: PARENT_STALE`）。但 retry7 `protocol.json` 中二者目录字符串命中为 0，`inputs` pin path 命中也为 0。因而当前冻结包不能证明这两次失败证据仍与本次审阅的 frozen lineage 对应。新版本需将两组 exact path/bytes/SHA 纳入 lineage，或明确给出并冻结排除理由；不能把“还在磁盘”当成 protocol-bound。

## 解阻条件

请出新的 versioned retry 包，保留 retry7 全部原始工件；不改 45/60/68、214/622、phase 顺序或数值阈值。新增 sampler 反例：bool/负 RSS、bool/NaN/Inf/负 CPU、子进程 bool/零/负/非有限 create_time；新增 kill_tree bool/零/负 PID 与非法 create_time 测试，并验证目标 fake 的 kill 次数为零、失败 receipt 不可 complete。对 retry5/retry6 记录 exact lineage pins。随后重跑 Python static QA、map/current-source 检查和新反例；通过后再交独立审阅。retry7 不得据此授予运行或验收。