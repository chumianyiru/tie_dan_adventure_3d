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
var level_root: Node3D

@onready var ui := CanvasLayer.new()
var menu := Control.new()
var hud := Control.new()

func _ready():
	camera = $Camera3D
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 55.0
	camera.position = Vector3(0, 10, 16)
	camera.look_at(Vector3(0, 1.5, 0), Vector3.UP)
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui)
	level_root = Node3D.new()
	level_root.name = "LevelRoot"
	add_child(level_root)
	_build_menu()
	_build_hud()
	_show_menu()

func _build_menu():
	menu.process_mode = Node.PROCESS_MODE_ALWAYS
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.08, 0.15, 0.92)
	menu.add_child(bg)

	var title := Label.new()
	title.text = "铁蛋的冒险日记 3D"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 58)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 0)
	title.position.y = 70
	menu.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "3D 横版冒险 · 300+ 关卡"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
	subtitle.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 0)
	subtitle.position.y = 140
	menu.add_child(subtitle)

	var btn_start := Button.new()
	btn_start.text = "开始冒险"
	btn_start.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE, 0)
	btn_start.position.y = -30
	btn_start.size = Vector2(200, 56)
	btn_start.pressed.connect(_on_start)
	menu.add_child(btn_start)

	var btn_continue := Button.new()
	btn_continue.text = "继续游戏"
	btn_continue.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE, 0)
	btn_continue.position.y = 50
	btn_continue.size = Vector2(200, 56)
	btn_continue.pressed.connect(_on_continue)
	menu.add_child(btn_continue)

	ui.add_child(menu)

func _build_hud():
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var label := Label.new()
	label.name = "HudLabel"
	label.position = Vector2(16, 16)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_outline_size", 4)
	hud.add_child(label)

	var touch_left := Button.new()
	touch_left.text = "←"
	touch_left.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 0)
	touch_left.position = Vector2(20, -120)
	touch_left.size = Vector2(90, 90)
	touch_left.button_down.connect(func(): _input_left = true)
	touch_left.button_up.connect(func(): _input_left = false)
	hud.add_child(touch_left)

	var touch_right := Button.new()
	touch_right.text = "→"
	touch_right.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 0)
	touch_right.position = Vector2(125, -120)
	touch_right.size = Vector2(90, 90)
	touch_right.button_down.connect(func(): _input_right = true)
	touch_right.button_up.connect(func(): _input_right = false)
	hud.add_child(touch_right)

	var touch_jump := Button.new()
	touch_jump.text = "跳"
	touch_jump.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 0)
	touch_jump.position = Vector2(-115, -120)
	touch_jump.size = Vector2(90, 90)
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
	# 清理旧关卡
	for child in level_root.get_children():
		child.queue_free()
	enemies.clear()
	allies.clear()

	rng.seed = level * 777
	var difficulty := 1.0 + (level - 1) * 0.02
	if level >= LEVEL_COUNT:
		difficulty = 5.0

	finish_x = clamp(120.0 + level * 8.0, 120.0, 260.0)

	# 天空色与光照微调
	var sky_hue := fmod(level * 0.03, 1.0)
	var sky: Environment = $WorldEnvironment.environment
	sky.background_color = Color.from_hsv(sky_hue, 0.35, 0.95)
	$DirectionalLight3D.light_color = Color.from_hsv(fmod(sky_hue + 0.08, 1.0), 0.25, 1.0)

	# 地面
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	ground.position = Vector3(finish_x / 2.0, -0.5, 0)
	var ground_col := CollisionShape3D.new()
	ground_col.shape = BoxShape3D.new()
	ground_col.shape.size = Vector3(finish_x + 60, 1, 24)
	ground.add_child(ground_col)
	var ground_mesh := MeshInstance3D.new()
	ground_mesh.mesh = BoxMesh.new()
	ground_mesh.mesh.size = Vector3(finish_x + 60, 1, 24)
	ground_mesh.material_override = _ground_mat()
	ground.add_child(ground_mesh)
	level_root.add_child(ground)

	# 路边草皮与装饰
	for i in range(0, int(finish_x), 4):
		if rng.randf() > 0.6:
			var gz := rng.randf_range(-10, -5) if rng.randf() > 0.5 else rng.randf_range(5, 10)
			level_root.add_child(_create_grass(Vector3(i + rng.randf_range(-1, 1), 0, gz)))
		if rng.randf() > 0.85:
			var rz := rng.randf_range(-11, -6) if rng.randf() > 0.5 else rng.randf_range(6, 11)
			level_root.add_child(_create_rock(Vector3(i + rng.randf_range(-1, 1), 0, rz), rng.randf_range(0.25, 0.65)))
		if rng.randf() > 0.82:
			var fz := rng.randf_range(-8, -3) if rng.randf() > 0.5 else rng.randf_range(3, 8)
			level_root.add_child(_create_flower(Vector3(i + rng.randf_range(-1, 1), 0, fz)))
		if rng.randf() > 0.92:
			var tx: float = clamp(i + rng.randf_range(5, 15), 10, finish_x - 20)
			level_root.add_child(_create_tree(Vector3(tx, 0, rng.randf_range(-11, 11))))

	# 天空云朵
	var cloud_count := 3 + level / 30
	for i in cloud_count:
		var cx := rng.randf_range(10, finish_x)
		var cy := rng.randf_range(12, 22)
		var cz := rng.randf_range(-35, -15)
		level_root.add_child(_create_cloud(Vector3(cx, cy, cz), rng.randf_range(0.8, 2.0)))

	# 空中平台
	var platform_count := 3 + level / 10
	for i in platform_count:
		var x := rng.randf_range(30, finish_x - 30)
		var y := rng.randf_range(1.8, 4.2)
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
		mesh.material_override = _platform_mat()
		platform.add_child(mesh)
		# 平台支柱
		var leg_l := MeshInstance3D.new()
		leg_l.mesh = BoxMesh.new()
		leg_l.mesh.size = Vector3(0.4, y, 0.4)
		leg_l.position = Vector3(-w / 2.0 + 0.4, -y / 2.0, 0)
		leg_l.material_override = _platform_mat()
		platform.add_child(leg_l)
		var leg_r := MeshInstance3D.new()
		leg_r.mesh = BoxMesh.new()
		leg_r.mesh.size = Vector3(0.4, y, 0.4)
		leg_r.position = Vector3(w / 2.0 - 0.4, -y / 2.0, 0)
		leg_r.material_override = _platform_mat()
		platform.add_child(leg_r)
		level_root.add_child(platform)

	# 建筑（房子）
	var building_count := 2 + level / 20
	for i in building_count:
		var x := rng.randf_range(30, finish_x - 30)
		level_root.add_child(_create_house(Vector3(x, 0, -8)))

	# 金币
	var coin_count := 5 + level / 4
	for i in coin_count:
		var x := rng.randf_range(15, finish_x - 15)
		var y := rng.randf_range(1.2, 4.5)
		level_root.add_child(_create_coin(Vector3(x, y, rng.randf_range(-2, 2))))

	# 玩家
	player = _create_player(Vector3(5, 2, 0))
	level_root.add_child(player)

	# 伙伴
	var ally1 := _create_ally(-2)
	var ally2 := _create_ally(2)
	level_root.add_child(ally1)
	level_root.add_child(ally2)
	allies.append(ally1)
	allies.append(ally2)

	# 怪物
	var enemy_count := 2 + level / 8
	if level >= LEVEL_COUNT:
		enemy_count = 25
	for i in enemy_count:
		var x := rng.randf_range(30, finish_x - 20)
		var dmg := rng.randf_range(2, 20) * difficulty
		if level >= LEVEL_COUNT and i == 0:
			dmg = 35
		var enemy := _create_enemy(Vector3(x, 1, rng.randf_range(-2, 2)), dmg, difficulty)
		level_root.add_child(enemy)
		enemies.append(enemy)

	# 终点城堡
	level_root.add_child(_create_castle(Vector3(finish_x, 0, 0)))

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

	player.velocity.x = dir * 5.5
	if (Input.is_action_just_pressed("jump") or _input_jump) and player.is_on_floor():
		player.velocity.y = 17.0
	_input_jump = false
	player.velocity.y -= 32.0 * delta
	player.move_and_slide()

	# 玩家朝向（模型面向左右）
	if dir != 0:
		var model := player.get_node("Model") as Node3D
		model.rotation.y = -PI / 2.0 * sign(dir)

	# 相机跟随
	var target_pos := player.position + Vector3(10.0, 9.0, 14.0)
	camera.position = camera.position.lerp(target_pos, delta * 3.0)
	camera.position.x = clamp(camera.position.x, 6.0, finish_x - 6.0)
	camera.look_at(player.position + Vector3(0, 1.5, 0), Vector3.UP)

	# 掉出地图
	if player.position.y < -12:
		_take_damage(100)

	# 伙伴逻辑
	for ally in allies:
		if is_instance_valid(ally):
			_ally_update(ally, delta)

	# 敌人逻辑
	for enemy in enemies:
		if is_instance_valid(enemy):
			_enemy_update(enemy, delta)

	# 金币旋转
	for c in level_root.get_children():
		if c.name.begins_with("Coin"):
			c.rotate_y(delta * 3.0)

	_update_hud()

func _ally_update(ally: Node3D, delta: float):
	var t := Time.get_time_dict_from_system()
	var target := player.position + Vector3(
		cos(ally.get_meta("offset") + float(t["second"]) * 1.5) * 2.5,
		1.8 + sin(Time.get_ticks_msec() / 400.0 + ally.get_meta("offset")) * 0.3,
		sin(ally.get_meta("offset") + float(t["second"]) * 1.5) * 2.0
	)
	ally.position = ally.position.lerp(target, delta * 4.0)
	ally.rotate_y(delta * 1.5)

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
			cd = 0.35
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
	if d < 22:
		dir = sign(player.position.x - enemy.position.x)
	enemy.velocity.x = dir * enemy.get_meta("speed")
	enemy.velocity.y -= 32.0 * delta
	enemy.move_and_slide()
	if dir != 0:
		var body := enemy.get_node("Body") as Node3D
		body.rotation.y = -PI / 2.0 * sign(dir)

	var cd: float = enemy.get_meta("attack_cooldown")
	if d < 1.8 and cd <= 0:
		cd = 0.9
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
	col.shape.radius = 0.45
	col.shape.height = 1.6
	body.add_child(col)

	var root := Node3D.new()
	root.name = "Model"
	root.rotation.y = -PI / 2.0
	body.add_child(root)

	# 身体（上衣）
	var torso := MeshInstance3D.new()
	torso.mesh = CapsuleMesh.new()
	torso.mesh.radius = 0.38
	torso.mesh.height = 0.9
	torso.material_override = _color_mat(Color(0.95, 0.55, 0.15), 0.5)
	root.add_child(torso)

	# 裤子
	var pants := MeshInstance3D.new()
	pants.mesh = CapsuleMesh.new()
	pants.mesh.radius = 0.32
	pants.mesh.height = 0.55
	pants.position = Vector3(0, -0.55, 0)
	pants.material_override = _color_mat(Color(0.2, 0.3, 0.55), 0.7)
	root.add_child(pants)

	# 腿与鞋
	for side in [-1, 1]:
		var leg := MeshInstance3D.new()
		leg.mesh = CapsuleMesh.new()
		leg.mesh.radius = 0.11
		leg.mesh.height = 0.55
		leg.position = Vector3(side * 0.22, -0.85, 0)
		leg.material_override = _color_mat(Color(0.2, 0.3, 0.55), 0.7)
		root.add_child(leg)
		var shoe := MeshInstance3D.new()
		shoe.mesh = BoxMesh.new()
		shoe.mesh.size = Vector3(0.24, 0.14, 0.32)
		shoe.position = Vector3(side * 0.22, -1.12, 0.06)
		shoe.material_override = _color_mat(Color(0.12, 0.08, 0.05), 0.6)
		root.add_child(shoe)

	# 头
	var head := MeshInstance3D.new()
	head.mesh = SphereMesh.new()
	head.mesh.radius = 0.3
	head.mesh.height = 0.6
	head.position = Vector3(0, 0.7, 0)
	head.material_override = _color_mat(Color(1, 0.85, 0.65), 0.5)
	root.add_child(head)

	# 眼睛
	for side in [-1, 1]:
		var eye := MeshInstance3D.new()
		eye.mesh = SphereMesh.new()
		eye.mesh.radius = 0.055
		eye.mesh.height = 0.11
		eye.position = Vector3(side * 0.11, 0.76, 0.25)
		eye.material_override = _color_mat(Color.BLACK, 0.1, 0.0, true)
		root.add_child(eye)

	# 帽子（带帽檐）
	var hat := MeshInstance3D.new()
	hat.mesh = CylinderMesh.new()
	hat.mesh.top_radius = 0.08
	hat.mesh.bottom_radius = 0.32
	hat.mesh.height = 0.32
	hat.position = Vector3(0, 1.02, 0)
	hat.material_override = _color_mat(Color(0.1, 0.35, 0.75), 0.5)
	root.add_child(hat)
	var brim := MeshInstance3D.new()
	brim.mesh = CylinderMesh.new()
	brim.mesh.top_radius = 0.42
	brim.mesh.bottom_radius = 0.42
	brim.mesh.height = 0.04
	brim.position = Vector3(0, 0.86, 0)
	brim.material_override = _color_mat(Color(0.1, 0.35, 0.75), 0.5)
	root.add_child(brim)

	# 背包
	var pack := MeshInstance3D.new()
	pack.mesh = BoxMesh.new()
	pack.mesh.size = Vector3(0.45, 0.5, 0.22)
	pack.position = Vector3(0, 0.05, -0.32)
	pack.material_override = _color_mat(Color(0.35, 0.25, 0.15), 0.7)
	root.add_child(pack)

	# 背后的小剑
	var sword := MeshInstance3D.new()
	sword.mesh = BoxMesh.new()
	sword.mesh.size = Vector3(0.08, 0.7, 0.12)
	sword.position = Vector3(0, 0.1, -0.45)
	sword.rotation.x = -0.2
	sword.material_override = _color_mat(Color(0.75, 0.75, 0.8), 0.2, 0.6)
	root.add_child(sword)
	var hilt := MeshInstance3D.new()
	hilt.mesh = BoxMesh.new()
	hilt.mesh.size = Vector3(0.22, 0.06, 0.14)
	hilt.position = Vector3(0, 0.48, -0.42)
	hilt.material_override = _color_mat(Color(0.35, 0.2, 0.1), 0.5)
	root.add_child(hilt)

	# 手臂
	for side in [-1, 1]:
		var arm := MeshInstance3D.new()
		arm.mesh = CapsuleMesh.new()
		arm.mesh.radius = 0.09
		arm.mesh.height = 0.5
		arm.position = Vector3(side * 0.42, 0.18, 0)
		arm.rotation.z = side * 0.35
		arm.material_override = _color_mat(Color(0.95, 0.55, 0.15), 0.5)
		root.add_child(arm)

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
	col.shape.radius = 0.45
	body.add_child(col)

	var root := Node3D.new()
	root.name = "Model"
	body.add_child(root)

	var color := Color.from_hsv(fmod(offset + 0.6, 1.0), 0.8, 1.0)

	# 核心球
	var core := MeshInstance3D.new()
	core.mesh = SphereMesh.new()
	core.mesh.radius = 0.32
	core.mesh.height = 0.64
	core.material_override = _color_mat(color, 0.2, 0.3, true)
	root.add_child(core)

	# 眼睛
	for side in [-1, 1]:
		var eye := MeshInstance3D.new()
		eye.mesh = SphereMesh.new()
		eye.mesh.radius = 0.06
		eye.mesh.height = 0.12
		eye.position = Vector3(side * 0.12, 0.08, 0.26)
		eye.material_override = _color_mat(Color.WHITE, 0.1, 0.0, true)
		root.add_child(eye)
		var pupil := MeshInstance3D.new()
		pupil.mesh = SphereMesh.new()
		pupil.mesh.radius = 0.03
		pupil.mesh.height = 0.06
		pupil.position = Vector3(side * 0.12, 0.08, 0.31)
		pupil.material_override = _color_mat(Color.BLACK, 0.1, 0.0, true)
		root.add_child(pupil)

	# 外环
	var ring := MeshInstance3D.new()
	ring.mesh = TorusMesh.new()
	ring.mesh.inner_radius = 0.42
	ring.mesh.outer_radius = 0.48
	ring.rotation.x = PI / 2.0
	ring.material_override = _color_mat(Color.WHITE, 0.1, 0.1, true)
	root.add_child(ring)

	# 小翅膀
	for side in [-1, 1]:
		var wing := MeshInstance3D.new()
		wing.mesh = BoxMesh.new()
		wing.mesh.size = Vector3(0.5, 0.08, 0.16)
		wing.position = Vector3(side * 0.5, 0, 0)
		wing.rotation.z = side * 0.45
		wing.material_override = _color_mat(color.lightened(0.3), 0.3, 0.0, true)
		root.add_child(wing)

	# 头顶光环
	var halo := MeshInstance3D.new()
	halo.mesh = TorusMesh.new()
	halo.mesh.inner_radius = 0.22
	halo.mesh.outer_radius = 0.26
	halo.position = Vector3(0, 0.55, 0)
	halo.rotation.x = PI / 2.0
	halo.material_override = _color_mat(Color.YELLOW, 0.1, 0.0, true)
	root.add_child(halo)

	return body

func _create_enemy(pos: Vector3, dmg: float, difficulty: float) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.name = "Enemy"
	body.position = pos
	body.collision_layer = 4
	body.collision_mask = 1
	body.set_meta("speed", 3.2 + difficulty * 1.6)
	body.set_meta("damage", dmg)
	body.set_meta("hp", int(2 + difficulty * 3))
	body.set_meta("attack_cooldown", 0.0)

	var root := Node3D.new()
	root.name = "Body"
	body.add_child(root)

	var c := Color.from_hsv(rng.randf_range(0.92, 1.08), 0.85, 0.85)
	if c.h > 1.0:
		c.h -= 1.0

	# 身体
	var torso := MeshInstance3D.new()
	torso.mesh = CapsuleMesh.new()
	torso.mesh.radius = 0.42
	torso.mesh.height = 1.0
	torso.material_override = _color_mat(c, 0.35)
	root.add_child(torso)

	# 肚子斑点
	var belly := MeshInstance3D.new()
	belly.mesh = SphereMesh.new()
	belly.mesh.radius = 0.24
	belly.mesh.height = 0.48
	belly.position = Vector3(0, -0.05, 0.28)
	belly.material_override = _color_mat(c.lightened(0.4), 0.4)
	root.add_child(belly)

	# 角
	for side in [-1, 1]:
		var horn := MeshInstance3D.new()
		horn.mesh = CylinderMesh.new()
		horn.mesh.top_radius = 0.0
		horn.mesh.bottom_radius = 0.12
		horn.mesh.height = 0.5
		horn.position = Vector3(side * 0.22, 0.85, 0)
		horn.rotation.z = -side * 0.45
		horn.material_override = _color_mat(Color(0.5, 0.5, 0.5), 0.3)
		root.add_child(horn)

	# 眉毛
	for side in [-1, 1]:
		var brow := MeshInstance3D.new()
		brow.mesh = BoxMesh.new()
		brow.mesh.size = Vector3(0.18, 0.06, 0.06)
		brow.position = Vector3(side * 0.16, 0.42, 0.35)
		brow.rotation.z = -side * 0.35
		brow.material_override = _color_mat(Color(0.2, 0.1, 0.1), 0.5)
		root.add_child(brow)

	# 眼睛
	for side in [-1, 1]:
		var eye := MeshInstance3D.new()
		eye.mesh = SphereMesh.new()
		eye.mesh.radius = 0.08
		eye.mesh.height = 0.16
		eye.position = Vector3(side * 0.16, 0.32, 0.32)
		eye.material_override = _color_mat(Color(1, 0.1, 0.1), 0.1, 0.0, true)
		root.add_child(eye)

	# 腿
	for side in [-1, 1]:
		var leg := MeshInstance3D.new()
		leg.mesh = CapsuleMesh.new()
		leg.mesh.radius = 0.11
		leg.mesh.height = 0.45
		leg.position = Vector3(side * 0.2, -0.55, 0)
		leg.material_override = _color_mat(c.darkened(0.3), 0.5)
		root.add_child(leg)

	# 尾巴
	var tail := MeshInstance3D.new()
	tail.mesh = CapsuleMesh.new()
	tail.mesh.radius = 0.1
	tail.mesh.height = 0.65
	tail.position = Vector3(0, -0.25, -0.45)
	tail.rotation.x = -0.8
	tail.material_override = _color_mat(c.darkened(0.35), 0.5)
	root.add_child(tail)

	# 碰撞体
	var col := CollisionShape3D.new()
	col.shape = CapsuleShape3D.new()
	col.shape.radius = 0.42
	col.shape.height = 1.15
	body.add_child(col)
	return body

func _create_coin(pos: Vector3) -> Area3D:
	var coin := Area3D.new()
	coin.name = "Coin"
	coin.position = pos
	coin.collision_layer = 8
	coin.collision_mask = 2
	var col := CollisionShape3D.new()
	col.shape = CylinderShape3D.new()
	col.shape.radius = 0.42
	col.shape.height = 0.12
	coin.add_child(col)

	var root := Node3D.new()
	root.name = "Model"
	coin.add_child(root)

	var mesh := MeshInstance3D.new()
	mesh.mesh = CylinderMesh.new()
	mesh.mesh.top_radius = 0.36
	mesh.mesh.bottom_radius = 0.36
	mesh.mesh.height = 0.08
	mesh.rotation.x = PI / 2.0
	mesh.material_override = _coin_mat()
	root.add_child(mesh)

	var ring := MeshInstance3D.new()
	ring.mesh = TorusMesh.new()
	ring.mesh.inner_radius = 0.38
	ring.mesh.outer_radius = 0.44
	ring.rotation.x = PI / 2.0
	ring.material_override = _coin_ring_mat()
	root.add_child(ring)

	# 中心宝石
	var gem := MeshInstance3D.new()
	gem.mesh = SphereMesh.new()
	gem.mesh.radius = 0.16
	gem.mesh.height = 0.32
	gem.material_override = _color_mat(Color(1, 0.95, 0.7), 0.1, 0.0, true)
	root.add_child(gem)

	coin.body_entered.connect(_on_coin_collected.bind(coin))
	return coin

func _create_house(pos: Vector3) -> StaticBody3D:
	var house := StaticBody3D.new()
	house.position = pos
	var w := rng.randf_range(5, 9)
	var h := rng.randf_range(4, 7)
	var d := rng.randf_range(4, 7)

	var col := CollisionShape3D.new()
	col.shape = BoxShape3D.new()
	col.shape.size = Vector3(w, h, d)
	col.position = Vector3(0, h / 2.0, 0)
	house.add_child(col)

	var wall := MeshInstance3D.new()
	wall.mesh = BoxMesh.new()
	wall.mesh.size = Vector3(w, h, d)
	wall.position = Vector3(0, h / 2.0, 0)
	var wall_color := Color.from_hsv(rng.randf(), 0.45, 0.95)
	wall.material_override = _color_mat(wall_color, 0.7)
	house.add_child(wall)

	# 屋顶
	var roof := MeshInstance3D.new()
	roof.mesh = PrismMesh.new()
	roof.mesh.size = Vector3(w + 1.2, 2.5, d + 1.0)
	roof.position = Vector3(0, h + 1.25, 0)
	roof.material_override = _color_mat(Color(0.5, 0.25, 0.15), 0.8)
	house.add_child(roof)

	# 烟囱
	var chim := MeshInstance3D.new()
	chim.mesh = BoxMesh.new()
	chim.mesh.size = Vector3(0.6, 1.2, 0.6)
	chim.position = Vector3(w * 0.25, h + 1.8, 0)
	chim.material_override = _color_mat(Color(0.55, 0.55, 0.55), 0.7)
	house.add_child(chim)

	# 门
	var door := MeshInstance3D.new()
	door.mesh = BoxMesh.new()
	door.mesh.size = Vector3(1.2, 2.2, 0.2)
	door.position = Vector3(0, 1.1, d / 2.0 + 0.05)
	door.material_override = _color_mat(Color(0.35, 0.2, 0.1), 0.6)
	house.add_child(door)

	# 窗户
	for side in [-1, 1]:
		var win := MeshInstance3D.new()
		win.mesh = BoxMesh.new()
		win.mesh.size = Vector3(1.0, 1.0, 0.15)
		win.position = Vector3(side * w / 3.5, h / 2.0 + 0.5, d / 2.0 + 0.05)
		win.material_override = _color_mat(Color(0.6, 0.85, 1.0), 0.1, 0.1, true)
		house.add_child(win)

	# 门前小路
	var path := MeshInstance3D.new()
	path.mesh = BoxMesh.new()
	path.mesh.size = Vector3(1.6, 0.05, 3.0)
	path.position = Vector3(0, 0.02, d / 2.0 + 1.5)
	path.material_override = _color_mat(Color(0.75, 0.72, 0.68), 0.9)
	house.add_child(path)

	return house

func _create_castle(pos: Vector3) -> StaticBody3D:
	var castle := StaticBody3D.new()
	castle.position = pos
	castle.name = "Castle"

	# 主塔
	var tower := MeshInstance3D.new()
	tower.mesh = CylinderMesh.new()
	tower.mesh.top_radius = 2.5
	tower.mesh.bottom_radius = 3.0
	tower.mesh.height = 8
	tower.position = Vector3(0, 4, 0)
	tower.material_override = _color_mat(Color(0.75, 0.7, 0.65), 0.6)
	castle.add_child(tower)

	var col := CollisionShape3D.new()
	col.shape = CylinderShape3D.new()
	col.shape.radius = 3.0
	col.shape.height = 8
	col.position = Vector3(0, 4, 0)
	castle.add_child(col)

	# 塔顶
	var roof := MeshInstance3D.new()
	roof.mesh = CylinderMesh.new()
	roof.mesh.top_radius = 0.2
	roof.mesh.bottom_radius = 3.2
	roof.mesh.height = 3.5
	roof.position = Vector3(0, 9.75, 0)
	roof.material_override = _color_mat(Color(0.6, 0.15, 0.15), 0.5)
	castle.add_child(roof)

	# 四角小塔
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var t := MeshInstance3D.new()
			t.mesh = CylinderMesh.new()
			t.mesh.top_radius = 0.6
			t.mesh.bottom_radius = 0.8
			t.mesh.height = 4.5
			t.position = Vector3(sx * 2.2, 2.25, sz * 2.2)
			t.material_override = _color_mat(Color(0.7, 0.65, 0.6), 0.6)
			castle.add_child(t)
			var tr := MeshInstance3D.new()
			tr.mesh = CylinderMesh.new()
			tr.mesh.top_radius = 0.05
			tr.mesh.bottom_radius = 0.9
			tr.mesh.height = 1.5
			tr.position = Vector3(sx * 2.2, 5.25, sz * 2.2)
			tr.material_override = _color_mat(Color(0.55, 0.12, 0.12), 0.5)
			castle.add_child(tr)

	# 大门
	var gate := MeshInstance3D.new()
	gate.mesh = BoxMesh.new()
	gate.mesh.size = Vector3(2.2, 3.2, 0.4)
	gate.position = Vector3(0, 1.6, 2.8)
	gate.material_override = _color_mat(Color(0.3, 0.15, 0.08), 0.7)
	castle.add_child(gate)

	# 旗帜
	for sx in [-1, 1]:
		var pole := MeshInstance3D.new()
		pole.mesh = CylinderMesh.new()
		pole.mesh.top_radius = 0.06
		pole.mesh.bottom_radius = 0.06
		pole.mesh.height = 2.5
		pole.position = Vector3(sx * 2.5, 11.5, 0)
		pole.material_override = _color_mat(Color.YELLOW, 0.3)
		castle.add_child(pole)
		var banner := MeshInstance3D.new()
		banner.mesh = BoxMesh.new()
		banner.mesh.size = Vector3(1.2, 0.7, 0.05)
		banner.position = Vector3(sx * 3.1, 12.0, 0)
		banner.material_override = _color_mat(Color(1, 0.2, 0.2), 0.4)
		castle.add_child(banner)

	# 终点触发区
	var finish_area := Area3D.new()
	finish_area.position = Vector3(0, 3, 0)
	finish_area.collision_mask = 2
	var flag_col := CollisionShape3D.new()
	flag_col.shape = CylinderShape3D.new()
	flag_col.shape.radius = 3.5
	flag_col.shape.height = 8
	finish_area.add_child(flag_col)
	finish_area.body_entered.connect(_on_finish_reached)
	castle.add_child(finish_area)

	return castle

func _create_tree(pos: Vector3) -> Node3D:
	var tree := Node3D.new()
	tree.position = pos
	var trunk := MeshInstance3D.new()
	trunk.mesh = CylinderMesh.new()
	trunk.mesh.top_radius = 0.22
	trunk.mesh.bottom_radius = 0.38
	trunk.mesh.height = 2.8
	trunk.position = Vector3(0, 1.4, 0)
	trunk.material_override = _color_mat(Color(0.45, 0.3, 0.15), 0.8)
	tree.add_child(trunk)

	var leaf_color := Color(0.15, 0.55, 0.2)
	for i in 3:
		var leaf := MeshInstance3D.new()
		leaf.mesh = SphereMesh.new()
		var r := 1.3 - i * 0.22
		leaf.mesh.radius = r
		leaf.mesh.height = r * 2.0
		leaf.position = Vector3(rng.randf_range(-0.4, 0.4), 3.2 + i * 1.1, rng.randf_range(-0.4, 0.4))
		leaf.material_override = _color_mat(leaf_color.lightened(i * 0.05), 0.85)
		tree.add_child(leaf)
	return tree

func _create_grass(pos: Vector3) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	for i in 3:
		var blade := MeshInstance3D.new()
		blade.mesh = BoxMesh.new()
		blade.mesh.size = Vector3(0.08, rng.randf_range(0.3, 0.7), 0.08)
		blade.position = Vector3(rng.randf_range(-0.2, 0.2), blade.mesh.size.y / 2.0, rng.randf_range(-0.2, 0.2))
		blade.rotation.z = rng.randf_range(-0.3, 0.3)
		blade.material_override = _color_mat(Color(0.25, 0.65, 0.2).darkened(rng.randf() * 0.2), 0.8)
		g.add_child(blade)
	return g

func _create_rock(pos: Vector3, s: float) -> Node3D:
	var rock := Node3D.new()
	rock.position = pos
	var mesh := MeshInstance3D.new()
	mesh.mesh = SphereMesh.new()
	mesh.mesh.radius = s
	mesh.mesh.height = s * 1.6
	mesh.scale = Vector3(rng.randf_range(0.7, 1.3), rng.randf_range(0.6, 1.0), rng.randf_range(0.7, 1.3))
	mesh.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * PI, rng.randf_range(-0.3, 0.3))
	mesh.material_override = _color_mat(Color(0.5, 0.52, 0.55), 0.9)
	rock.add_child(mesh)
	return rock

func _create_flower(pos: Vector3) -> Node3D:
	var f := Node3D.new()
	f.position = pos
	var stem := MeshInstance3D.new()
	stem.mesh = CylinderMesh.new()
	stem.mesh.top_radius = 0.02
	stem.mesh.bottom_radius = 0.03
	stem.mesh.height = 0.4
	stem.position = Vector3(0, 0.2, 0)
	stem.material_override = _color_mat(Color(0.25, 0.65, 0.2), 0.8)
	f.add_child(stem)
	var center := MeshInstance3D.new()
	center.mesh = SphereMesh.new()
	center.mesh.radius = 0.06
	center.mesh.height = 0.12
	center.position = Vector3(0, 0.42, 0)
	center.material_override = _color_mat(Color(1, 0.8, 0.1), 0.3)
	f.add_child(center)
	for side in [-1, 1]:
		var petal := MeshInstance3D.new()
		petal.mesh = BoxMesh.new()
		petal.mesh.size = Vector3(0.18, 0.04, 0.04)
		petal.position = Vector3(side * 0.1, 0.42, 0)
		petal.material_override = _color_mat(Color.from_hsv(rng.randf(), 0.7, 1.0), 0.4)
		f.add_child(petal)
		var petal_v := petal.duplicate()
		petal_v.rotation.z = PI / 2.0
		petal_v.position = Vector3(0, 0.42, side * 0.1)
		f.add_child(petal_v)
	return f

func _create_cloud(pos: Vector3, scale: float) -> Node3D:
	var cloud := Node3D.new()
	cloud.position = pos
	var n_blobs := rng.randi_range(3, 6)
	for i in n_blobs:
		var blob := MeshInstance3D.new()
		blob.mesh = SphereMesh.new()
		var r := rng.randf_range(0.8, 1.6) * scale
		blob.mesh.radius = r
		blob.mesh.height = r * 1.4
		blob.position = Vector3(rng.randf_range(-1.5, 1.5) * scale, rng.randf_range(-0.3, 0.3) * scale, rng.randf_range(-0.8, 0.8) * scale)
		blob.material_override = _cloud_mat()
		cloud.add_child(blob)
	return cloud

func _cloud_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1, 0.85)
	mat.roughness = 1.0
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	return mat

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

func _color_mat(c: Color, roughness: float = 0.5, metallic: float = 0.0, emission: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = roughness
	mat.metallic = metallic
	if emission:
		mat.emission_enabled = true
		mat.emission = c
		mat.emission_energy_multiplier = 0.3
	return mat

func _ground_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.55, 0.25)
	mat.roughness = 0.9
	return mat

func _platform_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.65, 0.45, 0.3)
	mat.roughness = 0.7
	return mat

func _coin_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.1)
	mat.metallic = 1.0
	mat.roughness = 0.25
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.0)
	mat.emission_energy_multiplier = 0.4
	return mat

func _coin_ring_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.75, 0.0)
	mat.metallic = 1.0
	mat.roughness = 0.2
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
