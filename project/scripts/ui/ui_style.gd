class_name UiStyle
extends RefCounted
## Shared look for menus: dark ink panels, bone-white text, teal spirit accents.
## Sizes are large enough for thumbs on phones (min button height 64 px at 720p).

const INK := Color(0.03, 0.04, 0.045, 0.88)
const BONE := Color(0.9, 0.88, 0.8)
const MUTED := Color(0.6, 0.62, 0.6)
const SPIRIT := Color(0.35, 0.95, 0.85)
const WARNING := Color(1.0, 0.7, 0.2)
const DANGER := Color(1.0, 0.25, 0.15)
const BUTTON_HEIGHT := 64


static func panel(bg: Color = INK, border: Color = Color(1, 1, 1, 0.08)) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(24)
	p.add_theme_stylebox_override("panel", sb)
	return p


static func label(text: String, size: int = 24, color: Color = BONE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(text: String, accent: Color = SPIRIT) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, BUTTON_HEIGHT)
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_color_override("font_color", BONE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", MUTED * Color(1, 1, 1, 0.6))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(12)
		sb.set_border_width_all(2)
		match state:
			"normal":
				sb.bg_color = Color(0.06, 0.08, 0.08, 0.95)
				sb.border_color = accent * Color(1, 1, 1, 0.55)
			"hover", "focus":
				sb.bg_color = Color(0.09, 0.13, 0.13, 0.95)
				sb.border_color = accent
			"pressed":
				sb.bg_color = accent * Color(0.35, 0.35, 0.35, 1.0)
				sb.border_color = accent
			"disabled":
				sb.bg_color = Color(0.05, 0.05, 0.05, 0.8)
				sb.border_color = Color(1, 1, 1, 0.08)
		b.add_theme_stylebox_override(state, sb)
	return b


## Full-screen dim layer that blocks input to the game behind it.
static func dim_backdrop(alpha: float = 0.6) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0, 0, 0, alpha)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	return r


static func centered(child: Control) -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(child)
	return c


static func uses_touch() -> bool:
	return DisplayServer.is_touchscreen_available() or Input.emulate_touch_from_mouse
