# Magic Runtime 分波次实施与验收计划（v0.2.2 · 纯计划基线）

> **当前定位（2026-11-26）**：面向定稿中的 **`Magic DSL v0.2.2`（Surgical Convergence Revision）** 制定 Godot 4.x（Forward+ / Jolt Physics 3D）无环施工路线、物理帧适配契约、简化的两级资源守恒策略与早期真实词义验证计划。
> **状态说明**：截至本次修订，仓库保持**纯粹设计规范 ＋ 实施计划 ＋ Schema / 单源规则 / 基准数据 ＋ 废城白盒场景**状态（所有 `game/scripts/` 与 `game/tools/` 将在 Wave 0 起从单源规则文件统一施工生成）。
> 核心配套：[02 · Magic DSL v0.2.2 正式语法与语义规范](02_Magic_DSL_v0.2_正式语法与语义规范.md) · 单源规则表：[dsl_rules_v0_2.json](../game/data/rules/dsl_rules_v0_2.json) · 21 条共享负向向量：[validator_negative_vectors.json](../game/data/tests/validator_negative_vectors.json)

---

## 一、施工红线（Zero Fake Progress & Single-Source Rules）

1. **禁止手写两套漂移规则**：Wave 0 落地的 Python 工具（构筑/CI 检查）与 GDScript 校验器（运行期准入）**必须读取同一份 [dsl_rules_v0_2.json](../game/data/rules/dsl_rules_v0_2.json)**，并通过同一组 [validator_negative_vectors.json](../game/data/tests/validator_negative_vectors.json)（21 条全红拦截）回归检验，绝不允许各自硬编码魔法数字。
2. **禁止法术特判与忽略校验**：运行时严禁出现 `if spell_id == "..."`；载入任意 JSON 时必须完整跑通 4 阶段检验并重算独立预算，忽略入参自带的 `"compiler_status": "VALID"`。
3. **禁止用 `Engine.time_scale` 做顿帧**：爆发打击仅触发作用目标与施法局部动作停顿（`hitstop_local_ms <= 140`），确保相机、音频、多法术与物理步完全稳定。
4. **不在早期过度设计物理回收**：阶段一不做动态刚体合并/再拆分与远距静态烘焙；只做创建前预算预检与利用 Jolt 原生刚体休眠。

---

## 二、待施工的 Godot 4 工程目录蓝图（`res://`）

```text
game/
├── data/                         # 【本阶段已落盘 · 唯一真相源】
│   ├── schema/                   # Draft 2020-12 Schema（magic_dsl_v0_2 / semantic_intent_v0_2）
│   ├── rules/dsl_rules_v0_2.json # 能力矩阵、相态矩阵、DAG/句柄规则、预算系数、ArtKit默认表、50词表
│   ├── tests/                    # validator_negative_vectors.json（21条负向规格）
│   ├── spells/                   # 7 份 v0.2.2 基准法术 JSON（Case 7 故意留白用于 Wave 2 盲测）
│   └── intents/                  # 真实 50 词语义意图示例
├── scenes/main.tscn              # 废城白盒光影场景底座（纯净无悬空脚本）
├── tools/                        # [Wave 0 待施工] 读取 dsl_rules_v0_2.json 的 CI 校验脚本
└── scripts/                      # [Wave 0–3 待施工]
    ├── dsl/                      # 单源规则加载器、4阶段校验器、Compiler（含 Wave 1A 20词原型）
    ├── world_law/                # 物理常态参数、湿润/导电邻接图、热相变表、创建前预算预检
    ├── runtime/                  # SubjectInst、4载体引擎、DAG ProcessGraph、RuntimeEvent 与 7算子
    ├── director/                 # ArtKit（状态驱动模块表 + Arbitrator 仲裁栈 + 局部顿帧/音效）
    └── player/                   # 第三人称近肩废城移动、举杖蓄力、翻滚/受击产生 ON_INTERRUPT 控制器
```

---

## 三、Godot 4 物理适配器契约与简化资源策略

### 3.1 Godot 4 `_physics_process` 1-Tick `Area3D` 适配器契约

Godot 4（Jolt / GodotPhysics3D）中，新建或刚通过 `global_transform` 瞬移重定位的 `Area3D`，其 `get_overlapping_bodies()` / `get_overlapping_areas()` 会滞后 1 个物理帧。因此 `MagicRuntime` 在每个物理 Tick 必须严格按 **6 步固定序** 推进：

1. **Tick 初读取重叠缓存**：已存活 `>= 1` Tick 的区域统一读取上帧物理步提交的重叠体与触点法线；
2. **DAG `ProcessGraph` 与 `RuntimeEvent` 派发**：按 `sim_tick` 消费 `ON_INPUT_RELEASE`、`ON_INTERRUPT`、`ON_COLLIDE`、`ON_TIMEOUT` 等事件，检查 `interruption_policy`，执行 `on_exit` / 线性移交 `handoff_handles` / `on_enter`（`ESTABLISH` 只在 `on_enter` 执行）；
3. **出生/瞬移帧同步空间查询绕过**：凡本 Tick 在 `on_enter` 刚建立或重定位的 `REGION` / `SURFACE` / `PATH_GRAPH`，若需首帧立即执行吸附支点（Case 1）、触发检测或首跳传导（Case 3 `LIVE_CONNECTIVITY`），**必须调用 `PhysicsDirectSpaceState3D.intersect_shape()` / `intersect_ray()` 进行同步查询**，或将区域监测明确延迟 1 个物理步进队列；
4. **`while_active` 与 `Propagation` 结算**：更新连续 `DRIVE`、`TRANSFER`、`CONSTRAIN` 与跨步传播前沿，严禁在 `while_active` 出现 `IMPULSE`；
5. **创建前预算与 Jolt 原生休眠结算**；
6. **只读发布状态快照至状态驱动 `ArtKitDirector`**。

### 3.2 简化的阶段一资源守恒策略（两项机制，不过度复杂化）

全球活跃魔法动态刚体硬顶 `64`、单法术硬顶 `16`。阶段一不引入破坏身份与热力关系的“多刚体合并与拆解”，仅靠以下两步稳定控成本：

1. **施法前预算预检拒批**：新建刚体类法术或 `SUBDIVIDE` 申请前检查 `当前活跃刚体数 + 申请峰值 <= 64`；若超额则在施法起手提示魔力饱和过载，**宁可拒批或暂缓新法术，绝不静默删掉玩家现场已构筑的冰桥或暗月残骸**；
2. **复用 Jolt 原生休眠与末端热消退**：静止且无持续外力作用的冰体直接由 Godot/Jolt 物理引擎自动进入低开销休眠态（仍保留完整身份、温度、导通性与碰撞）；仅当进入生命末期或被彻底击碎融尽后，才自然热消退、落下永续地面霜痕/湿迹/焦痕，随后归还刚体槽位。

---

## 四、无环五阶段路线：`Wave 0 → 1A → 1B → 2 → 3`

### Wave 0：单源规则引擎 ＋ 21 条门禁 ＋ 废城慢拍操控底座

- **核心工程**：
  1. 在安装好 **Godot 4.4+（启用 Jolt Physics）** 后，实现读取 `dsl_rules_v0_2.json` 的唯一校验核心（含 Python CI 与 GDScript 运行期准入）并 **21/21 全部拦截 `validator_negative_vectors.json`** + 7 份基准法术全绿；
  2. 完成第三人称近肩主角控制器与废城白盒场馆（移速惯性、翻滚/举盾、蓄力慢走与定身、主副手瞄准），确保 **主动松手（`ON_INPUT_RELEASE`）、阈值内取消、翻滚打断与受击强打断（`ON_INTERRUPT`）** 四路输入流物理手感扎实时实落地。

### Wave 1A：核心过程图 ＋ Case 2 / Case 5 ＋ 早期 20 词编译原型

- **核心工程**：
  1. 实现 `BODY` / `REGION` / `SURFACE` 三载体（含各自 `SpatialDistribution` 曲线/衰减参数）、DAG `ProcessGraph` + `RuntimeEvent` 总线、线性句柄所有权移交、`WorldLaw` 基础上界与状态驱动 ArtKit 基线替换；
  2. **同步交付“Wave 1A 20 词确定性编译器原型”**：直接用 [dsl_rules_v0_2.json](../game/data/rules/dsl_rules_v0_2.json) 中的 20 枚核心真实词（`水、气、火、土、以太、重、界、借用、汇聚、延展、交织、凝固、弥散、反转、守护、束缚、封存、唤醒、回应、爆发`），现场把中文符文回路降低为合法 `CompiledSpellDSL` ＋ `CompileTrace`，早期即实证 Case 2 与 Case 5 可从真实词义自然生成；
  3. **验收案例**：
     - **Case 2（引力沉渊）**：双 `DirectionSpec` 垂直抬升＋向内收拢、`ON_INPUT_RELEASE` 触发 `28.0` 往下冲量、`ON_INTERRUPT` 立即中止、局部顿帧 `hitstop_local_ms` 与 `CRATER_DECAL` 留痕；
     - **Case 5（定界折光壁）**：`SURFACE(BOUNDED_PLANE)` 单向透射（术者穿行无阻、外部弹道 `REFLECT`）、松手精准仅移交保留所需句柄进入 `POST_RELEASE_RESERVE`、过载 `FRACTURE` 并按实测荷载显示裂纹。

### Wave 1B：复原完整 Case 1 / 3 / 4 / 6 与复合暗月

- **核心工程**：接入 `PATH_GRAPH`（`width_profile`、`on_obstruction`、`per_segment_phase`）、`PropagationSpec`（`PATH_CONNECTIVITY` 与 `CONDUCTIVE_GRAPH`）、`TRANSFER(ENV:WATER)` 与 `WORLD_REF`。
- **验收案例**：
  - **Case 1（霜狱织网）**：多支点吸附拉网、受力拉伸 `COHESION/SUPPORT`、主动松手后零发射冲量沿连通冻结为 1 个原位复合可踩/可碎冰体、中途受击触发 `ON_INTERRUPT` 令液态水自然泼落；
  - **Case 3（连锁电势）**：验证干地/湿地的实时连通分支（`LIVE_CONNECTIVITY`），导通路途打断触发缺失原点退回不崩；
  - **Case 4（微风感雾障）** 与 **Case 6（器物烙印延爆）**：验证跟随关系、扰动感知回传、手持器物 `VESSEL_RESERVE` 封存与碰撞引爆；
  - **复合暗月（Case_Compound_Dark_Moon）**：验证 7 句柄全部随 `HANDOFF_TO_RESERVE` 伴随下降、坠地 `ON_COLLIDE` 碎裂成 8 个有界碎块后再逐一撤销 3 个伴随场，以及受击强打断全部消散。

### Wave 2：系统性化学涌现、多法术冲突仲裁与盲测 Case 7

- **核心工程**：完整打通跨法术世界交互（Case 1 遗留冰晶/积水导通 Case 3 电流；Case 5 折光壁弹返 Case 6 烙印掷物）；验证 `ArtKitArbitrator` 并行灯光 `<= 3` 与天光收敛 `<= 0.7`；
- **盲测 Case 7 终极验收**：由外部审阅者现场基于 50 真实词库撰写全仓从未出现过的新构思，直接编译并零特判在游戏里跑出预期现象与余韵。

### Wave 3：全 50 词法坛工坊接入 ＋ Apple M6 实机性能/耐力过检

- **核心工程**：扩展确定性规则库覆盖完整 50 实词及暂停期语义解析辅助接口；Apple M6 1080p 下同时维持多法术并行 60 秒并做 30 分钟切法术耐力压测，保证魔法运行时单帧开销 `<= 1.5 ms`、场景树 0 泄漏、全程稳跑 60 FPS。

---

## 五、Wave 1A 锁定前的最后 3 项细节确认

本次维护已将原 8 项共识全面写入规范与数据表，仅以下 3 项已在规划内采纳并请 GPT / Claude 最终打勾锁定即可直接开始 Wave 0 代码实施：

1. **`PropagationSpec` 作用域锁定**：阶段一明确**只允许挂在 `TRANSFORM / DRIVE / TRANSFER`** 上，严禁挂在 `ESTABLISH` / `WITHDRAW` 上，确保句柄所有权原子化。
2. **Wave 1A 最小核心词表增补 `重 / 界`**：在 [符文与词义设计](design/符文与词义设计.md) 原有 48 词基础上增补 **`重`**（引力/质量尺度）与 **`界`**（空间屏障/过滤规则），合共 50 词，并先行抽取 20 枚核心词在 Wave 1A 同步做出确定性编译原型验证。
3. **本仓保持纯粹“规范 ＋ 计划 ＋ 数据源”，施工阶段开启后再写代码**：已清理旧越界原型代码（Option A），后续由单一权威 `dsl_rules_v0_2.json` 驱动生成/实现 Wave 0 校验器，杜绝双套逻辑漂移。
