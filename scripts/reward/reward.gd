extends Control
## 報酬画面 - 安定化後のカード選択
## data/game_config.json の reward_count で報酬数を制御

const CARD_DATABASE = preload("res://data/card_database.gd")
const CardScene: PackedScene = preload("res://scenes/card_base.tscn")

@onready var choices_container: VBoxContainer = $VBox/Choices
@onready var skip_button: Button = $VBox/SkipButton
@onready var next_floor_button: Button = $VBox/NextFloorButton

var selected_card_data: Dictionary = {}

func _ready() -> void:
	skip_button.pressed.connect(_on_skip)
	next_floor_button.pressed.connect(_on_next)
	next_floor_button.disabled = true
	
	var settings_btn = get_node_or_null("UICanvas/SettingsButton")
	if settings_btn:
		settings_btn.pressed.connect(Settings.open_settings)
	
	# 設定から報酬数を取得
	var reward_count = GameState.get_config().get("reward_count", 3)
	var choices = CARD_DATABASE.get_random_cards(reward_count)
	for card_data in choices:
		var card = CardScene.instantiate()
		card.custom_minimum_size = Vector2(140, 150)
		card.set_card_data(card_data)
		card.clicked.connect(_on_card_clicked.bind(card, card_data))
		choices_container.add_child(card)

func _on_card_clicked(card_node: Control, card_data: Dictionary) -> void:
	selected_card_data = card_data
	next_floor_button.disabled = false
	for child in choices_container.get_children():
		child.modulate = Color(0.5, 0.5, 0.5, 1.0)
	card_node.modulate = Color.WHITE

func _on_skip() -> void:
	selected_card_data = {}
	next_floor_button.disabled = false
	for child in choices_container.get_children():
		child.modulate = Color(0.5, 0.5, 0.5, 1.0)

func _on_next() -> void:
	# 選択したカードがあればデッキに追加
	if not selected_card_data.is_empty():
		GameState.player_deck.append(selected_card_data.duplicate())
	if GameState.advance_floor():
		get_tree().change_scene_to_file("res://scenes/battle.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/clear_result.tscn")
