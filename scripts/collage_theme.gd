extends RefCounted
## Cut-paper UI; text is live and margins remain stable at every window size.
const Legacy = preload("res://scripts/parchment_theme.gd")
const INK: Color=Color("211f25")
const PAPER: Color=Color("f5eedb")
const ROOT: String="res://art/expansion-v030/ui/"
static var cache: Dictionary={}

static func texture(kind: String) -> Texture2D:
	var key: String={"leather":"button","rivet":"slot"}.get(kind,kind)
	if cache.has(key): return cache[key]
	var path: String=ROOT+key+".png"
	if ResourceLoader.exists(path):
		cache[key]=load(path) as Texture2D
		return cache[key]
	return null

static func box(kind: String="panel", tint: Color=Color.WHITE, margin: float=12) -> StyleBox:
	var tex: Texture2D=texture(kind)
	var result: StyleBox
	if tex!=null:
		var painted: StyleBoxTexture=StyleBoxTexture.new()
		painted.texture=tex
		painted.modulate_color=tint
		var horizontal: float={"panel":35.0,"slot":10.0,"rivet":8.0,"strip":12.0}.get(kind,14.0)
		var vertical: float={"panel":29.0,"slot":10.0,"rivet":8.0,"strip":4.0}.get(kind,7.0)
		for side: int in [SIDE_LEFT,SIDE_RIGHT]: painted.set_texture_margin(side,horizontal)
		for side: int in [SIDE_TOP,SIDE_BOTTOM]: painted.set_texture_margin(side,vertical)
		result=painted
	else:
		var flat: StyleBoxFlat=StyleBoxFlat.new()
		flat.bg_color=PAPER*tint
		flat.border_color=INK
		flat.set_border_width_all(2)
		flat.corner_radius_top_left=2
		flat.corner_radius_bottom_right=3
		flat.shadow_color=Color("15151bbb")
		flat.shadow_offset=Vector2(3,4)
		flat.shadow_size=1
		result=flat
	result.content_margin_left=margin
	result.content_margin_right=margin
	result.content_margin_top=margin
	result.content_margin_bottom=margin
	return result

static func tint_for(color: Color) -> Color:
	if color.r>.95 and color.g>.88: return Color.WHITE
	return Color.WHITE.lerp(Color(color,1.0),.28)

static func focus() -> StyleBox:
	var frame: StyleBoxFlat=StyleBoxFlat.new()
	frame.bg_color=Color.TRANSPARENT
	frame.border_color=Color("b74c48")
	frame.set_border_width_all(3)
	frame.set_expand_margin_all(3)
	return frame

static func build(base: Theme) -> Theme:
	var result: Theme=base.duplicate(true) as Theme
	for type_name: String in ["Button","OptionButton"]:
		for key: String in ["normal","hover","pressed","disabled"]:
			var tint: Color={"normal":Color.WHITE,"hover":Color("ffe3a2"),"pressed":Color("cfb890"),"disabled":Color("b3afa5")}[key]
			result.set_stylebox(key,type_name,box("button",tint,8))
		result.set_stylebox("focus",type_name,focus())
		for key: String in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_hover_pressed_color"]: result.set_color(key,type_name,INK)
		result.set_color("font_disabled_color",type_name,Color("66615c"))
	for type_name: String in ["Panel","PanelContainer","PopupPanel","PopupMenu"]: result.set_stylebox("panel",type_name,box())
	for type_name: String in ["Label","PopupMenu","TooltipLabel"]: result.set_color("font_color",type_name,INK)
	result.set_stylebox("panel","TooltipPanel",box("panel",Color.WHITE,12))
	result.set_font_size("font_size","TooltipLabel",16)
	for type_name: String in ["HScrollBar","VScrollBar"]:
		result.set_stylebox("scroll",type_name,box("strip",Color("bdb6a5"),2))
		for key: String in ["grabber","grabber_highlight","grabber_pressed"]: result.set_stylebox(key,type_name,box("button",Color.WHITE,2))
	return result

class PeriodMarker extends Legacy.PeriodMarker:
	pass
