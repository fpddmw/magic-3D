# 项目协作约定（AGENTS）

2026-11-26 · 适用于本仓库所有协作者与 AI 会话（GPT / Claude / Gemini / Antigravity）。

## 1. 项目身份与绝对优先级

本项目是一款 **3D 庄严奇幻废城动作冒险游戏**，以《艾尔登法环》式的宏大废墟氛围与慢拍厚重动作作为生存底盘，以**基于规律组合的语义魔法生成空间**作为核心灵魂与最高辨识度。

所有设计与工程决策必须服从以下优先级顺序：
1. **魔法生成空间与三层原语架构（`Semantic Primitives` → `Magic DSL v0.2` → `Runtime Kernels`）**
2. **同源爆炸级 4 层视听质感与沉重慢拍 3D 动作博弈**
3. **高自由度、因果诚实的共享世界规律（`WorldLaw`）**

## 2. 不可越过的工程与设计红线（防跑偏护栏）

1. **三层隔离不可混淆**：严禁将工程实现载体当作上层语义本体，也严禁允许模型编写无限制运行时过程脚本或跳过能力矩阵。所有执行载体严格收束为 **`BODY / PATH_GRAPH / SURFACE / REGION`**，非几何基础设施严格独立为 **`Reference / Relation / Process / Resource`**。
2. **禁止法术名特判与退化回技能枚举**：`carriers/`、`runtime/`、`world_law/` 与 `art_kit/` 严禁出现 `if spell.id == "..."` 或复合技能枚举（已冻结退役 v0.1 反模式）。
3. **引擎与空间不可回退**：采用 **Godot 4.x（Forward+ / Metal on macOS / Vulkan on Windows + Jolt 3D）** 实现真实 3D，**必须同时支持开阔苍穹外景与挑高哥特室内战斗**；严禁退回 2D 像素或自研底层 CFD 连续流体求解器（拒绝 CSG 布尔与任意网格切割）。
4. **兼顾普通玩家硬件与构筑期算力隔离**：
   - 目标 Apple M6 及普通中端独显 1080p 稳跑 60 FPS（战斗显存 $\le 2.5\text{ GB}$）。
   - 若接入本地轻量语义模型，**仅在“法坛构筑 / 世界暂停”阶段输出 `SemanticIntent`**，经确定性编译器降维并静态校验为 `CompiledSpellDSL` 后释放模型算力；**战斗中保持 0 模型开销、0 帧率损耗**。
5. **严禁空壳 TODO 与丑陋白盒过关**：Wave 1 就必须同时交付废城暴雨石殿氛围、4 层复合视觉栈、4 层动态音频与沉重动作手感门禁。未经实机运行验证的能力一律标为草案/待验证。

## 3. 当前活跃里程碑

- **当前阶段**：**`Magic DSL v0.2.1` 审计收口与 4 阶段验证通过，待 GPT / Claude 联合交叉复审后启动 Wave 1A**。
- **主入口**：
  - 正式规范（v0.2.1）：[docs/02_Magic_DSL_v0.2_正式语法与语义规范.md](docs/02_Magic_DSL_v0.2_正式语法与语义规范.md)
  - 分波次计划与审阅清单：[docs/06_Magic_Runtime_三波次实施与验收计划.md](docs/06_Magic_Runtime_三波次实施与验收计划.md)
  - 校验 Schema 与 7 份基准样例：[game/data/schema/magic_dsl_v0_2.schema.json](game/data/schema/magic_dsl_v0_2.schema.json) · [game/data/spells/](game/data/spells/case1_water_weave_freeze.json)
  - 4 阶段离线自检工具：[game/tools/validate_dsl.py](game/tools/validate_dsl.py)
  - 契约代码桩与导演仲裁：[game/scripts/dsl/](game/scripts/dsl/magic_dsl_types.gd) · [game/scripts/director/](game/scripts/director/spell_director.gd)

## 4. 资料同步与协作纪律

- **历史边界**：旧仓 `../city-fates`（含 C++20/Vulkan 引擎、`src/` 旧原型）与本仓冻结的 v0.1 讨论稿已明确停用，详见 [docs/00_资产清点与迁移清单.md](docs/00_资产清点与迁移清单.md)。
- **版本管理**：重要规范调整或每波次实机门禁验收通过后再提交与推送，严禁删除无关资产或覆盖用户修改。
