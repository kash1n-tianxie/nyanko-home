extends SceneTree
const Run=preload("res://scripts/run_state.gd")
const Toys=preload("res://scripts/toy_catalog.gd")
const SAVE: String="user://v034_toys_reward_review.save"
var checks: int=0
var failures: Array=[]
func _initialize() -> void: call_deferred("execute")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label);printerr("FAIL ",label)
func reward_run() -> RefCounted:
	var model: RefCounted=Run.new();model.new_run(34019)
	model.s.stage=19;model.s.phase="toy_reward";model.s.route_from=19;model.s.route_to=20
	model.s.toys={"T10":7,"T01":7,"T03":21}
	model.s.reward_choices=["T10","T01","T03","T04"]
	model.s.balance_version=33
	return model
func execute() -> void:
	var model: RefCounted=reward_run()
	var before: Dictionary=model.s.toys.duplicate(true)
	var rng: Dictionary=model.s.rng.duplicate(true)
	check(not model.command("reward_choose",{"id":"T10"}).ok,"stale capped reward rejected at transaction boundary")
	check(model.s.toys==before and model.s.phase=="toy_reward","rejected cap cannot spend reward or add meaningless stack")
	model=reward_run()
	check(model.save(SAVE),"write isolated legacy reward offer")
	var loaded: RefCounted=Run.new()
	check(loaded.load_save(SAVE),"legacy capped offer loads")
	check(loaded.s.reward_choices.size()==4,"migration replaces capped entries with complete legal offer")
	check("T04" in loaded.s.reward_choices,"migration preserves the original legal option")
	var unique: Array=[]
	for id: String in loaded.s.reward_choices:
		check(not Toys.is_capped(id,int(loaded.s.toys.get(id,0))),"migrated reward has actual power "+id)
		check(id not in unique,"migrated rewards remain unique "+id)
		unique.append(id)
	check(loaded.s.rng==rng,"offer repair does not consume future random streams")
	var again: RefCounted=Run.new()
	check(again.load_save(SAVE) and again.s.reward_choices==loaded.s.reward_choices,"reloading old offer cannot reroll replacement")
	var repaired: Array=loaded.s.reward_choices.duplicate()
	check(not loaded.command("reward_choose",{"id":"T10"}).ok and loaded.s.reward_choices==repaired,"old UI selection cannot claim removed capped reward")
	loaded=again
	var selected: String=str(loaded.s.reward_choices[0])
	var old_count: int=int(loaded.s.toys.get(selected,0))
	check(loaded.command("reward_choose",{"id":selected},"migration_claim").ok,"repaired real reward can be selected")
	check(int(loaded.s.toys.get(selected,0))==old_count+1 and loaded.s.phase=="route","repaired selection applies exactly once")
	var claimed: Dictionary=loaded.s.duplicate(true)
	check(loaded.command("reward_choose",{"id":selected},"migration_claim").ok and loaded.s==claimed,"repeat migration claim receipt is inert")
	# An already-legal saved offer keeps every choice and its exact ordering.
	model=reward_run();model.s.reward_choices=["T04","T06","T11","T13"]
	model.save(SAVE)
	loaded=Run.new()
	check(loaded.load_save(SAVE) and loaded.s.reward_choices==model.s.reward_choices,"legal old choices do not change on migration")
	check(loaded.s.rng==model.s.rng,"legal migration leaves all RNG untouched")
	# New settlement continues to use the reward stream and filters the same caps.
	model=reward_run();model.s.phase="combat";model.s.reward_choices=[];model.s.battle={"time":80.0}
	rng=model.s.rng.duplicate(true)
	model.settle_stage()
	check(model.s.rng.reward!=rng.reward,"new reward generation still consumes its normal random stream")
	for id: String in model.s.reward_choices: check(not Toys.is_capped(id,int(model.s.toys.get(id,0))),"new reward excludes capped toy "+id)
	for suffix: String in ["",".bak",".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE+suffix))
	print(JSON.stringify({"checks":checks,"failures":failures,"ok":failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)
