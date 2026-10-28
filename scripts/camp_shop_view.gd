extends Control
## A five-dish camp counter; all mutations are dispatched as run commands.
const Data=preload("res://scripts/catalog.gd")
const FishArt=preload("res://scripts/fish_art.gd")
const Advisor=preload("res://scripts/shop_advisor.gd")
const Paper=preload("res://scripts/collage_theme.gd")
var ui: Control
var state: Dictionary={}
var previews: Dictionary={}

func setup(owner_ui: Control) -> void:
	ui=owner_ui;name="CampFishShop"
	position=Vector2(20,430);size=Vector2(1240,173)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	state=ui.run.shop_status() if ui.run.has_method("shop_status") else {}
	var title: Label=ui._at_label(self,"今日鱼摊",Rect2(8,0,151,30),25)
	title.add_theme_stylebox_override("normal",ui._thin_paper(Color("eedbb1")))
	var options: Button=ui._at_button(self,"鱼摊选项",Rect2(708,0,161,32),show_tools,"ShopTools")
	options.add_theme_font_size_override("font_size",18)
	var refresh: Button=ui._at_button(self,"刷新 · %d" % int(state.get("refresh_cost",3)),Rect2(880,0,161,32),func() -> void: ui.dispatch("shop_refresh"),"ShopRefresh",ui.GOLD)
	refresh.disabled=bool(state.get("locked",false)) or int(ui.run.s.gold)<int(state.get("refresh_cost",3))
	var lock: Button=ui._at_button(self,"已锁店" if bool(state.get("locked",false)) else "锁定鱼摊",Rect2(1054,0,180,32),func() -> void: ui.dispatch("shop_lock"),"ShopLock",ui.TEAL if bool(state.get("locked",false)) else ui.PAPER)
	for control: Button in [refresh,lock]: control.add_theme_font_size_override("font_size",18)
	ui._bind_hint(lock,"保留整店","买后空盘也保留",["锁店会放弃下一关自动上新。","解锁后才能付费刷新。"] as Array[String])
	for slot: int in range(5): _offer(slot)

func _offer(slot: int) -> void:
	var offers: Array=state.get("offers",[])
	var item: Dictionary=offers[slot] if slot<offers.size() else {}
	var plate: Panel=ui._plate(self,Rect2(slot*249,41,239,132),"ShopDish%d" % slot)
	plate.add_theme_stylebox_override("panel",Paper.box("slot",Color("f3e4c5"),3))
	plate.mouse_filter=Control.MOUSE_FILTER_IGNORE
	if item.is_empty() or bool(item.get("sold",false)):
		ui._at_label(plate,"空盘",Rect2(71,35,105,29),23).modulate=Color("9a8d75")
		ui._at_label(plate,"刷新后补货",Rect2(57,77,145,26),17)
		return
	var watched: bool=str(item.kind) in state.get("wishlist",[])
	if watched: plate.add_theme_stylebox_override("panel",Paper.box("slot",Color("ffe7a3"),3))
	var name_label: Label=ui._at_label(plate,Data.fish_name(str(item.kind)).replace("小鱼干","鱼"),Rect2(15,8,179,28),20)
	name_label.add_theme_color_override("font_color",[Color("302c27"),Color("33788d"),Color("947020")][int(item.quality)])
	var star: Button=ui._at_button(plate,"★" if watched else "☆",Rect2(191,7,35,29),func() -> void: ui.dispatch("shop_watch",{"kind":str(item.kind)}),"ShopWatch%d" % slot)
	star.add_theme_stylebox_override("normal",ui._thin_paper(Color("e1ca8f") if watched else Color("e7dbc1")))
	star.add_theme_font_size_override("font_size",21)
	ui._bind_hint(star,"取消关注" if watched else "关注这种鱼","最多两种 · 不改变刷新概率",["关注的鱼出现时亮起金色鱼盘。"] as Array[String])
	ui._fish_static(plate,item,Rect2(12,43,95,80),true,false)
	var tag: Label=ui._at_label(plate,("3级 · " if Data.effective(item,ui.prep_focus_cat)<3 else "生效 · ")+Advisor.effect_tag(str(item.kind)),Rect2(116,36,111,24),18)
	tag.add_theme_color_override("font_color",Color("48796f"))
	ui._at_label(plate,"Lv.%d · %s色" % [int(item.level),["白","蓝","金"][int(item.quality)]],Rect2(118,60,110,24),17)
	var buy: Button=ui._at_button(plate,"%d 金币" % int(item.price),Rect2(116,87,111,35),func() -> void: ui.dispatch("shop_buy",{"slot":slot,"offer_id":str(item.id)}),"ShopBuy%d" % slot,ui.GOLD)
	buy.disabled=int(ui.run.s.gold)<int(item.price) or not ui._recruit_choices().is_empty()
	buy.add_theme_font_size_override("font_size",20)
	var hover: Button=ui._transparent_button(plate,Rect2(6,6,181,76),func() -> void: _hint(plate,slot),"ShopInfo%d" % slot)
	for source: Control in [hover,buy]:
		source.mouse_entered.connect(func() -> void: _hint(source,slot))
		source.mouse_exited.connect(func() -> void: ui.fish_hint.close_from(source);ui.highlight_shop_ingredients([]))
		source.focus_entered.connect(func() -> void: _hint(source,slot))
		source.focus_exited.connect(func() -> void: ui.fish_hint.close_from(source);ui.highlight_shop_ingredients([]))
	if bool(item.get("ordered",false)): ui._at_label(plate,"订",Rect2(86,103,25,22),15)

func focus_changed() -> void:
	previews.clear()

func _hint(source: Control,slot: int) -> void:
	var item: Dictionary=state.offers[slot]
	var key: String="%d:%s:%d" % [slot,ui.prep_focus_cat,ui.prep_focus_slot]
	if not previews.has(key): previews[key]=Advisor.preview(ui.run,slot,ui.prep_focus_cat,ui.prep_focus_slot)
	var comparison: Dictionary=previews[key]
	var lines: Array[String]=Advisor.lines(comparison)
	if lines.is_empty(): lines.assign([Data.short_description(item),Data.growth_description(item)])
	ui.highlight_shop_ingredients(comparison.get("ingredients",[]))
	ui.fish_hint.present(source,source.get_global_rect(),Data.fish_name(str(item.kind)),"%s色 Lv.%d · %d金币" % [["白","蓝","金"][int(item.quality)],int(item.level),int(item.price)],lines,FishArt.texture(str(item.kind)),Rect2(0,0,1280,425))

func show_tools() -> void:
	var column: VBoxContainer=ui._modal("鱼摊选项","shop_tools",780,320)
	var back: Button=ui.overlay.find_child("Close",true,false) as Button
	if back!=null: back.text="返回营地"
	ui._label(column,"订货与合成",22)
	var order: Button=ui._button(column,"指定订货",show_order,"ShopOrder")
	order.custom_minimum_size.y=48
	order.disabled=not bool(state.get("order_available",false))
	ui._label(column,"每章一次 · 占用第5格",18)
	var auto: Button=ui._button(column,"✓ 购后合成" if bool(state.get("auto_merge",true)) else "购后合成：关",func() -> void: ui.dispatch("shop_auto_merge"),"ShopAutoMerge")
	auto.custom_minimum_size.y=48
	ui._bind_hint(auto,"购买后自动合成","仅闲置鱼",["保护已装备的鱼。","只合成同种、同品质、同等级。"] as Array[String])
	ui._label(column,"☆ 最多关注2种",18)
	ui._label(column,"点击鱼盘上的星星，标记想要的鱼。",18)
	ui._focus_first()

func show_order() -> void:
	var column: VBoxContainer=ui._modal("指定订货 · 每章一次","shop_order",960,340)
	ui._label(column,"选一条已有鱼，订购同种同品质 Lv.1；将替换第5格。",20)
	var scroll: VBoxContainer=ui._scroll(column,180)
	var grid: GridContainer=GridContainer.new();grid.columns=8;scroll.add_child(grid)
	var seen: Dictionary={}
	for item: Dictionary in ui.run.s.get("items",{}).values():
		var key: String=str(item.kind)+":"+str(item.quality)
		if seen.has(key): continue
		seen[key]=true
		var tile: Button=ui._fish_tile(grid,item,Rect2(0,0,98,92),func() -> void: _order_confirm(item),"OrderFish"+str(item.id))
		tile.custom_minimum_size=Vector2(98,92)
	if seen.is_empty(): ui._label(scroll,"先获得一条鱼干，才能指定订货。",20)
	ui._focus_first()

func _order_confirm(item: Dictionary) -> void:
	var price: int=[6,9,14][int(item.quality)]+4
	ui.show_confirm("替换第5格订货？","%s · %s色 Lv.1\n标价 %d金币（含4金币服务费）。订货现在不扣钱，购买时付款。\n原第5格商品会被替换，本章只能订一次。" % [Data.fish_name(str(item.kind)),["白","蓝","金"][int(item.quality)],price],func() -> void: ui.dispatch("shop_order",{"id":str(item.id)}),func() -> void: ui.show_prep())
