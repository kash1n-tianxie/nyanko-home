extends SceneTree
## Mechanism fixtures use controlled state; these are not human playtests.
const Run=preload("res://scripts/run_state.gd")
const Data=preload("res://scripts/catalog.gd")
var checks: int=0
var failures: Array[String]=[]
func _initialize() -> void: call_deferred("execute")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label);printerr("FAIL ",label)
func rig(cat_id: String="C01",mode: String="easy") -> RefCounted:
	var model: RefCounted=Run.new()
	model.new_run(35001,cat_id,false,mode);model.command("start")
	model.combat.b.schedule=[];model.combat.b.duration=9999
	for cat: Dictionary in model.combat.b.cats: cat.cooldown=9999
	return model
func events(model: RefCounted,type: String) -> Array:
	return model.events.filter(func(e:Dictionary)->bool:return e.type==type)
func ready_boss(model: RefCounted,kind: String="B01") -> Dictionary:
	var boss: Dictionary=model.combat.spawn(kind,-1,true)
	model.combat._tick_enemy(boss,.8)
	return boss
func finish_flights(model: RefCounted,delta: float=1.0) -> void:
	if model.combat.has_method("tick_boss_flights"): model.combat.call("tick_boss_flights",delta)
func force_heavy(model: RefCounted,boss: Dictionary) -> void:
	boss.skill_left=9999;boss.special_windup=.01
	model.combat._tick_enemy(boss,.02)
func execute() -> void:
	for kind: String in ["B01","B02","B03","B04","B05"]:
		var boss_model: RefCounted=rig()
		var tested_boss: Dictionary=boss_model.combat.spawn(kind,-1,true)
		check(is_equal_approx(float(tested_boss.x),730) and is_equal_approx(float(tested_boss.y),430),kind+" visible front is fixed at legal hit point")
		check(events(boss_model,"boss_arrival").size()==1,kind+" arrival emitted once")
		var skill_left: float=float(tested_boss.skill_left)
		boss_model.combat._tick_enemy(tested_boss,.79)
		check(not boss_model.combat.can_target(boss_model.combat.b.cats[0],tested_boss),kind+" hidden entrance cannot be targeted")
		check(is_equal_approx(float(tested_boss.skill_left),skill_left) and is_equal_approx(float(tested_boss.special_left),2),kind+" entrance freezes attack clocks")
		boss_model.combat._tick_enemy(tested_boss,.02)
		check(boss_model.combat.can_target(boss_model.combat.b.cats[0],tested_boss),kind+" visible entrance permits targeting")
		for _i: int in range(20): boss_model.combat._tick_enemy(tested_boss,.1)
		check(is_equal_approx(float(tested_boss.x),730) and is_equal_approx(float(tested_boss.y),430),kind+" attacks do not advance body or hit point")
		for cat_id: String in Data.cats():
			boss_model=rig(cat_id);tested_boss=ready_boss(boss_model,kind)
			var cat: Dictionary=boss_model.combat.b.cats[0]
			check(boss_model.combat.can_target(cat,tested_boss),kind+" reachable with original "+cat_id+" range")
			var before: float=float(tested_boss.hp)
			if boss_model.combat.can_target(cat,tested_boss):
				boss_model.combat.attack(cat,[tested_boss])
				for _i: int in range(120): boss_model.combat._tick_projectiles(1.0/60)
			check(float(tested_boss.hp)<before,kind+" original "+cat_id+" carrier actually hits")
		boss_model=rig();tested_boss=ready_boss(boss_model,kind)
		force_heavy(boss_model,tested_boss)
		check(boss_model.s.hp==300 and boss_model.combat.b.get("hostile_boss_flights",[]).size()==1,kind+" heavy launches without premature HP damage")
		check(events(boss_model,"boss_cast").size()==1,kind+" cast event matches pending attack")
		finish_flights(boss_model,.01)
		check(boss_model.s.hp==300,kind+" partial flight cannot damage")
		finish_flights(boss_model,1)
		check(float(boss_model.s.hp)<300 and events(boss_model,"boss_impact").size()==1,kind+" arrival resolves exactly one impact")
		var after: float=float(boss_model.s.hp)
		finish_flights(boss_model,1)
		check(boss_model.s.hp==after,kind+" resolved flight never repeats")
		boss_model=rig();tested_boss=ready_boss(boss_model,kind);force_heavy(boss_model,tested_boss)
		boss_model.combat.fx.damage(tested_boss,100000,"C01","test",1)
		finish_flights(boss_model,2)
		check(boss_model.s.hp==300 and boss_model.combat.b.get("hostile_boss_flights",[]).is_empty(),kind+" death cancels unlanded attack")
		check(events(boss_model,"boss_departure").size()==1,kind+" death emits one departure")
	var model: RefCounted=rig("C04")
	var boss: Dictionary=ready_boss(model)
	# Probe the configured boundary: x900 is inside the v041 ground-wave reach.
	var far: Dictionary=model.combat.spawn("E01",model.combat.BASE_X+float(model.combat.b.cats[0].range)+1.0,true)
	check(not model.combat.can_target(model.combat.b.cats[0],far),"ordinary targets retain C04 range")
	model.combat.b.cats[0].range=300
	check(not model.combat.can_target(model.combat.b.cats[0],boss),"boss has no infinite-range exemption")
	var old_x: float=float(far.x);model.combat._tick_enemy(far,1)
	check(float(far.x)<old_x,"ordinary enemies still advance")
	model=rig("C02");boss=ready_boss(model)
	var front: Dictionary=model.combat.spawn("E01",680,true);front.y=430
	var hp_before_area: float=float(boss.hp)
	model.combat.attack(model.combat.b.cats[0],[front])
	for _i: int in range(120): model.combat._tick_projectiles(1.0/60)
	check(float(boss.hp)<hp_before_area,"C02 actual splash uses the same visible boss hit point")
	model=rig("C05");boss=ready_boss(model);front=model.combat.spawn("E01",650,true);front.y=430
	far=model.combat.spawn("E01",1100,true);far.y=430
	var far_hp: float=float(far.hp);var boss_hp: float=float(boss.hp)
	model.combat.attack(model.combat.b.cats[0],[front])
	for _i: int in range(120): model.combat._tick_projectiles(1.0/60)
	check(float(boss.hp)<boss_hp and far.hp==far_hp,"C05 native pierce reaches fixed boss but not beyond original range")
	model=rig();boss=ready_boss(model);front=model.combat.spawn("E01",650,true)
	model.s.attack_mode="manual";model.s.aim_x=730;model.s.aim_y=430
	check(model.combat.targets_for(model.combat.b.cats[0])[0].id==boss.id,"manual aim chooses actual visible boss hit point")
	for intersects: bool in [true,false]:
		model=rig();boss=ready_boss(model)
		model.combat.attack(model.combat.b.cats[0],[boss])
		var projectile: Dictionary=model.combat.b.projectiles[0]
		projectile.confused=true;projectile.target_x=730;projectile.target_y=430 if intersects else 80;projectile.travel=.5
		boss_hp=float(boss.hp)
		for _i: int in range(40): model.combat._tick_projectiles(1.0/60)
		check((float(boss.hp)<boss_hp)==intersects,"confused ray only hits when crossing real front "+str(intersects))
	model=rig();boss=model.combat.spawn("B01",-1,true)
	check(model.combat.near_at(Vector2(730,430),100,10).is_empty() and model.combat.near(730,100,10).is_empty(),"entrance excludes indirect area and chain selection")
	var entrance_hp: float=float(boss.hp)
	model.combat.fx.damage(boss,40,"C01","test",1)
	check(boss.hp==entrance_hp,"entrance cannot take hidden direct or area damage")
	model.s.toys={"T13":1};model.combat.b.toy_timer_meteor=0
	model.combat.expansion.independent_toys(.01)
	check(events(model,"toy_cast").is_empty(),"independent toy cannot launch at an unrevealed boss")
	model.combat._tick_enemy(boss,1.0)
	check(is_equal_approx(float(boss.special_left),1.8),"entrance crossing only advances remaining active delta")
	# The follow-up keeps its original 0.4s interval at impact as well as launch.
	model=rig();boss=ready_boss(model,"B02");force_heavy(model,boss)
	finish_flights(model,.4);model.combat._tick_enemy(boss,.4)
	finish_flights(model,.1)
	check(events(model,"boss_impact").size()==1,"double bite first hit arrives alone")
	finish_flights(model,.39)
	check(events(model,"boss_impact").size()==1,"double bite cannot compress original follow-up gap")
	finish_flights(model,.01)
	check(events(model,"boss_impact").size()==2 and is_equal_approx(float(model.s.hp),264),"double bite second hit arrives 0.4s later with original damage")
	# No early contact attacks: B01's old 970px / 25px/s approach needs 38.8 active seconds.
	model=rig();boss=ready_boss(model);boss.skill_left=9999;boss.special_left=9999
	model.combat._tick_enemy(boss,38.0)
	check(model.s.hp==300 and events(model,"boss_cast").is_empty(),"base ordinary attack waits for legacy approach")
	model.combat._tick_enemy(boss,.8)
	check(is_equal_approx(float(boss.get("legacy_approach_elapsed",-1)),38.8) and bool(boss.get("legacy_contact_ready",false)),"legacy contact becomes ready at original approach duration")
	model.combat._tick_enemy(boss,.61)
	check(model.s.hp==300 and events(model,"boss_cast").size()==1,"ordinary boss attack is also a real pending flight")
	finish_flights(model)
	check(is_equal_approx(float(model.s.hp),282),"B01 ordinary base damage remains eighteen")
	model=rig();boss=ready_boss(model);boss.skill_left=9999;boss.special_left=9999;boss.slow=.5
	model.combat._tick_enemy(boss,38.8)
	check(not bool(boss.get("legacy_contact_ready",true)) and is_equal_approx(float(boss.get("legacy_approach_elapsed",-1)),19.4),"slow still delays legacy ordinary-attack activation")
	# Pause freezes pending attack flights; freeze stops new boss attacks, not launched carriers.
	model=rig();boss=ready_boss(model);force_heavy(model,boss)
	model.s.paused=true
	var frozen: PackedByteArray=var_to_bytes(model.combat.b)
	model.step(2)
	check(var_to_bytes(model.combat.b)==frozen and model.s.hp==300,"pause freezes boss entrance timers and flights")
	model.s.paused=false;boss.freeze=2;var skill: float=float(boss.skill_left)
	model.combat._tick_enemy(boss,.5)
	check(float(boss.skill_left)==skill,"freeze prevents boss new skill progression")
	finish_flights(model,1)
	check(model.s.hp<300,"already released hostile carrier completes while caster frozen")
	# A real save round-trip preserves remaining flight time, attack counts and RNG.
	model=rig();boss=ready_boss(model);force_heavy(model,boss);finish_flights(model,.1)
	var path: String="user://v035-boss-flight-test.save"
	check(model.save(path),"pending hostile flight save succeeds")
	var restored: RefCounted=Run.new()
	check(restored.load_save(path),"pending hostile flight load succeeds")
	check(var_to_bytes(model.combat.b.get("hostile_boss_flights",[]))==var_to_bytes(restored.combat.b.get("hostile_boss_flights",[])),"load preserves exact pending flight state")
	finish_flights(model,1);finish_flights(restored,1)
	check(model.s.hp==restored.s.hp and model.s.rng==restored.s.rng,"loaded flight resolves identical damage without reroll")
	model=rig();boss=ready_boss(model);boss.x=835;boss.y=390;boss.special_windup=.3
	model.combat.attack(model.combat.b.cats[0],[boss])
	var old_projectiles: PackedByteArray=var_to_bytes(model.combat.b.projectiles)
	for key: String in ["boss_fixed","boss_stage_version","entrance_age","legacy_approach_elapsed","legacy_approach_duration","legacy_contact_ready"]: boss.erase(key)
	model.combat.b.erase("boss_stage_version");model.combat.b.erase("hostile_boss_flights")
	model.save(path);restored=Run.new();check(restored.load_save(path),"old approaching save migrates")
	boss=restored.combat.b.enemies[0]
	check(boss.x==730 and boss.y==430 and float(boss.get("entrance_age",0))>=.8,"old save restores visible fixed boss without entrance immunity")
	check(is_equal_approx(float(boss.get("legacy_approach_elapsed",-1)),19.4) and is_equal_approx(float(boss.special_windup),.3),"old save preserves approach progress and ongoing windup")
	check(var_to_bytes(restored.combat.b.projectiles)==old_projectiles,"boss save migration preserves already flying cat carriers")
	# Existing shield, threshold summons, guard selection and damage-window rules remain real.
	model=rig();boss=ready_boss(model,"B02")
	model.combat.fx.damage(boss,1800,"C01","test",1)
	check(boss.shield==400,"B02 original half-health shield remains")
	for kind: String in ["B03","B05"]:
		model=rig();boss=ready_boss(model,kind)
		# v039 queues threshold reinforcement behind the normal battle clock.
		var entrance_count: int=model.combat.enemies().filter(func(e:Dictionary)->bool:return not e.boss).size()
		model.combat.fx.damage(boss,float(boss.max_hp)*.75,"C01","test",1)
		check(boss.get("boss_pending_summons",[]).size()==2,kind+" both threshold waves queued once")
		model.combat.b.cinematic={"active":true,"cat":"C01","age":0.0,"duration":3.2}
		model.step(.1)
		check(model.combat.enemies().size()==entrance_count+1,kind+" threshold waves wait through cat cinema")
		model.combat.b.cinematic={"active":false}
		model.combat._tick_enemy(boss,.01)
		var adds: Array=model.combat.enemies().filter(func(e:Dictionary)->bool:return not e.boss)
		# B05 entrance borrows two of its 12 threshold adds; B03 entrance borrows
		# two of its separate 12 lifetime skill summons. Neither expands its budget.
		check(adds.size()==(14 if kind=="B03" else 12) and (int(boss.get("summoned",0))==2 if kind=="B03" else int(boss.get("boss_threshold_summon_credit",0))==0),kind+" original finite reinforcement budget remains")
		check(adds.all(func(e:Dictionary)->bool:return float(e.x)>=1180 and float(e.x)<=1280 and int(e.gold)==0),kind+" threshold summons enter from right and pay zero gold")
	model=rig();boss=ready_boss(model,"B03");model.combat.expansion.cast_skill(boss)
	check(model.combat.enemies().filter(func(e:Dictionary)->bool:return not e.boss).all(func(e:Dictionary)->bool:return e.x>=1180 and e.gold==0),"skill summons also enter from right")
	model=rig();boss=ready_boss(model,"B01");boss.skill_left=0
	var guard: Dictionary=model.combat.spawn("E03",650,false)
	model.combat._tick_enemy(boss,.01)
	check(boss.get("counter_state",{}).get("targets",[]).has(guard.id),"B01 counter still selects authored guard")
	model.combat.fx.damage(guard,10000,"C01","test",1);model.combat._tick_enemy(boss,.01)
	check(events(model,"boss_counter_success").size()==1 and boss.counter_stagger>0,"guard defeat still cancels charge and staggers")
	model=rig();boss=ready_boss(model,"B04");boss.skill_left=0;model.combat._tick_enemy(boss,.01)
	model.combat.fx.damage(boss,245,"C01","test",1);model.combat._tick_enemy(boss,.01)
	check(events(model,"boss_counter_success").size()==1,"B04 2.5 percent actual damage counter remains")
	for difficulty: String in ["easy","hard","hell"]:
		model=rig("C01",difficulty);boss=ready_boss(model)
		var damage: float={"easy":22.0,"hard":25.3,"hell":28.6}[difficulty]
		check(is_equal_approx(float(boss.heavy_damage),damage),difficulty+" authored heavy difficulty multiplier applied once")
		var duration: float=float(boss.get("legacy_approach_duration",0))
		model.s.hq=5;model.combat.refresh_team_bonuses()
		check(is_equal_approx(float(boss.get("legacy_approach_duration",0)),duration) and is_equal_approx(float(boss.heavy_damage),damage),difficulty+" no secret HQ boss scaling")
	model=rig();boss=ready_boss(model);force_heavy(model,boss);model.s.hp=0;model.settle_stage()
	check(model.combat.b.get("hostile_boss_flights",[]).is_empty(),"failure settlement clears pending hostile flights")
	model=rig();boss=ready_boss(model);force_heavy(model,boss);model.settle_stage()
	check(model.combat.b.get("hostile_boss_flights",[]).is_empty(),"success settlement also clears pending hostile flights")
	var result: Dictionary={"checks":checks,"ok":failures.is_empty(),"failures":failures,"scope":"controlled fixed-boss mechanism fixtures; not human playtesting"}
	print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
