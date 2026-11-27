# 拓展原题 02–09 · 重组、驾驭与物质流转

第 01、03 题的独立全谱与分步对照在[重点组合](focus.md)。 [共用语义](semantics.md) · [题目索引](README.md)

<a id="t02"></a>

## T02 · 牵引＋塑形＋联结

从散落废石取得同一批构件，持续改排为阶梯、桥或障壁，并在实际落座后交还。

**现场与锚定**　`土→引▷{聚,联}`。四个有匹配榫口的石件，现场有地坪、分开的桥墩。可在移动时切换三种排布。

```text
C 石,有限刚体,机械接缝
S blocks = borrow(stone,exact(group(nearby(cut_stone,4m),4),4))
K style = bind(set,input(layout),layout_choice,blocks,enum(steps,bridge,wall))
K seats = layout_targets(blocks,style,aim,steps=grid(4,1,(0.7,0.35,0),(0,0,0),up),bridge=grid(4,1,(0.7,0,0),(0,0,0),up),wall=grid(2,2,(0.7,0,0),(0,0.7,0),forward))
R links = support(adjacent(blocks),slot(foundations))
P set <8s,caster> : tick Drive.motion(blocks,guided_drift,seats) | when changed(input(fasten)) => Couple.link(links) | when changed(input(unfasten)) => Couple.unlink(links) | on release -> [Transform.handoff_world(blocks)] end
X set.hero @blocks.realized = array/slate/advance <- velocity + rumble
X set.secondary @blocks.realized = skin/slate/strain <- load
```

**正例**　由阶梯改为桥时，四个原键逐步移动。只有榫口到位并实际接到墩的边在确认时锁合，松手后世界沿这些边承载。换成墙改变排列、朝向和支点。

**反例**　只撤掉远墩，视觉仍可见石排成线，松手后超出近端承重的构件坠落。先前锁住的边要在再次改排前实际松脱或被负荷破开。

<a id="t04"></a>

## T04 · 飞行＋承载＋追随

让同一平台承载角色、物体与另一项术的实体追随瞄点移动。乘员可滑落、跳下或改变总负荷。

**现场与锚定**　`{气,引}→{土,守}`。石板、空气与上方净空，原载荷小于升力。三个乘员均有真实接触。

```text
C 空气传力,重力,接触承载
S raft = borrow(stone,slot(slab))
S air = manifest(air,column(1m,1m,1m),live(raft))
R lift = force(air,raft,via=slot(ambientAir))
R deck = support(raft,contacts(raft))
K steer = bind(carry,aim,desired_position,raft,1m/s)
P carry <6s,caster> : tick independent(Drive.field(lift,v(0,0,1)),Drive.motion(raft,guided_drift,aim),Constrain.support(deck)) | on release -> [Transform.handoff_world(raft)] end
X carry.hero @raft.realized = mass/slate/advance <- velocity
X carry.secondary @raft.realized = skin/etch/strain <- load + rumble
```

**正例**　角色站稳、箱子摩擦足够、一个外术实体也站在板上，三者随真实接触运动，外术所有权不变。角色跳下后板负荷减小，失去接触的角色按自身惯性飞行。

**反例**　只将目标瞄到薄墙后，平台不能瞬移穿墙，松放在板上的箱可滑落。只在板上加重到升力不足时高度下降，不能以“跟随”补齐位移。

<a id="t05"></a>

## T05 · 武器＋赋形＋分离

在挥击过程中为真实武器延展形态，临近交付把已长成的外缘分离，原武器仍握在手里。

**现场与锚定**　`{土,联}→引▷分`。短柄有可承载的镶槽，现场有限薄石片。与 J03 的冷光弧不同，此处交付的是有质量的外缘。

```text
C 薄石,带料变形,动作参照
S supply = borrow(stone,slot(flakes))
S rim = derived(supply,patch(2,0.8m,0.12m,40deg),live(weapon))
R swing = support(weapon,rim)
R kick = force(caster,rim)
P shape <1s,caster> : tick Transform.grow(rim,extent,1m/s,truncate,supply),Constrain.support(swing) | on pose_release if at_least(growth(rim),0.5) -> [Withdraw.close(swing),Transform.detach(rim),Drive.impulse(kick,forward)] fly
P fly <2s,caster> : tick Drive.motion(rim,ballistic,world) | on contact(rim) -> [Transform.handoff_world(rim)] end
X shape.hero @rim.front = skin/slate/advance <- growth + brace
X fly.hero @rim.realized = ribbon/slate/shed <- velocity ~0.15s
```

**正例**　外缘随挥击长到 0.6 m，真实动作交付时继承剑锋线速度。柄随人转向，离柄石片撞墙、落地，后续可拾回先前扣除的那份材料。

**反例**　只让动作提前到 0.2 m 时交付，未达最低成形比，不会凭空生成完整石弧。允许离刃的量上限永远是实际已建量。

<a id="t06"></a>

## T06 · 聚合＋分裂＋重组

聚拢多个已有实体为一体，受击只分离实际断开的部分，玩家能继续控制剩余部分并重组。

**现场与锚定**　`{土,聚,联}▷分▷联`。四块编号 a–d，各 1 kg，线性接触；握持端 a 可对其承力连通分量施控。

```text
C 实体集合,有限接缝,份额身份
S units = borrow(stone,exact(group(nearby(cut_stone,3m),4),4))
K row = formation(units,4,line,simultaneous,0.4m)
R joints = support(adjacent(units),natural_seams)
K root = component(units,part(units,a),support)
K pick = selected(outside(units,root),input(recover))
P gather <3s,caster> : tick Drive.motion(units,guided_drift,home(row)) | on changed(input(fasten)) -> [Couple.link(joints)] wield
P wield <5s,caster> : tick independent(Drive.motion(root,guided_drift,aim),Drive.motion(pick,guided_drift,home(row))) | when changed(input(fasten)) => Couple.link(joints) | on release -> [Transform.handoff_world(units)] end
X gather.hero @units.realized = array/slate/gather <- velocity
X wield.secondary @units.realized = skin/etch/strain <- load + crack
```

**正例**　击裂 c–d 接缝，root 下一步只含 a,b,c，玩家改向能驱动 3 kg。d 保有原键并独立落下。显式选回 d，受限牵引使两端接实后重扣，根分量回到 4 kg。

**反例**　只把 d 留在墙后，回收可以提出目标，接缝容差未满足，重扣失败。剩余三个仍可控制，总量没有增为五块。

<a id="t07"></a>

## T07 · 防护＋吸收＋释放

接住坠物，回收其中确实可转换的功，再把它用于推动另一物体。

**现场与锚定**　`守→藏▷引`。固定盘、落物、可受力滑车和有方向转换接口的绞轮。储能宿主与施法者分开。

```text
C 约束反力,可回收功,有限转换
S pan = borrow(solid,slot(tray))
S cart = ref(slot(cart))
R stop = support(slot(pillar),pan)
R receive = force(slot(fallingBody),pan,via=stop)
R give = force(slot(winch),cart,via=slot(rope))
K k = store(kinetic,pan,medium)
P guard <5s,caster> : tick Constrain.support(stop),Transfer.capture(receive,k) | on release -> [Transfer.deliver(k,give)] end
X guard.hero @pan.realized = skin/slate/strain <- load + rumble
X guard.secondary @pan.realized = core/etch/gather <- fill + breath
```

**正例**　一次真实落物接触并被盘承住。若实收 2 J 与可换向 2 N·s，对静止 2 kg 车只交 2 N·s，车获 1 J 动能。方向差与反冲由仍固定的绞轮和支点承担。

**反例**　只撤去落物，站立维系不会给 k 充值，松手后车保持原速。只切断绳路，已收余额不能跨断口交付。

<a id="t08"></a>

## T08 · 吸纳＋封存＋输送

从环境取实际内容到器物，封存并搬运，到目的地再输送。用同一器物并列储水与储热检验单位。

**现场与锚定**　`{水,火}→藏▷引`。器物有容水 2 kg 和隔热储层 100 J，可搬走。初态两槽为空，源为水池与暖石，目的地有壶与冷石。

```text
C 质量,热量,有限器物
S vessel = borrow(solid,slot(flask))
K water = store(material,vessel,2kg)
K heat = store(thermal,vessel,100J)
K keeper = store(mana,vessel,small)
R inW = material(slot(pool),water)
R inH = thermal(slot(warmRock),heat)
R outW = material(water,slot(jar))
R outH = thermal(heat,slot(coldRock))
P take <3s,caster> : enter Transfer.move(caster,keeper,all) | tick independent(Transfer.route(inW,1kg/s),Transfer.route(inH,50J/s)) | on release -> [Transfer.handoff(vessel,keeper)] sealed
P sealed <5s,keeper> : on contact(vessel,slot(dock)) -> drain
P drain <3s,keeper> : tick independent(Transfer.route(outW,1kg/s),Transfer.route(outH,50J/s))
X take.hero @vessel.realized = mass/water/gather <- fill(water)
X drain.secondary @vessel.realized = ribbon/ember/fade <- fill(heat)
```

**正例**　取两秒，池减 2 kg，暖石减 100 J。盖好后由器物的 keeper 支付有限等候期，主人可放手。本例该时段的自然泄漏可忽略，触及目的地才分开向壶和冷石输送，最终两槽为空。

**反例**　只预填壶至满，水仍留器物，冷石可接收热；热余额不能当作水补进壶。器物中途破裂时已借水与存热按现场泄漏/散热结清。

<a id="t09"></a>

## T09 · 导流＋传导＋相变

把同一真实水路用于输水与通电；局部冻结和断裂分别改变通路。

**现场与锚定**　`{水,引,联}→电▷逆`。三段含导电介质的水带 a→b→c。给定材料表中液态导电、固态电导低于灯阈值，另有可闭合的铜旁路。

```text
C 液态输送,电回路,局部相变
S g = borrow(water,slot(waterGraph))
R stream = material(slot(source),slot(jar),via=g)
R current = electric(slot(cell),slot(lamp),via=slot(parallelNetwork))
P run <6s,caster> : tick independent(Transfer.route(stream,0.2kg/s),Drive.charge(current)) | when changed(input(freeze_part)) => Transform.phase(selected(g,input(freeze_part)),solid,slot(coldStone)) | on release -> end
X run.hero @g.realized = ribbon/water/advance <- velocity
X run.secondary @g.front = skin/crystal/gather <- growth + ring
```

**正例**　前两秒向壶送入 0.4 kg，灯在闭合水路上亮。冻结 b 提交后，后续液流不再过 b，下一电传播步按新电导结算。在铜旁路初始断开的现场，灯随之熄灭。

**反例**　只把现场铜旁路闭合，冻结后水仍不通，灯却继续亮。只在冻结前断 b–c，两种沿水路径都失效，已送入壶的 0.4 kg 仍在。
