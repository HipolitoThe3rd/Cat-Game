### MailLetter will have one of the designs in "res://backgrounds/Mail/"
### The background in the prefab is the default design, this and the one with the color scheme of Crispy (and their inverses) will be the two defaults available, while you will be able to buy other designs with the money you earn through weekly paychecks
###
### Every design shares one layout: a big box for the letter (PanelBody) and a
### small box for who sent it (PanelSender). The text color in each box, and
### the scroll handle's color, are read from the design image itself, so a new
### design only needs its .jpg dropped into res://backgrounds/Mail/.
class_name MailLetter
extends Control

@onready var background: TextureRect = $TextureRect
@onready var body_panel = $PanelBody
@onready var body_label: RichTextLabel = $PanelBody/Body
@onready var body_scrollbar: VScrollBar = $PanelBody/VSBBody # if the body of the mail is long enough, this scroll bar will go up down; the color of the circle-shaped handle should match the outer color of the mail desig, such as #f0f0f0 for the default design background; the color of the handle will not be blended, but replaced
@onready var sender_panel = $PanelSender # where the sender of the mail's name will be displayed, whether by Friend Code or Discord username
@onready var sender_label: RichTextLabel = $PanelSender/Sender

@export var path_to_mail_designs = "res://backgrounds/Mail/"

const HANDLE_SIZE := 24.0

# pattern id -> {"outer", "body", "sender"} colors read from its image.
static var _palettes := {}

var _pattern := ""


func _ready() -> void:
	# The label scrolls itself; the prefab's own scroll bar mirrors it so it can
	# wear the design's colors. Hide the label's built-in one.
	var inner := body_label.get_v_scroll_bar()
	inner.modulate = Color.TRANSPARENT
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_label.add_theme_constant_override("scrollbar_width", 0)
	inner.changed.connect(_sync_scrollbar)
	inner.value_changed.connect(func(_v): _sync_scrollbar())
	body_scrollbar.value_changed.connect(func(v): inner.value = v)
	body_label.resized.connect(_sync_scrollbar.call_deferred)
	set_pattern("default")


## Shows the letter on a design (a Global.MAIL_PATTERNS id). Unknown or
## missing designs fall back to the default.
func set_pattern(id: String) -> void:
	var texture := Global.mail_pattern_texture(id)
	if texture == null:
		id = "default"
		texture = Global.mail_pattern_texture(id)
	_pattern = id
	background.texture = texture
	var colors := palette(id)
	body_label.add_theme_color_override("default_color", colors.body)
	sender_label.add_theme_color_override("default_color", colors.sender)
	_style_scrollbar(colors.outer)


## BBCode for the letter box and the sender box.
func set_text(body_bbcode: String, sender_bbcode: String) -> void:
	body_label.text = body_bbcode
	sender_label.text = "[center]%s[/center]" % sender_bbcode
	body_label.get_v_scroll_bar().value = 0
	_sync_scrollbar.call_deferred()


## Shows a letter Dictionary from Global.mail. Players' text is escaped so their
## BBCode is not rendered. extra_bbcode goes under the body (e.g. Kitcoins).
func show_letter(letter: Dictionary, is_new := false, extra_bbcode := "") -> void:
	set_pattern(Global.letter_pattern(letter))
	var colors := palette(_pattern)
	var body_color: Color = colors.body
	var faint: String = body_color.lerp(_opposite(body_color), 0.45).to_html(false)

	var sent := Time.get_datetime_string_from_unix_time(
		int(float(letter.get("sent_unix", 0.0)) + _timezone_bias()), true)
	var body := "[b]%s[/b]%s\n[font_size=16][color=#%s]%s[/color][/font_size]\n\n%s" % [
		escape(letter.get("subject", "")),
		"  [color=#d4a017](new)[/color]" if is_new else "",
		faint, sent.left(16),
		escape(letter.get("body", "")),
	]
	if not extra_bbcode.is_empty():
		body += "\n\n" + extra_bbcode

	# Players are shown with their friend code, so it is clear who to write back to.
	var from := escape(letter.get("from", ""))
	var from_code := str(letter.get("from_code", ""))
	if not from_code.is_empty() and str(letter.get("from", "")) != from_code:
		from += " [color=#%s](%s)[/color]" % [faint, escape(from_code)]
	# Backers get a badge in their tier's color.
	var tier := int(letter.get("from_tier", 0))
	if tier > 0:
		from += "  [color=#%s][%s][/color]" % [Account.tier_color(tier).to_html(false), Account.tier_name(tier)]
	set_text(body, from)


static func escape(value) -> String:
	return str(value).replace("[", "[lb]")


## Colors that read well on a design, sampled from its image once and cached:
## the outer frame's color (for the scroll handle) and black or white text for
## each of the two boxes, whichever contrasts more.
static func palette(id: String) -> Dictionary:
	if _palettes.has(id):
		return _palettes[id]
	var colors := {"outer": Color("#f0f0f0"), "body": Color.BLACK, "sender": Color.BLACK}
	var texture := Global.mail_pattern_texture(id)
	if texture != null:
		var image := texture.get_image()
		if image.is_compressed():
			image.decompress()
		var w := image.get_width()
		var h := image.get_height()
		# Fractions of the image: inside each box, and down the left margin.
		colors.body = _text_on(_most_common(image, Rect2(0.1 * w, 0.2 * h, 0.8 * w, 0.45 * h)))
		colors.sender = _text_on(_most_common(image, Rect2(0.45 * w, 0.8 * h, 0.45 * w, 0.06 * h)))
		colors.outer = _most_common(image, Rect2(0.004 * w, 0.1 * h, 0.022 * w, 0.6 * h))
	_palettes[id] = colors
	return colors


# The color most pixels in an area share (ignoring the odd star or sticker).
static func _most_common(image: Image, area: Rect2) -> Color:
	var counts := {}
	var best := Color.WHITE
	var best_count := 0
	var step := maxi(1, int(minf(area.size.x, area.size.y) / 12.0))
	for y in range(int(area.position.y), int(area.end.y), step):
		for x in range(int(area.position.x), int(area.end.x), step):
			var c := image.get_pixel(clampi(x, 0, image.get_width() - 1), clampi(y, 0, image.get_height() - 1))
			# Bucket colors so JPEG noise does not split one color into many.
			var key := Vector3i(int(c.r * 15.0 + 0.5), int(c.g * 15.0 + 0.5), int(c.b * 15.0 + 0.5))
			counts[key] = counts.get(key, 0) + 1
			if counts[key] > best_count:
				best_count = counts[key]
				best = Color(key.x / 15.0, key.y / 15.0, key.z / 15.0)
	return best


static func _text_on(background_color: Color) -> Color:
	return Color(0.12, 0.12, 0.12) if background_color.get_luminance() > 0.5 else Color(0.97, 0.97, 0.97)


static func _opposite(c: Color) -> Color:
	return Color.WHITE if c.get_luminance() < 0.5 else Color.BLACK


static func _timezone_bias() -> float:
	return float(Time.get_time_zone_from_system().get("bias", 0)) * 60.0


## A round handle in the design's frame color, on a faint track. The handle's
## length is fixed (page 0), which is what keeps it a circle.
func _style_scrollbar(color: Color) -> void:
	var handle := StyleBoxFlat.new()
	handle.bg_color = color
	handle.set_corner_radius_all(int(HANDLE_SIZE))
	handle.content_margin_top = HANDLE_SIZE / 2.0
	handle.content_margin_bottom = HANDLE_SIZE / 2.0
	handle.border_color = color.darkened(0.35)
	handle.set_border_width_all(2)
	var hover := handle.duplicate()
	hover.bg_color = color.lightened(0.15)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(color.r, color.g, color.b, 0.25)
	track.set_corner_radius_all(int(HANDLE_SIZE))
	body_scrollbar.add_theme_stylebox_override("grabber", handle)
	body_scrollbar.add_theme_stylebox_override("grabber_highlight", hover)
	body_scrollbar.add_theme_stylebox_override("grabber_pressed", hover)
	body_scrollbar.add_theme_stylebox_override("scroll", track)
	body_scrollbar.add_theme_stylebox_override("scroll_focus", track)


func _sync_scrollbar() -> void:
	if not is_inside_tree():
		return
	var inner := body_label.get_v_scroll_bar()
	var scroll_range := maxf(0.0, inner.max_value - inner.page)
	body_scrollbar.visible = scroll_range > 1.0
	body_scrollbar.max_value = scroll_range
	body_scrollbar.page = 0.0
	body_scrollbar.set_value_no_signal(inner.value)
