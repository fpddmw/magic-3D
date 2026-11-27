# 三组重点组合 · 逐步推演

编号沿用第二轮原题。每组只有一份配方。表内每一行是同一世界的下一次提交，负例都从标明的检查点只改一个条件。 [共用语义](semantics.md) · [题目索引](README.md)

<a id="t01"></a>

## T01 · 悬浮＋防护＋回应 · 群盾拦截

多片护盾环绕角色。它们应协调迎向真实威胁，也可被玩家临时抽调；分配任务、到达地点和实际拦下是三个时点。

**现场与锚定**　`{守,联}→{应,引}`。三片有容量的实体盾 A、B、C；角色是被保护端。实际可见运动物 u、v 正接近，分别将在 0.30、0.36 s 抵达保护面。C 被柱阻挡，侧墙停放区与两条来物轨迹均不相交。支撑与移动均有偿。

```text
C 实盾,感知,有限速度,接触反力
S shields = borrow(solid,exact(group(nearby(shield_plate,2m),3),3))
K ring = formation(shields,3,ring,per_trigger,1m)
K center = reference(ring,live(caster))
K sweep = orbit_phase(ring,30deg/s)
K mobile = basis(self,arcane_inertia,caster)
R brace = support(self,hit(self),basis=mobile)
K sensor = approaches(caster,visible_moving,4m,0.5s)
K jobs = match(ring,sensor,reachable)
K manual = bind(guard,input(member_pose),manual_goal,ring,2m/s)
P guard each(ring) <6s,caster> : tick independent(Drive.motion(self,guided_drift,goal(jobs,self)),Constrain.support(brace)) | on release -> [Transform.handoff_world(self)] end
X guard.hero @self.realized = array/slate/advance <- velocity
X guard.secondary @self.realized = skin/etch/strain <- load + crack
```

**正例**　假定 u、v 所需冲量均低于各盾容量，运动在这段时间没有新的扰动。

| 检查点 | 认领与控制 | 实际世界后果 |
|---|---|---|
| 发现之前 | 三槽受 ring 调度，空闲目标是环位 | 只有实际盾面能挡路 |
| 0 s 感知提交，下一调度匹配 | A 到 u/v 耗时 0.18/0.25 s，B 耗时 0.19/0.50 s，C 均不可达。选择 B→u、A→v，匹配数为 2 | u、v 此刻都仍有速度。若按最近先把 A 给 u，就会浪费唯一可接 v 的盾 |
| 约 0.19、0.25 s | B、A 先后就位，仍持各自任务代际 | 到位只建立可能的接触面，项目尚不能记作拦截成功 |
| 两物分别到达盾面 | 各盾承受真实接触与反力，超过容量才破裂 | 两次触点归属不同盾，按材料恢复系数停下或偏转，脉纹随真实负荷点亮 |
| 结束 | 松手撤去运动授权 | 盾仍是原物，物体保留此前取得的动量 |

还能把空闲 C 调往别的走廊，那里只有在盾真正抵达后才出现防护。

**反例**　从 0.10 s 分叉，只把 A 手动派往侧墙。旧的 A→v 认领先作废，B 保留 u，C 仍不可达。v 穿过预期位置，继续由世界与角色结算；系统不能把旧认领算成命中。若改的唯一条件是 B 的容量低于 u 的负荷，则 B 到位、实际接触、B 破裂，u 的剩余运动继续。这两个失败原因在法坛和舞台上应能分开。

<a id="t03"></a>

## T03 · 流动＋引导＋凝固 · 水带局部冻结

玩家持续弯曲一条水带，点选已经形成的一段冻结。冰段成为实际支点，其余可控液段继续改向；物质连通、控制可达和承力需要分别追踪。

**现场与锚定**　`{水,引}→联▷守`。四段 a,b,c,d 各 1 kg，施法者从槽中借出 4 kg，没有额外水源。b 已贴在石扣上。显式控制线沿四段布置，由施法者付款，允许跨固态节点；冷石仅足以冻一段。

```text
C 水,液态通路,有限控制边,相变热汇
S src = borrow(water,slot(trough))
S band = derived(src,path(5,4m,0.08m),capture(slot(feed)))
K chain = topology(band,4,serial)
R leash = control(caster,band,via=chain)
R pin = support(slot(stoneClip),solid_parts(band))
K steer = bind(pilot,aim,desired_path,eligible(band,liquid,leash),1m/s)
K base = pivot(band,slot(feed))
P fill <1s,caster> : enter Transfer.move(src,band,4kg),Couple.link(leash) | on ready -> pilot
P pilot <8s,caster> : tick independent(Drive.motion(eligible(band,liquid,leash),guided_drift,relative(base,aim)),Constrain.bind(pin)) | when changed(input(freeze_part)) => Transform.phase(selected(band,input(freeze_part)),solid,slot(coldStone)) | on release -> [Transform.handoff_world(band)] end
X pilot.hero @band.realized = ribbon/water/turn <- velocity + breath
X pilot.secondary @band.front = skin/crystal/advance <- growth + ring
```

**正例**　以下表中的“可控”指有下一步运动写权，刚提交的相变不能让原液态控制再多移动 b 一步。

| 时点 | 物质与几何 | 下一步的参照、责任及可观测结果 |
|---|---|---|
| 建成 | 槽减 4 kg，a/b/c/d 各 1 kg 液水 | 四段可达，基点为 feed；瞄点右移，实际液带在限速和截面内弯向右方 |
| 选择 b | 对 b 的稳定份额提交抽热，热汇承接相变热 | a、c、d 没有申请。选中但热未结清时仍属液水 |
| b 转固并与石扣接实 | 同一份 b 变为 1 kg 冰，3 kg 仍为水；流体不能穿过 b | b 失去液态运动写权。石扣接触提交后，c–d 的局部根可取 b；a 仍可从 feed 引导，控制线跨 b 仍有效 |
| 改瞄点 | c–d 绕实际固定点转弯，已有 2 kg 能被驾驶。b 不被瞄点拖走 | 不能从上游穿过冰再给 c–d 添加水。控制、质量、受力三笔分别可查 |
| 松手 | 停止外部引导；3 kg 水依世界流动或落下 | 1 kg 冰在自然扣合足以承载时继续留在石扣，另一术可独立借取并融化 |

**反例**　从已成冰检查点只切断控制线 b→c。c–d 虽然彼此仍由液态材料连接，却立即失去玩家写权，随后随重力和接触演化。a 仍可控，b 仍在，四段质量合计仍为 4 kg。另从选择 b 前只清空热汇，b 不结冰、不成为刚性支点，四段继续按液态控制。只移走石扣时 b 可结冰但不能成为固定的世界支点。

<a id="t13"></a>

## T13 · 遮蔽＋感应 · 同一雾中感知有限扰动

同一团真实介质同时挡住双方视线，并把实际扰动沿另一条边传回。施法者身在雾里也只能收到事先规定的粗粒度信息。

**现场与锚定**　`{水,散}→{光,藏}，{联,应}` 共同组织。窗洞横向分为左中右三区，光线通过雾额外乘 0.2，识别阈值 0.35。感知包只含区段、事件序号与采样时刻。

```text
C 水雾,光路衰减,机械扰动,有限信息
S mist = manifest(mist,patch(3,3m,2m,0deg),capture(slot(window)))
S bell = ref(slot(receiver))
R veil = optical(mist,within(mist,sightline))
K pickup = transducer(mist,impulse,0.02Ns,sector_event)
R wire = information(mist,bell,via=slot(thread),basis=pickup)
K split = topology(mist,3,serial)
K packet = bounds(wire,sector_event,4Hz)
P keep <8s,caster> : tick independent(Drive.optics(veil,0.2),Couple.sample(wire,sector_event)) | on release -> end
X keep.hero @mist.boundary(optical) = skin/mist/still <- transmission
X keep.secondary @bell.realized = core/etch/gather <- signal + ring ~0.1s
```

**正例**　起始两侧均有足够背景光，裸视透过率 1，旁路可视。采样间隔为 0.25 s。

| 时间 | 光学链 | 信息链 |
|---|---|---|
| 0 s 建雾 | 跨窗双向均得 0.2，低于识别阈值 | 分区传感器尚无扰动，无包 |
| 0.10 s 有人擦过左区 | 施法者依然认不出对面的人 | 接触给雾的冲量超过 0.02 N·s，登记左区事件一次 |
| 0.25 s 到采样槽 | 雾外不穿窗的视线不受额外衰减 | 收集左区事件，经有效通路在提交后送达。接收端知道“左区动过”，未知身份、位置坐标和移动意图 |
| 穿越者静止 | 穿雾观察仍受遮蔽 | 持续占据没有新的阈值边沿，铃不重响 |
| 撤术 | 异常遮蔽终止，余雾若尚存仅按自然光学结算 | 传感订阅关闭，过期包作废，回音不能延长感知 |

**反例**　从成雾后只剪断传感线，再让同一人擦过左区。双方跨窗识别仍受阻，接收端新包为零。从同一检查点只把来者换成能造成相同形变的无生命摆锤，收到同样的左区事件；若能分辨“敌人”，就泄漏了格式之外的信息。只绕过雾看窗外可恢复视线，不能触发穿雾扰动。
