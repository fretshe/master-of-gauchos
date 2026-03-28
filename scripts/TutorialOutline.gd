extends Control

class_name TutorialOutline

@export var outline_color: Color = Color(1.0, 0.84, 0.22, 0.92)
@export var glow_color: Color = Color(1.0, 0.92, 0.48, 0.18)
@export var line_width: float = 2.0
@export var corner_length: float = 18.0
@export var padding: float = 6.0

var _time: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return

	var pulse: float = 0.55 + 0.45 * sin(_time * 3.2)
	var glow_alpha: float = glow_color.a * (0.75 + pulse * 0.55)
	var border_alpha: float = outline_color.a * (0.78 + pulse * 0.22)
	var glow := Color(glow_color.r, glow_color.g, glow_color.b, glow_alpha)
	var border := Color(outline_color.r, outline_color.g, outline_color.b, border_alpha)
	var inset := padding
	var frame := Rect2(Vector2(inset, inset), rect.size - Vector2.ONE * inset * 2.0)

	draw_rect(frame.grow(4.0), Color(glow.r, glow.g, glow.b, glow.a * 0.38), false, line_width + 3.0)
	draw_rect(frame, border, false, line_width)

	var dash_shift: float = fposmod(_time * 42.0, maxf(frame.size.x + frame.size.y, 1.0))
	var dash_color := Color(1.0, 0.96, 0.68, border_alpha)
	var top_y: float = frame.position.y
	var left_x: float = frame.position.x
	var right_x: float = frame.end.x
	var bottom_y: float = frame.end.y
	for i: int in range(8):
		var x: float = left_x + fposmod(dash_shift + float(i) * 34.0, maxf(frame.size.x - 16.0, 1.0))
		draw_line(Vector2(x, top_y), Vector2(minf(x + 12.0, right_x), top_y), dash_color, 1.0)
		draw_line(Vector2(right_x - (x - left_x), bottom_y), Vector2(maxf(right_x - (x - left_x) - 12.0, left_x), bottom_y), dash_color, 1.0)

	var c: float = corner_length
	draw_line(frame.position, frame.position + Vector2(c, 0.0), border, line_width + 1.0)
	draw_line(frame.position, frame.position + Vector2(0.0, c), border, line_width + 1.0)
	draw_line(Vector2(frame.end.x, frame.position.y), Vector2(frame.end.x - c, frame.position.y), border, line_width + 1.0)
	draw_line(Vector2(frame.end.x, frame.position.y), Vector2(frame.end.x, frame.position.y + c), border, line_width + 1.0)
	draw_line(Vector2(frame.position.x, frame.end.y), Vector2(frame.position.x + c, frame.end.y), border, line_width + 1.0)
	draw_line(Vector2(frame.position.x, frame.end.y), Vector2(frame.position.x, frame.end.y - c), border, line_width + 1.0)
	draw_line(frame.end, frame.end - Vector2(c, 0.0), border, line_width + 1.0)
	draw_line(frame.end, frame.end - Vector2(0.0, c), border, line_width + 1.0)
