extends RefCounted
## Inclusive 5x5 square, centred on the actor's current cell.
static func in_range(origin: Vector2i, target: Vector2i) -> bool:
	var d := target-origin
	return absi(d.x)<=2 and absi(d.y)<=2

static func choose(candidates: Array, current: Variant, random: RandomNumberGenerator) -> Variant:
	if current != null and current in candidates: return current
	return candidates[random.randi_range(0,candidates.size()-1)] if not candidates.is_empty() else null
