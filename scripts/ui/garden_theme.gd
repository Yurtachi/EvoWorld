extends RefCounted

static func panel(color: Color, radius: int = 14, padding: int = 18) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	return style

static func create() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 15
	theme.set_color("font_color", "Label", Color("eeeede"))
	theme.set_color("font_color", "Button", Color("ebeede"))
	theme.set_color("font_hover_color", "Button", Color("ffffff"))
	theme.set_color("font_pressed_color", "Button", Color("213a30"))
	theme.set_color("font_focus_color", "Button", Color("eeeede"))
	theme.set_color("font_color", "LineEdit", Color("f4f0dc"))
	theme.set_color("font_placeholder_color", "LineEdit", Color("a4b7a7"))
	theme.set_stylebox("normal", "Button", panel(Color("354e42"), 9, 11))
	theme.set_stylebox("hover", "Button", panel(Color("496454"), 9, 11))
	theme.set_stylebox("pressed", "Button", panel(Color("d5deaa"), 9, 11))
	var focus := panel(Color.TRANSPARENT, 9, 11)
	focus.border_color = Color("e4d9a7")
	focus.set_border_width_all(2)
	theme.set_stylebox("focus", "Button", focus)
	theme.set_stylebox("panel", "PanelContainer", panel(Color("213a30")))
	theme.set_stylebox("panel", "AcceptDialog", panel(Color("213a30"), 14, 22))
	theme.set_stylebox("normal", "LineEdit", panel(Color("152e25"), 8, 12))
	theme.set_stylebox("focus", "LineEdit", focus)
	theme.set_stylebox("background", "ProgressBar", panel(Color("102b22"), 5, 0))
	theme.set_stylebox("fill", "ProgressBar", panel(Color("b9cd88"), 5, 0))
	theme.set_color("font_color", "CheckButton", Color("eeeede"))
	theme.set_constant("separation", "VBoxContainer", 10)
	theme.set_constant("separation", "HBoxContainer", 8)
	return theme
