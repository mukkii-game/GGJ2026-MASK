extends State
class_name PlayerFireDash

## カクカクモード時のジャンプボタン＝押し続けで炎状態（赤く光る）維持。与ダメ・被ダメともに2倍（ハイリスクハイリターン）。移動可能。

const FIRE_MODULATE := Color(1.25, 0.55, 0.2, 1)
## グリッド移動：1ステップのピクセル数（半キャラ＝32）
const STEP_SIZE := 32
## 1ステップごとの間隔（秒）
const STEP_COOLDOWN := 0.12

var player: CharacterBody2D
var player_main: PlayerMain
var sprite_node: Node2D
var step_timer := 0.0

func Enter() -> void:
	player = get_parent().get_parent() as CharacterBody2D
	player_main = player as PlayerMain
	if not player or not player_main:
		return
	player_main.fire_dash_damage_mult = 2.0
	player_main.fire_dash_damage_taken_mult = 2.0
	sprite_node = player_main.sprite if player_main else null
	if sprite_node:
		sprite_node.modulate = FIRE_MODULATE
	step_timer = 0.0
	player.velocity = Vector2.ZERO

func Exit() -> void:
	if player_main:
		player_main.fire_dash_damage_mult = 1.0
		player_main.fire_dash_damage_taken_mult = 1.0
	if sprite_node and is_instance_valid(sprite_node):
		sprite_node.modulate = Color.WHITE

func Update(delta: float) -> void:
	if not player or not player_main:
		return
	var hold_action := "Dash"
	var mv_left := "MoveLeft"
	var mv_right := "MoveRight"
	var mv_up := "MoveUp"
	var mv_down := "MoveDown"
	if player_main.is_player_two:
		hold_action = "Punch2"
		mv_left = "Move2Left"
		mv_right = "Move2Right"
		mv_up = "Move2Up"
		mv_down = "Move2Down"
	# 押し続けている間は炎状態維持。離したらIdleへ
	if not Input.is_action_pressed(hold_action):
		state_transition.emit(self, "Idle")
		return
	# グリッド移動（カクカクモード時の移動と同じ）
	step_timer -= delta
	var input_dir := Input.get_vector(mv_left, mv_right, mv_up, mv_down)
	if input_dir.length() > 0.01 and step_timer <= 0:
		step_timer = STEP_COOLDOWN
		var dir: Vector2
		if absf(input_dir.x) >= absf(input_dir.y):
			dir = Vector2(signf(input_dir.x), 0)
		else:
			dir = Vector2(0, signf(input_dir.y))
		player.global_position += dir * STEP_SIZE
		# スプライトの向きを変える
		if sprite_node and dir.x != 0:
			sprite_node.scale.x = signf(dir.x) * absf(sprite_node.scale.x)
	player.velocity = Vector2.ZERO
