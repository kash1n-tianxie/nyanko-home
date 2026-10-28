extends Control
const GameLocale=preload("res://scripts/game_locale.gd")
## Photo collage assembled from existing room, cat and boss artwork. Profile-only display.
signal selected(chapter: int)
const Atlas=preload("res://scripts/illustrated_atlas.gd")
const Art=preload("res://scripts/expansion_art.gd")
const ROOM: Texture2D=preload("res://art/story-v026/room.png")
const TITLES: Array[String]=["纸箱也有合照","吸尘器休息日","影王请吃饭","电视终于安静","月亮回家了"]
const INK: Color=Color("4c413b")
var unlocked: Array=[]
var chapter: int=1
var detail: bool=false

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	resized.connect(queue_redraw)

func _gui_input(event: InputEvent) -> void:
	if detail or not event is InputEventMouseButton or not event.pressed or event.button_index!=MOUSE_BUTTON_LEFT: return
	var pick: int=clampi(floori(event.position.x/(size.x/5.0))+1,1,5)
	if pick in unlocked: selected.emit(pick)

func _draw() -> void:
	if detail:
		_photo(chapter,Rect2(12,4,size.x-24,size.y-8),true)
		return
	var cell: float=size.x/5.0
	for i: int in range(5):
		var extent: Vector2=Vector2(cell-9,size.y-12)
		var center: Vector2=Vector2(cell*(i+.5),size.y*.5)
		draw_set_transform(center,deg_to_rad(-2 if i%2==0 else 2))
		var rect: Rect2=Rect2(-extent*.5,extent)
		if i+1 in unlocked: _photo(i+1,rect,false)
		else:
			draw_style_box(_paper(),rect)
			draw_rect(Rect2(rect.position+Vector2(6,6),rect.size-Vector2(12,31)),Color("c7bda6"))
			draw_arc(Vector2(0,-13),10,PI,TAU,18,INK,2,true)
			draw_rect(Rect2(-12,-13,24,20),Color("9d927c"))
			draw_circle(Vector2(0,-3),2,INK)
			_text("第%d章"%(i+1),Vector2(rect.position.x,rect.end.y-9),rect.size.x,15)
		draw_set_transform(Vector2.ZERO)

func _paper() -> StyleBox:
	var box: StyleBoxFlat=StyleBoxFlat.new()
	box.bg_color=Color("f7efdb"); box.border_color=Color("95816c")
	box.set_border_width_all(1); box.shadow_color=Color("3d302730"); box.shadow_size=3
	return box

func _photo(index: int,rect: Rect2,large: bool) -> void:
	draw_style_box(_paper(),rect)
	var image: Rect2=Rect2(rect.position+Vector2(7,7),rect.size-Vector2(14,35 if not large else 42))
	draw_texture_rect_region(ROOM,image,Rect2(160,110,960,540),Color("d5c7b7"))
	var boss: Texture2D=Atlas.enemy("B%02d"%index)
	Art.fit(self,boss,Rect2(image.position+Vector2(image.size.x*.47,image.size.y*.03),image.size*Vector2(.49,.8)),Color("fff2d8"))
	for i: int in range(3 if not large else 6):
		var cat: String="C%02d"%(i+1)
		var width: float=image.size.x*(.28 if not large else .17)
		var x: float=image.position.x+image.size.x*(.03+i*(.22 if not large else .13))
		Art.fit(self,Atlas.cat(cat),Rect2(x,image.position.y+image.size.y*.50,width,image.size.y*.49))
	var tape: Rect2=Rect2(rect.get_center().x-rect.size.x*.16,rect.position.y-3,rect.size.x*.32,8 if not large else 13)
	draw_rect(tape,Color("c9b26bc4"))
	_text(TITLES[index-1] if large else "第%d章 ✓"%index,Vector2(rect.position.x,rect.end.y-10),rect.size.x,21 if large else 15)

func _text(value: String,point: Vector2,width: float,font_size: int) -> void:
	draw_string(get_theme_default_font(),point,GameLocale.text(value),HORIZONTAL_ALIGNMENT_CENTER,width,font_size,INK)
