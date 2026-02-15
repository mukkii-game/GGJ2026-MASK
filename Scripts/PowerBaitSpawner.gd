extends Node
## パワーエサを10秒ごとにスポーン

const FIRST_SPAWN_DELAY := 10.0
const SPAWN_INTERVAL := 10.0
const POWER_BAIT_SCENE := preload("res://Scenes/Interactables/PowerBait.tscn")

var _timer: float = 0.0
var _first_spawned: bool = false


func _process(delta: float) -> void:
	_timer += delta
	var interval := FIRST_SPAWN_DELAY if not _first_spawned else SPAWN_INTERVAL
	if _timer >= interval:
		var is_first: bool = not _first_spawned
		_timer = 0.0
		_first_spawned = true
		_spawn_one(is_first)


func _spawn_one(is_first_spawn: bool = false) -> void:
	var bait: Node2D = POWER_BAIT_SCENE.instantiate() as Node2D
	if not bait:
		return
	# プレイヤーと同じ親（マット・敵と同じワールド）に追加して確実に表示
	var parent: Node = get_parent()
	var players := get_tree().get_nodes_in_group("Player")
	if players.size() > 0 and is_instance_valid(players[0]):
		var p: Node = players[0]
		if p.get_parent():
			parent = p.get_parent()
	parent.add_child(bait)
	# 最初の1匹はリングの真ん中を右→左に飛ばす（わかりやすい）
	var through_center: bool = is_first_spawn
	var horizontal: bool = true if through_center else (randi() % 2 == 0)
	bait.init_pattern(horizontal, through_center)
