"""Offline glTF 2.0 writer for the ring loft and the twelve PBR host meshes."""

import json
import struct

import numpy as np


def normals(points, triangles):
    n = np.zeros_like(points)
    faces = np.cross(
        points[triangles[:, 1]] - points[triangles[:, 0]],
        points[triangles[:, 2]] - points[triangles[:, 0]],
    )
    for index in triangles.T:
        np.add.at(n, index, faces)
    return n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-10)


class Model:
    def __init__(self):
        self.bin = bytearray()
        self.doc = {
            "asset": {
                "version": "2.0",
                "generator": "City Fates offline asset pipeline",
            },
            "scene": 0,
            "scenes": [{"nodes": []}],
            "nodes": [],
            "meshes": [],
            "materials": [],
            "bufferViews": [],
            "accessors": [],
        }

    def view(self, data):
        self.bin.extend(bytes(-len(self.bin) % 4))
        self.doc["bufferViews"].append(
            {"buffer": 0, "byteOffset": len(self.bin), "byteLength": len(data)}
        )
        self.bin.extend(data)
        return len(self.doc["bufferViews"]) - 1

    def accessor(self, values, kind):
        a = np.asarray(values, dtype="<u4" if kind == "SCALAR" else "<f4")
        item = {
            "componentType": 5125 if kind == "SCALAR" else 5126,
            "type": kind,
            "count": len(a),
            "bufferView": self.view(a.tobytes()),
        }
        if kind == "VEC3":
            item.update(min=a.min(axis=0).tolist(), max=a.max(axis=0).tolist())
        self.doc["accessors"].append(item)
        return len(self.doc["accessors"]) - 1

    def texture(self, path):
        image = {
            "bufferView": self.view(path.read_bytes()),
            "mimeType": "image/jpeg",
            "name": path.stem,
        }
        images = self.doc.setdefault("images", [])
        images.append(image)
        textures = self.doc.setdefault("textures", [])
        textures.append({"source": len(images) - 1})
        return {"index": len(textures) - 1}

    def mesh(
        self,
        name,
        points,
        triangles,
        uv,
        material=0,
        targets=None,
        color=None,
        uv2=None,
    ):
        p = np.asarray(points, dtype=float)
        tri = np.asarray(triangles, dtype=int)
        n = normals(p, tri)
        attrs = {
            "POSITION": self.accessor(p, "VEC3"),
            "NORMAL": self.accessor(n, "VEC3"),
            "TEXCOORD_0": self.accessor(uv, "VEC2"),
        }
        if uv2 is not None:
            attrs["TEXCOORD_1"] = self.accessor(uv2, "VEC2")
        if color is not None:
            attrs["COLOR_0"] = self.accessor(color, "VEC4")
        primitive = {
            "attributes": attrs,
            "indices": self.accessor(tri.ravel(), "SCALAR"),
            "material": material,
        }
        mesh = {"name": name, "primitives": [primitive]}
        if targets:
            mesh.update(
                weights=[0] * len(targets), extras={"targetNames": list(targets)}
            )
            primitive["targets"] = [
                {
                    "POSITION": self.accessor(q - p, "VEC3"),
                    "NORMAL": self.accessor(normals(q, tri) - n, "VEC3"),
                }
                for q in targets.values()
            ]
        idx = len(self.doc["meshes"])
        self.doc["meshes"].append(mesh)
        self.doc["scenes"][0]["nodes"].append(len(self.doc["nodes"]))
        self.doc["nodes"].append({"mesh": idx, "name": name})

    def save(self, path):
        self.bin.extend(bytes(-len(self.bin) % 4))
        self.doc["buffers"] = [{"byteLength": len(self.bin)}]
        meta = json.dumps(self.doc, separators=(",", ":")).encode()
        meta += b" " * (-len(meta) % 4)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(
            struct.pack("<4sII", b"glTF", 2, 28 + len(meta) + len(self.bin))
            + struct.pack("<I4s", len(meta), b"JSON")
            + meta
            + struct.pack("<I4s", len(self.bin), b"BIN\0")
            + self.bin
        )
