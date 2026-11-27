# Godot 工程与语义编译数据

语义工作从 [Magic Core](../docs/magic_core/README.md) 开始。参考构筑包含玩家输入、解释后的 Core、逐节点推导与下游缺口，适合用于未来编译器的对照。阶段 B 的离线程序从这些规则生成 Core 与执行数据。[编译器与验收](../docs/magic_core/阶段B_编译器与验收.md)。当前 Godot 主场景为占位场景。

| 数据职责 | 活动入口 |
|---|---|
| 世界公理、概念与性质 | [world.json](data/core/world.json) |
| 词库、带类型的义项、版本决定 | [meanings.json](data/core/meanings.json) · [首批义项依据](data/core/matching_basis.json) · [构造与归一化](data/core/composition_rules.json) · [decisions.json](data/core/decisions.json) |
| 输入图、Core、Trace 的结构 | [共享 Schema](data/schema/magic_core.schema.json) |
| 手工推演的对照构筑 | [8 个水冰雾构筑](data/examples/water_core_cases.json) · [5 个跨域构筑](data/examples/law_core_cases.json) |
| 能力、执行限制和资源系数 | [能力对应](data/lowering/semantic_bindings.json) · [执行规则](data/lowering/execution_rules.json) · [平衡规则](data/balance/resource_budget.json) |
| 艺术模块与表达 | [ArtKit](data/art/artkit_registry.json) · [Expression](data/art/expression_profiles.json) |
| 方向、传播与词义对照 | [配对向量](data/tests/semantic/paired_projections.json) · [词义输入](data/tests/semantic/operand_witnesses.json) · [复核方法](../docs/magic_core/阶段A_配对验收.md) |
| 语义与执行反例 | [语义向量](data/tests/semantic/meaning_vectors.json) · [冻结的执行负向向量](data/tests/validator_negative_vectors.json) |

原 [综合表](data/rules/dsl_rules_v0_2.json)、[执行 Schema](data/schema/magic_dsl_v0_2.schema.json)、[意图 Schema](data/schema/semantic_intent_v0_2.schema.json)、[意图样例](data/intents/sample_intent_water_weave_freeze.json)与 [7 份基准所在目录](data/spells/)服务执行版本 0.2.2。旧 JSON 中的 VALID、预算估值与能力状态属于基准数据的陈述，实测另记。施工边界与首批任务见[研发计划](../docs/06_Magic_Runtime_三波次实施与验收计划.md)。
