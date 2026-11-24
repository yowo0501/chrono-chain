extends CanvasLayer
## Session-scoped onboarding. Only the playable Main field enables it.
const View = preload("res://scripts/tutorial_view.gd")
var enabled := false
var active := false
var seen: Dictionary = {}
var field: Node2D
var view: Control
var choices: Array = []
var selected := 0
var previous_pause := false
var first_battle_done := false
var night_battle_done := false
var manager: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	manager = get_node("/root/EncounterManager")
	view = View.new()
	view.tutorial = self
	add_child(view)
	view.hide()

func start(source: Node2D) -> void:
	field = source
	enabled = true
	show_step("move", "방향키로 이동", "↑ ↓ ← → 방향키로 파티를 움직입니다.\n강조된 방향키를 누르거나 클릭해 시작하세요.", [
		option("←", Rect2(226,450,72,50), KEY_LEFT, move.bind(Vector2i.LEFT)),
		option("↑", Rect2(306,450,72,50), KEY_UP, move.bind(Vector2i.UP)),
		option("↓", Rect2(386,450,72,50), KEY_DOWN, move.bind(Vector2i.DOWN)),
		option("→", Rect2(466,450,72,50), KEY_RIGHT, move.bind(Vector2i.RIGHT))])

func move(direction: Vector2i) -> void:
	var player: Node2D = field.walker()
	player._move_to(player.grid_pos + direction)
	info("light", "첫 목표 · 빛 에어리어", "밝은 구역에서 보이는 적에게 다가가세요.\n적과 접촉하면 전투가 시작됩니다.\nM 지도의 노란 구역이 빛 에어리어입니다.", "빛 에어리어로 출발")

func option(label: String, rect: Rect2, key: int, callback: Callable = Callable(), existing: bool = false) -> Dictionary:
	return {"label": label, "rect": rect, "key": key, "callback": callback, "existing": existing}

func info(id: String, title: String, body: String, label: String = "확인 · Space / Enter", callback: Callable = Callable()) -> void:
	show_step(id, title, body, [option(label, Rect2(224,450,320,50), KEY_ENTER, callback)])

func show_step(id: String, title: String, body: String, buttons: Array) -> void:
	if not enabled or active or seen.has(id):
		return
	seen[id] = true
	choices = buttons
	selected = 0
	previous_pause = get_tree().paused
	get_tree().paused = true
	active = true
	view.title = title
	view.body = body
	view.show()
	view.queue_redraw()

func choose(index: int) -> void:
	if not active or index < 0 or index >= choices.size():
		return
	var callback: Callable = choices[index].callback
	active = false
	view.hide()
	get_tree().paused = previous_pause
	choices = []
	if callback.is_valid():
		callback.call()

func _input(event: InputEvent) -> void:
	if not active:
		return
	get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point := view.get_local_mouse_position()
		for i in choices.size():
			if choices[i].rect.has_point(point):
				choose(i)
				return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	for i in choices.size():
		if choices[i].key == key or (choices[i].key in [KEY_SPACE, KEY_ENTER] and key in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]):
			choose(i)
			return
	if choices[0].existing:
		if key in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
			selected = (selected + 1) % choices.size()
			view.queue_redraw()
		elif key in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_Z]:
			choose(selected)

func _process(_delta: float) -> void:
	if not enabled or active or not is_instance_valid(field) or get_tree().paused:
		return
	if manager.active:
		var battle: Control = manager.screen
		if not is_instance_valid(battle) or is_instance_valid(manager.transition):
			return
		if battle.phase == battle.Phase.COMMAND:
			if not battle.field_context.get("light", true) and not seen.has("dark_battle"):
				info("dark_battle", "어둠 속의 판정선", "어둠 전투에서는 적과 판정선이 보이지 않습니다.\n위치를 추측해 맞추거나 밝히기 특수 스킬을 쓰세요.\n한 번 맞춘 적의 판정선은 이 전투 내내 보입니다.")
			elif not seen.has("commands"):
				command_step(battle, false)
			elif battle.round_number >= 2 and not seen.has("resources"):
				command_step(battle, true)
		elif battle.phase == battle.Phase.GUARD_QTE and not seen.has("guard_timing"):
			show_step("guard_timing", "수비 타이밍", "Space/Enter를 적의 위치선에 맞추면 피해를 반사합니다.\n빗나가도 누르면 피해 절반, 시간 초과는 그대로 받습니다.\nSpace/Enter로 재개한 뒤, 타이밍에 다시 누르세요.", [option("Space / Enter · 수비 시작", Rect2(224,450,320,50), KEY_SPACE)])
		return
	if field.boss_spawned and not seen.has("boss"):
		info("boss", "모든 가로등 점등 완료!", "분수 광장에 보스가 나타났습니다.\n지도를 확인하고 광장으로 돌아가 보스에게 다가가세요.", "M · 보스 위치 보기", open_map)
		choices[0].key = KEY_M
	elif night_battle_done and not seen.has("lamps"):
		info("lamps", "다음 목표 · 모든 가로등 밝히기", "꺼진 가로등은 파란 빛으로 표시됩니다.\n가로등 옆에서 E를 누르면 체력 소모 없이 켤 수 있습니다.\n도시의 모든 가로등을 밝히세요!", "M · 가로등 지도 보기", open_map)
		choices[0].key = KEY_M
	elif night_battle_done and not seen.has("lamp_use") and not field.walker()._moving:
		var target: Dictionary = field.interaction_target(field.walker())
		if not target.is_empty() and not field.lit[field.lamps.find(target.tile)]:
			show_step("lamp_use", "가로등 켜기", "꺼진 가로등 옆에 도착했습니다.\nE 또는 아래 버튼으로 이 가로등을 밝히세요.", [option("E · 가로등 켜기", Rect2(224,450,320,50), KEY_E, light_lamp)])
	elif not field.is_lit(field.walker().grid_pos) and not seen.has("dark_area"):
		info("dark_area", "어둠 에어리어", "여기서는 이동 중 무작위로 적과 마주칩니다.\n보이는 적이 없어도 전투가 시작될 수 있습니다.")

func open_map() -> void:
	field.hud.show_map = true

func light_lamp() -> void:
	field.interact(field.walker())

func command_step(battle: Control, resources: bool) -> void:
	if resources:
		info("resources", "2라운드 · 집중과 특수", "집중은 집중 스택을 1개 얻고 행동을 마칩니다.\n특수는 모은 공격·수비·집중 스택을 소비하는 스킬입니다.\n설명을 확인한 뒤 원하는 행동을 자유롭게 선택하세요.")
		return
	var buttons: Array = []
	for index in [0,1]:
		buttons.append(option("", battle._command_rect(index), 0, battle.select_command.bind(index), true))
	show_step("commands", "첫 전투 · 공격과 수비", "공격은 타이밍을 맞춰 적을 때립니다. 수비는 방어 태세입니다.\n공격 또는 수비를 누르면 자세한 설명을 보여드립니다.\n강조 버튼 클릭 또는 방향키 선택 · Space/Enter 확인", buttons)

func explain_command(battle: Control, index: int) -> bool:
	var id := "command_%d" % index
	if not enabled or seen.has(id) or active:
		return false
	if index >= 2 and not seen.has("resources"):
		return false
	var descriptions := [
		"커서를 적의 위치선에 맞춰 Space/Enter를 누르세요.\n왼쪽 선은 위쪽 적, 오른쪽 선은 아래쪽 적입니다.\n맞추면 타격, 빗나가거나 시간이 끝나면 MISS입니다.\n공격 스택도 1개 얻습니다. (최대 3개)",
		"수비 스택을 1개 얻고 방어 태세를 취합니다. (최대 3개)\n이후 공격받을 때 Space/Enter로 수비 판정을 합니다.\n공격한 적의 선에 맞추면 반사, 그 외 입력은 피해 절반,\n아무것도 누르지 않으면 전체 피해를 받습니다.",
		"집중하면 집중 스택을 1개 얻고 행동을 마칩니다.\n스택은 종류별 최대 3개이며 전투가 끝나도 유지됩니다.\n모은 스택은 특수 스킬의 비용으로 사용할 수 있습니다.",
		"특수 목록에서 스킬별 공격·수비·집중 비용을 확인하세요.\n비용이 부족한 스킬은 사용할 수 없습니다.\n밝히기 스킬은 어둠 속 적과 판정선을 드러냅니다.\n사용할 스킬이 없다면 돌아가기로 다른 행동을 고르세요."]
	show_step(id, ["공격 방법", "수비 방법", "집중 스택", "특수 스킬"][index], descriptions[index], [option("행동 실행 · Space / Enter", Rect2(224,450,320,50), KEY_ENTER, battle.select_command.bind(index))])
	return true

func show_clear(source: Node2D) -> void:
	# Completion takes priority over any outstanding onboarding prompt.
	if active:
		active = false
		get_tree().paused = previous_pause
	field = source
	enabled = true
	field.hud.visible = true
	info("clear", "튜토리얼 클리어", "모든 가로등을 밝히고 보스를 물리쳤습니다.\n튜토리얼을 완료했습니다!", "타이틀 화면으로 돌아가기", return_to_title)

func return_to_title() -> void:
	get_node("/root/StoryRouter").open_scene("res://scenes/menu/title.tscn")

func battle_ended(context: Dictionary) -> void:
	if not enabled:
		return
	field.hud.visible = true
	if not context.get("light", true):
		night_battle_done = true
	if not first_battle_done:
		first_battle_done = true
		if not night_battle_done:
			info("after_first", "다음은 어둠 에어리어", "이제 어두운 구역으로 들어가 보세요.\n어둠에서는 이동 중 무작위로 전투가 발생합니다.\nM 지도의 파란 구역을 찾아가세요.", "어둠 에어리어로 출발")
