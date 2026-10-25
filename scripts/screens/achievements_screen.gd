extends Screen
## List of all achievements with their unlock day or current progress.


func build() -> void:
	content.add_child(UI.button("<  Back", main.go_back))
	var list := Game.achievement_list()
	section("Achievements  %d / %d" % [Game.achievements.size(), list.size()])
	for a in list:
		var done := Game.achievements.has(a.id)
		var box := UI.panel(Color("3a3220") if done else UI.PANEL, UI.GOLD if done else UI.PANEL_LIGHT, 2)
		var right := UI.label("Day %d" % Game.achievements[a.id] if done else Game.achievement_progress(a.id), 20, UI.GOLD if done else UI.TEXT_DIM)
		var text := UI.vbox([
			UI.label(a.name, 26, Color.WHITE if done else UI.TEXT_DIM),
			UI.para(a.desc, 20, UI.TEXT_DIM),
		])
		text.add_theme_constant_override("separation", 0)
		box.add_child(UI.hbox([UI.expand(text), right]))
		content.add_child(box)
