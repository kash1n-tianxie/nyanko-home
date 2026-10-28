extends SceneTree
const Run=preload("res://scripts/run_state.gd")
const Toys=preload("res://scripts/toy_catalog.gd")
const Advisor=preload("res://scripts/build_advisor.gd")
const Receipt=preload("res://scripts/feedback_receipt.gd")
var checks: int=0
var failures: Array=[]

func _initialize() -> void: call_deferred("execute")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label);printerr("FAIL ",label)
func rig(toys: Dictionary={},hq: int=1,cat_id: String="C01") -> RefCounted:
	var model: RefCounted=Run.new()
	model.new_run(34021,cat_id)
	model.s.toys=toys.duplicate(true);model.s.hq=hq
	model.command("start")
	model.combat.b.schedule=[];model.combat.b.duration=9999
	for cat: Dictionary in model.combat.b.cats: cat.cooldown=9999
	return model
func dummy(model: RefCounted,x: float=650) -> Dictionary:
	var enemy: Dictionary=model.combat.spawn("E01",x,true)
	enemy.hp=100000;enemy.max_hp=100000;enemy.armor=0;enemy.damage=0;enemy.speed=0
	return enemy
func drain(model: RefCounted) -> void:
	for i: int in range(150): model.combat._tick_projectiles(1.0/60)
func shots(model: RefCounted,id: String) -> Array:
	return model.events.filter(func(event:Dictionary)->bool:return event.type=="toy_cast" and event.get("toy","")==id)
func shield_hit(model: RefCounted,enemy: Dictionary,shield: float,incoming: float) -> void:
	model.combat.b.shields=[{"amount":shield,"left":99.0,"source":"T14"}]
	model.combat.fx.hurt_base(incoming,enemy,"test")
func bell(model: RefCounted) -> void:
	model.combat.queue_bell_return(model.combat.get_cat("C06"),650)
	model.combat.tick_buffs(.56)
func execute() -> void:
	# Removes the existing middle-tier dead rewards without changing carrier steps.
	for id: String in ["T03","T10"]:
		var previous: Dictionary=Toys.effects({id:1})
		for count: int in range(2,8):
			var effect: Dictionary=Toys.effects({id:count})
			check(effect!=previous,id+" duplicate "+str(count)+" has immediate power")
			check(int(effect.bounce_extra if id=="T03" else effect.projectile_bonus)==(1 if count<4 else (2 if count<7 else 3)),id+" original carrier staircase "+str(count))
			var lines: String="；".join(Advisor.stack_changes({"toys":{id:count-1},"hq":1},id))
			check(not lines.contains("效果不变") and not lines.contains("已到上限"),id+" duplicate explains real delta "+str(count))
			previous=effect
	var catalog: RefCounted=Toys.new()
	check(catalog.has_method("is_capped"),"reward pool can query complete toy cap")
	if catalog.has_method("is_capped"):
		for id: String in Toys.all():
			check(not bool(catalog.call("is_capped",id,0)),id+" first toy is never capped")
		for id: String in ["T01","T02","T03","T05","T07","T09","T10","T19","T20","T22"]:
			check(bool(catalog.call("is_capped",id,999)),id+" fully saturated toy is excluded")
		for id: String in ["T04","T06","T08","T11","T12","T13","T14","T15","T16","T17","T18","T21"]:
			check(not bool(catalog.call("is_capped",id,20)),id+" growing toy remains collectible")
	check(Toys.all().has("T21") and Toys.all().has("T22"),"two toys discoverable through catalog")
	# Shield absorption, not nominal shields/blocks/HP damage, powers the cannon.
	var model: RefCounted=rig({"T21":1})
	var enemy: Dictionary=dummy(model)
	model.combat.b.shields=[{"amount":100.0,"left":99.0,"source":"T14"}]
	model.combat.expansion.tick(.01)
	check(shots(model,"T21").is_empty() and float(model.combat.b.get("toy_cannon_charge",0))==0,"adding unused shield cannot charge cannon")
	model.combat.b.has_block=true;model.combat.b.block_cd=0
	model.combat.fx.hurt_base(30,enemy,"test")
	model.combat.expansion.tick(.01)
	check(float(model.combat.b.get("toy_cannon_charge",0))==0,"blocked damage cannot charge cannon")
	model.combat.b.has_block=false
	shield_hit(model,enemy,7,10)
	model.combat.expansion.tick(.01)
	check(is_equal_approx(float(model.combat.b.get("toy_cannon_charge",0)),7),"only seven actual shield absorption charges, three HP loss excluded")
	shield_hit(model,enemy,11,11)
	model.combat.expansion.tick(.01)
	check(shots(model,"T21").size()==1 and enemy.hp==100000,"eighteen absorption launches one cannon with visible flight")
	model.combat.expansion.tick(.40)
	check(is_equal_approx(100000-float(enemy.hp),90),"HQ1 cannon deals independent ninety damage")
	var report: Dictionary=model.current_feedback()
	check(is_equal_approx(float(report.get("damage_by_toy",{}).get("T21",0)),90),"cannon actual damage credited once to toy")
	check(is_equal_approx(float(report.base.shield_absorbed),18) and is_equal_approx(float(report.base.hp_damage),3),"cannon does not alter shield or base accounting")
	shield_hit(model,enemy,200,200)
	model.combat.expansion.tick(.01)
	check(shots(model,"T21").size()==1 and float(model.combat.b.get("toy_cannon_charge",0))<=18,"large shield hit stores at most one cannon and obeys cooldown")
	model.combat.expansion.tick(6)
	check(shots(model,"T21").size()==2,"stored cannon fires once after six game seconds")
	model.combat.expansion.tick(30)
	check(shots(model,"T21").size()==2,"cannon damage cannot recharge itself")
	model=rig({"T21":1},5);enemy=dummy(model)
	model.combat.b.cats[0].base_attack=99999
	shield_hit(model,enemy,18,18);model.combat.expansion.tick(.01);model.combat.expansion.tick(.4)
	check(is_equal_approx(100000-float(enemy.hp),180),"HQ5 cannon doubles without scaling from cat attack")
	# Armed support echoes resolve as terminal single hits, even in a rich build.
	model=rig({"T22":1});enemy=dummy(model)
	model.combat.add_cat("C06")
	var cat: Dictionary=model.combat.get_cat("C01")
	model.combat.attack(cat,[enemy]);drain(model)
	check(shots(model,"T22").is_empty(),"no bell return means no echo")
	bell(model)
	check(bool(cat.get("toy_echo_armed",false)),"actual teammate bell return arms recorder")
	model.combat.attack(cat,[enemy])
	check(model.combat.b.projectiles.filter(func(p:Dictionary)->bool:return p.get("source_toy","")=="T22").size()==1,"one buffed main attack launches exactly one weak echo")
	var attack_power: float=float(cat.attack)
	drain(model)
	report=model.current_feedback()
	check(is_equal_approx(float(report.damage_by_toy.get("T22",0)),attack_power*.22),"recorder reports its real weak terminal hit")
	var previous_damage: float=float(report.damage_by_toy.get("T22",0))
	model.combat.attack(cat,[enemy]);drain(model)
	check(is_equal_approx(float(model.current_feedback().damage_by_toy.get("T22",0)),previous_damage),"armed buff is consumed only once")
	bell(model);model.combat.attack(cat,[enemy]);drain(model)
	check(shots(model,"T22").size()==1,"fresh return during per-cat cooldown cannot trigger")
	model.combat.tick_buffs(4.1);bell(model);model.combat.attack(cat,[enemy]);drain(model)
	check(shots(model,"T22").size()==2,"new return after cooldown permits another echo")
	model=rig({"T22":1},1,"C06");enemy=dummy(model)
	bell(model);model.combat.attack(model.combat.get_cat("C06"),[enemy]);drain(model)
	check(shots(model,"T22").is_empty(),"solo self-return cannot claim teammate support echo")
	# Stopwatch and pending attacks freeze on pause and cannot resolve after death.
	model=rig({"T21":1,"T22":1});enemy=dummy(model);model.combat.add_cat("C06")
	shield_hit(model,enemy,18,18);model.combat.expansion.tick(.01);bell(model)
	model.s.paused=true
	var frozen: PackedByteArray=var_to_bytes(model.combat.b)
	model.combat.tick(2)
	check(var_to_bytes(model.combat.b)==frozen,"paused cannon flight/echo state frozen")
	model.s.paused=false;model.s.hp=0;model.settle_stage()
	var before: float=float(enemy.hp)
	model.combat.tick(3)
	check(float(enemy.hp)==before and model.combat.b.get("toy_cannon_pending",[]).is_empty() and float(model.combat.b.get("toy_cannon_charge",0))==0,"death clears reactive shots and no later damage")
	# The first-screen support card uses actual returned buffs and elapsed coverage.
	model=rig({"T04":1,"T22":1});enemy=dummy(model);model.combat.add_cat("C06")
	bell(model);model.combat.expansion.tick(.25)
	report=model.current_feedback();report.recent_toy="T04"
	check(is_equal_approx(float(report.support.get("C06",{}).get("benefit_seconds",0)),.25),"bell coverage records actual quarter second")
	check(int(report.support.get("C06",{}).get("buffs",0))==1,"bell records one real teammate return")
	var medals: Array=Receipt.medals(report)
	check(medals.size()==3 and str(medals[1].source)=="C06","support first screen is not displaced by newest inactive toy")
	check(not str(medals[1]).contains("额外伤害") and str(medals[1]).contains("0.2"),"support presents measured coverage without fabricated damage causality")
	# Actual volley damage and attack rates must realize the new duplicate deltas.
	var bounce_damage: Array[float]=[]
	var rates: Array[float]=[]
	for count: int in [1,2]:
		model=rig({"T03":count});enemy=dummy(model,650);dummy(model,700)
		model.combat.attack(model.combat.get_cat("C01"),[enemy]);drain(model)
		bounce_damage.append(float(model.current_feedback().damage_by_toy.get("T03",0)))
		model=rig({"T10":count});enemy=dummy(model)
		rates.append(float(model.combat.cat_display_stats("C01").rate))
		model.combat.attack(model.combat.get_cat("C01"),[enemy])
		check(model.combat.b.projectiles.size()==2,"duplicate kaleidoscope retains two main carriers "+str(count))
	check(bounce_damage[1]>bounce_damage[0],"middle-tier T03 actually increases bounced damage")
	check(rates[1]>rates[0],"middle-tier T10 actually increases firing rate")
	# A ready cannon waits for a real visible target and has bounded area hits.
	model=rig({"T21":1});enemy=dummy(model,1500)
	shield_hit(model,enemy,18,18);model.combat.expansion.tick(.1)
	check(shots(model,"T21").is_empty() and float(model.combat.b.get("toy_cannon_charge",0))==18,"offscreen target does not waste charged cannon")
	enemy.x=650
	for i: int in range(5): dummy(model,660+i*10)
	model.combat.expansion.tick(.1);model.combat.expansion.tick(.4)
	check(model.combat.enemies().filter(func(e:Dictionary)->bool:return float(e.hp)<100000).size()==4,"cannon hits at most four legal enemies")
	check(is_equal_approx(float(model.current_feedback().total_damage),360),"bounded cannon area total is sum of four actual hits")
	# A rich attack cannot turn the recorder's terminal hit into an effect carrier.
	model=rig({"T22":1,"T03":1,"T04":1,"T05":1,"T10":1,"T18":1});enemy=dummy(model);dummy(model,690)
	model.combat.add_cat("C06");cat=model.combat.get_cat("C01")
	cat.fish={"F01":preload("res://scripts/catalog.gd").fish("F01",2,5),"F02":preload("res://scripts/catalog.gd").fish("F02",2,5)}
	bell(model);model.combat.attack(cat,[enemy])
	model.combat.b.projectiles=model.combat.b.projectiles.filter(func(p:Dictionary)->bool:return p.get("source_toy","")=="T22")
	if not model.combat.b.projectiles.is_empty():
		var echo_payload: Dictionary=model.combat.b.projectiles[0].payload
		check(echo_payload.get("elements",[]).is_empty() and echo_payload.get("fish_ids",[]).is_empty(),"weak echo presentation does not promise inherited fish effects")
	drain(model)
	report=model.current_feedback()
	check(int(report.toys.get("T04",{}).get("triggers",0))==0 and int(report.toys.get("T05",{}).get("triggers",0))==0,"recorder never replays fish, popcorn, chain or bounce effects")
	check(report.direct_sources.keys()==["T22"] and int(report.toys.T22.hits)==1,"recorder generates one exclusive terminal hit in maximal carrier build")
	check(model.combat.b.projectiles.is_empty(),"terminal recorder hit queues no child carriers")
	# Cooldown belongs to each recipient, rather than a shared team lock.
	model=rig({"T22":1});enemy=dummy(model);model.combat.add_cat("C06");model.combat.add_cat("C02")
	for i: int in range(30):
		bell(model)
		if bool(model.combat.get_cat("C01").toy_echo_armed) and bool(model.combat.get_cat("C02").toy_echo_armed): break
	model.combat.attack(model.combat.get_cat("C01"),[enemy]);model.combat.attack(model.combat.get_cat("C02"),[enemy])
	check(shots(model,"T22").size()==2,"two buffed teammates each have their own recorder cooldown")
	# Battle serialization must retain charge, launch snapshots and consumed echoes.
	model=rig({"T21":1,"T22":1});enemy=dummy(model);model.combat.add_cat("C06")
	shield_hit(model,enemy,18,18);model.combat.expansion.tick(.1);bell(model)
	model.s.battle=bytes_to_var(var_to_bytes(model.s.battle))
	model.combat.expansion.tick(.4)
	check(is_equal_approx(float(model.current_feedback().damage_by_toy.get("T21",0)),90),"serialized in-flight cannon resolves exactly once")
	model.combat.expansion.tick(.4)
	check(is_equal_approx(float(model.current_feedback().damage_by_toy.get("T21",0)),90),"restored cannon cannot replay the same absorbed shield")
	# A lethal enemy hit earlier in this same simulation tick cancels weak echoes.
	model=rig({"T22":1});enemy=dummy(model);model.combat.add_cat("C06");bell(model)
	model.combat.attack(model.combat.get_cat("C01"),[enemy])
	model.s.hp=1;enemy.x=350;enemy.damage=10;enemy.attack_left=0
	for projectile: Dictionary in model.combat.b.projectiles: projectile.delay=0.0;projectile.travel=0.0
	model.step(1.0/60)
	check(str(model.s.phase)=="failed" and float(model.current_feedback().damage_by_toy.get("T22",0))==0,"recorder never resolves after lethal damage earlier in same tick")
	print(JSON.stringify({"checks":checks,"ok":failures.is_empty(),"failures":failures}))
	quit(0 if failures.is_empty() else 1)
