class_name FontConfig
extends RefCounted

# Global font configuration
const DEFAULT_FONT_PATH := "res://fonts/Triangle Break.otf"
const DEFAULT_FONT_SIZE := 20
const DEFAULT_UI_FONT_SIZE := 20
const DEFAULT_DIALOGUE_FONT_SIZE := 15
const DEFAULT_TITLE_FONT_SIZE := 36
const DEFAULT_POPUP_FONT_SIZE := 20

# Cached font resource
static var _default_font: FontFile = null

# Get the default font resource (cached for performance)
static func get_default_font() -> FontFile:
	if _default_font == null:
		_default_font = load(DEFAULT_FONT_PATH) as FontFile
	return _default_font

# Apply default font styling to a Label
static func apply_default_font(label: Label, font_size: int = DEFAULT_FONT_SIZE) -> void:
	var font := get_default_font()
	if font and label:
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", font_size)
		# Create bold effect with outline
		label.add_theme_constant_override("outline_size", 1)
		label.add_theme_color_override("font_outline_color", label.get_theme_color("font_color"))

# Apply default font styling to a RichTextLabel
static func apply_default_font_rich(rich_label: RichTextLabel, font_size: int = DEFAULT_DIALOGUE_FONT_SIZE) -> void:
	var font := get_default_font()
	if font and rich_label:
		rich_label.add_theme_font_override("normal_font", font)
		rich_label.add_theme_font_override("bold_font", font)
		rich_label.add_theme_font_override("italics_font", font)
		rich_label.add_theme_font_override("bold_italics_font", font)
		rich_label.add_theme_font_override("mono_font", font)
		rich_label.add_theme_font_size_override("normal_font_size", font_size)
		rich_label.add_theme_font_size_override("bold_font_size", font_size)
		rich_label.add_theme_font_size_override("italics_font_size", font_size)
		rich_label.add_theme_font_size_override("bold_italics_font_size", font_size)
		rich_label.add_theme_font_size_override("mono_font_size", font_size)

# Apply font with LabelSettings (alternative approach)
static func apply_font_with_settings(label: Label, font_size: int = DEFAULT_FONT_SIZE) -> void:
	var font := get_default_font()
	if font and label:
		var label_settings := LabelSettings.new()
		label_settings.font = font
		label_settings.font_size = font_size
		label.label_settings = label_settings

# Convenience methods for specific use cases
static func apply_ui_font(label: Label) -> void:
	apply_default_font(label, DEFAULT_UI_FONT_SIZE)

static func apply_dialogue_font(rich_label: RichTextLabel) -> void:
	apply_default_font_rich(rich_label, DEFAULT_DIALOGUE_FONT_SIZE)

static func apply_title_font(label: Label) -> void:
	apply_default_font(label, DEFAULT_TITLE_FONT_SIZE)

static func apply_popup_font(label: Label) -> void:
	apply_default_font(label, DEFAULT_POPUP_FONT_SIZE)

# Apply custom font (for when you need a different font)
static func apply_custom_font(label: Label, font_path: String, font_size: int = DEFAULT_FONT_SIZE) -> void:
	var custom_font := load(font_path) as FontFile
	if custom_font and label:
		label.add_theme_font_override("font", custom_font)
		label.add_theme_font_size_override("font_size", font_size)
