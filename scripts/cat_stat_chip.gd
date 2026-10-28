extends Control
const GameLocale=preload("res://scripts/game_locale.gd")
## Attack left / attacks per second right, with actual live values supplied by the model.
const Paper=preload("res://scripts/collage_theme.gd")
var attack: float=0
var rate: float=0
var compact: bool=false
var font: Font=preload("res://theme/main.tres").default_font
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
func set_values(value: float, speed: float) -> void:
	if not is_equal_approx(attack,value) or not is_equal_approx(rate,speed):
		attack=value
		rate=speed
		queue_redraw()
func _draw() -> void:
	draw_pair(self,Vector2.ZERO,size.x,attack,rate,font,19 if get_window().size.x<1120 else (15 if compact else 17))
static func draw_pair(canvas: CanvasItem, point: Vector2, span: float, power: float, aps: float, typeface: Font, text_size: int=14) -> void:
	var h: float=text_size+10
	var half: float=span*.5-2
	for side: int in range(2):
		var p: Vector2=point+Vector2(side*(half+4),0)
		canvas.draw_style_box(Paper.box("strip",Color.WHITE,2),Rect2(p,Vector2(half,h)))
		var icon: Vector2=p+Vector2(12,h*.52)
		var color: Color=Color("b84d45") if side==0 else Color("437c79")
		if side==0:
			canvas.draw_line(icon+Vector2(-4,5),icon+Vector2(5,-5),color,3,true)
			canvas.draw_line(icon+Vector2(-5,1),icon+Vector2(0,6),color,2,true)
			canvas.draw_colored_polygon(PackedVector2Array([icon+Vector2(2,-5),icon+Vector2(7,-7),icon+Vector2(5,-2)]),color)
		else:
			canvas.draw_arc(icon,6,-PI*.7,PI*.7,14,color,1.8,true)
			canvas.draw_line(icon,icon+Vector2(3,-3),color,1.8,true)
			canvas.draw_line(icon+Vector2(-3,-8),icon+Vector2(3,-8),color,1.5,true)
		var value: String=("%d" % roundi(power)) if side==0 else ("%.1f/秒" % aps)
		canvas.draw_string(typeface,p+Vector2(23,h-6),GameLocale.text(value),HORIZONTAL_ALIGNMENT_LEFT,half-24,mini(text_size,14) if side==1 else text_size,Paper.INK)
