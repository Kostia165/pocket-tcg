class_name Screen
extends ScrollContainer
## Base class for the tab screens: a vertical scroll list rebuilt whenever the game state changes.

var main: Main
var content: VBoxContainer


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	add_child(content)


func rebuild(keep_scroll := true) -> void:
	var scroll := scroll_vertical if keep_scroll else 0
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()
	build()
	_let_drags_through(content)
	# Content size is only known after the next layout pass.
	await get_tree().process_frame
	scroll_vertical = scroll


func build() -> void:
	pass


## Panels, check boxes etc. stop touch events by default, so a swipe that starts on them
## never reaches the ScrollContainer. Make every such control pass events up instead.
static func _let_drags_through(node: Node) -> void:
	for c in node.get_children():
		if c is Control and c.mouse_filter == Control.MOUSE_FILTER_STOP:
			c.mouse_filter = Control.MOUSE_FILTER_PASS
		_let_drags_through(c)


func section(title: String) -> void:
	content.add_child(UI.label(title, 32, UI.GOLD))
