extends Control
## BattleManager - デッキ管理・ターン進行・摂動源AIの制御
## 複雑系テーマ: 攻撃→摂動注入、防御→構造維持、スキル→触媒

const CardScene: PackedScene = preload("res://scenes/card_base.tscn")
const CARD_DATABASE = preload("res://data/card_database.gd")
const DefeatScreenScene: PackedScene =preload("res://scenes/defeat_screen.tscn")
const BGM_STREAM: AudioStream = preload("res://audio/music/_music_techno_t6.mp3")

@onready var hand_area: HBoxContainer = $HandArea
@onready var intent_label: Label = $EnemyArea/IntentLabel
@onready var entropy_label: Label = $EnemyArea/EntropyLabel
@onready var enemy_name_label: Label = $EnemyArea/EnemyNameLabel
@onready var entropy_bar_inner: ColorRect = $EnemyArea/EntropyBarInner
@onready var structure_label: Label = $PlayerStatus/StructureLabel
@onready var structure_bar_inner: ColorRect = $PlayerStatus/StructureBarInner
@onready var entropy_shield_label: Label = $PlayerStatus/EntropyShieldLabel
@onready var history_label: Label = $PlayerStatus/HistoryLabel
@onready var turn_label: Label = $PlayerStatus/TurnLabel
@onready var energy_label: Label = $PlayerStatus/EnergyLabel
@onready var end_turn_button: Button = $ControlBar/EndTurnButton
@onready var enemy_sprite: Control = $EnemyArea/EnemySprite
@onready var bgm_player: AudioStreamPlayer = $BGMPlayer
@onready var deck_btn: Button = $DeckBtn
@onready var draw_btn: Button = $DrawBtn
@onready var discard_btn: Button = $DiscardBtn

var player_structure: int = 30
var player_max_structure: int = 30
var entropy_shield: int = 0  # 負エントロピー（バリアに相当）
var system_entropy: int = 0  # 敵のエントロピー蓄積
var stability_threshold: int = 35  # 相転移閾値（勝利条件）
var energy: int = 1
var max_energy: int = 1
var current_turn: int = 0

var draw_pile: Array[Dictionary] = []  # 可能性空間
var hand: Array[Dictionary] = []       # 作用点
var discard_pile: Array[Dictionary] = []  # 履歴

var next_perturb_bonus: int = 0
var enemy_intent: Dictionary = {}
var floor_config: Dictionary = {}
var enemy_intent_index: int = 0
var enemy_intent_mode: String = "random"

func _ready() -> void:
	end_turn_button.pressed.connect(_on_end_turn)
	deck_btn.pressed.connect(_on_deck_button_pressed)
	draw_btn.pressed.connect(_on_draw_pile_button_pressed)
	discard_btn.pressed.connect(_on_discard_pile_button_pressed)
	
	var settings_btn = get_node_or_null("UICanvas/SettingsButton")
	if settings_btn:
		settings_btn.pressed.connect(Settings.open_settings)
	
	_start_battle()

func _start_battle() -> void:
	# 戦闘統計
	GameState.total_battles += 1
	
	# フロア設定の読み込み
	floor_config = GameState.get_floor_config(GameState.current_floor - 1)
	stability_threshold = floor_config.get("stability_threshold", 35)
	print("Debug: floor_config keys: ", floor_config.keys())
	# 敵意図選択モードの取得（randomまたはsequential）
	enemy_intent_mode = floor_config.get("enemy_intent_mode", "random")
	# sequentialモードではインデックスをリセット
	if enemy_intent_mode == "sequential":
		enemy_intent_index = 0
	print("Debug: Enemy intent mode = ", enemy_intent_mode)
	
	# 敵の名前を設定
	var enemy_name = floor_config.get("enemy_name", "摂動源")
	enemy_name_label.text = enemy_name
	
	# 敵スプライトの設定
	_configure_enemy_sprite()
	
	# プレイヤー初期値の読み込み
	var defaults = GameState.get_player_defaults()
	player_max_structure = defaults.get("max_structure", 30)
	max_energy = defaults.get("start_energy", 1)
	player_structure = player_max_structure
	energy = max_energy
	
	# プレイヤーデッキを使用（空なら初期デッキ）
	if GameState.player_deck.is_empty():
		draw_pile = CARD_DATABASE.create_starter_deck()
	else:
		draw_pile = GameState.player_deck.duplicate(true)
	_shuffle(draw_pile)
	
	# デバッグモード: 閾値1設定
	if GameState.is_debug_mode():
		stability_threshold = 1
	
	_start_player_turn()
	
	# BGM再生開始（フェードイン）
	_play_bgm_fade_in()

func _play_bgm_fade_in() -> void:
	# BGMをフェードイン再生
	bgm_player.stream = BGM_STREAM
	bgm_player.volume_db = -80.0
	bgm_player.play()
	
	var tween = create_tween()
	tween.tween_property(bgm_player, "volume_db", 0.0, 1.0)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)

func _stop_bgm_fade_out() -> void:
	# BGMをフェードアウト停止
	var tween = create_tween()
	tween.tween_property(bgm_player, "volume_db", -80.0, 0.5)
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(bgm_player.stop)

func _configure_enemy_sprite() -> void:
	if enemy_sprite and enemy_sprite.has_method("configure"):
		# 摂動源のスプライト設定
		var enemy_color_hex = floor_config.get("enemy_color", "#FFFFFF")
		var enemy_color_rgb = _hex_to_rgb(enemy_color_hex)
		var sprite_data = {
			"shape": "attractor",
			"color": enemy_color_rgb,
			"animation": "oscillate"
		}
		enemy_sprite.configure(sprite_data)

func _hex_to_rgb(hex: String) -> Array:
	# 16進数カラーコードをRGB配列に変換（例: "#F0F8FF" -> [0.941, 0.973, 1.0]）
	var color = Color.from_string(hex, Color.WHITE)
	return [color.r, color.g, color.b]

func _start_player_turn() -> void:
	current_turn += 1
	energy = max_energy
	entropy_shield = 0
	next_perturb_bonus = 0

	_determine_enemy_intent()
	var defaults = GameState.get_player_defaults()
	_draw_cards(defaults.get("cards_per_turn", 3))

	hand_area.mouse_filter = Control.MOUSE_FILTER_STOP
	end_turn_button.disabled = false
	_update_all_ui()

func _determine_enemy_intent() -> void:
	var intents = floor_config.get("enemy_intents", [])
	if intents.is_empty():
		# フォールバック
		enemy_intent = {"text": "微小摂動 (3エントロピー)", "type": "entropy", "value": 3}
	else:
		if enemy_intent_mode == "random":
			enemy_intent = intents[randi() % intents.size()]
		elif enemy_intent_mode == "sequential":
			enemy_intent = intents[enemy_intent_index]
			enemy_intent_index = (enemy_intent_index + 1) % intents.size()
		intent_label.text = enemy_intent.get("text", "???")

func _draw_cards(count: int) -> void:
	for i in count:
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			draw_pile = discard_pile.duplicate()
			discard_pile.clear()
			_shuffle(draw_pile)
		hand.append(draw_pile.pop_back())
	_rebuild_hand_ui()

func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = randi() % (i + 1)
		var temp = arr[i]
		arr[i] = arr[j]
		arr[j] = temp

func _rebuild_hand_ui() -> void:
	for child in hand_area.get_children():
		child.queue_free()
	
	var card_count := hand.size()
	if card_count == 0:
		return
	
	var card_height := 150
	var separation := 8
	var margin := 16
	
	var available_width := float(540 - margin * 2)
	var total_separation := float((card_count - 1) * separation)
	var card_width := int((available_width - total_separation) / float(card_count))
	card_width = mini(card_width, 130)
	
	for card_data in hand:
		var card = CardScene.instantiate()
		card.custom_minimum_size = Vector2(card_width, card_height)
		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card.set_card_data(card_data)
		card.clicked.connect(_on_card_clicked.bind(hand.find(card_data)))
		hand_area.add_child(card)

func _on_card_clicked(hand_idx: int) -> void:
	if hand.is_empty() or hand_idx >= hand.size():
		return
	var card_data = hand[hand_idx]

	if energy < card_data.get("cost", 1):
		return

	_apply_card_effect(card_data)
	
	# 戦闘統計
	GameState.total_cards_played += 1
	
	energy -= card_data.get("cost", 1)
	hand.remove_at(hand_idx)
	discard_pile.append(card_data)
	
	_rebuild_hand_ui()
	_update_all_ui()
	_check_win_condition()

func _apply_card_effect(card_data: Dictionary) -> void:
	var card_type = card_data.get("type", "")
	var value = card_data.get("value", 0)

	match card_type:
		"perturbation":
			# 摂動: エントロピー注入（敵にダメージ）
			value += next_perturb_bonus
			next_perturb_bonus = 0
			if card_data.has("multi_hit"):
				for i in card_data["multi_hit"]:
					system_entropy += value
			else:
				system_entropy += value
			if card_data.has("self_entropy"):
				_apply_entropy_to_player(card_data["self_entropy"])
		"structural":
			# 構造: 構造度回復（防御に相当）
			player_structure = mini(player_structure + value, player_max_structure)
		"catalyst":
			# 触媒: 増幅・変換効果
			var card_id = card_data.get("id", "")
			if card_id == "catalyst_2":
				# フィードバック: 次の摂動+3
				next_perturb_bonus += value
			elif card_id == "catalyst_1":
				# 分岐探索: ドロー
				_draw_cards(value)
			elif card_id == "structural_3":
				# 負のエントロピー（旧回復カード）
				player_structure = mini(player_structure + value, player_max_structure)

func _apply_entropy_to_player(entropy: int) -> void:
	if entropy_shield > 0:
		if entropy_shield >= entropy:
			entropy_shield -= entropy
			entropy = 0
		else:
			entropy -= entropy_shield
			entropy_shield = 0
	player_structure -= entropy

func _update_all_ui() -> void:
	# 用語を設定ファイルから取得
	var hp_term = GameState.get_terminology("player_hp", "構造度")
	var shield_term = GameState.get_terminology("shield", "負エントロピー")
	var entropy_term = GameState.get_terminology("enemy_damage_bar", "摂動蓄積")
	var draw_term = GameState.get_terminology("draw_pile", "可能性空間")
	var discard_term = GameState.get_terminology("discard_pile", "履歴")
	
	structure_label.text = "%s: %d / %d" % [hp_term, player_structure, player_max_structure]
	entropy_shield_label.text = "%s: %d" % [shield_term, entropy_shield]
	energy_label.text = "エネルギー: %d/%d" % [energy, max_energy]
	turn_label.text = "時間 %d" % current_turn
	history_label.text = "%s: %d | %s: %d" % [draw_term, draw_pile.size(), discard_term, discard_pile.size()]
	
	entropy_label.text = "%s: %d / %d" % [entropy_term, system_entropy, stability_threshold]
	var entropy_ratio = float(system_entropy) / float(stability_threshold)
	var entropy_target = 0.15 + (0.7 * minf(entropy_ratio, 1.0))
	
	# 構造度バーの更新
	var structure_ratio = float(player_structure) / float(player_max_structure)
	var structure_target = 0.02 + (0.96 * minf(structure_ratio, 1.0))
	
	# バーのアニメーション（イーズアウト）
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	
	tween.tween_property(entropy_bar_inner, "anchor_right", entropy_target, 0.3)
	tween.tween_property(structure_bar_inner, "anchor_right", structure_target, 0.3)

func _on_end_turn() -> void:
	hand_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	end_turn_button.disabled = true

	var tw = create_tween()
	tw.tween_property(end_turn_button, "modulate", Color(0.8, 0.8, 0.8, 1.0), 0.1)
	tw.tween_property(end_turn_button, "modulate", Color.WHITE, 0.1)

	# 捨て札（履歴へ）
	for card in hand:
		discard_pile.append(card)
	hand.clear()
	_rebuild_hand_ui()

	# 摂動源の時間発展
	await get_tree().create_timer(0.5).timeout
	_execute_entropy_phase()

	if player_structure <= 0:
		_on_defeat()
	elif system_entropy >= stability_threshold:
		_on_victory()
	else:
		await get_tree().create_timer(0.3).timeout
		_start_player_turn()

func _execute_entropy_phase() -> void:
	var intent_type = enemy_intent.get("type", "")
	if intent_type == "entropy":
		var damage = enemy_intent.get("value", 0)
		var multi = enemy_intent.get("multi", 1)
		for i in multi:
			if entropy_shield > 0:
				if entropy_shield >= damage:
					entropy_shield -= damage
					damage = 0
				else:
					damage -= entropy_shield
					entropy_shield = 0
			player_structure -= damage
	# "stabilize" type: 摂動源が自己安定化（何もしない）

func _check_win_condition() -> void:
	if system_entropy >= stability_threshold:
		_on_victory()

func _on_victory() -> void:
	# BGMフェードアウト
	_stop_bgm_fade_out()
	
	# 戦闘統計
	GameState.entropy_history.append(system_entropy)
	
	# 戦闘中の全カード（山札+手札+捨て札）をデッキとして保存
	GameState.player_deck.clear()
	for card in draw_pile:
		GameState.player_deck.append(card)
	for card in hand:
		GameState.player_deck.append(card)
	for card in discard_pile:
		GameState.player_deck.append(card)
	
	# 摂動源の相転移アニメーション（発散）
	_play_enemy_defeat_animation()
	await get_tree().create_timer(0.66).timeout
	
	# 最後のバトルならクリアリザルトへ、 otherwise 報酬画面へ
	if GameState.current_floor >= GameState.max_floor:
		get_tree().change_scene_to_file(GameState.get_scene_path("clear_result", "res://scenes/clear_result.tscn"))
	else:
		get_tree().change_scene_to_file(GameState.get_scene_path("reward", "res://scenes/reward.tscn"))

func _play_enemy_defeat_animation() -> void:
	# 摂動源が相転移（発散）するアニメーション
	# 中央を軸に回転するようにpivot_offsetを設定
	enemy_sprite.pivot_offset = enemy_sprite.size * 0.5
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	# スプライトを拡大しながら透明化
	tween.tween_property(enemy_sprite, "scale", Vector2(1.5, 1.5), 0.66)
	tween.tween_property(enemy_sprite, "modulate:a", 0.0, 0.66)
	
	# スプライトが回転しながら発散する効果
	tween.tween_property(enemy_sprite, "rotation", PI * 2, 0.66)

func _on_defeat() -> void:
	# BGMフェードアウト
	_stop_bgm_fade_out()
	
	var screen = DefeatScreenScene.instantiate()
	screen.continue_pressed.connect(_on_defeat_continue)
	screen.reset_pressed.connect(_on_defeat_reset)
	add_child(screen)

func _on_defeat_continue() -> void:
	GameState.reset_run()
	get_tree().reload_current_scene()

func _on_defeat_reset() -> void:
	GameState.reset_run()
	get_tree().change_scene_to_file(GameState.get_scene_path("main_menu", "res://scenes/main_menu.tscn"))

# --- デッキ/山札/捨て札ビューポップアップ ---

var _active_popup: Control = null

func _show_deck_popup(cards: Array, title: String) -> void:
	_close_deck_popup()
	
	var popup := Control.new()
	popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.name = "DeckPopup"
	
	# 背景オーバーレイ（クリックで閉じる）
	var overlay := Button.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.flat = true
	overlay.pressed.connect(_close_deck_popup)
	popup.add_child(overlay)
	
	# 暗転レイヤー
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.7)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_child(dim)
	
	# メインパネル
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 500)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -190
	panel.offset_right = 190
	panel.offset_top = -260
	panel.offset_bottom = 260
	popup.add_child(panel)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)
	
	# タイトル
	var title_label := Label.new()
	title_label.text = "%s (%d)" % [title, cards.size()]
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title_label)
	
	var sep := HSeparator.new()
	vbox.add_child(sep)
	
	# カードスクロールリスト
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 380)
	vbox.add_child(scroll)
	
	var card_list := VBoxContainer.new()
	card_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_list.add_theme_constant_override("separation", 4)
	scroll.add_child(card_list)
	
	for i in cards.size():
		var c = cards[i]
		var row := PanelContainer.new()
		row.custom_minimum_size = Vector2(0, 52)
		card_list.add_child(row)
		
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)
		row.add_child(hbox)
		
		# 小さな幾何学アイコン
		var icon_color = CardDatabase.parse_color(c.get("color", [0.5, 0.5, 0.5]))
		var icon := ColorRect.new()
		icon.custom_minimum_size = Vector2(12, 40)
		icon.color = icon_color
		hbox.add_child(icon)
		
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(info)
		
		var name_lbl := Label.new()
		name_lbl.text = c.get("name", "???")
		name_lbl.add_theme_font_size_override("font_size", 14)
		info.add_child(name_lbl)
		
		var desc_lbl := Label.new()
		desc_lbl.text = c.get("description", "")
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.modulate = Color(1, 1, 1, 0.65)
		info.add_child(desc_lbl)
		
		var cost_lbl := Label.new()
		cost_lbl.text = "E:%d" % c.get("cost", 1)
		cost_lbl.add_theme_font_size_override("font_size", 12)
		cost_lbl.custom_minimum_size = Vector2(36, 0)
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hbox.add_child(cost_lbl)
	
	# 戻るボタン
	var back_btn := Button.new()
	back_btn.text = "戻る"
	back_btn.custom_minimum_size = Vector2(200, 40)
	back_btn.pressed.connect(_close_deck_popup)
	vbox.add_child(back_btn)
	
	_active_popup = popup
	add_child(popup)

func _close_deck_popup() -> void:
	if _active_popup:
		_active_popup.queue_free()
		_active_popup = null

func _on_deck_button_pressed() -> void:
	var deck_cards: Array = []
	if GameState.player_deck.is_empty():
		deck_cards = CARD_DATABASE.create_starter_deck()
	else:
		deck_cards = GameState.player_deck.duplicate(true)
	_show_deck_popup(deck_cards, "デッキ")

func _on_draw_pile_button_pressed() -> void:
	_show_deck_popup(draw_pile.duplicate(true), "可能性空間")

func _on_discard_pile_button_pressed() -> void:
	_show_deck_popup(discard_pile.duplicate(true), "履歴")
