extends CharacterBase
class_name EnemyMain

## 静止・上下ループ・左右ループ・一定範囲ランダム・逃走の5種
enum Behavior { Idle, VerticalLoop, HorizontalLoop, RandomRange, Flee }

## 敵の状態（攻略性向上）：通常・怒り・弱り
enum EnemyState { Normal, Angry, Weak }

## 敵同士が重ならないよう、かさなったらずらす用（マット内）
const MAT_LEFT := 296.0
const MAT_RIGHT := 984.0
const MAT_TOP := 106.0
const MAT_BOTTOM := 614.0
const BODY_HALF := 32.0

@onready var fsm = $FSM as FiniteStateMachine
var player_in_range = false
## 突進攻撃時ダメージ倍率（1.0＝通常）
var charge_damage_mult := 1.0
## Patrol状態で上下=true／左右=false（VerticalLoop / HorizontalLoop 用）
var patrol_vertical := false
## ロープ間往復用：>0 のとき Patrol の patrol_distance として使用
var patrol_distance_override: float = 0.0
## ロープ間往復用：>0 のとき Patrol の move_speed として使用（プレイヤーより少し遅い程度）
var patrol_speed_override: float = 0.0

## 向いている左右（1=右, -1=左）。Turn() で更新。
var facing_dir_sign: int = 1
## Turn() 内で使う経過時間（ステージ3ボスの左右反転ディレイ用）
var _turn_delta: float = 0.0
var _boss_flip_timer: float = 0.0
const BOSS3_FLIP_DELAY := 1.0

@export var behavior_type: Behavior = Behavior.Idle
@export var attack_node : Node
@export var chase_node : Node

## ステージ番号（特殊処理用）
var stage_number: int = 1
## ボスキャラか（特殊行動用）
var is_boss: bool = false
## トレーニング用ダミー（動かず攻撃しない・プレイヤー検知でチェースに移行しない）
var is_training_dummy: bool = false
## ダウン状態で開始（動かず攻撃せず・赤フラッシュのまま。移行条件は後でアルゴリズム）
var is_down: bool = false
## リングイン着地目標（スポーン時に設定すると右端から走り込み→山なりジャンプでここに着地）
var ring_in_landing_pos: Vector2 = Vector2.ZERO
## 敵の状態（通常／怒り／弱り）。トレーニングダミーはスポーン時に固定され変動しない
var enemy_state: EnemyState = EnemyState.Normal
## 怒り：残りHPがこの割合以下で発生（アルゴリズム）
const ANGRY_HP_RATIO := 0.4
## 怒り：スポーンからこの秒数経過でも発生（アルゴリズム）
const ANGRY_TIME_SEC := 15.0
## 弱り：かすり／踏みのあとこの秒数だけ弱り状態
const WEAK_DURATION_SEC := 8.0
var _state_timer: float = 0.0
var _weak_until: float = 0.0
## 怒り時の色（体当たり赤と区別するためマゼンタ系）
const STATE_ANGRY_MODULATE := Color(1.35, 0.45, 0.55, 1.0)
## 弱り時の色
const STATE_WEAK_MODULATE := Color(0.5, 0.6, 1.4, 1.0)
## 被弾後この秒数だけ超高速で離脱（FleeStateで使用）
var super_flee_remaining: float = 0.0
## プレイヤーと接したあとこの秒数だけモーション2倍速
var _player_contact_timer: float = 0.0
const PLAYER_CONTACT_SPEED_SEC := 2.0
## 空中攻撃ノックバックのティーン中（押し離し・クランプをスキップ）
var _aerial_knockback_animating: bool = false

func _process(delta: float) -> void:
	_turn_delta = delta
	if super_flee_remaining > 0.0:
		super_flee_remaining = maxf(0.0, super_flee_remaining - delta)
	if _player_contact_timer > 0.0:
		_player_contact_timer = maxf(0.0, _player_contact_timer - delta)
	_weak_until = maxf(0.0, _weak_until - delta)
	if not is_training_dummy:
		_state_timer += delta
		_update_enemy_state()
	super._process(delta)
	if is_dead or GameManager.enemies_frozen:
		return
	var in_ring_in: bool = fsm.current_state and fsm.current_state.name.to_lower() == "enemy_ring_in_state"
	var in_down: bool = fsm.current_state and fsm.current_state.name.to_lower() == "enemy_down_state"
	# ノックバックティーン中は押し離しをスキップ（半キャラずらしで飛ばす距離が短くならないように）
	var in_knockback_stun: bool = knockback_stun_remaining > 0.0
	if not in_ring_in and not _aerial_knockback_animating and not in_down and not in_knockback_stun:
		_push_apart_from_other_enemies()
	# 状態に応じた色。半キャラずらしヒット中は敵の絵自体を白く（modulate で毎フレーム上書き）
	var now := Time.get_ticks_msec() / 1000.0
	if sprite and now < halfcar_white_until:
		sprite.modulate = Color(2.0, 2.0, 2.0, 1.0)
	elif sprite and not invincible and not in_down and knockback_stun_remaining <= 0.0:
		sprite.modulate = _get_state_modulate()
	# アニメ速度：飛んでいるとき4倍速、プレイヤーと接した直後数秒は2倍速、それ以外は通常
	if sprite:
		if fsm.current_state and fsm.current_state.name.to_lower() == "enemy_launched_state":
			sprite.speed_scale = 4.0
		elif _player_contact_timer > 0.0:
			sprite.speed_scale = 2.0
		else:
			sprite.speed_scale = 1.0
	# 敵が絶対にロープ外に出ないようにクランプ（リングイン・空中ノックバック・ダウン・ノックバック中はスキップ）
	if not in_ring_in and not _aerial_knockback_animating and not in_down and not in_knockback_stun:
		global_position.x = clampf(global_position.x, MAT_LEFT, MAT_RIGHT)
		global_position.y = clampf(global_position.y, MAT_TOP, MAT_BOTTOM)

func Turn() -> void:
	if not sprite:
		return
	# flipped_horizontal を考慮した基準方向（+1=右を向く）
	var base_dir := -1 if flipped_horizontal == true else 1
	
	# ステージ3ボスだけは左右反転を少し遅らせる
	if is_boss and stage_number == 3:
		var move_dir := 0
		if velocity.x < -0.1:
			move_dir = -1
		elif velocity.x > 0.1:
			move_dir = 1
		
		if move_dir != 0 and move_dir != facing_dir_sign:
			# 進行方向が変わったら、一定時間たってから振り向く
			_boss_flip_timer += _turn_delta
			if _boss_flip_timer >= BOSS3_FLIP_DELAY:
				facing_dir_sign = move_dir
				_boss_flip_timer = 0.0
		else:
			# 同じ方向を向いている、または止まっている間はタイマーをリセット
			_boss_flip_timer = 0.0
		
		if facing_dir_sign != 0:
			sprite.scale.x = base_dir * float(facing_dir_sign) * absf(sprite.scale.x)
		return
	
	# 通常敵: 速度方向に即座に向きを変える（従来どおり）
	if velocity.x < -0.1:
		sprite.scale.x = -base_dir * absf(sprite.scale.x)
		facing_dir_sign = -1
	elif velocity.x > 0.1:
		sprite.scale.x = base_dir * absf(sprite.scale.x)
		facing_dir_sign = 1

## 敵同士が重なっていたら互いにずらす（マット内にクランプ）。重なり判定は少し緩めに。
func _push_apart_from_other_enemies() -> void:
	var my_pos := global_position
	for node in get_tree().get_nodes_in_group("Enemy"):
		if node == self or not is_instance_valid(node):
			continue
		var other := node as CharacterBase
		if not other or other.is_dead:
			continue
		if other is EnemyMain and (other as EnemyMain).is_rope_launched():
			continue
		var o_pos := other.global_position
		var dx := my_pos.x - o_pos.x
		var dy := my_pos.y - o_pos.y
		# 実際に重なっている時だけずらす（1.5倍の距離＝60ドット以内）
		var overlap_threshold := BODY_HALF * 1.5
		if absf(dx) >= overlap_threshold or absf(dy) >= overlap_threshold:
			continue
		# 重なっている：中心間ベクトルで互いに半分ずつずらす
		var dist := Vector2(dx, dy).length()
		if dist < 0.01:
			dist = 0.01
		var away := Vector2(dx, dy) / dist
		var overlap := overlap_threshold - dist
		if overlap <= 0:
			continue
		var push := away * (overlap * 0.5)
		var new_my := my_pos + push
		var new_other := o_pos - push
		new_my.x = clampf(new_my.x, MAT_LEFT, MAT_RIGHT)
		new_my.y = clampf(new_my.y, MAT_TOP, MAT_BOTTOM)
		global_position = new_my
		# ダウン中の敵は動かさない
		if other is EnemyMain and (other as EnemyMain).is_in_down_state():
			break
		new_other.x = clampf(new_other.x, MAT_LEFT, MAT_RIGHT)
		new_other.y = clampf(new_other.y, MAT_TOP, MAT_BOTTOM)
		other.global_position = new_other
		break

func _ready():
	super()
	if get("flash_effect_white_texture") == null and ResourceLoader.exists("res://Art/Sprites/Effect/effect_white_m_man_r_l1.png"):
		set("flash_effect_white_texture", load("res://Art/Sprites/Effect/effect_white_m_man_r_l1.png") as Texture2D)
	took_damage.connect(_on_took_damage)
	await get_tree().process_frame
	# ダウン状態で開始（動かず・赤フラッシュのまま）
	if is_down:
		fsm.force_change_state("enemy_down_state")
		return
	# リングイン着地目標が設定されていれば右端から走り込み→山なりジャンプ（最優先）
	if ring_in_landing_pos != Vector2.ZERO:
		fsm.force_change_state("enemy_ring_in_state")
		ring_in_landing_pos = Vector2.ZERO
		return
	match behavior_type:
		Behavior.Idle:
			fsm.force_change_state("enemy_idle_state")
		Behavior.VerticalLoop:
			patrol_vertical = true
			fsm.force_change_state("enemy_patrol_state")
		Behavior.HorizontalLoop:
			patrol_vertical = false
			fsm.force_change_state("enemy_patrol_state")
		Behavior.RandomRange:
			fsm.force_change_state("enemy_wander_state")
		Behavior.Flee:
			fsm.force_change_state("enemy_flee_state")

func _get_state_modulate() -> Color:
	match enemy_state:
		EnemyState.Angry:
			return STATE_ANGRY_MODULATE
		EnemyState.Weak:
			return STATE_WEAK_MODULATE
		_:
			return Color.WHITE

func _update_enemy_state() -> void:
	if _weak_until > 0.0:
		enemy_state = EnemyState.Weak
		return
	var max_hp := maxf(1.0, float(max_health))
	var hp_ratio := float(health) / max_hp
	if hp_ratio <= ANGRY_HP_RATIO or _state_timer >= ANGRY_TIME_SEC:
		enemy_state = EnemyState.Angry
	else:
		enemy_state = EnemyState.Normal

## かすりを食らったとき（弱り状態へ）
func notify_graze_hit() -> void:
	_weak_until = WEAK_DURATION_SEC

## ジャンプで踏まれたとき（弱り状態へ）
func notify_stepped_on() -> void:
	_weak_until = WEAK_DURATION_SEC

## 指定秒数だけ弱り状態にする（パワーエサなど）。既存の弱りより長い場合だけ上書き
func set_weak_for(duration_sec: float) -> void:
	_weak_until = maxf(_weak_until, duration_sec)

## リングイン演出中（スポーン〜着地まで）は true。この間は当たり判定なし・敵として認識しない
func is_ring_in_effect_only() -> bool:
	return fsm.current_state and fsm.current_state.name.to_lower() == "enemy_ring_in_state"

## ロープ飛ばし中（一変向で回転して飛んでいる間）は true。この間は当たり判定なし
func is_rope_launched() -> bool:
	return fsm.current_state and fsm.current_state.name.to_lower() == "enemy_launched_state"

## ダウン状態か（動かず攻撃せず・赤フラッシュのまま）
func is_in_down_state() -> bool:
	return fsm.current_state and fsm.current_state.name.to_lower() == "enemy_down_state"

## ボスがダメージを受けたら超高速離脱フラグを立てる
func _on_took_damage(_amount: int) -> void:
	if is_boss:
		super_flee_remaining = 2.5

# 攻撃後は必ずIdleに戻す
func finished_attacking():
	charge_damage_mult = 1.0
	fsm.change_state(attack_node, "enemy_idle_state")

func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		if is_training_dummy:
			return  # トレーニング用ダミーは攻撃・接近しない
		# リングイン中は最優先で入場のみ。ダウン中・リングイン中はプレイヤー検知でチェースに移行しない
		if fsm.current_state:
			var sn: String = String(fsm.current_state.name).to_lower()
			if sn == "enemy_ring_in_state" or sn == "enemy_down_state":
				return
		_player_contact_timer = PLAYER_CONTACT_SPEED_SEC
		player_in_range = true
		# アイドル/パトロール/ワンダー中ならプレイヤーに接近して攻撃（チェース）へ
		if fsm.current_state:
			var state_name: StringName = fsm.current_state.name
			if state_name in ["enemy_idle_state", "enemy_patrol_state", "enemy_wander_state"]:
				fsm.force_change_state("enemy_chase_state")

func _on_detection_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		player_in_range = false

func _die():
	super() #calls _die() on base-class CharacterBase
	fsm.force_change_state("enemy_death_state")

## ロープまでノックされたときに呼ぶ。大きくジャンプして画面内のどこかに着地する
func trigger_rope_launch() -> void:
	if is_dead:
		return
	fsm.force_change_state("enemy_launched_state")

## 空中攻撃で踏まれたとき：かすり同様の距離でランダム方向にティーン＋回転（緑フラッシュは呼び元で実施）
const AERIAL_KNOCKBACK_DIST := 90.0
const AERIAL_KNOCKBACK_TWEEN_DURATION := 0.28
const AERIAL_KNOCKBACK_SPIN_DEGREES := 720.0

func trigger_aerial_knockback() -> void:
	_aerial_knockback_animating = true
	var dir := Vector2(cos(randf() * TAU), sin(randf() * TAU))
	var target_pos := global_position + dir * AERIAL_KNOCKBACK_DIST
	var body_shape_node := get_node_or_null("BodyCollider") as CollisionShape2D
	var sprite_node := sprite if sprite else get_node_or_null("AnimatedSprite2D")
	velocity = Vector2.ZERO
	knockback_stun_remaining = AERIAL_KNOCKBACK_TWEEN_DURATION + 0.1
	set_invincible_for(0.6)
	var spin_from: float = sprite_node.rotation_degrees if sprite_node else 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "global_position", target_pos, AERIAL_KNOCKBACK_TWEEN_DURATION)
	if sprite_node:
		tw.tween_property(sprite_node, "rotation_degrees", spin_from + AERIAL_KNOCKBACK_SPIN_DEGREES, AERIAL_KNOCKBACK_TWEEN_DURATION)
	tw.tween_callback(_on_aerial_knockback_done)
	if body_shape_node:
		body_shape_node.disabled = true
	collision_mask = 1
	z_index = 100

func _on_aerial_knockback_done() -> void:
	_aerial_knockback_animating = false
	var body_shape_node := get_node_or_null("BodyCollider") as CollisionShape2D
	var sprite_node := sprite if sprite else get_node_or_null("Node2D")
	if body_shape_node:
		body_shape_node.disabled = false
	collision_mask = 3
	z_index = 0
	if sprite_node and is_instance_valid(sprite_node):
		sprite_node.rotation_degrees = 0.0
	if _is_outside_mat(global_position) and has_method("trigger_rope_launch"):
		set_invincible_for(1.0)
		trigger_rope_launch()
	else:
		global_position.x = clampf(global_position.x, MAT_LEFT, MAT_RIGHT)
		global_position.y = clampf(global_position.y, MAT_TOP, MAT_BOTTOM)

func _is_outside_mat(p: Vector2) -> bool:
	return p.x < MAT_LEFT or p.x > MAT_RIGHT or p.y < MAT_TOP or p.y > MAT_BOTTOM
