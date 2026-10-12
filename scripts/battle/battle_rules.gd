extends RefCounted
## Pure rules, independent from drawing and animation.

static func cursor_at(elapsed: float, duration: float, trips: int = 2) -> float:
	var progress := clampf(elapsed / duration, 0.0, 1.0)
	return 1.0 - absf(fmod(progress * float(trips) * 2.0, 2.0) - 1.0)

static func grade(elapsed: float, duration: float, pressed: bool, half_width: float, trips: int = 2) -> String:
	if not pressed or elapsed >= duration:
		return "miss"
	if absf(cursor_at(elapsed, duration, trips) - 0.5) <= half_width:
		return "perfect"
	return "normal"

static func attack_damage(power: int, result: String) -> int:
	return power * (2 if result == "perfect" else (1 if result == "normal" else 0))

static func defense_damage(power: int, result: String) -> Dictionary:
	if result == "perfect":
		return {"received": 0, "reflected": power}
	return {"received": int(ceil(power * 0.5)) if result == "normal" else power, "reflected": 0}

static func living(units: Array) -> Array[int]:
	var indices: Array[int] = []
	for i in units.size():
		if int(units[i].hp) > 0:
			indices.append(i)
	return indices
