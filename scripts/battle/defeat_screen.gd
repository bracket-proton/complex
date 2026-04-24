extends Control
## 敗北確認画面
## 熱的平衡到達 → 非平衡化（再挑戦）or 初期条件復元（リセット）

signal continue_pressed
signal reset_pressed

@onready var continue_btn: Button = $Panel/VBox/ContinueButton
@onready var reset_btn: Button = $Panel/VBox/ResetButton

func _ready() -> void:
	continue_btn.pressed.connect(_on_continue)
	reset_btn.pressed.connect(_on_reset)
	
	var settings_btn = get_node_or_null("UICanvas/SettingsButton")
	if settings_btn:
		settings_btn.pressed.connect(Settings.open_settings)

func _on_continue() -> void:
	continue_pressed.emit()

func _on_reset() -> void:
	reset_pressed.emit()
