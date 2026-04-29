extends Node
## ユーザー設定の管理（BGM音量、文字サイズ）
## Autoloadとして登録。user://settings.cfg に永続化。

const SAVE_PATH := "user://settings.cfg"

var bgm_volume: float = 0.75
var font_scale: float = 1.0

func _ready() -> void:
	_load()
	get_tree().node_added.connect(_on_node_added)
	apply()

func _load() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)
	if err == OK:
		bgm_volume = cfg.get_value("audio", "bgm_volume", 0.75)
		font_scale = cfg.get_value("display", "font_scale", 1.0)

func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "bgm_volume", bgm_volume)
	cfg.set_value("display", "font_scale", font_scale)
	cfg.save(SAVE_PATH)

func apply() -> void:
	_apply_bgm()
	_apply_font_scale_to_node(get_tree().root)

func _apply_bgm() -> void:
	var bus_idx := AudioServer.get_bus_index("Music")
	if bus_idx == -1:
		bus_idx = 0
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(bgm_volume))

func _apply_font_scale_to_node(node: Node) -> void:
	if node is Label:
		_apply_to_label(node)
	for child in node.get_children():
		_apply_font_scale_to_node(child)

func _apply_to_label(label: Label) -> void:
	if not label.has_meta("original_font_size"):
		label.set_meta("original_font_size", label.get_theme_font_size("font_size"))
	var base: int = label.get_meta("original_font_size")
	label.add_theme_font_size_override("font_size", int(base * font_scale))

func _on_node_added(node: Node) -> void:
	if node is Label:
		_apply_to_label(node)

func set_bgm_volume(value: float) -> void:
	bgm_volume = clampf(value, 0.0, 1.0)
	_apply_bgm()
	save()

func set_font_scale(value: float) -> void:
	font_scale = clampf(value, 0.5, 2.0)
	_apply_font_scale_to_node(get_tree().root)
	save()

# ---------------------------------------------------------------------------
# 設定画面オーバーレイ管理（どのシーンからでも呼び出し可能）
# ---------------------------------------------------------------------------
var _overlay: Node = null

func open_settings() -> void:
	if _overlay != null:
		return
	_overlay = load("res://scenes/settings.tscn").instantiate()
	get_tree().root.add_child(_overlay)

func close_settings() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
