extends RefCounted
## Explicit next-cast price; payment remains attached to every caught item.
const VERSION: int = 30
const CAST_BASE: Array[int] = [6,8,11,15,18]
const CAST_STEP: int = 3
const MAX_SURCHARGE: int = 8
const DIRECTED_SURCHARGE: int = 4

static func cast_cost(hq_level: int, stage_casts: int) -> int:
	return CAST_BASE[clampi(hq_level-1,0,4)]+mini(MAX_SURCHARGE,floori(float(maxi(0,stage_casts))/CAST_STEP))

static func refund(paid_basis: int) -> int:
	return maxi(0,floori(float(paid_basis)/2.0))
