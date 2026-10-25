extends StaticBody2D

signal died

func take_hit() -> void:
	died.emit()
	queue_free()
