extends RefCounted
## Immutable attack recipe. Carriers inherit elements; terminal effects never spawn carriers.
const MAX_MAIN: int = 10
const MAX_ECHO: int = 3
const MAX_PIERCE: int = 3
const REPEAT_SCALES: Array[float] = [1.0,.6,.4,.3,.25]

static func repeat_scale(previous: int) -> float:
	return REPEAT_SCALES[clampi(previous,0,REPEAT_SCALES.size()-1)]

static func mechanics(cat: Dictionary) -> Dictionary:
	var active: Dictionary={}
	for kind: String in cat.fish:
		var config: Dictionary=cat.fish[kind]
		if int(config.get("level",1))>=3 and bool(config.get("mechanic_unlocked",true)): active[kind]=config
	return active

static func snapshot(cat: Dictionary, critical: bool, forced: bool = false) -> Dictionary:
	var fish: Dictionary=mechanics(cat).duplicate(true)
	# Old schema-2 mid-battle snapshots have no impact fields. Normalize without
	# replacing their existing coefficients, item IDs, cooldowns, or RNG state.
	if fish.has("F02"):
		var fire: Dictionary=fish.F02
		var quality: int=int(fire.get("quality",0))
		var level: int=int(fire.get("level",1))
		if not fire.has("impact"): fire.impact=.16+quality*.06+(level-1)*.035
		if not fire.has("impact_radius"): fire.impact_radius=70.0+quality*15+level*4
		if not fire.has("impact_count"): fire.impact_count=3+quality
	var elements: Array[String]=[]
	if fish.has("F02") or float(cat.get("toys",{}).get("explosion_ratio",0))>0: elements.append("fire")
	if fish.has("F06") or cat.id=="C03" or int(cat.get("toys",{}).get("chain_extra",0))>0: elements.append("electric")
	if fish.has("F04") or float(fish.get("F01",{}).get("freeze",0))>0: elements.append("ice")
	var mods: Array[String]=[]
	if int(fish.get("F01",{}).get("count",1))+int(cat.get("toys",{}).get("projectile_bonus",0))>1: mods.append("multishot")
	if int(fish.get("F01",{}).get("pierce",0))+int(fish.get("F03",{}).get("pierce",0))>0: mods.append("pierce")
	if float(fish.get("F01",{}).get("return_coef",0))+float(fish.get("F03",{}).get("return_coef",0))>0: mods.append("return")
	if int(fish.get("F05",{}).get("echo_every",0))>0: mods.append("echo")
	if fish.has("F07"): mods.append("critical")
	if fish.has("F08"): mods.append("shield")
	var ids: Array=fish.keys()
	ids.sort()
	return {"version":2,"weapon":cat.id,"base_attack":float(cat.attack),"fish":fish,"fish_ids":ids,"elements":elements,"mods":mods,"critical":critical,"forced":forced,"toys":cat.get("toys",{}).duplicate(true)}

static func context(cat: Dictionary, ctx: Dictionary) -> Dictionary:
	if not ctx.has("payload") or int(ctx.payload.get("version",0))<2: ctx.payload=snapshot(cat,bool(ctx.get("crit",false)),bool(ctx.get("forced",false)))
	return ctx.payload

static func visual(payload: Dictionary) -> Dictionary:
	var result: Dictionary={}
	for key: String in ["version","weapon","fish_ids","elements","mods","critical"]: result[key]=payload.get(key)
	return result

static func pierce(payload: Dictionary, carrier: String) -> int:
	var fish: Dictionary=payload.fish
	var count: int=int(fish.get("F01",{}).get("pierce",0))+int(fish.get("F03",{}).get("pierce",0))
	if carrier=="echo": count=maxi(count,int(fish.get("F05",{}).get("echo_pierce",0)))
	return clampi(count,0,MAX_PIERCE)

static func pierce_ratio(payload: Dictionary, carrier: String) -> float:
	var fish: Dictionary=payload.fish
	var ratio: float=maxf(float(fish.get("F01",{}).get("pierce_ratio",0)),float(fish.get("F03",{}).get("pierce_ratio",0)))
	if carrier=="echo": ratio=maxf(ratio,float(fish.get("F05",{}).get("echo_ratio",.7)))
	return ratio
