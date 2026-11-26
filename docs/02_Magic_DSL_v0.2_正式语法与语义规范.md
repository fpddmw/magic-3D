# 02 · Magic DSL v0.2 正式语法与语义规范

> **状态**：**Converged Spec v0.2（联合收敛候选正式版）**——综合项目核心诉求、多轮架构审计与跨大模型评审收束而成，替代并冻结原 v0.1 扁平枚举草案。
> **机器校验契约**：[magic_dsl_v0_2.schema.json](../game/data/schema/magic_dsl_v0_2.schema.json) ｜ [semantic_intent_v0_2.schema.json](../game/data/schema/semantic_intent_v0_2.schema.json)
> **工程对照桩**：[magic_dsl_types.gd](../game/scripts/dsl/magic_dsl_types.gd) ｜ [magic_capability_matrix.gd](../game/scripts/dsl/magic_capability_matrix.gd) ｜ [magic_dsl_document.gd](../game/scripts/dsl/magic_dsl_document.gd)

---

## 1. 架构定位、三层原语分离与四条工程宪章

本规范设计的不是“技能参数表”，也不是“科研级通用物理模拟脚本”，而是一门**在奇幻世界规则允许范围内具有组合闭包、且可被 Godot 4 稳定高效执行的现象构造语言**。

### 1.1 三层原语严格分离
```text
[Layer 1 · Semantic Primitives（玩家语义原语）]
  48+ 稳定词义符文 · 上下文多义 · 回路连接（概念依赖 / 结构依附 / 运行因果）
        │  （构筑期：由确定性规则或暂停期本地小模型解释为 SemanticIntent）
        ▼
[Layer 2 · Magic DSL v0.2（现象构造原语）]
  Subject · Spatial · Relation · Process(Operation × Profile × Propagate) · Contract · Expression
        │  （确定性编译器：补全 WorldLaw 默认行为、展开能力映射、核算 Budget、校验能力矩阵）
        ▼
[Layer 3 · Runtime Kernels + 三大共享库（Godot 4 有界执行层）]
  四大空间载体（BODY / PATH_GRAPH / SURFACE / REGION）＋ 共享基础设施（Reference / Relation / Process / Resource）
  WorldLaw（世界法则库） · RuntimeKernel（有限求解器） · ArtKit（4层视觉栈＋4层音频＋导演相机）
```

### 1.2 三种关系与三种终止（绝不混同）
1. **三种连接关系**：
   - **概念推导关系**（构筑期）：如 `火+以太+分离→光`，`光+反转→暗`——施放暗域时绝不先放火再放光；
   - **结构依附关系**（共存期）：如暗月实体同时承载引力场与抽热场；
   - **运行因果关系**（时变期）：如液态水网在 `RELEASE` 事件到来时原地冻成刚体冰网。
2. **三种生命周期终止**：
   - **支撑终止（Support End）**：魔法撤去人为托举、聚拢或感应句柄，但已具现的物质不消失；
   - **存在终止（Existence End）**：物质因融化/破碎/耗尽或场域能量枯竭而停止作为当前主体存在；
   - **表现终止（Presentation End）**：纯视听余韵（残光、烟尘散尽、石殿混响）淡出并回收表现节点。

### 1.3 四条工程宪章
1. **语义可以丰富，执行能力必须有限且明确**（能力矩阵未声明的能力直接静态拒绝，禁止悄悄降级欺骗）；
2. **空间可以组合，几何实现不必任意通用**（拒绝 3D CSG 布尔与任意网格切割）；
3. **世界可以高度交互，物理模拟不必科学精确**（以**因果真实、感知真实、规则真实**取代微距流体守恒）；
4. **艺术必须深度打磨，但不必逐个法术手工制作**（依托 `ArtKit` 四层复合视听协议同源派生）。

---

## 2. 形式类型系统与语义内核

### 2.1 三类主体（`Subject.kind`）
严格区分“固有性质 / 动态瞬时状态 / 主动作用规律”，绝不将其混为一张万能属性表：

| `Subject.kind` | 本质含义 | 必填锚定字段 | 可挂载的世界通道 |
|---|---|---|---|
| `MATERIAL` | 拥有宏观数量与物质构成的实体或介质 | `material_id`（引用 `WorldLaw` 材料表，如 `WATER`, `ICE`, `STONE`, `FOG`, `FLAME`, `LIGHTNING_PLASMA`）、`initial_phase`（`SOLID`/`LIQUID`/`GAS_MIST`/`PLASMA`）、`initial_quantity` | `MECHANICAL`, `MATERIAL`, `THERMAL`, `CONDUCTIVE`, `OPTICAL`, `INFORMATIONAL`, `SPATIAL` |
| `FIELD` | 定义空间范围内的作用法则分布，不一定拥有物质质量 | `field_channel`（`GRAVITY` \| `HEAT_EXTRACTION` \| `HEAT_INJECTION` \| `LIGHT_EMISSION` \| `LIGHT_ATTENUATION` \| `WIND_FORCE` \| `ELECTRIC_POTENTIAL` \| `SPATIAL_BARRIER` \| `LOCAL_TIME_RATE` \| `VITAL_FLUX`） | 依通道分别接入 `MECHANICAL` / `THERMAL` / `OPTICAL` / `CONDUCTIVE` / `SPATIAL` / `TEMPORAL` |
| `RELATION` | 显式具名关系主体（感应连接、供能锚定、映射通道） | 端点 `source_ref` / `target_ref` 与耦合或约束规范 | `INFORMATIONAL`, `CONDUCTIVE`, `SPATIAL`, `MATERIAL` |

> **关键规则**：每个 `MATERIAL` 必须显式指定 `inherit_world_law: true`（由世界库提供默认密度、电阻、相变温区与默认重力响应），法术仅在需要偏离常态时声明 `overrides` 或施加 `CONSTRAIN` / `DRIVE`。

### 2.2 作用句柄（Handles）与状态通道（`StateChannel`）
- **`EffectHandle` / `RelationHandle`**：每当 `ESTABLISH`、`DRIVE`、`CONSTRAIN`、`COUPLE` 启动持续作用时，运行时生成不可伪造的句柄；`WITHDRAW` 仅通过句柄撤除人为施加的支撑或控制，绝不回滚已提交的碰撞、碎裂与地形改变。
- **6 个连续 `StateChannel`**（供 `DRIVE` 连续/增量驱动，离散相变与断裂禁止混入）：
  - `POSE`（整体位姿）、`EXTENT`（空间尺度与延伸范围）、`DISTRIBUTION`（截面/密度分布）、`FLOW`（内容沿骨架坐标 `u` 的内部运动）、`INTENSITY`（场或作用强度）、`DIRECTION`（主导作用方向）。
  - 离散瞬时加速使用独立通道 `VELOCITY_IMPULSE`（仅当 `mode == IMPULSE` 时合法）。

---

## 3. 空间组织与四类工程载体契约

空间组织满足：**`空间组织 = Reference（参照） + Geometry（骨架） + Distribution（分布） + Connectivity（连接）`**，且必须在运行时严格区分 **`Desired Structure`（期望结构）** 与 **`Realized Structure`（实际受阻变形后结构）**。

### 3.1 四类空间执行载体（`Spatial.carrier`）与非几何基础设施
- **4 个空间执行载体**：`BODY`（有限凝聚实体与 Jolt 碰撞代理）、`PATH_GRAPH`（有限节点边图与连续介质链）、`SURFACE`（有限平面与曲面片）、`REGION`（空间体积查询与场强分布区）。
- **4 项共享非几何基础设施**（严禁归类为第 5 种几何载体）：`Reference`（锚点与参考系）、`Relation`（功能关系）、`Process`（有限过程调度）、`Resource`（材料/魔力/冷却/耐久账本）。

### 3.2 空间参照、有界几何生成器与战斗自动选支点
- **`anchor.source`**：`WORLD_POINT` | `CASTER_BODY` | `CASTER_HAND` | `AIM_POINT` | `AIM_DIRECTION` | `LOCKED_TARGET` | `AUTO_SUPPORT_SURFACE` | `NEARBY_MEDIUM` | `SUBJECT_REF` | `ACTUAL_CONTACT_POINT`
- **`anchor.binding`**：`CAPTURE`（创建瞬间取位置） | `FOLLOW`（持续追随目标位置，受自身动力上限约束） | `ATTACH`（刚性附着局部坐标） | `CONTROL`（受玩家单操控焦点实时引导）
- **战斗自动选支点规则（`AUTO_SUPPORT_SURFACE`）**：玩家不需要在战斗中手工逐点点击多个锚点。运行时按“瞄准方向锥角 $\le 35^\circ$、距锚定中心 $\le \text{max\_distance\_m}$、优先静态承重墙柱面再选大型刚体”的确定性顺序自动提取最多 `max_count` 个支点；找不到合法支点时，退化为自由悬浮端（若无 `SUPPORT` 约束则在重力下自然下坠）。
- **有界几何生成器（`geometry.generator`）**：
  - `BODY`: `SPHERE_SCULPT` | `LANCE_PRISM` | `SLAB_MONOLITH` | `COMPOUND_FROM_PATH`
  - `PATH_GRAPH`: `LINE_SEGMENT` | `ARC_CURVE` | `BRANCH_WEB` | `CLOSED_RING`
  - `SURFACE`: `BOUNDED_PLANE` | `SWEPT_STRIP` | `CONFORMAL_SHELL`
  - `REGION`: `RADIAL_SPHERE` | `CYLINDER_COLUMN` | `CONE_SECTOR` | `ALIGNED_BOX`
- **受阻局部形变红线**：`PATH_GRAPH` 与 `SURFACE` 遇障碍时每物理步每节点最多执行 `max_deflect_iterations_per_node <= 2` 次切向偏移；仍无法通过则按 `on_obstruction`（`DEFORM_OR_TRUNCATE` / `SLIDE_BOUNDARY` / `HALT`）截断或停止延伸，**严禁编写无界通用流体绕障求解器**。

### 3.3 v0.2 有限能力矩阵（Capability Matrix — 核心硬约束）

编译器在语义展开后**必须查表校验**；任何落在 `UNSUPPORTED` 上的组合直接拒绝并给出可读理由：

| 能力项 | `BODY` | `PATH_GRAPH` | `SURFACE` | `REGION` | 说明 |
|---|---|---|---|---|---|
| 整体位姿移动（`POSE`） | `SUPPORTED` | `SUPPORTED` | `SUPPORTED` | `SUPPORTED` | 按载体物理/场域规则移动 |
| 尺度与延伸（`EXTENT`） | `LIMITED`（成比例缩放/生长阶段） | `SUPPORTED` | `SUPPORTED` | `SUPPORTED` | 禁止对已冻结实体无限自由拉伸 |
| 局部受阻形变 | `UNSUPPORTED` | `LIMITED`（节点≤2次切向偏移） | `LIMITED`（条带沿边界微偏） | `UNSUPPORTED` | 刚体不实时弯折；场域穿墙受 `OPTICAL/BARRIER` 判定 |
| 结构断裂 / 离散分裂 | `LIMITED`（预设/程序裂解≤12块） | `SUPPORTED`（边超限断开） | `LIMITED`（整面破损撤除） | `UNSUPPORTED` | 拒绝任意 3D 网格切割 |
| 真实实体碰撞阻挡 | `SUPPORTED`（Jolt 刚体/静态体） | `LIMITED`（段扫掠接触＋力传递） | `LIMITED`（单/双向屏障拦截） | `UNSUPPORTED` | `REGION` 不得假装成阻挡墙体 |
| 沿骨架结构传播（`Propagate`） | `UNSUPPORTED` | `SUPPORTED`（沿节点连通边） | `LIMITED`（沿中心径向面） | `UNSUPPORTED` | 需结合 `SPATIAL_RADIUS` 或 `CONDUCTIVE_GRAPH` |
| 分布剖面（`Profile`）与衰减 | `LIMITED`（核心-外壳强度） | `SUPPORTED`（沿 `PATH_U` 变截面） | `SUPPORTED`（边缘衰减/厚度） | `SUPPORTED`（沿 `RADIAL_R` 衰减） | `MATERIAL` 体积增长需同步核对质量守恒 |
| 空间查询与区域影响 | `LIMITED`（接触与质心） | `SUPPORTED`（接触集合） | `SUPPORTED`（穿越射线/平面） | `SUPPORTED`（`Area3D` 重叠与遮蔽） | — |

### 3.4 v0.2 严格注册的 `Transform` 合法转换路径

仅允许以下 5 条 `TransformId` 转换；任何未注册跨载体强转一律拒绝：

| `transform_id` | 源载体/状态 | 目标载体/状态 | 保留资产与失败语义 |
|---|---|---|---|
| `PATH_LIQUID_TO_BODY_SOLID` | `PATH_GRAPH`（液态材料） | `BODY`（多个分段简单碰撞代理组合体 `COMPOUND_FROM_PATH`） | 保留当前 `realized_geometry` 节点/连接/材料量；跳过非法自穿插段；仅当支点或预付冻结储备充足时成立 |
| `BODY_SOLID_TO_SHARDS` | `BODY`（固态实体） | $\le 12$ 个离散 `BODY` 碎片＋视觉微屑 | 继承剩余质量与当前线/角动量；超限碎屑仅进 `ArtKit` 表现层 |
| `BODY_SOLID_TO_LIQUID_REGION` | `BODY`（如冰体受热） | `REGION` / 地表湿润积水分布 | 保留材料量并注入地表面潮湿状态与导电图，撤销原碰撞刚体 |
| `FOG_REGION_TO_ICE_SHARDS` | `REGION`（`GAS_MIST` 雾） | 有限离散 `BODY` 冰砂弹片（$\le 12$） | 严格从雾场真实质量扣除并同步消除对应区域的视线遮蔽 |
| `FIELD_RECONFIGURE` | `FIELD`（同主体） | 修改极性/方向或强度映射的同 `FIELD` | 保持主体身份与 `EffectHandle`，按新预算复算消耗 |

---

## 4. 七类变化原语、有限 `Profile` 与 `Propagate`

### 4.1 七类不可再分操作原语（`op.family`）
1. **`ESTABLISH`**：实例化声明的 `Subject` 或 `Relation`，返回持久化 `SubjectRef` / `RelationHandle`。
2. **`DRIVE`**：向合法 `StateChannel` 提交变化意图（`TARGET` 目标趋近 / `RATE` 持续速率 / `IMPULSE` 瞬时冲量）。绝不直接暴力写死坐标绕过碰撞，所有请求交由第 6 步统一裁决。
3. **`CONSTRAIN`**：维护必须持续成立的关系（`POSITION | DISTANCE | ATTACH | COHESION | SUPPORT | CONFORM | CONTAIN | BOUND`）。必须声明 `capacity`（抗干扰上限）、`on_exceed`（`YIELD` 屈服 / `DEFORM` 形变 / `BREAK` 崩断）与 `provider_ref`。
4. **`TRANSFORM`**：执行 3.4 节注册的离散相态或载体结构转换，支持挂载 `Propagate` 沿时间与结构逐步推进。
5. **`TRANSFER`**：在真实来源（`ENV:NEARBY_WATER`、载体储量、已有主体）与目标主体之间按守恒量纲转移 `MATERIAL | ENERGY | HEAT | VITALITY`，并规定来源不足时的确定性回退（`FAIL_ESTABLISH | CLAMP_TO_AVAILABLE | FALLBACK_TO_MANA_GEN`）。
6. **`COUPLE`**：在已注册的强类型通道间建立联动（`DISTURBANCE_TO_PERCEPTION | SUBJECT_POSE_TO_FIELD_ORIGIN | CONTACT_TO_TRIGGER | CONTACT_TO_CONDUCTION | HEAT_FLUX_TO_PHASE`）。其中 `DISTURBANCE_TO_PERCEPTION` 明确限制 `signal_granularity`（如 `DIRECTION_AND_INTENSITY_ONLY`，禁止附赠透视全知）。
7. **`WITHDRAW`**：撤销指定 `Subject / Relation / Process / ALL_SPELL_SUPPORTS` 的魔法支撑与操控（`STOP_SUPPORT | DETACH_CONTROL`），将主体交还 `WorldLaw` 自然演化。

### 4.2 有限剖面（`Profile`）
拒绝开放任意数学表达式解析，仅支持 **8 种有限曲线 × 5 种坐标域 × `min_val / max_val / inverted`**（其中 `PIECEWISE_4PT` 提供 4 个固定控制点以支持“缓慢悬置→骤然爆发”等宏观戏剧曲线）：
- **`curve`**：`CONSTANT | LINEAR | SLOW_BUILD | FAST_ESTABLISH | BELL_CONCENTRATED | IMPULSE_SPIKE | DECAY_OUT | PIECEWISE_4PT`
- **`domain`**：`TIME_NORM | PATH_U | RADIAL_R | CHARGE_PROGRESS | LOAD_RATIO`

### 4.3 空间传播（`Propagate`）
将操作沿指定传播域逐步作用于局部（如冻冰从实际接触点沿网蔓延、电流沿湿润连接击穿）：
- **`domain`**：`SPATIAL_RADIUS | PATH_CONNECTIVITY | CONDUCTIVE_GRAPH`
- **硬契约**：必须显式绑定 `origin_ref`、`speed_m_s`、`max_reach_m`，以及在玩家脱手后支撑传播继续完成的 **`reserve_ref`（预付储备）**——绝不允许停止吟唱后免费白嫖传播！

---

## 5. 有限过程图、闭合事件与 6 步固定结算协议（60 Hz）

### 5.1 有限过程与 9 类闭合事件
不开放通用脚本与无限递归。每项法术最多包含 8 个并发/串行 `Process`，每个 `Process` 声明 `start`、`operations[]`、`end` 与有限 `transitions[]`。
允许触发的 **9 类闭合事件（`event.type`）**：
`RELEASE`（玩家主动释放/收束）、`INTERRUPT`（受击失衡或闪避强制打断）、`DEPLETED`（魔力或预付储备耗尽）、`CONTACT_ENTER`（实际接触发生）、`OBSTRUCTION`（主结构受阻超限）、`BROKEN`（主体或支点断裂）、`COMPLETED`（过程自然或传播完成）、`TIMER`（非周期性有界计时到达）、`DISTURBANCE`（受支持介质出现超越阈值的扰动）。

### 5.2 60 Hz 固定逻辑步结算协议（单一权威状态来源）
1. **Step 1 · 输入与事件汇集**：读取玩家输入（瞄准/蓄力/释放/翻滚打断）与上一帧提交生成的世界事件，裁决过程激活、跳转与终止。
   - **同帧冲突铁律**：若同一固定步内同时出现 `RELEASE` 与 `INTERRUPT`，默认 **`INTERRUPT` 优先**（除非该术式已进入 `LOCKED_ON_COMMIT` 不可逆交付窗口）。
2. **Step 2 · 意图生成（Intent Generation）**：活跃过程的 `DRIVE` / `CONSTRAIN` / `TRANSFORM` / `TRANSFER` 生成强类型 `ChangeIntent`，同时 `WorldLaw` 为场中全部主体生成默认自然演化意图（重力、热量散失、松弛）。
3. **Step 3 · 预算、权限与通道仲裁**：
   - 核对魔力/预付储备扣减（不足触发 `DEPLETED`）；
   - 同通道多意图合并规则：力学作用按矢量叠加；同一主体互斥 `POSE` 控制按独占地位优先；`CONSTRAIN` 与外力冲突时对比 `capacity`（未超限由约束胜出并输出“挣扎应变值”给 `ArtKit`，超限触发 `on_exceed`）；`TRANSFORM` 严格按注册顺序与库存核准。
4. **Step 4 · 物理步进与有限形变反馈**：Jolt 3D 步进刚体碰撞；`PATH_GRAPH` / `SURFACE` 执行最多 2 次/节点的切向局部避障并刷新 `realized_geometry`；结算 `REGION` 重叠与射线遮挡。
5. **Step 5 · 唯一权威提交**：提交所有实体的实际位置、残余库存、相态与断裂后拓扑，更新局部身份映射表。**铁律：已提交到世界的材质与破坏绝不因后续施法失败而回滚。**
6. **Step 6 · 事件广播与表现读取**：向下一帧过程队列发布实际世界事件，并由 `ArtKit` 只读消费提交后状态与 `Desired vs Realized` 差值。

---

## 6. 世界规则库 `WorldLaw` 与力学四分离

严禁在代码里写“水+火→蒸汽、水+雷→感电”的硬编码元素配对表！世界通过 **7 个活跃作用通道 ＋ 1 个预留时间接口** 对所有材料与场统一结算：

| 通道 ID | 职责与统一规则 | 自然演化与退场（魔法 `WITHDRAW` 之后） |
|---|---|---|
| `MECHANICAL` | 接触、阻挡、支撑与结构负荷。**强制拆分为四项独立输出**：`hp_damage`（生命伤害）、`poise_damage`（架势/削韧）、`impulse_displacement`（物理冲量推退）、`mobility_constraint`（移动限制：`NONE/SLOW/ROOT_TETHER/ENCUMBER`） | 液态失去托举后依重力坠落与扩散；刚体保留真实碰撞、受力与摩擦 |
| `MATERIAL` | 材料数量、转移、地表潮湿留存、混合与离散分离 | 地表积水按有限时长蒸发吸收；碎片保留至清理预算线 |
| `THERMAL` | 热量传导与跨越临界温区的状态变化 | 冻结冰体在常温下极慢融化或在火焰附近快速融回水洼 |
| `CONDUCTIVE` | **沿真实空间接触与导电率图传播电势差**（湿润表面/金属/水网自动入图） | 脉冲瞬时释放；湿润与金属通路持续参与后续任何电性法术 |
| `OPTICAL` | 照明强度（正发光）与吸光/雾遮蔽（负遮蔽），**真实影响敌人视线射线与锁定距离** | 雾场在无凝聚约束时逐步扩散衰减；暗域随储备耗尽消散 |
| `INFORMATIONAL` | 介质位移/速度扰动向绑定 `Observe/Couple` 通道反馈有限方向与强度信号 | 解除耦合即切断反馈，绝不删除场中雾或水体 |
| `SPATIAL` | 锚点追踪、支点绑定、单/双向屏障截流与折射 | 锚点或支点破坏触发 `BROKEN` 事件并令依赖约束失效 |
| `TEMPORAL`（预留） | 定义局部区域对区域内 `Body` 动作速率、`Projectile` 速度及本地 `Process` 计时器的 `local_time_scale` 缩放接口 | **明确不实现全局世界时间倒流**；支持终端退出时恢复 `1.0` |

---

## 7. 施法契约与 3D 慢拍动作战斗耦合

为了彻底避免魔法设计与《法环》式慢拍 3D 战斗手感割裂，所有 `Contract` 必须显式填写 `combat` 块：

1. **蓄力门槛与阶梯收益**：
   - `formation == GRADUAL_CHARGE` 必须配置 `min_deliverable_progress`（例如 `0.25`）和 1–3 档 `charge_tiers`。
   - 低于门槛松手按 `on_under_threshold_release` 处理（`FIZZLE_PARTIAL_REFUND` 消散返还部分魔力，或 `DELIVER_MIN_TIER` 交付基础短促版），杜绝“0.1 秒鬼畜连发神罚”或“蓄了 1 秒白挨打”。
2. **施法期身体动作约束**：
   - `caster_movement`：`FULL_MOVE`（轻瞬发）/ `SLOW_SOLEMN_WALK`（沉重仪式感踱步，可转朝向）/ `ROOTED`（重型吟唱定身）。
   - `dodge_cancel_policy`：在战斗危急时刻玩家按翻滚键时，决定是立即 `TRIGGER_INTERRUPT`（保命撤出、放弃未成型魔力）、还是 `TRIGGER_RELEASE`（把当前已蓄好的半成品瞬间打出去换位），或大招末段 `LOCKED_ON_COMMIT`。
3. **严格受限的 7 项战场实时输入**：
   `AIM_POINT`, `AIM_DIRECTION`, `LOCKED_TARGET`, `CAST_HOLD`, `VOLUNTARY_RELEASE`, `INTERRUPT_SIGNAL`, `SINGLE_FOCUS_RAY`（同一时刻至多 1 个精细操控焦点）。
4. **载体寄托与预付储备交接**：
   - 脱离施法者维持的过程（如松手后继续沿路径蔓延凝固的冰网、或留在门框的触发印记），必须显式声明 `post_release_reserve_mana` 并在交付瞬间从施法者法力预先划拨托管，储备耗尽即触发 `DEPLETED`。

---

## 8. `ArtKit` 四层爆炸级视听映射契约

严禁把 `Expression` 写成只能靠口头解释的形容词。下表规定 `Expression` 高层意图与物理世界观测量如何**确定性驱动 Godot 4 的 4 层视觉栈、4 层音频栈与安全导演机位**：

### 8.1 视觉 4 层复合渲染栈（所有载体通用）
| 层级 | Godot 4 驱动源 | 具体渲染职责（拒绝“1网格+1色块”） |
|---|---|---|
| **L1 · 主轮廓与结构层** | `realized_geometry` + `Expression.composition / symmetry` + `Profile` | 生成雕塑感断面与剪影（`STRUCTURAL` 呈锐利棱面与对称法环刻度；`CONCENTRATED` 呈厚重核体；`STREAMING` 呈有厚度变化的连续带） |
| **L2 · 材质光学与细节层** | `Subject.material_id / field_channel` + `velocity` + `Desired-Realized 应变差` | 水：法线流动＋屏幕空间折射＋高曲率边缘白沫；冰：棱面折射＋内部应力裂纹（随应变/受损度增强）；引力/暗域：空间透镜畸变或负光照吸光黑边＋边缘噪波侵蚀 |
| **L3 · 动态光源与体积雾层** | `Expression.contrast` + `formation.progress` + `WorldEnvironment` | 蓄力进度与 `contrast == HIGH` 联动微压天光与环境雾色温；同时生成真实 `OmniLight3D / FogVolume` 照亮或吞噬废墟石柱与积水反光 |
| **L4 · 次级微粒与持久贴花层** | 真实碰撞冲量 `J` + `CONTACT_ENTER` + `WorldLaw` 状态留存 | 高冲量撞击喷溅纯装饰 `GPUParticles3D` 飞沫/碎屑；同时向地面/墙面投射持久化 `Decal`（潮湿积水、霜晶结壳、焦痕、重力碎裂纹） |

### 8.2 音频 4 层动态混音协议（厚重与浪漫的核心一半在声音）
1. **蓄力张力层（`drone_family`）**：音量与低通滤波随 `formation.progress` 连续拉升，并与环境风声形成对比；
2. **爆发前抽声留白（`silence_pre_impact_ms`）**：高冲量/高对比法术（`tension == GRADUAL_ACCUMULATION && contrast == HIGH`）在释放或命中前 40–100 ms 瞬时压低其它高频环境音轨，制造“万籁俱寂”的呼吸感；
3. **冲量分层重击与殿堂混响（`impact_family`）**：严禁一刀切顿帧！顿帧时长与低频 Sub-bass 权重**严格正比于实际结算冲量 `J` 与 `hp/poise_damage`**（如纯感知法术 `case4` 冲量为 0，自然无顿帧、仅留清越风铃/微颤提示音）；音效统一送入带空间大小的 Godot `AudioEffectReverb`（废城室外短回声 vs 石殿长混响）；
4. **持续与受阻挣扎循环音（`sustain_loop_family`）**：持续维系或遇到高压阻挡（`Desired vs Realized` 偏差增大）时自动叠加紧绷摩擦/震颤泛音。

### 8.3 导演相机安全边界
蓄力期相机平滑微移（俯仰偏移限定 $\pm 8^\circ$，拉远限定 $+2.5\,\text{m}$），且全程经 `SpringArm3D` 碰撞体安全裁剪，**绝不允许在挑高或狭窄废墟室内穿墙卡死视角**。

---

## 9. 三段式语义编译边界（`SemanticIntent` → `CompiledSpellDSL`）

为了保证后续接回 48 枚符文词库与本地 3B–4B 小模型时不出现幻觉崩溃，明确划分上下游责任：

- **上游 `SemanticIntent`（[semantic_intent_v0_2.schema.json](../game/data/schema/semantic_intent_v0_2.schema.json)）只填这 6 项**：
  1. `runes_used` 与 `intent_summary`（每枚符文在本次构思中的角色依据）；
  2. `subjects` 的高层材料/场域意图（不填质量/电阻/碰撞代理细节）；
  3. `spatial_intent`（锚点目标、希望的组织形态如线性延伸/分支交织/球形区域/平面阻挡、连续还是弥散）；
  4. `causal_steps`（时序流程：如“蓄力阶段向锚点引水并拉扯 → 主动释放时沿连接凝固”）；
  5. `combat_contract_intent`（瞬发/蓄力/维持/寄托，以及移动/打断倾向）；
  6. `art_intent`（`Expression` 6 个高层质感枚举）。
- **下游确定性编译器负责补全与裁决**：
  - 自动查 `WorldLaw` 填充材料属性、四分离力学基础权重、默认演化和退场；
  - 自动分配工程载体（`BODY / PATH_GRAPH / SURFACE / REGION`）和节点/面片预算，**查能力矩阵验证合法性**；
  - 自动按守恒做功量核算 `budget`（初始魔力、持续消耗、预付储备）；**小模型绝对无权自定法力消耗与伤害倍率**；
  - 输出并通过 [magic_dsl_v0_2.schema.json](../game/data/schema/magic_dsl_v0_2.schema.json) 校验后，固化存盘供战斗零开销执行。

---

## 10. 硬工程预算上限与 v0.2 明确砍单清单

### 10.1 双层工程预算上限（初始约束基准）
| 维度 | 单法术上限 | 场景并发总上限 |
|---|---:|---:|
| 具名主体数 | $\le 8$ | 活跃魔法主体 $\le 32$ |
| `PATH_GRAPH` 节点 / 边 | $\le 16$ 节点 / $\le 24$ 边 | 并发活跃路径图 $\le 4$ |
| `SURFACE` 网格面片 | $\le 64$ Quads | 并发活跃魔法曲面 $\le 6$ |
| 并发 `Process` 数量 | $\le 8$ | 场景活跃 `Process` $\le 24$ |
| 单次破碎衍生 `BODY` 刚体 | $\le 12$ | 场景活跃魔法生成刚体 $\le 64$（超出按最早闲置/最低重要度淘汰退场） |
| `REGION` 作用场 | 包含在 8 主体内 | 场景活跃作用场 $\le 8$ |
| 实时精细操控焦点 | 1 个（全局唯一） | 1 个 |
| 模拟步频 / 运行平台预算 | 60 Hz 固定逻辑步 | Apple M6 / 中端独显 1080p 稳 60 FPS；战斗显存 $\le 2.5\text{ GB}$；战斗期模型开销 $= 0$ |

### 10.2 v0.2 明确暂不实现清单（Anti-Scope-Creep）
1. 通用 3D CSG 布尔与任意网格实时切割；
2. 科研级连续介质 CFD / 逐滴守恒流体 / 全面电磁场模拟；
3. 任意自由度数学约束求解器；
4. 图灵完备脚本虚拟机、无限循环与无界递归事件；
5. 未在 3.4 节注册的任意主体自由互相转换；
6. 全局世界时间倒流（仅保留局部 `TEMPORAL` 速率缩放语义接口）；
7. 由大模型在构筑期或战斗期直接生成 GDScript、Shader 或任意物理数值；
8. 为单个法术/组合手写特判逻辑或独立专属美术动画资源；
9. 纯粹以“凑满全部 48 枚符文与全城关卡”替代底层能力验证。

---

## 11. 已落盘可校验跨领域 JSON 样例索引

全部 5 份样例均严格通过 `magic_dsl_v0_2.schema.json` 校验，分别对应不同物理/抽象/信息领域与组合方式：

1. [case1_water_weave_freeze.json](../game/data/spells/case1_water_weave_freeze.json)：`PATH_GRAPH` 活水网借水塑形、受阻变形、`RELEASE` 沿 `PATH_CONNECTIVITY` 传播冻结为 `COMPOUND_FROM_PATH` 刚体冰网；
2. [case2_gravity_collapse.json](../game/data/spells/case2_gravity_collapse.json)：`REGION` 引力场蓄力 `SLOW_BUILD` 向上悬浮聚拢，释放 `IMPULSE_SPIKE` 骤然向下崩落重击；
3. [case4_fog_disturbance_sense.json](../game/data/spells/case4_fog_disturbance_sense.json)：`REGION` 弥散雾场＋`COUPLE(DISTURBANCE_TO_PERCEPTION)`，验证纯非暴力信息反馈与无假顿帧演出；
4. [case5_ward_mirror_surface.json](../game/data/spells/case5_ward_mirror_surface.json)：`SURFACE` 有限平面结界，验证 `SPATIAL_BARRIER` 方向性阻挡/偏折与 `SUSTAINED` 受阻张力声效；
5. [case_compound_dark_moon.json](../game/data/spells/case_compound_dark_moon.json)：多主体复合组合——`BODY[ICE]` 主体挂载 `GRAVITY + HEAT_EXTRACTION + LIGHT_ATTENUATION` 三个随行 `REGION` 场，撞击触发 `BODY_SOLID_TO_SHARDS` 并撤去临时场域。
