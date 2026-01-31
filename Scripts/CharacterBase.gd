extends CharacterBody2D
class_name CharacterBase

@export var sprite : AnimatedSprite2D
@export var healthbar : ProgressBar
@export var health : int
@export var flipped_horizontal : bool
@export var hit_particles : GPUParticles2D
var invincible : bool = false
var is_dead : bool = false

func _ready():
	init_character()
	
func _process(_delta):
	Turn()
	# 1〜2ドット上下の揺れ（控えめに）
	if sprite:
		var bob: float = sin(Time.get_ticks_msec() * 0.002) * 0.5
		sprite.offset.y = bob
	
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

#After we are done flashing red, we can take damage again（スプライトのみフラッシュしてルートの色を維持）
func after_damage_iframes():
	invincible = true
	var target = sprite if sprite else self
	var tween = create_tween()
	tween.tween_property(target, "modulate", Color.DARK_RED, 0.1)
	tween.tween_property(target, "modulate", Color.WHITE, 0.1)
	tween.tween_property(target, "modulate", Color.RED, 0.1)
	tween.tween_property(target, "modulate", Color.WHITE, 0.1)
	await tween.finished
	invincible = false
	
## ノックバック中など、指定秒数だけ無敵にする
func set_invincible_for(seconds: float) -> void:
	invincible = true
	get_tree().create_timer(seconds).timeout.connect(_on_invincible_timeout)

func _on_invincible_timeout() -> void:
	if is_instance_valid(self):
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
