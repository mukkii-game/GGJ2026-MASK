extends State
class_name enemy_charge_state

## プレイヤーとXまたはY軸が揃ったとみなす距離
@export var align_threshold := 24.0
## 突進前の溜め時間（秒）
@export var charge_delay := 0.4
## 突進速度
@export var charge_speed := 280.0
## 突進時の攻撃ダメージ倍率
@export var charge_damage_mult := 2.0
const CHARGE_STEP_SIZE := 32
var _charge_step_cooldown: float:
	get: return CHARGE_STEP_SIZE / charge_speed

@export var animator : AnimationPlayer
@onready var body = get_parent().get_parent() as CharacterBody2D

var _phase := "align"  # align -> delay -> charging
var _charge_timer := 0.0
var _charge_dir := Vector2.ZERO
var _charge_step_timer := 0.0

func Enter():
	animator.play("Idle")
	_phase = "align"
	_charge_timer = 0.0

func Update(delta: float):
	if GameManager.enemies_frozen:
		body.velocity = Vector2.ZERO
		body.move_and_slide()
		return
	if body.knockback_stun_remaining > 0:
		body.velocity = Vector2.ZERO
		body.move_and_slide()
		return
	var player = get_tree().get_first_node_in_group("Player") as Node2D
	if not player:
		state_transition.emit(self, "enemy_idle_state")
		return

	var to_player = player.global_position - body.global_position
	var dist = to_player.length()

	if _phase == "align":
		body.velocity = Vector2.ZERO
		var ax = absf(to_player.x) <= align_threshold
		var ay = absf(to_player.y) <= align_threshold
		if ax or ay:
			_charge_dir = to_player.normalized()
			_phase = "delay"
			_charge_timer = charge_delay
	elif _phase == "delay":
		_charge_timer -= delta
		body.velocity = Vector2.ZERO
		if _charge_timer <= 0:
			_phase = "charging"
			_charge_step_timer = 0.0
			animator.play("Chasing")
	elif _phase == "charging":
		# 敵の動きはカクカク/通常に依存せず常にスムーズ
		body.velocity = _charge_dir * charge_speed
		body.move_and_slide()
		if body.get_slide_collision_count() > 0:
			for i in body.get_slide_collision_count():
				var col = body.get_slide_collision(i)
				if col and col.get_collider() and col.get_collider().is_in_group("Player"):
					body.charge_damage_mult = charge_damage_mult
					state_transition.emit(self, "enemy_attack_state")
					return
				if col and col.get_collider() and col.get_collider().is_in_group("Rope"):
					state_transition.emit(self, "enemy_idle_state")
					return
			state_transition.emit(self, "enemy_idle_state")
			return
		if dist < 40:
			body.charge_damage_mult = charge_damage_mult
			state_transition.emit(self, "enemy_attack_state")
			return
