extends SceneTree
## Retired emergency feed commands cannot mutate equipment or consume fish.
const Run = preload("res://scripts/run_state.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	call_deferred("_exercise")

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FAIL ", label)

func _exercise() -> void:
	var run: RefCounted = Run.new()
	run.new_run(4101, "C01", false, "hard")
	var spare: Dictionary = run.create_item("F02", 0, 1, 6, "inventory")
	var original: String = str(run.equipped("C01")[0].id)
	var items_before: PackedByteArray = var_to_bytes(run.s.items)
	for action: String in ["meal_prepare", "meal_clear", "meal_use"]:
		_check(not run.command(action, {"id":spare.id, "cat":"C01", "slot":0}).ok, "retired camp command rejected: " + action)
	_check(var_to_bytes(run.s.items) == items_before, "rejected commands preserve fish")
	_check(not run.meal_status().prepared and not run.meal_status().busy, "retired status has no active meal")
	_check(run.command("start").ok, "normal battle can start")
	_check(not run.command("meal_use").ok, "battle cannot use feed command")
	# A real v0.4.0 save can contain reserved fish or a parcel already in flight.
	for flight: float in [0.0, 0.3]:
		run.s.items[spare.id].reserved = true
		run.s.meal = {"item_id":spare.id,"cat":"C01","slot":0,"used":flight>0,"flight_left":flight,"flight_duration":0.55}
		var saved_items: Dictionary = run.s.items.duplicate(true)
		var gold: int = run.s.gold
		var path: String = "/tmp/cats-v041-meal-%d.save" % OS.get_process_id()
		_check(run.save(path), "legacy state saved using production serializer")
		var loaded: RefCounted = Run.new()
		_check(loaded.load_save(path), "legacy reserved / in-flight save loads")
		_check(loaded.s.items.size() == saved_items.size() and int(loaded.s.gold) == gold, "migration preserves all fish and gold")
		_check(not bool(loaded.s.items[spare.id].reserved) and loaded.s.items[spare.id].location == "inventory", "legacy fish unreserved in inventory")
		_check(str(loaded.equipped("C01")[0].id) == original, "migration keeps existing equipment")
		_check(not loaded.meal_status().prepared and not loaded.meal_status().busy, "migration cancels retired parcel")
		for _frame: int in range(60): loaded.step(1.0/60.0)
		_check(str(loaded.equipped("C01")[0].id) == original, "retired flight cannot change equipment after load")
		_check(loaded.events.filter(func(e: Dictionary) -> bool: return e.type in ["meal_launch","meal_arrive"]).is_empty(), "no retired parcel animation event")
		for suffix: String in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	print("V041_MEAL_RETIREMENT ", JSON.stringify({"checks":checks,"failures":failures,"player_save_access":false}))
	quit(0 if failures.is_empty() else 1)
