# Magic DSL v0.2.1 正式语法与语义规范（Semantic & Execution Contract Revision）

> **版本状态**：`v0.2.1`（2026-11-26）—— 在 `v0.2` 经 GPT 工程审计后完成全部 **P0 / P1 收口修订**，现与 [magic_dsl_v0_2.schema.json](../game/data/schema/magic_dsl_v0_2.schema.json)、[semantic_intent_v0_2.schema.json](../game/data/schema/semantic_intent_v0_2.schema.json)、4 阶段离线校验器 [validate_dsl.py](../game/tools/validate_dsl.py) 及 GDScript 契约桩完全同源。
> **核心理念**：不靠“预设法术枚举 + 数值滑块”，而是以**语义意图层 → 编译执行层（主体 · 四载体 · 关系 · 过程图 · 七算子） → 物理/演出运行时**三层分离架构，用有限原语在空间、结构、因果时序上自然生长出近乎无限的 3D 魔法。

---

## 0. v0.2.1 关键修订总览（回应交叉审计 P0/P1）

| 编号 | 原 v0.2 缺陷 | v0.2.1 硬性收口方案 |
|---|---|---|
| **P0-1** | GDScript 校验盲信 `budget.compiler_status == "VALID"`；缺可执行负向测试 | 离线 Python 与 GDScript 同步强制 **4 阶段校验**（结构 → 语义 → 能力/限定条件 → 独立预算与 ArtKit 注册表），彻底忽略伪造 `compiler_status` |
| **P0-2** | `process.start` 导致二重激活语义歧义；事件缺少作用域 | 删除 `process.start`，改为 **`process_graph`（`entry_processes` + 有向 `transitions` + 作用域 `RuntimeEvent`）** |
| **P0-3** | 过程内操作混杂单次初始化与每帧持续驱动；`HANDOFF` 交接对象不明 | 每个进程强制拆分为 **`on_enter`（仅允许 `ESTABLISH`）/ `while_active`（每 Tick）/ `on_exit`**；转移显式声明 `handoff_handles` |
| **P0-4** | 操作签名、单位制、`IMPULSE` 与 `TARGET` 混用、复合方向 `UPWARD_AND_INWARD` | 统一单位（`m, s, MU, EU, LU`）；Schema 层面拆分 **`OpDriveContinuous`（TARGET/RATE）** 与 **`OpDriveImpulse`（仅 IMPULSE）**；强制 **`DirectionSpec`** 三态正交 |
| **P0-5** | 空间附着在 `spatial.reference.binding` / `relations[]` / `COUPLE` 三处重复定义 | **`spatial[].reference` 仅负责出生点锚定**；`relations[]` 为唯一被动关系声明；`ESTABLISH(RELATION)` / `COUPLE` 唯一激活 |
| **P0-6** | `MATERIAL` 初始量与上限混淆；`PathGraph` 缺少逐段相态与断链快照策略；诚实界定 `Weave(Freeze)` | 分离 **`capacity_mu` 与 `initial_inventory_mu`（≤ capacity）**；新增 `per_segment_phase` 与 `PropagationSpec`；诚实限定阶段一 `Weave(Freeze)` 降阶为有界复合刚体（≤16 节点） |
| **P0-7** | `SemanticIntent` 使用 12 个复合法术短语枚举 | 重构为 **原子语义从句 `clauses[]`** + `INVERT` 目标索引 `scope_target_clause_id` + 强制 **`rune_contributions[].bound_ids[]` 溯源** |
| **P0-8** | 实施波次存在前置依赖倒挂、Godot 4 `Area3D` 单帧延迟未写明 | 重排为 **`Wave 0 → 1A → 1B → 2 → 3`**，在实施计划补齐 `_physics_process` 首帧适配器契约 |
| **P1** | 单字符串样式、`Engine.time_scale` 全局顿帧、不可预测音频前置静音、破坏性 64 刚体驱逐、样例缺口 | 拆分为可组合 **ArtKit 视觉/音频模块 + `ArtKitArbitrator` 仲裁栈**；改用**局部顿帧 `hitstop_local_ms`** 与 **`pre_delivery_silence_ms`**；四级非破坏性资源守恒；补齐 **Case 3 / Case 6** 共 7 份通过校验样例（Case 7 留白盲测） |

---

## 一、三层架构与边界红线

1. **Semantic Intent Layer（语义意图层 · 玩家构筑与符文工坊）**
   - 对应 Schema：[semantic_intent_v0_2.schema.json](../game/data/schema/semantic_intent_v0_2.schema.json)
   - 只描述“**想实现什么语义目的、由哪些符文/子句共同贡献**”，不包含碰撞体、节点数、Godot 节点名或底层力学系数。
   - **禁止**再次退化为 `WEAVE_AND_FREEZE` 这类复合技能名称枚举；必须拆分为原子 `IntentClause`（如 `SHAPE_AND_ROUTE`、`TRANSFORM_STATE`、`APPLY_FORCE`、`INVERT_OR_REDIRECT`）及显式 `rune_contributions[].bound_ids[]`。
2. **Compiled Execution DSL Layer（静态执行契约层 · 运行时唯一输入）**
   - 对应 Schema：[magic_dsl_v0_2.schema.json](../game/data/schema/magic_dsl_v0_2.schema.json)
   - 本身是一份**确定性、自洽、有硬预算上限、零运行期 AI 推理**的纯数据契约，供 GDScript/Godot 运行时零歧义加载。
   - 所有样例存放在 [game/data/spells/](../game/data/spells/case1_water_weave_freeze.json)。
3. **Runtime + WorldLaw + ArtKit Layer（物理/世界法则/演出运行时）**
   - **`WorldLaw`** 负责物理材质密度、导热、比热、相变阈值、导电率、浮力与碎裂判定。**任何 DSL 主体强制 `"inherit_world_law": true`，严禁声明 `overrides` 篡改世界法则。**
   - **`ArtKitDirector` 与 `ArtKitArbitrator`** 以只读方式消费 `ExpressionSpec`、受控 `SubjectRuntimeState` 快照及 `RuntimeEvent` 流，通过“轮廓模块 × 表面材质模块 × 附着细节模块”渲染并仲裁环境光雾音。

---

## 二、规范单位制与硬预算上限

| 物理/游戏量 | 单位 | 定义与全局上限（见 [magic_dsl_types.gd](../game/scripts/dsl/magic_dsl_types.gd)） |
|---|---|---|
| 空间尺度 | `m`（米） | `range_m <= 40.0`，`initial_extent_m <= 20.0` |
| 时间 | `s`（秒）/ `ms` | `windup_s <= 3.0`，`max_active_duration_s <= 30.0`，`rebind_cooldown_s >= 0.05` |
| 物质储量 | `MU`（Matter Unit） | 单主体 `capacity_mu <= 1000.0`，`0 <= initial_inventory_mu <= capacity_mu` |
| 能量/法力 | `EU` / Mana | `max_upfront_mana <= 300.0`，`max_sustain_mana_per_s <= 60.0`，`post_release_reserve_mana <= 200.0` |
| 结构承载荷载 | `LU`（Load Unit） | 单约束 `capacity_lu <= 500.0`，运行期通过 `realized_load / capacity_lu` 触发应变反馈或破断 |
| 结构实体硬上限 | 数量 | 单法术 `subjects <= 8`, `spatial <= 8`, `relations <= 12`, `processes <= 8`, `peak_dynamic_bodies <= 16`, `peak_path_nodes <= 16`, `peak_surface_quads <= 64`, `peak_point_lights <= 3` |

---

## 三、正交原语全集

### 3.1 主体 `subjects[]`（严格 `oneOf` 三选一，禁止 `RELATION` 冒充主体）

1. **`MATERIAL`（物质主体）**
   - 必填：`id`, `kind: "MATERIAL"`, `material_id`, `initial_phase`, `capacity_mu`, `initial_inventory_mu`, `inherit_world_law: true`, `visual_modules`。
   - **单账本不变量**：`capacity_mu` 为该主体允许承载的最大物质量；`initial_inventory_mu` 为起手凭空具现的初始存量（必须满足 `<= capacity_mu`）。从环境吸收的物质量（如 `TRANSFER(source="ENV:WATER")`）必须消耗同一 `capacity_mu` 剩余空间，绝不重复记账或无中生有超额叠加。
   - 支持材料枚举：`WATER`, `ICE`, `STONE`, `METAL`, `FOG`, `FLAME`, `ASH`, `LIGHTNING_PLASMA`, `VITAL_SPORE`。
   - 支持相态：`SOLID`, `LIQUID`, `GAS_MIST`, `PLASMA`。
2. **`FIELD`（物理/奥术场主体）**
   - 必填：`id`, `kind: "FIELD"`, `field_channel`, `initial_intensity`, `max_intensity` (`initial_intensity <= max_intensity`), `inherit_world_law: true`, `visual_modules`。
   - 支持场通道：`GRAVITY`, `HEAT_EXTRACTION`, `HEAT_INJECTION`, `LIGHT_EMISSION`, `LIGHT_ATTENUATION`, `WIND_FORCE`, `ELECTRIC_POTENTIAL`, `SPATIAL_BARRIER`, `LOCAL_TIME_RATE`, `VITAL_FLUX`。
   - **条件约束（Schema `if/then/else` 强制）**：`barrier_policy`（`{ directional_one_way, response_mode: BLOCK|REFLECT|DEFLECT, deflect_angle_deg }`）**有且仅当 `field_channel == "SPATIAL_BARRIER"` 时必填且合法**，其他任何场通道禁止出现该字段。
3. **`WORLD_REF`（既有世界参照主体）**
   - 必填：`id`, `kind: "WORLD_REF"`, `query_kind` (`VESSEL_IN_HAND | TARGET_SURFACE | NEARBY_MEDIUM | LOCKED_ACTOR`), `expected_filter`, `require_existing`；可选 `visual_modules`（如器物烙印印记）。

### 3.2 四大有限几何载体 `spatial[]`（载体决定生成器与维度）

| `carrier` | 锁定 `dimension` | 合法 `generator` | 预算限制 | 说明 |
|---|---|---|---|---|
| `BODY` | `3D` | `SPHERE_SCULPT`, `LANCE_PRISM`, `SLAB_MONOLITH`, `COMPOUND_FROM_PATH` | `node/edge/quad = 0` | 受限 3D 实体/冰棱/石块（单法术 ≤ 16 个刚体） |
| `PATH_GRAPH` | `1D` | `LINE_SEGMENT`, `ARC_CURVE`, `BRANCH_WEB`, `CLOSED_RING` | `2 <= node_budget <= 16`, `1 <= edge_budget <= 24`, `deflect <= 2`, **必填 `per_segment_phase`** | 水流丝络、电弧分支、晶脉连线 |
| `SURFACE` | `2D` | `BOUNDED_PLANE`, `SWEPT_STRIP`, `CONFORMAL_SHELL` | `1 <= quad_budget <= 64`, `deflect <= 1` | 平面折光壁、结界薄片、贴面冰霜层 |
| `REGION` | `3D` | `RADIAL_SPHERE`, `CYLINDER_COLUMN`, `CONE_SECTOR`, `ALIGNED_BOX` | `node/edge/quad = 0` | 雾团区域、重力场/热抽离场域 |

> **P0-5 空间引用单一权威**：`spatial[].reference` 仅声明出生时刻的一次性摆放位置：
> `spawn_anchor` ∈ `{ WORLD_POINT, CASTER_BODY, CASTER_HAND, AIM_POINT, AIM_DIRECTION, LOCKED_TARGET, AUTO_SUPPORT_SURFACE, SUBJECT_ORIGIN, WORLD_REF }`，加上可选 `spawn_subject_id` / `spawn_offset_m` / `auto_support_rule`。**完全移除 `binding: FOLLOW | ATTACH`**；持续跟随一律通过 `relations[]` 声明并在 `on_enter` 中激活。

### 3.3 单一权威关系 `relations[]`

- 仅作静态拓扑与功能耦合声明，除非被过程 `ESTABLISH(RELATION)` 或 `COUPLE(relation_id)` 激活，否则不产生每帧效果；`WITHDRAW` 后立刻解除：
  - `kind`: `SPATIAL_ATTACH | FUNCTIONAL_COUPLE | CONSTRAINT_LINK`
  - `channel`: `FOLLOW_TRANSFORM | DISTURBANCE_TO_PERCEPTION | ENERGY_FEED | CONTACT_TO_TRIGGER | GRAPH_SUPPORT`
  - 引用格式统一检查：`SUBJECT:<id>`, `WORLD_REF:<id>`, `CASTER:BODY`, `CASTER:HAND`, `CASTER:MANA`, `CASTER:RESERVE`, `TARGET:ANCHOR`, `TARGET:SURFACE`, `TARGET:ACTOR`（`TRANSFER.source_ref` 另允许 `ENV:WATER | ENV:MOISTURE | ENV:STONE | ENV:HEAT | ENV:CONDUCTOR`）。

---

## 四、事件驱动过程图 `process_graph` 与 `RuntimeEvent`

### 4.1 `process_graph` 结构与三段式生命周期

- 顶层 `process_graph` 包含 `entry_processes`（`1..4` 个起始过程 ID）与 `processes[]`（`1..8` 个）。**严禁孤立不可达过程（Stage 2 BFS 自动拒批）**。
- 每个 `ProcessSpec` **删除旧 `start` 字段**，强制包含：
  - `id`, `role` (`GENESIS | CARRIER_EXECUTION | CONSTRAINT_HOLD | TRANSFORM_STAGE | TRIGGER_WATCH | CLEANUP_DISSIPATE`)
  - **`on_enter[]`**：进入该过程时执行 **1 次**。**全 DSL 唯一允许放置 `ESTABLISH` 的阶段**（防止每帧重复实例化主体/关系）。
  - **`while_active[]`**：过程存活期间**每个物理 Tick 执行**，用于连续 `DRIVE`、`TRANSFER` 与 `CONSTRAIN` 维持。
  - **`on_exit[]`**：过程停止或转移退出时执行 **1 次**，负责 `WITHDRAW` 回收句柄、脉冲收尾或散热/消散。
  - `max_duration_s` (`0.0 < max_duration_s <= 30.0`)：任何过程都有明确寿命上限，超时触发 `ON_TIMEOUT`。

### 4.2 `RuntimeEvent` 作用域与转移 `transitions[]`

运行时发送的每条事件必须带有完整上下文作用域：

```text
RuntimeEvent {
  type:              ON_SPAWN | ON_INPUT_RELEASE | ON_INPUT_HOLD_EXPIRE | ON_TIMEOUT |
                     ON_COLLIDE | ON_CONSTRAINT_EXCEEDED | ON_GRAPH_COMPLETED |
                     ON_PHASE_CHANGED | ON_DEPLETED | ON_DISTURBANCE_PING
  cast_instance_id:  String   // 当前施法实例 ID
  source_subject_id: String   // 触发主体 ID（可为空）
  source_process_id: String   // 触发过程 ID
  payload:           Dict     // 碰撞法线/冲量/剩余MU等只读负载
  sim_tick:          int      // 确定性物理步编号
}
```

每条 `TransitionSpec` 显式声明：
- `event_source_filter`: `{ scope: "SELF_PROCESS" | "SUBJECT" | "CAST_INSTANCE", subject_id? }`
- `next_process_ids`: 转移目标进程列表
- `handoff_handles`: **必须显式列明要移交生命周期所有权给目标进程或后备池的句柄 ID**；凡未列出的本进程私有句柄在退出时自动释放，当 `action == "HANDOFF_TO_RESERVE"` 时，`handoff_handles` 严禁为空且 `provider.energy_source` 必须是 `POST_RELEASE_RESERVE` 或 `VESSEL_RESERVE`。

---

## 五、七大原子操作、Split `DRIVE` 与 `DirectionSpec`

1. **`ESTABLISH`** (`on_enter` 专用): 激活声明中的 `SUBJECT` 或 `RELATION`，可绑 `handle_id`。
2. **`DRIVE`**（Schema 严格拆分为两支，禁止冲量混入持续通道）：
   - **`OpDriveContinuous`**: `channel` ∈ `{ POSE, EXTENT, DISTRIBUTION, FLOW, INTENSITY, DIRECTION }`，严格搭配 `mode` ∈ `{ TARGET, RATE }`。
   - **`OpDriveImpulse`**: `channel` ∈ `{ VELOCITY_IMPULSE, INTENSITY_BURST }`，**严格锁定 `mode: "IMPULSE"`**。
   - 统一使用正交 **`DirectionSpec`**（禁止复合字符串）：
     - `WORLD_AXIS`: `{ mode: "WORLD_AXIS", axis: POS_X|NEG_X|POS_Y|NEG_Y|POS_Z|NEG_Z|UP|DOWN }`
     - `FRAME_RELATIVE`: `{ mode: "FRAME_RELATIVE", axis: AIM_FORWARD|CASTER_FORWARD|SURFACE_NORMAL|SURFACE_TANGENT }`
     - `RADIAL`: `{ mode: "RADIAL", center_ref, polarity: INWARD|OUTWARD }`
     - 如需同时向上抬升并向内聚拢（如 Case 2 引力沉渊），在 `while_active` 中并发两条原子 `DRIVE` 即可。
3. **`CONSTRAIN`**: `PIN | TETHER | CONTAIN | AXIS_LOCK | PRESSURE_WALL`，带 `desired_value`、`tolerance`、`capacity_lu`、`rebind_cooldown_s >= 0.05`、`on_exceed`（`DETACH | FRACTURE | VENT | STALL_NOTIFY`）与 `provider_ref`（`CASTER_MANA | POST_RELEASE_RESERVE | VESSEL_RESERVE | PASSIVE_STRUCTURE`）。
4. **`TRANSFORM`**: `PHASE_CHANGE | STRUCTURAL_CRYSTALLIZE | SUBDIVIDE | MERGE | IONIZE_OR_IGNITE | IGNITE_EXOTHERMIC | PROPAGATE | DISSIPATE`，强制声明 `preserve[]`。
   - **`PropagationSpec`**（当 `transform_id == "PROPAGATE"` 时必填）：
     - `medium_mode`: `CONDUCTIVE_GRAPH | VOLUME_OVERLAP`
     - `max_hops`: `1..12`, `hop_attenuation`: `0.0..1.0`
     - `graph_snapshot_mode`: `LIVE_CONNECTIVITY | INITIAL_SNAPSHOT`
     - `on_missing_origin`: `FALLBACK_TO_ROOT_NODE | ABORT_NO_COST`
   - **关于 `Weave(Freeze(W))` 与 `Freeze(Weave(W))` 的诚实边界**：
     - `Freeze(Weave(W))`：先以 `PATH_GRAPH(per_segment_phase=true)` 织就水流拓扑并维持动态流通，待蓄力/释放节点触发 `PHASE_CHANGE -> SOLID` 时，阶段一/二将其烘焙为单个受界复合晶格刚体（`max_output_bodies: 1`，总节点 `<= 16`）并可整体施压击飞。
     - `Weave(Freeze(W))`（先分别冻结离散冰珠再用连续铰链在运行期重编织刚体运动链）：当前四载体合同**不支持**无界多刚体铰链实时再编织，任何把 `WATER/ICE PHASE_CHANGE` 设置超出 `max_output_bodies > 16` 或把 `STONE PATH_GRAPH` 设为多段柔体链的请求都会在 **Stage 3 能力矩阵**被直接拦截。
5. **`TRANSFER`**: 将 `MU | EU | LU | HEAT` 从 `source_ref`（含 `ENV:*` / `CASTER:RESERVE`）以 `rate_per_s`、`max_amount` 传入目标主体，支持 `CLAMP_TO_AVAILABLE | PAUSE_PROCESS | ABORT_OP`。
6. **`COUPLE`**: 激活功能耦合类 `relation_id` 并生成具名 `handle_id`（如迷雾扰动感知回传或器物碰撞引信）。
7. **`WITHDRAW`**: 按 `HANDLE | SUBJECT_SUPPORTS | ALL_SPELL_SUPPORTS` 执行 `DISSIPATE | NATURAL_RELEASE | RECLAIM_TO_CASTER`。

---

## 六、可组合 ArtKit 模块表与独立预算公式

### 6.1 唯一合法的已注册 ArtKit 模块词汇

- **`contour_module`**（轮廓形态）：`SCULPTED_CORE`, `FACETED_PRISM`, `CONTINUOUS_RIBBON`, `BRANCH_TENDRIL`, `PLANAR_SIGIL`, `VOLUMETRIC_MIST`, `FIELD_AURA_RING`
- **`surface_modules`**（1–3 项叠加表面材质）：`REFRACTIVE_LIQUID`, `CRYSTALLINE_ICE`, `ROUGH_STONE`, `CONDUCTIVE_ARC`, `GRAVITY_DISTORTION`, `LIGHT_ABSORB_VOID`, `THERMAL_FROST`, `THERMAL_EMBER`, `RUNIC_BARRIER_GLASS`
- **`secondary_modules`**（0–3 项细节与世界留痕）：`VELOCITY_FOAM`, `STRESS_CRACKS`, `FROST_CREEP_DECAL`, `CRATER_DECAL`, `SCORCH_DECAL`, `FLOATING_DUST`, `ARC_SPARKS`, `SONAR_RIPPLES`
- **音频模块**：
  - `drone_module`: `NONE | CRYSTALLINE_HUM | SUB_VOID_RUMBLE | ARC_CRACKLE_HUM | HOLLOW_WIND | RESONANT_CHORD`
  - `impact_module`: `NONE | ICE_LOCK_CRACK | TECTONIC_SLAM | THUNDER_CRACK | HARMONIC_DEFLECT | FROST_SHATTER | ETHER_PING`
  - `sustain_loop_module`: `NONE | TENSE_WATER_STRAIN | SILENT_PRESSURE_HUM | SOFT_MIST_AMBIENCE | BARRIER_STRAIN_CHIME | ARC_HOLD_BUZZ`
  - `pre_delivery_silence_ms`: `0..120`（固定在起势转降临发招边界前触发的可预测静音窗）
- **局部打击顿帧**：`aftermath_profile.hitstop_local_ms`（`0..140`），仅作用于受击者与施法局部动作，**严禁改动 `Engine.time_scale`**。

### 6.2 Stage 4 确定性法力下界公式（与代码 100% 一致）

校验器完全忽略 `budget.compiler_status == "VALID"`，按以下公式独立验算并拒绝偷渡或白嫖法术：

1. **起步法力下界 `min_upfront_mana`**：
   $$\text{min\_upfront\_mana} = 2.0 + \sum_{s \in \text{subjects}} C_{\text{subj}}(s) + \sum_{g \in \text{spatial}} C_{\text{carrier}}(g) + 1.5 \times |\text{relations}|$$
   - 主体项 $C_{\text{subj}}$：`MATERIAL = 3.0 + 1.25 * initial_inventory_mu`；`FIELD = 6.0 + 0.20 * initial_intensity`；`WORLD_REF = 2.0`
   - 载体项 $C_{\text{carrier}}$：`BODY = 1.5`；`PATH_GRAPH = 0.25 * node_budget + 0.15 * edge_budget`；`SURFACE = 0.15 * quad_budget`；`REGION = 0.50 * initial_extent_m`
   - 必须满足：`min_upfront_mana <= derived_upfront_mana <= contract.combat.provider.max_upfront_mana` 且 `derived_upfront_mana > 0`。
2. **持续维持下界 `min_sustain_mana_per_s`**：
   - 遍历 `while_active`：当 `controller == CASTER_FOCUS` 时每条连续 `DRIVE` `+1.2`；每条 `TRANSFER` `+0.5`；每条 `provider_ref == CASTER_MANA` 的 `CONSTRAIN` `+max(0.5, 0.02 * capacity_lu)`；
   - 遍历 `on_enter/on_exit`：当 `controller == CASTER_FOCUS` 时每条感知/馈能 `COUPLE` `+1.2`。
   - 若使用 `POST_RELEASE_RESERVE` / `VESSEL_RESERVE` 供能，不计入施法者每秒维持费，但要求 `derived_reserve_mana == provider.post_release_reserve_mana >= 4.0`。

---

## 七、4 阶段校验门禁与现有已验证样例矩阵

执行入口：[`python3 game/tools/validate_dsl.py --self-test`](../game/tools/validate_dsl.py)

| 阶段 | 负责模块 | 拦截典型错误 |
|---|---|---|
| **Stage 1 · Structure** | Draft 2020-12 JSON Schema 严格校验 | 缺字段、额外 `overrides`、载体与生成器跨界、`IMPULSE` 误配 `TARGET`、`upfront_mana == 0`、非法 ArtKit 模块名 |
| **Stage 2 · Semantic** | 引用图 + 过程图可达性 + 句柄所有权 | 重复 ID、错指不存在主体/过程、`initial_inventory > capacity`、`ESTABLISH` 放进 `while_active`、孤立不可达过程、`HANDOFF` 无明确句柄 |
| **Stage 3 · Capability** | 能力矩阵 + `validate_limited_conditions` | 未规划组合、超 16 节点/16 刚体/64 四边、`SPATIAL_BARRIER` 缺策略或错用非 `SURFACE`、`Water->Ice` 无上界 |
| **Stage 4 · Budget & ArtKit** | 独立预算核算 + ArtKit 注册表 | 伪造 `"compiler_status": "VALID"` 的低价法术（如 `derived_upfront_mana: 1.0`）、超出合同峰值上限、未注册音画模块 |

当前已通过 4 阶段实机脚本全量校验的 7 份基准法术与 1 份语义样例：

| 文件 | 覆盖核心验证能力 |
|---|---|
| [case1_water_weave_freeze.json](../game/data/spells/case1_water_weave_freeze.json) | `PATH_GRAPH(per_segment_phase=true)` + `ENV:WATER` 吸收 + `HEAT_EXTRACTION` + `PHASE_CHANGE(max_output_bodies=1)` + `IMPULSE` 发射 |
| [case2_gravity_collapse.json](../game/data/spells/case2_gravity_collapse.json) | `DirectionSpec` 垂直抬升 + 径向向内拉扯拆分、`OpDriveImpulse` 砸地、`p_cleanup` 全程 `process_graph` 闭环 |
| [case3_conductive_lightning.json](../game/data/spells/case3_conductive_lightning.json) | **新增 Case 3**：`ELECTRIC_POTENTIAL` + `LIGHTNING_PLASMA` + `PROPAGATE(CONDUCTIVE_GRAPH, max_hops=6, LIVE_CONNECTIVITY, FALLBACK_TO_ROOT_NODE)` |
| [case4_fog_disturbance_sense.json](../game/data/spells/case4_fog_disturbance_sense.json) | `FOG` + `LIGHT_ATTENUATION` + `relations[]` 单一权威跟随与 `DISTURBANCE_TO_PERCEPTION` 扰动回传 |
| [case5_ward_mirror_surface.json](../game/data/spells/case5_ward_mirror_surface.json) | `SPATIAL_BARRIER` 专属 `barrier_policy` + `SURFACE(BOUNDED_PLANE)` + `HANDOFF_TO_RESERVE` 显式移交 `handoff_handles` |
| [case6_vessel_imprint_seal.json](../game/data/spells/case6_vessel_imprint_seal.json) | **新增 Case 6**：`WORLD_REF(VESSEL_IN_HAND)` + `CONTAIN(VESSEL_RESERVE)` + `CONTACT_TO_TRIGGER` 碰撞延迟引爆 |
| [case_compound_dark_moon.json](../game/data/spells/case_compound_dark_moon.json) | 四主体组合 + 三条显式 `SPATIAL_ATTACH` 关系 + `capacity_mu` / `initial_inventory_mu` 账本分离 |
| [sample_intent_water_weave_freeze.json](../game/data/intents/sample_intent_water_weave_freeze.json) | 组合语义从句 `clauses[]` + `rune_contributions[].bound_ids[]` 对接 `case1` 全链路溯源 |

> **故意留白说明**：**Case 7（未预设跨领域组合盲测）不预先写入仓库 JSON**，留待 Wave 2 由独立组合或 GPT/Claude 现场给定，直接检验零法术特化硬编码下的涌现上限。
