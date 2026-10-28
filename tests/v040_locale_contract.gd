extends SceneTree
const Locale=preload("res://scripts/game_locale.gd")
var checks: int=0
var failures: Array[String]=[]
func _initialize() -> void:
 call_deferred("_run")
func check(value: bool, note: String) -> void:
 checks+=1
 if not value: failures.append(note); printerr("FAIL: "+note)
func _run() -> void:
 Locale.set_language("ja",false)
 check(Locale.text("今日鱼摊")=="今日の魚屋","Japanese source message")
 check(TranslationServer.translate("今日鱼摊")=="今日の魚屋","Godot translation resource")
 check(Locale.text("攻击 22.0   攻速 1.05/秒")=="攻撃 22.0   速度 1.05/秒","formatted numeric labels")
 check(Locale.text("买下焦香小鱼干 · 自动合成2次")=="こんがり干し魚を購入 · 自動合成2回","buy merged fish")
 check(Locale.text("奶盖 Lv.3")=="ミルク Lv.3","nested name template")
 check(Locale.text("剑尾小鱼干 · 实际2 → 生效3")=="ソードテールの干し魚 · 魚2 → 効果3","empty optional formatted suffix")
 check(Locale.text("3级 · 分裂2发，每发80%\n5级 · 四发齐射 + 回旋")=="Lv.3 · 2発に分裂、各80%\nLv.5 · 4発斉射 + 旋回","multiline growth")
 check(Locale.text("HP 100 / 300")=="HP 100 / 300","numeric ASCII untouched")
 check(Locale.text("res://scripts/main.gd")=="res://scripts/main.gd","paths untouched")
 check(Locale.body_font().has_char(0x3042) and Locale.body_font().has_char(0x30CD),"Japanese font kana coverage")
 var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/fish.json"))
 for key: String in data:
  for field: String in ["description","mechanic_description","growth_description"]:
   if not data[key].has(field): continue
   var translated: String=Locale.text(str(data[key][field]))
   for original: String in ["攻击","攻速","级解锁","连锁","护盾","发，","灼烧","伤害","墨印使","主弹追踪"]:
    check(not translated.contains(original),"fish translation "+key+" "+field+": "+translated)
 Locale.set_language("zh_CN",false)
 check(Locale.text("今日鱼摊")=="今日鱼摊","Chinese original restored")
 check(TranslationServer.translate("今日鱼摊")=="今日鱼摊","Godot Chinese original restored")
 Locale.set_language("ja",false)
 print(JSON.stringify({"checks":checks,"failures":failures.size(),"messages":Locale._messages.size()}))
 quit(0 if failures.is_empty() else 1)
