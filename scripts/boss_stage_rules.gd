extends RefCounted
## Shared combat/presentation anchors. The visible front is the actual target.
const VERSION: int = 35
const HIT: Vector2 = Vector2(730,430)
const BODY: Vector2 = Vector2(1080,510)
const CAST: Vector2 = Vector2(930,370)
const SUMMON_X: float = 1180.0
const ENTER_SECONDS: float = .8
const BASE: Vector2 = Vector2(350,400)

static func initialize(enemy: Dictionary, legacy: bool = false) -> void:
	var old_x: float=float(enemy.get("x",1320))
	var old_contact: bool=bool(enemy.get("contact",false)) or old_x<=BASE.x
	var speed: float=maxf(.001,float(enemy.get("speed",25)))
	var distance: float=maxf(0.0,float(enemy.get("spawn_x",1320))-BASE.x)
	enemy.boss_fixed=true;enemy.boss_stage_version=VERSION
	enemy.entrance_age=ENTER_SECONDS if legacy else 0.0
	enemy.legacy_approach_duration=distance/speed
	enemy.legacy_approach_elapsed=clampf((float(enemy.get("spawn_x",1320))-old_x)/speed,0,distance/speed) if legacy else 0.0
	if legacy and old_contact: enemy.legacy_approach_elapsed=enemy.legacy_approach_duration
	enemy.legacy_contact_ready=legacy and old_contact
	enemy.contact=false
	enemy.x=HIT.x;enemy.y=HIT.y;enemy.feet_y=500.0

static func visible(enemy: Dictionary) -> bool:
	return not bool(enemy.get("boss_fixed",false)) or float(enemy.get("entrance_age",0))+.000001>=ENTER_SECONDS

static func cast_point(kind: String) -> Vector2:
	# Deliberate logical sockets, calibrated to the painted release poses.
	return {"B01":Vector2(975,385),"B05":Vector2(1153,341)}.get(kind,CAST)

static func flight_duration(_action: String) -> float:
	# Equal transit time preserves the authored gap between consecutive impacts.
	return .50

static func geometry(enemy: Dictionary) -> Dictionary:
	return {"kind":enemy.kind,"target":enemy.id,"x":HIT.x,"y":HIT.y,"body_x":BODY.x,"body_y":BODY.y,"from_x":cast_point(str(enemy.kind)).x,"from_y":cast_point(str(enemy.kind)).y}

static func summon_x(index: int, spacing: float = 16.0) -> float:
	return minf(1270.0,SUMMON_X+float(index)*spacing)
