extends CharacterBase
class_name PlayerMain

@onready var fsm = $FSM as FiniteStateMachine
@onready var cam = $Camera2D
const DEATH_SCREEN = preload("res://Scenes/Misc/DeathScreen.tscn")

## マット内の移動範囲（左右はロープにめり込むだけ・下は赤ロープに触れて跳ね返る）
const MAT_LEFT := 296   # 体半分めり込み時 center 296 → left 264
const MAT_RIGHT := 984  # 体半分めり込み時 center 984 → right 1016
const MAT_TOP := 48
const MAT_BOTTOM := 704 # 下ロープ（WallBottom y=696+8）に触れられるように
## カメラ固定位置（画面中央＝マット中央）
const CAM_CENTER := Vector2(640, 360)

## false=滑らか（初期） / true=カクカク。Gキーまたは右クリックでトグル
var use_grid_movement := false
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
## 着地した直後1フレームだけ体当たりをスキップ（ジャンプ着地時の二重発火防止）
var _just_landed_frame := false
## 体当たりダメージ用クールダウン（秒）
var body_contact_cooldown := 0.0
## 接した瞬間に食らうように間隔を短めに
const BODY_CONTACT_INTERVAL := 0.3
## 当たり判定の半径（やや余裕を持たせて「せき止め」で止まっても反応する）
const BODY_CONTACT_RADIUS := 70.0
const BODY_DAMAGE_DEALT := 10
const BODY_DAMAGE_TAKEN := 8
## ノックバック＝キャラ1人分の幅を一瞬で移動（64）
const BODY_PUSH_PIXELS := 64.0
## 体半分以上が重なったとみなす距離（中心間32以下＝半径同士で半分以上かぶる）
const HALF_OVERLAP_DIST := 32.0
## 半キャラずらし時：ノックバック量（キャラ1人分）・連続ダメージ間隔・1回あたりダメージ
const PUSH_KNOCKBACK := 64.0
const PUSH_DAMAGE_INTERVAL := 0.2
const PUSH_DAMAGE_PER_TICK := 6
var _push_damage_timer := 0.0
## 上ロープ矯正用（ワープではなく数フレームで下方向に押し戻す）
var _rope_correction_velocity := Vector2.ZERO
const ROPE_TOP_CORRECTION_SPEED := 120.0
const ROPE_TOP_CORRECTION_DECAY := 400.0
const ROPE_BOTTOM_BOUNCE := 256

func _ready():
	super()
	use_grid_movement = GameManager.use_grid_mode
	if cam:
		cam.position_smoothing_enabled = false
		# カメラをプレイヤーから切り離してスクロールしないようにする
		var root = get_tree().current_scene
		if root and cam.get_parent() == self:
			remove_child(cam)
			root.add_child(cam)
			cam.global_position = CAM_CENTER

func _process(_delta):
	super(_delta)
	if Input.is_action_just_pressed("ToggleGridMove") or Input.is_action_just_pressed("Kick"):
		GameManager.use_grid_mode = not GameManager.use_grid_mode
		use_grid_movement = GameManager.use_grid_mode
	# カメラ完全固定（スクロール一切なし）
	if cam:
		cam.global_position = CAM_CENTER
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

## ノックバックはX軸かY軸のみ（イース風・半キャラずらしを意識）
func _axis_knockback(to_enemy: Vector2, amount: float) -> Vector2:
	if absf(to_enemy.x) >= absf(to_enemy.y):
		return Vector2(signf(to_enemy.x) * amount, 0.0)
	return Vector2(0.0, signf(to_enemy.y) * amount)

## 体当たり：敵と触れたら必ずダメージ＋ノックバック。半キャラずらし＝敵方向に上下左右で移動＋接している部分が幅の半分以下のときは敵だけノックバック＆ダメージ、プレイヤーは止まらず動き続けられる
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
	# どの敵とも触れていないときはクールダウンをリセットし、次に触れた瞬間に必ず処理が入るようにする
	var in_contact := false
	for node in get_tree().get_nodes_in_group("Enemy"):
		var e := node as CharacterBase
		if is_instance_valid(e) and not e.is_dead:
			var dist := global_position.distance_to(e.global_position)
			if dist <= BODY_CONTACT_RADIUS and dist > 0.1:
				in_contact = true
				break
	if not in_contact:
		body_contact_cooldown = 0.0
		_push_damage_timer = 0.0
	for node in get_tree().get_nodes_in_group("Enemy"):
		var enemy = node as CharacterBase
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		var d := global_position.distance_to(enemy.global_position)
		if d > BODY_CONTACT_RADIUS or d <= 0.1:
			continue
		var to_enemy: Vector2 = (enemy.global_position - global_position).normalized()
		# 接する部分が半分以上のときは必ず双方ダメージ＋ノックバック（両者接した瞬間に食らう）。ノックバック中は無敵
		if d <= HALF_OVERLAP_DIST:
			if body_contact_cooldown <= 0.0:
				enemy._take_damage(BODY_DAMAGE_DEALT)
				_take_damage(BODY_DAMAGE_TAKEN)
				# 上から敵に当たったとき（プレイヤーが上）は両方飛びすぎないようノックバックを弱める（横だけ・量半分）
				var push_amount := BODY_PUSH_PIXELS
				var away: Vector2
				if global_position.y < enemy.global_position.y:
					away = Vector2(signf(-to_enemy.x) * push_amount * 0.5, 0.0)
				else:
					away = _axis_knockback(-to_enemy, push_amount)
				global_position += away
				enemy.global_position -= away
				global_position = Vector2(clampf(global_position.x, MAT_LEFT, MAT_RIGHT), clampf(global_position.y, MAT_TOP, MAT_BOTTOM))
				body_contact_cooldown = BODY_CONTACT_INTERVAL
				enemy.set_invincible_for(0.5)
				set_invincible_for(0.5)
			break
		# 接する部分が半分以下のとき、敵方向に上下左右で移動していれば一方的に敵だけノックバック＆ダメージ
		var is_cardinal: bool = absf(input_dir.x) < 0.01 or absf(input_dir.y) < 0.01
		var pressing_toward: bool = input_dir.length() > 0.3 and input_dir.dot(to_enemy) > 0.5
		var one_sided_ok: bool = is_cardinal and pressing_toward
		if one_sided_ok:
			var knock: Vector2 = _axis_knockback(to_enemy, PUSH_KNOCKBACK)
			var new_enemy_pos: Vector2 = Vector2(enemy.global_position.x + knock.x, enemy.global_position.y + knock.y)
			# 敵がロープ外に飛ぶ場合は「大きくジャンプして画面内に着地」に任せる（着地まで無敵）
			if _is_outside_mat(new_enemy_pos):
				if enemy.has_method("trigger_rope_launch"):
					enemy.set_invincible_for(1.5)
					enemy.trigger_rope_launch()
			else:
				enemy.global_position = new_enemy_pos
				enemy.set_invincible_for(0.5)
			global_position += _axis_knockback(to_enemy, 16.0)
			global_position = Vector2(clampf(global_position.x, MAT_LEFT, MAT_RIGHT), clampf(global_position.y, MAT_TOP, MAT_BOTTOM))
			if _push_damage_timer <= 0:
				_push_damage_timer = PUSH_DAMAGE_INTERVAL
				enemy._take_damage(PUSH_DAMAGE_PER_TICK)
			break
		# それ以外：敵味方ともダメージ＋ノックバック
		if body_contact_cooldown <= 0:
			enemy._take_damage(BODY_DAMAGE_DEALT)
			_take_damage(BODY_DAMAGE_TAKEN)
			var push_amount := BODY_PUSH_PIXELS
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
				enemy.set_invincible_for(0.5)
			global_position = Vector2(clampf(global_position.x, MAT_LEFT, MAT_RIGHT), clampf(global_position.y, MAT_TOP, MAT_BOTTOM))
			body_contact_cooldown = BODY_CONTACT_INTERVAL
			set_invincible_for(0.5)
		break

func _is_outside_mat(pos: Vector2) -> bool:
	return pos.x < MAT_LEFT or pos.x > MAT_RIGHT or pos.y < MAT_TOP or pos.y > MAT_BOTTOM

func _die():
	super() #calls _die() on base-class CharacterBase
	
	fsm.force_change_state("Die")
	var death_scene = DEATH_SCREEN.instantiate()
	add_child(death_scene)
