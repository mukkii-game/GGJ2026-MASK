extends Node2D
## パワーエサ。画面端からフラフラ揺れながら移動。ジャンプで取るとランダム効果（敵全体弱り or プレイヤー速度2倍）
## 見た目は _draw で大きくはっきり描画

## マット範囲（右→左 or 上→下の移動に使用）
const MAT_LEFT := 296.0
const MAT_RIGHT := 984.0
const MAT_TOP := 106.0
const MAT_BOTTOM := 614.0
## ジャンプの見た目の高さ（プレイヤーJUMP_VISUAL_HEIGHTと同じ）
const FLOAT_HEIGHT := 100.0
## 画面端（リングの橋から橋ではなく画面端→リング端）
const SCREEN_LEFT := -60.0
const SCREEN_RIGHT := 1340.0
const SCREEN_TOP := -60.0
const SCREEN_BOTTOM := 780.0
## 揺れの振幅（ピクセル）
const WOBBLE_AMP := 18.0
## 揺れの周波数（rad/秒）
const WOBBLE_FREQ := 4.5
## 端から端までかかる時間（秒）（速度2倍＝8秒）
const TRAVEL_DURATION := 8.0
## 効果持続時間（秒）
const EFFECT_DURATION := 5.0

enum Pattern { RightToLeft, TopToBottom }

var _pattern: Pattern = Pattern.RightToLeft
var _start_pos: Vector2 = Vector2.ZERO
var _end_pos: Vector2 = Vector2.ZERO
var _travel_time: float = 0.0
var _collected: bool = false

@onready var _area: Area2D = $Area2D
@onready var _sprite: Node2D = $BaitSprite  # 本体＋影の親

## わかりやすい大きさで描画（ピクセル）
const DRAW_W := 40.0
const DRAW_H := 48.0
## 足元の影（プレイヤー同様・四角）のサイズとオフセット（ジャンプ高さぶん下＝足元）
const SHADOW_SIZE := 28.0
const SHADOW_Y_OFFSET := FLOAT_HEIGHT
## 取得判定：物理に頼らず「この範囲にプレイヤーがいれば取れる」（SubViewport でも確実）
const COLLECT_HALF_X := 55.0
const COLLECT_HALF_Y := 90.0


func _ready() -> void:
	if _area:
		_area.position = Vector2.ZERO
		_area.body_entered.connect(_on_body_entered)


func _draw() -> void:
	# 青で大きくはっきり表示（中央基準）
	var rect := Rect2(-DRAW_W / 2.0, -DRAW_H / 2.0, DRAW_W, DRAW_H)
	draw_rect(rect, Color(0.25, 0.55, 1.0, 1.0))
	draw_rect(rect, Color(0.1, 0.35, 0.9, 1.0), false, 3.0)
	# 足元にプレイヤー同様の影（四角・ジャンプ高さぶん下＝地面の位置）
	var shadow_rect := Rect2(-SHADOW_SIZE / 2.0, SHADOW_Y_OFFSET - SHADOW_SIZE / 2.0, SHADOW_SIZE, SHADOW_SIZE)
	draw_rect(shadow_rect, Color(0.08, 0.08, 0.12, 0.65))


## 画面の端からリングの橋（端）へ。through_center のときはリング中央の高さ/横を通る
func init_pattern(horizontal: bool, through_center: bool = false) -> void:
	var center_x := (MAT_LEFT + MAT_RIGHT) / 2.0
	var center_y := (MAT_TOP + MAT_BOTTOM) / 2.0
	# 高さ＝プレイヤージャンプの最大の高さ（FLOAT_HEIGHT＝JUMP_VISUAL_HEIGHTと同じ）
	if horizontal:
		_pattern = Pattern.RightToLeft
		var float_y: float
		if through_center:
			float_y = center_y - FLOAT_HEIGHT
		else:
			float_y = randf_range(MAT_TOP + 80.0, MAT_BOTTOM - 80.0) - FLOAT_HEIGHT
		_start_pos = Vector2(SCREEN_RIGHT, float_y)
		_end_pos = Vector2(MAT_LEFT - 20.0, float_y)
	else:
		_pattern = Pattern.TopToBottom
		var x: float = center_x if through_center else randf_range(MAT_LEFT + 80.0, MAT_RIGHT - 80.0)
		_start_pos = Vector2(x, SCREEN_TOP)
		_end_pos = Vector2(x, MAT_TOP - 20.0)
	global_position = _start_pos
	_travel_time = 0.0


func _process(delta: float) -> void:
	if _collected:
		return
	_travel_time += delta
	var t: float = clampf(_travel_time / TRAVEL_DURATION, 0.0, 1.0)
	# 直線補間 + フラフラ揺れ
	var base_pos: Vector2 = _start_pos.lerp(_end_pos, t)
	var wobble: float = sin(_travel_time * WOBBLE_FREQ) * WOBBLE_AMP
	if _pattern == Pattern.RightToLeft:
		base_pos.y += wobble
	else:
		base_pos.x += wobble
	global_position = base_pos
	_try_collect_by_distance()
	_try_collect()
	if t >= 1.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if _collected:
		return
	if not body.is_in_group("Player") or not body is PlayerMain:
		return
	_collected = true
	_apply_random_effect(body as PlayerMain)
	AudioManager.play_sound(AudioManager.POWER_BAIT_GET, 0, -2)
	queue_free()


## 距離で取得判定（物理の当たり判定に依存しない・SubViewport でも動く）
func _try_collect_by_distance() -> void:
	if _collected:
		return
	var my_pos := global_position
	for node in get_tree().get_nodes_in_group("Player"):
		if not node is PlayerMain:
			continue
		var pm := node as PlayerMain
		if not is_instance_valid(pm) or pm.is_dead:
			continue
		var dp := pm.global_position - my_pos
		if absf(dp.x) <= COLLECT_HALF_X and absf(dp.y) <= COLLECT_HALF_Y:
			_collected = true
			_apply_random_effect(pm)
			AudioManager.play_sound(AudioManager.POWER_BAIT_GET, 0, -2)
			queue_free()
			return


func _try_collect() -> void:
	if _collected or not _area:
		return
	for body in _area.get_overlapping_bodies():
		if not body.is_in_group("Player") or not body is PlayerMain:
			continue
		_collected = true
		_apply_random_effect(body as PlayerMain)
		AudioManager.play_sound(AudioManager.POWER_BAIT_GET, 0, -2)
		queue_free()
		return


func _apply_random_effect(player: PlayerMain) -> void:
	var choice: int = randi() % 2
	if choice == 0:
		# プレイヤー速度2倍・一定時間
		player.apply_power_bait_speed(EFFECT_DURATION)
		_show_pickup_feedback(player, "スピード2倍！", Color(0.3, 0.8, 2.0, 1.0))
	else:
		# 敵全員弱り状態＋プレイヤーは敵からダメージを受けなくなる
		for node in get_tree().get_nodes_in_group("Enemy"):
			var e := node as EnemyMain
			if is_instance_valid(e) and not e.is_dead:
				e.set_weak_for(EFFECT_DURATION)
		player.apply_power_bait_enemy_immune(EFFECT_DURATION)
		_show_pickup_feedback(player, "敵全員よわり！", Color(0.3, 2.0, 0.6, 1.0))


## 取得フィードバック：プレイヤーをフラッシュ＋効果名のポップアップ表示（TD-08）
func _show_pickup_feedback(player: PlayerMain, text: String, flash_color: Color) -> void:
	# プレイヤー本体を効果色でフラッシュ（少し長めに維持して分かりやすく）
	if player.has_method("_flash_modulate"):
		player._flash_modulate(player.sprite if player.sprite else player, flash_color, 0.5)
	# 頭上に効果名を表示して浮かせながらフェードアウト
	var parent := player.get_parent()
	if not parent:
		return
	var label := Label.new()
	label.text = text
	label.z_index = 200
	label.add_theme_font_size_override("font_size", 36)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color(flash_color.r * 0.5, flash_color.g * 0.5, flash_color.b * 0.5, 1.0))
	label.add_theme_constant_override("outline_size", 8)
	parent.add_child(label)
	# 中央揃えで頭上に配置
	label.position = player.global_position + Vector2(-120.0, -110.0)
	label.size = Vector2(240.0, 40.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y - 50.0, 1.2)
	tw.tween_property(label, "modulate:a", 0.0, 1.2).set_delay(0.5)
	tw.chain().tween_callback(label.queue_free)
