extends RefCounted
## Small local 2D deformation meshes; no simulation, target or launch state lives here.
const Rules=preload("res://scripts/boss_stage_rules.gd")
const ROOT: String="res://art/immersion-v036/bosses/"
static var textures: Dictionary={}
var meshes: Dictionary={}

static func part(kind: String, piece: String) -> Texture2D:
	var key: String=kind+"-"+piece
	if textures.has(key): return textures[key]
	var path: String=ROOT+key+".png"
	textures[key]=load(path) as Texture2D if ResourceLoader.exists(path) else null
	return textures[key]

static func sample(kind: String, time: float, response: Dictionary, charge: float, reduced: bool) -> Dictionary:
	var release: float=float(response.get("release",0))
	var t: float=clampf(1-release/.56,0,1)
	var kick: float=sin(t*PI)*exp(-t*2.0)*16.0 if release>0 else 0.0
	var lag: float=sin(t*TAU-.8)*exp(-t*2.5)*14.0 if release>0 else 0.0
	var idle: float=sin(time*1.8)
	var stagger: float=float(response.get("stagger",0))/.65
	if reduced: kick*=.15;lag=0;idle=0;stagger*=.15
	return {"kind":kind,"clock":0.0 if reduced else time,"charge":charge,"kick":kick,"lag":lag,"idle":idle,"stagger":stagger,"reduced":reduced}

static func body_offset(kind: String, uv: Vector2, pose: Dictionary) -> Vector2:
	var charge: float=float(pose.charge)
	var idle: float=float(pose.idle)
	var kick: float=float(pose.kick)
	var time: float=float(pose.clock)
	var small: float=.18 if bool(pose.reduced) else 1.0
	if kind=="B01":
		# Upper cardboard corners fold against the taped central face; the feet and
		# rigid central face stay in place. This is not a whole-image squash.
		var flap: float=smoothstep(.55,1.0,uv.x)*(1-smoothstep(.10,.38,uv.y))
		var hem: float=(1-smoothstep(.0,.25,uv.x))*smoothstep(.72,1.0,uv.y)
		return Vector2(-flap*(charge*15+idle*1.6),flap*charge*12+hem*(idle*3+kick*.5))*small
	if kind=="B03":
		var tail: float=smoothstep(.55,1,uv.y)
		return Vector2(sin(time*2.8+uv.y*6)*tail*(5+charge*9),sin(time*2.4+uv.x*5)*tail*5-charge*tail*9)*small
	if kind=="B04":
		var tier: float=floor(uv.y*5.0)
		var support: float=1-smoothstep(.76,1,uv.y)
		var amplitude: float=(2+charge*5+kick*.5)*support
		return Vector2(sin(time*2.3-tier*.68)*amplitude,sin(time*1.7-tier*.5)*support*1.6)*small
	return Vector2.ZERO

static func limb_offset(kind: String, u: float, pose: Dictionary) -> Vector2:
	# The first quarter contains the visible legal target; its pixels never drift.
	if u<=.25 or u>=.98: return Vector2.ZERO
	var w: float=sin(inverse_lerp(.25,.98,u)*PI)
	var gain: float=1.0 if not bool(pose.reduced) else .12
	var amplitude: float=float(pose.lag)+float(pose.charge)*(-15 if kind=="B02" else -10)
	if kind in ["B03","B05"]: amplitude+=sin(float(pose.clock)*2.7-u*4)*4*gain
	return Vector2(0,w*amplitude*gain)

func draw_warp(canvas: Node2D, key: String, source: Texture2D, rect: Rect2, pose: Dictionary, tint: Color, limb: bool=false) -> void:
	if source==null: return
	var nx: int=12
	var ny: int=2 if limb else 12
	var vertices: PackedVector3Array=[]
	var uv_points: PackedVector2Array=[]
	var indices: PackedInt32Array=[]
	for row: int in range(ny+1):
		for col: int in range(nx+1):
			var uv: Vector2=Vector2(float(col)/nx,float(row)/ny)
			var delta: Vector2=limb_offset(str(pose.kind),uv.x,pose) if limb else body_offset(str(pose.kind),uv,pose)
			var point: Vector2=rect.position+uv*rect.size+delta
			vertices.append(Vector3(point.x,point.y,0));uv_points.append(uv)
	for row: int in range(ny):
		for col: int in range(nx):
			var a: int=row*(nx+1)+col
			indices.append_array(PackedInt32Array([a,a+1,a+nx+1,a+1,a+nx+2,a+nx+1]))
	if not meshes.has(key): meshes[key]=ArrayMesh.new()
	var mesh: ArrayMesh=meshes[key]
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uv_points;arrays[Mesh.ARRAY_INDEX]=indices
	mesh.clear_surfaces();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	canvas.draw_mesh(mesh,source,Transform2D.IDENTITY,tint)

static func draw_part(canvas: Node2D, source: Texture2D, center: Vector2, extent: Vector2, angle: float, tint: Color, pivot: Vector2=Vector2(.5,.5)) -> void:
	if source==null: return
	canvas.draw_set_transform(center,angle)
	canvas.draw_texture_rect(source,Rect2(-extent*pivot,extent),false,tint)
	canvas.draw_set_transform(Vector2.ZERO)

func clear() -> void:
	meshes.clear()
