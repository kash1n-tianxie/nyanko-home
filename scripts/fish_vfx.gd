extends RefCounted
## Painted attachments read resolved combat state only: no rolls, damage, nodes or state writes.
## Frames are semantic art: 0 projectile/charm, 1 motion, 2 impact, 3 aura/burst.
const Paint = preload("res://scripts/painted_vfx.gd")
const BuildArt = preload("res://scripts/build_art.gd")
const Weapons = preload("res://scripts/weapon_vfx.gd")
# Crops reuse the original painted ice/fire/electric brushwork, with no new repaint.
const COAT_PARTS: Dictionary={
	"fire":{"key":"fire_coat","region":Rect2(0,28,235,293)},
	"ice":{"key":"ice_coat","region":Rect2(114,0,311,119)},
	"electric":{"key":"electric_coat","region":Rect2(49,0,397,125)}}
static var _coat_parts: Dictionary={}

## Spatial roles keep the weapon's center visible even with all three elements.
static func element_layout(projectile: Dictionary, elements: Array) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var core: Vector2=Weapons.PROJECTILE_SIZE.get(str(projectile.get("cat","C01")),Vector2(60,46))
	if str(projectile.get("cat",""))=="C05" and bool(projectile.get("path_child",false)): core*=.44
	var emphasis: float=clampf(float(projectile.get("visual_emphasis",1.0)),.35,1.0)
	var branch: float=.78 if emphasis<.8 else 1.0
	if "fire" in elements: result.append({"element":"fire","offset":Vector2(-core.x*.60,2),"size":Vector2(core.x*.66,core.y*.82)*branch,"alpha":.85*emphasis})
	if "ice" in elements: result.append({"element":"ice","offset":Vector2(1,-core.y*.44),"size":Vector2(core.x*.74,core.y*.44)*branch,"alpha":.83*emphasis})
	if "electric" in elements: result.append({"element":"electric","offset":Vector2(-3,core.y*.43),"size":Vector2(core.x*.72,core.y*.333)*branch,"alpha":.86*emphasis})
	return result

static func _coat_part(element: String) -> AtlasTexture:
	if not _coat_parts.has(element):
		var source: Texture2D=BuildArt.texture(str(COAT_PARTS[element].key))
		if source==null: return null
		var part: AtlasTexture=AtlasTexture.new()
		part.atlas=source
		part.region=COAT_PARTS[element].region
		part.filter_clip=true
		_coat_parts[element]=part
	return _coat_parts[element]

static func draw_projectile(canvas: Node2D, projectile: Dictionary, pos: Vector2, direction: Vector2, fish_snapshot: Dictionary, clock: float, reduced: bool) -> void:
	var payload: Dictionary = projectile.get("payload",{})
	var fishes: Dictionary = payload.get("fish",fish_snapshot.get("fish",fish_snapshot))
	var axis: Vector2 = direction.normalized() if direction.length_squared()>.001 else Vector2.RIGHT
	var angle: float = axis.angle()
	var elements: Array = payload.get("elements",[]).duplicate()
	# Legacy saved missiles gain a presentation from their equipped fish, without new damage.
	if payload.is_empty():
		if _unlocked(fishes.get("F02",{})): elements.append("fire")
		if _unlocked(fishes.get("F06",{})): elements.append("electric")
		if _unlocked(fishes.get("F04",{})) or (_unlocked(fishes.get("F01",{})) and float(fishes.get("F01",{}).get("freeze",0))>0): elements.append("ice")
	var pulse: float = 1.0 if reduced else 1.0+sin(clock*11+float(projectile.get("id",0)))*.025
	for layer: Dictionary in element_layout(projectile,elements):
		var texture: AtlasTexture=_coat_part(str(layer.element))
		if texture==null: continue
		var location: Vector2=pos+Vector2(layer.offset).rotated(angle)
		var extent: Vector2=Vector2(layer.size)*(pulse if layer.element=="fire" else 1.0)
		Paint.draw_texture(canvas,texture,location,extent,angle,Color(1,1,1,float(layer.alpha)))
	if str(projectile.get("carrier",projectile.get("kind","")))=="echo":
		Paint.sprite(canvas,"F05",1,pos-axis*31,Vector2(39,21),angle,_opacity(.48))
	if bool(payload.get("critical",projectile.get("critical",false))):
		Paint.sprite(canvas,"F07",1,pos-axis*35,Vector2(28,21),angle,_opacity(.82))

static func draw_event(canvas: Node2D, event: Dictionary, pos: Vector2, age: float, reduced: bool, _font: Font) -> void:
	var event_type: String = str(event.get("type",""))
	var kind: String = str(event.get("kind",""))
	var fish: String = str(event.get("fish",""))
	var duration: float = .28
	if event_type in ["shield","block","safeguard"]: duration = .80
	if event_type=="chain": duration = .24
	if event_type=="burst": duration = .26
	if event_type=="hit" and kind=="burn": duration = .28
	if age<0.0 or age>duration: return
	var progress: float = age/duration
	var alpha: float = _fade(progress)
	var growth: float = 1.0+progress*(.06 if reduced else .15)
	match event_type:
		"chain":
			var start: Vector2 = Vector2(float(event.get("from_x",event.get("x",pos.x))),float(event.get("from_y",pos.y)))
			var end: Vector2 = Vector2(float(event.get("to_x",pos.x)),float(event.get("to_y",pos.y)))
			# The moving bright head travels along the actual resolved chain endpoints.
			var head: Vector2 = start.lerp(end,minf(1.0,progress*2.7))
			Paint.beam(canvas,"F06",1,start,head,7 if reduced else 10,_opacity(alpha*.90))
			Paint.sprite(canvas,"F06",2,head,Vector2.ONE*19,0.0,_opacity(alpha))
		"freeze":
			Paint.sprite(canvas,"F04",2,pos,Vector2.ONE*28*growth,0.0,_opacity(alpha*.95))
			if fish=="F06": Paint.sprite(canvas,"F06",0,pos+Vector2(12,-12),Vector2(16,16),0.0,_opacity(alpha))
		"critical":
			if fish=="F07" or bool(event.get("critical",true)): _impact(canvas,"F07",pos,progress,reduced,29)
		"hit": _draw_hit(canvas,event,pos,progress,reduced)
		"burst": _draw_burst(canvas,event,pos,progress,reduced)
		"vfx_status": _draw_status_event(canvas,event,pos,progress,reduced)
		"shield":
			if fish=="F08": Paint.sprite(canvas,"F08",1,pos+Vector2(0,-12),Vector2(81,91)*growth,0.0,_opacity(alpha*.83))
		"shield_absorb": _impact(canvas,"F08",pos+Vector2(2,-6),progress,reduced,49)
		"block": Paint.sprite(canvas,"F08",2,pos+Vector2(0,-10),Vector2.ONE*76*growth,0.0,_opacity(alpha))
		"safeguard": Paint.sprite(canvas,"F08",1,pos+Vector2(0,-20),Vector2(104,119)*growth,0.0,_opacity(alpha))

static func draw_status(canvas: Node2D, enemy: Dictionary, ground_pos: Vector2, height: float, clock: float, reduced: bool) -> void:
	var center: Vector2 = ground_pos-Vector2(0,height*.48)
	var width: float = clampf(height*.45,17.0,48.0)
	var pulse: float = 1.0 if reduced else .92+sin(clock*5+float(enemy.get("id",0)))*.08
	if float(enemy.get("freeze",0.0))>0.0:
		# The transparent painted ice shell keeps the enemy silhouette visible inside.
		Paint.sprite(canvas,"F04",3,center,Vector2(width*1.9,height+9),0.0,_opacity(.38))
	elif float(enemy.get("slow_left",0.0))>0.0:
		Paint.sprite(canvas,"F04",1,ground_pos+Vector2(0,-6),Vector2(width*1.7,15),0.0,_opacity(.72))
	if float(enemy.get("stun",0.0))>0.0:
		# A small orbit above the head signals stun without covering the body.
		for index: int in range(3):
			var a: float = clock*4+index*TAU/3
			var star: Vector2 = ground_pos+Vector2(cos(a)*15,-height-17+sin(a)*4)
			canvas.draw_line(star-Vector2(3,0),star+Vector2(3,0),Color("ffe39a"),1.8,true)
			canvas.draw_line(star-Vector2(0,3),star+Vector2(0,3),Color("ffe39a"),1.8,true)
	var burns: Array = enemy.get("burns",[])
	if not burns.is_empty():
		Paint.sprite(canvas,"F02",3,ground_pos+Vector2(width*.35,-12),Vector2(23,29)*pulse,0.0,_opacity(.88))
	if float(enemy.get("weak_left",0.0))>0.0:
		Paint.sprite(canvas,"F05",0,center+Vector2(width+7,-13),Vector2(15,15),PI*.5,_opacity(.76))
	if not enemy.get("electric_mark",{}).is_empty():
		Paint.sprite(canvas,"F06",0,center+Vector2(-width-8,-12),Vector2.ONE*16*pulse,0.0,_opacity(.95))
	if not enemy.get("pearl_mark",{}).is_empty():
		Paint.sprite(canvas,"F07",0,center+Vector2(width+7,10),Vector2(16,16),0.0,_opacity(.92))

static func draw_cat_aura(canvas: Node2D, cat_snapshot: Dictionary, origin: Vector2, clock: float, reduced: bool) -> void:
	var fishes: Dictionary = cat_snapshot.get("fish",{})
	var mint: Dictionary = fishes.get("F05",{})
	if _unlocked(mint):
		var phase: float = 0.0 if reduced else clock*2+float(str(cat_snapshot.get("id","C01")).substr(1))
		Paint.sprite(canvas,"F05",0,origin+Vector2(-25,-9-sin(phase)*3),Vector2(19,19),-.30,_opacity(.82))
	if _unlocked(fishes.get("F08",{})):
		# This is an equipment charm; only an accepted shield event paints a protective shell.
		Paint.sprite(canvas,"F08",0,origin+Vector2(-25,11),Vector2(19,19),0.0,_opacity(.83))

static func _draw_hit(canvas: Node2D, event: Dictionary, pos: Vector2, progress: float, reduced: bool) -> void:
	var kind: String = str(event.get("kind",""))
	var alpha: float = _fade(progress)
	var from_pos: Vector2 = Vector2(float(event.get("from_x",pos.x)),float(event.get("from_y",pos.y)))
	match kind:
		"return","bounce","pierce","echo":
			if kind=="echo": _impact(canvas,"F05",pos,progress,reduced,24)
		"burn": Paint.sprite(canvas,"F02",0,pos+Vector2(0,-progress*9),Vector2.ONE*16,0.0,_opacity(alpha*.72))
		"spark","burn_burst": _impact(canvas,"F02",pos,progress,reduced,27)
		"chain","electric_burst","electric_mark","thunder":
			_impact(canvas,"F06",pos,progress,reduced,24)
			if kind=="electric_mark" and from_pos.distance_to(pos)>3.0:
				Paint.beam(canvas,"F06",1,from_pos,pos,8,_opacity(alpha*.72))
		"iceburst": _impact(canvas,"F04",pos,progress,reduced,28)
		"pearl":
			var t: float = minf(1.0,progress*3.0)
			Paint.sprite(canvas,"F07",1,from_pos.lerp(pos,t),Vector2(24,18),(pos-from_pos).angle(),_opacity(alpha))
			_impact(canvas,"F07",pos,progress,reduced,27)
		"shield_break": Paint.sprite(canvas,"F08",3,pos,Vector2.ONE*(32+progress*9),0.0,_opacity(alpha))

static func _draw_burst(canvas: Node2D, event: Dictionary, pos: Vector2, progress: float, reduced: bool) -> void:
	var kind: String = str(event.get("kind",""))
	var radius: float = clampf(float(event.get("radius",80.0)),30.0,130.0)
	var alpha: float = _fade(progress)
	var size: float = burst_diameter(radius,reduced)*(.68+minf(progress*4,1)*.32)
	# A compact, single blast is painted below enemy silhouettes. The clear ground ring
	# indicates the resolved area; it is not a second opaque burst over their faces.
	var tint: Color = Color("f9ba6d")
	if kind in ["iceburst"]: tint=Color("a5e9ef")
	elif kind in ["electric_burst","thunder"]: tint=Color("b6b7ff")
	if kind=="thunder":
		Paint.beam(canvas,"F06",1,pos-Vector2(0,56),pos,8,_opacity(alpha))
	var key: String = ""
	match kind:
		"spark","burn_burst","fire_impact": key="fire_burst"
		"iceburst": key="ice_shatter"
		"electric_burst","thunder": key="electric_burst"
	if not key.is_empty():
		BuildArt.sprite(canvas,key,pos+Vector2(0,4),Vector2.ONE*size,0,alpha*.87)
	elif kind=="pearl": Paint.sprite(canvas,"F07",2,pos,Vector2.ONE*size*.6,0,_opacity(alpha))
	elif kind=="shield_break": Paint.sprite(canvas,"F08",3,pos,Vector2.ONE*size*.7,0,_opacity(alpha))
	else: return
	if not reduced:
		canvas.draw_set_transform(pos+Vector2(0,16),0,Vector2(1,.20))
		canvas.draw_arc(Vector2.ZERO,radius*(.55+progress*.45),0,TAU,32,Color(tint,alpha*.42),1.6,true)
		canvas.draw_set_transform(Vector2.ZERO)

static func burst_diameter(radius: float, reduced: bool=false) -> float:
	return clampf(radius*.68,38.0,62.0 if reduced else 78.0)

static func _unlocked(config: Dictionary) -> bool:
	return bool(config.get("mechanic_unlocked",int(config.get("level",0))>=3))

static func _draw_status_event(canvas: Node2D, event: Dictionary, pos: Vector2, progress: float, reduced: bool) -> void:
	var kind: String = str(event.get("kind",""))
	if bool(event.get("refresh",false)): return
	var alpha: float = _fade(progress)*.87
	var lift: Vector2 = Vector2(0,-progress*(4 if reduced else 13))
	match kind:
		"burn":
			if bool(event.get("spread",false)) and event.has("from_x"):
				var from_pos: Vector2 = Vector2(float(event.from_x),pos.y)
				var t: float = minf(1.0,progress*3.0)
				Paint.sprite(canvas,"F02",1,from_pos.lerp(pos,t)+Vector2(0,-sin(t*PI)*21),Vector2(23,18),(pos-from_pos).angle(),_opacity(alpha))
			Paint.sprite(canvas,"F02",0,pos+lift,Vector2.ONE*18,0.0,_opacity(alpha*.75))
		"slow":
			Paint.sprite(canvas,"F04",0,pos+lift,Vector2.ONE*18,0.0,_opacity(alpha))
			if str(event.get("visual_kind","")) in ["ring","death_ice"]:
				Paint.sprite(canvas,"F04",2,pos,Vector2.ONE*(26+progress*8),0.0,_opacity(alpha*.70))
		"weak": Paint.sprite(canvas,"F05",0,pos+lift,Vector2.ONE*18,PI*.5,_opacity(alpha))
		"pearl_mark": Paint.sprite(canvas,"F07",0,pos+Vector2(0,-13)+lift,Vector2.ONE*19,0.0,_opacity(alpha))
		"electric_mark": Paint.sprite(canvas,"F06",0,pos+lift,Vector2.ONE*19,0.0,_opacity(alpha))
		"pearl_consume": _impact(canvas,"F07",pos,progress,reduced,29)

static func _impact(canvas: Node2D, key: String, pos: Vector2, progress: float, reduced: bool, size: float) -> void:
	var growth: float = .88+progress*(.10 if reduced else .20)
	Paint.sprite(canvas,key,2,pos,Vector2.ONE*size*growth,0.0,_opacity(_fade(progress)))

static func _opacity(alpha: float) -> Color:
	return Color(1,1,1,clampf(alpha,0.0,1.0))

static func _fade(progress: float) -> float:
	# A readable short hold followed by a clean fade, instead of a flashing first frame.
	return 1.0-smoothstep(.10,1.0,progress)
