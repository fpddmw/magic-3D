"""Compose Godot captures and verify the recorded experiment. Pillow >=10."""
import argparse
import json
import shutil
import subprocess
from io import BytesIO
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs/art_assets/evidence/F08"
BACKGROUND = "#202227"
POINT = "#d9c6a2"
TEXT = "#e8e6e2"
MUTED = "#b8b8b8"
GAP = 12


def font(size):
    for path in ("/System/Library/Fonts/STHeiti Light.ttc",
                 "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc"):
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    raise RuntimeError("Install a CJK typeface for the review captions")


class Plate:
    def __init__(self, width, height, title, detail):
        self.im = Image.new("RGB", (width, height), BACKGROUND)
        self.draw = ImageDraw.Draw(self.im)
        self.label((24, 18), title, 34, TEXT)
        self.label((26, 65), detail, 20)
        self.draw.line((24, 103, width-24, 103), fill="#686151", width=2)

    def label(self, xy, label, size=20, color=MUTED):
        self.draw.text(xy, label, fill=color, font=font(size))

    def photo(self, source, x, y, w):
        if isinstance(source, Path):
            with Image.open(source) as picture:
                self.photo(picture, x, y, w)
            return
        self.im.paste(source.resize((w, round(w * 9 / 16)),Image.Resampling.LANCZOS),(x,y))


def gray(shots):
    width = 474
    p = Plate(48+4*width+3*GAP, 792, "F08   开放幕面  /  灰模验货",
              "同一正交尺度  ·  无贴图、无发光、无粒子  ·  米制双面实体与折边")
    angles = [(180,"正面  −Z"),(90,"侧面  +X"),(0,"背面  +Z"),(34,"斜视  34°")]
    for row,(form,title) in enumerate([("ArcVeil","开放弧幕"),("FlatVeil","平展幕")]):
        y = 118+row*334
        p.label((24,y),title,22,POINT)
        for col,(angle,view) in enumerate(angles):
            x = 24+col*(width+GAP)
            p.photo(shots/f"gray_{form}_{angle}.png",x,y+34,width)
            p.label((x,y+305),view,17)
    p.im.save(OUT/"f08_gray_review.png")


def materials(shots):
    width = 576
    p = Plate(48+3*width+2*GAP, 893, "F08   幕面透射与承载",
              "同一弧幕与中性标尺  ·  后方柱棱用于读取折光、遮蔽  ·  下排展示接触与光学细节")
    items = [("P19","P19  丝绸辉光薄幕"),("P04","P04  透明折光"),("P03","P03  暗幕遮蔽"),
             ("P19_load","P19  实际接触  /  7 kg · 容量 10 kg"),
             ("P04_detail","P04  柱棱折射局部"),("X13_detail","X13  接触局部  /  load_ratio = 0.70")]
    for i,(key,title) in enumerate(items):
        x,y = 24+(i%3)*(width+GAP),120+(i//3)*384
        p.photo(shots/(key+".png"),x,y,width)
        p.label((x,y+332),title,22,POINT)
    p.im.save(OUT/"f08_viewer_modes.png")


def interruptions(shots):
    thumb = 272
    group = thumb*3 + 8 + 18
    p = Plate(180+3*group,1112,"F08   从当前形态打断",
              "每组三格依次为切入前、转局部裂解后 420 ms、转收帷后 420 ms  ·  F08-04 取 Jolt 接触快照，切出后卸载  ·  两个出口分别从同一源相位进入")
    for col,cut in enumerate([25,55,85]):
        x = 164+col*group
        p.label((x,119),f"{cut}%  /  源动画进度",23,POINT)
        for i,label in enumerate(["当前形态","→  F08-05  裂解","→  F08-06  收帷"]):
            p.label((x+i*(thumb+4),154),label,17)
    for row,(code,title) in enumerate([("01","沿线展开"),("02","地面升幕"),("04","受压驾驭"),
                                       ("05","局部裂解"),("06","收帷交接")]):
        y = 186+row*181
        p.label((24,y+45),"F08-"+code,24,POINT)
        p.label((24,y+82),title,21,TEXT)
        for col,cut in enumerate([25,55,85]):
            for i,ending in enumerate(["entry","F08-05","F08-06"]):
                x = 164+col*group+i*(thumb+4)
                p.photo(shots/f"F08-{code}_{cut}_{ending}.png",x,y,thumb)
    p.im.save(OUT/"f08_interrupt_check.png")


def hall(ffmpeg):
    width = 460
    p = Plate(48+width*4+3*GAP, 1114, "F08   暗殿三配方  /  实机关键帧",
              "Godot 4.5.1  ·  Metal Forward+  ·  Jolt 3D  ·  B03 双臂开帷  ·  同一载体场景与机位轨迹")
    versions = [("v1_load","V1   承重光幕",[(.80,"展开"),(2.53,"飞石入画"),(3.30,"接触裂纹"),(4.90,"受压下滑")]),
                ("v2_occlude","V2   遮蔽暗幕",[(.80,"展开"),(2.53,"同初速入画"),(3.30,"穿过暗幕"),(5.80,"幕后的石块")]),
                ("v3_ground","V3   地面升幕与收帷",[(1.37,"贴地起势"),(2.80,"升幕压尘"),(3.55,"主动撤除"),(4.88,"向根线收回")])]
    for row,(key,title,frames) in enumerate(versions):
        y = 116+row*330
        p.label((24,y),title,22,POINT)
        for col,(t,label) in enumerate(frames):
            data = subprocess.check_output([ffmpeg,"-loglevel","error","-ss",str(t),"-i",str(OUT/(key+".mp4")),
                                            "-frames:v","1","-vf",f"scale={width}:-2","-f","image2pipe","-vcodec","png","-"])
            x = 24+col*(width+GAP)
            p.photo(Image.open(BytesIO(data)),x,y+32,width)
            p.label((x,y+296),f"{t:.2f} s    {label}",18)
    p.im.save(OUT/"f08_hall_keyframes.jpg", quality=94,subsampling=0)


def verify(shots, ffprobe):
    bench = json.loads((shots/"bench.json").read_text())
    cuts = bench["cuts"]
    assert bench["passed"] and bench["P03_stale_receipt"] == 0 and abs(bench["measured_load"]-.7)<1e-6
    assert len({(r["clip"],r["cut"],r["into"]) for r in cuts}) == 30
    assert all(r["max_entry_jump"] < .00001 and abs(r["art_clock_delta"]-.42)<1e-6 for r in cuts)
    required = {"unfold_from_line","rise_from_ground","load_bulge","fracture_open","retract_to_root"}
    assert {g["form"] for g in bench["geometry"]} == {"ArcVeil","FlatVeil"}
    for g in bench["geometry"]:
        assert g["vertices"] == g["uv0_count"] == g["uv1_count"] and set(g["keys"]) == required
    data = []
    for name in ["v1_load","v2_occlude","v3_ground"]:
        d = json.loads((OUT/(name+".trace.json")).read_text())
        meta = json.loads(subprocess.check_output([ffprobe,"-v","error","-select_streams","v:0","-show_entries",
                          "stream=width,height,codec_name,r_frame_rate,nb_frames,duration","-of","json",str(OUT/(name+".mp4"))]))["streams"][0]
        assert [meta["width"],meta["height"],meta["nb_frames"],meta["r_frame_rate"]] == [1920,1080,"180","30/1"]
        assert all(e["jump"] < 1e-5 for e in d["handoffs"])
        assert max(r["hand_span_m"] for r in d["samples"]) > 1.25
        data.append((d,meta))
    v1,v2,v3 = [d for d,_ in data]
    assert v1["contact_ticks"] > 0 and abs(v1["peak_load"]-.7)<1e-6
    assert v2["contact_ticks"] == v2["peak_load"] == 0
    assert all(r["load_ratio"] == r["flex"] == 0 for r in v2["samples"] + v3["samples"])
    a,b = [[r["stone_xyz"][2] for r in d["samples"] if "stone_xyz" in r] for d in [v1,v2]]
    assert a[0] == b[0] and min(a) > 0 and b[-1] < -5
    assert any(r["dust"] for r in v3["samples"]) and 0 < v3["handoffs"][1]["entry"][1] < 1
    assert v3["samples"][-1]["pose"][3] > .9999
    shutil.copyfile(shots/"bench.json",OUT/"bench.trace.json")
    summary = {"neutral_cut_cases":len(cuts),"max_entry_jump":max(r["max_entry_jump"] for r in cuts),
               "loaded_stone_min_z_m":min(a),"occluded_stone_final_z_m":b[-1],
               "videos":[meta for _,meta in data]}
    (OUT/"verification.json").write_text(json.dumps(summary,indent=2)+"\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("shots",type=Path)
    parser.add_argument("--ffmpeg",default="ffmpeg")
    parser.add_argument("--ffprobe",default="ffprobe")
    args = parser.parse_args()
    verify(args.shots,args.ffprobe)
    gray(args.shots)
    materials(args.shots)
    interruptions(args.shots)
    hall(args.ffmpeg)
