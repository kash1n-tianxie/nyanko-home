extends RefCounted
## Shared world-space launch geometry. No texture loads or presentation settings.
## RELEASE_OFFSETS are the weapon tips at the authored release pose (88px cats).
## Tests compare them to CatPerformance.muzzle(RELEASE, false) to catch art drift.
const FEET: Array[Vector2] = [Vector2(209,169),Vector2(124,254),Vector2(295,313),Vector2(127,380),Vector2(295,437)]
## v0.3.7 frenzy sprite: 110px body, fixed foot anchor and authored fishbone tip.
const RAGE_RELEASE_OFFSET: Vector2=Vector2(98.5729272,-79.2969573)
const RELEASE_OFFSETS: Dictionary = {
	"C01":Vector2(99.6741603,-31.5231585),
	"C02":Vector2(38.3521507,-69.2794932),
	"C03":Vector2(45.76,-49.2699429),
	"C04":Vector2(61.2199211,.9126072),
	"C05":Vector2(54.8874538,-50.8394781),
	"C06":Vector2(50.744918,-71.3225981)}

static func origin(slot: int, cat_id: String) -> Vector2:
	return FEET[clampi(slot,0,4)]+Vector2(RELEASE_OFFSETS.get(cat_id,RELEASE_OFFSETS.C01))
