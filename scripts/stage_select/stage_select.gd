extends Control

@onready var regime_list_container: VBoxContainer = $VBox/RegimeListContainer
@onready var regime_info_label: Label = $VBox/RegimeInfo
@onready var floor_info_label: Label = $VBox/FloorInfo
@onready var start_button: Button = $VBox/StartButton

var _regime_buttons: Dictionary = {}  # idx -> Button
var _selected_regime_idx: int = 0

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	
	var back_btn = $VBox/BackButton
	back_btn.pressed.connect(_on_back_pressed)
	
	var settings_btn = get_node_or_null("UICanvas/SettingsButton")
	if settings_btn:
		settings_btn.pressed.connect(Settings.open_settings)
	
	_build_regime_buttons()
	if _regime_buttons.size() > 0:
		_select_regime(0)

func _build_regime_buttons() -> void:
	var regimes = GameState.get_regimes()
	for i in regimes.size():
		var regime = regimes[i]
		var unlocked = GameState.is_regime_unlocked(i)
		var completed = GameState.is_regime_completed(i)
		
		var btn := Button.new()
		var status = ""
		if completed:
			status = " ✓"
		elif not unlocked:
			status = " [ロック]"
		btn.text = "レジーム %d: %s%s" % [i + 1, regime.get("name", "???"), status]
		btn.custom_minimum_size = Vector2(340, 44)
		btn.disabled = not unlocked
		btn.pressed.connect(_on_regime_selected.bind(i))
		regime_list_container.add_child(btn)
		_regime_buttons[i] = btn

func _on_regime_selected(idx: int) -> void:
	_select_regime(idx)

func _select_regime(idx: int) -> void:
	_selected_regime_idx = idx
	
	# ボタンのハイライト
	for i in _regime_buttons:
		var btn = _regime_buttons[i]
		if i == idx:
			btn.modulate = Color(0.6, 0.9, 1.0)
		elif GameState.is_regime_completed(i):
			btn.modulate = Color(0.5, 0.8, 0.5)  # クリア済み: 緑
		else:
			btn.modulate = Color.WHITE
	
	var regimes = GameState.get_regimes()
	if idx >= regimes.size():
		return
	
	var regime = regimes[idx]
	regime_info_label.text = regime.get("description", "")
	
	# 位相情報
	var floors = regime.get("floors", [])
	var floor_names: Array[String] = []
	for fl in floors:
		floor_names.append(fl.get("name", "???"))
	floor_info_label.text = "位相: %s" % ", ".join(floor_names)
	
	start_button.disabled = false

func _on_start_pressed() -> void:
	GameState.current_regime = _selected_regime_idx
	GameState.current_floor = 0
	get_tree().change_scene_to_file(GameState.get_scene_path("battle", "res://scenes/battle.tscn"))

func _on_back_pressed() -> void:
	GameState.reset_run()
	get_tree().change_scene_to_file(GameState.get_scene_path("main_menu", "res://scenes/main_menu.tscn"))