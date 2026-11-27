# 八组原创构筑 · 施法以后还能做什么

**历史初稿。** 保留第一次研究的构思与反事实。活动谱及本轮修订以[集中审阅入口](README.md)为准。

这组题目从废城里的具体需要出发。使用与[经典册](classic.md)完全相同的记法和接口。八个意向共九份完整谱，其中 O2 将两次施法拆开，O3 的第二个锚点另给出精确替换式。每项列出可使预期落空的现场变化，供集中审阅时独立推演。现阶段均为设计证据。

## O1 · 运送灯火的风渡

图 `{气,引}→{土,守}`，对外持续。「守」要使载物板承重，「引」只给有质量的板一个有限运动目标。需要把石板上的油灯送到对岸而不撞碎它。靠操作者的有限升力抵住重量，板与灯通过真实接触传力。

```text
C 固体承载,定向空气作用
S raft = borrow(stone,slot(slab))
S lift = manifest(air,column(1m,1m,0.8m),live(raft))
R air = force(lift,raft,via=slot(hallAir))
R deck = support(raft,within(lift,movable))
K steer = bind(carry,aim,desired_position,raft,1.2m/s)
P carry <6s,caster> : tick Drive.field(air,v(0,0,1)),Drive.motion(raft,guided_drift,aim),Constrain.support(deck) | on release -> [Transform.handoff_world(raft)] end
X carry.hero @raft.realized = mass/slate/advance <- velocity + rumble
X carry.secondary @raft.realized = skin/etch/strain <- load[0.7..1]:ease_in + crack
```

瞄点在 1 秒内跳到 5 m 外，板在该秒最多行进 1.2 m。升力与引导通过现场空气交换动量；若没有合格介质，只余真实板材与载荷。碰墙后板停在墙前，上面的灯按惯性可滑落。追加负荷若超过升力，板开始下沉；减去载荷则可继续渡运。反事实只把引导速率改低，位移上限随之降低，同样接触时材料和板的身份不变。该结构也能搬运别的法术留下的物体。

## O2 · 冰阶借水，第二位施法者来收水

同一个世界里**两次独立施法**。第一人的图 `水→引▷守`，锚定借出实际水量封成可踩冰阶。第二人的图 `{水,逆}▷引`，锚定从眼前已有的冰取水归壶。现场预置有容积的阶槽、冷石热汇和一段可计量 2 kg 的水源。阶槽上的水份可形成独立实体，成形前仅有自然槽底承载。

```text
C 水,冰,冻结排热
S source = borrow(water,slot(cistern))
S step = derived(source,patch(1,0.5m,0.3m,0deg),capture(slot(stepMould)))
P fill <1s,caster> : enter Establish.open(step),Transfer.move(source,step,2kg) | on ready -> freeze
P freeze <2s,caster> : enter Transform.phase(step,solid,slot(coldStone)) | on ready -> [Transform.handoff_world(step)] end
X fill.hero @step.front = skin/water/advance <- growth
X freeze.hero @step.realized = skin/crystal/gather <- growth + ring ~0.25s
```

```text
C 冰,水,融化取热
S ice = borrow(ice,near(ice,2m))
S jar = ref(slot(jar))
P thaw <2s,caster> : enter Transform.phase(ice,liquid,slot(warmStone)) | on ready -> collect
P collect <1s,caster> : enter Transfer.move(ice,jar,all) | on ready -> end
X thaw.hero @ice.front = skin/water/advance <- growth + breath
X collect.secondary @jar.realized = mass/water/gather <- fill ~0.15s
```

| 纸面检查点（整份转移） | 水源 | 冰阶位置 | 接收壶 | 身份与责任 |
|---|---:|---:|---:|---|
| 第一术入场 | 2 kg | 0 | 0 | 水源份 L，可分 |
| 借水、凝固、第一术完全退出 | 0 | 2 kg 固态 | 0 | 若整份转移就沿用 L，若从较大来源分份则记录子份 L₁→L。实体为 E。E 的世界键与物理实体跨撤术保持 |
| 第二术从近场重新取得 E，原位融化 | 0 | 2 kg 液态 | 0 | 新施法键、新控制句柄，材料份与 E 都相同 |
| 转入壶后 | 0 | 0 | 2 kg | L 的接收位置记为壶；空载体按世界规则清理 |

反事实从第一术已退出的检查点分叉，把 E 搬至 3 m 外并保证附近没有别的冰，第二术得 missing_target，壶增量为零，2 kg 仍在 E 上。有另一块冰时「近处冰」可合法命中另一块，审阅者必须对照份额键再判定是否复用成功。暖石热量不足时整份融化申请失败，壶同样不增量。阶槽、热汇、容器提供的是现场成立条件。

## O3 · 烟帘守窗，同一图的两种「守」

共同图 `{水,散}→{光,守,应}`，对世界留存。题目是「守住药房的破窗」。甲锚定阻挡辨认，真实光路变差；乙锚定有人过窗才通知，允许通视。乙把光作为窄窗的光学采样介质，扰动由实际遮断读出，双方各只有一个主要世界后果。这是一组主动改锚的姐妹配方，以下在同一谱上给出单点替换。

```text
C 水雾,光路采样,有限信号
S screen = manifest(mist,patch(2,1.4m,0.8m,0deg),capture(slot(window)))
R view = optical(screen,within(screen,sightline))
R wire = information(screen,slot(bell),via=slot(lightBeam))
P keep <5s,caster> : tick Drive.optics(view,0.2) | on release -> end
X keep.hero @screen.realized = skin/mist/still <- progress + breath
```

乙把 keep 的 tick 整项替为 `Couple.relay(wire,beam_break)`，其余声明不动。未使用的关系不建立。甲的「应」取作雾面对穿窗光线的实际衰减响应；乙的「守、应」取作限定端口收到越窗事件。前提是两解都符合玩家原先尚未钉死的「守」，明确锚定遮蔽后不能静默替换。

同一人在窗前穿过，外部光线稳定。甲的额外透过率为 0.2，钟无新信号；乙保留雾材自身的自然透过率，只有真实遮断光束才向钟发一个粗粒度事件。破坏光束，乙不报警，甲仍能遮挡。两者可以用完全相同的舞台轨；法坛必须从实际 tick 读出区别。

## O4 · 用楼梯落石给升降架攒一次起步

图 `{土,守}→藏▷引`，对世界留存。落石到铁盘时把可以回收的功存入现场绞盘，听候松手用于提升另一处小吊篮。与 C6 复用同一 capture/deliver，改变受体、储备所有者和反力来源。

```text
C 实体承载,碰撞回收,有向机械传递
S pan = borrow(solid,slot(tray))
S winch = ref(slot(winch))
S cage = ref(slot(basket))
R catch = support(slot(pillar),pan)
R intake = force(slot(fallingStone),pan)
R lift = force(winch,cage,via=slot(rope))
K k = store(kinetic,winch,medium)
P save <5s,caster> : tick Constrain.support(catch),Transfer.capture(intake,k) | on release -> [Transfer.deliver(k,lift)] end
X save.hero @pan.realized = mass/slate/strain <- load + rumble
X save.secondary @winch.realized = ribbon/etch/gather <- fill + ring
```

绞盘与有效绳路把输入方向映射到吊篮向上轴，固定支座承担反力。现场这段绳路只在张紧时有资格。取 2 kg 空篮，登记输出轴冲量上限 2 N·s、可用功 2 J，则瞬时起步速度上限 1 m/s，后续按重力和真实绳张力演化。切断绳路后，同样落石仍可入账，释放不能远程推篮。把空篮换成更重的篮，预期速度变小，机械功不会随用途复制。

## O5 · 水渠中的验线灯

图 `{水,联}→电▷{光,应}`，在泵房查一条铜线究竟有没有接到泵口。沿同一条湿渠铺有限导电通路，泵口灯只接受真实电交付引起的信号。渠边拐弯不应被直线视距截断。

```text
C 导电,水路,有限反馈
S wet = borrow(water,slot(channel))
S lamp = ref(slot(indicator))
R current = electric(slot(cell),lamp,via=wet)
R notice = information(lamp,slot(receiver))
P probe <3s,caster> : tick Drive.charge(current),Couple.relay(notice,delivery)
X probe.hero @wet.realized = ribbon/water/still <- progress
X probe.secondary @lamp.realized = core/etch/gather <- signal + ring ~0.1s
```

电池、可导水段、灯和回流端构成完整回路时，泵口才实际受电，接收端最早下步获得相应通知。挪走一段水后，电和通知一起停止；墙挡住泵口时，只要端口、回路与信息边仍有效，交付继续。有平行铜旁路时断水也未必断电，须明确 via 指向的导电图是否包含该旁路。换成无光学输出的同类受电器仍可收到电，读解不得承诺它会照亮泵房。

## O6 · 寄托在屋架上的裂口哨

图 `{土,守}→{以太,藏}▷应`，对世界留存。修缮者在屋架留一个有限哨点，能腾出手去别处施法。屋架自然承重；哨点关心的是哪一跨实际破裂。

```text
C 自然承重,寄托账户,有限事件
S beam = ref(slot(roofSpan))
S seal = manifest(aether,body(0.1m),live(beam))
K fund = store(mana,seal,small)
R wire = information(beam,slot(bell),via=seal)
P deposit <2s,caster> : enter Establish.open(seal) | tick Transfer.move(caster,fund,all) | on release if ready(fund,0.25) -> [Transfer.handoff(seal,fund)] listen
P listen <6s,fund> : tick Couple.relay(wire,break) | on signal(wire) -> end
X deposit.hero @seal.realized = core/etch/gather <- fill
X listen.secondary @beam.realized = skin/slate/strain <- load[0.8..1]:ease_out
X listen.director @beam.realized = none/none/still <- signal + crack ~0.35s
```

修缮者走开后，listen 只从 fund 实付。足额时屋架超载断裂，铃只获一次所属跨度的破裂信息，之后本术退出。将断裂推迟到储备耗尽之后，屋架仍然断，铃不响。移除哨点也不改变屋架的自然承载能力。若同一人此时不能另施一术，说明局部契约没有真正交接。

## O7 · 拆去临时托架，用原石补一处拱脚

图 `{以太,分}▷{土,联}`，对世界施放。在修复断拱前先撤除外术对松动楔石的悬托。只在楔石实际落入拱脚接合槽、且具备材料取用权时，才用它修接缝。借力与修结构是前后两个因果条件。

```text
C 可干涉支撑,同质石料,接缝修复
S stone = ref(slot(wedge))
S arch = borrow(stone,slot(arch))
S recess = ref(slot(socket))
R unpin = arcane_support(recess,support_of(stone))
R seam = support(arch,recess)
P free <1s,caster> : enter Constrain.cut(unpin) | on ready -> wait
P wait <3s,caster> : on contact(recess) -> mend
S supply = borrow(stone,slot(wedge))
P mend <1s,caster> : enter Transform.repair(seam,supply) | on ready -> [Transform.handoff_world(arch)] end
X free.secondary @stone.realized = mass/slate/shed <- break + breath
X wait.hero @recess.realized = skin/etch/still <- progress
X mend.hero @arch.front = skin/slate/advance <- growth + crack ~0.2s
```

只要术可干涉且足以切断，旧悬托先失效，楔石以原身份下落。掉进正确槽、质量足够且断口对齐时才扣楔石相应份额、接上一条自然受力边。把槽挪开 0.5 m，楔石落地却没有后半段修补，拱仍断。其他碎屑提前碰槽最多唤起一次修复检查，未对齐的楔石不能被远程消耗。旧术若显式保有对石的排他取用权，新术的借用同样失败。切断支撑本身不会转移财产权。

## O8 · 两扇都落座才能合缝的闸盖

图 `{土,分}▷{引,联}▷守`，对世界留存。希望用一块成对浇铸、有预制断缝的石盖封住旧渠。初始两片被卡在高处，需要沿各自有导轨的槽送到下方接合位置。若只有一片落座，施法者不得看到「闸盖已合」。两个座的设计位置保证两片都到时接缝相邻。闸盖是否止水最终取决于真实占位与缝隙。

```text
C 有限石份,实际接缝,自然承重
S blank = borrow(stone,slot(scoredCover))
S l = borrow(stone,piece(blank,0))
S r = borrow(stone,piece(blank,1))
S grout = borrow(stone,slot(chips))
R seam = support(l,r)
P part <1s,caster> : enter Transform.fracture(blank,slot(seam)) | on ready -> fork(left,right)
P left <3s,caster> : tick Drive.motion(l,guided_drift,slot(leftSeat)) | on contact(l,slot(leftSeat)) -> finish | on timeout -> abort
P right <3s,caster> : tick Drive.motion(r,guided_drift,slot(rightSeat)) | on contact(r,slot(rightSeat)) -> finish | on timeout -> abort
P finish join(all,left,right) <1s,caster> : enter Transform.repair(seam,grout) | on ready -> [Transform.handoff_world(l),Transform.handoff_world(r)] end
X left.secondary @l.realized = mass/slate/advance <- velocity + rumble
X right.secondary @r.realized = mass/slate/advance <- velocity + rumble
X finish.hero @l.realized = skin/etch/gather <- impact + ring ~0.25s
```

两瓣来自同一父份，初始断缝分配的质量之和等于原石盖。若左片先落座，它停在真实槽底，控制权暂存在汇合处，右片稍后落座才消耗碎石接边。右轨受阻超过 3 秒则汇合失败，全部句柄结清，已落座的左片原位留存，碎石未扣；未抵达的右片也不瞬移回出发点。若两片到位但碎石已被搬走，修复事务失败，两片仍可被别的术重新利用。此题把 C4 的承重条件与 O7 的修复条件用于一个需要并行会合的新结构。
