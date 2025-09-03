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
@onready var box: Area2D = $TileMapLayer/MysteryBox/Box
@onready var round_flip: AudioStreamPlayer = $RoundFlip
@onready var round_flip_short: AudioStreamPlayer = $RoundFlipShort
@onready var box_locations: Array = [
	$TileMapLayer/MysteryBox/SpawnLocation1, $TileMapLayer/MysteryBox/SpawnLocation2, $TileMapLayer/MysteryBox/SpawnLocation3, $TileMapLayer/MysteryBox/SpawnLocation4
]
@onready var box_move: AudioStreamPlayer2D = $TileMapLayer/MysteryBox/Box/Move
@onready var game_over_sound: AudioStreamPlayer = $GameOver

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

func _ready() -> void:
	load_box_location()

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
	
func zombie_death(zombie_type: String) -> void:
	player.increment_kills()
	match zombie_type:
		"basic":
			player.points += 100

	zombies_alive -= 1
	player.update_zombie_counter(zombies_alive)

	# Last zombies get faster
	if zombies_alive <= 3 and wave >= 4:
		for e in zombies.get_children():
			e.last_zombies()

	# Wave over
	if zombies_alive <= 0 and zombies_to_spawn <= 0:
		new_round()

func new_round() -> void:
	wave += 1
	player.update_round(wave)
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

	zombie_health_modifier += 1.01

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

	var zombie = zombie_scene.instantiate()
	zombie.health_modifier = zombie_health_modifier
	zombie.name = "Zombie" + str(zombie_index)
	zombie_index += 1

	zombies.call_deferred("add_child", zombie)
	zombie.connect("death", zombie_death)

	if zombies_alive <= 3 and wave >= 4:
		zombie.last_zombies()

	player.update_zombie_counter(zombies_alive)
	spawner.start()

func game_over() -> void:
	game_over_sound.play()
	for e in zombies.get_children():
		e.stop_tracking = true
	player.death()
	spawner.stop()

func prompt_short_jingle(perk: String) -> void:
	match perk:
		"QuickRevive":
			QR_Jingle_short.play()
		"SpeedCola":
			SC_Jingle_short.play()
		"Juggernog":
			J_Jingle_short.play()

func buy_box() -> void:
	can_prompt_box = false
	current_box_iteration += 1
	if current_box_iteration >= box_spins_till_move:
		#Play movement animation or whatnot
		box_move.play()
		await get_tree().create_timer(5.5).timeout
		box.visible = false
		await get_tree().create_timer(1.5).timeout
		box.visible = true 
		load_box_location()
		
	

func _on_gun_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player.add_weapon_to_inventory("pistol")
		gun.call_deferred("queue_free")
		round_flip_short.play()
		new_round()

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
		if randi_range(0, 5) == 5 and not QR_jingle.playing:
			QR_jingle.play()

func _on_j_jingle_radius_entered(body: Node2D) -> void:
	if body.name == "Player":
		if randi_range(0, 5) == 5 and not J_jingle.playing:
			J_jingle.play()

func _on_sc_jingle_entered(body: Node2D) -> void:
	if body.name == "Player":
		if randi_range(0, 5) == 5 and not SC_jingle.playing:
			SC_jingle.play()

func _on_speed_cola_entered(body: Node2D) -> void:
	if body.name == "Player": body.prompt_perk("SpeedCola")

func _on_speed_cola_exited(body: Node2D) -> void:
	if body.name == "Player": body.remove_prompt()

func _on_box_body_entered(body: Node2D) -> void:
	if body.name == "Player" and can_prompt_box: body.prompt_box()

func _on_box_body_exited(body: Node2D) -> void:
	if body.name == "Player": body.remove_prompt()
