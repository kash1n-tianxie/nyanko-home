extends Control
const GameLocale=preload("res://scripts/game_locale.gd")
## Twenty-node paper itinerary. Progress is presentation only; run state owns rewards.
signal continued
signal node_hovered(index: int, anchor: Rect2)
signal hover_ended
const Data=preload("res://scripts/catalog.gd")
const Paper=preload("res://scripts/collage_theme.gd")
const Atlas=preload("res://scripts/illustrated_atlas.gd")
const Campaign=preload("res://scripts/campaign_presentation.gd")
const Art=preload("res://scripts/expansion_art.gd")
var from_index: int=0
var to_index: int=1
var reduced: bool=false
var finished: bool=false
var hop: float=0
var marker: Vector2
var continue_button: Button
var font: Font=preload("res://theme/main.tres").default_font
const COLORS: Array[Color]=[Color("b5c4a2"),Color("d4b58f"),Color("b1c4cf"),Color("b4a2c0"),Color("c6a6a1")]
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP
	for i: int in range(20):
		var button: Button=Button.new()
		button.name="RouteNode%d" % i
		button.position=node_position(i)-Vector2(24,27)
		button.size=Vector2(48,54)
		button.flat=true
		button.mouse_default_cursor_shape=Control.CURSOR_HELP
		button.mouse_entered.connect(func() -> void: node_hovered.emit(i,button.get_global_rect()))
		button.mouse_exited.connect(func() -> void: hover_ended.emit())
		button.focus_entered.connect(func() -> void: node_hovered.emit(i,button.get_global_rect()))
		button.focus_exited.connect(func() -> void: hover_ended.emit())
		add_child(button)
	continue_button=Button.new()
	continue_button.name="RouteContinue"
	continue_button.text="月亮，回家了！ →" if finished else "回家准备 →"
	continue_button.position=Vector2(943,603)
	continue_button.size=Vector2(262,60)
	continue_button.add_theme_font_size_override("font_size",24)
	continue_button.pressed.connect(func() -> void: continued.emit())
	add_child(continue_button)
	continue_button.disabled=not reduced
	marker=node_position(from_index)
	if reduced:
		hop=1
		marker=node_position(to_index)
		continue_button.grab_focus()
	else:
		var tween: Tween=create_tween()
		tween.tween_interval(.2)
		tween.tween_method(_set_hop,0.0,1.0,.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_callback(func() -> void: continue_button.disabled=false; continue_button.grab_focus())
	queue_redraw()
func _set_hop(value: float) -> void:
	hop=value
	marker=node_position(from_index).lerp(node_position(to_index),value)+Vector2(0,-sin(value*PI)*62)
	queue_redraw()
static func node_position(index: int) -> Vector2:
	var n: int=clampi(index,0,19)
	return Vector2(92+floori(float(n)/4)*238+(n%4)*48,355)
func _draw() -> void:
	draw_rect(Rect2(0,0,1280,720),Color("25252b"))
	# Two offset sheets make a visibly layered collage without a full-screen dimmer.
	draw_set_transform(Vector2(28,111),-.012)
	draw_rect(Rect2(0,0,1224,459),Color("a88965"))
	for j: int in range(38): draw_line(Vector2(20,18+j*11),Vector2(1200,18+j*11),Color("8c775e"),.5)
	draw_set_transform(Vector2.ZERO)
	draw_style_box(Paper.box("panel",Color.WHITE,0),Rect2(38,133,1204,420))
	draw_string(font,Vector2(62,76),GameLocale.text("追月路线"),HORIZONTAL_ALIGNMENT_LEFT,-1,40,Color("f5eedb"))
	draw_string(font,Vector2(65,101),GameLocale.text("%02d / 20" % (from_index+1)),HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("d0bc97"))
	for chapter: int in range(5):
		var left: float=62+chapter*238
		var rect: Rect2=Rect2(left,206,223,267)
		draw_style_box(Paper.box("panel",COLORS[chapter].lightened(.17),0),rect)
		var name_text: String=str(Data.CHAPTERS[chapter])
		draw_string(font,Vector2(left+24,243),GameLocale.text("%02d" % (chapter+1)),HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("373039"))
		@warning_ignore("integer_division") # Reveal whole four-stage chapters using the original integer quotient.
		Art.fit(self,Atlas.enemy("B%02d" % (chapter+1)),Rect2(left+70,251,122,81),Color.WHITE if chapter<=to_index/4 else Color("ffffff88"))
		draw_string(font,Vector2(left+24,396),GameLocale.text(["群体与快怪","护卫与空袭","增援与控场","施法与净化","组合总考验"][chapter]),HORIZONTAL_ALIGNMENT_LEFT,199,19,Color("6b5948"))
		draw_string(font,Vector2(left+24,437),GameLocale.text(name_text),HORIZONTAL_ALIGNMENT_LEFT,199,19,Color("373039"))
	for i: int in range(19):
		var start: Vector2=node_position(i)+Vector2(17,0)
		var finish: Vector2=node_position(i+1)-Vector2(17,0)
		draw_line(start,finish,Color("4b4545") if i<to_index else Color("9e958c"),2,true)
		var tip: Vector2=finish-Vector2(2,0)
		draw_line(tip,tip+Vector2(-4,-3),Color("655e58"),2,true)
	for i: int in range(20):
		var p: Vector2=node_position(i)
		var ink: Color=Color("52464c")
		var fill: Color=Color("edcf7e") if i<=from_index else Color("e3dbce")
		var rank: int=i%4
		if rank==1:
			draw_style_box(Paper.box("slot",Color("b99cc8"),0),Rect2(p-Vector2(16,15),Vector2(32,30)))
			draw_string(font,p+Vector2(-7,7),GameLocale.text("★"),HORIZONTAL_ALIGNMENT_LEFT,-1,19,ink)
		elif rank==3:
			draw_circle(p,17,Color("bb6967"))
			draw_arc(p,17,0,TAU,24,ink,2,true)
			draw_circle(p+Vector2(-5,-2),3,Color("f5eedb"))
			draw_circle(p+Vector2(5,-2),3,Color("f5eedb"))
			draw_line(p+Vector2(-5,6),p+Vector2(5,6),ink,3,true)
		else:
			draw_circle(p,14,fill)
			draw_arc(p,14,0,TAU,24,ink,2,true)
		if i<to_index: draw_line(p+Vector2(-6,0),p+Vector2(-1,5),Color("496c53"),3,true); draw_line(p+Vector2(-1,5),p+Vector2(8,-6),Color("496c53"),3,true)
		if i==to_index: draw_arc(p,23,0,TAU,32,Color("f7f1df"),3,true)
	_draw_head(marker+Vector2(0,-39))
	draw_string(font,Vector2(68,617),GameLocale.text("● 遭遇   ★ 精英·三选一   ◉ 首领·四选一"),HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("ded4be"))
	draw_string(font,Vector2(68,649),GameLocale.text("玩具留在猫爬架，跟着整支猫队出发。"),HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("b8aa96"))
func _draw_head(p: Vector2) -> void:
	var shape: PackedVector2Array=PackedVector2Array([p+Vector2(-20,7),p+Vector2(-22,-22),p+Vector2(-7,-13),p+Vector2(7,-13),p+Vector2(22,-22),p+Vector2(20,7),p+Vector2(9,18),p+Vector2(-9,18),p+Vector2(-20,7)])
	draw_colored_polygon(shape,Color("f5d485"))
	draw_polyline(shape,Color("26232a"),3,true)
	draw_circle(p+Vector2(-8,-1),3,Color("26232a"))
	draw_circle(p+Vector2(8,-1),3,Color("26232a"))
	draw_line(p+Vector2(-3,7),p+Vector2(0,10),Color("26232a"),2,true)
	draw_line(p+Vector2(0,10),p+Vector2(3,7),Color("26232a"),2,true)
