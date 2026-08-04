extends Node3D

const LEVEL_COUNT := 300
const PLAYER_LIVES := 3
const PLAYER_MAX_HP := 100.0

var level := 1
var coins := 0
var lives := PLAYER_LIVES
var hp := PLAYER_MAX_HP
var total_coins := 0

var player: CharacterBody3D
var camera: Camera3D
var finish_x := 120.0
var enemies: Array[Node3D] = []
var allies: Array[Node3D] = []
var rng := RandomNumberGenerator.new()

@onready var ui := CanvasLayer.new()
var menu := Control.new()
var hud := Control.new()

func _ready():
	camera = $Camera3D
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui)
	_build_menu()
	_build_hud()
	_show_menu()

func _build_menu():
	menu.process_mode = Node.PROCESS_MODE_ALWAYS
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.85)
	menu.add_child(bg)

	var title := Label.new()
	title.text = "铁蛋的冒险日记 3D"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 0)
	title.position.y = 80
	menu.add_child(title)

	var btn_start := Button.new()
	btn_start.text = "开始冒险"
	btn_start.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE, 0)
	btn_start.position.y = -40
	btn_start.pressed.connect(_on_start)
	menu.add_child(btn_start)

	var btn_continue := Button.new()
	btn_continue.text = "继续游戏"
	btn_continue.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE, 0)
	btn_continue.position.y = 30
	btn_continue.pressed.connect(_on_continue)
	menu.add_child(btn_continue)

	ui.add_child(menu)

func _build_hud():
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var label := Label.new()
	label.name = "HudLabel"
	label.position = Vector2(16, 16)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color.WHITE)
	hud.add_child(label)

	var touch_left := Button.new()
	touch_left.text = "←"
	touch_left.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 0)
	touch_left.position = Vector2(20, -100)
	touch_left.size = Vector2(80, 80)
	touch_left.button_down.connect(func(): _input_left = true)
	touch_left.button_up.connect(func(): _input_left = false)
	hud.add_child(touch_left)

	var touch_right := Button.new()
	touch_right.text = "→"
	touch_right.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 0)
	touch_right.position = Vector2(110, -100)
	touch_right.size = Vector2(80, 80)
	touch_right.button_down.connect(func(): _input_right = true)
	touch_right.button_up.connect(func(): _input_right = false)
	hud.add_child(touch_right)

	var touch_jump := Button.new()
	touch_jump.text = "跳"
	touch_jump.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 0)
	touch_jump.position = Vector2(-100, -100)
	touch_jump.size = Vector2(80, 80)
	touch_jump.button_down.connect(func(): _input_jump = true)
	touch_jump.button_up.connect(func(): _input_jump = false)
	hud.add_child(touch_jump)

	ui.add_child(hud)
	hud.hide()

func _show_menu():
	menu.show()
	hud.hide()
	get_tree().paused = true

func _hide_menu():
	menu.hide()
	hud.show()
	get_tree().paused = false

func _on_start():
	level = 1
	coins = 0
	lives = PLAYER_LIVES
	hp = PLAYER_MAX_HP
	total_coins = 0
	_save()
	_load_level()
	_hide_menu()

func _on_continue():
	_load()
	_load_level()
	_hide_menu()

func _load_level():
	# 清理旧关卡（保留环境、相机、UI）
	for child in get_children():
		if child.name in ["WorldEnvironment", "DirectionalLight3D", "Camera3D", "Main"]:
			continue
		if child == ui:
			continue
		child.queue_free()
	enemies.clear()
	allies.clear()

	rng.seed = level * 777
	var difficulty := 1.0 + (level - 1) * 0.02
	if level >= LEVEL_COUNT:
		difficulty = 5.0

	finish_x = clamp(120.0 + level * 8.0, 120.0, 260.0)

	# 地面
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	ground.position = Vector3(finish_x / 2.0, -0.5, 0)
	var ground_col := CollisionShape3D.new()
	ground_col.shape = BoxShape3D.new()
	ground_col.shape.size = Vector3(finish_x + 40, 1, 20)
	ground.add_child(ground_col)
	var ground_mesh := MeshInstance3D.new()
	ground_mesh.mesh = BoxMesh.new()
	ground_mesh.mesh.size = Vector3(finish_x + 40, 1, 20)
	ground_mesh.material_override = _color_mat(Color(0.2, 0.45, 0.2))
	ground.add_child(ground_mesh)
	add_child(ground)

	# 空中平台
	var platform_count := 3 + level / 10
	for i in platform_count:
		var x := rng.randf_range(30, finish_x - 30)
		var y := rng.randf_range(1.5, 3.5)
		var w := rng.randf_range(6, 14)
		var platform := StaticBody3D.new()
		platform.position = Vector3(x, y, 0)
		var col := CollisionShape3D.new()
		col.shape = BoxShape3D.new()
		col.shape.size = Vector3(w, 0.5, 4)
		platform.add_child(col)
		var mesh := MeshInstance3D.new()
		mesh.mesh = BoxMesh.new()
		mesh.mesh.size = Vector3(w, 0.5, 4)
		mesh.material_override = _color_mat(Color(0.5, 0.35, 0.2))
		platform.add_child(mesh)
		add_child(platform)

	# 建筑
	var building_count := 2 + level / 20
	for i in building_count:
		var x := rng.randf_range(30, finish_x - 30)
		var h := rng.randf_range(5, 12)
		var w := rng.randf_range(4, 8)
		var building := StaticBody3D.new()
		building.position = Vector3(x, h / 2.0, -6)
		var b_col := CollisionShape3D.new()
		b_col.shape = BoxShape3D.new()
		b_col.shape.size = Vector3(w, h, 6)
		building.add_child(b_col)
		var b_mesh := MeshInstance3D.new()
		b_mesh.mesh = BoxMesh.new()
		b_mesh.mesh.size = Vector3(w, h, 6)
		var c := Color.from_hsv(rng.randf(), 0.7, 0.9)
		b_mesh.material_override = _color_mat(c)
		building.add_child(b_mesh)
		add_child(building)

	# 金币
	var coin_count := 4 + level / 5
	for i in coin_count:
		var x := rng.randf_range(15, finish_x - 15)
		var y := rng.randf_range(1.5, 4)
		add_child(_create_coin(Vector3(x, y, 0)))

	# 玩家
	player = _create_player(Vector3(5, 2, 0))
	add_child(player)

	# 伙伴
	var ally1 := _create_ally(-2)
	var ally2 := _create_ally(2)
	add_child(ally1)
	add_child(ally2)
	allies.append(ally1)
	allies.append(ally2)

	# 怪物
	var enemy_count := 2 + level / 8
	if level >= LEVEL_COUNT:
		enemy_count = 20
	for i in enemy_count:
		var x := rng.randf_range(30, finish_x - 20)
		var dmg := rng.randf_range(2, 20) * difficulty
		if level >= LEVEL_COUNT and i == 0:
			dmg = 30
		var enemy := _create_enemy(Vector3(x, 1, 0), dmg, difficulty)
		add_child(enemy)
		enemies.append(enemy)

	# 终点旗帜
	var flag := Area3D.new()
	flag.position = Vector3(finish_x, 2, 0)
	flag.collision_mask = 2
	var flag_col := CollisionShape3D.new()
	flag_col.shape = CylinderShape3D.new()
	flag_col.shape.radius = 2
	flag_col.shape.height = 4
	flag.add_child(flag_col)
	flag.body_entered.connect(_on_finish_reached)
	add_child(flag)
	var flag_mesh := MeshInstance3D.new()
	flag_mesh.mesh = CylinderMesh.new()
	flag_mesh.mesh.top_radius = 0.15
	flag_mesh.mesh.bottom_radius = 0.15
	flag_mesh.mesh.height = 4
	flag_mesh.material_override = _color_mat(Color.YELLOW)
	flag.add_child(flag_mesh)

	_update_hud()

var _input_left := false
var _input_right := false
var _input_jump := false

func _physics_process(delta):
	if get_tree().paused:
		return
	if player == null or not is_instance_valid(player):
		return

	var dir := 0.0
	if Input.is_action_pressed("move_left") or _input_left:
		dir -= 1
	if Input.is_action_pressed("move_right") or _input_right:
		dir += 1

	player.velocity.x = dir * 5.0
	if (Input.is_action_just_pressed("jump") or _input_jump) and player.is_on_floor():
		player.velocity.y = 16.0
	_input_jump = false
	player.velocity.y -= 30.0 * delta
	player.move_and_slide()

	# 相机跟随
	camera.position.x = lerp(camera.position.x, player.position.x + 4.0, delta * 3.0)
	camera.position.x = clamp(camera.position.x, 6.0, finish_x - 6.0)

	# 掉出地图
	if player.position.y < -10:
		_take_damage(100)

	# 伙伴逻辑
	for ally in allies:
		if is_instance_valid(ally):
			_ally_update(ally, delta)

	# 敌人逻辑
	for enemy in enemies:
		if is_instance_valid(enemy):
			_enemy_update(enemy, delta)

	_update_hud()

func _ally_update(ally: Node3D, delta: float):
	var t := Time.get_time_dict_from_system()
	var target := player.position + Vector3(
		cos(ally.get_meta("offset") + float(t["second"])),
		1.5,
		sin(ally.get_meta("offset"))
	)
	ally.position = ally.position.lerp(target, delta * 4.0)

	var nearest: Node3D = null
	var best := 30.0
	for e in enemies:
		if is_instance_valid(e):
			var d := ally.position.distance_to(e.position)
			if d < best:
				best = d
				nearest = e
	if nearest != null:
		var cd: float = ally.get_meta("cooldown")
		cd -= delta
		if cd <= 0:
			cd = 0.4
			var ehp: int = nearest.get_meta("hp")
			ehp -= 1
			if ehp <= 0:
				nearest.queue_free()
				enemies.erase(nearest)
				coins += 2
				total_coins += 2
			else:
				nearest.set_meta("hp", ehp)
		ally.set_meta("cooldown", cd)

func _enemy_update(enemy: Node3D, delta: float):
	var d := enemy.position.distance_to(player.position)
	var dir := 0.0
	if d < 20:
		dir = sign(player.position.x - enemy.position.x)
	enemy.velocity.x = dir * enemy.get_meta("speed")
	enemy.velocity.y -= 30.0 * delta
	enemy.move_and_slide()

	var cd: float = enemy.get_meta("attack_cooldown")
	if d < 1.8 and cd <= 0:
		cd = 1.0
		_take_damage(enemy.get_meta("damage"))
	cd -= delta
	enemy.set_meta("attack_cooldown", cd)

func _create_player(pos: Vector3) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.name = "Player"
	body.position = pos
	body.collision_layer = 2
	body.collision_mask = 1
	var col := CollisionShape3D.new()
	col.shape = CapsuleShape3D.new()
	col.shape.radius = 0.5
	col.shape.height = 1.8
	body.add_child(col)
	var mesh := MeshInstance3D.new()
	mesh.mesh = CapsuleMesh.new()
	mesh.mesh.radius = 0.5
	mesh.mesh.height = 1.8
	mesh.material_override = _color_mat(Color.ORANGE)
	body.add_child(mesh)
	return body

func _create_ally(offset: float) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.name = "Ally"
	body.set_meta("offset", offset)
	body.set_meta("cooldown", 0.0)
	body.collision_layer = 0
	body.collision_mask = 1
	var col := CollisionShape3D.new()
	col.shape = SphereShape3D.new()
	col.shape.radius = 0.4
	body.add_child(col)
	var mesh := MeshInstance3D.new()
	mesh.mesh = SphereMesh.new()
	mesh.mesh.radius = 0.4
	mesh.mesh.height = 0.8
	mesh.material_override = _color_mat(Color.CORNFLOWER_BLUE)
	body.add_child(mesh)
	return body

func _create_enemy(pos: Vector3, dmg: float, difficulty: float) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.name = "Enemy"
	body.position = pos
	body.collision_layer = 4
	body.collision_mask = 1
	body.set_meta("speed", 3.0 + difficulty * 1.5)
	body.set_meta("damage", dmg)
	body.set_meta("hp", int(2 + difficulty * 3))
	body.set_meta("attack_cooldown", 0.0)
	var col := CollisionShape3D.new()
	col.shape = BoxShape3D.new()
	col.shape.size = Vector3(1, 1.4, 1)
	body.add_child(col)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.mesh.size = Vector3(1, 1.4, 1)
	mesh.material_override = _color_mat(Color.CRIMSON)
	body.add_child(mesh)
	return body

func _create_coin(pos: Vector3) -> Area3D:
	var coin := Area3D.new()
	coin.name = "Coin"
	coin.position = pos
	coin.collision_layer = 8
	coin.collision_mask = 2
	var col := CollisionShape3D.new()
	col.shape = CylinderShape3D.new()
	col.shape.radius = 0.4
	col.shape.height = 0.1
	coin.add_child(col)
	var mesh := MeshInstance3D.new()
	mesh.mesh = CylinderMesh.new()
	mesh.mesh.top_radius = 0.4
	mesh.mesh.bottom_radius = 0.4
	mesh.mesh.height = 0.1
	mesh.material_override = _color_mat(Color.GOLD)
	coin.add_child(mesh)
	coin.body_entered.connect(_on_coin_collected.bind(coin))
	return coin

func _on_coin_collected(body: Node, coin: Area3D):
	if body == player:
		coin.queue_free()
		coins += 1
		total_coins += 1
		_update_hud()

func _on_finish_reached(body: Node):
	if body == player:
		if level >= LEVEL_COUNT:
			level = 1
			lives = PLAYER_LIVES
		else:
			level += 1
		hp = PLAYER_MAX_HP
		_save()
		_show_level_complete()

func _take_damage(amount: float):
	hp -= amount
	if hp <= 0:
		lives -= 1
		if lives <= 0:
			_save()
			_show_game_over()
		else:
			hp = PLAYER_MAX_HP
			player.position = Vector3(5, 3, 0)
			player.velocity = Vector3.ZERO
	_update_hud()

func _show_level_complete():
	get_tree().paused = true
	var dlg := AcceptDialog.new()
	dlg.process_mode = Node.PROCESS_MODE_ALWAYS
	dlg.title = "关卡完成"
	dlg.dialog_text = "第 %d 关完成！\n金币：%d" % [level, coins]
	dlg.confirmed.connect(func():
		dlg.queue_free()
		_load_level()
		get_tree().paused = false
	)
	ui.add_child(dlg)
	dlg.popup_centered()

func _show_game_over():
	get_tree().paused = true
	var dlg := AcceptDialog.new()
	dlg.process_mode = Node.PROCESS_MODE_ALWAYS
	dlg.title = "游戏结束"
	dlg.dialog_text = "到达关卡：%d\n总金币：%d" % [level, total_coins]
	dlg.confirmed.connect(func():
		dlg.queue_free()
		level = 1
		coins = 0
		lives = PLAYER_LIVES
		hp = PLAYER_MAX_HP
		total_coins = 0
		_save()
		_load_level()
		get_tree().paused = false
	)
	ui.add_child(dlg)
	dlg.popup_centered()

func _update_hud():
	var label := hud.get_node("HudLabel") as Label
	label.text = "关卡 %d/%d   金币:%d   生命:%d   血量:%d/%d" % [level, LEVEL_COUNT, coins, lives, int(hp), int(PLAYER_MAX_HP)]

func _color_mat(c: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = 0.6
	return mat

func _save():
	var cfg := ConfigFile.new()
	cfg.set_value("game", "level", level)
	cfg.set_value("game", "coins", coins)
	cfg.set_value("game", "lives", lives)
	cfg.set_value("game", "hp", hp)
	cfg.set_value("game", "total_coins", total_coins)
	cfg.save("user://save.cfg")

func _load():
	var cfg := ConfigFile.new()
	var err := cfg.load("user://save.cfg")
	if err == OK:
		level = cfg.get_value("game", "level", 1)
		coins = cfg.get_value("game", "coins", 0)
		lives = cfg.get_value("game", "lives", PLAYER_LIVES)
		hp = cfg.get_value("game", "hp", PLAYER_MAX_HP)
		total_coins = cfg.get_value("game", "total_coins", 0)
