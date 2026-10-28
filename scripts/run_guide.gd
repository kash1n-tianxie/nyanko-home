extends RefCounted
## Presentation progress. Call observe only after a successful run command.
## This metadata never changes economy, RNG, equipment or combat state.
static func ensure(state: Dictionary) -> Dictionary:
	if not state.get("guidance",null) is Dictionary:
		state.guidance={"version":2,"done":{},"dismissed":false}
	var guide: Dictionary=state.guidance
	if not guide.get("done",null) is Dictionary: guide.done={}
	if not guide.get("dismissed",null) is bool: guide.dismissed=false
	guide.version=2
	return guide

static func completed(state: Dictionary,key: String) -> bool:
	return bool(ensure(state).done.get(key,false))

static func observe(state: Dictionary,action: String) -> void:
	if state.is_empty(): return
	var done: Dictionary=ensure(state).done
	match action:
		"choose_fish": done.starter_fish=true
		"shop_buy": done.shop=true
		"equip": done.equip=true
		"upgrade": done.upgrade=true
		"recruit": done.recruit=true
		"start": done.start=true
		"cat_skill": done.skill=true
