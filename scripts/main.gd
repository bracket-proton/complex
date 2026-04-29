extends Control

func _ready() -> void:
	$StartButton.pressed.connect(_on_start_button_pressed)
	var settings_btn = get_node_or_null("UICanvas/SettingsButton")
	if settings_btn:
		settings_btn.pressed.connect(Settings.open_settings)

func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file(GameState.get_scene_path("stage_select", "res://scenes/stage_select.tscn"))
