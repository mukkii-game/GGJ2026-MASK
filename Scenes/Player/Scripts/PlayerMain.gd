extends CharacterBase
class_name PlayerMain

@onready var fsm = $FSM as FiniteStateMachine
@onready var cam = $Camera2D
const DEATH_SCREEN = preload("res://Scenes/Misc/DeathScreen.tscn")

<<<<<<< Updated upstream
## マット内の移動範囲（1280×720画面中央の720×720正方形内、プレイヤー半径32pxのマージン）
const MAT_LEFT := 344
const MAT_RIGHT := 936
const MAT_TOP := 64
const MAT_BOTTOM := 656
=======
## マット内の移動範囲（左右はロープにめり込むだけ・下は赤ロープに触れて跳ね返る）
const MAT_LEFT := 296   # 体半分めり込み時 center 296 → left 264
const MAT_RIGHT := 984  # 体半分めり込み時 center 984 → right 1016
const MAT_TOP := 16     # 上ロープ（16ドット幅）の下端
const MAT_BOTTOM := 704 # 下ロープ（16ドット幅）の上端
>>>>>>> Stashed changes
## カメラ固定位置（画面中央＝マット中央）
const CAM_CENTER := Vector2(640, 360)

## false=滑らか（初期） / true=カクカク。Gキーでトグル
var use_grid_movement := false
<<<<<<< Updated upstream
=======
## 左クリックで自動走行開始時に Moving に渡すフラグ
var start_auto_run := false
## 自動走行中か（風エフェクト表示用）
var is_auto_running := false
## 方向キー＋Punchでダッシュ（0.5秒3倍速、連打で延長）
var dash_timer := 0.0
const DASH_DURATION := 0.5
const DASH_SPEED_MULT := 3.0
## ジャンプ中か（当たり判定スキップ・Yクランプしない）
var is_jumping := false
## コーナーポストの上にいる（触れて登った状態）
var on_corner_post := false
## ポストからジャンプで降りた直後＝着地ダメージ2倍
var leave_post_2x_jump := false
## 着地した直後1フレームだけ体当たりをスキップ（ジャンプ着地時の二重発火防止）
var _just_landed_frame := false
## 炎ダッシュ中は敵への与ダメージ倍率（2倍）
var fire_dash_damage_mult: float = 1.0
## 炎ダッシュ中は受けるダメージ倍率（2倍・ハイリスクハイリターン）
var fire_dash_damage_taken_mult: float = 1.0
## 体当たりダメージ用クールダウン（秒）
var body_contact_cooldown := 0.0
## 接した瞬間に食らうように間隔を短めに
const BODY_CONTACT_INTERVAL := 0.3
## 体当たりはPC-88風の正方形コリジョン（中心から±この値＝1辺80の箱、scale 1.25を考慮）。+1で「ぴったり接している」も検出
const BODY_CONTACT_HALF := 40.0
const BODY_CONTACT_HALF_TOLERANCE := 1.0
const BODY_DAMAGE_DEALT := 10
const BODY_DAMAGE_TAKEN := 8
## ノックバック＝キャラ1人分の幅を一瞬で移動（80、scale 1.25を考慮）
const BODY_PUSH_PIXELS := 80.0
## 正面衝突（両方ダメージ）時のノックバック＝キャラ約3人分・実際に移動で飛ばす
const BODY_PUSH_PIXELS_FRONTAL := 240.0
## 体半分以上が重なったとみなす（両軸で中心差がこの値以下＝正方形が半分以上かぶる）
const HALF_OVERLAP_DIST := 40.0
## 半キャラずらし時：ノックバック量（キャラ1人分）・連続ダメージ間隔・1回あたりダメージ
const PUSH_KNOCKBACK := 80.0
const PUSH_DAMAGE_INTERVAL := 0.2
const PUSH_DAMAGE_PER_TICK := 6
var _push_damage_timer := 0.0
## 上ロープ矯正用（ワープではなく数フレームで下方向に押し戻す）
var _rope_correction_velocity := Vector2.ZERO
const ROPE_TOP_CORRECTION_SPEED := 120.0
const ROPE_TOP_CORRECTION_DECAY := 400.0
const ROPE_BOTTOM_BOUNCE := 256
>>>>>>> Stashed changes

func _ready():
	super()
	if cam:
		cam.position_smoothing_enabled = false
		# カメラをプレイヤーから切り離してスクロールしないようにする（SubViewport内のときはゲームルートに追加）
		var vp = get_viewport()
		var cam_root: Node = get_tree().current_scene
		if vp != get_tree().root and vp.get_child_count() > 0:
			cam_root = vp.get_child(0)
		if cam_root and cam.get_parent() == self:
			remove_child(cam)
			cam_root.add_child(cam)
			cam.global_position = CAM_CENTER

func _process(_delta):
	super(_delta)
	if Input.is_action_just_pressed("ToggleGridMove"):
		use_grid_movement = not use_grid_movement
	# カメラ完全固定（スクロール一切なし）
	if cam:
		cam.global_position = CAM_CENTER
<<<<<<< Updated upstream
	# マット外には出さない
	var p := global_position
	global_position = Vector2(clampf(p.x, MAT_LEFT, MAT_RIGHT), clampf(p.y, MAT_TOP, MAT_BOTTOM))
=======
	# ジャンプ中はYクランプ・体当たりしない
	if not is_jumping:
		var p := global_position
		# 上ロープ：矯正移動（ワープではなく数フレームで下方向に押し戻す）
		if p.y < MAT_TOP:
			p.y = MAT_TOP
			_rope_correction_velocity.y = ROPE_TOP_CORRECTION_SPEED
		# 下ロープ：触れたら上に跳ね飛ばし＋ぼよん音（ダメージなし）。壁で止まるので「下端付近かつ下方向」で検出
		if p.y >= MAT_BOTTOM - 48.0 and velocity.y > 0.0:
			p.y = clampf(p.y - ROPE_BOTTOM_BOUNCE, MAT_TOP, MAT_BOTTOM)
			velocity.y = 0.0
			AudioManager.play_sound(AudioManager.ROPE_BOUNCE, 0, -2)
		# 左右ロープ：跳ね返らない（形で触れてめり込むだけ、クランプのみ）
		# 矯正速度を適用してからクランプ
		_rope_correction_velocity = _rope_correction_velocity.move_toward(Vector2.ZERO, ROPE_TOP_CORRECTION_DECAY * _delta)
		p += _rope_correction_velocity * _delta
		global_position = Vector2(clampf(p.x, MAT_LEFT, MAT_RIGHT), clampf(p.y, MAT_TOP, MAT_BOTTOM))
		var we = get_node_or_null("WindEffect")
		if we:
			we.visible = is_auto_running
		_body_contact(_delta)
	else:
		# ジャンプ中はXだけマット内に
		var p := global_position
		global_position.x = clampf(p.x, MAT_LEFT, MAT_RIGHT)

## コーナーポストに触れたときに呼ばれる。大ジャンプ（通常ジャンプの長い版・回転あり）を即発動
func trigger_corner_post_jump() -> void:
	if is_dead or is_jumping:
		return
	on_corner_post = true
	fsm.force_change_state("Jump")

## 正方形コリジョン：2つの中心と半幅でAABBが重なるか
func _aabb_overlap(pa: Vector2, pb: Vector2, half: float) -> bool:
	return absf(pa.x - pb.x) <= 2.0 * half and absf(pa.y - pb.y) <= 2.0 * half

## 半分以上かぶっているか（両軸で中心差が half 以下）
func _is_heavy_overlap(pa: Vector2, pb: Vector2, half: float) -> bool:
	return absf(pa.x - pb.x) <= half and absf(pa.y - pb.y) <= half

## ノックバックはX軸かY軸のみ（イース風・半キャラずらしを意識）
func _axis_knockback(to_enemy: Vector2, amount: float) -> Vector2:
	if absf(to_enemy.x) >= absf(to_enemy.y):
		return Vector2(signf(to_enemy.x) * amount, 0.0)
	return Vector2(0.0, signf(to_enemy.y) * amount)

## 正面衝突でプレイヤーが食らったときの派手な白ぴかぴか
func _flash_white_body_contact() -> void:
	var target = sprite if sprite else self
	if not target:
		return
	var orig: Color = target.modulate
	var tween := create_tween()
	tween.set_parallel(false)
	tween.tween_property(target, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.08)
	tween.tween_property(target, "modulate", orig, 0.18)

## 体当たり：敵と触れたら必ずダメージ＋ノックバック。正方形コリジョン（PC-88風）。半キャラずらし＝敵方向に上下左右で移動＋接している部分が幅の半分以下のときは敵だけノックバック＆ダメージ
func _body_contact(delta: float) -> void:
	if is_dead:
		return
	# 着地直後1フレームは体当たりをスキップ（ジャンプ着地で _land() が処理するので二重発火防止）
	if _just_landed_frame:
		_just_landed_frame = false
		return
	var raw_input := Input.get_vector("MoveLeft", "MoveRight", "MoveUp", "MoveDown")
	var input_dir: Vector2 = raw_input.normalized() if raw_input.length() > 0.01 else Vector2.ZERO
	body_contact_cooldown -= delta
	_push_damage_timer -= delta
	var p_pos := global_position
	# どの敵とも触れていないときはクールダウンをリセット
	var in_contact := false
	for node in get_tree().get_nodes_in_group("Enemy"):
		var e := node as CharacterBase
		if is_instance_valid(e) and not e.is_dead:
			if _aabb_overlap(p_pos, e.global_position, BODY_CONTACT_HALF + BODY_CONTACT_HALF_TOLERANCE):
				in_contact = true
				break
	if not in_contact:
		body_contact_cooldown = 0.0
		_push_damage_timer = 0.0
	for node in get_tree().get_nodes_in_group("Enemy"):
		var enemy = node as CharacterBase
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if not _aabb_overlap(p_pos, enemy.global_position, BODY_CONTACT_HALF + BODY_CONTACT_HALF_TOLERANCE):
			continue
		var to_enemy: Vector2 = (enemy.global_position - global_position).normalized()
		var e_pos: Vector2 = enemy.global_position
		# 敵方向に上下左右のいずれかを押している場合
		var is_cardinal: bool = absf(input_dir.x) < 0.01 or absf(input_dir.y) < 0.01
		var pressing_toward: bool = input_dir.length() > 0.3 and input_dir.dot(to_enemy) > 0.5
		var pressing_toward_ok: bool = is_cardinal and pressing_toward
		# ショルダータックル判定：左右移動時はY軸の差、上下移動時はX軸の差を見る。少なめ(0〜半キャラ32)＝正面＝両方ダメージ＋作用反作用で離れる。多め(半キャラ〜1キャラ幅32〜64)＝ショルダー＝敵だけダメージ
		var alignment_diff: float
		if absf(to_enemy.x) >= absf(to_enemy.y):
			alignment_diff = absf(p_pos.y - e_pos.y)
		else:
			alignment_diff = absf(p_pos.x - e_pos.x)
		var shoulder_ok: bool = pressing_toward_ok and alignment_diff > HALF_OVERLAP_DIST
		if shoulder_ok:
			# ショルダータックル：ずれが多め＝敵だけノックバック＋ダメージ（0.2秒間隔）。下方向は暴発しないよう弱く
			if _push_damage_timer <= 0:
				_push_damage_timer = PUSH_DAMAGE_INTERVAL
				enemy._take_damage(int(PUSH_DAMAGE_PER_TICK * fire_dash_damage_mult))
				# 強化時（炎ダッシュ中）はすごめの音＋エフェクト大きく
				if fire_dash_damage_mult > 1.5:
					AudioManager.play_sound(AudioManager.PLAYER_ATTACK_HIT, 0, 2)
					if enemy.hit_particles:
						enemy.hit_particles.amount = 20
						enemy.hit_particles.emitting = true
				var knock_amount: float = PUSH_KNOCKBACK
				var player_push: float = 16.0
				if to_enemy.y > 0.5:
					knock_amount = 32.0
					player_push = 8.0
				var knock: Vector2 = _axis_knockback(to_enemy, knock_amount)
				var new_enemy_pos: Vector2 = Vector2(e_pos.x + knock.x, e_pos.y + knock.y)
				if _is_outside_mat(new_enemy_pos):
					if enemy.has_method("trigger_rope_launch"):
						enemy.set_invincible_for(1.5)
						enemy.trigger_rope_launch()
				else:
					enemy.global_position = new_enemy_pos
					enemy.velocity = Vector2.ZERO
					enemy.knockback_stun_remaining = 0.25
					enemy.set_invincible_for(0.5)
				global_position += _axis_knockback(to_enemy, player_push)
				global_position = Vector2(clampf(global_position.x, MAT_LEFT, MAT_RIGHT), clampf(global_position.y, MAT_TOP, MAT_BOTTOM))
			break
		# 正面（差が少なめ）または敵方向を押していない：両方ダメージ＋作用反作用で反対向きにノックバック（約3キャラ分・移動で飛ばす）
		if body_contact_cooldown <= 0:
			enemy._take_damage(int(BODY_DAMAGE_DEALT * fire_dash_damage_mult))
			_take_damage(int(BODY_DAMAGE_TAKEN * fire_dash_damage_taken_mult))
			# 強化時（炎ダッシュ中）はすごめの音＋エフェクト大きく
			if fire_dash_damage_mult > 1.5:
				AudioManager.play_sound(AudioManager.PLAYER_ATTACK_HIT, 0, 2)
				if enemy.hit_particles:
					enemy.hit_particles.amount = 20
					enemy.hit_particles.emitting = true
			if fire_dash_damage_taken_mult > 1.5:
				AudioManager.play_sound(AudioManager.BLOODY_HIT, 0, 5)
				if hit_particles:
					hit_particles.amount = 20
					hit_particles.emitting = true
			_flash_white_body_contact()
			var push_amount := BODY_PUSH_PIXELS_FRONTAL
			var away: Vector2
			if global_position.y < enemy.global_position.y:
				away = Vector2(signf(-to_enemy.x) * push_amount * 0.5, 0.0)
			else:
				away = _axis_knockback(-to_enemy, push_amount)
			global_position += away
			var new_enemy_pos: Vector2 = Vector2(enemy.global_position.x - away.x, enemy.global_position.y - away.y)
			if _is_outside_mat(new_enemy_pos) and enemy.has_method("trigger_rope_launch"):
				enemy.set_invincible_for(1.5)
				enemy.trigger_rope_launch()
			else:
				enemy.global_position = new_enemy_pos
				enemy.velocity = Vector2.ZERO
				enemy.knockback_stun_remaining = 0.25
				enemy.set_invincible_for(0.5)
			global_position = Vector2(clampf(global_position.x, MAT_LEFT, MAT_RIGHT), clampf(global_position.y, MAT_TOP, MAT_BOTTOM))
			body_contact_cooldown = BODY_CONTACT_INTERVAL
			set_invincible_for(0.5)
		break

func _is_outside_mat(pos: Vector2) -> bool:
	return pos.x < MAT_LEFT or pos.x > MAT_RIGHT or pos.y < MAT_TOP or pos.y > MAT_BOTTOM
>>>>>>> Stashed changes

func _die():
	super() #calls _die() on base-class CharacterBase
	
	fsm.force_change_state("Die")
	var death_scene = DEATH_SCREEN.instantiate()
	add_child(death_scene)
