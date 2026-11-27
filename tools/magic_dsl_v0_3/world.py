"""Small shared-world witness. Contacts, occluders and material edges are scene observations."""

from copy import deepcopy
from heapq import heappop, heappush
from math import cos, dist, hypot, radians

from .admission import check, index, structure


class World:
    def __init__(self, scene):
        structure(scene, "Scene")
        self.scene = deepcopy(scene)
        self.objects = index(self.scene["objects"])
        self.edges = self.scene["edges"]
        self.origin = self.scene["position"]
        self.aim = self.direction(self.scene["aim"])
        self.slots = self.scene["slots"]
        check(all(x in self.objects for x in self.slots.values()), "slots", "现场引用悬空")
        pairs = set()
        for e in self.edges:
            pair = (e["kind"], *sorted((e["a"], e["b"])))
            check(
                e["a"] in self.objects
                and e["b"] in self.objects
                and e["a"] != e["b"]
                and pair not in pairs,
                "edges",
                "现场边重复或端点无效",
            )
            pairs.add(pair)
        for e in scene["events"]:
            ev = e["event"]
            required = {
                "aim": {"vector"},
                "move": {"vector"},
                "unlink": {"ref"},
                "cut": {"ref", "other"},
            }.get(ev, set())
            check(set(e) == {"event", "at"} | required, "events", "事件参数不匹配")
            if ev == "cut":
                check(
                    any({k["a"], k["b"]} == {e["ref"], e["other"]} for k in self.edges),
                    "events",
                    "断边引用不存在",
                )
            if ev == "unlink":
                check(e["ref"] in self.objects, "events", "断联端点不存在")
            if ev == "aim":
                self.direction(e["vector"])

    @staticmethod
    def direction(vector):
        length = hypot(*vector)
        check(length > 0, "aim", "方向向量为零")
        return [x / length for x in vector]

    def capture(self, recipe, sid):
        s = recipe.subjects[sid]
        origin = self.origin
        anchor = s["spatial"]["reference"]["anchor"]
        if anchor == "target":
            key = self.slots.get("target")
            if key not in self.objects:
                return None
            origin = self.objects[key]["position"]
        if anchor == "aim_point":
            if "aim_point" not in self.scene:
                return None
            origin = self.scene["aim_point"]
        if anchor == "source":
            root = self.source(recipe, sid)
            if root in self.objects:
                origin = self.objects[root]["position"]
        return list(origin), list(self.aim)

    def source(self, recipe, sid):
        source = recipe.subjects[sid]["source"]
        while source["kind"] in ("Borrow", "Derived"):
            source = recipe.subjects[source["ref"]]["source"]
        return self.slots.get(source.get("slot"))

    @staticmethod
    def axis(name, origin, aim, position):
        if name in ("aim", "up", "down"):
            return {"aim": aim, "up": [0, 1, 0], "down": [0, -1, 0]}[name]
        v = [b - a for a, b in zip(origin, position)]
        if name == "radial_in":
            v = [-x for x in v]
        if name == "tangential":
            v = [v[2], 0, -v[0]]
        return World.direction(v) if hypot(*v) > 1e-9 else [0, 0, 0]

    def affected(self, space, pose, channel):
        if pose is None:
            return {}
        g = space["geometry"]
        origin, aim = pose
        out = {}
        for key, o in sorted(self.objects.items()):
            if space.get("scope") == "self" and key != self.slots.get("self"):
                continue
            d = dist(o["position"], origin)
            if channel == "pressure" and o.get("occluded"):
                continue
            if channel == "thermal" and o.get("thermal_path", "radiation") == "insulated":
                continue
            if (
                channel == "thermal"
                and o.get("thermal_path", "radiation") == "radiation"
                and o.get("occluded")
            ):
                continue
            delta = [x - y for x, y in zip(o["position"], origin)]
            if g["shape"] == "column":
                weight = self.column_weight(g, space["distribution"], delta)
            else:
                if d > g["extent_m"]:
                    continue
                axial = sum(x * y for x, y in zip(delta, aim))
                if g["shape"] == "cone" and axial + 1e-10 < d * cos(radians(g["half_angle_deg"])):
                    continue
                weight = 1 if space["distribution"] == "uniform" else max(0, 1 - d / g["extent_m"])
            if channel == "optical":
                weight *= o.get("transmission", 0 if o.get("occluded") else 1)
            if weight > 0:
                out[key] = (d, weight)
        return out

    @staticmethod
    def column_weight(g, distribution, delta):
        x, y, z = delta
        r = hypot(x, z) / g["radius_m"]
        h = y / g["height_m"]
        if r > 1 or not 0 <= h <= 1:
            return 0
        if isinstance(distribution, str):
            distribution = {"radial": distribution, "axial": "uniform"}
        radial = {"uniform": 1, "linear_falloff": 1 - r, "bell": (1 - r * r) ** 2}[distribution["radial"]]
        return radial * (1 - h if distribution["axial"] == "linear_falloff" else 1)

    @staticmethod
    def column_vector(components, origin, position):
        x, z = position[0] - origin[0], position[2] - origin[2]
        radius = hypot(x, z)
        if radius:
            x, z = x / radius, z / radius
        radial, tangent = components["radial"], components["tangential"]
        return [radial * x + tangent * z, components["axial"], radial * z - tangent * x]

    def drift(self, dt):
        for obj in self.objects.values():
            if "velocity" in obj:
                obj["position"] = [p + dt * v for p, v in zip(obj["position"], obj["velocity"])]

    def network(self, root, kind, eligible, reach, hops, geometry):
        if root not in eligible:
            return {}
        edges = [e for e in self.edges if e["kind"] == kind and e["a"] in eligible and e["b"] in eligible]
        check(len(edges) <= geometry["edges"], "WorldLaw", "现场网络边数超出配方配额", "OVER_BUDGET")
        labels = {}
        queue = [(0, 0, root)]
        while queue:
            distance, depth, key = heappop(queue)
            if distance > reach or depth > hops:
                continue
            if any(d <= distance and h <= depth for d, h in labels.get(key, [])):
                continue
            labels.setdefault(key, []).append((distance, depth))
            check(len(labels) <= geometry["nodes"], "WorldLaw", "连通节点超出配方配额", "OVER_BUDGET")
            for e in edges:
                if e["intact"] and key in (e["a"], e["b"]):
                    dest = e["b"] if key == e["a"] else e["a"]
                    heappush(queue, (distance + e["length_m"], depth + 1, dest))
        return {k: min(d for d, _ in v) for k, v in labels.items()}

    def apply(self, event):
        kind = event["event"]
        if kind == "aim":
            self.aim = self.direction(event["vector"])
        if kind == "move":
            self.origin = list(event["vector"])
        if kind == "unlink":
            self.objects[event["ref"]]["linked"] = False
        if kind == "cut":
            for e in self.edges:
                if {e["a"], e["b"]} == {event["ref"], event["other"]}:
                    e["intact"] = False
