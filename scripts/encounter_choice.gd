extends RefCounted
## Optional chapter-three detours. Only presentation, authored extra enemies,
## and a visible one-time victory bounty differ from the standard encounter.
const Data=preload("res://scripts/catalog.gd")
const TITLES: Array[String]=["追上飞走的零钱", "重罐头押运", "剪开蛛网封锁", "抢回天台零食", "滚筒外的最后一袋钱"]
const EXTRAS: Array=[
	[{"kind":"E08","count":3},{"kind":"E02","count":3}],
	[{"kind":"E05","count":3},{"kind":"E09","count":2}],
	[{"kind":"E10","count":2},{"kind":"E03","count":4}],
	[{"kind":"E09","count":4},{"kind":"E06","count":2}],
	[{"kind":"E10","count":3},{"kind":"E05","count":4}]]

static func eligible(stage: int) -> bool:
	return stage>=0 and stage<Data.total_stages() and stage%4==2

static func migrate(state: Dictionary) -> bool:
	if not state.has("encounter_choices"): state.encounter_choices={}
	if not state.encounter_choices is Dictionary: return false
	for key: Variant in state.encounter_choices:
		if not key is String or not key.is_valid_int(): return false
		var stage: int=int(key)
		if str(stage)!=key or not eligible(stage): return false
		if state.encounter_choices[key] not in ["normal","risk"]: return false
	return true

static func status(run: RefCounted) -> Dictionary:
	var stage: int=int(run.s.stage)
	var available: bool=eligible(stage)
	var chapter: int=clampi(floori(stage/4.0),0,4)
	var choice: String=str(run.s.get("encounter_choices",{}).get(str(stage),"normal"))
	var extras: Array=EXTRAS[chapter].duplicate(true) if available else []
	var parts: PackedStringArray=[]
	for group: Dictionary in extras:
		parts.append("%s×%d"%[Data.enemies()[group.kind].name,int(group.count)])
	return {"available":available,"choice":choice,"title":TITLES[chapter] if available else "常规守家",
		"detail":"额外来袭：%s；胜利后领取悬赏，增援不掉金币。"%"、".join(parts) if available else "按原定敌群推进。",
		"reward_gold":10+chapter*2 if available else 0,"extra_enemies":extras,
		"locked":str(run.s.phase)!="prep" or stage in run.s.get("settled",[])}

static func command(run: RefCounted,args: Dictionary) -> Dictionary:
	var info: Dictionary=status(run)
	if not info.available or info.locked: return run._result(false,"仅本章第三关出发前可选额外悬赏")
	var choice: String=str(args.get("choice",""))
	if choice not in ["normal","risk"]: return run._result(false,"请选择常规守家或额外悬赏")
	run.s.encounter_choices[str(int(run.s.stage))]=choice
	return run._result(true,"额外悬赏已接下 · 胜利 +%d 金币"%int(info.reward_gold) if choice=="risk" else "常规守家 · 不增加敌人")

static func augment_schedule(run: RefCounted,schedule: Array) -> void:
	var info: Dictionary=status(run)
	if not info.available or info.choice!="risk": return
	# Idempotent so a resumed battle or preview cannot double the detour wave.
	for entry: Dictionary in schedule:
		if bool(entry.get("risk_extra",false)): return
	var duration: float=Data.stages()[int(run.s.stage)].duration
	var index: int=0
	for group: Dictionary in info.extra_enemies:
		for n: int in range(int(group.count)):
			var entry: Dictionary={"time":duration*(.29 if index%2==0 else .57)+float(n)*.45,
				"kind":group.kind,"x":1288.0+float(n%3)*22.0,"wave":1 if index%2==0 else 2,
				"wave_name":"悬赏增援","free":true,"risk_extra":true}
			# Preserve the original order when authored entries share a timestamp.
			var at: int=schedule.size()
			for j: int in range(schedule.size()):
				if float(schedule[j].time)>float(entry.time): at=j;break
			schedule.insert(at,entry)
		index+=1

static func victory_reward(run: RefCounted) -> int:
	var info: Dictionary=status(run)
	return int(info.reward_gold) if info.available and info.choice=="risk" else 0
