"""Blender Python. Run in background Blender or with the official bpy wheel."""
import math
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "game/art_kit/families/F08_open_veil/F08_open_veil.glb"
KEYS = ("unfold_from_line", "rise_from_ground", "load_bulge", "fracture_open", "retract_to_root")
PI = math.pi
sin, cos, exp = math.sin, math.cos, math.exp


def point(u, h, face, panel, arc, key=""):
    # Work in Godot metres (Y up), then convert to Blender axes on return.
    s = 2*u-1
    lip = abs(s)**2.3
    top = 1.87 + 1.05*lip + .23*s + .13*cos(4*PI*u+.6) + .09*sin(6*PI*u+.3)
    root_z = arc*(.93*s*s - .25)
    x = 2.84*s + .16*s*h*h + .055*sin(2*PI*u)*sin(PI*h)
    y = .012+h*top
    # Watered silk pulled up at the selvedges. Fan pleats near each suspension
    # point converge into broad suspended catenaries across the middle.
    fan = u*5.6 + .60*sin(PI*h+.4)*s - .64*h*h*s
    valley = h*2.7 - (.82+.47*h)*s*s + .17*sin(3*PI*u)
    roll = (.102*sin(2*PI*fan) + .036*sin(4*PI*fan+.8))*(.66+.34*h)
    sling = .079*sin(2*PI*valley)*sin(PI*u)**.6
    piping = .036*exp(-((h-.978)/.019)**2) + .025*exp(-((h-.036)/.021)**2)
    z = root_z + .24*sin(PI*h)*sin(PI*u) + roll + sling
    z += face*(.012+.013*(1-h)+piping)
    if key == KEYS[0]:
        x = -2.84 + .019*(x+2.84) + .055*sin(PI*h)
        z = .68*arc + .17*s + .025*sin(20*PI*u)
    elif key == KEYS[1]:
        y = .012+.015*h + .015*(1+sin(2*PI*fan))*h
        z = root_z + .16*h + roll*.38 + face*.006
    elif key == KEYS[2]:
        z -= .42*sin(PI*h)*(.7 + .3*sin(PI*u))
    elif key == KEYS[3]:
        tear = max(0, (h-.22)/.78)**1.45
        peel = (-.34, .19, .48)[panel] * tear
        x += peel
        z += tear*(.22, -.54, .29)[panel]
        y -= tear*(.26, .64, .32)[panel]
    elif key == KEYS[4]:
        z = root_z + .04*sin(18*PI*h+4*u)*h + .036*s + face*.004
        x = 2.84*s + .032*sin(PI*h)
        y = .014 + h*.025 + .025*sin(PI*h)
    return (x, -z, y)


def build(name, arc):
    vertices, params, faces = [], [], []
    height_steps = 36
    for panel, (lo, hi, width_steps) in enumerate([(0, .31, 35), (.31, .66, 40), (.66, 1, 38)]):
        start = len(vertices)
        def idx(side, i, j):
            return start+(side*(width_steps+1)+i)*(height_steps+1)+j
        for side in range(2):
            for i in range(width_steps+1):
                for j in range(height_steps+1):
                    p = (lo+(hi-lo)*i/width_steps, j/height_steps, 1-2*side, panel, arc)
                    params.append(p)
                    vertices.append(point(*p))
        for i in range(width_steps):
            for j in range(height_steps):
                for side in (0, 1):
                    f = [idx(side,i,j), idx(side,i+1,j), idx(side,i+1,j+1), idx(side,i,j+1)]
                    faces.append(f if side == 0 else f[::-1])
        # Turned hems; adjacent cut lines share the unbroken resting silhouette.
        for i in range(width_steps):
            for j in (0, height_steps):
                f = [idx(0,i,j),idx(1,i,j),idx(1,i+1,j),idx(0,i+1,j)]
                faces.append(f if j == 0 else f[::-1])
        for j in range(height_steps):
            for i in (0,width_steps):
                f = [idx(0,i,j),idx(0,i,j+1),idx(1,i,j+1),idx(1,i,j)]
                faces.append(f if i == 0 else f[::-1])
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    tex = mesh.uv_layers.new(name="Silk")
    domain = mesh.uv_layers.new(name="LoomDomain")
    for poly in mesh.polygons:
        poly.use_smooth = True
        for li in poly.loop_indices:
            u,h,*_ = params[mesh.loops[li].vertex_index]
            tex.data[li].uv = (u+.013*sin(PI*h)*sin(2*PI*u),h)
            domain.data[li].uv = (u,1-h)
    obj.shape_key_add(name="Basis")
    for name in KEYS:
        target = obj.shape_key_add(name=name)
        target.data.foreach_set("co", [c for p in params for c in point(*p,key=name)])


bpy.ops.wm.read_factory_settings(use_empty=True)
build("ArcVeil", 1)
build("FlatVeil", 0)
bpy.ops.export_scene.gltf(filepath=str(OUT), export_format="GLB", export_yup=True,
                          export_morph=True, export_normals=True, export_morph_normal=True,
                          export_texcoords=True, export_animations=False)
