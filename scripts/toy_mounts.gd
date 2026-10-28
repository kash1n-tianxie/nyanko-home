extends RefCounted
## One acquisition-order map owns both the hanging prop and its source performance.
const HOOKS: Array[Vector2] = [Vector2(57,193),Vector2(57,270),Vector2(57,347),Vector2(57,424)]
const BOX: Vector2 = Vector2(304,488)
static func anchor(identity: String, held: Array = []) -> Vector2:
	var index: int = held.find(identity)
	if held.is_empty(): index=0
	return HOOKS[index] if index>=0 and index<HOOKS.size() else BOX
static func displayed(held: Array) -> Array:
	return held.slice(0,mini(4,held.size()))
