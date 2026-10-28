extends Control
## Painted, articulated comedy poses for home scenes. Presentation only: no Run/RNG writes.
signal walk_finished
const Mutations = preload("res://scripts/cat_mutations.gd")
var run_state: Dictionary = {}
const Original = preload("res://scripts/cat_sprite_art.gd")
const AttackPose = preload("res://scripts/cat_performance.gd")
const IDS: Array[String] = ["C01","C02","C03","C04","C05","C06"]
# Attachment anchors are authored against the actual four-frame source sheets.
# They follow held/lowered/raised weapons; hidden bell frames hide its weapon sleeve.
const GAG_ANCHORS: Dictionary = {
	"C01":[[Vector2(265,475),Vector2(365,480),Vector2(90,452)],[Vector2(970,405),Vector2(990,348),Vector2(1115,60)],[Vector2(440,895),Vector2(420,890),Vector2(105,940)],[Vector2(785,1075),Vector2(915,1085),Vector2(1145,1080)]],
	"C02":[[Vector2(150,355),Vector2(300,275),Vector2(550,280)],[Vector2(785,330),Vector2(930,255),Vector2(850,320)],[Vector2(175,970),Vector2(340,902),Vector2(560,800)],[Vector2(750,990),Vector2(930,908),Vector2(1170,890)]],
	"C03":[[Vector2(230,340),Vector2(360,292),Vector2(570,377)],[Vector2(860,350),Vector2(1000,309),Vector2(1185,350)],[Vector2(278,909),Vector2(330,843),Vector2(578,813)],[Vector2(877,980),Vector2(995,930),Vector2(1150,1092)]],
	"C04":[[Vector2(265,442),Vector2(396,401),Vector2(175,505)],[Vector2(882,449),Vector2(1043,399),Vector2(790,115)],[Vector2(225,1015),Vector2(380,1022),Vector2(515,1113)],[Vector2(985,1000),Vector2(836,896),Vector2(1130,1095)]],
	"C05":[[Vector2(281,420),Vector2(355,401),Vector2(555,559)],[Vector2(902,415),Vector2(972,369),Vector2(1195,293)],[Vector2(355,1050),Vector2(490,997),Vector2(685,936)],[Vector2(977,1040),Vector2(1042,965),Vector2(1143,974)]],
	"C06":[[Vector2(208,387),Vector2(356,301),Vector2(557,166)],[Vector2(795,490),Vector2(942,398),Vector2.ZERO],[Vector2(186,1018),Vector2(335,929),Vector2.ZERO],[Vector2(821,1019),Vector2(1031,999),Vector2(754,968)]]}
const GAGS: Dictionary = {"C01":"backflip","C02":"hairball_face","C03":"electric_shock","C04":"hammer_toe","C05":"reverse_yawn","C06":"pot_lid_peek"}
const DURATIONS: Dictionary = {"C01":[.26,.22,.48,.40],"C02":[.34,.52,.26,.65],"C03":[.30,.32,.42,.62],"C04":[.24,.42,.25,.72],"C05":[.40,.42,.58,.68],"C06":[.30,.35,.55,.68]}
const BLINKS: Dictionary = {
	"C01":{"color":"f1b465","eyes":[[321,174,29,11,-.06],[409,168,24,11,-.05]]},
	"C02":{"color":"f0e1c7","eyes":[[235,143,25,12,-.27],[323,119,18,10,-.24]]},
	"C03":{"color":"57515b","eyes":[[373,208,34,36,0],[453,234,19,12,.02]]},
	"C04":{"color":"ede0c8","eyes":[[372,310,22,11,-.15],[457,288,17,11,-.13]]},
	"C05":{"color":"a09bbb","eyes":[[362,207,24,10,-.42],[438,180,16,9,.12]]},
	"C06":{"color":"f7efd7","eyes":[[302,184,32,35,.05],[392,168,25,31,-.05]]}}
const SHEETS: Dictionary = {
	"C01":preload("res://art/story-v026/cats/C01-gag.png"),
	"C02":preload("res://art/story-v026/cats/C02-gag.png"),
	"C03":preload("res://art/story-v026/cats/C03-gag.png"),
	"C04":preload("res://art/story-v026/cats/C04-gag.png"),
	"C05":preload("res://art/story-v026/cats/C05-gag.png"),
	"C06":preload("res://art/story-v026/cats/C06-gag.png")}
@export var cat_id: String = "C01":
	set(value):
		cat_id = value if value in IDS else "C01"
		_gag_wait = 1.1+IDS.find(cat_id)*.65
		queue_redraw()
@export var reduced: bool = false
var paused: bool = false:
	set(value):
		if paused==value: return
		paused=value
		if is_instance_valid(_walk_tween) and _walk_tween.is_valid():
			if paused: _walk_tween.pause()
			else: _walk_tween.play()
@export var idle_offset: float = 0.0
var idle_clock: float = 0.0
var _attack_age: float = -1.0
var walking: bool = false
var _walk_clock: float = 0.0
var _walk_tween: Tween
var _facing: float = 1.0
var _gag_age: float = -1.0
var _gag_wait: float = 1.1
var _gag_count: int = 0
static var _manifest: Dictionary = {}
static var _textures: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	if size.x<=0.0 or size.y<=0.0: size=Vector2(200,200)
	_ensure_manifest()
	_gag_wait = 1.1+IDS.find(cat_id)*.65
	idle_clock = idle_offset+IDS.find(cat_id)*.71

static func _ensure_manifest() -> void:
	if not _manifest.is_empty(): return
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://art/story-v026/cats/manifest.json"))
	if parsed is Dictionary: _manifest=parsed

static func _frame_texture(id: String, index: int) -> AtlasTexture:
	_ensure_manifest()
	var key: String=id+str(index)
	if not _textures.has(key):
		var region: Array=_manifest[id].frames[index].region
		var texture: AtlasTexture=AtlasTexture.new()
		texture.atlas=SHEETS[id]
		texture.region=Rect2(float(region[0]),float(region[1]),float(region[2]),float(region[3]))
		texture.filter_clip=true
		_textures[key]=texture
	return _textures[key]

func _process(delta: float) -> void:
	if paused or not is_visible_in_tree(): return
	if _attack_age>=0.0:
		_attack_age+=delta
		if _attack_age>=AttackPose.duration(cat_id): _attack_age=-1.0
	# Reduced motion suppresses idle comedy; attack timing remains independent.
	if not reduced:
		idle_clock+=delta
		if walking: _walk_clock+=delta
		elif _attack_age>=0.0:
			pass
		elif _gag_age>=0.0:
			_gag_age+=delta
			if _gag_age>=gag_duration():
				_gag_age=-1.0
				_gag_count+=1
				_gag_wait=4.0+IDS.find(cat_id)*.44+fmod(_gag_count*1.31,1.6)
		else:
			_gag_wait-=delta
			if _gag_wait<=0.0: play_gag()
	queue_redraw()

## Called from an actual isolated trial attack event, never from an idle timer.
func play_attack() -> void:
	if walking: return
	_gag_age=-1.0
	_gag_wait=2.0
	_attack_age=0.0
	queue_redraw()

func gag_duration() -> float:
	var duration: float=0.0
	for amount: float in DURATIONS[cat_id]: duration+=amount
	return duration

## Optional preview hook. Normal scenes trigger each independent sequence themselves.
func play_gag() -> void:
	if not walking: _gag_age=0.0
	queue_redraw()

## Positions are Control top-left coordinates, never foot coordinates.
## The caller may tween size concurrently; rendering always reads the current size.
func walk_to(target: Vector2, duration: float) -> void:
	if is_instance_valid(_walk_tween): _walk_tween.kill()
	walking=true
	_walk_clock=0.0
	_gag_age=-1.0
	_facing=-1.0 if target.x<position.x else 1.0
	_walk_tween=create_tween()
	_walk_tween.tween_property(self,"position",target,maxf(.05,duration)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_walk_tween.tween_callback(_finish_walk)
	if paused: _walk_tween.pause()

func _finish_walk() -> void:
	walking=false
	_facing=1.0
	_gag_wait=1.8+IDS.find(cat_id)*.17
	walk_finished.emit()
	queue_redraw()

func _pose() -> Dictionary:
	var result: Dictionary={"frame":-1,"phase":"idle","offset":Vector2.ZERO,"scale":Vector2.ONE,"angle":0.0}
	if _attack_age>=0.0 and not walking:
		var attack: Dictionary=AttackPose.sample(cat_id,_attack_age,reduced)
		result.phase="attack_"+str(attack.phase)
		result.offset=attack.offset
		result.scale=attack.scale
		result.angle=attack.rotation
		result.original_pose=attack.pose
		return result
	if walking:
		result.phase="walk"
		if not reduced:
			var stride: float=fmod(_walk_clock*3.8,1.0)
			result.offset=Vector2(0,-absf(sin(stride*TAU))*13.0)
			result.scale=Vector2(1.0+.035*cos(stride*TAU),1.0-.045*cos(stride*TAU))
			result.frame=0 if stride<.5 else 1
		return result
	if reduced: return result
	if _gag_age<0:
		result.scale=Vector2(1.0+.008*sin(idle_clock*2.6),1.0+.012*sin(idle_clock*2.6))
		return result
	var remaining: float=_gag_age
	var frame: int=0
	for index: int in range(4):
		frame=index
		if remaining<float(DURATIONS[cat_id][index]): break
		remaining-=float(DURATIONS[cat_id][index])
	var progress: float=clampf(remaining/float(DURATIONS[cat_id][frame]),0,1)
	result.frame=frame
	result.phase=GAGS[cat_id]
	match cat_id:
		"C01":
			if frame==0: result.scale=Vector2(1.0+.05*progress,1.0-.06*progress)
			elif frame==1: result.offset.y=-sin(progress*PI*.5)*30.0
			elif frame==2:
				result.offset.y=-30.0-sin(progress*PI)*19.0
				result.angle=lerpf(-.24,.22,progress)
			else: result.scale=Vector2(1+.08*sin(progress*PI),1-.08*sin(progress*PI))
		"C02":
			if frame==1: result.scale=Vector2(1+.025*sin(progress*TAU*2),1.0)
			elif frame==2:
				result.offset.y=-sin(progress*PI)*14.0
				result.angle=-.06
			elif frame==3: result.angle=sin(progress*TAU)*.025
		"C03":
			if frame==2:
				result.offset=Vector2(sin(progress*TAU*8)*2.2,-5.0)
				result.scale=Vector2(1,1.02)
		"C04":
			if frame==1: result.angle=-sin(progress*PI)*.05
			elif frame==2: result.offset=Vector2(2.0,3.0*sin(progress*PI))
			elif frame==3:
				result.offset.y=-absf(sin(progress*TAU*1.5))*20.0
				result.angle=sin(progress*TAU*1.5)*.045
		"C05":
			if frame==1: result.scale=Vector2(1+.02*sin(progress*PI),1)
			elif frame==2: result.offset.x=sin(progress*PI)*9.0
			elif frame==3: result.angle=sin(progress*TAU*2)*.025
		"C06":
			if frame==1: result.offset.y=sin(progress*PI)*2.0
			elif frame==3: result.offset.x=sin(progress*PI)*6.0
	return result

func debug_state() -> Dictionary:
	var result: Dictionary=_pose().duplicate(true)
	result.cat=cat_id
	result.gag_age=_gag_age
	result.walking=walking
	result.attack_age=_attack_age
	return result

func _draw() -> void:
	_ensure_manifest()
	if not _manifest.has(cat_id): return
	var pose: Dictionary=_pose()
	var unit: float=minf(size.x,size.y)/200.0
	var foot: Vector2=Vector2(size.x*.5,size.y*.92)
	var shadow_width: float=44.0*unit
	var hop: float=absf(float(pose.offset.y))*unit
	draw_set_transform(foot+Vector2(0,3*unit),0,Vector2(maxf(.65,1.0-hop/120.0),.18))
	draw_circle(Vector2.ZERO,shadow_width,Color(0.17,0.12,0.16,.12))
	draw_set_transform(Vector2.ZERO)
	var texture: Texture2D
	var anchor: Vector2
	var pixel_scale: float
	var frame: int=int(pose.frame)
	# Walking cycles use real different leg/stance poses plus visible ground-contact hops.
	# No continuous idle sprite slide; no attacks or simulation callbacks are emitted.
	if _attack_age>=0.0 and not walking:
		texture=Original.texture(cat_id,str(pose.get("original_pose","idle")))
		anchor=Original.pivot(cat_id)*texture.get_size()
		pixel_scale=minf(size.x,size.y)*.66/texture.get_height()
	elif walking:
		texture=Original.texture(cat_id,"attack" if frame==1 else "idle")
		anchor=Original.pivot(cat_id)*texture.get_size()
		pixel_scale=minf(size.x,size.y)*.66/texture.get_height()
	elif cat_id=="C01" and frame<0:
		texture=Original.texture(cat_id,"idle")
		anchor=Original.pivot(cat_id)*texture.get_size()
		pixel_scale=minf(size.x,size.y)*.66/texture.get_height()
	else:
		frame=maxi(0,frame)
		texture=_frame_texture(cat_id,frame)
		var raw: Array=_manifest[cat_id].frames[frame].anchor
		anchor=Vector2(float(raw[0]),float(raw[1]))
		pixel_scale=minf(size.x,size.y)/800.0
	var visual_scale: Vector2=Vector2(pose.scale)*pixel_scale
	if walking: visual_scale.x*=_facing
	draw_set_transform(foot+Vector2(pose.offset)*unit,float(pose.angle),visual_scale)
	# The same silhouette parts follow the existing real gag frame transform.
	# They never replace the gag with an idle or procedural pretend frame.
	var attachment_height: float = minf(size.x,size.y)*.66/pixel_scale if _attack_age>=0.0 or walking or (cat_id=="C01" and int(pose.frame)<0) else float(texture.get_height())
	var attachment_anchors: Dictionary = {}
	if not walking and _attack_age<0.0 and not (cat_id=="C01" and int(pose.frame)<0):
		attachment_anchors=_costume_anchors(frame,anchor,attachment_height)
	Mutations.draw_overlay(self,run_state,cat_id,attachment_height,"back",str(pose.get("original_pose","idle")),attachment_anchors)
	draw_texture_rect(texture,Rect2(-anchor,texture.get_size()),false)
	Mutations.draw_overlay(self,run_state,cat_id,attachment_height,"front",str(pose.get("original_pose","idle")),attachment_anchors)
	if not walking and _gag_age<0.0 and _attack_age<0.0 and not reduced: _draw_blink(anchor)
	draw_set_transform(Vector2.ZERO)


func _draw_blink(anchor: Vector2) -> void:
	var cycle: float=fmod(idle_clock+IDS.find(cat_id)*.23,4.7)
	if cycle<4.42 or cycle>4.57: return
	var alpha: float=sin((cycle-4.42)/.15*PI)
	var source_origin: Vector2=Vector2.ZERO
	if cat_id!="C01":
		var region: Array=_manifest[cat_id].frames[0].region
		source_origin=Vector2(float(region[0]),float(region[1]))
	var fill: Color=Color(str(BLINKS[cat_id].color))
	fill.a=alpha
	for eye: Array in BLINKS[cat_id].eyes:
		var center: Vector2=Vector2(float(eye[0]),float(eye[1]))-source_origin-anchor
		var radii: Vector2=Vector2(float(eye[2]),float(eye[3]))
		var angle: float=float(eye[4])
		var shape: PackedVector2Array=PackedVector2Array()
		for i: int in range(24):
			var theta: float=TAU*i/24.0
			shape.append(center+(Vector2(cos(theta),sin(theta))*radii).rotated(angle))
		draw_colored_polygon(shape,fill)
		var lid: PackedVector2Array=PackedVector2Array()
		for i: int in range(7):
			var x: float=lerpf(-radii.x*.82,radii.x*.82,i/6.0)
			lid.append(center+Vector2(x,sin(i/6.0*PI)*radii.y*.15).rotated(angle))
		draw_polyline(lid,Color(.13,.09,.14,alpha),3.8,true)

func _costume_anchors(frame: int, foot_anchor: Vector2, height: float) -> Dictionary:
	var index: int=clampi(frame,0,3)
	var region: Array=_manifest[cat_id].frames[index].region
	var origin: Vector2=Vector2(float(region[0]),float(region[1]))+foot_anchor
	var values: Array=GAG_ANCHORS[cat_id][index]
	var result: Dictionary={}
	for i: int in range(3): result[["back","collar","weapon"][i]]=(Vector2(values[i])-origin)/height
	if cat_id=="C06" and index in [1,2]:
		result.hide_weapon=true
		result.hide_collar=true
	return result
