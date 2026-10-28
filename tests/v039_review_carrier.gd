extends SceneTree
const Run=preload("res://scripts/run_state.gd")
const OUT="res://outputs/v039/review"
var checks: int=0
var failures: Array[String]=[]
var legacy_probe: Dictionary={}
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label);printerr("FAIL ",label)
func _initialize() -> void: call_deferred("execute")
func rig() -> RefCounted:
	var r: RefCounted=Run.new();r.new_run(39055,"C01",false,"hard");r.command("start")
	r.s.battle.schedule=[];r.s.battle.duration=9999;r.s.hp=10000;r.s.max_hp=10000
	for cat: Dictionary in r.s.battle.cats: cat.cooldown=9999
	return r
func ids(flights: Array) -> Array:
	var result: Array=[]
	for flight: Dictionary in flights: result.append(int(flight.get("enemy",flight.get("boss_id",-1))))
	result.sort();return result
func execute() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var r: RefCounted=rig()
	var dead_boss: Dictionary=r.combat.spawn("B02",-1,true);dead_boss.entrance_age=2.0
	var alive_boss: Dictionary=r.combat.spawn("B04",-1,true);alive_boss.entrance_age=2.0
	var ordinary: Dictionary=r.combat.spawn("E10",900,true)
	for source: Dictionary in [dead_boss,alive_boss,ordinary]: r.combat.expansion.cast_skill(source)
	r.combat.launch_boss_attack(dead_boss,11,"test_dead")
	r.combat.launch_boss_attack(alive_boss,23,"test_alive")
	check(ids(r.s.battle.debuff_projectiles)==[dead_boss.id,alive_boss.id,ordinary.id],"three independently owned status flights launched")
	var survivors: Array=r.s.battle.debuff_projectiles.filter(func(f:Dictionary)->bool:return int(f.enemy)!=int(dead_boss.id)).duplicate(true)
	r.combat.fx.damage(dead_boss,1000000,"C01","test",1)
	check(var_to_bytes(r.s.battle.debuff_projectiles)==var_to_bytes(survivors),"death preserves all other status flight payloads and remaining times")
	check(ids(r.s.battle.hostile_boss_flights)==[alive_boss.id],"death only clears own base flight")
	r.combat.clear_boss_flights(int(dead_boss.id))
	check(var_to_bytes(r.s.battle.debuff_projectiles)==var_to_bytes(survivors),"repeated same-boss clear is idempotent")
	var path: String=OUT+"/carrier-after-death.save"
	check(r.save(path),"save after selective death clear")
	var restored: RefCounted=Run.new();check(restored.load_save(path),"restore after selective death clear")
	check(var_to_bytes(restored.s.battle.debuff_projectiles)==var_to_bytes(survivors),"reload preserves only surviving carriers")
	for model: RefCounted in [r,restored]:
		model.events.clear()
		var hp_before: float=float(model.s.hp)
		model.combat.tick_boss_flights(1.0);model.combat.expansion.tick_debuff_flights(1.0)
		var notices: Array=model.events.filter(func(e:Dictionary)->bool:return e.type=="cat_debuff")
		var hit_sources: Array=[]
		for notice: Dictionary in notices: hit_sources.append(int(notice.target))
		hit_sources.sort()
		check(hit_sources==[alive_boss.id,ordinary.id],"only other live boss and ordinary status carriers hit")
		check(is_equal_approx(float(model.s.hp),hp_before-23),"only live boss base flight damages once")
		var count: int=model.events.size();model.combat.tick_boss_flights(1.0);model.combat.expansion.tick_debuff_flights(1.0)
		check(model.events.size()==count and is_equal_approx(float(model.s.hp),hp_before-23),"repeated resolution cannot duplicate damage or status events")
	check(r.s.hp==restored.s.hp and r.s.rng==restored.s.rng,"postdeath load has identical damage and RNG")
	r=rig();dead_boss=r.combat.spawn("B02",-1,true);alive_boss=r.combat.spawn("B04",-1,true);ordinary=r.combat.spawn("E10",900,true)
	for source: Dictionary in [dead_boss,alive_boss,ordinary]: r.combat.expansion.cast_skill(source)
	var ordinary_flights: Array=r.s.battle.debuff_projectiles.filter(func(f:Dictionary)->bool:return int(f.enemy)==int(ordinary.id)).duplicate(true)
	r.combat.clear_boss_flights()
	check(var_to_bytes(r.s.battle.debuff_projectiles)==var_to_bytes(ordinary_flights),"global boss clear preserves ordinary carrier bytes")
	# A pre-fix save could retain a pending status carrier after its boss was
	# removed. Probe backward loading separately from current death semantics.
	r=rig();dead_boss=r.combat.spawn("B02",-1,true);dead_boss.entrance_age=2.0
	r.combat.expansion.cast_skill(dead_boss)
	var legacy_carriers: Array=r.s.battle.debuff_projectiles.duplicate(true)
	r.combat.fx.damage(dead_boss,1000000,"C01","test",1)
	r.s.battle.enemies=[];r.s.battle.debuff_projectiles=legacy_carriers
	path=OUT+"/carrier-legacy-orphan.save";check(r.save(path),"write legacy orphan fixture")
	restored=Run.new();check(restored.load_save(path),"load legacy orphan fixture")
	restored.combat.expansion.tick_debuff_flights(1.0)
	legacy_probe={"orphan_boss_web_applied":float(restored.s.battle.cats[0].get("web_left",0))>0,"web_left":restored.s.battle.cats[0].get("web_left",0)}
	check(not bool(legacy_probe.orphan_boss_web_applied),"legacy orphan Boss status carrier is discarded after load")
	var result: Dictionary={"checks":checks,"failures":failures,"legacy_probe":legacy_probe}
	var file: FileAccess=FileAccess.open(OUT+"/carrier.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "));file.close()
	print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
