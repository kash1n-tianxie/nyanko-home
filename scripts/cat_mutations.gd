extends RefCounted
## Read-only costume compositor. Three silhouette layers, shared by home and battle.
## Original faces, feet, weapon PNGs and real gag frames remain the visual identity.
const Art = preload("res://scripts/illustrated_atlas.gd")
const Data = preload("res://scripts/catalog.gd")
const Sprites = preload("res://scripts/cat_sprite_art.gd")
const BuildArt = preload("res://scripts/build_costume_art.gd")
const INK: Color = Color("493443")
const CREAM: Color = Color("ffebc2")
const HQ_TOYS: Array[String] = ["T13","T14","T16","T17","T19","T20","T21"]
const TOY_LAYERS: Dictionary = {
	"T01":"weapon", "T02":"weapon", "T03":"weapon", "T04":"back",
	"T05":"back", "T06":"back", "T07":"weapon", "T08":"back",
	"T09":"weapon", "T10":"weapon", "T11":"collar", "T12":"collar",
	"T15":"back", "T18":"weapon", "T22":"collar"}
const FISH_LAYERS: Dictionary = {"F01":"weapon","F02":"back","F03":"back","F04":"back","F05":"back","F06":"back","F07":"collar","F08":"collar","F09":"back","F10":"back"}
const COLORS: Dictionary = {"F01":"e4d4a5","F02":"df7f51","F03":"91bbb2","F04":"9fc6d5","F05":"98b39a","F06":"b8aed4","F07":"ead89a","F08":"ada5ba","F09":"bdd1d4","F10":"7b7b9b"}
# Anchors are relative to original foot position in units of cat height. Face stays clear.
const ANCHORS: Dictionary = {
	"C01":{"back":Vector2(-.15,-.43),"collar":Vector2(.08,-.43)},
	"C02":{"back":Vector2(-.20,-.38),"collar":Vector2(.02,-.43)},
	"C03":{"back":Vector2(-.18,-.36),"collar":Vector2(.01,-.40)},
	"C04":{"back":Vector2(-.20,-.30),"collar":Vector2(.08,-.29)},
	"C05":{"back":Vector2(-.22,-.38),"collar":Vector2(.02,-.43)},
	"C06":{"back":Vector2(-.17,-.36),"collar":Vector2(.03,-.38)}}
static var _parts: Dictionary = {}

static func fish_levels(state: Dictionary, cat_id: String) -> Dictionary:
	var result: Dictionary = {}
	# Equipped items also work in prep, where a stale battle snapshot must not win.
	for item: Dictionary in state.get("items",{}).values():
		if str(item.get("location",""))=="equipped" and str(item.get("cat",""))==cat_id:
			result[str(item.kind)] = maxi(int(result.get(str(item.kind),0)),Data.effective(item,cat_id))
	if not result.is_empty() or state.has("items"): return result
	for cat: Dictionary in state.get("battle",{}).get("cats",[]):
		if str(cat.get("id",""))!=cat_id: continue
		for id: String in cat.get("fish",{}): result[id] = int(cat.fish[id].get("level",0))
	return result

static func beneficiary(state: Dictionary, cat_id: String, toy: String) -> bool:
	if toy in HQ_TOYS or not TOY_LAYERS.has(toy): return false
	if toy=="T22":
		# A solo bell cannot pass its return to itself. No receiver, no costume.
		return cat_id!="C06" and "C06" in state.get("active",[]) and cat_id in state.get("active",[])
	return true

## All sources remain in the report; simultaneous sources merge into three physical parts.
static func describe(state: Dictionary, cat_id: String) -> Dictionary:
	var layers: Dictionary = {"back":[],"collar":[],"weapon":[]}
	var sources: Array[String] = []
	var fish: Dictionary = fish_levels(state,cat_id)
	for id: String in fish:
		if int(fish[id])>=3 and FISH_LAYERS.has(id):
			layers[FISH_LAYERS[id]].append(id)
			sources.append(id)
	for id: String in state.get("toys",{}):
		if int(state.toys[id])>0 and beneficiary(state,cat_id,id):
			layers[TOY_LAYERS[id]].append(id)
			sources.append(id)
	var costume: Dictionary = BuildArt.resolve(fish,sources,cat_id)
	var visible: Array[String] = []
	for layer: String in ["back","collar","weapon"]:
		if not layers[layer].is_empty() or (layer=="back" and str(costume.family)!=""): visible.append(layer)
	var armed: bool = false
	for cat: Dictionary in state.get("battle",{}).get("cats",[]):
		if str(cat.get("id",""))==cat_id: armed=bool(cat.get("toy_echo_armed",false))
	return {"layers":layers,"visible_layers":visible,"sources":sources,"fish":fish,"echo_armed":armed,"max_layers":3,
		"costume":costume}

## Draws the original sprite and its three parts. pose follows CatPerformance.sample.
## For real gag frames, callers can pass texture and sprite_rect plus the real pose transform.
static func draw(canvas: CanvasItem, state: Dictionary, cat_id: String, feet: Vector2, height: float = 88.0, pose: Dictionary = {}, clock: float = 0.0, reduced: bool = false) -> void:
	var report: Dictionary = describe(state,cat_id)
	var pose_name: String = str(pose.get("pose","idle"))
	report.anchors=Sprites.attachments(cat_id,pose_name)
	report.anchors.merge(pose.get("attachments",{}),true)
	report.part_scale=1.0/Sprites.pose_scale(cat_id,pose_name)
	var tex: Texture2D = pose.get("texture",Art.cat(cat_id,pose_name))
	var extent: Vector2 = Vector2(height*tex.get_width()/float(tex.get_height()),height)
	var rect: Rect2 = pose.get("sprite_rect",Rect2(-extent*Art.cat_pivot(cat_id),extent))
	var transform_scale: Vector2 = Vector2(pose.get("scale",Vector2.ONE))
	canvas.draw_set_transform(feet+Vector2(pose.get("offset",Vector2.ZERO)),float(pose.get("rotation",0)),transform_scale)
	_draw_back(canvas,cat_id,height,report,clock,reduced)
	canvas.draw_texture_rect(tex,rect,false)
	_draw_collar(canvas,cat_id,height,report)
	_draw_weapon(canvas,cat_id,height,pose_name,report)
	canvas.draw_set_transform(Vector2.ZERO)

## Overlay hook for existing articulated gags. Does not select or replace their texture.
static func draw_overlay(canvas: CanvasItem, state: Dictionary, cat_id: String, height: float, layer: String = "front", pose_name: String = "idle", anchors: Dictionary = {}) -> void:
	var report: Dictionary = describe(state,cat_id)
	report.anchors=Sprites.attachments(cat_id,pose_name)
	report.anchors.merge(anchors,true)
	report.part_scale=1.0/Sprites.pose_scale(cat_id,pose_name)
	if layer=="back": _draw_back(canvas,cat_id,height,report,0,true)
	else:
		_draw_collar(canvas,cat_id,height,report)
		_draw_weapon(canvas,cat_id,height,pose_name,report)

static func _has(report: Dictionary, id: String) -> bool:
	return id in report.sources

static func _dominant(report: Dictionary, layer: String) -> String:
	var best: String = ""
	var best_level: int = 0
	for id: String in report.layers[layer]:
		if id.begins_with("F") and int(report.fish[id])>best_level:
			best=id; best_level=int(report.fish[id])
	return best

static func _paper(canvas: CanvasItem, points: PackedVector2Array, fill: Color, width: float = 1.8) -> void:
	if points.size()<3: return
	canvas.draw_colored_polygon(points,fill)
	var outline: PackedVector2Array = points.duplicate()
	outline.append(points[0])
	canvas.draw_polyline(outline,INK,width,true)
	# An irregular inner seam, rather than a perfectly smooth vector sticker.
	if points.size()>3: canvas.draw_polyline(PackedVector2Array([points[0].lerp(points[1],.23),points[1].lerp(points[2],.20),points[2].lerp(points[3],.17)]),Color(CREAM,.5),maxf(.7,width*.45),true)

static func _shape(canvas: CanvasItem, origin: Vector2, units: Array, scale_value: float, fill: Color, width: float = 1.8) -> void:
	var points: PackedVector2Array = []
	for point: Vector2 in units: points.append(origin+point*scale_value)
	_paper(canvas,points,fill,maxf(1.1,width*scale_value))

static func _part(canvas: CanvasItem, key: String, rect: Rect2, angle: float = 0.0) -> bool:
	var path: String = "res://art/mutations-v034/"+key+".png"
	if not _parts.has(key):
		if not ResourceLoader.exists(path): return false
		_parts[key] = load(path) as Texture2D
	var tex: Texture2D = _parts[key]
	if tex==null: return false
	var factor: float = minf(rect.size.x/tex.get_width(),rect.size.y/tex.get_height())
	var extent: Vector2 = tex.get_size()*factor
	if absf(angle)<.001:
		canvas.draw_texture_rect(tex,Rect2(rect.get_center()-extent*.5,extent),false)
	else:
		var points: PackedVector2Array=[]
		var uvs: PackedVector2Array=PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN])
		for uv: Vector2 in uvs: points.append(rect.get_center()+((uv-Vector2(.5,.5))*extent).rotated(angle))
		canvas.draw_polygon(points,PackedColorArray([Color.WHITE]),uvs,tex)
	return true

static func _draw_back(canvas: CanvasItem, cat_id: String, height: float, report: Dictionary, _clock: float, _reduced: bool) -> void:
	var u: float = height/88.0*float(report.get("part_scale",1.0))
	var anchor: Vector2 = Vector2(report.get("anchors",{}).get("back",ANCHORS.get(cat_id,ANCHORS.C01).back))*height
	BuildArt.draw_back(canvas,report,anchor,u)

static func _draw_collar(canvas: CanvasItem, cat_id: String, height: float, report: Dictionary) -> void:
	if report.layers.collar.is_empty() or bool(report.get("anchors",{}).get("hide_collar",false)): return
	var u: float = height/88.0*float(report.get("part_scale",1.0))
	var anchor: Vector2 = Vector2(report.get("anchors",{}).get("collar",ANCHORS.get(cat_id,ANCHORS.C01).collar))*height
	var dominant: String = _dominant(report,"collar")
	var level: int = int(report.fish.get(dominant,3))
	var fill: Color = Color("a89cae") if dominant=="F08" else Color("c8ae7b")
	if _has(report,"T22"): fill=Color("9ba89a")
	# One narrow fastening, below the original face and tie. Sources stay in describe().
	_shape(canvas,anchor,[Vector2(-10,2),Vector2(-3,6),Vector2(7,5),Vector2(11,1),Vector2(9,6),Vector2(-2,10),Vector2(-10,6)],u,fill,1.2)
	if dominant=="F08":
		var shell: Texture2D = preload("res://scripts/painted_vfx.gd").texture("F08",0)
		var extent: float = 15.0 if level>=5 else 11.0
		if shell!=null: canvas.draw_texture_rect(shell,Rect2(anchor+Vector2(-11,6)*u,Vector2.ONE*extent*u),false)
	elif dominant=="F07":
		for i: int in range(3 if level>=5 else 2):
			var pearl: Vector2 = anchor+Vector2(-5+i*5,6)*u
			canvas.draw_circle(pearl,2.4*u,INK)
			canvas.draw_circle(pearl,1.5*u,CREAM)
	if _has(report,"T22"):
		var point: Vector2 = anchor+Vector2(-6,11)*u
		_shape(canvas,point,[Vector2(-4,-3),Vector2(4,-3),Vector2(4,3),Vector2(-4,3)],u,Color("9da48c"),1.0)
		canvas.draw_line(point+Vector2(-2,-1)*u,point+Vector2(2,-1)*u,INK,u,true)
		if bool(report.echo_armed): canvas.draw_arc(point,7*u,-.7,.7,8,Color("e2c89d"),1.5*u,true)

static func _draw_weapon(canvas: CanvasItem, cat_id: String, height: float, pose_name: String, report: Dictionary) -> void:
	if report.layers.weapon.is_empty() or bool(report.get("anchors",{}).get("hide_weapon",false)): return
	var u: float = height/88.0*float(report.get("part_scale",1.0))
	var tip: Vector2 = Vector2(report.get("anchors",{}).get("weapon",Art.cat_muzzle(cat_id,pose_name,height)/height))*height
	var angle: float = float(report.get("anchors",{}).get("weapon_angle",0.0))
	var branching: bool = _has(report,"T10") or _has(report,"T01") or _has(report,"F01")
	var anchor: Vector2 = tip+Vector2(-10,4).rotated(angle)*u
	# A single small binding preserves the full original weapon silhouette.
	var fill: Color = Color("baaa8b")
	if report.costume.family=="ice": fill=Color("a6bfc2")
	elif report.costume.family=="electric": fill=Color("a89aad")
	elif report.costume.family=="explosion": fill=Color("c4a07a")
	var points: PackedVector2Array = []
	for point: Vector2 in [Vector2(-5,-4),Vector2(4,-4),Vector2(5,3),Vector2(-3,5)]: points.append(anchor+point.rotated(angle)*u)
	_paper(canvas,points,fill,1.1*u)
	if branching:
		var extent: Vector2 = Vector2(18,15) if int(report.fish.get("F01",3))>=5 else Vector2(14,12)
		var center: Vector2 = tip+Vector2(3,3).rotated(angle)*u
		_part(canvas,"prism_fork",Rect2(center-extent*u*.5,extent*u),angle)
	elif _has(report,"T02") or _has(report,"T09"):
		canvas.draw_line(anchor+Vector2(-3,-3).rotated(angle)*u,anchor+Vector2(2,4).rotated(angle)*u,CREAM,1.4*u,true)

## Independent toy machinery changes the tree, never a non-beneficiary cat.
static func draw_tree(canvas: CanvasItem, state: Dictionary, _clock: float = 0.0, _reduced: bool = false) -> void:
	var toys: Dictionary = state.get("toys",{})
	var has_fort: bool = int(toys.get("T14",0))>0 or int(toys.get("T21",0))>0
	if has_fort:
		_shape(canvas,Vector2(313,425),[Vector2(-25,58),Vector2(-30,2),Vector2(-14,-9),Vector2(0,1),Vector2(13,-11),Vector2(30,0),Vector2(34,61)],1,Color("bea482"),2.2)
		for x: int in [-20,0,20]: canvas.draw_line(Vector2(313+x,438),Vector2(316+x,474),Color("8e735d"),1.6,true)
	if int(toys.get("T14",0))>0:
		_tree_art(canvas,"T14",Rect2(276,411,83,83))
	if int(toys.get("T21",0))>0:
		var painted: bool = _part(canvas,"box_cannon",Rect2(291,350,91,88))
		if not painted:
			_shape(canvas,Vector2(333,392),[Vector2(-25,25),Vector2(-26,-9),Vector2(10,-15),Vector2(24,4),Vector2(22,27)],1,Color("c6aa80"),2)
			_shape(canvas,Vector2(345,386),[Vector2(-8,-6),Vector2(36,-8),Vector2(41,3),Vector2(-9,7)],1,Color("9a8c88"),2)
		var charge: float = clampf(float(state.get("battle",{}).get("toy_cannon_charge",0))/18.0,0,1)
		canvas.draw_line(Vector2(311,419),Vector2(350,419),INK,7,true)
		canvas.draw_line(Vector2(313,419),Vector2(313+35*charge,419),Color("d3e5c2"),4,true)
	if int(toys.get("T16",0))>0:
		# Crop off the shop illustration's permanent laser; real beams remain event-only.
		_tree_art(canvas,"T16",Rect2(280,290,46,61),Rect2(0,0,175,256))
	if int(toys.get("T13",0))>0:
		# The installed litter tray is physical; its meteor only appears on a real cast.
		_tree_art(canvas,"T13",Rect2(278,195,61,31),Rect2(0,145,256,111))
	if int(toys.get("T19",0))>0: _tree_art(canvas,"T19",Rect2(274,251,57,59))
	if int(toys.get("T17",0))>0: _tree_art(canvas,"T17",Rect2(244,440,49,54))
	if int(toys.get("T20",0))>0:
		canvas.draw_polyline(PackedVector2Array([Vector2(289,487),Vector2(327,479),Vector2(351,490)]),Color("9a8575"),2,true)
		_tree_art(canvas,"T20",Rect2(333,465,46,39))
	if int(toys.get("T11",0))>0:
		_shape(canvas,Vector2(282,160),[Vector2(-13,15),Vector2(-15,-6),Vector2(-8,-16),Vector2(-1,-8),Vector2(8,-16),Vector2(14,-5),Vector2(11,15)],1,Color("ead29b"),1.8)
	if int(toys.get("T15",0))>0:
		canvas.draw_polyline(PackedVector2Array([Vector2(291,248),Vector2(280,264),Vector2(289,278),Vector2(280,294),Vector2(288,311),Vector2(281,330)]),Color("887396"),3,true)

static func _tree_art(canvas: CanvasItem, id: String, rect: Rect2, region: Rect2 = Rect2()) -> void:
	var texture: Texture2D = preload("res://scripts/expansion_art.gd").picture("toys",id)
	if texture==null: return
	if region.size.x>0: canvas.draw_texture_rect_region(texture,rect,region)
	else: preload("res://scripts/expansion_art.gd").fit(canvas,texture,rect)

static func draw_event(canvas: CanvasItem, event: Dictionary, state: Dictionary, reduced: bool = false) -> void:
	var type: String = str(event.get("type",""))
	var kind: String = str(event.get("kind",""))
	var age: float = float(event.get("age",0))
	var duration: float = maxf(.01,float(event.get("duration",.65)))
	var progress: float = clampf(age/duration,0,1)
	if age>duration: return
	var alpha: float = 1.0-smoothstep(.5,1.0,progress)
	if type=="toy_charge":
		var points: PackedVector2Array = [Vector2(364,359),Vector2(365,382),Vector2(347,412)]
		canvas.draw_polyline(points,Color("dce5bd",alpha*.85),3,true)
		return
	if type=="toy_armed" or (type=="toy_cast" and kind=="bell_echo"):
		var slot: int = state.get("active",[]).find(str(event.get("to_cat",event.get("cat",""))))
		if slot<0: return
		var center: Vector2 = preload("res://scripts/cat_combat_positions.gd").FEET[clampi(slot,0,4)]+Vector2(-22,-27)
		for i: int in range(2):
			canvas.draw_arc(center,13+i*6+progress*(1 if reduced else 8),-.7,.7,13,Color("c2a8d4",alpha),2.1,true)
		return
	if type=="toy_cast" and kind=="shield_cannon":
		var origin: Vector2 = Vector2(371,379) # Painted muzzle; resolved target/time stay from the event.
		var target: Vector2 = Vector2(float(event.get("to_x",800)),float(event.get("to_y",460)))
		var center: Vector2 = origin.lerp(target,progress)+Vector2(0,-sin(progress*PI)*(5 if reduced else 35))
		_shape(canvas,center,[Vector2(-11,-5),Vector2(2,-9),Vector2(13,-3),Vector2(13,6),Vector2(0,11),Vector2(-12,4)],1,Color("cdb38e",alpha),2)
		canvas.draw_line(center+Vector2(-4,-7),center+Vector2(3,9),Color("eee3bd",alpha),4,true)
		return
	if type=="burst" and kind=="shield_cannon":
		var center: Vector2 = Vector2(float(event.get("x",800)),float(event.get("y",460)))
		for i: int in range(6):
			var axis: Vector2 = Vector2.from_angle(i*TAU/6+.3)
			var p: Vector2 = center+axis*(13+progress*(12 if reduced else 29))
			_shape(canvas,p,[axis*10,axis.rotated(2.5)*6,axis.rotated(-2.5)*6],1,Color("d8bf91",alpha),1.4)
