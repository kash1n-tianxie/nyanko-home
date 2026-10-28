extends SceneTree
const CatPerformance=preload("res://scripts/cat_performance.gd")
const Sprites=preload("res://scripts/cat_sprite_art.gd")
const Positions=preload("res://scripts/cat_combat_positions.gd")
const Mutations=preload("res://scripts/cat_mutations.gd")
const Fish=preload("res://scripts/fish_vfx.gd")
var failures: Array[String]=[]
var checks: int=0
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label);printerr("CAT035_FAIL ",label)
func _init() -> void:
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://art/immersion-v035/cats/manifest.json"))
	var gags: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://art/story-v026/cats/manifest.json"))
	check(CatPerformance.RELEASE==.12,"production release remains 0.12 seconds")
	for index: int in range(6):
		var id: String="C%02d" % (index+1)
		var windup: Dictionary=CatPerformance.sample(id,.07)
		var strike: Dictionary=CatPerformance.sample(id,.16)
		var recover: Dictionary=CatPerformance.sample(id,CatPerformance.duration(id)-.07)
		check(windup.pose=="windup" and strike.pose=="attack" and recover.pose=="recover",id+" has three distinct authored phases")
		check(CatPerformance.muzzle(id,.12,false).distance_to(Positions.RELEASE_OFFSETS[id])<.01,id+" launch geometry remains identical to combat")
		check(CatPerformance.sample(id,CatPerformance.duration(id)).pose=="idle",id+" returns to original idle")
		check(Sprites.texture(id,"attack").atlas==Sprites.SHEETS[id],id+" preserves original strike sheet")
		check(Sprites.pivot(id)==Sprites.FRAMES[id].pivot,id+" keeps the shared foot pivot")
		check(gags[id].frames.size()==4,id+" preserves four gag frames")
		for pose: String in ["windup","recover"]:
			var frame: Dictionary=manifest.cats[id].frames[pose]
			var texture: AtlasTexture=Sprites.texture(id,pose)
			check(texture!=Sprites.texture(id,"idle") and texture!=Sprites.texture(id,"attack"),id+" "+pose+" uses distinct new artwork")
			check(texture.atlas.resource_path.ends_with(id+"-"+pose+".png"),id+" "+pose+" uses saved production PNG")
			check(int(frame.alpha_extrema[0])==0 and int(frame.alpha_extrema[1])==255,id+" "+pose+" has true alpha")
			var attachments: Dictionary=Sprites.attachments(id,pose)
			check(attachments.has("back") and attachments.has("collar") and attachments.has("weapon"),id+" "+pose+" has authored costume anchors")
			var age: float=.07 if pose=="windup" else CatPerformance.duration(id)-.07
			check(Sprites.pose_scale(id,pose)>=.75 and Sprites.pose_scale(id,pose)<=1.25,id+" "+pose+" avoids oversized padded hit centers")
			var reduced: Dictionary=CatPerformance.sample(id,age,true)
			check(reduced.pose==pose and reduced.rotation==0.0 and reduced.offset==Vector2.ZERO,id+" reduced retains keyframe with no body motion")
			check(is_equal_approx(Vector2(reduced.scale).x,Sprites.pose_scale(id,pose)),id+" reduced keeps source normalization")
		var p: Dictionary={"cat":id,"visual_emphasis":1.0}
		var layers: Array[Dictionary]=Fish.element_layout(p,["fire","ice","electric"])
		check(layers.size()==3,id+" retains all three actual elements")
		for layer: Dictionary in layers:
			check(not Rect2(Vector2(layer.offset)-Vector2(layer.size)*.5,Vector2(layer.size)).has_point(Vector2.ZERO),id+" "+str(layer.element)+" leaves weapon center clear")
		var state: Dictionary={"active":[id,"C06"],"toys":{"T04":1,"T15":1,"T22":1,"T10":1},"items":{"one":{"cat":id,"kind":"F04","level":5,"quality":0,"location":"equipped"}}}
		check(Mutations.describe(state,id).visible_layers.size()<=3,id+" costume still has at most three silhouette layers")
	var normal: Array[Dictionary]=Fish.element_layout({"cat":"C05"},["fire"])
	var child: Array[Dictionary]=Fish.element_layout({"cat":"C05","path_child":true},["fire"])
	check(Vector2(child[0].size).length()<Vector2(normal[0].size).length()*.5,"horn child effects follow its small carrier")
	print("CAT035_RESULT ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
