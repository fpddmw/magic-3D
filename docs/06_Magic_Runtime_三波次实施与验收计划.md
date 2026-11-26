# Magic Runtime 三波次（Wave 0–3）实施与验收计划（v0.2.1）

> **当前定位（2026-11-26）**：面向 **`Magic DSL v0.2.1`** 锁定施工顺序、消除前置依赖倒挂，并明确 **Godot 4.x（Forward+ / Jolt Physics）物理适配器契约**、**非破坏性四级资源守恒策略**与**慢拍厚重动作感生死门禁**。
> 配套规范：[02 · Magic DSL v0.2.1 正式语法与语义规范](02_Magic_DSL_v0.2_正式语法与语义规范.md) · 离线校验工具：[validate_dsl.py](../game/tools/validate_dsl.py)

---

## 一、开发绝对红线（Zero Fake Progress）

1. **严禁 `TODO / stub / hardcoded spell_id` 伪进度**：Wave 1A 起运行时调度中禁止出现 `if spell_id == "case2_gravity_collapse"`。所有行为只能驱动自 `Subject`、`Carrier`、`Relation`、`process_graph` 与 `WorldLaw`。
2. **绝不轻信任何入参的 `compiler_status`**：运行时加载任何 JSON（哪怕带 `"VALID"`）必经 `MagicDSLDocument.validate_all()` 完整跑通 Stage 1–4 才准入。
3. **禁止全局修改 `Engine.time_scale` 实现顿帧**：只允许利用局部动作动画停顿 / 打击受力暂停（`hitstop_local_ms <= 140`），避免破坏相机平滑、音频时钟、其余并行法术与联机潜力。
4. **先厚重动作底盘与闭环质量，后海量素材与 UI 美化**：若主控手感轻飘、视角穿模或法术没有前摇—蓄力—爆发—余韵节拍，严禁扩写下一波功能。

---

## 二、Godot 4 目录架构设计（`res://`）

```text
game/
├── data/
│   ├── schema/        # Draft 2020-12 强约束 Schema（magic_dsl_v0_2 & semantic_intent_v0_2）
│   ├── spells/        # 7 份通过 4 阶段校验的标准法术（Case 1–6 + 复合暗月；Case 7 留白盲测）
│   └── intents/       # 组合语义意图与 bound_ids 溯源样例
├── tools/
│   └── validate_dsl.py  # 零外部依赖 4 阶段离线验证器 + 12+ 负向非法法术回归套件
├── scenes/
│   └── main.tscn      # 废城白盒底座与角色控制器挂载点
└── scripts/
    ├── dsl/           # MagicDSLTypes / MagicCapabilityMatrix / MagicDSLDocument（已完成 v0.2.1 契约）
    ├── world_law/     # [Wave 1A–1B] 物理常数、导电邻接图、热容相变表、非破坏性资源管家
    ├── runtime/       # [Wave 1A–1B] SubjectInst、4载体引擎、ProcessGraph/RuntimeEvent 总线、7算子执行器
    ├── director/      # SpellDirector（ArtKitArbitrator 仲裁栈、局部顿帧、应变渲染参数映射）
    └── player/        # [Wave 0–1A] 第三人称近肩废城移动、举杖蓄力态、长按/松手与锁定控制器
```

---

## 三、物理帧契约与四级非破坏性资源守恒策略

### 3.1 Godot 4 `_physics_process` 首帧 `Area3D` 适配器契约（消除 Wave 1A 隐蔽时序 Bug）

在 Godot 4（Jolt / GodotPhysics3D）中，新创建的 `Area3D` 或刚刚在 `_physics_process` 里修改 `global_transform` 的查询区域，其 `get_overlapping_bodies()` / `get_overlapping_areas()` **不会在本物理帧立即刷新**，必须经过一次物理步进后才更新。因此 `MagicRuntime` 强制遵循以下 **6 步固定 Tick 序**：

1. **Tick 序首快照（Read Start-of-Tick Overlap）**：所有已存在超过 1 步的主体，在本 Tick 最开头统一读取上一物理步提交的 `Area3D` 重叠名单与触点法线；
2. **过程图事件入队与派发（ProcessGraph & RuntimeEvent Queue）**：按 `sim_tick` 消费 `ON_INPUT_RELEASE`、`ON_TIMEOUT`、`ON_COLLIDE` 等事件并执行 `on_exit` / 状态切换 / `on_enter`（确保所有 `ESTABLISH` 只在 `on_enter` 执行）；
3. **出生 1-Tick 缓冲规则（Spawn-Tick Deferral）**：凡在本帧 `on_enter` 新生成或瞬间瞬移重定位的 `REGION` / `SURFACE` / `PATH_GRAPH`，若需立刻执行范围判定或 `PROPAGATE` 首跳查询，**统一写入单帧挂起队列或执行一次性 `PhysicsDirectSpaceState3D.intersect_shape()` 同步空间查询**，绝不依赖刚创建的 `Area3D.get_overlapping_bodies()` 返回空数组；
4. **`while_active` 算子结算（Transfer / Continuous Drive / Constrain / Propagate）**：按固定预算计算实际施力与荷载 `realized_load_lu`；
5. **非破坏性资源上限检查（Budget & 4-Tier Conservation）**；
6. **只读状态发布给 `SpellDirector`（ArtKit 只读渲染 + 仲裁栈更新）**。

### 3.2 四级非破坏性资源守恒策略（取代“到 64 刚体直接删除旧物体”）

为解决 `p_limit` 下简单按 FIFO 删除已有法术冰柱/石块导致玩家构筑被静默破坏的重大体验缺陷，运行时对动态刚体（全局硬顶 64、单法术硬顶 16）采用严格的**非破坏性四级守恒降荷**：

| 层级 | 触发条件 | 运行时动作（绝不凭空抹消有效物质） |
|---|---|---|
| **Tier 1 · 施法前预检拒批** | 新法术申请的 `peak_dynamic_bodies` 加上当前活跃刚体将突破可用冗余 | 在起手前提示魔力结构过载/暂缓具现（拒绝新发而非强拆地上已有冰桥或战局结构） |
| **Tier 2 · 同源临近冻结体合并** | 同一空间簇内存在相邻且静止的同类固体块（如碎冰网块） | 合并碰撞形状进共用 `RigidBody3D` / 静态化集群，**严格守恒总体积与质量 `MU` 账本** |
| **Tier 3 · 远距静止体休眠固化** | 离交战主视锥外且速度趋零 > 1.5s | 强制进入低成本睡眠态或烘焙进轻量静态障壁层，随时随碰撞或热流冲击唤醒 |
| **Tier 4 · 超时余烬热力学消退** | 已耗尽 `RESERVE` 或进入 `CLEANUP_DISSIPATE` 的末端残片 | 先行触发粒子/声效热升华回馈、向 `WorldLaw` 留下永久焦痕/湿渍/霜层后再回收刚体 |

---

## 四、修正后的 Wave 0 → 1A → 1B → 2 → 3 无环依赖计划

> **P0-8 重排核心原则**：把所有互相咬死的前置依赖拆顺——先过离线校验与动作底座（Wave 0），再以单载体闭环验证两套最清晰的物理法术（Wave 1A），随后扩展路径树、环境吸收、传导图与器物烙印（Wave 1B），再考跨法术涌现与盲测 Case 7（Wave 2），最后接入离线语义编译与性能耐力压测（Wave 3）。

### Wave 0：契约门禁与废城动作底座（当前起点）

- **交付物**：
  - `game/tools/validate_dsl.py --self-test` 全绿（7 份正常法术 + 1 份语义溯源 + 12+ 项负向拒批测试）；
  - `MagicDSLTypes` / `MagicCapabilityMatrix` / `MagicDSLDocument` / `SpellDirector` v0.2.1 GDScript 契约就绪；
  - `main.tscn` 加载第三人称近肩废城探索操控（重脚步移动、翻滚/闪避、举杖长按与松手输入事件流对齐 `ON_INPUT_RELEASE`）。
- **硬门禁**：12 项负向测试 100% 在各自准确阶段拒批；操控帧率在 M6 实机跑满 60 FPS 无输入黏滞。

### Wave 1A：核心过程图引擎 + Case 2 & Case 5 双闭环验证

- **覆盖原语**：`ProcessGraph`（`on_enter/while_active/on_exit`）+ `RuntimeEvent` 总线 + `_physics_process` 首帧空间查询适配器 + `REGION` / `SURFACE` / 基础 `BODY` 载体 + `ESTABLISH` / `DRIVE(Continuous & Impulse)` / `CONSTRAIN(PRESSURE_WALL)` / `WITHDRAW` + `HANDOFF_TO_RESERVE` + `SpellDirector` 单法术四拍演出。
- **验收标准**：
  - **Case 2（引力沉渊）**：长按将废城石块与傀儡靶向上抬起并向中心收拢（验证双正交 `DirectionSpec`），松手触发 `ON_INPUT_RELEASE` 转入 `p_slam_down` 下砸冲量，落地产生 `pre_delivery_silence_ms` + `hitstop_local_ms` 局部顿帧 + `CRATER_DECAL` 留痕，并走完 `p_cleanup`；
  - **Case 5（定界折光壁）**：面前展开 4 四边有界平面，仅阻挡外部高速投射物（`barrier_policy.response_mode: REFLECT`），施法者自身贴身武器从内侧穿透不受阻，松手后通过 `handoff_handles` 无缝交给 `POST_RELEASE_RESERVE`，超荷载时触发 `FRACTURE` 并经 `Desired vs Realized` 反馈显示裂纹，**全过程零 `spell_id` 特判**。

### Wave 1B：PathGraph + 环境汲取 + 传导图 + 器物烙印（补齐 Case 1 / 3 / 4 / 6 / 暗月）

- **覆盖原语**：`PATH_GRAPH`（`per_segment_phase`）+ `TRANSFER(ENV:*)` + `TRANSFORM(PHASE_CHANGE / PROPAGATE / IGNITE_EXOTHERMIC / DISSIPATE)` + `WORLD_REF` + `relations[]` 单一权威跟随与 `DISTURBANCE_TO_PERCEPTION` / `CONTACT_TO_TRIGGER`。
- **验收标准**：
  - **Case 1（水网凝结）**：从附近水面槽汲取 `MU`（不突破 `capacity_mu`），编织多分支水流丝络后冻结为单复合刚体（诚实范围 `max_output_bodies=1`）击飞并碎裂成湿渍/冰痕；
  - **Case 3（连锁电势传导）**：测试 `LIVE_CONNECTIVITY` 现场通路——干石地仅单点灼烧；浇水（来自 Case 1 融化或环境水坑）后电弧沿 `CONDUCTIVE_GRAPH` 自动跃迁 `max_hops <= 6`；途中切碎导电连接即时遵循缺失原点契约退回根节点不崩溃；
  - **Case 4（微风感雾障）**：迷雾随施法者平滑跟随，外部敌人踏入雾区通过 `DISTURBANCE_TO_PERCEPTION` 回传方向性脉冲涟漪；
  - **Case 6（器物烙印延爆）**：手持石块注入 `VESSEL_RESERVE` 后脱手投掷，落地碰撞通过 `ON_COLLIDE` 解封 `HEAT_INJECTION` 激发热冲击；
  - **复合暗月（Case_Compound_Dark_Moon）**：四主体按三组 `SPATIAL_ATTACH` 同步悬停、`capacity_mu` 吸收与 `PIN` 破断坠落一次通过；四级资源守恒确保大场面不静默删物。

### Wave 2：系统性涌现、多法术仲裁与盲测 Case 7

- **核心任务**：
  - 开启 **多法术并存物理/光影仲裁**：先放 `Case 1` 冰晶残留融水，再用 `Case 3` 导电击穿同一摊水；用 `Case 5` 折光壁挡住 `Case 6` 抛出的引信石块触发反振自爆；
  - `ArtKitArbitrator` 验证多法术并行下 `sky_darken <= 0.7`、`peak_point_lights <= 3` 零闪烁平滑交接；
  - **盲测 Case 7**：由外部审阅者现场撰写一份仓库内此前**从未出现过 JSON** 的合法跨领域新法术（需满足 4 阶段校验），不改一行运行时代码直接放入游戏加载，验证真实泛化能力。

### Wave 3：离线语义工坊落地与性能耐力门禁

- **核心任务**：
  - 将玩家符文槽位构筑 / 可选离线大模型编译接入 `SemanticIntent v0.2.1 → CompiledSpellDSL v0.2.1` 下行通道，确保任意合法语义意图经 4 阶段校验后直接开火；战斗全程 `0` 次外部模型等待；
  - **Apple M6 性能与耐力测试**：同时活跃 3 套复合法术持续 60 秒并连续施法切换 30 分钟，验证单物理步魔法逻辑开销稳定 `<= 1.5 ms`、无场景树对象泄漏、无稳态帧率跌破 60 FPS。

---

## 五、提交 GPT 与 Claude 联合交叉审阅的关键复核清单（v0.2.1）

请审阅者优先审查以下 5 项设计合同，确认无实质隐患后即宣布 Wave 0 冻结并启动 Wave 1A 编码：

1. **过程图与句柄移交合同**：以 `process_graph`（`on_enter/while_active/on_exit`）配合 `handoff_handles` 取代 `process.start`，以及 `ESTABLISH` 严格锁定仅在 `on_enter` 出现的约束，是否足以堵死双激活与资源泄漏路径？
2. **Stage 4 独立法力下界公式**：`compute_independent_budget()` 中的 `min_upfront_mana` 与 `min_sustain_mana_per_s` 系数配比（特别是 `ENVIRONMENT_HARVEST` 减免起手消耗但计入吸收 Sustain、与 `VESSEL_RESERVE` / `POST_RELEASE_RESERVE` 转移至 `reserve_mana`），是否存在漏算高收益白嫖途径？
3. **`Weave(Freeze(W))` 的阶段一诚实范围**：在 `v0.2.1` 中显式限定阶段一至阶段二仅支持将 `PATH_GRAPH` 水络合成为单个复合刚体（`max_output_bodies: 1`），把可拆解多段冻结刚体铰链留到后续物理扩展，是否在表达力与工程可控之间取得了合适平衡？
4. **Godot 4 `_physics_process` 1-Tick `Area3D` 适配器与四级非破坏性资源守恒**：采用物理帧初统一读取 + 出生帧同步 `intersect_shape()` 绕开单帧滞后，以及四级降荷替换 FIFO 删除，是否适配 Godot 4 + Jolt 的真实运行机理？
5. **`SemanticIntent v0.2.1` 组合性重构**：用 10 类原子 `clause_role`、`target_archetype` 与强制 `rune_contributions[].bound_ids[]` 彻底替换旧 12 复合短语枚举，是否能无损表达全部 7+ 类案例以及未知新构筑？
