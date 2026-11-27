"""Bounded event scheduler over a validated recipe. Time is seconds in the offline fixture."""

from collections import defaultdict
from copy import deepcopy

from .admission import check
from .schema import REG
from .world import World

EPS = 1e-9


class Simulation:
    def __init__(self, recipe, scene):
        self.r = recipe
        self.w = World(scene)
        self.time = 0
        self.active = {}
        self.done = set()
        self.sent = set()
        self.waiting = defaultdict(set)
        self.handles = {}
        self.captured = {}
        self.cast_pose = {
            s: self.w.capture(recipe, s) for s, v in recipe.subjects.items() if "spatial" in v
        }
        self.material_ids = {}
        self.frozen = defaultdict(set)
        self.layers = {}
        self.layer_abilities = {}
        self.broken = set()
        self.log = []
        self.cues = []
        self.reserve = 0
        self.spent = 0
        self.delivered = 0
        self.result = None
        self.wallet = scene["caster_mana"]
        self.scale = recipe.tariff["scale"][recipe.data["scale"]]
        self.units = recipe.tariff["world_units"]
        if self.wallet + EPS < recipe.quote["upfront_mana"]:
            self.record("withheld", reason="upfront")
            return
        self.wallet -= recipe.quote["upfront_mana"]
        self.spent += recipe.quote["upfront_mana"]
        for p in sorted(recipe.data["Processes"]["entry"]):
            self.start(p)

    def record(self, event, **fields):
        self.log.append(dict(at=round(self.time, 8), event=event, **fields))

    def ratio(self):
        capacity = self.r.quote["reserve_capacity"]
        return min(1, self.reserve / capacity) if capacity else 0

    def art(self, p, cue):
        for tr in self.r.data["Expression"]:
            if tr["process"] != p or tr["cue"] != cue:
                continue
            if (
                tr.get("director")
                and self.r.contracts[self.r.nodes[p]["contract"]]["max_s"]
                - (self.time - self.active[p]["start"])
                > REG["artkit"]["silence_window_s"]
            ):
                continue
            value = self.ratio() if tr["bind"] == "fill_ratio" else 1
            if tr["bind"] == "geometry":
                value = self.r.subjects[tr["subject"]]["spatial"]["geometry"]
            self.cues.append({"at": round(self.time, 8), "track": tr, "value": value})

    def payer(self, p):
        c = self.r.contracts[self.r.nodes[p]["contract"]]
        if c["provider"] == "@caster":
            return "@caster"
        return self.w.source(self.r, c["provider"])

    def balance(self, key):
        if key == "@caster":
            return self.wallet
        obj = self.w.objects.get(key, {})
        return obj.get("mana", 0) if obj.get("linked") else 0

    def debit(self, key, amount):
        check(amount <= self.balance(key) + EPS, "provider", "账户超支")
        if key == "@caster":
            self.wallet = max(0, self.wallet - amount)
        else:
            self.w.objects[key]["mana"] = max(0, self.balance(key) - amount)
        self.spent += amount

    def start(self, p):
        self.active[p] = {"start": self.time, "repeats": 0}
        for h in self.waiting.pop(p, set()):
            self.handles[h] = p
        self.record("enter", process=p)
        c = self.r.contracts[self.r.nodes[p]["contract"]]
        if c["provider"] != "@caster" and self.balance(self.payer(p)) <= 0:
            self.finish(p, reason="supply_unavailable")
            return
        for op in self.r.nodes[p]["enter"]:
            if not self.action(p, op, 1):
                self.finish(p, reason="missing_binding")
                return
        self.art(p, "enter")

    def close(self, h):
        self.handles.pop(h, None)
        self.layers.pop(h, None)
        self.layer_abilities.pop(h, None)
        self.broken.discard(h)

    def finish(self, p, edge=None, reason="end"):
        self.art(p, "exit")
        for op in self.r.nodes[p]["exit"]:
            if self.handles.get(op["target"]) == p:
                if op["ability"] == "handoff_world":
                    self.record(
                        "handoff_world", object=self.material_ids[op["target"]], handle=op["target"]
                    )
                self.close(op["target"])
        for hand in (edge or {}).get("handoff", []):
            h = hand["handle"]
            dest = hand["to"]
            if self.handles.get(h) == p:
                self.handles[h] = ("waiting", dest)
                self.waiting[dest].add(h)
        for h, owner in list(self.handles.items()):
            if owner == p:
                self.close(h)
        del self.active[p]
        self.done.add(p)
        self.record("exit", process=p, reason=reason)
        for dest in (edge or {}).get("to", []):
            self.sent.add((p, dest))
            if self.r.nodes[dest]["join"] == "any" or all(
                (q, dest) in self.sent for q in self.r.parents[dest]
            ):
                self.start(dest)

    def event(self, p, ev):
        n = self.r.nodes[p]
        ready = False
        if self.r.charge_node:
            contract = self.r.contracts[self.r.nodes[self.r.charge_node]["contract"]]
            ready = self.reserve > 0 and self.ratio() + EPS >= contract["reserve"]["min_release_ratio"]
        for edge in n["on"]:
            if edge["event"] == ev and edge["when"] in (
                "always",
                "reserve_ready" if ready else "reserve_low",
            ):
                self.finish(p, edge, ev)
                return
        if ev in ("timeout", "interrupt"):
            self.finish(p, reason=ev)

    def pose(self, sid):
        sp = self.r.subjects[sid]["spatial"]
        if sp["reference"]["bind"] == "live":
            return self.w.capture(self.r, sid)
        return self.captured[sid]

    def action(self, p, op, dt):
        a, t = op["ability"], op["target"]
        if a == "form":
            sub = self.r.subjects.get(t)
            if sub:
                if "medium" in sub and sub["medium"] not in self.w.scene.get("media", []):
                    return False
                if sub["source"]["kind"] == "Borrow" and self.w.source(self.r, t) not in self.w.objects:
                    return False
                if (
                    "initial_phase" in sub
                    and self.w.objects[self.w.source(self.r, t)].get("phase") != sub["initial_phase"]
                ):
                    return False
                if sub["source"]["kind"] == "Derived":
                    self.close(sub["source"]["ref"])
                self.captured[t] = (
                    self.cast_pose[t]
                    if sub["spatial"]["reference"]["bind"] == "cast"
                    else self.w.capture(self.r, t)
                )
                if self.captured[t] is None:
                    return False
                if sub["kind"] == "Material":
                    root = self.w.source(self.r, t)
                    if sub["source"]["kind"] == "Manifest":
                        root = "manifest_" + t
                        if root in self.w.objects or len(self.w.objects) >= REG["limits"]["targets"]:
                            return False
                        self.w.objects[root] = {
                            "id": root,
                            "position": list(self.captured[t][0]),
                            "mass": self.scale,
                            "phase": "solid",
                        }
                    self.material_ids[t] = root
            else:
                rel = self.r.relations[t]
                if any(
                    self.r.subjects[rel[k]]["kind"] == "WorldRef" and self.w.source(self.r, rel[k]) is None
                    for k in ("from", "to")
                ):
                    return False
            self.handles[t] = p
            return True
        if a == "charge":
            return True  # paid below at the registered rate
        check(self.handles.get(t) == p, p, "现场句柄无有效所有者")
        rel = self.r.relations.get(t)
        sid = rel["from"] if rel else t
        space = self.r.subjects[sid]["spatial"]
        pose = self.pose(sid)
        candidates = self.w.affected(space, pose, REG["delivery"][a])
        objects = self.w.objects
        outcome = {}
        if a in ("impulse", "accelerate", "warm", "conduct"):
            weights = {k: v[1] for k, v in candidates.items()}
            if a == "conduct":
                conductors = {k for k in weights if objects[k].get("conductive")}
                root = min(conductors, key=lambda k: (candidates[k][0], k), default=None)
                nodes = self.w.network(
                    root, "electric", conductors, space["geometry"]["extent_m"], 12, space["geometry"]
                )
                weights = {k: weights[k] for k in nodes}
            if op.get("allocation") == "distance_weighted":
                weights = {k: v / (1 + candidates[k][0]) for k, v in weights.items()}
            total = sum(weights.values())
            if a == "impulse":
                budget = self.ratio() * self.r.quote["total_impulse_budget"]
                self.reserve = 0
            else:
                unit = {"accelerate": "acceleration", "warm": "heat_per_s", "conduct": "charge_per_pulse"}[
                    a
                ]
                budget = self.scale * self.units[unit] * dt
            for k, w in weights.items():
                value = budget * w * objects[k]["mass"] if a == "accelerate" else budget * w / total
                o = objects[k]
                outcome[k] = value
                if a in ("impulse", "accelerate"):
                    direction = self.w.axis(op["axis"], *pose, o["position"])
                    old = o.get("velocity", [0, 0, 0])
                    o["velocity"] = [x + y * value / o["mass"] for x, y in zip(old, direction)]
                elif a == "warm":
                    o["temperature_delta"] = o.get("temperature_delta", 0) + value / o["mass"]
                else:
                    o["charge"] = o.get("charge", 0) + value
            if a == "impulse":
                self.delivered += sum(outcome.values())
        elif a in ("project", "grow", "fracture"):
            key = self.material_ids[t]
            o = objects[key]
            if a == "project":
                axis = self.w.axis(op["axis"], *pose, o["position"])
                o["velocity"] = [
                    v + d * self.scale * self.units["project_impulse"] / o["mass"]
                    for v, d in zip(o.get("velocity", [0, 0, 0]), axis)
                ]
                outcome[key] = self.scale * self.units["project_impulse"]
            if a == "grow":
                value = min(self.units["max_growth"], o.get("growth", 0) + self.units["growth_per_s"] * dt)
                outcome[key] = o["growth"] = value
            if a == "fracture":
                outcome[key] = o["fragments"] = self.units["max_fragments"]
        elif a in ("solidify", "melt"):
            material = self.w.source(self.r, sid)
            if (
                material not in candidates
                or objects[material].get("phase") != ("liquid" if a == "solidify" else "solid")
                or objects[material]["mass"] > self.scale * self.units["phase_mass"]
            ):
                return False
            outcome[material] = objects[material]["phase"] = "solid" if a == "solidify" else "liquid"
        elif a == "freeze":
            pol = op["propagation"]
            origin = self.w.source(self.r, sid)
            if not self.frozen[t] and objects[origin].get("phase") != "liquid":
                return False
            eligible = {k for k in candidates if objects[k].get("phase") == "liquid" or k in self.frozen[t]}
            elapsed = self.time - self.active[p]["start"]
            reach = min(pol["reach_m"], elapsed * pol["speed_m_s"], space["geometry"]["extent_m"])
            route = self.w.network(origin, "material", eligible, reach, pol["hops"], space["geometry"])
            for k, d in route.items():
                if k not in self.frozen[t] and 1 - pol["attenuation"] * d > 0:
                    objects[k]["phase"] = "solid"
                    self.frozen[t].add(k)
                    outcome[k] = "solid"
        else:
            previous = self.layers.get(t, {})
            self.layer_abilities[t] = a
            if a == "bear_load":
                capacity = self.scale * self.units["load_capacity"]
                loads = {
                    k: objects[k].get("load", objects[k]["mass"])
                    for k in candidates
                    if objects[k].get("contact")
                }
                if t not in self.broken and sum(loads.values()) > capacity:
                    self.broken.add(t)
                    self.record("overload", target=t, capacity=capacity, load=sum(loads.values()))
                outcome = {} if t in self.broken else loads
            elif a == "attenuate":
                outcome = {k: self.units["transmission"] for k in candidates if objects[k].get("sight")}
            elif a == "notify":
                outcome = {k: True for k in candidates if objects[k].get("disturbance")}
            elif a == "illuminate":
                outcome = {k: self.units["light_level"] * self.scale * v[1] for k, v in candidates.items()}
            self.layers[t] = outcome
            if previous == outcome:
                return True
        if outcome:
            self.record(
                "effect",
                ability=a,
                target=t,
                objects=outcome,
                **({"receiver": self.w.source(self.r, rel["to"])} if a == "notify" else {}),
            )
            if a in ("impulse", "bear_load"):
                self.art(p, "impact")
        return True

    def rates(self):
        current = {}
        for p in self.active:
            rate = self.r.quote["rates"][p]
            if p == self.r.charge_node and (self.ratio() >= 1 - EPS or self.balance(self.payer(p)) <= EPS):
                rate = 0
            current[p] = rate
        return current

    def dispatch(self, events):
        # Scene changes are visible to subsequent delivery. Interrupt wins same-instant release.
        for e in events:
            self.w.apply(e)
        names = {e["event"] for e in events}
        active = sorted(self.active)
        for p in active:
            if p not in self.active:
                continue
            n = self.r.nodes[p]
            c = self.r.contracts[n["contract"]]
            state = self.active[p]
            elapsed = self.time - state["start"]
            if c["controller"] == "caster" and "interrupt" in names:
                self.event(p, "interrupt")
                continue
            needs_supply = c["provider"] != "@caster" or (
                p != self.r.charge_node and self.r.quote["rates"][p] > 0
            )
            if needs_supply and self.balance(self.payer(p)) <= EPS:
                self.finish(p, reason="supply_unavailable")
                continue
            if elapsed + EPS >= c["max_s"]:
                self.event(p, "timeout")
                continue
            for ev in ("release", "contact", "signal"):
                if ev in names and (ev != "release" or c["controller"] == "caster"):
                    self.event(p, ev)
                    if p not in self.active:
                        break
            if p not in self.active:
                continue
            rep = n.get("repeat")
            if (
                rep
                and state["repeats"] < rep["times"]
                and elapsed + EPS >= (state["repeats"] + 1) * rep["interval_s"]
            ):
                for op in rep["actions"]:
                    self.action(p, op, 1)
                state["repeats"] += 1
        # Enter/ready is a microstep, bounded by the acyclic process graph.
        for _ in self.r.nodes:
            ready = [
                p
                for p in sorted(self.active)
                if any(e["event"] == "ready" for e in self.r.nodes[p]["on"])
                and not self.active[p].get("ready_seen")
            ]
            if not ready:
                break
            for p in ready:
                self.active[p]["ready_seen"] = True
                self.event(p, "ready")

    def run(self):
        if self.result is not None:
            return deepcopy(self.result)
        until = self.w.scene["until_s"]
        external = defaultdict(list)
        for e in self.w.scene["events"]:
            external[e["at"]].append(e)
        self.dispatch(external.pop(0, []))
        while self.active and self.time < until - EPS:
            rates = self.rates()
            for p, rate in list(rates.items()):
                if rate and self.balance(self.payer(p)) <= EPS:
                    self.finish(p, reason="supply_exhausted")
            if not self.active:
                break
            rates = self.rates()
            by_wallet = defaultdict(float)
            end = min([until, *external])
            for p, rate in rates.items():
                state = self.active[p]
                n = self.r.nodes[p]
                c = self.r.contracts[n["contract"]]
                end = min(end, state["start"] + c["max_s"])
                by_wallet[self.payer(p)] += rate
                if "repeat" in n and state["repeats"] < n["repeat"]["times"]:
                    end = min(end, state["start"] + (state["repeats"] + 1) * n["repeat"]["interval_s"])
                if rate and p == self.r.charge_node:
                    end = min(end, self.time + (self.r.quote["reserve_capacity"] - self.reserve) / rate)
            for payer, rate in by_wallet.items():
                if rate:
                    end = min(end, self.time + self.balance(payer) / rate)
            dt = end - self.time
            check(dt > 0, "clock", "时间步无法推进")
            self.time = end
            for p, rate in rates.items():
                if rate:
                    self.debit(self.payer(p), rate * dt)
                if p == self.r.charge_node:
                    self.reserve += rate * dt
                for op in self.r.nodes[p]["active"]:
                    if not self.action(p, op, dt):
                        self.finish(p, reason="missing_binding")
                        break
                if p in self.active:
                    self.art(p, "active")
            self.dispatch(external.pop(end, []))
        if not self.active:
            for h in list(self.handles):
                self.close(h)
            self.reserve = 0
        for handle, values in self.layers.items():
            ability = self.layer_abilities[handle]
            field = {
                "bear_load": "supported_load",
                "attenuate": "transmission",
                "illuminate": "illumination",
                "notify": "disturbance_detected",
            }[ability]
            for key, value in values.items():
                obj = self.w.objects[key]
                if field == "transmission":
                    obj[field] = obj.get(field, 1) * value
                elif field == "disturbance_detected":
                    obj[field] = True
                else:
                    obj[field] = obj.get(field, 0) + value
        self.result = {
            "status": "active" if self.active else "finished",
            "mana_spent": self.spent,
            "caster_mana": self.wallet,
            "reserve_ratio": self.ratio(),
            "delivered_impulse": self.delivered,
            "objects": self.w.objects,
            "effects": self.layers,
            "events": self.log,
            "expression": self.cues,
        }
        return deepcopy(self.result)
