# Magic 3D · Godot 4 工程底座

本目录为 `magic-3D`（`city-fates-3d`）的 Godot 4.x（Forward+ / Metal & Vulkan）3D 工程起步底座。

## 当前状态（v0.2.2 · 纯规范/计划/单源数据基线，等待 Wave 0 施工）

> 遵照架构规划与代码施工分离边界，本目录当前刻意移除先前的临时原型脚本（已清理 `.py` / `.gd` 草案），只保留清晰可审阅的**唯一真相源数据 + Godot 4 废城白盒场景**；全部运行时与校验工具代码从 Wave 0 起依据 `data/rules/dsl_rules_v0_2.json` 统一落地。

- `data/schema/`：两份 Draft 2020-12 `v0.2.2` 强约束校验 Schema（`magic_dsl_v0_2.schema.json` 与 `semantic_intent_v0_2.schema.json`）。
- `data/rules/dsl_rules_v0_2.json`：唯一权威规则注册表（能力矩阵、材料×相态矩阵、DAG/句柄约束、能力单调预算公式、状态驱动 ArtKit 默认映射表与 50 词真实符文库）。
- `data/tests/validator_negative_vectors.json`：21 条共享负向非法构筑规范（12 基础 + 9 压力测试），供 Wave 0 Python/GDScript 共用验证。
- `data/spells/`：7 份现象完整、满足战斗契约与 `SpatialDistribution` 规范的 `v0.2.2` 基准样例 JSON（Case 1–6 + 复合暗月；**Case 7 留白盲测**）。
- `data/intents/`：严格使用 50 枚真实中文实词的 `SemanticIntent v0.2.2` 示例。
- `scenes/main.tscn`：最小 3D 废城光影占位场景（无悬空脚本，Godot 4.3+ / 4.4+ 可直接打开）。

## 目录结构

| 路径 | 状态与用途 |
|---|---|
| `data/schema/` | **[已就绪]** `CompiledSpellDSL v0.2.2` 与 `SemanticIntent v0.2.2` JSON Schema |
| `data/rules/` | **[已就绪]** `dsl_rules_v0_2.json` 单源声明式规则表 |
| `data/tests/` | **[已就绪]** `validator_negative_vectors.json` 21 条共享负向测试规格 |
| `data/spells/` | **[已就绪]** 7 份跨领域 v0.2.2 法术基准样例 JSON（Case 7 故意留白用于 Wave 2 盲测） |
| `data/intents/` | **[已就绪]** 真实中文词义组合从句样例 JSON |
| `scenes/` | **[已就绪]** 纯净废城白盒主场景与区块挂载 |
| `tools/` | **[Wave 0 待施工]** 基于单源规则的 CI 离线校验工具 |
| `scripts/dsl/` | **[Wave 0–1A 待施工]** 单源规则加载器、4 阶段校验器及 Wave 1A 20 词编译器 |
| `scripts/director/` | **[Wave 1A 待施工]** 状态驱动 `ArtKit` 演出导演与多法术仲裁栈 |
| `scripts/combat/` | **[Wave 0–1A 待施工]** 慢拍动作底盘、输入状态机与 `ON_INTERRUPT` 控制器 |
| `shaders/` & `assets/` | **[Wave 1A–1B 待施工]** 四层视觉栈 Shader 与废城视听资产 |
