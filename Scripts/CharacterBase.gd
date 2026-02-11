extends CharacterBody2D
class_name CharacterBase

## HP0でQTEを出す場合は true（ボス撃破時）。成功で本当に死亡、失敗でHP回復
signal defeated_for_qte(who: CharacterBase)
## ダメージを受けた瞬間（ボス用：被弾で超高速離脱など）
signal took_damage(amount: int)

@export var sprite : AnimatedSprite2D
@export var healthbar : ProgressBar
@export var health : int
@export var flipped_horizontal : bool
@export var hit_particles : GPUParticles2D
var max_health : int  # 初期HPを記録
var invincible : bool = false
var is_dead : bool = false
## HP0で_die()の代わりにQTEを出す（ボスのみ）
var use_qte_on_defeat: bool = false
## ノックバック直後はこの秒数だけ移動しない（隣の敵を押さないように）
var knockback_stun_remaining: float = 0.0

func _ready():
	max_health = health  # 初期HPを記録
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
	if not sprite:
		return
	#This ternary lets us flip a sprite if its drawn the wrong way
	var direction = -1 if flipped_horizontal == true else 1
	
	# 移動方向に合わせて向きを変える（velocity.xの符号で判定）
	if velocity.x < -0.1:
		sprite.scale.x = -direction * absf(sprite.scale.x)
	elif velocity.x > 0.1:
		sprite.scale.x = direction * absf(sprite.scale.x)

#region Taking Damage

#Play universal damage sound effect for any character taking damage and flashing red
func damage_effects():
	AudioManager.play_sound(AudioManager.BLOODY_HIT, 0, -3)
	after_damage_iframes()
	if(hit_particles):
		hit_particles.emitting = true

#After we are done flashing red, we can take damage again（ピカピカ明るめ・大きめ・少し長く）
func after_damage_iframes():
	invincible = true
	var target = sprite if sprite else self
	var flash_bright := Color(1.45, 0.55, 0.55, 1.0)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(target, "modulate", flash_bright, 0.1)
	tween.chain().set_parallel(true)
	tween.tween_property(target, "modulate", Color.WHITE, 0.1)
	tween.chain().tween_property(target, "modulate", flash_bright, 0.1)
	tween.chain().tween_property(target, "modulate", Color.WHITE, 0.1)
	tween.chain().tween_property(target, "modulate", Color(1.25, 0.65, 0.65, 1.0), 0.08)
	tween.chain().tween_property(target, "modulate", Color.WHITE, 0.12)
	await tween.finished
	if target and is_instance_valid(target):
		target.modulate = Color.WHITE
	invincible = false
	
func _take_damage(amount):
	if(invincible == true || is_dead == true):
		return
		
	health -= amount
	if healthbar:
		healthbar.value = health
	took_damage.emit(amount)
	damage_effects()
	
	if health <= 0:
		if use_qte_on_defeat:
			defeated_for_qte.emit(self)
			return
		_die()
		
## 指定秒数だけ無敵にする（体当たり・ロープ跳ね返り後など）
func set_invincible_for(duration: float) -> void:
	invincible = true
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(self):
		invincible = false
		
func _die():
	if(is_dead):
		return
		
	is_dead = true
	
	# マスク（顔）が飛んでいく演出
	if sprite and is_instance_valid(sprite):
		var mask_fly = Sprite2D.new()
		mask_fly.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
		# 反転（scale.x<0）や親スケールを含めた見た目をそのまま引き継ぐ
		# （root直下に出すので global_transform をコピーする）
		mask_fly.global_transform = sprite.global_transform
		mask_fly.set_script(load("res://Scripts/MaskFlyAway.gd"))
		get_tree().root.add_child(mask_fly)
		# 本体のスプライトは非表示
		sprite.visible = false
	
	#Remove/destroy this character once it's able to do so unless its the player
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(self) and not is_in_group("Player"):
		queue_free()

#endregion
