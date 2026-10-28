extends RefCounted
## Permanent run-wide cat-tree toys. Inventory has no slot limit. Duplicate power
## grows as stacks^0.45; visual/secondary trigger caps prevent runaway recursion.
static func all() -> Dictionary:
	return {
		"T01":{"name":"复读鸭","summary":"每5次攻击，追加一次45%伤害的复读齐射。","tags":["复读","多发"],"stack_description":"重复获得降低触发间隔、提高复读伤害；最短每2次、最高85%。","mechanics":{"repeat_every":5,"repeat_ratio":.45}},
		"T02":{"name":"弹簧拳套","summary":"命中把敌人推后24像素；大型敌人抵抗部分击退。","tags":["击退","控制"],"stack_description":"击退随层数^0.45增加，最多75像素。","mechanics":{"knockback":24.0}},
		"T03":{"name":"乒乓球台","summary":"主弹额外弹向1个敌人，继承鱼干效果。","tags":["弹射","联动"],"stack_description":"每再获得3个增加1次弹射，最多3次；每次重复弹射伤害+1.5个百分点，55%起、最高85%。","mechanics":{"bounce_extra":1,"bounce_ratio":.55}},
		"T04":{"name":"爆米花桶","summary":"每发命中产生75像素爆炸，造成28%攻击伤害。","tags":["爆炸","多发"],"stack_description":"伤害随层数^0.45增加；爆炸不再次触发爆炸。","mechanics":{"explosion_ratio":.28,"explosion_radius":75.0}},
		"T05":{"name":"静电毛毯","summary":"每发命中向额外1个敌人放电，造成22%攻击伤害。","tags":["连锁","电击"],"stack_description":"每再获得3个多连1只，最多3只；伤害最高65%。","mechanics":{"chain_extra":1,"chain_ratio":.22}},
		"T06":{"name":"薄荷风车","summary":"全队攻速+8%；每12秒吹走减速与混乱。","tags":["攻速","净化"],"stack_description":"攻速随层数^0.45增加；净化间隔最短4秒。","mechanics":{"speed_bonus":.08,"cleanse_interval":12.0}},
		"T07":{"name":"冰格方糖","summary":"每6次攻击冻结命中的敌人0.45秒。","tags":["冻结","控制"],"stack_description":"触发最短每3次；冻结最多1.6秒，首领有控制抵抗。","mechanics":{"freeze_every":6,"freeze_duration":.45}},
		"T08":{"name":"纸飞机","summary":"对空伤害+35%，主弹追踪飞行敌人。","tags":["对空","追踪"],"stack_description":"对空加成随层数^0.45增加，追踪不重复叠加。","mechanics":{"air_bonus":.35,"air_homing":true}},
		"T09":{"name":"胶带球","summary":"命中减速18%，持续1.4秒；便于爆炸聚怪。","tags":["减速","聚怪"],"stack_description":"减速随层数^0.45增加，最高50%。","mechanics":{"slow_pct":.18,"slow_duration":1.4}},
		"T10":{"name":"万花筒","summary":"所有猫多发1枚主弹，每枚主弹伤害变为85%。","tags":["多发","变形"],"stack_description":"每再获得3个多1枚，最多额外3枚；每次重复全队攻速+2%，最多+12%；每枚85%只乘一次。","mechanics":{"projectile_bonus":1,"projectile_ratio":.85}},
		"T11":{"name":"猫爪小夜灯","summary":"全队攻击+4%；每12秒回复大本营6点耐久。","tags":["回复","攻击"],"stack_description":"攻击和回复量随层数^0.45增加，不超过最大耐久。","mechanics":{"attack_bonus":.04,"heal_interval":12.0,"heal_amount":6.0}},
		"T12":{"name":"打工闹钟","summary":"全队攻速+6%，小铃的回响额外增加15%攻击与攻速。","tags":["回响","攻速"],"stack_description":"两个加成都随层数^0.45增加；回响刷新持续时间。","mechanics":{"speed_bonus":.06,"bell_bonus":.15}},
		"T13":{"name":"陨石猫砂","summary":"首件每9秒砸下陨石，100像素内基础110伤害，随大本营成长。","tags":["独立攻击","陨石"],"stack_description":"伤害随层数^0.45增加，间隔最短5秒；大本营Lv.1—5伤害为100/125/150/175/200%。","mechanics":{"meteor_interval":9.0,"meteor_damage":110.0,"meteor_radius":100.0}},
		"T14":{"name":"纸箱堡垒","summary":"每8秒补12点大本营护盾，最多60点。","tags":["大本营","护盾"],"stack_description":"护盾上限和补充量随层数^0.45增加。","mechanics":{"base_shield_max":60.0,"base_shield_interval":8.0,"base_shield_amount":12.0}},
		"T15":{"name":"诅咒逗猫棒","summary":"全队攻击+25%，大本营受到的伤害也+10%。","tags":["诅咒","攻击"],"stack_description":"收益与代价都随层数^0.45增加。","mechanics":{"attack_bonus":.25,"base_damage_taken":1.10}},
		"T16":{"name":"自动激光笔","summary":"每7秒射出独立激光，最多穿过8个敌人，各基础65伤害，随大本营成长。","tags":["独立攻击","穿透"],"stack_description":"伤害随层数^0.45增加，间隔不变；大本营Lv.1—5伤害为100/125/150/175/200%。","mechanics":{"laser_interval":7.0,"laser_damage":65.0,"laser_targets":8}},
		"T17":{"name":"九命存钱罐","summary":"大本营被击破时碎裂，回复30%最大耐久；每个用一次。","tags":["复活","大本营"],"stack_description":"每获得1个增加1次整局复活机会，跨关卡共享。","mechanics":{"revive_charges":1,"revive_ratio":.30}},
		"T18":{"name":"幽灵猫抓板","summary":"命中附加流血，每秒8伤害，持续2秒。","tags":["流血","多发"],"stack_description":"流血伤害随层数^0.45增加，同一目标刷新持续时间。","mechanics":{"bleed_dps":8.0,"bleed_duration":2.0}},
		"T19":{"name":"罐头黑洞","summary":"每13秒聚拢180像素内最多6个敌人，首领不被吸动。","tags":["独立控制","聚怪"],"stack_description":"间隔最短8秒；搭配陨石，吸住至少3只非首领后1秒砸中心，共用发射不加发，联动冷却12秒。","mechanics":{"blackhole_interval":13.0,"blackhole_radius":180.0,"blackhole_pull":90.0,"blackhole_targets":6}},
		"T20":{"name":"橡皮老鼠","summary":"每14秒引诱4个敌人停下3秒；首领停留减半。","tags":["诱饵","控制"],"stack_description":"间隔随层数缩短，最短8秒。","mechanics":{"decoy_interval":14.0,"decoy_duration":3.0,"decoy_targets":4}},
		"T21":{"name":"纸箱喵炮","summary":"护盾实际吸收累计18点，发射90基础伤害的喵炮；冷却6秒，最多储存一发。","tags":["护盾","独立攻击"],"stack_description":"90像素内最多4目标；伤害随层数^0.45与大本营成长，冷却中可储一发；新增护盾、格挡与失血不蓄能。","mechanics":{"cannon_threshold":18.0,"cannon_cooldown":6.0,"cannon_damage":90.0,"cannon_radius":90.0,"cannon_targets":4}},
		"T22":{"name":"回声录音机","summary":"小铃强化队友后，该猫下一次主攻击追加22%伤害回声；每猫冷却4秒。","tags":["小铃","回声"],"stack_description":"单发回声不携带鱼干或固有效果；小铃自我强化不触发；重复提高回声伤害，最高45%。","mechanics":{"support_echo_ratio":.22,"support_echo_cooldown":4.0}}}

static func effects(stacks: Dictionary) -> Dictionary:
	var result: Dictionary = {"attack_bonus":0.0,"speed_bonus":0.0,"projectile_bonus":0,"projectile_ratio":1.0,"repeat_every":0,"repeat_ratio":0.0,"knockback":0.0,"bounce_extra":0,"bounce_ratio":0.0,"explosion_ratio":0.0,"explosion_radius":0.0,"chain_extra":0,"chain_ratio":0.0,"slow_pct":0.0,"slow_duration":0.0,"freeze_every":0,"freeze_duration":0.0,"air_bonus":0.0,"air_homing":false,"mark_pct":0.0,"bell_bonus":0.0,"cleanse_interval":0.0,"heal_interval":0.0,"heal_amount":0.0,"meteor_interval":0.0,"meteor_damage":0.0,"meteor_radius":0.0,"base_shield_max":0.0,"base_shield_interval":0.0,"base_shield_amount":0.0,"base_damage_taken":1.0,"laser_interval":0.0,"laser_damage":0.0,"laser_targets":0,"revive_charges":0,"revive_ratio":0.0,"bleed_dps":0.0,"bleed_duration":0.0,"blackhole_interval":0.0,"blackhole_radius":0.0,"blackhole_pull":0.0,"blackhole_targets":0,"decoy_interval":0.0,"decoy_duration":0.0,"decoy_targets":0,"cannon_threshold":0.0,"cannon_cooldown":0.0,"cannon_damage":0.0,"cannon_radius":0.0,"cannon_targets":0,"support_echo_ratio":0.0,"support_echo_cooldown":0.0}
	for id: String in stacks:
		var count: int = maxi(0,int(stacks[id]))
		if count==0: continue
		var power: float = pow(float(count),.45)
		match id:
			"T01":
				result.repeat_every = maxi(2,5-floori((count-1)/2.0))
				result.repeat_ratio = minf(.85,.45*power)
			"T02": result.knockback = minf(75.0,24.0*power)
			"T03":
				result.bounce_extra = mini(3,1+floori((count-1)/3.0))
				result.bounce_ratio = minf(.85,.55+.015*(count-1))
			"T04":
				result.explosion_ratio = .28*power
				result.explosion_radius = minf(125.0,75.0+10.0*(power-1.0))
			"T05":
				result.chain_extra = mini(3,1+floori((count-1)/3.0))
				result.chain_ratio = minf(.65,.22*power)
			"T06":
				result.speed_bonus += .08*power
				result.cleanse_interval = maxf(4.0,12.0/power)
			"T07":
				result.freeze_every = maxi(3,6-floori((count-1)/2.0))
				result.freeze_duration = minf(1.6,.45*power)
			"T08":
				result.air_bonus = .35*power
				result.air_homing = true
			"T09":
				result.slow_pct = minf(.50,.18*power)
				result.slow_duration = 1.4
			"T10":
				result.projectile_bonus = mini(3,1+floori((count-1)/3.0))
				result.projectile_ratio = .85
				result.speed_bonus += minf(.12,.02*(count-1))
			"T11":
				result.attack_bonus += .04*power
				result.heal_interval = 12.0
				result.heal_amount = 6.0*power
			"T12":
				result.speed_bonus += .06*power
				result.bell_bonus = .15*power
			"T13":
				result.meteor_interval = maxf(5.0,9.0/power)
				result.meteor_damage = 110.0*power
				result.meteor_radius = 100.0
			"T14":
				result.base_shield_max = 60.0*power
				result.base_shield_interval = 8.0
				result.base_shield_amount = 12.0*power
			"T15":
				result.attack_bonus += .25*power
				result.base_damage_taken = 1.0+.10*power
			"T16":
				result.laser_interval = 7.0
				result.laser_damage = 65.0*power
				result.laser_targets = 8
			"T17":
				result.revive_charges = count
				result.revive_ratio = .30
			"T18":
				result.bleed_dps = 8.0*power
				result.bleed_duration = 2.0
			"T19":
				result.blackhole_interval = maxf(8.0,13.0/power)
				result.blackhole_radius = 180.0
				result.blackhole_pull = 90.0
				result.blackhole_targets = 6
			"T20":
				result.decoy_interval = maxf(8.0,14.0/power)
				result.decoy_duration = 3.0
				result.decoy_targets = 4
			"T21":
				result.cannon_threshold = 18.0
				result.cannon_cooldown = 6.0
				result.cannon_damage = 90.0*power
				result.cannon_radius = 90.0
				result.cannon_targets = 4
			"T22":
				result.support_echo_ratio = minf(.45,.22*power)
				result.support_echo_cooldown = 4.0
	return result

static func is_capped(id: String,count: int) -> bool:
	if count<=0 or not all().has(id): return false
	# These are finite effects, not an inventory limit. Check every independent
	# component so an interval plateau cannot hide a later staircase upgrade.
	var effect: Dictionary=effects({id:count})
	match id:
		"T01": return int(effect.repeat_every)<=2 and float(effect.repeat_ratio)>=.85
		"T02": return float(effect.knockback)>=75.0
		"T03": return int(effect.bounce_extra)>=3 and float(effect.bounce_ratio)>=.85
		"T05": return int(effect.chain_extra)>=3 and float(effect.chain_ratio)>=.65
		"T07": return int(effect.freeze_every)<=3 and float(effect.freeze_duration)>=1.6
		"T09": return float(effect.slow_pct)>=.50
		"T10": return int(effect.projectile_bonus)>=3 and float(effect.speed_bonus)>=.12
		"T19": return float(effect.blackhole_interval)<=8.0
		"T20": return float(effect.decoy_interval)<=8.0
		"T22": return float(effect.support_echo_ratio)>=.45
	return false
