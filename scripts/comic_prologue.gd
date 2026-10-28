extends Control
const GameLocale=preload("res://scripts/game_locale.gd")
## Five illustrated pages; no run state or save is created by viewing the prologue.
signal finished
signal cancelled
signal interacted
const InkButton = preload("res://scripts/front_menu_button.gd")
const InkWipe = preload("res://scripts/front_ink_transition.gd")
const DISPLAY_FONT: Font = preload("res://fonts/japanese-v040/ui_title.tres")
const BODY_FONT: Font = preload("res://fonts/japanese-v040/ui_body.tres")
const HEADLINES: Array[String] = ["平常的一天", "洗衣机，把月亮吞了！", "月光消失以后", "它们冲过来了！", "轮到猫咪反抗"]
const CAPTIONS: Array[String] = [
	"六只猫，六种摸鱼方式。今晚的月亮，还是圆的。",
	"滚筒里亮起陌生的光。下一秒，整颗月亮被吸了进去。",
	"拖鞋长出牙齿，纸箱睁开眼睛……家里的东西，醒了。",
	"家门快守不住了。猫猫的午睡，也被正式宣告结束。",
	"鱼骨、弹弓、插头、木锤、喇叭、锅盖——把月亮抢回来！"
]
var page_index: int = 0
var replay_mode: bool = false
var reduced: bool = false
var busy: bool = false
var done: bool = false
var canvas: Control
var artwork: TextureRect
var frame: Control
var headline: Label
var caption: Label
var counter: Label
var previous: Button
var next: Button
var skip: Button
var back: Button
var pages: Array[Texture2D] = []
var built: bool = false

func setup(replay: bool = false, quiet: bool = false) -> void:
	replay_mode=replay
	reduced=quiet
	if not built: _build()
	for button: Button in [previous,next,skip,back]:
		button.set("reduced",reduced)
	_apply_page(0)
	call_deferred("focus_default")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	clip_contents=true
	resized.connect(_layout)
	if not built: _build()
	_layout()

func _build() -> void:
	built=true
	canvas=Control.new()
	canvas.name="ComicCanvas"
	canvas.size=Vector2(1280,720)
	canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	artwork=TextureRect.new()
	artwork.name="ComicArtwork"
	artwork.position=Vector2(20,12)
	artwork.size=Vector2(1240,697.5)
	artwork.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	artwork.mouse_filter=Control.MOUSE_FILTER_IGNORE
	canvas.add_child(artwork)
	for i: int in range(5):
		var path: String="res://art/front-v029/comic-%02d.png" % (i+1)
		pages.append(load(path) as Texture2D if ResourceLoader.exists(path) else null)
	frame=Control.new()
	frame.size=Vector2(1280,720)
	frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
	canvas.add_child(frame)
	frame.draw.connect(_draw_frame)
	headline=_text("StoryHeadline",Rect2(60,555,1090,40),31,DISPLAY_FONT,Color("11131d"))
	caption=_text("StoryCaption",Rect2(62,599,1140,44),23,BODY_FONT,Color("25202a"))
	counter=_text("StoryCounter",Rect2(656,660,190,32),20,BODY_FONT,Color("fff4de"))
	previous=_nav("StoryPrevious","上一页",Rect2(877,651,155,48),previous_page)
	next=_nav("StoryNext","下一页",Rect2(1045,649,197,51),next_page)
	skip=_nav("StorySkip","跳过序章",Rect2(1053,29,185,46),complete)
	back=_nav("StoryBackHome","返回主页",Rect2(38,652,185,48),return_home)
	_layout()

func _text(key: String, rect: Rect2, font_size: int, font: Font, color: Color) -> Label:
	var label: Label=Label.new()
	label.name=key
	label.position=rect.position
	label.size=rect.size
	label.add_theme_font_override("font",font)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	canvas.add_child(label)
	return label

func _nav(key: String, words: String, rect: Rect2, action: Callable) -> Button:
	var button: Button=InkButton.new()
	button.position=rect.position
	button.size=rect.size
	button.set("compact",true)
	button.setup(key,words,1,reduced)
	canvas.add_child(button)
	button.pressed.connect(action)
	return button

func _layout() -> void:
	if not is_instance_valid(canvas): return
	var factor: float=minf(size.x/1280.0,size.y/720.0)
	if factor<=0.0: factor=1.0
	canvas.scale=Vector2.ONE*factor
	canvas.position=(size-Vector2(1280,720)*factor)*.5
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("11131d"))

func _draw_frame() -> void:
	frame.draw_polyline(PackedVector2Array([Vector2(18,12),Vector2(1262,12),Vector2(1262,710),Vector2(18,710),Vector2(18,12)]),Color("11131d"),14,true)
	frame.draw_colored_polygon(PackedVector2Array([Vector2(0,540),Vector2(1280,555),Vector2(1280,720),Vector2(0,720)]),Color("11131d"))
	frame.draw_colored_polygon(PackedVector2Array([Vector2(30,548),Vector2(1242,555),Vector2(1225,643),Vector2(43,648)]),Color("fff4de"))
	frame.draw_colored_polygon(PackedVector2Array([Vector2(27,548),Vector2(45,550),Vector2(56,644),Vector2(39,649)]),Color("ffd13c"))
	frame.draw_colored_polygon(PackedVector2Array([Vector2(26,29),Vector2(209,23),Vector2(200,67),Vector2(34,74)]),Color("132ba5"))
	frame.draw_string(DISPLAY_FONT,Vector2(48,57),GameLocale.text("序章 / %02d" % (page_index+1)),HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("fff4de"))
	for i: int in range(5):
		frame.draw_circle(Vector2(475+i*27,678),6 if i==page_index else 4,Color("ffd13c") if i==page_index else Color("686888"))

func _apply_page(index: int) -> void:
	page_index=clampi(index,0,4)
	artwork.texture=pages[page_index]
	headline.text=HEADLINES[page_index]
	caption.text=CAPTIONS[page_index]
	counter.text="%02d  /  05" % (page_index+1)
	previous.disabled=page_index==0
	previous.get_node("AnimatedPaper").queue_redraw()
	next.set("caption",("返回主页" if replay_mode else "选一只猫") if page_index==4 else "下一页")
	next.accessibility_name=str(next.get("caption"))
	next.get_node("AnimatedPaper").queue_redraw()
	skip.set("caption","返回主页" if replay_mode else "跳过序章")
	skip.accessibility_name=str(skip.get("caption"))
	skip.get_node("AnimatedPaper").queue_redraw()
	frame.queue_redraw()

func change_page(index: int) -> void:
	if busy or done or index<0 or index>4 or index==page_index: return
	busy=true
	interacted.emit()
	var wipe: Control=InkWipe.new()
	wipe.name="ComicPageTurn"
	add_child(wipe)
	wipe.finished.connect(func() -> void:
		busy=false
		wipe.queue_free()
		focus_default())
	wipe.start(func() -> void: _apply_page(index),reduced)

func next_page() -> void:
	if page_index==4: complete()
	else: change_page(page_index+1)

func previous_page() -> void:
	change_page(page_index-1)

func complete() -> void:
	if busy or done: return
	done=true
	interacted.emit()
	finished.emit()

func return_home() -> void:
	if busy or done: return
	done=true
	interacted.emit()
	cancelled.emit()

func focus_default() -> void:
	if is_instance_valid(next) and is_inside_tree(): next.grab_focus()

func handle_key(event: InputEvent) -> bool:
	if not event is InputEventKey or not event.pressed or event.echo: return false
	if event.keycode not in [KEY_ESCAPE,KEY_LEFT,KEY_RIGHT,KEY_SPACE,KEY_ENTER]: return false
	if busy or done: return true
	match event.keycode:
		KEY_ESCAPE: return_home()
		KEY_LEFT: previous_page()
		KEY_RIGHT,KEY_SPACE: next_page()
		KEY_ENTER:
			if get_viewport().gui_get_focus_owner()!=null: return false
			next_page()
	return true
