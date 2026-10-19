# 子智能体交付模板

请求GPT-6 Luna/high；实现、测试、复核分开，root独占共享入口集成和正式运行，最多9名并行、重计算串行。本轮Goal仍暂停，模板不授权自行恢复。

## 一张接口表

| 必须明确 | 当前工单填写 |
|---|---|
| 输入 | 实际源码/数据路径、候选与变化状态；来源/适用域 |
| 输出 | 消费者需要的字段、单位、维度、区域/面/法向/积分及DOF映射 |
| 接线 | 精确消费者函数、R/J或solve入口；真实上下游依赖 |
| 缺口 | 未实现、未接入、缺物理关系/来源、数值失败、仅缺运行证据 |
| 责任 | 提供者、模块实现者、root接线、不同测试者与复核者 |

## 角色任务

实现：按整条调用链交付原位修改，单位/索引/错误处理一起完成；缺物理假设先集中决策，不暗设0。单一主线src，兼容仅处理真实差异。

测试：用现有真实消费者短检加载/字段/单位/维度/DOF、一真实残差及线性步、修改J列FD、准备耗时/内存。通过后才原完整A/B；每次长跑失败有具体原因及对应修改。复用仍适用合格结果，不增同义框架。

复核：检查完整接线、原覆盖/阈值、FD/oracle、来源/适用性、资源和实际结果；helper/静态/安装不算正式门。给GO/HOLD及范围，不重做实现者职责。

交付：可应用修改、消费者与精确验证命令；实际命令、退出、PID创建时间、必要输入/结果hash、资源收据、原始日志、独立结论。常规任务只写必要字段；正式参考inverse还必须有下面三Genome/识别/同链forward/盲留出结构，缺项如实typed_absent，不据此授通过。

```json
{
  "producer_consumer_shared_entry": null,
  "consumer_receipt": null,
  "genome_bundle": {
    "g1": {"typed_body_ref": null, "source_hash": null, "content_hash": null, "canonical_hash": null, "theta_field_mapping_ref": null},
    "g2": {"typed_body_ref": null, "source_hash": null, "content_hash": null, "canonical_hash": null, "theta_field_mapping_ref": null},
    "g3": {"typed_body_ref": null, "source_hash": null, "content_hash": null, "canonical_hash": null, "theta_field_mapping_ref": null}
  },
  "inverse_observations": null,
  "identifiability": null,
  "common_forward_receipt": null,
  "heldout_prediction": null,
  "actual_result_and_scope": null,
  "blocking_condition": null,
  "next_bounded_run_condition": null
}
```

旧T2独立控制器/生命周期/分片/R30协议已取消，不派发。保留真实T0/T1/source witness调用，不能因名字包含T2误删生产接口。运行环境归environment_owner，所有模块不共同陷入runner排障。禁止覆盖旧失败、批量暂存/删除runs或绕过已受阻清理。
