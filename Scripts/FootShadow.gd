extends Node2D
## 足元の影（キャラと同じ横幅の楕円）。ジャンプ時はY軸だけ地面に固定する想定。

## 楕円の横半径（キャラ幅64の半分＝32）
@export var radius_x := 32.0
## 楕円の縦半径
@export var radius_y := 12.0
@export var color := Color(0.06, 0.06, 0.06, 0.7)
## 足元からのオフセット（Yを少し下にすると床の位置になる）
@export var offset_to_feet := Vector2(0, 28)
## 地面のY（ワールド座標）。未設定なら親のYに追従。ジャンプ時はここを固定する
var ground_y: float = INF
## ジャンプ時の地面X（ワールド座標）。未設定なら親のXに追従。プレイヤーが動かない限り影はそのまま
var ground_x: float = INF

func _ready() -> void:
	position = offset_to_feet

func _process(_delta: float) -> void:
	var parent_node = get_parent() as Node2D
	if not parent_node:
		return
	var p: Vector2 = parent_node.global_position
	# ジャンプ中：影は (ground_x, ground_y) に固定。着地後は ground_y/ground_x を INF にして通常の足元に
	if is_finite(ground_y):
		var wx: float = ground_x if is_finite(ground_x) else p.x
		position = parent_node.to_local(Vector2(wx, ground_y))
	else:
		position = Vector2(0, offset_to_feet.y)
	queue_redraw()

func _draw() -> void:
	var points: PackedVector2Array = []
	var n := 32
	for i in n:
		var a := i * TAU / float(n)
		points.append(Vector2(radius_x * cos(a), radius_y * sin(a)))
	draw_polygon(points, [color])
