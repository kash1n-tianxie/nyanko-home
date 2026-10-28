extends RefCounted
## A scalar-only, deterministic visual companion. It never owns simulation dictionaries.
const Scenery=preload("res://scripts/story_scenery.gd")
const Positions=preload("res://scripts/cat_combat_positions.gd")
const FEET: Array[Vector2]=Positions.FEET
var level: int=1
var hp_ratio: float=1.0
var clock: float=0.0
var reduced: bool=false
var upgrade_left: float=0.0
var repair_left: float=0.0
var damage_left: float=0.0
var previous_level: int=1
var _ready_state: bool=false
var _hp: float=300.0
var rope_angle: float=0.0
var rope_velocity: float=0.0
var charm_angle: float=0.0
var charm_velocity: float=0.0
var hit_age: float=8.0

func configure(current: Dictionary, reduced_motion: bool=false, reset_state: bool=false) -> void:
	var next_level: int=clampi(int(current.get("hq",1)),1,5)
	var next_hp: float=maxf(0.0,float(current.get("hp",300.0)))
	reduced=reduced_motion
	if reset_state: reset()
	if _ready_state:
		if next_level>level:
			previous_level=level
			upgrade_left=1.25
			repair_left=1.1
		elif next_hp>_hp+.01: repair_left=.9
		if next_hp<_hp-.01: _impact()
	level=next_level
	_hp=next_hp
	hp_ratio=clampf(next_hp/maxf(1.0,float(current.get("max_hp",300.0))),0.0,1.0)
	_ready_state=true

func reset() -> void:
	clock=0.0
	upgrade_left=0.0
	repair_left=0.0
	damage_left=0.0
	_ready_state=false
	rope_angle=0.0;rope_velocity=0.0
	charm_angle=0.0;charm_velocity=0.0
	hit_age=8.0

## Caller supplies elapsed presentation time only after applying pause and combat speed.
func tick(delta: float) -> void:
	clock+=maxf(0.0,delta)
	upgrade_left=maxf(0.0,upgrade_left-delta)
	repair_left=maxf(0.0,repair_left-delta)
	damage_left=maxf(0.0,damage_left-delta)
	hit_age+=maxf(0.0,delta)
	# Two damped links: the rope reacts first, the hanging flag follows it.
	# Small integration steps keep the motion stable when frames arrive late.
	var remaining: float=minf(maxf(0.0,delta),.5)
	while remaining>0.0:
		var step: float=minf(remaining,1.0/120.0)
		rope_velocity+=(-rope_angle*85.0-rope_velocity*7.5)*step
		rope_angle+=rope_velocity*step
		charm_velocity+=((rope_angle-charm_angle)*36.0-charm_velocity*4.7)*step
		charm_angle+=charm_velocity*step
		remaining-=step

func _impact() -> void:
	if damage_left<.30:
		rope_velocity=clampf(rope_velocity+1.7,-2.0,2.0)
		hit_age=0.0
	damage_left=.42

func event(notice: Dictionary) -> void:
	if str(notice.get("type",""))=="base_damage_resolved" and float(notice.get("hp_damage",0))>0: _impact()

func snapshot() -> Dictionary:
	return {"level":level,"platforms":level,"hp_ratio":hp_ratio,"clock":clock,"upgrade_left":upgrade_left,"repair_left":repair_left,"damage_left":damage_left,"anchors":FEET.slice(0,level),"rope_angle":rope_angle,"charm_angle":charm_angle,"silhouette":silhouette()}

func silhouette() -> Dictionary:
	return {"base_width":156.0+(level-1)*21.0,"posts":1+int(level>=2)+int(level>=3),"house":level>=3,"ladder":level>=4,"crest":level>=5}

func _module(canvas: CanvasItem, id: String, rect: Rect2, angle: float=0.0, alpha: float=1.0) -> void:
	Scenery.draw_module(canvas,id,rect,angle,Vector2(.5,.5),Color(1,1,1,alpha))

func draw_tree(canvas: CanvasItem) -> void:
	# Platforms always keep their combat anchor, even while new supports settle in.
	var shake: float=0.0 if reduced else sin((.42-damage_left)*53.0)*damage_left*3.5
	var sway: float=0.0 if reduced or hp_ratio>=.25 else sin(clock*2.4)*.006
	var base_width: float=156.0+(level-1)*21.0
	Scenery.contact_shadow(canvas,Vector2(208,528),Vector2(base_width+36,25),.31)
	# Auxiliary supports appear behind the existing platform feet, never under cats.
	if level>=2:
		_module(canvas,"tree_post",Rect2(110+shake*.65,266,29,244))
	if level>=3:
		_module(canvas,"tree_post",Rect2(281+shake*.65,326,29,184))
	if level>=4:
		_module(canvas,"wood_brace",Rect2(115+shake,437,89,75),-.15,.92)
	if level>=5:
		_module(canvas,"wood_brace",Rect2(229+shake,440,82,72),.20,.94)
	_module(canvas,"tree_base",Rect2(208-base_width*.5+shake,482,base_width,54))
	_module(canvas,"tree_post",Rect2(189+shake,171,44,325),sway)
	if level>=3:
		_module(canvas,"tree_house",Rect2(154+shake,391,81,82))
	if level>=4:
		_module(canvas,"tree_ladder",Rect2(66+shake,402,65,100),-.10)
	if level>=5:
		_module(canvas,"tree_crest",Rect2(169+shake,186,80,44))
	for i: int in range(level):
		var feet: Vector2=FEET[i]
		var fresh: bool=upgrade_left>0.0 and i>=previous_level
		var appear: float=1.0-clampf(upgrade_left/1.25,0.0,1.0) if fresh else 1.0
		var settle: float=(1.0-appear)*12.0 if fresh and not reduced else 0.0
		if i>0:
			var from: Vector2=Vector2(210,feet.y+65)
			var to: Vector2=feet+Vector2(0,16)
			var length: float=from.distance_to(to)
			_module(canvas,"tree_beam",Rect2((from+to)*.5-Vector2(length*.5,10)+Vector2(shake,settle),Vector2(length,20)),(to-from).angle(),.55+.45*appear)
		_module(canvas,"tree_platform",Rect2(feet.x-62,feet.y-7,124,39),0.0,.55+.45*appear)
		Scenery.contact_shadow(canvas,feet+Vector2(0,2),Vector2(53,8),.22)
		if i>0 and upgrade_left>0.0 and fresh:
			_module(canvas,"glints",Rect2(feet.x-55,feet.y-30,115,69),0.0,upgrade_left/1.25)
	if level>=2:
		var flag_angle: float=0.0 if reduced else sin(clock*1.4)*.025+charm_angle*.65
		_module(canvas,"tree_flag",Rect2(158,93,41,72),flag_angle)
	_draw_hanging(canvas)
	# Cracks are painted alpha decals on wood, not an overlay over cats or the stage.
	var damage: float=1.0-hp_ratio
	if hp_ratio<.72:
		_module(canvas,"wood_crack",Rect2(198+shake,289,26,83),.08,clampf(damage*1.4,0.0,1.0))
	if hp_ratio<.45:
		_module(canvas,"wood_crack",Rect2(178+shake,469,52,35),1.25,clampf(damage*1.5,0.0,1.0))
		_module(canvas,"wood_crack",Rect2(205+shake,194,24,58),-.16,.82)
	if hp_ratio<.25:
		_module(canvas,"wood_chips",Rect2(177,512,92,27),0.0,.85)
		_module(canvas,"repair_patch",Rect2(185+shake,369,49,31),.1,.95)
	if damage_left>0.0 and not reduced:
		var age: float=.42-damage_left
		_module(canvas,"wood_chips",Rect2(226+age*52,351+age*65,41,30),age*1.5,damage_left/.42)
	if repair_left>0.0:
		var progress: float=1.0-repair_left/1.1
		_module(canvas,"glints",Rect2(164,470-(0.0 if reduced else progress*260),93,82),0.0,minf(1.0,repair_left/.5))


func _draw_hanging(canvas: CanvasItem) -> void:
	var hinge: Vector2=Vector2(262,193)
	var angle: float=0.0 if reduced else rope_angle+sin(clock*1.1)*.018
	var end: Vector2=hinge+Vector2(0,28).rotated(angle)
	var middle: Vector2=hinge+Vector2(2.0,14).rotated(angle*.65)
	canvas.draw_polyline(PackedVector2Array([hinge,middle,end]),Color("61483d"),3.0,true)
	canvas.draw_polyline(PackedVector2Array([hinge+Vector2(-.6,0),middle+Vector2(-.6,0),end+Vector2(-.6,0)]),Color("c6ac7b"),1.2,true)
	var trailing: float=0.0 if reduced else charm_angle*.8
	Scenery.draw_module(canvas,"pennant",Rect2(end-Vector2(12,0),Vector2(24,22)),trailing,Vector2(.5,0),Color(1,1,1,.90))
