extends SceneTree
const Run=preload("res://scripts/run_state.gd")
var checks: int=0
var failures: Array[String]=[]
func _initialize() -> void: call_deferred("execute")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);printerr("FAIL ",label)
func execute() -> void:
	var r: RefCounted=Run.new();r.new_run(38001)
	check(r.has_method("shop_status"),"camp shop API exists")
	if not r.has_method("shop_status"): finish();return
	var shop: Dictionary=r.shop_status()
	check(shop.offers.size()==5 and shop.capacity==5,"five offers and level-one five-fish inventory")
	var rolls: Dictionary=r.s.rng.duplicate();var offers: Array=shop.offers.duplicate(true)
	r.shop_status();check(rolls==r.s.rng,"reading shop never rerolls")
	r.s.gold=1000
	var first: Dictionary=offers[0];var gold: int=r.s.gold
	check(r.command("shop_buy",{"slot":0,"offer_id":first.id},"buy-once").ok,"purchase succeeds")
	check(r.s.gold==gold-first.price and r.shop_status().offers[0].sold,"purchase spends once and leaves sold slot")
	r.command("shop_buy",{"slot":0},"buy-once")
	check(r.s.gold==gold-first.price,"receipt retry cannot double buy")
	check(not r.command("shop_buy",{"slot":0}).ok,"sold offer cannot buy twice")
	r.command("shop_lock");gold=r.s.gold
	check(not r.command("shop_refresh").ok and r.s.gold==gold,"lock blocks paid refresh")
	r.s.stage=1;r.s.phase="prep";r.shop_status()
	check(r.shop_status().offers==r.s.shop.offers and r.shop_status().offers[0].sold,"locked next camp preserves sold slots")
	r.command("shop_lock")
	for expected: int in [3,3,6]:
		check(r.shop_status().refresh_cost==expected,"refresh escalation")
		gold=r.s.gold;check(r.command("shop_refresh").ok and gold-r.s.gold==expected,"refresh actual charge")
	var gift: Dictionary=r.equipped("C01")[0]
	check(r.command("shop_order",{"id":gift.id}).ok,"chapter order accepts owned fish")
	var order: Dictionary=r.shop_status().offers[4].duplicate(true)
	check(order.kind==gift.kind and order.level==1 and order.price==10,"order costs fish plus four service coins")
	r.command("shop_refresh")
	check(r.shop_status().offers[4]==order and not r.command("shop_order",{"id":gift.id}).ok,"order persists refresh and once per chapter")
	var before: Dictionary=r.s.duplicate(true)
	r.command("start")
	for action: String in ["cast","keep","skip","sell","upgrade","recruit","merge","merge_all","equip","unequip","active","bait_target","shop_buy","shop_refresh","shop_lock","shop_auto_merge","shop_order","meal_prepare","meal_clear"]:
		check(not r.command(action).ok,"combat gate "+action)
	check(r.s.gold==before.gold and r.s.items==before.items,"rejected combat economy leaves money and items intact")
	var path: String="user://v038_shop_fixture.save";check(r.save(path),"save shop")
	var loaded: RefCounted=Run.new();check(loaded.load_save(path),"load shop")
	check(loaded.s.shop==r.s.shop,"save preserves offers sold lock RNG accounting")
	_test_capacity();finish()
func _test_capacity() -> void:
	var r: RefCounted=Run.new();r.new_run(38002);r.s.gold=999
	for n: int in range(5): r.create_item("F01",0,1,6,"inventory")
	r.command("shop_auto_merge")
	check(not r.command("shop_buy",{"slot":0}).ok,"full inventory blocks purchase without merging")
	check(r.s.items.size()==6,"failed capacity purchase does not create fish")
	r.command("shop_auto_merge")
	r.s.shop.offers[0]={"id":"fixture","kind":"F01","quality":0,"level":1,"price":6,"sold":false}
	check(r.command("shop_buy",{"slot":0}).ok and r.loose_count()<=5,"purchase may compact idle fish to make room")
	check(r.equipped("C01")[0].level==1,"automatic merge preserves equipped starter")
	for level: int in range(1,6):
		r.s.hq=level;check(r.shop_status().capacity==level*5,"capacity follows HQ")
func finish() -> void:
	print(JSON.stringify({"suite":"v038_shop","checks":checks,"failures":failures}));quit(1 if not failures.is_empty() else 0)
