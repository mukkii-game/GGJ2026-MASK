extends CharacterBase
class_name EnemyMain

## 静止・上下ループ・左右ループ・一定範囲ランダム・逃走の5種
enum Behavior { Idle, VerticalLoop, HorizontalLoop, RandomRange, Flee }

## 敵同士が重ならないよう、かさなったらずらす用（マット内）
const MAT_LEFT := 296.0
const MAT_RIGHT := 984.0
const MAT_TOP := 106.0
const MAT_BOTTOM := 614.0
const BODY_HALF := 40.0

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

@export var behavior_type: Behavior = Behavior.Idle
@export var attack_node : Node
@export var chase_node : Node

## ステージ番号（特殊処理用）
var stage_number: int = 1
## ボスキャラか（特殊行動用）
var is_boss: bool = false
## 被弾後この秒数だけ超高速で離脱（FleeStateで使用）
var super_flee_remaining: float = 0.0
## プレイヤーと接したあとこの秒数だけモーション2倍速
var _player_contact_timer: float = 0.0
const PLAYER_CONTACT_SPEED_SEC := 2.0

func _process(delta: float) -> void:
	if super_flee_remaining > 0.0:
		super_flee_remaining = maxf(0.0, super_flee_remaining - delta)
	if _player_contact_timer > 0.0:
		_player_contact_timer = maxf(0.0, _player_contact_timer - delta)
	super._process(delta)
	if is_dead or GameManager.enemies_frozen:
		return
	_push_apart_from_other_enemies()
	# アニメ速度：飛んでいるとき4倍速、プレイヤーと接した直後数秒は2倍速、それ以外は通常
	if sprite:
		if fsm.current_state and fsm.current_state.name.to_lower() == "enemy_launched_state":
			sprite.speed_scale = 4.0
		elif _player_contact_timer > 0.0:
			sprite.speed_scale = 2.0
		else:
			sprite.speed_scale = 1.0
	# 敵が絶対にロープ外に出ないようにクランプ
	global_position.x = clampf(global_position.x, MAT_LEFT, MAT_RIGHT)
	global_position.y = clampf(global_position.y, MAT_TOP, MAT_BOTTOM)

## 敵同士が重なっていたら互いにずらす（マット内にクランプ）。重なり判定は少し緩めに。
func _push_apart_from_other_enemies() -> void:
	var my_pos := global_position
	for node in get_tree().get_nodes_in_group("Enemy"):
		if node == self or not is_instance_valid(node):
			continue
		var other := node as CharacterBase
		if not other or other.is_dead:
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
		new_other.x = clampf(new_other.x, MAT_LEFT, MAT_RIGHT)
		new_other.y = clampf(new_other.y, MAT_TOP, MAT_BOTTOM)
		global_position = new_my
		other.global_position = new_other
		break

func _ready():
	super()
	took_damage.connect(_on_took_damage)
	await get_tree().process_frame
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

