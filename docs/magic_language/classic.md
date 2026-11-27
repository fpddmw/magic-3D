# 八种经典结构的编排与反事实

**历史初稿。** 保留第一次研究的构思与反事实。活动谱及本轮修订以[集中审阅入口](README.md)为准。

作者手写的八份独立配方，采用 [D1 六面简记](D-resolution.md)。取自原研究里的结构问题，题名仅供识别。每题先给玩家可以事前说出的期待，再给配方及推演。形状、材料工艺、速度与演出是作者补全。以下结果均为纸面预测。

## C1 · 守候剑阵，各自离阵

图 `{光,守}→应▷引`，对己留存。「守、应」锚定逐枚等待实际靠近的可见目标。「引」在触发后才交付朝向。三枚光棱围身，前方出现人影时只允许在各自感应半径 1 m 内且可见的成员发射。发射取确认目标当步的方向。

```text
C 光棱,以太维形,力学冲量
S blade = manifest(light,body(0.2m),live(caster))
K ring = formation(blade,3,arc,per_trigger,1.2m)
P prepare <1s,caster> : enter Establish.open(ring) | on ready -> watch
P watch each(ring) <5s,caster> : on proximity(self) -> [Transform.detach(self),Drive.impulse(shot,toward(sensed(self)))] fly
R shape = arcane_support(caster,self)
R shot = force(self,self,basis=shape)
P fly <1s,caster> : tick Drive.motion(self,ballistic,world) | on contact(self) -> [Drive.impulse(touch,along_velocity(self))] end
R touch = force(self,hit(self),basis=shape)
X watch.secondary @self.realized = mass/crystal/still <- progress + breath
X fly.hero @self.realized = ribbon/crystal/advance <- velocity + ring ~0.15s
```

一人只进入左棱感应范围，左棱触发，本槽进入 fly，其余两槽还在原位。左棱撞柱只给触点一笔有限交付，仍待发的两枚不会连射。撤去现场可见性则三枚都等到超时。若一次触发扣了三枚的预算或让右棱离阵，说明成员作用域丢失。

## C2 · 月刃离手，挥击与剑波分别交付

图 `{光,联}→引▷分`，对外瞬发。「联」指贴在现有武器上的扫掠，「分」指真实动作帧的独立派生。月牙推开所触物体，角色之后转身也不能改变它的航向。

```text
C 刃面光,奥术传力
S edge = manifest(light,patch(3,1.2m,0.12m,30deg),live(weapon))
S wave = derived(edge,patch(4,1.4m,0.1m,45deg),live(edge))
R edgeForm = arcane_support(caster,edge)
R waveForm = arcane_support(caster,wave)
R edgeHit = force(edge,hit(edge),basis=edgeForm)
R waveHit = force(wave,hit(wave),basis=waveForm)
P swing <1s,caster> : enter Establish.open(edge) | tick Drive.motion(edge,sweep_arc,weapon),Drive.impulse(edgeHit,forward) | on pose_release -> [Establish.open(wave),Transform.detach(wave),Drive.impulse(launch,forward)] travel
R launch = force(wave,wave,basis=waveForm)
P travel <1s,caster> : enter Withdraw.close(edge) | tick Drive.motion(wave,ballistic,world) | on contact(wave) -> [Drive.impulse(waveHit,forward)] end
X swing.hero @edge.realized = skin/crystal/advance <- velocity + breath
X travel.hero @wave.realized = skin/crystal/advance <- velocity + ring ~0.3s
X travel.director @wave.realized = none/none/still <- impact + echo ~0.5s
```

edgeForm 和 waveForm 分别承担有限弧面的位置、有效惯性和接触传力，预算同属各自的过程，普通光照没有这项能力。edgeHit 仅在真实扫掠初触时可交付，同次贴靠不会按每步重复冲击。离刃时 M 中的位姿和切向速度进入 wave。转身、甚至收剑只影响角色。墙在路上则碰墙，空挥只有离刃声。把 wave 的脱离与弹道改成持续随动，转身会带走远处的光弧，直接违反原锚。

## C3 · 柱形旋风，三个分量可独立改变

图 `{气,聚}→引`，对外维系。锚定向中心汇集、围轴回转且上升。现场空气成立，柱内放可受力探针。正切向取上轴叉乘外径向，柱东侧的正旋向朝 −Z。

```text
C 空气,力学
S f = manifest(air,column(2m,2m,5m),capture(aim))
R push = force(f,within(f,movable),via=slot(hallAir))
P wind <4s,caster> : tick Drive.field(push,v(-0.48,0.64,0.60)) | on release -> end
X wind.hero @f.boundary(force) = ribbon/mist/turn <- progress + rumble
X wind.secondary @f.realized = core/mist/gather <- progress[0.35..1]:ease_in
```

同一成品只把轴向置零，去掉直接上升；同一成品只改切向符号，翻转旋向。轴心只有轴向作用，域外无力。将捕获瞄点改为实时瞄点，空间中心变化独立于旋向。停术后已有动量保留。原版有限柱用均匀高度分布做过三组离线对照，实测数值只属于那份基线。[旧结果](../v0.3.1/最小语法与旋风对照.md)

## C4 · 从两端支撑的石桥

图 `{土,聚}▷联→守`，对世界留存。锚定就地取石、接成能承担负荷的结构。现场有碎石堆、3 m 缺口与两头支座。近端提供足够的悬臂刚度以维持建造，桥接触远端时才获得另一条承重路径。

```text
C 石料,抗弯支撑,质量守恒
S stock = borrow(stone,slot(rubble))
S deck = derived(stock,patch(3,3m,0.8m,0deg),capture(slot(leftPier)))
K frame = chain(deck,slot(piers),medium)
R brace = support(deck,frame)
P build <4s,caster> : enter Establish.open(deck) | tick Transform.grow(deck,extent,1m/s,truncate,stock),Constrain.support(brace) | on release -> [Transform.handoff_world(deck)] end
X build.hero @deck.front = skin/slate/advance <- growth + rumble
X build.secondary @deck.realized = skin/slate/strain <- load[0.65..1]:ease_in + crack
```

第 1 秒只有第一段可踩，第 3 秒在净空和材料充足时抵达对岸。撤去施法，已经咬合的石段靠自然支点继续受力。破坏中段后按两侧残留支点分别算，若左半超载、右半仍能承担，则只左半落下。提前搬空石堆使已成形段留在原位，前沿停止；视觉不能补全剩余桥面。

## C5 · 一轮共行的暗月，三个局部作用

图 `{{光,逆},{火,逆},{以太,分}→应}`，对外蓄势。第一组降低透过率，第二组把热移至现场热汇，末组响应进入范围的异常支撑并压制它。large，真实持续 4 s，可申请天象。三个域都依附正在移动的核心，热汇是独立条件。

```text
C 光学消光,抽热,以太支撑
S moon = manifest(aether,body(0.7m),capture(hand))
S veil = derived(moon,sphere(2m),live(moon))
S cold = derived(moon,sphere(1m),live(moon))
S seal = derived(moon,sphere(0.8m),live(moon))
K lead = owner(moon,glide)
R shade = optical(veil,within(veil,sightline))
R sink = thermal(within(cold,warm),slot(heatSink))
R mute = arcane_support(seal,support_of(within(seal,spell)))
P rise <4s,caster> : enter Establish.open(moon) | on timeout -> fork(glide,dim,cool,press)
P glide <3s,caster> : tick Drive.motion(moon,guided_drift,aim)
P dim <3s,caster> : tick Drive.optics(shade,0.25)
P cool <2s,caster> : tick Drive.heat(sink,forward)
P press <1s,caster> : tick Constrain.suppress(mute)
X rise.omen @moon.sky = horizon/dark/gather <- progress[0.55..1]:ease_in + breath
X dim.hero @veil.boundary(optical) = core/dark/advance <- transmission
X cool.secondary @cold.boundary(thermal) = skin/crystal/gather <- impact + breath
```

在 4 秒后核心起行。局部进入第 2 秒时压制已退、抽热仍可工作，第三秒只余光学与核心。热汇受阻时抽热链失效，光域仍移动并遮挡观察。压制消退不抹去此前生成的自然冰。远景压暗绝不改变作用半径。若另一术已有的冰因压制而被删除，或只有主核退场才能关掉抽热，设计失效。

## C6 · 静止蓄势，靠真实碰撞储力

图 `守→聚▷引`，锚定把已有物体锁在支点、积下外部撞击、松手交还。现场质量 2 kg 的空车静止在轨道上，地面可承受反力。

```text
C 运动,有限外功,反力
S cart = borrow(solid,slot(cart))
R stop = support(slot(railAnchor),cart)
R intake = force(slot(impacts),cart)
R out = force(slot(railAnchor),cart)
K k = store(kinetic,cart,medium)
P hold <4s,caster> : tick Constrain.lock(stop,rail_axis),Transfer.capture(intake,k) | on release -> [Withdraw.close(stop),Transfer.deliver(k,out),Transform.handoff_world(cart)] end
X hold.hero @cart.realized = mass/etch/strain <- fill + rumble
X hold.secondary @cart.realized = skin/etch/shed <- release + ring ~0.2s
```

设碰撞账已经回收同向 3 N·s 和 1 J，则最多交付 2 N·s，车速至多 1 m/s，其余冲量由锚承担。撤去撞击源，施法者仍需支付约束，松手交付为零。改成两次等额反向冲击，有向储备可为零。车原地、解锁、保持新动量三种状态均可区分。

## C7 · 穿过反魔法边界

图 `{以太,分}→守`，留在固定地点。锚定压制现场其他施法者维持悬浮的边。现场一块天然可存的冰由另一术悬浮，外术账户还有余额。压制容量大于这条悬浮关系的余量。

```text
C 以太支撑的有效容量
S zone = manifest(aether,sphere(2m),capture(aim))
R damp = arcane_support(zone,support_of(within(zone,spell)))
P suppress <4s,caster> : tick Constrain.suppress(damp) | on release -> end
X suppress.hero @zone.boundary(arcane_support) = skin/etch/still <- progress
X suppress.secondary @zone.realized = ribbon/dark/fade <- impact + breath ~0.2s
```

冰的悬浮边进入域，支撑跌到所需容量以下，世界从当前位姿对原冰体算下落。离域且外术仍有供给时可以重新受力；落地已经造成的缺角仍在。只把 suppress 改为 cut，原边成功断开后离域也不能复活，须由外术重建。把冰换成同质量自然落石则没有可压制边，落石照常运动。

## C8 · 逼近才分流的火核

图 `{火,聚}▷{应,散}`，对外留存。热与径向冲量由同一份积蓄分给两个受体接口。近距查询以火核为中心、半径 1 m、需可见，现场干木能吸热，有质量物体能接受冲量。

```text
C 热,空气传力,有限转换
S core = manifest(fire,sphere(1m),capture(hand))
K fuel = store(mana,core,medium)
R hot = thermal(core,within(core,warmable))
R shove = force(core,within(core,movable))
P charge <2s,caster> : enter Establish.open(core) | tick Transfer.move(caster,fuel,all) | on release if ready(fuel,0.2) -> approach
P approach <3s,caster> : tick Drive.motion(core,guided_drift,aim) | on proximity(core) -> [Transfer.split(fuel,hot@0.7,shove@0.3)] end
X charge.hero @core.realized = core/ember/gather <- fill + breath
X approach.hero @core.boundary(force) = skin/ember/advance <- velocity
X approach.director @core.realized = none/none/still <- impact + rumble ~0.4s
```

按同一份可转换余额划出 70% 热、30% 径向机械功，各有容量、效率及适用对象。移去干木后，未用热份不能自动把冲量扩大到满额。驱离所有可见近距目标时，火核到期退出，现场没有那次交付。若已有木料达到真实着火条件，术后由环境燃烧条件继续结算。
