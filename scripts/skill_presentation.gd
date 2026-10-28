extends RefCounted
const GameLocale=preload("res://scripts/game_locale.gd")
## All hits come from CatSkills. Flights read saved remaining time; impact art
## consumes real hit envelopes, so neither pause nor a reload invents damage.
const FishArt=preload("res://scripts/fish_art.gd")
const Art=preload("res://scripts/illustrated_atlas.gd")
const Paint=preload("res://scripts/painted_vfx.gd")
const Frames=preload("res://scripts/frame_art.gd")
const Expansion=preload("res://scripts/expansion_vfx.gd")
const Positions=preload("res://scripts/cat_combat_positions.gd")
const Catalog=preload("res://scripts/skill_catalog.gd")
const COLORS=preload("res://scripts/skill_cutin.gd").COLORS
var effects: Array[Dictionary]=[]
var textures: Dictionary={}
var clock: float=0.0

func texture(key: String) -> Texture2D:
	if textures.has(key): return textures[key]
	var path: String="res://art/skills-v037/%s.png" % key
	if ResourceLoader.exists(path): textures[key]=load(path);return textures[key]
	return null

func event(data: Dictionary) -> void:
	if data.get("type","")=="stage_start": clear();return
	if data.get("type","") not in ["skill_ready","skill_cast","skill_impact","meal_arrive"]: return
	var effect: Dictionary=data.duplicate(true)
	effect.age=0.0
	effect.life=1.1 if effect.type in ["skill_impact","meal_arrive"] else .7
	effects.append(effect)
	while effects.size()>32: effects.pop_front()

func clear() -> void:
	effects.clear()

func enemy_offset(enemy: Dictionary,reduced: bool) -> Vector2:
	if reduced or bool(enemy.get("boss_fixed",false)): return Vector2.ZERO
	for i: int in range(effects.size()-1,-1,-1):
		var effect: Dictionary=effects[i]
		if effect.get("type","")!="skill_impact" or effect.get("skill_id","")!="roar" or float(effect.age)>=.22: continue
		for hit: Dictionary in effect.get("targets",[]):
			if int(hit.id)==int(enemy.id):
				return Vector2(-float(hit.get("push",0))*pow(1-float(effect.age)/.22,2),0)
	return Vector2.ZERO

func tick(delta: float,state: Dictionary) -> void:
	if state.get("phase","") not in ["combat","cleanup"]: clear();return
	if bool(state.get("paused",false)): return
	var cinema: Dictionary=state.get("battle",{}).get("cinematic",{})
	var cinematic: bool=bool(cinema.get("active",false))
	if cinematic:
		# Rehydrate presentation only from already resolved saved hit envelopes.
		for notice: Dictionary in cinema.get("impact_history",[]):
			var found: bool=false
			for existing: Dictionary in effects:
				if existing.get("type","")=="skill_impact" and existing.get("cast_id",-1)==notice.get("cast_id",-2) and existing.get("pulse",0)==notice.get("pulse",0): found=true;break
			if not found and float(cinema.age)-float(notice.cinematic_age)<1.1: event(notice)
	var dt: float=maxf(0.0,delta)*(1.0 if cinematic else clampf(float(state.get("combat_speed",1)),1,2))
	if not cinematic: clock+=dt
	for effect: Dictionary in effects:
		if cinematic and effect.has("cinematic_age"): effect.age=maxf(0,float(cinema.age)-float(effect.cinematic_age))
		else: effect.age+=dt
	effects=effects.filter(func(effect: Dictionary)->bool:return float(effect.age)<float(effect.life))

func enemy_stretch(enemy: Dictionary,current: Dictionary,low_motion: bool) -> Vector2:
	var cinema: Dictionary=current.get("battle",{}).get("cinematic",{})
	if not bool(cinema.get("active",false)) or cinema.get("cat","")!="C04": return Vector2.ONE
	for event_data: Dictionary in cinema.get("impact_history",[]):
		var elapsed: float=float(cinema.age)-float(event_data.get("cinematic_age",0))
		if elapsed<0 or elapsed>.65: continue
		for hit: Dictionary in event_data.get("targets",[]):
			if int(hit.id)!=int(enemy.id): continue
			var t: float=elapsed/.65
			var pose: Vector2=Vector2(1.40,.55).lerp(Vector2(.90,1.16),smoothstep(0,.38,t)) if t<.38 else Vector2(.90,1.16).lerp(Vector2.ONE,smoothstep(.38,1,t))
			return Vector2.ONE.lerp(pose,.2 if low_motion else (.4 if bool(enemy.get("boss",false)) else 1.0))
	return Vector2.ONE

static func cat_state(state: Dictionary,id: String) -> Dictionary:
	for cat: Dictionary in state.get("battle",{}).get("cats",[]):
		if cat.id==id: return cat
	return {}

func meal_pose(id: String,pose: Dictionary,reduced: bool) -> Dictionary:
	for effect: Dictionary in effects:
		if effect.get("type","")!="meal_arrive" or effect.get("cat","")!=id or effect.age>.65: continue
		var result: Dictionary=pose.duplicate()
		var chew: float=sin(float(effect.age)*TAU*5)*(.035 if reduced else .12)*(1-float(effect.age)/.65)
		result.scale=Vector2(result.get("scale",Vector2.ONE))*Vector2(1+chew,1-chew)
		return result
	return pose

func _draw_meal(canvas: Node2D,state: Dictionary) -> void:
	var meal: Dictionary=state.get("meal",{})
	var left: float=float(meal.get("flight_left",0))
	if left>0:
		var item: Dictionary=state.get("items",{}).get(str(meal.get("item_id","")),{})
		var index: int=state.get("active",[]).find(str(meal.get("cat","")))
		var goal: Vector2=Positions.FEET[clampi(index,0,4)]+Vector2(8,-58)
		var t: float=clampf(1-left/maxf(.01,float(meal.get("flight_duration",.55))),0,1)
		var point: Vector2=Vector2(1180,640).lerp(goal,t)+Vector2(0,-sin(t*PI)*170)
		var tex: Texture2D=FishArt.texture(str(item.get("kind","F01")))
		var extent: Vector2=tex.get_size()*minf(72.0/tex.get_width(),60.0/tex.get_height())
		Paint.draw_texture(canvas,tex,point,extent,sin(t*PI)*.35)
		for i: int in range(3):
			var fraction: float=maxf(0,t-i*.025-.025)
			var trace: Vector2=Vector2(1180,640).lerp(goal,fraction)+Vector2(0,-sin(fraction*PI)*170)
			canvas.draw_circle(trace,4-i,Color("f3d392")*Color(1,1,1,.6-i*.15))
	for effect: Dictionary in effects:
		if effect.get("type","")!="meal_arrive": continue
		var index: int=state.get("active",[]).find(str(effect.cat))
		var point: Vector2=Positions.FEET[clampi(index,0,4)]+Vector2(0,-45)
		var t: float=clampf(float(effect.age)/1.1,0,1)
		_ring(canvas,point+Vector2(0,35),24+40*t,Color("ffe4a2"),1-t)
		var font: Font=preload("res://theme/main.tres").default_font
		canvas.draw_string_outline(font,point+Vector2(50,-8-12*t),GameLocale.text("开饭！"),HORIZONTAL_ALIGNMENT_LEFT,130,22,3,Color("47313a")*Color(1,1,1,1-t))
		canvas.draw_string(font,point+Vector2(50,-8-12*t),GameLocale.text("开饭！"),HORIZONTAL_ALIGNMENT_LEFT,130,22,Color("ffe5a6")*Color(1,1,1,1-t))

func rage_pose(id: String,cat: Dictionary,pose: Dictionary,height: float) -> Dictionary:
	if id!="C01" or float(cat.get("skill_rage_left",0))<=0: return pose
	var tex: Texture2D=texture("C01-rage")
	if tex==null: return pose
	var result: Dictionary=pose.duplicate()
	var extent: Vector2=tex.get_size()*(height*1.25/tex.get_height())
	result.texture=tex
	result.sprite_rect=Rect2(-extent*Vector2(.40482574,.99265477),extent)
	result.offset=Vector2.ZERO
	result.rotation=0.0
	result.scale=Vector2.ONE
	result.pose="idle"
	result.attachments={"back":Vector2(-.17,-.46),"collar":Vector2(.20,-.57),"weapon":Positions.RAGE_RELEASE_OFFSET/88.0,"weapon_angle":-.48}
	# One authored rage body plus the existing weapon motion; it is not a frame clip.
	return result

func draw_cat_back(canvas: Node2D,id: String,cat: Dictionary,feet: Vector2,pose: Dictionary,height: float,reduced: bool) -> void:
	var ready: bool=bool(cat.get("skills",{}).get("ready",false)) and not bool(cat.get("skills",{}).get("used",false))
	var rage: bool=float(cat.get("skill_rage_left",0))>0
	if not ready and not rage: return
	var tex: Texture2D=pose.get("texture",Art.cat(id,str(pose.get("pose","idle"))))
	var extent: Vector2=Vector2(height*tex.get_width()/float(tex.get_height()),height)
	var rect: Rect2=pose.get("sprite_rect",Rect2(-extent*Art.cat_pivot(id),extent))
	var tint: Color=Color("ffc76c") if ready else Color("fa7244")
	var strength: float=.35 if reduced else .35+.13*sin(clock*4)
	canvas.draw_set_transform(feet+Vector2(pose.get("offset",Vector2.ZERO)),float(pose.get("rotation",0)),Vector2(pose.get("scale",Vector2.ONE)))
	for i: int in range(6):
		var shift: Vector2=Vector2.RIGHT.rotated(i*TAU/6)*3.2
		canvas.draw_texture_rect(tex,Rect2(rect.position+shift,rect.size),false,Color(tint,strength))
	canvas.draw_set_transform(Vector2.ZERO)
	if rage:
		for i: int in range(5):
			var x: float=feet.x-38+i*18
			var wobble: float=0.0 if reduced else sin(clock*8+i)*4
			_line(canvas,PackedVector2Array([Vector2(x,feet.y-8),Vector2(x-12,feet.y-32-wobble),Vector2(x-4,feet.y-62-wobble)]),Color("f8b05d"),2.2,.6)

func draw_cat_front(canvas: Node2D,id: String,cat: Dictionary,feet: Vector2,font: Font,reduced: bool) -> void:
	var skill: Dictionary=cat.get("skills",{})
	if skill.is_empty(): return
	var ready: bool=bool(skill.ready) and not bool(skill.used)
	var point: Vector2=feet+Vector2(-48,-16)
	var accent: Color=COLORS.get(id,Color("ecc06b"))
	canvas.draw_circle(point,10,Color("352c36"))
	if ready:
		canvas.draw_circle(point,8.2,Color("ffe4a1"))
		var shape: PackedVector2Array=PackedVector2Array([point+Vector2(1,-7),point+Vector2(-4,1),point+Vector2(0,1),point+Vector2(-1,7),point+Vector2(5,-2),point+Vector2(1,-2)])
		canvas.draw_colored_polygon(shape,Color("88442d"))
		if reduced or sin(clock*3)>.0: canvas.draw_arc(point,12,0,TAU,24,Color("ffd984"),1.5,true)
	elif bool(skill.used):
		canvas.draw_line(point+Vector2(-4,0),point+Vector2(4,0),Color("a79e95"),1.8,true)
	else:
		var ratio: float=clampf(float(skill.charge)/maxf(.01,float(skill.duration)),0,1)
		canvas.draw_arc(point,8,-PI*.5,-PI*.5+ratio*TAU,24,accent,2.5,true)
	if float(cat.get("skill_chorus_left",0))>0:
		Paint.sprite(canvas,"C06",1,feet+Vector2(0,-88),Vector2(23,23))
	if float(cat.get("skill_rage_left",0))>0:
		var badge: Vector2=feet+Vector2(52,-17)
		canvas.draw_string_outline(font,badge,GameLocale.text("狂暴 ×2"),HORIZONTAL_ALIGNMENT_LEFT,-1,14,3,Color("4b2327"))
		canvas.draw_string(font,badge,GameLocale.text("狂暴 ×2"),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("ffe3a1"))

func _sprite(canvas: Node2D,key: String,p: Vector2,bounds: Vector2,angle: float=0,alpha: float=1) -> bool:
	var tex: Texture2D=texture(key)
	if tex==null: return false
	var extent: Vector2=tex.get_size()*minf(bounds.x/tex.get_width(),bounds.y/tex.get_height())
	var center: Vector2=p
	if key=="skill-meteor": center-=((Vector2(.66,.64)-Vector2(.5,.5))*extent).rotated(angle)
	if key=="skill-meteor-impact": center-=((Vector2(.55,.83)-Vector2(.5,.5))*extent).rotated(angle)
	Paint.draw_texture(canvas,tex,center,extent,angle,Color(1,1,1,alpha))
	return true

func _line(canvas: Node2D,points: PackedVector2Array,color: Color,width: float,alpha: float=1) -> void:
	var bounded: PackedVector2Array=[]
	for p: Vector2 in points: bounded.append(Vector2(clampf(p.x,5,1274),clampf(p.y,82,536)))
	canvas.draw_polyline(bounded,Color("483447")*Color(1,1,1,alpha),width+2.2,true)
	canvas.draw_polyline(bounded,Color(color,alpha),width,true)

func _bolt(canvas: Node2D,start: Vector2,end: Vector2,seed_value: int,alpha: float,width: float=5) -> void:
	var points: PackedVector2Array=[start]
	for j: int in range(1,8):
		var p: Vector2=start.lerp(end,j/8.0)
		p.x+=sin(seed_value*3.7+j*5.3)*18
		points.append(p)
	points.append(end)
	_line(canvas,points,Color("75cee5"),width,alpha)
	_line(canvas,points,Color("fff3ba"),maxf(1,width*.32),alpha)

func _ring(canvas: Node2D,center: Vector2,radius: float,color: Color,alpha: float) -> void:
	var points: PackedVector2Array=[]
	for i: int in range(49): points.append(center+Vector2(cos(i*TAU/48)*radius,sin(i*TAU/48)*radius*.23))
	_line(canvas,points,color,3,alpha)

func draw(canvas: Node2D,state: Dictionary,reduced: bool) -> void:
	var battle: Dictionary=state.get("battle",{})
	_draw_meal(canvas,state)
	for flight: Dictionary in battle.get("skill_flights",[]):
		if flight.get("skill_id","")!="meteor": continue
		var duration: float=float(Catalog.DEFINITIONS.C02.delay)
		var t: float=clampf(1-float(flight.left)/duration,0,1)
		var target: Vector2=Vector2(flight.x,flight.y)
		var p: Vector2=target+Vector2(-260,-390)*(1-t*t)
		_ring(canvas,target,50+35*t,Color("ffca7c"),.55)
		var extent: Vector2=Vector2(155,210)*(0.78+t*.22)
		if not _sprite(canvas,"skill-meteor",p,extent,-.2):
			Expansion.sprite(canvas,"meteor",p,extent,-.2)
		for i: int in range(1 if reduced else 3):
			_line(canvas,PackedVector2Array([p+Vector2(-12-i*9,-24),p+Vector2(-55-i*12,-90-i*13)]),Color("ffd276"),3,.45*(1-i*.2))
	var shield: float=0
	for layer: Dictionary in battle.get("shields",[]):
		if bool(layer.get("active_skill",false)): shield+=float(layer.amount)
	if shield>0:
		Expansion.sprite(canvas,"barrier",Vector2(213,309),Vector2(330,405),0,.40)
		_ring(canvas,Vector2(219,472),143,Color("b5e7bb"),.8)
		var font: Font=preload("res://theme/main.tres").default_font
		canvas.draw_string_outline(font,Vector2(178,487),GameLocale.text("守护 %d" % ceili(shield)),HORIZONTAL_ALIGNMENT_LEFT,-1,17,3,Color("303b38"))
		canvas.draw_string(font,Vector2(178,487),GameLocale.text("守护 %d" % ceili(shield)),HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("e5efb5"))
	for effect: Dictionary in effects:
		if effect.type!="skill_impact": continue
		var age: float=effect.age
		var t: float=clampf(age/float(effect.life),0,1)
		var alpha: float=1-t
		var p: Vector2=Vector2(effect.get("x",700),effect.get("y",460))
		match str(effect.get("skill_id","")):
			"meteor":
				_ring(canvas,p,40+210*sqrt(t),Color("f3b971"),alpha)
				if age<.65:
					var blast_scale: float=.86+.3*sin(minf(1,age/.3)*PI*.5)
					if not _sprite(canvas,"skill-meteor-impact",p,Vector2(260,200)*blast_scale,0,minf(1,(.65-age)/.28)):
						Frames.draw(canvas,"effects","meteor_impact",age,.65,p+Vector2(0,-38),Vector2(230,190))
				for i: int in range(4 if reduced else 8):
					var angle: float=i*TAU/8
					var chip: Vector2=p+Vector2(cos(angle)*145*t,-sin(t*PI)*64-absf(sin(angle))*75*t)
					Paint.sprite(canvas,"C02",i%4,chip,Vector2(18,18),angle,Color(1,.8,.55,alpha))
			"thunder":
				var targets: Array=effect.get("targets",[])
				for i: int in range(targets.size()):
					var hit: Dictionary=targets[i]
					var end: Vector2=Vector2(hit.x,hit.y)-Vector2(0,18)
					var start: Vector2=Vector2(hit.get("from_x",hit.x),hit.get("from_y",105))-Vector2(0,18) if bool(hit.get("chain",false)) else Vector2(end.x-38,88)
					if age<.36:
						_bolt(canvas,start,end,int(effect.get("pulse",0))*4+i,1-age/.36,4 if i>0 or reduced else 7)
					Paint.sprite(canvas,"C03",mini(3,int(t*4)),end,Vector2(64,68),0,Color(1,1,1,alpha))
			"quake":
				var center: Vector2=Vector2(750,486)
				_ring(canvas,center,85+500*t,Color("ffdb92"),alpha)
				_ring(canvas,center,30+340*t,Color("dba763"),alpha*.7)
				if age<.6: _sprite(canvas,"skill-paw",center+Vector2(0,-44),Vector2(190,180)*(1+t*.25),0,1-age/.6)
				for hit: Dictionary in effect.get("targets",[]):
					var at: Vector2=Vector2(hit.x,hit.y)
					_line(canvas,PackedVector2Array([at+Vector2(-32,0),at+Vector2(-16,-9),at+Vector2(1,2),at+Vector2(19,-11),at+Vector2(36,-1)]),Color("e7b565"),3,alpha)
			"roar":
				# Damage is simultaneous: four visible pressure fronts appear at
				# every depth on that same impact, then drift as harmless afterwaves.
				for i: int in range(0 if bool(battle.get("cinematic",{}).get("active",false)) else 4):
					var arc: PackedVector2Array=[]
					for j: int in range(17):
						var angle: float=-PI*.4+j*PI*.8/16
						arc.append(Vector2(375+i*230+70*t+cos(angle)*62,331+sin(angle)*180))
					_line(canvas,arc,Color("e5c8f3"),4.0,.7*alpha)
				for hit: Dictionary in effect.get("targets",[]):
					var start: Vector2=Vector2(float(hit.get("from_x",hit.x)),float(hit.y)-22)
					var end: Vector2=Vector2(float(hit.get("to_x",hit.x)),float(hit.y)-22)
					if start.distance_to(end)>8 and age<.4:
						var at: Vector2=start.lerp(end,1-pow(maxf(0,1-age/.22),2))
						_line(canvas,PackedVector2Array([at+Vector2(-58,-4),at+Vector2(-33,-12),at+Vector2(-12,-7)]),Color("eee1b4"),2.5,(1-age/.4)*.6)
			"sanctuary":
				var active: Array=state.get("active",[])
				for i: int in range(mini(active.size(),5)):
					var to: Vector2=Positions.FEET[i]+Vector2(0,-42)
					var from: Vector2=p
					var curve: PackedVector2Array=[]
					for j: int in range(17):
						var fraction: float=j/16.0
						curve.append(from.lerp(to,fraction)+Vector2(0,-sin(fraction*PI)*60))
					_line(canvas,curve,Color("c4ecc9"),2.5,alpha*.8)
					Paint.sprite(canvas,"C06",mini(3,int(t*4)),to,Vector2(55,60),0,Color(1,1,1,alpha))
			"rage":
				_ring(canvas,p,24+90*t,Color("f4ac56"),alpha)
