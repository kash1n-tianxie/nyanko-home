extends RefCounted
## Read-only explanations of existing recipes. No recommendation changes RNG or rules.
const Data=preload("res://scripts/catalog.gd")
const Difficulty=preload("res://scripts/difficulty_rules.gd")
const BLACKHOLE_METEOR_HINT: String="黑洞吸住至少3只非首领：1秒后砸中心；共用陨石发射、不加发，联动冷却12秒"
const FISH_BADGES={"F01":["⑂","多发"],"F02":["✹","群伤"],"F03":["↶","贯穿"],"F04":["❄","控制"],"F05":["↻","复读"],"F06":["ϟ","电链"],"F07":["✦","暴击"],"F08":["⬡","护家"],"F09":["↑","对空"],"F10":["●","墨印"]}
const EFFECT_NAMES={"attack_bonus":"攻击加成","speed_bonus":"攻速加成","projectile_bonus":"额外主弹","projectile_ratio":"每枚伤害","repeat_every":"每几次复读","repeat_ratio":"复读伤害","knockback":"击退","bounce_extra":"额外弹射","bounce_ratio":"弹射伤害","explosion_ratio":"爆炸伤害","explosion_radius":"爆炸半径","chain_extra":"额外电链","chain_ratio":"电链伤害","slow_pct":"减速","freeze_every":"每几次冻结","freeze_duration":"冻结秒数","air_bonus":"对空加成","air_homing":"对空追踪","bell_bonus":"回响加成","cleanse_interval":"净化间隔","heal_amount":"回复耐久","meteor_interval":"陨石间隔","meteor_damage":"陨石伤害","base_shield_max":"护盾上限","base_shield_amount":"补充护盾","base_damage_taken":"基地承伤","laser_damage":"激光伤害","revive_charges":"整局复活次数","bleed_dps":"每秒流血","blackhole_interval":"黑洞间隔","decoy_interval":"诱饵间隔","cannon_damage":"喵炮伤害","cannon_threshold":"吸收蓄能门槛","cannon_cooldown":"喵炮冷却","support_echo_ratio":"录音回声伤害","support_echo_cooldown":"每猫回声冷却"}
const PERCENT_FIELDS=["bounce_ratio","support_echo_ratio","attack_bonus","speed_bonus","projectile_ratio","repeat_ratio","explosion_ratio","chain_ratio","slow_pct","air_bonus","bell_bonus","base_damage_taken"]

static func worn(s: Dictionary,cat: String) -> Array:
	var result: Array=[]
	for item: Dictionary in s.get("items",{}).values():
		if item.get("location","")=="equipped" and str(item.get("cat",""))==cat: result.append(item)
	return result

static func badges(s: Dictionary,cat: String) -> Array:
	var result: Array=[]
	for item: Dictionary in worn(s,cat):
		var kind: String=str(item.kind)
		var level: int=Data.effective(item,cat)
		var badge: Array=FISH_BADGES.get(kind,["✦","能力"])
		var config: Dictionary=Data.fish(kind,int(item.quality),level)
		result.append({"icon":badge[0],"name":badge[1],"active":level>=3,"cat":cat,"fish":kind,"level":level,"text":str(config.get("mechanic_description","")) if level>=3 else "生效 3 级解锁；当前 %d 级" % level})
	if result.is_empty():
		var innate: Dictionary={"C01":["↗","单体"],"C02":["✹","群伤"],"C03":["ϟ","电链"],"C04":["❄","控制"],"C05":["→","穿透"],"C06":["♪","增益"]}
		var marker: Array=innate.get(cat,["✦","攻击"])
		result.append({"icon":marker[0],"name":marker[1],"active":true,"cat":cat,"fish":"","level":0,"text":str(Data.cats().get(cat,{}).get("skill_summary",""))})
	return result.slice(0,3)

static func _fish_reason(s: Dictionary,kinds: Array,active_text: String,locked_text: String) -> Dictionary:
	var future: Dictionary={}
	for cat: String in s.get("active",[]):
		for item: Dictionary in worn(s,cat):
			if item.kind not in kinds: continue
			var level: int=Data.effective(item,cat)
			var row: Dictionary={"cat":cat,"fish":item.kind,"active":level>=3,"text":active_text if level>=3 else locked_text}
			if level>=3: return row
			if future.is_empty(): future=row
	return future

static func _add(entries: Array,text: String,cat: String="",fish: String="",active: bool=true) -> void:
	if entries.size()<2: entries.append({"text":text,"cat":cat,"fish":fish,"active":active})

static func reasons(s: Dictionary,toy: String) -> Array:
	var result: Array=[]
	var active: Array=s.get("active",[])
	var toys: Dictionary=s.get("toys",{})
	var stage: int=mini(Data.last_stage(),int(s.get("stage",0))+(1 if s.get("phase","")=="toy_reward" else 0))
	var next: Dictionary=Data.stages()[stage]
	var airborne: bool=int(next.counts[7])+int(next.counts[8])>0
	var reason: Dictionary={}
	match toy:
		"T01":
			reason=_fish_reason(s,["F02","F06","F10"],"复读齐射也带着鱼干效果","鱼干生效 3 级后，复读可送出效果")
		"T02":
			if "C04" in active: _add(result,"击退后，争取下一次落锤","C04")
			reason=_fish_reason(s,["F04"],"减速＋击退，延缓靠近","冰晶生效 3 级后可再减速")
		"T03":
			reason=_fish_reason(s,["F02","F04","F06","F10"],"把鱼干效果送到下一只","鱼干生效 3 级后可随弹射传播")
			if "C01" in active: _add(result,"高伤鱼骨多打一个目标","C01")
		"T04":
			reason=_fish_reason(s,["F01","F03"],"多弹／贯穿带来多个爆点","生效 3 级后可在多处爆炸")
			if int(toys.get("T19",0))>0: _add(result,"黑洞聚怪，让爆炸覆盖更多")
			elif int(toys.get("T03",0))>0: _add(result,"弹射把爆点送到下一只")
		"T05":
			reason=_fish_reason(s,["F01","F03"],"多个载体带出额外电链","生效 3 级后可从更多落点放电")
			if "C03" in active: _add(result,"墨墨原有电链外再补一跳","C03")
		"T06":
			var foe: String=str(next.boss) if str(next.boss)!="" else str(next.elite)
			if int(next.counts[9])>0 or str(Data.enemies().get(foe,{}).get("skill","")) in ["web","confusion"]: _add(result,"下一关有缠身／混乱，可净化")
			if "C06" in active: _add(result,"净化后，小铃继续送回响","C06")
		"T07":
			if "C06" in active: _add(result,"小铃攻击较快，积攒冻结次数","C06")
			reason=_fish_reason(s,["F05"],"攻速构筑更快积攒攻击次数","薄荷生效 3 级后还会复读")
		"T08":
			if airborne: _add(result,"下一关有空中衣架／飞碟碗")
			if "C04" in active: _add(result,"改善对空命中；保留武器射程限制","C04")
		"T09":
			if "C02" in active: _add(result,"放慢怪群，毛球更容易覆盖","C02")
			if int(toys.get("T13",0))>0: _add(result,"拖慢目标，给独立陨石争取落点")
		"T10":
			if int(toys.get("T04",0))>0: _add(result,"更多主弹，更多实际爆点")
			elif int(toys.get("T05",0))>0: _add(result,"更多主弹落点，携带额外电链")
			reason=_fish_reason(s,["F02","F06","F10"],"更多主弹传播命中效果","鱼干生效 3 级后再传播机制")
		"T11": _add(result,"每次只回复真实损失的耐久")
		"T12":
			if "C06" in active: _add(result,"强化小铃返回队友的回响","C06")
			else: _add(result,"当前获得攻速；招到小铃再用回响")
		"T13","T16":
			_add(result,"独立火力随大本营成长，不吃猫的攻击／攻速")
			if toy=="T13" and int(toys.get("T19",0))>0: _add(result,BLACKHOLE_METEOR_HINT)
		"T14","T17":
			if next.rank=="boss": _add(result,"下一关是首领，给猫爬架兜底")
			var reports: Array=s.get("stage_reports",[])
			if not reports.is_empty() and float(reports[-1].get("feedback",{}).get("base",{}).get("hp_damage",0))>0: _add(result,"上一关实际失血，补足护家手段")
		"T15":
			if int(toys.get("T14",0))+int(toys.get("T11",0))+int(toys.get("T17",0))>0: _add(result,"已有护盾／回复承担承伤代价")
			reason=_fish_reason(s,["F08"],"厚壳护家，帮助承担承伤代价","厚壳生效 3 级后才开启护家机制")
		"T18":
			reason=_fish_reason(s,["F01","F03"],"多弹／贯穿把伤口送给更多目标","生效 3 级后可扩大流血覆盖")
		"T19":
			if int(toys.get("T13",0))>0: _add(result,BLACKHOLE_METEOR_HINT)
			for cat: String in ["C02","C04","C05"]:
				if cat in active: _add(result,"聚成一团，发挥范围／穿透","%s" % cat)
			if int(toys.get("T04",0))>0: _add(result,"聚怪让爆米花覆盖更多")
		"T21":
			if int(toys.get("T14",0))>0: _add(result,"纸箱堡垒的护盾被打掉后，为喵炮蓄能")
			else: _add(result,"需要纸箱堡垒、厚壳鱼干或羁绊等护盾来源")
			_add(result,"只计真实盾吸收；冷却6秒，最多储一发")
		"T22":
			if "C06" in active and active.size()>1: _add(result,"小铃返回队友后，下一次主攻击送出弱回声","C06")
			else: _add(result,"需要小铃与至少一位队友同场","C06","",false)
			_add(result,"每猫冷却4秒；单发回声不携带鱼干效果")
		"T20":
			if int(toys.get("T13",0))>0: _add(result,"停住怪群，等待陨石落下")
			else: _add(result,"拖延推进；首领停留减半")
	if not reason.is_empty() and result.size()<2: result.append(reason)
	return result.slice(0,2)

static func _value(key: String,value: Variant) -> String:
	if value is bool: return "开启" if value else "关闭"
	if key in PERCENT_FIELDS: return str(snappedf(float(value)*100,.1))+"%"
	return str(snappedf(float(value),.1))

static func _display_value(s: Dictionary,key: String,value: Variant) -> String:
	if key in ["meteor_damage","laser_damage","cannon_damage"]:
		return _value(key,float(value)*Difficulty.independent_power(int(s.get("hq",1))))
	return _value(key,value)

static func _independent_damage_line(s: Dictionary,id: String,picking: bool) -> String:
	var owned: int=int(s.get("toys",{}).get(id,0))
	var preview: Dictionary=s.get("toys",{}).duplicate(true)
	if owned<=0: preview[id]=1
	var effect: String="meteor_damage" if id=="T13" else "laser_damage"
	var effects: Dictionary=Data.toy_effects(preview)
	var current: float=float(effects.get(effect,0))
	var interval: float=float(effects.get("meteor_interval" if id=="T13" else "laser_interval",0))
	var label: String="当前" if owned>0 else ("获得后" if picking else "首件预览")
	var hq: int=clampi(int(s.get("hq",1)),1,5)
	return "%s伤害%s，每%s秒 · 本Lv.%d ×%d%%；不吃猫攻击／攻速" % [label,_display_value(s,effect,current),_value("interval",interval),hq,roundi(Difficulty.independent_power(hq)*100)]

static func stack_changes(s: Dictionary,id: String) -> Array[String]:
	var before_stacks: Dictionary=s.get("toys",{}).duplicate(true)
	var after_stacks: Dictionary=before_stacks.duplicate(true)
	after_stacks[id]=int(after_stacks.get(id,0))+1
	var before: Dictionary=Data.toy_effects(before_stacks)
	var after: Dictionary=Data.toy_effects(after_stacks)
	var changed: Array[String]=[]
	for key: String in EFFECT_NAMES:
		if before.get(key)==after.get(key): continue
		changed.append("%s %s → %s" % [EFFECT_NAMES[key],_display_value(s,key,before[key]),_display_value(s,key,after[key])])
	if changed.is_empty():
		var until_growth: int=0
		for extra: int in range(1,13):
			var future_stacks: Dictionary=after_stacks.duplicate(true)
			future_stacks[id]=int(after_stacks[id])+extra
			if Data.toy_effects(future_stacks)!=after:
				until_growth=extra
				break
		changed.append("已到上限" if until_growth==0 else "本次效果不变；再拿 %d 件到下一档" % until_growth)
	return changed

static func hint_lines(s: Dictionary,id: String,picking: bool) -> Array[String]:
	var spec: Dictionary=Data.toys().get(id,{})
	var lines: Array[String]=[]
	var delta: Array[String]=stack_changes(s,id)
	if picking and int(s.get("toys",{}).get(id,0))>0:
		lines.append("；".join(delta))
	else: lines.append(str(spec.get("summary","")))
	if id=="T21":
		var preview: Dictionary=s.get("toys",{}).duplicate(true)
		preview[id]=maxi(1,int(preview.get(id,0)))
		var effects: Dictionary=Data.toy_effects(preview)
		lines.append("当前喵炮%s伤害 · 本Lv.%d；仅实际盾吸收蓄能" % [_display_value(s,"cannon_damage",effects.cannon_damage),int(s.get("hq",1))])
	if id in ["T13","T16"]:
		lines.append(_independent_damage_line(s,id,picking))
		# The exact combo deserves the remaining line; the independent-fire
		# explanation is already included in the current-damage line above.
		if id=="T13" and int(s.get("toys",{}).get("T19",0))>0: lines.append(BLACKHOLE_METEOR_HINT)
		return lines
	for reason: Dictionary in reasons(s,id):
		var prefix: String="" if bool(reason.active) else "◇ 待解锁 · "
		if not str(reason.cat).is_empty(): prefix+=str(Data.cats()[reason.cat].name)+" · "
		lines.append(prefix+str(reason.text))
	if id=="T10" and not lines[0].contains("85%"):
		lines[0]+="；每枚主弹 85%，非等比翻倍"
	if id=="T15" and picking:
		lines[0]="；".join(delta)
	return lines.slice(0,3)

static func thresholds(before: Dictionary,after: Dictionary,cat: String) -> Array[String]:
	var old: Dictionary={}
	for item: Dictionary in worn(before,cat): old[str(item.kind)]=Data.effective(item,cat)
	var lines: Array[String]=[]
	for item: Dictionary in worn(after,cat):
		var level: int=Data.effective(item,cat)
		var previous: int=int(old.get(str(item.kind),0))
		var config: Dictionary=Data.fish(item.kind,int(item.quality),level)
		if level>=5 and previous<5: lines.append("%s · 生效 5 级：%s" % [Data.fish_name(item.kind),config.get("growth_description",config.get("mechanic_description",""))])
		elif level>=3 and previous<3: lines.append("%s · 生效 3 级：%s" % [Data.fish_name(item.kind),config.get("mechanic_description","")])
	return lines
