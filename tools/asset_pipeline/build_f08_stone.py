"""Offline lab prop: chipped voussoir, origin at centre of mass."""
from pathlib import Path
import math
import bpy

out = Path(__file__).resolve().parents[2] / "game/art_lab/f08/keystone.glb"
bpy.ops.wm.read_factory_settings(use_empty=True)
# Two irregular, chamfered rectangular rings at either end of a tapered stone.
vertices = []
for z,w,h in [(-.32,.235,.19),(-.27,.31,.245),(.19,.37,.25),(.295,.305,.21)]:
    for i,(x,y) in enumerate([(-.77,-1),(.65,-1),(1,-.61),(1,.59),(.74,1),(-.71,1),(-1,.66),(-1,-.62)]):
        vertices.append((w*x,-z+.026*math.sin(i*2.3+z),h*y+.022*math.sin(i*3.4+z)))
faces = [tuple(range(7,-1,-1)),tuple(range(24,32))]
for ring in range(3):
    for i in range(8):
        a = ring*8+i
        b = ring*8+(i+1)%8
        faces.append((a,b,b+8,a+8))
mesh = bpy.data.meshes.new("Voussoir")
mesh.from_pydata(vertices,[],faces)
mesh.update()
o = bpy.data.objects.new("ChippedKeystone",mesh)
bpy.context.collection.objects.link(o)
# UVs projected separately on each face for the hall's slate scan.
uv = mesh.uv_layers.new(name="Stone")
for poly in mesh.polygons:
    axis = max(range(3),key=lambda k: abs(poly.normal[k]))
    for li in poly.loop_indices:
        co = mesh.vertices[mesh.loops[li].vertex_index].co
        a,b = [co[k] for k in range(3) if k != axis]
        uv.data[li].uv = (a+.5,b+.5)
bpy.ops.export_scene.gltf(filepath=str(out),export_format="GLB")
