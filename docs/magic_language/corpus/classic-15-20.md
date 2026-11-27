# 经典原题 15–20 · 干涉、感知与局部规律

涉及声学、远观、跨门和生命的题采用候选世界合同；是否开放给玩家另行裁决。 [共用语义](semantics.md) · [题目索引](README.md)

<a id="j15"></a>

## J15 · 反魔法场

进入局部区域时抑制已有魔法的维持关系，离开后依实际供给恢复。

**现场与锚定**　`{以太,分}→守`。外术维持悬冰和光，天然石也落入同一区；抑制能力能盖过悬浮边的余量。

```text
C 已成立魔法,支撑容量
S zone = manifest(aether,sphere(2m),capture(aim))
R cut = arcane_support(zone,support_of(within(zone,spell)))
P ward <5s,caster> : tick Constrain.suppress(cut) | on release -> end
X ward.hero @zone.boundary(arcane_support) = skin/etch/still <- progress
X ward.secondary @zone.realized = ribbon/dark/fade <- impact + breath
```

**正例**　悬浮边进入后可用容量不足，冰以同一实体下落；外术光源仅在其实际支撑也被覆盖且不足时变暗。出域仍有供给时悬浮能再次施力，已经砸出的缺角保留。

**反例**　只换成天然石，查询不到悬浮边，区域不抹除石也不影响其普通重力。外术若在受抑期间已耗尽，到场撤去后同样不会恢复。

<a id="j16"></a>

## J16 · 静止器

暂时固定已有物体，接住的外来作用入账，解锁后交付有限积蓄。

**现场与锚定**　`守→聚▷引`。2 kg 车初始静止，锚承反力，可回收撞击有功和方向。

```text
C 有限约束,可回收功,有向冲量
S cart = borrow(solid,target)
R lock = support(slot(anchor),cart)
R hitIn = force(slot(impactSource),cart)
R out = force(slot(anchor),cart)
K k = store(kinetic,cart,medium)
P hold <4s,caster> : tick Constrain.lock(lock,all_axes),Transfer.capture(hitIn,k) | on release -> [Withdraw.close(lock),Transfer.deliver(k,out),Transform.handoff_world(cart)] end
X hold.hero @cart.realized = mass/etch/strain <- fill + rumble
```

**正例**　锚保持车静止，实际储到 3 N·s 与 1 J；沿合成方向至多送出 2 N·s，车速至多 1 m/s，余反力经锚结清。

**反例**　只撤撞击源，维持约束仍付费，释放冲量为零。两次等额反向碰撞有耗散也可使合成方向储量为零。

<a id="j17"></a>

## J17 · 沉默术

区域内抑制世界声源的辐射及经过该区的声音。真实听者、警戒和区外路径随之变化。

**现场与锚定**　`{气,藏}→守`。近声源和守卫位于域内，域外另有铃与绕墙通路。世界声学采样只取有权限的可听频带。

```text
C 声源,传播路径,听觉阈值
S hush = manifest(aether,sphere(3m),capture(aim))
R src = acoustic(hush,within(hush,sound_source),mode=emission)
R path = acoustic(hush,crossings(hush,sound_path),mode=transmission)
P hold <5s,caster> : tick Drive.gain(src,0),Drive.gain(path,0) | on release -> end
X hold.hero @hush.boundary(acoustic) = skin/mist/still <- progress
```

**正例**　域内铃仍在振动，登记频带的有效辐射为零，守卫得不到听觉事件；穿域的外部声路也衰减。撤术后新发出的铃声可到达。

**反例**　只把外部铃与守卫移到同一条完全绕域的有效路径上，旁路超过阈值就能被听见。关掉玩家扬声器不会影响守卫听觉。

<a id="j18"></a>

## J18 · 侦测术

远处建立感知端点，将真实视听通过有限的奥术联系送给施法者。

**现场与锚定**　`{空,联}→{光,应}`。已知并有权定位的远处观察点、门、钟和接收者。读视锥和声学带宽，双方不能借该通道穿行。

```text
C 远端采样,有限视听
S eye = manifest(aether,body(0.05m),capture(slot(knownPoint)))
S viewer = ref(caster)
R tether = arcane_support(viewer,eye)
K distance = bounds(tether,20m)
R video = information(eye,viewer,via=tether)
R audio = information(eye,viewer,via=tether)
K rate = bounds(video,4Hz,cone(6m,25deg))
K band = bounds(audio,4Hz,audible_band)
P see <4s,caster> : tick independent(Couple.sample(video,light_frame),Couple.sample(audio,sound_frame)) | on release -> end
X see.secondary @eye.realized = core/etch/still <- signal
```

**正例**　门开时远端眼可见烛焰，钟声沿有效声路抵达同一端，两种标时样本分别送达。关门后画面只见门面，绕门仍达阈值的钟声仍可传。

**反例**　只切断 tether，后续视听包均停止。接收者不能把最后一帧当成当前现场；移走钟后也不能用配乐补出真实声样本。

<a id="j19"></a>

## J19 · 双向奥术门

两个实际入口配对，在任一端正向跨面时把同一物体及其运动状态映射到另一端。

**现场与锚定**　`{空,联}→引`。A、B 是有净空的定向门框，B 比 A 转过 90°，均固定于世界。题设允许刚体及自愿角色通过。

```text
C 空间映射,有向面,身份连续
S a = manifest(aether,patch(1,2m,1m,0deg),capture(slot(frameA)))
S b = manifest(aether,patch(1,2m,1m,0deg),capture(slot(frameB)))
R pair = spatial(a,b,mode=bidirectional)
K who = bounds(pair,rigid_or_willing,whole_body)
P passage <5s,caster> : enter Couple.link(pair) | when crossed(pair) => Transfer.cross(pair,event.subject) | on release -> end
X passage.hero @a.boundary(spatial) = skin/etch/still <- progress
X passage.secondary @b.realized = skin/etch/shed <- impact + echo ~0.2s
```

**正例**　物体以 2 m/s 进入 A，保留世界键、质量与相对速率，出 B 的方向由两端框架决定。清出 B 后主动返穿才执行逆映射。

**反例**　只在 B 放实墙，出口包络预留失败，物体留在 A 的合法侧且没有副本。超宽物体也不被切成两半送出。

<a id="j20"></a>

## J20 · 植物生长术

促进现场已有植物的真实组织生长，改变覆盖、通路与后续生态状态。

**现场与锚定**　`生→聚→引`。有活性的枝株、水、环境底物和空闲攀附架。研究权限下每个生长单元消耗一份水与一份底物，最多四单元。

```text
C 活体组织,环境来源,自然延续
S plant = borrow(living_plant,near(living_plant,2m))
R life = life(caster,plant,via=slot(rootZone))
K limit = bounds(life,4units,slot(trellis))
P grow <4s,caster> : tick Transform.advance(life,1unit/s) | on release -> [Transform.handoff_world(plant)] end
X grow.hero @plant.front = ribbon/water/advance <- growth + breath
```

**正例**　水与底物各四份时最多长出四单元新组织，覆盖增加并占据部分架面。撤术后组织仍属于原株，后续缺水可自然萎蔫。

**反例**　只把水源换成两份，至多生长两单元；只把活株换成枯木，借用缺合格目标，既不生根也不扣材料。
