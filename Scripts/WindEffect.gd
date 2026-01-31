extends Node2D
## 自動走行時に表示するさりげない風エフェクト（上に被せる）
## 親の velocity または scale.x で向きを決める

@export var streak_count := 5
@export var streak_length := 12.0
@export var streak_spacing := 8.0
@export var color := Color(1, 1, 1, 0.25)
@export var offset_y := -20.0

var _phase: float = 0.0
var _direction: float = 1.0  # 1=右 -1=左

func _process(delta: float) -> void:
	var parent_body := get_parent() as CharacterBody2D
	if not parent_body:
		return
	var run_dir: float = 0.0
	if parent_body.velocity.x > 10:
		run_dir = 1.0
	elif parent_body.velocity.x < -10:
		run_dir = -1.0
	else:
		# スプライトの向きで決める
		var spr = parent_body.get_node_or_null("AnimatedSprite2D") as Node2D
		if spr and is_instance_valid(spr):
			run_dir = 1.0 if spr.scale.x >= 0 else -1.0
	_direction = run_dir if run_dir != 0 else _direction
	_phase += delta * 8.0
	queue_redraw()

func _draw() -> void:
	for i in streak_count:
		var t: float = (float(i) / max(1, streak_count - 1)) * 0.8 + 0.1
		var base_x: float = (t - 0.5) * streak_spacing * streak_count
		var wave := sin(_phase + i * 0.7) * 2.0
		var from := Vector2(base_x + wave, offset_y - i * 2)
		var to := from + Vector2(-_direction * streak_length + sin(_phase * 2 + i) * 3, 0)
		draw_line(from, to, color)
