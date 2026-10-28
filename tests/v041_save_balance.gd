extends SceneTree
const Run = preload("res://scripts/run_state.gd")
const Data = preload("res://scripts/catalog.gd")
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_exercise")
func _check(value: bool, label: String) -> void:
	if not value: failures.append(label); printerr("FAIL ",label)
func _exercise() -> void:
	var run: RefCounted = Run.new()
	run.new_run(4102,"C04",false,"hard")
	run.command("start")
	for _frame: int in range(30): run.step(1.0/60.0)
	run.s.balance_version=34
	run.combat.get_cat("C04").range=400
	var gold: int=run.s.gold
	var hp: float=run.s.hp
	var projectiles: PackedByteArray=var_to_bytes(run.s.battle.get("projectiles",[]))
	var path: String="/tmp/cats-v041-balance-%d.save" % OS.get_process_id()
	_check(run.save(path),"old balance fixture saved")
	var loaded: RefCounted=Run.new()
	_check(loaded.load_save(path),"old battle save loads")
	_check(float(loaded.combat.get_cat("C04").range)==float(Data.cats().C04.range),"old hammer range migrates to catalog value")
	_check(loaded.s.gold==gold and is_equal_approx(loaded.s.hp,hp),"migration preserves economy and health")
	_check(var_to_bytes(loaded.s.battle.get("projectiles",[]))==projectiles,"migration preserves projectiles already in flight")
	_check(int(loaded.s.balance_version)==41,"migration version recorded")
	for suffix: String in ["",".bak",".tmp"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	print("V041_SAVE_BALANCE ",JSON.stringify({"checks":6,"failures":failures,"player_save_access":false}))
	quit(0 if failures.is_empty() else 1)
