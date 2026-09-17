# N06 R10 static-negative-control count repair

状态：`review_pending`；只修改 N06 owned test，未运行 Julia/DESC，未修改生产 validator、runner、G1/G2/G3、E0、核心文档或 R1–R9 raw evidence。

R9 的 actual-A baseline `28/28`、typed occurrence index `3/3`、五个 source-derived mutation `31/31` 均已真实到达；唯一失败是测试行 263 将 fixture 的 14 个 static negative IDs 错写为长度 12。R10 将断言改为精确 14 项 ID 集合，并同时检查长度、去重和集合相等，避免只把数字改成 14 而漏掉某个控制。

逐项核对的 14 个控制为：`duplicate_resource_port_id`、`forged_source_locator`、`forged_source_type`、`same_dimension_exponent_mismatch`、`missing_power_flow_partner`、`foreign_valid_flow_link`、`reordered_network_dynamic_path`、`wrong_mutation_kind_for_target`、`relabeled_mutation_id`、`detached_projection`、`detached_g1_occurrence`、`foreign_e0_binding`、`missing_source_selector`、`wrong_source_selector`。测试已有对应执行路径：重复 resource port、forged locator/type、baseline dimension mismatch、mapping partner/link/detached-G1 controls、mutation kind/label/projection/E0 controls、source selector 删除与错 selector；R10 只修集合闭合断言，不删除或旁路这些执行。

R9 原始 receipt/stdout/stderr/process/protected hashes 保留；本轮只做 JSON/静态文本/hash/dirty/process QA。R10 不授予 B04、provider、mesh、工程、物理或 R01–R10 信用。
