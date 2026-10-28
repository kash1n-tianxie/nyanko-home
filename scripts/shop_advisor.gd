extends RefCounted
## Read-only shop query. Both buying/merging and equipping use production rules on a
## detached run; no save, events, item identities or RNG state escape into the game.
const Data=preload("res://scripts/catalog.gd")
const Battle=preload("res://scripts/combat.gd")
const TAGS={"F01":"分叉","F02":"灼烧","F03":"贯穿","F04":"减速","F05":"回响","F06":"电链","F07":"暴击","F08":"护盾","F09":"对空","F10":"墨印"}

static func _copy(run: RefCounted) -> RefCounted:
	var copy: RefCounted=run.get_script().new()
	copy.s=run.s.duplicate(true)
	copy.autosave=false
	copy.combat=Battle.new();copy.combat.setup(copy)
	return copy

static func stats(run: RefCounted,cat: String) -> Dictionary:
	if cat not in run.s.get("active",[]): return {"attack":0.0,"rate":0.0}
	var copy: RefCounted=_copy(run)
	copy.combat.start_stage()
	# Show stable equipped stats. Temporary battle-opening haste is labelled by its
	# fish tooltip, rather than baked into a permanent comparison.
	copy.s.battle.time=10.0
	return copy.combat.cat_display_stats(cat).duplicate(true)

static func effect_tag(kind: String) -> String:
	return str(TAGS.get(kind,"构筑强化"))

static func preview(run: RefCounted,offer_slot: int,cat: String,fish_slot: int) -> Dictionary:
	var offers: Array=run.s.get("shop",{}).get("offers",[])
	if offer_slot<0 or offer_slot>=offers.size() or cat not in run.s.get("active",[]) or fish_slot<0 or fish_slot>2: return {}
	var offer: Dictionary=offers[offer_slot]
	if bool(offer.get("sold",false)): return {}
	var copy: RefCounted=_copy(run)
	var before: Dictionary=stats(run,cat)
	var old_items: Dictionary=copy.s.items.duplicate(true)
	# paid_basis is additive in the real merge operation. In this isolated query,
	# zero existing bases and mark only the proposed purchase with one to trace its
	# descendant through arbitrarily many merges. Prices and all gameplay inputs
	# remain unchanged; this marker never touches a save or the returned item.
	for fish: Dictionary in copy.s.items.values(): fish.paid_basis=0
	copy.s.shop.offers[offer_slot].paid_basis=1
	copy.s.gold=maxi(int(copy.s.gold),int(offer.price))
	var purchase: Dictionary=copy.command("shop_buy",{"slot":offer_slot,"offer_id":str(offer.id)})
	var answer: Dictionary={"valid":false,"reason":purchase.message,"affordable":int(run.s.gold)>=int(offer.price),"before":before,"after":before.duplicate(),"attack_delta":0.0,"rate_delta":0.0,"item":offer.duplicate(true),"ingredients":[],"effective":Data.effective(offer,cat),"slot":fish_slot,"cat":cat,"merged":false,"threshold":""}
	if not bool(purchase.ok): return answer
	var result: Dictionary={}
	for fish: Dictionary in copy.s.items.values():
		if int(fish.paid_basis)==1: result=fish;break
	if result.is_empty(): answer.reason="无法定位合成结果";return answer
	var ingredients: Array[String]=[]
	for id: String in old_items:
		var old: Dictionary=old_items[id]
		if old.location not in ["inventory","inbox","basket"] or bool(old.get("reserved",false)): continue
		var new: Dictionary=copy.item(id)
		if new.is_empty() or int(new.level)>int(old.level): ingredients.append(id)
	answer.ingredients=ingredients
	answer.item=result.duplicate(true);answer.item.erase("paid_basis")
	answer.effective=Data.effective(result,cat)
	answer.merged=int(result.level)>int(offer.level)
	var prior: Dictionary=run.equipped(cat)[fish_slot]
	var prior_effective: int=Data.effective(prior,cat) if not prior.is_empty() and prior.kind==result.kind else 0
	if int(answer.effective)>=5 and prior_effective<5: answer.threshold="装配后 · 5级质变"
	elif int(answer.effective)>=3 and prior_effective<3: answer.threshold="装配后 · 3级机制解锁"
	var equipped: Dictionary=copy.command("equip",{"id":str(result.id),"cat":cat,"slot":fish_slot})
	answer.valid=bool(equipped.ok);answer.reason=equipped.message
	if answer.valid:
		answer.after=stats(copy,cat)
		answer.attack_delta=float(answer.after.attack)-float(before.attack)
		answer.rate_delta=float(answer.after.rate)-float(before.rate)
	return answer

static func lines(value: Dictionary) -> Array[String]:
	if value.is_empty(): return []
	var item: Dictionary=value.item
	var output_lines: Array[String]=[]
	if bool(value.merged): output_lines.append("买后合成 → Lv.%d · 高亮材料" % int(item.level))
	else: output_lines.append("买入库存 · 手动装配")
	if not bool(value.affordable): output_lines.append("金币不足 · 以下为装配预览")
	if not bool(value.valid): output_lines.append(str(value.reason));return output_lines
	output_lines.append("换入%s · 第%d槽后" % [Data.cats()[value.cat].name,int(value.slot)+1])
	output_lines.append("攻击 %.1f → %.1f  (%+.1f)" % [float(value.before.attack),float(value.after.attack),float(value.attack_delta)])
	output_lines.append("攻速 %.2f → %.2f 次/秒  (%+.2f)" % [float(value.before.rate),float(value.after.rate),float(value.rate_delta)])
	if not str(value.threshold).is_empty(): output_lines.append(str(value.threshold))
	else: output_lines.append("生效 Lv.%d · 3级解锁 / 5级质变" % int(value.effective))
	if Data.effective(item,str(value.cat))>int(item.level): output_lines[-1]+=" · ♥+1级"
	var config: Dictionary=Data.fish(str(item.kind),int(item.quality),int(value.effective))
	var effect: String=str(config.get("mechanic_description","")) if int(value.effective)>=3 else str(Data.fish(str(item.kind),int(item.quality),3).get("mechanic_description",""))
	output_lines.append(("效果：" if int(value.effective)>=3 else "3级：")+effect.get_slice("；",0).get_slice("。",0))
	return output_lines
