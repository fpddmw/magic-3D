# Magic 3D · 废城中的语义魔法

玩家在法坛用少量符文表达意向，模型构思完整现象。确认后的 **Magic DSL v0.3** 保存形成过程、局部责任、世界作用和视听轨道。承落的光幕可以接住石块，也可能因负荷过大而破裂；另一道外观相同的光幕可以改变观察条件，让石块照常通过。

| 活动入口 | 内容 |
|---|---|
| [魔法形而上学](docs/v0.3/魔法形而上学.md) | 性质和以太公理、五种构思逻辑、因果与世界作用 |
| [20 枚符文与编译契约](docs/v0.3/符文与编译契约.md) | 构筑图、锚定、一次生成、确定性读解及训练记录 |
| [Magic DSL v0.3 正式规范](docs/v0.3/Magic_DSL.md) | 六部分配方、过程与资源、能力边界及复现命令 |
| [离线验收](docs/v0.3/验收.md) | 压风、三种守护、断边、寄托与实机边界 |
| [机器契约与配方](game/data/magic_v0_3) | Draft 2020-12 Schema、注册表、计费表与场景 |
| [废城世界](docs/03_世界结构与废城探索.md) · [动作与导演](docs/04_动作底盘、战斗与演出导演.md) | 共享空间、慢拍动作及视听目标 |

在仓库根目录运行新基线的全部回归。

```sh
uv run --isolated --with-requirements tools/magic_dsl_v0_3/requirements.txt python -m unittest discover -s tests -v
```

旧 54 词、Magic Core 0.1.x 及执行 DSL 0.2.2 已[归档](archive/pre-v0.3/README.md)。Godot 当前保留既有场景，实机法坛、运行时接入及视听品质另行验收。
