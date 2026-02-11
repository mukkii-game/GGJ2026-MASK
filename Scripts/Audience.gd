extends Node2D
## 観客：リング外（ロープ外）にのみ配置。軽量化のため間隔を広げて人数を削減。

var _member_script: GDScript

## 観客の配置間隔（大きいほど人数減・軽い）。16=密、32=約1/4、48=約1/9
@export var audience_step := 32

func _ready() -> void:
	if audience_step <= 0:
		return  # 0以下で観客なし（最大軽量化）
	_member_script = load("res://Scripts/AudienceMember.gd") as GDScript
	if not _member_script:
		return
	_replace_left_right_with_members()
	_spawn_top_bottom()

func _replace_left_right_with_members() -> void:
	var step := audience_step
	# 左側：画面左端からロープまで（x 0〜280）
	var left = get_node_or_null("Left")
	if left:
		for c in left.get_children():
			c.queue_free()
		var idx := 0
		for y in range(-10, 730, step):
			for x in range(0, 280, step):
				var m := Node2D.new()
				m.set_script(_member_script)
				m.position = Vector2(x, y)
				m.set("type_index", idx % 2)
				left.add_child(m)
				idx += 1
	# 右側：ロープから画面右端まで（x 1000〜1280）
	var right = get_node_or_null("Right")
	if right:
		for c in right.get_children():
			c.queue_free()
		var idx := 0
		for y in range(-10, 730, step):
			for x in range(1000, 1280, step):
				var m := Node2D.new()
				m.set_script(_member_script)
				m.position = Vector2(x, y)
				m.set("type_index", idx % 2)
				right.add_child(m)
				idx += 1

func _spawn_top_bottom() -> void:
	var step := audience_step
	# 上：画面上端からロープまで
	var top := Node2D.new()
	top.name = "Top"
	add_child(top)
	var idx := 0
	for y in range(-10, 17, step):
		for x in range(0, 1280, step):
			var m := Node2D.new()
			m.set_script(_member_script)
			m.position = Vector2(x, y)
			m.set("type_index", idx % 2)
			top.add_child(m)
			idx += 1
	# 下：ロープから画面下端まで
	var bottom := Node2D.new()
	bottom.name = "Bottom"
	add_child(bottom)
	idx = 0
	for y in range(704, 731, step):
		for x in range(0, 1280, step):
			var m := Node2D.new()
			m.set_script(_member_script)
			m.position = Vector2(x, y)
			m.set("type_index", idx % 2)
			bottom.add_child(m)
			idx += 1

func _process(_delta: float) -> void:
	# 観客の見え方：普通モード=明るいオレンジ、カクカクモード=明るい黄色
	var audience_color := Color(1.0, 0.7, 0.3, 1.0)  # 明るいオレンジ
	if GameManager.use_grid_mode:
		audience_color = Color(1.0, 1.0, 0.5, 1.0)  # 明るい黄色
	
	for group_name in ["Left", "Right", "Top", "Bottom"]:
		var n = get_node_or_null(group_name)
		if not n:
			continue
		for c in n.get_children():
			if c is CanvasItem:
				(c as CanvasItem).modulate = audience_color
