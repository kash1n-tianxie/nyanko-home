extends RefCounted
## Character flavour and prop names only; combat rules remain in catalog/combat.
const PROFILES: Dictionary = {
	"C01":{"weapon":"鱼骨剑","quip":"剑是昨晚吃剩的。","accent":"c88c48","specialty":"远程单体高伤"},
	"C02":{"weapon":"毛球弹弓","quip":"弹药库存，在肚子里。","accent":"ae936d","specialty":"扎堆溅射"},
	"C03":{"weapon":"插头叉","quip":"先别摸我，刚起静电。","accent":"8887bd","specialty":"闪电连锁"},
	"C04":{"weapon":"猫爪印章锤","quip":"不合格。退回去。","accent":"78946e","specialty":"中距震荡眩晕"},
	"C05":{"weapon":"哈欠喇叭","quip":"打完叫我，没打完别叫。","accent":"aa83b8","specialty":"整条直线穿透"},
	"C06":{"weapon":"手铃＋锅盖盾","quip":"别慌！我先慌一下！","accent":"bf796b","specialty":"回响鼓舞队友"}
}

static func profile(id: String) -> Dictionary:
	return PROFILES.get(id,PROFILES.C01)
