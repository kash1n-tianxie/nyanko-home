extends Control
## Short two-part diagonal ink wipe. All input stays blocked until the reveal completes.
signal finished
var progress: float = 0.0:
	set(value):
		progress = value
		queue_redraw()
var motion: Tween

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	clip_contents = true

func start(change_scene: Callable, reduced: bool = false) -> void:
	if reduced:
		change_scene.call()
		finished.emit()
		return
	motion = create_tween()
	motion.tween_property(self,"progress",1.0,.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	motion.tween_callback(change_scene)
	motion.tween_interval(.045)
	motion.tween_property(self,"progress",2.0,.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	motion.tween_callback(func() -> void: finished.emit())

func _draw() -> void:
	if progress <= 0.0 or progress >= 2.0: return
	var w: float = size.x
	var h: float = size.y
	var lean: float = w * .17
	var edge: float = lerpf(-lean*1.4,w+lean*1.4,progress if progress <= 1.0 else progress-1.0)
	var shape: PackedVector2Array
	if progress <= 1.0:
		shape=PackedVector2Array([Vector2(-w,0),Vector2(edge+lean,0),Vector2(edge-lean,h),Vector2(-w,h)])
	else:
		shape=PackedVector2Array([Vector2(edge+lean,0),Vector2(w*2,0),Vector2(w*2,h),Vector2(edge-lean,h)])
	draw_colored_polygon(shape,Color("132ba5"))
	var stripe: PackedVector2Array=PackedVector2Array([Vector2(edge+lean-28,0),Vector2(edge+lean+28,0),Vector2(edge-lean+28,h),Vector2(edge-lean-28,h)])
	draw_colored_polygon(stripe,Color("ffd13c"))
	for i: int in range(13):
		var y: float = fmod(float(i)*83.0+29.0,h)
		var x: float = edge+lean-2.0*lean*y/h+sin(float(i)*4.7)*51.0
		draw_circle(Vector2(x,y),float(7+i%4*6),Color("ffd13c"))
		draw_circle(Vector2(x+34,y+19),float(3+i%3*2),Color("fff4de"))
