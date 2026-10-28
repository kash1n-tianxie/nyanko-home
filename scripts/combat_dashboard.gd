extends Control
## Active-cat contribution strip. No economy or inventory commands live here.
const Data=preload("res://scripts/catalog.gd")
const Paper=preload("res://scripts/collage_theme.gd")
const Metrics=preload("res://scripts/battle_metrics.gd")
var ui: Control
var metrics: RefCounted=Metrics.new()
var signature: String=""
var rows: Dictionary={}
var total: Label
var sample_left: float=0.0

func setup(owner_ui: Control) -> void:
	ui=owner_ui
	name="CombatDashboard"
	position=Vector2.ZERO;size=Vector2(1280,172)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var paper: Panel=ui._plate(self,Rect2(0,0,1280,172),"ContributionPaper")
	paper.add_theme_stylebox_override("panel",Paper.box("strip",Color("e8d9b9"),3))
	paper.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ui._at_label(self,"守家战报",Rect2(25,8,130,26),20)
	total=ui._at_label(self,"近 5 秒 · 有效战斗时间",Rect2(165,8,1085,26),17)
	build()

func build() -> void:
	for row: Dictionary in rows.values():
		ui._remove(row.panel)
	rows.clear()
	var active: Array=ui.run.s.get("active",[])
	var count: int=maxi(1,active.size())
	var width: float=(1240.0-(count-1)*12.0)/count
	for index: int in range(active.size()):
		var cat: String=str(active[index])
		var panel: Panel=ui._plate(self,Rect2(20+index*(width+12),39,width,122),"ContributionSlot%d" % index)
		panel.add_theme_stylebox_override("panel",Paper.box("slot",Color("f4e8c9"),3))
		var wide: bool=width>=800
		var portrait: Control=ui._portrait(panel,cat,Vector2(76,76))
		portrait.position=Vector2(7,9);portrait.size=Vector2(76,76)
		var info_width: float=width-102 if not wide else width*.36-96
		ui._at_label(panel,str(Data.cats()[cat].name),Rect2(90,5,info_width,26),22)
		var damage: Label=ui._at_label(panel,"— DPS",Rect2(90,31,info_width,27),23)
		damage.name="CatDPS"+cat
		var support: Label=ui._at_label(panel,"累计 0",Rect2(90,59,info_width,21),16)
		var condition: Label=ui._at_label(panel,"",Rect2(9,66,78,20),15)
		condition.name="CatCondition"+cat
		condition.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		condition.hide()
		var button_rect: Rect2=Rect2(10,83,width-20,31)
		var meter_rect: Rect2=Rect2(12,79,width-24,3)
		var detail_rect: Rect2=Rect2(0,0,width,79)
		if wide:
			var middle: float=width*.37
			var skill: Dictionary=ui.run.combat.skill_status(cat)
			ui._at_label(panel,str(skill.get("name","绝招")),Rect2(middle,12,width*.25,29),22)
			ui._at_label(panel,"每场一次 · 全屏演出",Rect2(middle,44,width*.25,24),17)
			condition.position=Vector2(middle,75);condition.size=Vector2(width*.25,24)
			button_rect=Rect2(width*.65,31,width*.35-16,52)
			meter_rect=Rect2(width*.65+3,88,width*.35-22,5)
			detail_rect=Rect2(0,0,width*.64,118)
		else:
			# Debuffs take the support line while active, without covering portrait or DPS.
			condition.position=Vector2(86,59);condition.size=Vector2(width-94,21)
		var action: Button=ui._at_button(panel,"蓄能",button_rect,func() -> void: _skill(cat),"SkillHUD"+cat,ui.GOLD)
		action.add_theme_font_size_override("font_size",20 if wide else 18)
		var meter: ProgressBar=ui._meter(panel,meter_rect,ui.GOLD)
		var hotspot: Button=ui._transparent_button(panel,detail_rect,func() -> void: ui.show_cat(cat),"ContributionDetails"+cat)
		hotspot.mouse_entered.connect(func() -> void: _hint(hotspot,cat))
		hotspot.mouse_exited.connect(func() -> void: ui.fish_hint.close_from(hotspot))
		action.mouse_entered.connect(func() -> void: _skill_hint(action,cat))
		action.mouse_exited.connect(func() -> void: ui.fish_hint.close_from(action))
		rows[str(index)]={"panel":panel,"cat":cat,"dps":damage,"support":support,"condition":condition,"button":action,"meter":meter,"wide":wide}
	signature=str(ui.run.s.get("active",[]))

func tick(delta: float) -> void:
	if str(ui.run.s.get("active",[]))!=signature: build()
	sample_left-=delta
	if sample_left>0: return
	sample_left=.2
	var state: Dictionary=ui.run.s
	metrics.sample(state)
	var busy: bool=bool(state.get("battle",{}).get("cinematic",{}).get("active",false))
	var paused: bool=bool(state.get("paused",false))
	var ledger: Dictionary=state.get("feedback",{})
	for row: Dictionary in rows.values():
		var cat: String=str(row.cat)
		if cat.is_empty(): continue
		var amount: float=metrics.dps(cat)
		row.dps.text="— DPS" if amount<0 else ("%.1fk DPS" % (amount/1000.0) if amount>=1000 else "%.1f DPS" % amount)
		var help: Dictionary=ledger.get("support",{}).get(cat,{})
		row.support.text="累计 %.0f" % float(ledger.get("damage_by_cat",{}).get(cat,0))
		if float(help.get("shield_absorbed",0))>0: row.support.text="挡伤 %.0f" % float(help.shield_absorbed)
		elif float(help.get("stuns",0))>0: row.support.text="眩晕 %d 次" % int(help.stuns)
		elif float(help.get("cleanses",0))>0: row.support.text="净化 %d 次" % int(help.cleanses)
		var actor: Dictionary=ui.run.combat.get_cat(cat)
		var status: String=""
		if float(actor.get("web_left",0))>0: status="蛛网 −%d%% · %.1fs" % [roundi(float(actor.get("web_slow",0))*100),float(actor.web_left)]
		if float(actor.get("confuse_left",0))>0: status=("蛛网 + 混乱" if not status.is_empty() else "轨迹混乱")+" · %.1fs" % float(actor.confuse_left)
		row.condition.text=status;row.condition.visible=not status.is_empty()
		row.support.visible=bool(row.wide) or status.is_empty()
		row.condition.add_theme_stylebox_override("normal",ui._thin_paper(Color("d99780")))
		row.condition.add_theme_color_override("font_color",Color("612e30"))
		var skill: Dictionary=ui.run.combat.skill_status(cat)
		row.meter.value=float(skill.get("progress",0))*100.0
		row.button.text="已使用" if bool(skill.get("used",false)) else ("✦ 释放绝招" if bool(skill.get("ready",false)) else "蓄能 %ds" % ceili(maxf(0,float(skill.get("duration",18))-float(skill.get("charge",0)))))
		row.button.disabled=paused or busy or bool(skill.get("used",false)) or not bool(skill.get("ready",false))
		row.panel.modulate=Color.WHITE
		row.button.add_theme_stylebox_override("normal",Paper.box("button",Color("f4cc6d") if bool(skill.get("ready",false)) and not bool(skill.get("used",false)) else Color("e0d9bd"),3))
	var toys: float=0
	for amount: Variant in ledger.get("damage_by_toy",{}).values(): toys+=float(amount)
	total.text="近 5 秒 · 有效战斗时间   /   场地与玩具累计 %.0f" % toys

func _skill(cat: String) -> void:
	if ui.controller.has_method("activate_cat_skill"):
		var result: Dictionary=ui.controller.activate_cat_skill(cat)
		if not bool(result.get("ok",false)): ui.notify(str(result.get("message","")))

func _hint(source: Control,cat: String) -> void:
	ui.fish_hint.present(source,source.get_global_rect(),str(Data.cats()[cat].name),"本场真实贡献",metrics.details(ui.run.s,cat),null,Rect2(0,0,1280,720))

func _skill_hint(source: Control,cat: String) -> void:
	var skill: Dictionary=ui.run.combat.skill_status(cat)
	ui.fish_hint.present(source,source.get_global_rect(),str(skill.get("name","绝招")),"每场一次 · 全屏演出",[str(skill.get("description","")),"上一段演出结束后，才能释放下一只猫。"] as Array[String],null,Rect2(0,0,1280,720))
