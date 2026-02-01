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
	# 左右も画面全体を敷き詰める
	var step_x := 16
	var step_y := 16
	
	# 左側：画面左端からロープまで（x 0〜280）
	var left = get_node_or_null("Left")
	if left:
		for c in left.get_children():
			c.queue_free()
		var idx := 0
		for y in range(-10, 730, step_y):  # 上下にも広げる
			for x in range(0, 280, step_x):
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
		for y in range(-10, 730, step_y):  # 上下にも広げる
			for x in range(1000, 1280, step_x):
				var m := Node2D.new()
				m.set_script(_member_script)
				m.position = Vector2(x, y)
				m.set("type_index", idx % 2)
				right.add_child(m)
				idx += 1

func _spawn_top_bottom() -> void:
	# 上・下は画面全体を敷き詰める（黒い背景を観客で置き換え）
	var step_x := 16  # さらに密に配置（黒い部分を完全に埋める）
	var step_y := 4   # 縦方向も非常に密に配置
	
	# 上：画面上端からロープまで（y 0〜16を完全に埋める）
	var top := Node2D.new()
	top.name = "Top"
	add_child(top)
	var idx := 0
	for y in range(-10, 17, step_y):  # さらに上から配置
		for x in range(0, 1280, step_x):  # 画面全体を埋める
			var m := Node2D.new()
			m.set_script(_member_script)
			m.position = Vector2(x, y)
			m.set("type_index", idx % 2)
			top.add_child(m)
			idx += 1
	
	# 下：ロープから画面下端まで（y 704〜730を完全に埋める）
	var bottom := Node2D.new()
	bottom.name = "Bottom"
	add_child(bottom)
	idx = 0
	for y in range(704, 731, step_y):  # さらに下まで配置
		for x in range(0, 1280, step_x):  # 画面全体を埋める
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
