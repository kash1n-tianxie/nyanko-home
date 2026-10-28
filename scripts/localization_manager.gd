extends Node
## Language preference is independent of the campaign save.
signal language_changed(language: String)
const Locale = preload("res://scripts/game_locale.gd")
var translation: Translation
func _enter_tree() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 Locale.initialize()
 translation=load("res://scripts/locale_translation.gd").new()
 translation.locale="ja"
 TranslationServer.add_translation(translation)
 TranslationServer.set_locale(Locale.current_language())
 DisplayServer.window_set_title(Locale.text(str(ProjectSettings.get_setting("application/config/name","猫咪和它的小鱼干"))))
func notify_changed(language: String) -> void:
 DisplayServer.window_set_title(Locale.text(str(ProjectSettings.get_setting("application/config/name","猫咪和它的小鱼干"))))
 language_changed.emit(language)
 _redraw(get_tree().root)
func _redraw(node: Node) -> void:
 if node is CanvasItem: (node as CanvasItem).queue_redraw()
 for child: Node in node.get_children(): _redraw(child)
func _exit_tree() -> void:
 # Registered scripted translations must leave the server before GDScript teardown.
 # Otherwise Godot 4.7 can invoke this resource after its script state is released.
 if translation!=null:
  TranslationServer.remove_translation(translation)
  translation=null
