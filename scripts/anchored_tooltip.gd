extends PanelContainer
## One small, mouse-transparent paper card. All measurements are in logical UI pixels.
const Paper=preload("res://scripts/collage_theme.gd")
const MAX_WIDTH: float=296.0
const SAFE_MARGIN: float=24.0
var source_ref: WeakRef
var anchor: Rect2
var limits: Rect2=Rect2(0,0,1280,720)
var pinned: bool=false
var presented_lines: Array[String]=[]

func _ready() -> void:
 name="AnchoredTooltip"
 z_index=80
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 var paper: StyleBox=Paper.box("panel",Color.WHITE,SAFE_MARGIN)
 if paper is StyleBoxTexture:
  for side: int in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]: paper.set_texture_margin(side,7)
 add_theme_stylebox_override("panel",paper)
 hide()

static func fit_rect(source: Rect2, extent: Vector2, bounds: Rect2) -> Rect2:
 var gap: float=14
 var x: float=source.end.x+gap
 if x+extent.x>bounds.end.x-10: x=source.position.x-gap-extent.x
 x=clampf(x,bounds.position.x+10,maxf(bounds.position.x+10,bounds.end.x-extent.x-10))
 var y: float=clampf(source.get_center().y-extent.y*.5,bounds.position.y+10,maxf(bounds.position.y+10,bounds.end.y-extent.y-10))
 return Rect2(Vector2(x,y),extent)

func present(source: Control, source_rect: Rect2, title: String, subtitle: String, lines: Array[String], icon_texture: Texture2D, bounds: Rect2, keep: bool=false) -> void:
 for child: Node in get_children(): remove_child(child); child.queue_free()
 source_ref=weakref(source) if source!=null else null
 anchor=source_rect
 limits=bounds
 pinned=keep
 presented_lines=lines.duplicate()
 var column: VBoxContainer=VBoxContainer.new()
 column.custom_minimum_size.x=MAX_WIDTH-SAFE_MARGIN*2
 column.add_theme_constant_override("separation",8)
 column.mouse_filter=Control.MOUSE_FILTER_IGNORE
 add_child(column)
 var header: HBoxContainer=HBoxContainer.new()
 header.mouse_filter=Control.MOUSE_FILTER_IGNORE
 header.add_theme_constant_override("separation",8)
 column.add_child(header)
 if icon_texture!=null:
  var icon: TextureRect=TextureRect.new()
  icon.texture=icon_texture
  icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
  icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  icon.custom_minimum_size=Vector2(44,44)
  icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
  header.add_child(icon)
 var heading: VBoxContainer=VBoxContainer.new()
 heading.custom_minimum_size.x=206
 heading.mouse_filter=Control.MOUSE_FILTER_IGNORE
 header.add_child(heading)
 _text(heading,title,19,206)
 _text(heading,subtitle,14,206)
 for line: String in lines:
  if not line.strip_edges().is_empty(): _text(column,line,16,MAX_WIDTH-SAFE_MARGIN*2)
 custom_minimum_size=Vector2(MAX_WIDTH,0)
 size=Vector2(MAX_WIDTH,0)
 show()
 reset_size()
 _place()
 call_deferred("_place")

func _text(parent: Node, value: String, font_size: int, width: float) -> Label:
 var label: Label=Label.new()
 label.text=value
 label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 label.custom_minimum_size.x=width
 label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 label.add_theme_font_size_override("font_size",font_size)
 label.add_theme_color_override("font_color",Color("392b20"))
 label.mouse_filter=Control.MOUSE_FILTER_IGNORE
 parent.add_child(label)
 return label

func _place() -> void:
 if not visible: return
 size.x=MAX_WIDTH
 position=fit_rect(anchor,size,limits).position

func _process(_delta: float) -> void:
 if not visible or source_ref==null: return
 var source: Object=source_ref.get_ref()
 if not is_instance_valid(source) or not (source as Control).is_visible_in_tree(): hide(); return
 anchor=(source as Control).get_global_rect()
 _place()

func close_from(source: Control) -> void:
 if pinned: return
 if source_ref==null or source_ref.get_ref()==source: hide()
