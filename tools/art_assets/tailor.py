"""Tailor the observatory vestments and skin them to an original humanoid rig.
Run with NumPy. Dimensions are metres; the test figure faces +Z.
"""

from pathlib import Path
import json
import struct
import numpy as np

DEST = Path(__file__).resolve().parents[2] / "game/assets/models/astronomer.glb"
bones = []
positions = []


def bone(name, pos, parent=None):
    index = len(bones)
    delta = np.array(pos) - (positions[parent] if parent is not None else 0)
    bones.append(dict(name=name, translation=delta.tolist()))
    positions.append(np.array(pos, dtype=float))
    if parent is not None:
        bones[parent].setdefault("children", []).append(index)
    return index


hip = bone("Pelvis", (0, 0.91, 0))
spine = bone("Spine", (0, 1.13, 0), hip)
chest = bone("Chest", (0, 1.36, 0), spine)
head = bone("Head", (0, 1.60, 0), chest)
cape = bone("Mantle", (0, 1.40, -0.14), chest)
hem = bone("Hem", (0, 0.85, -0.20), cape)
arms = []
legs = []
for s, side in [(-1, "L"), (1, "R")]:
    arm = bone("Shoulder" + side, (s * 0.205, 1.46, 0), chest)
    elbow = bone("Elbow" + side, (s * 0.345, 1.19, 0.025), arm)
    hand = bone("Hand" + side, (s * 0.39, 0.965, 0.105), elbow)
    arms.append((arm, elbow, hand))
    thigh = bone("Thigh" + side, (s * 0.11, 0.91, 0), hip)
    knee = bone("Knee" + side, (s * 0.14, 0.52, 0.025), thigh)
    foot = bone("Foot" + side, (s * 0.145, 0.13, 0), knee)
    legs.append((thigh, knee, foot))

# Every surface is a tailored ring loft with four bone weights per vertex.
surfaces = []


def loft(
    mat,
    sections,
    *,
    folds=0,
    depth=0.0,
    start=0,
    span=2 * np.pi,
    n=64,
    rag=0,
    oriented=False,
):
    xyz = []
    joints = []
    weights = []
    uv = []
    idx = []
    for j, (center, rx, rz, binding) in enumerate(sections):
        if isinstance(binding, int):
            binding = {binding: 1.0}
        center = np.asarray(center, float)
        axis = np.array([0.0, 1.0, 0.0])
        if oriented:
            before = sections[max(0, j - 1)][0]
            after = sections[min(len(sections) - 1, j + 1)][0]
            axis = np.subtract(after, before)
            axis /= max(np.linalg.norm(axis), 1e-6)
        side = np.cross(axis, [0, 0, 1])
        side /= max(np.linalg.norm(side), 1e-6)
        forward = np.cross(side, axis)
        for i in range(n + 1):
            u = i / n
            v = j / (len(sections) - 1)
            a = start + u * span
            ridge = 1 + depth * np.cos(folds * a + 0.45 * v) * (
                0.75 + 0.25 * np.cos(v * 3)
            )
            p = center + ridge * (side * np.cos(a) * rx + forward * np.sin(a) * rz)
            if j == 0:
                p[1] += rag * (0.45 * np.sin(7 * a) + 0.55 * np.cos(11 * a + 0.5))
            xyz.append(p)
            uv.append((u, v))
            ids = list(binding)
            ws = list(binding.values())
            joints.append((ids + [0] * 4)[:4])
            weights.append((ws + [0] * 4)[:4])
            if i < n and j < len(sections) - 1:
                k = j * (n + 1) + i
                idx.extend((k, k + n + 1, k + 1, k + 1, k + n + 1, k + n + 2))
    xyz = np.array(xyz)
    it = np.array(idx).reshape(-1, 3)
    faces = np.cross(xyz[it[:, 1]] - xyz[it[:, 0]], xyz[it[:, 2]] - xyz[it[:, 0]])
    normal = np.zeros_like(xyz)
    for i in range(3):
        np.add.at(normal, it[:, i], faces)
    if abs(span - 2 * np.pi) < 0.001:
        for j in range(len(sections)):
            k = j * (n + 1)
            normal[k] = normal[k + n] = normal[k] + normal[k + n]
    normal /= np.maximum(np.linalg.norm(normal, axis=1, keepdims=True), 1e-10)
    surfaces.append((mat, xyz, normal, uv, joints, weights, idx))


def body(mat, rings, **kw):
    loft(mat, [((0, y, z), x, r, b) for y, z, x, r, b in rings], **kw)


linen, velvet, gilt, iron, leather, ivory = range(6)
body(
    linen,
    [
        (0.13, 0, 0.31, 0.25, hip),
        (0.31, 0, 0.29, 0.23, hip),
        (0.72, 0, 0.23, 0.18, hip),
        (1.01, 0, 0.15, 0.115, hip),
        (1.23, 0, 0.19, 0.14, spine),
        (1.44, 0, 0.24, 0.13, chest),
        (1.53, 0, 0.125, 0.09, chest),
    ],
    folds=20,
    depth=0.068,
    rag=0.025,
)
body(
    velvet,
    [
        (0.10, -0.09, 0.425, 0.265, hem),
        (0.28, -0.08, 0.38, 0.25, {hem: 0.7, cape: 0.3}),
        (0.73, -0.05, 0.27, 0.2, cape),
        (1.13, -0.025, 0.23, 0.17, {cape: 0.6, chest: 0.4}),
        (1.44, 0, 0.30, 0.172, chest),
        (1.56, 0, 0.14, 0.11, chest),
    ],
    start=2.05,
    span=5.38,
    folds=16,
    depth=0.095,
    rag=0.042,
)
for y, z, x, r, b in [
    (1.02, 0.0, 0.177, 0.142, hip),
    (1.34, 0, 0.244, 0.16, chest),
    (1.50, 0, 0.202, 0.14, chest),
    (1.535, 0, 0.17, 0.124, chest),
]:
    body(
        gilt,
        [
            (y - 0.023, z, x, r, b),
            (y - 0.013, z, x + 0.008, r + 0.01, b),
            (y + 0.008, z, x + 0.007, r + 0.01, b),
            (y + 0.02, z, x - 0.008, r, b),
        ],
        folds=32,
        depth=0.018,
    )
# A recessed ivory mask under the cowl; opening follows the face.
body(
    iron,
    [
        (1.55, 0.035, 0.042, 0.07, head),
        (1.60, 0.04, 0.077, 0.097, head),
        (1.70, 0.04, 0.102, 0.11, head),
        (1.78, 0.019, 0.084, 0.085, head),
        (1.80, 0, 0.01, 0.01, head),
    ],
)
body(
    velvet,
    [
        (1.49, -0.025, 0.143, 0.145, head),
        (1.57, -0.018, 0.154, 0.164, head),
        (1.70, -0.008, 0.145, 0.154, head),
        (1.78, -0.01, 0.117, 0.126, head),
        (1.839, -0.018, 0.055, 0.06, head),
        (1.855, -0.017, 0.001, 0.002, head),
    ],
    start=2.24,
    span=4.95,
    folds=7,
    depth=0.06,
)
for s in (-1, 1):
    arm, elbow, hand = arms[int(s > 0)]
    for mat, sections in [
        (
            linen,
            [
                (positions[hand], 0.056, 0.057, hand),
                (
                    positions[elbow] * 0.55 + positions[hand] * 0.45,
                    0.078,
                    0.071,
                    {elbow: 0.8, hand: 0.2},
                ),
                (positions[elbow], 0.092, 0.081, {arm: 0.42, elbow: 0.58}),
                (positions[arm], 0.106, 0.105, arm),
            ],
        ),
        (
            iron,
            [
                (positions[hand] + [0, 0.016, 0], 0.065, 0.059, hand),
                (positions[hand] + [0, 0.097, -0.018], 0.071, 0.071, elbow),
            ],
        ),
        (
            gilt,
            [
                (positions[arm] + [s * 0.045, -0.07, 0], 0.111, 0.118, arm),
                (positions[arm], 0.117, 0.125, arm),
                (positions[arm] + [-s * 0.03, 0.03, 0], 0.081, 0.082, arm),
            ],
        ),
        (
            leather,
            [
                (positions[hand] + [0, -0.093, 0.018], 0.032, 0.031, hand),
                (positions[hand] + [0, -0.04, 0.009], 0.048, 0.036, hand),
                (positions[hand], 0.046, 0.04, hand),
            ],
        ),
    ]:
        loft(mat, sections, oriented=True, folds=12, depth=0.045)
    thigh, knee, foot = legs[int(s > 0)]
    loft(
        leather,
        [
            ((s * 0.145, 0.035, 0.06), 0.087, 0.148, foot),
            ((s * 0.145, 0.11, 0.03), 0.085, 0.12, foot),
            (positions[knee], 0.069, 0.075, knee),
            (positions[thigh], 0.099, 0.102, thigh),
        ],
    )
    # Raised gold chevrons of the sealed face and the hem of the hood.
    loft(
        gilt,
        [
            ((s * 0.019, 1.659, 0.145), 0.004, 0.004, head),
            ((s * 0.053, 1.69, 0.147), 0.008, 0.005, head),
            ((s * 0.089, 1.705, 0.12), 0.004, 0.003, head),
        ],
        oriented=True,
        n=12,
    )

# Brocade panels lie forward of the pleated underdress. Their hems respond
# to the pelvis while their collars stay with the sternum.
for side in (-1, 1):
    loft(
        velvet,
        [
            ((side * 0.102, 0.225, 0.217), 0.087, 0.009, hip),
            ((side * 0.117, 0.405, 0.220), 0.068, 0.009, hip),
            ((side * 0.088, 0.77, 0.174), 0.06, 0.012, hip),
            ((side * 0.07, 1.02, 0.124), 0.052, 0.010, hip),
            ((side * 0.063, 1.20, 0.159), 0.062, 0.012, spine),
            ((side * 0.099, 1.43, 0.113), 0.067, 0.014, chest),
            ((side * 0.109, 1.50, 0.081), 0.056, 0.014, chest),
        ],
        n=32,
    )
    for k in (0, 1):
        displacement = (-1 if k == 0 else 1) * 0.050
        loft(
            gilt,
            [
                ((side * (x + displacement), h, z), 0.005, 0.004, b)
                for x, h, z, b in [
                    (0.102, 0.235, 0.229, hip),
                    (0.117, 0.40, 0.232, hip),
                    (0.088, 0.77, 0.185, hip),
                    (0.07, 1.02, 0.143, hip),
                    (0.063, 1.20, 0.172, spine),
                    (0.099, 1.43, 0.131, chest),
                ]
            ],
            n=10,
        )
    hand = arms[int(side > 0)][2]
    wrist = positions[hand]
    for digit in range(5):
        off = (digit - 2) * 0.014
        bend = 0.025 if digit == 0 else 0.010
        finger = [
            (wrist + [off, -0.055, 0.023], 0.012, 0.010, hand),
            (wrist + [off * 1.2, -0.107 + bend, 0.028], 0.010, 0.010, hand),
            (wrist + [off * 1.25, -0.125 + bend, 0.045], 0.005, 0.006, hand),
        ]
        loft(leather, finger, n=10, oriented=True)
# An articulated, overlapping gorget and a chased crescent mask ridge.
for i in range(5):
    h = 1.32 + i * 0.041
    r = 0.258 - i * 0.022
    body(
        iron,
        [
            (h, 0, r, 0.16 - i * 0.01, chest),
            (h + 0.024, 0, r + 0.008, 0.168 - i * 0.01, chest),
            (h + 0.042, 0, r - 0.008, 0.154 - i * 0.01, chest),
        ],
        start=0,
        span=2 * np.pi,
        folds=16,
        depth=0.027,
    )
    body(
        gilt,
        [
            (h + 0.017, 0, r + 0.009, 0.169 - i * 0.01, chest),
            (h + 0.022, 0, r + 0.009, 0.169 - i * 0.01, chest),
        ],
    )
loft(
    gilt,
    [
        ((0, 1.589, 0.126), 0.003, 0.006, head),
        ((0, 1.653, 0.151), 0.010, 0.009, head),
        ((0, 1.715, 0.156), 0.007, 0.007, head),
        ((0, 1.758, 0.117), 0.003, 0.003, head),
    ],
    n=12,
)
# Staff, ferrules and three curving silver prongs share the hand socket.
hand = arms[1][2]
x, y, z = positions[hand] + [0, 0, 0.048]


def staff(mat, rows):
    loft(
        mat,
        [((x + dx, y + dy, z + dz), r, r, hand) for dx, dy, dz, r in rows],
        oriented=True,
        n=22,
    )


staff(
    leather,
    [
        (0, -0.89, 0, 0.012),
        (0, -0.82, 0, 0.022),
        (0.018, 0.32, 0, 0.019),
        (0, 0.86, 0, 0.023),
        (0, 1.11, 0, 0.012),
    ],
)
for dy in (-0.83, -0.08, 0.06, 0.66, 0.78, 0.88):
    staff(gilt, [(0, dy, 0, 0.025), (0, dy + 0.018, 0, 0.026)])
for phi in (0, 2.09, 4.18):
    staff(
        gilt,
        [
            (np.cos(phi) * r, h, np.sin(phi) * r, w)
            for h, r, w in [
                (0.83, 0.015, 0.018),
                (0.92, 0.059, 0.017),
                (1.02, 0.077, 0.012),
                (1.1, 0.047, 0.009),
                (1.18, 0.008, 0.003),
            ]
        ],
    )
staff(ivory, [(0, 0.92, 0, 0.002), (0, 1.0, 0, 0.042), (0, 1.08, 0, 0.001)])

doc = dict(
    asset=dict(version="2.0", generator="ArtLab vestment atelier"),
    nodes=bones,
    scenes=[dict(nodes=[0, len(bones)])],
    scene=0,
    bufferViews=[],
    accessors=[],
    materials=[],
    meshes=[dict(name="Vestments", primitives=[])],
)
blob = bytearray()


def accessor(array, dtype, kind, code, extrema=False):
    a = np.ascontiguousarray(array, dtype=dtype)
    blob.extend(bytes((-len(blob)) % 4))
    view = len(doc["bufferViews"])
    doc["bufferViews"].append(dict(buffer=0, byteOffset=len(blob), byteLength=a.nbytes))
    blob.extend(a.tobytes())
    spec = dict(bufferView=view, componentType=code, count=len(a), type=kind)
    if extrema:
        spec.update(min=a.min(axis=0).tolist(), max=a.max(axis=0).tolist())
    doc["accessors"].append(spec)
    return len(doc["accessors"]) - 1


for name, col, metal, rough in [
    ("Ash brocade", [0.28, 0.27, 0.236], 0.08, 0.88),
    ("Midnight velvet", [0.045, 0.055, 0.068], 0.08, 0.84),
    ("Old gilt", [0.48, 0.31, 0.155], 0.79, 0.32),
    ("Gunmetal", [0.16, 0.20, 0.22], 0.86, 0.32),
    ("Waxed leather", [0.086, 0.063, 0.047], 0.16, 0.62),
    ("Moonstone", [0.55, 0.8, 0.84], 0.24, 0.24),
]:
    doc["materials"].append(
        dict(
            name=name,
            doubleSided=True,
            pbrMetallicRoughness=dict(
                baseColorFactor=col + [1], metallicFactor=metal, roughnessFactor=rough
            ),
        )
    )
for m, p, n, uv, j, w, idx in surfaces:
    attrs = dict(
        POSITION=accessor(p, "<f4", "VEC3", 5126, True),
        NORMAL=accessor(n, "<f4", "VEC3", 5126),
        TEXCOORD_0=accessor(uv, "<f4", "VEC2", 5126),
        JOINTS_0=accessor(j, "<u2", "VEC4", 5123),
        WEIGHTS_0=accessor(w, "<f4", "VEC4", 5126),
    )
    doc["meshes"][0]["primitives"].append(
        dict(attributes=attrs, indices=accessor(idx, "<u4", "SCALAR", 5125), material=m)
    )
ibm = np.tile(np.eye(4), (len(bones), 1, 1))
ibm[:, 3, :3] = -np.asarray(positions)
doc["skins"] = [
    dict(
        joints=list(range(len(bones))),
        skeleton=0,
        inverseBindMatrices=accessor(ibm, "<f4", "MAT4", 5126),
    )
]
bones.append(dict(name="Astronomer", mesh=0, skin=0))
doc["buffers"] = [dict(byteLength=len(blob))]
header = json.dumps(doc, separators=(",", ":")).encode()
header += b" " * ((-len(header)) % 4)
blob.extend(bytes((-len(blob)) % 4))
DEST.write_bytes(
    struct.pack("<4sII", b"glTF", 2, 28 + len(header) + len(blob))
    + struct.pack("<I4s", len(header), b"JSON")
    + header
    + struct.pack("<I4s", len(blob), b"BIN\0")
    + blob
)
