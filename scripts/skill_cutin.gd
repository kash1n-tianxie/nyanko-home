extends Control
const GameLocale=preload("res://scripts/game_locale.gd")
## Full-screen, saved action timeline. Draws authored key poses, never owns damage.
const Data=preload("res://scripts/catalog.gd")
const Art=preload("res://scripts/illustrated_atlas.gd")
const Catalog=preload("res://scripts/skill_catalog.gd")
const Positions=preload("res://scripts/cat_combat_positions.gd")
const DURATION: float=4.2 # Compatibility: per-cast duration is authoritative.
const COLORS: Dictionary={"C01":Color("d95339"),"C02":Color("df9850"),"C03":Color("68c7d1"),"C04":Color("dca74b"),"C05":Color("af8bbd"),"C06":Color("80bfa7")}
var age: float=0.0
var cast: Dictionary={}
var cinema: Dictionary={}
var state: Dictionary={}
var reduced: bool=false
var textures: Dictionary={}
var pose_metrics: Dictionary={}
var font: Font=preload("res://theme/main.tres").default_font
var camera: Transform2D=Transform2D.IDENTITY

func _ready() -> void:
	name="CatSkillCinema"
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	position=Vector2.ZERO;size=Vector2(1280,720)
	clip_contents=true;visible=false
	var manifest_path: String="res://art/cinema-v038/manifest.json"
	if FileAccess.file_exists(manifest_path):
		var manifest: Variant=JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		if manifest is Dictionary: pose_metrics=manifest.get("cats",{})

func show_cast(data: Dictionary,motion_reduced: bool) -> void:
	cast=data.duplicate(true);age=0.0;reduced=motion_reduced
	visible=true;queue_redraw()

func set_frame(current: Dictionary,motion_reduced: bool) -> void:
	state=current;reduced=motion_reduced
	cinema=current.get("battle",{}).get("cinematic",{})
	if not bool(cinema.get("active",false)):
		clear();return
	cast=cinema.get("cast",{});age=float(cinema.get("age",0))
	camera=camera_transform(current,reduced)
	visible=true;queue_redraw()

func tick(_delta: float,_paused: bool) -> void:
	# The authoritative real clock is CatSkills.tick_cinematic, including on reload.
	queue_redraw()

func clear() -> void:
	cast={};cinema={};visible=false;camera=Transform2D.IDENTITY
	queue_redraw()

func busy() -> bool:
	return visible and bool(cinema.get("active",false))

static func camera_transform(current: Dictionary,motion_reduced: bool=false) -> Transform2D:
	var data: Dictionary=current.get("battle",{}).get("cinematic",{})
	if not bool(data.get("active",false)): return Transform2D.IDENTITY
	var t: float=float(data.get("age",0))
	var span: float=float(data.get("duration",3.8))
	var action: Dictionary=data.get("cast",{})
	var arrive: float=float(action.get("impact_delay",2.25))
	var zoom: float=1.0+.34*smoothstep(.15,.72,t)*(1.0-smoothstep(span-.58,span,t))
	var focus: Vector2=Vector2(680,350)
	if str(data.get("cat","")) in ["C02","C04"]: focus=Vector2(clampf(float(action.get("target_x",750)),580,980),360)
	var offset: Vector2=Vector2(focus.x-focus.x*zoom,0)
	if not motion_reduced and t>=arrive and t<arrive+.18:
		offset+=Vector2(sin((t-arrive)*91),cos((t-arrive)*73))*5.0*(1-(t-arrive)/.18)
	return Transform2D(0,Vector2.ONE*zoom,0,offset)

func _texture(path: String) -> Texture2D:
	if textures.has(path): return textures[path]
	if ResourceLoader.exists(path): textures[path]=load(path);return textures[path]
	return null

func _pose(id: String,frame: int) -> Texture2D:
	var tex: Texture2D=_texture("res://art/cinema-v038/cats/%s-%02d.png" % [id,clampi(frame,0,5)])
	return tex if tex!=null else Art.cat(id,"attack" if frame in [2,3] else "idle")

func _sprite(tex: Texture2D,feet: Vector2,height: float,turn: float=0,stretch: Vector2=Vector2.ONE,alpha: float=1.0) -> void:
	if tex==null: return
	var reference_height: float=float(tex.get_height())
	if tex.resource_path.contains("cinema-v038/cats/"):
		var id: String=tex.resource_path.get_file().substr(0,3)
		var metrics: Dictionary=pose_metrics.get(id,{})
		var span: float=float(cinema.get("duration",4.2))
		var home_blend: float=smoothstep(span-.58,span,age)
		reference_height=lerpf(float(metrics.get("common_occupied_height",reference_height)),float(metrics.get("settle_occupied_height",reference_height)),home_blend)
	var extent: Vector2=tex.get_size()*(height/maxf(1,reference_height))
	draw_set_transform(feet,turn,stretch)
	draw_texture_rect(tex,Rect2(-extent*Vector2(.5,.9375),extent),false,Color(1,1,1,alpha))
	draw_set_transform(Vector2.ZERO)

func _effect(key: String,center: Vector2,height: float,alpha: float=1.0) -> void:
	var tex: Texture2D=_texture("res://art/skills-v037/%s.png" % key)
	if tex==null: return
	var extent: Vector2=tex.get_size()*(height/float(tex.get_height()))
	draw_texture_rect(tex,Rect2(center-extent*.5,extent),false,Color(1,1,1,alpha))

func _paper(points: PackedVector2Array,color: Color) -> void:
	draw_colored_polygon(points,color)
	var edge: PackedVector2Array=points.duplicate();edge.append(edge[0])
	draw_polyline(edge,Color("30282f"),4,true)

func _beam(from: Vector2,to: Vector2,color: Color,width: float=4) -> void:
	draw_line(from,to,Color("30282f")*Color(1,1,1,color.a),width+3,true)
	draw_line(from,to,color,width,true)

func _arc(center: Vector2,radius: Vector2,color: Color,alpha: float) -> void:
	var points: PackedVector2Array=[]
	for i: int in range(49): points.append(center+Vector2(cos(TAU*i/48)*radius.x,sin(TAU*i/48)*radius.y))
	draw_polyline(points,Color(color,alpha),3,true)

func _draw() -> void:
	if cast.is_empty() or not visible: return
	var id: String=str(cast.cat)
	var span: float=float(cinema.get("duration",cast.get("duration",3.8)))
	var accent: Color=COLORS.get(id,COLORS.C01)
	var exit_blend: float=smoothstep(span-.5,span,age)
	var reveal: float=smoothstep(.0,.15,age)
	var anticipation: float=1-smoothstep(.8,1.15,age)
	# The opening/closing paper matte covers the old dock while the action camera
	# fills the screen with the real arena. It never stretches the scenery texture.
	var floor_edge: float=(camera*Vector2(0,548)).y
	if floor_edge<720: draw_rect(Rect2(0,maxf(0,floor_edge-1),1280,722-floor_edge),Color("30272f"))
	# Wide authored-action composition, then open onto the actual target field.
	draw_rect(Rect2(0,0,1280,720),Color("30272f")*Color(1,1,1,(.16+.28*anticipation)*(1-exit_blend)*reveal))
	if anticipation>.001:
		_paper(PackedVector2Array([Vector2(-30,18),Vector2(1290,-22),Vector2(1270,122),Vector2(-10,172)]),Color(accent.darkened(.52),anticipation*.9))
		_paper(PackedVector2Array([Vector2(-30,610),Vector2(1275,650),Vector2(1310,740),Vector2(-10,735)]),Color("efe1bf")*Color(1,1,1,anticipation))
		for i: int in range(14):
			var from: Vector2=Vector2(-30,210+i*29)
			var to: Vector2=Vector2(450-i%3*48,180+i*27)
			draw_line(from,to,Color(accent,anticipation*.16),2,true)
	var title_alpha: float=reveal*(1-smoothstep(.75,1.15,age))
	if title_alpha>0:
		draw_string_outline(font,Vector2(54,90),GameLocale.text(str(cast.get("name",""))),HORIZONTAL_ALIGNMENT_LEFT,800,49,6,Color("30282f")*Color(1,1,1,title_alpha))
		draw_string(font,Vector2(54,90),GameLocale.text(str(cast.get("name",""))),HORIZONTAL_ALIGNMENT_LEFT,800,49,Color("fff0c9")*Color(1,1,1,title_alpha))
		draw_string(font,Vector2(63,677),GameLocale.text(str(Data.cats()[id].name)+"  ·  绝招"),HORIZONTAL_ALIGNMENT_LEFT,800,27,Color(accent.darkened(.45),title_alpha))
	match id:
		"C01": _rage(span)
		"C02": _meteor(span)
		"C03": _thunder(span)
		"C04": _hammer(span)
		"C05": _roar(span)
		"C06": _bell(span)
	_draw_result(span)

func _return(feet: Vector2,height: float,span: float) -> Dictionary:
	var blend: float=smoothstep(span-.58,span,age)
	var index: int=state.get("active",[]).find(str(cast.cat))
	var home: Vector2=camera*Positions.FEET[clampi(index,0,4)]
	return {"feet":feet.lerp(home,blend),"height":lerpf(height,88*camera.get_scale().x,blend)}

func _rage(span: float) -> void:
	var frame: int=0 if age<.35 else (1 if age<.85 else (2 if age<1.55 else (3 if age<2.2 else (4 if age<span-.58 else 5))))
	var height: float=430.0+40*smoothstep(.85,1.55,age)
	var feet: Vector2=Vector2(610,610)
	if age>1.55 and age<2.55:
		var burst: float=clampf((age-1.55)/.6,0,1)
		for i: int in range(15):
			var direction: Vector2=Vector2.RIGHT.rotated(i*TAU/15)
			_beam(Vector2(610,390)+direction*(120+burst*100),Vector2(610,390)+direction*(150+burst*215),Color("f4ae60")*Color(1,1,1,1-smoothstep(1.95,2.55,age)),4)
	var end: Dictionary=_return(feet,height,span)
	_sprite(_pose("C01",frame),end.feet,end.height,0,Vector2(1+.05*sin(age*11),1),1)

func _meteor(span: float) -> void:
	var frame: int=0 if age<.45 else (1 if age<1.1 else (2 if age<1.8 else (3 if age<2.65 else (4 if age<span-.58 else 5))))
	var end: Dictionary=_return(Vector2(308,600),385,span)
	_sprite(_pose("C02",frame),end.feet,end.height,0,Vector2(1,1))
	if age>=1.15 and age<2.55:
		var t: float=clampf((age-1.15)/1.4,0,1)
		var target: Vector2=camera*Vector2(cast.target_x,cast.target_y)
		var point: Vector2=Vector2(810,-150).lerp(target,t*t)
		_effect("skill-meteor",point,320-80*t)
		for i: int in range(4): _beam(point+Vector2(-55-i*18,-62),point+Vector2(-95-i*26,-175),Color("ffcc7c"),3)

func _thunder(span: float) -> void:
	var frame: int=0 if age<.4 else (1 if age<1.0 else (2 if age<1.65 else (3 if age<2.85 else (4 if age<span-.58 else 5))))
	var end: Dictionary=_return(Vector2(310,600),400,span)
	_sprite(_pose("C03",frame),end.feet,end.height)
	if age>1.0 and age<3.1:
		var alpha: float=smoothstep(1,1.4,age)*(1-smoothstep(2.85,3.1,age))
		var cloud: PackedVector2Array=PackedVector2Array([Vector2(390,120),Vector2(405,27),Vector2(525,75),Vector2(690,35),Vector2(820,65),Vector2(1000,15),Vector2(1055,120),Vector2(1160,155),Vector2(1105,210),Vector2(430,215),Vector2(340,165)])
		draw_colored_polygon(cloud,Color("263d4e")*Color(1,1,1,alpha*.86))
		_beam(Vector2(620,135),Vector2(665,145),Color("d9f9f3"),7)
		_beam(Vector2(828,145),Vector2(878,132),Color("d9f9f3"),7)
		for hit: Dictionary in cinema.get("impact_history",[]):
			var since: float=age-float(hit.cinematic_age)
			if since>=0 and since<.22:
				var end_point: Vector2=camera*Vector2(hit.x,hit.y)
				var bolt: PackedVector2Array=[Vector2(end_point.x-30,160),Vector2(end_point.x+14,244),Vector2(end_point.x-18,300),end_point]
				draw_polyline(bolt,Color("c4f6ef")*Color(1,1,1,1-since/.22),7,true)

func _hammer(span: float) -> void:
	var frame: int=0
	var feet: Vector2=Vector2(430,620)
	var height: float=390
	if age<.35:
		frame=0
	elif age<1.35:
		frame=1;feet=Vector2(430,620).lerp(Vector2(770,415),sin((age-.35)*PI*.5));height=370
	elif age<1.7:
		frame=2;feet=Vector2(770,415);height=370
	elif age<2.25:
		frame=3
		var t: float=pow(clampf((age-1.7)/.55,0,1),2)
		feet=Vector2(770,415).lerp(camera*Vector2(750,505),t);height=370
		if not reduced:
			for i: int in range(5): _beam(feet+Vector2(-105+i*48,-250),feet+Vector2(-105+i*48,-340-30*t),Color("edcf91"),3)
	else:
		frame=3 if age<2.43 else (4 if age<span-.58 else 5);feet=camera*Vector2(750,505);height=350
		var t: float=clampf((age-2.25)/.7,0,1)
		_arc(feet,Vector2(160+600*t,35+95*t),Color("ffe0a0"),1-t)
	var end: Dictionary=_return(feet,height,span)
	_sprite(_pose("C04",frame),end.feet,end.height)

func _roar(span: float) -> void:
	var frame: int=0 if age<.35 else (1 if age<.9 else (2 if age<1.45 else (3 if age<2.5 else (4 if age<span-.58 else 5))))
	var end: Dictionary=_return(Vector2(335,610),420,span)
	_sprite(_pose("C05",frame),end.feet,end.height,0,Vector2(1+.10*sin(clampf(age/1.45,0,1)*PI),1))
	if age>=1.45 and age<2.65:
		var t: float=clampf((age-1.45)/.9,0,1)
		var x: float=lerpf(326,1280,t)
		var points: PackedVector2Array=[]
		for j: int in range(25):
			var angle: float=-PI*.48+j*PI*.96/24
			points.append(camera*(Vector2(x,330)+Vector2(cos(angle)*65,sin(angle)*230)))
		draw_polyline(points,Color("e9cbf1"),9,true)

func _bell(span: float) -> void:
	var frame: int=0 if age<.4 else (1 if age<.95 else (2 if age<1.85 else (3 if age<2.4 else (4 if age<span-.58 else 5))))
	var end: Dictionary=_return(Vector2(720,610),400,span)
	_sprite(_pose("C06",frame),end.feet,end.height)
	if age>.65 and age<2.5:
		var t: float=clampf((age-.65)/1.2,0,1)
		for i: int in range(state.get("active",[]).size()):
			var goal: Vector2=camera*(Positions.FEET[i]+Vector2(0,-42))
			var point: Vector2=Vector2(665,350).lerp(goal,t)+Vector2(0,-sin(t*PI)*(80+i*15))
			draw_circle(point,18,Color("263c36"));draw_circle(point,14,Color("bbebbd"))
			draw_string(font,point+Vector2(-10,10),GameLocale.text("♪"),HORIZONTAL_ALIGNMENT_LEFT,30,30,Color("324c3b"))
	if age>=1.85:
		var strength: float=smoothstep(1.85,2.15,age)*(1-smoothstep(span-.5,span,age))
		_arc(camera*Vector2(220,340),Vector2(170,220),Color("ceecca"),strength)

func _draw_result(span: float) -> void:
	if age<span-.75: return
	var damage: float=0
	var targets: Dictionary={}
	var stunned: int=0
	for notice: Dictionary in cinema.get("impact_history",[]):
		for hit: Dictionary in notice.get("targets",[]):
			damage+=float(hit.get("damage",0))
			targets[int(hit.id)]=true
			if float(hit.get("stun",0))>0: stunned+=1
	var label: String=""
	match str(cast.cat):
		"C01": label="狂暴就绪  ·  攻击 ×2  攻速 ×2"
		"C06":
			var history: Array=cinema.get("impact_history",[])
			if not history.is_empty(): label="守护 +%d  ·  净化 %d 位" % [roundi(float(history[0].get("shield",0))),history[0].get("cleansed",[]).size()]
		_: label="命中 %d  ·  伤害 %d" % [targets.size(),roundi(damage)]
	if stunned>0: label+="  ·  眩晕 %d" % stunned
	var alpha: float=smoothstep(span-.75,span-.55,age)*(1-smoothstep(span-.16,span,age))
	_paper(PackedVector2Array([Vector2(385,630),Vector2(1150,613),Vector2(1160,669),Vector2(393,683)]),Color("efe1bf")*Color(1,1,1,alpha))
	draw_string(font,Vector2(418,655),GameLocale.text(label),HORIZONTAL_ALIGNMENT_LEFT,720,25,Color("3b3037")*Color(1,1,1,alpha))
