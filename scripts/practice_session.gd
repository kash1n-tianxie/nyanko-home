extends RefCounted
## Three isolated Run instances: a live demonstration and matched ten-second trials.
## No save, transaction, reward, seed or item reference reaches the player's Run.
const Run = preload("res://scripts/run_state.gd")
const Data = preload("res://scripts/catalog.gd")
const Ledger = preload("res://scripts/feedback_ledger.gd")
const DURATION: float = 10.0
const STEP: float = 1.0/60.0
var target_kind: String = "single"
var before_state: Dictionary = {}
var after_state: Dictionary = {}
var before_run: RefCounted
var after_run: RefCounted
var demo_run: RefCounted
var result: Dictionary = {}
var recent: Array = []
var sampled: Array = []
var elapsed: float = 0.0
var accumulator: float = 0.0
var compare_steps: int = 0
var cancelled: bool = false
var focus_cat: String = ""
var starting_before: Dictionary = {}
var starting_after: Dictionary = {}
var demo_round_limit: int = 0
var demo_finished: bool = false

func start(before: Dictionary, after: Dictionary, kind: String = "single", cat_id: String = "") -> void:
	target_kind=kind if kind in ["single","queue","cluster","air"] else "single"
	before_state=before.duplicate(true);after_state=after.duplicate(true)
	focus_cat=cat_id if cat_id in after.get("active",[]) else str(after.get("active",["C01"])[0])
	# Identical stream starting states. Different builds may consume different numbers
	# of random samples; no counterfactual per-hit damage is inferred from this trial.
	before_run=make_trial(before_state,target_kind)
	after_state.rng=before_state.rng.duplicate(true)
	after_run=make_trial(after_state,target_kind)
	demo_run=make_trial(after_state,target_kind)
	starting_before=before_run.combat.cat_display_stats(focus_cat)
	starting_after=after_run.combat.cat_display_stats(focus_cat)
	result={};recent=[];sampled=[];elapsed=0;accumulator=0;compare_steps=0;cancelled=false;demo_finished=false;demo_round_limit=0

static func make_trial(state: Dictionary, kind: String) -> RefCounted:
	var trial: RefCounted=Run.new()
	trial.new_run(31031,str(state.get("initial_cat","C01")))
	trial.s=state.duplicate(true)
	trial.autosave=false
	trial.s.phase="combat";trial.s.paused=false
	trial.s.pending="";trial.s.cast_left=0.0
	trial.combat.start_stage()
	var battle: Dictionary=trial.s.battle
	battle.schedule=[];battle.next_spawn=0;battle.duration=9999.0;battle.warned=true
	var points: Array[Vector2]=[Vector2(590,466)]
	if kind=="queue": points=[Vector2(550,466),Vector2(665,466),Vector2(780,466)]
	elif kind=="cluster": points=[Vector2(550,466),Vector2(595,448),Vector2(635,480),Vector2(675,452),Vector2(710,480)]
	elif kind=="air": points=[Vector2(565,265),Vector2(675,290),Vector2(785,250)]
	for point: Vector2 in points:
		var enemy: Dictionary=trial.combat.spawn("E08" if kind=="air" else "E03",point.x,true)
		enemy.hp=100000000.0;enemy.max_hp=100000000.0
		enemy.speed=0.0;enemy.damage=0.0;enemy.armor=0.0
		enemy.skill_left=9999.0;enemy.y=point.y;enemy.feet_y=point.y+float(enemy.draw_height)*.42
		enemy.practice=true
	trial.events.clear()
	return trial

func tick(delta: float) -> void:
	if cancelled or demo_run==null: return
	# Bounded batches keep the room responsive; the start button never awaits this.
	if compare_steps<600:
		for _i: int in range(mini(8,600-compare_steps)):
			before_run.step(STEP);after_run.step(STEP)
			before_run.events.clear();after_run.events.clear()
			compare_steps+=1
		if compare_steps==600: _finish_comparison()
	if elapsed>=DURATION or demo_finished: return
	accumulator+=minf(delta,.1)
	while accumulator>=STEP and elapsed<DURATION:
		if demo_round_limit>0:
			for cat: Dictionary in demo_run.s.battle.cats:
				if int(cat.attacks)>=demo_round_limit: cat.cooldown=9999.0
		demo_run.step(STEP);elapsed+=STEP;accumulator-=STEP
		for value: Dictionary in demo_run.events:
			if value.get("type","") not in ["attack","hit","chain","freeze","burn","toy_trigger","cat_buff","bell_return"]: continue
			var event: Dictionary=value.duplicate(true)
			event.event_time=elapsed;event.age=0.0
			recent.append(event)
		while recent.size()>48: recent.pop_front()
		demo_run.events.clear()
	for value: Dictionary in recent: value.age=elapsed-float(value.event_time)
	recent=recent.filter(func(value: Dictionary)->bool:return float(value.age)<.8)
	if sampled.size()<3 and elapsed>=float(sampled.size()+1)*.65: sampled.append(Ledger.snapshot(demo_run))
	if demo_round_limit>0:
		var all_fired: bool=demo_run.s.battle.cats.all(func(cat:Dictionary)->bool:return int(cat.attacks)>=demo_round_limit)
		var settled: bool=demo_run.s.battle.projectiles.is_empty() and demo_run.s.battle.support_returns.is_empty()
		var quiet: bool=recent.all(func(event:Dictionary)->bool:return float(event.age)>.45)
		demo_finished=all_fired and settled and quiet

func _finish_comparison() -> void:
	var first: Dictionary=Ledger.report(before_run)
	var second: Dictionary=Ledger.report(after_run)
	var before_stats: Dictionary=starting_before
	var after_stats: Dictionary=starting_after
	result={"target_kind":target_kind,"before_damage":float(first.total_damage),"after_damage":float(second.total_damage),"duration":DURATION,"before_control":first.get("support",{}),"after_control":second.get("support",{}),"before_attack":before_stats.attack,"after_attack":after_stats.attack,"before_rate":before_stats.rate,"after_rate":after_stats.rate,"events":recent.duplicate(true),"frames":sampled.duplicate(true),"before_report":first,"after_report":second,"note":"全队耐打靶 · 同起始随机数 · 无击杀/来袭"}

func frame() -> Dictionary:
	if cancelled or demo_run==null: return {}
	return {"target_kind":target_kind,"time":elapsed,"cats":demo_run.s.battle.cats,"enemies":demo_run.s.battle.enemies,"projectiles":demo_run.s.battle.projectiles if elapsed<DURATION and not demo_finished else [],"events":recent if elapsed<DURATION and not demo_finished else [],"running":elapsed<DURATION and not demo_finished}

func cancel() -> void:
	cancelled=true
	before_run=null;after_run=null;demo_run=null
	recent.clear();sampled.clear()

static func stats_for(state: Dictionary, cat_id: String) -> Dictionary:
	var trial: RefCounted=make_trial(state,"single")
	# Room chips show permanent stats; opening-eight-second buffs belong to the trial.
	trial.s.battle.time=8.0
	return trial.combat.cat_display_stats(cat_id)

static func thresholds(before: Dictionary, after: Dictionary, cat_id: String) -> Array[String]:
	var old: Dictionary={}
	for item: Dictionary in before.get("items",{}).values():
		if item.get("location","")=="equipped" and item.get("cat","")==cat_id: old[item.kind]=Data.effective(item,cat_id)
	var lines: Array[String]=[]
	for item: Dictionary in after.get("items",{}).values():
		if item.get("location","")!="equipped" or item.get("cat","")!=cat_id: continue
		var level: int=Data.effective(item,cat_id)
		var previous: int=int(old.get(item.kind,0))
		var tier: int=5 if level>=5 and previous<5 else (3 if level>=3 and previous<3 else 0)
		if tier==0: continue
		var config: Dictionary=Data.fish(item.kind,item.quality,level)
		lines.append("%s · 实际%d → 生效%d\n%s" % [Data.fish_name(item.kind),item.level,level,config.get("growth_description" if tier==5 else "mechanic_description","")])
	return lines
