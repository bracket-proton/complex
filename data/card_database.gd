class_name CardDatabase
extends Resource

## カードデータテンプレート
## data/card_set.json から動的に読み込み
## テーマ変更時はJSONファイルのみ置き換えればよい

const CARD_SET_PATH := "res://data/card_set.json"

static var _card_cache: Array[Dictionary] = []
static var _starter_deck_ids: Array[String] = []
static var _loaded := false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	
	var file := FileAccess.open(CARD_SET_PATH, FileAccess.READ)
	if file == null:
		push_error("CardDatabase: %s の読み込み失敗" % CARD_SET_PATH)
		return
	
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	
	if err != OK:
		push_error("CardDatabase: JSON解析エラー - %s" % json.get_error_message())
		return
	
	var data: Dictionary = json.data
	if data.has("cards"):
		_card_cache.clear()
		for item in data["cards"]:
			if item is Dictionary:
				_card_cache.append(item)
	if data.has("starter_deck"):
		_starter_deck_ids.clear()
		for item in data["starter_deck"]:
			_starter_deck_ids.append(str(item))

static func get_card(card_id: String) -> Dictionary:
	_ensure_loaded()
	for card in _card_cache:
		if card.get("id", "") == card_id:
			return card.duplicate()
	return {}

static func create_starter_deck() -> Array[Dictionary]:
	_ensure_loaded()
	var deck: Array[Dictionary] = []
	for card_id in _starter_deck_ids:
		var card = get_card(card_id)
		if not card.is_empty():
			deck.append(card)
	return deck

static func get_all_cards() -> Array[Dictionary]:
	_ensure_loaded()
	return _card_cache.duplicate(true)

static func get_random_cards(count: int) -> Array[Dictionary]:
	var all := get_all_cards()
	# Shuffle
	for i in range(all.size() - 1, 0, -1):
		var j := randi() % (i + 1)
		var temp = all[i]
		all[i] = all[j]
		all[j] = temp
	
	var result: Array[Dictionary] = []
	for i in mini(count, all.size()):
		result.append(all[i])
	return result

## Color変換ヘルパー: JSON [r,g,b] → Color
static func parse_color(arr: Variant) -> Color:
	if arr is Array and arr.size() >= 3:
		return Color(float(arr[0]), float(arr[1]), float(arr[2]))
	return Color.WHITE
