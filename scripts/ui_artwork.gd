extends Control
## Small hand-drawn native decorations. No simulation state or random calls.
const FishArt = preload("res://scripts/fish_art.gd")

var motif: String = "fish"
var kind: String = "F01"
var quality: int = 0
var cat_id: String = "C01"
var color: Color = Color("eee4d8")
var phase: float = 0.0
var ink: Color = Color("393349")
var cats_texture: Texture2D
var cat_pose: String = "idle"
var preview_enabled: bool = false
var cat_atlas: Script

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if motif=="cat" and ResourceLoader.exists("res://scripts/illustrated_atlas.gd"):
		cat_atlas = load("res://scripts/illustrated_atlas.gd") as Script
		cats_texture = cat_atlas.cat(cat_id) as Texture2D
		if preview_enabled:
			mouse_filter = Control.MOUSE_FILTER_PASS
			mouse_entered.connect(func() -> void: set_cat_pose("attack"))
			mouse_exited.connect(func() -> void: set_cat_pose("idle"))
	queue_redraw()

func set_cat_pose(value: String) -> void:
	if motif!="cat" or cat_atlas==null: return
	cat_pose = value
	cats_texture = cat_atlas.cat(cat_id,cat_pose) as Texture2D
	queue_redraw()

func polygon(points: Array, fill: Color, width: float = 2.3) -> void:
	var vertices: PackedVector2Array = PackedVector2Array(points)
	draw_colored_polygon(vertices,fill)
	vertices.append(vertices[0])
	draw_polyline(vertices,ink,width,true)

func oval(p: Vector2, radius: Vector2, fill: Color, width: float = 2.4) -> void:
	var points: Array = []
	for i: int in range(41): points.append(p+Vector2(cos(i*TAU/40)*radius.x,sin(i*TAU/40)*radius.y))
	polygon(points,fill,width)

func _draw() -> void:
	match motif:
		"fish": _fish()
		"cat": _cat()
		"pond": _pond()
		"basket": _basket()
		"paw": _paw()
		"sun": _sun()
		"tape": _tape()

func _fish() -> void:
	var icon: Texture2D = FishArt.texture(kind)
	var tint: Color = [Color("d5c9b4"),Color("84b9d6"),Color("dfb45a")][clampi(quality,0,2)]
	var available: Vector2 = size-Vector2(10,17)
	var icon_size: Vector2 = icon.get_size()*minf(available.x/icon.get_width(),available.y/icon.get_height())
	var halo_size: float = minf(size.x,size.y)*.4
	draw_circle(size*.5-Vector2(0,5),halo_size,Color(tint,.15))
	draw_texture_rect(icon,Rect2((size-icon_size)*.5-Vector2(0,4),icon_size),false)
	for i: int in range(quality+1):
		var x: float = size.x*.5+(i-quality*.5)*12
		draw_line(Vector2(x-3,size.y-6),Vector2(x+3,size.y-6),tint.darkened(.15),3,true)

func _native_fish() -> void:
	draw_set_transform(Vector2.ZERO,0,size/Vector2(120,100))
	var accents: Array[Color] = [Color("e9b46e"),Color("ec8e6f"),Color("83baa9"),Color("8cc6e8"),Color("9bc99a"),Color("dfc470"),Color("c4abd8"),Color("baaa91")]
	var index: int = clampi(int(kind.substr(1))-1,0,7)
	var fill: Color = accents[index]
	var quality_color: Color = [Color("ded5c5"),Color("9ac7dd"),Color("edc471")][clampi(quality,0,2)]
	draw_circle(Vector2(58,49),39,Color(fill,.18))
	for i: int in range(quality+1):
		draw_line(Vector2(40+i*14,91),Vector2(48+i*14,91),quality_color.darkened(.2),4,true)
	if index==5:
		# Electric eel: long curling body, broken lightning stripe.
		var eel: PackedVector2Array = []
		for i: int in range(22): eel.append(Vector2(20+i*3.6,52+sin(float(i)*.27)*17))
		draw_polyline(eel,ink,21,true)
		draw_polyline(eel,fill,16,true)
		draw_circle(Vector2(94,46),14,ink)
		draw_circle(Vector2(94,46),11,fill)
		draw_circle(Vector2(98,44),2.8,ink)
		draw_polyline(PackedVector2Array([Vector2(39,52),Vector2(51,45),Vector2(48,61),Vector2(64,54)]),Color("fff7e8"),3,true)
	elif index==7:
		# Plump armored fish with overlapping shell plates.
		polygon([Vector2(87,46),Vector2(107,30),Vector2(105,64)],fill)
		oval(Vector2(58,47),Vector2(35,28),fill)
		for dx: int in [0,15]: draw_arc(Vector2(58+dx,47),24,PI*.58,PI*1.42,24,ink,2,true)
		draw_circle(Vector2(34,43),3,ink)
		polygon([Vector2(57,20),Vector2(65,10),Vector2(72,23)],fill)
	else:
		polygon([Vector2(85,46),Vector2(106,29),Vector2(107,64)],fill)
		oval(Vector2(56,46),Vector2(35,21),fill)
		polygon([Vector2(52,28),Vector2(60,13),Vector2(73,29)],fill)
		polygon([Vector2(59,63),Vector2(71,73),Vector2(76,57)],fill)
		draw_circle(Vector2(34,42),3.7,ink)
		draw_circle(Vector2(33,41),1.1,Color.WHITE)
		draw_arc(Vector2(37,48),15,-.8,.8,12,ink,1.7,true)
		if index==0:
			polygon([Vector2(20,47),Vector2(1,48),Vector2(25,53)],fill)
			draw_line(Vector2(53,45),Vector2(78,45),Color("fff5da"),4,true)
		elif index==1:
			for dx: int in [0,11,22]: draw_line(Vector2(52+dx,32),Vector2(45+dx,57),Color("a6604d"),3,true)
			polygon([Vector2(49,18),Vector2(46,4),Vector2(55,10),Vector2(63,1),Vector2(66,19)],Color("efa56d"))
		elif index==2:
			draw_arc(Vector2(60,47),36,.25,PI*1.55,30,Color("659c91"),3,true)
			polygon([Vector2(61,10),Vector2(70,14),Vector2(61,19)],Color("83baa9"))
		elif index==3:
			for p: Vector2 in [Vector2(15,24),Vector2(89,13),Vector2(94,76)]:
				polygon([p+Vector2(0,-7),p+Vector2(5,0),p+Vector2(0,7),p+Vector2(-5,0)],Color("d6f2ff"),1.5)
			draw_line(Vector2(54,35),Vector2(70,56),Color("edfaff"),3,true)
		elif index==4:
			polygon([Vector2(60,22),Vector2(46,5),Vector2(66,10),Vector2(70,23)],Color("99bd7c"))
			draw_line(Vector2(61,14),Vector2(65,24),ink,1.7,true)
			for p: Vector2 in [Vector2(56,42),Vector2(69,49),Vector2(60,56)]: draw_circle(p,3,Color("699c73"))
		elif index==6:
			for p: Vector2 in [Vector2(51,44),Vector2(65,38),Vector2(71,51)]:
				draw_circle(p,6,Color("fffaf1"))
				draw_arc(p,6,0,TAU,18,Color("9683a9"),1.4,true)
	draw_set_transform(Vector2.ZERO)

func _cat() -> void:
	if cats_texture!=null:
		var inset: Vector2 = Vector2(2,2)
		var extent: Vector2 = cats_texture.get_size()
		var fitted: Vector2 = extent*minf((size.x-inset.x)/extent.x,(size.y-inset.y)/extent.y)
		draw_texture_rect(cats_texture,Rect2((size-fitted)*.5,fitted),false)
		return
	draw_set_transform(Vector2.ZERO,0,size/Vector2(120,100))
	var p: Vector2 = Vector2(60,54)
	for side: int in [-1,1]:
		polygon([p+Vector2(side*29,-5),p+Vector2(side*29,-38),p+Vector2(side*6,-23)],color)
		polygon([p+Vector2(side*24,-17),p+Vector2(side*24,-29),p+Vector2(side*15,-23)],Color("eeb5ae"),1.4)
	oval(p,Vector2(33,28),color)
	for side: int in [-1,1]:
		draw_circle(p+Vector2(side*12,-3),3,ink)
		draw_circle(p+Vector2(side*23,8),5,Color("eaa5a0"))
		for dy: int in [1,8]: draw_line(p+Vector2(side*27,dy),p+Vector2(side*38,dy-2),ink,1.6,true)
	polygon([p+Vector2(-3,4),p+Vector2(3,4),p+Vector2(0,7)],ink,1)
	draw_arc(p+Vector2(-4,7),4,0,PI,10,ink,1.5,true)
	draw_arc(p+Vector2(4,7),4,0,PI,10,ink,1.5,true)
	draw_set_transform(Vector2.ZERO)

func _pond() -> void:
	draw_set_transform(Vector2.ZERO,0,size/Vector2(300,172))
	oval(Vector2(123,99),Vector2(134,65),Color("a8c9c2"),3)
	oval(Vector2(123,99),Vector2(123,55),Color("87b5b4"),2)
	for p: Vector2 in [Vector2(42,105),Vector2(132,54),Vector2(101,130)]:
		draw_arc(p,22,0,TAU,30,Color("dceee2"),2,true)
		oval(p,Vector2(15,7),Color("8fa57b"),1.5)
		draw_line(p,p+Vector2(10,4),Color("bac797"),1.5,true)
	draw_arc(Vector2(77,90),25,0,TAU,30,Color("ebf6ea"),2,true)
	draw_arc(Vector2(77,90),16,0,TAU,30,Color("ebf6ea"),1.5,true)
	draw_line(Vector2(142,9),Vector2(77,89),Color("fff7e8"),2,true)
	draw_line(Vector2(139,8),Vector2(230,169),ink,8,true)
	draw_line(Vector2(140,8),Vector2(230,169),Color("bf916d"),4,true)
	oval(Vector2(77,86),Vector2(6,9),Color("f0eee0"),2)
	draw_circle(Vector2(77,82),5,Color("e7847e"))
	for p: Vector2 in [Vector2(20,35),Vector2(276,125),Vector2(237,40)]:
		polygon([p,p+Vector2(-8,-25),p+Vector2(5,-12)],Color("8eaf81"),1.5)
		polygon([p,p+Vector2(18,-18),p+Vector2(13,-1)],Color("b5c39b"),1.5)
	draw_set_transform(Vector2.ZERO)

func _basket() -> void:
	draw_set_transform(Vector2.ZERO,0,size/Vector2(120,100))
	var wicker: Color = Color("dcba84")
	polygon([Vector2(14,36),Vector2(105,36),Vector2(95,85),Vector2(25,85)],wicker)
	for x: int in range(29,96,10): draw_line(Vector2(x,40),Vector2(x,82),Color("ac8d68"),1.5,true)
	for y: int in range(46,81,9): draw_line(Vector2(21,y),Vector2(99,y),Color("ac8d68"),1.5,true)
	draw_arc(Vector2(60,39),34,PI,TAU,24,ink,6,true)
	draw_arc(Vector2(60,39),34,PI,TAU,24,wicker,3,true)
	for p: Vector2 in [Vector2(39,32),Vector2(64,24),Vector2(83,34)]:
		polygon([p+Vector2(8,-1),p+Vector2(14,-10),p+Vector2(15,5)],Color("a3bac9"),1.6)
		oval(p,Vector2(15,7),Color("a3bac9"),1.8)
		draw_circle(p+Vector2(-8,-1),1.8,ink)
	var label_box: StyleBoxFlat = StyleBoxFlat.new()
	label_box.bg_color = Color("fff4dd")
	label_box.border_color = ink
	label_box.set_border_width_all(2)
	label_box.set_corner_radius_all(4)
	draw_style_box(label_box,Rect2(35,49,48,23))
	draw_set_transform(Vector2.ZERO)

func _paw() -> void:
	draw_set_transform(Vector2.ZERO,0,size/Vector2(60,60))
	draw_circle(Vector2(30,30),27,ink)
	draw_circle(Vector2(30,30),24,Color("fff7e8"))
	for p: Vector2 in [Vector2(14,24),Vector2(25,15),Vector2(38,16),Vector2(46,28)]: oval(p,Vector2(5,7),Color("e38e82"),.8)
	polygon([Vector2(17,41),Vector2(19,32),Vector2(30,27),Vector2(41,34),Vector2(43,43),Vector2(35,45),Vector2(29,41),Vector2(23,46)],Color("e38e82"),.8)
	draw_set_transform(Vector2.ZERO)

func _sun() -> void:
	draw_set_transform(Vector2.ZERO,0,size/Vector2(60,60))
	var center: Vector2 = Vector2(30,30)
	draw_circle(center,11,color)
	draw_arc(center,11,0,TAU,28,ink,2,true)
	for i: int in range(8):
		var ray: Vector2 = Vector2.from_angle(i*TAU/8)
		draw_line(center+ray*17,center+ray*23,ink,2,true)
	draw_set_transform(Vector2.ZERO)

func _tape() -> void:
	draw_set_transform(Vector2.ZERO,0,size/Vector2(60,20))
	polygon([Vector2(0,2),Vector2(59,0),Vector2(57,19),Vector2(2,18)],Color(color,.85),1)
	for x: int in range(3,56,7):
		draw_line(Vector2(x,3),Vector2(x+4,3),Color("fff7e8"),1,true)
		draw_line(Vector2(x,16),Vector2(x+4,16),Color("fff7e8"),1,true)
	draw_set_transform(Vector2.ZERO)
