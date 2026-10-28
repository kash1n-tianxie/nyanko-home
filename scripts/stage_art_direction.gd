extends RefCounted
## Art-only chapter grades for the v038 clean authored backgrounds.
## These scalars never read or mutate simulation/RNG.
## Detail reduction is in the new paintings; this is only a gentle palette grade.
## The material belongs to PaintedDistance, so cats, shots and UI stay untouched.
const CHAPTERS: Array[Dictionary]=[
	{"name":"庭院", "strength":.34, "contrast":.90, "saturation":.92, "highlights":.08, "ambient":Color("c5b7ad"), "warm":Color("ffe2ae"), "light_a":Vector2(.108,.282), "light_b":Vector2(.714,.400), "radius_a":Vector2(.095,.22), "radius_b":Vector2(.12,.16)},
	{"name":"杂货街", "strength":.34, "contrast":.90, "saturation":.92, "highlights":.08, "ambient":Color("b9b7ad"), "warm":Color("ffdda5"), "light_a":Vector2(.626,.431), "light_b":Vector2(.033,.322), "radius_a":Vector2(.14,.21), "radius_b":Vector2(.10,.20)},
	{"name":"洗衣厂", "strength":.34, "contrast":.90, "saturation":.92, "highlights":.08, "ambient":Color("afbfc0"), "warm":Color("f9e1ac"), "light_a":Vector2(.737,.122), "light_b":Vector2(.116,.155), "radius_a":Vector2(.11,.23), "radius_b":Vector2(.12,.19)},
	{"name":"天台", "strength":.34, "contrast":.90, "saturation":.92, "highlights":.08, "ambient":Color("b4bcc9"), "warm":Color("ffe3b5"), "light_a":Vector2(.581,.475), "light_b":Vector2(.092,.274), "radius_a":Vector2(.11,.19), "radius_b":Vector2(.14,.20)},
	{"name":"月亮滚筒", "strength":.34, "contrast":.90, "saturation":.92, "highlights":.08, "ambient":Color("bdb7c7"), "warm":Color("fff0bd"), "light_a":Vector2(.748,.339), "light_b":Vector2(.220,.380), "radius_a":Vector2(.16,.23), "radius_b":Vector2(.12,.22)},
]

static func chapter_config(stage: int) -> Dictionary:
	return CHAPTERS[clampi(floori(float(stage)/4.0),0,4)].duplicate(true)

static func configure_material(material: ShaderMaterial, stage: int, presentation: Dictionary={}) -> void:
	if material==null: return
	var stage_index: int=clampi(stage,0,19)
	if int(material.get_meta("art_stage",-1))!=stage_index:
		var spec: Dictionary=chapter_config(stage_index)
		material.set_meta("art_stage",stage_index)
		for key: String in ["strength","contrast","saturation","highlights","ambient","warm","light_a","light_b","radius_a","radius_b"]:
			material.set_shader_parameter(key,spec[key])
		material.set_shader_parameter("night",1.0 if stage_index%4==3 else 0.0)
	material.set_shader_parameter("aftermath",clampf(float(presentation.get("aftermath",0.0)),0.0,1.0))
	material.set_shader_parameter("pressure",clampf(float(presentation.get("pressure",0.0)),0.0,1.0))
	material.set_shader_parameter("quiet",clampf(float(presentation.get("quiet",0.0)),0.0,1.0))
