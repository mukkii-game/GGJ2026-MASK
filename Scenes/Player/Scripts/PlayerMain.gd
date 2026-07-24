extends CharacterBase
class_name PlayerMain

@onready var fsm = $FSM as FiniteStateMachine
@onready var cam = $Camera2D
const DEATH_SCREEN = preload("res://Scenes/Misc/DeathScreen.tscn")
const FlashPikaPikaScript = preload("res://Scripts/FlashPikaPika.gd")

## マット内の移動範囲（ロープの位置ぴったりまで）
# ArenaMat.tscn の MatColor / RopeLeft / RopeRight に合わせる
# ロープの内側だけ行ける（上は背景ロープに食い込まないよう余裕、下ロープ上端=614）
const MAT_LEFT := 280   # 左ロープの内側端
const MAT_RIGHT := 1000 # 右ロープの内側端
const MAT_TOP := 138    # 上ロープ3本の下端よりさらに内側（奥行き見た目用）
const MAT_BOTTOM := 614 # 下ロープの内側（ロープより上）
## 通常時 collision_mask（layer1のみ。layer2=ロープ外壁は無効＝コードで跳ね返す）
const MAT_COLLISION_MASK := 1
## カメラ固定位置（画面中央＝マット中央）
const CAM_CENTER := Vector2(640, 360)

## 2Pかどうか（true=2P。入力と見た目を変える）
@export var is_player_two: bool = false
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
## ダウン敵連続ジャンプ（ジャンプ台）の段数。威力は同じで高さ・滞空・移動が伸びる
var trampoline_combo: int = 0
## 空中頭突き（P7）: 走行中にジャンプした瞬間の走行方向。JumpStateが消費（ZERO=通常ジャンプ）
var pending_headbutt_dir := Vector2.ZERO
## 着地した直後1フレームだけ体当たりをスキップ（ジャンプ着地時の二重発火防止）
var _just_landed_frame := false
## ロープダッシュ攻撃の与ダメ倍率（確定仕様P3: 威力より「速度と殴打回数」で差を付ける。走行系は連打間隔も半減）
const ROPE_DASH_DAMAGE_MULT := 1.25
## 弱り敵への正面ブラスト（確定仕様P5）: 一方的大ダメージ＋吹き飛ばし。ザコ級は即死＝場外へ
const WEAK_FRONTAL_DAMAGE := 40
## 強い敵に正面で当たったとき（確定仕様P9）: 敵は無傷、プレイヤーだけ食らって大きく弾かれる
const STRONG_FRONTAL_SELF_DAMAGE := 8
const STRONG_FRONTAL_KNOCKBACK := 160.0
## 向き規則（確定仕様P2）: 直近の移動方向。敵の方を向いていない接触は一方的被弾
var facing_dir := Vector2.RIGHT

## 敵からのダメージ（体当たり・敵攻撃）。パワーエサ効果中は無効
func take_damage_from_enemy(amount: int) -> void:
	if power_bait_enemy_damage_immune_until > 0.0:
		return
	_take_damage(amount)
## 体当たりダメージ用クールダウン（秒）
var body_contact_cooldown := 0.0
## 接した瞬間に食らうように間隔を短めに
const BODY_CONTACT_INTERVAL := 0.3
## 体当たりは正方形コリジョン（中心から±この値＝1辺64の箱、キャラ64x64に合わせる）
const BODY_CONTACT_HALF := 32.0
const BODY_CONTACT_HALF_TOLERANCE := 1.0
const BODY_DAMAGE_DEALT := 10
const BODY_DAMAGE_TAKEN := 8
## 正面衝突（両方ダメージ）時のノックバック＝キャラ約1.5人分・実際に移動で飛ばす
const BODY_PUSH_PIXELS_FRONTAL := 120.0
## 通常・半キャラのノックバックを数フレームで動かす時間（その間無敵）
const BODY_KNOCKBACK_TWEEN_DURATION := 0.2
## 半キャラずらし時：敵ノックバックを倍速（0.1秒で完了＝追撃しやすい）。プレイヤーはノックバック量を半分に
const BODY_KNOCKBACK_TWEEN_DURATION_HALFCAR := 0.1
const PUSH_PLAYER_KNOCKBACK_HALFCAR := 6.0
## 正面／半キャラの境：ずれが32未満＝正面、32以上＝半キャラ or かすり
const HALF_OVERLAP_DIST := 32.0
## 半キャラずらしの上限：ずれ 32〜58 未満＝半キャラ、58以上64未満＝かすり
## （旧52→58。かすり帯12pxを半分の6pxにし、その分を半キャラへ。上下も半キャラ可）
const SEMI_CAR_MAX := 58.0
## ずれ64以上＝当たってない（体当たり処理しない）
const BODY_CONTACT_MAX_ALIGNMENT := 64.0
## かすり時：斜めにすっ飛ばす距離（X,Y両方ずれて離れる方向・まあまあ大きく）
const KASURI_KNOCKBACK_DIAGONAL := 90.0
const KASURI_COOLDOWN := 0.4
## かすり：移動＋縦軸回転のティーン時間（バレリーナのように回転しながら飛ぶ）
const KASURI_TWEEN_DURATION := 0.28
const KASURI_SPIN_DEGREES := 720.0
## 半キャラずらし時：ノックバック量（キャラ1人分・連打で押し込み続けられる値）・連続ダメージ間隔・1回あたりダメージ
const PUSH_KNOCKBACK := 60.0
const PUSH_DAMAGE_INTERVAL := 0.2
const PUSH_DAMAGE_PER_TICK := 6
var _push_damage_timer := 0.0
## 敵と接したあとこの秒数だけモーション2倍速
var _enemy_contact_timer: float = 0.0
const ENEMY_CONTACT_SPEED_SEC := 2.0
## パワーエサ取得後：移動速度倍率（1.0＝通常、2.0＝2倍速）
var power_bait_speed_mult: float = 1.0
## パワーエサ速度アップの残り時間（秒）。0以下で power_bait_speed_mult を1に戻す
var power_bait_speed_until: float = 0.0
## パワーエサ「敵全員弱り」効果：敵からダメージを受けない残り時間（秒）
var power_bait_enemy_damage_immune_until: float = 0.0

## アリーナマット（ロープの見た目をたわませる用）
var _arena_mat: Node2D = null

## ジャンプ入力（1P: M/Space/Enter/左クリック※2Pモード時は左クリック無効、2P: 右クリック）
func wants_jump() -> bool:
	if is_player_two:
		return Input.is_action_just_pressed("Jump2")
	if Input.is_action_just_pressed("Jump") or Input.is_action_just_pressed("ui_accept"):
		return true
	if not GameManager.two_player_mode and Input.is_action_just_pressed("JumpClick1P"):
		return true
	return false

func _get_body_damage_mult() -> float:
	return ROPE_DASH_DAMAGE_MULT if rope_bounce_running else 1.0

func _get_push_damage_interval() -> float:
	# 走行中（ロープ往復・Nダッシュ）は連打間隔半減＝足の速さのぶん殴打回数が増える（P3）
	return PUSH_DAMAGE_INTERVAL * 0.5 if (rope_bounce_running or is_run_dashing) else PUSH_DAMAGE_INTERVAL

## ロープ／走行加速中は入力なしでも進行方向が敵方向なら「押している」扱い（半キャラ・かすり判定用）
func _is_pressing_toward_enemy(input_dir: Vector2, to_enemy: Vector2) -> bool:
	var is_cardinal: bool = absf(input_dir.x) < 0.01 or absf(input_dir.y) < 0.01
	if input_dir.length() > 0.3 and is_cardinal and input_dir.dot(to_enemy) > 0.5:
		return true
	var travel := Vector2.ZERO
	if rope_bounce_running:
		travel = rope_bounce_direction
	elif is_run_dashing and run_dash_direction.length_squared() > 0.01:
		travel = run_dash_direction
	elif is_auto_running and velocity.length_squared() > 100.0:
		travel = velocity
	if travel.length_squared() < 0.01:
		return false
	travel = travel.normalized()
	var travel_cardinal: bool = absf(travel.x) < 0.01 or absf(travel.y) < 0.01
	return travel_cardinal and travel.dot(to_enemy) > 0.5

func _is_boosted_body_hit(damage_mult: float) -> bool:
	return damage_mult > 1.5 or rope_bounce_running or is_run_dashing

func _play_shoulder_hit_sound(damage_mult: float) -> void:
	if is_dead:
		return
	var volume: float = 2.0 if _is_boosted_body_hit(damage_mult) else 0.0
	AudioManager.play_sound(AudioManager.PLAYER_ATTACK_HIT, 0, volume)

## 接触ヒットSEを必ず鳴らす（通常正面でも無音にしない）
func _play_contact_hit_sound(boosted: bool = false) -> void:
	if is_dead:
		return
	AudioManager.play_sound(AudioManager.PLAYER_ATTACK_HIT, 0, 2.0 if boosted else 0.0)
	if boosted or rope_bounce_running or is_run_dashing:
		AudioManager.play_sound(AudioManager.BLOODY_HIT, 0, -1)

func apply_power_bait_enemy_immune(duration_sec: float) -> void:
	power_bait_enemy_damage_immune_until = duration_sec

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
	# 一旦ロープ以外の背景コリジョン（ロープ外の壁）を無効化：layer1 のみ当たる
	collision_mask = MAT_COLLISION_MASK
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
				# _ready 中は親がセットアップ中で add_child が失敗するため遅延実行
				remove_child(cam)
				cam_root.add_child.call_deferred(cam)
				cam.set_deferred("global_position", CAM_CENTER)

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
	if is_dead:
		rope_bounce_running = false
		velocity = Vector2.ZERO
		return
	# パワーエサ速度アップの残り時間
	if power_bait_speed_until > 0.0:
		power_bait_speed_until -= delta
		if power_bait_speed_until <= 0.0:
			power_bait_speed_mult = 1.0
	# パワーエサ「敵からダメージ無効」の残り時間
	if power_bait_enemy_damage_immune_until > 0.0:
		power_bait_enemy_damage_immune_until -= delta
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
			flying = flying or state_name == "RopeLaunched"
		if flying:
			sprite.speed_scale = 4.0
		elif is_run_dashing:
			sprite.speed_scale = 2.0  # 走り中はモーション2倍
		elif _enemy_contact_timer > 0.0:
			sprite.speed_scale = 2.0
		else:
			sprite.speed_scale = 1.0

	# ロープバウンス中に「新しく」キーを押したときだけ停止
	if rope_bounce_running:
		var mv_left := "MoveLeft" if not is_player_two else "Move2Left"
		var mv_right := "MoveRight" if not is_player_two else "Move2Right"
		var mv_up := "MoveUp" if not is_player_two else "Move2Up"
		var mv_down := "MoveDown" if not is_player_two else "Move2Down"
		var jump_act := "Jump" if not is_player_two else "Jump2"
		var dash_act := "Dash" if not is_player_two else "Punch2"
		if Input.is_action_just_pressed(mv_left) or Input.is_action_just_pressed(mv_right) or Input.is_action_just_pressed(mv_up) or Input.is_action_just_pressed(mv_down) or Input.is_action_just_pressed(jump_act) or Input.is_action_just_pressed(dash_act):
			# ロープ走行中のジャンプ＝回避のみ（頭突き廃止）
			if Input.is_action_just_pressed(jump_act) and rope_bounce_direction.length() > 0.1:
				pending_headbutt_dir = Vector2.ZERO
			rope_bounce_running = false
			rope_bounce_direction = Vector2.ZERO
	
	# カメラ完全固定（スクロール一切なし）
	if cam:
		cam.global_position = CAM_CENTER
	# ジャンプ中はXだけマット内に（Yクランプ・体当たり・ロープバウンスは _physics_process で処理）
	if is_jumping:
		var p := global_position
		global_position.x = clampf(p.x, MAT_LEFT, MAT_RIGHT)
	# 描画順は CharacterBase.update_draw_priority（足元Yのみ）
	var we = get_node_or_null("WindEffect")
	if we:
		we.visible = is_auto_running

## ジャンプ／ロープ飛ばされ中は空中として手前に
func is_airborne_for_draw() -> bool:
	if is_jumping:
		return true
	if fsm and fsm.current_state:
		var sn: StringName = fsm.current_state.name
		if sn == "RopeLaunched" or sn == "Jump":
			return true
	return false


func _physics_process(delta: float) -> void:
	# 死亡後はロープ往復・体当たりを一切しない（影の残留走り防止）
	if is_dead:
		rope_bounce_running = false
		velocity = Vector2.ZERO
		return
	# is_jumping フラグ残留対策（deferred Exit 等でステートとズレた場合）
	if is_jumping and fsm and fsm.current_state:
		var sn := String(fsm.current_state.name)
		if sn != "Jump" and sn != "RopeLaunched":
			is_jumping = false
			collision_mask = MAT_COLLISION_MASK
	# ロープ跳ね返り・マット内クランプは移動の後に実行（SubViewport でも確実に動く）
	if is_jumping:
		return
	var p := global_position
	# ロープバウンス自動移動中（パワーエサ2倍速で逆方向に歩いても必ず跳ね返るよう、余裕で上回る速度に）
	if rope_bounce_running:
		var base_speed := 480.0 * 2.0 / 1.2
		var move_speed := maxf(base_speed, 480.0 * power_bait_speed_mult * 2.2)
		p += rope_bounce_direction * move_speed * delta
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
		_body_contact(delta)
		return
	# 通常時：ロープ接触チェック（プレイヤーは左右のみ。上下はクランプ）
	if p.x <= MAT_LEFT:
		rope_bounce_running = true
		rope_bounce_direction = Vector2.RIGHT
		rope_bounce_target = Vector2(MAT_RIGHT, p.y)
		facing_dir = rope_bounce_direction
		_face_horizontal(rope_bounce_direction.x)
		_notify_rope_bounce("left")
	elif p.x >= MAT_RIGHT:
		rope_bounce_running = true
		rope_bounce_direction = Vector2.LEFT
		rope_bounce_target = Vector2(MAT_LEFT, p.y)
		facing_dir = rope_bounce_direction
		_face_horizontal(rope_bounce_direction.x)
		_notify_rope_bounce("right")
	if rope_bounce_running:
		# ロープ跳ね返り開始時: かすり回転などの移動系Tweenを止め、逆さ向きのまま走るのを防ぐ
		kill_motion_tweens()
		if sprite and is_instance_valid(sprite):
			sprite.rotation_degrees = 0.0
			_face_horizontal(rope_bounce_direction.x)
	global_position = Vector2(clampf(p.x, MAT_LEFT, MAT_RIGHT), clampf(p.y, MAT_TOP, MAT_BOTTOM))
	_body_contact(delta)

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

## 体当たり用：指定色でフラッシュ。hold_at_peak でその色のまま維持する秒数（0で従来どおり）。
## 終了色は target の所有者に応じて復元（ダウン中の敵を真っ白にしない）
func _flash_modulate(target: CanvasItem, flash_color: Color, hold_at_peak: float = 0.0) -> void:
	if not target or not is_instance_valid(target):
		return
	var tween := create_tween()
	tween.set_parallel(false)
	tween.tween_property(target, "modulate", flash_color, 0.12)
	if hold_at_peak > 0.0:
		tween.tween_interval(hold_at_peak)
	var restore := _flash_restore_modulate_for(target)
	tween.tween_property(target, "modulate", restore, 0.35)
	tween.tween_callback(func() -> void:
		if target and is_instance_valid(target):
			target.modulate = _flash_restore_modulate_for(target)
	)

func _flash_restore_modulate_for(target: CanvasItem) -> Color:
	var owner_n := target.get_parent()
	while owner_n and not (owner_n is CharacterBase):
		owner_n = owner_n.get_parent()
	if owner_n is EnemyMain:
		var em := owner_n as EnemyMain
		if em.is_in_down_state():
			return Color(1.4, 0.4, 0.4, 1.0)
		if "body_tint" in em:
			return em.body_tint
	return Color.WHITE

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
	# 向き規則（P2）用: 直近の移動方向を facing_dir として保持（走行中は進行方向を優先）
	if rope_bounce_running and rope_bounce_direction.length() > 0.1:
		facing_dir = rope_bounce_direction
	elif is_run_dashing and run_dash_direction.length() > 0.1:
		facing_dir = run_dash_direction.normalized()
	elif input_dir.length() > 0.1:
		facing_dir = input_dir
	body_contact_cooldown -= delta
	_push_damage_timer -= delta
	var p_pos := global_position
	# どの敵とも触れていないときはクールダウンをリセット
	var in_contact := false
	for node in get_tree().get_nodes_in_group("Enemy"):
		var e := node as CharacterBase
		if not is_instance_valid(e) or e.is_dead:
			continue
		if e is EnemyMain and ((e as EnemyMain).is_ring_in_effect_only() or (e as EnemyMain).is_rope_launched() or (e as EnemyMain).is_in_down_state() or (e as EnemyMain).is_perched or (e as EnemyMain).is_top_rope_aerial):
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
		# ダウン（寝）中・吹き飛ばされ中（空中）・ポスト上待機中の敵は体当たり対象外
		if enemy is EnemyMain and ((enemy as EnemyMain).is_ring_in_effect_only() or (enemy as EnemyMain).is_rope_launched() or (enemy as EnemyMain).is_in_down_state() or (enemy as EnemyMain)._aerial_knockback_animating or (enemy as EnemyMain).is_perched or (enemy as EnemyMain).is_top_rope_aerial):
			continue
		if not _aabb_overlap(p_pos, enemy.global_position, BODY_CONTACT_HALF + BODY_CONTACT_HALF_TOLERANCE):
			continue
		var to_enemy: Vector2 = (enemy.global_position - global_position).normalized()
		var e_pos: Vector2 = enemy.global_position
		# 敵方向に上下左右のいずれかを押している場合（ロープ／走行加速中は進行方向で代用）
		var pressing_toward_ok: bool = _is_pressing_toward_enemy(input_dir, to_enemy)
		# ずれ：左右接近時はY差、上下接近時はX差
		var horizontal_approach: bool = absf(to_enemy.x) >= absf(to_enemy.y)
		var alignment_diff: float
		if horizontal_approach:
			alignment_diff = absf(p_pos.y - e_pos.y)
		else:
			alignment_diff = absf(p_pos.x - e_pos.x)
		if alignment_diff >= BODY_CONTACT_MAX_ALIGNMENT:
			continue
		# 半キャラ: 上下左右とも 32〜58。かすり帯は端の6pxのみ（旧は左右のみ半キャラ・上下は全部かすりで出やすすぎた）
		var shoulder_ok: bool = pressing_toward_ok and alignment_diff >= HALF_OVERLAP_DIST and alignment_diff < SEMI_CAR_MAX
		var kasuri_ok: bool = pressing_toward_ok and alignment_diff >= SEMI_CAR_MAX and alignment_diff < BODY_CONTACT_MAX_ALIGNMENT
		# 敵状態の参照（Angry=強い: 半キャラ・正面とも弾かれる / Weak=弱り: 正面で吹き飛ばし）
		var enemy_angry: bool = enemy is EnemyMain and (enemy as EnemyMain).is_shoulder_immune()
		var enemy_weak: bool = enemy is EnemyMain and (enemy as EnemyMain).is_weak_state()
		var em := enemy as EnemyMain
		# ボスのロープ走行中（強い状態・確定仕様）: どんな接触でも一方的にやられる。
		# 唯一の対抗手段＝直角カウンター: 走行軸と直角方向から敵へ押しながら当てると弾き飛ばしダウン＋強化解除
		if em and em.rope_running:
			var perpendicular_approach: bool = (horizontal_approach != em.rope_run_horizontal)
			if perpendicular_approach and pressing_toward_ok:
				# 直角カウンター成功（マタドール）
				if GameManager.training_mode:
					GameManager.body_contact_type_text = "直角カウンター！"
					GameManager.body_contact_type_timer = 1.5
				AudioManager.play_sound(AudioManager.BLOODY_HIT, 0, -1)
				GameManager.show_callout(em, "カウンター！", Color(0.4, 1.0, 0.5, 1.0))
				em.stop_rope_run()
				em._take_damage(int(BODY_DAMAGE_DEALT * 1.5))
				flash_aerial_hit(em)
				if not em.is_dead and em.health > 0:
					em.blast_to_down(to_enemy)
				set_invincible_for(0.5)
				body_contact_cooldown = BODY_CONTACT_INTERVAL
			elif body_contact_cooldown <= 0:
				# 轢かれた: 一方的被弾＋大きく弾かれる
				if GameManager.training_mode:
					GameManager.body_contact_type_text = "轢かれた！(走行ボス)"
					GameManager.body_contact_type_timer = 1.5
				take_damage_from_enemy(12)
				_flash_white_body_contact()
				var away_run: Vector2 = _axis_knockback(-to_enemy, STRONG_FRONTAL_KNOCKBACK)
				var run_hit_pos := global_position + away_run
				set_invincible_for(BODY_KNOCKBACK_TWEEN_DURATION + 0.3)
				if _is_outside_mat(run_hit_pos):
					set_invincible_for(1.5)
					trigger_rope_launch()
				else:
					var tw_hit := create_tween()
					tw_hit.tween_property(self, "global_position", run_hit_pos, BODY_KNOCKBACK_TWEEN_DURATION)
					tw_hit.tween_callback(func() -> void:
						global_position = Vector2(clampf(global_position.x, MAT_LEFT, MAT_RIGHT), clampf(global_position.y, MAT_TOP, MAT_BOTTOM))
					)
					register_motion_tween(tw_hit)
				body_contact_cooldown = BODY_CONTACT_INTERVAL
			break
		if shoulder_ok:
			# 怒り中は後ろ半キャラのみ有効。それ以外の半キャラは逆に被ダメ
			if enemy_angry and em and not em.is_rear_approach_from(p_pos):
				if GameManager.training_mode:
					GameManager.body_contact_type_text = "怒り半キャラ逆ダメ！"
					GameManager.body_contact_type_timer = 1.5
				if _push_damage_timer <= 0:
					_push_damage_timer = _get_push_damage_interval()
					take_damage_from_enemy(STRONG_FRONTAL_SELF_DAMAGE)
					_flash_white_body_contact()
					var repel: Vector2 = _axis_knockback(-to_enemy, PUSH_KNOCKBACK)
					var repel_pos := global_position + repel
					set_invincible_for(BODY_KNOCKBACK_TWEEN_DURATION_HALFCAR + 0.2)
					if _is_outside_mat(repel_pos):
						set_invincible_for(1.5)
						trigger_rope_launch()
					else:
						var tw_rp := create_tween()
						tw_rp.tween_property(self, "global_position", repel_pos, BODY_KNOCKBACK_TWEEN_DURATION_HALFCAR)
						tw_rp.tween_callback(func() -> void:
							global_position = Vector2(clampf(global_position.x, MAT_LEFT, MAT_RIGHT), clampf(global_position.y, MAT_TOP, MAT_BOTTOM))
						)
						register_motion_tween(tw_rp)
				break
			if GameManager.training_mode:
				if rope_bounce_running:
					GameManager.body_contact_type_text = "ロープ(半キャラ)"
				elif enemy_angry:
					GameManager.body_contact_type_text = "後ろ半キャラ！"
				else:
					GameManager.body_contact_type_text = "弱り(半キャラ)" if enemy_weak else "半キャラ"
				GameManager.body_contact_type_timer = 1.5
			# 半キャラずらし＝白エフェクト
			var flash_tex: Texture2D = enemy.get("flash_effect_white_texture") as Texture2D
			if flash_tex and (enemy.sprite or enemy):
				var flash: Node2D = FlashPikaPikaScript.new()
				flash.call("setup", flash_tex)
				var parent: Node2D = enemy.sprite if enemy.sprite else enemy
				parent.add_child(flash)
				flash.call("start")
			else:
				enemy.halfcar_white_until = Time.get_ticks_msec() / 1000.0 + 1.0
			if _push_damage_timer <= 0:
				var push_interval: float = _get_push_damage_interval()
				_push_damage_timer = push_interval
				GameManager.notify_stage1_shoulder_tackle()
				var damage_mult: float = _get_body_damage_mult()
				var damage: int = int(PUSH_DAMAGE_PER_TICK * damage_mult)
				var dealt: bool = enemy.apply_repeat_contact_damage(damage, push_interval * 0.95)
				if dealt and em:
					em.notify_halfcar_hit()
				_play_shoulder_hit_sound(damage_mult)
				if enemy.hit_particles:
					if _is_boosted_body_hit(damage_mult):
						enemy.hit_particles.amount = 40
						enemy.hit_particles.lifetime = 0.8
					else:
						enemy.hit_particles.amount = 20
						enemy.hit_particles.lifetime = 0.4
					enemy.hit_particles.emitting = true
				var knock_amount: float = PUSH_KNOCKBACK
				var player_push: float = PUSH_PLAYER_KNOCKBACK_HALFCAR
				var tween_dur: float = BODY_KNOCKBACK_TWEEN_DURATION_HALFCAR
				if GameManager.current_stage == 4 and "stage_number" in enemy and enemy.stage_number == 4:
					knock_amount = 90.0
				var knock: Vector2 = _axis_knockback(to_enemy, knock_amount)
				var new_enemy_pos: Vector2 = Vector2(e_pos.x + knock.x, e_pos.y + knock.y)
				var new_player_pos := global_position + _axis_knockback(-to_enemy, player_push)
				enemy.velocity = Vector2.ZERO
				enemy.knockback_stun_remaining = 1.15
				set_invincible_for(tween_dur + 0.1)
				if _is_outside_mat(new_enemy_pos) and enemy.has_method("trigger_rope_launch"):
					enemy.set_invincible_for(1.5)
					enemy.trigger_rope_launch()
				else:
					var tw_e := enemy.create_tween()
					tw_e.tween_property(enemy, "global_position", new_enemy_pos, tween_dur)
					tw_e.tween_callback(_clamp_enemy_to_mat.bind(enemy))
					enemy.register_motion_tween(tw_e)
				if _is_outside_mat(new_player_pos):
					set_invincible_for(1.5)
					trigger_rope_launch()
				else:
					var tw_p := create_tween()
					tw_p.tween_property(self, "global_position", new_player_pos, tween_dur)
					tw_p.tween_callback(func() -> void:
						global_position = Vector2(clampf(global_position.x, MAT_LEFT, MAT_RIGHT), clampf(global_position.y, MAT_TOP, MAT_BOTTOM))
					)
					register_motion_tween(tw_p)
			break
		if kasuri_ok and body_contact_cooldown <= 0:
			# かすり：両者スピン。敵は5秒ダウン（notify_graze_hit）
			body_contact_cooldown = KASURI_COOLDOWN
			if GameManager.training_mode:
				if rope_bounce_running:
					GameManager.body_contact_type_text = "ロープ(かすり)"
				else:
					GameManager.body_contact_type_text = "かすりダウン"
				GameManager.body_contact_type_timer = 1.5
			# かすり＝黄フラッシュ（敵のみ・プレイヤーはダメージなしなので光らせない）。黄を少し長く維持
			var enemy_sprite_kasuri: CanvasItem = enemy.sprite if enemy.sprite else enemy
			_flash_modulate(enemy_sprite_kasuri, Color(1.8, 1.8, 0.2, 1.0), 0.56)
			var damage_mult: float = _get_body_damage_mult()
			var damage: int = int(PUSH_DAMAGE_PER_TICK * damage_mult)
			enemy._take_damage(damage)
			if enemy.has_method("notify_graze_hit"):
				enemy.notify_graze_hit()
			_play_contact_hit_sound(_is_boosted_body_hit(damage_mult))
			if enemy.hit_particles:
				if _is_boosted_body_hit(damage_mult):
					enemy.hit_particles.amount = 40
					enemy.hit_particles.lifetime = 0.8
				else:
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
			register_motion_tween(tw_p)
			# 敵：位置＋回転を同じ時間でティーン
			var tw_e := enemy.create_tween()
			tw_e.set_parallel(true)
			tw_e.tween_property(enemy, "global_position", new_enemy_pos, KASURI_TWEEN_DURATION)
			tw_e.tween_property(enemy_sprite_node, "rotation_degrees", spin_from_e + KASURI_SPIN_DEGREES, KASURI_TWEEN_DURATION)
			tw_e.chain().tween_callback(_clamp_enemy_to_mat.bind(enemy))  # KI-20: かすりトドメ時のドリフト防止
			enemy.register_motion_tween(tw_e)
			break
		# 正面など（半キャラ・かすり以外の接触）: 敵状態と向きで分岐
		if body_contact_cooldown <= 0:
			# ステージ3: ユニ帝仮面の正面無敵 + 反撃（正面側から当たったときだけ有効。弱り中は無効）
			var is_stage3_boss: bool = GameManager.current_stage == 3 and "stage_number" in enemy and enemy.stage_number == 3
			var stage3_front_guard := false
			if is_stage3_boss and not enemy_weak and "facing_dir_sign" in enemy:
				var boss_facing: int = enemy.facing_dir_sign
				if boss_facing != 0:
					# 敵→プレイヤーのX方向と facing が同じなら「正面側」にいる
					var enemy_to_player_x: float = global_position.x - enemy.global_position.x
					if absf(enemy_to_player_x) > 4.0 and signf(enemy_to_player_x) == float(boss_facing):
						stage3_front_guard = true
			# 向き規則（P2）: 敵方向を押しているか、facingが敵向きなら「向いている」
			var facing_enemy: bool = pressing_toward_ok or facing_dir.dot(to_enemy) > 0.5

			if enemy_weak:
				# 弱り正面ブラスト（P5）: 一方的大ダメージ＋吹き飛ばし。プレイヤーは無傷。
				# ザコ級は即死＝場外へ吹っ飛ぶ。耐えた敵はリング内に落ちてダウン
				if not enemy.invincible:
					if GameManager.training_mode:
						GameManager.body_contact_type_text = "正面ブラスト！"
						GameManager.body_contact_type_timer = 1.5
					var blast_mult: float = _get_body_damage_mult()
					var blast_dir: Vector2 = _axis_knockback(to_enemy, 1.0)
					enemy._take_damage(int(WEAK_FRONTAL_DAMAGE * blast_mult))
					AudioManager.play_sound(AudioManager.BLOODY_HIT, 0, -1)
					AudioManager.play_sound(AudioManager.PLAYER_ATTACK_HIT, 0, 2)
					if enemy.hit_particles:
						enemy.hit_particles.amount = 60
						enemy.hit_particles.lifetime = 1.0
						enemy.hit_particles.emitting = true
					_flash_modulate(enemy.sprite if enemy.sprite else enemy, Color(2.0, 1.6, 0.3, 1.0))
					if em:
						if enemy.is_dead:
							em.fly_out_visual(blast_dir)
						elif enemy.health > 0:
							GameManager.show_callout(enemy, "ブラスト！")
							em.blast_to_down(blast_dir)
					body_contact_cooldown = BODY_CONTACT_INTERVAL
			elif stage3_front_guard:
				# ユニ帝仮面の正面無敵：敵にダメージなし、プレイヤーに20ダメージ + 200px大ノックバック
				if GameManager.training_mode:
					GameManager.body_contact_type_text = "正面"
					GameManager.body_contact_type_timer = 1.5
					_flash_modulate(sprite if sprite else self, Color(2.0, 0.2, 0.2, 1.0))
				take_damage_from_enemy(20)
				if not GameManager.training_mode:
					_flash_white_body_contact()
				# ボス側には「ガードされた」ことが伝わる青白フラッシュを常に出す（トレーニング/本番問わず・ダメージの赤と区別）
				_flash_modulate(enemy.sprite if enemy.sprite else enemy, Color(0.7, 0.9, 2.0, 1.0))
				
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
					register_motion_tween(tw_p)
				
				body_contact_cooldown = BODY_CONTACT_INTERVAL
			elif enemy_angry:
				# 強い敵に正面（P9）: 敵は無傷、プレイヤーだけ食らって大きく弾かれる
				if GameManager.training_mode:
					GameManager.body_contact_type_text = "正面無効(強い)"
					GameManager.body_contact_type_timer = 1.5
				take_damage_from_enemy(STRONG_FRONTAL_SELF_DAMAGE)
				_flash_white_body_contact()
				_flash_modulate(enemy.sprite if enemy.sprite else enemy, Color(0.7, 0.9, 2.0, 1.0))
				var away_strong: Vector2 = _axis_knockback(-to_enemy, STRONG_FRONTAL_KNOCKBACK)
				var strong_hit_pos := global_position + away_strong
				set_invincible_for(BODY_KNOCKBACK_TWEEN_DURATION + 0.3)
				if _is_outside_mat(strong_hit_pos):
					set_invincible_for(1.5)
					trigger_rope_launch()
				else:
					var tw_st := create_tween()
					tw_st.tween_property(self, "global_position", strong_hit_pos, BODY_KNOCKBACK_TWEEN_DURATION)
					tw_st.tween_callback(func() -> void:
						global_position = Vector2(clampf(global_position.x, MAT_LEFT, MAT_RIGHT), clampf(global_position.y, MAT_TOP, MAT_BOTTOM))
					)
					register_motion_tween(tw_st)
				body_contact_cooldown = BODY_CONTACT_INTERVAL
			elif not facing_enemy:
				# 向き規則（P2）: 敵の方を向いていない接触＝一方的被弾（正面位置でも）。敵は無傷
				if GameManager.training_mode:
					GameManager.body_contact_type_text = "背面被弾！"
					GameManager.body_contact_type_timer = 1.5
				var back_dmg_mult: float = em.state_damage_mult() if em else 1.0
				take_damage_from_enemy(int(BODY_DAMAGE_TAKEN * back_dmg_mult))
				_flash_white_body_contact()
				# プレイヤーだけ押し飛ばされる（敵はその場・軽く離すのみ）
				var away_back: Vector2 = _axis_knockback(-to_enemy, BODY_PUSH_PIXELS_FRONTAL)
				var back_hit_pos := global_position + away_back
				enemy.velocity = Vector2.ZERO
				enemy.knockback_stun_remaining = BODY_KNOCKBACK_TWEEN_DURATION + 0.05
				set_invincible_for(BODY_KNOCKBACK_TWEEN_DURATION + 0.3)
				if _is_outside_mat(back_hit_pos):
					set_invincible_for(1.5)
					trigger_rope_launch()
				elif not rope_bounce_running:
					var tw_bk := create_tween()
					tw_bk.tween_property(self, "global_position", back_hit_pos, BODY_KNOCKBACK_TWEEN_DURATION)
					tw_bk.tween_callback(func() -> void:
						global_position = Vector2(clampf(global_position.x, MAT_LEFT, MAT_RIGHT), clampf(global_position.y, MAT_TOP, MAT_BOTTOM))
					)
					register_motion_tween(tw_bk)
				body_contact_cooldown = BODY_CONTACT_INTERVAL
			else:
				# 通常の正面衝突（KI: 誤学習防止ヒントの累計カウントはステージ1・本番プレイのみ）
				GameManager.notify_stage1_front_collision()
				var damage_mult: float = _get_body_damage_mult()
				var damage_to_enemy: int = int(BODY_DAMAGE_DEALT * damage_mult)

				enemy._take_damage(damage_to_enemy)
				take_damage_from_enemy(BODY_DAMAGE_TAKEN)
				
				# 正面衝突：常にヒットSE（通常正面でも無音にしない）
				var boosted_frontal: bool = _is_boosted_body_hit(damage_mult)
				_play_contact_hit_sound(boosted_frontal)
				if enemy.hit_particles:
					enemy.hit_particles.amount = 40
					enemy.hit_particles.lifetime = 0.8
					enemy.hit_particles.emitting = true
				if hit_particles:
					hit_particles.amount = 40
					hit_particles.lifetime = 0.8
					hit_particles.emitting = true
				if GameManager.training_mode:
					GameManager.body_contact_type_text = "ロープ(正面)" if rope_bounce_running else "正面"
					GameManager.body_contact_type_timer = 1.5
				# 正面衝突＝赤フラッシュ（プレイヤー・敵とも常に。危険・両方ダメージのイメージ）
				_flash_modulate(sprite if sprite else self, Color(2.0, 0.2, 0.2, 1.0))
				_flash_modulate(enemy.sprite if enemy.sprite else enemy, Color(2.0, 0.2, 0.2, 1.0))
				
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
					enemy.register_motion_tween(tw_e)
				if _is_outside_mat(new_player_pos):
					set_invincible_for(1.5)
					trigger_rope_launch()
				elif not rope_bounce_running:
					# ロープ自動走行中は毎フレーム位置上書きのためプレイヤーTweenはスキップ
					var tw_p := create_tween()
					tw_p.tween_property(self, "global_position", new_player_pos, BODY_KNOCKBACK_TWEEN_DURATION)
					tw_p.tween_callback(func() -> void:
						global_position = Vector2(clampf(global_position.x, MAT_LEFT, MAT_RIGHT), clampf(global_position.y, MAT_TOP, MAT_BOTTOM))
					)
					register_motion_tween(tw_p)
				body_contact_cooldown = BODY_CONTACT_INTERVAL
		break

func _is_outside_mat(pos: Vector2) -> bool:
	return pos.x < MAT_LEFT or pos.x > MAT_RIGHT or pos.y < MAT_TOP or pos.y > MAT_BOTTOM

func _clamp_enemy_to_mat(enemy_ref: CharacterBase) -> void:
	if is_instance_valid(enemy_ref):
		enemy_ref.global_position.x = clampf(enemy_ref.global_position.x, MAT_LEFT, MAT_RIGHT)
		enemy_ref.global_position.y = clampf(enemy_ref.global_position.y, MAT_TOP, MAT_BOTTOM)

func _die():
	# ロープ往復・走り・接触を即停止（影だけ走り続けるバグ対策）
	_stop_all_motion_on_death()
	# ゲームオーバー中はバトルを止める（敵は待機モーションのみ）＋SE全停止
	GameManager.freeze_battle_for_game_over()
	super() #calls _die() on base-class CharacterBase
	
	fsm.force_change_state("Die")
	var death_scene = DEATH_SCREEN.instantiate()
	add_child(death_scene)

## 死亡時: ロープバウンス等の残留動作と足元エフェクトを止める
func _stop_all_motion_on_death() -> void:
	rope_bounce_running = false
	rope_bounce_direction = Vector2.ZERO
	is_auto_running = false
	is_run_dashing = false
	run_dash_direction = Vector2.ZERO
	start_auto_run = false
	is_jumping = false
	trampoline_combo = 0
	velocity = Vector2.ZERO
	kill_motion_tweens()
	# 影（本体位置）が敵に当たり続けないようコリジョンも切る
	collision_layer = 0
	collision_mask = 0
	var body_shape := get_node_or_null("BodyCollisionShape") as CollisionShape2D
	if body_shape:
		body_shape.disabled = true
	var we := get_node_or_null("WindEffect")
	if we:
		we.visible = false
	var shadow := get_node_or_null("FootShadow")
	if shadow:
		shadow.visible = false
	var smoke := get_node_or_null("FeetSmoke")
	if smoke:
		smoke.visible = false
	var spiral := get_node_or_null("FeetSpiral")
	if spiral:
		spiral.visible = false
