extends CanvasLayer
## 設定画面UI（オーバーレイ）

@onready var bgm_slider: HSlider = $Overlay/VBox/BgmRow/Slider
@onready var bgm_value: Label = $Overlay/VBox/BgmRow/Value
@onready var font_slider: HSlider = $Overlay/VBox/FontRow/Slider
@onready var font_value: Label = $Overlay/VBox/FontRow/Value
@onready var back_btn: Button = $Overlay/VBox/BackButton

func _ready() -> void:
	bgm_slider.value = Settings.bgm_volume
	font_slider.value = Settings.font_scale
	_update_labels()

	bgm_slider.value_changed.connect(_on_bgm_changed)
	font_slider.value_changed.connect(_on_font_changed)
	back_btn.pressed.connect(_on_back)

func _on_bgm_changed(value: float) -> void:
	Settings.set_bgm_volume(value)
	_update_labels()

func _on_font_changed(value: float) -> void:
	Settings.set_font_scale(value)
	_update_labels()

func _update_labels() -> void:
	bgm_value.text = str(int(Settings.bgm_volume * 100)) + "%"
	font_value.text = str(int(Settings.font_scale * 100)) + "%"

func _on_back() -> void:
	Settings.close_settings()
