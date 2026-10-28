extends Control
const GameLocale=preload("res://scripts/game_locale.gd")
## Actual unfiled fish, grouped by species. Draws over the empty painted world basket.
## Presentation uses deterministic offsets only; it never rolls or modifies a run.
const FishArt = preload("res://scripts/fish_art.gd")
const INK: Color = Color("594633")
const COLORS: Array[Color] = [Color("e1cda8"),Color("85b9ce"),Color("deb34b")]
@export var reduced: bool = false
@export var show_count: bool = true
@export var draw_basket: bool = false
var basket_texture: Texture2D
var _fish: Array = []
var _groups: Array = []
var _previous_locations: Dictionary = {}
var _jumps: Dictionary = {}
var _count: int = 0
var _capacity: int = 5
var _reserved: int = 0
var _full: bool = false
var _initialized: bool = false
var _clock: float = 0.0
var _shake_left: float = 0.0
var _next_hop: float = 2.2
var _hop_index: int = 0

func _ready() -> void:
	name = "BasketView"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	if size.x<1 or size.y<1: size = Vector2(210,112)

func sync_run(run: RefCounted) -> void:
	if run==null or run.s.is_empty(): return
	_count = run.basket_count()
	_capacity = run.basket_capacity()
	_reserved = 0
	_fish.clear()
	var current_locations: Dictionary = {}
	for value: Dictionary in run.s.items.values():
		if str(value.get("location","")) not in ["basket","pending"]: continue
		var fish_id: String = str(value.id)
		var location: String = str(value.location)
		_fish.append(value.duplicate())
		current_locations[fish_id] = location
		if location=="pending": _reserved += 1
		elif _initialized and _previous_locations.get(fish_id,"")!="basket": _jumps[fish_id] = 0.0
	for fish_id: String in _jumps.keys():
		if not current_locations.has(fish_id): _jumps.erase(fish_id)
	_previous_locations = current_locations
	_build_groups()
	var now_full: bool = _count>=_capacity
	if now_full and not _full and _initialized: shake_full()
	_full = now_full
	_initialized = true
	tooltip_text = ""
	if _reserved>0: tooltip_text += " · 待收 %d" % _reserved
	queue_redraw()

func _build_groups() -> void:
	var by_kind: Dictionary = {}
	for value: Dictionary in _fish:
		var kind: String = str(value.kind)
		if not by_kind.has(kind):
			by_kind[kind] = {"kind":kind,"count":0,"quality":0,"pending":true,"ids":[]}
		var group: Dictionary = by_kind[kind]
		group.count += 1
		group.quality = maxi(int(group.quality),int(value.quality))
		group.pending = bool(group.pending) and value.location=="pending"
		group.ids.append(value.id)
	_groups.clear()
	var kinds: Array = by_kind.keys()
	kinds.sort()
	for kind: String in kinds: _groups.append(by_kind[kind])

func shake_full() -> void:
	_shake_left = .38
	queue_redraw()

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	if reduced:
		_jumps.clear()
		_shake_left = 0.0
		queue_redraw()
		return
	_clock += delta
	_shake_left = maxf(0.0,_shake_left-delta)
	for fish_id: String in _jumps.keys():
		_jumps[fish_id] = float(_jumps[fish_id])+delta
		if float(_jumps[fish_id])>.64: _jumps.erase(fish_id)
	_next_hop -= delta
	if _next_hop<=0.0:
		var resting: Array = _fish.filter(func(value: Dictionary) -> bool: return value.location=="basket")
		if not resting.is_empty():
			var value: Dictionary = resting[_hop_index%resting.size()]
			_jumps[str(value.id)] = 0.0
			_hop_index += 1
		_next_hop = 2.4+float(_hop_index%3)*.43
	queue_redraw()

func debug_state() -> Dictionary:
	var distribution: Dictionary = {}
	for group: Dictionary in _groups: distribution[group.kind] = group.count
	return {"count":_count,"capacity":_capacity,"reserved":_reserved,"full":_full,"distribution":distribution,"jumping":0 if reduced else _jumps.size(),"shaking":not reduced and _shake_left>0.0}

func _draw() -> void:
	var unit: Vector2 = size/Vector2(210,112)
	var shake: float = sin(_clock*76.0)*2.6*(_shake_left/.38) if not reduced and _shake_left>0.0 else 0.0
	draw_set_transform(Vector2(shake,0),0,unit)
	if basket_texture!=null: draw_texture_rect(basket_texture,Rect2(0,0,210,112),false)
	elif draw_basket: _draw_empty_basket()
	for index: int in range(_groups.size()):
		var group: Dictionary = _groups[index]
		var columns: int = 4
		var row: int = floori(float(index)/columns)
		var row_count: int = mini(columns,_groups.size()-row*columns)
		var origin: Vector2 = Vector2(105.0+(float(index%columns)-(row_count-1)*.5)*43.0,42.0-row*23.0)
		var jump: float = 0.0
		for fish_id: String in group.ids:
			if _jumps.has(fish_id): jump = maxf(jump,sin(clampf(float(_jumps[fish_id])/.64,0.0,1.0)*PI))
		var fish_center: Vector2 = origin+Vector2(sin(_clock*9.0+index)*jump*3,-jump*(22.0+index%3*4))
		var tilt: float = ((index%3)-1)*.12+jump*sin(_clock*10.0+index)*.2
		draw_set_transform((fish_center+Vector2(shake,0))*unit,tilt,unit)
		var texture: Texture2D = FishArt.texture(str(group.kind))
		var fit: Vector2 = texture.get_size()*minf(45.0/texture.get_width(),29.0/texture.get_height())
		var tint: Color = Color(1,1,1,.56 if bool(group.pending) else 1.0)
		draw_texture_rect(texture,Rect2(-fit*.5,fit),false,tint)
		if int(group.count)>1:
			draw_circle(Vector2(17,9),8.0,Color("fff0cf"))
			draw_arc(Vector2(17,9),8,0,TAU,18,INK,1.0,true)
			draw_string(GameLocale.body_font(),Vector2(13,13),GameLocale.text(str(group.count)),HORIZONTAL_ALIGNMENT_LEFT,-1,11,INK)
		if int(group.quality)>0:
			draw_circle(Vector2(-16,10),2.7,COLORS[int(group.quality)])
		draw_set_transform(Vector2(shake,0),0,unit)
	if show_count:
		# A little paper tag tied to the wicker, not a floating modern card.
		draw_line(Vector2(100,65),Vector2(101,82),INK,1.1,true)
		var paper: PackedVector2Array = PackedVector2Array([Vector2(76,79),Vector2(133,78),Vector2(137,100),Vector2(75,102)])
		draw_colored_polygon(paper,Color("fae9c7"))
		paper.append(paper[0])
		draw_polyline(paper,INK,1.3,true)
		draw_circle(Vector2(102,82),1.6,INK)
		var label: String = "%d/%d" % [_count,_capacity]
		var width: float = GameLocale.body_font().get_string_size(GameLocale.text(label),HORIZONTAL_ALIGNMENT_LEFT,-1,17).x
		draw_string(GameLocale.body_font(),Vector2(106-width*.5,97),GameLocale.text(label),HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("a44932") if _full else INK)
	draw_set_transform(Vector2.ZERO)

func _draw_empty_basket() -> void:
	var body: PackedVector2Array = PackedVector2Array([Vector2(10,48),Vector2(200,48),Vector2(182,104),Vector2(30,104)])
	draw_colored_polygon(body,Color("c99b61"))
	for x: int in range(29,190,12): draw_line(Vector2(x,51),Vector2(24+(x-20)*.86,101),Color("a37242"),2,true)
	for y: int in range(58,102,9): draw_line(Vector2(16+(y-48)*.25,y),Vector2(198-(y-48)*.25,y),Color("e4bd80"),3,true)
	body.append(body[0]); draw_polyline(body,INK,2.2,true)
	var rim: PackedVector2Array = []
	for index: int in range(49): rim.append(Vector2(105+cos(index*TAU/48)*96,49+sin(index*TAU/48)*18))
	draw_colored_polygon(rim,Color("88613c"))
	draw_polyline(rim,INK,5,true)
	draw_polyline(rim,Color("e7be7e"),2.6,true)
