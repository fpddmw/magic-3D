"""Write a metre-scale glTF 2.0 GLB offline using NumPy. Both meshes share topology/UVs."""
import json
import struct
from pathlib import Path

import numpy as np

OUT = Path(__file__).resolve().parents[2] / "game/art_kit/families/F03_arc_blade/F03_arc_blade.glb"
STEPS = 96
BANDS = np.array([0, .038, .09, .20, .38, .60, .80, 1.])
KEYS = ["unfold_root_to_tip", "arc_open", "sweep_bend", "edge_retract"]


def surface(wide, key=None):
    verts, uv, uv1, triangles = [], [], [], []
    angle = np.radians(80 if key == "arc_open" else 22.5)
    radius = 1 / np.sin(angle)
    for sheet in range(2):
        rows = []
        for i in range(STEPS + 1):
            s = i / STEPS
            row = []
            taper = np.sin(np.pi*s) ** .87
            theta = (2*s-1)*angle
            # Crown to wingtips measured along an open circular arc, flying toward -Z.
            x = radius*np.sin(theta)
            crown = radius*(np.cos(theta)-np.cos(angle))
            outer = np.array([x, crown*np.sin(.64), -crown*np.cos(.64)])
            for v in ([0.] if i in (0, STEPS) else BANDS):
                thickness = (.49 if wide else .30) * taper
                across = v*thickness*(1 + v*v*.15*np.sin(17*s + sheet))
                pos = outer + np.array([-np.sin(theta)*across,
                       -.48*across, np.cos(theta)*across])
                # Two lofted open membranes, a discrete ridge near the cutting edge.
                ridge = np.interp(v, [0, .038, .09, .38, 1], [0, .035, .032, .016, 0])
                pos[1] += taper*(ridge*(1 if sheet == 0 else -.65)
                                 - sheet*(.004 + .048*np.sin(np.pi*v)))
                pos[2] += sheet*taper*(.002+.081*v)
                if key == "unfold_root_to_tip":
                    pos[0] -= .28*s*s
                    pos[1] -= .12*s
                    pos[2] += .19*s*s
                if key == "sweep_bend":
                    pos[1] += .13*x
                    pos[2] += .25*x*x + .07*x
                if key == "edge_retract":
                    pos[0] -= .42*s**1.5
                    pos[1] += .13*s*s
                    pos[2] += .29*s*s
                row.append(len(verts))
                verts.append(pos)
                uv.append([s, v])
                uv1.append([s, 1-v])
            rows.append(row)
        for a, b in zip(rows, rows[1:]):
            if len(a) == 1:
                triangles.extend((a[0], b[j], b[j+1]) for j in range(len(b)-1))
            elif len(b) == 1:
                triangles.extend((a[j], b[0], a[j+1]) for j in range(len(a)-1))
            else:
                for j in range(len(a)-1):
                    triangles.extend([(a[j], b[j], a[j+1]), (a[j+1], b[j], b[j+1])])
    p, idx = np.array(verts), np.array(triangles)
    faces = np.cross(p[idx[:, 1]]-p[idx[:, 0]], p[idx[:, 2]]-p[idx[:, 0]])
    normals = np.zeros_like(p)
    for corner in range(3):
        np.add.at(normals, idx[:, corner], faces)
    normals /= np.maximum(np.linalg.norm(normals, axis=1)[:, None], 1e-9)
    return p, normals, uv, uv1, idx


def main():
    blob = bytearray()
    doc = {"asset": {"version": "2.0", "generator": "City Fates F03 offline loft"},
           "scene": 0, "scenes": [{"nodes": [0, 1]}], "nodes": [], "meshes": [],
           "materials": [{"doubleSided": True}], "buffers": [], "bufferViews": [], "accessors": []}

    def accessor(array, kind, indices=False):
        a = np.array(array, dtype="<u2" if indices else "<f4")
        if indices:
            a = a.flatten()
        blob.extend(bytes((-len(blob)) % 4))
        view = {"buffer": 0, "byteOffset": len(blob), "byteLength": a.nbytes}
        doc["bufferViews"].append(view)
        blob.extend(a.tobytes())
        acc = {"bufferView": len(doc["bufferViews"])-1, "componentType": 5123 if indices else 5126,
               "count": len(a), "type": kind}
        if kind == "VEC3":
            acc.update(min=a.min(axis=0).tolist(), max=a.max(axis=0).tolist())
        doc["accessors"].append(acc)
        return len(doc["accessors"])-1

    for wide, name in enumerate(["narrow_edge", "wide_crescent"]):
        p, n, uv, uv1, tris = surface(wide)
        att = {k: accessor(a, t) for k, a, t in [
            ("POSITION", p, "VEC3"), ("NORMAL", n, "VEC3"),
            ("COLOR_0", np.repeat([[1.,1.,1.,1.],[0.,0.,0.,1.]],len(p)//2,axis=0), "VEC4"),
            ("TEXCOORD_0", uv, "VEC2"), ("TEXCOORD_1", uv1, "VEC2")]}
        primitive = {"attributes": att, "indices": accessor(tris, "SCALAR", True),
                     "material": 0, "targets": []}
        for key in KEYS:
            pk, nk, *_ = surface(wide, key)
            primitive["targets"].append({"POSITION": accessor(pk-p, "VEC3"),
                                          "NORMAL": accessor(nk-n, "VEC3")})
        doc["meshes"].append({"name": name, "primitives": [primitive],
                              "weights": [0]*4, "extras": {"targetNames": KEYS}})
        doc["nodes"].append({"name": name, "mesh": wide})
    blob.extend(bytes((-len(blob)) % 4))
    doc["buffers"].append({"byteLength": len(blob)})
    header = json.dumps(doc, separators=(",", ":")).encode()
    header += b" " * ((-len(header)) % 4)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_bytes(struct.pack("<4sII", b"glTF", 2, 28+len(header)+len(blob))
                    + struct.pack("<I4s", len(header), b"JSON") + header
                    + struct.pack("<I4s", len(blob), b"BIN\0") + blob)


if __name__ == "__main__":
    main()
