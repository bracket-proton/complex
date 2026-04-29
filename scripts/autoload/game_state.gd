extends Node
## ゲーム全体の状態管理
## Autoloadとして登録: Project Settings > Autoload > GameState
## data/game_config.json から設定を読み込み

const CONFIG_PATH := "res://data/game_config.json"

var current_regime: int = 0       # 選択されたレジームのインデックス（0-based）
var current_floor: int = 0        # 現在のレジーム内フロアインデックス（0-based）
var player_deck: Array[Dictionary] = []
var max_regime: int = 2           # レジーム数

var completed_regimes: Array[int] = []   # クリア済みレジームインデックス

# 戦闘統計
var total_battles: int = 0
var total_cards_played: int = 0
var entropy_history: Array[int] = []  # 各バトル終了時の摂動蓄積

# 設定キャッシュ
var _config: Dictionary = {}
var _loaded := false

func _ready() -> void:
	_load_config()
	reset_run()

func _load_config() -> void:
	if _loaded:
		return
	
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_error("GameState: %s の読み込み失敗" % CONFIG_PATH)
		return
	
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	
	if err != OK:
		push_error("GameState: JSON解析エラー - %s" % json.get_error_message())
		return
	
	_config = json.data
	_loaded = true
	if _config.has("regimes"):
		max_regime = _config["regimes"].size()

func get_config() -> Dictionary:
	_load_config()
	return _config

func get_terminology(key: String, fallback: String = "") -> String:
	var term = get_config().get("terminology", {})
	return term.get(key, fallback)

func get_regimes() -> Array:
	return get_config().get("regimes", [])

func get_current_regime_config() -> Dictionary:
	var regimes = get_regimes()
	if current_regime >= 0 and current_regime < regimes.size():
		return regimes[current_regime]
	return {}

func get_current_regime_floors() -> Array:
	var regime = get_current_regime_config()
	return regime.get("floors", [])

func get_floor_config() -> Dictionary:
	var floors = get_current_regime_floors()
	if current_floor >= 0 and current_floor < floors.size():
		return floors[current_floor]
	return {}

func get_max_floor_in_regime() -> int:
	return get_current_regime_floors().size()

func get_card_types() -> Dictionary:
	return get_config().get("card_types", {})

func get_player_defaults() -> Dictionary:
	return get_config().get("player_defaults", {
		"max_structure": 30,
		"start_energy": 1,
		"cards_per_turn": 3
	})

func get_scene_path(key: String, fallback: String = "") -> String:
	return get_config().get("scene_flow", {}).get(key, fallback)

func is_debug_mode() -> bool:
	return get_config().get("debug_mode", false)

func reset_run() -> void:
	current_regime = 0
	current_floor = 0
	player_deck = []
	total_battles = 0
	total_cards_played = 0
	entropy_history = []

func complete_current_regime() -> void:
	if not completed_regimes.has(current_regime):
		completed_regimes.append(current_regime)

func is_regime_completed(regime_idx: int) -> bool:
	return completed_regimes.has(regime_idx)

func is_regime_unlocked(regime_idx: int) -> bool:
	# レジーム0,1 は常にアンロック。レジーム2は0と1の両方クリアでアンロック
	if regime_idx <= 1:
		return true
	if regime_idx == 2:
		return completed_regimes.has(0) and completed_regimes.has(1)
	return completed_regimes.has(regime_idx - 1)

func are_all_regimes_completed() -> bool:
	return completed_regimes.size() >= max_regime

func advance_floor() -> bool:
	if current_floor + 1 < get_max_floor_in_regime():
		current_floor += 1
		return true
	return false