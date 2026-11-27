# 经典原题 01–07 · 从地面、动作与介质中展开

每题独立施法。读谱时可先遮住两个结果，从给定现场推一次。 [共用语义](semantics.md) · [题目索引](README.md)

<a id="j01"></a>

## J01 · 岩石球

从地面分别抬起三块岩石，悬停成列，松手后沿弧线投出，各石可独立碰撞、碎裂并留下。

**现场与锚定**　`{土,聚}▷引`。借三块可移动石，石上有有限天然裂缝。施法者与地面可承担升力和反冲。

```text
C 石料,引力,有限传力
S stones = borrow(stone,exact(group(nearby(loose_stone,3m),3),3))
K row = formation(stones,3,arc,simultaneous,0.8m)
K center = reference(row,offset(live(caster),(0,1.2m,0)))
R sling = force(caster,self,via=slot(ground))
P raise each(row) <3s,caster> : tick Drive.motion(self,guided_drift,home(row,self)) | on release -> [Drive.impulse(sling,aim_upward)] fly
P fly <2s,caster> : tick Drive.motion(self,ballistic,world) | when overload(self) => Transform.fracture(self,material_seam) | on timeout -> end
X raise.hero @self.realized = array/slate/gather <- velocity + rumble
X fly.secondary @self.realized = mass/slate/shed <- break + crack ~0.3s
```

**正例**　三块先离地再悬停，交付捕获上仰方向，之后受重力呈弧。横梁挡住中间一块并使该石裂缝过载，只有它留下碎块，另外两块继续。超时还权后世界继续算动量。

**反例**　从同一现场只取走第三块，exact 建立失败，地上两块原位。只改变横梁强度则影响中途的碎裂，不能回溯收回已投出的石。

<a id="j02"></a>

## J02 · 卡利亚圆阵

在施法者上方形成多枚待发辉剑，各自感知、消费与发射；待发期间仍可被外界阻挡或破坏。

**现场与锚定**　`{光,守}→应▷引`。三个槽，真实光学感应半径 2 m；每槽独立分得有限储备。

```text
C 奥术形体,有限感应
S blade = manifest(light,body(0.15m),offset(live(caster),(0,1.5m,0)))
K fan = formation(blade,3,arc,per_trigger,1m)
K bank = per_member(fan,store(mana,self,small))
R shot = force(self,self,basis=shape)
K axis = bounds(shot,toward(sensed(self)))
K shape = basis(self,arcane_inertia,caster)
P form each(fan) <1s,caster> : enter Establish.open(self),Transfer.move(caster,bank,all) | on ready -> watch
P watch <5s,caster> : on proximity(self) if ready(bank,1) -> [Transform.detach(self),Transfer.deliver(bank,shot)] fly
P fly <2s,caster> : tick Drive.motion(self,ballistic,world) | on contact(self) -> end
X watch.hero @self.realized = array/crystal/still <- fill + breath
X fly.secondary @self.realized = ribbon/crystal/advance <- velocity ~0.2s
```

**正例**　受体位于左槽的感应域内，shot 按已感应的方向交付，左槽余额用尽。另两枚仍随施法者移动。飞行实体真实初触可向柱体传力。

**反例**　在触发前摧毁左棱支撑，左槽退出且无发射，另外两槽的余额及位置不变。仅遮住受体同样不发射，但左槽仍有效。

<a id="j03"></a>

## J03 · 亚杜拉的月光剑

冷刃贴着真实武器扫掠，交付帧产生独立的霜波；近身与远端都能对触及的实物抽热。

**现场与锚定**　`{{光,联},{火,逆}}▷分`。近身陶杯 A 与远处湿砖 B 分处两条扫掠轨迹；施法者携带有限余热接收器。

```text
C 寒冷弧面,热交换,动作派生
S blade = manifest(aether,body(1m),live(weapon))
S wave = derived(blade,patch(4,1.6m,0.15m,50deg),live(blade))
K form = basis(wave,arcane_inertia,caster)
R chillA = thermal(hit(blade),slot(heatSink),via=blade)
R chillB = thermal(hit(wave),slot(heatSink),via=wave)
R castWave = force(caster,wave,basis=form)
P swing <1s,caster> : tick Drive.motion(blade,sweep_arc,weapon) | when contact(blade) => Drive.heat(chillA,forward) | on pose_release -> [Establish.open(wave),Transform.detach(wave),Drive.impulse(castWave,forward)] travel
P travel <2s,caster> : enter Withdraw.close(blade) | tick Drive.motion(wave,ballistic,world) | on contact(wave) -> [Drive.heat(chillB,forward)] end
X swing.hero @blade.realized = skin/crystal/advance <- velocity + breath
X travel.hero @wave.realized = ribbon/crystal/advance <- velocity + ring ~0.3s
```

**正例**　先扫中 A，A 失热。角色在离刃后转身，波继续原方向接触 B，B 的水膜在抽热超过潜热门槛时结霜。两次热均进同一有限汇，不能各称拥有全额。

**反例**　只把 B 换成干砖，仍能失热，表面没有那层水霜。只把打断放在离刃同刻，则 A 先前的温降保留，B 没有接触也没有温降。

<a id="j04"></a>

## J04 · 恶神火焰

缓行的火球在临近时爆开，地上留下可持续燃烧的结果。

**现场与锚定**　`{火,聚}▷{应,散}`。同一地面有干油迹和湿石，热与向外冲量共用一槽；临近探针在 1 m 内。

```text
C 火核,热交换,可燃介质
S core = manifest(fire,sphere(1m),capture(hand))
K fuel = store(mana,core,medium)
R hot = thermal(core,within(core,heat_receiver))
R push = force(core,within(core,movable))
K direction = bounds(push,radial_out)
K speed = bounds(core,linear_speed,0.6m/s)
P kindle <2s,caster> : enter Establish.open(core) | tick Transfer.move(caster,fuel,all) | on release if ready(fuel,0.2) -> creep
P creep <4s,caster> : tick Drive.motion(core,guided_drift,aim) | on proximity(core) -> [Transfer.split(fuel,hot@0.7,push@0.3)] end
X kindle.hero @core.realized = core/ember/gather <- fill + breath
X creep.hero @core.realized = skin/ember/advance <- velocity + rumble
```

**正例**　慢行时位置持续改变，未有临近就没有爆发。实付热使油迹达到着火阈值，燃料和空气继续支持燃烧；碎物另得有限径向冲量。

**反例**　只去掉油迹仍有爆发、石面升温和碎物位移；撤术后没有相同的地面燃烧。提前驱离目标则连爆发都没有。

<a id="j05"></a>

## J05 · 菈妮的暗月

施法者悬起，冷暗月体与多个局部域共同长成并向外移动，遇到可干涉的魔法时作用。

**现场与锚定**　`{{重力,逆},{光,藏},{火,逆},{以太,分}}▷引`，large。施法者有质量，场内有温石和由另一术悬托的冰体。

```text
C 局部重力,消光,抽热,奥术支撑
S moon = manifest(aether,body(0.15m),live(hand))
S cloud = derived(moon,sphere(0.2m),live(moon))
K size = store(mana,moon,large)
R rise = gravity(moon,caster)
R shade = optical(cloud,within(cloud,sightline))
R cold = thermal(within(cloud,warm),slot(heatSink))
R dim = arcane_support(cloud,support_of(within(cloud,spell)))
K shell = basis(moon,arcane_inertia,caster)
R send = force(caster,moon,basis=shell)
P form <4s,caster> : enter Establish.open(moon),Establish.open(cloud) | tick independent([Transfer.move(caster,size,all),Drive.shape(moon,body(0.8m),fill(size)),Drive.shape(cloud,sphere(2m),fill(size))],Drive.gravity(rise,up),Drive.optics(shade,0.25),Drive.heat(cold,forward),Constrain.suppress(dim)) | on release if ready(size,0.5) -> [Transform.detach(moon),Transfer.deliver(size,send)] glide
P glide <3s,caster> : tick independent(Drive.motion(moon,ballistic,world),Drive.optics(shade,0.25),Drive.heat(cold,forward),Constrain.suppress(dim))
X form.omen @moon.sky = horizon/dark/gather <- fill[0.5..1]:ease_in + breath
X glide.hero @cloud.boundary(optical) = core/dark/advance <- velocity + rumble
```

**正例**　向上局部加速度超过自然重力时角色升起。放出后角色失去该项升力，已长成的各域随月行。冰的悬托进入域且容量不足时失效，冰带原有动量下落。

**反例**　只移走热汇，温石不再失热，月体照旧遮光并能压制悬托。把悬冰换成自然冰块则无异常边可压制。天光暗化没有扩大世界作用域。

<a id="j06"></a>

## J06 · 古龙雷击

从施法者向外依次形成多个落点，蓄力扩半径，击中后才沿现场导体继续传播。

**现场与锚定**　`{电,聚}▷散→联`。3 个方位落点，距离随满度在 1–4 m 内改变。回路有地端和可切断的湿铜桥。

```text
C 电势,局部放电,导电传播
S pin = manifest(aether,body(0.05m),capture(caster))
K sites = formation(pin,3,line,staggered,1m)
K cell = store(mana,caster,medium)
K pattern = layout(sites,radial_steps,fill(cell),1m,4m)
K quota = per_member(sites,store(mana,self,small))
R strike = electric(self,first_contact(self,down),via=air_gap)
R branch = electric(first_contact(self,down),slot(ground),via=slot(conductorGraph))
P charge <2s,caster> : tick Transfer.move(caster,cell,all) | on release if ready(cell,0.2) -> [Transfer.apportion(cell,quota,sites)] sequence
P sequence each(sites) <2s,caster> : on scheduled(self,0.2s) -> [Transfer.deliver(quota,strike)] conduct
P conduct <0.1s,caster> : enter Transfer.route(branch,residual(strike)) | on ready -> end
X sequence.hero @self.realized = ribbon/etch/advance <- impact + crack
X conduct.secondary @self.realized = ribbon/ember/shed <- impact ~0.15s
```

**正例**　放手时锁定布局与三个独立份额，按离中心的次序在 0、0.2、0.4 秒放电。第二落点接入湿铜，后续只用该落点剩余的实际电荷与电功。

**反例**　只断铜桥，三处主放电的先后与位置相同，桥后的二次交付为零。缩短蓄力则外圈半径与可交付量收缩。

<a id="j07"></a>

## J07 · 长吟形成的巨型旋风

柱域须逐步长成，维持时半径、强度和形态随供给而变，撤术保留对象运动。

**现场与锚定**　`{气,聚}▷{引,散}`，large。现场空气充足，东侧、轴心、远侧各一质量探针，采用径向衰减。

```text
C 空气,有限三分量力
S f = manifest(air,column(0.3m,0.2m,0.5m),capture(aim))
K reserve = store(mana,f,large)
R spin = force(f,within(f,movable),via=slot(air))
K profile = bounds(spin,linear_falloff,uniform)
K strength = envelope(spin,fill(reserve),linear)
P chant <4s,caster> : enter Establish.open(f) | tick Transfer.move(caster,reserve,all),Drive.shape(f,column(3m,1.5m,8m),fill(reserve)) | on release if ready(reserve,0.3) -> hold
P hold <5s,reserve> : tick Drive.shape(f,column(3m,1.5m,8m),fill(reserve)),Drive.field(spin,v(-0.48,0.64,0.60)) | on interrupt -> end
X chant.hero @f.boundary(force) = ribbon/mist/gather <- fill + breath
X hold.hero @f.realized = ribbon/mist/turn <- velocity + rumble
```

**正例**　蓄满时柱底和柱顶不同宽，东侧探针向内、绕轴并上升，轴心只受轴向作用。寄存额度消耗后作用域逐步收窄，满额力乘以实际余额比，远侧先失去作用。尾段无新增受力。

**反例**　对同一首步只置 axial=0，升力为零；只反转 tangential，旋向相反。仅在满蓄前打断则没有 hold 阶段，已形成的无支撑气域消退。
