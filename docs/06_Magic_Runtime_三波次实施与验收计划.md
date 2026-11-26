# 06 · Magic Runtime 三波次实施与验收计划（Godot 4）

> **用途**：面向实现者（GPT / Claude / 开发者）的 Godot 4 施工蓝图与门禁标准。所有设计与数据结构必须严格对齐 [02 · Magic DSL v0.2 正式语法与语义规范](02_Magic_DSL_v0.2_正式语法与语义规范.md)。

---

## 1. Godot 4 运行时模块边界与代码布局

严格禁止把逻辑塞进少数巨型“上帝脚本”，亦禁止只写空壳 DTO 与 `TODO` 桩。`game/scripts/` 下的权威模块拆分如下：

```text
game/scripts/
├── dsl/                            # 数据模型、能力矩阵与 Schema 校验
│   ├── magic_dsl_types.gd          # 全部正交枚举与单法术/全局硬预算常量
│   ├── magic_capability_matrix.gd  # 能力矩阵与合法 TransformId 静态裁决表
│   └── magic_dsl_document.gd       # 编译后 DSL JSON 加载与引用完整性校验
├── runtime/                        # 60 Hz 固定步核心调度（6步结算协议）
│   ├── magic_world_tick.gd         # Step 1~6 固定顺序调度与帧末唯一权威提交
│   ├── subject_registry.gd         # Subject 实例生命周期、唯一 ID 与分裂重映射
│   ├── process_runner.gd           # 有限过程图、9类闭合事件、Handle 托管与预付储备
│   └── intent_arbitrator.gd        # 同通道多 ChangeIntent 合并、Capacity 冲突与同帧优先级裁决
├── carriers/                       # Layer 3 四大空间载体内核（禁止法术名特判）
│   ├── body_carrier.gd             # Jolt RigidBody/StaticBody、分段简单代理与 ≤12 碎裂管理
│   ├── path_graph_carrier.gd       # ≤16节点/24边、每步≤2次切向局部绕障、Desired/Realized 输出
│   ├── surface_carrier.gd          # 有限平面/条带/覆盖面、方向性阻挡/偏转射线与网格生成
│   └── region_carrier.gd           # Area3D 查询、Radial 剖面采样、遮蔽边界上报
├── world_law/                      # 共享世界规则库（7+1通道＋默认材料演化）
│   ├── material_catalog.gd         # Water/Ice/Stone/Fog/Flame 等固有性质、临界状态与默认演化
│   ├── mechanical_channel.gd       # 严格的四分离受击结算（HP/削韧/冲量位移/行动约束）
│   ├── conductive_channel.gd       # 空间接触与潮湿/金属导电图传播（带跳跃次数与距离预算）
│   ├── thermal_optical_channel.gd  # 积水留痕/蒸发、热传导相变、雾/暗域对 AI 视线遮蔽
│   └── temporal_channel.gd         # 预留 local_time_scale（先作用于局部行动/弹道速度与进程计时）
├── combat/                         # 慢拍 3D 动作底盘与敌我交互
│   ├── player_controller.gd        # 沉重移动/翻滚/格挡/法杖近战/锁定/蓄力门槛与打断策略
│   ├── combat_camera.gd            # 自由第三人称（A）+ SpringArm 防穿墙 + 导演偏置融合（B）
│   └── enemy_guardian.gd           # 慢拍石甲废墟骑士（韧性、盾防与真实视线射线/扰动感知）
├── art_kit/                        # 四层爆炸级视听同源管线
│   ├── visual_stack_composer.gd    # L1轮廓 + L2材质/折射/扭曲 + L3动态光与体积雾 + L4粒子与贴花
│   ├── audio_director.gd           # 蓄力低频/爆发前抽声留白/冲量分层重击+石殿混响/挣扎循环音
│   └── spell_director.gd           # 监听提交态、Desired-Realized 差值与真实世界事件
└── semantic/                       # Wave 3 后接入：确定性展开器与暂停期本地模型接口
```

---

## 2. 防敷衍与防退化红线（Review & QA 铁律）

任何波次的交付在进入审阅前，必须逐条核对以下 **5 条否决项**，触犯任意一条直接打回：

1. **零法术名特判**：`carriers/`、`runtime/`、`world_law/` 与 `art_kit/` 内严禁出现 `if spell.id == "..."` 或针对具体样例法术的硬编码分支。
2. **严禁空壳 TODO 冒充验收**：凡在验收清单中声明生效的能力，必须有真实可观测的 3D 几何/碰撞/状态改变与事件触发日志，不得仅靠打印日志或播粒子动画糊弄。
3. **严禁跳过视觉与声音门禁**：Wave 1 就必须具备暴雨/夜月/挑高石殿氛围、材质折射/扭曲/贴花、顿帧抽声与重击混响。拿简陋彩色线框交差即判失败。
4. **严禁突破场景与性能预算**：实时跑通 Apple M6（1080p 60 FPS）与普通中端显卡显存预算；任何超出 `MAX_FRACTURE_BODIES` / `MAX_ACTIVE_BODIES` 的衍生体必须确定性淘汰，不得无限泄漏。
5. **模型零战斗开销**：Wave 1–3 核心运行时严禁加载或调用任何 LLM；语义编译器仅能在暂停状态下的独立入口测试。

---

## 3. 三波次垂直实施路线

### Wave 1 · 核心闭环 ＋ “效果爆炸”废城美学与慢拍动作门禁
- **工程交付**：
  1. 完成 `dsl/`（JSON 加载、Schema 枚举、能力矩阵与预算核查）、`runtime/`（6 步 Tick、过程、句柄、`INTERRUPT` 优先级裁决）与 `art_kit/` 全部 4 层视听管线（含核心域 Shader：棱面晶冰、空间畸变重力波纹、结界光幕、地面 Decal 留痕，及 4 层音频总线）。
  2. 完成 `body_carrier`、`surface_carrier`、`region_carrier` 三大载体，以及 `world_law` 中的 `MECHANICAL`（四分离）、`THERMAL`、`OPTICAL` 基础规则。
  3. 搭建 **1 座贯通“暴雨断桥外景 → 挑高哥特石殿室内”的实机测试废城**，实装主角慢拍动作底盘（走/滚/格挡/基础攻击/锁定/蓄力阶梯与翻滚取消）＋ 1 名持盾慢拍废墟骑士。
- **Wave 1 强制验货（生死门禁）**：
  - **验收案例 2（`case2_gravity_collapse.json` · 引力先抬后砸）**：蓄力时场内碎石与轻敌真实浮起、天光微压、低频蓄能音拉满；爆发瞬间 40–80ms 抽声留白＋十倍向下冲量砸裂架势＋地面重力裂纹贴花＋石殿混响；**手动在 JSON 把重力方向改为向外斥力，零改代码即可验证完全不同的掀翻弹道效果**。
  - **验收案例 5（`case5_ward_mirror_surface.json` · 有限平面结界）**：在石柱间立起有限平面结界，能真实挡住/偏折敌方或己方弹道，受击产生光纹震荡与紧绷循环音；绕过平面边缘则不再阻挡（证明有限空间边界真实有效）。
  - **多主体验证（`case_compound_dark_moon.json`）**：验证 1 个 `BODY` 挂载 3 个 `FIELD` 的组合推进、接触破碎为 $\le 12$ 块真实碰撞冰体、同时临时场域自动撤销。
  - **美学与手感门禁**：你本人上手试玩 5 分钟，**必须觉得画面厚重浪漫、动作和施法打击感立得住、帧率稳 60 FPS**，方可进入 Wave 2。

### Wave 2 · 连续变形结构、相变刚体烘焙与跨法术世界状态
- **工程交付**：
  1. 完成 `path_graph_carrier`（16 节点 / 24 边、每步每节点最多 2 次切向局部绕障、输出 `Desired vs Realized` 偏差驱使视觉水花与紧绷音效）。
  2. 完成 `TRANSFORM: PATH_LIQUID_TO_BODY_SOLID`（将当前合法路径段按原有支点与连通关系转为有限复合 Jolt 碰撞代理体，支持受力断裂）及 `Propagate` 沿 `PATH_CONNECTIVITY` 渐进传播。
  3. 完成 `conductive_channel` 导电图与潮湿表面留存，以及 `FOG_REGION_TO_ICE_SHARDS`（消耗真实雾质量与视线遮蔽）。
- **Wave 2 强制验货**：
  - **验收案例 1（`case1_water_weave_freeze.json` · 水网塑形与沿连接冻冰）**：拉出的水带绕过石柱和敌人时发生可信的局部弯曲变形；松手 `RELEASE` 后从接触点沿连接图逐步冻成真实可挡箭、可踩踏、可被敲碎的刚体冰网；若被重击打断（`INTERRUPT`），已引出的水直接脱力泼洒落地形成导电水洼。
  - **不可交换性对照测试（$Freeze(Weave(W)) \neq Weave(Freeze(W))$）**：仅调换 `PROCESS` 里冻结与塑形的顺序，验证“先冻后织”输出刚性冰条卡位而不是贴身缠绕。
  - **验收案例 3（跨法术导电连锁）**：先用任意水魔法在场中留下积水与潮湿敌人，再对积水一端释放雷电法术——电势沿真实湿润与金属导电图自动跳跃传遍湿区，干燥高台上的目标不受波及。

### Wave 3 · 非物质关系、契约交接与“真生成空间”终极验收
- **工程交付**：
  1. 补齐 `COUPLE / INFORMATIONAL` 信息耦合通道；将 `OPTICAL` 遮蔽正式接入敌人 AI 视觉射线（雾与暗域真实切断敌人锁定与远程瞄准）。
  2. 完成载体/地面寄托契约（`ANCHORED_VESSEL_OR_GROUND`）与预付储备账户管理，完善载体破坏 `BROKEN` / 储备耗尽 `DEPLETED` 语义。
  3. 接入 `semantic/` 确定性展开器（将精简 `SemanticIntent` JSON 自动补全为合法 `CompiledSpellDSL` JSON），留出本地模型或词库界面的标准输入口。
- **Wave 3 强制验货**：
  - **验收案例 4（`case4_fog_disturbance_sense.json` · 浓雾遮蔽与扰动感应）**：浓雾切断敌方视线同时遮蔽己方视野；敌人或投石穿过雾区时，仅向玩家反馈方向性光环/声纳脉冲（**严禁透视敌人轮廓与身份**），零假顿帧。
  - **验收案例 6（载体/地面封印阵交接）**：施法者在石阶或兵器上寄托待发术式后自由跑开甚至换招；敌人踩入触发条件后由预付储备驱动爆发，打碎载体则触发未释放撤除或预设损坏后果。
  - **验收案例 7（终极防作弊“未预设重组测试”）**：**现场编写 2 份在开发期从未在需求里提到过的全新合法组合 JSON**（例如：“先建立高空持续抽热寒雾场，再用引力向上聚拢并瞬间触发 `FOG_REGION_TO_ICE_SHARDS` 形成悬空冰暴阵”或“在镜面结界上耦合扰动感知”），不改一行引擎代码，直接加载运行并评估视觉区分度、世界因果与可玩性。

---

## 4. 7+1 验收标准总览表

| 案例 | 逻辑与状态验证线 | 世界因果验证线 | 视听美学与预算线 |
|---|---|---|---|
| **Case 1** 水网冻冰（Wave 2） | `RELEASE` 沿 `u` 传播相变；`INTERRUPT` 撤支撑落地；换序异果成立 | 冻后冰网真实阻挡弹道与移动；断一根支柱余网重构或塌落 | 流动法线/白沫→棱面霜纹蔓延；紧绷音→脆裂声；节点 $\le 16$ |
| **Case 2** 引力沉渊（Wave 1） | `SLOW_BUILD` 升、`IMPULSE_SPIKE` 降；反转方向无需新代码即成斥力 | 轻碎片与敌人真实受向心/向下冲量；不可破坏石地不假造深坑 | 天光微压＋浮石；40–80ms 抽声留白＋重击震动＋裂纹贴花 |
| **Case 3** 湿区导雷（Wave 2） | 仅依赖 `CONDUCTIVE` 通道与湿润图，无水雷专属配对代码 | 踩在同一水洼内导电，踏上干燥石台或冰绝缘体即中断 | 分形电弧沿真实导通路径跳跃并瞬间照亮潮湿石殿墙面 |
| **Case 4** 雾织感应（Wave 3） | `COUPLE` 只传方向与扰动强度；撤支持后雾扩散且停止感应 | 真实切断敌我视觉射线；抽取雾做冰砂时对应区块视野同步变清 | 体积雾动态翻涌＋局部微弱涟漪光圈；零顿帧、空灵微音 |
| **Case 5** 有限平面（Wave 1） | `SURFACE` 绑定方向性阻挡/偏折；受阻超出容量时触发 `BROKEN` | 仅阻挡穿过有限面积的弹道，绕过侧边即可攻击 | 秩序几何纹理＋受击涟漪震颤＋紧绷音；面片 $\le 64$ |
| **Case 6** 器物刻印（Wave 3） | 预付储备托管，`CONTROL` 移交载体；`DEPLETED/BROKEN` 精确收尾 | 施法者跑离后仍独立按世界条件触发 | 载体地面浮现克制法环微光，不提前泄光 |
| **Case 7** 未预设重组（Wave 3） | 现场拼出全新合法组合，能力矩阵校验通过即跑 | 完整进入 6 步结算与自然演化，无跨界漏洞 | **不需手工改美术，依然拥有独特辨识度与四层质感** |
| **全局硬线** | 所有操作仅经 6 步 Tick 提交，表现不改写世界状态 | 战斗与近战格挡/韧性/位移四分离手感扎实 | Apple M6 1080p 60 FPS；战斗显存 $\le 2.5\text{ GB}$；0 模型开销 |

---

## 5. 供 GPT / Claude 联合评审的 5 个靶向压力问题

把本仓库发给 GPT 与 Claude 交叉审阅时，请重点让它们挑以下 5 个地方的毛病：

1. **能力矩阵与转换表的完备性**：3.3 节能力矩阵和 3.4 节 5 条注册 `Transform` 是否存在“既不复杂、又能在第一版极大地打开玩法组合，却被漏掉了”的合法路径（例如火/风与烟雾的相互转移）？
2. **6 步结算里的冲突裁决边界**：同时存在两个互相拮抗的 `CONSTRAIN`（例如一个魔法要把门拉向南，另一个魔法或重骑要把门撞向北）时，第 3 步按 `capacity` 仲裁并输出应变给 `ArtKit` 的机制是否存在边界漏洞或震荡隐患？
3. **`SemanticIntent` 到 `CompiledSpellDSL` 的降低确定性**：检查 [semantic_intent_v0_2.schema.json](../game/data/schema/semantic_intent_v0_2.schema.json) 的字段粒度，是否已经简单到 3B–4B 本地小模型能稳定填写、同时又不丢失多义上下文与时序顺序（如“先织后冻” vs “先冻后织”）？
4. **Wave 1 美学与动作门禁的可达性**：在 Godot 4 Forward+ 下，用 `VisualStackComposer`（4 层视觉）＋ `AudioDirector`（4 层音频）＋ 模块化废城石殿，是否真的能在 Wave 1 就稳定呈现《法环》级厚重感而不拖慢迭代节奏？
5. **5 份 JSON 样例的压力检查**：审阅 [game/data/spells/](../game/data/spells/case1_water_weave_freeze.json) 中的 5 份样例，是否存在任何“偷偷塞进暗门枚举”或“换了载体就无法解释”的伪原子化痕迹？
