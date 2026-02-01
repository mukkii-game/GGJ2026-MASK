extends CharacterBody2D
class_name CharacterBase

@export var sprite : AnimatedSprite2D
@export var healthbar : ProgressBar
@export var health : int
@export var flipped_horizontal : bool
@export var hit_particles : GPUParticles2D
var invincible : bool = false
var is_dead : bool = false
## ノックバック直後はこの秒数だけ移動しない（隣の敵を押さないように）
var knockback_stun_remaining: float = 0.0

func _ready():
	init_character()
	
func _process(delta: float):
	knockback_stun_remaining = maxf(0.0, knockback_stun_remaining - delta)
	Turn()
	
#Add anything here that needs to be initialized on the character
func init_character():
	if healthbar:
		healthbar.max_value = health
		healthbar.value = health

#Flip charater sprites based on their current velocity
func Turn():
	#This ternary lets us flip a sprite if its drawn the wrong way
	var direction = -1 if flipped_horizontal == true else 1
	
	if velocity.x < 0:
		sprite.scale.x = -direction * absf(sprite.scale.x)
	elif velocity.x > 0:
		sprite.scale.x = direction * absf(sprite.scale.x)

#region Taking Damage

#Play universal damage sound effect for any character taking damage and flashing red
func damage_effects():
	AudioManager.play_sound(AudioManager.BLOODY_HIT, 0, -3)
	after_damage_iframes()
	if(hit_particles):
		hit_particles.emitting = true

<<<<<<< Updated upstream
#After we are done flashing red, we can take damage again
func after_damage_iframes():
	invincible = true
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.DARK_RED, 0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)
	tween.tween_property(self, "modulate", Color.RED, 0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)
=======
#After we are done flashing red, we can take damage again（ピカピカ明るめ・大きめ・少し長く）
func after_damage_iframes():
	invincible = true
	var target = sprite if sprite else self
	var orig_scale: Vector2 = target.scale if target else Vector2.ONE
	var flash_bright := Color(1.45, 0.55, 0.55, 1.0)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(target, "modulate", flash_bright, 0.1)
	tween.tween_property(target, "scale", orig_scale * 1.12, 0.08)
	tween.chain().set_parallel(true)
	tween.tween_property(target, "modulate", Color.WHITE, 0.1)
	tween.tween_property(target, "scale", orig_scale, 0.1)
	tween.chain().tween_property(target, "modulate", flash_bright, 0.1)
	tween.chain().tween_property(target, "modulate", Color.WHITE, 0.1)
	tween.chain().tween_property(target, "modulate", Color(1.25, 0.65, 0.65, 1.0), 0.08)
	tween.chain().tween_property(target, "modulate", Color.WHITE, 0.12)
>>>>>>> Stashed changes
	await tween.finished
	if target and is_instance_valid(target):
		target.modulate = Color.WHITE
		target.scale = orig_scale
	invincible = false
	
func _take_damage(amount):
	if(invincible == true || is_dead == true):
		return
		
	health -= amount
	if healthbar:
		healthbar.value = health
	damage_effects()
	
	if(health <= 0):
		_die()
		
func _die():
	if(is_dead):
		return
		
	is_dead = true
	#Remove/destroy this character once it's able to do so unless its the player
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(self) and not is_in_group("Player"):
		queue_free()

#endregion
