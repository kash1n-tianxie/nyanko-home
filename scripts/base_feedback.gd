extends RefCounted
const GameLocale=preload("res://scripts/game_locale.gd")
## Shield and HP have separate visual channels, using post-resolution quantities.
static func draw(canvas: Node2D, effect: Dictionary, reduced: bool, font: Font) -> void:
	var age: float = float(effect.get("age",0))
	var type: String = str(effect.get("type",""))
	var point: Vector2 = Vector2(337,377)
	if type=="base_damage_resolved":
		if age>.62: return
		var absorbed: float = float(effect.get("shield_absorbed",0))
		var loss: float = float(effect.get("hp_damage",0))
		var alpha: float = 1.0-smoothstep(.33,.62,age)
		var drift: float = 0.0 if reduced else age*18
		if absorbed>0:
			canvas.draw_arc(point,31+age*15,-PI*.5,PI*.5,24,Color(.68,.85,.93,alpha*.8),3,true)
			_label(canvas,font,point+Vector2(13,-36-drift),"盾 −%d" % roundi(absorbed),Color("a8d4e4"),alpha)
		if loss>0:
			canvas.draw_arc(point+Vector2(-22,0),17+age*25,PI*.55,PI*1.45,18,Color(.92,.52,.39,alpha*.8),4,true)
			# The post-resolution HP numeral is drawn once, above every effect, by DamageNumbers.
	elif type=="base_shield_broken":
		if age>.48: return
		var alpha: float = 1-age/.48
		for i: int in range(5):
			var p: Vector2 = point+Vector2((i-2)*12,-35+i*12)
			if not reduced: p+=Vector2((i-2)*age*22,age*25)
			canvas.draw_polyline(PackedVector2Array([p+Vector2(-6,-10),p+Vector2(2,-2),p+Vector2(-3,6),p+Vector2(5,14)]),Color(.84,.72,.53,alpha),3,true)
		# Generic shield fracture: F08/bond shields must never borrow a T14 source icon.
		var crest: Vector2=point+Vector2(-8,-48)
		canvas.draw_polyline(PackedVector2Array([crest+Vector2(-13,-12),crest+Vector2(-10,6),crest+Vector2(0,15),crest+Vector2(10,6),crest+Vector2(13,-12)]),Color(.68,.85,.93,alpha),2.5,true)
	elif type=="base_low_hp":
		if age>.8: return
		var threshold: int = int(effect.get("threshold",35))
		var alpha: float = 1-smoothstep(.3,.8,age)
		var color: Color = Color("ffce83") if threshold>=35 else Color("e88872")
		canvas.draw_polyline(PackedVector2Array([Vector2(82,425),Vector2(98,415),Vector2(119,428),Vector2(146,416)]),Color(color,alpha),3,true)
		canvas.draw_polyline(PackedVector2Array([Vector2(246,458),Vector2(265,446),Vector2(281,462),Vector2(305,453)]),Color(color,alpha),3,true)
		_label(canvas,font,Vector2(326,464),"%d%%" % threshold,color,alpha)
static func _label(canvas: Node2D, font: Font, p: Vector2, text: String, color: Color, alpha: float) -> void:
	canvas.draw_string_outline(font,p,GameLocale.text(text),HORIZONTAL_ALIGNMENT_LEFT,-1,17,3,Color(.18,.15,.18,alpha))
	canvas.draw_string(font,p,GameLocale.text(text),HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color(color,alpha))
