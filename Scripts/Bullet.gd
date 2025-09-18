extends Area2D

@export var speed: float = 800.0
@export var damage: float = 0.0

var velocity: Vector2

var bullet_life: float = 2.0

func remove_bullet() -> void:
	await get_tree().create_timer(2).timeout
	call_deferred("queue_free")

func _ready() -> void:
	remove_bullet()

func _process(delta: float) -> void:
	position += velocity * delta

func set_direction(direction: float, start_position: Vector2) -> void:
	position = start_position
	rotation = direction
	velocity = Vector2.RIGHT.rotated(direction) * speed

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
		return
	
	if body.name == "Player":
		return
	
	# Destroy bullet on any other collision
	queue_free()
