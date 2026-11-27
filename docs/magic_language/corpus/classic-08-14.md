# 经典原题 08–14 · 材料、空间与局部责任

本组逐题保留真实材料或对象的身份。死亡、断供和撤术各自结清局部责任。 [共用语义](semantics.md) · [题目索引](README.md)

<a id="j08"></a>

## J08 · 冰柱与可取走的碎冰

从实水在支点逐段形成可踩冰柱，外力超过强度后留下可拾取的冰块。

**现场与锚定**　`水→聚→守`。底座、6 kg 水、冷石；柱体预定三段。空间可容全柱，每生长一段须有水和排热通路。

```text
C 水,潜热,自然支撑
S water = borrow(water,slot(pool))
S ice = derived(water,body(0.25m),capture(slot(base)))
R grip = support(slot(base),ice)
K build = growth_material(ice,water,solid,slot(coldStone),3)
P rise <4s,caster> : tick Transform.grow(ice,height,0.5m/s,truncate,build),Constrain.support(grip) | on release -> [Transform.handoff_world(ice)] end
X rise.hero @ice.front = mass/crystal/advance <- growth + ring
X rise.secondary @ice.realized = skin/crystal/strain <- load + crack
```

**正例**　水源减少的量等于已凝固量。只能踩已成形高度。成形后撤术，同一冰柱仍可站立；世界重物压裂天然接缝后，三段中脱落的段仍有质量、动量与可抓取接口。

**反例**　只把顶板降到 0.7 m，前沿、碰撞与可踩高度同步止于顶板，未成形份不扣水。换成无余量的热汇则没有新增冰。

<a id="j09"></a>

## J09 · 石墙、斜坡与石桥

用实料逐段建立相互支撑的石构件，可选墙、斜坡或桥；断局部支点后按剩余拓扑重算。

**现场与锚定**　`{土,聚}▷{联,守}`。两墩间宽 3 m，近端可承建造期悬臂。建术时选择形状和支点，石料有天然咬合面。

```text
C 石料,有限承重图
S rock = borrow(stone,slot(stock))
S slab = derived(rock,patch(3,3m,1m,0deg),capture(slot(pierA)))
K frame = chain(slab,slot(piers),medium)
K form = poses(slab,cast(input(form)),wall=pitch(90deg),ramp=pitch(30deg),bridge=pitch(0deg))
R load = support(slab,frame)
P lay <5s,caster> : tick Transform.grow(slab,extent,1m/s,truncate,rock),Constrain.support(load) | on release -> [Transform.handoff_world(slab)] end
X lay.hero @slab.front = skin/slate/advance <- growth + rumble
X lay.secondary @slab.realized = skin/slate/strain <- load + crack
```

**正例**　选 bridge 时近端延伸，抵达远墩后才形成第二支点，释放后自然咬合承重。之后炸裂中缝，仍受两侧不同支点承托的部分分别验负荷。

**反例**　只移去远墩，已铺石不会自动获得跨空支持。超过悬臂容量的部分坠落。选 ramp 时端位和接触法向随几何改变，同一支撑规则重算。

<a id="j10"></a>

## J10 · 控水与分海

主动改道、分开水体留出可通行缺口，撤销约束后按真实水位回填。原题的改向、浪涌、旋涡用同一批水。

**现场与锚定**　`{水,分}→{引,守}`。三个单位底面积的连通槽 L/M/R，初始各 2 m³，侧槽各有 ≥1 m³ 余容。局部对照采用稳定底面。

```text
C 水,水头差,介质动量
S pool = borrow(water,slot(basin))
R left = hydraulic(part(pool,M),part(pool,L))
R right = hydraulic(part(pool,M),part(pool,R))
R dam = hydraulic(slot(sideReturns),part(pool,M))
R swirl = force(pool,within(pool,water),via=slot(banks))
K mode = choice(cast(input(form)),part,redirect,surge,rotate)
P work <5s,caster> : tick by(mode,part:[Constrain.bind(dam),Transfer.route(left,0.5m3/s),Transfer.route(right,0.5m3/s)],redirect:[Transfer.route(right,1m3/s)],surge:[repeat(1,1s,Transfer.route(right,packet(1m3)))],rotate:[Drive.field(swirl,v(0,0.7,0))]) | on release -> end
X work.hero @pool.front = skin/water/advance <- growth + rumble
X work.secondary @pool.realized = ribbon/water/turn <- velocity
```

**正例**　分海维系 2 秒后 L/M/R 为 3/0/3，总量 6，中央水深低于通行阈值。松手释放回流边，下一世界步开始从两侧向中间回填。改向持续输送；浪涌只送一拍后让有限水团沿后续梯度传播；旋涡改变实际水的运动。

**反例**　只预先占满右槽余容，右向申请为零，2 秒后中央仍有 ≥1 m³，不能报告全宽通路。演出即使画出两面水墙，也不能把这份水从占位里拿掉。

<a id="j11"></a>

## J11 · 蛛网

撒出有支点的柔性网，接触后黏住，在足够外力或确实燃烧时局部失效。

**现场与锚定**　`{联,守}→应`。已知纤维性质；两柱相距 2 m，擦过网的负荷 3，黏着上限 4，同一根纤维受热后上限可降到 2。

```text
C 柔性纤维,黏附,可燃
S web = manifest(fiber,path(6,3m,0.02m),capture(slot(postA)))
K seed = initial(web,extent,0m)
K mesh = topology(web,slot(posts),branched)
R tie = support(web,slot(posts))
R glue = adhesion(web,hit(web))
P weave <3s,caster> : enter Establish.open(web) | tick independent(Drive.shape(web,path(6,3m,0.02m),progress),Couple.link(tie)) | on release -> [Transform.handoff_world(web)] end
K surface = natural(web,glue,contact,material_strength)
X weave.hero @web.realized = ribbon/etch/strain <- load + breath
```

**正例**　两端接实后，受力 3 的物体黏住，负荷沿纤维送至柱。外部火焰将局部纤维烧薄，可承上限降到 2，该边先脱开，其余分支按还存在的支点结算。

**反例**　只移掉远端柱，材料仍可垂挂、局部沾附，无法维持同样横跨两柱的约束。只关闭火源并保持负荷 3，未损的边继续承担。

<a id="j12"></a>

## J12 · 磁力抓取

引用同一件可被磁力作用的金属，有限力与力矩控制位置、姿态，松手保留运动。

**现场与锚定**　`{引,联}→土`。施法者瞄着铁箱，铁箱前有墙，反力由现场锚体承担。

```text
C 磁响应,力矩,惯性
S box = borrow(magnetic_solid,target)
R pull = magnetic(slot(anchor),box)
K pose = bind(guide,aim,desired_pose,box,1m/s)
K torque = bounds(pull,angular_speed,45deg/s)
P guide <5s,caster> : tick Constrain.bind(pull),Drive.motion(box,guided_drift,aim) | on release -> [Withdraw.close(pull),Transform.handoff_world(box)] end
X guide.hero @box.realized = mass/slate/turn <- velocity + rumble
```

**正例**　瞄点提高并旋转，铁箱在限速限矩内上升并转身，碰墙时停在可实现的位置。松手后箱以当时姿态和动量下落。

**反例**　只把箱换成相同外形的无磁木箱，借用条件失败。把墙后瞄点改到墙前才可能成功到位，增加视效不会提高抓力。

<a id="j13"></a>

## J13 · 活化物体

多件原有器物取得有限行动能力，按命令与各自感知行动；解除后仍是同一批器物。

**现场与锚定**　`{以太,联}→{引,应}`。两件可活动器物、两个现场可见工作点、有限地面通路。主人选择守候或前往。

```text
C 原物,受限感知,自主运动
S tools = borrow(solid,group(nearby(loose_solid,3m),2))
K legs = basis(self,ground_motion,caster)
K jobs = match(tools,visible_points(self,3m),reachable)
K cmd = bind(act,input(order),enum_order,tools,hold_or_go)
P act each(tools) <6s,caster> : tick by(cmd,hold:[Drive.motion(self,static,world)],go:[Drive.motion(self,guided_drift,waypoint(self,goal(jobs,self)))]) | on release -> [Transform.handoff_world(self)] end
X act.hero @self.realized = array/etch/advance <- velocity + brace
```

**正例**　两个目标都可达时分别认领、移动。途中堵住左侧通路，左器物停住或走已登记的绕路，右器物继续；撤术后同一世界键和损伤仍在。

**反例**　只摧毁一件器物的运动支撑，即使它仍能被感知，也不能继续迈进。另一件不会复制它、重置其损伤或被一并解除。

<a id="j14"></a>

## J14 · 守卫刻文

把真正待发的局部过程和余额交给器物，主人可离开；一次合格事件只消费一次。

**现场与锚定**　`{以太,藏}▷{应,散}`。门楣上有刻面，门前有触点，储备足够一次有限推力。

```text
C 寄托,事件,奥术传力
S stone = ref(slot(lintel))
S zone = manifest(aether,sphere(1m),live(stone))
K fund = store(mana,stone,small)
R push = force(zone,within(zone,movable))
R trigger = information(slot(pressurePlate),stone)
P deposit <2s,caster> : enter Establish.open(zone) | tick Transfer.move(caster,fund,all) | on release if ready(fund,1) -> [Transfer.handoff(zone,fund)] wait
P wait <6s,fund> : tick Couple.relay(trigger,contact) | on signal(trigger) -> fire
P fire <0.1s,fund> : enter Transfer.deliver(fund,push) | on ready -> end
X wait.hero @stone.realized = skin/etch/still <- fill
X fire.secondary @zone.realized = ribbon/mist/shed <- impact + rumble ~0.2s
```

**正例**　主人离开，器物仍承担等待。触点首个接触启动已登记的 fire，实际场内受体分摊剩余可交付额。第二次触点事件找不到待发过程。

**反例**　先毁门楣再触碰，局部责任随宿主失效，余额按合同结清，门前无推力。打断已经交接的原施法者则不造成这一结果。
