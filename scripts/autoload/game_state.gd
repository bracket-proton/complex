extends Node
## ゲーム全体の状態管理
## Autoloadとして登録: Project Settings > Autoload > GameState
## data/game_config.json から設定を読み込み

const CONFIG_PATH := "res://data/game_config.json"

var current_floor: int = 1
var player_deck: Array[Dictionary] = []
var max_floor: int = 2

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
	if _config.has("floors"):
		max_floor = _config["floors"].size()

func get_config() -> Dictionary:
	_load_config()
	return _config

func get_terminology(key: String, fallback: String = "") -> String:
	var term = get_config().get("terminology", {})
	return term.get(key, fallback)

func get_floor_config(floor_idx: int) -> Dictionary:
	var floors = get_config().get("floors", [])
	if floor_idx >= 0 and floor_idx < floors.size():
		return floors[floor_idx]
	return {}

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
	current_floor = 1
	player_deck = []
	# 戦闘統計リセット
	total_battles = 0
	total_cards_played = 0
	entropy_history = []

func advance_floor() -> bool:
	if current_floor < max_floor:
		current_floor += 1
		return true
	return false
