# Magic DSL v0.2.2 正式语法与语义规范（Surgical Convergence Revision）

> **执行基线归档**：以下是 4ea4626 时的 v0.2.2 正文。历史“单源”“词库”“当前阶段”均指该版本。现行语义权威见 [Magic Core](magic_core/README.md)，各执行域的数据归属见[迁移表](magic_core/资产迁移与版本.md)。

> **版本定位**：`v0.2.2`（2026-11-26）—— 在保留 v0.2.1 工程约束成果的前提下，完成针对第二次交叉审计的**外科手术式收口**：完整复原被误删的魔法现象与战斗施法契约、恢复精简载体专属空间分布、把传播还回正交算子组织器、升级按能力单调缩放的预算规则、切清真实 50 词符文与下游 `CompileTrace`、建立状态驱动的 ArtKit 基准表，并以单源规则表统一规则来源。
> **仓库范围红线（Option A）**：本仓库当前**纯粹作为设计规范 + 施工与验收计划 + Draft 2020-12 Schema + 单源声明式规则表 + 21 条负向向量规格 + 7 份基准法术样例与 Godot 4 空场景底座**；**不提前存放 `.py` / `.gd` 实现代码**，全部可执行校验器与运行时模块将在 Wave 0–3 按本规范从 [dsl_rules_v0_2.json](../game/data/rules/dsl_rules_v0_2.json) 统一生成/实现。

---

## 0. v0.2.2 外科收口总览（不破整体骨架，只修退步与漏洞）

| 收口项 | 原 v0.2.1 问题 | v0.2.2 精确修订 |
|---|---|---|
| **魔法现象复原** | Case 1 丢支点与打断落水并强加发射冲量；暗月漏移交 6 个随行场句柄且缺碰撞碎裂 | **Case 1 完整复原**原位多支点水网→松手沿连通凝固（Wave 1B 限 1 复合刚体、零发射冲量）→ `ON_INTERRUPT` 自然落水；**暗月**移交全部 7 句柄至降落、碰撞 `SUBDIVIDE(max_output_bodies=8)` 后撤销伴随场 |
| **空间分布 `distribution`** | 各载体 `SpatialSpec` 缺少截面、厚度、径向衰减与遇阻变形描述 | 恢复**精简且载体专属的 `SpatialDistribution`**（`BODY` 截面/长宽比/粗糙度；`PATH_GRAPH` 宽厚/宽度剖面/`on_obstruction`；`SURFACE` 厚度/边界柔化；`REGION` 径向衰减/边界），仍拒绝通用 CSG 与几何大集合 |
| **战斗施法契约 + 中断** | 只剩传统技能式前摇/后摇且删掉了 `ON_INTERRUPT` | 恢复 `formation_mode`、`min_deliverable_progress`、`charge_tiers`、`caster_mobility`、`release_policy`、`interruption_policy`、`control_focus`，并将 **`ON_INTERRUPT`** 恢复为一等事件 |
| **过程 DAG 与线性句柄** | BFS 只查可达不查环路；全局 handle 集合不核查所有权；`IMPULSE` 可混入 `while_active`；材料×相态未校核；主体可无空间定义 | 锁定过程图为 **严格 DAG（Kahn 拓扑）**；全局 `handle_id` 唯一 + **线性句柄所有权**（禁止移交未建句柄、禁止并行分支复制同一独占句柄）；`WhileActiveOpSpec` 严禁 `ESTABLISH` 与 `IMPULSE`；Schema 强制 **`material_id × initial_phase`** 兼容；活跃 `MATERIAL`/`FIELD` 必须至少绑定一个 `spatial[]` |
| **能力单调缩放预算** | 按操作数量计费，导致冲量 `28 -> 500` 时预算下界完全不变 | 从 [dsl_rules_v0_2.json](../game/data/rules/dsl_rules_v0_2.json) 统一引入随**冲量幅值、转移总量、相变容量、碎裂数、传播半径与跳数、持续驱动速度、约束荷载**单调递增的预算规则 |
| **正交 `PropagationSpec`** | 把传播塞进 `TRANSFORM(transform_id="PROPAGATE")`，丢失传播物理过程 | 从 `transform_id` 移除 `"PROPAGATE"`，恢复正交 `PropagationSpec`（`domain, origin_ref, speed_m_s, max_reach_m, max_hops?, attenuation, connectivity_policy, on_missing_origin`），第一阶段**仅允许挂在 `TRANSFORM / DRIVE / TRANSFER`** 上 |
| **真实词义 + `CompileTrace`** | `SemanticIntent` 混入技能组件词与先猜下游 ID 的 `bound_ids` | 回退至极简 `clauses[] { id, meaning, subject_ref, input_refs, scope_target_clause_id?, timing }`，Strictly 使用项目真实 **50 枚中文符文词库（48 基础词 + `重 / 界`）**；下游编译器单独吐出 **`CompileTraceSpec`** 映射 `clause_id -> dsl_ids[]` |
| **状态驱动 ArtKit** | 在主体上静态固化视觉模块，相变后模块含义不清晰 | ArtKit 按 **`(material_id, current_phase, carrier)` / `(field_channel, carrier)`** 动态查默认基线（如水→冰自动切换折射液面→结晶冰体）；DSL 仅声明 **`art_overrides`** |
| **单源规则与共享向量** | Python 与 GDScript 两份手写校验逻辑出现漂移 | 所有阈值、枚举、能力矩阵、相态矩阵、预算系数、ArtKit 默认表统一收敛到 [dsl_rules_v0_2.json](../game/data/rules/dsl_rules_v0_2.json)，全部 21 条负向测试收敛到 [validator_negative_vectors.json](../game/data/tests/validator_negative_vectors.json) |

---

## 一、三层架构、规范单位制与单源规则

1. **三层隔离**：
   - **`SemanticIntent v0.2.2`**（[semantic_intent_v0_2.schema.json](../game/data/schema/semantic_intent_v0_2.schema.json)）：纯真实词义组合图（50 枚实词，禁止技能名与 `RUNE_*` 组件名，不预猜下游 DSL ID）。
   - **`CompiledSpellDSL v0.2.2`**（[magic_dsl_v0_2.schema.json](../game/data/schema/magic_dsl_v0_2.schema.json)）：确定性静态契约，编译器同步产出一份只读 `CompileTraceSpec` 建立可追溯映射。
   - **`Runtime + WorldLaw + ArtKit`**：`inherit_world_law: true` 强制继承世界物理/热力学/导电法则，严禁 `overrides`；`ArtKit` 只读状态快照并按实际材料与载体选择表现。
2. **规范单位与硬顶**：距离 `m`、时间 `s / ms`、物质 `MU`、能量/法力 `EU / Mana`、结构荷载 `LU`。全局硬顶全部声明于 `dsl_rules_v0_2.json -> hard_limits`（单法术 `bodies <= 16`, `global bodies <= 64`, `nodes <= 16`, `edges <= 24`, `quads <= 64`, `lights <= 3`, `pre_delivery_silence_ms <= 120`, `hitstop_local_ms <= 140`）。

---

## 二、主体、四载体 `SpatialDistribution` 与单一关系权威

### 2.1 `subjects[]`（严禁 `overrides`，强制 `material × initial_phase`）

- **`MATERIAL`**：必填 `id, material_id, initial_phase, capacity_mu, initial_inventory_mu (<= capacity_mu), inherit_world_law: true, art_overrides`。Schema 通过 `allOf` `if/then` 锁死物理相态兼容（例如 `WATER` 仅允许 `LIQUID`，`ICE/STONE/METAL` 仅 `SOLID`，`FOG` 仅 `GAS_MIST`，`FLAME/LIGHTNING_PLASMA` 仅 `PLASMA`）。
- **`FIELD`**：必填 `field_channel, initial_intensity (<= max_intensity), max_intensity, art_overrides`；仅当 `field_channel == "SPATIAL_BARRIER"` 时必填且允许 `barrier_policy`。
- **`WORLD_REF`**：查询既有世界对象（`VESSEL_IN_HAND | TARGET_SURFACE | NEARBY_MEDIUM | LOCKED_ACTOR`），不强占空间实体配额；**凡活跃的 `MATERIAL` 与 `FIELD` 主体必须在 `spatial[]` 中拥有至少一个对应载体定义**。

### 2.2 四大有限载体与专属 `SpatialDistribution`

| `carrier` | `dimension` | `generator` | 专属 `distribution`（宏观塑形而不引入通用 CSG） | `reference` |
|---|---|---|---|---|
| `BODY` | `3D` | `SPHERE_SCULPT / LANCE_PRISM / SLAB_MONOLITH / COMPOUND_FROM_PATH` | `cross_section (CIRCULAR/PRISM/SLAB)`, `aspect_ratio`, `surface_roughness` | **仅出生点锚定**（`spawn_anchor` + 可选 `auto_support_rule`；禁止 `binding`） |
| `PATH_GRAPH` | `1D` | `LINE_SEGMENT / ARC_CURVE / BRANCH_WEB / CLOSED_RING` | `width_m`, `thickness_m`, `width_profile (CurveProfileSpec)`, `on_obstruction (DEFORM_OR_TRUNCATE/SLIDE_BOUNDARY/HALT)` ＋ **`per_segment_phase`** | 同上 |
| `SURFACE` | `2D` | `BOUNDED_PLANE / SWEPT_STRIP / CONFORMAL_SHELL` | `thickness_m`, `boundary_falloff (SHARP/FEATHERED)`, `edge_profile (CurveProfileSpec)` | 同上 |
| `REGION` | `3D` | `RADIAL_SPHERE / CYLINDER_COLUMN / CONE_SECTOR / ALIGNED_BOX` | `radial_falloff (CONSTANT/LINEAR_DECAY/BELL_CONCENTRATED/INVERSE_EDGE)`, `boundary (SHARP/SOFT)` | 同上 |

### 2.3 单一权威 `relations[]`

持续追踪（`FOLLOW_TRANSFORM`）、多支点支撑（`GRAPH_SUPPORT`）、雾区扰动感知回传（`DISTURBANCE_TO_PERCEPTION`）、馈能（`ENERGY_FEED`）与器物碰撞触发（`CONTACT_TO_TRIGGER`）统一声明在 `relations[]`，**仅在 `on_enter` 经 `ESTABLISH(RELATION)` / `COUPLE` 激活，并于退出或 `WITHDRAW` 时即时失效**。

---

## 三、真实战斗施法契约 `ContractSpec` ＋ 事件驱动 DAG `process_graph`

### 3.1 `ContractSpec`（不再只是冷却时长，体现真博弈窗口）

- `formation_mode`: `INSTANT | GRADUAL_CHARGE | SUSTAINED_CHANNEL | VESSEL_IMPRINT`
- `timing`: `windup_s`, `full_charge_s`, `recovery_s`, `max_active_duration_s`
- `min_deliverable_progress` (`0..1`) ＋ 可选 `charge_tiers[]`（蓄力门槛与尺度/强度/能耗分档倍率）
- `caster_mobility`: `FREE_MOVE | SLOW_WALK | ROOTED`
- `release_policy`: `{ on_valid_release, on_under_threshold_release }`（区分阈值内提前取消与达标释放）
- `interruption_policy`: `{ on_interrupt (ABORT_AND_DROP | COLLAPSE_IN_PLACE | COMMIT_IF_PAST_THRESHOLD), dodge_behavior (TRIGGER_INTERRUPT | ALLOW_DODGE_AFTER_HANDOFF), interruption_priority }`
- `control_focus`: `{ owner (CASTER_FOCUS | AUTONOMOUS | VESSEL_BOUND), exclusive_focus_slot }`

### 3.2 DAG `process_graph`、阶段算子权限与线性句柄所有权

1. **有向无环图（DAG）约束**：`process_graph` 由 `entry_processes[]` 启动，所有过程必须从入口可达且拓扑排序无环（持续脉动、牵引与维持统一由 `while_active` 承担）。
2. **三段分权**：
   - `on_enter[]`（入场 1 次）：允许所有 7 类算子，**唯一允许 `ESTABLISH` 的阶段**。
   - `while_active[]`（每物理 Tick）：仅允许 `OpDriveContinuous (TARGET|RATE)`、`OpConstrain`、`OpTransfer`、`OpCouple`、`OpWithdraw`；**Schema 层面严禁 `OpEstablish` 与 `OpDriveImpulse`**。
   - `on_exit[]`（离场 1 次）：允许 `OpDriveImpulse`、`OpTransform`、`OpTransfer`、`OpWithdraw`。
3. **全局唯一与线性句柄所有权**：
   - 整份 DSL 内声明的全部 `handle_id` **必须全局唯一**（不允许两个操作复用同一 `handle_id`）；
   - 每个进程在退出过渡中能放进 `handoff_handles` 的，**仅限该进程自己创建的句柄或从前置进程合法继承得到的句柄**（严禁移交尚未建立的未来句柄，禁止单个并行分支把同一独占句柄复制给多个子进程）。
4. **`ON_INTERRUPT` 一等事件**：所有可控蓄力/引导法术均显式提供 `ON_INTERRUPT` 转移链路，明确受击强打断与玩家主动 `ON_INPUT_RELEASE` 产生不同物理结局。

---

## 四、正交 `PropagationSpec` 与 7 类原子操作

- **方向正交**：`DirectionSpec` 严格为 `WORLD_AXIS | FRAME_RELATIVE | RADIAL`。
- **驱动拆分**：`OpDriveContinuous`（`POSE | EXTENT | DISTRIBUTION | FLOW | INTENSITY | DIRECTION`, `TARGET | RATE`）与 `OpDriveImpulse`（`VELOCITY_IMPULSE | INTENSITY_BURST`, 仅 `IMPULSE`）。
- **`PropagationSpec`（不再伪装成 `TRANSFORM` 变体）**：
  - 结构：`{ domain (SPATIAL_RADIUS | PATH_CONNECTIVITY | SURFACE_SPREAD | CONDUCTIVE_GRAPH), origin_ref, speed_m_s, max_reach_m, max_hops?, attenuation, connectivity_policy (LIVE_CONNECTIVITY | INITIAL_SNAPSHOT), on_missing_origin (FALLBACK_TO_ROOT_NODE | ABORT_NO_COST) }`。
  - **允许范围约定（阶段一锁定）**：**仅允许可选挂载于 `TRANSFORM`、`DRIVE`、`TRANSFER`**（如 `Case 1` 的 `TRANSFORM(PHASE_CHANGE) + PATH_CONNECTIVITY` 与 `Case 3` 的 `DRIVE(INTENSITY_BURST) + CONDUCTIVE_GRAPH`），**禁止挂载于 `ESTABLISH` 与 `WITHDRAW`**，保证句柄生命周期原子化。
- **`Weave(Freeze)` 诚实实现范围**：阶段一至阶段二保留多支点 `PATH_GRAPH(per_segment_phase=true)` 柔体牵扯与沿路径传播凝固（`TRANSFORM(PHASE_CHANGE -> SOLID) + PATH_CONNECTIVITY`），并将最终冻结输出限定为 `max_output_bodies: 1` 的单复合可承重/可碎裂刚体；后续需要多段可拆铰链冰柱时再按能力矩阵单独开放。

---

## 五、能力单调预算规则与状态驱动 ArtKit

### 5.1 能力单调预算（同源于 `dsl_rules_v0_2.json -> budget_formula`）

Stage 4 永远忽略 `budget.compiler_status`，直接按 `dsl_rules_v0_2.json` 计算以下三项下界（确保更高冲量、更大覆盖、更大容量、更远传播与更高维持强度的法术**严格要求更高预算**）：

- **基础与主体空间项**：`2.0` ＋ 材料（`3.0 + 1.25 * initial_inventory_mu`）＋ 场（`5.0 + 0.15 * initial_intensity + 0.10 * max_intensity`）＋ 参照（`2.0`）＋ 载体缩放（`BODY: 1.2*extent`；`PATH_GRAPH: 0.25*nodes + 0.15*edges + 0.30*extent`；`SURFACE: 0.15*quads + 0.40*extent`；`REGION: 0.60*extent`）＋ 每条关系 `+1.5`。
- **主动能力按强度递增项**：
  - `OpDriveImpulse`: `magnitude * 0.15`（例如引力冲量 `28 -> 500` 直接抬高下界 `+70.8` 魔力，杜绝白嫖）；
  - `OpTransfer`: `max_amount * 0.25`；
  - `OpTransform`: `PHASE_CHANGE/STRUCTURAL_CRYSTALLIZE` 按 `capacity_mu * 0.35`，`SUBDIVIDE` 按 `max_output_bodies * 0.80`，`DISSIPATE` 不额外加费；
  - `OpConstrain`: `capacity_lu * 0.02`；
  - 凡带 `propagation` 的操作：额外 `+ 0.25 * max_reach_m + 0.50 * max_hops`；
  - 上述费用按“是否处于 `HANDOFF_TO_RESERVE` / `VESSEL_RESERVE` 后置分支”归入 `min_upfront_mana` 或 `min_reserve_mana`（凡使用储备均要求 `>= 4.0`）。
- **每秒维持下界 `min_sustain_mana_per_s`**：`CASTER_FOCUS` 下每条 `while_active` 连续 `DRIVE` 按 `0.5 + 0.12 * |magnitude|` 递增，`TRANSFER` 按 `0.15 * rate_per_s` 递增，`CONSTRAIN(CASTER_MANA)` 按 `0.02 * capacity_lu` 递增，`DISTURBANCE_TO_PERCEPTION / ENERGY_FEED` 耦合每条 `+1.2`。

### 5.2 状态驱动 ArtKit 表现映射

- 运行时渲染优先按当前真实状态查表 `dsl_rules_v0_2.json -> artkit_state_defaults`（例如 `(WATER, LIQUID, PATH_GRAPH)` → `BRANCH_TENDRIL + REFRACTIVE_LIQUID + VELOCITY_FOAM`；相变发生时依据 `per_segment_phase` / `PropagationSpec` 推进冻结前沿并平滑过渡到 `(ICE, SOLID, BODY/PATH_GRAPH)` 的 `CRYSTALLINE_ICE + STRESS_CRACKS`）。
- DSL 的 `art_overrides` 仅提供色板（`tint_palette`）、必要细节追加或轮廓/表面艺术覆写；多法术共存由 `ArtKitArbitrator` 仲裁（`sky_darken <= 0.7`, `peak_point_lights <= 3`），命中停顿严格走局部 `hitstop_local_ms (0..140)`，发招音画收敛走可预测 `pre_delivery_silence_ms (0..120)`，严禁篡改全局 `Engine.time_scale`。

---

## 六、真实词义层（50 词典）与 21 条负向向量规格

- **语义词库锁定**：`semantic_intent_v0_2.schema.json` 直接引用来自 [符文与词义设计](design/符文与词义设计.md) 的 48 枚候选词＋本次明确增补的 `重`（引力/载荷尺度）、`界`（空间结界/阻断过滤）共 **50 枚真实实词**，严禁使用 `RUNE_*` 工程名或复合行为短语。
- **反转必须有界**：任何 `meaning == "反转"` 的 `IntentClause` 必须指定 `scope_target_clause_id`。
- **Wave 1A 首批最小核心 20 词**：`水、气、火、土、以太、重、界、借用、汇聚、延展、交织、凝固、弥散、反转、守护、束缚、封存、唤醒、回应、爆发`。
- **7 份基准法术与 21 条共享负向测试规格**（Case 7 留白用于 Wave 2 盲测）：
  - 正常样例：[case1_water_weave_freeze.json](../game/data/spells/case1_water_weave_freeze.json) · [case2_gravity_collapse.json](../game/data/spells/case2_gravity_collapse.json) · [case3_conductive_lightning.json](../game/data/spells/case3_conductive_lightning.json) · [case4_fog_disturbance_sense.json](../game/data/spells/case4_fog_disturbance_sense.json) · [case5_ward_mirror_surface.json](../game/data/spells/case5_ward_mirror_surface.json) · [case6_vessel_imprint_seal.json](../game/data/spells/case6_vessel_imprint_seal.json) · [case_compound_dark_moon.json](../game/data/spells/case_compound_dark_moon.json) · [sample_intent_water_weave_freeze.json](../game/data/intents/sample_intent_water_weave_freeze.json)
  - 21 条共享负向向量（12 基础 + 9 压力测试）：[validator_negative_vectors.json](../game/data/tests/validator_negative_vectors.json)
