extends RefCounted
## Original generated PNGs; engine-native rectangle crops and shared foot anchors.
const SHEETS: Dictionary = {
	"C01":preload("res://art/cat-weapons/C01-poses.png"),
	"C02":preload("res://art/cat-weapons/C02-poses.png"),
	"C03":preload("res://art/cat-weapons/C03-poses.png"),
	"C04":preload("res://art/cat-weapons/C04-poses.png"),
	"C05":preload("res://art/cat-weapons/C05-poses.png"),
	"C06":preload("res://art/cat-weapons/C06-poses.png")}
const FRAMES: Dictionary = {
	"C01": {"pivot":Vector2(0.30481927710843376,0.9869888475836431),
		"idle":{"region":Rect2(37,229,631,538),"margin":Rect2(35,0,199,0),"tip":Vector2(0.7267657992565055,-0.9070631970260223)},
		"attack":{"region":Rect2(697,288,830,478),"margin":Rect2(0,59,0,60),"tip":Vector2(1.0223048327137547,-0.4646840148698885)},
	},
	"C02": {"pivot":Vector2(0.39892183288409705,0.9873873873873874),
		"idle":{"region":Rect2(30,232,716,548),"margin":Rect2(26,7,26,7),"tip":Vector2(0.5855855855855856,-0.7081081081081081)},
		"attack":{"region":Rect2(814,225,695,555),"margin":Rect2(0,0,47,0),"tip":Vector2(0.5765765765765766,-0.7711711711711712)},
	},
	"C03": {"pivot":Vector2(0.4234354194407457,0.9914285714285714),
		"idle":{"region":Rect2(43,152,695,700),"margin":Rect2(51,0,56,0),"tip":Vector2(0.5785714285714286,-0.5942857142857143)},
		"attack":{"region":Rect2(772,197,751,657),"margin":Rect2(0,43,0,43),"tip":Vector2(0.5714285714285714,-0.5257142857142857)},
	},
	"C04": {"pivot":Vector2(0.45040840140023336,0.951856946354883),
		"idle":{"region":Rect2(34,168,658,700),"margin":Rect2(0,0,199,27),"tip":Vector2(-0.23383768913342504,-0.7400275103163686)},
		"attack":{"region":Rect2(782,372,739,523),"margin":Rect2(118,204,118,204),"tip":Vector2(0.5364511691884457,-0.08803301237964237)},
	},
	"C05": {"pivot":Vector2(0.5136897001303781,0.9827288428324698),
		"idle":{"region":Rect2(34,235,659,579),"margin":Rect2(108,0,108,0),"tip":Vector2(0.5803108808290155,-0.533678756476684)},
		"attack":{"region":Rect2(776,256,757,563),"margin":Rect2(0,15,10,16),"tip":Vector2(0.5613126079447323,-0.6545768566493955)},
	},
	"C06": {"pivot":Vector2(0.41506849315068495,0.9857549857549858),
		"idle":{"region":Rect2(52,178,667,701),"margin":Rect2(45,0,63,1),"tip":Vector2(0.47150997150997154,-0.5441595441595442)},
		"attack":{"region":Rect2(787,188,730,692),"margin":Rect2(0,10,0,10),"tip":Vector2(0.4700854700854701,-0.8518518518518519)},
	},
}
static var _cache: Dictionary = {}
static var _action_frames: Dictionary = {}

static func _actions() -> Dictionary:
	if _action_frames.is_empty():
		var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://art/immersion-v035/cats/manifest.json"))
		if parsed is Dictionary: _action_frames=parsed.get("cats",{})
	return _action_frames

static func _action(id: String, pose: String) -> Dictionary:
	return _actions().get(id,{}).get("frames",{}).get(pose,{})

## Normalization is a static source-art scale, separate from procedural body motion.
static func pose_scale(id: String, pose: String) -> float:
	return float(_action(id,pose).get("pose_scale",1.0))

static func attachments(id: String, pose: String) -> Dictionary:
	var result: Dictionary={}
	for key: String in _action(id,pose).get("anchors",{}):
		var raw: Variant=_action(id,pose).anchors[key]
		if raw is Array: result[key]=Vector2(float(raw[0]),float(raw[1]))
		else: result[key]=float(raw)
	return result

static func texture(id: String, pose: String = "idle") -> AtlasTexture:
	if not FRAMES.has(id): id = "C01"
	if pose not in ["attack","windup","recover"]: pose = "idle"
	var key: String = id+"_"+pose
	var action: Dictionary=_action(id,pose)
	if not action.is_empty() and not _cache.has(key):
		var result: AtlasTexture=AtlasTexture.new()
		result.atlas=load("res://art/immersion-v035/cats/"+str(action.file)) as Texture2D
		result.region=Rect2(Vector2.ZERO,result.atlas.get_size())
		result.filter_clip=true
		_cache[key]=result
	if not _cache.has(key):
		var frame: Dictionary = FRAMES[id][pose]
		var result: AtlasTexture = AtlasTexture.new()
		result.atlas = SHEETS[id]
		result.region = frame.region
		result.margin = frame.margin
		result.filter_clip = true
		_cache[key] = result
	return _cache[key]

static func pivot(id: String) -> Vector2:
	return FRAMES.get(id,FRAMES.C01).pivot

static func muzzle(id: String, pose: String = "attack", height: float = 88.0) -> Vector2:
	var action: Dictionary=_action(id,pose)
	if not action.is_empty(): return Vector2(float(action.tip[0]),float(action.tip[1]))*height
	return Vector2(FRAMES.get(id,FRAMES.C01)["attack" if pose=="attack" else "idle"].tip)*height
