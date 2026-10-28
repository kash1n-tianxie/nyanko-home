extends RefCounted
## A visual impulse around the sprite's existing foot pivot. No position or HP writes.
const DURATION: float = .30
const RETRIGGER_AFTER: float = .105
const KEYS: Array[Vector2] = [Vector2.ONE, Vector2(1.17,.81), Vector2(.94,1.095), Vector2(1.025,.975), Vector2.ONE]
const TIMES: Array[float] = [0.0,.045,.13,.215,DURATION]

static func sample(age: float, reduced: bool = false, frozen: bool = false, boss: bool = false) -> Vector2:
	if age < 0 or age >= DURATION: return Vector2.ONE
	var impulse: Vector2 = Vector2.ONE
	for index: int in range(TIMES.size()-1):
		if age <= TIMES[index+1]:
			var t: float = smoothstep(TIMES[index],TIMES[index+1],age)
			impulse = KEYS[index].lerp(KEYS[index+1],t)
			break
	var strength: float = .62 if boss else 1.0
	if reduced: strength *= .22
	if frozen: strength *= .3
	return Vector2.ONE.lerp(impulse,strength)

static func flash(age: float) -> float:
	return 0.0 if age < 0 else 1.0-clampf(age/.16,0.0,1.0)
