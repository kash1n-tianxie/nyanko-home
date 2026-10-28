extends RefCounted
## Short mix envelopes emphasize real events, never alter battle speed or damage.
## Selected Kenney CC0 cues; originals and normalization are documented beside them.
const UI_CLICK_PATH: String="res://audio/free-v040/ui_click.wav"
const INTERFACE_PATHS: Dictionary={
	"ui_click":UI_CLICK_PATH,
	"ui_purchase":"res://audio/free-v040/purchase.wav",
	"ui_equip":"res://audio/free-v040/equip.wav",
	"ui_refresh":"res://audio/free-v040/refresh.wav",
	"ui_merge":"res://audio/free-v040/merge.wav",
	"ui_skill_ready":"res://audio/free-v040/skill_ready.wav",
	"ui_tutorial_hint":"res://audio/free-v040/tutorial_hint.wav"
}

static func interface_route(data: Dictionary) -> Dictionary:
	var type: String=str(data.get("type",""))
	var key: String=""
	match type:
		"shop_purchase": key="ui_merge" if int(data.get("merged",0))>0 else "ui_purchase"
		"shop_refresh": key="ui_refresh"
		"equip", "unequip": key="ui_equip"
		"merge", "merge_all": key="ui_merge"
		"skill_ready": key="ui_skill_ready"
		"tutorial_hint": key="ui_tutorial_hint"
		"ui_click": key="ui_click"
	if key.is_empty(): return {}
	return {"key":key,"priority":2,"gain":.95 if type=="skill_ready" else .8,"interval":.8 if type=="skill_ready" else (2.0 if type=="tutorial_hint" else .08)}

var left: float=0.0
var emphasis: float=0.0
var priority: int=0
var first_toys: Dictionary={}

func reset() -> void:
	left=0.0
	emphasis=0.0
	priority=0
	first_toys.clear()

func notice(data: Dictionary) -> void:
	var type: String=str(data.get("type",""))
	if type=="stage_start":
		reset()
		return
	var duration: float=0.0
	var rank: int=0
	if type=="toy_trigger":
		var toy: String=str(data.get("source_toy",data.get("toy","")))
		if toy.is_empty() or first_toys.has(toy): return
		first_toys[toy]=true
		duration=.24;rank=1
	elif type=="toy_combo":
		duration=.32;rank=2
	elif type=="skill_cast":
		duration=.55;rank=3
	elif type=="skill_impact":
		duration=.28;rank=3
	elif type in ["boss_arrival","boss_counter_success"]:
		duration=.44;rank=3
	elif type=="boss_departure":
		duration=.72;rank=4
	if duration>0 and (left<=0 or rank>priority):
		left=duration
		priority=rank

func tick(delta: float) -> void:
	left=maxf(0.0,left-maxf(0.0,delta))
	emphasis=move_toward(emphasis,1.0 if left>0 else 0.0,maxf(0.0,delta)/(0.045 if left>0 else .38))
	if left<=0 and emphasis<=0: priority=0

func music_gain() -> float:
	return lerpf(1.0,.70,emphasis)

func routine_gain() -> float:
	return lerpf(1.0,.42,emphasis)

static func boss_route(data: Dictionary) -> Dictionary:
	if str(data.get("type",""))!="boss_cast": return {}
	var kind: String=str(data.get("kind",""))
	# Reuse the game's soft wood/coil/bell palette; no broadband whooshes.
	var keys: Dictionary={"B01":"C04_hit","B02":"C02_attack","B03":"T18","B04":"C03_hit","B05":"T13"}
	if not keys.has(kind): return {}
	return {"key":keys[kind],"priority":3,"gain":.46,"interval":.38,"pitch":.87 if kind in ["B01","B05"] else .94}
