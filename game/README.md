# City Fates 3D · Godot 4 工程底座

本目录为 `city-fates-3d` 的 Godot 4.x（Forward+ / Metal & Vulkan）3D 工程起步底座。

## 当前状态

- `scripts/dsl/` 与 `data/spells/` 为 **Draft v0.1**，与 [docs/02_魔法本体论与DSL讨论稿.md](../docs/02_魔法本体论与DSL讨论稿.md) 一一对应，待与 GPT 共同锁定 DSL v1.0 后再接入 Step 1–2 实机切片。
- `scenes/main.tscn` 为最小 3D 废城光影与导演节点占位场景（使用 Godot 4.3+ / 推荐 4.4+ 启用 Jolt Physics 即可直接打开运行）。

## 目录结构

| 路径 | 用途 |
|---|---|
| `scenes/` | 主场景及后续废城区块、角色、魔法载体场景 |
| `scripts/dsl/` | 不可拆分 4 层 `SpellDSL` 资源定义草案 |
| `scripts/director/` | 四拍演出程序化导演接口桩 |
| `scripts/combat/` | 待接入：慢拍动作底盘、韧性与系统交互状态 |
| `scripts/semantic/` | 待接入：构筑期词义校验与本地模型编译入口 |
| `shaders/` | 待接入：6 大领域程序化 Shader 与天地异象后处理 |
| `data/spells/` | 3 份跨领域标杆法术 JSON 草案（暗月缓降、引力沉渊、霜狱潮/织网） |
| `assets/` | 3D 废墟模块、材质贴图、动作与多层次音效资产目录 |
