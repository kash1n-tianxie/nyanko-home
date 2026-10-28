extends RefCounted
## Explicit, saved difficulty. Multipliers are applied once to fresh enemies.
## Easy keeps the authored campaign: it still requires fish and a growing team.
static func ids() -> Array[String]:
	return ["easy", "hard", "hell"]

static func profile(id: String) -> Dictionary:
	match id:
		"hard":
			return {"id":"hard", "name":"困难", "description":"敌人耐久 +18%，伤害 +15%，推进 +6%；技能更频繁。", "hp":1.18, "damage":1.15, "pace":1.06, "skill_rate":1.12, "counter_window":.94}
		"hell":
			return {"id":"hell", "name":"地狱", "description":"敌人耐久 +42%，伤害 +30%，推进 +12%；需要完整构筑。", "hp":1.42, "damage":1.30, "pace":1.12, "skill_rate":1.25, "counter_window":.88}
		_:
			return {"id":"easy", "name":"简单", "description":"标准守家压力；仍需钓鱼、合成与扩编，不能只靠初始装备。", "hp":1.0, "damage":1.0, "pace":1.0, "skill_rate":1.0, "counter_window":1.0}

static func independent_power(hq: int) -> float:
	# Explicit HQ growth, independent of cat attack or haste. Lv.1/2/3/4/5:
	# 100/125/150/175/200%. No hidden enemy or inventory scaling.
	return 1.0 + .25 * float(clampi(hq,1,5)-1)
