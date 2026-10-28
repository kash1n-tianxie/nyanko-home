extends RefCounted
## Battle basket capacity is separate from the historical 128 loose-item safety cap.
## A purchased pending catch already owns its slot; taking it never needs another.
const BY_HQ: Array[int] = [5,10,15,20,25]

static func for_hq(level: int) -> int:
	return BY_HQ[clampi(level-1,0,BY_HQ.size()-1)]

static func count(items: Dictionary) -> int:
	var result: int = 0
	for value: Dictionary in items.values():
		if str(value.get("location","")) in ["basket","pending"]: result += 1
	return result

static func has_space(items: Dictionary, level: int) -> bool:
	return count(items)<for_hq(level)
