extends State
class_name enemy_attack_state

@export var attack : Attack_Data
@onready var enemy = $"../.."
@onready var hit_particles = $"../../AnimatedSprite2D/HitParticles"
@export var animator : AnimationPlayer
## 気合モード風の赤（攻撃中）
const ATTACK_MODULATE := Color(1.18, 0.55, 0.55, 1.0)

func Enter():
	if enemy.sprite:
		enemy.sprite.modulate = ATTACK_MODULATE
	animator.play(attack.anim)
	await animator.animation_finished
	enemy.finished_attacking()

func Exit():
	if enemy.sprite:
		enemy.sprite.modulate = Color.WHITE
	
#During attack animation, Hitbox is activated and tries to find the player
func _on_hit_box_body_entered(body):
	if body.is_in_group("Player"):
		deal_damage_to_player(body)

#Connect and deal damage to the player（突進時は倍率適用。炎ダッシュ中はプレイヤー受けるダメージ2倍。怒り中は1.5倍・弱り中は攻撃無効）
func deal_damage_to_player(player : PlayerMain):
	if enemy is EnemyMain and (enemy as EnemyMain).is_weak_state():
		return  # 弱り状態の敵は攻撃してもダメージを与えられない
	hit_particles.emitting = true
	var state_mult: float = (enemy as EnemyMain).state_damage_mult() if enemy is EnemyMain else 1.0
	var dmg = int(attack.damage * enemy.charge_damage_mult * player.fire_dash_damage_taken_mult * state_mult)
	player.take_damage_from_enemy(dmg)
	
func play_hitground_sound():
	AudioManager.play_sound(AudioManager.ENEMY_HIT, 0, -10)
	
