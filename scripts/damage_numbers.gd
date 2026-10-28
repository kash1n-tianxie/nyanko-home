extends RefCounted
const GameLocale=preload("res://scripts/game_locale.gd")
## Presentation-only numbers. Keep a stable lane, never borrow gameplay RNG.
const INK: Color = Color("33262f")
const CRITICAL_RED: Color = Color("ff5956")
const MAX_BASE_NUMBERS: int = 5

static func supports(effect: Dictionary) -> bool:
	return (str(effect.get("type","")) == "hit" and float(effect.get("amount",0)) > 0) or (str(effect.get("type","")) == "base_damage_resolved" and float(effect.get("hp_damage",0)) > 0)

static func style(effect: Dictionary) -> Dictionary:
	var base: bool = str(effect.get("type","")) == "base_damage_resolved"
	var crit: bool = not base and bool(effect.get("critical",false))
	var burn: bool = str(effect.get("kind","")) == "burn"
	var amount: float = float(effect.get("hp_damage",0) if base else effect.get("amount",0))
	var color: Color = Color("ffb5a1") if base else Color("fff7df")
	if burn and not crit: color = Color("ffcd84")
	if crit: color = CRITICAL_RED
	return {"text":("-%d" if base else "%d") % maxi(1,roundi(amount)),"size":32 if base else (30 if crit else (18 if burn else 22)),"color":color,"duration":.88 if base else (.78 if crit else .68),"base":base,"critical":crit}

static func _anchor(effect: Dictionary) -> Vector2:
	if str(effect.get("type","")) == "base_damage_resolved": return Vector2(354,348)
	return Vector2(float(effect.get("x",600)),float(effect.get("y",478))-30)

static func bounds(effect: Dictionary, font: Font) -> Rect2:
	var spec: Dictionary = style(effect)
	var anchor: Vector2 = Vector2(effect.get("number_anchor",_anchor(effect)))
	# Pack against where an older number is now, rather than where it spawned.
	var rise: float = 13.0 if bool(effect.get("number_reduced",false)) else (39.0 if bool(spec.critical) else 32.0)
	anchor.y -= rise*clampf(float(effect.get("age",0))/float(spec.duration),0,1)
	# Reserve enough width for two hits merging before the first float has moved.
	var width: float = float(effect.get("number_width",0))
	if width<=0: width = maxf(48,font.get_string_size(str(spec.text)+"0",HORIZONTAL_ALIGNMENT_LEFT,-1,int(spec.size)).x+10)
	return Rect2(anchor-Vector2(width*.5,float(spec.size)+5),Vector2(width,float(spec.size)+11))

static func prepare(effect: Dictionary, active: Array, font: Font, reduced: bool = false) -> void:
	if not supports(effect): return
	effect["number_reduced"] = reduced
	var spec: Dictionary = style(effect)
	# The budget merges a rapid hit into its earlier numeral. Avoid repacking that lane.
	if not bool(spec.base):
		for previous: Dictionary in active:
			if str(previous.get("type",""))!="hit" or float(previous.get("age",0))>.1: continue
			if previous.get("target",-1)!=effect.get("target",-2) or previous.get("cat","")!=effect.get("cat",""): continue
			if previous.get("kind","")!=effect.get("kind","") or bool(previous.get("critical",false))!=bool(effect.get("critical",false)): continue
			effect["number_anchor"] = previous.get("number_anchor",_anchor(previous))
			effect["number_hidden"] = previous.get("number_hidden",false)
			return
	effect["number_width"] = maxf(48,font.get_string_size(str(spec.text)+"0",HORIZONTAL_ALIGNMENT_LEFT,-1,int(spec.size)).x+10)
	var occupied: Array[Rect2] = []
	var base_numbers: Array[Dictionary] = []
	for other: Dictionary in active:
		if not supports(other) or bool(other.get("number_hidden",false)): continue
		var other_spec: Dictionary = style(other)
		if float(other.get("age",0)) >= float(other_spec.duration): continue
		if bool(other_spec.base): base_numbers.append(other)
		if bool(spec.base) == bool(other_spec.base): occupied.append(bounds(other,font))
	if bool(spec.base) and base_numbers.size() >= MAX_BASE_NUMBERS:
		base_numbers[0]["number_hidden"] = true
		occupied.remove_at(0)
	var origin: Vector2 = _anchor(effect)
	var candidates: Array[Vector2] = []
	if bool(spec.base):
		for row: int in range(5): candidates.append(origin+Vector2(0,-row*48))
	else:
		for row: int in range(4):
			for column: float in [0.0,-70.0,70.0,-140.0,140.0]:
				candidates.append(origin+Vector2(column,-row*40))
	for candidate: Vector2 in candidates:
		candidate.x = clampf(candidate.x,340 if bool(spec.base) else 390,1225)
		candidate.y = clampf(candidate.y,138,515)
		effect["number_anchor"] = candidate
		var rect: Rect2 = bounds(effect,font)
		var clear: bool = true
		for other_rect: Rect2 in occupied:
			if rect.intersects(other_rect): clear = false; break
		if clear: return
	if bool(spec.critical):
		# A new red hit can replace nearby minor normal text, while every impact still draws.
		for candidate: Vector2 in candidates:
			candidate.x=clampf(candidate.x,390,1225)
			candidate.y=clampf(candidate.y,138,515)
			effect["number_anchor"]=candidate
			var rect: Rect2=bounds(effect,font)
			var conflicts: Array[Dictionary]=[]
			var blocked: bool=false
			for other: Dictionary in active:
				if str(other.get("type",""))!="hit" or bool(other.get("number_hidden",false)): continue
				if float(other.get("age",0))>=float(style(other).duration) or not rect.intersects(bounds(other,font)): continue
				if bool(other.get("critical",false)) or float(other.get("amount",0))>float(effect.get("amount",0)):
					blocked=true;break
				conflicts.append(other)
			if not blocked:
				for other: Dictionary in conflicts: other["number_hidden"]=true
				return
	# Dense proc storms keep impact art but omit an unreadable extra numeral.
	effect["number_hidden"] = true

static func sample(effect: Dictionary, age: float, reduced: bool = false) -> Dictionary:
	var spec: Dictionary = style(effect)
	var duration: float = float(spec.duration)
	var anchor: Vector2 = Vector2(effect.get("number_anchor",_anchor(effect)))
	var rise: float = (13.0 if reduced else (39.0 if bool(spec.critical) else 32.0))*clampf(age/duration,0,1)
	var pop: float = 1.0
	if not reduced:
		pop = lerpf(1.18 if bool(spec.critical) else 1.10,1.0,smoothstep(.02,.15,age))
	return {"position":anchor-Vector2(0,rise),"size":roundi(float(spec.size)*pop),"alpha":1.0-smoothstep(duration*.60,duration,age),"text":spec.text,"color":spec.color}

static func draw(canvas: Node2D, effect: Dictionary, age: float, reduced: bool, font: Font) -> void:
	if not supports(effect) or bool(effect.get("number_hidden",false)) or age >= float(style(effect).duration): return
	var frame: Dictionary = sample(effect,age,reduced)
	var width: float = font.get_string_size(str(frame.text),HORIZONTAL_ALIGNMENT_LEFT,-1,int(frame.size)).x
	var at: Vector2 = Vector2(frame.position)-Vector2(width*.5,0)
	var alpha: float = float(frame.alpha)
	canvas.draw_string_outline(font,at+Vector2(1,2),GameLocale.text(str(frame.text)),HORIZONTAL_ALIGNMENT_LEFT,-1,int(frame.size),4,Color(.13,.10,.15,alpha*.65))
	canvas.draw_string_outline(font,at,GameLocale.text(str(frame.text)),HORIZONTAL_ALIGNMENT_LEFT,-1,int(frame.size),3,Color(INK,alpha))
	canvas.draw_string(font,at,GameLocale.text(str(frame.text)),HORIZONTAL_ALIGNMENT_LEFT,-1,int(frame.size),Color(frame.color,alpha))
