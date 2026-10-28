extends RefCounted
## Presentation-only cumulative snapshots. Uses simulation seconds, never wall time.
var samples: Array[Dictionary]=[]
var identity: String=""
var observed_from: float=0.0
var ledger_observed_from: float=0.0
var restoring: bool=false
var last_time: float=-1.0

func sample(state: Dictionary) -> void:
	var ledger: Dictionary=state.get("feedback",{})
	var now: float=float(state.get("battle",{}).get("time",0))
	var token: String="%s:%s:%s" % [state.get("seed",0),state.get("stage",0),ledger.get("observed_from",0)]
	if token!=identity or now<last_time:
		samples.clear();identity=token
		ledger_observed_from=float(ledger.get("observed_from",0))
		# A view opened mid-battle has no reliable last-five-second history.
		# Seed with the current cumulative totals instead of inventing a burst.
		restoring=now>ledger_observed_from+.25
		observed_from=now if restoring else ledger_observed_from
		if not restoring: samples.append({"time":ledger_observed_from,"damage":{}})
	last_time=now
	var totals: Dictionary=ledger.get("damage_by_cat",{}).duplicate()
	if samples.is_empty() or now>float(samples[-1].time)+.00001:
		samples.append({"time":now,"damage":totals})
	else:
		# Cinematic damage can land while combat time stands still.
		samples[-1].damage=totals
	while samples.size()>2 and float(samples[1].time)<now-5.0:
		samples.pop_front()

func dps(cat: String) -> float:
	if samples.is_empty() or last_time<=observed_from: return -1.0
	var span: float=minf(5.0,last_time-observed_from)
	var boundary: float=last_time-span
	var base: float=float(samples[0].damage.get(cat,0)) if restoring else 0.0
	if boundary>observed_from+.001:
		for i: int in range(samples.size()-1):
			var a: Dictionary=samples[i]
			var b: Dictionary=samples[i+1]
			if float(a.time)<=boundary and float(b.time)>=boundary:
				var mix: float=inverse_lerp(float(a.time),float(b.time),boundary)
				base=lerpf(float(a.damage.get(cat,0)),float(b.damage.get(cat,0)),mix)
				break
	return maxf(0.0,float(samples[-1].damage.get(cat,0))-base)/maxf(.001,span)

func details(state: Dictionary,cat: String) -> Array[String]:
	var ledger: Dictionary=state.get("feedback",{})
	var total: float=float(ledger.get("damage_by_cat",{}).get(cat,0))
	var elapsed: float=maxf(.001,last_time-ledger_observed_from)
	var skill: float=0
	for key: String in ledger.get("damage_by_source",{}):
		if key.begins_with(cat+"|") and key.get_slice("|",4).begins_with("active_"): skill+=float(ledger.damage_by_source[key])
	var lines: Array[String]=["累计伤害 %.0f · 场均 %.1f / 秒" % [total,total/elapsed],"绝招伤害 %.0f" % skill]
	var support: Dictionary=ledger.get("support",{}).get(cat,{})
	for pair: Array in [["shield_absorbed","护盾实际吸收"],["stuns","眩晕目标"],["cleanses","净化次数"],["knockback_distance","击退距离"],["buffs","鼓舞次数"]]:
		if float(support.get(pair[0],0))>0: lines.append("%s %.0f" % [pair[1],float(support[pair[0]])])
	if restoring and last_time-observed_from<5.0: lines.append("读档后正在积累实时窗口（%.1f / 5秒）。" % maxf(0,last_time-observed_from))
	lines.append("近5秒有效战斗时间；独立玩具伤害单独统计。")
	return lines
