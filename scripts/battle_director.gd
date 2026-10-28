extends RefCounted
## Authored identities, finite budgets. All 20 schedules preserve catalog counts
## and special units; no summon is promoted to a paid reinforcement.
const Data = preload("res://scripts/catalog.gd")
const NAMES: Array[String] = [
	"毛球试探 · 拖鞋抢跑", "晾衣架的空袭", "纸箱护送队", "折断纸箱旗",
	"罐头滚过长街", "收音机的护卫", "碗碟上下夹击", "堵住吸尘口",
	"洗衣厂的增援", "拖把的灰尘队", "胶带封锁线", "打翻影王晚餐",
	"天台空中走廊", "主持人开播", "重甲压住前排", "打断万眼直播",
	"月面急行军", "洗衣篮的蛛网", "最后的杂物潮", "掀开吞月滚筒"]
const PATTERNS: Array = [
	[0,0,1,0], [0,2,0,2], [1,0,1,3], [0,1,3,1],
	[0,1,0,1], [1,3,0,3], [2,1,2,0], [1,0,3,2],
	[0,3,0,3], [1,3,0,3], [1,3,2,3], [0,3,1,3],
	[2,0,2,1], [1,3,2,3], [1,2,1,3], [2,3,1,3],
	[0,2,1,0], [1,3,2,3], [0,1,2,3], [1,2,3,0]]
const LABELS: Array[String] = ["抢跑与群袭", "重甲护送", "上下夹击", "后排施法"]

static func wave_name(stage: int) -> String:
	return NAMES[clampi(stage,0,NAMES.size()-1)]

static func boss_hint(stage: int) -> String:
	if stage%4!=3: return ""
	@warning_ignore("integer_division") # Four stages share one chapter hint; preserve integer truncation.
	return ["号令前打倒标记护卫，折断旗子。", "吸气时集中攻击吸尘器，堵住吸口。", "吞噬前打倒标记杂物，打翻晚餐。", "开播时集中攻击电视塔，打断催眠。", "滚筒蓄力时打倒标记杂物，卡住蛛网喷口。"][clampi(stage/4,0,4)]

static func threat_preview(stage: int) -> Array[Dictionary]:
	var i: int=clampi(stage,0,19)
	var spec: Dictionary=Data.stages()[i]
	var primary_ids: Array[String]=["E02","E08","E03","E03","E05","E06","E09","E05","E04","E10","E10","E04","E08","E09","E03","E10","E02","E10","E09","E06"]
	var details: Dictionary={
		"E01":"慢速成群靠近；群攻能省下单体火力。",
		"E02":"会越过慢怪抢先到家；减速或近敌优先。",
		"E03":"纸箱护甲挡在前排；群攻、贯穿能碰到后排。",
		"E04":"密集灰尘团；爆炸和连锁能快速清场。",
		"E05":"第一次撞家更重；提前减速或集中击破。",
		"E06":"替附近杂物减伤并加速；优先威胁或范围攻击。",
		"E08":"从空中越过地面弹道；留一只猫优先对空。",
		"E09":"带护甲的高空敌人；对空增伤比乱打更有效。",
		"E10":"会缠住猫减攻速；优先施法者或带净化。"}
	var primary: String=primary_ids[i]
	var result: Array[Dictionary]=[{"kind":"enemy","enemy_id":primary,"name":Data.enemies()[primary].name,"detail":details[primary]}]
	if str(spec.elite)!="":
		var e: Dictionary=Data.enemies()[spec.elite]
		result.append({"kind":"elite","enemy_id":spec.elite,"name":e.name,"detail":e.skill_summary})
	elif str(spec.boss)!="":
		result.append({"kind":"boss","enemy_id":spec.boss,"name":Data.enemies()[spec.boss].name,"detail":boss_hint(i)})
	else:
		var secondary: String="E08" if int(spec.counts[7])>0 and primary!="E08" else ("E03" if int(spec.counts[2])>0 and primary!="E03" else "E01")
		result.append({"kind":"enemy","enemy_id":secondary,"name":Data.enemies()[secondary].name,"detail":details[secondary]})
	return result

static func category(kind: String) -> int:
	var e: Dictionary=Data.enemies().get(kind,{})
	if str(e.get("skill",""))!="": return 3
	if bool(e.get("air",false)): return 2
	if float(e.get("armor",0))>0 or kind=="E05": return 1
	return 0

static func schedule(stage: int) -> Array:
	var i: int=clampi(stage,0,19)
	var spec: Dictionary=Data.stages()[i]
	var groups: Array=[[],[],[],[]]
	var patterns: Array=PATTERNS[i]
	for k: int in range(spec.counts.size()):
		var kind: String="E%02d"%(k+1)
		var weights: Array=[]
		var total_weight: float=0.0
		for group: int in range(4):
			var weight: float=2.0 if category(kind)==int(patterns[group]) else 1.0
			weights.append(weight);total_weight+=weight
		var assigned: int=0
		var cumulative: float=0.0
		for group: int in range(4):
			cumulative+=float(weights[group])
			var next: int=roundi(float(spec.counts[k])*cumulative/total_weight)
			for _n: int in range(next-assigned): groups[group].append(kind)
			assigned=next
	var output: Array=[]
	var starts: Array=[0.0,.26,.50,.74]
	for group: int in range(4):
		var types: Array=groups[group]
		var pattern: int=int(patterns[group])
		types.sort_custom(func(a:String,c:String)->bool:
			var aa: int=_order(a,pattern)
			var cc: int=_order(c,pattern)
			return aa<cc if aa!=cc else a<c)
		for j: int in range(types.size()):
			var t: float=float(spec.duration)*(float(starts[group])+.18*float(j)/maxi(1,types.size()-1))
			var x: float=1080.0+float(j)*30.0 if group==0 and j<3 else 1300.0+float(j%3)*22.0
			output.append({"time":t,"kind":types[j],"x":x,"wave":group,"wave_name":LABELS[pattern]})
	if str(spec.elite)!="": output.append({"time":float(spec.duration)*.45,"kind":spec.elite})
	if str(spec.boss)!="": output.append({"time":float(spec.duration)*.60,"kind":spec.boss})
	output.sort_custom(func(a:Dictionary,c:Dictionary)->bool:return float(a.time)<float(c.time))
	return output

static func _order(kind: String, pattern: int) -> int:
	var c: int=category(kind)
	# Armour first gives it time to form a front; casters arrive behind it.
	if pattern==1 or pattern==3: return {1:0,0:1,2:2,3:3}[c]
	if pattern==2: return {0:0,2:1,1:2,3:3}[c]
	return {0:0,1:1,2:2,3:3}[c]
