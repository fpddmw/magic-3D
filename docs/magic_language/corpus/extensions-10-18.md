# 拓展原题 10–18 · 在术与术、观察者和世界之间

第 13 题「遮蔽＋感应」的完整双通道谱见[重点组合](focus.md#t13)。本册后三题使用有界研究权限。 [共用语义](semantics.md) · [题目索引](README.md)

<a id="t10"></a>

## T10 · 寄托＋感应＋回应

把待发作用与有限责任留在现场，让真实环境变化触发；施法者能腾手离开。

**现场与锚定**　`{以太,藏}▷{应,守}`。蓄水闸边的浮标、排水副闸及回流渠。只响应水位越过高刻度的上升边沿。

```text
C 寄托,浮标接触,实际排流
S host = ref(slot(gauge))
S sign = manifest(aether,body(0.05m),live(host))
K fund = store(mana,host,medium)
R gate = hydraulic(slot(basin),slot(drain))
P deposit <2s,caster> : enter Establish.open(sign) | tick Transfer.move(caster,fund,all) | on release if ready(fund,0.5) -> [Transfer.handoff(sign,fund)] armed
P armed <7s,fund> : on contact(host,slot(highFloat)) -> vent
P vent <1s,fund> : tick Transfer.route(gate,0.5m3/s)
X armed.hero @host.realized = skin/etch/still <- fill
X vent.secondary @host.realized = ribbon/water/advance <- impact + ring
```

**正例**　交接后主人离开。浮标因真实水位升高接触刻度，器物付款输送最多 0.5 m³，源减量与排水渠增量相等，本次待发任务退出。

**反例**　只压低水位使浮标不碰刻度，等到期也不排水；只在触发前毁掉宿主，水位再高也失去主动排流责任。

<a id="t11"></a>

## T11 · 分离＋解除＋归属

切断另一术对楔石的悬托，等它自然落座，重新取得合法材料再利用。

**现场与锚定**　`{以太,分}▷{土,联}`。外术支撑边暴露且容量可被切断，楔石下方有修补座，石材的借用权限独立登记。

```text
C 已有魔法,自然石料,接缝
S wedge = ref(slot(wedge))
S arch = borrow(stone,slot(arch))
R drop = arcane_support(caster,support_of(wedge))
K reach = bounds(drop,2m)
R seam = support(arch,slot(socket))
S supply = borrow(stone,slot(wedge))
P undo <1s,caster> : enter Constrain.cut(drop) | on ready -> wait
P wait <3s,caster> : on contact(wedge,slot(socket)) -> mend
P mend <1s,caster> : enter Transform.repair(seam,supply) | on ready -> [Transform.handoff_world(arch)] end
X wait.hero @wedge.realized = mass/slate/advance <- velocity
X mend.secondary @arch.front = skin/slate/gather <- growth + crack
```

**正例**　切断后原石以原键落下。命中槽口、有借用权且份额相容时，才扣楔石相应材料补合拱边；原术以后恢复供给也不能复用那份材料。

**反例**　只保留原物主的排他取用权，新术仍能解除被授权干涉的悬托，却无法拿石修拱。只搬开槽口则根本不到修复阶段。

<a id="t12"></a>

## T12 · 联结＋转向＋传递

在传输仍在发生时更换真实下游端口，保持在途份额去向。

**现场与锚定**　`{水,联}→引▷逆`。泵到岔口有同介质两出口 A、B，每包 0.5 kg，飞行一秒，源有 2 kg。两端都有容量。

```text
C 有向输送,在途材料份
S src = borrow(water,slot(tank))
R a = material(src,slot(binA),via=slot(pipeA))
R b = material(src,slot(binB),via=slot(pipeB))
K mux = ports(a,b,initial=a,transit=1s)
P send <5s,caster> : enter Couple.link(a) | tick repeat(4,0.5s,Transfer.route(active(mux),packet(0.5kg))) | when changed(input(turn)) => Couple.switch(active(mux),selected(mux,input(turn))) | on release -> end
X send.hero @src.realized = ribbon/water/advance <- velocity + breath
```

**正例**　0.5 秒、1.0 秒发往 A；1.1 秒切到 B；1.5 秒、2.0 秒两包发往 B。待在途清空，两槽各多 1 kg，源净减 2 kg。信息包、热包复用端口选择与在途合同，但各自校验载荷与单位。

**反例**　只令 B 在切换时失去接收资格，切换事务失败，维持 A，四包均走 A；重复切换通知不能复制已出发的包。

<a id="t14"></a>

## T14 · 幻象＋追随＋回应

非实体哨影跟随真实人形姿态，根据实际观察条件回应。不同位置的观察者可形成不同判断。

**现场与锚定**　`{光,藏,联}→应`。走廊有一尊空像、一个表演者和两名观察者。图样来自已登记外形，映射不赋实体质量。被观测信号限定有光学互见采样和授权报告。

```text
C 光学形象,单人观察记录,有限图样
S image = manifest(light,body(0.8m),live(slot(actorPose)))
R light = optical(image,within(image,observer_ray))
R reply = information(slot(lookSensor),image,via=mutual_sight)
K exposure = bounds(reply,gaze_event,4Hz)
P mimic <5s,caster> : tick independent(Drive.emit(light,pose_sample),Couple.sample(reply,gaze_event)) | when signal(reply) => Drive.emit(light,turn_to_sample) | on release -> end
X mimic.hero @image.realized = mass/mist/advance <- velocity
X mimic.secondary @image.realized = skin/etch/turn <- signal
```

**正例**　无遮挡观察者看见姿态取样生成的影像。已登记的观察端报告有效注视，下一显示采样哨影向该端转头。伸手摸到空处，接触矛盾仅记在该观察者可用证据里。

**反例**　只在另一观察者与影像之间关门，后者得不到这帧光，也不能因前者识破而自动知道真相。把一只箱放在影像上依然落地。

<a id="t15"></a>

## T15 · 活化＋控制＋寄托

让已有器物在主人离开后从守候转为搬运，再交付真实载物。

**现场与锚定**　`{以太,藏}→{应,引,守}`。有脚轮的小车、获准搬动的木箱、地面通路与目的仓位。车可接收一次真实装运信号。

```text
C 器物寄托,有限导航,负荷
S cart = borrow(solid,slot(trolley))
S crate = borrow(solid,slot(crate))
K k = store(mana,cart,medium)
R grip = support(cart,crate)
R notice = information(slot(loadingPad),cart)
P fund <2s,caster> : enter Establish.open(cart) | tick Transfer.move(caster,k,all) | on release if ready(k,0.5) -> [Transfer.handoff(cart,k)] wait
P wait <4s,k> : tick Couple.relay(notice,contact) | on signal(notice) -> take
P take <3s,k> : tick Drive.motion(cart,guided_drift,waypoint(cart,crate)) | on contact(cart,crate) -> [Constrain.bind(grip)] haul
P haul <4s,k> : tick Drive.motion(cart,guided_drift,waypoint(cart,slot(bay))),Constrain.support(grip) | on contact(cart,slot(bay)) -> [Withdraw.close(grip),Transform.handoff_world(crate),Transform.handoff_world(cart)] end
X wait.secondary @cart.realized = skin/etch/still <- fill
X haul.hero @cart.realized = mass/slate/advance <- velocity + rumble
```

**正例**　主人走后仍由 k 付费。车等信号，到箱边实际取物，再沿可达路线搬运；到仓位解除抓持，箱和车以原键交还。

**反例**　只堵住全部通路，车即使已收信号也只能等待，不能把箱隔墙交付。只令 k 在途中耗尽，抓持失效，车与箱都留在最后的实际位置。

<a id="t16"></a>

## T16 · 修复＋联结＋重构

用散落残料修复已有结构。可以修复局部受力图，不回滚整件物体。

**现场与锚定**　`{土,聚}→联▷守`。原有梁的两个断口错位，残石 1 kg；需要在容差内，断口至少 0.6 kg 同质料。

```text
C 结构身份,承力边,相容补料
S beam = borrow(stone,slot(damagedBeam))
S endcap = borrow(stone,slot(looseEnd))
S mortar = borrow(stone,slot(fragments))
R joint = support(beam,endcap)
K fit = bounds(joint,0.02m,0.6kg)
P align <3s,caster> : tick Drive.motion(endcap,guided_drift,slot(seat)) | on contact(beam,endcap) -> bond
P bond <1s,caster> : enter Transform.repair(joint,mortar) | on ready -> [Transform.handoff_world(beam),Transform.handoff_world(endcap)] end
X align.hero @endcap.realized = mass/slate/advance <- velocity
X bond.hero @beam.front = skin/slate/gather <- growth + crack
```

**正例**　两端相距 1 cm、法向匹配，新边消耗 0.6 kg，余 0.4 kg。重新分配负荷后梁能承受本次静载，别处旧伤仍在。

**反例**　只把残料减至 0.5 kg，接触可以发生，但整笔修复失败，不扣残料，承重边继续缺失。

<a id="t17"></a>

## T17 · 空间＋联结＋传递

远隔的两实际位置之间仅让被选类别的真实内容通过，保持来源、容量和出口条件。

**现场与锚定**　`{空,联}→引`。两个定向小面，开放自然脱离的水份额，排除携带容器及人，容量每次至多 1 kg。

```text
C 有限空间通路,材料份,净空
S a = manifest(aether,patch(1,0.4m,0.4m,0deg),capture(slot(spout)))
S b = manifest(aether,patch(1,0.4m,0.4m,0deg),capture(slot(receiver)))
R port = spatial(a,b,mode=one_way)
K admit = bounds(port,free_water_lot,1kg)
P open <4s,caster> : enter Couple.link(port) | when crossed(port) => Transfer.cross(port,event.subject) | on release -> end
X open.hero @a.boundary(spatial) = skin/water/still <- progress
X open.secondary @b.realized = ribbon/water/advance <- impact + ring
```

**正例**　一份 0.8 kg 的水以独立份额穿面，源侧失去该份，出口接到相同份额和映射速度。第二份重新占用通行容量。

**反例**　只把同份水留在完整封闭的壶里经过入口，壶不符合资格且水没有独立穿面，二者留在原侧。只塞住出口，第一次水份也不会被提前扣走。

<a id="t18"></a>

## T18 · 时间＋束缚＋交付

只暂缓指定过程的演化，条件满足后解除，让一次有来源的待交付作用正常完成。

**现场与锚定**　`{时,守}→藏▷引`。器物里有可转移物料，接收仓在同一条有效送料通路上。配方显式建立一次性成熟过程及其可调速端口，由独立分支干涉；其世界时硬顶为 8 秒。

```text
C 局部过程时钟,已有权益,外部事件
S host = ref(slot(container))
K stock = store(material,host,1kg)
R send = material(stock,slot(bin),via=slot(feed))
R pause = temporal(caster,clock_of(ripen))
K filter = bounds(pause,local_progress_only,0,1)
P load <1s,caster> : enter Transfer.move(slot(source),stock,1kg) | on ready if ready(stock,1) -> fork(ripen,watch)
P ripen <8s,caster> : on local_after(2s) -> [Transfer.route(send,packet(1kg))] end
P watch <3s,caster> : on contact(host,slot(brake)) -> stop
P stop <4s,caster> : tick Drive.gain(pause,0) | on contact(host,slot(latch)) -> [Withdraw.close(pause)] end
X stop.hero @host.realized = skin/etch/still <- progress + breath
```

**正例**　在本地进度 1 s 时暂停，世界时过 2 s 闩扣接触，解除后还需 1 s 自然成熟，ripen 通过 send 只交付此前预留的一份。继承前一快照已成立的倍率直到解除边界，硬时限约束两支。期间撞击器物照常发生。

**反例**　只让器物在暂停中被摧毁，待交付权益失效，1 kg 实料按原位泄落结清，闩扣后来打开也不能复活它。若只把 ripen 的世界硬顶缩短到早于恢复时刻，交付同样为零。与把物体锁在原地的静止器有不同后果。
