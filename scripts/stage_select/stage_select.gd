extends Control

@onready var stage_name_label: Label = $VBox/StageName
@onready var start_button: Button = $VBox/StartButton

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	
	var back_btn = $VBox/BackButton
	back_btn.pressed.connect(_on_back_pressed)
	
	var settings_btn = get_node_or_null("UICanvas/SettingsButton")
	if settings_btn:
		settings_btn.pressed.connect(Settings.open_settings)
	
	_update_floor_display()

func _update_floor_display() -> void:
	var floor_config = GameState.get_floor_config(GameState.current_floor - 1)
	var floor_name = floor_config.get("name", "未知の位相")
	stage_name_label.text = "位相 %d - %s" % [GameState.current_floor, floor_name]

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(GameState.get_scene_path("battle", "res://scenes/battle.tscn"))

func _on_back_pressed() -> void:
	GameState.reset_run()
	get_tree().change_scene_to_file(GameState.get_scene_path("main_menu", "res://scenes/main_menu.tscn"))
