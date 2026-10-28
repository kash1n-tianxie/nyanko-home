extends SceneTree
## Earned-resource campaign runs. Automated policies, never presented as human playtests.
const Run=preload("res://scripts/run_state.gd")
const Data=preload("res://scripts/catalog.gd")
const POLICY_VERSION: int=3
const BATTLE_REVISION: String="engagement-r1"
const OUT="res://outputs/v033-upgrade/balance-engagement-r1"
var mode: String="easy"
var seed_value: int=41
var cat_id: String="C01"
var policy: String="adaptive"
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="): mode=arg.trim_prefix("--mode=")
		if arg.begins_with("--seed="): seed_value=int(arg.trim_prefix("--seed="))
		if arg.begins_with("--cat="): cat_id=arg.trim_prefix("--cat=")
		if arg.begins_with("--policy="): policy=arg.trim_prefix("--policy=")
	call_deferred("execute")
func recruit(model: RefCounted) -> void:
	var choices: Array=model.recruit_choices()
	if choices.is_empty(): return
	for preferred: String in ["C01","C03","C05","C02","C06","C04"]:
		if preferred in choices: model.command("recruit",{"cat":preferred});return
func outfit(model: RefCounted) -> void:
	for item: Dictionary in model.s.items.values().duplicate():
		if item.location=="equipped": model.command("unequip",{"id":item.id})
	model.command("merge_all")
	# First secure each cat's own mechanism; then allocate damage fish by role,
	# not by recruitment order (which had over-equipped a C06 starter).
	var order: Array=[]
	for id: String in ["C01","C03","C05","C02","C04","C06"]:
		if id in model.s.active: order.append(id)
	for id: String in order:
		var favorite: Dictionary={};var value: float=-1
		for item: Dictionary in model.s.items.values():
			if item.location not in ["inventory","inbox"] or item.kind not in Data.cats()[id].favorites: continue
			var score: float=Data.effective(item,id)*10+int(item.quality)*6
			if score>value: favorite=item;value=score
		if not favorite.is_empty(): model.command("equip",{"id":favorite.id,"cat":id,"slot":0})
	for slot: int in range(3):
		for id: String in order:
			if not model.equipped(id)[slot].is_empty(): continue
			var best: Dictionary={};var best_score: float=-1.0
			var used: Array=[]
			for equipped: Dictionary in model.equipped(id):
				if not equipped.is_empty(): used.append(equipped.kind)
			for item: Dictionary in model.s.items.values():
				if item.location not in ["inventory","inbox"] or item.kind in used: continue
				var effective: int=Data.effective(item,id)
				var score: float=effective*10+int(item.quality)*6
				if effective>=3: score+=18+float({"F01":13,"F02":14,"F03":10,"F06":13,"F09":8}.get(item.kind,4))
				if effective>=5: score+=20
				if id=="C06" and item.kind in ["F05","F08"]: score+=8
				if score>best_score: best=item;best_score=score
			if not best.is_empty(): model.command("equip",{"id":best.id,"cat":id,"slot":slot})

func choose_priorities(model: RefCounted) -> void:
	var stage: Dictionary=Data.stages()[int(model.s.stage)]
	var has_air: bool=int(stage.counts[7])+int(stage.counts[8])>0
	var antiair: String="C03" if "C03" in model.s.active else ("C02" if "C02" in model.s.active else "")
	var breaker: String="C01" if "C01" in model.s.active else (("C03" if "C03" in model.s.active else str(model.s.active[0])) if str(stage.boss)!="" else "")
	for id: String in model.s.active:
		var priority: String="threat" if id==breaker else ("air" if has_air and id==antiair else "nearest")
		model.command("cat_priority",{"cat":id,"priority":priority})

func aim_build(model: RefCounted) -> void:
	if not bool(model.bait_status().available): return
	var best: Dictionary={};var score: float=-1
	for item: Dictionary in model.s.items.values():
		if item.location not in ["inventory","equipped","inbox"] or int(item.level)>=5: continue
		var favored: bool=false
		for id: String in model.s.active:
			if str(item.kind) in Data.cats()[id].favorites: favored=true
		var candidate: float=float(item.level)*4+int(item.quality)*2+(12 if favored else 0)
		if str(item.kind) in ["F01","F02","F04","F06"]: candidate+=5
		if int(item.level)==1: candidate+=3
		if candidate>score: best=item;score=candidate
	if not best.is_empty(): model.command("bait_target",{"id":best.id})
func purchase(model: RefCounted) -> void:
	if policy=="no_build": return
	var stage_index: int=int(model.s.stage)
	var target: int=2 if stage_index<2 else (3 if stage_index<8 else (4 if stage_index<12 else 5))
	if int(model.s.hq)<target and int(model.s.gold)>=int(Data.hq(int(model.s.hq)+1).cost):
		model.command("upgrade");recruit(model)
	var reserve: int=0
	if int(model.s.hq)==2: reserve=62
	elif int(model.s.hq)==3 and stage_index>=5: reserve=250
	elif int(model.s.hq)==4 and stage_index>=9: reserve=440
	var casts_here: int=int(model.s.stage_casts.get(stage_index,0))
	# Allocate two casts per encounter before saving aggressively; no extra money.
	if casts_here<2:
		reserve=0
	elif int(model.s.hq)>=3 and float(model.s.hp)<float(model.s.max_hp)*.55 and casts_here<4:
		# At most two extra catches prepare the NEXT encounter. Fishing cannot
		# equip during combat; low HP must not spend every future HQ upgrade.
		reserve=mini(reserve,ceili(float(Data.hq(mini(5,int(model.s.hq)+1)).cost)*.5))
	if int(model.s.gold)-reserve>=model.cast_cost() and model.can_cast_capacity() and float(model.s.cast_left)<=0:
		model.command("cast")
	if model.s.pending!="" and float(model.s.cast_left)<=0: model.command("keep")
func execute() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var model: RefCounted=Run.new()
	model.save_path=OUT+"/isolated-unused-v3.save"
	model.new_run(seed_value,cat_id,false,mode)
	var ticks: int=0;var last_stage: int=-1;var rows: Array=[]
	var began: int=Time.get_ticks_msec()
	var counter_success: int=0;var counter_failure: int=0;var combos: int=0
	while model.s.phase not in ["failed","victory"] and ticks<240000:
		var phase: String=model.s.phase
		if phase=="toy_reward":
			var selected: String=model.s.reward_choices[0]
			var preferences: Array=["T10","T04","T05","T15","T03","T01","T13","T16","T11","T14","T06"]
			if float(model.s.hp)<float(model.s.max_hp)*.55: preferences=["T14","T11","T06","T04","T10","T13","T16","T03"]
			for preferred: String in preferences:
				if preferred in model.s.reward_choices: selected=preferred;break
			model.command("reward_choose",{"id":selected})
		elif phase=="route": model.command("route_continue")
		elif phase=="prep":
			if policy!="no_build":
				recruit(model);purchase(model);outfit(model);aim_build(model)
				choose_priorities(model)
			if int(model.s.stage)!=last_stage:
				rows.append({"stage":int(model.s.stage)+1,"hq":model.s.hq,"gold":model.s.gold,"hp":model.s.hp,"max_hp":model.s.max_hp,"fish":model.s.items.size(),"casts":model.s.stats.casts,"build":model.s.campaign_progress.run.duplicate(true)})
				last_stage=int(model.s.stage)
				print("RUN %s/%d/%s stage=%d hq=%d hp=%.0f gold=%d casts=%d" % [mode,seed_value,policy,last_stage+1,int(model.s.hq),float(model.s.hp),int(model.s.gold),int(model.s.stats.casts)])
				if last_stage in [3,7,11,15,19]: model.save(OUT+"/%s-%d-%s-%s-v%d-stage%02d.save" % [mode,seed_value,cat_id,policy,POLICY_VERSION,last_stage+1])
			model.command("start")
		else:
			if policy!="no_build":
				recruit(model)
				if ticks%30==0: purchase(model)
			model.step(1.0/60.0)
		for event: Dictionary in model.events:
			if event.type=="boss_counter_success": counter_success+=1
			if event.type=="boss_counter_failure": counter_failure+=1
			if event.type=="toy_combo": combos+=1
		model.events.clear();ticks+=1
	var result: Dictionary={"battle_revision":BATTLE_REVISION,"policy_version":POLICY_VERSION,"policy_notes":"role-first recruitment, favorite then damage-role allocation, no sole-AOE caster tunneling outside boss, HQ3 protects early62, max two emergency casts after HQ3 with 50% HQ reserve","active":model.s.active,"failure":model.s.get("failure_feedback",{}).get("last3",[]),"mode":mode,"seed":seed_value,"policy":policy,"cat":cat_id,"phase":model.s.phase,"stage":int(model.s.stage)+1,"hq":model.s.hq,"hp":model.s.hp,"gold":model.s.gold,"casts":model.s.stats.casts,"fish":model.s.items.size(),"toys":model.s.toys,"elapsed_game_s":ticks/60.0,"wall_s":(Time.get_ticks_msec()-began)/1000.0,"counter_success":counter_success,"counter_failure":counter_failure,"combos":combos,"history":rows,"milestones":model.s.campaign_progress.run,"total_hp_loss":model.s.stats.lost_hp}
	var file: FileAccess=FileAccess.open(OUT+"/%s-%d-%s-%s-v%d.json" % [mode,seed_value,cat_id,policy,POLICY_VERSION],FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "));file.close()
	print("COMPLETE "+JSON.stringify({"mode":mode,"seed":seed_value,"phase":model.s.phase,"stage":int(model.s.stage)+1,"hq":model.s.hq,"hp":model.s.hp,"casts":model.s.stats.casts,"counter_success":counter_success,"counter_failure":counter_failure,"wall_s":result.wall_s}))
	quit(0 if model.s.phase in ["failed","victory"] else 1)
