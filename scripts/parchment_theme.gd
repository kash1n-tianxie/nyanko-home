extends RefCounted
## Painted paper and leather surfaces share one atlas, with OFL handwriting fonts.
## Text, focus and enabled states stay separate from the illustration.
const INK: Color=Color("392b20")
const PAPER: Color=Color("e8cf9f")
const ROOT: String="res://art/parchment-v027/"
static var textures: Dictionary={}

static func texture(kind: String) -> Texture2D:
	if textures.has(kind): return textures[kind]
	var path: String=ROOT+kind+".png"
	if ResourceLoader.exists(path):
		textures[kind]=load(path) as Texture2D
		return textures[kind]
	var sheet_path: String=ROOT+"ui-sheet.png"
	var regions_path: String=ROOT+"ui-regions.json"
	if ResourceLoader.exists(sheet_path) and FileAccess.file_exists(regions_path):
		var metadata: Variant=JSON.parse_string(FileAccess.get_file_as_string(regions_path))
		var regions: Dictionary=metadata.get("regions",metadata) if metadata is Dictionary else {}
		if regions.has(kind):
			var rect: Array=regions[kind]
			var atlas: AtlasTexture=AtlasTexture.new()
			atlas.atlas=load(sheet_path) as Texture2D
			atlas.region=Rect2(rect[0],rect[1],rect[2],rect[3])
			textures[kind]=atlas
			return atlas
	return null

static func box(kind: String="panel", tint: Color=Color.WHITE, margin: float=12) -> StyleBox:
	var surface: Texture2D=texture(kind)
	var result: StyleBox
	if surface!=null:
		var painted: StyleBoxTexture=StyleBoxTexture.new()
		painted.texture=surface
		painted.modulate_color=tint
		# Small normalized crops keep the ragged perimeter at its real pixel size.
		var edge: float={"strip":7.0,"button":9.0,"panel":17.0,"leather":9.0,"slot":8.0,"rivet":0.0}.get(kind,10.0)
		for side: int in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]: painted.set_texture_margin(side,edge)
		result=painted
	else:
		# Only used before the painted atlas import has completed.
		var fallback: StyleBoxFlat=StyleBoxFlat.new()
		fallback.bg_color=PAPER*tint
		fallback.border_color=INK
		fallback.set_border_width_all(2)
		result=fallback
	result.content_margin_left=margin
	result.content_margin_right=margin
	result.content_margin_top=margin
	result.content_margin_bottom=margin
	return result

static func tint_for(color: Color) -> Color:
	# Subtle ink washes let the original paper grain remain visible.
	if color.r>.95 and color.g>.88: return Color.WHITE
	return Color.WHITE.lerp(Color(color,1.0),.20)

static func focus() -> StyleBox:
	var line: StyleBoxTexture=box("slot",Color("d8ad65"),0) as StyleBoxTexture
	if line!=null:
		line.draw_center=false
		for side: int in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]: line.set_expand_margin(side,2)
		return line
	return StyleBoxEmpty.new()

static func build(base: Theme) -> Theme:
	var result: Theme=base.duplicate(true) as Theme
	for type_name: String in ["Button","OptionButton"]:
		result.set_stylebox("normal",type_name,box("button",Color.WHITE,8))
		result.set_stylebox("hover",type_name,box("button",Color("ffe8bb"),8))
		result.set_stylebox("pressed",type_name,box("button",Color("c9ac7e"),8))
		result.set_stylebox("disabled",type_name,box("button",Color("ded2bd"),8))
		result.set_stylebox("focus",type_name,focus())
		for key: String in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_hover_pressed_color"]:
			result.set_color(key,type_name,INK)
		result.set_color("font_disabled_color",type_name,Color("66503b"))
	result.set_stylebox("panel","PanelContainer",box("panel"))
	result.set_stylebox("panel","Panel",box("panel"))
	result.set_stylebox("panel","PopupPanel",box("panel"))
	result.set_stylebox("panel","PopupMenu",box("panel"))
	result.set_color("font_color","PopupMenu",INK)
	result.set_color("font_color","Label",INK)
	result.set_stylebox("panel","TooltipPanel",box("strip",Color.WHITE,8))
	result.set_color("font_color","TooltipLabel",INK)
	result.set_font_size("font_size","TooltipLabel",16)
	for kind: String in ["HScrollBar","VScrollBar"]:
		result.set_stylebox("scroll",kind,box("leather",Color("bba385"),2))
		result.set_stylebox("grabber",kind,box("button",Color.WHITE,2))
		result.set_stylebox("grabber_highlight",kind,box("button",Color("f5d8a0"),2))
		result.set_stylebox("grabber_pressed",kind,box("button",Color("caa475"),2))
	result.set_stylebox("slider","HSlider",box("leather",Color("d7c7af"),3))
	result.set_stylebox("grabber_area","HSlider",box("strip",Color("c29453"),3))
	result.set_stylebox("grabber_area_highlight","HSlider",box("strip",Color("ebc178"),3))
	return result

class PeriodMarker extends Control:
	var period: int=0
	func _ready() -> void:
		mouse_filter=Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var center: Vector2=Vector2(14,14)
		var ink: Color=Color("513521")
		if period<2:
			draw_circle(center,5.0,Color("b78535") if period==0 else Color("a45c30"))
			draw_arc(center,5.3,0,TAU,22,ink,1.5,true)
			for i: int in range(8):
				var direction: Vector2=Vector2.from_angle(i*TAU/8+.08)
				draw_line(center+direction*8,center+direction*11,ink,1.4,true)
		else:
			var crescent: PackedVector2Array=[]
			for i: int in range(25):
				var angle: float=lerpf(-PI*.5,PI*.5,i/24.0)
				crescent.append(center+Vector2(-cos(angle)*9,sin(angle)*9))
			for i: int in range(25):
				var angle: float=lerpf(PI*.5,-PI*.5,i/24.0)
				crescent.append(center+Vector2(-cos(angle)*3,sin(angle)*9))
			draw_colored_polygon(crescent,Color("6c536f"))
			crescent.append(crescent[0])
			draw_polyline(crescent,ink,1.2,true)
