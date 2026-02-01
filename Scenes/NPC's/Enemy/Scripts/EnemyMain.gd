extends CharacterBase
class_name EnemyMain

<<<<<<< Updated upstream
@onready var fsm = $FSM as FiniteStateMachine
var player_in_range = false

@export var attack_node : Node
@export var chase_node : Node

# 攻撃後は必ずIdleに戻す（一定時間追従はChase側のタイマーで制御）
=======
## 静止・上下ループ・左右ループ・一定範囲ランダムの4種
enum Behavior { Idle, VerticalLoop, HorizontalLoop, RandomRange }

## 敵同士が重ならないよう、かさなったらずらす用（マット内）
const MAT_LEFT := 296.0
const MAT_RIGHT := 984.0
const MAT_TOP := 16.0
const MAT_BOTTOM := 704.0
const BODY_HALF := 40.0

@onready var fsm = $FSM as FiniteStateMachine
var player_in_range = false
## 突進攻撃時ダメージ倍率（1.0＝通常）
var charge_damage_mult := 1.0
## Patrol状態で上下=true／左右=false（VerticalLoop / HorizontalLoop 用）
var patrol_vertical := false

@export var behavior_type: Behavior = Behavior.Idle
@export var attack_node : Node
@export var chase_node : Node

func _process(delta: float) -> void:
	super._process(delta)
	if is_dead:
		return
	_push_apart_from_other_enemies()

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

# 攻撃後は必ずIdleに戻す
>>>>>>> Stashed changes
func finished_attacking():
	fsm.change_state(attack_node, "enemy_idle_state")

<<<<<<< Updated upstream
# プレイヤーが範囲内に入ったら一定時間追従（Chase）に切り替え
func _on_detection_area_body_entered(body):
	if body.is_in_group("Player"):
		player_in_range = true
		var cs = fsm.current_state.name if fsm.current_state else ""
		if cs != "enemy_death_state" and cs != "enemy_attack_state":
			fsm.force_change_state("enemy_chase_state")
=======
func _on_detection_area_body_entered(_body: Node2D) -> void:
	pass

func _on_detection_area_body_exited(_body: Node2D) -> void:
	pass
>>>>>>> Stashed changes

func _die():
	super() #calls _die() on base-class CharacterBase
	fsm.force_change_state("enemy_death_state")
	
	
