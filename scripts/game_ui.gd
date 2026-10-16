extends CanvasLayer
class_name AbrissUI

signal tool_selected(index: int)
signal restart_requested
signal purchase_requested(id: String)
signal continue_requested
signal sensitivity_changed(value: float)
signal quality_changed(enabled: bool)
signal quality_level_changed(level: int)
signal detonate_requested
signal contract_requested

const INK := Color("10212e")
const CARD := Color("142b3a")
const TEXT := Color("f1f4ed")
const MUTED := Color("a3bac4")
const ORANGE := Color("ffa83e")
const YELLOW := Color("f2cf65")
const TOOL_NAMES := ["Vorschlaghammer", "Impulsladung", "Wirbelladung"]

var cash_label: Label
var progress_label: Label
var contract_label: Label
var charges_label: Label
var progress_bar: ProgressBar
var tool_hint: Label
var toast_label: Label
var crosshair: Label
var tool_buttons: Array[Button] = []
var _root: Control
var _overlay: ColorRect
var _panel_body: VBoxContainer
var _toast: PanelContainer
var _toast_remaining := 0.0
var _cash := 0
var _owned: Dictionary = {}
var _panel_kind := ""
var _sensitivity := 0.002
var _quality := true
var _quality_level := 1
var _shop_balance: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_build_hud()
	_build_overlay()
	set_status(0, 0.0, 0, 0, "Erster Auftrag · Gartenhaus")


func _process(delta: float) -> void:
	if _toast_remaining > 0.0:
		_toast_remaining -= delta
		_toast.visible = _toast_remaining > 0.0


func set_status(cash: int, progress: float, tool_index: int, charges: int, contract_title: String) -> void:
	_cash = cash
	if cash_label == null:
		return
	cash_label.text = _money(cash)
	contract_label.text = contract_title
	var percent := clampf(progress, 0.0, 1.0) * 100.0
	progress_label.text = "Abrissfortschritt   %d %%" % roundi(percent)
	progress_bar.value = percent
	charges_label.text = "%d Ladungen platziert" % charges
	for index in range(tool_buttons.size()):
		tool_buttons[index].add_theme_stylebox_override("normal", _style(ORANGE if index == tool_index else CARD, 10))
		tool_buttons[index].add_theme_color_override("font_color", INK if index == tool_index else TEXT)
	if tool_index == 0:
		tool_hint.text = "Linksklick: schlagen  ·  Nah an ein Bauteil herangehen"
	else:
		tool_hint.text = "Linksklick: Ladung platzieren  ·  R: alle Ladungen zünden"
	if is_instance_valid(_shop_balance):
		_shop_balance.text = "Verfügbar: " + _money(cash)


func show_toast(message: String) -> void:
	if toast_label == null:
		return
	toast_label.text = message
	_toast_remaining = 4.0
	_toast.show()


func show_shop(cash: int, owned: Dictionary) -> void:
	_cash = cash
	_owned = owned.duplicate()
	_open_panel("shop", "WERKSTATT", "Dein nächstes Werkzeug wartet.")
	_shop_balance = _label("Verfügbar: " + _money(cash), 21, YELLOW)
	_panel_body.add_child(_shop_balance)
	_add_shop_item("hammer_upgrade", "Verstärkter Hammer", "Mehr Schlagkraft für Holz, Ziegel und Beton.", 450)
	_add_shop_item("blast_upgrade", "Impulsverstärker", "Mehr Wirkung für beide Ladungstypen.", 700)
	_add_shop_item("boots_upgrade", "Leichte Arbeitsstiefel", "Schneller über die Baustelle laufen.", 350)
	_panel_body.add_child(_paragraph("Gekaufte Verbesserungen und dein Guthaben werden gespeichert.", 14, MUTED))
	var actions := _row()
	_panel_body.add_child(actions)
	actions.add_child(_button("Zurück zur Baustelle", func(): continue_requested.emit(), true))
	actions.add_child(_button("Neuer Auftrag", func(): contract_requested.emit()))


func show_pause() -> void:
	_open_panel("pause", "FEIERABEND?", "Deine Baustelle wartet auf dich.")
	_panel_body.add_child(_button("Weiterspielen", func(): continue_requested.emit(), true))
	_panel_body.add_child(_button("Auftrag neu starten", func(): restart_requested.emit()))
	_panel_body.add_child(_label("EINSTELLUNGEN", 14, YELLOW))
	var sensitivity_row := _row()
	_panel_body.add_child(sensitivity_row)
	sensitivity_row.add_child(_label("Mausempfindlichkeit", 17, TEXT))
	var slider := HSlider.new()
	slider.min_value = 0.001
	slider.max_value = 0.005
	slider.step = 0.0001
	slider.value = _sensitivity
	slider.custom_minimum_size = Vector2(220, 30)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(value: float):
		_sensitivity = value
		sensitivity_changed.emit(value)
	)
	sensitivity_row.add_child(slider)
	var quality_row := _row()
	quality_row.add_child(_label("Grafikqualität", 17, TEXT))
	var quality_choice := OptionButton.new()
	quality_choice.add_item("Niedrig · 36 aktive Bruchstücke")
	quality_choice.add_item("Mittel · 72 aktive Bruchstücke")
	quality_choice.add_item("Hoch · 96 aktive Bruchstücke")
	quality_choice.selected = _quality_level
	quality_choice.custom_minimum_size = Vector2(310, 42)
	quality_choice.item_selected.connect(func(index: int):
		_quality_level = index
		_quality = index > 0
		quality_level_changed.emit(index)
	)
	quality_row.add_child(quality_choice)
	_panel_body.add_child(quality_row)
	_panel_body.add_child(_paragraph("WASD Bewegen  ·  Maus Umsehen  ·  Leertaste Springen\n1 / 2 / 3 Werkzeug  ·  Linksklick Benutzen  ·  R Zünden\nShift Sprint  ·  B Werkstatt  ·  F5 Neustart  ·  Esc Pause", 15, MUTED))
	_panel_body.add_child(_button("Spiel beenden", func(): get_tree().quit()))


func show_result(earned: int, total: int) -> void:
	_open_panel("result", "SAUBERE ARBEIT!", "Auftrag abgeschlossen. Zeit für den nächsten Abriss.")
	var payout := _label("+ " + _money(earned), 46, YELLOW)
	payout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel_body.add_child(payout)
	_panel_body.add_child(_paragraph("Die Auszahlung wurde deinem Firmenkonto gutgeschrieben.", 16, TEXT))
	_panel_body.add_child(_label("Firmenkonto: " + _money(total), 21, YELLOW))
	_panel_body.add_child(_button("Nächsten Auftrag annehmen", func(): contract_requested.emit(), true))
	_panel_body.add_child(_button("Baustelle weiter erkunden", func(): continue_requested.emit()))


func show_briefing(title: String, reward: int) -> void:
	_open_panel("briefing", "DEIN ABRISSAUFTRAG", title)
	_panel_body.add_child(_paragraph("Willkommen bei deiner Abrissfirma. Erkunde das Haus, probiere den Hammer aus und bringe das Gebäude zum Einsturz.", 19, TEXT))
	_panel_body.add_child(_paragraph("Auftragsziel: mindestens 72 % Abrissfortschritt.\nDein Vorrat: 12 orange Impulsladungen und 6 violette Wirbelladungen.", 17, YELLOW))
	_panel_body.add_child(_paragraph("Ladungen mit 2 / 3 auswählen, mit Linksklick platzieren und anschließend mit R gemeinsam zünden.", 17, MUTED))
	_panel_body.add_child(_label("Auftragsprämie: " + _money(reward), 22, YELLOW))
	_panel_body.add_child(_button("Auftrag annehmen und loslegen", func(): contract_requested.emit(), true))


func hide_panels() -> void:
	_overlay.hide()
	_panel_kind = ""
	crosshair.show()


func is_panel_open() -> bool:
	return is_instance_valid(_overlay) and _overlay.visible


func _build_hud() -> void:
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_sync_layout()
	get_viewport().size_changed.connect(_sync_layout)
	var company := _card_at(Vector2(24, 22), Vector2(268, 86))
	var company_body := _column(company, 12)
	company_body.add_child(_label("ABRISSFIRMA", 23, YELLOW))
	var balance_row := _row()
	company_body.add_child(balance_row)
	var account_caption := _label("FIRMENKONTO", 12, MUTED)
	account_caption.custom_minimum_size.x = 110
	account_caption.size_flags_horizontal = Control.SIZE_FILL
	balance_row.add_child(account_caption)
	cash_label = _label("0 €", 21, TEXT)
	cash_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	balance_row.add_child(cash_label)
	var job := PanelContainer.new()
	job.add_theme_stylebox_override("panel", _style(CARD, 12))
	job.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(job)
	job.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	job.offset_left = -364
	job.offset_right = -24
	job.offset_top = 22
	job.offset_bottom = 142
	job.custom_minimum_size = Vector2(340, 120)
	var job_body := _column(job, 12)
	job_body.add_child(_label("AKTUELLER AUFTRAG", 12, YELLOW))
	contract_label = _label("Gartenhaus", 18, TEXT)
	job_body.add_child(contract_label)
	progress_label = _label("Abrissfortschritt   0 %", 14, MUTED)
	job_body.add_child(progress_label)
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0, 7)
	progress_bar.show_percentage = false
	progress_bar.add_theme_stylebox_override("background", _style(INK, 4))
	progress_bar.add_theme_stylebox_override("fill", _style(ORANGE, 4))
	job_body.add_child(progress_bar)
	crosshair = _label("+", 26, Color(1, 1, 1, 0.88))
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_root.add_child(crosshair)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.position = _root.size * 0.5 + Vector2(-12, -20)
	crosshair.size = Vector2(24, 40)
	var toolbar_backdrop := Panel.new()
	toolbar_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toolbar_backdrop.add_theme_stylebox_override("panel", _style(Color(0.055, 0.12, 0.17, 0.94), 14, Color(0.35, 0.47, 0.53, 0.7)))
	_root.add_child(toolbar_backdrop)
	toolbar_backdrop.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	toolbar_backdrop.offset_left = -470
	toolbar_backdrop.offset_right = 470
	toolbar_backdrop.offset_top = -166
	toolbar_backdrop.offset_bottom = -8
	var bottom := VBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.add_theme_constant_override("separation", 8)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.offset_left = -450
	bottom.offset_right = 450
	bottom.offset_top = -145
	bottom.offset_bottom = -17
	tool_hint = _label("", 15, TEXT)
	tool_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(tool_hint)
	var tools := _row()
	bottom.add_child(tools)
	for index in range(3):
		var tool_index := index
		var btn := _button("%d   %s" % [index + 1, TOOL_NAMES[index]], func():
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				tool_selected.emit(tool_index)
		)
		btn.custom_minimum_size = Vector2(220, 47)
		tools.add_child(btn)
		tool_buttons.append(btn)
	var keys := _label("WASD Bewegen  ·  Shift Sprint  ·  Leertaste Springen  ·  R Zünden  ·  B Shop  ·  F5 Neustart  ·  Esc Pause", 13, MUTED)
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(keys)
	charges_label = _label("0 Ladungen platziert", 14, YELLOW)
	charges_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(charges_label)
	_toast = PanelContainer.new()
	_toast.add_theme_stylebox_override("panel", _style(INK, 10, ORANGE))
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toast)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_left = -280
	_toast.offset_right = 280
	_toast.offset_top = 154
	_toast.offset_bottom = 200
	_toast.custom_minimum_size = Vector2(560, 46)
	toast_label = _label("", 17, TEXT)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.add_child(toast_label)
	_toast.hide()


func _build_overlay() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0.025, 0.06, 0.09, 0.82)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(610, 0)
	panel.add_theme_stylebox_override("panel", _style(CARD, 18, Color("3d5663")))
	center.add_child(panel)
	var margin := MarginContainer.new()
	for edge in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 28)
	panel.add_child(margin)
	_panel_body = VBoxContainer.new()
	_panel_body.custom_minimum_size = Vector2(554, 0)
	_panel_body.add_theme_constant_override("separation", 15)
	margin.add_child(_panel_body)
	_overlay.hide()


func _open_panel(kind: String, title: String, subtitle: String) -> void:
	for child in _panel_body.get_children():
		_panel_body.remove_child(child)
		child.queue_free()
	_shop_balance = null
	_panel_kind = kind
	_overlay.show()
	crosshair.hide()
	_panel_body.add_child(_label("ABRISSFIRMA  /  " + title, 13, YELLOW))
	_panel_body.add_child(_paragraph(subtitle, 26, TEXT))


func _add_shop_item(id: String, title: String, description: String, cost: int) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _style(INK, 10))
	_panel_body.add_child(card)
	var row := _row()
	card.add_child(row)
	var words := VBoxContainer.new()
	words.custom_minimum_size.x = 340
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(_label(title, 18, TEXT))
	words.add_child(_label(description, 14, MUTED))
	row.add_child(words)
	var bought := bool(_owned.get(id, false))
	var action := _button("Gekauft" if bought else _money(cost), func(): purchase_requested.emit(id), not bought)
	action.custom_minimum_size = Vector2(130, 46)
	action.disabled = bought or _cash < cost
	row.add_child(action)


func _card_at(position: Vector2, minimum_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = position
	panel.custom_minimum_size = minimum_size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(CARD, 12))
	_root.add_child(panel)
	return panel


func _column(parent: Node, spacing: int) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", spacing / 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(column)
	return column


func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return row


func _label(content: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = content
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _paragraph(content: String, font_size: int, color: Color) -> Label:
	var label := _label(content, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 554
	return label


func _sync_layout() -> void:
	if is_instance_valid(_root):
		_root.position = Vector2.ZERO
		_root.size = get_viewport().get_visible_rect().size


func _button(content: String, callback: Callable, accent := false) -> Button:
	var button := Button.new()
	button.text = content
	button.custom_minimum_size.y = 46
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", INK if accent else TEXT)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_stylebox_override("normal", _style(ORANGE if accent else Color("223e4d"), 9))
	button.add_theme_stylebox_override("hover", _style(YELLOW, 9))
	button.add_theme_stylebox_override("pressed", _style(Color("e89735"), 9))
	button.add_theme_stylebox_override("disabled", _style(Color("20313c"), 9))
	button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, 9, YELLOW))
	button.pressed.connect(callback)
	return button


func _style(color: Color, radius: int, border := Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	if border.a > 0.0:
		style.border_color = border
		style.set_border_width_all(1)
	return style


func _money(value: int) -> String:
	return "%d €" % value
