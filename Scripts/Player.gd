extends CharacterBody2D

@export var speed: float = 200.0
@onready var player_sprite: AnimatedSprite2D = $PlayerSprite
@onready var heart: TextureRect = $Camera2D/CanvasLayer/Control/Hearts/Heart
@onready var heart_2: TextureRect = $Camera2D/CanvasLayer/Control/Hearts/Heart2
@onready var heart_3: TextureRect = $Camera2D/CanvasLayer/Control/Hearts/Heart3
@onready var player: CharacterBody2D = $"."
@onready var marker_2d: Marker2D = $PlayerSprite/Marker2D
@onready var round_container: HBoxContainer = $Camera2D/CanvasLayer/Control/Round/MarginContainer/HBoxContainer/RoundContainer
@onready var score: Label = $Camera2D/CanvasLayer/Control/Points/Score
@onready var bullets_left: Label = $Camera2D/CanvasLayer/Control/Bullets/MarginContainer/VBoxContainer/Bullets
@onready var regenerate_timer: Timer = $RegenerateTimer
@onready var zombies_left: Label = $Camera2D/CanvasLayer/Control/ZombieCounter/MarginContainer/ZombiesLeft
@onready var purchase: RichTextLabel = $Camera2D/CanvasLayer/Control/PurchaseText/MarginContainer/Purchase
@onready var perk_container: HBoxContainer = $Camera2D/CanvasLayer/Control/Round/MarginContainer/HBoxContainer/Perks/PerkContainer
@onready var drink_perk: AudioStreamPlayer2D = $DrinkPerk
@onready var ak_marker: Marker2D = $PlayerSprite/akMarker
var world: Node2D
@onready var game_over: Control = $Camera2D/CanvasLayer/Control/GameOver

@onready var heart_states: Array = [
	preload("res://Assets/Charcter/Hearts/heartFull.png"),
	preload("res://Assets/Charcter/Hearts/HeartHalf.png"),
	preload("res://Assets/Charcter/Hearts/HeartEmpty.png")
]

@onready var perk_icons: Dictionary = {
	"Juggernog" : preload("res://Assets/perks/Juggernog/JuggernogIcon.webp"),
	"QuickRevive" : preload("res://Assets/perks/QuickRevive/QuickReviveIcon.webp"),
	"SpeedCola" : preload("res://Assets/perks/Speedcola/SpeedColaIcon.webp")
}

@onready var rounds: Array = [
	preload("res://Assets/RoundNumbers/0.png"),
	preload("res://Assets/RoundNumbers/1.png"),
	preload("res://Assets/RoundNumbers/2.png"),
	preload("res://Assets/RoundNumbers/3.png"),
	preload("res://Assets/RoundNumbers/4.png"),
	preload("res://Assets/RoundNumbers/5.png"),
	preload("res://Assets/RoundNumbers/6.png"),
	preload("res://Assets/RoundNumbers/7.png"),
	preload("res://Assets/RoundNumbers/8.png"),
	preload("res://Assets/RoundNumbers/9.png"),
]

var has_juggernog: bool = false
var has_quickrevive: bool = false
var has_speedcola: bool = false

var can_move: bool = true
var kills: int = 0
var game_state: bool = true
var can_action: bool = true

var box_prompted: bool = false
var box_weapon: String = ""
var weapon_ready: bool = false
var sprinting: bool = false

var can_switch_weapon: bool = true

var reload_speed: float = 1.0

var points: int = 0

var max_health: int = 3
var _health: int = 3
var health: int = 3:
	get:
		return _health
	set (newval):
		_health = newval
		if _health <= -1:
			_health = 0

		if _health >= 7:
			_health = 6

		match health:
			6:
				health_state(0,0,0)
			5:
				health_state(0,0,1)
			4:
				health_state(0,0,2)
			3:
				health_state(0,1,2)
			2:
				health_state(0,2,2)
			1:
				health_state(1,2,2)
			0:
				health_state(2,2,2)
				if game_state:
					world.game_over()
					game_state = false
			_:
				print("Something wrong happened")
		pass

var weapon_equipped: String = ""

class weapon_class extends Node2D:
	var currently_equipped: bool = false
	var max_bullet_mag: int
	var max_bullets: int
	var full_mags_ammo: int
	var full_bullets_ammo: int
	var bullets_left: int
	var current_mag: int
	var bullet_damage: float
	var shot_cd: float
	var shot_vol: float = 0
	var reload_time: float
	var reload_timer: Timer = Timer.new()
	var weapon_equipped_anim_name: String
	var weapon_equipped_reload_anim_name: String
	var can_shoot: bool = true
	var can_reload: bool = true
	var player_sprite: AnimatedSprite2D
	var marker_2d: Marker2D
	var bullet_scene: PackedScene = preload("res://Scenes/Bullet.tscn")
	var world: Node2D
	var global_scope: Node2D
	var shotgun: bool = false
	var _reload_sound_path: String = ""
	var _shot_sound_path: String = ""
	var reload_sound: AudioStreamPlayer2D
	var reloading: bool = false
	
	func _ready() -> void:
		world = get_tree().get_first_node_in_group("world")
		global_scope = get_tree().get_first_node_in_group("player")
		add_child(reload_timer)
		reload_timer.one_shot = true
		reload_timer.connect("timeout", Callable(self.finish_reload))
	
	func _init(max_bull: int, bullet_mag_size: int, bul_dam: float, bul_cd: float, reload_cd: float, bullet_volume: float, anim_name: String, reload_anim_name: String, player: AnimatedSprite2D, marker: Marker2D, shot_sound_path: String = "", reload_sound_path: String = "", is_shotgun: bool = false) -> void:
		marker_2d = marker
		current_mag = bullet_mag_size
		bullets_left = max_bull
		full_mags_ammo = max_bull
		full_bullets_ammo = bullet_mag_size
		bullet_damage = bul_dam
		shot_cd = bul_cd
		reload_time = reload_cd
		weapon_equipped_anim_name = anim_name
		weapon_equipped_reload_anim_name = reload_anim_name
		max_bullet_mag = bullet_mag_size
		player_sprite = player
		shotgun = is_shotgun
		_reload_sound_path = reload_sound_path
		_shot_sound_path = shot_sound_path
		shot_vol = bullet_volume
		if reload_sound_path:
			reload_sound = AudioStreamPlayer2D.new()
			reload_sound.stream = load(_reload_sound_path)
			add_child(reload_sound)

	func fill_ammo() -> void:
		if currently_equipped:
			self.stop_reload(true)
		else:
			self.stop_reload()
		bullets_left = full_mags_ammo
		current_mag = full_bullets_ammo

	func equip() -> void:
		currently_equipped = true
		player_sprite.animation = weapon_equipped_anim_name

	func unequip() -> void:
		currently_equipped = false
		player_sprite.animation = "nogun"

	func stop_reload(return_anim: bool = false, allow_shoot: bool = true) -> void:
		reload_timer.stop()
		if reload_sound != null:
			reload_sound.stop()
		if return_anim and currently_equipped:
			player_sprite.animation = weapon_equipped_anim_name
		if allow_shoot:
			can_shoot = true
			can_reload = true

	func new_version() -> void:
		fill_ammo()
		unpap()
		
	func unpap() -> void:
		pass
		
	func pap() -> void:
		pass

	func reload() -> void:
		if current_mag >= max_bullet_mag or not currently_equipped:
			return
		if bullets_left > 0 and can_reload:
			reloading = true
			player_sprite.animation = weapon_equipped_reload_anim_name
			can_shoot = false
			can_reload = false
			if reload_sound != null:
				if global_scope.reload_speed != 1.0:
					reload_sound.pitch_scale = 1 * (global_scope.reload_speed + 1)
				reload_sound.play()
			reload_timer.wait_time = (reload_time * global_scope.reload_speed)
			reload_timer.start()
			
	func finish_reload() -> void:
		if current_mag >= max_bullet_mag or not currently_equipped:
			return
		if bullets_left >= max_bullet_mag - current_mag:
			bullets_left -= max_bullet_mag - current_mag
			current_mag = max_bullet_mag
		else:
			current_mag = bullets_left
			bullets_left -= bullets_left
		can_shoot = true
		can_reload = true
		reloading = false
		player_sprite.animation = weapon_equipped_anim_name

	func create_shot(path: String) -> void:
		if path:
			var shot_sound = AudioStreamPlayer2D.new()
			shot_sound.stream = load(path)
			add_child(shot_sound)
			shot_sound.volume_db = shot_vol
			shot_sound.pitch_scale = randf_range(.85,1.25)
			shot_sound.play()
			await shot_sound.finished
			shot_sound.queue_free()
			return

	func shoot() -> void:
		if current_mag > 0 and can_shoot:
			can_shoot = false
			current_mag -= 1
			create_shot(_shot_sound_path)
			if shotgun:
				for e in range(5):
					var bullet = bullet_scene.instantiate()
					bullet.set_direction(player_sprite.rotation+deg_to_rad(randf_range(-10,10)), marker_2d.global_position)
					bullet.damage = bullet_damage
					world.add_child(bullet)
			else:
				var bullet = bullet_scene.instantiate()
				bullet.set_direction(player_sprite.rotation, marker_2d.global_position)
				bullet.damage = bullet_damage
				world.add_child(bullet)
			await get_tree().create_timer(shot_cd).timeout
			if not reloading:
				can_shoot = true
		else:
			pass#Idk play some sound effect or summin

var weapons: Dictionary = {}

var max_weapon_inventory: int = 2
var weapon_inventory_index: int = 0
var weapon_inventory: Array = [
	
]

func drink_quickrevive(price: int) -> void: # Bo2 perk icon, bo5 functionality :(
	if not points >= price:
		return
		
	if has_quickrevive:
		return

	stop_current_action()
	points -= price
	can_action = false
	has_quickrevive = true
	player_sprite.animation = "drink"
	drink_perk.play()
	can_switch_weapon = false
	world.prompt_short_jingle("QuickRevive")
	await get_tree().create_timer(3).timeout
	can_switch_weapon = true
	can_action = true
	regenerate_timer.wait_time /= 2
	if weapon_equipped:
		player_sprite.animation = weapons[weapon_equipped].weapon_equipped_anim_name
	else:
		player_sprite.animation = "nogun"
	var perkIcon = TextureRect.new()
	perkIcon.texture = perk_icons["QuickRevive"]
	perkIcon.name = "QuickRevive"
	perkIcon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	perkIcon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	perkIcon.custom_minimum_size = Vector2(54,54)
	perk_container.call_deferred("add_child", perkIcon)

func drink_speedcola(price: int) -> void:
	if not points >= price:
		return
		
	if has_speedcola:
		return

	stop_current_action()
	points -= price
	can_action = false
	has_speedcola = true
	player_sprite.animation = "drink"
	drink_perk.play()
	can_switch_weapon = false
	world.prompt_short_jingle("SpeedCola")
	await get_tree().create_timer(3).timeout
	can_action = true
	can_switch_weapon = true
	if weapon_equipped:
		player_sprite.animation = weapons[weapon_equipped].weapon_equipped_anim_name
	else:
		player_sprite.animation = "nogun"
	reload_speed = .5
	var perkIcon = TextureRect.new()
	perkIcon.texture = perk_icons["SpeedCola"]
	perkIcon.name = "SpeedCola"
	perkIcon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	perkIcon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	perkIcon.custom_minimum_size = Vector2(54,54)
	perk_container.call_deferred("add_child", perkIcon)

func drink_juggernog(price: int) -> void:
	if not points >= price:
		return

	if has_juggernog:
		return

	points -= price
	stop_current_action()
	can_action = false
	weapons[weapon_equipped].can_shoot = false
	has_juggernog = true
	player_sprite.animation = "drink"
	drink_perk.play()
	can_switch_weapon = false
	world.prompt_short_jingle("Juggernog")
	await get_tree().create_timer(3).timeout
	can_action = true
	can_switch_weapon = true
	weapons[weapon_equipped].can_shoot = true
	if weapon_equipped:
		player_sprite.animation = weapons[weapon_equipped].weapon_equipped_anim_name
	else:
		player_sprite.animation = "nogun"
	max_health = 6
	heart_3.visible = true
	regenerate_timer.start()
	var perkIcon = TextureRect.new()
	perkIcon.texture = perk_icons["Juggernog"]
	perkIcon.name = "Juggernog"
	perkIcon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	perkIcon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	perkIcon.custom_minimum_size = Vector2(54,54)
	perk_container.call_deferred("add_child", perkIcon)

var perks: Dictionary = {
	"Juggernog" : [2500, "Purchase [color=red]Juggernog[/color] cola for [color=yellow]2500 points[/color]", Callable(drink_juggernog)], #Price, text, func
	"QuickRevive" : [500, "Purchase [color=lightblue]Quick revive[/color] for [color=yellow]500 points[/color]", Callable(drink_quickrevive)],
	"SpeedCola" : [4000, "Purchase [color=green]Speed cola[/color] for [color=yellow]4000 points[/color]", Callable(drink_speedcola)]
}

var valid_perks: Array

var prompted: String

func prompt_perk(perk: String) -> void:
	prompted = perk
	purchase.text = perks[perk][1]

func prompt_box() -> void:
	purchase.text = "Buy [color=yellow][/color]Mystery box for [color=yellow]950 points[/color]"
	box_prompted = true
	
func prompt_box_gun(gun: String = "") -> void:
	box_weapon = gun
	purchase.text = "Take %s" % gun
	weapon_ready = true

func remove_prompt() -> void:
	prompted = ""
	purchase.text = ""
	box_prompted = false

func update_round(new_round: int) -> void:
	new_round += 1
	var tween = create_tween()
	
	var children = round_container.get_children()
	if children.size() > 0:
		var fade_out_group = tween.parallel()
		for child in children:
			fade_out_group.tween_property(child, "modulate:a", 0.0, 2.4)
		
		tween.tween_callback(func(): 
			for child in children:
				child.queue_free()
		)
		
		tween.tween_interval(5)
	
	
	var digits = str(new_round)
	for i in range(digits.length()):
		var digit_char = digits[i]
		var index = int(digit_char) - 1
		if index >= 0 and index < rounds.size():
			tween.tween_callback(func():
				var img = TextureRect.new()
				img.texture = rounds[index]
				img.modulate.a = 0.0
				img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				round_container.add_child(img)
				
				var flash_tween = create_tween()
				for flash in range(2):
					flash_tween.tween_property(img, "modulate:a", 1.0, 1.5)
					flash_tween.tween_property(img, "modulate:a", 0.1, 1.5)
				flash_tween.tween_property(img, "modulate:a", 1.0, 1.5)
			)
			
			if i < digits.length() - 1:
				tween.tween_interval(0.1)

func health_state(a: int, b: int, c: int) -> void:
	heart.texture = heart_states[a]
	heart_2.texture = heart_states[b]
	heart_3.texture = heart_states[c]

func _ready() -> void:
	var pistol: weapon_class = weapon_class.new(81, 9, 1.0, .4, 1.76,0, "pistol", "pistol_reload", player_sprite, marker_2d, "res://Assets/GunSounds/1911/shot.mp3", "res://Assets/GunSounds/1911/reload.mp3")
	var olympia: weapon_class = weapon_class.new(28, 2 , 2.1, .3, 2.3,0, "olympia", "olympia_reload", player_sprite, marker_2d, "res://Assets/GunSounds/Olympia/shot.mp3", "res://Assets/GunSounds/Olympia/reload.mp3", true)
	var ak47: weapon_class = weapon_class.new(240, 30, 3, .09, 3.8, -16.0, "ak", "ak_reload", player_sprite, ak_marker, "res://Assets/GunSounds/ak/shot.mp3","res://Assets/GunSounds/ak/reload.mp3",false)
	add_child(pistol)
	add_child(olympia)
	add_child(ak47)
	weapons["pistol"] = pistol
	weapons["olympia"] = olympia
	weapons["ak47"] = ak47
	health = 3 #Force heart display
	for key in perks:
		valid_perks.append(key)
	points = 500
	world = get_tree().get_first_node_in_group("world")

func _physics_process(_delta: float) -> void:
	score.text = str(points)
	if weapon_equipped:
		bullets_left.text = "%s / %s" % [weapons[weapon_equipped].current_mag, weapons[weapon_equipped].bullets_left]
	else:
		bullets_left.text = "0 / 0"
	
	var input_vector := Vector2.ZERO

	if can_move:
		
		if Input.is_action_pressed("sprint"):
			sprinting = true
			speed = 350.0
		else:
			speed = 200.0
			sprinting = false

		if Input.is_action_pressed("walk_up"):
			input_vector.y -= 1
		if Input.is_action_pressed("walk_down"):
			input_vector.y += 1
		if Input.is_action_pressed("walk_left"):
			input_vector.x -= 1
		if Input.is_action_pressed("walk_right"):
			input_vector.x += 1

		input_vector = input_vector.normalized()

		player_sprite.look_at(get_global_mouse_position())

	velocity = input_vector * speed
	move_and_slide()
	
	if Input.is_action_just_pressed("interact"):
		if prompted in valid_perks:
			perks[prompted][2].call(perks[prompted][0])
			
		if box_prompted:
			world.buy_box()
			remove_prompt()
			box_prompted = false
		
		if weapon_ready and box_weapon:
			add_weapon_to_inventory(box_weapon)
			purchase.text = ""
			box_weapon = ""
			if world.in_mystery_box_area:
				prompt_box()
	
	if Input.is_action_pressed("shoot"): #remove just for bullet spam
		if weapon_equipped and can_action and not sprinting:
			weapons[weapon_equipped].shoot()

	if Input.is_action_just_pressed("reload"):
		if weapon_equipped and can_action and not sprinting:
			weapons[weapon_equipped].reload()

	if Input.is_action_just_pressed("weapon_scroll_up") and can_switch_weapon and not sprinting:
		stop_current_action()
		switch_weapon()
	
	if Input.is_action_just_pressed("weapon_scroll_down") and can_switch_weapon and not sprinting:
		stop_current_action()
		switch_weapon(false)
		
	if Input.is_action_just_pressed("cheat"):
		points += 1000
		add_weapon_to_inventory("ak47")

	if Input.is_action_just_pressed("cheat2"):
		remove_weapon()

func take_hit(damange: int) -> void:
	health -= damange
	regenerate_timer.start()

func remove_weapon() -> void:
	if not weapon_equipped:
		return
	var weapon_to_remove: int = weapon_inventory_index
	switch_weapon()
	if len(weapon_inventory) > 1:
		weapon_inventory.remove_at(weapon_to_remove)
	else:
		weapons[weapon_equipped].unequip()
		weapon_inventory.clear()
		weapon_equipped = ""

func switch_weapon(forward: bool = true) -> void:
	if len(weapon_inventory) >= 2:
		weapons[weapon_equipped].currently_equipped = false
		if forward:
			weapon_inventory_index += 1
			if weapon_inventory_index > len(weapon_inventory) - 1:
				weapon_inventory_index = 0
			weapon_equipped = weapon_inventory[weapon_inventory_index]
		else:
			weapon_inventory_index -= 1
			if weapon_inventory_index < 0:
				weapon_inventory_index = len(weapon_inventory) - 1
			weapon_equipped = weapon_inventory[weapon_inventory_index]
		weapons[weapon_equipped].equip()

func add_weapon_to_inventory(weapon: String) -> void:
	for e in weapon_inventory:
		if e == weapon:
			return
	if len(weapon_inventory) > 1:
		weapon_inventory.remove_at(weapon_inventory_index)
	weapon_equipped = weapon
	weapon_inventory.append(weapon)
	weapon_inventory_index = len(weapon_inventory) - 1
	weapons[weapon_equipped].equip()

func _on_regenerate_timer_timeout() -> void:
	if health >= max_health:
		return
	
	health += 1
	regenerate_timer.start()

func increment_kills():
	kills += 1

func max_ammo() -> void:
	for e in weapon_inventory:
		weapons[e].fill_ammo()

func stop_current_action() -> void:
	if weapon_equipped:
		weapons[weapon_equipped].stop_reload()

func update_zombie_counter(zombies: int) -> void:
	zombies_left.text = "Zombies left: %s" % str(zombies)

func death() -> void:
	visible = false
	can_move = false
	game_over.visible = true
	$Camera2D/CanvasLayer/Control/GameOver/HBoxContainer/Label.text = "USERNAME | SCORE | KILLS
YOU | %s | %s" % [points, kills]
