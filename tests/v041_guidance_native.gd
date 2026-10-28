extends "res://scripts/main.gd"
## Automated native UI exercise. Player saves/settings are never read or written.
const Locale=preload("res://scripts/game_locale.gd")
const OUT: String="res://outputs/v041/guide-qa"
class MemoryRun extends "res://scripts/run_state.gd":
	var memory: Dictionary={}
	func save(_path: String=SAVE_PATH) -> bool:
		memory=s.duplicate(true)
		return true
	func load_save(_path: String=SAVE_PATH) -> bool:
		if memory.is_empty(): return false
		s=memory.duplicate(true)
		combat=Battle.new();combat.setup(self)
		return true
var failures: Array[String]=[]
var checks: int=0
var evidence: Array=[]
var old_language: String="ja"
var old_preference_path: String=""
var test_preference_path: String=""
var finished: bool=false
func _load_settings() -> void:
	settings.music=0.0;settings.sfx=0.0;settings.reduced=true;settings.started=true;settings.guidance=true
func _save_settings() -> void: pass
func has_save() -> bool: return not run.memory.is_empty()
func _ready() -> void:
	ui_test_mode=true
	run=MemoryRun.new()
	old_language=Locale.current_language()
	old_preference_path=Locale.preference_path
	test_preference_path="/tmp/cats-v041-guidance-language-%s.cfg" % OS.get_process_id()
	Locale.preference_path=test_preference_path
	Locale.initialize()
	Locale.set_language(Locale.current_language(),false)
	super._ready()
	set_physics_process(false)
	run.autosave=false
	DirAccess.make_dir_recursive_absolute(OUT)
	get_tree().create_timer(80).timeout.connect(func() -> void:
		_check(false,"native fixture timed out")
		_finish())
	call_deferred("_exercise")
func _check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label);push_error("V041_QA "+label)
func _wait(seconds: float=.18) -> void:
	await get_tree().create_timer(seconds).timeout
	await get_tree().process_frame
func _control(key: String) -> Control: return ui.find_child(key,true,false) as Control
func _move_away() -> void:
	Input.warp_mouse(Vector2(2,2))
	var motion: InputEventMouseMotion=InputEventMouseMotion.new()
	motion.position=Vector2(2,2);motion.global_position=motion.position
	get_viewport().push_input(motion,true)
	ui._hide_hint();ui._close_cat_card()
	await _wait()
func _click_point(point: Vector2) -> void:
	for pressed: bool in [true,false]:
		var event: InputEventMouseButton=InputEventMouseButton.new()
		event.position=point;event.global_position=point
		event.pressed=pressed;event.button_index=MOUSE_BUTTON_LEFT
		get_viewport().push_input(event,true)
		await get_tree().process_frame
	await _move_away()
func _click(key: String) -> void:
	var source: Control=_control(key)
	_check(source!=null,"click target exists "+key)
	if source==null: return
	_check(source.is_visible_in_tree(),"click target visible "+key)
	if source is BaseButton: _check(not source.disabled,"click target enabled "+key)
	await _click_point(source.get_global_rect().get_center())
func _hover(key: String) -> void:
	var source: Control=_control(key)
	_check(source!=null,"hover target exists "+key)
	if source==null: return
	var center: Vector2=source.get_global_rect().get_center()
	Input.warp_mouse(get_viewport().get_final_transform()*center)
	var motion: InputEventMouseMotion=InputEventMouseMotion.new()
	motion.position=center;motion.global_position=center
	get_viewport().push_input(motion,true)
	await _wait(.3)
func _key(code: Key) -> void:
	for down: bool in [true,false]:
		var event: InputEventKey=InputEventKey.new()
		event.keycode=code;event.pressed=down
		Input.parse_input_event(event)
		await get_tree().process_frame
	await _wait(.25)
func _shot(label: String) -> void:
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var picture: Image=get_viewport().get_texture().get_image()
		picture.save_png(OUT+"/"+label+".png")
	evidence.append({"image":label,"language":Locale.current_language(),"window":[get_window().size.x,get_window().size.y],"step":guide.step_id,"guide_visible":guide.card.is_visible_in_tree(),"bubble":str(guide.bubble_rect),"targets":str(guide.target_rects)})
func _expect_step(key: String) -> void:
	_check(guide.step_id==key,"guide step expected "+key+", found "+guide.step_id)
	_check(guide.card.is_visible_in_tree(),"guide card visible "+key)
	_check(guide.message.get_minimum_size().y<=guide.message.size.y+.5,"guide message minimum height fits "+key)
	_check(guide.message.get_line_count()<=guide.message.get_visible_line_count(),"guide all text lines visible "+key)
	_check(guide.card.get_global_rect().encloses(guide.message.get_global_rect()),"guide text stays inside paper "+key)
	var safe: Rect2=guide._bounds()
	_check(safe.encloses(guide.bubble_rect),"guide card stays in logical viewport "+key)
	_check(not guide.target_rects.is_empty(),"guide highlights real action "+key)
	for rect: Rect2 in guide.target_rects:
		_check(safe.grow(6).encloses(rect),"highlight stays in logical viewport "+key)
		_check(not guide.bubble_rect.intersects(rect),"short guidance avoids target "+key)
		for blocked: Rect2 in guide.dim_rects:
			_check(not blocked.has_point(rect.get_center()),"spotlight hole passes target "+key)
	_check(not guide.dim_rects.is_empty(),"non-target area has a dim input mask "+key)
	for piece: ColorRect in guide.dim_pieces:
		if piece.visible: _check(piece.mouse_filter==Control.MOUSE_FILTER_STOP,"visible mask stops non-target mouse input "+key)
func _guide_done(key: String) -> bool: return bool(run.s.get("guidance",{}).get("done",{}).get(key,false))
func _exercise() -> void:
	await _wait(.3)
	Locale.set_language("ja",false)
	ui.show_initial();await _move_away()
	_expect_step("cat")
	await _click_point(Vector2(10,10))
	_check(menu_open and not ui.room_selection_busy,"dim area cannot choose a cat")
	for dimension: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1440,600)]:
		get_window().size=dimension;await _wait(.2)
		_expect_step("cat");await _shot("ja-cat-%dx%d" % [dimension.x,dimension.y])
	await _hover("ChooseC01")
	_check(guide.step_id=="cat" and guide.visible,"cat tooltip does not remove selection mask")
	await _click("ChooseC01");await _wait(1.3)
	_check(run.s.phase=="initial_fish","native highlighted cat click reaches starter fish")
	_expect_step("starter_fish")
	var before: Dictionary=run.s.guidance.duplicate(true)
	_check(not dispatch("choose_fish",{"kind":"missing"}).ok and run.s.guidance==before,"failed command cannot advance guide")
	await _click("ChooseFish"+str(run.s.initial_fish_choices[0]));await _wait(.5)
	_expect_step("shop")
	var gold_before: int=int(run.s.gold)
	await _click("Start")
	_check(run.s.phase=="prep" and int(run.s.gold)==gold_before,"dim mask prevents accidental departure")
	_check(not dispatch("start").ok,"command guard rejects shortcut bypass of purchase guide")
	await _hover("ShopBuy0")
	_check(guide.step_id=="shop" and guide.visible,"shop tooltip cannot unlock non-target controls")
	_check(not ui.fish_hint.visible,"strong shop guide suppresses competing hover popup")
	await _shot("ja-shop-hover")
	await _move_away()
	var offer_index: int=0
	for index: int in range(run.shop_status().offers.size()):
		if int(run.shop_status().offers[index].price)<int(run.shop_status().offers[offer_index].price): offer_index=index
	await _click("ShopBuy%d" % offer_index)
	_check(_guide_done("shop"),"real shop click marks purchase complete")
	_expect_step("inventory")
	var loose: Dictionary=run.in_location("inventory")[0]
	await _click("Fish"+str(loose.id))
	_expect_step("equip")
	await _click("EquipTarget"+guide.target_cat+str(guide.target_slot))
	_check(_guide_done("equip") and run.item(str(loose.id)).location=="equipped","real highlighted slot equips fish")
	if run.s.gold<18:
		_expect_step("start")
		_check(not _guide_done("upgrade"),"low-gold run can depart without claiming HQ completion")
		run.s.gold=18;ui.show_prep();await _move_away()
	_expect_step("upgrade")
	await _hover("HomeUpgrade")
	_check(not ui.fish_hint.visible,"HQ hover does not cover upgrade target with duplicate popup")
	await _shot("ja-hq-upgrade")
	Locale.set_language("zh_CN",false);await _wait()
	_check(guide.message.text.begins_with("点击升级"),"Chinese guide follows locale switch")
	await _shot("zh-hq-upgrade")
	Locale.set_language("ja",false);await _wait()
	ui.show_settings();await _wait()
	_check(not guide.visible,"settings modal immediately suspends mask")
	_check(not guide.blocks_action("shop_refresh"),"modal owns its input without stale guide guards")
	ui._restore_phase();await _move_away();_expect_step("upgrade")
	await _click("HomeUpgrade")
	_check(int(run.s.hq)==2 and _guide_done("upgrade"),"native upgrade click spends gold and completes step")
	_expect_step("recruit")
	_check(run.recruit_choices().size()==2,"upgrade creates two real recruit choices")
	await _shot("ja-recruit-two-choice")
	var chosen: String=str(run.recruit_choices()[1])
	await _click("Recruit"+chosen)
	_check(chosen in run.s.active and _guide_done("recruit"),"second highlighted recruit joins the active team")
	_expect_step("start")
	await _click("Start")
	_check(run.s.phase in ["combat","cleanup"] and _guide_done("start"),"real departure starts battle")
	# Charge through production simulation; no direct ready flag is assigned.
	for _tick: int in range(1500):
		if bool(run.combat.skill_status("C01").get("ready",false)): break
		if run.s.phase not in ["combat","cleanup"]: break
		run.step(1.0/60.0)
	_consume_events();_phase_changed();await _move_away()
	_expect_step("skill")
	_check(guide.holds_combat() and not bool(run.s.paused),"first skill holds combat without changing pause-menu state")
	var aim_before: Vector2=Vector2(float(run.s.aim_x),float(run.s.aim_y))
	aim_dragging=true
	_move_aim(Vector2(1170,480))
	_check(not aim_dragging and Vector2(float(run.s.aim_x),float(run.s.aim_y))==aim_before,"spotlight blocks an existing manual aim drag")
	aim_dragging=true
	var dragging_event: InputEventMouseMotion=InputEventMouseMotion.new()
	dragging_event.position=Vector2(1170,480)
	_input(dragging_event)
	_check(not aim_dragging and Vector2(float(run.s.aim_x),float(run.s.aim_y))==aim_before,"input route also cancels the drag under skill spotlight")
	var frozen: float=float(run.s.battle.time)
	for _frame: int in range(8): _physics_process(.05);_process(.05)
	_check(is_equal_approx(float(run.s.battle.time),frozen),"controller integration actually freezes battle while skill is highlighted")
	_check(guide.blocks_world_point(Vector2(900,300)),"world clicks outside highlighted cat are rejected")
	_check(not guide.blocks_world_point(courtyard.cat_position(0)),"highlighted battlefield cat remains clickable")
	for dimension: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1440,600)]:
		get_window().size=dimension;await _wait(.2)
		_expect_step("skill");await _shot("ja-skill-%dx%d" % [dimension.x,dimension.y])
	await _click_point(courtyard.cat_position(0))
	_check(bool(run.combat.skill_status("C01").used) and _guide_done("skill"),"native cat click uses real skill and completes guide")
	_check(not guide.visible and not guide.holds_combat(),"successful skill clears mask and releases guide hold")
	await _wait(3.6)
	_check(not run.combat.skills.cinematic_busy(),"skill cinematic finishes after tutorial hold is released")
	_physics_process(.1)
	_check(float(run.s.battle.time)>frozen,"normal battle simulation resumes after skill")
	# Insufficient funds leave upgrade incomplete without a dead-end spotlight.
	new_game("C01","easy");await _move_away()
	ui.dispatch("choose_fish",{"kind":run.s.initial_fish_choices[0]});await _move_away()
	GuideProgress.ensure(run.s).done.shop=true;GuideProgress.ensure(run.s).done.equip=true
	run.s.gold=0;ui.show_prep();await _move_away()
	_expect_step("start")
	_check(not _guide_done("upgrade"),"unaffordable upgrade is deferred without false completion")
	await _key(KEY_ESCAPE)
	_check(not guide.visible and bool(run.s.guidance.dismissed),"Escape skips this run's guide")
	_check(not guide.blocks_action("start") and not guide.holds_combat(),"skip releases action and simulation guards")
	new_game("C02","easy");await _move_away();_expect_step("starter_fish")
	await _click_point(guide.close_button.get_global_rect().get_center())
	_check(not guide.visible and bool(run.s.guidance.dismissed),"native visible skip button dismisses guide")
	_check(not guide.COPY.has("meal"),"emergency feeding guide is removed")
	# Skip during a ready skill releases the independent simulation hold as well.
	run.command("choose_fish",{"kind":run.s.initial_fish_choices[0]})
	run.command("start")
	guide.begin_run();GuideProgress.ensure(run.s).dismissed=false
	run.combat.b.schedule=[];run.combat.b.duration=9999
	var enemy: Dictionary=run.combat.spawn("E01",900)
	enemy.hp=100000;enemy.max_hp=100000
	run.combat.skills.tick(float(run.combat.skill_status("C02").duration)+.01)
	previous_phase="combat";ui.show_battle();await _move_away()
	_expect_step("skill")
	_check(guide.holds_combat(),"second isolated ready skill establishes hold")
	frozen=float(run.s.battle.time)
	await _click_point(guide.close_button.get_global_rect().get_center())
	_check(not guide.holds_combat() and not _guide_done("skill"),"skipping ready skill releases hold without pretending it was used")
	_physics_process(.1)
	_check(float(run.s.battle.time)>frozen and not run.combat.skill_status("C02").used,"skill skip resumes simulation and preserves the unused ability")
	_finish()
func _finish() -> void:
	if finished: return
	finished=true
	Locale.preference_path=old_preference_path
	Locale.set_language(old_language,false)
	if FileAccess.file_exists(test_preference_path): DirAccess.remove_absolute(test_preference_path)
	var report: Dictionary={"checks":checks,"failures":failures,"screenshots":evidence,"automated":true,"player_save_access":false}
	var file: FileAccess=FileAccess.open(OUT+"/native-report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "));file.close()
	print("V041_NATIVE_QA ",JSON.stringify({"checks":checks,"failures":failures,"screenshots":evidence.size()}))
	get_tree().quit(0 if failures.is_empty() else 1)
