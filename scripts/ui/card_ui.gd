extends Control
## CardUI - カード1枚の表示と操作
## res://scenes/card_base.tscn にアタッチして使用
## 幾何学スプライト対応、JSONデータ駆動型

signal clicked

var card_data: Dictionary = {}
var base_pos_y: float = 0.0

func _ready() -> void:
	await get_tree().process_frame
	base_pos_y = position.y
	# 拡大の中心をカード中央にする
	pivot_offset = size * 0.5

	var btn = get_node_or_null("ClickLayer")
	if btn:
		btn.mouse_entered.connect(_on_hover)
		btn.mouse_exited.connect(_on_unhover)

	if card_data:
		_update_visuals()

func set_card_data(data: Dictionary) -> void:
	card_data = data
	if is_node_ready():
		_update_visuals()

func _update_visuals() -> void:
	var name_label = get_node_or_null("Margin/VBox/CardName")
	var desc_label = get_node_or_null("Margin/VBox/CardDesc")
	var type_label = get_node_or_null("Margin/VBox/CardType")
	var art_rect = get_node_or_null("Margin/VBox/ArtRect")

	if name_label: name_label.text = card_data.get("name", "Card")
	if desc_label: desc_label.text = card_data.get("description", "")
	
	# カードタイプの表示
	if type_label:
		var card_type = card_data.get("type", "")
		var type_info = GameState.get_card_types().get(card_type, {})
		type_label.text = type_info.get("label", card_type)
	
	# 幾何学スプライトの設定
	if art_rect:
		if art_rect.has_method("configure"):
			art_rect.configure(card_data)
		elif card_data.has("color"):
			# フォールバック: 単色表示
			art_rect.color = CardDatabase.parse_color(card_data["color"])

	# Setup click state
	var click_btn = get_node_or_null("ClickLayer")
	if click_btn:
		click_btn.disabled = false
		if not click_btn.pressed.is_connected(_on_card_clicked):
			click_btn.pressed.connect(_on_card_clicked)

func _on_card_clicked() -> void:
	clicked.emit()

func _on_hover() -> void:
	var tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	tw.tween_property(self, "position:y", base_pos_y - 24.0, 0.2)
	tw.parallel().tween_property(self, "scale", Vector2(1.08, 1.08), 0.2)

func _on_unhover() -> void:
	var tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	tw.tween_property(self, "position:y", base_pos_y, 0.2)
	tw.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)
