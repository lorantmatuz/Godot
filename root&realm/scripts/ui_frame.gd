class_name UiFrame
extends RefCounted

## The chunky wooden panel the HUD controls draw behind their content: dark
## outline, a lit top-left bevel, wood, and a dark inner line so content never
## touches the wood. Shared so the minimap and the clock strip match.

const BORDER := 8

# Kit wood, straight from the fence and signpost sprites.
const WOOD := Color("6e4e36")
const LIGHT := Color("926445")
const SHADE := Color("664031")
const DARK := Color("030101")


static func draw(canvas: CanvasItem, full: Rect2) -> void:
	var inner := Rect2(full.position + Vector2.ONE, full.size - Vector2.ONE * 2.0)

	# A soft drop shadow sells the frame as a panel lying on the HUD.
	canvas.draw_rect(
		Rect2(full.position + Vector2(2.0, 2.0), full.size), Color(0.0, 0.0, 0.0, 0.3)
	)
	canvas.draw_rect(full, DARK)
	canvas.draw_rect(full.grow(-1.0), WOOD)
	# Raised bevel: the top and left edges catch the light, the other two do not.
	canvas.draw_rect(Rect2(inner.position, Vector2(inner.size.x, 1.0)), LIGHT)
	canvas.draw_rect(Rect2(inner.position, Vector2(1.0, inner.size.y)), LIGHT)
	canvas.draw_rect(Rect2(inner.position.x, inner.end.y - 1.0, inner.size.x, 1.0), SHADE)
	canvas.draw_rect(Rect2(inner.end.x - 1.0, inner.position.y, 1.0, inner.size.y), SHADE)
	# The inner line is drawn over the wood, so content starts one pixel later.
	_outline(canvas, full.grow(1.0 - BORDER), DARK)


static func _outline(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 1.0)), color)
	canvas.draw_rect(Rect2(rect.position.x, rect.end.y - 1.0, rect.size.x, 1.0), color)
	canvas.draw_rect(Rect2(rect.position.x, rect.position.y, 1.0, rect.size.y), color)
	canvas.draw_rect(Rect2(rect.end.x - 1.0, rect.position.y, 1.0, rect.size.y), color)
