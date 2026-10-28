extends RefCounted
## Read-only labels shared by preparation, itinerary, and the difficulty picker.
const Data=preload("res://scripts/catalog.gd")
const Atlas=preload("res://scripts/illustrated_atlas.gd")
static func profile(id: String) -> Dictionary:
	if ResourceLoader.exists("res://scripts/difficulty_rules.gd"):
		var rules: Script=load("res://scripts/difficulty_rules.gd")
		return rules.profile(id)
	return {"name":{"easy":"简单","hard":"困难","hell":"地狱"}.get(id,"简单"),"description":"需要合成鱼干与合理分工；难度在开局后固定。","hp":1.0,"damage":1.0,"pace":1.0,"skill_rate":1.0}
static func threats(stage: int) -> Array:
	if ResourceLoader.exists("res://scripts/battle_director.gd"):
		var director: Script=load("res://scripts/battle_director.gd")
		return director.threat_preview(stage).slice(0,3)
	var level: Dictionary=Data.stages()[clampi(stage,0,19)]
	var result: Array=[]
	var main_foe: String=str(level.boss) if not str(level.boss).is_empty() else str(level.elite)
	if not main_foe.is_empty(): result.append({"kind":main_foe,"name":Data.enemies()[main_foe].name,"detail":str(Data.enemies()[main_foe].get("skill","首领来袭"))})
	for index: int in [9,7,2,1,0]:
		if int(level.counts[index])<=0: continue
		var kind: String="E%02d" % (index+1)
		result.append({"kind":kind,"name":Data.enemies()[kind].name,"detail":{"E10":"缠身施法，净化与控制有用","E08":"空中目标，留意命中覆盖","E03":"耐打前排，保留单体火力","E02":"推进快，别让它漏过去","E01":"成群来袭，准备范围伤害"}.get(kind,"")})
		if result.size()>=3: break
	return result
static func boss_hint(stage: int) -> String:
	if ResourceLoader.exists("res://scripts/battle_director.gd"):
		var director: Script=load("res://scripts/battle_director.gd")
		return director.boss_hint(stage)
	return ""
static func wave_name(stage: int) -> String:
	if ResourceLoader.exists("res://scripts/battle_director.gd"):
		var director: Script=load("res://scripts/battle_director.gd")
		return director.wave_name(stage)
	return ["快慢夹击","护卫来袭","空地交错","首领之夜"][stage%4]
static func role(id: String) -> Dictionary:
	if id in ["T10","T15"]: return {"label":"承担代价","color":Color("aa5758")}
	if id in ["T02","T06","T08","T09","T11","T14","T17","T20"]: return {"label":"补足短板","color":Color("537b72")}
	return {"label":"扩大优势","color":Color("927139")}

const Advisor=preload("res://scripts/build_advisor.gd")
const Mutations=preload("res://scripts/cat_mutations.gd")
const BUILDS: Array=[
	{"id":"popcorn","name":"爆米花连锁","toys":["T04","T03"],"fish":["F01","F03"],"description":"多弹或贯穿送出爆点，再由乒乓球台传到下一只。"},
	{"id":"meteor","name":"黑洞陨石","toys":["T19","T13"],"fish":[],"description":"黑洞吸住至少3只非首领后，1秒后陨石砸中心；共用发射、不加发。"},
	{"id":"fortress","name":"纸箱反击堡","toys":["T14","T21"],"fish":[],"description":"纸箱堡垒补盾，护盾真实吸收18点来袭后，喵炮蓄成一发反击。"}]

static func reward_preview(state: Dictionary,id: String) -> Dictionary:
	var preview: Dictionary=state.duplicate(true)
	preview.toys=state.get("toys",{}).duplicate(true)
	preview.toys[id]=int(preview.toys.get(id,0))+1
	return preview

static func reward_gain(state: Dictionary,id: String) -> String:
	var count: int=int(state.get("toys",{}).get(id,0))
	var before: Dictionary=Data.toy_effects(state.get("toys",{}))
	var after: Dictionary=Data.toy_effects(reward_preview(state,id).toys)
	if before==after:
		if Data.Toys.is_capped(id,count): return "本次效果已满\n继续收集一件"
		var steps: int=1
		while steps<20:
			var future: Dictionary=state.get("toys",{}).duplicate(true)
			future[id]=count+1+steps
			if Data.toy_effects(future)!=after: break
			steps+=1
		return "本次尚未跨档\n再拿%d件到下一档" % steps
	if count==0:
		return {
			"T01":"每5次攻击\n多一次复读齐射", "T02":"每次命中\n把敌人往后推", "T03":"主弹弹向下一只\n鱼干效果一起带走",
			"T04":"每次命中\n多炸周围一圈", "T05":"命中再放电\n多打一只敌人", "T06":"全队攻击更快\n定时吹走异常",
			"T07":"每6次攻击\n把敌人冻住", "T08":"对空伤害提高\n主弹追踪飞行目标", "T09":"每次命中减速\n怪群更难靠近",
			"T10":"每只猫多一枚主弹\n每枚伤害变为85%", "T11":"攻击提高，定时修家\n只回复已损失耐久", "T12":"全队攻速提高\n小铃回响更强",
			"T13":"猫爬架落下陨石\n新增独立范围火力", "T14":"猫爬架定时补盾\n替耐久挡住来袭", "T15":"全队攻击 +25%\n代价：家承伤 +10%",
			"T16":"猫爬架自动射激光\n一次穿过多个敌人", "T17":"家被击破时\n多一次复活机会", "T18":"每次命中留伤口\n持续流血2秒",
			"T19":"黑洞把怪群聚拢\n范围攻击更好命中", "T20":"放出橡皮老鼠\n引诱敌人停下", "T21":"护盾实际吸收18点\n蓄一发喵炮反击", "T22":"小铃强化队友后\n队友下次附带回声"
		}.get(id,str(Data.toys()[id].summary))
	match id:
		"T10":
			if int(after.projectile_bonus)>int(before.projectile_bonus): return "全队再多一枚主弹\n每枚仍为85%伤害"
			return "全队攻速立即提高\n这次主弹数量不变"
		"T03": return "弹射再多打一只\n弹射伤害也提高" if int(after.bounce_extra)>int(before.bounce_extra) else "弹射伤害立即提高\n这次弹射次数不变"
		"T05": return "闪电再多连一只\n连锁伤害也提高" if int(after.chain_extra)>int(before.chain_extra) else "连锁伤害立即提高\n这次连锁人数不变"
		"T15": return "全队攻击进一步提高\n代价：家承伤也提高"
		"T17": return "再增加一次\n本局复活机会"
		"T14": return "护盾更厚\n每次补充也更多"
		"T04": return "爆炸伤害提高\n"+("爆炸范围更大" if float(after.explosion_radius)>float(before.explosion_radius) else "范围保持最大")
		"T13": return "陨石砸得更重\n"+("落下也更频繁" if float(after.meteor_interval)<float(before.meteor_interval) else "间隔保持5秒")
		"T16": return "激光伤害提高\n发射间隔不变"
		"T19","T20": return "等待更短\n控制发动更频繁"
		"T22": return "回声伤害提高\n每猫仍有4秒冷却"
		"T21": return "喵炮伤害提高\n蓄能门槛仍为18"
		"T08": return "对空伤害提高\n保持追踪飞行目标"
		"T11": return "攻击与回复提高\n每12秒修补家"
		"T06": return "攻速提高\n"+("净化来得更快" if float(after.cleanse_interval)<float(before.cleanse_interval) else "净化间隔保持4秒")
		"T12": return "攻速提高\n小铃回响更强"
		"T01": return "复读发动更频繁\n伤害保持85%" if float(after.repeat_ratio)==float(before.repeat_ratio) else "复读齐射伤害提高\n悬停看发动间隔"
		"T07": return "冻结持续更久\n悬停看发动间隔"
		"T02": return "击退距离增加\n把怪推得更远"
		"T09": return "减速力度提高\n靠近猫爬架更慢"
		"T18": return "伤口更痛\n每秒流血提高"
	return "立即强化现有效果"

static func reward_context(state: Dictionary,id: String) -> String:
	if id=="T22" and ("C06" not in state.get("active",[]) or state.get("active",[]).size()<2): return "◇ 需小铃与队友同场"
	if id=="T21" and not has_shield_source(state): return "◇ 还需要护盾来源"
	if id=="T13" and int(state.get("toys",{}).get("T19",0))>0: return "✓ 黑洞陨石联动就绪"
	if id=="T19" and int(state.get("toys",{}).get("T13",0))>0: return "✓ 黑洞陨石联动就绪"
	if id=="T22": return "队友的回声挂件"
	return "猫爬架挂载部位" if id in Mutations.HQ_TOYS else str(Data.cats()[preview_cat(state,id)].name)+"的外形变化"

static func has_shield_source(state: Dictionary) -> bool:
	if int(state.get("toys",{}).get("T14",0))>0: return true
	if "C02" in state.get("active",[]) and "C05" in state.get("active",[]): return true
	for cat: String in state.get("active",[]):
		for item: Dictionary in Advisor.worn(state,cat):
			if item.kind=="F08" and Data.effective(item,cat)>=3: return true
	return false

static func preview_cat(state: Dictionary,id: String) -> String:
	var active: Array=state.get("active",["C01"])
	for cat: String in active:
		if Mutations.beneficiary(state,cat,id): return cat
	return str(active[0]) if not active.is_empty() else "C01"

static func cat_sources(state: Dictionary,id: String) -> Array[String]:
	var lines: Array[String]=[]
	for item: Dictionary in Advisor.worn(state,id):
		var effective: int=Data.effective(item,id)
		lines.append("%s · 实际%d → 生效%d%s" % [Data.fish_name(item.kind),int(item.level),effective," · 变身已开" if effective>=5 else (" · 机制已开" if effective>=3 else " · 生效3级开机制")])
	for toy: String in state.get("toys",{}):
		if Mutations.beneficiary(state,id,toy): lines.append(str(Data.toys()[toy].name)+" · 全队玩具外形")
	if lines.is_empty(): lines.append("装备喜好鱼可多生效1级；生效3级点亮机制，5级进一步变身。")
	return lines

static func cat_source_line(state: Dictionary,id: String) -> String:
	var report: Dictionary=Mutations.describe(state,id)
	var sources: Array=report.get("sources",[])
	if sources.is_empty(): return "变身起点：喜好鱼 +1级\n生效3级开机制 · 5级再成长"
	var names: Array[String]=[]
	for source: String in sources.slice(0,2): names.append(Data.fish_name(source) if source.begins_with("F") else str(Data.toys()[source].name))
	return "变身："+names[0]+(" +%d种来源" % (sources.size()-1) if sources.size()>1 else "")+"\n悬停查看鱼干与玩具来源"

static func signature_builds(state: Dictionary) -> Array:
	var result: Array=[]
	for spec: Dictionary in BUILDS:
		var entry: Dictionary=spec.duplicate(true)
		var missing: Array[String]=[]
		var pieces: Array[String]=[]
		for toy: String in spec.toys:
			var owned: bool=int(state.get("toys",{}).get(toy,0))>0
			if not owned: missing.append(str(Data.toys()[toy].name))
			pieces.append(("✓ " if owned else "○ ")+str(Data.toys()[toy].name))
		var fish_ready: bool=spec.fish.is_empty()
		for cat: String in state.get("active",[]):
			for item: Dictionary in Advisor.worn(state,cat):
				if item.kind in spec.fish and Data.effective(item,cat)>=3: fish_ready=true
		entry.progress=" + ".join(pieces)
		entry.next="已成形 · 装备喜好鱼继续长大" if missing.is_empty() and fish_ready else ("下一步：找 "+missing[0] if not missing.is_empty() else "下一步：剑尾／回游鱼生效3级")
		entry.complete=missing.is_empty() and fish_ready
		result.append(entry)
	return result

static func codex_description(id: String) -> String:
	if id.begins_with("C"): return str(Data.cats().get(id,{}).get("skill_summary",""))
	if id.begins_with("T"): return str(Data.toys().get(id,{}).get("summary",""))
	if id.begins_with("F"): return "装备给喜欢它的猫，生效等级 +1。生效3级开启机制，5级进一步成长。"
	var enemy: Dictionary=Data.enemies().get(id,{})
	return str(enemy.get("skill_summary","留意它的推进速度和位置，在猫爬架前拦住它。"))
