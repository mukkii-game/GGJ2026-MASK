extends Node

var money = 0

<<<<<<< Updated upstream
=======
## グリッドモード（G/右クリックでトグル）。true=カクカク移動・マットグレー・観客青
var use_grid_mode: bool = false
## 敵を全員止める（体当たりテスト用）。true の間は敵は移動しない
var enemies_frozen: bool = false

>>>>>>> Stashed changes
#NOTE This class is our game manager and handles the players money and loading scenes
#These functions can be called globally from anywhere

func reset_money():
	money = 0

func add_money(addmoney : int):
	money += addmoney

func load_next_level(next_scene : PackedScene):
	get_tree().change_scene_to_packed(next_scene)

func load_same_level():
	get_tree().reload_current_scene()
