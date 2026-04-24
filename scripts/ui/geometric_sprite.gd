extends Control
## GeometricSprite - 幾何学的アニメーションスプライト
## CanvasItemの_draw()を使用した手描き風ジオメトリックアート
## 画像ファイル不要、完全データ駆動型

var shape: String = "circle"
var base_color: Color = Color.WHITE
var animation_type: String = "none"
var anim_time: float = 0.0
var params: Dictionary = {}

func _ready() -> void:
	queue_redraw()

func _process(delta: float) -> void:
	anim_time += delta
	if animation_type != "none":
		queue_redraw()

func configure(card_data: Dictionary) -> void:
	shape = card_data.get("shape", "circle")
	base_color = CardDatabase.parse_color(card_data.get("color", [1, 1, 1]))
	animation_type = card_data.get("animation", "none")
	# スプライト設定からパラメータ取得
	params = _get_shape_params(shape)
	queue_redraw()

func _get_shape_params(shp: String) -> Dictionary:
	var file := FileAccess.open("res://data/sprite_config.json", FileAccess.READ)
	if file:
		var json := JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var shapes = json.data.get("shapes", {})
			if shapes.has(shp):
				return shapes[shp].get("params", {})
	return {}

func _draw() -> void:
	var center := size * 0.5
	var base_size := mini(int(size.x), int(size.y)) * 0.4
	
	# アニメーション変形
	var scale_mod := 1.0
	var rotation_mod := 0.0
	var offset := Vector2.ZERO
	
	match animation_type:
		"pulse":
			scale_mod = 0.95 + 0.05 * sin(anim_time * 2.0)
		"rotate":
			rotation_mod = anim_time * 1.5
		"expand":
			scale_mod = 0.85 + 0.15 * (0.5 + 0.5 * sin(anim_time * 1.0))
		"oscillate":
			offset = Vector2(sin(anim_time * 3.0) * 3, cos(anim_time * 2.5) * 3)
	
	var draw_center := center + offset
	var draw_size := base_size * scale_mod
	
	match shape:
		"circle":
			_draw_circle(draw_center, draw_size, rotation_mod)
		"triangle":
			_draw_polygon(draw_center, draw_size, 3, rotation_mod)
		"hexagon":
			_draw_polygon(draw_center, draw_size, 6, rotation_mod)
		"spiral":
			_draw_spiral(draw_center, draw_size, rotation_mod)
		"wave":
			_draw_wave(draw_center, draw_size, anim_time)
		"fractal":
			_draw_fractal_tree(draw_center, draw_size, rotation_mod)
		"attractor":
			_draw_attractor(draw_center, draw_size, anim_time)
		_:
			_draw_circle(draw_center, draw_size, 0)

func _draw_circle(center: Vector2, radius: float, _rot: float) -> void:
	# 外周
	draw_arc(center, radius, 0, TAU, 32, base_color, 2.0)
	# 内部リング
	draw_arc(center, radius * 0.6, 0, TAU, 32, base_color * Color(1, 1, 1, 0.5), 1.5)
	# 中心点
	draw_circle(center, 3, base_color)
	# 放射線
	for i in 8:
		var angle := TAU * i / 8.0
		var inner := center + Vector2.from_angle(angle) * (radius * 0.3)
		var outer := center + Vector2.from_angle(angle) * (radius * 0.85)
		draw_line(inner, outer, base_color * Color(1, 1, 1, 0.4), 1.0)

func _draw_polygon(center: Vector2, radius: float, sides: int, rot: float) -> void:
	var points := PackedVector2Array()
	for i in sides:
		var angle := TAU * i / sides + rot
		points.append(center + Vector2.from_angle(angle) * radius)
	points.append(points[0]) # close
	draw_polyline(points, base_color, 2.0)
	
	# 内側の同心図形
	var inner_points := PackedVector2Array()
	for i in sides:
		var angle := TAU * i / sides + rot + PI / sides
		inner_points.append(center + Vector2.from_angle(angle) * (radius * 0.5))
	inner_points.append(inner_points[0])
	draw_polyline(inner_points, base_color * Color(1, 1, 1, 0.4), 1.0)
	
	draw_circle(center, 2, base_color)

func _draw_spiral(center: Vector2, max_radius: float, rot: float) -> void:
	var points := PackedVector2Array()
	var turns := 3.0
	var steps := 60
	for i in steps:
		var t := float(i) / steps
		var angle := t * TAU * turns + rot
		var r := t * max_radius
		points.append(center + Vector2.from_angle(angle) * r)
	draw_polyline(points, base_color, 2.0)
	
	# 中心の小さな六角形
	_draw_polygon(center, max_radius * 0.15, 6, rot * 0.5)

func _draw_wave(center: Vector2, amplitude: float, time: float) -> void:
	var points := PackedVector2Array()
	var half_width := amplitude * 2.5
	var segments := 40
	for i in segments:
		var t := float(i) / segments
		var x := center.x - half_width + t * half_width * 2
		var y := center.y + sin(t * TAU * 2 + time * 3.0) * amplitude * 0.5
		points.append(Vector2(x, y))
	draw_polyline(points, base_color, 2.0)
	
	# 振幅マーカー
	for i in 3:
		var x := center.x - half_width + (i + 0.5) * half_width * 2 / 3.0
		draw_circle(Vector2(x, center.y), 2, base_color * Color(1, 1, 1, 0.5))

func _draw_fractal_tree(center: Vector2, length: float, rot: float) -> void:
	_fractal_branch(center, Vector2.UP * length, length, 4, rot)

func _fractal_branch(start: Vector2, direction: Vector2, length: float, depth: int, angle_offset: float) -> void:
	if depth <= 0 or length < 2:
		return
	var end := start + direction
	var col := base_color * Color(1, 1,1, 0.3 + 0.7 * (depth / 4.0))
	draw_line(start, end, col, maxf(1.0, depth * 0.5))
	
	var branch_length := length * 0.7
	var left_dir := direction.rotated(-angle_offset) * 0.7
	var right_dir := direction.rotated(angle_offset) * 0.7
	_fractal_branch(end, left_dir, branch_length, depth - 1, angle_offset)
	_fractal_branch(end, right_dir, branch_length, depth - 1, angle_offset)

func _draw_attractor(center: Vector2, attractor_scale: float, time: float) -> void:
	var r := attractor_scale
	if r < 10.0:
		r = minf(size.x, size.y) * 0.4
	if r < 10.0:
		r = 30.0
	
	# 外周の回転する多角形（不安定な摂動源を表現）
	var outer_sides := 7
	var outer_rot := time * 0.8
	var outer_points := PackedVector2Array()
	for i in outer_sides:
		var angle := TAU * i / outer_sides + outer_rot
		# 各頂点の半径を微妙に変動させる
		var wobble := 1.0 + 0.12 * sin(time * 2.5 + i * 1.7)
		outer_points.append(center + Vector2.from_angle(angle) * r * wobble)
	outer_points.append(outer_points[0])
	draw_polyline(outer_points, base_color, 2.5)
	
	# 内側の逆回転多角形
	var inner_sides := 5
	var inner_rot := -time * 1.2
	var inner_r := r * 0.55
	var inner_points := PackedVector2Array()
	for i in inner_sides:
		var angle := TAU * i / inner_sides + inner_rot
		var wobble := 1.0 + 0.08 * sin(time * 3.0 + i * 2.3)
		inner_points.append(center + Vector2.from_angle(angle) * inner_r * wobble)
	inner_points.append(inner_points[0])
	draw_polyline(inner_points, base_color * Color(1, 1, 1, 0.7), 2.0)
	
	# 放射する軌跡線
	for i in 12:
		var angle := TAU * i / 12.0 + time * 0.3
		var inner := center + Vector2.from_angle(angle) * (r * 0.2)
		var outer := center + Vector2.from_angle(angle) * (r * (0.8 + 0.15 * sin(time * 2.0 + i)))
		draw_line(inner, outer, base_color * Color(1, 1, 1, 0.3 + 0.2 * sin(time + i)), 1.0)
	
	# 中心の点
	draw_circle(center, 4.0, base_color)
	draw_circle(center, r * 0.12, base_color * Color(1, 1, 1, 0.25))
