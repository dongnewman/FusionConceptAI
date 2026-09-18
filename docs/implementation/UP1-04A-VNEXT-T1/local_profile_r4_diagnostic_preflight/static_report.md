# UP1-04A VNext T1 diagnostic preflight R4

状态：`prepared_not_executed`。本批仅增加测试专用 first-failure
diagnostic，不运行 Julia，不授予 T1、T2、UP1 或任何 R01–R10 credit。

## 变更边界

- `test/GenomeV5/Integration/vnext_t1_projection_diagnostic_v1.jl` 是
  additive test-only 文件，由 focused test 在 `Main` 中 include；没有加入
  `FusionConceptAI.jl`，没有 export，也没有改变生产入口。
- 诊断器按生产 T1 admission 的顺序逐阶段调用 snapshot、declaration、child、
  feedback、no-legacy、output-gate 和 package 逻辑；捕获第一个异常。
- 返回值严格只有 `status`、`stage`、`exception_type`、`message_digest`；异常
  全文只在内存中用于即时哈希，不写入回执。
- focused test 当前仅断言 `status === :internal_failure`，并验证 stage/type/digest
  的类型；未知的首失败阶段、异常类型和摘要没有被硬编码。

## 静态验证计划

待父任务执行：

```text
python -B test/GenomeV5/Integration/static_qa_vnext_t1_candidate_state_package_v5_next.py
python -B test/GenomeV5/Integration/vnext_t1_candidate_state_package_v5_next_oracle.py
```

两条命令均应为只读静态/独立 oracle 检查；本批没有 Julia runtime receipt。

## 证据边界

当前仍保持 T1 `prepared_not_executed`、`accepted=false`、
`claim_ceiling=contract_only`。诊断输出只能定位当前 focused runtime 的首个
内部失败，不能把失败定位转化为 T1 acceptance、provider evidence、物理或工程
验证。
