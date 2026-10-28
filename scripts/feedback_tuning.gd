extends RefCounted
## Presentation tunables; shared flight duration keeps the debuff and its art in sync.
const PATH: String = "res://data/feedback-v031.json"
static var _data: Dictionary = {}
static func section(id: String) -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary: _data = parsed
	return _data.get(id,{})
static func number(group: String, id: String, fallback: float) -> float:
	return float(section(group).get(id,fallback))
static func debuff_flight(distance: float) -> float:
	return clampf(distance/maxf(1.0,number("debuff","flight_speed",1900)),number("debuff","flight_min",.38),number("debuff","flight_max",.50))
