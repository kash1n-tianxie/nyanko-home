extends RefCounted
## Generated gouache frames. Clipped textured quads preserve every combat boundary.
const BOUNDS: Rect2 = Rect2(4,78,1272,460)
static var cache: Dictionary = {}

static func texture(key: String, frame: int = 0) -> Texture2D:
	var asset: String = "%s-%d" % [key,clampi(frame,0,3)]
	if cache.has(asset): return cache[asset]
	var path: String = "res://art/painted-vfx/%s.png" % asset
	if not ResourceLoader.exists(path): return null
	var result: Texture2D = load(path) as Texture2D
	cache[asset] = result
	return result

static func sprite(canvas: Node2D, key: String, frame: int, pos: Vector2, size: Vector2, angle: float = 0.0, modulate: Color = Color.WHITE) -> void:
	if modulate.a<=.005 or size.x<.5 or size.y<.5: return
	var tex: Texture2D = texture(key,frame)
	if tex==null: return
	draw_texture(canvas,tex,pos,size,angle,modulate)

static func draw_texture(canvas: Node2D, tex: Texture2D, pos: Vector2, size: Vector2, angle: float = 0.0, modulate: Color = Color.WHITE) -> void:
	if tex==null or modulate.a<=.005 or size.x<.5 or size.y<.5: return
	# Most projectiles are wholly inside the battlefield. Avoid per-sprite dictionary
	# clipping in that case; hardware quads preserve the exact same texture and angle.
	var half: Vector2=size*.5
	var extent: Vector2=Vector2(absf(cos(angle))*half.x+absf(sin(angle))*half.y,absf(sin(angle))*half.x+absf(cos(angle))*half.y)
	if pos.x-extent.x>=BOUNDS.position.x and pos.x+extent.x<=BOUNDS.end.x and pos.y-extent.y>=BOUNDS.position.y and pos.y+extent.y<=BOUNDS.end.y:
		canvas.draw_set_transform(pos,angle)
		canvas.draw_texture_rect(tex,Rect2(-half,size),false,modulate)
		canvas.draw_set_transform(Vector2.ZERO)
		return
	var vertices: Array = []
	for uv: Vector2 in [Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]:
		vertices.append({"p":pos+((uv-Vector2(.5,.5))*size).rotated(angle),"uv":uv})
	for edge: int in range(4):
		if vertices.is_empty(): return
		var clipped: Array = []
		var previous: Dictionary = vertices[-1]
		for current: Dictionary in vertices:
			var a: bool = _inside(previous.p,edge)
			var b: bool = _inside(current.p,edge)
			if a!=b:
				var axis: int = 0 if edge<2 else 1
				var boundary: float = [BOUNDS.position.x,BOUNDS.end.x,BOUNDS.position.y,BOUNDS.end.y][edge]
				var ratio: float = (boundary-previous.p[axis])/(current.p[axis]-previous.p[axis])
				clipped.append({"p":Vector2(previous.p).lerp(current.p,ratio),"uv":Vector2(previous.uv).lerp(current.uv,ratio)})
			if b: clipped.append(current)
			previous = current
		vertices = clipped
	var points: PackedVector2Array = []
	var uvs: PackedVector2Array = []
	for vertex: Dictionary in vertices:
		if points.is_empty() or points[-1].distance_squared_to(vertex.p)>.0001:
			points.append(vertex.p)
			uvs.append(vertex.uv)
	if points.size()>2 and points[0].distance_squared_to(points[-1])<.0001:
		points.remove_at(points.size()-1)
		uvs.remove_at(uvs.size()-1)
	if points.size()<3: return
	var area: float = 0.0
	for index: int in range(points.size()): area += points[index].cross(points[(index+1)%points.size()])
	if absf(area)<.01: return
	canvas.draw_polygon(points,PackedColorArray([modulate]),uvs,tex)

static func beam(canvas: Node2D, key: String, frame: int, start: Vector2, end: Vector2, width: float, modulate: Color = Color.WHITE) -> void:
	var vector: Vector2 = end-start
	if vector.length()<1: return
	# Short painted pieces retain texture grain over both short links and long beams.
	var pieces: int = maxi(1,ceili(vector.length()/130.0))
	for index: int in range(pieces):
		var a: Vector2 = start.lerp(end,float(index)/pieces)
		var b: Vector2 = start.lerp(end,float(index+1)/pieces)
		sprite(canvas,key,frame,(a+b)*.5,Vector2(a.distance_to(b)+3,width),vector.angle(),modulate)

static func _inside(point: Vector2, edge: int) -> bool:
	match edge:
		0: return point.x>=BOUNDS.position.x
		1: return point.x<=BOUNDS.end.x
		2: return point.y>=BOUNDS.position.y
		_: return point.y<=BOUNDS.end.y
