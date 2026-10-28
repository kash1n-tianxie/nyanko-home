extends SceneTree
const Run=preload("res://scripts/run_state.gd")
const Catalog=preload("res://scripts/skill_catalog.gd")
var failures: Array[String]=[]
var checks: int=0
func _initialize() -> void: call_deferred("execute")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label);printerr("FAIL ",label)
func rig(id: String="C04") -> RefCounted:
	var model: RefCounted=Run.new();model.new_run(38004,id);model.command("start")
	model.combat.b.schedule=[];model.combat.b.duration=9999
	for cat: Dictionary in model.combat.b.cats:
		cat.cooldown=9999;cat.skills.ready=true;cat.skills.charge=cat.skills.duration
	model.events=[]
	return model
func enemy(model: RefCounted,x: float=650,kind: String="E01") -> Dictionary:
	var result: Dictionary=model.combat.spawn(kind,x,true)
	result.hp=100000;result.max_hp=100000;result.armor=0.0;result.shield=0.0
	if result.boss: result.entrance_age=2.0
	return result
func impacts(model: RefCounted) -> Array:
	return model.events.filter(func(e:Dictionary)->bool:return e.type=="skill_impact")
func execute() -> void:
	var empty: RefCounted=rig();empty.s={}
	check(not empty.combat.skills.cinematic_busy(),"title screen can query busy before a run exists")
	var model: RefCounted=rig()
	check(model.combat.skills.has_method("tick_cinematic"),"independent persisted real-clock cinematic interface exists")
	if not model.combat.skills.has_method("tick_cinematic"): finish();return
	for id: String in Catalog.DEFINITIONS:
		model=rig(id);var victim: Dictionary=enemy(model)
		var before: float=victim.hp
		check(model.command("cat_skill",{"cat":id}).ok,id+" accepts once")
		var duration: float=float(Catalog.DEFINITIONS[id].cinema_duration)
		check(model.combat.skills.cinematic_busy() and model.s.battle.cinematic.duration==duration,id+" full duration persists")
		check(not model.command("cat_skill",{"cat":id}).ok,id+" rejects repeated queued input")
		check(victim.hp==before,id+" no premature impact at cast")
		var sim_time: float=model.s.battle.time
		var hp: float=model.s.hp
		model.step(1.0)
		check(model.s.battle.time==sim_time and model.s.hp==hp,id+" ordinary battle frozen")
		model.s.paused=true;model.combat.skills.tick_cinematic(2)
		check(model.s.battle.cinematic.age==0,id+" pause freezes timeline")
		model.s.paused=false;model.s.combat_speed=2.0
		model.combat.skills.tick_cinematic(duration-.01)
		check(model.combat.skills.cinematic_busy(),id+" 2x speed retains real duration")
		var count: int=impacts(model).size()
		model.combat.skills.tick_cinematic(.02)
		check(not model.combat.skills.cinematic_busy(),id+" full playback unlocks")
		model.combat.skills.tick_cinematic(20)
		check(impacts(model).size()==count,id+" completed timeline cannot damage again")
		check(model.combat.skill_status(id).used,id+" consumed use stays consumed")
	_test_impact_and_restore();_test_buffs();_test_serial_and_exit();_test_sweep();_test_coefficients()
	finish()
func _test_impact_and_restore() -> void:
	var model: RefCounted=rig();var victim: Dictionary=enemy(model)
	model.command("cat_skill",{"cat":"C04"});model.combat.skills.tick_cinematic(2.24)
	check(victim.hp==100000 and victim.stun==0,"hammer does not hit before the 2.25 second contact")
	var file: String="user://v038_cinema_fixture.save"
	check(model.save(file),"cinematic snapshot saved independently")
	var restored: RefCounted=Run.new();check(restored.load_save(file),"cinematic snapshot reloads")
	restored.combat.skills.tick_cinematic(.02)
	var enemy_after: Dictionary=restored.combat.get_enemy(victim.id)
	check(enemy_after.hp<100000 and enemy_after.stun==3.0,"restored hammer lands exactly on impact")
	var hp_after: float=enemy_after.hp
	check(restored.save(file) and model.load_save(file),"post-impact snapshot reloads")
	model.combat.skills.tick_cinematic(5)
	check(model.combat.get_enemy(victim.id).hp==hp_after,"load after impact never replays damage")
	check(model.combat.get_enemy(victim.id).stun==3.0,"stun starts aging only after cinema ends")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
func _test_buffs() -> void:
	var model: RefCounted=rig("C01");var cat: Dictionary=model.combat.get_cat("C01")
	cat.buff_left=8.0;cat.web_left=5.0
	model.command("cat_skill",{"cat":"C01"});model.step(5)
	check(cat.buff_left==8 and cat.web_left==5,"ordinary buffs/debuffs freeze")
	model.combat.skills.tick_cinematic(3.2)
	check(cat.skill_rage_left==8.0,"rage receives full effective battle duration")
	model=rig("C06");cat=model.combat.get_cat("C06");cat.web_left=5
	model.command("cat_skill",{"cat":"C06"});model.combat.skills.tick_cinematic(3.5)
	check(cat.web_left==0 and cat.skill_chorus_left==6.0,"bell cleanse real effect and full duration")
	check(model.combat.b.shields[0].left==8.0,"shield lifetime not spent watching animation")
func _test_serial_and_exit() -> void:
	var model: RefCounted=rig("C04");model.s.owned.append("C02");model.s.active.append("C02")
	model.combat.add_cat("C02")
	var second: Dictionary=model.combat.get_cat("C02");model.combat.skills.initialize_cat(second);second.skills.ready=true
	model.command("cat_skill",{"cat":"C04"})
	check(not model.command("cat_skill",{"cat":"C02"}).ok and not second.skills.used,"another cat is rejected without spending or queuing")
	model.combat.skills.tick_cinematic(3.8)
	check(model.command("cat_skill",{"cat":"C02"}).ok,"next cat only casts after complete return")
	var victim: Dictionary=enemy(model);model.s.phase="prep";model.combat.skills.tick_cinematic(5)
	check(victim.hp==100000 and not model.combat.skills.cinematic_busy(),"stage exit cancels pending impacts and busy lock")
	model=rig();model.s.meal={"flight_left":.3}
	check(not model.command("cat_skill",{"cat":"C04"}).ok,"meal flight cannot overlap cinema")
	model=rig();victim=enemy(model);victim.hp=1;model.combat.b.duration=0;model.s.phase="cleanup"
	model.command("cat_skill",{"cat":"C04"});model.combat.skills.tick_cinematic(2.3);model.step(.1)
	check(victim.dead and model.s.phase=="cleanup","last target death retains cinema before settlement")
	model.combat.skills.tick_cinematic(2);model.step(.02)
	check(model.s.phase not in ["combat","cleanup"],"last target settles only after return")
func _test_sweep() -> void:
	var model: RefCounted=rig("C05");var near: Dictionary=enemy(model,400);var far: Dictionary=enemy(model,1120)
	model.command("cat_skill",{"cat":"C05"});model.combat.skills.tick_cinematic(1.55)
	check(near.hp<100000 and far.hp==100000,"roar hits near targets when visible wave arrives")
	model.combat.skills.tick_cinematic(1.1)
	check(far.hp<100000,"roar reaches and hits distant targets later")
func _test_coefficients() -> void:
	var model: RefCounted=rig("C02")
	var near: Dictionary=enemy(model,650);var far: Dictionary=enemy(model,1100)
	var power: float=model.combat.get_cat("C02").attack
	model.command("cat_skill",{"cat":"C02"})
	model.combat.get_cat("C02").attack=power*99
	model.combat.skills.tick_cinematic(2.56)
	check(is_equal_approx(float(near.hp),100000-power*16),"meteor preserves 16A cast-time snapshot")
	check(far.hp==100000,"fullscreen camera does not turn meteor into global damage")
	model=rig("C03");near=enemy(model,650);power=model.combat.get_cat("C03").attack
	model.command("cat_skill",{"cat":"C03"});model.combat.skills.tick_cinematic(4)
	check(impacts(model).size()==5 and is_equal_approx(float(near.hp),100000-power*15),"five lightning impacts preserve five times 3A")
	model=rig("C04");var air: Dictionary=enemy(model,650,"E08");var elite: Dictionary=enemy(model,800,"X01");var boss: Dictionary=enemy(model,1000,"B01")
	model.command("cat_skill",{"cat":"C04"});model.combat.skills.tick_cinematic(2.3)
	check(air.stun==3 and elite.stun==1.8 and boss.stun==1,"air, elite and boss keep existing stun tiers")
	check(air.get("air",false),"hammer does not change an airborne target layer")
	model=rig();near=enemy(model);model.command("cat_skill",{"cat":"C04"});model.s.hp=0
	model.combat.skills.tick_cinematic(5)
	check(near.hp==100000 and not model.combat.skills.cinematic_busy(),"base destruction cancels future cinematic impacts")

func finish() -> void:
	var report: Dictionary={"checks":checks,"failures":failures}
	var out: FileAccess=FileAccess.open("res://outputs/v038/cinema/contract.json",FileAccess.WRITE)
	if out!=null: out.store_string(JSON.stringify(report,"  "))
	print("v038_cinema: ",checks," checks / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
