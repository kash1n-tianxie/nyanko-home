extends SceneTree
const Run=preload("res://scripts/run_state.gd")
const Advisor=preload("res://scripts/shop_advisor.gd")
var checks: int=0
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);push_error(label)
func _init() -> void:
	var run: RefCounted=Run.new();run.new_run(39025,"C01");run.s.gold=100;run.s.items.clear()
	var ids: Array=[]
	for lv: int in [1,2,3]: ids.append(run.create_item("F01",0,lv,6,"inventory").id)
	run.s.shop.offers[0]={"id":"recursive","kind":"F01","quality":0,"level":1,"price":6,"paid_basis":6,"sold":false,"ordered":false}
	var before: PackedByteArray=var_to_bytes(run.s)
	var events: PackedByteArray=var_to_bytes(run.events)
	var value: Dictionary=Advisor.preview(run,0,"C01",0)
	check(not value.is_empty(),"advisor returns real preview")
	if value.is_empty(): finish();return
	check(bool(value.valid),"recursive purchase can equip")
	check(int(value.item.level)==4,"1+1 ->2 +2 ->3 +3 ->4 using production merge")
	check(int(value.effective)==5,"favorite actual4 becomes effective5")
	for id: String in ids: check(id in value.ingredients,"recursive ingredient highlighted "+id)
	check(float(value.attack_delta)>0 and float(value.rate_delta)>0,"both true stat gains shown")
	check(var_to_bytes(run.s)==before and var_to_bytes(run.events)==events,"query leaves state RNG gold items receipts events unchanged")
	var actual: RefCounted=Run.new();actual.s=run.s.duplicate(true);actual.combat=preload("res://scripts/combat.gd").new();actual.combat.setup(actual)
	check(actual.command("shop_buy",{"slot":0}).ok,"actual purchase succeeds")
	var result: Dictionary=actual.in_location("inventory")[0]
	check(actual.command("equip",{"id":result.id,"cat":"C01","slot":0}).ok,"actual equip succeeds")
	actual.combat.start_stage();actual.s.battle.time=10.0
	var stats: Dictionary=actual.combat.cat_display_stats("C01")
	check(is_equal_approx(float(value.after.attack),float(stats.attack)),"display attack equals actual combat")
	check(is_equal_approx(float(value.after.rate),float(stats.rate)),"display attacks/sec equals actual combat outside opening buffs")
	run.s.items.clear()
	var reserved: Dictionary=run.create_item("F01",0,1,6,"inventory");reserved.reserved=true
	value=Advisor.preview(run,0,"C01",0)
	check(int(value.item.level)==1 and reserved.id not in value.ingredients,"reserved meal never treated as merge material")
	var worn: Dictionary=run.create_item("F01",0,1,0,"equipped");worn.cat="C01";worn.slot=2
	value=Advisor.preview(run,0,"C01",0)
	check(not bool(value.valid) and str(value.reason).contains("同名"),"different slot duplicate kind rejected")
	value=Advisor.preview(run,0,"C01",2)
	check(bool(value.valid),"same-kind replacement in its own slot valid")
	run.s.shop.auto_merge=false;reserved.reserved=false
	value=Advisor.preview(run,0,"C01",2)
	check(int(value.item.level)==1 and value.ingredients.is_empty(),"auto merge OFF previews raw purchased fish")
	run.s.gold=0;value=Advisor.preview(run,0,"C01",2)
	check(not bool(value.affordable) and bool(value.valid),"unaffordable item still supports explicit hypothetical comparison")
	run.s.shop.offers[0].sold=true
	check(Advisor.preview(run,0,"C01",2).is_empty(),"sold plate has no preview")
	finish()
func finish() -> void:
	print(JSON.stringify({"suite":"v039_shop_advisor","checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
