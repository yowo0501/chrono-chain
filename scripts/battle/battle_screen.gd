extends Control
## Battle presentation and explicit turn state machine. Values live in battle_balance.json.
signal battle_finished(won: bool)
const Rules = preload("res://scripts/battle/battle_rules.gd")
const TimerSkill = preload("res://scripts/battle/timer_skill.gd")
const AssassinSkill = preload("res://scripts/battle/assassin_skill.gd")
const DESIGN := Vector2(768, 672)
const INK := Color("0c1220")
const PAPER := Color("e9edf4")
const MUTED := Color("97a7bc")
const ORANGE := Color("ffb35a")
const BLUE := Color("61cfff")
const GREEN := Color("66dfb0")
const HERO_POS := [Vector2(200, 414), Vector2(92, 324)]
const FOE_POS := [Vector2(475, 416), Vector2(587, 340), Vector2(694, 264)]
const ACTOR_SCALE := 0.75
const ANIMATION_CELL := Vector2(384, 240)
const FOOT_ANCHOR := Vector2(128, 232)
const SPECIAL_DURATION := 2.4
const FOCUS_DURATION := 1.0
const CHUHEUN_IDLE_CYCLE := 1.6
const YEONWOO_SPIN_CYCLE := 1.6
const WINDUP_FRAMES := [8, 9, 10, 11, 12, 13]
enum Phase { INTRO, COMMAND, TARGET, ATTACK_QTE, GUARD_QTE, RESOLVE, ENEMY, RESULT, TIMER, SKILLS, ASSASSIN }

var party: Array
var enemies: Array = []
var balance: Dictionary
var rng: RandomNumberGenerator
var phase := Phase.INTRO
var hero_index := 0
var enemy_index := 0
var target_index := 0
var defending_index := 0
var command_index := 0
var round_number := 1
var clock := 0.0
var qte_elapsed := 0.0
var delay := 0.0
var pending := Callable()
var won := false
var heading := "그림자가 앞을 가로막았다"
var message := "그림자 3마리 출현"
var float_text := ""
var float_position := Vector2.ZERO
var impact_position := Vector2.ZERO
var fx_time := 0.0
var shake_time := 0.0
var impact := false
var action_kind := ""
var action_index := -1
var hurt_hero := -1
var hurt_enemy := -1
var last_grade := ""
var font: SystemFont
var textures: Array[Texture2D] = []
var motion_textures: Array[Texture2D] = []
var expressive_textures: Array[Texture2D] = []
var calm_idle_texture: Texture2D
var fixed_windup_body: Texture2D
var fixed_windup_wrist: Texture2D
var windup_rig: Dictionary
var chain_texture: Texture2D
var chain_joins: Dictionary
var special_actor := -1
var next_special_actor := 0
var special_elapsed := 0.0
var special_wait := 7.0
var focus_elapsed := 0.0
var monster_texture: Texture2D
var armored_texture: Texture2D
var timer_texture: Texture2D
var timer_cast: TimerSkill
var assassin_cast: AssassinSkill
var timer_motion_texture: Texture2D
var focus_texture: Texture2D
var assassin_texture: Texture2D
var eyes_texture: Texture2D
var skill_index := 0
var target_action := "attack"
var armored_encounter := false

func setup(heroes: Array, settings: Dictionary, random: RandomNumberGenerator, armored: bool = false) -> void:
	party = heroes
	balance = settings
	rng = random
	armored_encounter = armored
	for hero in party:
		hero.guarding = false
		for stack_name in ["attack_stacks", "defense_stacks", "focus_stacks"]:
			if not hero.has(stack_name):
				hero[stack_name] = 0
	for i in int(balance.monster_count):
		var enemy: Dictionary = (balance.armored_monster if armored else balance.monster).duplicate(true)
		enemy.hp = enemy.max_hp
		enemy.name += " " + str(i + 1)
		enemies.append(enemy)
	message = "그림자 %d마리 출현" % enemies.size()
	if armored:
		heading = "중장 그림자가 앞을 가로막았다"
		message = "중장 그림자 %d마리 출현 · 두 라운드마다 공격" % enemies.size()

func _ready() -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans CJK KR", "Arial"])
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	for id in ["chuheun", "yeonwoo"]:
		textures.append(load("res://assets/sprites/battle/" + id + ".png"))
		motion_textures.append(load("res://assets/sprites/battle/" + id + "-motion.png"))
		expressive_textures.append(load("res://assets/sprites/battle/" + id + "-expressive.png"))
	chain_texture = load("res://assets/sprites/battle/chain-extension.png")
	calm_idle_texture = load("res://assets/sprites/battle/chuheun-idle-calm.png")
	fixed_windup_body = load("res://assets/sprites/battle/yeonwoo-windup-body.png")
	fixed_windup_wrist = load("res://assets/sprites/battle/yeonwoo-windup-wrist.png")
	windup_rig = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/battle/yeonwoo-windup-rig.json"))
	chain_joins = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/battle/chain-joins.json"))
	monster_texture = load("res://assets/sprites/battle/shadow.png")
	armored_texture = load("res://assets/sprites/battle/armored-shadow.png")
	timer_texture = load("res://assets/sprites/battle/chuheun-timer.png")
	timer_motion_texture = load("res://assets/sprites/battle/chuheun-timer-v2.png")
	focus_texture = load("res://assets/sprites/battle/focus.png")
	assassin_texture = load("res://assets/sprites/battle/yeonwoo-assassin.png")
	eyes_texture = load("res://assets/sprites/battle/yeonwoo-eyes-v2.png")
	_resize()
	get_viewport().size_changed.connect(_resize)
	_schedule(1.0, _start_party_turn)

func _resize() -> void:
	var view := get_viewport_rect().size
	scale = view / DESIGN
	size = DESIGN
	queue_redraw()

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if not (phase == Phase.ASSASSIN and assassin_cast.is_qte()):
		clock += delta
	if action_kind == "focus" and phase == Phase.RESOLVE:
		focus_elapsed += delta
	_advance_idle(delta)
	fx_time = maxf(0, fx_time - delta)
	shake_time = maxf(0, shake_time - delta)
	if phase == Phase.ASSASSIN:
		assassin_cast.advance(delta)
		queue_redraw()
		return
	if phase == Phase.TIMER:
		timer_cast.advance(delta)
		queue_redraw()
		return
	if phase in [Phase.ATTACK_QTE, Phase.GUARD_QTE]:
		qte_elapsed += delta
		if qte_elapsed >= float(balance.qte.duration):
			_resolve_qte(false)
	elif delay > 0:
		delay -= delta
		if delay <= 0 and pending.is_valid():
			var callback := pending
			pending = Callable()
			callback.call()
	queue_redraw()

func _advance_idle(delta: float) -> void:
	# One shared scheduler prevents overlap and alternates who gets the next break.
	if phase not in [Phase.COMMAND, Phase.TARGET, Phase.SKILLS]:
		if special_actor != -1:
			special_actor = -1
			special_wait = 6.0
		return
	if special_actor != -1:
		special_elapsed += delta
		if special_elapsed >= SPECIAL_DURATION:
			special_actor = -1
			special_wait = 6.0
		return
	special_wait -= delta
	if special_wait > 0:
		return
	for offset in party.size():
		var candidate := (next_special_actor + offset) % party.size()
		if int(party[candidate].hp) > 0 and not bool(party[candidate].guarding):
			special_actor = candidate
			next_special_actor = (candidate + 1) % party.size()
			special_elapsed = 0.0
			return
	special_wait = 6.0

func special_frame() -> int:
	# Fewer pose changes, with time to settle into the stretch/yawn.
	var frames := [8, 9, 10, 11, 13, 15]
	var boundaries := [0.25, 0.55, 0.80, 1.65, 2.05]
	for i in boundaries.size():
		if special_elapsed < boundaries[i]:
			return frames[i]
	return 15

func attack_frame(elapsed: float) -> int:
	var frames := [0, 2, 3, 4, 6, 7]
	var boundaries := [0.10, 0.20, 0.40, 0.54, 0.68]
	for i in boundaries.size():
		if elapsed < boundaries[i]:
			return frames[i]
	return 7

func idle_frame(index: int, time: float) -> int:
	# Full support/landing poses last longer than the small weight transfers.
	var t := fposmod(time, CHUHEUN_IDLE_CYCLE)
	var boundaries: Array = [0.28, 0.50, 0.80, 1.08, 1.30] if index == 0 else [0.7, 0.9, 1.3]
	for i in boundaries.size():
		if t < float(boundaries[i]):
			return i
	return 5 if index == 0 else 3

func attack_anchor(index: int) -> Vector2:
	# Weapon reach changes; the actor's world-space foot anchor never does.
	return HERO_POS[index]

func chain_points(index: int, elapsed: float) -> PackedVector2Array:
	var frame := attack_frame(elapsed)
	var joins: Dictionary = chain_joins["chuheun" if index == 0 else "yeonwoo"]
	if not joins.has(str(frame)):
		return PackedVector2Array()
	var join: Array = joins[str(frame)]
	var start := attack_anchor(index) + Vector2(join[0], join[1]) * ACTOR_SCALE
	var end: Vector2 = FOE_POS[target_index] + Vector2(-24, -105) * ACTOR_SCALE
	var reach := smoothstep(0.10, 0.20, elapsed) * (1.0 - smoothstep(0.40, 0.54, elapsed))
	if reach <= 0.001:
		return PackedVector2Array()
	end = start.lerp(end, reach)
	var span := end.x - start.x
	var c1 := start + Vector2(span * 0.30, 0)
	var c2 := end - Vector2(span * 0.25, 0)
	var points := PackedVector2Array()
	for i in 49:
		var t := i / 48.0
		var point := start.bezier_interpolate(c1, c2, end, t)
		point.y += sin(t * PI) * (1.0 - reach) * 24.0
		points.append(point)
	return points

func _schedule(seconds: float, callback: Callable) -> void:
	delay = seconds
	pending = callback

func _start_party_turn() -> void:
	for hero in party:
		hero.guarding = false
	hero_index = 0
	_next_hero()

func _next_hero() -> void:
	if _check_end():
		return
	while hero_index < party.size() and int(party[hero_index].hp) <= 0:
		hero_index += 1
	if hero_index >= party.size():
		enemy_index = 0
		phase = Phase.ENEMY
		heading = "상대 턴"
		message = "그림자가 움직인다"
		_schedule(0.55, _enemy_action)
		return
	phase = Phase.COMMAND
	command_index = 0
	action_kind = ""
	action_index = -1
	target_action = "attack"
	heading = "아군 턴  /  " + str(party[hero_index].name)
	message = "행동을 선택하세요"

func select_command(index: int) -> void:
	if phase != Phase.COMMAND:
		return
	if index == 0:
		target_action = "attack"
		phase = Phase.TARGET
		target_index = Rules.living(enemies)[0]
		message = "공격할 그림자를 선택하세요"
	elif index == 1:
		party[hero_index].guarding = true
		party[hero_index].defense_stacks += 1
		action_kind = "guard"
		action_index = hero_index
		message = str(party[hero_index].name) + "의 방어 태세"
		phase = Phase.RESOLVE
		_schedule(0.55, _after_hero)
	elif index == 2:
		var hero: Dictionary = party[hero_index]
		hero.focus_stacks += 1
		action_kind = "focus"
		action_index = hero_index
		focus_elapsed = 0.0
		phase = Phase.RESOLVE
		message = str(hero.name) + "은 정신을 집중했다"
		_schedule(FOCUS_DURATION, _after_hero)
	elif index == 3:
		phase = Phase.SKILLS
		skill_index = 0
		message = "특수 스킬을 선택하세요"

func skills() -> Array:
	return balance.special_skills.get(str(party[hero_index].id), [])

func can_use_skill(skill: Dictionary) -> bool:
	for key in ["attack", "defense", "focus"]:
		if int(party[hero_index].get(key + "_stacks", 0)) < int(skill.cost.get(key, 0)):
			return false
	return true

func _pay_skill(skill: Dictionary) -> void:
	for key in ["attack", "defense", "focus"]:
		party[hero_index][key + "_stacks"] -= int(skill.cost.get(key, 0))

func select_skill(index: int) -> void:
	if phase != Phase.SKILLS:
		return
	var list := skills()
	if index == list.size():
		_back_to_commands()
		return
	if index < 0 or index >= list.size():
		return
	skill_index = index
	var skill: Dictionary = list[index]
	if not can_use_skill(skill):
		message = "스택이 부족합니다!"
		return
	target_action = str(skill.id)
	if str(skill.target) == "single":
		target_index = Rules.living(enemies)[0]
		phase = Phase.TARGET
		message = str(skill.name) + " 대상을 선택하세요"
	elif target_action == "assassin":
		_begin_assassin(skill)

func _back_to_commands() -> void:
	phase = Phase.COMMAND
	target_action = "attack"
	message = "행동을 선택하세요"

func _cancel_target() -> void:
	if target_action != "attack":
		phase = Phase.SKILLS
		message = "특수 스킬을 선택하세요"
	else:
		_back_to_commands()

func can_use_timer() -> bool:
	for skill in skills():
		if str(skill.id) == "timer":
			return can_use_skill(skill)
	return false

func _begin_timer() -> void:
	if not can_use_timer():
		phase = Phase.SKILLS
		message = "스택이 부족합니다!"
		return
	var hero: Dictionary = party[hero_index]
	_pay_skill(skills()[skill_index])
	phase = Phase.TIMER
	action_kind = "timer"
	action_index = hero_index
	special_actor = -1
	special_wait = 6.0
	fx_time = 0.0
	hurt_enemy = -1
	hurt_hero = -1
	delay = 0.0
	pending = Callable()
	timer_cast = TimerSkill.new()
	timer_cast.setup(balance.timer, int(hero.attack), HERO_POS[hero_index], FOE_POS[target_index], timer_texture)
	timer_cast.motion_texture = timer_motion_texture
	timer_cast.spear_hit.connect(_timer_spear_hit)
	timer_cast.lightning_hit.connect(_timer_lightning_hit)
	timer_cast.finished.connect(_after_hero)
	heading = "강추흔  /  특수 · 타이머"

func _begin_assassin(skill: Dictionary) -> void:
	_pay_skill(skill)
	phase = Phase.ASSASSIN
	action_kind = "assassin"
	action_index = hero_index
	special_actor = -1
	special_wait = 6.0
	fx_time = 0.0
	hurt_enemy = -1
	hurt_hero = -1
	delay = 0.0
	pending = Callable()
	assassin_cast = AssassinSkill.new()
	assassin_cast.setup(balance.assassin, int(party[hero_index].attack), HERO_POS[hero_index], Rules.living(enemies), assassin_texture, eyes_texture)
	assassin_cast.damage_hit.connect(_assassin_damage)
	assassin_cast.finished.connect(_after_hero)
	heading = "김연우  /  특수 · 어쌔신 스텝"

func _assassin_damage() -> void:
	for index in assassin_cast.marked:
		enemies[index].hp = maxi(0, int(enemies[index].hp) - assassin_cast.damage)
	shake_time = 0.3

func _timer_spear_hit() -> void:
	enemies[target_index].hp = maxi(0, int(enemies[target_index].hp) - int(timer_cast.spear_damage))
	hurt_enemy = target_index
	_effect(str(timer_cast.spear_damage), FOE_POS[target_index], false)

func _timer_lightning_hit() -> void:
	for enemy in enemies:
		enemy.hp = maxi(0, int(enemy.hp) - int(timer_cast.lightning_damage))
	fx_time = 0.0
	shake_time = 0.75

func confirm_target() -> void:
	if phase != Phase.TARGET or int(enemies[target_index].hp) <= 0:
		return
	if target_action == "timer":
		_begin_timer()
		return
	phase = Phase.ATTACK_QTE
	qte_elapsed = 0.0
	action_kind = "windup"
	action_index = hero_index
	message = "중앙에 닿는 순간 SPACE"

func _resolve_qte(pressed: bool) -> void:
	if phase not in [Phase.ATTACK_QTE, Phase.GUARD_QTE]:
		return
	var was_attack := phase == Phase.ATTACK_QTE
	var result := Rules.grade(qte_elapsed, float(balance.qte.duration), pressed,
		float(balance.qte.perfect_half_width), int(balance.qte.round_trips))
	last_grade = result
	phase = Phase.RESOLVE
	if was_attack:
		party[hero_index].attack_stacks += 1
		var damage := Rules.attack_damage(int(party[hero_index].attack), result)
		enemies[target_index].hp = maxi(0, int(enemies[target_index].hp) - damage)
		action_kind = "attack"
		action_index = hero_index
		hurt_enemy = target_index if damage > 0 else -1
		hurt_hero = -1
		var label := "CRITICAL HIT!" if result == "perfect" else ("HIT" if damage > 0 else "MISS")
		message = label + "  ·  " + str(damage)
		_effect(str(damage) if damage > 0 else "?", FOE_POS[target_index] if damage > 0 else HERO_POS[hero_index], result == "perfect")
		_schedule(0.8, _after_hero)
	else:
		var damage: Dictionary = Rules.defense_damage(int(enemies[enemy_index].attack), result)
		party[defending_index].hp = maxi(0, int(party[defending_index].hp) - int(damage.received))
		enemies[enemy_index].hp = maxi(0, int(enemies[enemy_index].hp) - int(damage.reflected))
		hurt_hero = defending_index if int(damage.received) > 0 else -1
		hurt_enemy = enemy_index if int(damage.reflected) > 0 else -1
		action_kind = "enemy_attack"
		action_index = enemy_index
		message = ("COUNTER HIT!" if result == "perfect" else ("GUARD" if result == "normal" else "방어 실패"))
		message += "  ·  " + str(damage.reflected if result == "perfect" else damage.received)
		_effect(str(damage.reflected if result == "perfect" else damage.received), FOE_POS[enemy_index] if result == "perfect" else HERO_POS[defending_index], result == "perfect")
		_schedule(0.8, _after_enemy)

func _after_hero() -> void:
	hero_index += 1
	_next_hero()

func _enemy_action() -> void:
	if _check_end():
		return
	while enemy_index < enemies.size() and int(enemies[enemy_index].hp) <= 0:
		enemy_index += 1
	if enemy_index >= enemies.size():
		round_number += 1
		_start_party_turn()
		return
	var interval := int(enemies[enemy_index].get("action_interval", 1))
	if round_number % interval != 0:
		action_kind = ""
		action_index = -1
		message = str(enemies[enemy_index].name) + "가 다음 공격을 준비한다"
		phase = Phase.ENEMY
		_schedule(0.65, _after_enemy)
		return
	var targets := Rules.living(party)
	defending_index = targets[rng.randi_range(0, targets.size() - 1)]
	heading = "상대 턴  /  " + str(enemies[enemy_index].name)
	action_kind = "enemy_windup"
	action_index = enemy_index
	message = str(party[defending_index].name) + "에게 공격!"
	phase = Phase.ENEMY
	_schedule(0.55, _enemy_strike)

func _enemy_strike() -> void:
	if bool(party[defending_index].guarding):
		phase = Phase.GUARD_QTE
		qte_elapsed = 0.0
		message = "중앙에 맞춰 SPACE · 반격 기회"
		return
	var damage := int(enemies[enemy_index].attack)
	party[defending_index].hp = maxi(0, int(party[defending_index].hp) - damage)
	phase = Phase.RESOLVE
	action_kind = "enemy_attack"
	hurt_hero = defending_index
	hurt_enemy = -1
	message = str(party[defending_index].name) + "  ·  " + str(damage) + " 피해"
	_effect(str(damage), HERO_POS[defending_index], false)
	_schedule(0.7, _after_enemy)

func _after_enemy() -> void:
	enemy_index += 1
	_enemy_action()

func _check_end() -> bool:
	if not Rules.living(party).is_empty() and not Rules.living(enemies).is_empty():
		return false
	won = Rules.living(enemies).is_empty() and not Rules.living(party).is_empty()
	phase = Phase.RESULT
	action_kind = ""
	pending = Callable()
	delay = 0.0
	heading = "전투 승리" if won else "전투 불능"
	message = "모두 회복한 뒤, 원래 위치로 돌아갑니다"
	return true

func _effect(value: String, where: Vector2, strong: bool) -> void:
	float_text = value
	float_position = where + Vector2(0, -160) * ACTOR_SCALE
	impact_position = where + (Vector2(-24, -105) if action_kind == "attack" else Vector2(0, -75)) * ACTOR_SCALE
	fx_time = 0.8
	impact = value != "?"
	if strong:
		shake_time = 0.3

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if phase == Phase.TIMER:
			if key == KEY_SPACE:
				timer_cast.press()
		elif phase == Phase.ASSASSIN:
			if key == KEY_SPACE:
				assassin_cast.press()
		elif phase == Phase.SKILLS:
			if key in [KEY_UP, KEY_LEFT]:
				skill_index = posmod(skill_index - 1, skills().size() + 1)
			elif key in [KEY_DOWN, KEY_RIGHT]:
				skill_index = (skill_index + 1) % (skills().size() + 1)
			elif key in [KEY_ENTER, KEY_Z]:
				select_skill(skill_index)
			elif key in [KEY_ESCAPE, KEY_X]:
				_back_to_commands()
		elif phase in [Phase.ATTACK_QTE, Phase.GUARD_QTE]:
			if key == KEY_SPACE:
				_resolve_qte(true)
		elif phase == Phase.COMMAND:
			if key in [KEY_LEFT, KEY_RIGHT]:
				command_index = command_index ^ 1
			elif key in [KEY_UP, KEY_DOWN]:
				command_index = (command_index + 2) % 4
			elif key in [KEY_ENTER, KEY_Z]:
				select_command(command_index)
		elif phase == Phase.TARGET:
			if key in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
				var choices := Rules.living(enemies)
				var direction := -1 if key in [KEY_LEFT, KEY_UP] else 1
				target_index = choices[posmod(choices.find(target_index) + direction, choices.size())]
			elif key in [KEY_ENTER, KEY_Z]:
				confirm_target()
			elif key in [KEY_ESCAPE, KEY_X]:
				_cancel_target()
		elif phase == Phase.RESULT and key == KEY_ENTER:
			battle_finished.emit(won)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and phase == Phase.SKILLS and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var direction := -1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1
		skill_index = clampi(skill_index + direction, 0, skills().size())
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point := get_local_mouse_position()
		if phase == Phase.COMMAND:
			for i in 4:
				if _command_rect(i).has_point(point):
					select_command(i)
					break
		elif phase == Phase.SKILLS:
			if Rect2(635, 510, 98, 26).has_point(point):
				_back_to_commands()
			else:
				var start := _skill_page_start()
				for i in range(start, mini(start + 2, skills().size())):
					if _skill_rect(i - start).has_point(point):
						select_skill(i)
						break
		elif phase == Phase.TARGET:
			if Rect2(635, 510, 98, 26).has_point(point):
				_cancel_target()
				return
			for i in enemies.size():
				if int(enemies[i].hp) > 0 and Rect2(FOE_POS[i] - Vector2(65, 180) * ACTOR_SCALE, Vector2(130, 225) * ACTOR_SCALE).has_point(point):
					target_index = i
					confirm_target()
					break
		elif phase == Phase.RESULT:
			battle_finished.emit(won)
		get_viewport().set_input_as_handled()

func _command_rect(index: int) -> Rect2:
	return Rect2(410 + (index % 2) * 159, 539 + int(index / 2) * 43, 148, 36)

func _skill_page_start() -> int:
	return int(mini(skill_index, maxi(0, skills().size() - 1)) / 2) * 2

func _skill_rect(row: int) -> Rect2:
	return Rect2(410, 541 + row * 42, 322, 39)

func _label(text: String, at: Vector2, color: Color = PAPER, font_size: int = 16) -> void:
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _panel(rect: Rect2, fill: Color = Color("121e31"), edge: Color = Color("344961")) -> void:
	draw_rect(rect, fill)
	draw_rect(rect, edge, false, 1)

func _draw() -> void:
	if font == null:
		return
	# Shake the whole composition, including its UI, for critical/counter hits.
	if shake_time > 0:
		var strength := 2.2 if phase == Phase.TIMER else 1.0
		draw_set_transform(Vector2(sin(clock * 137) * 5, cos(clock * 109) * 4) * strength)
	draw_rect(Rect2(-8, -8, 784, 688), INK)
	_draw_city()
	_label("CHRONO CHAIN", Vector2(28, 34), MUTED, 14)
	_label("ROUND %02d" % round_number, Vector2(627, 34), MUTED, 14)
	_label(heading, Vector2(28, 73), PAPER, 22)
	draw_line(Vector2(28, 88), Vector2(740, 88), Color("33455d"), 1)
	for i in [1, 0]:
		if not (action_kind == "attack" and phase == Phase.RESOLVE and action_index == i):
			_draw_hero(i)
	for i in range(enemies.size() - 1, -1, -1):
		_draw_enemy(i)
	if action_kind == "attack" and phase == Phase.RESOLVE:
		_draw_hero(action_index)
	if phase == Phase.TIMER:
		timer_cast.draw(self)
	elif phase == Phase.ASSASSIN:
		assassin_cast.draw(self)
	_draw_effects()
	if phase == Phase.TIMER:
		timer_cast.draw_qte(self)
	elif phase == Phase.ASSASSIN:
		assassin_cast.draw_qte(self)
	elif phase in [Phase.ATTACK_QTE, Phase.GUARD_QTE]:
		_draw_qte()
	elif phase in [Phase.COMMAND, Phase.TARGET, Phase.SKILLS]:
		_draw_commands()
	else:
		_panel(Rect2(24, 506, 720, 129))
		_label(message, Vector2(48, 557), ORANGE if phase == Phase.RESULT else PAPER, 22)
		var hint := "ENTER / 클릭 · 필드로 돌아가기" if phase == Phase.RESULT else ""
		if phase == Phase.RESULT:
			_label("프로토타입: 전투 종료 시 체력 전체 회복", Vector2(48, 585), MUTED, 14)
		_label(hint, Vector2(48, 613), MUTED, 16)
	_label("방향키 선택   ENTER / Z 확인   ESC / X 취소   SPACE 타이밍", Vector2(28, 657), MUTED, 13)

func _draw_city() -> void:
	# Pixel geometry echoes the existing night-city field without introducing a new map.
	draw_rect(Rect2(0, 96, 768, 390), Color("192a42"))
	for i in 12:
		var x := i * 70 - 24
		var top := 113 + (i * 37) % 63
		draw_rect(Rect2(x, top, 60, 219 - top), Color("101b2f"))
		for j in 3:
			for k in 3:
				var color := Color("d8ab6c") if (i + j * 3 + k) % 4 == 0 else Color("293e58")
				draw_rect(Rect2(x + 10 + j * 15, top + 15 + k * 22, 7, 10), color)
	draw_rect(Rect2(0, 228, 768, 258), Color("202c3d"))
	draw_rect(Rect2(0, 228, 768, 10), Color("4a5766"))
	for y in range(258, 486, 38):
		draw_line(Vector2(0, y), Vector2(768, y), Color("28374a"), 2)
	for x in range(20, 768, 102):
		draw_rect(Rect2(x, 452, 56, 4), Color("576275"))
	for x in [48, 716]:
		draw_rect(Rect2(x, 131, 4, 112), Color("718599"))
		draw_rect(Rect2(x - 7, 126, 18, 7), Color("aed9ed"))

func _frame(texture: Texture2D, frame: int, cols: int, rows: int, rect: Rect2, tint: Color = Color.WHITE) -> void:
	if texture == null:
		return
	var cell := Vector2(texture.get_width() / float(cols), texture.get_height() / float(rows))
	var region := Rect2(Vector2(frame % cols, int(frame / cols)) * cell, cell)
	draw_texture_rect_region(texture, rect, region, tint)

func _draw_hero(index: int) -> void:
	var hero: Dictionary = party[index]
	var base: Vector2 = HERO_POS[index]
	var alive := int(hero.hp) > 0
	var selected := index == hero_index and phase in [Phase.COMMAND, Phase.TARGET, Phase.SKILLS, Phase.ATTACK_QTE]
	if selected:
		var ring := PackedVector2Array()
		for point in 33:
			var a := point * TAU / 32.0
			ring.append(base + Vector2(cos(a) * 46, sin(a) * 8) * ACTOR_SCALE)
		draw_polyline(ring, ORANGE, 2)
		_label("▼", base + Vector2(-8, -184) * ACTOR_SCALE, ORANGE, 16)
	var frame := 0
	if bool(hero.guarding):
		frame = 4
	var winding := action_index == index and phase == Phase.ATTACK_QTE
	var attacking := action_index == index and action_kind == "attack" and phase == Phase.RESOLVE
	if hurt_hero == index and fx_time > 0:
		frame = 5
		base.x -= sin(fx_time * 31.0) * 4
	var tint := Color.WHITE if alive else Color(0.35, 0.4, 0.5, 0.7)
	if hurt_hero == index and fx_time > 0.5:
		tint = Color(1.5, 0.65, 0.65)
	var sprite_rect := Rect2(base - Vector2(96, 192) * ACTOR_SCALE, Vector2(192, 200) * ACTOR_SCALE)
	var focusing := action_index == index and action_kind == "focus" and phase == Phase.RESOLVE
	if phase in [Phase.TIMER, Phase.ASSASSIN] and index == hero_index:
		pass # The cast draws its airborne actor, but status stays in place.
	elif alive and focusing:
		_draw_focus(index, base, tint)
	elif alive and (winding or attacking):
		_draw_action(index, base, winding, tint)
	elif alive and frame == 0:
		var rect := Rect2(base - FOOT_ANCHOR * ACTOR_SCALE, ANIMATION_CELL * ACTOR_SCALE)
		if special_actor == index:
			_frame(expressive_textures[index], special_frame(), 4, 4, rect, tint)
		else:
			var pose := idle_frame(index, clock + index * 0.4)
			if index == 0:
				_frame(calm_idle_texture, pose, 3, 2, rect, tint)
			else:
				_frame(motion_textures[index], pose, 4, 4, rect, tint)
	else:
		_frame(textures[index], frame, 4, 2, sprite_rect, tint)
	if not alive:
		_label("전투 불능", base + Vector2(-31, -12), MUTED, 13)
	elif bool(hero.guarding):
		_label("방어", base + Vector2(37, -25), BLUE, 13)
	_hp(hero, HERO_POS[index] + Vector2(-51, 20), GREEN)
	_label("공격 %d  수비 %d  집중 %d" % [hero.attack_stacks, hero.defense_stacks, hero.focus_stacks], HERO_POS[index] + Vector2(-62, 57), BLUE, 11)

func _draw_focus(index: int, base: Vector2, tint: Color) -> void:
	var rect := Rect2(base - Vector2(77, 150), Vector2(154, 154))
	var pose := mini(int(focus_elapsed / FOCUS_DURATION * 4), 3)
	_frame(focus_texture, index * 4 + pose, 4, 2, rect, tint)
	# Small blue motes rise toward the character as they gather energy.
	for i in 7:
		var t := fposmod(clock * 0.8 + i / 7.0, 1.0)
		var x := base.x + sin(clock * 5.0 + i * 2.1) * (12.0 + i * 2.0)
		var y := base.y - 24.0 - t * 108.0
		draw_circle(Vector2(x, y), 2.0 + (i % 2), Color(0.38, 0.82, 1.0, 1.0 - t * 0.55))

func _draw_action(index: int, base: Vector2, winding: bool, tint: Color) -> void:
	var rect := Rect2(base - FOOT_ANCHOR * ACTOR_SCALE, ANIMATION_CELL * ACTOR_SCALE)
	if winding:
		if index == 1:
			_draw_fixed_windup(base, qte_elapsed, tint)
		else:
			_frame(motion_textures[index], WINDUP_FRAMES[int(qte_elapsed * 5.0) % WINDUP_FRAMES.size()], 4, 4, rect, tint)
	else:
		var elapsed := clampf(0.8 - fx_time, 0, 0.8)
		_draw_chain_extension(chain_points(index, elapsed), tint)
		_frame(expressive_textures[index], attack_frame(elapsed), 4, 4, rect, tint)

func _draw_fixed_windup(base: Vector2, time: float, tint: Color) -> void:
	# One unchanging body texture guarantees identical head, hair and planted feet.
	# The cuff pivot moves only the wrist and its integrated three-link chain stub.
	var phase_angle := fposmod(time, YEONWOO_SPIN_CYCLE) / YEONWOO_SPIN_CYCLE * TAU
	var wrist_angle := sin(phase_angle) * 0.12
	var pivot := Vector2(windup_rig.pivot[0], windup_rig.pivot[1])
	var tip := Vector2(windup_rig.tip[0], windup_rig.tip[1])
	var start := base + (pivot + (tip - pivot).rotated(wrist_angle)) * ACTOR_SCALE
	# A vertical lasso behind the body. Links travel around a stable loop instead
	# of changing the whole silhouette between unrelated generated poses.
	var center := base + Vector2(-64, -112) * ACTOR_SCALE
	var radius := Vector2(25, 45) * ACTOR_SCALE
	var loop := PackedVector2Array()
	for i in 65:
		var angle := phase_angle + i * TAU / 64.0
		loop.append(center + Vector2(cos(angle), sin(angle)) * radius)
	var tail := PackedVector2Array()
	var end: Vector2 = loop[0]
	for i in 25:
		var t := i / 24.0
		tail.append(start.bezier_interpolate(start + Vector2(-12, 8), end + Vector2(12, 0), end, t))
	_draw_chain_extension(tail, tint, true)
	_draw_chain_extension(loop, tint, true)
	var rect := Rect2(base - FOOT_ANCHOR * ACTOR_SCALE, ANIMATION_CELL * ACTOR_SCALE)
	draw_texture_rect(fixed_windup_body, rect, false, tint)
	var corners := PackedVector2Array()
	for corner in [Vector2.ZERO, Vector2(ANIMATION_CELL.x, 0), ANIMATION_CELL, Vector2(0, ANIMATION_CELL.y)]:
		corners.append(base + (pivot + (corner - FOOT_ANCHOR - pivot).rotated(wrist_angle)) * ACTOR_SCALE)
	var uv := PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)])
	draw_polygon(corners, PackedColorArray([tint,tint,tint,tint]), uv, fixed_windup_wrist)

func _draw_chain_extension(points: PackedVector2Array, tint: Color, short_links: bool = false) -> void:
	if points.size() < 2:
		return
	# Repeat the sampled steel links along the curve, keeping their native width.
	# Explicit quad vertices avoid resetting the composition's critical-hit transform.
	var distance := 0.0
	var next_link := 0.0
	# Short one-link samples follow tight lasso curves without polygonal corners.
	var tile_size := Vector2(13 if short_links else 26, 10) * ACTOR_SCALE
	var spacing := (10.0 if short_links else 22.0) * ACTOR_SCALE
	var u := 0.5 if short_links else 1.0
	var uv := PackedVector2Array([Vector2(0,0),Vector2(u,0),Vector2(u,1),Vector2(0,1)])
	for i in range(1, points.size()):
		var segment := points[i] - points[i-1]
		var length := segment.length()
		if length < 0.001:
			continue
		var along := segment / length
		var across := Vector2(-along.y, along.x) * tile_size.y * 0.5
		while next_link <= distance + length:
			var center := points[i-1] + along * (next_link - distance)
			var half := along * tile_size.x * 0.5
			var quad := PackedVector2Array([center-half-across, center+half-across, center+half+across, center-half+across])
			draw_polygon(quad, PackedColorArray([tint,tint,tint,tint]), uv, chain_texture)
			next_link += spacing
		distance += length

func _draw_enemy(index: int) -> void:
	var enemy: Dictionary = enemies[index]
	var base: Vector2 = FOE_POS[index]
	var alive := int(enemy.hp) > 0
	# No idle animation: frames only change on an actual attack or hit.
	var frame := 0
	if action_kind in ["enemy_attack", "enemy_windup"] and action_index == index and phase in [Phase.ENEMY, Phase.RESOLVE, Phase.GUARD_QTE]:
		frame = 1
		if action_kind == "enemy_attack" and fx_time > 0:
			base.x -= sin((0.8 - fx_time) * PI / 0.8) * 25
	var lightning_hit: bool = phase == Phase.TIMER and timer_cast.stage == TimerSkill.Stage.LIGHTNING
	var assassin_hit: bool = phase == Phase.ASSASSIN and assassin_cast.stage == AssassinSkill.Stage.SLASHES and index in assassin_cast.marked
	var taking_hit: bool = lightning_hit or assassin_hit or (hurt_enemy == index and fx_time > 0 and (action_kind != "attack" or fx_time <= 0.60))
	if taking_hit:
		frame = 2
		base.x += sin(fx_time * 29.0) * 5
	if alive or lightning_hit or assassin_hit or fx_time > 0 and hurt_enemy == index:
		var tint := Color.WHITE
		if taking_hit and fx_time > 0.5:
			tint = Color(1.8, 1.5, 1.5)
		var tex: Texture2D = armored_texture if armored_encounter else monster_texture
		var dimensions := Vector2(230, 214) if armored_encounter else Vector2(192, 176)
		_frame(tex, frame, 3, 1, Rect2(base - Vector2(dimensions.x * 0.5, dimensions.y - 8) * ACTOR_SCALE, dimensions * ACTOR_SCALE), tint)
	else:
		_label("격파", base + Vector2(-17, -40), MUTED, 16)
	if phase == Phase.TARGET and target_index == index:
		draw_arc(base + Vector2(0, -75) * ACTOR_SCALE, 79 * ACTOR_SCALE, 0, TAU, 32, ORANGE, 2)
		_label("타이머 대상" if target_action == "timer" else "공격 대상", base + Vector2(-32, -163) * ACTOR_SCALE, ORANGE, 14)
	_hp(enemy, FOE_POS[index] + Vector2(-51, 20), Color("f17d89"))

func _hp(unit: Dictionary, at: Vector2, color: Color) -> void:
	_label(str(unit.name), at + Vector2(0, -4), PAPER, 14)
	draw_rect(Rect2(at + Vector2(0, 4), Vector2(102, 7)), Color("080e19"))
	draw_rect(Rect2(at + Vector2(0, 4), Vector2(102 * float(unit.hp) / float(unit.max_hp), 7)), color)
	_label("%d / %d" % [unit.hp, unit.max_hp], at + Vector2(0, 27), MUTED, 12)

func _draw_commands() -> void:
	_panel(Rect2(24, 506, 367, 129))
	_panel(Rect2(398, 506, 346, 129))
	var hero: Dictionary = party[hero_index]
	# A crop of the same pixel character keeps the portrait identity consistent.
	var tex: Texture2D = textures[hero_index]
	if tex != null:
		draw_texture_rect_region(tex, Rect2(35, 526, 76, 96), Rect2(44, 16, 88, 104))
	_label(str(hero.name), Vector2(122, 541), ORANGE, 21)
	_label("HP  %d / %d" % [hero.hp, hero.max_hp], Vector2(122, 570), GREEN, 17)
	_label("공격 %d  수비 %d  집중 %d" % [hero.attack_stacks, hero.defense_stacks, hero.focus_stacks], Vector2(122, 594), BLUE, 12)
	draw_multiline_string(font, Vector2(122, 616), message, HORIZONTAL_ALIGNMENT_LEFT, 252, 11, 2, MUTED)
	_label("행동 선택" if phase == Phase.COMMAND else ("특수 스킬" if phase == Phase.SKILLS else "대상 선택"), Vector2(414, 528), MUTED, 13)
	if phase in [Phase.SKILLS, Phase.TARGET]:
		_panel(Rect2(635, 510, 98, 26), Color("243348"), ORANGE if phase == Phase.SKILLS and skill_index == skills().size() else MUTED)
		_label("← 뒤로가기", Vector2(644, 528), PAPER, 12)
	if phase == Phase.SKILLS:
		var list := skills()
		var start := _skill_page_start()
		if list.is_empty():
			_label("등록된 스킬이 없습니다", Vector2(422, 572), MUTED, 15)
		for i in range(start, mini(start + 2, list.size())):
			var skill: Dictionary = list[i]
			var rect := _skill_rect(i - start)
			var chosen := skill_index == i
			_panel(rect, Color("334053") if chosen else Color("172438"), ORANGE if chosen else Color("344961"))
			_label(str(skill.name), rect.position + Vector2(10, 17), ORANGE if chosen else PAPER, 15)
			var cost: Dictionary = skill.cost
			_label("공격 %d / 수비 %d / 집중 %d" % [cost.get("attack", 0), cost.get("defense", 0), cost.get("focus", 0)], rect.position + Vector2(10, 33), BLUE if can_use_skill(skill) else MUTED, 11)
		if list.size() > 2:
			_label("↑↓ 목록 %d/%d" % [int(start / 2) + 1, ceili(list.size() / 2.0)], Vector2(493, 528), MUTED, 11)
		return
	var commands := ["공격", "수비", "집중", "특수"]
	for i in 4:
		var rect := _command_rect(i)
		var chosen := command_index == i and phase == Phase.COMMAND
		if chosen:
			_panel(rect, Color("334053"), ORANGE)
		var enabled := true
		_label(commands[i], rect.position + Vector2(14, 24), (ORANGE if chosen else PAPER) if enabled else Color("69778b"), 16 if enabled else 13)

func _draw_qte() -> void:
	_panel(Rect2(24, 506, 720, 129))
	_label(message, Vector2(48, 535), BLUE, 18)
	var bar := Rect2(52, 562, 664, 36)
	draw_rect(bar, Color("080e19"))
	var half := float(balance.qte.perfect_half_width) * bar.size.x
	draw_rect(Rect2(384 - half, 558, half * 2, 44), Color("284a62"))
	draw_rect(Rect2(384 - half, 558, half * 2, 44), BLUE, false, 1)
	var cursor := Rules.cursor_at(qte_elapsed, float(balance.qte.duration), int(balance.qte.round_trips))
	draw_rect(Rect2(bar.position.x + cursor * bar.size.x - 2, 553, 4, 54), BLUE)
	_label("SPACE", Vector2(354, 587), PAPER, 17)
	_label("중앙: " + ("치명타 ×2" if phase == Phase.ATTACK_QTE else "피해 반사") + "    그 외: " + ("공격 ×1" if phase == Phase.ATTACK_QTE else "피해 절반"), Vector2(49, 622), MUTED, 13)
	_label("%.1f초" % maxf(0, float(balance.qte.duration) - qte_elapsed), Vector2(657, 535), MUTED, 14)

func _draw_effects() -> void:
	if fx_time <= 0:
		return
	if action_kind == "attack" and fx_time > 0.60:
		return
	if impact and fx_time > 0.35:
		var center := impact_position
		for ray in 8:
			var direction := Vector2.from_angle(ray * TAU / 8.0)
			draw_line(center + direction * 12, center + direction * (32 + (0.8 - fx_time) * 50), ORANGE, 3)
	_label(float_text, float_position + Vector2(-12, -(0.8 - fx_time) * 25), ORANGE, 30)
