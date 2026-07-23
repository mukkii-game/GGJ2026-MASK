extends Node2D
## 走り中に足元で出す煙のようなエフェクト

var _player_main: PlayerMain
var _particles: GPUParticles2D

func _ready() -> void:
	_player_main = get_parent() as PlayerMain
	position = Vector2(0, 14)
	z_index = -2

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 35.0
	mat.initial_velocity_min = 15.0
	mat.initial_velocity_max = 45.0
	mat.gravity = Vector3(0, -15, 0)
	mat.scale_min = 2.0
	mat.scale_max = 5.0

	_particles = GPUParticles2D.new()
	_particles.amount = 12
	_particles.lifetime = 0.4
	_particles.explosiveness = 0.0
	_particles.process_material = mat
	_particles.modulate = Color(0.88, 0.88, 0.9, 0.55)
	_particles.emitting = false
	_particles.visible = false
	add_child(_particles)

func _process(_delta: float) -> void:
	if not _player_main:
		return
	if _player_main.is_dead:
		_particles.emitting = false
		_particles.visible = false
		return
	var show_smoke := _player_main.is_run_dashing
	_particles.emitting = show_smoke
	_particles.visible = show_smoke

