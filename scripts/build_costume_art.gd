extends RefCounted
## Presentation-only build grouping. Never changes fish/toy mechanics or state.
const ROOT: String = "res://art/immersion-v036/costumes/"
const CAT_SCALE: Dictionary = {"C01":1.0,"C02":.90,"C03":.88,"C04":.94,"C05":.90,"C06":.90}
const FAMILY_FISH: Dictionary = {"explosion":["F01"],"ice":["F04"],"electric":["F06"],"fire":["F02"],"utility":["F03","F05","F09","F10"]}
const INK: Color = Color("493443")
static var textures: Dictionary = {}

static func resolve(fish: Dictionary, sources: Array, cat_id: String) -> Dictionary:
	var scores: Dictionary = {"ice":0,"electric":0,"explosion":0,"fire":0,"utility":0}
	for family: String in ["ice","electric","fire","utility"]:
		for id: String in FAMILY_FISH[family]:
			if id in sources: scores[family]=maxi(int(scores[family]),int(fish.get(id,0))*10)
	if "T04" in sources:
		scores.explosion=22+(int(fish.get("F01",0))*6 if "F01" in sources else 0)
		for id: String in ["T01","T10"]:
			if id in sources: scores.explosion+=4
	if "T05" in sources: scores.electric+=22
	if "T07" in sources: scores.ice+=22
	for id: String in ["T06","T08","T15"]:
		if id in sources: scores.utility=maxi(int(scores.utility),12)
	var family: String = ""
	var score: int = 0
	# Stable tie order: equipment insertion order cannot change the costume.
	for candidate: String in ["ice","electric","explosion","fire","utility"]:
		if int(scores[candidate])>score: family=candidate; score=int(scores[candidate])
	var tier: int = 3
	if family!="":
		for id: String in FAMILY_FISH[family]:
			if id in sources and int(fish.get(id,0))>=5: tier=5
	var auxiliary: Array[String] = []
	if "T04" in sources and family!="explosion": auxiliary.append("T04")
	if "T15" in sources: auxiliary.append("T15")
	var key: String = family+"-"+str(tier) if family in ["explosion","ice","electric"] else ""
	return {"family":family,"tier":tier,"key":key,"auxiliary":auxiliary,"cat_scale":float(CAT_SCALE.get(cat_id,.9)),
		"large_back_parts":0 if family=="" else 1,"max_large_back_parts":1,"max_auxiliary_marks":2,
		"source_count":sources.size()}

static func texture(key: String) -> Texture2D:
	if textures.has(key): return textures[key]
	var path: String = ROOT+key+".png"
	if not ResourceLoader.exists(path): return null
	textures[key]=load(path) as Texture2D
	return textures[key]

static func draw_back(canvas: CanvasItem, report: Dictionary, anchor: Vector2, unit: float) -> bool:
	var costume: Dictionary = report.costume
	var family: String = str(costume.family)
	if family=="": return true
	var part: Texture2D = texture(str(costume.key)) if str(costume.key)!="" else null
	if part==null:
		var legacy: String = "flame_mantle" if family=="fire" else "mint_cape"
		var key: String = "legacy/"+legacy
		if not textures.has(key): textures[key]=load("res://art/mutations-v034/"+legacy+".png") as Texture2D
		part=textures[key]
	if part==null: return false
	var limit: Vector2 = Vector2(63,58) if int(costume.tier)>=5 else Vector2(54,52)
	limit*=float(costume.cat_scale)*unit
	var extent: Vector2 = part.get_size()*minf(limit.x/float(part.get_width()),limit.y/float(part.get_height()))
	var pin: Vector2 = anchor+Vector2(5,-8)*unit
	var rect: Rect2 = Rect2(pin-extent*Vector2(.84,.20),extent)
	canvas.draw_texture_rect(part,rect,false)
	# Sewn cues live inside this same silhouette; no second backpack or tall wand.
	for id: String in costume.auxiliary:
		if id=="T04":
			var point: Vector2 = rect.position+extent*Vector2(.36,.67)
			for shift: Vector2 in [Vector2(-3,1),Vector2(1,-2),Vector2(4,2)]:
				canvas.draw_circle(point+shift*unit,3.2*unit,INK)
				canvas.draw_circle(point+shift*unit,2.1*unit,Color("ebd5a6"))
		elif id=="T15":
			var point: Vector2 = rect.position+extent*Vector2(.35,.37)
			var points: PackedVector2Array = PackedVector2Array([point+Vector2(-4,-5)*unit,point+Vector2(4,-3)*unit,point+Vector2(3,7)*unit,point+Vector2(-3,5)*unit])
			canvas.draw_colored_polygon(points,Color("87718e"))
			points.append(points[0]); canvas.draw_polyline(points,INK,1.1*unit,true)
			canvas.draw_line(point+Vector2(-1,-1)*unit,point+Vector2(1,3)*unit,Color("d8c8cf"),unit,true)
	return true
