# 从符文图到配方 · 构思、取舍与法坛读解

符文给出要保留的意向和相互关系，选择本性、对象来源、有限范围、动作与责任是构思的一部分。到法坛确认时，这些选择必须已经落到一份可独立解释的配方中。将大量意象组织起来的能力，来自同一套词能指向不同的真实对象、作用与时机。

## 符文的落点

| 输入字 | 在本稿中可以要求什么 | 作者须指出的证据 |
|---|---|---|
| 土、水、气、火 | 指材料、介质、热过程或可分离性质 | 借石查现场来源，凝水有材料账，空气传力经有限域，抽热有热汇。知识中的火不会自动让现场燃烧 |
| 光、电、重力 | 指显明/遮蔽、电荷传递或局部有向加速度 | 有光路及观察者、供电/回路、场域及受质量作用的对象。同一片区域的三个查询可不同 |
| 空 | 可锚定参照、距离、内外、朝向或界面 | 位姿采样时刻、范围、越界规则；要求穿越相隔位置时须有独立空间通行接口 |
| 以太 | 主动指向异常关系、寄托、封存或干涉其他作用 | 外术引用、可干涉边、有限端点及责任。普通施法已含媒介作用 |
| 时、生 | 本体预留局部过程速率、活体组织与资源更新 | 目前 20 词总盘中的延后词。倒转已发生历史属世界不许可；生长石阶只证明几何改变，不能兑现活体生长锚 |
| 聚、散 | 可指材料聚散、储备累积、作用在空间或时间上的分布 | 实有份额、储备实付曲线、域与分布，指出哪种量变得更集中或更分散 |
| 引、联 | 给对象一个方向，或在端点间建立具体通道 | 带参照的受力/运动目标，或能说明传什么、向谁传、何时断的边。连接同组符文在玩家输入层还可仅表示语义组织 |
| 分、逆 | 可分开份额、解除支撑、脱离父参照，或逆转某项已指明作用 | 指出被分的是物、关系还是控制；逆的是方向、相态、传递或作用符号。施法不能借“逆”免费收回已散失的热 |
| 藏、应、守 | 有限寄托、接受实际事件、对某种变化作出防护或警示 | 账户与接收者、传感来源与交付时刻、实际被保护的性质。承担落石、遮住目击、报告越线各有不同证据 |

## 一次可审阅的构思

**意向**为「把光附在刃上，挥出时分出一道仍会向前行的弧」。在输入图 `{光,联}→引▷分` 中，若把「分」解成让整把剑碎裂，虽有同一字面，却丢失挥剑后还能继续持剑的核心预期。因而作者将「联」落在 `edge→weapon` 的 live 参照，将「引」落在扫掠与离手方向，将「分」落在 `pose_release` 的派生与脱离。碰撞造成推力属于对这条力学版本的补全，须明写并付费。若玩家指定仅有可见残光，须另选光学配方，不能再保留推力。[C2 配方](classic.md)

法坛可据实读为「刃面随武器挥动。交付帧从当前剑锋分出一次向前的弧，先碰到物体就在该处推一次。之后转身只会带动手中的武器。」如果去掉 `detach` 而读解依旧承诺弧已独立，即使语法能解析，这个编译结果也应被拒收。

**相同输入的不同锚点。** 守窗口的图可以把「守」落在降低透过率，或把它落在光束受扰后的报告。两份候选的形色可以完全相同。确定性读解应分别回答「外面的人还能看清吗」和「里面的人能得知什么」。把亮度稍改一次没有产生新的保护机制，不能拿来占用备选锚点。[O3 同图替换](original.md)

## 新构筑怎么检验

先写玩家能预测的那一句，再逐词找本性、对象和过程见证。然后由另一名读者在给定现场换掉一个条件：拿走付款器物、移走水源、转身、切断边，或只保留同一外形。能从同一组接口推出新后果才算语言有表达力。若必须由作者再口头补一个隐藏前提，记录它属于世界现场、合理缺省、新的通用能力，还是需要退回的语义跳跃。

真实世界用途可以超出原锚。托住石板的有限力也可运灯、送材料或暂托另一道冰阶；它的资格是物体质量、受力通道、负荷和供给。让同一个配方只对「运灯任务」特判会消掉这种复用空间。默认生成的顺畅度、构筑者满意度以及非预设世界用途是否频繁出现，需要后续人的盲测及真实交互才能判断。

## 局部谱段的写法

`fragment 名(端口:模式 类型,…) { C/S/R/P/K/X … } exposes(端口…)` 是作者给一段配方取局部名的写法。`use 名 as 别名(形参=实参)` 做词法内联；`each 集合 use …` 在有界集合中逐个绑定；`group` 可嵌套另一段或艺术组。配方入口、外部时限、账户上限从调用处取得。组合不能递归，深度、最大实例和同时活动分支均可从声明计算。所有自由引用须由形参或词法父级给出。暴露的输出仅含声明的权利，私有键不能从外部拼字符串访问。

| 端口模式 | 消费与组合 |
|---|---|
| read T | 共享快照。观察、参照与几何取样不能移动 T。 |
| write T | 独占有界操控权，借出至子段结束或显式交接。并行两写在展开时拒绝。力学通道可各自申请独立作用。 |
| move T | 转交一次真实份额或句柄及归还责任；源端随提交失效。 |
| spend Q | 有量纲的有限账户份。并行操作先分份；按实付扣取，退款或耗散依 K。 |
| event E | 带源、代际、序号、位置及允许负载的只读通知。同一消费点对一次回执只触发一次。 |

一个段可有多入口事件，但须有唯一初始 P。`a ▷ b` 把 a 成功提交后的暴露端口交 b；失败走显式失败边或归还退出。`fork/join/each/repeat` 遵循 B1。两个并行分支处理同一事件时，先做各自资格和份额裁决，后广播已提交回执。`use` 不隐式拉起重复入口。成员在建术快照选定，后来出现的同类物不自动补位；持续监听须另写有界查询与新代际。亡失成员的局部写权撤销，已交付效果继续有效。

`replace 实例.字段 = 值` 在作者版本上换一个同类型值；`add/drop` 修改声明及其依赖。改完须重新展开整份配方。换媒介需要自带成立依据，换实物为视觉引用不能继续满足 write。变奏按基准和逐项差分读成独立、完整的配方。冲突定义、未处理的悬空端口或更窄时限包不住的尾项都应在读谱时指出。

### 一段悬托，两种组法

以下源段既能用于离散阵列，也能作为有材料路径的活动端点。`active`、`ready`、`detached`、`contact`、`end` 都有各自的提交时刻。就绪指实际位置达到目标的公差，而过程的 `on ready` 仍沿用 D1 的进入成功含义。

```text
fragment member(piece:write Body, site:read Pose, q:spend ImpulseCredit,
                guide:spend ControlCredit, trigger:event Release, base:read ReactionPort) {
  C 有质量的借物；有限牵引与反冲
  S b = piece
  R tether = control(site,b,reaction=base) ; out = force(base,b)
  K owner(b,hold); bounds(tether,2m/s,collision=truncate); bounds(out,along=site.forward)
  P hold <3s,guide> : tick Drive.motion(b,guided_drift,site)
    | on trigger if near(b,site,0.1m) -> [Transform.detach(b),Transfer.deliver(q,out)] flight
  P flight <2s,world> : tick Drive.motion(b,ballistic,world) | on timeout -> [Transform.handoff_world(b)] end
  X edge @real(b) : visual=real_contour(slate); start=enter(hold); stop=exit(hold)
  X line @local(detached.position) : visual=sweep(strip(2cm),history(b,4),+Y);
      start=commit(detach,b); stop=first(contact(b),exit(flight)); tail=0.12s
} exposes(b:read Body,detached:event Detach,contact:event Contact,end:event End)
S stones = borrow(stone,select(loose_stone,within=3m,up_to=3,order=distance_key))
K common = capture(aim); ground_contact=resolve(reaction,at=caster,policy=contact)
K targets = arrange(stones,at(sample(arc(+Y,2m,120deg),3),common),orientation=tangent)
K launch_credit=quote(caster,impulse,medium,once); guide_credit=quote(caster,control,medium,3s)
K grants = apportion(launch_credit,stones,equal); upkeep = apportion(guide_credit,stones,equal)
each stones use member as m(piece=self,site=targets[self],q=grants[self],guide=upkeep[self],
                            trigger=release_for(self),base=ground_contact)
```

`release_for` 是 B 的受权选择与派发事件：整阵释放同时向所有已占槽广播；点选则只发给已选键。无效目标或未到位时不消费发射份，在 hold 内可重新输入，直至最长时限。自然飞行仅观察惯性和接触，world 不支付导引。尾迹存最多四个实际样本；停止后冻结，不能推断下一位置。线性账户按额定冲量与反力报价，不是玩家填写蓝耗。

另一种组法把两个独立受控物装在一个作者作用域里。

```text
fragment pair(a:write Body,b:write Body,sites:read Pose[2],g:spend ControlCredit[2],
              q:spend ImpulseCredit[2],go:event Release[2],base:read ReactionPort) {
  use member as l(piece=a,site=sites[0],guide=g[0],q=q[0],trigger=go[0],base=base)
  use member as r(piece=b,site=sites[1],guide=g[1],q=q[1],trigger=go[1],base=base)
  X visual seam @local(base)=between(real(l.b),real(r.b))/etch/still;
    start=both_established(l.b,r.b); stop=first(l.end,r.end,l.b.lost,r.b.lost)
} exposes(l.b:read Body,r.b:read Body,seam:read Visual)
```

父段没有另写调度时，并行启动两个有入口的子段，各自结清后父段退出。l 退出时 seam 停止，r 仍可继续。将 seam 另接 `S conduit=derived(water,path,…); R flow=hydraulic(l.b,r.b,via=conduit)` 并沿 A7 截面实际充水后，流量才可过两端之间。断开的水留在实际位置；两种用法都无权再借第二遍石。实例、事件与账目展开见 [D6](D-resolution.md#d6)，另有[四组可实际换件的构筑](corpus/recombinations.md)。
