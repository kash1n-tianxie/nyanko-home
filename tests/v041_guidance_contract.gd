extends SceneTree
## Isolated transactions and metadata checks; no player save access.
const Run=preload("res://scripts/run_state.gd")
const Guide=preload("res://scripts/run_guide.gd")
var checks: int=0
var failures: Array[String]=[]
func _initialize() -> void: call_deferred("_exercise")
func _check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label);printerr("FAIL ",label)
func _without_guide(state: Dictionary) -> PackedByteArray:
	var copy: Dictionary=state.duplicate(true);copy.erase("guidance")
	return var_to_bytes(copy)
func _exercise() -> void:
	var run: RefCounted=Run.new();run.autosave=false
	run.new_run(41001,"C01",true,"easy")
	var before: PackedByteArray=_without_guide(run.s)
	Guide.ensure(run.s)
	_check(_without_guide(run.s)==before,"guide initialization cannot alter gameplay or RNG")
	var failed: Dictionary=run.command("choose_fish",{"kind":"missing"})
	if failed.ok: Guide.observe(run.s,"choose_fish")
	_check(not failed.ok and not Guide.completed(run.s,"starter_fish"),"failed fish choice never completes step")
	var result: Dictionary=run.command("choose_fish",{"kind":run.s.initial_fish_choices[0]})
	if result.ok: Guide.observe(run.s,"choose_fish")
	_check(result.ok and Guide.completed(run.s,"starter_fish"),"successful starter command completes only starter step")
	_check(not Guide.completed(run.s,"equip"),"starter fish does not claim a real inventory equip")
	run.s.gold=0
	failed=run.command("upgrade")
	if failed.ok: Guide.observe(run.s,"upgrade")
	_check(not failed.ok and not Guide.completed(run.s,"upgrade"),"unaffordable HQ command leaves guide pending")
	run.s.gold=18
	result=run.command("upgrade")
	if result.ok: Guide.observe(run.s,"upgrade")
	_check(result.ok and Guide.completed(run.s,"upgrade") and run.recruit_choices().size()==2,"real affordable upgrade completes guide and offers two cats")
	_check(not Guide.completed(run.s,"recruit"),"upgrade alone never claims recruitment")
	failed=run.command("recruit",{"cat":"C01"})
	if failed.ok: Guide.observe(run.s,"recruit")
	_check(not failed.ok and not Guide.completed(run.s,"recruit"),"invalid recruit cannot advance guide")
	result=run.command("recruit",{"cat":run.recruit_choices()[0]})
	if result.ok: Guide.observe(run.s,"recruit")
	_check(result.ok and Guide.completed(run.s,"recruit") and run.s.active.size()==2,"real recruit completes guide and adds teammate")
	before=_without_guide(run.s)
	Guide.observe(run.s,"start")
	_check(Guide.completed(run.s,"start") and not Guide.completed(run.s,"shop") and not Guide.completed(run.s,"equip"),"departure never falsely marks purchases or equipment complete")
	Guide.observe(run.s,"meal_use")
	_check(not Guide.completed(run.s,"meal"),"removed emergency meal has no guidance step")
	_check(_without_guide(run.s)==before,"observation mutates only presentation metadata")
	Guide.ensure(run.s).dismissed=true
	var snapshot: Dictionary=run.s.guidance.duplicate(true)
	var path: String="/tmp/cats-v041-guide-%s.save" % OS.get_process_id()
	_check(run.save(path),"production serializer saves guidance")
	var restored: RefCounted=Run.new()
	_check(restored.load_save(path) and Guide.ensure(restored.s)==snapshot,"save/load retains exact guidance and dismissal")
	for suffix: String in ["",".tmp",".bak"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	restored.new_run(41001,"C02",true,"easy")
	_check(Guide.ensure(restored.s).done.is_empty() and not bool(restored.s.guidance.dismissed),"new run resets guidance even with repeated seed")
	var legacy: Dictionary={"guidance":{"version":1,"done":{"shop":true,"meal":true},"dismissed":true},"stage":4}
	var migrated: Dictionary=Guide.ensure(legacy)
	_check(migrated.version==2 and migrated.dismissed and migrated.done.shop,"legacy migration preserves acknowledged progress and skip")
	print("V041_GUIDANCE_CONTRACT ",JSON.stringify({"checks":checks,"failures":failures,"player_save_access":false}))
	quit(0 if failures.is_empty() else 1)
