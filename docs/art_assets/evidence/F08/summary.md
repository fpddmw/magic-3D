# F08 开放幕面 · 独立资产验货记录

在 Godot 4.5.1、Metal Forward+、Apple M6（Apple9）与 Jolt 3D 上录制。三份 JSON 使用同一个大殿入口、同一个 F08 场景和同一条运镜。承重配方记录到 154 个幕面接触物理帧。遮蔽配方记录到 0 个。五段族内动画的 30 组中断试验均保持了切入瞬间的形态。人工审美评议待签收。

## 先看实机

| 配方、影片 | 同条件观测 | 求解器与动画日志 |
|---|---|---|
| [V1 承重光幕](v1_load.mp4) | 石块于 2.45 s 从 z = +3.15 m 飞入。3.15 s 首次接幕，冲量向量约为 (−1.30, 1.55, 1.87) N·s。石块被挡住，沿幕面下滑，质心 z 最小值为 +0.296 m。接触期间负载为 0.70，X13 随接触点迁移。间歇脱离时回到 0。 | [V1 记录](v1_load.trace.json) |
| [V2 遮蔽暗幕](v2_occlude.mp4) | 使用同一块石头、同一初速、推力和重力。石块从幕前穿到幕后，末帧 z = −10.890 m。幕面接触帧、负载峰值和回弹权重均为 0。 | [V2 记录](v2_occlude.trace.json) |
| [V3 地面升幕与收帷](v3_ground.mp4) | 平展构形沿接地根线升起，0.48–3.15 s 开启低位压尘。3.55 s 主动撤除时，升幕形态键仍保留 0.1182 权重。收帷从该值进入，切入跳变量为 0，最后沿原根线闭合。 | [V3 记录](v3_ground.trace.json) |

影片均为 H.264、1920 × 1080、30 fps、6.00 s、180 帧。物理以 60 Hz 运行，日志每三个物理帧采样一次，并额外记录负载变化。影片末尾裁去了 Movie Maker 的终止帧。[大殿关键帧](f08_hall_keyframes.jpg) · [媒体与场景核验](verification.json)

## 中性验货台

| 图板 | 读图方式 |
|---|---|
| [灰模](f08_gray_review.png) | 上下两排分别为开放弧幕、平展幕。依次为正视、侧视、背视和斜视。全图使用同一无贴图、无发光的灰材质与正交尺度。 |
| [表现包和 X13](f08_viewer_modes.png) | 上排比较 P19、P04、P03。后方细柱和横尺给出透射及折光的参照。下排有实测 0.70 的全景、P04 柱棱局部和 X13 接触局部。 |
| [打断承接](f08_interrupt_check.png) | 每行一段动画，每组三格为源相位、转裂解后 420 ms、转收帷后 420 ms。25%、55%、85% 三处各走两个出口。近收尽的幕面在打断后维持其剩余尺度。 |
| [裂纹阈值](load_crack_thresholds.png) | 在最终单通道 Mask 上二值化。0.25、0.55、0.80 阈值的覆盖率分别为 1.98%、0.87%、0.31%。三个阈值为离线自检值。 |

中性台的 0.70 来自限位石块与原网格碰撞体的真实 Jolt 接触。中断图板的 F08-04 行冻结该物理快照，两条出口从同一视觉时钟和负载重新采样，测量交接后卸载。30 组的形态向量、侵蚀或回弹权重最大切入偏差为 0，每条出口内的独立艺术时钟均前进 0.42 s。另将快照中的正负载送入 P03，实际接收值为 0。[中性台逐例数据](bench.trace.json)

## 资产和输入

下列路径均相对于仓库根目录。各资产同时附有 Godot 需要的导入设置和脚本 UID。

| 目录 | 产物 |
|---|---|
| [ImageGen 原稿](../../../../game/assets/vfx_source/F08_open_veil/) | `concept_source.png` 为庄严石殿幕面概念，`flow_source.png` 为经纬织纹，`erosion_source.png` 为纵向裂解图层，`crack_source.png` 为中心应力分叉图层。`.gdignore` 将原稿留在制作侧。 |
| [离线管线](../../../../tools/asset_pipeline/) | `process_f08_textures.py` 加工线性通道和阈值图，`build_f08_mesh.py` 在 Blender Python 中构造载体与形态键，`build_f08_stone.py` 构造验货石，`build_f08_evidence.py` 检查采样、视频和导入数据并排版实机截图。 |
| [资产族](../../../../game/art_kit/families/F08_open_veil/) | `F08_open_veil.glb`、`F08_open_veil.tscn`、`veil.gd`、`veil.gdshader`、`rise_curve.tres`、`B03_dual_open.tres`、`spec.json`。五段可寻址的 Animation 位于场景的 AnimationLibrary。 |
| [加工贴图](../../../../game/art_kit/families/F08_open_veil/textures/) | `veil_flow.png` 的 RG 为编码方向、B 为纤维密度。`veil_erosion.png` 与 `load_crack_mask.png` 为独立灰度 Mask。三张均为 1024 × 1024，按数据纹理采样。 |
| [隔离验货场景](../../../../game/art_lab/f08/) | `bench.tscn`、`bench.gd` 为中性台，`hall.tscn`、`hall.gd` 为大殿，`lab_setup.gd` 布置验货道具、碰撞与压尘。`keystone.glb`、`stone.gd`、`limestone.gdshader` 组成带接触回执的刚体石块。 |
| [纯 JSON 配方](../../../../game/art_lab/f08/recipes/) | `v1_load.json`、`v2_occlude.json`、`v3_ground.json` 给出构形、表现包、片段时序、曲线、碰撞、石块、压尘和 B03 相位。 |

两个构形各有 8,584 个顶点、17,156 个三角形、两套完整 UV。两者的三角索引及 UV 数组逐项相同。Blender 源以米为单位，节点原点为零，作用前向为 −Z。UV0 供流场、侵蚀和接触裂纹的局部纹理坐标使用。UV1.x 从左侧缘到右侧缘，UV1.y 从根线到幕冠，范围都是 0–1。根线下摆预留 12 mm，V3 的锚点下移 12 mm 对齐大殿地面。

两个构形均保有 `unfold_from_line`、`rise_from_ground`、`load_bulge`、`fracture_open`、`retract_to_root`。族内入口 `enter(clip, seconds, curve)` 接受外部 Godot Curve。F08-05 在原有展开尺度上撕开局部，F08-06 接续当前宽度和侵蚀状态。着色器用场景深度软化交界，P04 在读取偏移背景前检查遮挡深度。

B03 是可复用的骨骼动画，取样于只读的 `astronomer.glb`。双手间距由收拢时约 0.32 m 增至约 1.31 m。大殿入口只读实例化仓库的 `stage.gd`。验货配方在幕面完全展开后启用承载碰撞。遮蔽配方停用幕面碰撞形状，P03 材质入口也会丢弃残留正负载。

本次用 7 kg 测试石和 10 kg 额定容量标定 `load_ratio`。求解器须先报告石块与指定幕面的接触，演出层才读取该比值和世界接触点。冲量向量另存于日志。影片中的受压回弹来自接触期间的局部形变，动画寻址只改变表现。

## 复验

从已有 Godot 4.5.1 导入缓存的隔离工程副本运行。以下示例中 `F08_GAME` 为该副本的 game 项目路径，`F08_SHOTS`、`F08_OUT` 为绝对输出目录。制作时使用 Blender Python 4.3.0、NumPy 和 Pillow。

```sh
godot --path "$F08_GAME" --rendering-driver metal res://art_lab/f08/bench.tscn -- --shots="$F08_SHOTS"

for v in v1_load v2_occlude v3_ground; do
  godot --path "$F08_GAME" --rendering-driver metal --fixed-fps 30 \
    --write-movie "$F08_OUT/$v.avi" res://art_lab/f08/hall.tscn -- \
    --recipe="res://art_lab/f08/recipes/$v.json" --observations="$F08_OUT/$v.trace.json"
  ffmpeg -i "$F08_OUT/$v.avi" -an -frames:v 180 -c:v libx264 -crf 18 \
    -pix_fmt yuv420p -movflags +faststart "$F08_OUT/$v.mp4"
done
```

将三份 MP4 和对应 trace 放入本证据目录后，在仓库根目录运行 `python3 tools/asset_pipeline/build_f08_evidence.py "$F08_SHOTS"` 可重建四张实机图板并复查 30 组交接。三次录像和中性台的最终运行均无脚本或着色器错误。Metal 报告一次采样器 LOD bias 不受支持的驱动提示。

## 待审

- **人工审美**　请对照灰模侧视与暗殿影片，评议 P19 的幕缘亮度、P03 暗区褶皱的可读性，以及 V3 的压尘尺度。
- **玩法接入**　承载容量、石块推力和开关时机是本验货台的标定值。正式世界回执、连续变化负载和中途撤除承重面的玩法处理仍待集成验证。
- **性能与玩家证据**　本次记录覆盖单台 M6 的实机画面与固定步长物理。1080p 实时 60 fps、中端独显显存预算及玩家辨读仍待单独测量。
