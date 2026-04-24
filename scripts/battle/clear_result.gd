extends Control
## クリアリザルト画面 - 全フロアクリア後の統計表示

@onready var stats_label: Label = $VBox/StatsLabel
@onready var title_button: Button = $VBox/TitleButton

func _ready() -> void:
	title_button.pressed.connect(_on_title_pressed)
	
	var settings_btn = get_node_or_null("UICanvas/SettingsButton")
	if settings_btn:
		settings_btn.pressed.connect(Settings.open_settings)
	
	_update_stats()

func _update_stats() -> void:
	var stats_text = "戦闘統計\n"
	stats_text += "バトル数: %d\n" % GameState.total_battles
	stats_text += "使用カード数: %d\n" % GameState.total_cards_played
	stats_label.text = stats_text

func _on_title_pressed() -> void:
	GameState.reset_run()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
