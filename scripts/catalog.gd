extends RefCounted
## Executable whitepaper tables. No runtime parsing of prose.

static var _fish: Dictionary = {}
const Toys = preload("res://scripts/toy_catalog.gd")
const QUALITIES: Array[String] = ["白色·家常", "蓝色·珍味", "金色·奇珍"]
const FISH_NAMES: Array[String] = ["剑尾", "焦香", "回游", "冰晶", "薄荷", "电鳗", "珍珠", "厚壳", "穿云", "墨汁"]
# Each price is the one-time cost to enter that level. A mixed spending route
# reaches Lv.3 in chapter1, Lv.4 in chapter3 and Lv.5 during chapter4.
const HQ_COST: Array[int] = [0,18,62,250,400]
const HQ_HP: Array[int] = [300,380,480,620,800]
const HQ_SLOTS: Array[int] = [1,2,3,4,5]
const QUALITY_ODDS: Array = [[100,0,0],[80,20,0],[60,35,5],[40,45,15],[20,45,35]]
const LEVEL_ODDS: Array = [[100,0,0],[85,15,0],[65,30,5],[40,45,15],[20,50,30]]
# Counts are E01..E10. E07 is a zero-gold summoned creature, never scheduled.
const COUNTS: Array = [
 [22,6,0,0,0,0,0,0,0,0],[24,10,2,0,0,0,0,2,0,0],[24,12,3,3,0,0,0,4,0,0],[28,14,4,4,2,0,0,4,0,0],
 [28,16,5,6,2,1,0,6,0,0],[30,18,6,8,3,1,0,6,2,0],[32,20,7,8,4,1,0,8,3,1],[32,20,8,10,5,2,0,8,4,1],
 [34,22,8,10,6,2,0,10,5,2],[36,24,9,12,6,2,0,10,6,2],[38,24,10,12,7,3,0,12,6,3],[40,26,10,14,8,3,0,12,8,3],
 [40,28,11,14,8,3,0,14,8,3],[42,28,12,16,9,4,0,14,10,4],[44,30,12,16,10,4,0,16,10,4],[46,32,14,18,10,4,0,16,12,5],
 [46,34,14,18,12,5,0,18,12,5],[48,34,15,20,12,5,0,18,14,6],[50,36,16,20,14,6,0,20,14,6],[54,38,18,22,16,6,0,22,16,8]]
const GOLD_BUDGET: Array[int] = [28,36,40,48,48,56,62,74,72,84,88,104,100,112,124,140,134,150,162,190]
const TIMES: Array[int] = [34,40,38,50,40,46,44,58,45,52,48,64,50,56,54,70,54,62,58,78]
const CHAPTERS: Array[String] = ["庭院赶走杂物", "倒走杂货街", "失眠洗衣厂", "荧屏天台", "月亮滚筒"]
const CHAPTER_HP: Array[float] = [1.0,1.25,1.55,1.85,2.15]
const CHAPTER_DAMAGE: Array[float] = [1.0,1.12,1.28,1.44,1.62]
# Fixed authored difficulty; never scales secretly with HQ or player loadout.
const PERIOD_HP: Array[float] = [1.0,1.05,1.10,1.15,1.25,1.32,1.38,1.45,1.55,1.65,1.75,1.85,2.0,2.12,2.24,2.36,2.5,2.65,2.8,3.0]
const PERIOD_PACE: Array[float] = [1.0,1.0,1.0,1.0,1.02,1.03,1.04,1.05,1.06,1.07,1.08,1.09,1.10,1.11,1.12,1.13,1.14,1.15,1.16,1.18]
const STARTER_FISH: Dictionary = {"C01":"F01","C02":"F03","C03":"F06","C04":"F02","C05":"F05","C06":"F07"}
const WORLD: String = "洗衣机偷走了月亮。月光消失后，外星力量让日用品变异。六只猫守在猫爬架上，追着杂物找回月亮。"

static func total_stages() -> int:
	return COUNTS.size()

static func last_stage() -> int:
	return total_stages()-1

static func boss_for_stage(index: int) -> String:
	return "B%02d" % (floori(index/4.0)+1) if index>=0 and index<total_stages() and index%4==3 else ""

static func elite_for_stage(index: int) -> String:
	return "X%02d" % (floori(index/4.0)+1) if index>=0 and index<total_stages() and index%4==1 else ""

static func fish_kinds() -> Array:
	var result: Array = []
	for index: int in range(FISH_NAMES.size()): result.append("F%02d" % (index+1))
	return result

static func toys() -> Dictionary:
	return Toys.all()

static func toy_effects(stacks: Dictionary) -> Dictionary:
	return Toys.effects(stacks)

static func starter_fish(cat_id: String) -> String:
	return str(STARTER_FISH.get(cat_id,"F01"))

static func chapter_scaling(index: int) -> Dictionary:
	var chapter: int = clampi(floori(index/4.0),0,CHAPTER_HP.size()-1)
	return {"hp":CHAPTER_HP[chapter],"damage":CHAPTER_DAMAGE[chapter]}

static func stage_pressure(index: int) -> Dictionary:
	var i: int=clampi(index,0,PERIOD_HP.size()-1)
	return {"hp":PERIOD_HP[i],"pace":PERIOD_PACE[i],"spawn_x":1296.0}

static func cats() -> Dictionary:
	return {
		"C01":{"name":"豆包","attack":22.0,"interval":1.05,"range":800.0,"speed":720.0,"favorites":["F01"],"weapon":"鱼骨剑","skill_name":"鱼骨直击","skill_summary":"远距离单体主弹，造成100%攻击伤害。","role":"鱼骨 · 高伤单体","bond":"夜巡搭子","color":"f1ba70"},
		"C02":{"name":"奶盖","attack":9.0,"interval":1.45,"range":930.0,"speed":560.0,"favorites":["F03"],"weapon":"毛球弹弓","skill_name":"毛球爆散","skill_summary":"每发命中，在170像素内对6个其他敌人造成75%攻击溅射。","innate_radius":170.0,"innate_targets":6,"innate_ratio":.75,"role":"毛球 · 大范围溅射","bond":"午睡联盟","color":"eee4d8"},
		"C03":{"name":"墨墨","attack":10.0,"interval":1.15,"range":760.0,"speed":0.0,"favorites":["F06"],"weapon":"插头叉","skill_name":"连锁放电","skill_summary":"每发命中，额外连锁3个敌人，每跳190像素、70%攻击伤害。","innate_radius":190.0,"innate_targets":3,"innate_ratio":.70,"role":"闪电 · 连锁放电","bond":"夜巡搭子","color":"77758e"},
		"C04":{"name":"麻糬","attack":15.0,"interval":1.65,"range":750.0,"speed":620.0,"favorites":["F02"],"weapon":"猫爪印章锤","skill_name":"掌波震地","skill_summary":"每发命中眩晕0.7秒；135像素内5个其他敌人受80%攻击并眩晕。","innate_radius":135.0,"innate_targets":5,"innate_ratio":.80,"innate_stun":.70,"role":"掌波 · 范围眩晕","bond":"护家小队","color":"b9ceb0"},
		"C05":{"name":"阿眠","attack":11.0,"interval":1.4,"range":700.0,"speed":600.0,"favorites":["F05"],"weapon":"哈欠喇叭","skill_name":"哈欠贯穿","skill_summary":"主弹沿攻击路径贯穿射程内所有敌人，每个100%攻击伤害。","role":"哈欠 · 射程内直线穿透","bond":"午睡联盟","color":"c7aedb"},
		"C06":{"name":"小铃","attack":7.0,"interval":0.85,"range":800.0,"speed":760.0,"favorites":["F07"],"weapon":"摇铃平底锅","skill_name":"铃声回响","skill_summary":"命中后铃声飞回随机队友，3秒内攻击和攻速+20%；独自出战时攻击+80%、攻速+25%。","role":"铃声 · 回响鼓舞伙伴","attack_pct":.20,"speed_pct":.20,"duration":3.0,"solo_attack_pct":.80,"solo_speed_pct":.25,"bond":"护家小队","color":"e4aea8"}}

static func enemies() -> Dictionary:
	var result: Dictionary = {
		"E01":{"trait":"slow","name":"毛球怪","hp":34.0,"speed":42.0,"damage":4.0,"interval":1.4,"armor":0.0,"gold":1,"draw_height":56.0},
		"E02":{"trait":"fast","name":"拖鞋精","hp":28.0,"speed":92.0,"damage":3.0,"interval":1.1,"armor":0.0,"gold":1,"draw_height":46.0},
		"E03":{"trait":"shell","name":"纸箱壳虫","hp":130.0,"speed":27.0,"damage":7.0,"interval":1.8,"armor":.28,"gold":2,"draw_height":82.0},
		"E04":{"trait":"swarm","name":"灰尘团","hp":58.0,"speed":40.0,"damage":4.0,"interval":1.5,"armor":0.0,"gold":1,"draw_height":64.0},
		"E05":{"trait":"roller","name":"罐头滚滚","hp":90.0,"speed":51.0,"damage":9.0,"interval":2.0,"armor":0.0,"gold":2,"draw_height":72.0},
		"E06":{"trait":"guard","rank":"large","name":"搬运头目","hp":260.0,"speed":29.0,"damage":10.0,"interval":2.0,"armor":.10,"guard_radius":125.0,"guard_reduction":.18,"gold":4,"draw_height":138.0,"skill":"rally","skill_cd":14.0,"skill_duration":4.0,"skill_strength":.20,"skill_targets":4},
		"E07":{"trait":"minion","name":"灰尘幼体","hp":20.0,"speed":48.0,"damage":2.0,"interval":1.5,"armor":0.0,"gold":0,"draw_height":32.0},
		"E08":{"trait":"flying","name":"蝙蝠衣架","hp":42.0,"speed":64.0,"damage":4.0,"interval":1.6,"armor":0.0,"gold":1,"draw_height":72.0,"air":true,"air_height":180.0},
		"E09":{"trait":"flying_shell","name":"飞碟碗","hp":105.0,"speed":36.0,"damage":7.0,"interval":1.9,"armor":.18,"gold":2,"draw_height":88.0,"air":true,"air_height":245.0},
		"E10":{"trait":"binder","rank":"large","name":"胶带木乃伊","hp":300.0,"speed":26.0,"damage":12.0,"interval":2.2,"armor":.12,"gold":4,"draw_height":155.0,"skill":"web","skill_cd":16.0,"skill_duration":3.0,"skill_strength":.28,"skill_targets":1},
		"X01":{"name":"蜘蛛晾衣架","trait":"web_elite","rank":"elite","hp":360.0,"speed":28.0,"damage":9.0,"interval":2.1,"armor":.08,"gold":8,"draw_height":205.0,"skill":"web","skill_cd":11.0,"skill_duration":3.0,"skill_strength":.30,"skill_targets":1},
		"X02":{"name":"催眠收音机","trait":"confuse_elite","rank":"elite","hp":520.0,"speed":26.0,"damage":12.0,"interval":2.2,"armor":.06,"gold":10,"draw_height":200.0,"skill":"confusion","skill_cd":12.0,"skill_duration":3.0,"skill_strength":.42,"skill_targets":1},
		"X03":{"name":"滚筒拖把精","trait":"summon_elite","rank":"elite","hp":670.0,"speed":25.0,"damage":15.0,"interval":2.2,"armor":.12,"gold":12,"draw_height":225.0,"skill":"summon","skill_cd":13.0,"skill_duration":0.0,"skill_strength":1.0,"skill_targets":4},
		"X04":{"name":"荧屏主持人","trait":"confuse_elite","rank":"elite","hp":820.0,"speed":25.0,"damage":18.0,"interval":2.1,"armor":.10,"gold":14,"draw_height":230.0,"skill":"confusion","skill_cd":11.0,"skill_duration":3.6,"skill_strength":.48,"skill_targets":2},
		"X05":{"name":"月蚀洗衣篮","trait":"web_elite","rank":"elite","hp":1020.0,"speed":24.0,"damage":20.0,"interval":2.1,"armor":.15,"gold":16,"draw_height":245.0,"skill":"web","skill_cd":10.0,"skill_duration":4.0,"skill_strength":.38,"skill_targets":2},
		"B01":{"name":"纸箱队长","rank":"boss","hp":1600.0,"speed":25.0,"damage":18.0,"interval":2.6,"armor":.15,"gold":10,"draw_height":260.0,"skill":"rally","skill_cd":12.0,"skill_duration":4.0,"skill_strength":.25,"skill_targets":8},
		"B02":{"name":"吸尘器兽","rank":"boss","hp":3400.0,"speed":24.0,"damage":22.0,"interval":2.5,"armor":.08,"gold":14,"draw_height":275.0,"skill":"web","skill_cd":12.0,"skill_duration":3.5,"skill_strength":.35,"skill_targets":2},
		"B03":{"name":"贪吃影王","rank":"boss","hp":6200.0,"speed":23.0,"damage":26.0,"interval":2.4,"armor":.12,"gold":20,"draw_height":295.0,"skill":"summon","skill_cd":12.0,"skill_duration":0.0,"skill_strength":1.0,"skill_targets":6},
		"B04":{"name":"万眼电视塔","rank":"boss","hp":9800.0,"speed":22.0,"damage":28.0,"interval":2.3,"armor":.10,"gold":24,"draw_height":310.0,"skill":"confusion","skill_cd":11.0,"skill_duration":4.0,"skill_strength":.55,"skill_targets":2},
		"B05":{"name":"吞月洗衣机","rank":"boss","hp":15000.0,"speed":21.0,"damage":32.0,"interval":2.4,"armor":.12,"gold":30,"draw_height":330.0,"skill":"web","skill_cd":10.0,"skill_duration":4.0,"skill_strength":.40,"skill_targets":3}}
	for kind: String in result:
		var enemy: Dictionary = result[kind]
		var rank: String = str(enemy.get("rank","small"))
		enemy.merge({"rank":rank,"air":false,"air_height":170.0,"hit_radius":48.0 if rank in ["boss","elite"] else 24.0,"skill":"","skill_cd":0.0,"skill_duration":0.0,"skill_strength":0.0,"skill_targets":0,"skill_telegraph":1.1,"skill_start":2.4 if rank=="boss" else (4.0 if rank=="elite" else 7.0),"spawn_x":1320.0},false)
		if rank=="boss":
			var heavy: Dictionary = {"B01":{"heavy_damage":22.0,"heavy_interval":9.0,"heavy_windup":1.0},"B02":{"heavy_damage":18.0,"heavy_interval":8.0,"heavy_windup":1.0,"heavy_followup_damage":18.0,"heavy_followup_delay":.4},"B03":{"heavy_damage":32.0,"heavy_interval":9.0,"heavy_windup":1.2},"B04":{"heavy_damage":36.0,"heavy_interval":8.0,"heavy_windup":1.0},"B05":{"heavy_damage":18.0,"heavy_alternate_damage":28.0,"heavy_interval":7.0,"heavy_windup":1.0,"heavy_alternate_windup":1.3}}[kind]
			enemy.merge(heavy,false)
			enemy["heavy_start"] = 2.0
		enemy["skill_name"] = {"web":"蛛丝缠身","confusion":"杂音催眠","rally":"杂物号令","summon":"灰尘增援"}.get(str(enemy.skill),"无")
		enemy["skill_interval"] = enemy.skill_cd
		enemy["skill_windup"] = enemy.skill_telegraph
		enemy["skill_summary"] = "无主动技能" if str(enemy.skill)=="" else "%s · 间隔%.1f秒 · 持续%.1f秒 · %d个目标" % [enemy.skill_name,float(enemy.skill_cd),float(enemy.skill_duration),int(enemy.skill_targets)]
	return result

static func stages() -> Array:
	var result: Array = []
	for i: int in range(total_stages()):
		var chapter: int = floori(i/4.0)
		var encounter: int = i%4+1
		result.append({"index":i,"chapter":chapter+1,"encounter":encounter,"period":["白天","中午","傍晚","夜晚"][i%4],"duration":TIMES[i],"counts":COUNTS[i].duplicate(),"gold_budget":GOLD_BUDGET[i],"boss":boss_for_stage(i),"elite":elite_for_stage(i),"rank":"boss" if encounter==4 else ("elite" if encounter==2 else "normal"),"title":CHAPTERS[chapter],"biome":["courtyard","market","laundry","rooftop","moon_drum"][chapter],"background":background_for_stage(i)})
	return result

static func hq(level: int) -> Dictionary:
	var index: int = clampi(level-1,0,4)
	return {"level":level,"hp":HQ_HP[index],"slots":HQ_SLOTS[index],"cost":HQ_COST[index],"quality":QUALITY_ODDS[index],"levels":LEVEL_ODDS[index]}

static func fish(kind: String, quality: int, level: int) -> Dictionary:
	if _fish.is_empty():
		_fish = JSON.parse_string(FileAccess.get_file_as_string("res://data/fish.json"))
	return _fish.get("%s_%d_%d" % [kind,quality,clampi(level,1,5)],{}).duplicate(true)

static func fish_name(kind: String) -> String:
	return FISH_NAMES[clampi(int(kind.substr(1))-1,0,FISH_NAMES.size()-1)] + "小鱼干"

static func effective(item: Dictionary, cat_id: String = "") -> int:
	return mini(5,int(item.level)+(1 if cats().has(cat_id) and item.kind in cats()[cat_id].favorites else 0))

static func description(item: Dictionary, cat_id: String = "") -> String:
	if item.is_empty(): return "空槽 · 休整时装配小鱼干"
	var level: int = effective(item,cat_id)
	return "%s  ·  %s\n实际 Lv.%d → 生效 Lv.%d%s\n%s\n实付成本 %d · 回收 %d 金币" % [fish_name(item.kind),QUALITIES[int(item.quality)],int(item.level),level,"（喜欢 +1）" if level>int(item.level) else "",fish(item.kind,item.quality,level).get("description",""),int(item.paid_basis),floori(float(item.paid_basis)/2.0)]

static func short_description(item: Dictionary, cat_id: String = "") -> String:
	if item.is_empty(): return ""
	return str(fish(item.kind,int(item.quality),effective(item,cat_id)).get("description",""))

static func growth_description(item: Dictionary, _cat_id: String = "") -> String:
	if item.is_empty(): return ""
	var tier3: Dictionary=fish(item.kind,int(item.quality),3)
	var tier5: Dictionary=fish(item.kind,int(item.quality),5)
	return "3级 · %s\n5级 · %s" % [tier3.get("mechanic_description",""),tier5.get("growth_description",tier5.get("mechanic_description",""))]

static var _background_paths: Array=[]
static func background_for_stage(index: int) -> String:
	if _background_paths.is_empty():
		var value: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://art/expansion-v030/campaign-backgrounds.json"))
		if value is Dictionary: _background_paths=value.get("mapping",[])
	if not _background_paths.is_empty(): return str(_background_paths[clampi(index,0,_background_paths.size()-1)].path)
	return "res://art/story-v026/stage-01.png"
