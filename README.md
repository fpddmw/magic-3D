# Magic 3D / City Fates 3D

这是一款以语义魔法构筑为核心的 3D 奇幻废城动作冒险游戏。玩家在法坛理解并组织符文，在断桥和高拱石殿间用走位、格挡与近战争取施法窗口。改变一枚符文的所指，可以改变力量在世界中的实际后果。

**从 [Magic Core](docs/magic_core/README.md) 开始。** 世界公理约束何种魔法成立，词义与构造关系给出解释，Core 保存确定的意义。游戏逻辑、艺术表现和施法体验各自转译；执行 v0.2.2 提供 Godot 4 / Forward+ / Jolt 的下游契约。

| 要做的工作 | 入口 |
|---|---|
| 讨论或修订设定 | [世界公理与概念](docs/magic_core/世界公理与概念.md) · [决定与版本迁移](docs/magic_core/资产迁移与版本.md) |
| 编写语义构筑 | [语言与 Core DSL](docs/magic_core/语言与Core_DSL.md) · [词义登记](game/data/core/meanings.json) |
| 比较新旧构筑 | [21 例覆盖矩阵](docs/magic_core/案例覆盖与语义验收.md) · [水冰雾参考数据](game/data/examples/water_core_cases.json) · [跨域构筑](game/data/examples/law_core_cases.json) |
| 对接世界、艺术和动作 | [三路转译契约](docs/magic_core/三路转译契约.md) · [Godot 与数据导航](game/README.md) |
| 准备施工与验收 | [阶段 A–E 计划](docs/06_Magic_Runtime_三波次实施与验收计划.md) · [交付清单与验证范围](docs/magic_core/交付清单.md) |
| 废城与动作设计 | [游戏总纲](docs/01_设计哲学与总纲.md) · [世界结构](docs/03_世界结构与废城探索.md) · [动作与导演](docs/04_动作底盘、战斗与演出导演.md) |

阶段 B 已交付离线语义编译器，可直接编译一张新构筑图并核对推导与执行条件。[运行方法与三组验收](docs/magic_core/阶段B_编译器与验收.md)。目标性能、视听和动作手感留到实机验收。原有 [v0.2.2 执行基线](docs/02_Magic_DSL_v0.2_正式语法与语义规范.md)、[水冰雾图鉴](docs/design/魔法图鉴_水冰雾参考案例/README.md)与[旧仓审计](docs/00_资产清点与迁移清单.md)均可查阅。
