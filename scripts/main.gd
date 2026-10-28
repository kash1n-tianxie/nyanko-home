extends Control
## Runtime coordinator: fixed simulation, transactional input, view and save lifecycle.
const Run = preload("res://scripts/run_state.gd")
const Courtyard = preload("res://scripts/courtyard.gd")
const UI = preload("res://scripts/game_ui.gd")
const Audio = preload("res://scripts/audio_player.gd")
const Practice = preload("res://scripts/practice_session.gd")
const SkillCutin = preload("res://scripts/skill_cutin.gd")
const GuideProgress = preload("res://scripts/run_guide.gd")
const GuideView = preload("res://scripts/run_guide_view.gd")
var run: RefCounted = Run.new()
var courtyard: Node2D
var ui: Control
var audio: Node
var menu_open: bool = true
var settings: Dictionary = {"music":.35,"sfx":.4,"reduced":false,"started":false,"difficulty_default":"easy","guidance":true}
var previous_phase: String = ""
var accumulator: float = 0
var pressure_announced: bool = false
var settings_path: String = "user://cat_tree_v02.settings"
var ui_test_mode: bool = false
var aim_dragging: bool = false
var aim_height: float = 452.0
var practice_session: RefCounted
var practice_before: Dictionary = {}
var practice_after: Dictionary = {}
var practice_cat: String = ""
var practice_delivered: bool = false
var presentation_hold: float = 0.0
var presentation_state: Dictionary = {}
var presentation_paused: bool = false
var transition_held: bool = false
var exit_requested: bool = false
var skill_cutin: Control
var skill_hitstop: float=0.0
var guide: Control

func _ready() -> void:
	get_tree().auto_accept_quit = false
	_load_settings()
	courtyard = Courtyard.new()
	courtyard.name = "Courtyard"
	add_child(courtyard)
	audio = Audio.new()
	audio.name = "SoftAudio"
	audio.stopped=ui_test_mode
	add_child(audio)
	audio.set_volumes(float(settings.music),float(settings.sfx))
	skill_cutin=SkillCutin.new()
	add_child(skill_cutin)
	ui = UI.new()
	ui.name = "GameUI"
	add_child(ui)
	ui.setup(self,run)
	guide=GuideView.new()
	ui.add_child(guide)
	guide.setup(ui)

func _physics_process(delta: float) -> void:
	if menu_open or run.s.is_empty() or presentation_hold>0 or skill_hitstop>0: return
	if bool(run.s.paused) or run.combat.skills.cinematic_busy() or (guide!=null and guide.holds_combat()): accumulator=0; return
	accumulator += delta*clampf(float(run.s.get("combat_speed",1.0)),1.0,2.0)
	while accumulator>=1.0/60.0:
		run.step(1.0/60.0)
		accumulator -= 1.0/60.0
		if run.s.phase not in ["combat","cleanup"]: accumulator=0; break
	_consume_events()
	_phase_changed()

func _process(delta: float) -> void:
	if not menu_open and not run.s.is_empty() and run.combat.skills.cinematic_busy():
		run.combat.skills.tick_cinematic(delta)
		_consume_events()
		_phase_changed()
	if not menu_open:
		skill_cutin.set_frame(run.s,bool(settings.reduced))
		courtyard.transform=SkillCutin.camera_transform(run.s,bool(settings.reduced))
	else:
		skill_cutin.clear();courtyard.transform=Transform2D.IDENTITY
	courtyard.reduced = bool(settings.reduced)
	courtyard.visible = ui.scene_mode=="battle"
	courtyard.aim_height = float(run.s.get("aim_y",aim_height))
	courtyard.live_stats.clear()
	if not menu_open and run.s.get("phase","") in ["combat","cleanup"]:
		for cat_id: String in run.s.get("active",[]): courtyard.live_stats[cat_id]=run.combat.cat_display_stats(cat_id)
	if presentation_hold>0: presentation_state.paused=presentation_paused
	var view_state: Dictionary=presentation_state if presentation_hold>0 else ({} if menu_open else run.s)
	if skill_hitstop>0 or (guide!=null and guide.holds_combat()):
		view_state=view_state.duplicate(false)
		view_state.paused=true
	courtyard.tick(delta,view_state)
	var skill_paused: bool=menu_open or bool(run.s.get("paused",false)) or presentation_paused
	if not skill_paused: skill_hitstop=maxf(0,skill_hitstop-delta)
	skill_cutin.tick(delta,skill_paused)
	if presentation_hold>0:
		if not presentation_paused: presentation_hold=maxf(0,presentation_hold-delta)
		if presentation_hold<=0:
			presentation_state={}
			_phase_changed()
	if practice_session!=null and not menu_open and run.s.get("phase","")=="prep" and not bool(run.s.get("paused",false)):
		practice_session.tick(delta)
		if not practice_delivered and not practice_session.result.is_empty():
			practice_delivered=true
			ui.set_practice_result(practice_session.result)
	ui.update(delta)
	guide.tick(delta)
	audio.set_context("combat" if presentation_hold>0 else str(run.s.get("phase","prep")),int(run.s.get("stage",0)),menu_open or bool(run.s.get("paused",false)) or presentation_paused)
	if not menu_open and not run.s.is_empty():
		# Battle presentation has no economy controls or fishing popup.
		var battle: Dictionary = run.s.get("battle",{})
		if bool(battle.get("pressure",false)) and not pressure_announced:
			pressure_announced = true
			ui.notify("敌群压境！")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F11:
		get_window().mode = Window.MODE_WINDOWED if get_window().mode==Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
		get_viewport().set_input_as_handled()
		return
	if presentation_hold>0:
		if presentation_paused and ui.modal_kind=="settings":
			if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
				ui._restore_phase()
				get_viewport().set_input_as_handled()
			return
		if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE,KEY_ESCAPE]:
			toggle_pause()
		elif presentation_paused:
			return
		get_viewport().set_input_as_handled()
		return
	if ui.front_transition_busy:
		get_viewport().set_input_as_handled()
		return
	if guide!=null and guide.blocks_shortcut(event):
		get_viewport().set_input_as_handled()
		return
	if ui.handle_front_input(event):
		get_viewport().set_input_as_handled()
		return
	if ui.room_selection_busy: return
	if aim_dragging:
		if menu_open or bool(run.s.get("paused",false)) or not ui.modal_kind.is_empty() or ui.scene_mode!="battle" or (guide!=null and guide.holds_combat()):
			aim_dragging = false
		elif event is InputEventMouseMotion:
			_move_aim(event.position)
			get_viewport().set_input_as_handled()
			return
		elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
			aim_dragging = false
			get_viewport().set_input_as_handled()
			return
	if not event is InputEventKey or not event.pressed or event.echo: return
	if not ui.modal_kind.is_empty():
		# Modal controls keep their own focus navigation; world shortcuts cannot pass through.
		if event.keycode==KEY_ESCAPE and ui.modal_kind=="settings":
			ui._restore_phase()
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_ESCAPE,KEY_SPACE] and ui.modal_kind=="pause":
			toggle_pause()
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_R,KEY_U,KEY_B]: get_viewport().set_input_as_handled()
		return
	if menu_open: return
	var handled: bool = true
	match event.keycode:
		KEY_SPACE: toggle_pause()
		KEY_R:
			if not bool(run.s.paused) and run.s.phase=="prep": ui.dispatch("shop_refresh")
		KEY_U:
			if not bool(run.s.paused) and run.s.phase=="prep": ui.show_hq()
		KEY_B:
			if not bool(run.s.paused) and run.s.phase=="prep": ui.show_basket()
		KEY_ENTER:
			if run.s.phase=="prep" and ui.modal_kind.is_empty() and not bool(run.s.paused): ui.request_start()
			else: handled=false
		KEY_ESCAPE:
			if ui.cancel_context(): pass
			elif ui.modal_kind not in ["visit","confirm"]: toggle_pause()
		_: handled=false
	if handled: get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if menu_open or run.s.is_empty() or presentation_hold>0 or run.combat.skills.cinematic_busy(): return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
		if menu_open or bool(run.s.get("paused",false)) or not ui.modal_kind.is_empty() or ui.scene_mode!="battle": return
		if guide!=null and guide.blocks_world_point(event.position):
			get_viewport().set_input_as_handled()
			return
		var cat: String = courtyard.cat_at(event.position)
		if not cat.is_empty():
			var status: Dictionary=run.combat.skill_status(cat)
			if event.button_index==MOUSE_BUTTON_LEFT and bool(status.get("ready",false)) and not bool(status.get("used",false)):
				var result: Dictionary=activate_cat_skill(cat)
				if not bool(result.ok): ui.notify(str(result.message))
			else: ui.show_cat(cat)
			get_viewport().set_input_as_handled()
		elif event.button_index==MOUSE_BUTTON_LEFT and str(run.s.get("attack_mode","auto"))=="manual" and Rect2(350,110,930,423).has_point(event.position):
			aim_dragging = true
			_move_aim(event.position)
			get_viewport().set_input_as_handled()

func activate_cat_skill(cat_id: String) -> Dictionary:
	if menu_open or presentation_hold>0 or not ui.modal_kind.is_empty() or run.combat.skills.cinematic_busy():
		return {"ok":false,"message":"等这次演出收回，再释放下一只猫的绝招"}
	var result: Dictionary=dispatch("cat_skill",{"cat":cat_id})
	if bool(result.ok):
		aim_dragging=false
		ui._close_cat_card()
		ui._hide_hint()
	return result

func set_attack_mode(mode: String) -> void:
	if menu_open or run.s.is_empty() or bool(run.s.get("paused",false)): return
	aim_dragging = false
	var result: Dictionary = dispatch("attack_mode",{"mode":mode})
	if not result.ok: ui.notify(result.message)

func _move_aim(point: Vector2) -> void:
	if guide!=null and guide.blocks_action("aim"):
		aim_dragging=false
		return
	aim_height = clampf(point.y,140,505)
	run.command("aim",{"x":clampf(point.x,350,1280),"y":aim_height})

func dispatch(action: String, args: Dictionary = {}) -> Dictionary:
	if menu_open: return {"ok":false,"message":"请先开始守家"}
	if guide!=null and guide.blocks_action(action,args): return {"ok":false,"message":"请完成高亮操作，或跳过引导"}
	var before: Dictionary=run.s.duplicate(true) if run.s.get("phase","")=="prep" and action in ["equip","unequip","merge","merge_all"] else {}
	var result: Dictionary = run.command(action,args)
	if result.ok:
		var guide_before: Dictionary=run.s.get("guidance",{}).duplicate(true)
		GuideProgress.observe(run.s,action)
		# The command saves before UI observation; persist only changed guide metadata.
		if run.autosave and guide_before!=run.s.get("guidance",{}): run.save(run.save_path)
		if action in ["equip","unequip"]: audio.event({"type":action})
	if result.ok and not before.is_empty():
		for cat_id: String in run.s.active:
			var old_equipment: Array=[]
			for item: Dictionary in before.items.values():
				if item.get("location","")=="equipped" and item.get("cat","")==cat_id: old_equipment.append(item)
			var new_equipment: Array=run.equipped(cat_id).filter(func(item:Dictionary)->bool:return not item.is_empty())
			old_equipment.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return int(a.slot)<int(b.slot))
			new_equipment.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return int(a.slot)<int(b.slot))
			if var_to_bytes(old_equipment)!=var_to_bytes(new_equipment):
				call_deferred("_equipment_response",before,run.s.duplicate(true),cat_id)
				break
	if result.ok and (run.s.phase!="prep" or action in ["active","upgrade","recruit"]):
		_cancel_practice()
		practice_before={};practice_after={};practice_cat=""
	_consume_events()
	_phase_changed()
	return result

func _consume_events() -> void:
	var batch: Array = run.events
	run.events=[]
	# Transfer ownership once: views copy event envelopes and only read recipe payloads.
	for event_data: Dictionary in batch:
		courtyard.event(event_data)
		audio.event(event_data)
		if event_data.type=="skill_cast":
			skill_cutin.show_cast(event_data,bool(settings.reduced))
			skill_hitstop=0.0
			skill_cutin.set_frame(run.s,bool(settings.reduced))
			accumulator=0.0
		if event_data.type=="catch" and run.s.get("phase","")=="prep": ui.show_catch()
		if event_data.type=="stage_start":
			pressure_announced=false
			skill_hitstop=0.0;skill_cutin.clear()

func _phase_changed() -> void:
	var phase: String = str(run.s.get("phase",""))
	if phase==previous_phase or presentation_hold>0: return
	var finish_skill: bool=phase!="failed" and skill_cutin.busy()
	if previous_phase in ["combat","cleanup"] and phase not in ["combat","cleanup"] and not transition_held and (courtyard.has_death_remainder() or finish_skill):
		transition_held=true
		presentation_hold=maxf(courtyard.death_remainder_seconds(),float(skill_cutin.cast.get("duration",0))-skill_cutin.age if finish_skill else 0.0)
		presentation_paused=false
		presentation_state=run.s.duplicate(true)
		presentation_state.phase="combat";presentation_state.paused=false;presentation_state.combat_speed=1.0
		return
	if phase in ["combat","cleanup"]: transition_held=false
	else:
		skill_hitstop=0.0
		skill_cutin.clear()
	previous_phase = phase
	match phase:
		"initial_fish": ui.show_initial_fish()
		"prep": ui.show_prep()
		"visit": ui.show_visit()
		"route": ui.show_route()
		"toy_reward": ui.show_toy_reward()
		"combat","cleanup":
			ui.show_battle()
		"failed","victory": ui.show_summary()

func has_save() -> bool:
	var saved: RefCounted = Run.new()
	return saved.load_save()

func request_new_game() -> void:
	if has_save():
		ui.show_confirm("开始新的守家？", "当前已有存档。新的一局会替换它，原来的猫咪、鱼干和进度不会带入。",_choose_initial,ui.show_menu)
	else: _choose_initial()

func _choose_initial() -> void:
	ui.close_modal()
	ui._transition_to(func() -> void: ui.show_story(false))

func _finish_prologue() -> void:
	ui._transition_to(ui.show_initial)

func replay_story() -> void:
	ui._transition_to(func() -> void: ui.show_story(true))

func request_exit() -> void:
	if exit_requested: return
	exit_requested=true
	if not run.s.is_empty() and not ui_test_mode: run.save()
	set_process(false)
	set_physics_process(false)
	audio.stop_all()
	# Give the audio mixer time to release queued Ogg playbacks before tree teardown.
	await get_tree().create_timer(.08).timeout
	get_tree().quit()

func new_game(cat_id: String = "C01", difficulty: String = "") -> void:
	_cancel_presentation()
	guide.begin_run(menu_open and ui.initial_room_open)
	run.autosave = not ui_test_mode
	var chosen: String = difficulty if difficulty!="" else str(settings.get("difficulty_default","easy"))
	run.new_run(int(Time.get_unix_time_from_system()) if not ui_test_mode else 20261014,cat_id,true,chosen)
	settings.started = true
	if not ui_test_mode: _save_settings()
	menu_open = false
	previous_phase = ""
	pressure_announced = false
	aim_dragging = false
	accumulator = 0
	_phase_changed()

func resume_game() -> void:
	_cancel_presentation()
	if not run.load_save(): ui.notify("存档未通过校验，无法继续。" ); return
	run.autosave = not ui_test_mode
	menu_open = false
	previous_phase = ""
	accumulator = 0
	_phase_changed()
	if bool(run.s.paused): ui.show_pause()
	elif run.s.phase=="prep" and run.s.pending!="" and float(run.s.cast_left)<=0: ui.show_catch()

func toggle_pause() -> void:
	if presentation_hold>0:
		presentation_paused=not presentation_paused
		if presentation_paused: ui.show_pause()
		else: ui.close_modal()
		return
	if menu_open or run.s.is_empty() or run.s.phase in ["failed","victory"]: return
	aim_dragging = false
	var result: Dictionary = run.command("pause")
	if not result.ok: ui.notify(result.message); return
	accumulator = 0
	if bool(run.s.paused): ui.show_pause()
	else:
		ui.close_modal()
		if run.s.phase=="initial_fish": ui.show_initial_fish()
		elif run.s.phase=="prep": ui.show_prep()
		elif run.s.phase=="visit": ui.show_visit()
		elif run.s.phase=="route": ui.show_route()
		elif run.s.phase=="toy_reward": ui.show_toy_reward()
		elif run.s.phase=="prep" and run.s.pending!="" and float(run.s.cast_left)<=0: ui.show_catch()

func to_menu() -> void:
	_cancel_presentation()
	if not run.s.is_empty() and not ui_test_mode: run.save()
	menu_open = true
	aim_dragging = false
	accumulator = 0
	ui.show_menu()

func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	audio.set_volumes(float(settings.music),float(settings.sfx))
	if not ui_test_mode: _save_settings()

func _load_settings() -> void:
	var file: FileAccess = FileAccess.open(settings_path,FileAccess.READ)
	if file==null: return
	var value: Variant = file.get_var(false)
	if value is Dictionary:
		for key: String in settings.keys(): settings[key] = value.get(key,settings[key])

func _save_settings() -> void:
	var file: FileAccess = FileAccess.open(settings_path,FileAccess.WRITE)
	if file!=null: file.store_var(settings,false)

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		request_exit()

func _equipment_response(before: Dictionary, after: Dictionary, cat_id: String) -> void:
	if menu_open or run.s.get("phase","")!="prep": return
	practice_before=before;practice_after=after;practice_cat=cat_id
	ui.show_equipment_feedback(cat_id,Practice.stats_for(before,cat_id),Practice.stats_for(after,cat_id),Practice.thresholds(before,after,cat_id))
	start_practice("single")
	if practice_session!=null: practice_session.demo_round_limit=2 if not Practice.thresholds(before,after,cat_id).is_empty() else 1

func start_practice(target_kind: String = "single") -> void:
	if menu_open or run.s.get("phase","")!="prep": return
	_cancel_practice()
	if practice_after.is_empty():
		practice_before=run.s.duplicate(true);practice_after=run.s.duplicate(true)
		practice_cat=str(run.s.active[0])
	practice_session=Practice.new()
	practice_session.start(practice_before,practice_after,target_kind,practice_cat)
	practice_delivered=false

func _cancel_practice() -> void:
	if practice_session!=null: practice_session.cancel()
	practice_session=null
	practice_delivered=false
	if is_instance_valid(ui):
		ui.set_practice_result({})
		if is_instance_valid(ui.practice_display): ui.practice_display.set_frame({}, {})

func _cancel_presentation() -> void:
	_cancel_practice()
	practice_before={};practice_after={};practice_cat=""
	presentation_hold=0;presentation_state={};transition_held=false;presentation_paused=false
	skill_hitstop=0.0
	if is_instance_valid(skill_cutin): skill_cutin.clear()
	if is_instance_valid(courtyard): courtyard.skills_view.clear()
