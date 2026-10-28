extends Control
const GameLocale=preload("res://scripts/game_locale.gd")
## Self-contained title screen. The runtime coordinator owns all actions and saves.
signal action_requested(action: String)
signal hovered(action: String)

const InkMenuButton = preload("res://scripts/front_menu_button.gd")
const INK: Color = Color("11131d")
const CREAM: Color = Color("fff4de")
const YELLOW: Color = Color("ffd13c")
const BLUE: Color = Color("132ba5")
const DISPLAY_FONT: Font = preload("res://fonts/japanese-v040/ui_title.tres")
const BODY_FONT: Font = preload("res://fonts/japanese-v040/ui_body.tres")
const HERO_PATH: String = "res://art/front-v029/menu-hero.png"
const DESIGN_SIZE: Vector2 = Vector2(1280, 720)

var reduced: bool = false
var _has_save: bool = false
var _built: bool = false
var _canvas: Control
var _hero: TextureRect
var _ornament: Control
var _title: Control
var _buttons: Array[Button] = []
var _language_switch: Button
var _intro: Tween
var _reaction: Tween
var _reaction_value: float = 0.0
var _active_index: int = 0
var _parallax: Vector2 = Vector2.ZERO
var _clock: float = 0.0
var _locked: bool = false

func setup(has_save: bool, quiet: bool = false) -> void:
	_has_save = has_save
	reduced = quiet
	if not _built: _build()
	for button: Button in _buttons:
		button.set("reduced",reduced)
		if button.name == "Resume":
			button.disabled = not _has_save
			button.tooltip_text = "没有可继续的冒险" if not _has_save else ""
			button.accessibility_description = "没有存档" if not _has_save else ""
			button.get_node("AnimatedPaper").queue_redraw()
	_configure_focus()
	call_deferred("_enter")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(_layout)
	if not _built: _build()
	_layout()

func _build() -> void:
	_built = true
	_canvas = Control.new()
	_canvas.name = "MenuCanvas"
	_canvas.size = DESIGN_SIZE
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_hero = TextureRect.new()
	_hero.name = "MenuHero"
	_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_hero.position = Vector2(180,65)
	_hero.size = Vector2(1120,630)
	if ResourceLoader.exists(HERO_PATH): _hero.texture = load(HERO_PATH)
	_canvas.add_child(_hero)
	_ornament = Control.new()
	_ornament.name = "InkAndPaper"
	_ornament.size = DESIGN_SIZE
	_ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_ornament)
	_ornament.draw.connect(_draw_ornaments)
	_title = Control.new()
	_title.name = "Title"
	_title.position = Vector2(48,58)
	_title.size = Vector2(410,205)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_title)
	_title.draw.connect(_draw_title)
	var labels: Array[String] = ["开始新冒险", "继续冒险", "漫画序章", "声音与效果", "离开"]
	var actions: Array[String] = ["NewGame", "Resume", "ReplayStory", "MenuSettings", "ExitGame"]
	for i: int in range(actions.size()):
		var button: Button = InkMenuButton.new()
		button.position = Vector2(56+i*3,285+i*65)
		button.size = Vector2(355,57)
		button.disabled = actions[i] == "Resume" and not _has_save
		button.setup(actions[i], labels[i], i, reduced)
		_canvas.add_child(button)
		button.pressed.connect(_activate.bind(actions[i]))
		button.highlighted.connect(_hover_action)
		_buttons.append(button)
	_language_switch=Button.new()
	_language_switch.name="TitleLanguageSwitch"
	_language_switch.position=Vector2(1030,22)
	_language_switch.size=Vector2(222,40)
	_language_switch.text="日本語 / 简体中文"
	_language_switch.add_theme_font_size_override("font_size",18)
	_language_switch.pressed.connect(func() -> void:
		GameLocale.set_language("zh_CN" if GameLocale.current_language()=="ja" else "ja")
	)
	_canvas.add_child(_language_switch)
	_configure_focus()
	_layout()

func _configure_focus() -> void:
	var enabled: Array[Button] = []
	for button: Button in _buttons:
		button.focus_mode = Control.FOCUS_NONE if button.disabled else Control.FOCUS_ALL
		if not button.disabled: enabled.append(button)
	for i: int in range(enabled.size()):
		enabled[i].focus_neighbor_top = enabled[(i+enabled.size()-1)%enabled.size()].get_path()
		enabled[i].focus_neighbor_bottom = enabled[(i+1)%enabled.size()].get_path()
		enabled[i].focus_previous = enabled[(i+enabled.size()-1)%enabled.size()].get_path()
		enabled[i].focus_next = enabled[(i+1)%enabled.size()].get_path()

func _layout() -> void:
	if not is_instance_valid(_canvas): return
	var canvas_scale: float = minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	if canvas_scale <= 0: canvas_scale = 1.0
	_canvas.scale = Vector2.ONE * canvas_scale
	_canvas.position = (size - DESIGN_SIZE * canvas_scale) * 0.5
	queue_redraw()

func _enter() -> void:
	if not is_inside_tree(): return
	_locked = false
	if _intro and _intro.is_valid(): _intro.kill()
	if reduced:
		_title.modulate.a = 1.0
		for button: Button in _buttons:
			button.modulate.a = 1.0
			button.position.x = 56 + int(button.get("index")) * 3
	else:
		_intro = create_tween().set_parallel(true)
		_title.modulate.a = 0.0
		_title.position.x = 12
		_intro.tween_property(_title,"modulate:a",1.0,0.3)
		_intro.tween_property(_title,"position:x",48.0,0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		for i: int in range(_buttons.size()):
			var button: Button = _buttons[i]
			button.modulate.a = 0.0
			button.position.x = -100
			_intro.tween_property(button,"modulate:a",1.0,0.18).set_delay(0.04*i)
			_intro.tween_property(button,"position:x",56.0+i*3,0.3).set_delay(0.04*i).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_buttons[0].grab_focus()

func _process(delta: float) -> void:
	if not visible or not is_visible_in_tree() or not _built: return
	if reduced:
		_hero.position = Vector2(180,65)
		return
	_clock += delta
	var pointer: Vector2 = _canvas.get_local_mouse_position() / DESIGN_SIZE - Vector2(0.5,0.5)
	pointer = pointer.clamp(Vector2(-0.5,-0.5),Vector2(0.5,0.5))
	_parallax = _parallax.lerp(pointer*10.0,1.0-exp(-delta*4.0))
	_hero.position = Vector2(180,65) + _parallax + Vector2(_reaction_value * 5.0, -_reaction_value * 3.0)
	if _reaction_value > 0: _ornament.queue_redraw()

func _hover_action(action: String) -> void:
	_active_index = ["NewGame","Resume","ReplayStory","MenuSettings","ExitGame"].find(action)
	if _reaction and _reaction.is_valid(): _reaction.kill()
	if not reduced:
		_reaction_value = 1.0
		_reaction = create_tween()
		_reaction.tween_property(self,"_reaction_value",0.0,0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_ornament.queue_redraw()
	hovered.emit(action)

func _activate(action: String) -> void:
	if _locked: return
	_locked = true
	action_requested.emit(action)
	# A modal may keep this screen alive; the coordinator need not rebuild it to unlock.
	call_deferred("_unlock")

func _unlock() -> void:
	_locked = false

func refresh_hero() -> void:
	if _built and ResourceLoader.exists(HERO_PATH): _hero.texture = load(HERO_PATH)

func focus_default() -> void:
	if not _buttons.is_empty(): _buttons[0].grab_focus()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),INK)

func _draw_ornaments() -> void:
	# Asymmetric ink curtain reserves left navigation and keeps the artwork readable.
	_ornament.draw_colored_polygon(PackedVector2Array([Vector2.ZERO,Vector2(483,0),Vector2(407,720),Vector2(0,720)]),INK)
	_ornament.draw_colored_polygon(PackedVector2Array([Vector2(449,0),Vector2(486,0),Vector2(410,720),Vector2(390,720)]),BLUE)
	_ornament.draw_colored_polygon(PackedVector2Array([Vector2(0,0),Vector2(770,0),Vector2(709,24),Vector2(0,42)]),BLUE)
	_ornament.draw_colored_polygon(PackedVector2Array([Vector2(0,681),Vector2(555,665),Vector2(539,720),Vector2(0,720)]),BLUE)
	_ornament.draw_colored_polygon(PackedVector2Array([Vector2(1058,0),Vector2(1280,0),Vector2(1280,57)]),INK)
	_ornament.draw_colored_polygon(PackedVector2Array([Vector2(1066,696),Vector2(1280,648),Vector2(1280,720),Vector2(1047,720)]),INK)
	for row: int in range(7):
		for col: int in range(13):
			_ornament.draw_circle(Vector2(12+col*18+row%2*9,145+row*18),1.6,Color(1,0.96,0.87,0.07))
	for row: int in range(4):
		for col: int in range(9):
			_ornament.draw_circle(Vector2(1089+col*20,630+row*18),1.7,Color(1,0.82,0.24,0.35))
	_ornament.draw_line(Vector2(453,46),Vector2(468,18),YELLOW,5,true)
	_ornament.draw_line(Vector2(460,55),Vector2(482,22),CREAM,3,true)
	_ornament.draw_string(BODY_FONT,Vector2(59,696),GameLocale.text("月亮失窃 · 猫咪出动"),HORIZONTAL_ALIGNMENT_LEFT,-1,17,CREAM)
	# Small ink bursts respond at different edges of the illustration, never covering faces.
	if _reaction_value > 0.01:
		var centers: Array[Vector2] = [Vector2(590,126),Vector2(1139,120),Vector2(589,557),Vector2(1167,505),Vector2(993,646)]
		var origin: Vector2 = centers[clampi(_active_index,0,4)]
		var color: Color = YELLOW
		color.a = _reaction_value
		for i: int in range(3):
			var angle: float = -0.7+i*0.55
			var direction: Vector2 = Vector2(cos(angle),sin(angle))
			_ornament.draw_line(origin+direction*10,origin+direction*(23+_reaction_value*10),color,4,true)

func _draw_title() -> void:
	var tag: PackedVector2Array = PackedVector2Array([Vector2(12,0),Vector2(195,0),Vector2(184,29),Vector2(0,34)])
	_title.draw_colored_polygon(tag,YELLOW)
	_title.draw_string(BODY_FONT,Vector2(18,23),GameLocale.text("六只猫，一轮月亮。"),HORIZONTAL_ALIGNMENT_LEFT,-1,17,INK)
	_title.draw_string_outline(DISPLAY_FONT,Vector2(5,116),GameLocale.text("猫猫家园"),HORIZONTAL_ALIGNMENT_LEFT,-1,50 if GameLocale.current_language()=="ja" else 79,8,BLUE)
	_title.draw_string(DISPLAY_FONT,Vector2(0,109),GameLocale.text("猫猫家园"),HORIZONTAL_ALIGNMENT_LEFT,-1,50 if GameLocale.current_language()=="ja" else 79,CREAM)
	_title.draw_colored_polygon(PackedVector2Array([Vector2(5,126),Vector2(347,115),Vector2(340,125),Vector2(0,137)]),YELLOW)
	_title.draw_string(BODY_FONT,Vector2(11,171),GameLocale.text("猫咪和它的小鱼干"),HORIZONTAL_ALIGNMENT_LEFT,-1,24,CREAM)
