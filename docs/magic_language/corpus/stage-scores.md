# 六份舞台谱 · 从动作、介质和支点出发

六个 X 块分别接到所引原题的 C/S/R/P/K。标题是文档定位，写在配方内的 `X include` 在编谱时静态内联相应块。所有 start、stop、驱动都局限于本实例。以下以 `p/enter(p)/exit(p)` 表过程、进入与退出，`commit(op,obj)` 表成功提交，`receipt(r)` 表本次关系交付，`phase(s)` 表观察到的真实相变。事件位置和法向随回执。`@local(s)` 默认读 s 的实际姿态。行内 `scope=p` 从进入到退出；跨段须明列各段。只写秒数的短音/动作按 duration 自行结束。表中各段是分镜说明，演出可因输入中途结束。[轨道和可复用艺术组](../C-stage.md)

<a id="j03"></a>

## J03 · 月刃从手腕转到远处的湿柱

[世界谱](classic-01-07.md#j03)。交付前，画面留空的是剑尖外侧；离手后，同一空处变成月牙的内弧。近身扫中的温降和远端可能结出的白边各有出处。

```text
X group @local(blade) scope=swing
  visual edge @real(blade.geometry) = contour(blade)/crystal(transmission=.72)/still ; hero
  visual after = sweep(strip(3cm),history(blade.tip,5),+Y)/dark/turn(actual_pose); tail=.09s
  body wrist = brace(weight=.12); drive=swing.progress[0.2..0.7]:smooth; stop=exit(swing)
  audio draw = breath(attack=.12s,decay=.08s); drive=blade.velocity
X group @local(wave) scope=travel start=commit(detach,wave)
  visual rim @real(wave.geometry) = contour(wave)/crystal(edge=1cm)/advance; hero; crossfade=.07s
  visual veil = mirror(sweep(strip(2cm),history(wave,4),+Y),local_XY)/mist/step_fade; tail=.30s
  audio departure = ring(attack=.012s,decay=.18s); start=commit(detach,wave)
  camera pass = reframe(weight=.06,duration=.12s); start=enter(travel)
X environment deposit @real(phase(surface_water).position) = contour(changed_part)/crystal/thin;
  while=observable; start=phase(surface_water) caused_by=receipt(chillA|chillB); tail=0
X use knock(contact(wave),room) @real(contact(wave).position) scope=travel
```

| 观察点 | 玩家可见或可听的差别 |
|---|---|
| 挥过、尚未交付 | 低声与薄边沿手走。近物的水膜若已相变可以白，走廊深处依然空。 |
| 离手或同刻打断 | 只有成功离刃才有第二轮廓和短促高音。转身只带走手部姿态。 |
| 擦过干柱或撞上湿柱 | 干柱可有实际撞声，冻结需附着水和潜热。未碰到时只剩稀薄轨迹。 |

<a id="j04"></a>

## J04 · 迟行的暗火核

[世界谱](classic-01-07.md#j04)。蓄力时高亮藏在小核的三处缺口；靠近合格对象时壳的剪影只散开一次。松手把火核送上路，爆发另等真实近距事件和分流提交。

```text
X group @local(core) scope=kindle|creep
  visual rind = shell(.40m,.035m)/ember(roughness=.9,emission=.10)/still; hero
  use ribs(core,.44m,fill(fuel)); secondary
  visual fissure = repeat(arc(+Y,.38m,15deg),3,yaw(120deg))/ember/turn(fill(fuel),16deg);
    drive=fill(fuel)[.30..1]:ease_in→emission[.05,.8]
  audio ember = rumble(attack=.21s); drive=fill(fuel); stop=exit(creep); tail=.12s
  environment rake @scene(floor) = grazing_projection(rind,reach=1m); scope=creep; opacity=.08
X visual burst @real(receipt(push).position) = radial_strokes(6,length=.4m)/etch/shed;
  start=receipt(push); duration=.12s; hero
X audio vent @local(core) = breath(attack=.01s,decay=.22s); start=commit(split,fuel)
X camera recoil = reframe(weight=.07,duration=.09s); start=receipt(push); require=visible
X environment coals @real(ignition.position) = contour(ignition.patch)/ember/advance;
  start=world.ignition caused_by=receipt(hot); stop=world.extinction; owner=world_material
```

蓄得越满，壳缝越清楚；火核缓行时地面的掠光只交代离地距离。目标被带离近距就只有迟行和熄暗。若热被湿石吸收，热交付仍可发生，地面没有持续的火。若油迹着火，后续火光归世界燃料与氧气控制。低档去掉掠光，保留核的剪影与真实冲击拍。

<a id="j05"></a>

## J05 · 暗月内的空与外部三个作用

[世界谱](classic-01-07.md#j05)。负空间由暗核、偏轴环与薄雾壳围出来。登高、远景、真正的消光、抽热和悬托失效各有独立条件。

```text
X group @local(moon) scope=form|glide
  visual globe @real(moon.geometry) = contour(moon)/dark(roughness=.85)/still; hero
  visual vapor = shell(.96m,.08m)/mist(transmission=.82)/turn(progress(form),18deg);
    drive=fill(size)[0.2..0.8]:ease_out→opacity[0,.28]; latch=exit(form)
  use ribs(moon,1.05m,progress(form)); latch=exit(form)
  audio undertone = rumble(attack=.35s,decay=.24s); drive=moon.velocity; tail=.24s
X environment omen @scene(visible_sky|vault) = annulus(3m,3.4m)/dark;
  scope=form; drive=fill(size)[.55..1]:ease_in→opacity[0,.16]; tail=.45s
X visual limb @real(shade.boundary) = contour(shade)/dark/advance; while=active(shade); tail=0
X camera framing @local(moon) = reframe(weight=.05,duration=.3s); start=enter(form); require=free_view
X use knock(contact(moon),room) @real(contact(moon).position) scope=glide
X audio depart @local(moon) = ring(decay=.25s); start=commit(detach,moon)
X body rise = brace(weight=.1); while=receipt(rise); stop=exit(form)
X environment frost @real(phase(surface_water).position) = contour(changed_part)/crystal/still;
  start=phase(surface_water) caused_by=receipt(cold); owner=world_material
X visual loose @real(suppressed_edge.position) = short_stroke(5cm)/etch/fade;
  start=receipt(dim) where=edge_lost; duration=.12s
```

先读到手上暗圆，再见偏轴环遮过圆缘；过半才允许穹顶渐暗。form 末拍锁定交付扣账前的壳雾外观。放出时音高落下，轮廓随真实月体掠行。热汇撤掉只影响热通道及霜；普通冰没有悬托边可松。室内无穹顶适配时远景关闭，局部消光仍可测。镜头保持自由，远景不扩大视线阻断范围。

<a id="j07"></a>

## J07 · 旋风的空轴与受力方向

[世界谱](classic-01-07.md#j07)。蓄势时先给稀疏的柱形尺度，交付后用同一组离轴探针把三分量画清。实心白柱会挡住判断旋向的两条侧缘。

```text
X visual mouth @local(f) = layer(annulus(.22m,.30m),mirror(arc(+Y,.4m,80deg),local_XY))
    /mist(transmission=.88)/gather; scope=chant; hero; drive=fill(reserve)→scale[1,3]
X audio inhale @local(f) = breath(attack=.22s); scope=chant; drive=fill(reserve); tail=.08s
X visual bounds @real(spin.boundary) = contour(f)/mist/still; scope=hold; while=active(spin)
X visual threads @real(spin.boundary) = stream_samples(ring_sites=6,max_steps=8,channel=spin)
    /mist(edge=2cm)/advance; scope=hold; hero; crossfade=.12s; tail=0
X environment dust @real(receipt(spin).position) = history(visible_affected_body,4)/slate/shed;
    start=receipt(spin); duration=.15s; require=loose_visible_material
X audio shear @local(f) = rumble(attack=.15s); scope=hold; drive=fill(reserve); tail=.28s
X camera scale = reframe(weight=.05,duration=.25s); start=enter(hold); require=whole_column_visible
```

门楣给高度尺度，近侧条带的弯向给旋向。`stream_samples` 沿提交的力场取有限方向线，只画方向；尘屑与物体位置要读实际运动。去掉轴向后方向线平绕，已有向上速度的石仍可能继续上升；反转切向后两侧条带反向，径向内吸仍在。蓄势被打断，只有呼吸尾声。

<a id="j09"></a>

## J09 · 一座可踏、会失去支点的石桥

[世界谱](classic-08-14.md#j09)。最亮的部位只有最前一条湿石断面。观者先看见缝变窄，再听到远墩接合，才有理由把跨空石条当成两端承重的桥。

```text
X visual tread @real(slab.geometry) = contour(slab)/slate(roughness=.82)/still; scope=lay
X visual lip @real(slab.front) = sweep(strip(2cm),front(slab),+Y)/etch/advance;
    scope=lay; hero; drive=growth(slab)→phase[0,1]; tail=0
X visual joint @real(load.geometry) = contour(loaded_seams)/slate/strain;
    scope=lay; drive=load[.65..1]:ease_in→emission[.04,.48]
X environment grit @real(slab.front) = short_strokes(5,2cm)/slate/shed;
    start=commit(grow,slab); limit=3; duration=.18s
X audio abrade @local(slab.front) = rumble(attack=.14s); while=advancing(slab); tail=.14s
X use knock(joined(frame,pierB),room) @real(joined(frame,pierB).position) scope=lay
X body weight = brace(weight=.09); while=load>.65; scope=lay
X visual breakline @real(world.break.position) = contour(broken_seam)/slate/shed;
    owner=world_material; start=world.break(slab); duration=.16s
```

同一秒内前沿受阻时，静止的真实断面仍可见，磨石声衰减，搭上对岸的声响不会发生。若放手前已接实，原石的接缝继续承重；放手后过载，世界的局部碎裂表现跟着原石下落，施法镜头和建造声已经结束。低档可去砂粒，留前沿、已有踏面和真实负荷读数。

<a id="t03"></a>

## T03 · 局部冻结的水带

[世界谱与四份材料的去向](focus.md#t03)。保留带身的连续剪影，用短而硬的横纹区别冰和以它为支点继续转动的液尾。瞄点可移动；点中、开始抽热、结成冰和扣住是四件事。

```text
X visual ribbon @real(band.geometry) = sweep(disk(4cm),real_centerline(band),+Y)/water/turn;
    scope=fill|pilot; hero; drive=actual_flow(band); tail=0
X visual mark @local(aim) = arc(+Y,.08m,50deg)/etch/still; while=valid(freeze_pick);
    opacity=.22; scope=pilot
X visual crystals @real(phase(band).position) = repeat(strip(1cm),3,step_along(2cm))
    /crystal(transmission=.56)/advance; start=phase(band,solid); duration=.22s; hero; crossfade=.07s
X audio cooling @real(phase(band).position) = ring(attack=.012s,decay=.19s); start=phase(band,solid)
X use knock(joined(pin),room) @real(joined(pin).position) scope=pilot
X environment glint @scene(floor) = projection(real_centerline(band),reach=.4m)/water;
    scope=pilot; drive=actual_flow(band)→opacity[0,.14]
X visual wet @real(band.geometry) = contour(liquid_parts)/water/advance;
    scope=pilot; while=control_reachable; secondary
```

热汇不足时只留下瞄准小弧，液尾仍随控制走。冰已成而石扣缺失时有冰响，没有扣合声。切断 b→c 控制后，c–d 仍是可见水，只失去跟随驱动的次轨；它受重力的位移留在主轮廓。松手关闭瞄准、跟随及投影；原位冰、水材质随世界身份留存。低档保留液带和冰的截面差异。

### 读谱边界

谱内 `history` 至多读给定个数的已实现样本；`front` 与 `contour` 取可见的几何边界。`projection / grazing_projection` 只在可见合法场景面投映有限构图。`short_strokes / radial_strokes` 是 A7 的短线重复与径向排列；`step_fade / advance / shed` 为 C1 的有界运动/透明包络。`while=receipt` 仅覆盖有实际交付的区间；每个持续关系按已提交状态拆区间。`latch` 只在指定边界锁最后一个本地艺术参数。`owner=world_material` 声明把一次已获许可的材料外观交给世界已有材料表现，后续由世界的可见材料与自然事件驱动，施法实例退出即注销私有订阅。无模块、表面或权限时跳过可选轨。受体相变、点火和支撑失效，分别从材料更新、燃烧和关系提交取回执；尚无相应领域能力时读作待实现。六谱是人工分镜与读谱证据，艺术资产与实机观感待验证。
