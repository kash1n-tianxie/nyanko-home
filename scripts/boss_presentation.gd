extends RefCounted
## Giant bodies and their connected strike parts. Damage lives only in Combat.
const Rules = preload("res://scripts/boss_stage_rules.gd")
const Encounter = preload("res://scripts/boss_encounter.gd")
const Art = preload("res://scripts/illustrated_atlas.gd")
const Paint = preload("res://scripts/painted_vfx.gd")
const Expansion = preload("res://scripts/expansion_art.gd")
const MaterialMotion = preload("res://scripts/boss_material_motion.gd")
const SETTLE_SECONDS: float = 2.05
var material_motion: RefCounted = MaterialMotion.new()
const ROOT: String = "res://art/immersion-v035/bosses/"
const COLORS: Dictionary = {"B01":"d5a45c","B02":"8ab9ac","B03":"ae88bd","B04":"d2b575","B05":"e4d186"}
static var textures: Dictionary = {}
static var action_manifest: Dictionary = {}
var state: Dictionary = {}
var reduced: bool = false
var stage: int = -1
var clock: float = 0.0
var reactions: Dictionary = {}
var remains: Array[Dictionary] = []

func configure(current: Dictionary, low_motion: bool) -> void:
	var next_stage: int = int(current.get("stage",0))
	if next_stage!=stage:
		stage=next_stage
		reactions.clear()
		remains.clear()
		material_motion.clear()
	state=current
	reduced=low_motion

func tick(delta: float) -> void:
	if bool(state.get("paused",false)) or delta<=0: return
	var elapsed: float=delta*clampf(float(state.get("combat_speed",1.0)),1,2)
	clock+=elapsed
	for enemy: Dictionary in state.get("battle",{}).get("enemies",[]):
		if not bool(enemy.get("boss_fixed",false)) or bool(enemy.get("dead",false)): continue
		var enemy_id: int=int(enemy.id)
		if not reactions.has(enemy_id): reactions[enemy_id]={"release":0.0,"stagger":0.0,"hit":0.0,"charge_age":0.0}
		var charging: bool=maxf(float(enemy.get("special_windup",0)),float(enemy.get("windup",0)))>0 or not enemy.get("counter_state",{}).is_empty()
		if float(enemy.get("freeze",0))>0 or float(enemy.get("stun",0))>0: continue
		reactions[enemy_id].charge_age=float(reactions[enemy_id].get("charge_age",0))+elapsed if charging else 0.0
	for id: int in reactions:
		var reaction: Dictionary=reactions[id]
		for key: String in ["release","stagger","hit","phase","summon"]:
			reaction[key]=maxf(0,float(reaction.get(key,0))-elapsed)
	for wreck: Dictionary in remains: wreck.age=float(wreck.age)+elapsed
	remains=remains.filter(func(wreck: Dictionary)->bool:return float(wreck.age)<8.0)

func event(data: Dictionary) -> void:
	var type: String=str(data.get("type",""))
	if type=="stage_start":
		reactions.clear(); remains.clear(); material_motion.clear()
		return
	var id: int=int(data.get("target",data.get("boss_id",-1)))
	if type=="hit" and not bool(data.get("boss",false)): return
	if type in ["boss_cast","boss_counter_success","boss_phase","boss_reinforcement","hit"]:
		if not reactions.has(id): reactions[id]={"release":0.0,"stagger":0.0,"hit":0.0}
		if type=="boss_cast": reactions[id].release=.56
		elif type=="boss_counter_success": reactions[id].stagger=.65
		elif type=="boss_phase": reactions[id].phase=1.35
		elif type=="boss_reinforcement": reactions[id].summon=.7
		elif float(data.get("amount",0))>0: reactions[id].hit=.16
	if type=="boss_departure":
		for wreck: Dictionary in remains:
			if int(wreck.id)==id: return
		remains.append({"id":id,"kind":str(data.get("kind","B01")),"age":0.0})

static func body_rect(_kind: String) -> Rect2:
	# The root stays at BODY. The silhouette extends past the right viewport edge.
	return Rect2(Rules.BODY-Vector2(220,402),Vector2(468,402))

static func limb_rect() -> Rect2:
	# Painted distal end occupies the actual finite-range hit point.
	return Rect2(Rules.HIT-Vector2(30,54),Vector2(Rules.BODY.x-Rules.HIT.x+53,108))

static func hit_region() -> Rect2:
	return Rect2(Rules.HIT-Vector2(30,40),Vector2(86,80))

static func texture(kind: String, frame: String) -> Texture2D:
	var key: String=kind+"/"+frame
	if textures.has(key): return textures[key]
	var path: String=ROOT+kind+"-"+frame+".png"
	if ResourceLoader.exists(path):
		textures[key]=load(path) as Texture2D
		return textures[key]
	return null

func frame_for(enemy: Dictionary) -> String:
	var response: Dictionary=reactions.get(int(enemy.get("id",-1)),{})
	if float(enemy.get("counter_stagger",0))>0 or float(response.get("stagger",0))>0: return "stagger"
	if str(enemy.get("boss_state",""))=="flight" or float(response.get("release",0))>0: return "release"
	if str(enemy.get("boss_state",""))=="windup" or maxf(float(enemy.get("special_windup",0)),float(enemy.get("windup",0)))>0 or not enemy.get("counter_state",{}).is_empty(): return "charge"
	return "idle"

func draw_back(canvas: Node2D, battle: Dictionary) -> void:
	for wreck: Dictionary in remains: _draw_wreck(canvas,wreck)
	for enemy: Dictionary in battle.get("enemies",[]):
		if bool(enemy.get("boss_fixed",false)) and not bool(enemy.get("dead",false)): _draw_body(canvas,enemy)

func _draw_body(canvas: Node2D, enemy: Dictionary, alpha: float=1.0) -> void:
	var kind: String=str(enemy.kind)
	var age: float=float(enemy.get("entrance_age",2.0))
	var entrance: float=smoothstep(0,.8,age)
	var frozen: bool=float(enemy.get("freeze",0))>0 or float(enemy.get("stun",0))>0
	var response: Dictionary=reactions.get(int(enemy.get("id",-1)),{})
	var charging: bool=frame_for(enemy)=="charge"
	var charge: float=smoothstep(0,.8,float(response.get("charge_age",0))) if charging else 0.0
	var pose: Dictionary=MaterialMotion.sample(kind,clock,response,charge,reduced or frozen)
	var kick: float=float(pose.kick)
	var tint: Color=Color("d5e9ed") if frozen else Color.WHITE
	tint=tint.lerp(Color(1.0,.93,.80),float(response.get("hit",0))/.16*.4)
	tint.a=entrance*alpha
	canvas.draw_set_transform(Vector2(Rules.BODY.x,514),0,Vector2(1,.12))
	canvas.draw_circle(Vector2.ZERO,185,Color(.16,.13,.18,.22*tint.a))
	canvas.draw_set_transform(Vector2.ZERO)
	# Detached parts have individual pivots and inertia. Their parent/root and the
	# existing attack limb's first quarter are never translated by these motions.
	var new_pose: bool=_draw_action_pose(canvas,enemy,tint,kick)
	if not new_pose:
		match kind:
			"B01":
				_piece(canvas,kind,"feet",Vector2(1202,485),Vector2(186,79),0,tint)
				material_motion.draw_warp(canvas,kind+"cast_sleeve",MaterialMotion.part(kind,"hose"),Rect2(917,346,190,60),pose,tint,true)
				material_motion.draw_warp(canvas,kind+"body",MaterialMotion.part(kind,"body"),Rect2(1040+kick*.3,174,310,310),pose,tint)
				_piece(canvas,kind,"crown",Vector2(1192+kick*.6,171-charge*10),Vector2(123,82),float(pose.idle)*.015-charge*.07+float(pose.lag)*.003,tint)
				_piece(canvas,kind,"muzzle",Rules.CAST,Vector2(48,48)*(1+charge*.10),-charge*.08,tint)
			"B02":
				# Wheels remain planted while the loaded shell recoils and handle lags.
				for wheel_x: float in [1104.0,1236.0]: _piece(canvas,kind,"wheel",Vector2(wheel_x,480),Vector2(67,74),kick*.018,tint)
				material_motion.draw_warp(canvas,kind+"cast_hose",MaterialMotion.part(kind,"hose"),Rect2(917,330,190,66),pose,tint,true)
				_piece(canvas,kind,"body",Vector2(1168+kick,354+charge*3),Vector2(350,260),-kick*.0015,tint)
				_piece(canvas,kind,"handle",Vector2(1178+kick*.5,223+charge*4),Vector2(122,68),float(pose.lag)*.008-charge*.025,tint)
				_piece(canvas,kind,"muzzle",Rules.CAST,Vector2(55,59),0,tint)
			"B05":
				_piece(canvas,kind,"tentacle",Vector2(1244,215),Vector2(125,162),float(pose.idle)*.035+float(pose.lag)*.006,tint)
				for foot_x: float in [1134.0,1258.0]: _piece(canvas,kind,"hand",Vector2(foot_x,487),Vector2(94,77),-.25,tint)
				# The metal cabinet remains rigid; no sine-wave is applied to it.
				_piece(canvas,kind,"body",Vector2(1163+kick*.65,325),Vector2(310,330),kick*.001,tint)
				var drum: Vector2=Vector2(1114,355)+Vector2(sin(clock*3.0),cos(clock*3.0))*(0.8+charge*2.0)*(0 if reduced or frozen else 1)
				_piece(canvas,kind,"moon",drum,Vector2(88,88),clock*.12 if not reduced and not frozen else 0.0,tint)
				# True door image hinged at its right edge, independently from the shell.
				_piece(canvas,kind,"door",Vector2(1065+kick*.35,350),Vector2(104*(1-charge*.20),180),-.055-charge*.09+float(pose.lag)*.004,tint,Vector2(1,.5))
			_:
				var body_frame: String="stagger" if frame_for(enemy)=="stagger" else ("release" if int(enemy.get("boss_phase",1))==2 else "idle")
				var source: Texture2D=texture(kind,body_frame)
				if source==null: source=Art.enemy(kind)
				material_motion.draw_warp(canvas,kind+"body",source,body_rect(kind),pose,tint)
	_draw_phase_detail(canvas,enemy,tint)
	var limb: Texture2D=texture(kind,"limb")
	if limb!=null: material_motion.draw_warp(canvas,kind+"limb",limb,limb_rect(),pose,tint,true)
	if charge>0 or float(response.get("release",0))>0:
		# The saved CAST point remains the emission point. A restrained painted
		# charge connection makes its relation to the cabinet/box visible.
		var socket: Vector2=Rules.cast_point(kind)
		if not new_pose:
			var mouth: Vector2=Vector2(1080,355)
			Paint.beam(canvas,kind,1,mouth,socket,10,Color(1,1,1,(.18+charge*.30)*tint.a))
		Paint.sprite(canvas,"B04" if kind=="B05" else kind,2,socket,Vector2(46,40)*(1+charge*.35),0,Color(1,1,1,.65*tint.a))
	if float(response.get("hit",0))>0:
		var flash: float=float(response.hit)/.16
		canvas.draw_arc(Rules.HIT,25+(1-flash)*12,-PI*.7,PI*.7,14,Color(.99,.88,.62,flash*.75),3,true)
	if float(enemy.get("shield",0))>0:
		canvas.draw_arc(Rules.HIT,47,-PI*.65,PI*.65,20,Color(.67,.86,.88,.65),3,true)

static func action_texture(kind: String, frame: String) -> Texture2D:
	var key: String="v039/"+kind+"/"+frame
	if textures.has(key): return textures[key]
	var path: String="res://art/boss-v039/"+kind+"/"+frame+".png"
	if not ResourceLoader.exists(path): return null
	textures[key]=load(path) as Texture2D
	return textures[key]

func _draw_action_pose(canvas: Node2D, enemy: Dictionary, tint: Color, kick: float, frame_override: String="") -> bool:
	var kind: String=str(enemy.kind)
	if kind not in ["B01","B05"]: return false
	var phase: int=int(enemy.get("boss_phase",1))
	var frame: String="exposed" if phase==2 else "idle"
	var current: String=str(enemy.get("boss_state","idle"))
	if current=="windup": frame="windup"
	elif current=="flight": frame="release"
	elif current=="recover": frame="recover"
	elif frame_for(enemy)=="charge": frame="windup"
	elif frame_for(enemy)=="release": frame="release"
	if not frame_override.is_empty(): frame=frame_override
	var source: Texture2D=action_texture(kind,frame)
	if source==null: return false
	if action_manifest.is_empty() and FileAccess.file_exists("res://art/boss-v039/manifest.json"):
		var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://art/boss-v039/manifest.json"))
		if parsed is Dictionary: action_manifest=parsed
	var spec: Dictionary=action_manifest.get("bosses",{}).get(kind,{})
	var reference_height: float=float(spec.get("reference_height",600))
	var scale: float=(338.0 if kind=="B01" else 390.0)/maxf(1,reference_height)
	var canvas_extent: Vector2=source.get_size()*scale
	var anchor: Vector2=Vector2(1162 if kind=="B01" else 1176,514)
	var recoil: Vector2=Vector2(kick*.35,0)
	Paint.draw_texture(canvas,source,anchor+recoil+Vector2(0,(.5-.9375)*canvas_extent.y),canvas_extent,0,tint)
	return true

func _draw_phase_detail(canvas: Node2D, enemy: Dictionary, tint: Color) -> void:
	var phase: int=int(enemy.get("boss_phase",1))
	var current: String=str(enemy.get("boss_state","idle"))
	var color: Color=Color(COLORS.get(str(enemy.kind),"e4d186"))
	if current=="transition":
		var progress: float=clampf(1-float(enemy.get("boss_transition_left",0))/Encounter.TRANSITION_SECONDS,0,1)
		# A crack burst remains beside the body, never over cats or the lower HUD.
		var center: Vector2=Vector2(1080,320)
		for i: int in range(7):
			var angle: float=-PI*.72+float(i)*PI*.21
			var direction: Vector2=Vector2.from_angle(angle)
			canvas.draw_line(center+direction*(36+progress*45),center+direction*(55+progress*78),Color(color, .65*sin(progress*PI)),5,true)
	if phase==2:
		# The vulnerable limb stays at the same finite-range target anchor.
		canvas.draw_arc(Rules.HIT,36,-PI*.65,PI*.65,20,Color(color,.45*tint.a),3,true)
	var summon: float=float(reactions.get(int(enemy.get("id",-1)),{}).get("summon",0))
	if summon>0:
		var progress: float=1-summon/.7
		for i: int in range(3):
			var point: Vector2=Rules.cast_point(str(enemy.kind)).lerp(Vector2(1180+i*25,470),progress)
			Paint.sprite(canvas,str(enemy.kind) if str(enemy.kind)!="B05" else "B04",2,point,Vector2(35,25),progress*.4,Color(1,1,1,.7*(1-progress)))

func _piece(canvas: Node2D, kind: String, piece: String, center: Vector2, extent: Vector2, angle: float, tint: Color, pivot: Vector2=Vector2(.5,.5)) -> void:
	MaterialMotion.draw_part(canvas,MaterialMotion.part(kind,piece),center,extent,angle,tint,pivot)

func settle_remaining() -> float:
	var remaining: float=0.0
	for wreck: Dictionary in remains: remaining=maxf(remaining,SETTLE_SECONDS-float(wreck.age))
	return maxf(0,remaining)

func _draw_wreck(canvas: Node2D, wreck: Dictionary) -> void:
	var kind: String=str(wreck.kind)
	var age: float=float(wreck.age)
	if age<.26:
		var shell: Dictionary={"id":wreck.id,"kind":kind,"entrance_age":1.0}
		_draw_body(canvas,shell,1-smoothstep(.03,.26,age))
	var falling: float=smoothstep(.16,.92,age)
	var rest_alpha: float=smoothstep(.65,1.30,age)
	var source: Texture2D=texture(kind,"defeat")
	var new_defeat: bool=false
	if age>=.10 and age<1.3 and kind in ["B01","B05"]:
		new_defeat=_draw_action_pose(canvas,{"kind":kind,"id":wreck.id},Color(1,1,1,smoothstep(.10,.26,age)*(1-rest_alpha)),0,"defeat")
	if not new_defeat and source!=null and age<1.3:
		var pose: Dictionary=MaterialMotion.sample(kind,clock,{},1-falling,reduced)
		var rect: Rect2=Rect2(Rules.BODY-Vector2(210,260-falling*24),Vector2(420,260))
		material_motion.draw_warp(canvas,kind+"wreck",source,rect,pose,Color(1,1,1,smoothstep(.10,.26,age)*(1-rest_alpha)))
	var restored: Texture2D=MaterialMotion.part(kind,"restored")
	if restored!=null:
		var width: float=300.0 if kind in ["B01","B03"] else 245.0
		var height: float=width*restored.get_height()/maxf(1,restored.get_width())
		var bounce: float=sin(maxf(0,age-.65)*16)*exp(-maxf(0,age-.65)*5)*6 if age>.65 and not reduced else 0.0
		MaterialMotion.draw_part(canvas,restored,Rules.BODY+Vector2(45,bounce),Vector2(width,height),0,Color(1,1,1,rest_alpha),Vector2(.5,1))
	if kind=="B01" and age<1.0:
		var t: float=clampf(age/.9,0,1)
		_piece(canvas,kind,"crown",Vector2(1190-80*t,171+300*t*t),Vector2(95,64),t*.55,Color(1,1,1,1-smoothstep(.65,1,t)))
	if kind=="B05" and age>.25:
		var rise: float=smoothstep(.25,1.85,age)
		var point: Vector2=Vector2(1114,355).lerp(Vector2(1040,172),rise)
		var moon_alpha: float=1-smoothstep(1.8,2.1,age)
		_piece(canvas,kind,"moon",point,Vector2.ONE*(88-rise*18),rise*.18,Color(1,1,1,moon_alpha))

func draw_flights(canvas: Node2D, battle: Dictionary) -> void:
	for flight: Dictionary in battle.get("hostile_boss_flights",[]):
		var duration: float=maxf(.001,float(flight.get("duration",.6)))
		var progress: float=clampf(1-float(flight.get("left",duration))/duration,0,1)
		var from: Vector2=Vector2(float(flight.get("from_x",Rules.CAST.x)),float(flight.get("from_y",Rules.CAST.y)))
		var to: Vector2=Vector2(float(flight.get("to_x",350)),float(flight.get("to_y",400)))
		var point: Vector2=from.lerp(to,progress)
		var kind: String=str(flight.get("kind","B01"))
		var art_key: String="B04" if kind=="B05" else kind
		var source: Texture2D=Paint.texture(art_key,1)
		if kind=="B04": source=Expansion.picture("vfx","enemy-tv")
		var action: String=str(flight.get("action","contact"))
		var extent: Vector2=Vector2(124,96) if action!="contact" else Vector2(92,72)
		if kind=="B05" and action=="moon_tide": extent=Vector2(164,112)
		if kind=="B04": extent=Vector2(100,100)
		if source!=null:
			if not reduced:
				for i: int in range(2):
					var trail: Vector2=point+(from-to).normalized()*(18+i*16)
					Expansion.fit(canvas,source,Rect2(trail-extent*.5,extent),Color(1,1,1,.22-i*.08))
			Expansion.fit(canvas,source,Rect2(point-extent*.5,extent))

static func draw_impact(canvas: Node2D, effect: Dictionary) -> void:
	var age: float=float(effect.get("age",0))
	if age>.32: return
	var kind: String=str(effect.get("enemy_kind",effect.get("kind","B01")))
	var key: String="B04" if kind=="B05" else kind
	var source: Texture2D=Paint.texture(key,2 if age<.13 else 3)
	if kind=="B04": source=Expansion.picture("vfx","enemy-tv")
	if source!=null: Expansion.fit(canvas,source,Rect2(Vector2(350,400)-Vector2(76,60),Vector2(152,120)),Color(1,1,1,1-smoothstep(.16,.32,age)))
