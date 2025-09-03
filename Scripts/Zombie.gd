extends CharacterBody2D
@onready var agent: NavigationAgent2D = $NavigationAgent2D
@onready var player: CharacterBody2D = get_node("/root/World/TileMapLayer/Player")
@onready var zombie_sprite: Sprite2D = $ZombieSprite
@onready var atk_timer: Timer = $AtkCD
@onready var groan_timer: Timer = $groan
@onready var sprint_timer: Timer = $sprint
@onready var attack_timer: Timer = $attack
@onready var groan_sound: AudioStreamPlayer2D = $groanSound
@onready var sprint_sound: AudioStreamPlayer2D = $sprintSound
@onready var attack_sound: AudioStreamPlayer2D = $AttackSound

@export var attack_cd: float = 1.2

const skins: Array = [
	preload("res://Assets/Enemies/ZombieOrange/Zombie.png"),
	preload("res://Assets/Enemies/ZombieBlue/Zombie.png"),
	preload("res://Assets/Enemies/ZombieRed/Zombie.png"),
	preload("res://Assets/Enemies/ZombiePink/Zombie.png"),
	preload("res://Assets/Enemies/ZombieGreen/Zombie.png"),
	preload("res://Assets/Enemies/ZombieMagenta/Zombie.png")
]

const groan_sounds: Array = [
	preload("res://Assets/Enemies/ZombieSounds/idle.mp3"),
	preload("res://Assets/Enemies/ZombieSounds/idle2.mp3"),
	preload("res://Assets/Enemies/ZombieSounds/idle3.mp3"),
	preload("res://Assets/Enemies/ZombieSounds/idle4.mp3"),
	preload("res://Assets/Enemies/ZombieSounds/idle5.mp3"),
	preload("res://Assets/Enemies/ZombieSounds/idle6.mp3"),
	preload("res://Assets/Enemies/ZombieSounds/idle7.mp3"),
]

const sprint_sounds: Array = [
	preload("res://Assets/Enemies/ZombieSounds/sprint.mp3"),
	preload("res://Assets/Enemies/ZombieSounds/sprint2.mp3"),
	preload("res://Assets/Enemies/ZombieSounds/sprint3.mp3"),
	preload("res://Assets/Enemies/ZombieSounds/sprint4.mp3"),
	preload("res://Assets/Enemies/ZombieSounds/sprint5.mp3"),
	preload("res://Assets/Enemies/ZombieSounds/sprint6.mp3"),
	preload("res://Assets/Enemies/ZombieSounds/sprint7.mp3"),
	preload("res://Assets/Enemies/ZombieSounds/sprint8.mp3"),
	preload("res://Assets/Enemies/ZombieSounds/sprint9.mp3"),
]

const attack_sounds: Array = [
	preload("res://Assets/Enemies/ZombieSounds/attack1.mp3"),
	preload("res://Assets/Enemies/ZombieSounds/attack2.mp3"),
	preload("res://Assets/Enemies/ZombieSounds/attack3.mp3"),
	preload("res://Assets/Enemies/ZombieSounds/attack4.mp3"),
]

signal death(zombie_type: String)

var can_atk: bool = true
var hitpoints: float = 4.0
var health_modifier: float = 1.0
var last_zombie: bool = false
var is_ready: bool = false
var is_dead: bool = false
var stop_tracking: bool = false

func sprint() -> void:
	sprint_sound.stream = sprint_sounds[randi_range(0,8)]
	sprint_sound.play()

func last_zombies() -> void:
	last_zombie = true
	if is_ready:
		agent.max_speed *= 1.3

func _ready() -> void:
	randomize()
	agent.target_position = player.global_position
	zombie_sprite.texture = skins[randi_range(0,5)]
	hitpoints = floor(hitpoints * health_modifier)

	if last_zombie:
		agent.max_speed *= 1.3

	is_ready = true

func _physics_process(_delta: float) -> void:
	if is_dead:
		return

	agent.target_position = player.global_position
	var distance = (player.global_position - global_position).length()

	if stop_tracking:
		return

	if distance <= 45:
		if can_atk:
			can_atk = false
			atk_timer.start()
			attack_sound.stream = attack_sounds[randi_range(0,3)]
			attack_sound.play()
			player.take_hit(1)
	else:
		var next_point = agent.get_next_path_position()
		var direction = (next_point - global_transform.origin).normalized()
		zombie_sprite.rotation = direction.angle()
		velocity = direction * agent.max_speed
		move_and_slide()

func _on_atk_cd_timeout() -> void:
	can_atk = true

func take_damage(dam: float) -> void:
	if is_dead: return
	hitpoints -= dam
	if hitpoints <= 0:
		is_dead = true
		emit_signal("death", "basic", global_position)
		call_deferred("queue_free")

func _on_groan_timeout() -> void:
	var rng = randi_range(0,4)
	if rng == 4:
		groan_sound.stream = groan_sounds[randi_range(0,6)]
		groan_sound.play()
	groan_timer.start()
