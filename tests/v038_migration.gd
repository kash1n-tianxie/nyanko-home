extends SceneTree
const Run=preload("res://scripts/run_state.gd")
var checks: int=0
var failures: Array[String]=[]
func _initialize() -> void: call_deferred("execute")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);printerr("FAIL ",label)
func execute() -> void:
	var r: RefCounted=Run.new();r.new_run(38999)
	for n: int in range(32): r.create_item("F%02d"%(n%10+1),n%3,n%5+1,6,"inventory")
	var paid: Dictionary=r.create_item("F04",1,2,17,"pending")
	r.s.pending=paid.id;r.s.cast_left=.4;r.s.erase("shop");r.s.erase("meal");r.s.rng.erase("shop")
	var old_rng: Dictionary=r.s.rng.duplicate();var count: int=r.s.items.size()
	var path: String="user://v038_legacy_fixture.save";check(r.save(path),"write isolated legacy fixture")
	var bytes: PackedByteArray=FileAccess.get_file_as_bytes(path)
	var loaded: RefCounted=Run.new();check(loaded.load_save(path),"migrate old pending and over-capacity inventory")
	check(loaded.s.items.size()==count and loaded.item(paid.id).paid_basis==17 and loaded.item(paid.id).location=="inventory","paid old catch and overflow retained")
	check(loaded.s.pending=="" and float(loaded.s.cast_left)==0,"legacy flight safely retired")
	for key: String in old_rng: check(loaded.s.rng[key]==old_rng[key],"preserve legacy RNG "+key)
	check(FileAccess.get_file_as_bytes(path)==bytes,"migration read does not rewrite source save")
	loaded.s.gold=999
	check(not loaded.command("shop_buy",{"slot":0}).ok,"overflow blocks extra purchases")
	check(loaded.command("sell",{"id":paid.id}).ok and loaded.s.gold==1007,"overflow still permits sale at original paid cost")
	r=Run.new();r.new_run(38222);r.s.gold=100
	var gift: Dictionary=r.equipped("C01")[0]
	r.command("shop_order",{"id":gift.id});check(r.command("shop_buy",{"slot":4}).ok,"buy ordered fish")
	var loose: Array=r.in_location("inventory");check(loose.size()==1 and loose[0].paid_basis==6,"service fee excluded from paid basis")
	var gold: int=r.s.gold;r.command("sell",{"id":loose[0].id})
	check(r.s.gold==gold+3,"order refund is half fish price, not service fee")
	var before: Dictionary=r.s.duplicate(true)
	r.autosave=true;r.save_path="/missing-v038-no-directory/test.save"
	check(not r.command("shop_buy",{"slot":0}).ok,"save failure rejects purchase")
	check(r.s==before,"save failure restores gold offers items RNG and receipt")
	r.autosave=false;r.s.shop.offers[0].level=99
	var bad: String="user://v038_invalid_fixture.save";r.save(bad)
	check(not loaded.load_save(bad),"invalid store payload rejected before use")
	print(JSON.stringify({"suite":"v038_migration","checks":checks,"failures":failures}));quit(1 if not failures.is_empty() else 0)
