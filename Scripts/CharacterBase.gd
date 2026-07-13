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
## UIの体力バー用：低HP点滅
var _hb_blink_t: float = 0.0
var _hb_blink_on: bool = true
## HP0で_die()の代わりにQTEを出す（ボスのみ）
var use_qte_on_defeat: bool = false
## ノックバック直後はこの秒数だけ移動しない（隣の敵を押さないように）
var knockback_stun_remaining: float = 0.0
## 半キャラずらしヒット時：この時刻（秒・get_ticks_msec/1000）までスプライトをまっしろに（0＝無効）
var halfcar_white_until: float = 0.0
## エフェクト用：白いキャラ絵（透明以外を白にした画像）。設定されていれば半キャラ時にピカピカ表示
var flash_effect_white_texture: Texture2D = null
## 移動・回転系のTween（ノックバック・かすり回転など）。ステート切替時に個別killするために保持
## （以前は get_processed_tweens() で全Tweenをkillしており、UIや他キャラのTweenを巻き込んでいた: KI-02）
var _motion_tweens: Array[Tween] = []

## 位置・回転を動かすTweenを登録する。ジャンプ/ロープ飛ばし開始時にまとめてkillされる
func register_motion_tween(t: Tween) -> void:
	_motion_tweens = _motion_tweens.filter(func(x: Tween) -> bool: return x != null and x.is_valid())
	_motion_tweens.append(t)

## 登録済みの移動・回転Tweenだけをkillする（modulateフラッシュ等は巻き込まない）
func kill_motion_tweens() -> void:
	for t in _motion_tweens:
		if t and t.is_valid():
			t.kill()
	_motion_tweens.clear()

func _ready():
	max_health = health  # 初期HPを記録
	init_character()
	
func _process(delta: float):
	knockback_stun_remaining = maxf(0.0, knockback_stun_remaining - delta)
	Turn()
	_update_healthbar_visual(delta)
	
#Add anything here that needs to be initialized on the character
func init_character():
	if healthbar:
		healthbar.max_value = health
		healthbar.value = health
		_update_healthbar_visual(0.0)

func _update_healthbar_visual(delta: float) -> void:
	if not healthbar:
		return
	# max_value が未設定の場合も安全に
	var maxv := float(healthbar.max_value) if healthbar.max_value > 0 else float(max_health if max_health > 0 else 1)
	var hp_percent := clampf(float(health) / maxv, 0.0, 1.0)

	var color: Color
	if hp_percent <= 0.3:
		_hb_blink_t += delta
		if _hb_blink_t >= 0.15:
			_hb_blink_t = 0.0
			_hb_blink_on = not _hb_blink_on
		color = Color(0.9, 0.25, 0.12, 1.0) if _hb_blink_on else Color.WHITE
	elif hp_percent <= 0.5:
		_hb_blink_t = 0.0
		_hb_blink_on = true
		color = Color(1.0, 0.9, 0.25, 1.0)
	else:
		_hb_blink_t = 0.0
		_hb_blink_on = true
		color = Color(0.2, 1.0, 0.35, 1.0)

	# fill の色を差し替える（StyleBoxFlat を想定）
	var fill := healthbar.get_theme_stylebox("fill")
	if fill is StyleBoxFlat:
		(fill as StyleBoxFlat).bg_color = color

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
	# set_invincible_for() などで、この演出より長い無敵期限が設定されている場合に上書きしないよう、
	# 自分の分の期限も登録しておく（期限管理方式: KI-06 と同じ仕組み）
	var my_duration := 0.1 + 0.1 + 0.1 + 0.1 + 0.08 + 0.12
	var my_until := Time.get_ticks_msec() + int(my_duration * 1000.0)
	if my_until > _invincible_until_ms:
		_invincible_until_ms = my_until
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
	# 自分より後に、より長い無敵（set_invincible_for等）が設定されていたら解除しない
	if Time.get_ticks_msec() >= _invincible_until_ms - 10:
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

## 半キャラ連打など：damage_effects（長い無敵＋BLOODY_HIT）を使わず、短い無敵だけで tick ダメージ
func apply_repeat_contact_damage(amount: int, invincible_sec: float) -> bool:
	if invincible or is_dead:
		return false
	health -= amount
	if healthbar:
		healthbar.value = health
	took_damage.emit(amount)
	set_invincible_for(invincible_sec)
	if health <= 0:
		if use_qte_on_defeat:
			defeated_for_qte.emit(self)
			return true
		_die()
	return true
		
## 無敵の期限（ミリ秒）。重複呼び出し時に短いタイマーが長い無敵を打ち消さないようにする
var _invincible_until_ms: int = 0

## 指定秒数だけ無敵にする（体当たり・ロープ跳ね返り後など）
func set_invincible_for(duration: float) -> void:
	invincible = true
	var until := Time.get_ticks_msec() + int(duration * 1000.0)
	if until > _invincible_until_ms:
		_invincible_until_ms = until
	await get_tree().create_timer(duration).timeout
	# 自分より後に、より長い無敵が設定されていたら解除しない
	if is_instance_valid(self) and Time.get_ticks_msec() >= _invincible_until_ms - 10:
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
