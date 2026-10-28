extends RefCounted
## Exact source messages and anchored format templates, never substring replacement.
## Only rendered text is localized; identifiers, stats and saved data remain unchanged.
const CONFIG_PATH: String="user://language.cfg"
const JAPANESE: String="ja"
const CHINESE: String="zh_CN"
static var BODY: FontVariation=preload("res://fonts/japanese-v040/ui_body.tres")
static var TITLE: FontVariation=preload("res://fonts/japanese-v040/ui_title.tres")
static var JA_FONT: Font=preload("res://fonts/japanese-v040/KiwiMaru.ttf")
const ZH_BODY: Font=preload("res://fonts/parchment-v027/LXGWWenKai-Regular.ttf")
const ZH_TITLE: Font=preload("res://fonts/parchment-v027/ZCOOLKuaiLe-Regular.ttf")
static var preference_path: String=CONFIG_PATH
static var _language: String=JAPANESE
static var _loaded: bool=false
static var _messages: Dictionary={}
static var _templates: Array=[]
static var _template_index: Dictionary={}
static var _cache: Dictionary={}
static var _busy: Dictionary={}

static func initialize() -> void:
 _language=JAPANESE
 var config: ConfigFile=ConfigFile.new()
 if config.load(preference_path)==OK:
  _language=CHINESE if str(config.get_value("language","locale",JAPANESE))==CHINESE else JAPANESE
 _load_catalog()
 _fonts()

static func current_language() -> String:
 return _language

static func set_language(language: String, persist: bool=true) -> void:
 _language=CHINESE if language in [CHINESE,"zh","zh-CN"] else JAPANESE
 _cache.clear()
 _fonts()
 if persist:
  var config: ConfigFile=ConfigFile.new()
  config.set_value("language","locale",_language)
  config.save(preference_path)
 TranslationServer.set_locale(_language)
 var tree: SceneTree=Engine.get_main_loop() as SceneTree
 if tree!=null:
  var manager: Node=tree.root.get_node_or_null("GameLocalization")
  if manager!=null: manager.call("notify_changed",_language)

static func body_font() -> Font:
 return BODY

static func title_font() -> Font:
 return TITLE

static func _fonts() -> void:
 BODY.base_font=JA_FONT if _language==JAPANESE else ZH_BODY
 TITLE.base_font=JA_FONT if _language==JAPANESE else ZH_TITLE
 # Retain handwritten Chinese glyphs for character names the Japanese face lacks.
 JA_FONT.fallbacks=[ZH_BODY]

static func _load_catalog() -> void:
 if _loaded: return
 _loaded=true
 var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://localization/ja.json"))
 if parsed is Dictionary: _messages=parsed
 var format_token: RegEx=RegEx.new()
 format_token.compile("%(?:[+ 0-]*[0-9]*(?:\\.[0-9]+)?)[sdf]|\\{[0-9]+\\}")
 for source: String in _messages:
  var matches: Array[RegExMatch]=format_token.search_all(source)
  if matches.is_empty() or source.contains("%s%s"): continue
  var expression: String="^"
  var cursor: int=0
  var output: String=str(_messages[source])
  var tokens: Array=[]
  for index: int in range(matches.size()):
   var found: RegExMatch=matches[index]
   expression+=_escape(source.substr(cursor,found.get_start()-cursor))
   var token: String=found.get_string()
   var is_text: bool=token.ends_with("s")
   expression+="([\\s\\S]*?)" if is_text else "([+−-]?[0-9]+(?:\\.[0-9]+)?)"
   tokens.append({"source":token,"text":is_text})
   cursor=found.get_end()
  expression+=_escape(source.substr(cursor))+"$"
  var regex: RegEx=RegEx.new()
  if regex.compile(expression)==OK: _templates.append({"regex":regex,"target":output,"tokens":tokens,"source":source,"bucket":source.substr(0,1) if matches[0].get_start()>0 else ""})
 # Longer fixed phrases take precedence over generic short messages.
 _templates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return str(a.source).length()>str(b.source).length())
 for entry: Dictionary in _templates:
  if not _template_index.has(entry.bucket): _template_index[entry.bucket]=[]
  _template_index[entry.bucket].append(entry)

static func _escape(value: String) -> String:
 var output: String=""
 for character: String in value:
  output+=("\\" if character in ["\\",".","^","$","|","?","*","+","(",")","[","]","{","}"] else "")+character
 return output.replace("%%","%")

static func text(source: String) -> String:
 if _language!=JAPANESE or source.is_empty(): return source
 _load_catalog()
 if _messages.has(source): return str(_messages[source])
 if _cache.has(source): return str(_cache[source])
 # Damage values, clocks, counters and technical IDs need no regex work.
 if source.to_utf8_buffer().size()==source.length(): return source
 if _busy.has(source): return source
 _busy[source]=true
 var result: String=_resolve(source)
 _busy.erase(source)
 if _cache.size()>5000: _cache.clear()
 _cache[source]=result
 return result

static func _resolve(source: String) -> String:
 var trimmed: String=source.strip_edges()
 if not trimmed.is_empty() and trimmed!=source:
  var offset: int=source.find(trimmed)
  return source.substr(0,offset)+text(trimmed)+source.substr(offset+trimmed.length())
 var candidates: Array=_template_index.get(source.substr(0,1),[]).duplicate()
 candidates.append_array(_template_index.get("",[]))
 for entry: Dictionary in candidates:
  var matched: RegExMatch=(entry.regex as RegEx).search(source)
  if matched==null: continue
  var result: String=str(entry.target)
  var cursor: int=0
  for index: int in range(entry.tokens.size()):
   var token: String=str(entry.tokens[index].source)
   var value: String=matched.get_string(index+1)
   if bool(entry.tokens[index].text): value=text(value)
   # Translation preserves placeholder order. Replace exactly one occurrence.
   var at: int=result.find(token,cursor)
   if at>=0:
    result=result.substr(0,at)+value+result.substr(at+token.length())
    cursor=at+value.length()
  return result.replace("%%","%")
 # Composite UI uses explicit separators; translate complete clauses only.
 for separator: String in ["\n"," · "," ·","：","；"]:
  if source.contains(separator):
   var parts: PackedStringArray=source.split(separator)
   for index: int in range(parts.size()): parts[index]=text(parts[index])
   return separator.join(parts)
 return source
