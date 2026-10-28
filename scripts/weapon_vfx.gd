extends RefCounted
## Painted, weapon-specific attacks. Combat owns the events; this file only displays them.
## All artwork is from the generated transparent attack atlas, with no shape fallback.
const Painted = preload("res://scripts/painted_vfx.gd")
const TINTS: Dictionary = {"C01":"f29a59","C02":"e79c96","C03":"a78ce0","C04":"85b599","C05":"bda0cd","C06":"e9bb58"}
const PROJECTILE_SIZE: Dictionary = {
	"C01":Vector2(65,39), # A literal ivory fish skeleton, pointing at the victim.
	"C02":Vector2(56,47), # The slingshot's wound yarn pellet and its loose thread.
	"C03":Vector2(69,40), # An illustrated electric discharge from the plug fork.
	"C04":Vector2(62,52), # The hammer launches a stamped paw shock-front.
	"C05":Vector2(70,50), # A lazily unfurling yawn cloud, matching the horn.
	"C06":Vector2(64,52), # A brass bell note with drawn sound waves.
}
const IMPACT_SIZE: Dictionary = {
	"C01":Vector2(42,34), "C02":Vector2(43,36), "C03":Vector2(31,29),
	"C04":Vector2(54,44), "C05":Vector2(35,29), "C06":Vector2(32,30),
}

static func tint(cat_id: String, alpha: float = 1.0) -> Color:
	return Color(Color(str(TINTS.get(cat_id,"e9bb58"))),alpha)

static func draw_projectile(canvas: Node2D, projectile: Dictionary, pos: Vector2, direction: Vector2, clock: float, reduced: bool) -> void:
	var cat_id: String = str(projectile.get("cat","C01"))
	var angle: float = direction.angle() if direction.length_squared()>.001 else 0.0
	var travel_age: float = maxf(0.0,float(projectile.get("age",0.0))-float(projectile.get("delay",0.0)))
	var identity: float = float(projectile.get("id",0.0))*.83
	var critical: bool = bool(projectile.get("critical",false))
	var bounds: Vector2 = PROJECTILE_SIZE.get(cat_id,Vector2(60,46))
	var swell: float = 1.12 if critical else 1.0
	var opacity: float = 1.0
	# A horn wave's subsequent path contacts use small puffs, not repeated full-size clouds.
	# The initial weapon projectile and all elemental flight coats remain unchanged.
	if cat_id=="C05" and bool(projectile.get("path_child",false)):
		bounds *= .44
		opacity = .72
	var position: Vector2 = pos
	# Flight frame already contains the illustrated trail. Never layer a second
	# opaque missile over it: split attacks must remain countable on the field.
	var frame: int = 0 if travel_age<.065 else 1
	if not reduced:
		match cat_id:
			"C02":
				angle += sin(clock*11.0+identity)*.07
			"C05":
				position += direction.orthogonal()*sin(clock*6.0+identity)*1.4
				angle += sin(clock*5.0+identity)*.025
			"C06":
				swell *= 1.0+sin(clock*10.0+identity)*.025
	_draw(canvas,cat_id,frame,position,bounds*swell,angle,opacity)

static func draw_muzzle(canvas: Node2D, cat_id: String, origin: Vector2, age: float, reduced: bool) -> void:
	if age<0.0 or age>.19: return
	var progress: float = age/.19
	var size: Vector2 = IMPACT_SIZE.get(cat_id,Vector2(96,88))
	var growth: float = lerpf(.43,.56,progress) if reduced else lerpf(.38,.68,progress)
	var position: Vector2 = origin+Vector2(10.0 if reduced else 10.0+progress*5.0,0.0)
	var alpha: float = (1.0-progress)*.84
	# The initial contact painting doubles as a small, short release flourish.
	# It is tied to the actual post-windup release, not the cat's idle animation.
	_draw(canvas,cat_id,2,position,size*growth,0.0,alpha)

static func draw_impact(canvas: Node2D, event: Dictionary, pos: Vector2, age: float, reduced: bool, _font: Font) -> void:
	if age<0.0 or age>.22: return
	if event.has("amount") and float(event.amount)<=0.0: return
	var cat_id: String = str(event.get("cat","C01"))
	var critical: bool = bool(event.get("critical",event.get("crit",false)))
	var kind: String = str(event.get("kind","primary"))
	var progress: float = age/.22
	var force: float = 1.17 if critical else 1.0
	# Terminal/native follow-ups are less dominant than a primary contact.
	if kind in ["fur","arc"]: force *= .82
	var bounds: Vector2 = IMPACT_SIZE.get(cat_id,Vector2(96,88))
	var scale: float = lerpf(.86,1.02,progress) if reduced else lerpf(.73,1.14,progress)
	var alpha: float = 1.0 if progress<.22 else pow(clampf((1.0-progress)/.78,0.0,1.0),1.1)
	var frame: int = 2 if age<.075 else 3
	var position: Vector2 = pos
	var angle: float = 0.0
	if not reduced:
		match cat_id:
			"C01": angle = -.08+progress*.05
			"C02": angle = progress*.07
			"C04": position.y += progress*3.0
			"C05": position.y -= progress*4.0
			"C06": angle = sin(progress*PI)*.045
	# Damage numbers (including critical emphasis) are rendered once by the court.
	_draw(canvas,cat_id,frame,position,bounds*force*scale,angle,alpha)

static func _draw(canvas: Node2D, key: String, frame: int, pos: Vector2, bounds: Vector2, angle: float, alpha: float) -> void:
	if alpha<=.005: return
	var texture: Texture2D = Painted.texture(key,frame)
	if texture==null: return
	var dimensions: Vector2 = texture.get_size()
	if dimensions.x<=0.0 or dimensions.y<=0.0: return
	# Cropped cells have different aspect ratios. Preserve each hand-painted silhouette.
	var factor: float = minf(bounds.x/dimensions.x,bounds.y/dimensions.y)
	Painted.sprite(canvas,key,frame,pos,dimensions*factor,angle,Color(1.0,1.0,1.0,alpha))
