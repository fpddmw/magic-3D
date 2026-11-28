# 雨殿

用 Godot 4.5.1 打开本目录的 `project.godot`，等待首次资源导入，按 F6 运行打开的主场景或按 F5 启动游戏。项目以 Forward+ 和 Jolt 运行。

| 操作 | 按键 |
|---|---|
| 移动、转向、格挡 | WASD、鼠标、Shift |
| 翻滚、近战 | 空格、鼠标左键 |
| 切换配方 | Q / E |
| 进入构筑已保存的施法过程、松手 | 按住、松开鼠标右键 |
| 在起点石坛恢复魔力 | 结束施法后按 R |
| 切断或接回身边水渠的边 | 靠近渠段按 F |
| 释放鼠标 | Esc |

初始选中压风。右键持咒至蓄力条超过五分之一，朝石块松手。换到投石留形，松手后走近那块石头，仍可用下一个构筑推动它。雨殿西侧有四段水渠，切断中间的边可比较相变和导电的范围。Q/E 也可载入独立模型生成的构筑及其反向对照。

[配方、计费表与准入目录](data/magic_v0_3) · [构筑、实机与性能验收](../docs/v0.3/雨殿切片.md)

## ArtLab

在雨殿按 **F8** 进入「天体降临」研究场景。首版已交审，负责人要求重做月体成形、角色动作与交付重量、场景尺度与整体构图。三机位、图层与带声音的连续镜头使用同一版资产。[审阅入口](../docs/art_research/reference_breakdowns/01_celestial_descent.md)

| 操作 | 按键 |
|---|---|
| 暂停或继续；前后各走一个 60 Hz 采样步 | 空格；← / →。拖动底部时间条可跳到指定时刻 |
| 主机位、材质特写、建筑远景、侧面、背面 | 1–5；按住鼠标右键拖动可绕看 |
| 独立切换核心、包络、光带、星屑 | Q / W / E / R |
| 切换石殿和暗穹；双人错时施法 | O；D |
| 在交付前强制打断；从当前时刻移动转身 | I；T |
| 单独检查六种骨骼姿态；隐藏界面 | P 循环；H |
| 生成图板与测量记录；返回重新载入的雨殿 | C 写入 Godot 用户数据目录下的 `art_lab/`；Esc |

从仓库根目录复现。把 `godot` 换成本机 Godot 4.5.1 可执行文件。首次运行先导入资源；电影与抓拍分别运行。电影的固定输出帧率用于比对动作时点。

```sh
godot --headless --editor --path game --import
mkdir -p .local/art_lab
godot --path game --rendering-driver metal res://art_lab/workbench.tscn -- --lab-capture="$PWD/.local/art_lab/frames"
godot --path game --rendering-driver metal --fixed-fps 30 --write-movie "$PWD/.local/art_lab/cast.avi" res://art_lab/workbench.tscn -- --lab-film --lab-turn
python3 tools/art_assets/plates.py .local/art_lab/frames .local/art_lab/plates
```

模型、烘焙贴图、五条声音素材均已提交，直接运行只需 Godot。需要重新制作资产时，`tools/art_assets/tailor.py` 用 NumPy 输出带权重的人形 GLB，`bake.py` 用 NumPy、SciPy、Pillow 从三张源图和固定随机种子生成材质数据与声音。月面、蚀刻、岩纹和外景天空采用生成图像，烘焙源图与天空成品随仓库保存。图板发布脚本只需要 Pillow。
