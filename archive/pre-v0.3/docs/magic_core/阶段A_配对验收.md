# 阶段 A 配对验收 · Core 0.1.1

本轮验收检查两个问题。玩家在法坛改选方向，执行层能否得到相反的作用？同一张水网在现场断开，凝固能否停在断口？第一组固定现场、改变构筑。第二组固定构筑、改变现场。输入差分、测试数值和预期结果都收录在[配对向量](../../game/data/tests/semantic/paired_projections.json)。

## 从输入重建待比较的字段

1. 从基准案例只取 `graph`。按 `inputs` 的依赖顺序读节点，逐词配对 `words[i]` 与 `operands[i]`。词的对象类型必须匹配，`match.all` 中每项都有来源才能选中。零个候选报告 `INVALID_MEANING`，多个独立解释报告 `AMBIGUOUS`。见[词义表](../../game/data/core/meanings.json)与[事实来源](../../game/data/core/matching_basis.json)。
2. `reads` 只能取登记的概念、性质、参照、契约、选择，或同节点较早及依赖链上已成立的词项。地址 `n3:1` 指 n3 的第二个词。性质读取须与 `aspect_ref` 一致，且依赖链中有本体依据。向后提供的事实取自 `grant`。契约可在选定的持续过程上追加有条件的产出。将每个原始词项的 `at_use` 写入 Core 的 `obligations`，连同词项地址保留。共享引用 `reuse` 复用已有结果与条件。
3. 用该节点实际读到和推得的事实核对 `intent_normalization`。每个 `intents[].ref` 是构筑内的局部引用。主体的归一化结果是 `spatial_intent`，含空间形态、布局、分布与锚点。过程可取得 `direction`、`profile`、`when`、`propagation` 和相应的操作、效果。相变词项的主体引用必须等于传播选择的材料引用。该材料来自可达的上游主体，并须满足传播所需的空间条件。[构造与归一化规则](../../game/data/core/composition_rules.json)
4. 转译按 Core 的字段组合查 `projections`。方向的坐标系与轴值成对匹配。传播还要匹配操作、效果、材料和支点。案例编号仅用于找到基准数据。完成推导后，再与样例的 Core、Trace 及配对预期比对。案例名、中文说明、旧执行 ID 和样例的 `lowering.binding` 均未用作上述字段的推导输入。[转译规则](../../game/data/lowering/semantic_bindings.json)

## 引力向下与向上 · L05

两次均以瞄准点为中心建立有限径向域。持咒时，持续供给与有余容的储备共同授权随时间积蓄。松手时，爆发交付已经积下的部分。测试只改 `/graph/2/intents/0/direction/axis`。例中的径向布局是构筑选择；其他有限域可以另选空间组织。[输入和参考 Core](../../game/data/examples/law_core_cases.json)

| 观察字段 | 向下 | 向上 |
|---|---|---|
| 输入方向 | `world / down` | `world / up` |
| Core 交付 | `Drive · short_impulse · world/down` | `Drive · short_impulse · world/up` |
| 执行方向 | `WORLD_AXIS / DOWN` | `WORLD_AXIS / UP` |
| 两次共有的执行字段 | `REGION / RADIAL_SPHERE`、`TRANSFER`、`VELOCITY_IMPULSE / INSTANT_BURST` | 同左 |

逐字段差分只落在 Core 和执行方向的轴值上。两次的施法事件、义项、现场条件、储备过程和短时交付方式相同。用向量提供的相同测试数值补全两项操作后，`OpTransfer` 和 `OpDriveImpulse` 均通过执行 0.2.2 的 Schema。

## 水网完整与断开 · M009

构筑选择以支点为锚的连续交织路径。松手时对同一份材料原位转固，保留质量、位置、动量和已有拓扑。转译得到 `BRANCH_WEB` 和 `PATH_CONNECTIVITY / LIVE_CONNECTIVITY`。传播起点解析为这份材料上的实际支点接触段。当前沿抵达一段时，读取此刻仍连续的材料边。[输入和参考 Core](../../game/data/examples/water_core_cases.json)

现场有六段液态水。起点 `root` 连到分叉 `fork`。左支通往 `left`，右支经 `bridge` 到 `tip`。另有一段 `loose` 与左支相碰，左支也与右支相碰。两处接触均没有建立材料连接。测试边各长 1 米，前沿每秒走 1 米，最远 6 米、最多 6 跳，衰减取零。在第 4 秒读取结果。

| 唯一现场差分 | 已冻结 | 仍为液态 |
|---|---|---|
| `fork—bridge` 连续 | root、fork、left、bridge、tip | loose |
| `fork—bridge` 断开 | root、fork、left | bridge、tip、loose |

两次使用相同的语义图、Core 字段和执行指令。完整、断开两种现场均通过集合比对。还检查了三个边界。缺起点返回 `MISSING_BINDING`，对应本次凝固的费用策略为 `ABORT_NO_COST`。传播已开始、前沿从 fork 出发前再断边，仍只冻三段。松手前打断，撤去主动牵引，冻结集合为空。测试传播参数填入后，`OpTransform` 及其 `PropagationSpec` 通过执行 Schema。此前取水和塑形的成本按原契约保留。

## 词义覆盖与下一阶段

13 个参考构筑的已登记词项按输入重选义项，核对 Core 空间与过程投影以及现场条件。另有 14 条短输入，覆盖参考构筑缺少的义项和容易混淆的前提。例如，同是「水＋凝固」，以概念为对象得到冰的构成，以现场实体为对象得到相变并留下材料在场条件；单给驱动供给和阻隔、没有已有推进，不能授权穿透。两种合法联结端点同时可用时保留歧义。首批 24 词共有 32 个义项，M009 另用「汇聚」一义，合计 33 个均有正向输入。[词义对照输入](../../game/data/tests/semantic/operand_witnesses.json)

阶段 A 取得的是声明式规则和固定场景的复算证据。阶段 B 须从输入图独立生成**整份** Core、CompileTrace 与执行产物，对未见构筑检查引用、冲突、能力和预算，并接回 21 条工程反例。M017、M020 的封存等剩余义项仍以人工参考为准。引力实际位移在阶段 C 测量，水网的断裂、传播、承重和视听同步在阶段 D 实机验收。[施工计划](../06_Magic_Runtime_三波次实施与验收计划.md)
