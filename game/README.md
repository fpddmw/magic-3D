# Magic 3D · Godot 4 工程底座

本目录为 `magic-3D`（`city-fates-3d`）的 Godot 4.x（Forward+ / Metal & Vulkan）3D 工程起步底座。

## 当前状态（v0.2.1 · Wave 0 验证门禁通过，待联合终审后进入 Wave 1A）

- `data/schema/` 提供两份 Draft 2020-12 `v0.2.1` 强约束校验 Schema（`magic_dsl_v0_2.schema.json` 与 `semantic_intent_v0_2.schema.json`）。
- `data/spells/` 提供 **7 份通过 4 阶段验证的 `Magic DSL v0.2.1` 基准样例**（Case 1 水网凝结、Case 2 引力沉渊、Case 3 连锁电势传导、Case 4 微风感雾障、Case 5 定界折光壁、Case 6 器物烙印延爆、多主体复合暗月；**Case 7 留白盲测**），与 [02 · Magic DSL v0.2.1 正式语法与语义规范](../docs/02_Magic_DSL_v0.2_正式语法与语义规范.md) 严格对齐。
- `data/intents/` 提供组合语义意图与 `bound_ids[]` 全链路溯源样例。
- `tools/validate_dsl.py` 为零外部依赖 Python 3 四阶段校验器（含 7 正常 + 1 意图 + 12+ 负向非法法术自检套件：`python3 game/tools/validate_dsl.py --self-test`）。
- `scripts/dsl/` 与 `scripts/director/` 为 v0.2.1 契约、4 阶段核验、能力矩阵与 `ArtKitArbitrator` 仲裁接口桩；具体 `Wave 0 → 1A → 1B → 2 → 3` 运行时规划见 [06 · Magic Runtime 三波次实施与验收计划](../docs/06_Magic_Runtime_三波次实施与验收计划.md)。
- `scenes/main.tscn` 为最小 3D 废城光影占位场景（使用 Godot 4.3+ / 推荐 4.4+ 启用 Jolt Physics 即可直接打开运行）。

## 目录结构

| 路径 | 用途 |
|---|---|
| `data/schema/` | `CompiledSpellDSL v0.2.1` 与 `SemanticIntent v0.2.1` 严格 JSON Schema |
| `data/spells/` | 7 份跨领域 v0.2.1 法术基准样例 JSON（Case 7 故意留白用于 Wave 2 盲测） |
| `data/intents/` | 组合语义意图从句与符文绑定溯源样例 JSON |
| `tools/` | `validate_dsl.py` 四阶段离线验证与 `--self-test` 负向套件 |
| `scripts/dsl/` | v0.2.1 正交枚举、硬预算常量、能力矩阵与 4 阶段 GDScript 校验契约 |
| `scripts/director/` | `ArtKit` 只读状态/事件演出导演与多法术 `ArtKitArbitrator` 接口桩 |
| `scripts/combat/` | Wave 1 目标：慢拍动作底盘、四分离受击与防穿墙相机 |
| `scripts/semantic/` | Wave 3 目标：确定性展开器与暂停期本地模型编译器入口 |
| `scenes/` | 主场景及废城区块、角色与魔法载体场景 |
| `shaders/` | `ArtKit` 四层视觉栈程序化 Shader 目录 |
| `assets/` | 3D 废墟模块、材质贴图、动作与多层次音效素材目录 |
