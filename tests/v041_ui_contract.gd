extends "res://scripts/main.gd"
## Automated native Control/input contract; no player save or preference writes.
const Locale=preload("res://scripts/game_locale.gd")
const OUT: String="res://outputs/upgrade-v041/ui-qa"
var checks: int=0
var failures: Array[String]=[]
var captures: Array[String]=[]
var original_language: String="ja"
func _load_settings() -> void:
	settings={"music":0.0,"sfx":0.0,"reduced":true,"started":true,"guidance":false}
func _save_settings() -> void: pass
func has_save() -> bool: return false
func _ready() -> void:
	ui_test_mode=true;super._ready();run.autosave=false
	original_language=Locale.current_language()
	run.save_path=OUT+"/never-written.save"
	set_physics_process(false)
	DirAccess.make_dir_recursive_absolute(OUT)
	call_deferred("_exercise")
func _check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);printerr("V041_UI_FAIL ",label)
func _node(key: String) -> Control: return ui.find_child(key,true,false) as Control
func _wait() -> void:
	await get_tree().create_timer(.06).timeout
	await get_tree().process_frame;await get_tree().process_frame
func _click(key: String) -> void:
	if DisplayServer.get_name()!="headless": get_window().grab_focus()
	await _wait()
	var target: BaseButton=_node(key) as BaseButton
	_check(target!=null,"click target "+key)
	if target==null: return
	_check(target.is_visible_in_tree() and not target.disabled,"clickable "+key)
	var point: Vector2=get_viewport().get_final_transform()*target.get_global_rect().get_center()
	for pressed: bool in [true,false]:
		var event: InputEventMouseButton=InputEventMouseButton.new()
		event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
		Input.parse_input_event(event);await get_tree().process_frame
	ui._hide_hint();ui._close_cat_card()
	var motion: InputEventMouseMotion=InputEventMouseMotion.new()
	motion.position=Vector2(2,2);motion.global_position=motion.position
	get_viewport().push_input(motion,true)
	await _wait()
func _rig(count: int=1) -> void:
	_cancel_presentation();menu_open=false;previous_phase=""
	run.new_run(41025,"C01",false,"easy")
	run.s.active=["C01","C02","C03","C04","C06"].slice(0,count)
	run.s.owned=run.s.active.duplicate();run.s.gold=120
	run.s.hq=count;run.s.applied_hq=count
	run.s.chapter_events.used=[1,2,3,4,5]
	run.s.items.clear();run.shop_status()
	for slot: int in range(5):
		run.s.shop.offers[slot]={"id":"v041offer"+str(slot),"kind":"F%02d"%(slot+1),"quality":0,"level":1,"price":6,"paid_basis":6,"sold":false,"ordered":false}
	ui.prep_focus_cat="C01";ui.prep_focus_slot=0
	_phase_changed();ui.show_prep()
func _no_meal() -> void:
	for key: String in ["CampMeal","MealSetup","MealClear","EquipMeal","EmergencyMeal","EmergencyFeed"]:
		_check(_node(key)==null,"removed node "+key)
	for function: String in ["_show_meal_setup","_prepare_meal","_show_meal_hint","_build_meal_summary"]:
		_check(not ui.has_method(function),"removed UI command path "+function)
func _within(key: String) -> void:
	var node: Control=_node(key)
	_check(node!=null,"layout target "+key)
	if node!=null: _check(Rect2(0,0,1280,720).encloses(node.get_global_rect()),"inside viewport "+key)
func _header_layout() -> void:
	var previous: Control=null
	for key: String in ["HomeHeading","CampTools","CampaignJournal","HomeGold","HomeHQ","HomeSettings"]:
		var control: Control=_node(key)
		if control==null: continue
		if previous!=null: _check(not previous.get_global_rect().intersects(control.get_global_rect()),"header controls separated "+key)
		previous=control
	var level: Label=_node("HomeHQLevel") as Label
	if level!=null:
		var extent: Vector2=level.get_theme_font("font").get_string_size(Locale.text(level.text),HORIZONTAL_ALIGNMENT_LEFT,-1,level.get_theme_font_size("font_size"))
		_check(extent.x<=level.size.x,"HQ level wording fully visible")
func _shot(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	var picture: Image=get_viewport().get_texture().get_image()
	picture.save_png(OUT+"/"+label+".png");captures.append(label)
func _exercise() -> void:
	await _wait()
	for language: String in ["ja","zh_CN"]:
		Locale.set_language(language,false)
		for dimension: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1440,600)]:
			get_window().size=dimension;_rig();await _wait()
			_no_meal();_header_layout()
			var hq: Button=_node("HomeUpgrade") as Button
			_check(hq!=null and Locale.text(hq.text).contains("金币") if language=="zh_CN" else hq!=null and Locale.text(hq.text).contains("コイン"),"upgrade names action and currency "+language)
			_check(_node("HomeHQLevel")!=null,"HQ level has dedicated label")
			_check(_node("InventoryTray").size.x>=1230,"inventory fills released meal area")
			_check(_node("ShopOrder")==null and _node("ShopAutoMerge")==null,"secondary shop actions folded")
			for key: String in ["HomeUpgrade","HomeHQLevel","Start","ShopBuy0","ShopBuy4","InventoryTray","CampTools","CampaignJournal"]: _within(key)
			ui.toast="";ui.toast_left=0
			await _shot(language+"-camp-%dx%d" % [dimension.x,dimension.y])
			var gold_before: int=run.s.gold
			await _click("ShopBuy0")
			_check(run.s.gold==gold_before-6,"real purchase debit "+language+str(dimension))
			_check(not run.in_location("inventory").is_empty(),"purchase enters inventory")
			if run.in_location("inventory").is_empty(): continue
			var fish_id: String=str(run.in_location("inventory")[0].id)
			await _click("Fish"+fish_id);_no_meal()
			await _click("EquipTargetC010")
			_check(run.item(fish_id).location=="equipped","real equip click "+language+str(dimension))
			await _click("ShopTools")
			_check(ui.modal_kind=="shop_tools","shop tools modal opens")
			_check(_node("ShopOrder")!=null and _node("ShopAutoMerge")!=null,"folded shop systems remain available")
			var auto_before: bool=bool(run.shop_status().auto_merge)
			await _click("ShopAutoMerge")
			_check(bool(run.shop_status().auto_merge)!=auto_before,"folded auto merge still works")
			await _click("CampTools")
			_check(ui.modal_kind=="toys","home toy collection remains available")
			ui._restore_phase();await _wait()
			await _click("CampaignJournal")
			_check(ui.modal_kind=="journal","journal remains available")
			ui._restore_phase();await _wait()
			await _click("HomeUpgrade")
			_check(int(run.s.hq)==2,"explicit HQ upgrade works")
			_rig();await _wait();await _click("Start")
			_check(run.s.phase in ["combat","cleanup"],"real departure works")
			_no_meal()
	for count: int in [1,2,3,5]:
		Locale.set_language("ja",false);get_window().size=Vector2i(1280,720)
		_rig(count);await _wait()
		if count==5:
			for index: int in range(20): run.create_item("F%02d" % (index%10+1),index%3,1,6,"inventory")
			run.s.chapter_events.used=[];run.s.stage=4;run.s.settled=[0,1,2,3];ui.show_prep();await _wait()
			_check(ui.modal_kind.is_empty(),"optional chapter stall does not interrupt camp")
			_check(_node("ChapterEvent")!=null,"chapter stall remains accessible")
			await _shot("ja-camp-full-team-inventory")
			await _click("ChapterEvent")
			_check(ui.modal_kind=="chapter_event","optional chapter stall still opens")
			ui._restore_phase();await _wait()
			await _click("ShopTools");await _shot("ja-shop-tools")
			ui._restore_phase();await _wait()
		ui.dispatch("start");await _wait()
		ui.combat_dashboard.tick(.3)
		for _frame: int in range(360): run.step(1.0/60.0)
		_consume_events();ui.combat_dashboard.tick(.3);await _wait()
		_check(ui.combat_dashboard.rows.size()==count,"dashboard has only active cats "+str(count))
		var previous_end: float=20
		for index: int in range(count):
			var row: Dictionary=ui.combat_dashboard.rows[str(index)]
			_check(not str(row.cat).is_empty() and row.has("dps") and row.has("button"),"DPS and skill retained "+str(count)+":"+str(index))
			_check(not str(row.dps.text).contains("—") and float(row.meter.value)>0,"actual battle updates DPS and skill progress "+str(count)+":"+str(index))
			_check(row.panel.position.x>=previous_end-.1,"dashboard cards do not overlap")
			_check(Rect2(Vector2.ZERO,row.panel.size).encloses(row.button.get_rect()),"skill stays inside card")
			previous_end=row.panel.get_rect().end.x
		_check(is_equal_approx(previous_end,1260),"dashboard fills removed meal space "+str(count))
		_no_meal();ui.toast="";ui.toast_left=0;await _wait();await _shot("ja-battle-%d-cats" % count)
	Locale.set_language(original_language,false)
	var report: Dictionary={"checks":checks,"failures":failures,"captures":captures,"automated":true,"player_save_access":false}
	var file: FileAccess=FileAccess.open(OUT+"/ui-contract.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "));file.close()
	print("V041_UI ",JSON.stringify(report));get_tree().quit(0 if failures.is_empty() else 1)
