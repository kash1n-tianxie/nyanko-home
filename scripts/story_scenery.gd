extends RefCounted
## Five chapters use sixteen painted scenes; encounter mapping is explicit data.
static var _cache: Dictionary={}
static var _paths: Array=[]
static var _modules: Dictionary={}
const MODULE_MANIFEST: String="res://art/immersion-v035/scenery/manifest.json"
const ROOT: String="res://art/story-v026/"
const TREE_REGION: Rect2=Rect2(101,8,910,1430)
const TREE_DEST: Rect2=Rect2(38,101,340,438)
static func path_for_stage(stage: int) -> String:
	if _paths.is_empty():
		var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://art/expansion-v030/campaign-backgrounds.json"))
		_paths=data.get("mapping",[])
	if not _paths.is_empty(): return str(_paths[clampi(stage,0,_paths.size()-1)].path)
	return ROOT+"stage-%02d.png" % (clampi(stage,0,11)+1)
static func texture(path: String) -> Texture2D:
	if _cache.has(path): return _cache[path]
	if not ResourceLoader.exists(path): return null
	var result: Texture2D=load(path) as Texture2D
	_cache[path]=result
	return result
static func draw_background(canvas: Node2D, stage: int, legacy: Texture2D) -> void:
	var plate: Texture2D=texture(path_for_stage(stage))
	if plate!=null: canvas.draw_texture_rect(plate,Rect2(0,0,1280,548),false)
	else: canvas.draw_texture_rect_region(legacy,Rect2(0,0,1280,548),Rect2(0,0,legacy.get_width(),legacy.get_height()*607.0/941.0))
	var dock: Texture2D=texture("res://art/parchment-v027/dock-empty.png")
	if dock!=null: canvas.draw_texture_rect(dock,Rect2(0,548,1280,172),false)
	else:
		var split: float=legacy.get_height()*607.0/941.0
		canvas.draw_texture_rect_region(legacy,Rect2(0,548,1280,172),Rect2(0,split,legacy.get_width(),legacy.get_height()-split))
static func draw_tree(canvas: Node2D) -> void:
	var tree: Texture2D=texture("res://art/parchment-v027/tree-five.png")
	if tree!=null: canvas.draw_texture_rect_region(tree,TREE_DEST,TREE_REGION)

## Authored transparent modules; cached crops retain the source alpha and painted edges.
static func module_texture(id: String) -> Texture2D:
	if _modules.is_empty() and FileAccess.file_exists(MODULE_MANIFEST):
		var manifest: Variant=JSON.parse_string(FileAccess.get_file_as_string(MODULE_MANIFEST))
		if manifest is Dictionary: _modules=manifest.get("modules",{})
	var key: String="module:"+id
	if _cache.has(key): return _cache[key]
	if not _modules.has(id): return null
	var spec: Dictionary=_modules[id]
	var sheet: Texture2D=texture(str(spec.atlas))
	if sheet==null: return null
	var region: Array=spec.region
	var atlas: AtlasTexture=AtlasTexture.new()
	atlas.atlas=sheet
	atlas.region=Rect2(float(region[0]),float(region[1]),float(region[2]),float(region[3]))
	atlas.filter_clip=true
	_cache[key]=atlas
	return atlas

static func draw_module(canvas: CanvasItem, id: String, rect: Rect2, angle: float=0.0, pivot: Vector2=Vector2(.5,.5), tint: Color=Color.WHITE) -> void:
	var painted: Texture2D=module_texture(id)
	if painted==null: return
	var hinge: Vector2=rect.position+rect.size*pivot
	canvas.draw_set_transform(hinge,angle)
	canvas.draw_texture_rect(painted,Rect2(-rect.size*pivot,rect.size),false,tint)
	canvas.draw_set_transform(Vector2.ZERO)
static func ready_count() -> int:
	var count: int=0
	for i: int in range(20):
		if ResourceLoader.exists(path_for_stage(i)): count+=1
	return count

## Cheap contact shading is a separate drawing primitive, never baked into artwork.
## Source alpha is procedural engine falloff; all illustrated modules stay intact.
static var _contact_texture: GradientTexture2D
static func contact_shadow(canvas: CanvasItem, center: Vector2, dimensions: Vector2, alpha: float=.22) -> void:
	if _contact_texture==null:
		var gradient: Gradient=Gradient.new()
		gradient.offsets=PackedFloat32Array([0.0,.45,1.0])
		gradient.colors=PackedColorArray([Color(1,1,1,.80),Color(1,1,1,.40),Color(1,1,1,0)])
		_contact_texture=GradientTexture2D.new()
		_contact_texture.width=96
		_contact_texture.height=32
		_contact_texture.gradient=gradient
		_contact_texture.fill=GradientTexture2D.FILL_RADIAL
		_contact_texture.fill_from=Vector2(.5,.5)
		_contact_texture.fill_to=Vector2(1.0,.5)
	canvas.draw_texture_rect(_contact_texture,Rect2(center-dimensions*.5,dimensions),false,Color(.17,.12,.14,clampf(alpha,0.0,.5)))
