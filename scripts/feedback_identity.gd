extends RefCounted
## Visible identities originate only from resolved toy/mechanism events.
const Art = preload("res://scripts/expansion_art.gd")
const Atlas = preload("res://scripts/fish_art.gd")
const Catalog = preload("res://scripts/catalog.gd")
const Frames = preload("res://scripts/frame_art.gd")
const Mounts = preload("res://scripts/toy_mounts.gd")
static var enemy_specs: Dictionary=Catalog.enemies()
const ToyColors: Array[Color] = [Color("f1cd65"),Color("e79964"),Color("d5e7af"),Color("f2ce92"),Color("aabfe9"),Color("9dd2b2"),Color("a2d9ed"),Color("d8e9e4"),Color("d0bb8b"),Color("deb6e6"),Color("ffe3a4"),Color("e7bb6b"),Color("d5a782"),Color("d4b995"),Color("c47e87"),Color("e89583"),Color("ddc2df"),Color("b9aed7"),Color("b2c5ca"),Color("e4d4b2")]
var seen: Dictionary = {}
var cooldowns: Dictionary = {}
func reset() -> void:
	seen.clear()
	cooldowns.clear()
func notice(event: Dictionary, clock: float) -> Dictionary:
	var type: String = str(event.get("type",""))
	var toy: String = str(event.get("source_toy",event.get("toy","")))
	var fish: String = str(event.get("source_fish",event.get("fish","")))
	# visual.fish_ids is built from Build.mechanics, never from locked equipment.
	var active_ids: Array=event.get("payload",{}).get("fish_ids",[])
	var carrier: String=str(event.get("carrier_origin",event.get("carrier",event.get("kind",""))))
	var mechanism: bool = type in ["chain","burst","freeze","stun","vfx_status","shield"]
	if type=="attack" and "F01" in active_ids and int(event.get("count",1))>1:
		fish="F01";toy="";mechanism=true
	elif type=="critical" and "F07" in active_ids:
		fish="F07";toy="";mechanism=true
	elif type=="hit" and float(event.get("amount",0))>0:
		if "F09" in active_ids and bool(enemy_specs.get(str(event.get("enemy_kind","")),{}).get("air",false)):
			fish="F09";toy="";mechanism=true
		elif fish=="F03" and "F03" in active_ids and carrier in ["F03","return","bounce","pierce"]:
			toy="";mechanism=true
		elif fish=="F05" and "F05" in active_ids and carrier in ["F05","echo"]:
			toy="";mechanism=true
	if type!="toy_trigger" and not (toy=="" and fish.begins_with("F") and mechanism): return {}
	var identity: String = toy if toy!="" else fish
	if identity=="": return {}
	var key: String = identity+":"+str(event.get("cat","")) if toy=="" else identity
	# Give a six-frame source performance time to finish before repeating it.
	if clock-float(cooldowns.get(key,-100))<(.76 if toy!="" else .32): return {}
	cooldowns[key] = clock
	var first: bool = not seen.has(key)
	seen[key] = true
	var duration: float = (.74 if first else .48) if toy!="" else (.70 if first else .30)
	return {"type":"mechanism_identity","identity":identity,"toy":toy,"fish":fish,"cat":event.get("cat",""),"first":first,"duration":duration,"x":event.get("x",344),"y":event.get("y",375),"target":event.get("target",0),"metric":event.get("metric",""),"age":0.0}
static func tree_anchor(identity: String, held: Array = []) -> Vector2:
	return Mounts.anchor(identity,held)
static func draw(canvas: Node2D, effect: Dictionary, cat_origin: Vector2, reduced: bool) -> void:
	var age: float = float(effect.get("age",0))
	var duration: float = float(effect.get("duration",.7))
	if age>duration: return
	var t: float = clampf(age/duration,0,1)
	var identity: String = str(effect.get("identity","T01"))
	var is_toy: bool = identity.begins_with("T")
	var first: bool = bool(effect.get("first",false))
	var source: Vector2 = Vector2(effect.get("mount",tree_anchor(identity))) if is_toy else cat_origin
	var target: Vector2 = Vector2(float(effect.get("x",344)),clampf(float(effect.get("y",375)),108,524))
	var color: Color = ToyColors[clampi(int(identity.substr(1))-1,0,19)] if is_toy else Color("d8e4b1")
	var alpha: float = 1.0-smoothstep(.65,1.0,t)
	var size: float = (74.0 if first else 48.0) if is_toy else (37.0 if first else 24.0)
	if reduced and is_toy: size*=.9
	var tex: Texture2D = Art.picture("toys",identity) if is_toy else Atlas.texture(identity)
	var framed: bool = is_toy and Frames.draw(canvas,"toys",identity,age,duration,source,Vector2.ONE*size,0,Color(1,1,1,alpha))
	if not framed:
		var fallback_size: float = 37.0 if first else 24.0
		canvas.draw_circle(source,fallback_size*.58,Color("423c3d")*Color(1,1,1,.9*alpha))
		canvas.draw_arc(source,fallback_size*.62,-PI*.5,-PI*.5+TAU*(1-t),24,Color(color,alpha),2,true)
		Art.fit(canvas,tex,Rect2(source-Vector2.ONE*fallback_size*.5,Vector2.ONE*fallback_size),Color(1,1,1,alpha))
	if first and source.distance_to(target)>65:
		# A short dotted causal annotation; never creates a fake damaging projectile.
		var bend: Vector2 = (source+target)*.5+Vector2(0,-28)
		for index: int in range(12):
			var a: float = float(index)/12.0
			var b: float = a+.028
			var p1: Vector2 = source.bezier_interpolate(bend,bend,target,a)
			var p2: Vector2 = source.bezier_interpolate(bend,bend,target,b)
			canvas.draw_line(p1,p2,Color(color,alpha*.48),1.3,true)
		canvas.draw_arc(target,23+(0.0 if reduced else t*12),0,TAU,24,Color(color,alpha*.72),2,true)
		if t>.24 and not is_toy:
			Art.fit(canvas,tex,Rect2(target+Vector2(17,-34),Vector2(25,25)),Color(1,1,1,alpha))
