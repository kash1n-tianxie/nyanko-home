extends Button
const GameLocale=preload("res://scripts/game_locale.gd")
## A slanted ink-and-paper menu control. Its Button owns input/focus; its children own motion.
signal highlighted(action: String)

const INK: Color = Color("11131d")
const CREAM: Color = Color("fff4de")
const YELLOW: Color = Color("ffd13c")
const BLUE: Color = Color("132ba5")
const DISPLAY_FONT: Font = preload("res://fonts/japanese-v040/ui_title.tres")
const BODY_FONT: Font = preload("res://fonts/japanese-v040/ui_body.tres")

var action: String = ""
var caption: String = ""
var index: int = 0
var reduced: bool = false
var primary: bool = false
var compact: bool = false
var _hovered: bool = false
var _focused: bool = false
var _pressed: bool = false
var _highlight: float = 0.0
var _press: float = 0.0
var _motion: Tween
var _paper: Control

func setup(action_id: String, label_text: String, order: int, quiet: bool = false) -> void:
	action = action_id
	caption = label_text
	index = order
	reduced = quiet
	primary = order == 0
	name = action_id
	tooltip_text = "没有可继续的冒险" if action_id == "Resume" and disabled else ""
	accessibility_name = caption
	accessibility_description = "没有存档" if disabled else ""
	if is_node_ready(): queue_redraw()

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	for style: String in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(style, empty)
	text = ""
	_paper = Control.new()
	_paper.name = "AnimatedPaper"
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_paper)
	_paper.draw.connect(_draw_paper)
	mouse_entered.connect(func() -> void: _hovered = true; _state_changed())
	mouse_exited.connect(func() -> void: _hovered = false; _state_changed())
	focus_entered.connect(func() -> void: _focused = true; _state_changed())
	focus_exited.connect(func() -> void: _focused = false; _state_changed())
	button_down.connect(func() -> void: _pressed = true; _state_changed())
	button_up.connect(func() -> void: _pressed = false; _state_changed())
	resized.connect(func() -> void: _paper.queue_redraw())
	_paper.queue_redraw()

func _state_changed() -> void:
	var active: bool = (_hovered or _focused) and not disabled
	var next: float = 1.0 if active else 0.0
	if active and _highlight < 0.5: highlighted.emit(action)
	if _motion and _motion.is_valid(): _motion.kill()
	if reduced:
		_highlight = next
		_press = 1.0 if _pressed else 0.0
		_update_visual()
	else:
		_motion = create_tween().set_parallel(true)
		_motion.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_motion.tween_method(_set_highlight, _highlight, next, 0.15)
		_motion.tween_method(_set_press, _press, 1.0 if _pressed else 0.0, 0.09)

func _set_highlight(value: float) -> void:
	_highlight = value
	_update_visual()

func _set_press(value: float) -> void:
	_press = value
	_update_visual()

func _update_visual() -> void:
	if not is_instance_valid(_paper): return
	_paper.pivot_offset = size * 0.5
	_paper.position = Vector2(13.0 * _highlight, -2.0 * _highlight)
	_paper.rotation = 0.0 if reduced else deg_to_rad(-1.0 * _highlight)
	_paper.scale = Vector2.ONE * (1.0 - _press * 0.035)
	_paper.queue_redraw()

func _draw_paper() -> void:
	var w: float = size.x
	var h: float = size.y
	var paper: PackedVector2Array = PackedVector2Array([
		Vector2(13, 5), Vector2(w - 8, 0), Vector2(w - 21, h - 5), Vector2(0, h)
	])
	var shadow: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in paper: shadow.append(p + Vector2(5, 6))
	var normal: Color = YELLOW if primary else CREAM
	var fill: Color = normal.lerp(YELLOW, _highlight)
	var lettering: Color = INK
	if disabled:
		fill = Color("73768b")
		lettering = Color("313547")
	_paper.draw_colored_polygon(shadow, Color(0.02, 0.025, 0.06, 0.8))
	_paper.draw_colored_polygon(paper, fill)
	var outline: PackedVector2Array = paper.duplicate()
	outline.append(paper[0])
	_paper.draw_polyline(outline, INK, 2.5, true)
	# Ink tab stays aligned while the full paper slides, tilts, and compresses.
	var tab: PackedVector2Array = PackedVector2Array([
		Vector2(10, 9), Vector2(46, 8), Vector2(40, h-8), Vector2(3, h-6)
	])
	if not compact:
		_paper.draw_colored_polygon(tab, BLUE if _highlight > 0.1 else INK)
		_paper.draw_string(BODY_FONT, Vector2(15, h * 0.5 + 7),GameLocale.text("%02d" % (index+1)), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, CREAM)
	_paper.draw_string(DISPLAY_FONT, Vector2(18 if compact else 60, h * 0.5 + 10),GameLocale.text(caption), HORIZONTAL_ALIGNMENT_LEFT, w - (53 if compact else 102), 22 if compact else (29 if primary else 26), lettering)
	if _highlight > 0.01 and not disabled:
		var mark: Color = BLUE
		mark.a = _highlight
		var x: float = w - 42
		var y: float = h * 0.5
		_paper.draw_polyline(PackedVector2Array([Vector2(x-7,y-9),Vector2(x+4,y),Vector2(x-9,y+9)]),mark,4,true)
		for n: int in range(3):
			_paper.draw_line(Vector2(w - 73 + n * 6, 10),Vector2(w - 79 + n * 6, 20),mark,2,true)
	elif disabled:
		_paper.draw_arc(Vector2(w-40,h*0.5-3),5,PI,TAU,10,lettering,2,true)
		_paper.draw_rect(Rect2(w-47,h*0.5-3,14,11),lettering)
