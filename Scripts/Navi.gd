extends NavigationRegion2D

func _ready() -> void:
	for e in get_children():
		e.color = Color.TRANSPARENT
