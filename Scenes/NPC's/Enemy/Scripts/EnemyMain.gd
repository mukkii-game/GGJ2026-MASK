extends CharacterBase
class_name EnemyMain

enum Behavior { Bounce, Wander, Chase, Charge }

@onready var fsm = $FSM as FiniteStateMachine
var player_in_range = false
## 突進攻撃時ダメージ倍率（1.0＝通常）
var charge_damage_mult := 1.0

@export var behavior_type: Behavior = Behavior.Chase
@export var attack_node : Node
@export var chase_node : Node

func _ready():
	super()
	await get_tree().process_frame
	match behavior_type:
		Behavior.Bounce:
			fsm.force_change_state("enemy_bounce_state")
		Behavior.Wander:
			fsm.force_change_state("enemy_wander_state")
		Behavior.Chase, Behavior.Charge:
			pass

# 攻撃後は必ずIdleに戻す
func finished_attacking():
	charge_damage_mult = 1.0
	fsm.change_state(attack_node, "enemy_idle_state")

# プレイヤーが範囲内に入ったら追従または突進に切り替え
func _on_detection_area_body_entered(body):
	if body.is_in_group("Player"):
		player_in_range = true
		var cs = fsm.current_state.name if fsm.current_state else ""
		if cs != "enemy_death_state" and cs != "enemy_attack_state":
			if behavior_type == Behavior.Charge:
				fsm.force_change_state("enemy_charge_state")
			else:
				fsm.force_change_state("enemy_chase_state")

#Return to idle when player leaves our proximity
func _on_detection_area_body_exited(body):
	if body.is_in_group("Player"):
		player_in_range = false
		fsm.change_state(chase_node, "enemy_idle_state")
		
func _die():
	super() #calls _die() on base-class CharacterBase
	fsm.force_change_state("enemy_death_state")

## ロープまでノックされたときに呼ぶ。大きくジャンプして画面内のどこかに着地する
func trigger_rope_launch() -> void:
	if is_dead:
		return
	fsm.force_change_state("enemy_launched_state")

