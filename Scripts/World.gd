extends Node2D
@onready var player: CharacterBody2D = $TileMapLayer/Player
@onready var gun: Area2D = $Gun
@onready var spawner: Timer = $Spawner
@onready var zombies: Node2D = $TileMapLayer/Zombies
@onready var QR_jingle: AudioStreamPlayer2D = $Perks/QuickRevive/Jingle
@onready var J_jingle: AudioStreamPlayer2D = $Perks/Juggernog/Jingle
@onready var SC_jingle: AudioStreamPlayer2D = $Perks/SpeedCola/Jingle
@onready var J_Jingle_short: AudioStreamPlayer2D = $Perks/Juggernog/Jingle2
@onready var QR_Jingle_short: AudioStreamPlayer2D = $Perks/QuickRevive/Jingle2
@onready var SC_Jingle_short: AudioStreamPlayer2D = $Perks/SpeedCola/Jingle2
@onready var SU_jingle: AudioStreamPlayer2D = $Perks/StaminUp/Jingle
@onready var SU_jingle_short: AudioStreamPlayer2D = $Perks/StaminUp/Jingle2
@onready var DP_jingle: AudioStreamPlayer2D = $Perks/DoubleTap/Jingle
@onready var DP_jingle_short: AudioStreamPlayer2D = $Perks/DoubleTap/Jingle2
@onready var box_open: Node2D = $TileMapLayer/MysteryBox/Box/BoxOpen

@onready var box: Area2D = $TileMapLayer/MysteryBox/Box
@onready var round_flip: AudioStreamPlayer = $RoundFlip
@onready var round_flip_short: AudioStreamPlayer = $RoundFlipShort
@onready var box_locations: Array = [
	$TileMapLayer/MysteryBox/SpawnLocation1, $TileMapLayer/MysteryBox/SpawnLocation2, $TileMapLayer/MysteryBox/SpawnLocation3, $TileMapLayer/MysteryBox/SpawnLocation4
]
@onready var powerups: Node2D = $Powerups
@onready var box_move: AudioStreamPlayer2D = $TileMapLayer/MysteryBox/Box/Move
@onready var game_over_sound: AudioStreamPlayer = $GameOver
@onready var fogs: Node2D = $Fogs
@onready var instakill_timer: Timer = $Instakill
@onready var double_points_timer: Timer = $DoublePoints
@onready var mystery_spin: AudioStreamPlayer2D = $TileMapLayer/MysteryBox/Box/Spin
@onready var box_finish: Timer = $BoxFinish

var in_location: String = "grasslands"

@onready var zombie_spawns: Dictionary = {
	"grasslands" : [
		$ZombieSpawnLocations/SpawnArea1/Marker2D, $ZombieSpawnLocations/SpawnArea1/Marker2D2, $ZombieSpawnLocations/SpawnArea1/Marker2D3, $ZombieSpawnLocations/SpawnArea1/Marker2D4
	],
	"rocklands" : [
		$ZombieSpawnLocations/SpawnArea2/Marker2D, $ZombieSpawnLocations/SpawnArea2/Marker2D2, $ZombieSpawnLocations/SpawnArea2/Marker2D3, $ZombieSpawnLocations/SpawnArea2/Marker2D4, $ZombieSpawnLocations/SpawnArea2/Marker2D5
	],
	"dirtlands" : [
		$ZombieSpawnLocations/SpawnArea3/Marker2D, $ZombieSpawnLocations/SpawnArea3/Marker2D2, $ZombieSpawnLocations/SpawnArea3/Marker2D3, $ZombieSpawnLocations/SpawnArea3/Marker2D4, $ZombieSpawnLocations/SpawnArea3/Marker2D5, $ZombieSpawnLocations/SpawnArea3/Marker2D6
	],
	"poshlands" : [
		$ZombieSpawnLocations/SpawnArea4/Marker2D, $ZombieSpawnLocations/SpawnArea4/Marker2D2, $ZombieSpawnLocations/SpawnArea4/Marker2D3, $ZombieSpawnLocations/SpawnArea4/Marker2D4, $ZombieSpawnLocations/SpawnArea4/Marker2D5, $ZombieSpawnLocations/SpawnArea4/Marker2D6
	]
}

const MAX_BLAMMO = preload("res://Assets/Sounds/powerups/MaxBlammo.mp3")
const MAX_AMMO_MODEL = preload("res://Assets/Sounds/powerups/maxAmmo.png")
const INSTAKILL = preload("res://Assets/Sounds/powerups/Instakill.mp3")
const INSTAKILL_MODEL = preload("res://Assets/Sounds/powerups/Instakill.png")
const DOUBLE_POINTS = preload("res://Assets/Sounds/powerups/DoubePoints.mp3")
const DOUBLE_POINTS_MODEL = preload("res://Assets/Sounds/powerups/DoublePoints.png")
const KABOOM = preload("res://Assets/Sounds/powerups/kaboom.mp3")
const KABOOM_MODEL = preload("res://Assets/Sounds/powerups/Kaboom.png")
var zombie_scene: PackedScene = preload("res://Scenes/Zombie.tscn")
var zombie_index: int = 0

var spawn_timer: float = 5
var default_zombies_per_round: int = 8
var max_zombies_alive: int = 25

var wave: int = 0
var zombie_health_modifier: float = 1.0
var zombies_alive: int = 0
var zombies_to_spawn: int = 0

var current_box_location: int
var box_spins_till_move: int
var current_box_iteration: int
var can_prompt_box: bool = true
var box_has_weapon: bool = false
var in_mystery_box_area: bool = false
var gun_to_spawn

var instakill_active: bool = false
var double_points_active: bool = false

#Attempt to fix performance issues on web

#Pooling of some sort, I dont exactly understand it
var zombie_pool: Array[Node2D] = []
var active_zombies: Array[Node2D] = []
var pool_size: int = 30
var zombie_pool_initialized: bool = false

func _ready() -> void:
	create_zombie_pool()
	load_box_location()

func create_zombie_pool() -> void:
	print("Creating zombie pool with ", pool_size, " zombies...")
	
	for i in pool_size:
		var zombie = zombie_scene.instantiate()
		zombie.name = "PooledZombie" + str(i)
		
		# Set initial inactive state
		zombie.visible = false
		zombie.set_physics_process(false)
		zombie.set_process(false)
		
		# Disable Area2D monitoring if zombie has one
		var area_node = zombie.get_node_or_null("Area2D")
		if area_node and area_node is Area2D:
			area_node.monitoring = false
		
		# Connect death signal to pool return function
		zombie.connect("death", _on_zombie_returned_to_pool)
		
		# Add to scene but keep inactive
		zombies.add_child(zombie)
		zombie_pool.append(zombie)
	
	zombie_pool_initialized = true
	print("Zombie pool created successfully!")

# Get zombie from pool with full setup
func get_zombie_from_pool(spawn_position: Vector2) -> Node2D:
	var zombie: Node2D
	
	if zombie_pool.is_empty():
		# Fallback: create new zombie if pool is exhausted
		print("Warning: Zombie pool exhausted, creating new zombie")
		zombie = zombie_scene.instantiate()
		zombie.name = "EmergencyZombie" + str(zombie_index)
		zombie_index += 1
		zombie.connect("death", _on_zombie_returned_to_pool)
		zombies.add_child(zombie)
	else:
		# Get zombie from pool
		zombie = zombie_pool.pop_back()
		active_zombies.append(zombie)
	
	# Activate and setup zombie
	activate_zombie(zombie, spawn_position)
	return zombie

# Activate zombie with all necessary setup
func activate_zombie(zombie: Node2D, spawn_position: Vector2) -> void:
	# Reset position and state
	zombie.global_position = spawn_position
	
	# Set health and modifiers
	zombie.health_modifier = zombie_health_modifier
	# Recalculate hitpoints with new modifier
	zombie.hitpoints = 4.0 * zombie_health_modifier
	
	# Apply current powerup effects
	if instakill_active:
		zombie.activate_instakill()
	
	# Handle late round speed boost
	if zombies_alive <= 3 and wave >= 4:
		zombie.last_zombies()
	
	# Activate zombie systems
	zombie.visible = true
	zombie.set_physics_process(true)
	zombie.set_process(true)
	
	# Re-enable Area2D monitoring if zombie has one
	var area_node = zombie.get_node_or_null("Area2D")
	if area_node and area_node is Area2D:
		area_node.monitoring = true
	
	# Reset zombie to initial state (you'll need this method in Zombie.gd)
	zombie.reset_to_pool_state()

# Return zombie to pool
func return_zombie_to_pool(zombie: Node2D) -> void:
	if not zombie:
		return
	
	# Remove from active list
	if zombie in active_zombies:
		active_zombies.erase(zombie)
	
	# Deactivate zombie
	deactivate_zombie(zombie)
	
	# Return to pool if there's space
	if zombie_pool.size() < pool_size:
		zombie_pool.append(zombie)
	else:
		# Pool is full, destroy excess zombie
		zombie.queue_free()

# Deactivate zombie completely
func deactivate_zombie(zombie: Node2D) -> void:
	# Stop all processes
	zombie.set_physics_process(false)
	zombie.set_process(false)
	zombie.visible = false
	
	# Disable Area2D monitoring if zombie has one
	var area_node = zombie.get_node_or_null("Area2D")
	if area_node and area_node is Area2D:
		area_node.monitoring = false
	
	# Reset zombie state
	zombie.reset_to_pool_state()
	
	# Stop any ongoing animations or sounds
	zombie.stop_all_activity()

# Signal handler for zombie death
func _on_zombie_returned_to_pool(zombie_type: String, death_from: String, zm_position: Vector2, zombie_node: Node2D) -> void:
	# Handle scoring and powerup spawning first
	handle_zombie_death_effects(zombie_type, death_from, zm_position)
	
	# Return zombie to pool
	return_zombie_to_pool(zombie_node)
	
	# Update counters
	zombies_alive -= 1
	player.update_zombie_counter(zombies_alive)
	
	# Handle last zombie speed boost
	if zombies_alive <= 3 and wave >= 4:
		for zombie in active_zombies:
			if zombie and zombie.visible:
				zombie.sprint()
	
	# Check for round end
	if zombies_alive <= 0 and zombies_to_spawn <= 0:
		new_round()

# Separate function to handle death effects (points, powerups, etc.)
func handle_zombie_death_effects(zombie_type: String, death_from: String, zm_position: Vector2) -> void:
	player.increment_kills()
	
	var multi = 1
	if double_points_active:
		multi = 2
	
	match zombie_type:
		"basic":
			if death_from == "bullet":
				player.add_points(80 * multi)
			elif death_from == "knife":
				player.add_points(130 * multi)
			else:
				player.add_points(80 * multi)  # Default to bullet points
	
	# Powerup spawn chance
	var powerup_rng = randi_range(1, 40)
	if powerup_rng == 40:
		spawn_powerup(zm_position)

# Utility function to clean up pool on game over
func cleanup_zombie_pool() -> void:
	# Return all active zombies to pool
	for zombie in active_zombies.duplicate():
		return_zombie_to_pool(zombie)
	
	# Stop all zombie activity
	for zombie in zombie_pool:
		if zombie:
			deactivate_zombie(zombie)

func load_box_location() -> void:
	var new_location = randi_range(0,3)
	if new_location == current_box_location:
		if new_location == len(box_locations) - 1:
			new_location -= 1
		elif new_location == 0:
			new_location += 1
			
	current_box_location = new_location
	
	box.position = Vector2(0,0)
	box.rotation = deg_to_rad(0)
	box.reparent(box_locations[current_box_location]) #Idk whhich one fixes it but yh it works or summin
	box.position = Vector2(0,0)
	box.rotation = deg_to_rad(0)
	current_box_iteration = 0
	can_prompt_box = true
	box_spins_till_move = randi_range(4,9)

func collect_powerup(body: Node2D, powerup: String, powerup_node: Sprite2D) -> void:
	if body.name != "Player":
		return
	match powerup:
		"maxblammo":
			player.max_ammo()
			var max_ammo: AudioStreamPlayer = AudioStreamPlayer.new()
			max_ammo.stream = MAX_BLAMMO
			add_child(max_ammo)
			max_ammo.play()
			powerup_node.call_deferred("queue_free")
			await get_tree().create_timer(2.95).timeout
			max_ammo.call_deferred("queue_free")
		"instakill":
			for zombie in active_zombies:
				if zombie and zombie.visible:
					zombie.activate_instakill()
			instakill_active = true
			var instakill: AudioStreamPlayer = AudioStreamPlayer.new()
			instakill.stream = INSTAKILL
			add_child(instakill)
			instakill.play()
			player.display_powerup("Instakill")
			powerup_node.call_deferred("queue_free")
			instakill_timer.start()
			await get_tree().create_timer(2.74).timeout
			instakill.call_deferred("queue_free")
		"doublepoints":
			double_points_active = true
			var double_points: AudioStreamPlayer = AudioStreamPlayer.new()
			double_points.stream = DOUBLE_POINTS
			add_child(double_points)
			player.display_powerup("DoublePoints")
			double_points.play()
			powerup_node.call_deferred("queue_free")
			double_points_timer.start()
			await get_tree().create_timer(2.17).timeout
			double_points.call_deferred("queue_free")
		"kaboom":
			var kaboom: AudioStreamPlayer = AudioStreamPlayer.new()
			kaboom.stream = KABOOM
			add_child(kaboom)
			kaboom.play()
			powerup_node.call_deferred("queue_free")
			await get_tree().create_timer(2.71).timeout
			kaboom.call_deferred("queue_free")
			for zombie in active_zombies:
				if zombie and zombie.visible:
					zombie.take_damage(9999999999999.0)
			await get_tree().create_timer(3).timeout
			player.add_points(400)

func spawn_powerup(positioning: Vector2, _specific: String = "") -> void:
	var powerup_rng = randi_range(0,3)
	match powerup_rng:
		0:
			var max_blammo_sprite: Sprite2D = Sprite2D.new()
			max_blammo_sprite.texture = MAX_AMMO_MODEL
			max_blammo_sprite.scale = Vector2(0.7,0.7)
			max_blammo_sprite.position = positioning
			var max_blammo_area: Area2D = Area2D.new()
			max_blammo_area.connect("body_entered", Callable(collect_powerup).bind("maxblammo", max_blammo_sprite))
			var max_blammo_area_collision: CollisionShape2D = CollisionShape2D.new()
			var rectangle: RectangleShape2D = RectangleShape2D.new()
			rectangle.size = Vector2(65.595,65.102)
			max_blammo_area_collision.shape = rectangle
			max_blammo_area.call_deferred("add_child", max_blammo_area_collision)
			max_blammo_sprite.call_deferred("add_child", max_blammo_area)
			powerups.call_deferred("add_child", max_blammo_sprite)
		1:
			var instakill_sprite: Sprite2D = Sprite2D.new()
			instakill_sprite.texture = INSTAKILL_MODEL
			instakill_sprite.scale = Vector2(0.06,0.06)
			instakill_sprite.position = positioning
			var instakill_area: Area2D = Area2D.new()
			instakill_area.connect("body_entered", Callable(collect_powerup).bind("instakill", instakill_sprite))
			var instakill_area_collision: CollisionShape2D = CollisionShape2D.new()
			var rectangle: RectangleShape2D = RectangleShape2D.new()
			rectangle.size = Vector2(65.595,65.102)
			instakill_area_collision.shape = rectangle
			instakill_area.call_deferred("add_child", instakill_area_collision)
			instakill_sprite.call_deferred("add_child", instakill_area)
			powerups.call_deferred("add_child", instakill_sprite)
		2:
			var double_points_sprite: Sprite2D = Sprite2D.new()
			double_points_sprite.texture = DOUBLE_POINTS_MODEL
			double_points_sprite.scale = Vector2(0.06,0.06)
			double_points_sprite.position = positioning
			var double_points_area: Area2D = Area2D.new()
			double_points_area.connect("body_entered", Callable(collect_powerup).bind("doublepoints", double_points_sprite))
			var double_points_area_collision: CollisionShape2D = CollisionShape2D.new()
			var rectangle: RectangleShape2D = RectangleShape2D.new()
			rectangle.size = Vector2(65.595,65.102)
			double_points_area_collision.shape = rectangle
			double_points_area.call_deferred("add_child", double_points_area_collision)
			double_points_sprite.call_deferred("add_child", double_points_area)
			powerups.call_deferred("add_child", double_points_sprite)
		3:
			var kaboom_sprite: Sprite2D = Sprite2D.new()
			kaboom_sprite.texture = KABOOM_MODEL
			kaboom_sprite.scale = Vector2(0.078,0.078)
			kaboom_sprite.position = positioning
			var kaboom_area: Area2D = Area2D.new()
			kaboom_area.connect("body_entered", Callable(collect_powerup).bind("kaboom", kaboom_sprite))
			var kaboom_area_collision: CollisionShape2D = CollisionShape2D.new()
			var rectangle: RectangleShape2D = RectangleShape2D.new()
			rectangle.size = Vector2(65.595,65.102)
			kaboom_area_collision.shape = rectangle
			kaboom_area.call_deferred("add_child", kaboom_area_collision)
			kaboom_sprite.call_deferred("add_child", kaboom_area)
			powerups.call_deferred("add_child", kaboom_sprite)

func zombie_death(zombie_type: String, death_from: String, zm_position: Vector2) -> void:
	player.increment_kills()
	var multi = 1
	if double_points_active:
		multi = 2
	match zombie_type:
		"basic":
			if death_from == "bullet":
				player.add_points(80 * multi)
			elif death_from == "knife":
				player.add_points(130 * multi)

	var powerup_rng = randi_range(1,40)
	if powerup_rng == 40:
		spawn_powerup(zm_position)

	zombies_alive -= 1
	player.update_zombie_counter(zombies_alive)

	# Last zombies get faster
	if zombies_alive <= 3 and wave >= 4:
		if active_zombies.size() > 0:
			var first_zombie = active_zombies[0]
			if first_zombie and first_zombie.visible:
				first_zombie.sprint()
		for zombie in active_zombies:
			if zombie and zombie.visible:
				zombie.last_zombies()

	# Wave over
	if zombies_alive <= 0 and zombies_to_spawn <= 0:
		new_round()

func new_round() -> void:
	wave += 1
	player.update_round(wave)
	
	# Show difficulty progression messages to player
	if wave == 11:
		print("Round 11: Zombies are getting much stronger!")
	elif wave == 6:
		print("Round 6: Zombies are tougher now...")
	
	if not round_flip_short.playing:
		round_flip.play()
	await get_tree().create_timer(spawn_timer).timeout
	spawn_timer = max(1.0, spawn_timer - 0.2) + 3 #for the round flip
	start_round()

func start_round() -> void:
	if wave == 1:
		zombies_to_spawn = default_zombies_per_round
		zombie_health_modifier = 1.0
		spawner.start()
		return

	if spawner.wait_time > 4:
		spawner.wait_time -= 0.2

	default_zombies_per_round = min(60, floor(default_zombies_per_round * 1.2))
	zombies_to_spawn = default_zombies_per_round

	# New scaling system - more balanced progression
	# Rounds 1-5: Gradual increase (1.0 -> 2.5)
	# Rounds 6-10: Moderate increase (2.5 -> 5.0) 
	# Round 11+: Significant increase (weapons start feeling weak)
	if wave <= 5:
		zombie_health_modifier = 1.0 + (wave - 1) * 0.3  # Linear growth early
	elif wave <= 10:
		zombie_health_modifier = 2.5 + (wave - 5) * 0.5  # Moderate growth mid-game
	else:
		# Exponential growth for late game - weapons become noticeably weak
		zombie_health_modifier = 5.0 + pow(wave - 10, 1.3) * 0.8

	# Debug output for health scaling (remove this later if not needed)
	var zombie_hp = floor(4.0 * zombie_health_modifier)
	print("Round ", wave, ": Zombie HP = ", zombie_hp, " (modifier: ", zombie_health_modifier, ")")

	zombies_alive = 0

	spawner.start()

func _on_spawner_timeout() -> void:
	#player.points = 70000
	if zombies_to_spawn <= 0:
		return

	if zombies_alive >= max_zombies_alive:
		spawner.start()
		return
	
	zombies_to_spawn -= 1
	zombies_alive += 1

	# Get spawn location
	var spawns: int = len(zombie_spawns[in_location]) - 1
	var spawn_index: int = randi_range(0, spawns)
	var spawn_position = zombie_spawns[in_location][spawn_index].global_position
	
	# Get zombie from pool instead of instantiating
	var zombie = get_zombie_from_pool(spawn_position)
	
	player.update_zombie_counter(zombies_alive)
	spawner.start()

func game_over() -> void:
	game_over_sound.play()
	
	# Use pooled zombies instead of getting all children
	for zombie in active_zombies:
		if zombie:
			zombie.stop_tracking = true
	
	cleanup_zombie_pool()
	player.death()
	spawner.stop()

func remove_quick_revive() -> void:
	var quick_revive = $Perks/QuickRevive
	quick_revive.visible = false
	quick_revive.disconnect("body_entered", Callable(_on_quick_revive_entered))
	box_move.play()

func prompt_short_jingle(perk: String) -> void:
	match perk:
		"QuickRevive":
			QR_Jingle_short.play()
		"SpeedCola":
			SC_Jingle_short.play()
		"Juggernog":
			J_Jingle_short.play()
		"StaminUp":
			SU_jingle_short.play()
		"DoubleTap":
			DP_jingle_short.play()

func buy_box() -> void:
	if player.points < 950:
		#Fail noise maybe?
		return
	
	box_open.visible = true
	player.remove_points(950)
	can_prompt_box = false
	current_box_iteration += 1
	mystery_spin.play()
	await get_tree().create_timer(6.0).timeout
	if current_box_iteration >= box_spins_till_move:
		#Play movement animation or whatnot
		player.add_points(950)
		box_move.play()
		await get_tree().create_timer(5.5).timeout
		box.visible = false
		box.reparent($".")
		await get_tree().create_timer(1.5).timeout
		box.visible = true 
		load_box_location()
		box_open.visible = false
		return
	
	box_has_weapon = true
	var valid_guns: Array
	for e in player.weapons:
		valid_guns.append(e)
	for e in player.weapon_inventory:
		valid_guns.erase(e)
	var random_gun = randi_range(0, len(valid_guns) - 1)
	gun_to_spawn = valid_guns[random_gun]
	if in_mystery_box_area:
		player.prompt_box_gun(gun_to_spawn)
	box_finish.start()

func taken_weapon() -> void:
	box_finish.stop()
	gun_to_spawn = ""
	box_has_weapon = false
	can_prompt_box = true
	player.remove_prompt_gun()
	box_open.visible = false

func _on_box_finish_timeout() -> void:
	player.remove_prompt_gun()
	box_has_weapon = false
	gun_to_spawn = ""
	can_prompt_box = true
	box_open.visible = false
	if in_mystery_box_area:
		player.prompt_box()

func _on_gun_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player.add_weapon_to_inventory("pistol")
		gun.call_deferred("queue_free")
		round_flip_short.play()
		new_round()
		#spawn_powerup(Vector2(0,0), "max")

func _on_juggernog_entered(body: Node2D) -> void:
	if body.name == "Player": body.prompt_perk("Juggernog")

func _on_juggernog_exited(body: Node2D) -> void:
	if body.name == "Player": body.remove_prompt()

func _on_quick_revive_entered(body: Node2D) -> void:
	if body.name == "Player": body.prompt_perk("QuickRevive")

func _on_quick_revive_exited(body: Node2D) -> void:
	if body.name == "Player": body.remove_prompt()

func _on_qr_jingle_radius_entered(body: Node2D) -> void:
	if body.name == "Player":
		if randi_range(0, 6) == 5 and not QR_jingle.playing:
			QR_jingle.play()

func _on_j_jingle_radius_entered(body: Node2D) -> void:
	if body.name == "Player":
		if randi_range(0, 6) == 5 and not J_jingle.playing:
			J_jingle.play()

func _on_sc_jingle_entered(body: Node2D) -> void:
	if body.name == "Player":
		if randi_range(0, 6) == 5 and not SC_jingle.playing:
			SC_jingle.play()

func _on_su_jingle_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		if randi_range(0, 6) == 5 and not SU_jingle.playing:
			SU_jingle.play()

func _on_dp_jingle_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		if randi_range(0, 6) == 5 and not DP_jingle.playing:
			DP_jingle.play()

func _on_speed_cola_entered(body: Node2D) -> void:
	if body.name == "Player": body.prompt_perk("SpeedCola")

func _on_speed_cola_exited(body: Node2D) -> void:
	if body.name == "Player": body.remove_prompt()

func _on_stamin_up_body_entered(body: Node2D) -> void:
	if body.name == "Player": body.prompt_perk("StaminUp")

func _on_stamin_up_body_exited(body: Node2D) -> void:
	if body.name == "Player": body.remove_prompt()

func _on_double_tap_body_entered(body: Node2D) -> void:
	if body.name == "Player": body.prompt_perk("DoubleTap")

func _on_double_tap_body_exited(body: Node2D) -> void:
	if body.name == "Player": body.remove_prompt()

func _on_box_body_entered(body: Node2D) -> void:
	if body.name == "Player": 
		in_mystery_box_area = true
		if box_has_weapon and gun_to_spawn:
			player.prompt_box_gun(gun_to_spawn)
		elif can_prompt_box:
			body.prompt_box()

func _on_box_body_exited(body: Node2D) -> void:
	if body.name == "Player": 
		in_mystery_box_area = false
		body.remove_prompt()

func _zombie_spawn_area1(body: Node2D) -> void:
	if body.name == "Player": in_location = "grasslands"

func _zombie_spawn_area2(body: Node2D) -> void:
	if body.name == "Player": in_location = "dirtlands"

func _zombie_spawn_area3(body: Node2D) -> void:
	if body.name == "Player": in_location = "rocklands"

func _zombie_spawn_area4(body: Node2D) -> void:
	if body.name == "Player": in_location = "poshlands"

func _on_instakill_timeout() -> void:
	instakill_active = false
	for zombie in active_zombies:
		if zombie and zombie.visible:
			zombie.deactivate_instakill()

func _on_double_points_timeout() -> void:
	double_points_active = false

# Add these advanced pool management functions to World.gd

# Dynamically resize pool based on performance
func adjust_pool_size(new_size: int) -> void:
	if new_size < pool_size:
		# Shrink pool
		var excess = pool_size - new_size
		for i in excess:
			if not zombie_pool.is_empty():
				var zombie = zombie_pool.pop_back()
				zombie.queue_free()
	elif new_size > pool_size:
		# Grow pool
		var additional = new_size - pool_size
		for i in additional:
			var zombie = zombie_scene.instantiate()
			zombie.name = "PooledZombie" + str(pool_size + i)
			zombie.visible = false
			zombie.set_physics_process(false)
			zombie.connect("death", _on_zombie_returned_to_pool)
			zombies.add_child(zombie)
			zombie_pool.append(zombie)
	
	pool_size = new_size

# Preload zombies with specific configurations
# Preload zombies with specific configurations
func preload_zombie_configurations() -> void:
	# Zombies are configured when activated, so this function
	# can be used for other pre-loading tasks if needed
	pass

# Performance monitoring
func monitor_pool_performance() -> void:
	var status = get_pool_status()
	
	# Adjust pool size based on usage
	if status.active_zombies > status.pool_size * 0.8:
		# Pool is nearly exhausted, increase size
		adjust_pool_size(pool_size + 5)
	elif status.active_zombies < status.pool_size * 0.3 and pool_size > 15:
		# Pool is underutilized, decrease size
		adjust_pool_size(pool_size - 5)

# Debug function to monitor pool status
func get_pool_status() -> Dictionary:
	return {
		"pool_size": zombie_pool.size(),
		"active_zombies": active_zombies.size(),
		"total_zombie_children": zombies.get_child_count(),
		"zombies_alive": zombies_alive
	}
