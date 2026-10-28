extends SceneTree
const Run=preload("res://scripts/run_state.gd")
const Advisor=preload("res://scripts/shop_advisor.gd")
const Data=preload("res://scripts/catalog.gd")
const OUT="res://outputs/v039/review"
var checks: int=0
var failures: Array[String]=[]
var evidence: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value and label not in failures: failures.append(label);printerr("FAIL ",label)
func _initialize() -> void: call_deferred("execute")
func execute() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_shop()
	_boss()
	var result: Dictionary={"checks":checks,"failures":failures,"evidence":evidence}
	var file: FileAccess=FileAccess.open(OUT+"/logic.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "));file.close()
	print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
func _shop() -> void:
	var rng:=RandomNumberGenerator.new();rng.seed=391025
	for scenario: int in range(180):
		var r: RefCounted=Run.new();r.new_run(39000+scenario,"C01",false,"hard")
		r.s.items.clear();r.s.hq=rng.randi_range(1,5);r.s.gold=100
		r.s.active=["C01","C02","C03","C04","C05"];r.s.owned=r.s.active.duplicate()
		r.s.shop.auto_merge=scenario%3!=0
		for c: String in r.s.active:
			var used: Array=[]
			for slot: int in range(3):
				var kind: String=Data.fish_kinds()[rng.randi_range(0,9)]
				if kind in used or rng.randf()<.3: continue
				used.append(kind)
				var worn: Dictionary=r.create_item(kind,rng.randi_range(0,2),rng.randi_range(1,5),rng.randi_range(0,50),"equipped")
				worn.cat=c;worn.slot=slot
		for index: int in range(rng.randi_range(0,int(r.s.hq)*5+2)):
			var loose_item: Dictionary=r.create_item(Data.fish_kinds()[rng.randi_range(0,9)],rng.randi_range(0,2),rng.randi_range(1,4),rng.randi_range(0,50),"inventory")
			loose_item.reserved=rng.randf()<.25
		var chosen: String=str(r.s.active[scenario%5]);var slot: int=scenario%3
		r.s.shop.offers[0]={"id":"review_offer","kind":Data.fish_kinds()[rng.randi_range(0,9)],"level":rng.randi_range(1,3),"quality":rng.randi_range(0,2),"price":6,"paid_basis":6,"sold":false,"ordered":false}
		var before: PackedByteArray=var_to_bytes(r.s);var notices: PackedByteArray=var_to_bytes(r.events)
		var preview: Dictionary=Advisor.preview(r,0,chosen,slot)
		check(before==var_to_bytes(r.s) and notices==var_to_bytes(r.events),"preview source immutable "+str(scenario))
		var actual: RefCounted=Advisor._copy(r)
		var bought: Dictionary=actual.command("shop_buy",{"slot":0,"offer_id":"review_offer"})
		if not bought.ok:
			check(not preview.valid and preview.reason==bought.message,"capacity purchase rejection parity "+str(scenario));continue
		var item: Dictionary=actual.item(str(preview.item.id))
		check(not item.is_empty() and int(item.level)==int(preview.item.level) and item.kind==preview.item.kind,"real recursive descendant "+str(scenario))
		var result: Dictionary=actual.command("equip",{"id":str(preview.item.id),"cat":chosen,"slot":slot})
		check(preview.valid==result.ok and preview.reason==result.message,"real equip rejection parity "+str(scenario))
		if result.ok:
			actual.combat.start_stage();actual.s.battle.time=10.0
			var stats: Dictionary=actual.combat.cat_display_stats(chosen)
			check(is_equal_approx(float(stats.attack),float(preview.after.attack)) and is_equal_approx(float(stats.rate),float(preview.after.rate)),"real attack rate stat parity "+str(scenario))
		check(Advisor.preview(r,-1,chosen,slot).is_empty() and Advisor.preview(r,0,chosen,3).is_empty(),"invalid slot cannot preview "+str(scenario))
	evidence.append({"shop_scenarios":180,"coverage":"all cat types except C06, all slots, HQ1-5, full/overfull inventory, auto merge toggle, random reserved fish, random qualities/levels"})
func _boss() -> void:
	for kind: String in ["B01","B02","B03","B04","B05"]:
		var r: RefCounted=Run.new();r.new_run(39100,"C01",false,"hard");r.command("start")
		r.s.battle.schedule=[];r.s.battle.duration=9999;r.s.hp=100000;r.s.max_hp=100000
		for cat: Dictionary in r.s.battle.cats: cat.cooldown=100000
		var boss: Dictionary=r.combat.spawn(kind,-1,true)
		var casts: Dictionary={};var impacts: Dictionary={};var actions: Dictionary={};var counter_count: int=0;var transition_count: int=0
		var resumed: bool=false
		for frame: int in range(12000):
			if frame==6000: boss.hp=float(boss.max_hp)*.49
			r.step(1.0/60)
			var heavy: bool=float(boss.special_windup)>0 or float(boss.second_bite)>=0
			check(not (heavy and not boss.get("counter_state",{}).is_empty()),kind+" counter and heavy never overlap")
			if str(boss.get("boss_state",""))=="transition":
				check(not heavy and boss.get("counter_state",{}).is_empty() and r.s.battle.hostile_boss_flights.is_empty(),kind+" transition waits until current attacks finish")
			for event: Dictionary in r.events:
				if event.type=="boss_cast":
					check(not casts.has(event.id),kind+" unique cast id")
					casts[event.id]=float(r.s.battle.time);actions[event.action]=int(actions.get(event.action,0))+1
					check(Vector2(event.from_x,event.from_y)==r.combat.BossRules.cast_point(kind) and Vector2(event.to_x,event.to_y)==Vector2(350,400),kind+" fixed origin and real base endpoint")
				if event.type=="boss_impact":
					check(casts.has(event.id) and not impacts.has(event.id),kind+" one impact per cast")
					if casts.has(event.id): check(is_equal_approx(float(r.s.battle.time)-float(casts[event.id]),.5),kind+" damage occurs after full flight")
					impacts[event.id]=true
				if event.type=="boss_counter_warning": counter_count+=1
				if event.type=="boss_phase" and event.phase==2: transition_count+=1
			r.events.clear()
			if not resumed and frame>200 and str(boss.get("boss_state",""))=="windup":
				var path: String=OUT+"/"+kind+"-windup.save"
				check(r.save(path),kind+" isolated midwindup save")
				var loaded: RefCounted=Run.new();check(loaded.load_save(path),kind+" midwindup load")
				var duplicate: RefCounted=Advisor._copy(r)
				# Existing save migrations add inert defaults; compare gameplay with
				# those same defaults on the un-reloaded branch.
				duplicate.combat.skills.migrate()
				if not duplicate.s.has("last_feedback_report"): duplicate.s.last_feedback_report={}
				if not duplicate.s.has("failure_feedback"): duplicate.s.failure_feedback={}
				for subframe: int in range(120): duplicate.step(1.0/60);loaded.step(1.0/60)
				var differences: Array=[]
				_diff(duplicate.s,loaded.s,"s",differences)
				if not differences.is_empty(): evidence.append({"boss":kind,"save_differences":differences})
				check(differences.is_empty(),kind+" midwindup save deterministic replay")
				resumed=true
		check(counter_count>0,kind+" naturally reaches counter skill")
		check(actions.has("contact") and actions.size()>=2,kind+" naturally reaches heavy and contact actions")
		check(transition_count==1 and int(boss.boss_phase)==2,kind+" exactly one phase transition")
		check(resumed,kind+" exercised save replay")
		evidence.append({"boss":kind,"seconds":200,"casts":casts.size(),"impacts":impacts.size(),"actions":actions,"counter_warnings":counter_count,"phase_transitions":transition_count})
		var old_hp: float=float(r.s.hp)
		r.combat.launch_boss_attack(boss,55,"review_death")
		r.combat.fx.damage(boss,10000000,"C01","test",1)
		r.combat.tick_boss_flights(2)
		check(float(r.s.hp)==old_hp and r.s.battle.hostile_boss_flights.is_empty(),kind+" dying source cannot deliver pending base damage")
func _diff(a: Variant,b: Variant,path: String,result: Array) -> void:
	if a is Dictionary and b is Dictionary:
		for key: Variant in a:
			if not b.has(key): result.append(path+" missing "+str(key))
			else: _diff(a[key],b[key],path+"."+str(key),result)
		for key: Variant in b:
			if not a.has(key): result.append(path+" added "+str(key))
	elif a is Array and b is Array:
		if a.size()!=b.size(): result.append(path+" size "+str(a.size())+" -> "+str(b.size()))
		else:
			for index: int in range(a.size()): _diff(a[index],b[index],path+"["+str(index)+"]",result)
	elif a!=b: result.append({"path":path,"a":a,"b":b})
