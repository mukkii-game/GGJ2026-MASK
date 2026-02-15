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


func _ready() -> void:
	# 当たり判定を足元の影の位置に（浮いているので通常接触では取れない＝影の上でジャンプしたときだけ取れる）
	if _area:
		_area.position = Vector2(0.0, SHADOW_Y_OFFSET)


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
	# 足元の影の位置にプレイヤーがいて、かつジャンプ中なら取得（コーナーポストジャンプも含む）
	_try_collect()
	if t >= 1.0:
		queue_free()


func _try_collect() -> void:
	if _collected or not _area:
		return
	for body in _area.get_overlapping_bodies():
		if not body.is_in_group("Player"):
			continue
		var pm := body as PlayerMain
		if not pm or not pm.is_jumping:
			continue
		_collected = true
		_apply_random_effect(pm)
		AudioManager.play_sound(AudioManager.COIN_PICK, 0, -6)
		queue_free()
		return


func _apply_random_effect(player: PlayerMain) -> void:
	var choice: int = randi() % 2
	if choice == 0:
		# プレイヤー速度2倍・一定時間
		player.apply_power_bait_speed(EFFECT_DURATION)
	else:
		# 敵全員弱り状態＋プレイヤーは敵からダメージを受けなくなる
		for node in get_tree().get_nodes_in_group("Enemy"):
			var e := node as EnemyMain
			if is_instance_valid(e) and not e.is_dead:
				e.set_weak_for(EFFECT_DURATION)
		player.apply_power_bait_enemy_immune(EFFECT_DURATION)
