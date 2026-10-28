extends Control
## Spotlight holes retain native target clicks; the surrounding dim pieces stop input.
const Progress=preload("res://scripts/run_guide.gd")
const Paper=preload("res://scripts/collage_theme.gd")
const COPY: Dictionary={
	"cat":["点击喜欢的猫咪，\n一起去找月亮。","好きなネコをクリック。\n一緒に月を探しに行こう。"],
	"starter_fish":["点击一份鱼干，\n喂给刚选的猫咪。","干し魚を1つクリック。\n選んだネコに装備しよう。"],
	"shop":["点击价格，买一条鱼干。","値段をクリックして、\n干し魚を1つ買おう。"],
	"inventory":["点击刚买的鱼干，\n准备给猫咪装备。","買った干し魚をクリック。\nネコに装備しよう。"],
	"equip":["点击亮起的鱼槽，\n把鱼干装上。","光るスロットをクリック。\n干し魚を装備しよう。"],
	"upgrade":["点击升级大本营！\n解锁猫位，再选一位伙伴。","拠点をレベルアップ！\n仲間をもう1匹迎えよう。"],
	"recruit":["两只新伙伴，点击选一只！\n它会立刻加入队伍。","新しい仲間を1匹選ぼう！\nすぐにチームに加わるよ。"],
	"start":["准备好了，点击出门！","準備ができたら、出発！"],
	"skill":["战斗已暂停。点击发光猫咪！\n每只猫每场可用一次大招。","戦闘は一時停止中。\n光るネコをクリックで必殺技！"]}
var ui: Control
var card: Panel
var message: Label
var close_button: Button
var step_id: String=""
var target_cat: String=""
var target_item: String=""
var target_slot: int=-1
var allowed_shop_slots: Array[int]=[]
var target_rects: Array[Rect2]=[]
var dim_rects: Array[Rect2]=[]
var dim_pieces: Array[ColorRect]=[]
var bubble_rect: Rect2=Rect2()
var selection_dismissed: bool=false
var refresh_left: float=0
var pulse: float=0
var announced: Dictionary={}
var last_run_seed: int=-1

func setup(owner_ui: Control) -> void:
	ui=owner_ui
	name="RunGuide"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	z_index=90
	card=Panel.new();card.name="GuidePaper"
	card.add_theme_stylebox_override("panel",Paper.box("strip",Color("fff0c8"),8))
	card.mouse_filter=Control.MOUSE_FILTER_STOP
	add_child(card)
	message=Label.new();message.name="GuideMessage"
	message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	message.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	message.add_theme_font_size_override("font_size",22)
	message.add_theme_color_override("font_color",Color("392b20"))
	message.mouse_filter=Control.MOUSE_FILTER_IGNORE
	card.add_child(message)
	close_button=Button.new();close_button.name="DismissRunGuide"
	close_button.add_theme_font_size_override("font_size",17)
	for surface: String in ["normal","hover","pressed","disabled"]: close_button.add_theme_stylebox_override(surface,Paper.box("button",Color("ead8b3"),3))
	close_button.add_theme_stylebox_override("focus",Paper.focus())
	close_button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	close_button.pressed.connect(dismiss)
	card.add_child(close_button)
	hide()

func begin_selection() -> void:
	selection_dismissed=false
	announced.clear();last_run_seed=-1
	refresh_left=0
	clear_hint()

func begin_run(keep_selection: bool=false) -> void:
	if not keep_selection: selection_dismissed=false
	announced.clear();last_run_seed=-1;refresh_left=0
	clear_hint()

func dismiss() -> void:
	selection_dismissed=true
	if not ui.controller.menu_open and not ui.run.s.is_empty():
		Progress.ensure(ui.run.s).dismissed=true
		if not ui.controller.ui_test_mode: ui.run.save(ui.run.save_path)
	clear_hint()

func clear_hint() -> void:
	step_id="";target_cat="";target_item="";target_slot=-1
	target_rects.clear();dim_rects.clear();allowed_shop_slots.clear()
	for piece: ColorRect in dim_pieces: piece.hide()
	hide();queue_redraw()

func _suspended() -> bool:
	return not bool(ui.controller.settings.get("guidance",true)) or not ui.modal_kind.is_empty() or ui.room_selection_busy or ui.front_transition_busy or float(ui.controller.presentation_hold)>0

func _active() -> bool:
	return visible and not step_id.is_empty() and not _suspended() and not selection_dismissed and (ui.controller.menu_open or not bool(ui.run.s.get("paused",false)))

## The controller must consult this before invoking any gameplay command.
func blocks_action(action: String,args: Dictionary={}) -> bool:
	if not _active(): return false
	match step_id:
		"starter_fish": return action!="choose_fish"
		"shop": return action!="shop_buy" or int(args.get("slot",-1)) not in allowed_shop_slots
		"inventory": return action!="equip" or str(args.get("id",""))!=target_item
		"equip": return action!="equip" or str(args.get("id",""))!=target_item or str(args.get("cat",""))!=target_cat or int(args.get("slot",-1))!=target_slot
		"upgrade": return action!="upgrade"
		"recruit": return action!="recruit" or str(args.get("cat","")) not in ui._recruit_choices()
		"start": return action!="start"
		"skill": return action!="cat_skill" or str(args.get("cat",""))!=target_cat
	return true

## Pause simulation without setting run.paused, which belongs to the pause menu.
func holds_combat() -> bool:
	return _active() and step_id=="skill" and ui.run.s.get("phase","") in ["combat","cleanup"] and not Progress.completed(ui.run.s,"skill")

func blocks_world_point(point: Vector2) -> bool:
	if not _active(): return false
	var local_point: Vector2=get_global_transform().affine_inverse()*point
	for rect: Rect2 in target_rects:
		if rect.has_point(local_point): return false
	return true

## Esc skips guidance. Modal navigation, pause and fullscreen remain available.
func blocks_shortcut(event: InputEvent) -> bool:
	if not _active() or not event is InputEventKey or not event.pressed or event.echo: return false
	if event.keycode==KEY_ESCAPE:
		dismiss();return true
	return event.keycode in [KEY_R,KEY_U,KEY_B,KEY_ENTER,KEY_KP_ENTER]

func tick(delta: float) -> void:
	pulse+=delta
	refresh_left-=delta
	# Check modal/pause every frame so a stale mask cannot cover a newly opened dialog.
	if _suspended(): clear_hint();return
	if visible: _hide_competing_hints()
	if ui.scene_mode in ["menu","story"]: clear_hint();return
	if ui.controller.menu_open:
		if ui.initial_room_open and not selection_dismissed:
			_present("cat",_controls("ChooseC*"),Vector2(420,60))
		else: clear_hint()
		return
	if ui.run.s.is_empty(): clear_hint();return
	if bool(ui.run.s.get("paused",false)) or bool(ui.run.s.get("battle",{}).get("cinematic",{}).get("active",false)):
		clear_hint();return
	if refresh_left>0:
		if visible and not bool(ui.controller.settings.get("reduced",false)): queue_redraw()
		return
	refresh_left=.05
	var seed_value: int=int(ui.run.s.get("seed",0))
	if seed_value!=last_run_seed:
		last_run_seed=seed_value;announced.clear()
	var progress: Dictionary=Progress.ensure(ui.run.s)
	if selection_dismissed: progress.dismissed=true
	if bool(progress.dismissed): clear_hint();return
	match str(ui.run.s.get("phase","")):
		"initial_fish": _present("starter_fish",_controls("ChooseFish*"),Vector2(450,90))
		"prep": _prep()
		"combat","cleanup": _battle()
		_: clear_hint()

func _controls(pattern: String) -> Array[Rect2]:
	var result: Array[Rect2]=[]
	var inverse: Transform2D=get_global_transform().affine_inverse()
	for node: Node in ui.find_children(pattern,"BaseButton",true,false):
		var button: BaseButton=node as BaseButton
		if button.is_visible_in_tree() and not button.disabled: result.append(inverse*button.get_global_rect())
	return result

func _control(key: String) -> Array[Rect2]:
	return _controls(key)

func _valid_slot(item: Dictionary) -> Dictionary:
	for cat: String in ui.run.s.get("active",[]):
		var equipped: Array=ui.run.equipped(cat)
		for existing: Dictionary in equipped:
			if not existing.is_empty() and str(existing.kind)==str(item.kind): return {"cat":cat,"slot":int(existing.slot)}
		for index: int in range(equipped.size()):
			if equipped[index].is_empty(): return {"cat":cat,"slot":index}
	if not ui.run.s.get("active",[]).is_empty(): return {"cat":str(ui.run.s.active[0]),"slot":0}
	return {}

func _prep() -> void:
	var state: Dictionary=ui.run.s
	if not ui._recruit_choices().is_empty():
		if not Progress.completed(state,"recruit"): _present("recruit",_controls("Recruit*"),Vector2(440,360))
		else: clear_hint()
		return
	if not Progress.completed(state,"equip"):
		if not ui.equip_id.is_empty():
			var item: Dictionary=ui.run.item(ui.equip_id)
			var slot: Dictionary=_valid_slot(item) if not item.is_empty() else {}
			if not slot.is_empty():
				target_item=ui.equip_id;target_cat=str(slot.cat);target_slot=int(slot.slot)
				_present("equip",_control("EquipTarget"+str(slot.cat)+str(slot.slot)),Vector2(660,110))
				return
		for item: Dictionary in state.get("items",{}).values():
			if str(item.get("location","")) in ["inventory","inbox"] and not bool(item.get("reserved",false)):
				var rects: Array[Rect2]=_control("Fish"+str(item.id))
				if not rects.is_empty():
					target_item=str(item.id)
					_present("inventory",rects,Vector2(660,110));return
	if not Progress.completed(state,"shop"):
		var choices: Array[Rect2]=_controls("ShopBuy*")
		if not choices.is_empty():
			allowed_shop_slots.clear()
			for index: int in range(5):
				if not _control("ShopBuy%d" % index).is_empty(): allowed_shop_slots.append(index)
			_present("shop",choices,Vector2(660,110));return
	if not Progress.completed(state,"upgrade") and int(state.get("hq",1))<5:
		# The button is disabled until affordable: never trap a low-gold player.
		var upgrade: Array[Rect2]=_control("HomeUpgrade")
		if not upgrade.is_empty():
			_present("upgrade",upgrade,Vector2(800,106));return
	if not Progress.completed(state,"start"):
		_present("start",_control("Start"),Vector2(660,110));return
	clear_hint()

func _battle() -> void:
	var state: Dictionary=ui.run.s
	if not Progress.completed(state,"skill") and float(state.get("meal",{}).get("flight_left",0))<=0:
		for cat: String in state.get("active",[]):
			var skill: Dictionary=ui.run.combat.skill_status(cat)
			if bool(skill.get("ready",false)) and not bool(skill.get("used",false)):
				var index: int=state.active.find(cat)
				var center: Vector2=ui.controller.courtyard.cat_position(index)
				target_cat=cat
				var targets: Array[Rect2]=[get_global_transform().affine_inverse()*Rect2(center-Vector2(52,53),Vector2(104,106))]
				targets.append_array(_control("SkillHUD"+cat))
				_present("skill",targets,Vector2(375,132))
				return
	clear_hint()

func _bounds() -> Rect2:
	return Rect2(Vector2.ZERO,size if size.x>0 and size.y>0 else get_viewport_rect().size)

func _present(key: String,rects: Array[Rect2],position_hint: Vector2) -> void:
	var bounds: Rect2=_bounds()
	var clipped: Array[Rect2]=[]
	for rect: Rect2 in rects:
		var safe: Rect2=rect.intersection(bounds)
		if safe.size.x>1 and safe.size.y>1: clipped.append(safe)
	if clipped.is_empty(): clear_hint();return
	step_id=key
	if key not in ["skill","equip"]: target_cat=""
	if key not in ["equip","inventory"]: target_item="";target_slot=-1
	target_rects=clipped
	var card_size: Vector2=Vector2(minf(394,bounds.size.x-24),112)
	bubble_rect=_place_card(card_size,position_hint,bounds)
	if bubble_rect.size==Vector2.ZERO:
		# A fully obstructed/tiny viewport must remain usable; skip is never off-screen.
		clear_hint();return
	card.position=bubble_rect.position;card.size=bubble_rect.size
	message.position=Vector2(18,7);message.size=Vector2(card_size.x-36,64)
	close_button.position=Vector2(card_size.x-112,75);close_button.size=Vector2(96,29)
	var japanese: bool=not TranslationServer.get_locale().begins_with("zh")
	message.text=str(COPY[key][1 if japanese else 0])
	close_button.text="スキップ" if japanese else "跳过"
	close_button.tooltip_text="この冒険のガイドを閉じる（Esc）" if japanese else "跳过本局引导（Esc）"
	_build_mask(bounds)
	_hide_competing_hints()
	show();queue_redraw()
	if not announced.has(key):
		announced[key]=true
		if key!="skill" and is_instance_valid(ui.controller.audio): ui.controller.audio.event({"type":"tutorial_hint"})

func _hide_competing_hints() -> void:
	ui._hide_hint()
	if is_instance_valid(ui.cat_card): ui._close_cat_card()

func _place_card(card_size: Vector2,preferred: Vector2,bounds: Rect2) -> Rect2:
	if card_size.x<210 or bounds.size.y<card_size.y+24: return Rect2()
	var candidates: Array[Vector2]=[preferred]
	for rect: Rect2 in target_rects:
		candidates.append(Vector2(rect.get_center().x-card_size.x*.5,rect.position.y-card_size.y-28))
		candidates.append(Vector2(rect.get_center().x-card_size.x*.5,rect.end.y+28))
	for y: float in [12.0,bounds.size.y-card_size.y-12,(bounds.size.y-card_size.y)*.5]:
		for x: float in [12.0,(bounds.size.x-card_size.x)*.5,bounds.size.x-card_size.x-12]: candidates.append(Vector2(x,y))
	for candidate: Vector2 in candidates:
		var frame: Rect2=Rect2(Vector2(clampf(candidate.x,12,bounds.size.x-card_size.x-12),clampf(candidate.y,12,bounds.size.y-card_size.y-12)),card_size)
		var intersects: bool=false
		for target: Rect2 in target_rects:
			if frame.intersects(target.grow(14)): intersects=true;break
		if not intersects: return frame
	return Rect2()

func _build_mask(bounds: Rect2) -> void:
	dim_rects.assign([bounds])
	for target: Rect2 in target_rects:
		var hole: Rect2=target.grow(7).intersection(bounds)
		var next: Array[Rect2]=[]
		for region: Rect2 in dim_rects:
			var cut: Rect2=region.intersection(hole)
			if cut.size.x<=0 or cut.size.y<=0:
				next.append(region);continue
			for piece: Rect2 in [Rect2(region.position,Vector2(region.size.x,cut.position.y-region.position.y)),Rect2(Vector2(region.position.x,cut.end.y),Vector2(region.size.x,region.end.y-cut.end.y)),Rect2(Vector2(region.position.x,cut.position.y),Vector2(cut.position.x-region.position.x,cut.size.y)),Rect2(Vector2(cut.end.x,cut.position.y),Vector2(region.end.x-cut.end.x,cut.size.y))]:
				if piece.size.x>0 and piece.size.y>0: next.append(piece)
		dim_rects=next
	while dim_pieces.size()<dim_rects.size():
		var piece: ColorRect=ColorRect.new()
		piece.name="GuideDim%d" % dim_pieces.size()
		piece.color=Color.TRANSPARENT
		piece.mouse_filter=Control.MOUSE_FILTER_STOP
		add_child(piece);move_child(piece,0)
		dim_pieces.append(piece)
	for index: int in range(dim_pieces.size()):
		var piece: ColorRect=dim_pieces[index]
		piece.visible=index<dim_rects.size()
		if piece.visible: piece.position=dim_rects[index].position;piece.size=dim_rects[index].size
	move_child(card,get_child_count()-1)

func _draw() -> void:
	if not visible: return
	for region: Rect2 in dim_rects: draw_rect(region,Color(.035,.025,.055,.72),true)
	var reduced: bool=bool(ui.controller.settings.get("reduced",false))
	var glow: float=1.0 if reduced else .83+.17*sin(pulse*3.0)
	for rect: Rect2 in target_rects:
		var frame: Rect2=rect.grow(4)
		draw_rect(frame,Color("4a352b"),false,7)
		draw_rect(frame,Color(1,.86,.40,glow),false,4)
		draw_rect(rect,Color(1,.89,.52,.06),true)
	if not target_rects.is_empty():
		var rect: Rect2=target_rects[0]
		var above: bool=rect.position.y>38
		var p: Vector2=Vector2(rect.get_center().x,rect.position.y-15 if above else rect.end.y+15)
		var direction: float=1.0 if above else -1.0
		draw_colored_polygon(PackedVector2Array([p+Vector2(-13,-10*direction),p+Vector2(13,-10*direction),p+Vector2(0,7*direction)]),Color("4a352b"))
		draw_colored_polygon(PackedVector2Array([p+Vector2(-9,-8*direction),p+Vector2(9,-8*direction),p+Vector2(0,4*direction)]),Color("ffdb72"))
