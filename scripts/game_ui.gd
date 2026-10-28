extends Control
## Scene-based home / battle interface. Every transaction still goes through Main.
const Data = preload("res://scripts/catalog.gd")
const GameLocale = preload("res://scripts/game_locale.gd")
const Artwork = preload("res://scripts/ui_artwork.gd")
const Painted = preload("res://scripts/painted_vfx.gd")
const CatPresentation = preload("res://scripts/cat_presentation.gd")
const Parchment = preload("res://scripts/collage_theme.gd")
const ExpansionArt = preload("res://scripts/expansion_art.gd")
const CatStats = preload("res://scripts/cat_stat_chip.gd")
const Journey = preload("res://scripts/journey_map.gd")
const Hint = preload("res://scripts/anchored_tooltip.gd")
const FishArt = preload("res://scripts/fish_art.gd")
const FrontMenu = preload("res://scripts/front_menu.gd")
const ComicPrologue = preload("res://scripts/comic_prologue.gd")
const InkTransition = preload("res://scripts/front_ink_transition.gd")
const BuildAdvisor = preload("res://scripts/build_advisor.gd")
const FeedbackReceipt = preload("res://scripts/feedback_receipt.gd")
const Campaign = preload("res://scripts/campaign_presentation.gd")
const ShopAdvisor=preload("res://scripts/shop_advisor.gd")
const PracticeDisplay = preload("res://scripts/practice_display.gd")
const Memento = preload("res://scripts/campaign_memento.gd")
const CampShopView = preload("res://scripts/camp_shop_view.gd")
const CombatDashboard = preload("res://scripts/combat_dashboard.gd")
const INK: Color = Color("211f25")
const PAPER: Color = Color("f5eedb")
const CORAL: Color = Color("a55f42")
const TEAL: Color = Color("8d9060")
const GOLD: Color = Color("b68a43")
var controller: Node
var run: RefCounted
var top: Control
var bottom: Control
var overlay: Control
var scene_layer: Control
var equip_layer: Control
var cat_card: Control
var dock_content: Control
var home_inventory: Control
var hud: Label
var progress: ProgressBar
var boss: Label
var status: Label
var cast_button: Button
var pause_button: Button
var speed_button: Button
var toy_button: Button
var stat_chips: Dictionary={}
var mode_button: Button
var basket_button: Button
var basket_view: Control
var upgrade_button: Button
var modal_kind: String = ""
var scene_mode: String = "menu"
var dock_kind: String = "closed"
var inspect_id: String = ""
var equip_id: String = ""
var reserve_id: String = ""
var selected_cat: String = ""
var toast: String = ""
var toast_left: float = 0
var serial: int = 0
var boss_plate: Panel
var boss_bar: ProgressBar
var boss_shield: Label
var boss_phase_label: Label
var boss_tell_label: Label
var boss_tell_bar: ProgressBar
var hp_bar: ProgressBar
var shield_label: Label
var stage_label: Label
var clock_label: Label
var gold_label: Label
var catch_card: Panel
var catch_title: Label
var catch_meta: Label
var catch_keep: Button
var catch_sell: Button
var shown_fish: String = ""
var status_plate: Panel
var odds_labels: Array[Label] = []
var dock_signature: String = ""
var dock_refresh: float = 0.0
var slot_rects: Dictionary = {}
var home_details: bool = false
var fish_hint: PanelContainer
var cat_hover_only: bool=false
var sale_busy: bool=false
var cat_dps: Label
var cat_status_label: Label
var room_actors: Dictionary = {}
var room_ui: Control
var room_selection_busy: bool = false
var room_selection_token: int = 0
var selected_room_actor: Control
var initial_room_open: bool = false
var room_auto_focus: bool = false
var room_actor_rects: Dictionary = {}
var front_menu: Control
var story_view: Control
var front_transition_busy: bool = false
var front_click: AudioStreamPlayer
var practice_display: Control
var practice_result: Dictionary={}
var highlight_strip: Control
var equipment_feedback: Control
var practice_attack_seen: Dictionary={}
var practice_previous_time: float=-1
var difficulty_label: Label
var difficulty_choice: String="easy"
var compact_reading: bool=false
var last_window_size: Vector2i=Vector2i.ZERO
var prep_focus_cat: String=""
var prep_focus_slot: int=0
var practice_recent_changed: bool=false
var prep_focus_bar: Control
var journal_tab: String="journey"
var journal_page: int=0
var journal_category: int=0
var journal_selected: String=""
var event_fish: String=""
var event_give: String=""
var event_take: String=""
var camp_shop: Control
var combat_dashboard: Control

class FishDragButton extends Button:
	var owner_ui: Control
	var item_id: String=""
	var target_cat: String=""
	var target_slot: int=-1
	func _get_drag_data(_at_position: Vector2) -> Variant:
		if owner_ui.run.s.get("phase","")!="prep": return null
		var item: Dictionary=owner_ui.run.item(item_id)
		if item.is_empty() or bool(item.get("reserved",false)) or str(item.get("location","")) not in ["inventory","inbox"]: return null
		var preview: TextureRect=TextureRect.new()
		preview.texture=FishArt.texture(str(item.kind))
		preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.custom_minimum_size=Vector2(82,72);preview.size=Vector2(82,72)
		set_drag_preview(preview)
		owner_ui._hide_hint()
		return {"fish_id":item_id}
	func _can_drop_data(_at_position: Vector2,data: Variant) -> bool:
		return owner_ui.run.s.get("phase","")=="prep" and not target_cat.is_empty() and data is Dictionary and data.has("fish_id")
	func _drop_data(_at_position: Vector2,data: Variant) -> void:
		owner_ui.dispatch("equip",{"id":str(data.fish_id),"cat":target_cat,"slot":target_slot})

class RewardTreePreview extends Node2D:
	var state: Dictionary={}
	func _draw() -> void:
		preload("res://scripts/story_scenery.gd").draw_tree(self)
		preload("res://scripts/cat_mutations.gd").draw_tree(self,state,0,true)


func setup(main_controller: Node, run_model: RefCounted) -> void:
	theme = Parchment.build(preload("res://theme/main.tres"))
	controller = main_controller
	run = run_model
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	front_click = AudioStreamPlayer.new()
	front_click.stream = preload("res://audio/free-v040/ui_click.wav")
	add_child(front_click)
	_build_hud()
	fish_hint=Hint.new()
	add_child(fish_hint)
	show_menu()

func _button(parent: Node, text: String, callable: Callable, key: String = "", disabled: bool = false) -> Button:
	var button: Button = Button.new()
	serial += 1
	button.name = key if not key.is_empty() else "Button%d" % serial
	button.text = text
	button.disabled = disabled
	button.custom_minimum_size.y = 40
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size",19)
	parent.add_child(button)
	button.pressed.connect(callable)
	button.pressed.connect(_front_sound)
	button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	return button

func _label(parent: Node, text: String, font_size: int = 18) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",maxi(19,font_size) if compact_reading else font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func _vbox(parent: Node) -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	return box

func _hbox(parent: Node) -> HBoxContainer:
	var box: HBoxContainer = HBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	return box

func _style(fill: Color = PAPER, _radius: int = 14, margin: float = 12) -> StyleBox:
	return Parchment.box("panel",Parchment.tint_for(fill),margin)

func _plate(parent: Node, rect: Rect2, key: String, fill: Color = PAPER) -> Panel:
	var panel: Panel = Panel.new()
	panel.name = key
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel",Parchment.box("strip" if rect.size.y<80 else "panel",Parchment.tint_for(fill),8))
	parent.add_child(panel)
	return panel

func _at_label(parent: Node, text: String, rect: Rect2, font_size: int = 18) -> Label:
	var label: Label = _label(parent,text,font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _art(parent: Node, motif: String, rect: Rect2, color: Color = CORAL) -> Control:
	var art: Control = Artwork.new()
	art.motif = motif
	art.color = color
	art.position = rect.position
	art.size = rect.size
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(art)
	return art

func _accent(button: Button, fill: Color) -> void:
	var leather: bool=fill==CORAL
	var surface: String="leather" if leather else "button"
	var tint: Color=Color.WHITE if leather else Parchment.tint_for(fill)
	button.add_theme_stylebox_override("normal",Parchment.box(surface,tint,8))
	button.add_theme_stylebox_override("hover",Parchment.box(surface,tint.lightened(.12),8))
	button.add_theme_stylebox_override("pressed",Parchment.box(surface,tint.darkened(.12),8))
	button.add_theme_stylebox_override("disabled",Parchment.box(surface,Color("ded2bd"),8))
	button.add_theme_stylebox_override("focus",Parchment.focus())
	if leather:
		for key: String in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: button.add_theme_color_override(key,INK)

func _at_button(parent: Node, text: String, rect: Rect2, callable: Callable, key: String, fill: Color = PAPER) -> Button:
	var button: Button = _button(parent,text,callable,key)
	button.position = rect.position
	button.size = rect.size
	_accent(button,fill)
	button.custom_minimum_size.y = rect.size.y
	if rect.size.y<42:
		button.add_theme_font_size_override("font_size",15)
		for style_name: String in ["normal","hover","pressed","disabled"]:
			var compact: StyleBox = button.get_theme_stylebox(style_name).duplicate() as StyleBox
			compact.content_margin_top = 4
			compact.content_margin_bottom = 4
			button.add_theme_stylebox_override(style_name,compact)
	button.size = rect.size
	return button

func _meter(parent: Node, rect: Rect2, fill: Color) -> ProgressBar:
	var bar: ProgressBar=ProgressBar.new()
	bar.position=rect.position
	bar.size=rect.size
	bar.show_percentage=false
	bar.add_theme_font_size_override("font_size",1)
	bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	for key: String in ["background","fill"]:
		var style: StyleBoxFlat=StyleBoxFlat.new()
		style.bg_color=Color("4a4442") if key=="background" else fill
		style.set_corner_radius_all(2)
		style.border_color=Color("242126")
		style.set_border_width_all(1 if key=="background" else 0)
		bar.add_theme_stylebox_override(key,style)
	parent.add_child(bar)
	# Assign after style/font overrides: Control retains its former minimum size.
	bar.size=rect.size
	return bar

func _info_button(parent: Node, rect: Rect2, callable: Callable, key: String) -> Button:
	var button: Button = _at_button(parent,"i",rect,callable,key)
	for style_name: String in ["normal","hover","pressed","disabled","focus"]:
		button.add_theme_stylebox_override(style_name,Parchment.box("rivet",Color("ffe1a7") if style_name=="hover" else Color.WHITE,0))
	button.custom_minimum_size = rect.size
	button.add_theme_font_size_override("font_size",20 if rect.size.x>30 else 17)
	button.size = rect.size
	return button

func notify(message: String) -> void:
	toast = message
	toast_left = 2.5

func _modal(title: String, kind: String, width: float = 1060, height: float = 440) -> VBoxContainer:
	_hide_hint()
	_close_cat_card()
	close_modal()
	modal_kind = kind
	overlay = Control.new()
	overlay.name = "Overlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.gui_input.connect(_on_backdrop)
	var center: CenterContainer = CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 106
	center.offset_bottom = -171
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	overlay.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(width,minf(height,432))
	panel.add_theme_stylebox_override("panel",_style(Color("fff7e8fa"),18,28))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)
	var column: VBoxContainer = _vbox(panel)
	column.name = "Content"
	column.add_theme_constant_override("separation",8)
	var heading: HBoxContainer = _hbox(column)
	var title_label: Label = _label(heading,title,25)
	title_label.theme_type_variation = "TitleLabel"
	if kind not in ["menu","visit","pause","confirm"]:
		_button(heading,"关闭",_request_close,"Close").size_flags_horizontal = Control.SIZE_SHRINK_END
	return column

func _on_backdrop(_event: InputEvent) -> void:
	pass

func _sticker_card(parent: Node, fill: Color = Color("fcf0da")) -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel",_style(fill,13,10))
	parent.add_child(panel)
	var column: VBoxContainer = _vbox(panel)
	column.add_theme_constant_override("separation",5)
	return column

func show_confirm(title: String, body: String, action: Callable, cancel: Callable = close_modal) -> void:
	var col: VBoxContainer = _modal(title,"confirm",760,300)
	_label(col,body,20)
	var line: HBoxContainer = _hbox(col)
	var token: int = overlay.get_instance_id()
	_button(line,"确认",func() -> void: _accept_confirmation(token,action),"Confirm")
	_button(line,"取消",cancel,"Cancel")
	_focus_first()

func _accept_confirmation(token: int, action: Callable) -> void:
	if not is_instance_valid(overlay) or overlay.get_instance_id()!=token: return
	close_modal()
	action.call()

func _skill_icon(parent: Node, key: String, icon_size: Vector2) -> TextureRect:
	var icon: TextureRect = TextureRect.new()
	icon.name = "SkillIcon"+key
	icon.texture = Painted.texture(key)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = icon_size
	icon.size = icon_size
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)
	return icon

func _badge(parent: Node, quality: int, kind: String = "F01", icon_size: Vector2 = Vector2(100,70)) -> void:
	var badge: PanelContainer = PanelContainer.new()
	badge.name = "FishSkill"+kind
	badge.custom_minimum_size = icon_size
	badge.add_theme_stylebox_override("panel",_style([Color("f7ebd7"),Color("dbebed"),Color("f6e1aa")][clampi(quality,0,2)],10,3))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(badge)
	_skill_icon(badge,kind,icon_size-Vector2(6,6))

func _portrait(parent: Node, id: String, icon_size: Vector2 = Vector2(100,80), preview: bool = false) -> Control:
	var portrait: Control = Artwork.new()
	portrait.name = "CatPortrait"+id
	portrait.motif = "cat"
	portrait.cat_id = id
	portrait.color = Color(str(Data.cats()[id].color))
	portrait.custom_minimum_size = icon_size
	portrait.preview_enabled = preview and not bool(controller.settings.get("reduced",false))
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(portrait)
	return portrait

func _scroll(parent: Node, height: float) -> VBoxContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size.y = height
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	return _vbox(scroll)

func show_pause() -> void:
	var col: VBoxContainer = _modal("小院暂停中", "pause",610,290)
	_label(col,"战斗和绝招演出已暂停。",22)
	_button(col,"继续守家 [空格]",func() -> void: controller.toggle_pause(),"ResumePause")
	_button(col,"声音与效果",show_settings,"PauseSettings")
	_button(col,"保存并回到标题",func() -> void: controller.to_menu(),"SaveMenu")
	_focus_first()

func show_settings() -> void:
	var col: VBoxContainer = _modal("声音与效果", "settings",650,500)
	var language_row: HBoxContainer=_hbox(col)
	_label(language_row,"语言 / Language",20)
	var language: OptionButton=OptionButton.new()
	language.name="LanguageChoice"
	language.add_item("日本語",0);language.add_item("简体中文",1)
	language.selected=0 if GameLocale.current_language()=="ja" else 1
	language.custom_minimum_size=Vector2(260,38)
	language.add_theme_font_size_override("font_size",20)
	language_row.add_child(language)
	language.item_selected.connect(func(index: int) -> void:
		GameLocale.set_language("ja" if index==0 else "zh_CN",not controller.ui_test_mode)
		call_deferred("show_settings"))
	for category: String in ["music","sfx"]:
		_label(col,"音乐音量" if category=="music" else "音效音量",20)
		var slider: HSlider = HSlider.new()
		slider.name = "MusicVolume" if category=="music" else "SfxVolume"
		slider.min_value = 0
		slider.max_value = 1
		slider.step = .05
		slider.value = controller.settings.get(category,.45)
		slider.custom_minimum_size.y = 30
		col.add_child(slider)
		slider.value_changed.connect(func(value: float) -> void: controller.set_setting(category,value))
	var checkbox: CheckButton = CheckButton.new()
	checkbox.name = "ReducedEffects"
	checkbox.text = "减少动态效果（保留状态和伤害提示）"
	checkbox.button_pressed = controller.settings.get("reduced",false)
	col.add_child(checkbox)
	checkbox.toggled.connect(func(value: bool) -> void: controller.set_setting("reduced",value))
	var guidance: CheckButton=CheckButton.new()
	guidance.name="GuidanceEnabled"
	guidance.text="每局显示简洁操作引导"
	guidance.button_pressed=bool(controller.settings.get("guidance",true))
	col.add_child(guidance)
	guidance.toggled.connect(func(value: bool) -> void: controller.set_setting("guidance",value))
	_button(col,"返回",_restore_phase,"BackSettings")
	_focus_first()

func show_summary() -> void:
	var won: bool = run.s.phase=="victory"
	var col: VBoxContainer = _modal("把月亮送回天上！" if won else "月亮还在滚筒里", "summary",1020,420)
	(col.get_parent() as PanelContainer).add_theme_stylebox_override("panel",_style(PAPER,18,40))
	var stats: Dictionary = run.s.stats
	_label(col,"%s · 猫咪都平安 · 到达%d-%d" % ["洗衣机断电，日用品恢复正常 · %d段旅程完成" % Data.total_stages() if won else "先回家吃鱼，明晚再去拆洗衣机",floori(float(run.s.stage)/4)+1,int(run.s.stage)%4+1],22)
	if not won: _build_failure_receipt(col)
	var list: VBoxContainer = _scroll(col,145 if not won else 235)
	var contents: String = "击杀 %d · 购买 %d条 · 未用鱼干 %d份\n收入：击杀%d / 补贴%d / 回收%d金币\n支出：买鱼%d / 刷新%d / 猫爬架%d金币 · 剩余%d金币\n敌人来袭伤害 %.1f / 护盾吸收 %.1f / 耐久实际损失 %.1f" % [int(stats.get("kills",0)),int(stats.get("shop_bought",0)),run.in_location("basket").size()+run.in_location("inventory").size()+run.in_location("inbox").size()+(1 if run.s.pending!="" else 0),int(stats.kill_gold),int(stats.bonus_gold),int(stats.sell_gold),int(stats.fish_spend),int(stats.get("shop_refresh_spend",0)),int(stats.hq_spend),int(run.s.gold),float(stats.incoming),float(stats.absorbed),float(stats.lost_hp)]+"\n\n"
	for id: String in run.s.owned:
		contents += "%s：主攻击 %.1f · 附加效果 %.1f" % [Data.cats()[id].name,float(stats.primary.get(id,0)),float(stats.extra.get(id,0))]+"\n"
	for enemy_id: String in stats.get("hp_loss_by_enemy",{}).keys():
		contents += "%s：来袭 %.1f · 实际耐久损失 %.1f" % [Data.enemies().get(enemy_id,{"name":enemy_id}).name,float(stats.get("incoming_by_enemy",{}).get(enemy_id,0)),float(stats.hp_loss_by_enemy[enemy_id])]+"\n"
	for stage_index: int in range(int(run.s.stage)+1):
		var spent: int = 0
		for entry: Dictionary in run.s.ledger:
			if int(entry.stage)==stage_index and entry.category in ["fish_spend","shop_refresh_spend"]: spent += absi(int(entry.amount))
		contents += "%d-%d 鱼摊实际支出 %d金币" % [floori(stage_index/4.0)+1,stage_index%4+1,spent]+"\n"
	_label(list,contents,18)
	_button(col,"回到标题",func() -> void: controller.to_menu(),"SummaryMenu")
	_focus_first()

func _build_hud() -> void:
	compact_reading=get_window().size.x<1120
	last_window_size=get_window().size
	top = Control.new()
	top.name = "HUD"
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 88
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	var home: Panel = _plate(top,Rect2(18,14,220,60),"HomeIsland",Color("fff7e8ee"))
	_art(home,"paw",Rect2(8,13,35,35))
	hud = _at_label(home,"Lv.1",Rect2(49,12,60,22),16)
	shield_label = _at_label(home,"300 / 300",Rect2(105,12,106,23),14)
	hp_bar = _meter(home,Rect2(49,38,158,10),CORAL)
	var timeline_paper: Panel=_plate(top,Rect2(384,12,430,68),"TimelinePaper")
	timeline_paper.mouse_filter=Control.MOUSE_FILTER_IGNORE
	stage_label=_at_label(timeline_paper,"1-1",Rect2(24,20,57,29),19)
	progress=_meter(timeline_paper,Rect2(88,36,272,7),TEAL)
	progress.max_value=4
	for i: int in range(4):
		var stamp: Label=_at_label(timeline_paper,["●","★","●","◉"][i],Rect2(78+i*88,12,24,24),18)
		stamp.add_theme_color_override("font_color",CORAL if i==3 else INK)
	clock_label=_at_label(timeline_paper,"",Rect2(248,45,152,16),12)
	clock_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	speed_button=_at_button(top,"1×",Rect2(920,14,76,54),func() -> void: dispatch("combat_speed"),"CombatSpeed")
	_bind_hint(speed_button,"战斗速度","点击切换",["1× / 1.5× / 2×","只加速战斗，音乐保持原速。"])
	mode_button=_at_button(top,"◎ 自动",Rect2(1002,14,126,54),_toggle_mode,"AttackMode",TEAL)
	_bind_hint(mode_button,"瞄准方式","自动 / 手动",["自动：按各猫的近敌／对空／威胁分工。","手动：拖动准星，射程内猫咪集火。"])
	pause_button=_at_button(top,"Ⅱ",Rect2(1134,14,54,54),func() -> void: controller.toggle_pause(),"Pause")
	_at_button(top,"⚙",Rect2(1194,14,54,54),show_settings,"Settings")
	difficulty_label=_at_label(top,"简单",Rect2(827,24,83,30),19)
	difficulty_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	difficulty_label.add_theme_stylebox_override("normal",_thin_paper(Color("d9e0c4")))
	difficulty_label.mouse_filter=Control.MOUSE_FILTER_PASS
	difficulty_label.mouse_entered.connect(func() -> void:
		var profile: Dictionary=Campaign.profile(str(run.s.get("difficulty","easy")))
		fish_hint.present(difficulty_label,difficulty_label.get_global_rect(),str(profile.name),"本局固定 · 不随装备偷偷变化",[str(profile.description)] as Array[String],null,Rect2(0,0,1280,548)))
	difficulty_label.mouse_exited.connect(func() -> void: fish_hint.close_from(difficulty_label))
	toy_button=_at_button(top,"玩具 0",Rect2(22,80,102,31),show_toys,"TreeToys")
	_bind_hint(toy_button,"猫爬架玩具","全队共享 · 不限数量",["精英三选一，首领四选一。","点击查看；重复获得会叠加。"])
	boss_plate = _plate(top,Rect2(438,87,382,114),"BossIsland",Color("fff7e8e8"))
	boss = _at_label(boss_plate,"",Rect2(18,23,143,25),18)
	boss_bar = _meter(boss_plate,Rect2(18,51,277,9),CORAL)
	boss_shield = _at_label(boss_plate,"",Rect2(303,44,62,25),16)
	boss_phase_label=_at_label(boss_plate,"",Rect2(164,23,201,25),16)
	boss_phase_label.name="BossPhaseLabel"
	boss_tell_label=_at_label(boss_plate,"",Rect2(18,69,347,26),19)
	boss_tell_label.name="BossTellLabel"
	boss_tell_bar=_meter(boss_plate,Rect2(18,98,347,4),GOLD)
	bottom = Control.new()
	bottom.name = "Actions"
	bottom.position = Vector2(0,548)
	bottom.size = Vector2(1280,172)
	bottom.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bottom)
	combat_dashboard=CombatDashboard.new()
	bottom.add_child(combat_dashboard)
	# setup occurs when a run is present, not while the title screen is empty.
	dock_content=Control.new()
	dock_content.name="UnusedLegacyDock"
	dock_content.hide()
	bottom.add_child(dock_content)
	status_plate = _plate(self,Rect2(510,505,260,29),"StatusRibbon",Color("fff7e8e8"))
	status_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status = _at_label(status_plate,"",Rect2(8,2,244,25),14)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_plate.hide()

func update(delta: float) -> void:
	if get_window().size!=last_window_size:
		last_window_size=get_window().size
		var small: bool=last_window_size.x<1120
		if compact_reading!=small:
			compact_reading=small
			call_deferred("_apply_reading_size")
	for actor: Control in room_actors.values():
		if is_instance_valid(actor) and actor.get("reduced")!=null:
			actor.set("reduced",bool(controller.settings.get("reduced",false)))
			actor.set("paused",not controller.menu_open and bool(run.s.get("paused",false)))
	_update_practice()
	toast_left = maxf(0,toast_left-delta)
	status.text = toast
	status_plate.position=Vector2(510,88 if scene_mode=="home" else 505)
	status_plate.visible = toast_left>0 and modal_kind.is_empty() and scene_mode not in ["menu","story"]
	if controller.menu_open or run.s.is_empty():
		top.hide()
		bottom.hide()
		return
	top.visible = scene_mode=="battle"
	bottom.visible = scene_mode=="battle"
	if scene_mode!="battle": return
	_update_cat_hover()
	var s: Dictionary = run.s
	var stage: Dictionary = Data.stages()[int(s.stage)]
	var battle: Dictionary = s.battle
	var time: float = float(battle.get("time",0))
	hud.text = "Lv.%d" % int(s.hq)
	hp_bar.max_value = float(s.max_hp)
	hp_bar.value = float(s.hp)
	shield_label.text = "%d / %d" % [ceili(s.hp),int(s.max_hp)]
	progress.value = float(int(s.stage)%4)+clampf(time/float(stage.duration),0,1)
	stage_label.text = "%d-%d" % [int(stage.chapter),int(stage.get("encounter",int(s.stage)%4+1))]
	clock_label.text = "%02d:%02d · %s" % [floori(time/60),int(time)%60,str(stage.period)]
	speed_button.text=str(float(s.get("combat_speed",1.0)))+"×"
	speed_button.disabled=bool(s.paused)
	toy_button.text="玩具 %d" % s.get("toys",{}).size()
	if is_instance_valid(combat_dashboard): combat_dashboard.tick(delta)
	var cinema: bool=bool(battle.get("cinematic",{}).get("active",false))
	for child: Control in top.get_children(): child.visible=not cinema or child==pause_button
	bottom.visible=not cinema
	if cinema:
		_hide_hint()
		_close_cat_card()
		status_plate.hide()
	pause_button.text = "▷" if bool(s.paused) else "Ⅱ"
	if is_instance_valid(difficulty_label): difficulty_label.text=str(Campaign.profile(str(s.get("difficulty","easy"))).name)
	mode_button.text = "◎ 手动" if str(s.get("attack_mode","auto"))=="manual" else "◎ 自动"
	mode_button.disabled = bool(s.paused)
	var boss_state: Dictionary = {}
	for enemy: Dictionary in battle.get("enemies",[]):
		if not bool(enemy.get("dead",false)) and (str(enemy.kind).begins_with("B") or str(enemy.kind).begins_with("X")): boss_state=enemy
	boss_plate.visible = not cinema and not boss_state.is_empty() and modal_kind.is_empty()
	if not boss_state.is_empty():
		boss.text = str(Data.enemies()[boss_state.kind].name)
		boss_bar.max_value = float(boss_state.max_hp)
		boss_bar.value = float(boss_state.hp)
		boss_shield.text = "%d" % ceili(float(boss_state.hp))
		var giant: bool=str(boss_state.kind).begins_with("B")
		boss_plate.size.y=114 if giant else 84
		boss_phase_label.visible=giant;boss_tell_label.visible=giant;boss_tell_bar.visible=giant
		if giant:
			var display: Dictionary=preload("res://scripts/boss_encounter.gd").status(boss_state)
			boss_phase_label.text="%s · %s" % ["Ⅰ" if int(display.phase)==1 else "Ⅱ",str(display.phase_name).get_slice(" · ",0)]
			var acting: bool=str(display.state) in ["windup","flight","transition"]
			boss_tell_label.text=str(display.tell) if not str(display.tell).is_empty() else ("清理增援，等待破绽" if int(display.phase)==1 else "直击大本营 · 留意下一击")
			if str(display.state) in ["windup","flight"]: boss_tell_label.text+="  %.1fs" % maxf(0,float(display.left))
			boss_tell_label.add_theme_color_override("font_color",Color("a84734") if acting else Color("64604c"))
			boss_tell_bar.visible=acting
			boss_tell_bar.value=float(display.progress)*100.0
	if is_instance_valid(cat_dps) and not selected_cat.is_empty(): cat_dps.text = "普攻 DPS %.1f" % _cat_dps(selected_cat)
	if is_instance_valid(cat_status_label) and not selected_cat.is_empty(): cat_status_label.text=_cat_status_text(selected_cat)
	dock_refresh -= delta
	if dock_refresh<=0:
		dock_refresh=.15
		var signature: String = _dock_state_signature()
		if signature!=dock_signature:
			dock_signature=signature
			_build_dock()

func _clear(node: Node) -> void:
	if not is_instance_valid(node): return
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _remove(node: Node) -> void:
	if not is_instance_valid(node): return
	if node.get_parent()!=null: node.get_parent().remove_child(node)
	node.queue_free()

func _scene(kind: String, background_path: String) -> Control:
	_hide_hint()
	room_selection_token+=1
	room_selection_busy=false
	initial_room_open=false
	practice_display=null
	practice_attack_seen.clear()
	practice_previous_time=-1
	highlight_strip=null
	equipment_feedback=null
	room_actors.clear()
	room_actor_rects.clear()
	stat_chips.clear()
	selected_room_actor=null
	room_ui=null
	front_menu=null
	story_view=null
	close_modal()
	_remove(equip_layer)
	_remove(cat_card)
	_remove(scene_layer)
	equip_layer=null
	cat_card=null
	cat_dps=null
	equip_id=""
	scene_mode=kind
	scene_layer=Control.new()
	scene_layer.name="FullScene"
	scene_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scene_layer.mouse_filter=Control.MOUSE_FILTER_STOP
	add_child(scene_layer)
	move_child(scene_layer,0)
	var wash: ColorRect=ColorRect.new()
	wash.color=Color("d4c0a6")
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter=Control.MOUSE_FILTER_IGNORE
	scene_layer.add_child(wash)
	if not background_path.is_empty() and ResourceLoader.exists(background_path):
		var backdrop: TextureRect=TextureRect.new()
		backdrop.name="SceneArtwork"
		backdrop.texture=load(background_path) as Texture2D
		backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		backdrop.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		backdrop.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
		backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE
		scene_layer.add_child(backdrop)
	top.hide()
	bottom.hide()
	return scene_layer

func show_menu() -> void:
	var page: Control = _scene("menu","")
	front_menu = FrontMenu.new()
	page.add_child(front_menu)
	front_menu.setup(controller.has_save(),bool(controller.settings.reduced))
	front_menu.action_requested.connect(_front_action)

func _front_action(action: String) -> void:
	if front_transition_busy or not modal_kind.is_empty(): return
	_front_sound()
	match action:
		"NewGame": show_difficulty()
		"Resume": _transition_to(controller.resume_game)
		"ReplayStory": controller.replay_story()
		"MenuSettings": show_settings()
		"ExitGame": controller.request_exit()

func _front_sound() -> void:
	var volume: float = float(controller.settings.sfx)
	if volume <= 0: return
	front_click.volume_db = linear_to_db(volume * 0.5)
	front_click.play()

func _transition_to(change_scene: Callable) -> void:
	if front_transition_busy: return
	front_transition_busy = true
	var transition: Control = InkTransition.new()
	transition.name = "FrontTransition"
	add_child(transition)
	transition.finished.connect(func() -> void:
		front_transition_busy = false
		transition.queue_free()
	)
	transition.start(change_scene,bool(controller.settings.reduced))

func show_story(replay: bool = false) -> void:
	var page: Control = _scene("story","")
	story_view = ComicPrologue.new()
	page.add_child(story_view)
	story_view.setup(replay,bool(controller.settings.reduced))
	story_view.interacted.connect(_front_sound)
	story_view.finished.connect(func() -> void:
		if replay: _transition_to(show_menu)
		else: controller._finish_prologue()
	)
	story_view.cancelled.connect(func() -> void: _transition_to(show_menu))

func handle_front_input(event: InputEvent) -> bool:
	if not modal_kind.is_empty(): return false
	if scene_mode == "story" and is_instance_valid(story_view):
		return story_view.handle_key(event)
	return false

func show_battle() -> void:
	if scene_mode=="battle":
		return
	close_modal()
	_remove(cat_card)
	cat_card=null
	cat_dps=null
	cat_status_label=null
	selected_cat=""
	_remove(scene_layer)
	_remove(equip_layer)
	scene_layer=null
	room_actors.clear()
	room_actor_rects.clear()
	stat_chips.clear()
	selected_room_actor=null
	room_ui=null
	initial_room_open=false
	room_selection_busy=false
	equip_layer=null
	equip_id=""
	scene_mode="battle"
	dock_kind="closed"
	top.show()
	bottom.show()
	dock_signature=""
	if is_instance_valid(combat_dashboard): combat_dashboard.queue_free()
	combat_dashboard=CombatDashboard.new()
	bottom.add_child(combat_dashboard)
	combat_dashboard.setup(self)

func _home_header(page: Control, title_text: String) -> void:
	var paper: Panel=_plate(page,Rect2(28,19,338,56),"HomeHeading")
	paper.add_theme_stylebox_override("panel",_thin_paper())
	paper.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var title: Label = _at_label(paper,title_text,Rect2(26,10,294,36),26)
	title.theme_type_variation="TitleLabel"
	_at_button(page,"⚙",Rect2(1205,22,46,40),show_settings,"HomeSettings")

func show_initial() -> void:
	if not initial_room_open and is_instance_valid(controller.guide): controller.guide.begin_selection()
	var page: Control = _scene("home",_room_background())
	initial_room_open=true
	room_ui=_room_ui_layer(page)
	_home_header(room_ui,"谁陪你去找月亮？")
	var placements: Array[Rect2] = [Rect2(73,290,213,213),Rect2(318,348,225,225),Rect2(963,193,190,190),Rect2(741,346,225,225),Rect2(513,179,205,205),Rect2(1068,420,170,170)]
	for i: int in range(6):
		var id: String="C%02d" % (i+1)
		_add_room_cat(page,id,placements[i])
		_room_hotspot(room_ui,id,placements[i],func() -> void: _choose_room_cat(id),"Choose"+id)
	page.move_child(room_ui,page.get_child_count()-1)
	_focus_room_default()

func _focus_room_default() -> void:
	room_auto_focus=true
	_focus_first()
	room_auto_focus=false

func _choice_cat(parent: Control, id: String, rect: Rect2, action: Callable, key: String) -> void:
	_add_room_cat(parent,id,rect)
	_room_hotspot(parent,id,rect,action,key)

func show_initial_fish() -> void:
	var id: String = str(run.s.initial_cat)
	var page: Control
	if initial_room_open and is_instance_valid(scene_layer) and is_instance_valid(selected_room_actor):
		page=scene_layer
		_clear(room_ui)
	else:
		page=_scene("home",_room_background())
		room_ui=_room_ui_layer(page)
		for cat_id: String in Data.cats():
			_add_room_cat(page,cat_id,_dinner_cat_rect(cat_id,id))
		selected_room_actor=room_actors[id]
		page.move_child(room_ui,page.get_child_count()-1)
	initial_room_open=true
	room_selection_busy=false
	_home_header(room_ui,"吃饱，去找月亮")
	for cat_id: String in Data.cats():
		var actor_rect: Rect2=_dinner_cat_rect(cat_id,id)
		room_actor_rects[cat_id]=actor_rect
		var actor: Control=room_actors[cat_id]
		actor.position=actor_rect.position
		actor.size=actor_rect.size
		_room_hotspot(room_ui,cat_id,actor_rect,func() -> void: _switch_room_cat(cat_id),"Switch"+cat_id)
	var choices: Array = run.s.get("initial_fish_choices",[])
	for i: int in range(choices.size()):
		var kind: String=str(choices[i])
		var center: float=360+i*280
		_container_picture(room_ui,i,Rect2(center-115,445,230,187))
		var fish: Control=_fish_static(room_ui,{"kind":kind,"quality":0,"level":1},Rect2(center-70,440,140,128))
		fish.name="StarterFishArt"+kind
		var target: Button=_transparent_button(room_ui,Rect2(center-116,427,232,195),func() -> void: _choose_room_fish(kind,fish),"ChooseFish"+kind)
		_bind_fish_hint(target,{"kind":kind,"quality":0,"level":1,"paid_basis":0},id)
		if kind in Data.cats()[id].favorites:
			var heart: Label=_at_label(room_ui,"♥",Rect2(center+61,441,29,29),23)
			heart.add_theme_color_override("font_color",CORAL)
			heart.add_theme_color_override("font_outline_color",PAPER)
			heart.add_theme_constant_override("outline_size",4)
		var caption: Label=_at_label(room_ui,_fish_tag(kind),Rect2(center-76,625,153,30),19)
		caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_stylebox_override("normal",Parchment.box("strip",Color.WHITE,3))
		_info_button(room_ui,Rect2(center+92,630,23,23),func() -> void: _starter_fish_details(kind,id),"StarterFishInfo"+kind)
	room_ui.modulate.a=0
	create_tween().tween_property(room_ui,"modulate:a",1.0,.3)
	_focus_room_default()

func show_prep() -> void:
	if run.s.get("phase","")!="prep": return
	if scene_mode!="home": home_details=false
	var page: Control = _scene("home",_room_background())
	_home_header(page,"整装，去找月亮")
	slot_rects.clear()
	var gold: Panel = _plate(page,Rect2(704,25,120,48),"HomeGold",Color("fff7e8e8"))
	_art(gold,"paw",Rect2(8,6,32,32),GOLD)
	_at_label(gold,str(run.s.gold),Rect2(44,7,68,32),23)
	var max_hq: bool=int(run.s.hq)>=5
	var hq: Panel=_plate(page,Rect2(840,19,344,82),"HomeHQ")
	hq.add_theme_stylebox_override("panel",_thin_paper(Color("e9d5a8")))
	var level: Label=_at_label(hq,("大本营 Lv.%d · 已满级" % int(run.s.hq)) if max_hq else ("大本营 Lv.%d → %d" % [int(run.s.hq),int(run.s.hq)+1]),Rect2(12,3,320,29),20)
	level.name="HomeHQLevel"
	var upgrade: Button=_at_button(hq,"已满级" if max_hq else "升级 · %d 金币" % int(Data.hq(int(run.s.hq)+1).cost),Rect2(12,34,320,39),func() -> void: dispatch("upgrade"),"HomeUpgrade",GOLD)
	upgrade.disabled=max_hq or not _recruit_choices().is_empty() or (not max_hq and int(run.s.gold)<int(Data.hq(int(run.s.hq)+1).cost))
	_bind_hint(upgrade,"大本营升级","增加位置与耐久",["升级后迎来两只猫，挑一只加入。"] as Array[String])
	var active: Array=run.s.active
	if prep_focus_cat not in active and not active.is_empty(): prep_focus_cat=str(active[0]);prep_focus_slot=0
	var placements: Array=_home_placements(active.size())
	for i: int in range(active.size()):
		var id: String=str(active[i])
		var rect: Rect2=placements[i]
		_add_room_cat(page,id,rect)
		var hotspot: Button=_room_hotspot(page,id,rect,func() -> void: _click_home_cat(id),"HomeCat"+id)
		if not reserve_id.is_empty(): hotspot.modulate=TEAL
		_add_capability_badges(page,id,rect)
		var center: float=rect.get_center().x
		var slots: Array=run.equipped(id)
		for j: int in range(3):
			var slot_rect: Rect2=Rect2(center-89+j*61,rect.end.y+28,55,55)
			slot_rects[id+":"+str(j)]=slot_rect
			var target: Button=_fish_tile(page,slots[j],slot_rect,func() -> void: _focus_cat_slot(id,j),"Slot"+id+str(j),false)
			target.target_cat=id;target.target_slot=j
	var reserves: Array=[]
	for id: String in run.s.owned:
		if id not in active: reserves.append(id)
	for i: int in range(reserves.size()):
		var id: String=str(reserves[i])
		var reserve_rect: Rect2=Rect2(1160,75+i*84,78,78)
		_add_room_cat(page,id,reserve_rect)
		var target: Button=_room_hotspot(page,id,reserve_rect,func() -> void: _select_reserve(id),"Reserve"+id)
		if reserve_id==id: target.modulate=TEAL
		_at_label(page,"↔",Rect2(1210,reserve_rect.end.y-11,30,29),22)
	_build_next_threat(page)
	var start: Button=_at_button(page,"出门  →",Rect2(1033,374,216,48),request_start,"Start",CORAL)
	start.add_theme_font_size_override("font_size",27)
	start.add_theme_stylebox_override("normal",Parchment.box("button",Color("f3b877"),7))
	start.add_theme_color_override("font_color",Color("4d2b20"))
	_build_encounter_choice(page)
	start.disabled=not _recruit_choices().is_empty()
	home_inventory=Control.new()
	home_inventory.name="HomeInventory"
	home_inventory.position=Vector2(20,560)
	home_inventory.size=Vector2(1240,145)
	page.add_child(home_inventory)
	_build_home_inventory()
	camp_shop=CampShopView.new()
	page.add_child(camp_shop)
	camp_shop.setup(self)
	page.move_child(home_inventory,page.get_child_count()-1)
	var toys: Button=_at_button(page,"玩具",Rect2(390,25,134,44),show_toys,"CampTools")
	toys.add_theme_stylebox_override("normal",_thin_paper(Color("dfd7c0")))
	toys.add_theme_font_size_override("font_size",18)
	_build_campaign_entry(page)
	_build_practice(page)
	practice_display.scale=Vector2(.75,.75)
	practice_display.position=Vector2(305,46)
	practice_display.hide()
	_build_feedback_medals(page,Vector2(26,102))
	_build_stage_contribution(page)
	_build_risk_receipt(page,Rect2(715,151,283,32))
	_build_prep_focus_bar(page)
	_apply_prep_focus()
	_build_chapter_event_entry(page)
	_apply_reading_size()
	_focus_first()

func _click_home_cat(id: String) -> void:
	if not reserve_id.is_empty():
		var cats: Array=run.s.active.duplicate()
		cats[cats.find(id)]=reserve_id
		reserve_id=""
		dispatch("active",{"cats":cats})
	else:
		prep_focus_cat=id
		prep_focus_slot=_preferred_fish_slot(id)
		show_cat(id)
		_apply_prep_focus()

func _select_reserve(id: String) -> void:
	if run.s.active.size()<int(Data.hq(run.s.applied_hq).slots):
		var cats: Array=run.s.active.duplicate()
		cats.append(id)
		dispatch("active",{"cats":cats})
	else:
		reserve_id="" if reserve_id==id else id
		show_prep()
		if not reserve_id.is_empty(): notify("点一只猫咪交换位置")

func show_visit() -> void:
	var page: Control=_scene("home",_room_background())
	_home_header(page,"门口来了新朋友")
	for i: int in range(run.s.visitors.size()):
		var id: String=str(run.s.visitors[i])
		var rect: Rect2=Rect2(214+i*310,244+(i%2)*52,235,235)
		_choice_cat(page,id,rect,func() -> void: _recruit_room_cat(id),"Recruit"+id)
		for j: int in range(Data.cats()[id].favorites.size()):
			_fish_static(page,{"kind":Data.cats()[id].favorites[j],"quality":0,"level":1},Rect2(rect.position.x+72+j*48,rect.end.y+36,43,39),false)
	_focus_first()

func _fish_static(parent: Node, value: Dictionary, rect: Rect2, level: bool = true, hover: bool = true) -> Control:
	var icon: Control=_art(parent,"fish",rect)
	icon.kind=str(value.get("kind","F01"))
	icon.quality=int(value.get("quality",0))
	if hover: _bind_fish_hint(icon,value,str(value.get("cat","")))
	if level:
		var label: Label=_at_label(parent,str(int(value.get("level",1))),Rect2(rect.end.x-26,rect.end.y-29,25,25),19 if compact_reading else 17)
		label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_stylebox_override("normal",Parchment.box("rivet",Color.WHITE,0))
	return icon

func _fish_tile(parent: Node, value: Dictionary, rect: Rect2, action: Callable, key: String, selected: bool = false) -> Button:
	var fill: Color=Color("fff7e8dc") if value.is_empty() else [Color("f7eddb"),Color("d9ecf0"),Color("f4df9e")][int(value.quality)]
	var tile: FishDragButton=FishDragButton.new()
	tile.owner_ui=self;tile.item_id=str(value.get("id",""))
	tile.name=key;tile.position=rect.position;tile.size=rect.size
	tile.custom_minimum_size.y=rect.size.y
	tile.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	parent.add_child(tile)
	tile.pressed.connect(action);tile.pressed.connect(_front_sound)
	_accent(tile,TEAL if selected else fill)
	for style_name: String in ["normal","hover","pressed","disabled"]:
		var tint: Color=Color("f4d188") if selected else Parchment.tint_for(fill)
		if style_name=="hover": tint=tint.lightened(.15)
		if style_name=="disabled": tint=Color("9c8a71")
		tile.add_theme_stylebox_override(style_name,Parchment.box("slot",tint,2))
	if selected:
		var mark: Label=_at_label(tile,"•",Rect2(1,-7,18,20),22)
		mark.add_theme_color_override("font_color",CORAL)
	if value.is_empty():
		var mark: Label=_at_label(tile,"+",Rect2(0,7,rect.size.x,rect.size.y-10),31)
		mark.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		mark.modulate=Color("958b7f88")
	else:
		_fish_static(tile,value,Rect2(3,3,rect.size.x-6,rect.size.y-6),true,false)
		_bind_fish_hint(tile,value,str(value.get("cat","")))
		_bind_fish_sale(tile,str(value.get("id","")))
	return tile

func _loose_fish() -> Array:
	var values: Array=run.in_location("inventory")+run.in_location("inbox")+run.in_location("basket")
	values.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		if str(a.kind)!=str(b.kind): return str(a.kind)<str(b.kind)
		if int(a.quality)!=int(b.quality): return int(a.quality)>int(b.quality)
		if bool(a.get("reserved",false))!=bool(b.get("reserved",false)): return not bool(a.get("reserved",false))
		if int(a.level)!=int(b.level): return int(a.level)>int(b.level)
		return str(a.id)<str(b.id))
	return values

func _inventory_grid(parent: Node, rect: Rect2, columns: int, home: bool) -> void:
	var scroll: ScrollContainer=ScrollContainer.new()
	scroll.name="FishGridScroll"
	scroll.position=rect.position
	scroll.size=rect.size
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var grid: GridContainer=GridContainer.new()
	grid.columns=columns
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",7)
	scroll.add_child(grid)
	var values: Array=_loose_fish()
	for value: Dictionary in values:
		var tile: Button=_fish_tile(grid,value,Rect2(0,0,65,65),func() -> void: _inventory_click(str(value.id),home),"Fish"+str(value.id),inspect_id==str(value.id))
		tile.custom_minimum_size=Vector2(65,65)
		if home: _decorate_focus_fish(tile,value)
	if values.is_empty():
		var empty: Label=_label(grid,"⌁",32)
		empty.custom_minimum_size=Vector2(90,60)

func _refresh_inventory(home: bool) -> void:
	if home: _build_home_inventory()
	else: dock_kind="basket"; _build_dock()

func _build_home_inventory() -> void:
	if not is_instance_valid(home_inventory): return
	_clear(home_inventory)
	home_inventory.position=Vector2(20,610)
	home_inventory.size=Vector2(1240,101)
	if not _recruit_choices().is_empty():
		home_inventory.position=Vector2(20,560)
		_build_recruit_dock(home_inventory,Rect2(0,0,1240,145),true)
		return
	var count: int=_loose_fish().size()
	var plate: Panel=_plate(home_inventory,Rect2(0,0,1240,98),"InventoryTray")
	plate.add_theme_stylebox_override("panel",_inventory_paper())
	_art(plate,"basket",Rect2(5,5,70,58))
	_at_label(plate,"%d / %d" % [count,int(run.s.hq)*5],Rect2(5,69,78,23),18).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	if count>0: _inventory_grid(plate,Rect2(85,11,1045,77),14,true)
	else: _at_label(plate,"点鱼盘购买 · 拖到猫咪鱼槽装备",Rect2(105,34,1000,32),22)
	_add_merge_all(plate,Rect2(1145,15,83,68))

func _dock_state_signature() -> String:
	if run.s.is_empty(): return ""
	var s: Dictionary=run.s
	return "%s:%s:%s:%s:%s:%s:%s" % [hash(s.items),s.pending,float(s.cast_left)>0,dock_kind,inspect_id,s.paused,hash(_recruit_choices())]

func _build_dock() -> void:
	if scene_mode=="battle": return
	if not is_instance_valid(dock_content) or run.s.is_empty(): return
	dock_signature=_dock_state_signature()
	_clear(dock_content)
	catch_card=null
	shown_fish=""
	if not _recruit_choices().is_empty():
		basket_button.hide()
		_build_recruit_dock(dock_content,Rect2(0,0,908,119),false)
		return
	if dock_kind=="toys":
		basket_button.hide()
		_build_toy_shelf(dock_content,Rect2(0,0,850,116),true)
		_at_button(dock_content,"×",Rect2(861,4,35,32),show_toys,"CloseToys")
		return
	var pending: Dictionary=run.item(str(run.s.pending))
	var pending_ready: bool=not pending.is_empty() and float(run.s.cast_left)<=0
	basket_button.visible=dock_kind=="closed" and not pending_ready
	if pending_ready and dock_kind in ["closed","catch_detail"]:
		shown_fish=str(pending.id)
		catch_card=_plate(dock_content,Rect2(89,5,460,106),"CatchCard")
		_fish_static(catch_card,pending,Rect2(19,2,118,101))
		_info_button(catch_card,Rect2(133,13,25,25),show_catch_details,"CatchInfo")
		_at_label(catch_card,_fish_intent(pending),Rect2(170,4,280,29),19)
		catch_keep=_at_button(catch_card,"入篓",Rect2(185,39,112,54),func() -> void: _catch_action("keep"),"KeepCatch")
		catch_sell=_at_button(catch_card,"卖 +%d" % floori(float(pending.paid_basis)/2),Rect2(311,39,125,54),func() -> void: _catch_action("sell"),"SellCatch")
		catch_keep.disabled=bool(run.s.paused)
		catch_sell.disabled=bool(run.s.paused)

		return
	if dock_kind=="closed": return
	var plate: Panel=_plate(dock_content,Rect2(0,0,908,119),"DockTray",Color("fff7e8f5"))
	_at_button(plate,"×",Rect2(860,7,36,32),func() -> void: dock_kind="closed"; _build_dock(),"CloseDock")
	if dock_kind=="hq":
		_build_hq_details(plate)
		return
	_inventory_grid(plate,Rect2(12,9,621,101),8,false)
	_add_merge_all(plate,Rect2(840,65,61,45))
	_build_fish_actions(plate,Vector2(648,9),false)

func _build_fish_actions(parent: Node, pos: Vector2, home: bool) -> void:
	var value: Dictionary=run.item(inspect_id)
	var icon_rect: Rect2=Rect2(pos.x,pos.y,68,68)
	if not value.is_empty():
		var selected_icon: Control=_fish_static(parent,value,icon_rect)
		selected_icon.name="SelectedFishIcon"
	var paused: bool=bool(run.s.get("paused",false))
	if _can_sell(value):
		var sell: Button=_at_button(parent,"卖 +%d" % floori(float(value.get("paid_basis",0))/2),Rect2(pos.x,pos.y+76,68,25),func() -> void: _sell_fish(str(value.id)),"SellFish")
		_style_small_action(sell)
	var details: Button=_at_button(parent,"详细",Rect2(pos.x+80,pos.y,82,29),_show_selected_hint,"FishDetails")
	details.disabled=value.is_empty()
	var merge: Button=_at_button(parent,"合成",Rect2(pos.x+80,pos.y+36,82,29),func() -> void: _merge_selected(),"MergeSelected",GOLD)
	merge.disabled=value.is_empty() or matching(value).is_empty() or paused
	var equip: Button=_at_button(parent,"取下" if str(value.get("location",""))=="equipped" else "装备",Rect2(pos.x+80,pos.y+72,82,29),_equip_action,"Equip",TEAL)
	equip.disabled=value.is_empty() or not home or run.s.phase!="prep" or paused
	for action_button: Button in [details,merge,equip]:
		_style_small_action(action_button)

func _thin_paper(tint: Color=Color.WHITE) -> StyleBox:
	return Parchment.box("strip",tint,2)

func _inventory_paper() -> StyleBox:
	var paper: StyleBoxTexture=Parchment.box("strip",Color("dfd2ad"),12) as StyleBoxTexture
	if paper!=null:
		paper.set_texture_margin(SIDE_LEFT,26)
		paper.set_texture_margin(SIDE_RIGHT,26)
		paper.set_texture_margin(SIDE_TOP,11)
		paper.set_texture_margin(SIDE_BOTTOM,11)
	return paper

func _sheet_paper(tint: Color=Color.WHITE) -> StyleBox:
	return Parchment.box("panel",tint,24)

func _style_small_action(button: Button) -> void:
	# Compact actions need readable paper centers, not a frame taller than the text.
	for state: String in ["normal","hover","pressed","disabled"]:
		var tint: Color={"normal":Color.WHITE,"hover":Color("fff4d8"),"pressed":Color("e4c99e"),"disabled":Color("eee5d3")}[state]
		button.add_theme_stylebox_override(state,_thin_paper(tint))
	button.add_theme_font_size_override("font_size",16)
	for key: String in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: button.add_theme_color_override(key,INK)
	button.add_theme_color_override("font_disabled_color",Color("65513c"))


func _inline_text(parent: Node, text: String, rect: Rect2) -> void:
	var scroll: ScrollContainer=ScrollContainer.new()
	scroll.position=rect.position
	scroll.size=rect.size
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var label: Label=_label(scroll,text,16)
	label.custom_minimum_size.x=rect.size.x-20
	label.size_flags_horizontal=Control.SIZE_EXPAND_FILL


func _build_hq_details(parent: Node) -> void:
	var hq: Dictionary=Data.hq(int(run.s.hq))
	_at_label(parent,"Lv.%d" % int(run.s.hq),Rect2(17,10,86,27),22)
	_at_label(parent,"♥ %d    ♟ %d" % [int(hq.hp),int(hq.slots)],Rect2(17,48,181,30),20)
	var text: String="品质与鱼干等级分别抽取。每种鱼出现机会相同。\n升级立即增加位置与耐久，并迎来两只猫，挑一只加入。\n鱼干等级 1 / 2 / 3：%d%% / %d%% / %d%%" % [hq.levels[0],hq.levels[1],hq.levels[2]]
	_inline_text(parent,text,Rect2(210,9,619,101))

func show_basket() -> void:
	if run.s.get("phase","")!="prep": return
	if controller.menu_open or run.s.is_empty(): return
	if scene_mode=="home": home_details=false; _build_home_inventory(); return
	if not str(run.s.pending).is_empty() and float(run.s.cast_left)<=0:
		dispatch("keep")
	dock_kind="closed" if dock_kind=="basket" else "basket"
	_build_dock()

func show_help() -> void:
	show_hq()

func show_hq() -> void:
	if run.s.get("phase","")!="prep": return
	if controller.menu_open or run.s.is_empty(): return
	if scene_mode=="home":
		notify("Lv.%d · ♥ %d · %d 个位置" % [int(run.s.hq),int(Data.hq(int(run.s.hq)).hp),int(Data.hq(int(run.s.hq)).slots)])
		return
	dock_kind="closed" if dock_kind=="hq" else "hq"
	_build_dock()

func show_catch() -> void:
	pass

func _sync_catch() -> void:
	_build_dock()

func show_catch_details() -> void:
	var value: Dictionary=run.item(str(run.s.pending))
	if is_instance_valid(catch_card) and not value.is_empty(): _show_fish_hint(value,catch_card,"",true)

func _catch_action(action: String) -> void:
	if shown_fish.is_empty() or shown_fish!=str(run.s.get("pending","")) or bool(run.s.paused): return
	dispatch(action,{"id":shown_fish} if action=="sell" else {})
	dock_kind="closed"
	_build_dock()

func matching(value: Dictionary) -> Array:
	if value.is_empty() or bool(value.get("reserved",false)) or int(value.level)>=5: return []
	var locations: Array=["inventory","inbox","basket"]
	if run.s.phase=="prep": locations.append("equipped")
	return run.s.items.values().filter(func(other: Dictionary) -> bool: return not bool(other.get("reserved",false)) and other.id!=value.id and other.kind==value.kind and other.quality==value.quality and other.level==value.level and other.location in locations and (run.s.phase=="prep" or value.location!="equipped"))

func _merge_selected() -> void:
	var primary: Dictionary=run.item(inspect_id)
	var pairs: Array=matching(primary)
	if pairs.is_empty(): return
	# Prefer loose material, so a cat never loses a slot when loose duplicates exist.
	pairs.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.location=="equipped")<int(b.location=="equipped"))
	request_merge(primary,pairs[0])

func request_merge(primary: Dictionary, secondary: Dictionary) -> void:
	if primary.location=="equipped" or secondary.location=="equipped":
		show_confirm("合成这两份？","已装备的鱼干也会参与合成。",func() -> void: dispatch("merge",{"id":primary.id,"other":secondary.id,"confirm":true}),_restore_phase)
	else: dispatch("merge",{"id":primary.id,"other":secondary.id})

func show_inspect(id: String, cat_id: String = "", _slot: int = 0) -> void:
	if scene_mode=="battle":
		var value: Dictionary=run.item(id)
		if not value.is_empty(): _show_fish_hint(value,cat_card,cat_id,true)
		return
	if id.is_empty():
		if not cat_id.is_empty(): show_cat(cat_id)
		return
	inspect_id=id
	home_details=false
	if scene_mode=="home": _build_home_inventory()
	else: dock_kind="basket"; _build_dock()

func _begin_equip() -> void:
	_hide_hint()
	var value: Dictionary=run.item(inspect_id)
	if run.s.phase!="prep" or value.is_empty() or bool(value.get("reserved",false)) or value.location not in ["inventory","inbox"]: return
	_remove(cat_card)
	cat_card=null
	_remove(equip_layer)
	equip_id=inspect_id
	equip_layer=Control.new()
	equip_layer.name="EquipSpotlight"
	equip_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(equip_layer)
	var dim: ColorRect=ColorRect.new()
	dim.color=Color("211c2b60")
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	equip_layer.add_child(dim)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT: _cancel_equip())
	for key: String in slot_rects:
		var split: PackedStringArray=key.split(":")
		var cat: String=split[0]
		var slot: int=int(split[1])
		var valid: bool=true
		for existing: Dictionary in run.equipped(cat):
			if not existing.is_empty() and existing.kind==value.kind and int(existing.slot)!=slot: valid=false
		var button: Button=_fish_tile(equip_layer,run.equipped(cat)[slot],slot_rects[key],func() -> void: _place_equipment(cat,slot),"EquipTarget"+cat+str(slot),prep_focus_cat.is_empty() or cat==prep_focus_cat)
		button.disabled=not valid
		button.modulate=(Color.WHITE if prep_focus_cat.is_empty() or cat==prep_focus_cat else Color("e6dfd4b8")) if valid else Color("ffffff35")
	var chosen: Panel=_plate(equip_layer,Rect2(370,555,540,141),"EquipDecision")
	_fish_static(chosen,value,Rect2(10,10,90,90))
	_at_label(chosen,("给%s选鱼槽 · 也可改选别猫" % Data.cats()[prep_focus_cat].name) if not prep_focus_cat.is_empty() else "点猫咪下方的鱼槽，直接装备",Rect2(108,25,416,30),21)
	var sell: Button=_at_button(chosen,"卖 +%d" % floori(float(value.get("paid_basis",0))/2),Rect2(112,64,196,54),func() -> void: var item_id: String=equip_id; _cancel_equip(); _sell_fish(item_id),"EquipSell")
	sell.disabled=not _can_sell(value)
	var merge: Button=_at_button(chosen,"合成这一条",Rect2(320,64,204,54),func() -> void: _cancel_equip(); _merge_selected(),"EquipMerge",GOLD)
	merge.disabled=matching(value).is_empty()
	_at_button(equip_layer,"×",Rect2(1203,22,48,43),_cancel_equip,"CancelEquip")
	_focus_first()

func _place_equipment(cat: String, slot: int) -> void:
	prep_focus_cat=cat;prep_focus_slot=slot
	var id: String=equip_id
	_cancel_equip()
	dispatch("equip",{"id":id,"cat":cat,"slot":slot})

func _cancel_equip() -> void:
	_remove(equip_layer)
	equip_layer=null
	equip_id=""

func _cat_dps(id: String) -> float:
	var stats: Dictionary=_cat_stats(id)
	return float(stats.attack)*float(stats.rate)

func _cat_anchor(id: String) -> Rect2:
	if scene_mode=="home": return room_actor_rects.get(id,Rect2(480,230,220,220))
	if controller.get("courtyard")!=null:
		var index: int=run.s.get("active",[]).find(id)
		if index>=0:
			var point: Vector2=controller.courtyard.cat_position(index)
			return Rect2(point-Vector2(44,74),Vector2(88,84))
	return Rect2(245,150,50,80)

func _close_cat_card() -> void:
	_remove(cat_card)
	cat_card=null
	cat_dps=null
	selected_cat=""
	cat_hover_only=false

func show_cat(id: String) -> void:
	if id.is_empty() or not Data.cats().has(id): return
	if scene_mode=="home" and run.s.get("phase","")=="prep":
		prep_focus_cat=id
		_apply_prep_focus()
	if selected_cat==id and is_instance_valid(cat_card) and not cat_hover_only:
		_close_cat_card()
		return
	_build_cat_card(id,_cat_anchor(id),true)

func _show_cat_hover(id: String, source_rect: Rect2) -> void:
	if is_instance_valid(controller.guide) and controller.guide.visible: return
	if room_selection_busy or room_auto_focus or not modal_kind.is_empty() or is_instance_valid(equip_layer): return
	if is_instance_valid(cat_card) and not cat_hover_only: return
	if selected_cat==id and is_instance_valid(cat_card): return
	_build_cat_card(id,source_rect,false)

func _build_cat_card(id: String, source_rect: Rect2, interactive: bool) -> void:
	_close_cat_card()
	selected_cat=id
	cat_hover_only=not interactive
	if initial_room_open:
		_build_opening_cat_card(id,source_rect)
		return
	var bounds: Rect2=Hint.fit_rect(source_rect,Vector2(340,391 if interactive and scene_mode=="home" else (392 if scene_mode=="battle" else 251)),Rect2(0,80,1280,470))
	cat_card=_plate(self,bounds,"CatQuickCard")
	cat_card.add_theme_stylebox_override("panel",_sheet_paper())
	_at_label(cat_card,str(Data.cats()[id].name),Rect2(27,27,220,30),23)
	if interactive: _at_button(cat_card,"×",Rect2(278,22,48,44),_close_cat_card,"CloseCat")
	var slots: Array=run.equipped(id) if not controller.menu_open and not run.s.is_empty() and id in run.s.get("owned",[]) else [{},{},{}]
	if controller.menu_open:
		var role: Label=_label(cat_card,str(Data.cats()[id].role),16)
		role.position=Vector2(24,53)
		role.size=Vector2(232,62)
	else:
		for i: int in range(3):
			_fish_tile(cat_card,slots[i],Rect2(29+i*96,70,87,60),func() -> void: show_inspect(str(slots[i].get("id",""))),"CatFish"+str(i))
	_at_label(cat_card,"♥",Rect2(29,142,25,28),20).add_theme_color_override("font_color",CORAL)
	var favorite: String=str(Data.cats()[id].favorites[0])
	_fish_static(cat_card,{"kind":favorite,"quality":0,"level":1},Rect2(56,136,46,39),false)
	_at_label(cat_card,"+1",Rect2(104,144,29,23),15)
	cat_dps=_at_label(cat_card,"普攻 DPS %.1f" % _cat_dps(id),Rect2(160,144,155,24),15)
	var source_text: String=Campaign.cat_source_line(run.s,id) if scene_mode=="home" else _cat_status_text(id)
	cat_status_label=_at_label(cat_card,source_text,Rect2(29,178,282,190 if scene_mode=="battle" else 46),17)
	cat_status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	cat_status_label.clip_text=false
	cat_status_label.text_overrun_behavior=TextServer.OVERRUN_NO_TRIMMING
	_bind_hint(cat_status_label,"变身来自这里",str(Data.cats()[id].name),Campaign.cat_sources(run.s,id))
	if interactive and scene_mode=="home":
		var priorities: Dictionary=run.s.get("cat_priorities",{})
		var selected: String=str(priorities.get(id,"nearest"))
		_at_label(cat_card,"自动分工 · 合法射程内",Rect2(29,232,282,27),18)
		for i: int in range(3):
			var key: String=["nearest","air","threat"][i]
			var option: Button=_at_button(cat_card,["近敌","对空","威胁"][i],Rect2(27+i*96,270,90,54),func() -> void: dispatch("cat_priority",{"cat":id,"priority":key}); show_cat(id),"Priority"+key,TEAL if key==selected else PAPER)
			_bind_hint(option,"自动分工",["最近敌人","优先空中","优先高威胁"][i],["仍受原射程限制；没有合法目标就攻击近敌。"] as Array[String])
		var trial: Button=_at_button(cat_card,"试打当前队伍 →",Rect2(27,328,282,44),func() -> void: _close_cat_card(); controller.start_practice("single"),"LocalPractice")
		trial.add_theme_font_size_override("font_size",18)
	if not interactive:
		cat_card.mouse_filter=Control.MOUSE_FILTER_IGNORE
		for child: Node in cat_card.find_children("*","Control",true,false): (child as Control).mouse_filter=Control.MOUSE_FILTER_IGNORE

func _build_opening_cat_card(id: String, source_rect: Rect2) -> void:
	# Opening details stay next to the cat; the fish bowls remain usable below.
	var spec: Dictionary=Data.cats()[id]
	var bounds: Rect2=Hint.fit_rect(source_rect,Vector2(332,270),Rect2(0,80,1280,350))
	cat_card=_plate(self,bounds,"CatOpeningDetails")
	cat_card.add_theme_stylebox_override("panel",_sheet_paper())
	cat_card.set_meta("cat_id",id)
	_at_label(cat_card,str(spec.name),Rect2(32,24,268,28),22)
	_at_label(cat_card,str(spec.role),Rect2(32,56,268,25),16)
	_at_label(cat_card,"攻击 %.1f   攻速 %.2f/秒" % [float(spec.attack),1.0/float(spec.interval)],Rect2(32,87,268,25),16)
	_at_label(cat_card,"射程 %d" % int(spec.range),Rect2(32,115,268,25),16)
	var favorite: String=str(spec.favorites[0])
	_fish_static(cat_card,{"kind":favorite,"quality":0,"level":1},Rect2(32,143,39,35),false)
	_at_label(cat_card,"♥ "+Data.fish_name(favorite)+" +1级",Rect2(76,147,224,27),15)
	var ability: Label=_label(cat_card,str(spec.skill_summary),14)
	ability.position=Vector2(32,184)
	ability.size=Vector2(268,67)
	cat_card.mouse_filter=Control.MOUSE_FILTER_IGNORE
	for child: Node in cat_card.find_children("*","Control",true,false): (child as Control).mouse_filter=Control.MOUSE_FILTER_IGNORE

func _update_cat_hover() -> void:
	if is_instance_valid(controller.guide) and controller.guide.visible: return
	if scene_mode!="battle" or not modal_kind.is_empty() or is_instance_valid(equip_layer): return
	if is_instance_valid(controller.skill_cutin) and controller.skill_cutin.busy():
		if cat_hover_only: _close_cat_card()
		return
	if is_instance_valid(cat_card) and not cat_hover_only: return
	var id: String=controller.courtyard.cat_at(get_global_mouse_position())
	if id.is_empty():
		if cat_hover_only: _close_cat_card()
	else: _show_cat_hover(id,_cat_anchor(id))

func _toggle_mode() -> void:
	var mode: String="auto" if str(run.s.get("attack_mode","auto"))=="manual" else "manual"
	controller.set_attack_mode(mode)

func request_start() -> void:
	if controller.menu_open or run.s.phase!="prep" or bool(run.s.paused) or not equip_id.is_empty() or not _recruit_choices().is_empty(): return
	dispatch("start")

func dispatch(action: String, args: Dictionary = {}) -> void:
	_hide_hint()
	var result: Dictionary=controller.dispatch(action,args)
	if not bool(result.ok):
		if action in ["choose_fish","switch_initial_cat"] and run.s.phase=="initial_fish": show_initial_fish()
		elif action=="recruit" and run.s.phase=="visit": show_visit()
		notify(str(result.message))
		return
	if action=="sell" and run.item(inspect_id).is_empty():
		inspect_id=""
		home_details=false
		if dock_kind=="details": dock_kind="basket"
	if action=="equip":
		prep_focus_cat=str(args.get("cat",prep_focus_cat));prep_focus_slot=int(args.get("slot",prep_focus_slot));practice_recent_changed=true
	if action in ["merge","merge_all","unequip"]: practice_recent_changed=true
	if action=="start": practice_recent_changed=false
	if action=="upgrade": notify("↑ Lv.%d" % int(run.s.hq))
	if action=="cast": close_modal()
	if action in ["equip","unequip","merge","merge_all","active","upgrade","recruit","sell","bait_target","cat_priority","chapter_event","shop_buy","shop_refresh","shop_lock","shop_auto_merge","shop_order","shop_watch","encounter_choice"] and run.s.phase=="prep":
		show_prep()
	elif action=="switch_initial_cat" and run.s.phase=="initial_fish": show_initial_fish()
	elif action=="start": show_battle()
	elif action in ["merge","merge_all","sell","keep","upgrade","recruit"]: _build_dock()

func close_modal() -> void:
	_remove(overlay)
	overlay=null
	modal_kind=""

func _request_close() -> void:
	if modal_kind=="summary": controller.to_menu()
	else: _restore_phase()

func _restore_phase() -> void:
	close_modal()
	if controller.get("presentation_paused")==true:
		show_pause()
	elif controller.menu_open:
		if initial_room_open: show_initial()
		else: show_menu()
	elif bool(run.s.get("paused",false)): show_pause()
	elif run.s.phase=="visit": show_visit()
	elif run.s.phase=="initial_fish": show_initial_fish()
	elif run.s.phase in ["failed","victory"]: show_summary()
	elif run.s.phase=="prep": show_prep()
	elif run.s.phase=="route": show_route()
	elif run.s.phase=="toy_reward": show_toy_reward()
	else: show_battle()

func cancel_context() -> bool:
	if is_instance_valid(fish_hint) and fish_hint.visible: _hide_hint(); return true
	if is_instance_valid(equip_layer): _cancel_equip(); return true
	if is_instance_valid(cat_card):
		_remove(cat_card)
		cat_card=null
		cat_dps=null
		selected_cat=""
		return true
	if dock_kind!="closed" and scene_mode=="battle": dock_kind="closed"; _build_dock(); return true
	if modal_kind in ["settings","difficulty","bait","journal","memento","chapter_event","shop_order","shop_tools","toys","merge_preview"]: _restore_phase(); return true
	if not reserve_id.is_empty(): reserve_id=""; show_prep(); return true
	return false

func _focus_first() -> void:
	if scene_mode=="home" and modal_kind.is_empty() and not is_instance_valid(equip_layer):
		var exit_button: Button=find_child("Start",true,false) as Button
		if exit_button!=null and not exit_button.disabled: exit_button.grab_focus(); return
	var root: Node=overlay if is_instance_valid(overlay) else (equip_layer if is_instance_valid(equip_layer) else scene_layer)
	if not is_instance_valid(root): return
	if root==overlay:
		var controls: Array[Control]=[]
		for candidate: Control in root.find_children("*","Control",true,false):
			if candidate.focus_mode==Control.FOCUS_NONE or not candidate.is_visible_in_tree(): continue
			if candidate is BaseButton and candidate.disabled: continue
			controls.append(candidate)
		for index: int in range(controls.size()):
			var current: Control=controls[index]
			var previous: NodePath=current.get_path_to(controls[posmod(index-1,controls.size())])
			var next: NodePath=current.get_path_to(controls[(index+1)%controls.size()])
			current.focus_previous=previous
			current.focus_next=next
			current.focus_neighbor_top=previous
			current.focus_neighbor_left=previous
			current.focus_neighbor_bottom=next
			current.focus_neighbor_right=next
		if not controls.is_empty(): controls[0].grab_focus()
		return
	for candidate: Node in root.find_children("*","Button",true,false):
		if str(candidate.name) in ["MenuSettings","HomeSettings","Settings"]: continue
		if not (candidate as Button).disabled:
			(candidate as Button).grab_focus()
			return

func _fish_tag(kind: String) -> String:
	return {"F01":"分裂飞刃","F02":"灼烧扩散","F03":"回旋弹射","F04":"减速凝冰","F05":"疾风残影","F06":"闪电连锁","F07":"闪耀暴击","F08":"厚壳守护","F09":"穿云追踪","F10":"墨汁标记"}.get(kind,"")

func _starter_fish_details(kind: String, cat: String) -> void:
	var source: Control=find_child("StarterFishArt"+kind,true,false) as Control
	if source!=null: _show_fish_hint({"kind":kind,"quality":0,"level":1,"paid_basis":0},source,cat,true)

func _toggle_fish_details(_home: bool) -> void:
	_show_selected_hint()

func _equip_action() -> void:
	var value: Dictionary=run.item(inspect_id)
	if str(value.get("location",""))=="equipped": dispatch("unequip",{"id":inspect_id})
	else: _begin_equip()

func _room_background() -> String:
	if ResourceLoader.exists("res://art/clean-v038/home.png"): return "res://art/clean-v038/home.png"
	return "res://art/story-v026/room.png" if ResourceLoader.exists("res://art/story-v026/room.png") else "res://art/home-v025/home-room.png"

func _room_ui_layer(parent: Control) -> Control:
	var layer: Control=Control.new()
	layer.name="RoomInteractions"
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(layer)
	return layer

func _add_room_cat(parent: Control, id: String, rect: Rect2) -> Control:
	var actor: Control
	if ResourceLoader.exists("res://scripts/room_cat.gd"):
		var actor_script: Script=load("res://scripts/room_cat.gd") as Script
		actor=actor_script.new() as Control
		actor.set("cat_id",id)
		actor.set("run_state",run.s)
		actor.set("reduced",bool(controller.settings.get("reduced",false)))
		actor.set("idle_offset",float(int(id.substr(1)))*1.13)
		parent.add_child(actor)
	else:
		actor=_portrait(parent,id,rect.size)
	actor.name="RoomCat"+id
	actor.custom_minimum_size=Vector2.ZERO
	actor.position=rect.position
	actor.size=rect.size
	actor.mouse_filter=Control.MOUSE_FILTER_IGNORE
	room_actors[id]=actor
	room_actor_rects[id]=rect
	return actor

func _transparent_button(parent: Control, rect: Rect2, action: Callable, key: String) -> Button:
	var button: Button=_button(parent,"",action,key)
	button.custom_minimum_size=Vector2.ZERO
	button.position=rect.position
	button.size=rect.size
	button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	for style_name: String in ["normal","hover","pressed","disabled","focus"]:
		button.add_theme_stylebox_override(style_name,StyleBoxEmpty.new())
	return button

func _room_hotspot(parent: Control, id: String, rect: Rect2, action: Callable, key: String) -> Button:
	var stat_width: float=maxf(136,rect.size.x-24)
	_add_cat_stats(parent,id,Rect2(rect.get_center().x-stat_width*.5,rect.end.y-35,stat_width,29))
	var button: Button=_transparent_button(parent,rect,action,key)
	var label: Label=_at_label(parent,str(Data.cats()[id].name),Rect2(rect.get_center().x-54,rect.end.y-1,108,26),17)
	label.name="RoomName"+id
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	label.add_theme_stylebox_override("normal",_thin_paper(Color.WHITE))
	button.mouse_entered.connect(func() -> void: label.add_theme_color_override("font_color",CORAL))
	button.mouse_exited.connect(func() -> void: label.add_theme_color_override("font_color",INK))
	button.focus_entered.connect(func() -> void: label.add_theme_color_override("font_color",CORAL))
	button.focus_exited.connect(func() -> void: label.add_theme_color_override("font_color",INK))
	button.mouse_entered.connect(func() -> void: _show_cat_hover(id,button.get_global_rect()))
	button.focus_entered.connect(func() -> void: _show_cat_hover(id,button.get_global_rect()))
	button.mouse_exited.connect(func() -> void:
		if cat_hover_only and selected_cat==id: _close_cat_card())
	button.focus_exited.connect(func() -> void:
		if cat_hover_only and selected_cat==id: _close_cat_card())
	return button

func _lock_room_inputs() -> void:
	_hide_hint()
	_close_cat_card()
	room_selection_busy=true
	for node: Node in scene_layer.find_children("*","Button",true,false): (node as Button).disabled=true

func _choose_room_cat(id: String) -> void:
	if room_selection_busy or not initial_room_open or not room_actors.has(id): return
	_lock_room_inputs()
	selected_room_actor=room_actors[id]
	var token: int=room_selection_token
	for other: String in room_actors:
		if other!=id: _make_room_for_dinner(other)
	for name_label: Node in room_ui.find_children("RoomName*","Label",true,false): name_label.hide()
	selected_room_actor.get_parent().move_child(selected_room_actor,selected_room_actor.get_parent().get_child_count()-1)
	var destination: Vector2=Vector2(530,202)
	if selected_room_actor.has_method("walk_to"):
		selected_room_actor.connect("walk_finished",func() -> void: _complete_cat_walk(id,token),CONNECT_ONE_SHOT)
		selected_room_actor.call("walk_to",destination,1.05)
	else:
		var tween: Tween=create_tween()
		tween.tween_property(selected_room_actor,"position",destination,1.05)
		tween.tween_callback(func() -> void: _complete_cat_walk(id,token))

func _complete_cat_walk(id: String, token: int) -> void:
	if token!=room_selection_token or not room_selection_busy or not initial_room_open: return
	controller.new_game(id)

func _dinner_cat_rect(id: String, chosen: String = "") -> Rect2:
	if id==chosen: return Rect2(530,202,220,220)
	var placements: Array[Rect2]=[Rect2(114,210,138,138),Rect2(264,172,138,138),Rect2(990,190,138,138),Rect2(820,226,138,138),Rect2(405,143,124,124),Rect2(1119,297,138,138)]
	return placements[clampi(int(id.substr(1))-1,0,5)]

func _switch_room_cat(id: String) -> void:
	if room_selection_busy or run.s.get("phase","")!="initial_fish" or not room_actors.has(id): return
	if id==str(run.s.initial_cat): return
	var previous: String=str(run.s.initial_cat)
	var result: Dictionary=controller.dispatch("switch_initial_cat",{"cat":id})
	if not bool(result.ok): notify(str(result.message)); return
	_lock_room_inputs()
	_make_room_for_dinner(previous)
	selected_room_actor=room_actors[id]
	var token: int=room_selection_token
	var actor: Control=selected_room_actor
	create_tween().tween_property(actor,"size",Vector2(220,220),.6)
	var complete: Callable=func() -> void:
		if token==room_selection_token and run.s.get("phase","")=="initial_fish": show_initial_fish()
	if actor.has_method("walk_to"):
		actor.connect("walk_finished",complete,CONNECT_ONE_SHOT)
		actor.call("walk_to",Vector2(530,202),.6)
	else:
		var tween: Tween=create_tween()
		tween.tween_property(actor,"position",Vector2(530,202),.6)
		tween.tween_callback(complete)

func _choose_room_fish(kind: String, artwork: Control) -> void:
	if room_selection_busy or run.s.get("phase","")!="initial_fish": return
	_lock_room_inputs()
	var token: int=room_selection_token
	var tween: Tween=create_tween().set_parallel(true)
	tween.tween_property(artwork,"position",Vector2(588,330),.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(artwork,"scale",Vector2(.55,.55),.35)
	tween.tween_property(artwork,"modulate:a",.15,.35)
	tween.chain().tween_callback(func() -> void:
		if token==room_selection_token and run.s.get("phase","")=="initial_fish":
			room_selection_busy=false
			dispatch("choose_fish",{"kind":kind}))

func _recruit_room_cat(id: String) -> void:
	if room_selection_busy or run.s.get("phase","")!="visit": return
	_lock_room_inputs()
	var token: int=room_selection_token
	var actor: Control=room_actors[id]
	var complete: Callable=func() -> void:
		if token==room_selection_token:
			room_selection_busy=false
			dispatch("recruit",{"cat":id})
	if actor.has_method("walk_to"):
		actor.connect("walk_finished",complete,CONNECT_ONE_SHOT)
		actor.call("walk_to",Vector2(529,240),.7)
	else:
		var tween: Tween=create_tween()
		tween.tween_property(actor,"position",Vector2(529,240),.7)
		tween.tween_callback(complete)

func _container_picture(parent: Control, index: int, rect: Rect2) -> void:
	var path: String="res://art/story-v026/containers.png"
	if ResourceLoader.exists(path):
		var source: Texture2D=load(path) as Texture2D
		var atlas: AtlasTexture=AtlasTexture.new()
		atlas.atlas=source
		atlas.region=Rect2(index*source.get_width()/3.0,0,source.get_width()/3.0,source.get_height())
		var regions_path: String="res://art/story-v026/containers-regions.json"
		if FileAccess.file_exists(regions_path):
			var metadata: Variant=JSON.parse_string(FileAccess.get_file_as_string(regions_path))
			if metadata is Dictionary and metadata.get("regions",[]).size()>index:
				var region: Array=metadata.regions[index]
				atlas.region=Rect2(float(region[0]),float(region[1]),float(region[2]),float(region[3]))
		var container: TextureRect=TextureRect.new()
		container.name="FishContainer%d" % index
		container.texture=atlas
		container.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		container.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		container.position=rect.position
		container.size=rect.size
		container.mouse_filter=Control.MOUSE_FILTER_IGNORE
		parent.add_child(container)
	else:
		var basket: Control=_art(parent,"basket",rect)
		basket.name="FishContainer%d" % index

func _home_placements(count: int) -> Array:
	var result: Array=[]
	var width: float=202 if count<5 else 184
	var spacing: float=204 if count>=4 else 268
	var left: float=(1035-(count-1)*spacing-width)*.5
	for i: int in range(count): result.append(Rect2(left+i*spacing,350-width,width,width))
	return result

func _make_room_for_dinner(id: String) -> void:
	var actor: Control=room_actors[id]
	var rect: Rect2=_dinner_cat_rect(id)
	var destination: Vector2=rect.position
	room_actor_rects[id]=rect
	create_tween().tween_property(actor,"size",rect.size,.65)
	if actor.has_method("walk_to"): actor.call("walk_to",destination,.65)
	else: create_tween().tween_property(actor,"position",destination,.65)

func _recruit_choices() -> Array:
	return run.recruit_choices() if run!=null and run.has_method("recruit_choices") else []

func _build_recruit_dock(parent: Control, rect: Rect2, home: bool) -> void:
	var plate: Panel=_plate(parent,rect,"RecruitDock")
	var candidates: Array=_recruit_choices()
	var left: float=145 if home else 97
	var gap: float=416 if home else 335
	var caption: Label=_at_label(plate,"新伙伴\n选一只",Rect2(17,30,94,72),22)
	caption.theme_type_variation="TitleLabel"
	for i: int in range(candidates.size()):
		var id: String=str(candidates[i])
		var x: float=left+i*gap
		var actor: Control
		if ResourceLoader.exists("res://scripts/room_cat.gd"):
			var actor_script: Script=load("res://scripts/room_cat.gd") as Script
			actor=actor_script.new() as Control
			actor.set("cat_id",id)
			actor.set("reduced",bool(controller.settings.get("reduced",false)))
			plate.add_child(actor)
		else: actor=_portrait(plate,id)
		actor.position=Vector2(x,0)
		actor.size=Vector2(126,126) if home else Vector2(112,112)
		actor.mouse_filter=Control.MOUSE_FILTER_IGNORE
		_at_label(plate,str(Data.cats()[id].name),Rect2(x+130,12,112,30),22)
		var favorites: Array=Data.cats()[id].favorites
		for j: int in range(favorites.size()): _fish_static(plate,{"kind":favorites[j],"quality":0,"level":1},Rect2(x+130+j*42,48,42,41),false)
		_at_button(plate,"加入",Rect2(x+230,38,80,39),func() -> void: dispatch("recruit",{"cat":id}),"Recruit"+id)
		_transparent_button(plate,Rect2(x,0,224,rect.size.y),func() -> void: dispatch("recruit",{"cat":id}),"RecruitPortrait"+id)

func _cast_cost() -> int:
	return run.cast_cost() if run.has_method("cast_cost") else 6

func _hide_hint() -> void:
	if is_instance_valid(fish_hint): fish_hint.hide()

func _bind_fish_hint(source: Control, value: Dictionary, cat: String="") -> void:
	if value.is_empty(): return
	source.mouse_filter=Control.MOUSE_FILTER_PASS if not source is Button else Control.MOUSE_FILTER_STOP
	source.mouse_entered.connect(func() -> void:
		var fresh: Dictionary=run.item(str(value.get("id",""))) if value.has("id") else value
		if not fresh.is_empty(): _show_fish_hint(fresh,source,cat))
	source.mouse_exited.connect(func() -> void:
		if is_instance_valid(fish_hint): fish_hint.close_from(source))

func _show_fish_hint(value: Dictionary, source: Control, cat: String="", pinned: bool=false) -> void:
	if not is_instance_valid(fish_hint) or value.is_empty() or not is_instance_valid(source): return
	if modal_kind not in ["","bait","shop_order","merge_preview"] or room_selection_busy: return
	var actual: int=int(value.get("level",1))
	var effective: int=Data.effective(value,cat)
	var subtitle: String="Lv.%d" % actual
	if effective>actual: subtitle+=" → %d · 喜欢 +1" % effective
	var lines: Array[String]=[]
	for line: String in Data.short_description(value,cat).split("\n"):
		if not line.is_empty() and line!="3级解锁攻击机制": lines.append(line)
	for line: String in Data.growth_description(value,cat).split("\n"):
		if line.is_empty(): continue
		var threshold: int=int(line.left(1))
		lines.append("%d级 · 已解锁" % threshold if effective>=threshold else line)
	if cat.is_empty():
		var favorites: Array[String]=[]
		for id: String in Data.cats():
			if value.kind==Data.cats()[id].favorites[0]: favorites.append(str(Data.cats()[id].name))
		if not favorites.is_empty(): lines.append("♥ %s：生效等级 +1" % " / ".join(favorites))
	fish_hint.present(source,source.get_global_rect(),Data.fish_name(value.kind),subtitle,lines,FishArt.texture(value.kind),Rect2(Vector2.ZERO,size),pinned)

func _show_selected_hint() -> void:
	var source: Control=find_child("SelectedFishIcon",true,false) as Control
	if source!=null: _show_fish_hint(run.item(inspect_id),source,str(run.item(inspect_id).get("cat","")),true)

func _inventory_click(id: String, home: bool) -> void:
	if is_instance_valid(equip_layer) or run.item(id).is_empty(): return
	_hide_hint()
	inspect_id=id
	home_details=false
	_refresh_inventory(home)
	if home and run.s.phase=="prep": _begin_equip()

func _can_sell(value: Dictionary) -> bool:
	if value.is_empty() or bool(value.get("reserved",false)) or bool(run.s.get("paused",false)): return false
	return run.s.get("phase","")=="prep" and value.location in ["inventory","inbox"]

func _bind_fish_sale(control: Control, id: String) -> void:
	if id.is_empty(): return
	control.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
			control.accept_event()
			_sell_fish(id))

func _sell_fish(id: String) -> void:
	if sale_busy or not _can_sell(run.item(id)): return
	sale_busy=true
	_cancel_equip()
	dispatch("sell",{"id":id})
	call_deferred("_release_sale_guard")

func _release_sale_guard() -> void:
	sale_busy=false

func _can_merge_all() -> bool:
	var kinds: Dictionary={}
	var worn: Dictionary={}
	if run.s.get("phase","")=="prep":
		for value: Dictionary in run.in_location("equipped"):
			if int(value.level)<5: worn["%s:%s:%s" % [value.kind,value.quality,value.level]]=true
	for value: Dictionary in _loose_fish():
		if bool(value.get("reserved",false)) or int(value.level)>=5: continue
		var key: String="%s:%s:%s" % [value.kind,value.quality,value.level]
		if kinds.has(key) or worn.has(key): return true
		kinds[key]=true
	return false

func _add_merge_all(parent: Control, rect: Rect2) -> void:
	var button: Button=_at_button(parent,"一键合成" if rect.size.x>70 else "一键\n合成",rect,_request_merge_all,"MergeAll",GOLD)
	_style_small_action(button)
	button.add_theme_font_size_override("font_size",19 if rect.size.x>70 else 16)
	button.disabled=bool(run.s.get("paused",false)) or not _can_merge_all()
	button.mouse_entered.connect(func() -> void:
		var hints: Array[String]=["只合成未装备鱼干。"]
		if run.s.get("phase","")=="prep": hints.assign(["有已装鱼升级时，先显示具体预览。","不合并两份已装鱼，保留猫咪当前装备。"])
		fish_hint.present(button,button.get_global_rect(),"一键合成","同鱼种 · 同品质 · 同等级",hints,null,Rect2(Vector2.ZERO,size)))
	button.mouse_exited.connect(func() -> void: fish_hint.close_from(button))

func _bind_hint(source: Control, heading: String, subtitle: String, lines: Array[String], icon: Texture2D=null) -> void:
	if source.mouse_filter==Control.MOUSE_FILTER_IGNORE: source.mouse_filter=Control.MOUSE_FILTER_PASS
	source.mouse_entered.connect(func() -> void:
		if is_instance_valid(fish_hint) and modal_kind in ["","journal","bait"]: fish_hint.present(source,source.get_global_rect(),heading,subtitle,lines,icon,Rect2(0,0,1280,720)))
	source.mouse_exited.connect(func() -> void:
		if is_instance_valid(fish_hint): fish_hint.close_from(source))

func _cat_stats(id: String) -> Dictionary:
	if not controller.menu_open and not run.s.is_empty() and run.s.phase in ["combat","cleanup"] and run.combat.has_method("cat_display_stats"):
		return run.combat.cat_display_stats(id)
	if not controller.menu_open and not run.s.is_empty() and id in run.s.get("active",[]): return ShopAdvisor.stats(run,id)
	var base: Dictionary=Data.cats()[id]
	return {"attack":float(base.attack),"rate":1.0/float(base.interval)}

func _add_cat_stats(parent: Control, id: String, rect: Rect2) -> void:
	var chip: Control=CatStats.new()
	chip.name="Stats"+id
	chip.position=rect.position
	chip.size=rect.size
	chip.compact=rect.size.x<156
	var numbers: Dictionary=_cat_stats(id)
	chip.set_values(float(numbers.attack),float(numbers.rate))
	parent.add_child(chip)
	stat_chips[id]=chip

func _toy_icon(parent: Node, id: String, rect: Rect2) -> TextureRect:
	var picture: TextureRect=TextureRect.new()
	picture.name="ToyArt"+id
	picture.position=rect.position
	picture.size=rect.size
	picture.texture=ExpansionArt.picture("toys",id)
	picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(picture)
	return picture

func _toy_hint(source: Control, id: String, count: int=0) -> void:
	var spec: Dictionary=Data.toys().get(id,{})
	if spec.is_empty(): return
	var lines: Array[String]=BuildAdvisor.hint_lines(run.s,id,scene_mode=="toy_reward")
	var tags: String=" · ".join(spec.get("tags",[]))
	_bind_hint(source,str(spec.name),tags+(" · ×%d" % count if count>0 else ""),lines,ExpansionArt.picture("toys",id))

func _build_toy_shelf(parent: Control, rect: Rect2, enlarged: bool) -> void:
	var collected: Dictionary=run.s.get("toys",{})
	var used_rect: Rect2=rect
	if not enlarged: used_rect.size.x=clampf(collected.size()*51+16,230,rect.size.x)
	var shelf: Panel=_plate(parent,used_rect,"ToyShelf")
	var scroll: ScrollContainer=ScrollContainer.new()
	scroll.name="ToyCollectionScroll"
	scroll.position=Vector2(8,5)
	scroll.size=used_rect.size-Vector2(16,10)
	scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	shelf.add_child(scroll)
	var row: HBoxContainer=HBoxContainer.new()
	row.add_theme_constant_override("separation",9)
	scroll.add_child(row)
	if collected.is_empty():
		var label: Label=_label(row,"玩具 · 精英／首领掉落",16)
		label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		label.custom_minimum_size=Vector2(used_rect.size.x-24,rect.size.y-12)
	for id: String in collected:
		var extent: float=72 if enlarged else 42
		var tile: Button=_button(row,"",func() -> void: _show_toy_details(id),"Toy"+id)
		tile.custom_minimum_size=Vector2(extent,extent)
		tile.size=Vector2.ONE*extent
		for style: String in ["normal","hover","pressed"]: tile.add_theme_stylebox_override(style,Parchment.box("slot",Color("ffe3a2") if style=="hover" else Color.WHITE,2))
		_toy_icon(tile,id,Rect2(2,2,extent-4,extent-4))
		var count: int=int(collected[id])
		if count>1:
			var counter: Label=_at_label(tile,"×%d" % count,Rect2(extent-31,extent-23,30,22),14)
			counter.add_theme_color_override("font_outline_color",Color("faf4dd"))
			counter.add_theme_constant_override("outline_size",3)
		_toy_hint(tile,id,count)

func _show_toy_details(id: String) -> void:
	var source: Control=find_child("Toy"+id,true,false) as Control
	if source==null: return
	var spec: Dictionary=Data.toys()[id]
	var lines: Array[String]=BuildAdvisor.hint_lines(run.s,id,false)
	fish_hint.present(source,source.get_global_rect(),str(spec.name)," · ".join(spec.tags),lines,ExpansionArt.picture("toys",id),Rect2(0,0,1280,720),true)

func show_toys() -> void:
	if scene_mode not in ["battle","home"]: return
	var column: VBoxContainer=_modal("猫爬架玩具","toys",1010,270)
	_label(column,"全队共享 · 悬停看真实效果与联动",20)
	var holder: Control=Control.new();holder.custom_minimum_size=Vector2(930,130);column.add_child(holder)
	_build_toy_shelf(holder,Rect2(0,0,930,120),true)
	_focus_first()

func show_toy_reward() -> void:
	var page: Control=_scene("toy_reward",_room_background())
	var veil: ColorRect=ColorRect.new()
	veil.color=Color("17171aa6")
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter=Control.MOUSE_FILTER_IGNORE
	page.add_child(veil)
	_home_header(page,"猫爬架，添件玩具")
	var choices: Array=run.s.get("reward_choices",[])
	var width: float=242
	var gap: float=20
	var start: float=(1280-choices.size()*width-(choices.size()-1)*gap)*.5
	for i: int in range(choices.size()):
		var id: String=str(choices[i])
		var spec: Dictionary=Data.toys()[id]
		var card: Panel=_plate(page,Rect2(start+i*(width+gap),182,width,411),"RewardPaper"+id)
		card.add_theme_stylebox_override("panel",_sheet_paper())
		_toy_icon(card,id,Rect2(61,39,120,101))
		var role: Dictionary=Campaign.role(id)
		var role_label: Label=_at_label(card,str(role.label),Rect2(25,19,width-50,26),19)
		role_label.add_theme_color_override("font_color",role.color)
		var name_label: Label=_at_label(card,str(spec.name),Rect2(17,144,width-34,31),24)
		name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var gain: Label=_label(card,Campaign.reward_gain(run.s,id),21)
		gain.name="RewardGain"+id
		gain.position=Vector2(24,182); gain.size=Vector2(width-48,76)
		_build_reward_preview(card,id,Rect2(24,263,width-48,104))
		var tag: Label=_at_label(card,Campaign.reward_context(run.s,id),Rect2(24,372,width-48,26),17)
		tag.add_theme_color_override("font_color",Color("53715b"))
		var choice: Button=_transparent_button(page,Rect2(start+i*(width+gap),182,width,411),func() -> void: dispatch("reward_choose",{"id":id}),"ChooseToy"+id)
		var detail: Array[String]=BuildAdvisor.stack_changes(run.s,id)
		detail.append_array(BuildAdvisor.hint_lines(run.s,id,true))
		_bind_hint(choice,str(spec.name),"本次精确变化 · 选择后全队生效",detail,ExpansionArt.picture("toys",id))
		choice.mouse_entered.connect(func() -> void: card.modulate=Color("fff0c9"))
		choice.mouse_exited.connect(func() -> void: card.modulate=Color.WHITE)
		choice.focus_entered.connect(func() -> void: card.modulate=Color("fff0c9"))
		choice.focus_exited.connect(func() -> void: card.modulate=Color.WHITE)
	_build_feedback_medals(page,Vector2(26,102))
	_build_stage_contribution(page)
	_build_risk_receipt(page,Rect2(715,151,283,32))
	var note: Label=_at_label(page,"%d 选 1 · 小像预览变化 · 悬停查看数值" % choices.size(),Rect2(334,615,612,38),21)
	note.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_stylebox_override("normal",_thin_paper())
	_focus_first()

func _build_reward_preview(parent: Control,id: String,rect: Rect2) -> void:
	var before: Dictionary=run.s.duplicate(true)
	var after: Dictionary=Campaign.reward_preview(run.s,id)
	var preview: Panel=_plate(parent,rect,"RewardPreview"+id,Color("e5ddc8"))
	preview.set_meta("before",before)
	preview.set_meta("after",after)
	preview.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var inset: StyleBoxFlat=StyleBoxFlat.new()
	inset.bg_color=Color("e8dfc7"); inset.border_color=Color("bcae91"); inset.set_border_width_all(1); inset.set_corner_radius_all(3)
	preview.add_theme_stylebox_override("panel",inset)
	var tree: bool=id in preload("res://scripts/cat_mutations.gd").HQ_TOYS
	var cat: String=Campaign.preview_cat(run.s,id)
	for i: int in range(2):
		var state: Dictionary=before if i==0 else after
		if tree:
			var crop: Control=Control.new()
			crop.name="TreeDetail"+str(i); crop.position=Vector2(5+i*105,4); crop.size=Vector2(78,71)
			crop.clip_contents=true; crop.mouse_filter=Control.MOUSE_FILTER_IGNORE; preview.add_child(crop)
			var center: Vector2={"T13":Vector2(304,207),"T19":Vector2(302,281),"T14":Vector2(315,453),"T21":Vector2(335,392),"T16":Vector2(315,320),"T17":Vector2(271,466),"T20":Vector2(351,487)}.get(id,Vector2(315,392))
			var miniature: RewardTreePreview=RewardTreePreview.new()
			miniature.state=state
			miniature.position=Vector2(39,36)-center*.82
			miniature.scale=Vector2(.82,.82)
			crop.add_child(miniature)
		else:
			var actor: Control=preload("res://scripts/room_cat.gd").new()
			actor.set("cat_id",cat); actor.set("run_state",state); actor.set("reduced",true)
			actor.position=Vector2(4+i*105,0); actor.size=Vector2(80,80)
			actor.mouse_filter=Control.MOUSE_FILTER_IGNORE
			preview.add_child(actor)
		_at_label(preview,"现在" if i==0 else "获得后",Rect2(i*105+8,79,70,22),16).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_at_label(preview,"→",Rect2(83,31,28,30),22).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var added: Label=_at_label(preview,"+1",Rect2(164,2,27,22),15)
	added.add_theme_color_override("font_color",Color("8a5d2f"))
	added.add_theme_stylebox_override("normal",_thin_paper(Color("f1d69d")))

func show_route() -> void:
	var page: Control=_scene("route","")
	var board: Control=Journey.new()
	board.name="JourneyMap"
	board.from_index=int(run.s.get("route_from",run.s.stage))
	board.to_index=mini(19,int(run.s.get("route_to",int(run.s.stage)+1)))
	board.finished=int(run.s.get("route_to",int(run.s.stage)+1))>=20
	board.reduced=bool(controller.settings.get("reduced",false))
	board.size=Vector2(1280,720)
	board.continued.connect(func() -> void: dispatch("route_continue"))
	board.node_hovered.connect(_route_hint)
	board.hover_ended.connect(_hide_hint)
	page.add_child(board)
	_build_feedback_medals(page,Vector2(72,492))
	_build_risk_receipt(page,Rect2(758,492,420,57))

func _route_hint(index: int, anchor_rect: Rect2) -> void:
	var level: Dictionary=Data.stages()[index]
	var foe: String=str(level.boss) if not str(level.boss).is_empty() else str(level.get("elite",""))
	var reward: String="玩具四选一" if level.rank=="boss" else ("玩具三选一" if level.rank=="elite" else "金币与鱼干")
	var lines: Array[String]=["%s · %s" % [str(level.period),reward]]
	if not foe.is_empty(): lines.append(str(Data.enemies()[foe].name))
	for threat: Dictionary in Campaign.threats(index).slice(0,2): lines.append(str(threat.name)+" · "+str(threat.detail))
	var counter: String=Campaign.boss_hint(index)
	if not counter.is_empty(): lines.append(counter)
	fish_hint.present(null,anchor_rect,"%d-%d %s" % [int(level.chapter),int(level.encounter),str(level.title)],"首领" if level.rank=="boss" else ("精英" if level.rank=="elite" else "遭遇"),lines,null,Rect2(0,0,1280,720))

func _add_capability_badges(parent: Control,id: String,rect: Rect2) -> void:
	var capabilities: Array=BuildAdvisor.badges(run.s,id)
	var left: float=rect.get_center().x-capabilities.size()*15.0
	for i: int in range(capabilities.size()):
		var info: Dictionary=capabilities[i]
		var button: Button=_at_button(parent,str(info.icon),Rect2(left+i*30,rect.end.y-64,27,25),func() -> void: show_cat(id),"Capability"+id+str(i))
		button.add_theme_font_size_override("font_size",15)
		button.add_theme_stylebox_override("normal",Parchment.box("slot",Color("eee0b8") if bool(info.active) else Color("b9b1a2"),2))
		if not str(info.fish).is_empty():
			button.text=""
			var icon: TextureRect=TextureRect.new()
			icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture=FishArt.texture(str(info.fish))
			icon.position=Vector2(3,2)
			icon.size=Vector2(21,20)
			icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
			icon.modulate=Color.WHITE if bool(info.active) else Color("ffffff66")
			button.add_child(icon)
		if not bool(info.active):
			var lock: Label=_at_label(button,"◇",Rect2(16,11,12,12),12)
			lock.add_theme_color_override("font_color",INK)
		_bind_hint(button,str(info.name),("已生效" if bool(info.active) else "尚未解锁"),[str(info.text)] as Array[String],FishArt.texture(str(info.fish)) if not str(info.fish).is_empty() else null)

func _build_practice(parent: Control) -> void:
	practice_display=PracticeDisplay.new()
	practice_display.reduced=bool(controller.settings.get("reduced",false))
	parent.add_child(practice_display)
	practice_display.target_requested.connect(func(kind: String) -> void:
		if controller.has_method("start_practice"): controller.start_practice(kind))
	practice_display.hint_requested.connect(func(source: Control,title_text: String,subtitle: String,lines: Array[String]) -> void:
		if is_instance_valid(fish_hint) and modal_kind.is_empty() and not is_instance_valid(equip_layer): fish_hint.present(source,source.get_global_rect(),title_text,subtitle,lines,null,Rect2(0,0,1280,548)))
	practice_display.hint_closed.connect(func(source: Control) -> void: fish_hint.close_from(source))
	if not practice_result.is_empty(): practice_display.set_result(practice_result)

func _update_practice() -> void:
	if scene_mode!="home" or not is_instance_valid(practice_display) or controller.menu_open: return
	var session: Variant=controller.get("practice_session")
	if session==null or not session.has_method("frame"): return
	var anchors: Dictionary={}
	for id: String in room_actor_rects:
		var rect: Rect2=room_actor_rects[id]
		anchors[id]=(Vector2(rect.end.x-22,rect.get_center().y+15)-practice_display.position)/practice_display.scale
	practice_display.reduced=bool(controller.settings.get("reduced",false))
	var frame: Dictionary=session.frame()
	var practicing: bool=bool(frame.get("running",false))
	var risk_panel: Control=scene_layer.find_child("EncounterChoice",true,false) as Control
	practice_display.visible=practicing or not practice_result.is_empty()
	if risk_panel!=null: risk_panel.visible=not practice_display.visible
	var threat: Control=scene_layer.find_child("NextThreat",true,false) as Control
	if threat!=null: threat.visible=not practice_display.visible
	if float(frame.get("time",0))<practice_previous_time: practice_attack_seen.clear()
	practice_previous_time=float(frame.get("time",0))
	for event: Dictionary in frame.get("events",[]):
		if str(event.get("type",""))!="attack": continue
		var cat_id: String=str(event.get("cat",""))
		var event_key: String="%s:%.4f" % [cat_id,float(event.get("event_time",0))]
		if practice_attack_seen.has(event_key): continue
		practice_attack_seen[event_key]=true
		var actor: Control=room_actors.get(cat_id)
		if is_instance_valid(actor) and actor.has_method("play_attack"): actor.play_attack()
	practice_display.set_frame(frame,anchors)

func set_practice_result(value: Dictionary) -> void:
	practice_result=value.duplicate(true)
	if is_instance_valid(practice_display): practice_display.set_result(value)

func show_equipment_feedback(cat_id: String,before: Dictionary,after: Dictionary,threshold_lines: Array[String]) -> void:
	if scene_mode!="home" or not is_instance_valid(scene_layer): return
	_remove(equipment_feedback)
	var rect: Rect2=room_actor_rects.get(cat_id,Rect2(420,210,235,235))
	equipment_feedback=Control.new()
	equipment_feedback.name="EquipmentGrowth"
	equipment_feedback.mouse_filter=Control.MOUSE_FILTER_IGNORE
	scene_layer.add_child(equipment_feedback)
	var attack_delta: float=float(after.get("attack",0))-float(before.get("attack",0))
	var speed_delta: float=float(after.get("rate",0))-float(before.get("rate",0))
	var delta_text: String="攻击 %+.1f · 攻速 %+.2f/秒" % [attack_delta,speed_delta]
	var label: Label=_at_label(equipment_feedback,delta_text,Rect2(clampf(rect.get_center().x-155,22,948),rect.position.y-35,310,31),19)
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_stylebox_override("normal",_thin_paper())
	label.add_theme_color_override("font_color",Color("537345") if attack_delta+speed_delta>=0 else CORAL)
	if not threshold_lines.is_empty():
		var parts: PackedStringArray=threshold_lines[0].split("\n")
		var brief: String=parts[0]
		if parts.size()>1: brief+="\n"+str(parts[1]).get_slice("。",0).left(45)
		var growth_paper: Panel=_plate(equipment_feedback,Rect2(clampf(rect.get_center().x-180,18,900),maxf(150,rect.position.y-129),360,95),"GrowthThresholdPaper")
		growth_paper.add_theme_stylebox_override("panel",_sheet_paper(Color("ffecb8")))
		var threshold: Label=_at_label(growth_paper,brief,Rect2(26,19,308,60),18)
		threshold.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		threshold.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		threshold.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		threshold.text_overrun_behavior=TextServer.OVERRUN_NO_TRIMMING
		threshold.clip_text=false
		threshold.max_lines_visible=2
	var chip: Control=stat_chips.get(cat_id)
	if is_instance_valid(chip):
		var chip_ref: WeakRef=weakref(chip)
		var animate: Tween=create_tween()
		animate.tween_method(func(weight: float) -> void:
			var live_chip: Control=chip_ref.get_ref() as Control
			if is_instance_valid(live_chip): live_chip.set_values(lerpf(float(before.get("attack",0)),float(after.get("attack",0)),weight),lerpf(float(before.get("rate",0)),float(after.get("rate",0)),weight)),0.0,1.0,.15)
	var target_ref: WeakRef=weakref(equipment_feedback)
	var tween: Tween=create_tween()
	tween.tween_interval(3.0 if not threshold_lines.is_empty() else 1.5)
	tween.tween_callback(func() -> void:
		var target: Control=target_ref.get_ref() as Control
		if is_instance_valid(target): target.queue_free())

func _feedback_icon(source: String) -> Texture2D:
	if source.begins_with("T"): return ExpansionArt.picture("toys",source.split(":")[0])
	if source.begins_with("F"): return FishArt.texture(source.split(":")[0])
	if source.begins_with("E") or source.begins_with("B") or source.begins_with("X"): return preload("res://scripts/illustrated_atlas.gd").enemy(source.split(":")[0])
	return null

func _build_feedback_medals(parent: Control,origin: Vector2) -> void:
	var report: Dictionary=FeedbackReceipt.latest(run.s)
	if report.is_empty(): return
	var medals: Array=FeedbackReceipt.medals(report)
	for i: int in range(medals.size()):
		var medal: Dictionary=medals[i]
		var button: Button=_at_button(parent,"",Rect2(origin+Vector2(i*182,0),Vector2(174,57)),func() -> void: _show_medal_hint(medal,i),"StageMedal%d" % i)
		button.add_theme_stylebox_override("normal",Parchment.box("strip",Color.WHITE,3))
		button.set_meta("report",report)
		var source: String=str(medal.source)
		if source.begins_with("C"):
			var portrait: Control=_portrait(button,source,Vector2(42,42))
			portrait.position=Vector2(5,7)
		elif source.begins_with("T"): _toy_icon(button,source,Rect2(5,7,42,42))
		else: _at_label(button,"⌂" if i==2 else "✦",Rect2(10,12,33,34),27)
		_at_label(button,str(medal.title),Rect2(48,7,119,20),12)
		_at_label(button,str(medal.text),Rect2(48,27,119,22),16)
		var lines: Array[String]=[]
		lines.assign(medal.lines)
		_bind_hint(button,str(medal.title),str(medal.subtitle),lines,_feedback_icon(source))
	var highlights: Array=report.get("highlights",[])
	if not highlights.is_empty():
		var film: Button=_at_button(parent,"胶片",Rect2(origin+Vector2(552,4),Vector2(66,49)),func() -> void: _show_highlight(report),"StageHighlight")
		_bind_hint(film,"三格战报","这次联动做了什么",["发动前 → 效果示意 → 结算后","看看击中了谁、打掉了多少血。"] as Array[String])

func _build_risk_receipt(parent: Control,rect: Rect2) -> void:
	var reports: Array=run.s.get("stage_reports",[])
	if reports.is_empty(): return
	var reward: int=int(reports[-1].get("risk_reward",0))
	if reward<=0: return
	var label: Label=_at_label(parent,"悬赏完成 · 额外 +%d 金币" % reward,rect,20)
	label.name="RiskRewardReceipt"
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	label.add_theme_stylebox_override("normal",_thin_paper(Color("e9d19a")))

func _build_stage_contribution(parent: Control) -> void:
	var report: Dictionary=FeedbackReceipt.latest(run.s)
	if report.is_empty(): return
	var highlights: Array=report.get("highlights",[])
	var text: String=""
	if not highlights.is_empty() and (float(highlights[0].get("damage",0))>0 or int(highlights[0].get("target_count",0))>0):
		var event: Dictionary=highlights[0]
		text="上场关键一击 · %s  %.0f伤害 / %d目标" % [FeedbackReceipt.source_name(str(event.get("source",""))),float(event.get("damage",0)),int(event.get("target_count",0))]
	else:
		var best: String="";var amount: float=0
		for cat: String in report.get("damage_by_cat",{}):
			if float(report.damage_by_cat[cat])>amount: best=cat;amount=float(report.damage_by_cat[cat])
		if amount>0: text="上场守家 · %s实际造成 %.0f 伤害" % [FeedbackReceipt.source_name(best),amount]
	if text.is_empty(): return
	var receipt: Button=_at_button(parent,text,Rect2(28,151,670,30),func() -> void:
		if not highlights.is_empty(): _show_highlight(report)
		else: show_campaign_journal(),"StageContribution")
	receipt.add_theme_font_size_override("font_size",16)
	receipt.add_theme_stylebox_override("normal",_thin_paper(Color("e2d8bc")))
	_bind_hint(receipt,"上一场真实记录","点击查看",FeedbackReceipt.detail_lines(report))

func _show_medal_hint(medal: Dictionary,index: int) -> void:
	var source: Control=find_child("StageMedal%d" % index,true,false) as Control
	if source==null: return
	var lines: Array[String]=[]
	lines.assign(medal.lines)
	fish_hint.present(source,source.get_global_rect(),str(medal.title),str(medal.subtitle),lines,_feedback_icon(str(medal.source)),Rect2(0,0,1280,720),true)

func _show_highlight(report: Dictionary) -> void:
	_hide_hint()
	_remove(highlight_strip)
	var entries: Array=report.get("highlights",[])
	if entries.is_empty() or not is_instance_valid(scene_layer): return
	var highlight: Dictionary=entries[0]
	var frames: Array=highlight.get("frames",[])
	if frames.is_empty(): return
	highlight_strip=Control.new()
	highlight_strip.name="HighlightFilm"
	highlight_strip.size=Vector2(1280,720)
	highlight_strip.mouse_filter=Control.MOUSE_FILTER_STOP
	scene_layer.add_child(highlight_strip)
	var sheet: Panel=_plate(highlight_strip,Rect2(150,175,980,306),"HighlightSheet")
	sheet.add_theme_stylebox_override("panel",_sheet_paper())

	_at_label(sheet,"三格战报 · "+FeedbackReceipt.source_name(str(highlight.get("source",""))),Rect2(27,16,865,29),22)
	_at_button(sheet,"×",Rect2(907,8,54,54),func() -> void: _remove(highlight_strip); highlight_strip=null,"CloseHighlight")
	for i: int in range(mini(3,frames.size())):
		var shot: Dictionary=frames[i]
		var paper: Panel=_plate(sheet,Rect2(21+i*314,65,306,218),"HighlightFrame%d" % i)
		paper.add_theme_stylebox_override("panel",Parchment.box("slot",Color("e6d7b7"),4))
		_at_label(paper,["① 发动前","② 效果示意","③ 结算后"][i],Rect2(12,6,280,28),21)
		var film: Control=preload("res://scripts/feedback_film.gd").new()
		film.name="RecordedFrame%d" % i
		film.frame=shot.duplicate(true)
		film.highlight=highlight.duplicate(true)
		film.frame_index=i
		film.position=Vector2(9,39)
		film.size=Vector2(288,168)
		paper.add_child(film)
	var target: Control=highlight_strip
	if not bool(controller.settings.get("reduced",false)):
		var tween: Tween=create_tween()
		target.modulate.a=0
		tween.tween_property(target,"modulate:a",1.0,.15)

func _build_failure_receipt(parent: VBoxContainer) -> void:
	var rows: Array=FeedbackReceipt.failure_rows(run.s)
	if rows.is_empty(): return
	var row: HBoxContainer=_hbox(parent)
	row.name="LastThreeHits"
	for i: int in range(rows.size()):
		var entry: Dictionary=rows[i]
		var button: Button=_button(row,"%d. %s\n%s" % [i+1,entry.title,entry.text],func() -> void: pass,"FailureHit%d" % i)
		button.custom_minimum_size=Vector2(275,59)
		button.add_theme_font_size_override("font_size",14)
		var lines: Array[String]=[]
		lines.assign(entry.lines)
		button.mouse_entered.connect(func() -> void: fish_hint.present(button,button.get_global_rect(),str(entry.title),str(entry.subtitle),lines,_feedback_icon(str(entry.source)),Rect2(0,0,1280,720)))
		button.mouse_exited.connect(func() -> void: fish_hint.close_from(button))
	var suggestion: String=str(run.s.get("failure_feedback",{}).get("suggestion",""))
	if not suggestion.is_empty(): _label(parent,suggestion,15)

func _cat_status_text(id: String) -> String:
	var lines: Array[String]=[]
	for current: Dictionary in run.s.get("battle",{}).get("cats",[]):
		if str(current.id)!=id: continue
		if float(current.get("web_left",0))>0: lines.append("蛛网 · 攻速 −%d%% · %.1fs" % [roundi(float(current.get("web_slow",0))*100),float(current.web_left)])
		if float(current.get("confuse_left",0))>0: lines.append("混乱 · 弹道偏转 · %.1fs" % float(current.confuse_left))
	if lines.is_empty(): lines.append(str(Data.cats()[id].role))
	if scene_mode=="battle" and run.combat!=null:
		var skill: Dictionary=run.combat.skill_status(id)
		if not skill.is_empty():
			var skill_state_text: String="本场已使用" if bool(skill.used) else ("左键释放 · 右键详情" if bool(skill.ready) else "蓄能 %.1f / %.1f 秒" % [float(skill.charge),float(skill.duration)])
			if float(skill.active_left)>0: skill_state_text="生效中 · 剩 %.1f 秒" % float(skill.active_left)
			lines.append(str(skill.name)+" · 每场一次")
			lines.append(str(skill.description))
			lines.append(skill_state_text)
			lines.append("攻速加快蓄能 · 攻击增威")
	return "\n".join(lines)

func _apply_reading_size() -> void:
	# The 1280 canvas is preserved. In small windows, reading text is 19px logical
	# (14.25px at 960), with 54px primary controls (40.5px at 960).
	for node: Node in find_children("*","Label",true,false):
		var label: Label=node as Label
		if compact_reading and label.size.y>=26 and not bool(label.get_meta("fixed_reading",false)):
			label.add_theme_font_size_override("font_size",maxi(19,label.get_theme_font_size("font_size")))
	for key: String in ["HomeUpgrade","PracticeComparison"]:
		var button: Button=find_child(key,true,false) as Button
		if button!=null: button.add_theme_font_size_override("font_size",19)

func show_difficulty() -> void:
	difficulty_choice=str(controller.settings.get("difficulty_default","easy"))
	var body: VBoxContainer=_modal("今晚，想挑战怎样的夜色？","difficulty",1144,432)
	_label(body,"三个难度都有完整20关；简单也需要合成、招募与分工。当前存档不会因选择而改变。",19)
	var row: HBoxContainer=_hbox(body)
	row.add_theme_constant_override("separation",18)
	for i: int in range(3):
		var id: String=["easy","hard","hell"][i]
		var profile: Dictionary=Campaign.profile(id)
		var holder: Control=Control.new()
		holder.custom_minimum_size=Vector2(350,248)
		row.add_child(holder)
		var card: Panel=_plate(holder,Rect2(4,7,337,235),"DifficultyPaper"+id)
		card.rotation=deg_to_rad([-1.3,.8,-.7][i])
		card.add_theme_stylebox_override("panel",_sheet_paper([Color("dde3c4"),Color("ead3af"),Color("d9bec5")][i]))
		_portrait(card,["C01","C03","C05"][i],Vector2(104,94)).position=Vector2(218,6)
		_at_label(card,str(profile.name),Rect2(19,15,195,38),32)
		_at_label(card,["有余地，仍要动脑","构筑与防守都要稳","给熟练猫队的恶梦"][i],Rect2(20,60,203,52),19).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		var details: Label=_label(card,str(profile.get("description","")),19)
		details.position=Vector2(20,113); details.size=Vector2(295,78)
		var choice: Button=_at_button(card,"选择 "+str(profile.name),Rect2(20,177,295,54),func() -> void: _pick_difficulty(id),"Difficulty"+id,TEAL if id==difficulty_choice else PAPER)
		choice.set_meta("difficulty",id)
	var actions: HBoxContainer=_hbox(body)
	var back: Button=_button(actions,"再想想",_restore_phase,"DifficultyBack")
	back.custom_minimum_size.y=54
	var confirm: Button=_button(actions,"带上猫咪，出发 →",_confirm_difficulty,"DifficultyConfirm")
	confirm.custom_minimum_size.y=54
	_accent(confirm,CORAL)
	_focus_first()

func _pick_difficulty(id: String) -> void:
	difficulty_choice=id
	for key: String in ["easy","hard","hell"]:
		var choice: Button=find_child("Difficulty"+key,true,false) as Button
		if choice!=null:
			choice.text=("✓ 已选 " if key==id else "选择 ")+str(Campaign.profile(key).name)
			_accent(choice,TEAL if key==id else PAPER)

func _confirm_difficulty() -> void:
	controller.set_setting("difficulty_default",difficulty_choice)
	close_modal()
	controller.request_new_game()

func _build_encounter_choice(page: Control) -> void:
	if not run.has_method("encounter_status"): return
	var encounter_info: Dictionary=run.encounter_status()
	if not bool(encounter_info.get("available",false)): return
	var panel: Panel=_plate(page,Rect2(1033,244,216,126),"EncounterChoice")
	panel.add_theme_stylebox_override("panel",_thin_paper(Color("ead7b4")))
	var groups: Array[String]=[]
	for group: Dictionary in encounter_info.get("extra_enemies",[]): groups.append("%s×%d" % [Data.enemies()[str(group.kind)].name,int(group.count)])
	var extra: Label=_at_label(panel,"加码："+"\n".join(groups),Rect2(12,11,192,40),16)
	extra.name="RiskExtraEnemies";extra.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	extra.add_theme_font_size_override("font_size",16)
	extra.set_meta("fixed_reading",true)
	extra.clip_text=false;extra.text_overrun_behavior=TextServer.OVERRUN_NO_TRIMMING
	var selected: String=str(encounter_info.get("choice","normal"))
	for i: int in range(2):
		var choice: String="normal" if i==0 else "risk"
		var title: String="常规守家 · 稳定收入" if i==0 else "加码袭击 · 胜利 +%d 金" % int(encounter_info.get("reward_gold",0))
		var button: Button=_at_button(panel,("✓ " if selected==choice else "")+title,Rect2(8,54+i*33,200,29),func() -> void: dispatch("encounter_choice",{"choice":choice}),"Encounter"+choice.capitalize(),GOLD if selected==choice else PAPER)
		button.add_theme_font_size_override("font_size",16)
		var lines: Array[String]=[]
		lines.assign(["原有敌群与收入不变。"] if i==0 else [str(encounter_info.get("detail","")),"胜利额外 +%d 金；失败不发。" % int(encounter_info.get("reward_gold",0)),"额外敌人不另掉金币。"])
		_bind_hint(button,"常规守家" if i==0 else str(encounter_info.get("title","加码袭击")),"出门后锁定选择",lines)

func _build_next_threat(page: Control) -> void:
	var index: int=int(run.s.stage)
	var next: Dictionary=Data.stages()[index]
	var paper: Panel=_plate(page,Rect2(1033,132,216,110),"NextThreat")
	paper.add_theme_stylebox_override("panel",Parchment.box("slot",Color("dfd7c0"),3))
	_at_label(paper,"%d-%d  %s" % [int(next.chapter),int(next.encounter),Campaign.wave_name(index).get_slice(" · ",0)],Rect2(12,8,196,26),18)
	var threats: Array=Campaign.threats(index)
	for i: int in range(threats.size()):
		var threat: Dictionary=threats[i]
		var icon: TextureRect=TextureRect.new()
		icon.texture=preload("res://scripts/illustrated_atlas.gd").enemy(_threat_enemy(threat,index))
		icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position=Vector2(15+i*63,35);icon.size=Vector2(55,48)
		icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;paper.add_child(icon)
		var hotspot: Button=_transparent_button(paper,Rect2(10+i*63,34,63,50),func() -> void: pass,"Threat"+str(threat.kind))
		_bind_hint(hotspot,str(threat.name),"下一关的主要威胁",[str(threat.detail)] as Array[String],icon.texture)
	var hint_text: String=Campaign.boss_hint(index)
	if hint_text.is_empty(): hint_text="悬停看敌情 · 先补短板"
	_at_label(paper,str(Campaign.profile(str(run.s.get("difficulty","easy"))).name)+" · "+str(next.period),Rect2(12,82,193,24),17)
	_bind_hint(paper,"出门前看一眼",str(next.title),[Campaign.wave_name(index),hint_text] as Array[String])
	paper.mouse_filter=Control.MOUSE_FILTER_PASS

func show_bait() -> void:
	if run.s.get("phase","")!="prep" or not run.has_method("bait_status"): return
	var bait: Dictionary=run.bait_status()
	var body: VBoxContainer=_modal("把想要的鱼，系在下一竿上","bait",1060,432)
	_label(body,str(bait.get("description","每章一次：下一竿同鱼种、同品质，等级照常抽取。")),20)
	_label(body,"选择不扣钱、不消耗原鱼。成功钓鱼多付4金币，回家后再装配。",18)
	var scroll: ScrollContainer=ScrollContainer.new()
	scroll.custom_minimum_size=Vector2(1000,205)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var grid: GridContainer=GridContainer.new(); grid.columns=9
	grid.add_theme_constant_override("h_separation",12); grid.add_theme_constant_override("v_separation",12)
	scroll.add_child(grid)
	for value: Dictionary in run.s.get("items",{}).values():
		if value.get("location","") not in ["inventory","inbox","equipped"]: continue
		var tile: Button=_fish_tile(grid,value,Rect2(0,0,92,92),func() -> void: close_modal(); dispatch("bait_target",{"id":str(value.id)}),"BaitFish"+str(value.id))
		tile.custom_minimum_size=Vector2(92,92)
		tile.disabled=not bool(bait.get("available",false))
	if grid.get_child_count()==0: _label(grid,"先获得一条鱼，就能把它设为目标。",20)
	if bool(bait.get("armed",false)):
		var clear: Button=_button(body,"解开鱼饵，保留本章机会",func() -> void: close_modal(); dispatch("bait_target",{"id":""}),"DisarmBait")
		clear.custom_minimum_size.y=54
	_focus_first()

func _build_campaign_entry(page: Control) -> void:
	var button: Button=_at_button(page,"追月手帐",Rect2(534,25,151,44),show_campaign_journal,"CampaignJournal")
	button.add_theme_stylebox_override("normal",_thin_paper(Color("dfd7c0")))
	button.add_theme_font_size_override("font_size",19)
	_bind_hint(button,"追月手帐","发现 · 挑战 · 本局目标",["记录已见过的鱼、玩具与敌人。","解锁收集称号；没有永久伤害加成。"] as Array[String])

func show_campaign_journal() -> void:
	var body: VBoxContainer=_modal("追月手帐","journal",1120,432)
	var center: Control=overlay.get_node("Center") as Control
	center.offset_top=72; center.offset_bottom=-38
	(body.get_parent() as PanelContainer).custom_minimum_size.y=578
	var tabs: HBoxContainer=_hbox(body)
	for id: String in ["journey","codex","challenges"]:
		var tab: Button=_button(tabs,{"journey":"本局与纪念","codex":"发现图鉴","challenges":"挑战印章"}[id],func() -> void: journal_tab=id; journal_page=0; show_campaign_journal(),"JournalTab"+id)
		tab.custom_minimum_size.y=44
		_accent(tab,TEAL if id==journal_tab else PAPER)
	var book: Control=Control.new()
	book.name="JournalSpread"; book.custom_minimum_size=Vector2(1056,414)
	body.add_child(book)
	var left: Panel=_plate(book,Rect2(0,0,516,406),"JournalLeft")
	var right: Panel=_plate(book,Rect2(534,0,516,406),"JournalRight")
	left.add_theme_stylebox_override("panel",_sheet_paper(Color("e5dbc2")))
	right.add_theme_stylebox_override("panel",_sheet_paper(Color("e5dbc2")))
	match journal_tab:
		"codex": _journal_codex(left,right)
		"challenges": _journal_challenges(left,right)
		_: _journal_journey(left,right)
	_apply_reading_size()
	_focus_first()

func _journal_journey(left: Control,right: Control) -> void:
	_at_label(left,"今晚的小目标",Rect2(24,19,466,30),22)
	var goals: Array=run.campaign_goals() if run.has_method("campaign_goals") else []
	for i: int in range(mini(4,goals.size())):
		var entry: Dictionary=goals[i]
		var done: bool=bool(entry.get("complete",false))
		var row: Label=_at_label(left,("✓ " if done else "○ ")+str(entry.get("title","")),Rect2(26,57+i*36,464,30),19)
		row.add_theme_color_override("font_color",Color("53715b") if done else INK)
		_bind_hint(row,str(entry.get("title","")),"已经完成" if done else "本局目标",[str(entry.get("detail",""))] as Array[String])
	_at_label(left,"首领合照墙",Rect2(24,211,350,28),22)
	var wall: Control=Memento.new()
	wall.name="MementoWall"; wall.unlocked=run.s.get("campaign_progress",{}).get("profile",{}).get("mementos",[]).duplicate()
	wall.position=Vector2(24,246); wall.size=Vector2(468,135)
	wall.selected.connect(show_memento)
	left.add_child(wall)
	_at_label(right,"下一套，想这样玩",Rect2(24,19,465,30),22)
	var tracked: String=str(run.s.get("campaign_progress",{}).get("profile",{}).get("tracked_build",""))
	var recipes: Array=Campaign.signature_builds(run.s)
	for i: int in range(recipes.size()):
		var recipe: Dictionary=recipes[i]
		var row: Panel=_plate(right,Rect2(20,57+i*108,475,101),"BuildRecipe"+str(recipe.id),Color("ede5cf"))
		var note_paper: StyleBoxFlat=StyleBoxFlat.new()
		note_paper.bg_color=Color("dfd3b0") if str(recipe.id)==tracked else Color("eee5d0")
		note_paper.border_color=Color("bcae91"); note_paper.border_width_bottom=1; note_paper.set_corner_radius_all(3)
		row.add_theme_stylebox_override("panel",note_paper)
		_at_label(row,str(recipe.name),Rect2(15,8,298,27),21)
		_at_label(row,str(recipe.progress),Rect2(15,39,344,26),18)
		_at_label(row,str(recipe.next),Rect2(15,69,445,24),17).add_theme_color_override("font_color",Color("6d6554"))
		var track: Button=_at_button(row,"✓ 追踪中" if str(recipe.id)==tracked else "追踪",Rect2(347,7,114,52),func() -> void: dispatch("track_build",{"id":str(recipe.id)}); show_campaign_journal(),"TrackBuild"+str(recipe.id),TEAL if str(recipe.id)==tracked else PAPER)
		_bind_hint(track,str(recipe.name),"跨局保留目标",[str(recipe.description),"只记录目标，不自动购买或装备。"] as Array[String])

func _journal_codex(left: Control,right: Control) -> void:
	var catalog: Dictionary=run.codex_status() if run.has_method("codex_status") else {}
	var categories: Array=catalog.get("categories",[])
	if categories.is_empty(): return
	journal_category=clampi(journal_category,0,categories.size()-1)
	for i: int in range(categories.size()):
		var tab_category: Dictionary=categories[i]
		var tab: Button=_at_button(left,str(tab_category.name),Rect2(22+i*121,20,115,44),func() -> void: journal_category=i; journal_selected=""; journal_page=0; show_campaign_journal(),"CodexCategory"+str(tab_category.id),TEAL if i==journal_category else PAPER)
		tab.add_theme_font_size_override("font_size",17)
	var category: Dictionary=categories[journal_category]
	var entries: Array=category.get("entries",[])
	var per_page: int=18
	var pages: int=maxi(1,ceili(float(entries.size())/per_page))
	journal_page=clampi(journal_page,0,pages-1)
	_at_label(left,"%s · 已发现 %d / %d" % [category.name,category.found,category.total],Rect2(26,78,462,29),21)
	var selection: Dictionary={}
	for i: int in range(journal_page*per_page,mini((journal_page+1)*per_page,entries.size())):
		var entry: Dictionary=entries[i]
		var n: int=i-journal_page*per_page
		var tile: Button=_at_button(left,"?" if not bool(entry.discovered) else "",Rect2(28+(n%6)*78,119+floori(n/6.0)*78,68,68),func() -> void: journal_selected=str(entry.id); show_campaign_journal(),"Codex"+str(entry.id),TEAL if journal_selected==str(entry.id) else PAPER)
		if bool(entry.discovered): _journal_icon(tile,str(entry.id),Rect2(5,5,58,58))
		if journal_selected==str(entry.id): selection=entry
	if selection.is_empty() and not entries.is_empty(): selection=entries[journal_page*per_page]
	_journal_pagination(left,pages,365)
	if not selection.is_empty():
		var found: bool=bool(selection.discovered)
		_at_label(right,str(selection.name) if found else "尚未发现",Rect2(28,25,460,36),26)
		if found: _journal_icon(right,str(selection.id),Rect2(135,79,245,204))
		else: _at_label(right,"?",Rect2(190,107,130,145),100).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var note: Label=_label(right,Campaign.codex_description(str(selection.id)) if found else "在旅途中遇见它，再把贴纸贴进手帐。",20)
		note.position=Vector2(30,299); note.size=Vector2(456,79)

func _journal_icon(parent: Control,id: String,rect: Rect2) -> void:
	var texture: Texture2D=_feedback_icon(id)
	if id.begins_with("C"): texture=preload("res://scripts/illustrated_atlas.gd").cat(id)
	if texture==null: return
	var picture: TextureRect=TextureRect.new()
	picture.texture=texture; picture.position=rect.position; picture.size=rect.size
	picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(picture)

func _journal_challenges(left: Control,right: Control) -> void:
	var challenges: Array=run.challenge_status() if run.has_method("challenge_status") else []
	var pages: int=maxi(1,ceili(float(challenges.size())/6))
	journal_page=clampi(journal_page,0,pages-1)
	for page: Control in [left,right]: _at_label(page,"走过的路，都留一枚印章",Rect2(26,20,464,30),22)
	for i: int in range(journal_page*6,mini((journal_page+1)*6,challenges.size())):
		var entry: Dictionary=challenges[i]
		var n: int=i-journal_page*6
		var page: Control=left if n<3 else right
		var row: Panel=_plate(page,Rect2(22,65+(n%3)*94,472,87),"Challenge"+str(entry.id))
		row.add_theme_stylebox_override("panel",_thin_paper())
		_at_label(row,"✓" if bool(entry.get("complete",false)) else "○",Rect2(12,19,47,45),31).add_theme_color_override("font_color",TEAL if bool(entry.get("complete",false)) else Color("a69b84"))
		_at_label(row,str(entry.get("name",entry.get("title",""))),Rect2(67,10,385,28),21)
		var detail: Label=_label(row,str(entry.get("detail","")),17)
		detail.position=Vector2(67,42); detail.size=Vector2(385,38)
	_journal_pagination(right,pages,365)
	_at_label(left,"纪念与称号 · 不增加永久战力",Rect2(27,367,460,25),18)

func _journal_pagination(parent: Control,pages: int,y: float) -> void:
	_at_button(parent,"‹",Rect2(24,y,62,35),func() -> void: journal_page=maxi(0,journal_page-1); show_campaign_journal(),"JournalPrevious").disabled=journal_page<=0
	_at_label(parent,"%d / %d" % [journal_page+1,pages],Rect2(185,y,140,30),19).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_at_button(parent,"›",Rect2(430,y,62,35),func() -> void: journal_page=mini(pages-1,journal_page+1); show_campaign_journal(),"JournalNext").disabled=journal_page>=pages-1

func show_memento(chapter: int) -> void:
	var unlocked: Array=run.s.get("campaign_progress",{}).get("profile",{}).get("mementos",[])
	if chapter not in unlocked: return
	var body: VBoxContainer=_modal("第%d章 · %s" % [chapter,Memento.TITLES[chapter-1]],"memento",1000,432)
	var art: Control=Memento.new()
	art.name="MementoLarge"; art.chapter=chapter; art.unlocked=unlocked.duplicate(); art.detail=true
	art.custom_minimum_size=Vector2(924,290)
	body.add_child(art)
	var back: Button=_button(body,"收回合照，翻回手帐",show_campaign_journal,"MementoBack")
	back.custom_minimum_size.y=44
	_focus_first()

func _threat_enemy(threat: Dictionary,index: int) -> String:
	if threat.has("enemy_id") and Data.enemies().has(str(threat.enemy_id)): return str(threat.enemy_id)
	if Data.enemies().has(str(threat.kind)): return str(threat.kind)
	var stage: Dictionary=Data.stages()[index]
	if str(threat.kind)=="elite": return str(stage.elite)
	if str(threat.kind)=="boss": return str(stage.boss)
	for candidate: int in ([7,8,9,2,1,0] if str(threat.kind) in ["air","confusion"] else [9,5,2,1,0]):
		if int(stage.counts[candidate])>0: return "E%02d" % (candidate+1)
	return "E01"

func _fish_intent(value: Dictionary) -> String:
	var words: Array[String]=[]
	for id: String in run.s.get("active",[]):
		if str(value.kind)==str(Data.cats()[id].favorites[0]):
			words.append("♥ "+str(Data.cats()[id].name))
			if Data.effective(value,id)>=3: words.append("机制已开")
			break
	if not matching(value).is_empty(): words.append("可合成")
	return " · ".join(words) if not words.is_empty() else "回家装配 · 升级开机制"

func _preferred_fish_slot(id: String) -> int:
	var slots: Array=run.equipped(id)
	for i: int in range(3):
		if slots[i].is_empty(): return i
	return 0

func _focus_cat_slot(id: String,slot: int) -> void:
	prep_focus_cat=id;prep_focus_slot=slot
	_close_cat_card();_hide_hint();_apply_prep_focus()

func _build_prep_focus_bar(parent: Control) -> void:
	prep_focus_bar=_plate(parent,Rect2(28,104,670,44),"PrepFocusRibbon")
	prep_focus_bar.add_theme_stylebox_override("panel",_thin_paper(Color("eaddbf")))

func _apply_prep_focus() -> void:
	if scene_mode!="home" or run.s.get("phase","")!="prep": return
	if prep_focus_cat not in run.s.get("active",[]): prep_focus_cat=str(run.s.active[0]) if not run.s.active.is_empty() else ""
	var focused: bool=not prep_focus_cat.is_empty()
	for key: String in ["StageMedal0","StageMedal1","StageMedal2","StageHighlight"]:
		var receipt: Control=scene_layer.find_child(key,true,false) as Control
		if receipt!=null: receipt.visible=false
	for id: String in room_actors:
		var chosen: bool=id==prep_focus_cat
		for i: int in range(3):
			var slot: Button=scene_layer.find_child("Slot"+id+str(i),true,false) as Button
			if slot==null: continue
			var selected: bool=chosen and i==prep_focus_slot
			for state: String in ["normal","hover","pressed"]: slot.add_theme_stylebox_override(state,Parchment.box("slot",Color("f1c869") if selected else Color.WHITE,2))
			if selected:
				slot.add_theme_stylebox_override("normal",Parchment.box("slot",Color("f1c869"),2))
	if is_instance_valid(prep_focus_bar):
		_clear(prep_focus_bar)
		prep_focus_bar.visible=focused
		if focused:
			_at_label(prep_focus_bar,"比较给 "+str(Data.cats()[prep_focus_cat].name),Rect2(12,8,178,28),20)
			for slot: int in range(3):
				var button: Button=_at_button(prep_focus_bar,"槽%d" % (slot+1),Rect2(196+slot*72,5,65,34),func() -> void: _focus_cat_slot(prep_focus_cat,slot),"CompareSlot%d" % slot,GOLD if slot==prep_focus_slot else PAPER)
				button.add_theme_font_size_override("font_size",17)
			var trial: Button=_at_button(prep_focus_bar,"比较试打 →" if practice_recent_changed else "试打 →",Rect2(459,5,196,34),func() -> void: _close_cat_card();controller.start_practice("single"),"ComparePractice",TEAL if practice_recent_changed else PAPER)
			trial.add_theme_font_size_override("font_size",18)
	_build_home_inventory()
	if is_instance_valid(camp_shop): camp_shop.focus_changed()

func highlight_shop_ingredients(ids: Array) -> void:
	if not is_instance_valid(home_inventory): return
	for fish: Dictionary in _loose_fish():
		var tile: Button=home_inventory.find_child("Fish"+str(fish.id),true,false) as Button
		if tile==null: continue
		var old: Node=tile.get_node_or_null("ShopMergeMark")
		if old!=null: _remove(old)
		if str(fish.id) in ids:
			tile.modulate=Color.WHITE
			tile.add_theme_stylebox_override("normal",Parchment.box("slot",Color("f8ca73"),2))
			var mark: Label=_at_label(tile,"合",Rect2(39,2,24,24),16)
			mark.name="ShopMergeMark";mark.add_theme_stylebox_override("normal",_thin_paper(GOLD))
		else:
			tile.add_theme_stylebox_override("normal",Parchment.box("slot",Color.WHITE,2))
			_decorate_focus_fish(tile,fish)

func _decorate_focus_fish(tile: Button,value: Dictionary) -> void:
	if prep_focus_cat.is_empty(): return
	var favorite: bool=str(value.kind) in Data.cats()[prep_focus_cat].favorites
	var mergeable: bool=not matching(value).is_empty()
	var worn_kind: bool=false
	for item: Dictionary in run.equipped(prep_focus_cat):
		if item.get("kind","")==value.kind: worn_kind=true
	var relevant: bool=favorite or mergeable or worn_kind
	tile.modulate=Color.WHITE if relevant else Color("ede7d9")
	tile.set_meta("focus_relevant",relevant)
	var old_mark: Node=tile.get_node_or_null("FocusFishMark")
	if old_mark!=null: _remove(old_mark)
	if not relevant: return
	var mark: Label=_at_label(tile,("♥" if favorite else "")+("↑" if mergeable else ""),Rect2(3,0,53,23),18)
	mark.name="FocusFishMark"
	mark.add_theme_color_override("font_color",CORAL if favorite else Color("547258"))
	mark.add_theme_color_override("font_outline_color",PAPER); mark.add_theme_constant_override("outline_size",3)

func _build_chapter_event_entry(parent: Control) -> void:
	if not run.has_method("chapter_event_status"): return
	var event: Dictionary=run.chapter_event_status()
	if not bool(event.get("available",false)): return
	var button: Button=_at_button(parent,"章间小摊 →",Rect2(718,110,280,36),show_chapter_event,"ChapterEvent",GOLD)
	_bind_hint(button,"章间小摊","每章一次 · 可直接离开",["修家、补一条指定鱼，或换走一件重复玩具。","选一项，或不花钱跳过。"] as Array[String])

func show_chapter_event() -> void:
	if not run.has_method("chapter_event_status"): return
	var event: Dictionary=run.chapter_event_status()
	if not bool(event.get("available",false)): return
	var body: VBoxContainer=_modal(str(event.get("title","章间小摊")),"chapter_event",1120,432)
	var center: Control=overlay.get_node("Center") as Control
	center.offset_top=84; center.offset_bottom=-62
	(body.get_parent() as PanelContainer).custom_minimum_size.y=550
	_label(body,"今晚剩下 %d 金币 · 挑一摊，或者空手继续赶路。" % int(run.s.gold),21)
	var stalls: Control=Control.new(); stalls.custom_minimum_size=Vector2(1056,343); body.add_child(stalls)
	var repair: Panel=_plate(stalls,Rect2(0,0,340,337),"EventRepairStall")
	var fish: Panel=_plate(stalls,Rect2(355,0,340,337),"EventFishStall")
	var exchange: Panel=_plate(stalls,Rect2(710,0,340,337),"EventExchangeStall")
	for stall: Panel in [repair,fish,exchange]: stall.add_theme_stylebox_override("panel",_sheet_paper())
	_at_label(repair,"修修补补",Rect2(25,19,290,30),24)
	_toy_icon(repair,"T11",Rect2(108,62,124,102))
	_at_label(repair,"花 %d 金币" % int(event.repair_cost),Rect2(28,177,284,29),22)
	_at_label(repair,"获得：回复 %s 点耐久" % str(snappedf(float(event.repair_amount),.1)),Rect2(28,216,284,28),20)
	var repair_button: Button=_at_button(repair,"修好猫爬架",Rect2(25,270,290,54),func() -> void: _take_chapter_event({"choice":"repair"}),"EventChooseRepair",TEAL)
	repair_button.disabled=int(run.s.gold)<int(event.repair_cost) or float(event.repair_amount)<=0
	if float(event.repair_amount)<=0: repair_button.text="耐久已经满了"
	_at_label(fish,"熟悉的鱼香",Rect2(25,19,290,30),24)
	var known: Array=event.get("known_fish",[])
	if event_fish not in known: event_fish=str(known[0]) if not known.is_empty() else ""
	_fish_static(fish,{"kind":event_fish if not event_fish.is_empty() else "F01","quality":0,"level":int(event.fish_level)},Rect2(114,64,111,96),true,false)
	_event_selector(fish,known,event_fish,Rect2(25,58,290,114),"EventFishSelect",func(id: String) -> void: event_fish=id; show_chapter_event(),true)
	_at_label(fish,"花 %d 金币" % int(event.fish_cost),Rect2(28,177,284,29),22)
	_at_label(fish,"获得：白色%s · %d级" % [Data.fish_name(event_fish) if not event_fish.is_empty() else "鱼干",int(event.fish_level)],Rect2(28,216,284,28),20)
	var fish_button: Button=_at_button(fish,"带走这条鱼",Rect2(25,270,290,54),func() -> void: _take_chapter_event({"choice":"fish","kind":event_fish}),"EventChooseFish",GOLD)
	fish_button.disabled=known.is_empty() or int(run.s.gold)<int(event.fish_cost)
	_at_label(exchange,"旧玩具换新",Rect2(25,19,290,30),24)
	var duplicates: Array=event.get("duplicates",[])
	var choices: Array=event.get("exchange_choices",[])
	if event_give not in duplicates: event_give=str(duplicates[0]) if not duplicates.is_empty() else ""
	if event_take not in choices: event_take=str(choices[0]) if not choices.is_empty() else ""
	if not event_give.is_empty(): _toy_icon(exchange,event_give,Rect2(48,72,83,76))
	if not event_take.is_empty(): _toy_icon(exchange,event_take,Rect2(210,72,83,76))
	_at_label(exchange,"→",Rect2(145,93,45,29),25)
	_event_selector(exchange,duplicates,event_give,Rect2(20,60,139,109),"EventGiveSelect",func(id: String) -> void: event_give=id; show_chapter_event(),false)
	_event_selector(exchange,choices,event_take,Rect2(181,60,139,109),"EventTakeSelect",func(id: String) -> void: event_take=id; show_chapter_event(),false)
	var cost: Label=_label(exchange,"付出："+(str(Data.toys()[event_give].name)+" ×1" if not event_give.is_empty() else "需要一件重复玩具"),19)
	cost.position=Vector2(25,177); cost.size=Vector2(292,38)
	var gain: Label=_label(exchange,"获得："+(str(Data.toys()[event_take].name)+" ×1" if not event_take.is_empty() else "暂无可交换玩具"),19)
	gain.position=Vector2(25,216); gain.size=Vector2(292,38)
	var exchange_button: Button=_at_button(exchange,"换一件 · 不花金币",Rect2(25,270,290,54),func() -> void: _take_chapter_event({"choice":"exchange","give":event_give,"take":event_take}),"EventChooseExchange",TEAL)
	exchange_button.disabled=duplicates.is_empty() or choices.is_empty()
	var skip: Button=_button(body,"这次不买，继续备战 →",func() -> void: _take_chapter_event({"choice":"skip"}),"EventSkip")
	skip.custom_minimum_size.y=48
	_apply_reading_size(); _focus_first()

func _event_selector(parent: Control,values: Array,current: String,rect: Rect2,key: String,change: Callable,fish: bool) -> void:
	if values.size()<=1: return
	var index: int=values.find(current)
	for direction: int in [-1,1]:
		var x: float=rect.position.x if direction<0 else rect.end.x-34
		var button: Button=_at_button(parent,"‹" if direction<0 else "›",Rect2(x,rect.position.y+30,34,44),func() -> void: change.call(str(values[posmod(index+direction,values.size())])),key+("Previous" if direction<0 else "Next"))
		button.add_theme_font_size_override("font_size",23)
	if fish: _at_label(parent,"%d / %d" % [index+1,values.size()],Rect2(rect.position.x+93,rect.end.y-14,104,22),16).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER

func _take_chapter_event(args: Dictionary) -> void:
	close_modal()
	dispatch("chapter_event",args)

func _request_merge_all() -> void:
	if run.s.get("phase","")!="prep": return
	# Run the exact existing merge order on an isolated, non-saving snapshot.
	# Preview cannot touch the live inventory, RNG, skill state or ledger.
	var probe: RefCounted=load("res://scripts/run_state.gd").new()
	probe.s=run.s.duplicate(true)
	probe.autosave=false
	var count: int=probe._merge_all_loose(true)
	var changed: Array[String]=[]
	for before: Dictionary in run.in_location("equipped"):
		var after: Dictionary=probe.item(str(before.id))
		if not after.is_empty() and int(after.level)>int(before.level):
			var cat: String=str(before.cat)
			var line: String="%s · %s　Lv.%d → %d" % [Data.cats()[cat].name,Data.fish_name(str(before.kind)),int(before.level),int(after.level)]
			var effective_before: int=Data.effective(before,cat)
			var effective_after: int=Data.effective(after,cat)
			if effective_before<3 and effective_after>=3: line+="　解锁 "+_fish_tag(str(before.kind))
			elif effective_before<5 and effective_after>=5: line+="　到达5级质变"
			changed.append(line)
	if changed.is_empty(): dispatch("merge_all");return
	var column: VBoxContainer=_modal("一键合成预览","merge_preview",1000,clampf(240+changed.size()*36,280,410))
	_label(column,"将完成 %d 次合成，以下已装备鱼干会升级：" % count,20)
	var list: VBoxContainer=_scroll(column,clampf(changed.size()*36,48,190))
	for line: String in changed: _label(list,line,20)
	_label(column,"其余仅合成闲置鱼；不会吞掉其他猫的装备。",18)
	var actions: HBoxContainer=_hbox(column)
	_button(actions,"确认合成",func() -> void: dispatch("merge_all"),"ConfirmMergeAll")
	_button(actions,"返回营地",show_prep,"CancelMergeAll")
	_focus_first()
