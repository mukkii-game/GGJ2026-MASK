extends State
class_name enemy_wander_state

## ランダム / サイン波 / ヨタヨタ / ゆっくり接近 を behavior_type で分岐

@export var wander_radius: float = 100.0
@export var move_speed: float = 50.0
@export var animator: AnimationPlayer
@onready var body = get_parent().get_parent() as CharacterBody2D

var _start_pos := Vector2.ZERO
var _target := Vector2.ZERO
var _has_target := false

func Enter():
	animator.play("Chasing")
	_start_pos = body.global_position
	_has_target = false
	if body is EnemyMain:
		var em := body as EnemyMain
		match em.behavior_type:
			EnemyMain.Behavior.SineWave:
				em._sine_phase = randf() * TAU
				em._sine_axis_horizontal = randf() > 0.5
			EnemyMain.Behavior.Yotayota:
				em._yota_dir = Vector2.RIGHT.rotated(randf() * TAU)
				em._yota_move_left = randf_range(0.6, 1.2)
				em._yota_pause_left = 0.0
			_:
				_pick_new_target()

func _pick_new_target():
	var angle = randf() * TAU
	var r = randf() * wander_radius
	_target = _start_pos + Vector2(cos(angle), sin(angle)) * r
	_has_target = true

func Update(delta: float):
	if GameManager.enemies_frozen:
		body.velocity = Vector2.ZERO
		body.move_and_slide()
		return
	if body.knockback_stun_remaining > 0:
		body.velocity = Vector2.ZERO
		body.move_and_slide()
		return
	if body is EnemyMain and (body as EnemyMain).player_in_range:
		# ロープ往復系以外は接近可能。サイン/ヨタヨタは半キャラ窓を残すため検知時も少し粘る
		var em0 := body as EnemyMain
		if em0.behavior_type != EnemyMain.Behavior.SineWave and em0.behavior_type != EnemyMain.Behavior.Yotayota:
			state_transition.emit(self, "enemy_chase_state")
			return
		# サイン/ヨタは距離が近いときだけチェイス
		var players := get_tree().get_nodes_in_group("Player")
		if players.size() > 0 and is_instance_valid(players[0]):
			if body.global_position.distance_to(players[0].global_position) < 70.0:
				state_transition.emit(self, "enemy_chase_state")
				return
	if not (body is EnemyMain):
		return
	var em := body as EnemyMain
	var speed_mult: float = em.state_speed_mult()
	match em.behavior_type:
		EnemyMain.Behavior.SineWave:
			_update_sine(em, delta, speed_mult)
		EnemyMain.Behavior.Yotayota:
			_update_yotayota(em, delta, speed_mult)
		EnemyMain.Behavior.SlowApproach:
			_update_slow_approach(em, delta, speed_mult)
		_:
			_update_random(em, delta, speed_mult)

func _update_sine(em: EnemyMain, delta: float, speed_mult: float) -> void:
	em._sine_phase += delta * 1.8
	# 山谷（sinの極値付近）で減速＝半キャラ窓
	var wave := sin(em._sine_phase)
	var slow_window: float = 1.0 - absf(wave)  # 0 at peaks? abs(sin)=1 at peaks. We want slow at peaks/valleys = |sin| near 1? 
	# User: 山谷で少し遅くなる. peaks and valleys of sine = |sin|==1 or cos==0. |wave| near 1 → slow
	var speed_factor: float = lerpf(1.15, 0.35, clampf(absf(wave), 0.0, 1.0))
	var base: float = 95.0 * speed_mult * speed_factor
	if em._sine_axis_horizontal:
		body.velocity = Vector2(base * signf(cos(em._sine_phase) + 0.001), wave * 70.0 * speed_mult)
	else:
		body.velocity = Vector2(wave * 70.0 * speed_mult, base * signf(cos(em._sine_phase) + 0.001))
	_clamp_and_bounce(em)
	body.move_and_slide()

func _update_yotayota(em: EnemyMain, delta: float, speed_mult: float) -> void:
	if em._yota_pause_left > 0.0:
		em._yota_pause_left -= delta
		body.velocity = Vector2.ZERO
		body.move_and_slide()
		if em._yota_pause_left <= 0.0:
			em._yota_dir = Vector2.RIGHT.rotated((randi() % 8) * TAU / 8.0)
			em._yota_move_left = randf_range(0.6, 1.2)
		return
	em._yota_move_left -= delta
	body.velocity = em._yota_dir * 70.0 * speed_mult
	_clamp_and_bounce(em)
	body.move_and_slide()
	if em._yota_move_left <= 0.0:
		em._yota_pause_left = randf_range(0.2, 0.45)

func _update_slow_approach(em: EnemyMain, delta: float, speed_mult: float) -> void:
	var players := get_tree().get_nodes_in_group("Player")
	if players.is_empty() or not is_instance_valid(players[0]):
		body.velocity = Vector2.ZERO
		body.move_and_slide()
		return
	var to_p: Vector2 = players[0].global_position - body.global_position
	if to_p.length() < 8.0:
		body.velocity = Vector2.ZERO
	else:
		body.velocity = to_p.normalized() * 55.0 * speed_mult
	body.move_and_slide()

func _update_random(em: EnemyMain, delta: float, speed_mult: float) -> void:
	if not _has_target:
		_pick_new_target()
		return
	var to_target = _target - body.global_position
	if to_target.length() < 8.0:
		_has_target = false
		state_transition.emit(self, "enemy_idle_state")
		return
	body.velocity = to_target.normalized() * move_speed * speed_mult
	body.move_and_slide()

func _clamp_and_bounce(em: EnemyMain) -> void:
	# ザコは四辺で跳ね返り（進行方向反転）
	const M := 8.0
	if body.global_position.x <= EnemyMain.MAT_LEFT + M and body.velocity.x < 0:
		body.velocity.x = absf(body.velocity.x)
		em._yota_dir.x = absf(em._yota_dir.x)
	elif body.global_position.x >= EnemyMain.MAT_RIGHT - M and body.velocity.x > 0:
		body.velocity.x = -absf(body.velocity.x)
		em._yota_dir.x = -absf(em._yota_dir.x)
	if body.global_position.y <= EnemyMain.MAT_TOP + M and body.velocity.y < 0:
		body.velocity.y = absf(body.velocity.y)
		em._yota_dir.y = absf(em._yota_dir.y)
	elif body.global_position.y >= EnemyMain.MAT_BOTTOM - M and body.velocity.y > 0:
		body.velocity.y = -absf(body.velocity.y)
		em._yota_dir.y = -absf(em._yota_dir.y)
