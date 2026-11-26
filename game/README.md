# Magic 3D · Godot 4 工程底座

本目录为 `magic-3D`（`city-fates-3d`）的 Godot 4.x（Forward+ / Metal & Vulkan）3D 工程起步底座。

## 当前状态（v0.2 · 待联合终审后进入 Wave 1）

- `data/schema/` 提供两份 Draft 2020-12 强约束校验 Schema（`magic_dsl_v0_2.schema.json` 与 `semantic_intent_v0_2.schema.json`）。
- `data/spells/` 提供 **5 份跨领域 `Magic DSL v0.2` 验证样例**（水网冻冰、引力沉渊、雾织感应、有限平面结界、多主体复合暗月），与 [02 · Magic DSL v0.2 正式语法与语义规范](../docs/02_Magic_DSL_v0.2_正式语法与语义规范.md) 严格对齐。
- `scripts/dsl/` 与 `scripts/director/` 为 v0.2 契约代码桩与硬预算常量；具体 Wave 1–3 运行时模块规划见 [06 · Magic Runtime 三波次实施与验收计划](../docs/06_Magic_Runtime_三波次实施与验收计划.md)。
- `scenes/main.tscn` 为最小 3D 废城光影占位场景（使用 Godot 4.3+ / 推荐 4.4+ 启用 Jolt Physics 即可直接打开运行）。

## 目录结构

| 路径 | 用途 |
|---|---|
| `data/schema/` | `CompiledSpellDSL v0.2` 与 `SemanticIntent v0.2` 严格 JSON Schema |
| `data/spells/` | 5 份跨领域 v0.2 法术样例 JSON（已通过 Schema 严格校验） |
| `scripts/dsl/` | v0.2 正交枚举、硬预算常量、能力矩阵与文档校验桩 |
| `scripts/director/` | `ArtKit` 只读状态/事件演出导演接口桩 |
| `scripts/combat/` | Wave 1 目标：慢拍动作底盘、四分离受击与防穿墙相机 |
| `scripts/semantic/` | Wave 3 目标：确定性展开器与暂停期本地模型编译器入口 |
| `scenes/` | 主场景及废城区块、角色与魔法载体场景 |
| `shaders/` | `ArtKit` 四层视觉栈程序化 Shader 目录 |
| `assets/` | 3D 废墟模块、材质贴图、动作与多层次音效素材目录 |
