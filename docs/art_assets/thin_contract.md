# 薄编排与资产接口契约（实验前草案）

> 状态：**实验草案（thin-contract.0.1）**。本文件刻意保持极薄，仅约定跑通 Pilot 01 及实验 A–C 所需的最小数据边界；未经过跨魔法冻结盲测前，不得将其扩张为僵硬的通用引擎框架。

## 一、`WorldLaw → Stage` 七种标准只读信号

演出层对世界状态保持**严格只读**。无论后台是剑波、引力场、冰桥还是外术干涉，世界层只向演出编排器发布以下 7 类结构化只读信号及生命周期事件：

| 信号类型 | 携带的核心数据 | 典型消费资产 | 不可逾越的边界 |
|---|---|---|---|
| **1. `AnchorPose`** | 合法参照中心 `Transform3D`、宿主实体键、局部挂点/刃线方向 | `F03 / F05 / H01 / H05` | 演出层不得反写世界位姿或碰撞坐标 |
| **2. `RealizedExtent`** | 实得半径、已推进前沿位置、合法开放扇区/遮挡裁剪掩码 | `F04 / F08 / F09 / H07 / X17` | 未到达的前沿或被墙阻挡区不得提前亮出命中边界 |
| **3. `PathGraph`** | 有界脊线采样点、有效拓扑边列表、节点状态 | `F05 / F06 / F13 / H06` | 断边之外与未授权路由不得绘制伪造脉冲 |
| **4. `MemberSlots`** | 成员稳定键、当前实时位姿、速度矢量、空槽标记 | `F10 / F02 / H01` | 缺员时槽位保留空位，不复制假实体填位 |
| **5. `ReceiptEvent`** | 真实交付点/接触点、法向、瞬时冲量、`load_ratio`（0..1）、失效掩码 | `X03 / X06 / X07 / X13 / S03 / S04 / S09` | **绝不由 `AnimationPlayer.seek()` 回调触发**；未命中不触发命中声画 |
| **6. `FieldVector`** | 场中心、有效作用方向、实付强度比 `funded_ratio` | `H07 / F15 / D01 / D03` | 区分物理加速度（`m/s²`）与纯视觉流速（`m/s`） |
| **7. `PhaseFraction`** | 真实材料份额、相变进度（`0..1`）、相变前沿位置 | `H03 / F11 / TR04 / TR06` | 视觉相变只能落后或同步于世界已提交相变 |

### 统一生命周期与退出事件

- **生命周期事件**：`enter_prepare` → `commit_active` → `tick` → `handoff`（可选局部转化/交权）→ `exit(reason)`。
- **退出原因区分**：`completed`（自然到期）、`released`（主动撤除）、`depleted`（耗尽）、`interrupted`（受击打断）、`source_lost`（宿主/来源失效）、`preserve_world`（演出退出但实物留存）。不同退出原因决定播放「溃散 / 收束 / 坠落 / 交还世界」，禁止全员线性淡出。

---

## 二、三级演出参数体系与规范化公共词表

为防止 400+ 散乱字段导致 LLM 编译幻觉与资产接错口，参数采用三级组织并收束公共命名：

1. **一级 · 艺术验证预设（`preset`）**：每个资产族自带经过人工审美验收的默认预设（如 `swift_silver`、`heavy_cleave`），模型可直接使用。
2. **二级 · 高杠杆宏观调制（Macro Knobs）**：表达跨资产共通的质感倾向——`weight`（轻锐↔沉重）、`sharpness`（雾散↔锋利）、`density`（稀薄↔稠密）、`turbulence`（平顺↔剧烈）、`contrast`（隐微↔强对比）。**声明纪律**：单个参数落在 `[0, 1]` 不保证任意双参数联合取值皆美观；资产卡须标明相容组合走廊与禁止极值，不可将其当作「全自动安全区」。
3. **三级 · 规范化精细编排词表（共 27 个公共标准键）**：

| 维度 | 规范化标准键（替代散乱别名） | 含义说明 |
|---|---|---|
| **时间与节拍** | `duration`, `delay`, `stagger`, `curve_id`, `tail_s`, `scale_tier` | 阶段总时长、局部起手延迟、成员错峰、曲线 `C01–C12`、尾韵时长、尺度档位 `T1/T2/T3` |
| **空间与尺寸** | `radius_m`, `length_m`, `width_m`, `height_m`, `span_deg`, `spacing_m`, `count` | 统一采用米制与角度制；统一收束旧 `edge_width / rim_width / width_profile` 等 13 种别名 |
| **形态与拓扑** | `thickness_ratio`, `curvature`, `taper`, `twist`, `coverage` | 厚度比、弧弯度、收尖比、扭转角、有效覆盖率（`0..1`） |
| **运动与流动** | `flow_speed`, `lag`, `phase_offset` | 独立于 `art_clock` 的纹理/流场速度、跟随滞后、空间相位偏移 |
| **表面与光学** | `distortion`, `edge_gain`, `erosion_threshold`, `load_tint`, `color_temp`, `env_weight` | 折光强度、锋缘增益、侵蚀阈值、受压变色权重、色温偏移、环境压制权重（限 `T2/T3`） |

> 资产族确需独有语义参数（如 `F08` 的 `sag` 垂度、`F16` 的 `stroke_order` 笔序）时，允许在该资产的 `spec.json` 中显式声明专有字段，但不得重复发明公共词表已有概念。

---

## 三、Godot 4.5 资产族打包与 Blender `.glb` 导出约定

1. **目录分工**：
   - `game/assets/vfx_source/<id>/`：存放 ImageGen 原创概念图、四帧分镜及未经加工的原始 2D 图层；
   - `game/art_kit/families/<id>/`：存放加工后的贴图、Blender 导出 `.glb`、Godot `.tscn` 包装场景、Shader 及资产描述 `spec.json`；
   - `tools/asset_pipeline/`：存放 Blender Python 建模脚本与纹理通道加工脚本（如去底、灰度归一化、羽化）。
2. **Blender `.glb` 统一导出契约**：
   - 原点归零，主作用前向对齐 Godot `-Z`，单位严格 `1 unit = 1 meter`；
   - **`UV0`**：用于流动贴图、侵蚀 Mask 与表面细节纹理坐标；
   - **`UV1`**：统一存储沿主体生长的归一化弧长 `u = s ∈ [0, 1]`（沿刃/沿根到梢）与横截面坐标 `v ∈ [0, 1]`（内弧到外锋），保证沿路径展锋、分段溃散与回卷无需硬编码顶点索引；
   - **`Shape Keys (BlendShapes)`**：按语义命名（如 `unfold_root_to_tip`、`arc_open`、`sweep_bend`、`edge_retract`），供资产族内部 `AnimationPlayer / AnimationTree` 平滑混合与外部 `Curve` 采样；
   - **渲染属性纪律**：按实例实际情况选择 `ShaderMaterial` 参数传递方式，不强求全员 `instance uniform`；若使用透明混合（`blend_mix`），必须启用基于深度的软交界处理并关闭无效阴影投射。

---

## 四、资产编译知识卡模板（每项资产完成后必填）

每次一个资产族通过实机验收，必须同步产出以下结构化知识条目，供后续法坛模型检索（与硬编码约束分离）：

```yaml
asset_id: F03
name: 开口弧刃
scale_tiers: [T2, T3]
artistic_intent: 清晰的开放弧形锋面、内弧留白、外弧拉锋，具备明确斩击或推进方向
suitable_for: [武器离体斩波, 沿线推开空间断缘, 触发式弧形反击]
unsuitable_for: [无方向全向感知, 长期静止结界, 无边界均匀场域]
supported_carriers: [F03具现主体, H05武器刃线派生]
supported_formations: [F03-01 沿刃展锋, F03-02 原位聚弧]
supported_motions: [M05 独立飞行, M06 动作扫掠, M07 前沿推进]
supported_endings: [F03-05 沿锋分段溃散, F03-06 沿根回卷收锋, TR02 接触解体]
appearance_packs: [P01 冷银刃光, P04 透明折光]
safe_parameter_corridors:
  duration: "0.12s–2.5s (瞬发选 C01, 蓄势聚弧选 C02)"
  span_deg: "45deg–160deg (禁止强行拉伸为 360deg 闭环)"
world_feedback_hooks: [ReceiptEvent.contact_point -> X06, RealizedExtent.front -> F03-04]
```
