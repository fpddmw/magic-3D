# 拆开配方再创作 · 四组变奏与一份独立原创

每组的六面是完整基准。两个差分各自只继承本组基准，不互相叠加；点名的行整体替换或追加到指定过程。`G` 是 A7 几何值的局部名，`each` 只遍历声明的有限集合。`X` 用 C5；省略轨道的 start/stop 取所列过程的起止。硬顶为世界时，角色只有一个主动焦点。现场数值用于纸面验读。[空间](../A-space.md) · [责任](../B-world.md) · [局部段](../composition.md) · [舞台](../C-stage.md)

<a id="r1"></a>

## R1 · 三块界石之间有一段空路

**所求。** 在碎石院里，让三块石标出一股朝中心收拢的窄风，从门外把散叶聚到漏水点附近。石间的亮线方便辨认朝向。锚为 `{土,聚}→{风,引}`，读解应能分别指出石、风和亮线的来源。

```text
C 可移动实石、有反力的气流、实际空气；中心取三槽共同参照
S stones=borrow(stone,select(loose_stone,within=3m,exact=3)); air=manifest(air,column(.9m,.9m,1.2m),capture(aim))
G sites=sample(arc(+Y,1.3m,160deg),3); ends=arrange(stones,at(sites,live(air)))
R pull=force(air,within(air,movable),via=resolve(medium,within=air,kind=air))
K frame=reference(ends,live(air)); ground=resolve(reaction,at=caster,policy=contact)
K hold=basis(stones,arcane_inertia,caster); bounds(stones,1m/s); bounds(pull,ground,medium)
P keep <6s,caster>: tick independent(each(stones,Drive.motion(self,guided_drift,ends[self])),Drive.field(pull,v(-1,0,0)))
  | on release -> [Transform.handoff_world(stones),Withdraw.close(air)] end
X visual edges @local(air)=each(adjacent_slots(ends),between(real(left.member),real(right.member)))/etch/still;
  scope=keep; on_loss=hide_edge; opacity=.24
X visual throat @real(pull.boundary)=stream_samples(4,4,pull)/mist/gather; scope=keep; hero
X audio brush @real(receipt(pull).position)=breath(decay=.09s); start=receipt(pull); limit=3
```

三条有界主体运动与受力分开申请。中石被挡时亮线折向它的实到位置；风仍在原指定域收拢。去掉中石时相邻两线均停，不会把原先不相邻的外端连起来。退出后剩余实石及已被吹动的叶片留下。

**R1a · 将亮线换成可送水的细管。** 在水罐和承接碗之间使用两条实到石边作为临时水路，保留原风域。

```text
add S stock=borrow(water,slot(jar)); catch=ref(slot(bowl))
add S pipe=derived(stock,path(3,3m,.04m),live(air)); K ports=topology(pipe,3,serial)
add R feed=hydraulic(stock,catch,via=pipe); K bounds(feed,.1kg/s)
add K shape=branch(real(stones),adjacent_slots(ends)); bounds(pipe,length=3m,radius=2cm)
add P keep.enter = Establish.open(pipe)
add P keep.tick independent branch = [Drive.shape(pipe,each(shape.edge,sweep(disk(2cm),self.curve,+Y)),1),
  Transfer.move(stock,pipe,unfilled_volume),Couple.link(feed),Transfer.route(feed,.1kg/s)]
replace X edges = contour(real(pipe.filled_edges))/water/advance; scope=keep
add P keep.exit = Transform.handoff_world(pipe)
```

`unfilled_volume` 以水密度换算为本步要补的管内质量；建满后取零。管的有效入口/出口还须实际抵达罐口、碗口并满足水头。当前版本基准以整管充满为连通条件。水源 1 kg、两边合计 2 m 时，半径 2 cm 的整管需约 2.51 kg；用该现场观察，首次完整建管的必需事务失败，罐不扣、碗仍空。换为 4 kg，约 2.51 kg 占管，余量才可逐步出罐进碗。失去中石时断掉相应物理边，管内水原位交世界；上步已经落碗的水保留。光线无论多亮都不能做这件事。

**R1b · 把弧阵折进两道门。**

```text
replace G sites = sample(polyline([(0,0,0),(0,0,1.3m),(1.3m,0,1.3m)],false),3)
replace S air.ref = live(aim.position,on_loss=capture_last)
add X environment sill @scene(floor)=projection(edges,reach=.25m)/etch; scope=keep; opacity=.12
```

玩家能把中心从一扇门缓移到下一扇，折线的拐点仍由实石受控赶到。移瞄点那一步，风域随参照更新，石受限速停在后方。固定版在原地收叶，两版均无输水。把石当测风标或把水罐排空是可分辨的世界用途。

<a id="r2"></a>

## R2 · 挂住上缘以后，把下游的水交给谁

**所求。** 取有限存水，在墙扣上留下一个真的冰榫；驾驭其余液尾，将水留给以后到场的人。`{水,引}→{守,联}▷应`。原始现场有四个各能容 1 kg 的等份、石扣、有限冷石与空盆；进入同一施法时借出 4 kg。

```text
C 有限水份、冰的自然刚性、接触扣合、独立控制边
S src=borrow(water,slot(trough)); band=derived(src,path(5,4m,.08m),capture(slot(feed)))
S basin=ref(slot(basin)); K parts=topology(band,4,serial); base=pivot(band,slot(feed))
R lead=control(caster,band,via=parts); lock=support(slot(clip),solid_parts(band))
K aim=bind(pilot,input(aim),desired_path,eligible(band,liquid,lead),1m/s)
K pick=pick(eligible(band,liquid,lead),input(point),first_intersection,on_loss=clear)
K outlet=part(band,d); bounds(basin,capacity=2kg); K receive=contact(outlet,basin.inlet)
P fill <1s,caster>: enter Transfer.move(src,band,4kg),Couple.link(lead) | on ready -> pilot
P pilot <8s,caster>: tick independent(Drive.motion(eligible(band,liquid,lead),guided_drift,relative(base,input(aim))),Constrain.bind(lock))
  | when input(freeze) if valid(pick) => Transform.phase(pick,solid,slot(coldStone))
  | when input(pour) if receive => Transfer.move(component(band,outlet,liquid),basin,packet(2kg))
  | on release -> [Transform.handoff_world(band)] end
X visual rim @real(band.geometry)=contour(band)/water/turn; scope=fill|pilot; hero
X visual notch @real(joined(lock).position)=strip(4cm)/crystal/still; start=joined(lock); stop=exit(pilot)
X audio tap @real(basin.inlet)=ring(decay=.16s); start=receipt(transfer,basin); limit=2
```

冻住 b，真实扣住后 c–d 可绕 b 被驾驭，d 碰盆且玩家交付时这两份才离开 band。盆里 2 kg、a 仍 1 kg 水、b 仍 1 kg 冰。没有真实接触或热汇不足时分别缺入盆资格或冰支点；点在 a 不会冻 b。收尾后可以用第二次施法从盆借取，原施法者离场不影响其身份。

**R2a · 将盆换成提升闸门的配重桶。**

```text
replace S basin = ref(slot(bucket)); replace K bounds(basin) = capacity 2kg
add C 自然绳轮与闸板；fixture bucket 已由真实绳索挂在闸板另一侧，滑轮锚定墙体
drop X audio tap; add X use knock(receipt(transfer,basin),room) scope=pilot
```

输入的蓄水、扣合、驾驶和交付完全相同。题设闸板折算阈值 1.5 kg，传动实际可用时，2 kg 入桶后闸门才上移。只剪绳，仍能装水却不提门；接管者可以搬走水或修绳。额外功由配重下降的重力势能提供。

**R2b · 把一次倾倒分成按前沿到达的两次。**

```text
add S cups=ref(select(cup,within=2m,exact=2,order=distance_key))
drop S basin; drop K receive,bounds(basin)
replace P pilot.when(pour) = when contact(outlet,cups.member) if unused(event.subject)
  => [Transfer.move(component(band,outlet,liquid),event.subject,1kg),mark_used(event.subject)]
add K visited = bounded_set(cups,initial=empty); mark_used writes visited on commit
drop X audio tap; add X use knock(receipt(transfer,cups.member),room) scope=pilot
```

两杯各可容 1 kg。液尾扫到第一杯发生一次，继续相贴不重复；第二杯被挪开时另一份仍在液尾。撤术那一刻可数到杯中 1 kg、液带余水 2 kg、扣上冰 1 kg。`unused/mark_used` 是有界过程状态，按杯键记录成功回执，断联不重置。这里把一次需要按键的交付，改成可由对象的实际排列演奏的两拍。

<a id="r3"></a>

## R3 · 沿暗廊移动的一小片凉影

**所求。** 运送怕光、怕热的物件通过亮廊。`{藏,光}→引，{水,分}` 锚为遮光与抽热。两种作用各有半径、承担者和寿命；壳、环、远景可在两种作用之间自由换形。

```text
C 奥术中心、有限光衰减、向有容量的热汇转移热
S core=manifest(aether,body(.12m),capture(hand)); zone=derived(core,sphere(1.4m),live(core))
R shade=optical(zone,within(zone,sightline),extent=sphere(1.4m))
R exchange=thermal(within(zone,warm),resolve(thermal_sink,at=zone,policy=ambient),extent=sphere(.5m))
K pilot=bind(move,input(aim),center,core,.6m/s); upkeep=basis(core,arcane_inertia,caster)
P move <6s,caster>: tick independent(Drive.motion(core,guided_drift,input(aim)),Drive.optics(shade,.35),Drive.heat(exchange,forward))
  | on release -> end
X visual kernel @local(core)=shell(.36m,.02m)/dark/still; scope=move; hero
X use ribs(core,.48m,progress(move)); scope=move
X visual tint @real(shade.boundary)=contour(shade)/dark/fade; while=active(shade)
X environment dew @real(phase(surface_vapor).position)=contour(changed_part)/water/still;
  start=phase(surface_vapor) caused_by=receipt(exchange); owner=world_material
X audio pulse @local(core)=breath(attack=.1s,decay=.2s); start=enter(move)
```

距中心 0.9 m 的物件可能已入暗区，尚不能失热；0.3 m 处有热汇才可降温。断热汇后暗壳随行、照度照减，实际凝露停下。运送结束后温度与先前凝出的水保留，局部消光终止。

**R3a · 保留暗壳，换成压低钟声的作用。**

```text
replace C 向有容量的热汇转移热 = 声学路径、有限衰减
replace R exchange = acoustic(slot(bell),within(zone,listener),via=audible_air,extent=sphere(.5m))
replace P move.tick branch Drive.heat = Drive.gain(exchange,.2)
replace X environment dew = audio damping @real(exchange.boundary)=hush(attack=.04s);
  while=active(exchange); drive=transmission(exchange); tail=0
```

同一外壳、环和消光继续随人走。在钟与听者的实际有效声路上听者接收衰减，绕域声路独立结算。带一块温铜和一盏钟同行，基准可使铜失热，本变奏只改变合格声路；法坛列两种作用，现场的水珠或受阻钟音分别给出线索。舞台的 hush 本身不让守卫失聪。

**R3b · 保留两种真实作用，把圆壳换成低门楣。**

```text
replace X visual kernel = visual lintel @local(core)=sweep(strip(3cm),
  polyline([(-.5m,0,0),(-.5m,.4m,0),(.5m,.4m,0),(.5m,0,0)],false),+Z)/slate/still; scope=move; hero
replace X use ribs = visual offsets @local(core)=repeat(strip(9cm),3,step_along(.2m))/mist/fade;
  scope=move; stagger=.08s
add X environment vault @scene(vault)=projection(lintel,reach=2m)/dark; scope=move; opacity=.08
```

廊下人先看到横梁，再见到沿行进方向错开的三道阴影。把同一热探针与光度计放回 0.3 m、0.9 m，读数、付款和受体集合等同基准。门楣是新的构图，无法被人踩上去。室外没有穹顶便省略投影。

<a id="r4"></a>

## R4 · 让老水槽在涨水时短暂解除另一术的悬托

**所求。** 施法者离开后，水位上涨一次，就让悬在槽口的外术冰块有机会落入槽中。`{以太,联}→{应,分}` 的受体是外露支撑关系，冰仍属于原世界。涨水只在真实探头被淹时给一条信息。

```text
C 水位边沿、寄托账户、可干涉的外术支撑与有限抑制
S host=borrow(device,slot(marker)); port=ref(slot(level_probe)); ice=ref(slot(hanging_ice))
R wire=information(port,host,via=slot(thread),basis=sense); edge=arcane_support(host,support_of(ice))
K sense=transducer(port,water_height,.4m,rising_event); grant=store(mana,host,small)
K bounds(edge,reachable=2m,capacity=small); K one=bounded_count(1)
P set <1s,caster>: enter Transfer.move(caster,grant,all),Couple.link(wire)
  | on ready -> [Transfer.handoff(wire,grant,host),Transform.handoff_world(host)] watch
P watch <8s,grant>: tick Couple.sample(wire,rising_event)
  | on signal(wire) if unused(one) -> [mark_used(one)] act
P act <.3s,grant>: tick Constrain.suppress(edge) | on timeout -> end
X visual thread @local(host)=arc(+Y,.10m,80deg)/etch/still; scope=watch; drive=fill(grant)
X audio note @real(signal(wire).position)=ring(decay=.12s); start=signal(wire); limit=1
X visual seam @real(edge.boundary)=short_stroke(6cm)/etch/fade; scope=act; while=active(edge); hero
```

容量超过悬托负荷且实际高处无别的支点，冰按自身速度下落；0.3 秒后外术若仍有合法支撑可以恢复，已经发生的位移保留。若冰已自然卡在钩上，支撑抑制仍有回执而冰不落。宿主被毁或导线先断，不能越过缺失的信息触发。冰落槽以后，他人可凭实际接触及新取用权另行借冰；寄托术没有取得它的控制权。

**R4a · 将同一份消息交给外术保养端。**

```text
replace C 有限抑制 = 有权接收入账的外部支撑端
replace R edge = arcane_support(host,slot(exposed_maintenance),permission=deposit_only)
replace K bounds(edge) = reachable=2m,capacity=small
add K gift=store(mana,host,small); replace P set.enter Transfer.move(caster,grant,all)
  = Transfer.apportion(caster,[grant,gift],weights=[.7,.3],cap=quoted_total)
replace P set.on_ready = [Transfer.handoff(wire,grant,gift,host),Transform.handoff_world(host)] watch
replace P act = P act <.3s,grant>: enter Transfer.move(gift,edge.receiver,all) | on ready -> end
replace X visual seam = visual pulse @real(receipt(transfer,edge.receiver).position)=strip(4cm)/etch/fade;
  start=receipt(transfer,edge.receiver); duration=.12s
```

接收端公示允许赠与且有余容才入账。相同涨水事件可延长外术支撑，冰继续悬着；赠与者仍无操控外术的权利。端口拒收时，gift 按寄托到期合同结清。比较关闭支撑和资助支撑，能够区分「可以干涉」和「可以接管」。

**R4b · 把探头装在移动的闸板上。**

```text
replace S port = ref(slot(gate_probe)); add K mount=reference(port,live(slot(gate).probe_socket))
replace K sense = transducer(port,local_immersion,.04m,rising_event)
replace X visual thread = visual two_ticks @local(port)=repeat(strip(3cm),2,step_along(4cm))/etch/still;
  scope=watch; on_loss=hide
```

将探头真实装在已有闸板的滑槽内；mount 读已接实的安装关系，失去安装则停止本次观测。在水面不变时放低闸板，浸深跨过 4 cm 也会触发；固定探头版无消息。只移动艺术刻度、探头依然高悬时，两者都无触发。这个变奏可以用闸板位置和水位的真实相对关系作联锁。

<a id="new"></a>

## 独立原创 · 后来的人能摸到井水曾经涨到哪一层吗

**从需求开始。** 一座蓄水井没有刻度，也无人值夜。后来者即使在黑暗中也应能摸到本夜真正淹过的最高一档。要留下可触的记录，可以沉积真实材料。仅留一段记忆、悬空图标或在水退时重画一圈，都无法满足施法者离场与盲摸两个条件。

```text
C 井水浸润、有限材料转移、已有浅槽的自然嵌合
S wall=ref(slot(well_liner)); water=ref(slot(basin_water)); host=borrow(device,slot(float_box))
S stock=borrow(stone,select(compatible_wedges,within=1m,exact=3))
G levels=arrange(slot(three_grooves),at(repeat(point(0,0,0),3,translate(0,.20m,0)),capture(wall.lowest_socket)))
K bank=store(mana,host,medium); K parcel=per_member(levels,store(material,self,40g))
K allowance=per_member(levels,store(mana,self,small)); K owner(host,arm)
R wet[self]=material(water,self.sensor,via=actual_contact); R seat[self]=support(self.groove,self.wedge)
K self.wedge=ref(identity_of_assigned_lot(parcel[self])); K bounds(seat[self],natural_wedge_fit)
P arm <1s,caster>: enter Transfer.move(caster,bank,all),Transfer.apportion(bank,allowance,levels),
  Transfer.apportion(stock,parcel,levels,unit=40g) | on ready -> [Transfer.handoff(parcel,allowance,host),Transform.handoff_world(host)] watch
P watch each(levels) <30s,allowance[self]>: on contact(wet[self]) ->
  [Transfer.move(parcel[self],self.groove,40g),Constrain.bind(seat[self])] done
P done <.1s,world>: enter Transform.handoff_world(self.groove.content) | on ready -> end
X visual sockets @real(wall.geometry)=contour(levels)/slate/still; scope=arm; secondary
X visual grain @real(receipt(transfer,self.groove).position)=strip(3cm)/slate/strain;
  start=receipt(transfer,self.groove); duration=.14s; hero
X use knock(joined(seat[self]),room) @real(joined(seat[self]).position) scope=watch|done
```

**读谱条件。** 三个实际槽高 0.20、0.40、0.60 m，repeat 从已捕获的最低槽参照开始。每槽确有一个取样口和一块可嵌入的粗糙石楔，先按稳定键配给；每块 40 g。预置浅槽允许短程送入，每块石楔预置在相应槽口旁 2 cm 内，实际入槽沿这段清空导向道搬运并由宿主承担反力；座靠真实楔形、摩擦和可达方向；不满足则整次送入失败，可在下一次新的浸润边沿再尝试，到期原物交世界。三个嵌槽都没有此前记录，一次接实后此槽退出。已浸润的传感器在启用时以当前接触作一次初始边沿。阵位只给作者排布和稳定配对，取样位置读每个现有槽口；挪动槽时不会在旧高度继续上报。wet 读取真实材料端的连续液体接触，溅在井外的雨、屏幕上的水纹或远端同名水不通过资格。

**纸面复算。** 水从槽下升至 0.48 m 再退去；低、中两处各有一块凸起，原物共 80 g。干的高槽没有凸起，40 g 还在宿主，期满回到残存容器。撤走施法者、熄灯后后来者仍摸到中档，所能断言的是「至少到 0.40 m」，无法从三档恢复精确连续最高值。只把中槽堵死，第二块没有入壁，后来的触读只能给出已成功留痕的下界。若再把水源换成断开的细雨，中、高槽不会替井水记账。指尖接触既有石楔由自然碰撞承担，下次施法可以按可见/可摸的真实物质重新选取它。

这份构筑组合的是接触、局部分份、寄托、有限嵌合与材料交还；所需的可感知水源身份、浅槽接触和自然接合能力仍待领域后端验证。井内无人观察时可以没有艺术输出，触记依然成立。
