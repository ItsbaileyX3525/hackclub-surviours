extends Area2D

@export var speed: float = 800.0
@export var damage: float = 0.0

var velocity: Vector2
var bullet_life: float = 2.0
var life_timer: float = 0.0
var world_ref: Node2D

func remove_bullet() -> void:
	if world_ref and world_ref.has_method("return_bullet_to_pool"):
		world_ref.call_deferred("return_bullet_to_pool", self)
	else:
		call_deferred("queue_free")

func _ready() -> void:
	world_ref = get_tree().get_first_node_in_group("world")

func _process(delta: float) -> void:
	position += velocity * delta
	life_timer += delta
	if life_timer >= bullet_life:
		reset_bullet()
		call_deferred("remove_bullet")

func set_direction(direction: float, start_position: Vector2) -> void:
	position = start_position
	rotation = direction
	velocity = Vector2.RIGHT.rotated(direction) * speed
	life_timer = 0.0

func reset_bullet() -> void:
	velocity = Vector2.ZERO
	life_timer = 0.0
	damage = 0.0

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
		reset_bullet()
		call_deferred("remove_bullet")
		return
	
	if body.name == "Player":
		return
	
	# Destroy bullet on any other collision
	reset_bullet()
	call_deferred("remove_bullet")
