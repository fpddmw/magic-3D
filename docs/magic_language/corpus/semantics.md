# 38 份谱的兼容读法

[空间与构形](../A-space.md) · [局部控制、守恒和领域合同](../B-world.md) · [舞台](../C-stage.md) · [解析与时序](../D-resolution.md)。六面简记继续可读。尺寸和槽名是原题现场实参。

## 旧六面简记

沿用 C/S/R/P/K/X 六面。写 `slot(name)` 的地方，现场只提供有类型的物、几何、器件、资源或实际输入。例如“承台”可提供接触和强度，“哨铃”可接收信号；现场不能提供“敌人已被拦住”一类预制结论。符文图和自然语言锚在配方前。词提供意向，知识与世界条件补全具体机构。时、生及高阶空间的配方只用于推演相应权限开放后的世界。

- `P p <4s,caster>` 为 4 秒世界时硬顶，唯一入口默认为第一段。没有 K 时按 D1 缺省契约；施法者不再持咒且没有寄托后继，维系作用结束。`on event -> [actions] next` 消费一次事件并换段。`when event => actions` 在当前过程内订阅并留在原段，只处理新事件；以过程、源事件、接触对去重。`when` 也受本步最高优先终止事件约束。定次重复、阵列展开和事件队列各受版本硬顶；同一物体保持接触不反复触发 enter_contact。
- `tick A,B` 是一组必需操作，依 D 事务结算。`tick independent(A,B,...)` 使各项有独立责任与失败结果，仍共享总预算；其中用 [A,B] 指定一组须一起提交的动作。多槽可以订阅同一次玩家松手输入，各槽分别检查自己的过程与余额；共享转移权益仍只能消费一次。`when e if guard => …` 接收已有事件，guard 使用 B5。`end / abort` 关闭局部作用，真实材料、动量、热、损伤照常归还。有限场失主默认撤销。契约到期不会自动追加最后一次交付。
- `group(selector,n)` 按距离、稳定键选至多 n 个不同实物；`exact(group,n)` 数量不足整组失败。借用集合时逐个取得合法用权。`each(g)` 只展开有限成员，以 `self` 称本槽，后继保留槽身份；一个成员的失败仅结清自己的过程。`per_member(g,store(...))` 逐槽分账。`formation` 可展开待具现的原型；对于已经借到的集合只分配目标位置，不生成副本。`layout(line/arc/ring/steps/wall/bridge,spacing)` 表达沿线、平面、带高度差的有限目标位姿，实物要用运动和接触才能到达。
- `event.subject / event.part / event.vector` 只在对应签名的事件处理中读取；`sensed(self)`、`hit(self)` 同理。`input(name)` 是预先公开的控制量，可取位置、姿态、一枚活成员/段、枚举或确认边沿，不能传入新过程。`selected(g,input)` 返回范围内可选的稳定成员或空。`pulse(k,dt)` 最多 k 次，第一拍在 dt。`changed(input)` 只在离散选择变化时发一次。`formed(s) / joined(r) / arrived(s) / crossed(pair)` 分别由真实成形、连边、到位和边界穿越提交。`on ready` 只表示入段事务完成。事件的本步世界提交最早供下步逻辑消费。
- `K … = bounds(…)` 给速率、单次量、最大工作量与范围加物理上限；`K … = basis(受体,条件,付款端)` 是局部赋性/供给合同，随所列责任退出。`K … = bind(process,input,drives,target,limit)` 只更改目标/驱动值。关系 `via` 指实际通路，`basis` 指异常性质的成立依据。预算先为整个配方按档报价，再沿实际同时对象分配。满度、分布和颜色都不能额外放大已实付总作用。
- 每谱至少有一条 X。`X all.…` 可跨阶段，世界读数或事件缺失时对应轨不显示。光学形象可影响世界观察仅当另有有效光学通道；声音提示可影响场内听者仅当另有真实声源。危险边界、触点与相变锋面均用已实现几何。未特别说明时，其他声画模块采用 C 的有限默认；角色姿态和音乐不能凭表现轨生成世界事件。

## 已有构造的展开索引

下表补齐谱里省去的展开步骤。词表描述世界数据类型与有限变换；案例编号、标题和场景美术不可作能力分派键。

| 声明或读数 | 唯一含义 |
|---|---|
| `reference(g,ref)`、`home(g[,member])` | 为组指定共同的布局坐标系，读取该槽目标位姿。具现原型默认其声明的父参照，借物默认首次捕获施法者坐标系。借物的 formation 分配目标位姿，还要显式运动才能到达 |
| `topology(s,n,serial)`、`topology(s,anchors,branched)` | 有序 n 个材料单元、相邻边及稳定的份额槽；标为 branched 时以实际有限支点构成接缝。初次等截面等长填充按各段容积等比分份。字母和数字索引都指现场已标定的稳定键。几何相邻不给予额外导通 |
| `initial(s,dimension,q)`、`growth_material(s,src,phase,sink,n)` | 前者指定初始已实现尺度（其余材料仍有去处，例如支点处待展开的一团纤维）。后者给 grow 声明先取材、满足相变潜热、再形成至多 n 个有接缝的可碰撞单元的原子合同。自然碎裂和可抓取属性取自材料与段质量 |
| `bounds(r,…)`、`envelope(r,readout,curve)` | 按关系类型限定方向、几何、速率、阈值、单包量或同一额的分布。envelope 以裁到 [0,1] 的只读值缩放本项最大交付。它只能缩减允许的额度。采样 fill 的初始几何与目标几何分别是 0 和 1 两个端点 |
| `choice / poses / layout_targets / layout` | choice 只保存有限枚举，分支行为全部写在 by 里。poses 把作者给的枚举映射到局部位姿，以 pitch 指定实际倾角。layout_targets 从所选 grid 的行列数、两个以米计的步进向量及成员法向生成有限目标。steps、wall、bridge 等是该配方的局部输入标签，改名并同步修改引用不影响世界行为。用 cast 取建术时选择，用 bind 则保留玩家选择。radial_steps 用稳定槽序绕轴等分方位，距中心从内向外等分到锁定外半径。J06 在付费蓄力后取 1–4 m 的外半径，放手先锁值再分账。scheduled(member,dt) 在本组共同派发边界后按槽序 0、dt、2dt 各一次；第 0 槽在首个可消费边界派发 |
| `by(key,枚举:[操作],…)`、`independent`、`repeat` | by 只展开当前枚举对应的有界操作组，所有可能枚举在准入前有定义。repeat 的次数预算跨整个局部过程，只消费一次同序号的拍点。无副作用的查询可在各组共读；bind 的控制量来自已声明输入，初始取场景明确的选择或枚举首项 |
| `approaches / visible_points / goal / waypoint` | approaches 用运动样本预测与所选端点可能相交的对象。它同样能选择快进站的货车或正在漂近的载物板，不依赖敌我标签。visible_points 是各成员在自己的可观测域看到的工作点清单；match 在可行边上综合这些局部可见性而不向成员披露隐藏目标。goal 优先返回已获权的人工目标，再取匹配目标，再回 home。导航不能虚构一条穿墙通路 |
| `contacts / crossings / first_contact / adjacent / nearby` | 实际接触端集合、与域相交的有限路径、从实际落点沿指定方向有限长度的首个接触、相邻接缝端和半径内合格实体。空集不会取得任何作用。air_gap 是射程内可击穿的实际介质，导电传播还要有回路。aim_upward 为瞄准方向上仰的有界投射，toward(sensed(self)) 锁定本槽有效感应时的真实朝向 |
| `eligible(g,phase,leash) / solid_parts / outside(g,subset)` | 分别是相态与控制可达性的交集、固态段、剩余成员。空集产生零持续作用。selected 的连续输入保持玩家选取的稳定键直到改选、失效或撤术。选择器本身不转移写权 |
| `relative(pivot,aim)`、`control(…,via=graph)` | 在每个有权驱动的分量上，保留已扣合的边界点并引导其余可动点。源相连液态分量以进水端为根，断开流路但控制仍可达的分量以接实的最近固段为局部根；同距按稳定键。固段若未扣在支点上，只提供其实际可动位姿。control 边独立付费，依附段的几何与完整性，局部固化不会令其自动绝缘 |
| `natural(s,r,contact,material_strength)`、`Couple.unlink(r)` | 前者声明现有材料在持续自然条件下有黏附/柔性等属性，离术后由接触与材料强度承担。后者主动解除当前有权、可达、允许拆装的连接，仍有负荷时先结算脱开反力。已经固结的自然接缝需通过有限碎裂或补料修复 |
| `Transfer.apportion(k,child,g)`、`residual(r)` | 在一次提交中从 k 扣实际总额，按稳定槽位等份记入各独立 child，容量不足的余款仍在 k。可转换的电交付先扣可用功，只将首接触结算后尚在该节点的实际电荷/电功沿支路输送；residual 是一次可消费余额。无首接触则为零。方向/能量转换的反力、回流与损耗查 B3 |
| `ports(…,initial=…,transit=…)`、`active`、`packet` | 一组互斥的通路、当前出边和一次性整包。体积单位仅对密度已知的材料换算质量。瞬时整包在源、带宽或接收端预留不足时整体失败。持续路由则按实际可达额度部分交付。显式有行程的包占用在途账；关闭施法时只清理尚未发出的指令 |
| `clock_of(p)`、`local_after(t)` | 暴露一个明确同意外部调速的局部过程端，后者在该过程实际积分首次达到 t 时发一次。世界硬顶相同时间到达时按 D 先处理超时。寄托账户即使还有余额也不能超过该硬顶 |
| `gaze_event / pose_sample / turn_to_sample` | 第一项是获授权且光学互见的观察端给出的一次注视边沿与来向，不读取隐藏认知；后两项为有限姿态图样及朝向该观测来向的姿态。事件改变一个显示采样窗口，此后恢复跟随。双端采样/订阅只有在登记的传感器、权限与付款端同时有效时建立 |
| `gain / transmission / velocity / growth / fill / load / impact / signal` | 演出按 C 的提交后读数取样。速度可读物体或已实现介质流速；front 可读物质分布前沿，增长读数可取已实现形态/目标之比。写明 fill(k) 优先于推导；显示没有真实数据时该轨不产生读数 |

**跨过程句柄。** 每个谱的入段惰性建立只解析该段实际要用的资源。全谱声明的后续 borrow 不会在上一步提前占走物权。每个 K 的 owner 是保管者，P 的 payer 支付本段动作；持有器物自身的有限槽可成为接责端。fork 中未指定共享写权时，按唯一消耗方转交：例如时率题的物料槽只交给 ripen，watch 只取得 clock_of 的有限干预权。宿主毁坏时材料槽内实物原位泄落或交给残存容器，储热结清到环境，纯奥术储备依契约耗散。

**同时刻的增补次序。** 先结清旧区间，在新边界处理打断、到期和玩家离场，再处理手动成员/路径选择及端口切换，然后再为自动任务预留。受影响的旧代际申请作废。在同一提交中，必需事务写同一状态的操作按声明次序使用本地暂存值；其他过程只读取旧提交。形态或权限在提交时变化后，下步任何持续控制都要重新校验受体。临界接触可在同一日志中同时有真实物理冲量与另付费的魔法作用，二者须分来源，不能重复消费同一碰撞。

**阵列与传感的两个实参。** `orbit_phase(g,rate)` 只推进空闲布局的角相位；赶赴任务的成员离开各自原环位，人工目标优先。它改变可达性预测的初态，不能把实体直接摆到新位置。`transducer(subject,measure,threshold,format)` 为实际接触/介质登记有界传感器。以冲量为例，区段内一次实际扰动跨过阈值才生成边沿，回落复位。sector_event 取传感区段和时间，去重键属于传感器；原动作者的身份与坐标在投影成包时移除。采样缓冲每区只留最新的未发边沿，超过本格式一个采样周期或在链接断开时丢弃。因此积压小动作不会在恢复供给后泄露历史。

## 从旧词回到语言内核、构造库和领域能力

按在语句中的**签名**分类。例如 `material` 作 R 构造时是材料连通关系，作 select 谓词时读材料类型。以下为原谱调用和简写的归宿；领域目录供审阅，还未形成新机器注册表。

| 归宿 | 旧谱记号 | 规范读法 |
|---|---|---|
| 语言内核 | `ref borrow manifest derived slot input event each fork join independent repeat by owner store bind bounds basis enum choice` | 有类型来源、有限控制流、权利、容器与责任。slot 实例化现场端口；choice/enum/by 是有限标签的声明、选择与消去。 |
| 构造库 · 空间 | `body path patch sphere column cone capture live cast offset reference formation layout grid layout_targets poses pitch initial topology chain orbit_phase` | A 的基本形和采样/变换/排列。chain 额外申请 B 的承重端。orbit_phase 只推进目标位姿。 |
| 构造库 · 关系与控制 | `control material support arcane_support adhesion natural envelope per_member ports packet transducer relative basis` | 用端点建立带类型的边、介质、局部账户或传感绑定。basis 的声明是内核，具体惯性/承力依据来自已登记能力。 |
| 领域能力 | `force gravity magnetic electric thermal hydraulic optical acoustic information spatial temporal growth_material life growth match waypoint approaches` | B6 的签名给出实际世界或导航服务。growth 作生长关系构造时属于领域，作 X 进度时是读数。match 使用有界相交预测与到达成本；waypoint 要可行导航。 |
| 派生读数与可达集合 | `fill residual active ready support_of clock_of goal home pivot component part eligible solid_parts outside hit sensed first_contact visible_points initial` | 从有权读取的余额、图、事件、部位、初态或姿态取投影。residual 作为交付实参时仍只能消费一次。初态声明和读取初态签名可区分。 |
| 有类型的谓词和事件 | `at_least near contact contacts crossed crossings changed overload scheduled local_after signal proximity selected adjacent` | 数值阈值、真实接触或通知、资格筛选。scheduled 来自有限派发；selected 相当于从合格视图 pick。contact 的事件只在变化边沿出现。 |
| 旧选择/排布别名 | `nearby within group exact selected layout grid` | `group(nearby(T,r),n) → select(T,within=r,up_to=n,order=distance_key)`；外包 exact 替换数量策略。`within(s,T)` 是在 s 的真实通道域查询；`selected(g,input) → pick(g,input,key)`。grid/layout 由 A7 的有界行列、旋转、采样组合产生。 |
| 向量和身份投影 | `v toward along_velocity piece local_after packet store residual` | 三轴分量、边界时锁定的单位向量、实际速度方向、已提交分份键、局部时钟事件、有类型的整包/存放/剩余量。零速无投射方向。 |
| 提案中的派生数据 | `gaze_event pose_sample turn_to_sample pulse formed joined arrived release_for quote` | 来自受权观察、真实姿态、有限拍点、世界提交或版本报价；不得向读视图写事实。 |

七操作族仍由 B4 与本轮 B6 的渠道合同解释：Establish.open；Drive 的 motion/shape/field/impulse/gravity/heat/charge/optics/gain/emit；Constrain 的 bind/cut/lock/support/suppress；Transfer 的 move/apportion/split/deliver/route/capture/cross/handoff；Couple 的 link/unlink/relay/sample/switch；Transform 的 advance/detach/fracture/grow/handoff_world/phase/phase_path/repair；Withdraw.close。能力名组合不赋予无穷动作。将一套任务匹配、时率或水文能力从可用目录移除会产生明确的 capability_gap，其余配方仍按同一语法展开。
