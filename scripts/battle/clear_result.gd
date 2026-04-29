extends Control
## クリアリザルト画面 - レジームクリア後の統計表示

@onready var title_label: Label = $VBox/TitleLabel
@onready var stats_label: Label = $VBox/StatsLabel
@onready var ok_button: Button = $VBox/OKButton

func _ready() -> void:
	ok_button.pressed.connect(_on_ok_pressed)
	
	var settings_btn = get_node_or_null("UICanvas/SettingsButton")
	if settings_btn:
		settings_btn.pressed.connect(Settings.open_settings)
	
	_update_display()

func _update_display() -> void:
	var regime_name = GameState.get_current_regime_config().get("name", "???")
	title_label.text = "%s - 安定化達成" % regime_name
	
	var stats_text = "戦闘数: %d\n" % GameState.total_battles
	stats_text += "使用カード数: %d\n" % GameState.total_cards_played
	stats_label.text = stats_text

func _on_ok_pressed() -> void:
	if GameState.are_all_regimes_completed():
		GameState.reset_run()
		get_tree().change_scene_to_file(GameState.get_scene_path("main_menu", "res://scenes/main_menu.tscn"))
	else:
		get_tree().change_scene_to_file(GameState.get_scene_path("stage_select", "res://scenes/stage_select.tscn"))