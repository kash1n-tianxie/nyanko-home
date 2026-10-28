extends RefCounted
## Presentation curves only. No simulation writes, random draws, timers or damage callbacks.
## The 0.12 s windup is the launch delay already used by Combat.queue_hit.
const Art = preload("res://scripts/illustrated_atlas.gd")
const Sprites = preload("res://scripts/cat_sprite_art.gd")
const RELEASE: float = .12
const DURATIONS: Dictionary = {"C01":.46,"C02":.54,"C03":.40,"C04":.58,"C05":.56,"C06":.42}
const COLORS: Dictionary = {"C01":"efaa5c","C02":"c89672","C03":"a799dc","C04":"91b998","C05":"bda2d1","C06":"dfb65e"}

static func duration(id: String) -> float:
	return float(DURATIONS.get(id,.46))

static func color(id: String) -> Color:
	return Color(str(COLORS.get(id,"efaa5c")))

static func sample(id: String, age: float, reduced: bool = false) -> Dictionary:
	var result: Dictionary = {"pose":"idle","offset":Vector2.ZERO,"scale":Vector2.ONE,"rotation":0.0,"phase":"idle","strength":0.0}
	if age<0 or age>=duration(id): return result
	var windup: bool = age<RELEASE
	var anticipation: float = clampf(age/RELEASE,0,1)
	var strike: float = 1.0-clampf((age-RELEASE)/.14,0,1)
	var recovery: float = clampf((age-RELEASE-.14)/(duration(id)-RELEASE-.14),0,1)
	result.phase = "windup" if windup else ("strike" if age<RELEASE+.14 else "recovery")
	result.pose = "windup" if windup else ("attack" if age<RELEASE+.14 else "recover")
	result.strength = anticipation if windup else maxf(0,strike)
	# Accessibility retains the actual pose change and weapon signal, with no body rocking.
	var source_scale: float=Sprites.pose_scale(id,str(result.pose))
	if reduced:
		result.scale=Vector2.ONE*source_scale
		return result
	var kick: float = strike if not windup else 0.0
	var settle: float = sin(recovery*PI)*.025 if result.phase=="recovery" else 0.0
	match id:
		"C01": # Crouch backward, slash through a forward lean, then settle.
			result.rotation = -.10*anticipation if windup else .13*kick-settle
			result.scale = Vector2(1+.06*anticipation,1-.07*anticipation) if windup else Vector2(1-.035*kick,1+.055*kick)
			result.offset = Vector2(-4*anticipation,0) if windup else Vector2(8*kick,0)
		"C02": # Pull the sling across the belly; the release recoils the whole cat.
			result.rotation = -.065*anticipation if windup else -.12*kick+settle
			result.scale = Vector2(1-.045*anticipation,1+.025*anticipation) if windup else Vector2(1+.09*kick,1-.07*kick)
			result.offset = Vector2(-6*anticipation,0) if windup else Vector2(-9*kick,0)
		"C03": # Socket-cat hunches, then stiffens like a shocked tuning fork.
			result.rotation = .025*anticipation if windup else sin((age-RELEASE)*75)*.04*kick
			result.scale = Vector2(1+.045*anticipation,1-.04*anticipation) if windup else Vector2(1-.09*kick,1+.065*kick)
		"C04": # Stamp hammer winds up vertically, then compresses hard on impact.
			result.rotation = -.11*anticipation if windup else .14*kick-settle
			result.scale = Vector2(1-.04*anticipation,1+.065*anticipation) if windup else Vector2(1+.14*kick,1-.14*kick)
			result.offset = Vector2(-3*anticipation,0) if windup else Vector2(7*kick,0)
		"C05": # The long cat inhales; its yawn-horn exhales in one ridiculous squeeze.
			result.rotation = -.035*anticipation if windup else .075*kick
			result.scale = Vector2(1+.06*anticipation,1+.035*anticipation) if windup else Vector2(1-.07*kick,1-.055*kick)
			result.offset = Vector2(-2*anticipation,0) if windup else Vector2(5*kick,0)
		"C06": # Alternating bell-hand shake; the lid remains a readable guard silhouette.
			result.rotation = -.065*anticipation if windup else sin((age-RELEASE)*38+PI*.5)*.11*kick
			result.scale = Vector2(1,1-.025*anticipation) if windup else Vector2(1+.03*kick,1+.02*kick)
	result.scale*=source_scale
	return result

static func muzzle(id: String, age: float = RELEASE, reduced: bool = false) -> Vector2:
	var pose: Dictionary = sample(id,age,reduced)
	var local: Vector2 = Art.cat_muzzle(id,str(pose.pose),88.0)
	return (local*Vector2(pose.scale)).rotated(float(pose.rotation))+Vector2(pose.offset)
