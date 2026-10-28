extends Control
const GameLocale=preload("res://scripts/game_locale.gd")
## The room's paper-box toy. This view only reads an isolated real-combat simulation.
signal target_requested(kind: String)
signal hint_requested(source: Control,title: String,subtitle: String,lines: Array[String])
signal hint_closed(source: Control)
const Paper=preload("res://scripts/collage_theme.gd")
const TARGETS=["single","queue","cluster","air"]
const NAMES={"single":"单体","queue":"队列","cluster":"聚群","air":"空中"}
var selected: String="single"
var result: Dictionary={}
var frame: Dictionary={}
var anchors: Dictionary={}
var reduced: bool=false
var painter: PracticePaint
var result_button: Button
var buttons: Dictionary={}

class PracticePaint extends Node2D:
	const Weapon=preload("res://scripts/weapon_vfx.gd")
	const Fish=preload("res://scripts/fish_vfx.gd")
	const Type=preload("res://theme/main.tres")
	var view: Control
	func target_point(index: int,kind: String) -> Vector2:
		match kind:
			"queue": return Vector2(1118+index*47,370)
			"cluster": return Vector2(1143+(index%3)*31,351+floori(index/3.0)*34)
			"air": return Vector2(1132+index*46,346)
		return Vector2(1170,367)
	func mapped(point: Vector2) -> Vector2:
		var enemies: Array=view.frame.get("enemies",[])
		var winner: int=0
		var nearest: float=INF
		for i: int in range(enemies.size()):
			var enemy: Dictionary=enemies[i]
			var distance: float=point.distance_squared_to(Vector2(enemy.get("x",700),enemy.get("y",470)))
			if distance<nearest: nearest=distance; winner=i
		return target_point(winner,str(view.selected))
	func _draw() -> void:
		var count: int={"single":1,"queue":3,"cluster":5,"air":3}.get(view.selected,1)
		var hit_points: Array[Vector2]=[]
		for event: Dictionary in view.frame.get("events",[]):
			if event.get("type","")=="hit" and float(event.get("age",0))<.18: hit_points.append(mapped(Vector2(event.get("x",700),event.get("y",470))))
		for i: int in range(count):
			var point: Vector2=target_point(i,view.selected)
			var scale_factor: float=1.0 if view.selected=="single" else .55
			var squash: float=.92 if point in hit_points and not view.reduced else 1.0
			draw_set_transform(point,0,Vector2(scale_factor,scale_factor*squash))
			if view.selected=="air":
				draw_line(Vector2(0,-22),Vector2(0,-58),Color("a18d70"),2,true)
				draw_arc(Vector2(0,-23),8,PI,TAU+PI*.5,12,Color("4e4540"),3,true)
			var front: PackedVector2Array=PackedVector2Array([Vector2(-43,-25),Vector2(34,-28),Vector2(39,27),Vector2(-38,31)])
			draw_colored_polygon(front,Color("b78d5f") if point not in hit_points else Color("efcc88"))
			draw_polyline(front+PackedVector2Array([front[0]]),Color("493d32"),2,true)
			draw_colored_polygon(PackedVector2Array([Vector2(-43,-25),Vector2(-26,-38),Vector2(49,-36),Vector2(34,-28)]),Color("d8b381"))
			draw_colored_polygon(PackedVector2Array([Vector2(34,-28),Vector2(49,-36),Vector2(53,14),Vector2(39,27)]),Color("876949"))
			draw_line(Vector2(-4,-31),Vector2(1,29),Color("ddc9a1"),8,true)
			for eye_x: float in [-20,18]:
				draw_circle(Vector2(eye_x,-5),8,Color("f2e8ce"))
				draw_circle(Vector2(eye_x,-9),3,Color("2c2927"))
			draw_line(Vector2(-10,15),Vector2(10,13),Color("46392e"),2,true)
			draw_line(Vector2(-33,22),Vector2(-23,18),Color("89734f"),2,true)
			draw_set_transform(Vector2.ZERO)
		# Every carrier comes from the real simulation; transform coordinates only.
		for projectile: Dictionary in view.frame.get("projectiles",[]):
			if float(projectile.get("age",0))<float(projectile.get("delay",0)): continue
			var origin: Vector2=view.anchors.get(str(projectile.get("cat","")),Vector2(600,340))
			var destination: Vector2=mapped(Vector2(projectile.get("target_x",700),projectile.get("target_y",470)))
			var progress: float=clampf((float(projectile.get("age",0))-float(projectile.get("delay",0)))/maxf(.001,float(projectile.get("travel",1))),0,1)
			if str(projectile.get("source_kind","main")) not in ["main","echo","toy_echo"]: origin=mapped(Vector2(projectile.get("origin_x",700),projectile.get("origin_y",470)))
			var point: Vector2=origin.lerp(destination,progress)+Vector2(0,sin(progress*PI)*float(projectile.get("lane",0))*.4)
			var direction: Vector2=(destination-origin).normalized()
			Weapon.draw_projectile(self,projectile,point,direction,float(view.frame.get("time",0)),view.reduced)
			Fish.draw_projectile(self,projectile,point,direction,{},float(view.frame.get("time",0)),view.reduced)
		for event: Dictionary in view.frame.get("events",[]):
			var age: float=float(event.get("age",0))
			var type: String=str(event.get("type",""))
			if type=="hit" and age<.22:
				var point: Vector2=mapped(Vector2(event.get("x",700),event.get("y",470)))
				Weapon.draw_impact(self,event,point,age,view.reduced,Type.default_font)
				if float(event.get("amount",0))>0: draw_string(Type.default_font,point+Vector2(-10,-46-age*40),GameLocale.text("%d" % roundi(event.amount)),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("f6ddb0"))
			elif type=="chain" and age<.24:
				var a: Vector2=mapped(Vector2(event.get("from_x",700),event.get("from_y",470)))
				var b: Vector2=mapped(Vector2(event.get("to_x",700),event.get("to_y",470)))
				draw_line(a,b,Color("b9deec"),2,true)
		draw_string(Type.default_font,Vector2(1100,408),GameLocale.text("纸箱试打"+(" · ▶" if bool(view.frame.get("running",false)) else "")),HORIZONTAL_ALIGNMENT_LEFT,158,15,Color("f2e5c9"))

func _ready() -> void:
	name="RoomPractice"
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	size=Vector2(1280,548)
	painter=PracticePaint.new()
	painter.view=self
	add_child(painter)
	for i: int in range(TARGETS.size()):
		var kind: String=TARGETS[i]
		var button: Button=Button.new()
		button.name="Practice"+kind.capitalize()
		button.position=Vector2(1091+i*42,285)
		button.size=Vector2(39,31)
		button.text=["●","▸▸","∴","↑"][i]
		button.add_theme_stylebox_override("normal",Paper.box("slot",Color.WHITE,3))
		button.add_theme_font_size_override("font_size",17)
		add_child(button)
		buttons[kind]=button
		button.pressed.connect(func() -> void: selected=kind; result={}; sync_result(); target_requested.emit(kind))
		button.mouse_entered.connect(func() -> void: hint_requested.emit(button,NAMES[kind]+"纸箱靶","隔离试打 · 不影响金币和存档",["同一队伍、同一随机种子、同一 10 秒。","群伤结果不当作单体 DPS。"] as Array[String]))
		button.mouse_exited.connect(func() -> void: hint_closed.emit(button))
	var box: Button=Button.new()
	box.name="PracticeAgain"
	box.position=Vector2(1096,320)
	box.size=Vector2(166,88)
	box.flat=true
	for style: String in ["normal","hover","pressed","focus"]: box.add_theme_stylebox_override(style,StyleBoxEmpty.new())
	box.pressed.connect(func() -> void: target_requested.emit(selected))
	add_child(box)
	result_button=Button.new()
	result_button.name="PracticeComparison"
	result_button.position=Vector2(1085,415)
	result_button.size=Vector2(176,30)
	result_button.add_theme_font_size_override("font_size",13)
	result_button.add_theme_stylebox_override("normal",Paper.box("strip",Color.WHITE,2))
	result_button.pressed.connect(func() -> void: target_requested.emit(selected))
	result_button.mouse_entered.connect(_result_hint)
	result_button.mouse_exited.connect(func() -> void: hint_closed.emit(result_button))
	add_child(result_button)
	sync_result()

func sync_result() -> void:
	if not is_instance_valid(result_button): return
	result_button.text="点纸箱试一轮" if result.is_empty() else "%.0f → %.0f / 10秒" % [float(result.get("before_damage",0)),float(result.get("after_damage",0))]
	for kind: String in buttons: buttons[kind].modulate=Color("ebcc83") if kind==selected else Color.WHITE
	painter.queue_redraw()

func set_frame(value: Dictionary,cat_anchors: Dictionary) -> void:
	frame=value
	selected=str(frame.get("target_kind",selected))
	anchors=cat_anchors
	painter.queue_redraw()

func set_result(value: Dictionary) -> void:
	result=value.duplicate(true)
	selected=str(value.get("target_kind",selected))
	sync_result()

func _result_hint() -> void:
	var lines: Array[String]=["全队耐打靶 · 无击杀／来袭。"]
	if not result.is_empty():
		lines.append("有效伤害 %.1f → %.1f" % [float(result.get("before_damage",0)),float(result.get("after_damage",0))])
		for side: String in ["before_control","after_control"]:
			var control: Variant=result.get(side,{})
			if control is Dictionary:
				var descriptions: Array[String]=[]
				for key: String in control:
					if not control[key] is Dictionary: continue
					for metric: String in control[key]:
						if descriptions.size()>=3: break
						var receipt: Script=preload("res://scripts/feedback_receipt.gd")
						descriptions.append("%s %s %.1f" % [receipt.source_name(key),receipt.METRIC_LABELS.get(metric,metric),float(control[key][metric])])
				if not descriptions.is_empty(): lines.append(("前：" if side=="before_control" else "后：")+" / ".join(descriptions))
	hint_requested.emit(result_button,NAMES.get(selected,"试打")+" · 强化前后","同靶、同种子、同 10 秒",lines)
