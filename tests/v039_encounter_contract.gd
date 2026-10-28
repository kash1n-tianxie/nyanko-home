extends SceneTree
const Run=preload("res://scripts/run_state.gd")
const Encounters=preload("res://scripts/encounter_choice.gd")
const Shop=preload("res://scripts/camp_shop.gd")
const Director=preload("res://scripts/battle_director.gd")
const Data=preload("res://scripts/catalog.gd")
var checks: int=0
var failures: Array[String]=[]
func _initialize() -> void: call_deferred("execute")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);printerr("FAIL ",label)
func gameplay(state: Dictionary) -> Dictionary:
	# Rejected commands intentionally retain an idempotency receipt in production.
	var result: Dictionary=state.duplicate(true)
	result.erase("tx_seq");result.erase("receipts")
	return result
func execute() -> void:
	var r: RefCounted=Run.new();r.new_run(39001)
	check(r.has_method("encounter_status"),"risk encounter API exists")
	check(r.shop_status().has("wishlist"),"shop watch API exists")
	if not r.has_method("encounter_status"): finish();return
	for stage: int in range(20):
		r.s.stage=stage
		var available: bool=stage%4==2
		check(bool(r.encounter_status().available)==available,"eligible stage "+str(stage))
		if available: continue
		var stage_before: Dictionary=r.s.duplicate(true)
		check(not r.command("encounter_choice",{"choice":"risk"}).ok and gameplay(r.s)==gameplay(stage_before),"cannot add risk to standard/elite/Boss stage "+str(stage))
	r.s.stage=2
	var before: Dictionary=r.s.duplicate(true)
	check(not r.command("encounter_choice",{"choice":"garbage"}).ok and gameplay(r.s)==gameplay(before),"invalid route is atomic")
	for stage: int in [2,6,10,14,18]:
		r.s.stage=stage
		var base: Array=Director.schedule(stage)
		var normal: Array=base.duplicate(true)
		Encounters.augment_schedule(r,normal)
		check(normal==base,"normal schedule is byte-equivalent "+str(stage))
		var rolls: Dictionary=r.s.rng.duplicate(true)
		check(r.command("encounter_choice",{"choice":"risk"}).ok,"choose optional risk "+str(stage))
		var info: Dictionary=r.encounter_status()
		check(int(info.reward_gold)==10+floori(stage/4.0)*2,"advertised bounty "+str(stage))
		var risk: Array=base.duplicate(true)
		Encounters.augment_schedule(r,risk)
		var expected: int=0
		for group: Dictionary in info.extra_enemies: expected+=int(group.count)
		var remaining: Array=[];var actual: int=0;var last_time: float=-1.0
		for entry: Dictionary in risk:
			check(float(entry.time)>=last_time,"schedule remains sorted")
			last_time=float(entry.time)
			if bool(entry.get("risk_extra",false)):
				actual+=1
				check(bool(entry.get("free",false)),"extra units cannot consume gold budget")
			else: remaining.append(entry)
		check(remaining==base and actual==expected,"risk preserves authored units and adds advertised count "+str(stage))
		var copy: Array=risk.duplicate(true);Encounters.augment_schedule(r,risk)
		check(risk==copy and r.s.rng==rolls,"augmentation idempotent and no RNG "+str(stage))
	r.s.stage=2
	r.s.paused=true
	check(not r.command("encounter_choice",{"choice":"normal"}).ok,"pause gates route selection")
	r.s.paused=false
	check(r.command("start").ok,"start risk encounter")
	var extras: int=0
	for entry: Dictionary in r.s.battle.schedule:
		if bool(entry.get("risk_extra",false)): extras+=1
	check(extras==6,"production battle includes risk schedule hook")
	before=r.s.duplicate(true)
	check(r.encounter_status().locked and not r.command("encounter_choice",{"choice":"normal"}).ok and gameplay(r.s)==gameplay(before),"battle locks chosen route")
	var reward_index: int=int(r.s.battle.get("reward_spawn_index",0))
	var extra: Dictionary=r.combat.spawn("E08",1100.0,true)
	check(extra.gold==0 and int(r.s.battle.get("reward_spawn_index",0))==reward_index,"free spawn preserves authored reward index")
	var gold: int=r.s.gold
	r.settle_stage()
	check(r.s.gold-gold==14 and r.s.stage_reports.back().risk_reward==10,"risk victory pays exactly advertised bounty plus normal four")
	r.s.phase="cleanup";gold=r.s.gold;r.settle_stage()
	check(r.s.gold==gold,"repeated settlement cannot repay risk")
	var failed: RefCounted=Run.new();failed.new_run(39002);failed.s.stage=2
	failed.command("encounter_choice",{"choice":"risk"});failed.command("start");failed.s.hp=0
	gold=failed.s.gold;failed.settle_stage()
	check(failed.s.phase=="failed" and failed.s.gold==gold,"defeat grants no risk bounty")
	_watch_contract();_persistence_contract()
	finish()

func _watch_contract() -> void:
	var r: RefCounted=Run.new();r.new_run(39003)
	var rng: Dictionary=r.s.rng.duplicate(true);var offers: Array=r.s.shop.offers.duplicate(true);var gold: int=r.s.gold
	check(r.command("shop_watch",{"kind":"F01"}).ok and r.command("shop_watch",{"kind":"F06"}).ok,"pin two fish")
	check(not r.command("shop_watch",{"kind":"F03"}).ok and not r.command("shop_watch",{"kind":"bad"}).ok,"limit and valid kind enforced")
	check(r.shop_status().wishlist==["F01","F06"],"wishlist order and uniqueness")
	check(r.s.rng==rng and r.s.shop.offers==offers and r.s.gold==gold,"watch never changes odds offers or gold")
	check(r.command("shop_watch",{"kind":"F01"}).ok and r.shop_status().wishlist==["F06"],"watch toggles off")
	r.command("start")
	check(not r.command("shop_watch",{"kind":"F01"}).ok and r.shop_status().wishlist==["F06"],"watch locked in combat")
	for list: Array in [["F01","F01"],["bad"],["F01","F02","F03"]]:
		var malformed: Dictionary=r.s.duplicate(true);malformed.shop.wishlist=list
		check(not Shop.validate(malformed),"malformed wishlist rejected")

func _persistence_contract() -> void:
	var r: RefCounted=Run.new();r.new_run(39004);r.s.stage=2
	r.command("shop_watch",{"kind":"F01"});r.command("encounter_choice",{"choice":"risk"});r.command("start")
	var path: String="user://v039_encounter_fixture.save"
	check(r.save(path),"save risk battle")
	var loaded: RefCounted=Run.new()
	check(loaded.load_save(path),"load risk battle")
	check(loaded.encounter_status().choice=="risk" and loaded.encounter_status().locked and loaded.shop_status().wishlist==["F01"],"save keeps choices and watch pins")
	check(loaded.s.battle.schedule==r.s.battle.schedule,"resume preserves exact extra schedule")
	r.s.phase="prep";r.s.battle={};r.s.erase("encounter_choices");r.s.shop.erase("wishlist")
	path="user://v039_legacy_fixture.save";check(r.save(path),"save legacy fixture")
	check(loaded.load_save(path) and loaded.encounter_status().choice=="normal" and loaded.shop_status().wishlist.is_empty(),"legacy save defaults normal and no pins")
	for value: Variant in [[],{"3":"risk"},{"02":"risk"},{"22":"risk"},{"2":"bad"},{2:"risk"}]:
		var malformed: Dictionary=loaded.s.duplicate(true);malformed.encounter_choices=value
		check(not Encounters.migrate(malformed),"malformed encounter choice rejected")
	loaded.autosave=true;loaded.save_path="/missing-v039-no-directory/test.save"
	var before: Dictionary=loaded.s.duplicate(true)
	check(not loaded.command("encounter_choice",{"choice":"risk"}).ok and loaded.s==before,"failed autosave rolls back route choice")
	check(not loaded.command("shop_watch",{"kind":"F01"}).ok and loaded.s==before,"failed autosave rolls back pin")
func finish() -> void:
	print(JSON.stringify({"suite":"v039_encounter","checks":checks,"failures":failures}));quit(1 if not failures.is_empty() else 0)
