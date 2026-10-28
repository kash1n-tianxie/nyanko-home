extends RefCounted
## One painted attack family per enemy. All cues follow actual windup / base-hit state.
const Paint = preload("res://scripts/painted_vfx.gd")
const Expansion=preload("res://scripts/expansion_vfx.gd")
const CONTACT_ART: Dictionary={"E08":"enemy-hanger","E09":"enemy-saucer","E10":"enemy-tape","X01":"enemy-web","X02":"enemy-radio","X03":"enemy-mop","X04":"enemy-tv","X05":"enemy-web","B04":"enemy-tv"}

static func windup(canvas: Node2D, enemy: Dictionary, feet: Vector2, height: float, reduced: bool) -> void:
	if float(enemy.get("freeze",0))>0 or float(enemy.get("stun",0))>0: return
	var left: float = maxf(float(enemy.get("windup",0)),float(enemy.get("special_windup",0)))
	if left<=0: return
	var boss: bool = bool(enemy.get("boss",false))
	var has_special: bool = float(enemy.get("special_windup",0))>0
	var progress: float = 1-clampf(left/(1.2 if has_special else .6),0,1)
	var size: float = (48.0 if boss else 32.0)*(1+progress*(.06 if reduced else .17))
	var center: Vector2 = feet+Vector2(-height*.35-10,-height*.59)
	_stamp(canvas,str(enemy.kind),0,center,Vector2.ONE*size,.28+progress*.35)

static func strike(canvas: Node2D, event: Dictionary, age: float, reduced: bool) -> void:
	if age<0 or age>.46: return
	var key: String = str(event.get("enemy_kind","E01"))
	if CONTACT_ART.has(key):
		_new_strike(canvas,key,event,age,reduced)
		return
	if key=="B05":
		_moon_strike(canvas,event,age,reduced)
		return
	var boss: bool = key.begins_with("B")
	var heavy: bool = str(event.get("kind","")) in ["heavy","double_bite"]
	var force: float = 1.18 if heavy else 1.0
	var origin: Vector2 = Vector2(float(event.get("from_x",260)),449 if boss else 466)
	var contact: Vector2 = Vector2(338,447 if boss else 466)
	var progress: float = clampf(age/.46,0,1)
	var width: float = (138 if boss else 79)*force
	var height: float = (114 if boss else 73)*force
	if age<.12:
		var travel: float = minf(1,age/.085)
		var center: Vector2 = origin.lerp(contact,travel)
		_stamp(canvas,key,1,center,Vector2(width,height),.95)
	else:
		var frame: int = 2 if age<.22 else 3
		var expansion: float = 1+progress*(.08 if reduced else .30)
		var fade: float = 1-smoothstep(.42,1,progress)
		_stamp(canvas,key,frame,contact,Vector2(width,height)*expansion,fade)

static func _moon_strike(canvas: Node2D, event: Dictionary, age: float, reduced: bool) -> void:
	var start: Vector2=Vector2(float(event.get("from_x",760)),429)
	var finish: Vector2=Vector2(340,448)
	var progress: float=clampf(age/.46,0,1)
	if age<.20:
		var point: Vector2=start.lerp(finish,clampf(age/.18,0,1))
		var size: Vector2=Vector2(156,102) if str(event.get("kind",""))=="moon_tide" else Vector2(130,90)
		_stamp(canvas,"B05",1,point,size,1.0)
		if not reduced: Paint.beam(canvas,"B04",3,start,point,35,Color(1,1,1,.3*(1-progress)))
	else:
		_stamp(canvas,"B05",2 if age<.31 else 3,finish,Vector2(164,139)*(1+progress*.15),1-smoothstep(.5,1,progress))

static func special(canvas: Node2D, event: Dictionary, age: float, reduced: bool) -> void:
	if str(event.get("enemy_kind",event.get("kind","")))!="B05" or age>.7: return
	var x: float=float(event.get("x",event.get("from_x",750)))
	var spread: float=24.0 if reduced else 24.0+age*90
	for i: int in range(3):
		_stamp(canvas,"B05",3,Vector2(x+(i-1)*spread,440-age*45),Vector2(83,71),1-age/.7)

static func _stamp(canvas: Node2D, key: String, frame: int, center: Vector2, bounds: Vector2, alpha: float) -> void:
	if CONTACT_ART.has(key):
		Expansion.sprite(canvas,str(CONTACT_ART[key]),center,bounds,0,alpha)
		return
	var art_key: String = "B04" if key=="B05" else key
	var texture: Texture2D = Paint.texture(art_key,frame)
	if texture==null: return
	var original: Vector2 = texture.get_size()
	var factor: float = minf(bounds.x/original.x,bounds.y/original.y)
	Paint.sprite(canvas,art_key,frame,center,original*factor,0,Color(1,1,1,alpha))

static func _new_strike(canvas: Node2D, key: String, event: Dictionary, age: float, reduced: bool) -> void:
	var from: Vector2=Vector2(float(event.get("from_x",500)),float(event.get("from_y",350)))
	var target: Vector2=Vector2(float(event.get("to_x",350)),float(event.get("to_y",400)))
	var t: float=clampf(age/.46,0,1)
	var point: Vector2=from.lerp(target,minf(1,age/.17))
	var extent: Vector2=Vector2(70,52) if key.begins_with("B") else Vector2(52,41)
	var angle: float=(target-from).angle()+PI
	Expansion.sprite(canvas,str(CONTACT_ART[key]),point,extent*(1.0 if reduced else 1+t*.12),angle,1-smoothstep(.5,1,t))
