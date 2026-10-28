extends SceneTree
## Controlled encounter fixtures. No player save; not human playtesting.
const Run=preload("res://scripts/run_state.gd")
var failures: Array[String]=[]
var checks: int=0
func _initialize() -> void: call_deferred("execute")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label);printerr("FAIL ",label)
func rig(kind: String="B01") -> RefCounted:
	var model: RefCounted=Run.new();model.new_run(39001,"C01",false,"easy");model.command("start")
	model.combat.b.schedule=[];model.combat.b.duration=9999
	model.s.hp=10000;model.s.max_hp=10000
	for cat: Dictionary in model.combat.b.cats: cat.cooldown=9999
	model.combat.spawn(kind,-1,true)
	return model
func advance(model: RefCounted,seconds: float) -> void:
	for _i: int in range(ceili(seconds*60)): model.step(1.0/60)
func notices(model: RefCounted,type: String) -> Array:
	return model.events.filter(func(e:Dictionary)->bool:return e.type==type)
func execute() -> void:
	for kind: String in ["B01","B02","B03","B04","B05"]:
		var phase_model: RefCounted=rig(kind)
		var phase_boss: Dictionary=phase_model.combat.b.enemies[0]
		check(int(phase_boss.get("boss_phase",0))==1,kind+" starts in readable reinforcement phase")
		advance(phase_model,1.0)
		check(is_equal_approx(float(phase_boss.x),730) and is_equal_approx(float(phase_boss.y),430),kind+" keeps finite visible target anchor")
		check(notices(phase_model,"boss_phase").size()==1,kind+" reinforcement phase announces once")
		var adds: Array=phase_model.combat.enemies().filter(func(e:Dictionary)->bool:return not e.boss)
		check(not adds.is_empty() and adds.all(func(e:Dictionary)->bool:return e.gold==0),kind+" visible finite entrance reinforcement pays no gold")
		phase_boss.skill_left=9999;phase_boss.special_left=9999
		phase_boss.hp=float(phase_boss.max_hp)*.49
		var cine: Dictionary={"active":true,"cat":"C01","age":0.0,"duration":3.2}
		phase_model.combat.b.cinematic=cine
		var before: PackedByteArray=var_to_bytes(phase_boss)
		phase_model.step(1)
		check(before==var_to_bytes(phase_boss),kind+" phase waits through cat cinema")
		phase_model.combat.b.cinematic={"active":false}
		advance(phase_model,.1)
		check(int(phase_boss.get("boss_phase",0))==2 and str(phase_boss.get("boss_state",""))=="transition",kind+" half HP begins visible phase transition")
		check(notices(phase_model,"boss_phase").size()==2,kind+" phase change emitted once")
		advance(phase_model,1.5)
		check(bool(phase_boss.get("legacy_contact_ready",false)),kind+" exposed phase opens real direct-base pressure")
		# Freeze regular heavy and counter; observe the ordinary pressure attack.
		phase_boss.special_left=9999;phase_boss.skill_left=9999;phase_boss.attack_left=.6
		var hp_before: float=float(phase_model.s.hp)
		advance(phase_model,.62)
		check(float(phase_model.s.hp)==hp_before,kind+" base damage waits for visible flight")
		check(not phase_model.combat.b.get("hostile_boss_flights",[]).is_empty(),kind+" direct pressure releases carrier")
		advance(phase_model,.55)
		check(float(phase_model.s.hp)<hp_before and notices(phase_model,"boss_impact").size()==1,kind+" carrier impact accounts exactly once")
		check(is_equal_approx(float(phase_boss.x),730),kind+" exposed phase does not advance body")
		phase_boss.special_left=9999;phase_boss.skill_left=9999
		var count_before: int=phase_model.combat.enemies().size()
		advance(phase_model,.3)
		check(phase_model.combat.enemies().size()==count_before,kind+" transition cannot repeat summon")
		phase_model.s.paused=true;before=var_to_bytes(phase_model.combat.b);phase_model.step(2)
		check(before==var_to_bytes(phase_model.combat.b),kind+" pause freezes all encounter clocks")
		phase_model.s.paused=false
		phase_model.combat.fx.damage(phase_boss,1000000,"C01","test",1)
		phase_model.combat.b.enemies=phase_model.combat.b.enemies.filter(func(e:Dictionary)->bool:return e.boss)
		var cast_count: int=notices(phase_model,"boss_cast").size();advance(phase_model,3)
		check(notices(phase_model,"boss_cast").size()==cast_count and phase_model.combat.b.get("hostile_boss_flights",[]).is_empty(),kind+" death cancels future attack and hostile flight")
	# A phase change cannot replace a committed shot or duplicate its damage.
	var pending: RefCounted=rig("B05");advance(pending,1)
	var pending_boss: Dictionary=pending.combat.b.enemies[0]
	pending.combat.launch_boss_attack(pending_boss,28,"moon_tide")
	check(pending.combat.b.hostile_boss_flights[0].from_x==1153 and pending.combat.b.hostile_boss_flights[0].from_y==341,"washer shot originates at the painted release drum")
	pending_boss.hp=float(pending_boss.max_hp)*.49
	advance(pending,.2)
	check(int(pending_boss.boss_phase)==1 and notices(pending,"boss_impact").is_empty(),"half-health waits while committed shot is in flight")
	advance(pending,.31)
	check(notices(pending,"boss_impact").size()==1 and int(pending_boss.boss_phase)==2,"committed hit lands once before transition")
	# Only one authored action owns the telegraph at a time.
	var serial: RefCounted=rig("B04");advance(serial,1)
	var serial_boss: Dictionary=serial.combat.b.enemies[0]
	serial_boss.skill_left=0;serial_boss.special_left=0
	advance(serial,.02)
	check(not serial_boss.get("counter_state",{}).is_empty() and float(serial_boss.special_windup)==0,"counter and heavy cannot start together")
	var special_clock: float=float(serial_boss.special_left)
	advance(serial,.5)
	check(is_equal_approx(float(serial_boss.special_left),special_clock),"heavy clock waits behind counter action")
	# A killed Boss cannot apply its already released web later.
	var web_model: RefCounted=rig("B02");advance(web_model,1.0)
	var web_boss: Dictionary=web_model.combat.b.enemies[0]
	web_model.combat.expansion.cast_skill(web_boss)
	check(not web_model.combat.b.get("debuff_projectiles",[]).is_empty(),"Boss web really launches a status carrier")
	web_model.combat.fx.damage(web_boss,1000000,"C01","test",1)
	advance(web_model,2)
	check(float(web_model.combat.b.cats[0].get("web_left",0))==0 and web_model.combat.b.get("debuff_projectiles",[]).is_empty(),"Boss death cancels pending status attack")
	# Legacy saves can contain a carrier whose dead Boss was already filtered out.
	var orphan: RefCounted=rig("B02");advance(orphan,1)
	var orphan_boss: Dictionary=orphan.combat.b.enemies[0]
	orphan.combat.expansion.cast_skill(orphan_boss)
	orphan.combat.b.enemies=orphan.combat.b.enemies.filter(func(e:Dictionary)->bool:return e.id!=orphan_boss.id)
	var orphan_path: String="user://v039-orphan-phase_boss-status.save"
	check(orphan.save(orphan_path),"old orphan carrier fixture saves")
	var orphan_loaded: RefCounted=Run.new();check(orphan_loaded.load_save(orphan_path),"old orphan carrier fixture loads")
	advance(orphan_loaded,2)
	check(float(orphan_loaded.combat.b.cats[0].get("web_left",0))==0 and orphan_loaded.combat.b.get("debuff_projectiles",[]).is_empty(),"legacy dead Boss carrier never applies after load")
	# Save/resume during transition keeps countdown without repeating announcements.
	var model: RefCounted=rig();advance(model,1);var boss: Dictionary=model.combat.b.enemies[0]
	boss.hp=float(boss.max_hp)*.49;advance(model,.2)
	var path: String="user://v039-boss-contract.save"
	check(model.save(path),"isolated transition fixture save")
	var restored: RefCounted=Run.new();check(restored.load_save(path),"transition fixture load")
	check(var_to_bytes(restored.combat.b.enemies)==var_to_bytes(model.combat.b.enemies),"saved encounter state round-trips exactly")
	advance(model,2);advance(restored,2)
	check(var_to_bytes(restored.combat.b.enemies)==var_to_bytes(model.combat.b.enemies),"resumed encounter is deterministic")
	# A v038 in-flight save has no new director keys; migration never adds a free wave.
	var legacy: RefCounted=rig();advance(legacy,1)
	var legacy_boss: Dictionary=legacy.combat.b.enemies[0]
	for key: String in ["boss_encounter_version","boss_phase","boss_phase_name","boss_state","boss_tell","boss_state_left","boss_state_duration","boss_transition_left","boss_recovery_left","boss_reinforced","boss_pending_summons"]: legacy_boss.erase(key)
	var original_count: int=legacy.combat.enemies().size()
	check(legacy.save(path),"legacy director fixture saves")
	var migrated: RefCounted=Run.new();check(migrated.load_save(path),"legacy director fixture loads")
	advance(migrated,.1)
	check(migrated.combat.enemies().size()==original_count,"legacy load does not duplicate entrance reinforcement")
	print(JSON.stringify({"checks":checks,"ok":failures.is_empty(),"failures":failures}));quit(0 if failures.is_empty() else 1)
