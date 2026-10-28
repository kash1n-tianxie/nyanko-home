extends SceneTree
const Living=preload("res://scripts/living_stage.gd")
const Direction=preload("res://scripts/stage_art_direction.gd")
const TreeArt=preload("res://scripts/tree_presentation.gd")
const Positions=preload("res://scripts/cat_combat_positions.gd")
const ShaderSource=preload("res://shaders/battle_readability.gdshader")
var checks: int=0
var failures: Array[String]=[]

func check(condition: bool, description: String) -> void:
	checks+=1
	if not condition: failures.append(description);push_error(description)

func _initialize() -> void:
	var state: Dictionary={"seed":3601,"stage":3,"phase":"combat","hq":1,"hp":300.0,"max_hp":300.0,"combat_speed":2.0,"paused":false,"rng":{"fish":123,"combat":456},"battle":{"enemies":[]}}
	var original: PackedByteArray=var_to_bytes(state)
	var life: RefCounted=Living.new()
	life.configure(state,false)
	life.event({"type":"boss_counter_warning","kind":"B01","duration":2.0})
	check(float(life.grade_state().pressure)>0.0,"charging supplies local environment pressure")
	life.event({"type":"boss_departure","kind":"B01","target":11})
	life.tick(.5)
	check(is_equal_approx(float(life.snapshot().aftermath_age),.5),"two-second quiet ending ignores 2x combat speed")
	check(float(life.grade_state().aftermath)>0.0 and float(life.grade_state().aftermath)<1.0,"warmth eases in instead of flashing")
	check(float(life.grade_state().pressure)==0.0,"departed Boss clears pressure")
	var early_warmth: float=float(life.grade_state().aftermath)
	life.event({"type":"death","kind":"B01","boss":true,"target":11})
	check(is_equal_approx(float(life.snapshot().aftermath_age),.5),"duplicate departure/death cannot restart the epilogue")
	state.paused=true;life.configure(state,false)
	var frozen: PackedByteArray=var_to_bytes(life.snapshot())
	life.tick(4.0)
	check(frozen==var_to_bytes(life.snapshot()),"pause freezes warmth, tree pendulum and ending")
	state.paused=false;life.configure(state,false);life.tick(1.6)
	check(float(life.grade_state().aftermath)>early_warmth and is_equal_approx(float(life.grade_state().aftermath),1.0),"lamps reach a stable warm finish after 2.1 seconds")
	check(is_zero_approx(float(life.quiet_remaining())),"quiet hold ends after its duration")
	life.tick(2.0)
	check(is_equal_approx(float(life.grade_state().aftermath),1.0),"warm finish holds without pulsation")
	state.paused=false
	check(original==var_to_bytes(state),"presentation events leave simulation, RNG, HP and speed untouched")
	var grade: ShaderMaterial=ShaderMaterial.new();grade.shader=ShaderSource
	for stage: int in range(20):
		Direction.configure_material(grade,stage,life.grade_state())
		var spec: Dictionary=Direction.chapter_config(stage)
		check(str(spec.name)!="" and float(grade.get_shader_parameter("strength"))>0.0,"encounter %d has an authored chapter grade" % stage)
		check(float(grade.get_shader_parameter("contrast"))>=.7 and float(grade.get_shader_parameter("saturation"))>=.7,"encounter %d keeps illustration detail and color" % stage)
		check(is_equal_approx(float(grade.get_shader_parameter("aftermath")),1.0),"encounter %d receives warm ending" % stage)
		var detached: Dictionary=Direction.chapter_config(stage);detached.strength=0.0
		check(float(Direction.chapter_config(stage).strength)>0.0,"chapter spec edits cannot mutate shared authoring data")
	state.stage=4;life.configure(state,false)
	check(not bool(life.snapshot().aftermath_active) and float(life.grade_state().aftermath)==0.0,"new encounter clears old warmth and settling")
	var tree: RefCounted=TreeArt.new()
	for level: int in range(1,6):
		tree.configure({"hq":level,"hp":300,"max_hp":300},false,true)
		var frame: Dictionary=tree.snapshot()
		check(frame.anchors==Positions.FEET.slice(0,level),"level %d leaves each foot anchor identical" % level)
		check(int(frame.silhouette.posts)==mini(level,3),"level %d evolves the support silhouette" % level)
		tree.configure({"hq":level,"hp":150,"max_hp":300},false)
		tree.tick(.08)
		var swing: Dictionary=tree.snapshot()
		check(absf(float(swing.rope_angle))>absf(float(swing.charm_angle)),"level %d rope leads its hanging ornament after impact" % level)
		check(swing.anchors==Positions.FEET.slice(0,level),"level %d impact never shakes platform feet" % level)
		for sample: int in range(240): tree.tick(1.0/60.0)
		check(absf(float(tree.snapshot().rope_angle))<.01 and absf(float(tree.snapshot().charm_angle))<.01,"level %d ornaments settle without accumulating motion" % level)
	var report: Dictionary={"suite":"v036_stage_art","checks":checks,"failures":failures}
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
