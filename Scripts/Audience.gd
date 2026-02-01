extends Node2D
## 観客：リング外（ロープ外）にのみ配置。左右・上下のリング外ストリップ。見え方はグリッド／通常とも同じ。

var _member_script: GDScript

func _ready() -> void:
	_member_script = load("res://Scripts/AudienceMember.gd") as GDScript
	if not _member_script:
		return
	_replace_left_right_with_members()
	_spawn_top_bottom()

func _replace_left_right_with_members() -> void:
	for group_name in ["Left", "Right"]:
		var group = get_node_or_null(group_name)
		if not group:
			continue
		var positions: Array[Vector2] = []
		for c in group.get_children():
			positions.append((c as Node2D).position)
			c.queue_free()
		var idx := 0
		for pos in positions:
			var m := Node2D.new()
			m.set_script(_member_script)
			m.position = pos
			m.set("type_index", idx % 2)
			group.add_child(m)
			idx += 1

func _spawn_top_bottom() -> void:
	# 上・下はリング外ストリップのみ（y 0-16, 704-720）。左右と同じ水色エリアに配置
	var step_x := 72
	# 上：リング外ストリップ y 0〜16 のみ（16ドット幅）
	var top := Node2D.new()
	top.name = "Top"
	add_child(top)
	var idx := 0
	var y := 8
	for x in range(40, 1240, step_x):
		var m := Node2D.new()
		m.set_script(_member_script)
		m.position = Vector2(x, y)
		m.set("type_index", idx % 2)
		top.add_child(m)
		idx += 1
	# 下：リング外ストリップ y 704〜720 のみ（16ドット幅）
	var bottom := Node2D.new()
	bottom.name = "Bottom"
	add_child(bottom)
	idx = 0
	y = 712
	for x in range(40, 1240, step_x):
		var m := Node2D.new()
		m.set_script(_member_script)
		m.position = Vector2(x, y)
		m.set("type_index", idx % 2)
		bottom.add_child(m)
		idx += 1

func _process(_delta: float) -> void:
	# 観客の見え方はグリッド／通常とも同じ（常に通常表示）
	for group_name in ["Left", "Right", "Top", "Bottom"]:
		var n = get_node_or_null(group_name)
		if not n:
			continue
		for c in n.get_children():
			if c is CanvasItem:
				(c as CanvasItem).modulate = Color.WHITE
