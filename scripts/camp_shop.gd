extends RefCounted
## Persisted camp offers. Browsing never consumes combat/reward randomness.
const Data=preload("res://scripts/catalog.gd")
const PRICES: Array=[[6,11,20],[9,17,32],[14,26,50]]

static func validate(state: Dictionary) -> bool:
	if state.has("shop"):
		var shop: Variant=state.shop
		if not shop is Dictionary: return false
		for key: String in ["stage","refreshes","serial"]:
			if not shop.get(key) is int: return false
		if int(shop.refreshes)<0 or int(shop.serial)<0: return false
		for key: String in ["locked","auto_merge"]:
			if not shop.get(key) is bool: return false
		if not shop.get("offers") is Array or shop.offers.size() not in [0,5]: return false
		if not shop.get("ordered_chapters") is Array: return false
		if shop.has("wishlist"):
			if not shop.wishlist is Array or shop.wishlist.size()>2: return false
			var watched: Array=[]
			for kind: Variant in shop.wishlist:
				if kind not in Data.fish_kinds() or kind in watched: return false
				watched.append(kind)
		for chapter: Variant in shop.ordered_chapters:
			if not chapter is int or int(chapter)<1 or int(chapter)>5: return false
		var ids: Array=[]
		for offer: Variant in shop.offers:
			if not offer is Dictionary: return false
			if not offer.get("id") is String or offer.id in ids: return false
			ids.append(offer.id)
			if offer.get("kind","") not in Data.fish_kinds(): return false
			for key: String in ["quality","level","price"]:
				if not offer.get(key) is int: return false
			if int(offer.quality)<0 or int(offer.quality)>2 or int(offer.level)<1 or int(offer.level)>3 or int(offer.price)<0: return false
			if not offer.get("sold") is bool: return false
	if state.has("meal"):
		var meal: Variant=state.meal
		if not meal is Dictionary: return false
		for key: String in ["cat","item_id"]:
			if not meal.get(key) is String: return false
		if not meal.get("slot") is int or not meal.get("used") is bool: return false
		for key: String in ["flight_left","flight_duration"]:
			if not (meal.get(key) is float or meal.get(key) is int) or not is_finite(float(meal[key])) or float(meal[key])<0: return false
		if float(meal.flight_left)>float(meal.flight_duration) or float(meal.flight_duration)>.65: return false
		if str(meal.item_id)!="":
			if not state.items.has(meal.item_id) or meal.cat not in state.active or int(meal.slot)<0 or int(meal.slot)>2: return false
	return true

static func migrate(run: RefCounted) -> void:
	if not run.s.rng.has("shop"):
		var rng:=RandomNumberGenerator.new();rng.seed=int(run.s.seed)+782321
		run.s.rng.shop=rng.state
	if not run.s.has("shop"):
		run.s.shop={"stage":-1,"offers":[],"locked":false,"auto_merge":true,"refreshes":0,"serial":0,"ordered_chapters":[]}
	if not run.s.has("meal"): run.s.meal=empty_meal()
	if not run.s.shop.has("wishlist"): run.s.shop.wishlist=[]
	# Preserve every paid legacy catch; there is no fishing flight in this mode.
	for fish: Dictionary in run.s.items.values():
		if fish.location in ["pending","basket"]: fish.location="inventory"
		if not fish.has("reserved"): fish.reserved=false
	run.s.pending="";run.s.cast_left=0.0
	if str(run.s.phase)=="prep": enter(run)

static func empty_meal() -> Dictionary:
	return {"item_id":"","cat":"","slot":-1,"used":false,"flight_left":0.0,"flight_duration":.55}

static func count(run: RefCounted) -> int:
	var total: int=0
	for fish: Dictionary in run.s.items.values():
		if fish.location in ["inventory","inbox","basket","pending"]: total+=1
	return total

static func enter(run: RefCounted) -> void:
	var shop: Dictionary=run.s.shop
	if int(shop.stage)==int(run.s.stage): return
	shop.stage=int(run.s.stage);shop.refreshes=0
	if not bool(shop.locked) or shop.offers.size()!=5: roll_offers(run)

static func _offer(run: RefCounted,kind: String,quality: int,level: int,ordered: bool=false) -> Dictionary:
	var shop: Dictionary=run.s.shop;shop.serial+=1
	var basis: int=PRICES[quality][level-1]
	return {"id":"offer_%d"%int(shop.serial),"kind":kind,"quality":quality,"level":level,"price":basis+(4 if ordered else 0),"paid_basis":basis,"sold":false,"ordered":ordered}

static func roll_offers(run: RefCounted) -> void:
	var shop: Dictionary=run.s.shop
	var order: Dictionary={}
	if shop.offers.size()==5 and bool(shop.offers[4].get("ordered",false)) and not bool(shop.offers[4].sold): order=shop.offers[4]
	var offers: Array=[]
	var hq: Dictionary=Data.hq(int(run.s.hq))
	for i: int in range(4):
		var quality: int=run.weighted("shop",hq.quality)
		var level: int=run.weighted("shop",hq.levels)+1
		var kind: String=Data.fish_kinds()[run.rand_index("shop",Data.fish_kinds().size())]
		offers.append(_offer(run,kind,quality,level))
	if not order.is_empty(): offers.append(order)
	else:
		var choices: Array=[];var seen: Array=[]
		for fish: Dictionary in run.s.items.values():
			var key: String="%s_%d"%[fish.kind,int(fish.quality)]
			if int(fish.level)<5 and key not in seen:
				choices.append(fish);seen.append(key)
		if choices.is_empty(): offers.append(_offer(run,Data.fish_kinds()[run.rand_index("shop",Data.fish_kinds().size())],0,1))
		else:
			var pick: Dictionary=choices[run.rand_index("shop",choices.size())]
			offers.append(_offer(run,pick.kind,int(pick.quality),1))
	shop.offers=offers

static func status(run: RefCounted) -> Dictionary:
	if not run.s.has("shop"): migrate(run)
	if str(run.s.phase)=="prep": enter(run)
	var shop: Dictionary=run.s.shop
	return {"offers":shop.offers.duplicate(true),"locked":shop.locked,"auto_merge":shop.auto_merge,"refresh_cost":3 if int(shop.refreshes)<2 else 6,"count":count(run),"capacity":int(run.s.hq)*5,"order_available":run.current_chapter() not in shop.ordered_chapters,"wishlist":shop.get("wishlist",[]).duplicate()}

static func command(run: RefCounted,action: String,args: Dictionary) -> Dictionary:
	if str(run.s.phase)!="prep": return run._result(false,"回家后才能逛鱼摊")
	enter(run)
	var shop: Dictionary=run.s.shop
	match action:
		"shop_watch":
			var kind: String=str(args.get("kind",""))
			if kind not in Data.fish_kinds(): return run._result(false,"请选择有效鱼干")
			if kind in shop.wishlist: shop.wishlist.erase(kind)
			elif shop.wishlist.size()<2: shop.wishlist.append(kind)
			else: return run._result(false,"最多关注两种鱼干，请先取消一个关注")
			return run._result(true,"已关注 · 只标亮鱼盘，不改变出现概率" if kind in shop.wishlist else "已取消关注")
		"shop_lock":
			shop.locked=not bool(shop.locked)
			return run._result(true,"鱼摊已锁定" if shop.locked else "鱼摊已解锁")
		"shop_auto_merge":
			shop.auto_merge=not bool(shop.auto_merge)
			return run._result(true,"购买后自动合成闲置鱼干" if shop.auto_merge else "自动合成已关闭")
		"shop_refresh":
			if shop.locked: return run._result(false,"先解锁鱼摊再刷新")
			var price: int=3 if int(shop.refreshes)<2 else 6
			if int(run.s.gold)<price: return run._result(false,"刷新需要 %d 金币"%price)
			run.change_gold(-price,"shop_refresh_spend");shop.refreshes+=1;roll_offers(run)
			run.events.append({"type":"shop_refresh"})
			return run._result(true,"新鲜鱼干上桌")
		"shop_order":
			if run.current_chapter() in shop.ordered_chapters: return run._result(false,"本章订货已使用")
			var fish: Dictionary=run.item(str(args.get("id","")))
			if fish.is_empty(): return run._result(false,"请选择已经拥有的鱼干订货")
			if shop.offers.size()==5 and bool(shop.offers[4].get("ordered",false)) and not bool(shop.offers[4].sold): return run._result(false,"先购买上一份订货")
			shop.offers[4]=_offer(run,fish.kind,int(fish.quality),1,true)
			shop.ordered_chapters.append(run.current_chapter())
			return run._result(true,"同种同品质 Lv.1 已放在第五盘 · 含4金币订货费")
		"shop_buy":
			var index: int=int(args.get("slot",-1))
			if index<0 or index>=shop.offers.size(): return run._result(false,"请选择鱼盘")
			var offer: Dictionary=shop.offers[index]
			if offer.sold or (args.has("offer_id") and str(args.offer_id)!=str(offer.id)): return run._result(false,"这一盘已买走或已刷新")
			if int(run.s.gold)<int(offer.price): return run._result(false,"还差 %d 金币"%(int(offer.price)-int(run.s.gold)))
			# Preview actual compaction on an isolated state: a failed purchase is atomic.
			var previous: Dictionary=run.s.items.duplicate(true);var sequence: int=run.s.next_item
			var fish: Dictionary=run.create_item(offer.kind,int(offer.quality),int(offer.level),int(offer.get("paid_basis",offer.price)),"inventory")
			var merged: int=run._merge_all_loose(false) if bool(shop.auto_merge) else 0
			if count(run)>int(run.s.hq)*5:
				run.s.items=previous;run.s.next_item=sequence
				return run._result(false,"鱼篓已满，先装备、合成或出售")
			run.change_gold(-int(offer.price),"fish_spend");offer.sold=true
			run.s.stats.shop_bought=int(run.s.stats.get("shop_bought",0))+1
			run.events.append({"type":"shop_purchase","id":fish.id,"kind":offer.kind,"merged":merged})
			return run._result(true,"买下%s%s"%[Data.fish_name(offer.kind)," · 自动合成%d次"%merged if merged>0 else ""])
	return run._result(false,"未知鱼摊操作")
