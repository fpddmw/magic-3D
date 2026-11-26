# 02 · 魔法本体论与原子 DSL 讨论稿（v0.1 · 与 GPT 共创定稿用）

> **文档性质**：RFC 讨论稿（Draft v0.1）——同步对应 Godot 4 工程草案 [game/scripts/dsl/](../game/scripts/dsl/spell_dsl.gd) 与 3 份标杆 JSON 样例 [game/data/spells/](../game/data/spells/dark_moon_descent.json)。
> **当前任务**：与 GPT 共同推敲、质疑、压实本文件第 5 节的 **7 项开放议题（Q1–Q7）**，将 `SpellDSL` 锁定至 **v1.0** 后再进入 Godot 3D 实机验证。

---

## 1. DSL 的核心设计目标与铁律

我们要解决的核心矛盾是：**既不能靠人工穷举成百上千个固定技能模板，也不能把演出交给脆弱的自由脚本或逐帧大模型生成，而必须在“近乎无限的语义组合”下，稳定产出“各有清晰区分度、且每一招都厚重浪漫”的 3D 魔法。**

因此，这套 `SpellDSL` 必须同时满足四条铁律：

1. **不可再拆分的正交原子**：绝不按“火球、海啸、冰墙、黑洞”这类招式名词分类，而必须拆到数学拓扑、世界法则物性与四拍动力学原语。
2. **双路同源（Single Source of Truth）**：同一份 `SpellDSL` 必须同时驱动两条下游管线——
   - **世界与战斗数值交互**（伤害、削韧、冲击位移、碰撞实体、导电/引燃、遮蔽视野、重力/时间改写）；
   - **Godot 4 程序化表现与导演**（3D 几何生成、Shader 材质参数、蓄力异象、机位偏移、光影压暗、顿帧与 4 层空间音效）。
3. **大道至简，自带审美保底**：任何合法组装出来的 `SpellDSL`，哪怕来自奇思妙想的冷门符文组合，都天然包含**铺垫 → 蓄力异象 → 降临爆发 → 战后余韵**四拍节奏，绝不退化成“几颗塑料球飞过去”。
4. **对构筑期语义编译友好**：结构必须强类型、字段有限、枚举正交，使得确定性规则演算与本地轻量语义模型（仅在法坛构筑暂停时运行）都能稳定、可校验地翻译出合法 DSL。

---

## 2. 六大“大道领域”（魔法本体论）

在原 [5 基本元素与 11 衍生概念](design/元素与衍生元素.md) 的基础上，为了打破“只有元素碰撞”的局限并契合《艾尔登法环》式的庄严奇幻感，新体系确立 **6 个正交宏观法则领域**（保留原 48 枚真实词义符文的语境组合入口）：

| 大道领域 | 涵盖元素/抽象概念 | 世界交互职责 | 视觉与光影特征（Godot Shader 基调） |
|---|---|---|---|
| **水与寒（Water & Frost）** | 水、冰、雪、雾、潮汐 | 冲击推退、潮湿导电、灭火；凝冰形成**真实可站立可阻挡可碎裂的 3D 碰撞实体**；浓雾遮蔽视线 | 半透明折射水面与白沫、棱面冷光晶冰、沉重低空体积雾 |
| **火与岩（Fire & Stone）** | 火、熔岩、岩土、铁、晶石 | 灼烧与持续余烬、高温破冰、硬岩碰撞阻挡与砸击削韧 | 炽亮内核＋暗红裂纹熔壳、焦黑烟尘、带辉光的沉重石碑 |
| **风与雷（Wind & Lightning）** | 狂风、风暴、天雷、电荷 | 吹散雾气/火势、极速贯通、沿**水洼与金属导通图**瞬间连锁击穿与强麻痹削韧 | 空气扭曲波纹、分形强自发光电弧、骤明骤暗的雷暴闪光 |
| **星与引力（Star & Gravity）** | 星辉、满月、引力、斥力 | 失重悬浮、聚拢牵引、骤然重压崩落、高威力冲击波 | 深邃冷蓝/暗紫星尘、空间重力畸变透镜、碎石悬浮奇观 |
| **光与暗（Light & Dark）** | 圣辉、照明、暗蚀、遮蔽、影 | 驱散黑暗与显现隐藏痕迹；或吞没全场光源、切断感知与视距、持续侵蚀 | 刺破迷雾的金白光束；**负光照吸光黑域**与声音沉寂 |
| **时与界（Time & Boundary）** | 时间凝滞、回响、结界、空间裂隙 | 局部时间极度缓滞（冻结弹道与敌我动作）、单向/双向能量屏障、短距空间裂隙、地阵印记 | 局部色彩抽离与尘埃悬停、细密庄严的几何法环纹路、空间撕裂折边 |

> **如何承接旧体系中的“生命 / 毒 / 灵 / 以太”？**
> 生命、毒、灵与以太不再单开杂乱的小系统，而是按具体表现分别接入上述领域与关系维度（例如：枯竭/侵蚀对接「暗与时」、生机修复对接「光与水」、以太阵法对接「时与界」）。这一点列入第 5 节开放议题共同校准。

---

## 3. 四层不可拆分 Magic DSL 草案（v0.1）

对应工程代码：[spell_dsl.gd](../game/scripts/dsl/spell_dsl.gd)、[spell_contract.gd](../game/scripts/dsl/spell_contract.gd)、[spell_manifold.gd](../game/scripts/dsl/spell_manifold.gd)、[spell_essence.gd](../game/scripts/dsl/spell_essence.gd)、[spell_four_beat.gd](../game/scripts/dsl/spell_four_beat.gd)。

```text
SpellDSL {
  id, display_name, rune_signature[]

  // 第一层：施法契约（谁在成型、谁承担存续与代价）
  contract: {
    formation: INSTANT | CHANNEL_SCULPT,
    ownership: DETACHED | SUSTAINED_FOCUS | ANCHORED_VESSEL_OR_GROUND | SELF_ATTUNEMENT,
    charge_window_s, mana_cost, sustain_mana_per_s, interruption_rule
  }

  // 第二层：空间拓扑（不枚举招式外形，只定义 3D 几何载体维度）
  manifold: {
    dimension: POINT_0D | CURVE_OR_GRAPH_1D | SURFACE_2D | SOLID_3D | FIELD_3D | RELATION,
    scale_m, branch_count, anchor_target
  }

  // 第三层：法则与介质基因（同时决定物理化学规则 + 程序化 Shader 质感）
  essence: {
    primary_domain, secondary_domain, phase_shift_target,
    mass_weight, rigidity, conductivity,
    thermal_polarity, gravity_polarity, time_scale,
    luminance_polarity, opacity, leaves_persistent_state
  }

  // 第四层：四拍仪式与导演参数（铺垫 / 蓄力 / 爆发 / 余韵）
  four_beat: {
    // 1. 铺垫与蓄力异象
    charge_duration_s, charge_omen (DIM_SKY | FLOAT_DEBRIS | DRAW_MOISTURE | SILENCE_FIELD | GROUND_SEAL),
    // 2. 释放来源、运动规律与受阻响应
    genesis_source (CASTER | SKY_DESCENT | GROUND_ERUPTION | ENVIRONMENT_DRAW),
    motion_law (BALLISTIC | SLOW_ADVANCE | SWEEP_CREST | ORBIT_GUARD | IMPLODE_TO_SLAM | STATIC_ANCHOR),
    block_response (SHATTER | DEFLECT_SIDEWAYS | PENETRATE | ENCASE_OR_BIND | PASS_THROUGH),
    // 3. 爆发瞬间的导演脚本（由程序化导演直接消费）
    hit_stop_s, camera_pitch_shift_deg, camera_zoom_bias, ambient_dim_factor, audio_impact_weight,
    // 4. 战后余韵与地形留存
    aftermath_kind (NONE | PERSISTENT_SOLID | PUDDLE_WET | SCORCH_EMBER | FOG_CLOUD | GRAVITY_CRATER | RUNE_ECHO),
    aftermath_duration_s
  }
}
```

### 为什么这套四层结构可能实现“大道至简＋无限组合不撞车”？
- **横向组合**：同样是 `SURFACE_2D`，填入 `水`＋`SWEEP_CREST`＋`DEFLECT_SIDEWAYS` 就是“拍在盾上会炸开侧泄的海啸浪墙”；填入 `时与界`＋`STATIC_ANCHOR`＋`PASS_THROUGH` 就是“阻挡物理剑矢但可传导星辉的庄严结界壁”；填入 `暗`＋`SLOW_ADVANCE` 就是“贴地推进、吞没火把与视野的深渊暗幕”。
- **纵向变调**：改变 `genesis_source`（从自身挥出 vs 从苍穹降下 vs 从环境积水里抽取），连动作姿态、蓄力异象、镜头仰角和声音方位都会跟着一起质变。

---

## 4. 标杆法术推演与旧案例压力测试

### A. 三份已落盘的跨领域标杆样例（见 `game/data/spells/`）
1. **`dark_moon_descent.json`（《暗月缓降》）**：
   - `CHANNEL_SCULPT × DETACHED` ｜ `SOLID_3D` ｜ `STAR_GRAVITY + LIGHT_DARK → WATER_FROST`
   - 长蓄力时天色骤暗、寒雾垂落；高空凝出冰冷暗月缓慢压过战场（沿途冻结地表与熄灭弱火），撞击瞬间全场失声半拍并碎裂成大片持久寒冰残骸。
2. **`gravity_abyss.json`（《引力沉渊》）**：
   - `CHANNEL_SCULPT × DETACHED` ｜ `FIELD_3D` ｜ `STAR_GRAVITY（gravity_polarity = -1 → +3）`
   - 蓄力时周边碎石与轻型敌人被死寂拉离地面；爆发时音频骤抽、镜头微俯震动，十倍重力将目标连同悬石砸进地面，留下龟裂陷坑与高额削韧。
   - **单原子突变测试**：仅将极性反转（`gravity_polarity` 改为负斥力），立刻演变为《星爆斥潮》——蓄力向心吸气后骤然向四周掀翻一切弹道与盾卫。
3. **`frost_tide_web.json`（《霜狱潮／织网》）**：
   - `CHANNEL_SCULPT × SUSTAINED_FOCUS` ｜ `CURVE_OR_GRAPH_1D / SURFACE_2D` ｜ `WATER_FROST`（`phase_shift_target = SOLID_ICE`）
   - 先借地面/场中水汽延展交织成受阻可绕流的活水浪/网；**玩家松手收束的一瞬原地相变**，把当前贴在石柱与敌人身上的形态原样冻成真实可踩可砍的 3D 冰体。

### B. 对旧 [21 份水冰雾图鉴](design/魔法图鉴_水冰雾参考案例/README.md) 的压力测试（抽检）

| 旧图鉴条目 | 映射到新 `SpellDSL` 的方式 | 审视与需升级之处 |
|---|---|---|
| [M001 凝水贯刺](design/魔法图鉴_水冰雾参考案例/条目/M001_凝水贯刺.md) | `POINT_0D/1D` + `WATER_FROST (phase_shift: ICE)` + `PENETRATE` | 完美匹配，且 3D 下蓄力时的空气凝霜＋镜头拉近贯入极具爆发力 |
| [M004 回澜](design/魔法图鉴_水冰雾参考案例/条目/M004_回澜.md) | `SURFACE_2D` + `WATER_FROST` + `SWEEP_CREST` + `DEFLECT_SIDEWAYS` | 3D 里不再画 2D 纸片浪，而是真实带半透明折射与白沫的立体曲面潮汐 |
| [M015 雾织感应](design/魔法图鉴_水冰雾参考案例/条目/M015_雾织感应.md) | `FIELD_3D` + `WATER_FROST (FOG)` + `RELATION` + `SILENCE_FIELD` | 在 3D 暗黑废城雾海里，感应涟漪直接以冷蓝声纳光圈透出石柱后伏兵的方位 |
| [M017 伏霜印](design/魔法图鉴_水冰雾参考案例/条目/M017_伏霜印.md) | `ANCHORED_VESSEL_OR_GROUND` + `POINT_0D/1D` + `GROUND_SEAL` | 需收束为“庄严的地面/武器封印阵”，避免做成繁琐的机关陷阱微操 |

---

## 5. 待与 GPT 共同讨论并拍板的 7 项核心开放议题（Open RFC Questions）

下一轮与 GPT 讨论时，请逐一攻克以下 7 个问题——**只要这 7 题全部拍死，`SpellDSL` v1.0 就可以直接锁版开发**：

1. **Q1（组合拓扑的表达力上限）**：
   目前 `Manifold` 只有单一的 `dimension` 字段。像“外层是 `FIELD_3D` 的暗雾、内部藏着 `1D` 引雷链”或“先 `SURFACE_2D` 推进再原地分裂为多个 `POINT_0D` 弹幕”这类**两段式/嵌套式拓扑**，应该用**拓扑嵌套（Primary + Secondary Manifold）**表达，还是靠 **`Stage Transition`（释放中段→收束末段）** 来拆解？怎样才能既保持无限组合，又不让系统膨胀？
2. **Q2（`Essence` 物性基因的极简完备集）**：
   当前列了 `mass_weight / rigidity / conductivity / thermal / gravity / time / luminance / opacity` 等 8 个物理与交互标量。是否存在**缺失的核心大道基因**（例如“生命/生机与枯竭”、“空间穿透/折跃”、“精神/认知干扰”），或者哪些字段在游戏性上其实冗余、可以合并？
3. **Q3（契约维度是否足够完整而不臃肿）**：
   旧设计的“瞬发 / 维持 / 吟唱 / 仪式附魔”已重构为 **`formation`（瞬发 vs 蓄势塑形） × `ownership`（脱手 / 专注维系 / 载体或地面寄托 / 自身同调）**。这 `2 × 4` 的矩阵是否已经覆盖了“反制契约、时序回响、环境地阵、护体姿态”？有没有某个组合在动作冒险手感上其实是无效组合？
4. **Q4（“铺垫与蓄力”如何在慢拍动作战斗中兼顾爽感与不被打断到烦躁）**：
   如果长蓄力要营造法环级浪漫，动作节奏又偏沉重，如何设计 **“阶段式蓄力门槛”**（例如：点按打出干脆的 1 拍轻法术；蓄满 1.2s 进入天地异象段，即便被打断或提前松手也能以当前成型的半成品轰出）？这段状态机应该如何写进 `FourBeat` 协议？
5. **Q5（48 枚词库与新增高阶抽象词的语义边界）**：
   现有的 [48 枚候选词](design/符文与词义设计.md) 主要围绕土/水/气/火/以太编写；面对“引力、星辉、时间凝滞、空间裂隙、光暗”等新领域，应该靠现有词（如`凝聚、反转、沉降、分离、循环`）语境多义推导出，还是增补少数极具神圣感的抽象核心词（如`星、重、时、界、虚`）？
6. **Q6（构筑期“确定性演算 vs. 本地大模型”的严格交接 Schema）**：
   玩家拼完符文回路后，确定性规则负责哪一部分，本地 3B–4B 小模型负责哪一部分？如何设计一套**静态校验器（预算点数、风险代价、合法数值区间）**，防止模型把某招编译成“0.1 秒瞬发、全屏秒杀、无限持久”的破坏平衡怪胎，同时保留语境涌现的惊喜感？
7. **Q7（Godot 4 渲染与导演映射的 1-to-1 可实现性审计）**：
   针对 `dark_moon_descent`、`gravity_abyss`、`frost_tide_web` 三份样例里的每一项参数，审视 Godot 4.x（Forward+ 体积雾、Custom Shader、GPUParticles3D、Camera3D 偏移）是否都能用**不超过 6–8 个高通用度基础场景/Shader 模块**稳定渲染出来，确保不存在需要为单个法术手写代码的“虚假原子化”。
