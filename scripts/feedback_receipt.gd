extends RefCounted
## Small read-only stage receipts. All figures originate in the resolved combat ledger.
const Data=preload("res://scripts/catalog.gd")
const METRIC_LABELS={"stuns":"眩晕次数","stun_seconds":"眩晕覆盖秒数","triggers":"发动","hits":"命中","damage":"有效伤害","knockback_distance":"有效后退","knockback":"击退次数","frozen_seconds":"冻结秒数","freeze_seconds":"冻结秒数","slow_seconds":"减速秒数","slow_targets":"减速目标","cleansed":"净化次数","cleanse_count":"净化次数","pulled":"聚拢目标","pull_targets":"聚拢目标","decoy_seconds":"拖延秒数","healed":"真实回复","shield_added":"新增护盾","shield_absorbed":"实际吸收","revived":"复活回复","buff_seconds":"队友受益秒数","air_bonus_damage":"对空额外伤害","air_hits":"对空命中","misses":"砸空次数","extra_projectiles":"额外主弹","repeat_volleys":"追加齐射","volleys":"追加齐射","extra_carriers":"额外主弹","targets":"作用目标","explosions":"爆炸次数","chain_hits":"额外电链命中","cleanses":"净化次数","cleansed_web":"解除蛛网","cleansed_confusion":"解除混乱","freezes":"冻结次数","eligible_air_damage":"对空有效伤害","slowed_targets":"减速目标","healed_hp":"实际回复","buffs":"强化回响次数","benefit_seconds":"强化覆盖（猫·秒）","shield_remaining":"剩余护盾","revives":"消耗猫命","restored_hp":"复活恢复","pulled_targets":"拉拢目标","pull_distance":"有效拉拢距离","affected_targets":"生效目标","delay_seconds":"拖延秒数","carrier_hits":"载体命中","attack_bonus":"攻击加成","speed_bonus":"攻速加成","air_bonus":"对空加成","base_damage_taken":"基地承伤倍率","projectile_ratio":"主弹伤害系数","buffed_allies":"受益队友数","self_buff_seconds":"自身强化秒数","charge_received":"实际入库蓄能","armed_returns":"录入队友回响","echoes":"弱回声发射","casts":"发射次数","impact_hits":"落点命中","meteor_combos":"黑洞引导陨石","covered_targets":"覆盖目标"}

static func latest(s: Dictionary) -> Dictionary:
	if not s.get("last_feedback_report",{}).is_empty(): return s.last_feedback_report
	var entries: Array=s.get("stage_reports",[])
	if entries.is_empty(): return {}
	return entries[-1].get("feedback",{})

static func source_name(source: String) -> String:
	var id: String=source.split("|")[0].split(":")[0]
	if Data.cats().has(id): return str(Data.cats()[id].name)
	if Data.toys().has(id): return str(Data.toys()[id].name)
	if id.begins_with("F"): return Data.fish_name(id)
	return {"primary":"主攻击","extra":"附加效果","base":"猫爬架"}.get(source,source)

static func detail_lines(report: Dictionary) -> Array[String]:
	var lines: Array[String]=["本场有效伤害 %.1f" % float(report.get("total_damage",0))]
	if bool(report.get("partial",false)): lines.append("旧存档：仅记录 %.1fs 后的实战" % float(report.get("observed_from",0)))
	var sources: Dictionary=report.get("direct_sources",{})
	var keys: Array=sources.keys()
	keys.sort_custom(func(a: String,b: String) -> bool: return float(sources[a])>float(sources[b]))
	for key: String in keys.slice(0,3): lines.append("%s · %.1f" % [source_name(key),float(sources[key])])
	return lines

static func medals(report: Dictionary) -> Array:
	if report.is_empty(): return []
	var entries: Array=[]
	for kind: String in ["damage_by_cat","damage_by_toy"]:
		for source: String in report.get(kind,{}): entries.append({"source":source,"damage":float(report[kind][source])})
	entries.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return float(a.damage)>float(b.damage))
	var winner: Dictionary=entries[0] if not entries.is_empty() else {"source":"base","damage":0.0}
	var first: Dictionary={"source":winner.source,"title":source_name(str(winner.source)),"text":"%.0f 伤害" % float(winner.damage),"subtitle":"本场直接伤害 · 不含过量","lines":detail_lines(report)}
	if Data.cats().has(str(winner.source)): first.subtitle="猫咪有效伤害 · 含绝招"
	var toy_entries: Dictionary=report.get("toys",{})
	var newest: String=str(report.get("recent_toy",""))
	if newest.is_empty() and not toy_entries.is_empty():
		var toy_ids: Array=toy_entries.keys()
		toy_ids.sort_custom(func(a: String,b: String) -> bool: return float(toy_entries[a].get("damage",0))+float(toy_entries[a].get("triggers",0))>float(toy_entries[b].get("damage",0))+float(toy_entries[b].get("triggers",0)))
		newest=str(toy_ids[0])
	var second: Dictionary={"source":newest,"title":"构筑留痕","text":"尚未触发","subtitle":"本场真实作用","lines":[]}
	if not newest.is_empty():
		var metrics: Dictionary=toy_entries.get(newest,{})
		second.title=source_name(newest)
		second.text="发动 %d 次" % int(metrics.get("triggers",0)) if int(metrics.get("triggers",0))>0 else "尚未触发"
		var detail: Array[String]=["有效命中 %d · 伤害 %.1f" % [int(metrics.get("hits",0)),float(metrics.get("damage",0))]]
		for metric: String in metrics.get("metrics",{}):
			if detail.size()>=4: break
			detail.append(metric_text(metric,float(metrics.metrics[metric])))
		if int(metrics.get("triggers",0))==0:
			if newest in ["T06","T11","T12","T15"] and (float(metrics.get("metrics",{}).get("attack_bonus",0))+float(metrics.get("metrics",{}).get("speed_bonus",0)))>0:
				second.text="常驻加成生效"
				detail.append("常驻加成已生效；条件技能本场未发动。")
			else: detail.append({"T17":"本场未被击破，没有消耗猫命。","T08":"本场未命中空中敌人。","T13":"没有到达触发时刻或没有可用目标。","T14":"本场未需要补充护盾。"}.get(newest,"本场没有满足触发条件。"))
		second.lines=detail
	else:
		var support: Dictionary=report.get("support",{})
		if not support.is_empty():
			var source: String=str(support.keys()[0])
			second.source=source
			second.title=source_name(source)
			second.text="辅助生效"
			var details: Array[String]=[]
			for metric: String in support[source]:
				if details.size()>=4: break
				details.append(metric_text(metric,float(support[source][metric])))
			second.lines=details
		else: second.lines=["尚无玩具／辅助作用记录。","下一次强化后，可在家里试打比较。"]
	var measured_support: Dictionary=_support_card(report)
	if not measured_support.is_empty(): second=measured_support
	var base: Dictionary=report.get("base",{})
	var absorbed: float=float(base.get("shield_absorbed",0))
	var healed: float=float(base.get("healed",0))
	var lost: float=float(base.get("hp_damage",0))
	var text: String="失血 %.0f" % lost if lost>maxf(absorbed,healed) else ("吸收 %.0f" % absorbed if absorbed>=healed else "回复 %.0f" % healed)
	if maxf(lost,maxf(absorbed,healed))==0: text="完好守住"
	var third: Dictionary={"source":"base","title":"家守住了吗","text":text,"subtitle":"吸收、回复、失血分开记","lines":["护盾吸收 %.1f · 格挡 %.1f" % [absorbed,float(base.get("blocked",0))],"耐久损失 %.1f · 回复 %.1f" % [lost,healed],"剩余护盾 %.1f · 复活恢复 %.1f" % [float(base.get("shield_remaining",0)),float(base.get("revived",0))]]}
	return [first,second,third]

static func _support_card(report: Dictionary) -> Dictionary:
	var support: Dictionary=report.get("support",{})
	var keys: Array=support.keys()
	keys.sort()
	# Support uses its own units. Never turn coverage into guessed extra damage
	# or rank shields, healing and time against one another as equivalent points.
	if "C06" in keys:
		keys.erase("C06")
		keys.push_front("C06")
	var order: Array[String]=["benefit_seconds","shield_absorbed","healed_hp","restored_hp","blocked","cleansed_web","cleansed_confusion","stun_seconds","freeze_seconds","slow_seconds","delay_seconds","pull_distance"]
	var rows: Array=[]
	for source: String in keys:
		var values: Dictionary=support[source]
		for metric: String in order:
			if float(values.get(metric,0))>0:
				rows.append({"source":source,"metric":metric,"value":float(values[metric])})
				break
	if rows.is_empty(): return {}
	var lead: Dictionary=rows[0]
	var source: String=str(lead.source)
	var lines: Array[String]=[]
	for row: Dictionary in rows.slice(0,3):
		lines.append("%s · %s" % [source_name(str(row.source)),metric_text(str(row.metric),float(row.value))])
	if source=="C06":
		lines.append("返回强化 %d 次 · 受益队友 %d 位" % [int(support[source].get("buffs",0)),int(support[source].get("buffed_allies",0))])
	return {"source":source,"title":source_name(source)+" · 辅助","text":metric_text(str(lead.metric),float(lead.value)),"subtitle":"实际辅助记录 · 各项独立计量","lines":lines}

static func failure_rows(s: Dictionary) -> Array:
	var report: Dictionary=s.get("failure_feedback",{})
	var hits: Array=report.get("last3",report.get("base",{}).get("damage_events",[]))
	var result: Array=[]
	for hit: Dictionary in hits.slice(maxi(0,hits.size()-3)):
		var enemy: String=str(hit.get("enemy_kind",""))
		var label: String=str(Data.enemies().get(enemy,{}).get("name","不明来源"))
		var skill: String=str(hit.get("skill_kind","普通攻击"))
		skill={"heavy":"重击","heavy_followup":"第二拍重击","contact":"碰撞","normal":"普攻","attack":"普攻"}.get(skill,skill)
		var details: Array[String]=["%.2fs · %s" % [float(hit.get("time",0)),skill],"护盾吸收 %.1f · 耐久损失 %.1f" % [float(hit.get("shield_absorbed",0)),float(hit.get("hp_damage",0))],"耐久 %.1f → %.1f" % [float(hit.get("hp_before",0)),float(hit.get("hp_after",0))]]
		if float(hit.get("revive_amount",0))>0: details.append("存钱罐救场：恢复 %.1f" % float(hit.revive_amount))
		result.append({"source":enemy,"title":label,"subtitle":skill,"text":"盾 −%.0f / 家 −%.0f" % [float(hit.get("shield_absorbed",0)),float(hit.get("hp_damage",0))],"lines":details})
	return result

static func metric_text(metric: String,value: float) -> String:
	var label: String=str(METRIC_LABELS.get(metric,metric))
	if metric in ["attack_bonus","speed_bonus","air_bonus"]: return "%s +%.1f%%" % [label,value*100]
	if metric=="projectile_ratio": return "%s %.1f%%" % [label,value*100]
	if metric=="base_damage_taken": return "%s ×%.2f" % [label,value]
	return "%s %.1f" % [label,value]
