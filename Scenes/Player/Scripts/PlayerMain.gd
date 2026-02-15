extends CharacterBase
class_name PlayerMain

@onready var fsm = $FSM as FiniteStateMachine
@onready var cam = $Camera2D
const DEATH_SCREEN = preload("res://Scenes/Misc/DeathScreen.tscn")

## マット内の移動範囲（ロープの位置ぴったりまで）
# ArenaMat.tscn の MatColor / RopeLeft / RopeRight に合わせる
# ロープの内側だけ行ける（上ロープ下端=106、下ロープ上端=614でクランプ）
const MAT_LEFT := 280   # 左ロープの内側端
const MAT_RIGHT := 1000 # 右ロープの内側端
const MAT_TOP := 106    # 上ロープの内側（ロープより下）
const MAT_BOTTOM := 614 # 下ロープの内側（ロープより上）
## カメラ固定位置（画面中央＝マット中央）
const CAM_CENTER := Vector2(640, 360)

## 2Pかどうか（true=2P。入力と見た目を変える）
@export var is_player_two: bool = false
## false=滑らか（初期） / true=カクカク。Gキーでトグル（1Pのみがトグル可能）
var use_grid_movement := false
## Nボタン/左クリックで自動走行開始時に Moving に渡すフラグ
var start_auto_run := false
## 自動走行中か（風エフェクト表示用・ロープバウンド連携）
var is_auto_running := false
## 走り（Nダッシュ）中か（前傾・足元うずまき・スピードライン用）
var is_run_dashing := false
## 走り中の進行方向（スピードラインの向き用。右＝(1,0)、左＝(-1,0)）
var run_dash_direction := Vector2.ZERO
## ロープタッチ自動移動中か
var rope_bounce_running := false
## ロープタッチ自動移動の方向
var rope_bounce_direction := Vector2.ZERO
## ロープタッチ自動移動の目標位置
var rope_bounce_target := Vector2.ZERO
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
## 体当たりは正方形コリジョン（中心から±この値＝1辺64の箱、キャラ64x64に合わせる）
const BODY_CONTACT_HALF := 32.0
const BODY_CONTACT_HALF_TOLERANCE := 1.0
const BODY_DAMAGE_DEALT := 10
const BODY_DAMAGE_TAKEN := 8
## ノックバック＝キャラ1人分の幅を一瞬で移動（64に合わせて60前後）
const BODY_PUSH_PIXELS := 60.0
## 正面衝突（両方ダメージ）時のノックバック＝キャラ約1.5人分・実際に移動で飛ばす
const BODY_PUSH_PIXELS_FRONTAL := 120.0
## 通常・半キャラのノックバックを数フレームで動かす時間（その間無敵）
const BODY_KNOCKBACK_TWEEN_DURATION := 0.2
## 正面／半キャラの境：ずれが32未満＝正面、32以上＝半キャラ or かすり
const HALF_OVERLAP_DIST := 32.0
## 半キャラずらしの上限：ずれ 32〜58 未満＝半キャラ、58以上64未満＝かすり
const SEMI_CAR_MAX := 58.0
## ずれ64以上＝当たってない（体当たり処理しない）
const BODY_CONTACT_MAX_ALIGNMENT := 64.0
## かすり時：斜めにすっ飛ばす距離（X,Y両方ずれて離れる方向・まあまあ大きく）
const KASURI_KNOCKBACK_DIAGONAL := 90.0
const KASURI_COOLDOWN := 0.4
## かすり：移動＋縦軸回転のティーン時間（バレリーナのように回転しながら飛ぶ）
const KASURI_TWEEN_DURATION := 0.28
const KASURI_SPIN_DEGREES := 720.0
## 半キャラずらし時：ノックバック量（キャラ1人分）・連続ダメージ間隔・1回あたりダメージ
const PUSH_KNOCKBACK := 60.0
const PUSH_DAMAGE_INTERVAL := 0.2
const PUSH_DAMAGE_PER_TICK := 6
var _push_damage_timer := 0.0
## 上ロープ矯正用（ワープではなく数フレームで下方向に押し戻す）
var _rope_correction_velocity := Vector2.ZERO
const ROPE_TOP_CORRECTION_SPEED := 120.0
const ROPE_TOP_CORRECTION_DECAY := 400.0
const ROPE_BOTTOM_BOUNCE := 256
## 敵と接したあとこの秒数だけモーション2倍速
var _enemy_contact_timer: float = 0.0
const ENEMY_CONTACT_SPEED_SEC := 2.0

## アリーナマット（ロープの見た目をたわませる用）
var _arena_mat: Node2D = null

func _enter_tree() -> void:
	# 2P: 木に入った瞬間に表示（元の挙動。1Pのときだけ _ready で隠す）
	if is_player_two:
		visible = true
		process_mode = PROCESS_MODE_INHERIT

func _ready():
	super()
	# 2P: 1Pモードのときだけここで非表示にする（2P/テストは表示のまま）
	if is_player_two:
		if not (GameManager.two_player_mode or GameManager.test_mode):
			visible = false
			process_mode = PROCESS_MODE_DISABLED
	# 2P: 専用キャラ画像（m_man_gr_l1 / m_man_gr_l2）に差し替え
	if is_player_two and sprite and sprite.sprite_frames:
		_apply_2p_sprite_frames()
	use_grid_movement = GameManager.use_grid_mode
	# 一旦ロープ以外の背景コリジョン（ロープ外の壁）を無効化：layer1 のみ当たる
	collision_mask = 1
	# アリーナマット（ロープ見た目）参照を取っておく（なくても動作はする）
	var scene_root: Node = get_tree().current_scene
	if scene_root:
		_arena_mat = scene_root.get_node_or_null("ArenaMat")
	if cam:
		if is_player_two:
			# 2P側のカメラは使わない（UIは1Pカメラのみ）
			cam.enabled = false
			cam.visible = false
		else:
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

## 2P用: SpriteFrames の 1P 画像を 2P 用（m_man_gr_l1 / m_man_gr_l2）に差し替え
func _apply_2p_sprite_frames() -> void:
	if not sprite or not sprite.sprite_frames:
		return
	var tex_gr_l1 := load("res://Art/Sprites/m_man_gr_l1.png") as Texture2D
	var tex_gr_l2 := load("res://Art/Sprites/m_man_gr_l2.png") as Texture2D
	if not tex_gr_l1 or not tex_gr_l2:
		return
	var sf := sprite.sprite_frames.duplicate()
	for anim_name in sf.get_animation_names():
		var fc: int = sf.get_frame_count(anim_name)
		for i in range(fc):
			var t: Texture2D = sf.get_frame_texture(anim_name, i)
			var dur: float = sf.get_frame_duration(anim_name, i)
			if t and t.resource_path:
				var new_tex: Texture2D = null
				if "m_man_g_l1" in t.resource_path:
					new_tex = tex_gr_l1
				elif "m_man_g_l2" in t.resource_path:
					new_tex = tex_gr_l2
				if new_tex:
					sf.set_frame(anim_name, i, new_tex, dur)
	sprite.sprite_frames = sf

func _process(delta: float):
	super(delta)
	# 敵との接触タイマー（接している間は2秒にリセット、離れたら減衰）
	var in_contact := false
	for node in get_tree().get_nodes_in_group("Enemy"):
		var e := node as CharacterBase
		if not e or e.is_dead:
			continue
		if global_position.distance_to(e.global_position) < BODY_CONTACT_HALF * 2.0:
			in_contact = true
			break
	if in_contact:
		_enemy_contact_timer = ENEMY_CONTACT_SPEED_SEC
	else:
		_enemy_contact_timer = maxf(0.0, _enemy_contact_timer - delta)
	# アニメ速度：走り中＝2倍速、敵接触直後＝2倍、飛んでいるとき＝4倍、それ以外＝1倍
	if sprite:
		var flying := is_jumping
		if fsm and fsm.current_state:
			var state_name: StringName = fsm.current_state.name
			flying = flying or state_name == "RopeLaunched" or state_name == "FireDash"
		if flying:
			sprite.speed_scale = 4.0
		elif is_run_dashing:
			sprite.speed_scale = 2.0  # 走り中はモーション2倍
		elif _enemy_contact_timer > 0.0:
			sprite.speed_scale = 2.0
		else:
			sprite.speed_scale = 1.0
	# グリッドモードトグルは1Pのみ（Gキー）
	if not is_player_two and Input.is_action_just_pressed("ToggleGridMove"):
		GameManager.use_grid_mode = not GameManager.use_grid_mode
		use_grid_movement = GameManager.use_grid_mode

	# 何か操作したらロープバウンス停止（方向キー・Mジャンプ・N走りで解除）
	if rope_bounce_running:
		var mv_left := "MoveLeft" if not is_player_two else "Move2Left"
		var mv_right := "MoveRight" if not is_player_two else "Move2Right"
		var mv_up := "MoveUp" if not is_player_two else "Move2Up"
		var mv_down := "MoveDown" if not is_player_two else "Move2Down"
		var jump_act := "Jump" if not is_player_two else "Jump2"
		var input := Input.get_vector(mv_left, mv_right, mv_up, mv_down)
		if input.length() > 0.1 or Input.is_action_just_pressed(jump_act) or Input.is_action_just_pressed("Dash"):
			rope_bounce_running = false
			rope_bounce_direction = Vector2.ZERO
	
	# カメラ完全固定（スクロール一切なし）
	if cam:
		cam.global_position = CAM_CENTER
	# 下側ロープの手前：地面にいるときだけキャラをロープより後ろに（z_index で制御）。飛んでるときはキャラ前面
	var flying := is_jumping
	if fsm and fsm.current_state:
		var state_name: StringName = fsm.current_state.name
		flying = flying or state_name == "RopeLaunched" or state_name == "FireDash"
	# 空中（ジャンプ・ロープ飛ばされ・炎ダッシュ）は地上より前面に描画
	if not flying and global_position.y >= 550:
		z_index = -10
	elif flying:
		z_index = 10
	else:
		z_index = 0
	# ジャンプ中はYクランプ・体当たりしない
	if not is_jumping:
		var p := global_position
		
		# ロープバウンス自動移動中（速度は歩きの約1.2倍程度に抑える）
		if rope_bounce_running:
			var move_speed := 480.0 * 2.0 / 1.2  # 約800（以前の2倍速を1.2で割った値）
			p += rope_bounce_direction * move_speed * delta
			# 目標到達チェック
			if rope_bounce_direction.x > 0 and p.x >= rope_bounce_target.x:
				p.x = rope_bounce_target.x
				rope_bounce_running = false
			elif rope_bounce_direction.x < 0 and p.x <= rope_bounce_target.x:
				p.x = rope_bounce_target.x
				rope_bounce_running = false
			elif rope_bounce_direction.y > 0 and p.y >= rope_bounce_target.y:
				p.y = rope_bounce_target.y
				rope_bounce_running = false
			elif rope_bounce_direction.y < 0 and p.y <= rope_bounce_target.y:
				p.y = rope_bounce_target.y
				rope_bounce_running = false
			global_position = p
			# ロープバウンス中は敵に当たる
			_body_contact(delta)
			return
		
		# 通常時：ロープ接触チェック（左右のみバネる）
		# 左ロープに触れたら右へ自動移動（ロープ位置ぴったりでバネる）
		if p.x <= MAT_LEFT:
			rope_bounce_running = true
			rope_bounce_direction = Vector2.RIGHT
			rope_bounce_target = Vector2(MAT_RIGHT, p.y)
			# ロープで跳ね返ったら進行方向（右）を向く
			_face_horizontal(rope_bounce_direction.x)
			_notify_rope_bounce("left")
		# 右ロープに触れたら左へ自動移動（ロープ位置ぴったりでバネる）
		elif p.x >= MAT_RIGHT:
			rope_bounce_running = true
			rope_bounce_direction = Vector2.LEFT
			rope_bounce_target = Vector2(MAT_LEFT, p.y)
			# ロープで跳ね返ったら進行方向（左）を向く
			_face_horizontal(rope_bounce_direction.x)
			_notify_rope_bounce("right")
		
		# 上下ロープは「走らない」ので、縦方向のバウンドは行わない
		# 左右ロープのみ：矯正速度を適用してからクランプ
		_rope_correction_velocity = _rope_correction_velocity.move_toward(Vector2.ZERO, ROPE_TOP_CORRECTION_DECAY * delta)
		p += _rope_correction_velocity * delta
		global_position = Vector2(clampf(p.x, MAT_LEFT, MAT_RIGHT), clampf(p.y, MAT_TOP, MAT_BOTTOM))
		var we = get_node_or_null("WindEffect")
		if we:
			we.visible = is_auto_running
		_body_contact(delta)
	else:
		# ジャンプ中はXだけマット内に
		var p := global_position
		global_position.x = clampf(p.x, MAT_LEFT, MAT_RIGHT)

## ロープバウンドなど、X方向の進行方向に合わせてスプライトの向きを変える
func _face_horizontal(dir_x: float) -> void:
	if not sprite:
		return
	var direction := -1 if flipped_horizontal == true else 1
	if dir_x < -0.1:
		sprite.scale.x = -direction * absf(sprite.scale.x)
	elif dir_x > 0.1:
		sprite.scale.x = direction * absf(sprite.scale.x)

## ロープヒットをアリーナマットに通知して、ロープ見た目をたわませる
func _notify_rope_bounce(side: String) -> void:
	if _arena_mat and _arena_mat.has_method("bend_rope"):
		_arena_mat.bend_rope(side)

## コーナーポストに触れたときに呼ばれる。大ジャンプ（通常ジャンプの長い版・回転あり）を即発動
func trigger_corner_post_jump() -> void:
	if is_dead or is_jumping:
		return
	on_corner_post = true
	fsm.force_change_state("Jump")

## ノックバックでロープ外に出たときに呼ばれる。反対側に放物線移動
func trigger_rope_launch() -> void:
	if is_dead:
		return
	fsm.force_change_state("RopeLaunched")

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

## かすりティーン終了時：マット外ならロープ飛ばし、内ならクランプ。スプライト回転をリセット
func _on_kasuri_tween_done(enemy_ref: CharacterBase, _new_player_pos: Vector2) -> void:
	if sprite and is_instance_valid(sprite):
		sprite.rotation_degrees = 0.0
	if _is_outside_mat(global_position):
		trigger_rope_launch()
		set_invincible_for(1.0)
	else:
		global_position = Vector2(clampf(global_position.x, MAT_LEFT, MAT_RIGHT), clampf(global_position.y, MAT_TOP, MAT_BOTTOM))
	if is_instance_valid(enemy_ref):
		if enemy_ref.sprite and is_instance_valid(enemy_ref.sprite):
			enemy_ref.sprite.rotation_degrees = 0.0
		if _is_outside_mat(enemy_ref.global_position) and enemy_ref.has_method("trigger_rope_launch"):
			enemy_ref.set_invincible_for(1.0)
			enemy_ref.trigger_rope_launch()

## 空中攻撃成功時：プレイヤーと敵を緑フラッシュ
func flash_aerial_hit(enemy: CharacterBase) -> void:
	_flash_modulate(sprite if sprite else self, Color(0.25, 1.0, 0.4, 1.0))
	_flash_modulate(enemy.sprite if enemy.sprite else enemy, Color(0.25, 1.0, 0.4, 1.0))

## 正面衝突でプレイヤーが食らったときの派手な白ぴかぴか
func _flash_white_body_contact() -> void:
	_flash_modulate(sprite if sprite else self, Color(2.0, 2.0, 2.0, 1.0))

## 体当たり用：指定色でフラッシュ。約1秒で必ず白に戻す（赤のまま残らないようにする）
func _flash_modulate(target: CanvasItem, flash_color: Color) -> void:
	if not target or not is_instance_valid(target):
		return
	var tween := create_tween()
	tween.set_parallel(false)
	tween.tween_property(target, "modulate", flash_color, 0.14)
	tween.tween_property(target, "modulate", Color.WHITE, 0.86)
	tween.tween_callback(func() -> void:
		if target and is_instance_valid(target):
			target.modulate = Color.WHITE
	)

## 体当たり：敵と触れたら必ずダメージ＋ノックバック。正方形コリジョン（PC-88風）。半キャラずらし＝敵方向に上下左右で移動＋接している部分が幅の半分以下のときは敵だけノックバック＆ダメージ
func _body_contact(delta: float) -> void:
	if is_dead:
		return
	# ジャンプ中は敵をすり抜ける（ロープには当たる）
	if is_jumping:
		return
	# 着地直後1フレームは体当たりをスキップ（ジャンプ着地で _land() が処理するので二重発火防止）
	if _just_landed_frame:
		_just_landed_frame = false
		return
	var mv_left := "MoveLeft" if not is_player_two else "Move2Left"
	var mv_right := "MoveRight" if not is_player_two else "Move2Right"
	var mv_up := "MoveUp" if not is_player_two else "Move2Up"
	var mv_down := "MoveDown" if not is_player_two else "Move2Down"
	var raw_input := Input.get_vector(mv_left, mv_right, mv_up, mv_down)
	var input_dir: Vector2 = raw_input.normalized() if raw_input.length() > 0.01 else Vector2.ZERO
	body_contact_cooldown -= delta
	_push_damage_timer -= delta
	var p_pos := global_position
	# どの敵とも触れていないときはクールダウンをリセット
	var in_contact := false
	for node in get_tree().get_nodes_in_group("Enemy"):
		var e := node as CharacterBase
		if not is_instance_valid(e) or e.is_dead:
			continue
		if e is EnemyMain and ((e as EnemyMain).is_ring_in_effect_only() or (e as EnemyMain).is_rope_launched()):
			continue
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
		if enemy is EnemyMain and ((enemy as EnemyMain).is_ring_in_effect_only() or (enemy as EnemyMain).is_rope_launched()):
			continue
		if not _aabb_overlap(p_pos, enemy.global_position, BODY_CONTACT_HALF + BODY_CONTACT_HALF_TOLERANCE):
			continue
		var to_enemy: Vector2 = (enemy.global_position - global_position).normalized()
		var e_pos: Vector2 = enemy.global_position
		# 敵方向に上下左右のいずれかを押している場合
		var is_cardinal: bool = absf(input_dir.x) < 0.01 or absf(input_dir.y) < 0.01
		var pressing_toward: bool = input_dir.length() > 0.3 and input_dir.dot(to_enemy) > 0.5
		var pressing_toward_ok: bool = is_cardinal and pressing_toward
		# ずれ：左右接近時はY差、上下接近時はX差。32未満＝正面、32〜58未満＝半キャラ、58〜64未満＝かすり、64以上＝当たってない
		var alignment_diff: float
		if absf(to_enemy.x) >= absf(to_enemy.y):
			alignment_diff = absf(p_pos.y - e_pos.y)
		else:
			alignment_diff = absf(p_pos.x - e_pos.x)
		if alignment_diff >= BODY_CONTACT_MAX_ALIGNMENT:
			continue
		var shoulder_ok: bool = pressing_toward_ok and alignment_diff >= HALF_OVERLAP_DIST and alignment_diff < SEMI_CAR_MAX
		var kasuri_ok: bool = pressing_toward_ok and alignment_diff >= SEMI_CAR_MAX and alignment_diff < BODY_CONTACT_MAX_ALIGNMENT
		if shoulder_ok:
			if GameManager.training_mode:
				GameManager.body_contact_type_text = "半キャラ"
				GameManager.body_contact_type_timer = 1.5
				var enemy_sprite: CanvasItem = enemy.sprite if enemy.sprite else enemy
				_flash_modulate(enemy_sprite, Color(2.0, 2.0, 2.0, 1.0))
			# ショルダータックル：ずれが多め＝敵だけノックバック＋ダメージ（0.2秒間隔）。下方向は暴発しないよう弱く
			if _push_damage_timer <= 0:
				_push_damage_timer = PUSH_DAMAGE_INTERVAL
				
				# ダメージ計算（コーナージャンプ特攻を含む）
				var damage: int = int(PUSH_DAMAGE_PER_TICK * fire_dash_damage_mult)
				# ステージ4: 異論マスク、コーナージャンプ特攻
				if GameManager.current_stage == 4 and leave_post_2x_jump:
					damage = 50  # 特攻ダメージ
					leave_post_2x_jump = false  # 1回だけ
				
				enemy._take_damage(damage)
				
				# 半キャラずらし：敵の方にエフェクトを出す（通常サイズ）
				if fire_dash_damage_mult > 1.5:
					AudioManager.play_sound(AudioManager.PLAYER_ATTACK_HIT, 0, 2)
				if enemy.hit_particles:
					enemy.hit_particles.amount = 20
					enemy.hit_particles.lifetime = 0.4  # 通常
					enemy.hit_particles.emitting = true
				
				# ノックバック量：ステージ4では超反動
				var knock_amount: float = PUSH_KNOCKBACK  # 60.0
				var player_push: float = 12.0
				
				# ステージ4: 異論マスクの超反動（150px）
				if GameManager.current_stage == 4 and "stage_number" in enemy and enemy.stage_number == 4:
					knock_amount = 150.0
				
				# 敵を押し飛ばす方向は「敵から離れる方向」（-to_enemy）。数フレームで動かし、その間無敵
				var knock: Vector2 = _axis_knockback(to_enemy, knock_amount)
				var new_enemy_pos: Vector2 = Vector2(e_pos.x + knock.x, e_pos.y + knock.y)
				var new_player_pos := global_position + _axis_knockback(-to_enemy, player_push)
				enemy.velocity = Vector2.ZERO
				enemy.knockback_stun_remaining = BODY_KNOCKBACK_TWEEN_DURATION + 0.05
				enemy.set_invincible_for(BODY_KNOCKBACK_TWEEN_DURATION + 0.1)
				set_invincible_for(BODY_KNOCKBACK_TWEEN_DURATION + 0.1)
				if _is_outside_mat(new_enemy_pos) and enemy.has_method("trigger_rope_launch"):
					enemy.set_invincible_for(1.5)
					enemy.trigger_rope_launch()
				else:
					var tw_e := enemy.create_tween()
					tw_e.tween_property(enemy, "global_position", new_enemy_pos, BODY_KNOCKBACK_TWEEN_DURATION)
					tw_e.tween_callback(_clamp_enemy_to_mat.bind(enemy))
				if _is_outside_mat(new_player_pos):
					set_invincible_for(1.5)
					trigger_rope_launch()
				else:
					var tw_p := create_tween()
					tw_p.tween_property(self, "global_position", new_player_pos, BODY_KNOCKBACK_TWEEN_DURATION)
					tw_p.tween_callback(func() -> void:
						global_position = Vector2(clampf(global_position.x, MAT_LEFT, MAT_RIGHT), clampf(global_position.y, MAT_TOP, MAT_BOTTOM))
					)
			break
		if kasuri_ok and body_contact_cooldown <= 0:
			# かすり：一方的にダメージ、両者斜めにすっ飛ばして離れる。繋がらない（クールダウンで連打防止）
			body_contact_cooldown = KASURI_COOLDOWN
			if GameManager.training_mode:
				GameManager.body_contact_type_text = "かすり"
				GameManager.body_contact_type_timer = 1.5
				_flash_modulate(sprite if sprite else self, Color(1.8, 1.8, 0.2, 1.0))
				_flash_modulate(enemy.sprite if enemy.sprite else enemy, Color(1.8, 1.8, 0.2, 1.0))
			var damage: int = int(PUSH_DAMAGE_PER_TICK * fire_dash_damage_mult)
			if GameManager.current_stage == 4 and leave_post_2x_jump:
				damage = 50
				leave_post_2x_jump = false
			enemy._take_damage(damage)
			if enemy.has_method("notify_graze_hit"):
				enemy.notify_graze_hit()
			if enemy.hit_particles:
				enemy.hit_particles.amount = 16
				enemy.hit_particles.lifetime = 0.3
				enemy.hit_particles.emitting = true
			# 斜めに一定距離移動＋縦軸回転（バレリーナのように）で遅く目立たせる
			var away: Vector2 = (-to_enemy) * KASURI_KNOCKBACK_DIAGONAL
			var new_player_pos := global_position + away
			var new_enemy_pos: Vector2 = Vector2(e_pos.x - away.x, e_pos.y - away.y)
			enemy.velocity = Vector2.ZERO
			enemy.knockback_stun_remaining = KASURI_TWEEN_DURATION + 0.1
			enemy.set_invincible_for(0.6)
			set_invincible_for(0.6)
			var player_sprite_node: Node = sprite if sprite else self
			var enemy_sprite_node: Node = enemy.sprite if enemy.sprite else enemy
			var spin_from_p: float = player_sprite_node.rotation_degrees
			var spin_from_e: float = enemy_sprite_node.rotation_degrees
			# プレイヤー：位置＋回転を一定時間でティーン
			var tw_p := create_tween()
			tw_p.set_parallel(true)
			tw_p.tween_property(self, "global_position", new_player_pos, KASURI_TWEEN_DURATION)
			tw_p.tween_property(player_sprite_node, "rotation_degrees", spin_from_p + KASURI_SPIN_DEGREES, KASURI_TWEEN_DURATION)
			tw_p.tween_callback(_on_kasuri_tween_done.bind(enemy, new_player_pos))
			# 敵：位置＋回転を同じ時間でティーン
			var tw_e := enemy.create_tween()
			tw_e.set_parallel(true)
			tw_e.tween_property(enemy, "global_position", new_enemy_pos, KASURI_TWEEN_DURATION)
			tw_e.tween_property(enemy_sprite_node, "rotation_degrees", spin_from_e + KASURI_SPIN_DEGREES, KASURI_TWEEN_DURATION)
			break
		# 正面（差が少なめ）または敵方向を押していない：両方ダメージ＋作用反作用で反対向きにノックバック（約3キャラ分・移動で飛ばす）
		if body_contact_cooldown <= 0:
			# ステージ3: ユニ帝仮面の正面無敵 + 反撃（正面側から当たったときだけ有効）
			var is_stage3_boss: bool = GameManager.current_stage == 3 and "stage_number" in enemy and enemy.stage_number == 3
			var stage3_front_guard := false
			if is_stage3_boss and "facing_dir_sign" in enemy:
				var boss_facing: int = enemy.facing_dir_sign
				if boss_facing != 0:
					# 敵→プレイヤーのX方向と facing が同じなら「正面側」にいる
					var enemy_to_player_x: float = global_position.x - enemy.global_position.x
					if absf(enemy_to_player_x) > 4.0 and signf(enemy_to_player_x) == float(boss_facing):
						stage3_front_guard = true
			
			if stage3_front_guard:
				# ユニ帝仮面の正面無敵：敵にダメージなし、プレイヤーに20ダメージ + 200px大ノックバック
				if GameManager.training_mode:
					GameManager.body_contact_type_text = "正面"
					GameManager.body_contact_type_timer = 1.5
					_flash_modulate(sprite if sprite else self, Color(2.0, 0.2, 0.2, 1.0))
					_flash_modulate(enemy.sprite if enemy.sprite else enemy, Color(2.0, 0.2, 0.2, 1.0))
				_take_damage(20)
				if not GameManager.training_mode:
					_flash_white_body_contact()
				
				# プレイヤーを大きく吹っ飛ばす（200px）。数フレームで動かしその間無敵
				var away: Vector2 = _axis_knockback(-to_enemy, 200.0)
				var new_player_pos := global_position + away
				set_invincible_for(BODY_KNOCKBACK_TWEEN_DURATION + 0.1)
				if _is_outside_mat(new_player_pos):
					set_invincible_for(1.5)
					trigger_rope_launch()
				else:
					var tw_p := create_tween()
					tw_p.tween_property(self, "global_position", new_player_pos, BODY_KNOCKBACK_TWEEN_DURATION)
					tw_p.tween_callback(func() -> void:
						global_position = Vector2(clampf(global_position.x, MAT_LEFT, MAT_RIGHT), clampf(global_position.y, MAT_TOP, MAT_BOTTOM))
					)
				
				body_contact_cooldown = BODY_CONTACT_INTERVAL
			else:
				# 通常の正面衝突
				var damage_to_enemy: int = int(BODY_DAMAGE_DEALT * fire_dash_damage_mult)
				
				# ステージ4: 異論マスク、コーナージャンプ特攻
				if GameManager.current_stage == 4 and leave_post_2x_jump:
					damage_to_enemy = 50
					leave_post_2x_jump = false
				
				enemy._take_damage(damage_to_enemy)
				_take_damage(int(BODY_DAMAGE_TAKEN * fire_dash_damage_taken_mult))
			
			# 正面衝突：血のエフェクトを2倍大きく、2倍長く
			if fire_dash_damage_mult > 1.5:
				AudioManager.play_sound(AudioManager.PLAYER_ATTACK_HIT, 0, 2)
				if enemy.hit_particles:
					enemy.hit_particles.amount = 40  # 2倍
					enemy.hit_particles.lifetime = 0.8  # 2倍長く
					enemy.hit_particles.emitting = true
			if fire_dash_damage_taken_mult > 1.5:
				AudioManager.play_sound(AudioManager.BLOODY_HIT, 0, 5)
				if hit_particles:
					hit_particles.amount = 40  # 2倍
					hit_particles.lifetime = 0.8  # 2倍長く
					hit_particles.emitting = true
			else:
				# 通常の正面衝突でも血のエフェクトを強く
				if enemy.hit_particles:
					enemy.hit_particles.amount = 40
					enemy.hit_particles.lifetime = 0.8
					enemy.hit_particles.emitting = true
				if hit_particles:
					hit_particles.amount = 40
					hit_particles.lifetime = 0.8
					hit_particles.emitting = true
				if GameManager.training_mode:
					GameManager.body_contact_type_text = "正面"
					GameManager.body_contact_type_timer = 1.5
					_flash_modulate(sprite if sprite else self, Color(2.0, 0.2, 0.2, 1.0))
					_flash_modulate(enemy.sprite if enemy.sprite else enemy, Color(2.0, 0.2, 0.2, 1.0))
				else:
					_flash_white_body_contact()
				
				var push_amount := BODY_PUSH_PIXELS_FRONTAL
				# ステージ4: 異論マスクの超反動（150px）
				if GameManager.current_stage == 4 and "stage_number" in enemy and enemy.stage_number == 4:
					push_amount = 150.0
				
				# プレイヤーと敵、両方が離れる方向に数フレームで押し飛ばす（その間無敵）
				var away: Vector2 = _axis_knockback(-to_enemy, push_amount)
				var new_player_pos := global_position + away
				var new_enemy_pos: Vector2 = Vector2(enemy.global_position.x - away.x, enemy.global_position.y - away.y)
				enemy.velocity = Vector2.ZERO
				enemy.knockback_stun_remaining = BODY_KNOCKBACK_TWEEN_DURATION + 0.05
				enemy.set_invincible_for(BODY_KNOCKBACK_TWEEN_DURATION + 0.1)
				set_invincible_for(BODY_KNOCKBACK_TWEEN_DURATION + 0.1)
				if _is_outside_mat(new_enemy_pos) and enemy.has_method("trigger_rope_launch"):
					enemy.set_invincible_for(1.5)
					enemy.trigger_rope_launch()
				else:
					var tw_e := enemy.create_tween()
					tw_e.tween_property(enemy, "global_position", new_enemy_pos, BODY_KNOCKBACK_TWEEN_DURATION)
					tw_e.tween_callback(_clamp_enemy_to_mat.bind(enemy))
				if _is_outside_mat(new_player_pos):
					set_invincible_for(1.5)
					trigger_rope_launch()
				else:
					var tw_p := create_tween()
					tw_p.tween_property(self, "global_position", new_player_pos, BODY_KNOCKBACK_TWEEN_DURATION)
					tw_p.tween_callback(func() -> void:
						global_position = Vector2(clampf(global_position.x, MAT_LEFT, MAT_RIGHT), clampf(global_position.y, MAT_TOP, MAT_BOTTOM))
					)
				body_contact_cooldown = BODY_CONTACT_INTERVAL
		break

func _is_outside_mat(pos: Vector2) -> bool:
	return pos.x < MAT_LEFT or pos.x > MAT_RIGHT or pos.y < MAT_TOP or pos.y > MAT_BOTTOM

func _clamp_enemy_to_mat(enemy_ref: CharacterBase) -> void:
	if is_instance_valid(enemy_ref):
		enemy_ref.global_position.x = clampf(enemy_ref.global_position.x, MAT_LEFT, MAT_RIGHT)
		enemy_ref.global_position.y = clampf(enemy_ref.global_position.y, MAT_TOP, MAT_BOTTOM)

func _die():
	super() #calls _die() on base-class CharacterBase
	
	fsm.force_change_state("Die")
	var death_scene = DEATH_SCREEN.instantiate()
	add_child(death_scene)
