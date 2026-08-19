extends Node

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy/enemy.tscn")
const ARENA_SCENE: PackedScene = preload("res://scenes/arena/arena.tscn")

var failures: Array[String] = []
var next_entity_id := 1


func _ready() -> void:
	_test_arclight_chains()
	_test_bulwark_slam_and_mitigation()
	_test_warden_aura()
	_test_frostbinder_slow()
	_test_taunt_priority()
	_test_class_replication()
	_test_enemy_types()
	_test_stalker_ignores_taunt()
	_test_hexer_heals_allies()
	_test_spitter_projectiles()
	_test_damage_counters()
	_test_flying_and_exploding()
	_test_splitter_and_summoner()
	_test_charger()
	_test_separation()
	_test_wave_archetypes()
	_test_classic_mode()
	_test_wave_escalation()
	_test_sprite_art()
	_test_wave_themes_and_debuts()
	_test_wave_modifiers()
	_test_gold_rewards()
	_test_arena_field()
	_test_shop()
	_test_shop_schedule()
	_test_shop_items_are_not_level_up_stats()
	_test_item_effects()
	_test_ability_data_integrity()
	_test_ability_rank_scaling()
	_test_ability_learn_and_upgrade()
	_test_ability_offer_alternation()
	_test_ability_archetypes_smoke()
	_test_ability_aoe_and_cooldown()

	if failures.is_empty():
		print("Class smoke test passed.")
		get_tree().quit(0)
		return
	for failure in failures:
		printerr("FAIL: %s" % failure)
	get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _make_player(class_id: String, position: Vector2 = Vector2.ZERO) -> Player:
	var player := PLAYER_SCENE.instantiate() as Player
	player.global_position = position
	add_child(player)
	player.configure(1, Player.SimulationMode.OFFLINE, false, class_id)
	return player


func _make_enemy(position: Vector2, type_id: String = EnemyType.DEFAULT_TYPE_ID, health_multiplier: float = 1.0, speed_multiplier: float = 1.0) -> Enemy:
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.global_position = position
	add_child(enemy)
	enemy.configure(next_entity_id, true, type_id, health_multiplier, speed_multiplier)
	next_entity_id += 1
	return enemy


func _aim(player: Player, target: Node2D) -> void:
	player.facing_direction = player.global_position.direction_to(target.global_position)


func _test_arclight_chains() -> void:
	var player := _make_player("arclight")
	var primary := _make_enemy(Vector2(120.0, 0.0))
	var neighbour := _make_enemy(Vector2(200.0, 0.0))
	_aim(player, primary)
	player._perform_attack()
	_check(primary.health.current_health < primary.health.max_health, "Arclight did not damage its primary target")
	_check(neighbour.health.current_health < neighbour.health.max_health, "Arclight chain did not reach the second enemy")
	_cleanup([player, primary, neighbour])


func _test_bulwark_slam_and_mitigation() -> void:
	var player := _make_player("bulwark")
	_check(is_equal_approx(player.health.max_health, 220.0), "Bulwark should have 220 max health")

	var front := _make_enemy(Vector2(90.0, 0.0))
	var behind := _make_enemy(Vector2(-90.0, 0.0))
	_aim(player, front)
	player._perform_attack()
	_check(front.health.current_health < front.health.max_health, "Bulwark slam missed the enemy in front")
	_check(is_equal_approx(behind.health.current_health, behind.health.max_health), "Bulwark slam should not hit enemies behind it")

	player.health.take_damage(100.0)
	_check(is_equal_approx(player.health.current_health, 150.0), "Bulwark should take 70 damage from a 100 damage hit, got %f" % (220.0 - player.health.current_health))
	_cleanup([player, front, behind])


func _test_warden_aura() -> void:
	var warden := _make_player("warden")
	var ally := _make_player("arclight", Vector2(80.0, 0.0))
	ally.health.take_damage(40.0)
	var wounded_health := ally.health.current_health

	warden._apply_support_aura(1.0)
	_check(ally.health.current_health > wounded_health, "Warden aura did not heal a nearby ally")
	_check(ally.damage_dealt_multiplier > 1.0, "Warden aura did not buff ally damage")

	var far_ally := _make_player("arclight", Vector2(900.0, 0.0))
	far_ally.health.take_damage(40.0)
	var far_health := far_ally.health.current_health
	warden._apply_support_aura(1.0)
	_check(is_equal_approx(far_ally.health.current_health, far_health), "Warden aura reached outside its radius")
	_cleanup([warden, ally, far_ally])


func _test_frostbinder_slow() -> void:
	var player := _make_player("frostbinder")
	var target := _make_enemy(Vector2(200.0, 0.0))
	_aim(player, target)
	player._perform_attack()
	_check(target.health.current_health < target.health.max_health, "Frostbinder burst did no damage")
	_check(target.is_slowed(), "Frostbinder burst did not slow the enemy")
	_check(target.slow_factor < 1.0, "Frostbinder slow factor was not applied")
	_cleanup([player, target])


func _test_taunt_priority() -> void:
	var tank := _make_player("bulwark", Vector2(-100.0, 0.0))
	var glass_cannon := _make_player("arclight", Vector2(90.0, 0.0))
	var enemy := _make_enemy(Vector2.ZERO)
	var chosen := enemy._find_nearest_player()
	_check(chosen == tank, "Enemy should prefer the tank over a slightly closer damage dealer")
	_cleanup([tank, glass_cannon, enemy])


func _test_class_replication() -> void:
	var proxy := _make_player("arclight")
	proxy.apply_network_state({"class_id": "frostbinder", "position": Vector2.ZERO})
	_check(proxy.class_id == "frostbinder", "Player did not adopt the replicated class id")
	_check(is_equal_approx(proxy.health.max_health, 130.0), "Replicated class did not apply its stats")

	var snapshot := proxy.snapshot()
	_check(snapshot.has("class_id"), "Snapshot must include the class id")
	_check(PlayerClass.sanitize_id("not_a_class") == PlayerClass.DEFAULT_CLASS_ID, "Invalid class ids must fall back to the default")
	_cleanup([proxy])


func _test_enemy_types() -> void:
	_check(EnemyType.TYPES.size() >= 6, "Expected at least six enemy types")
	_check(EnemyType.sanitize_id("nonsense") == EnemyType.DEFAULT_TYPE_ID, "Invalid enemy type must fall back to the default")

	for type_data in EnemyType.TYPES:
		var enemy := _make_enemy(Vector2.ZERO, str(type_data.id))
		_check(enemy.type_id == type_data.id, "Enemy did not adopt type %s" % type_data.id)
		_check(is_equal_approx(enemy.health.max_health, float(type_data.max_health)), "Type %s has wrong max health" % type_data.id)
		_check(is_equal_approx(enemy.body_radius, float(type_data.radius)), "Type %s has wrong body radius" % type_data.id)
		var shape := enemy.collision_shape.shape as CircleShape2D
		_check(shape != null and is_equal_approx(shape.radius, float(type_data.radius)), "Type %s did not resize its collision shape" % type_data.id)
		_check(enemy.snapshot().has("type_id"), "Enemy snapshot must replicate its type")
		_cleanup([enemy])

	var grunt := _make_enemy(Vector2.ZERO, "grunt")
	_check(is_equal_approx(grunt.body_radius, 17.0), "Grunt should be back at the original radius of 17")
	_cleanup([grunt])

	var base_grunt_health := float(EnemyType.field("grunt", "max_health"))
	var scaled := _make_enemy(Vector2.ZERO, "grunt", 2.0)
	_check(is_equal_approx(scaled.health.max_health, base_grunt_health * 2.0), "Wave health scaling was not applied")
	_cleanup([scaled])

	var shared_a := _make_enemy(Vector2.ZERO, "swarmling")
	var shared_b := _make_enemy(Vector2.ZERO, "brute")
	var shape_a := shared_a.collision_shape.shape as CircleShape2D
	var shape_b := shared_b.collision_shape.shape as CircleShape2D
	_check(shape_a != shape_b and not is_equal_approx(shape_a.radius, shape_b.radius), "Enemies must not share one collision shape resource")
	_cleanup([shared_a, shared_b])


func _test_stalker_ignores_taunt() -> void:
	var tank := _make_player("bulwark", Vector2(-100.0, 0.0))
	var squishy := _make_player("arclight", Vector2(90.0, 0.0))
	var grunt := _make_enemy(Vector2.ZERO, "grunt")
	var stalker := _make_enemy(Vector2.ZERO, "stalker")
	_check(grunt._find_nearest_player() == tank, "Grunt should respect the taunt weight")
	_check(stalker._find_nearest_player() == squishy, "Stalker should ignore taunt and pick the closest player")
	_cleanup([tank, squishy, grunt, stalker])


func _test_hexer_heals_allies() -> void:
	var hexer := _make_enemy(Vector2.ZERO, "hexer")
	var wounded := _make_enemy(Vector2(120.0, 0.0), "grunt")
	var far := _make_enemy(Vector2(900.0, 0.0), "grunt")
	wounded.health.take_damage(15.0)
	far.health.take_damage(15.0)
	var wounded_before := wounded.health.current_health
	var far_before := far.health.current_health

	hexer._apply_healing_aura(1.0)
	_check(wounded.health.current_health > wounded_before, "Hexer did not heal a nearby enemy")
	_check(is_equal_approx(far.health.current_health, far_before), "Hexer healed outside its aura radius")
	_cleanup([hexer, wounded, far])


func _test_spitter_projectiles() -> void:
	var victim := _make_player("arclight", Vector2(300.0, 0.0))
	var spitter := _make_enemy(Vector2.ZERO, "spitter")
	_check(spitter.behaviour == EnemyType.Behaviour.RANGED, "Spitter should use ranged behaviour")
	_check(is_equal_approx(spitter.contact_damage, 0.0), "Spitter should not deal contact damage")

	var shots: Array[Dictionary] = []
	spitter.projectile_fired.connect(
		func(origin: Vector2, direction: Vector2, damage: float, speed: float, sprite_name: String) -> void:
			shots.append({"origin": origin, "direction": direction, "damage": damage, "speed": speed, "sprite": sprite_name})
	)
	spitter.target = victim
	spitter._fire_projectile()
	_check(shots.size() == 1, "Spitter did not emit a projectile event")
	if not shots.is_empty():
		_check(shots[0].damage > 0.0, "Spitter projectile carries no damage")
		_check(shots[0].direction.dot(Vector2.RIGHT) > 0.9, "Spitter did not aim at its target")
		_check(SpriteLibrary.texture_for(str(shots[0].sprite)) != null, "Projectile sprite %s is missing" % shots[0].sprite)

	spitter._fire_projectile()
	_check(shots.size() == 1, "Spitter ignored its attack cooldown")

	var projectile := preload("res://scenes/projectile/projectile.tscn").instantiate() as SurvivorProjectile
	add_child(projectile)
	projectile.configure(Vector2.RIGHT, 8.0, 400.0, true, false)
	_check(projectile.target_group == "players", "Hostile projectile must target players")
	_check(projectile.collision_mask == (SurvivorProjectile.WORLD_LAYER | SurvivorProjectile.PLAYER_LAYER), "Hostile projectile has the wrong collision mask")

	var health_before := victim.health.current_health
	projectile._on_body_entered(victim)
	_check(victim.health.current_health < health_before, "Hostile projectile did not damage the player")

	var cosmetic := preload("res://scenes/projectile/projectile.tscn").instantiate() as SurvivorProjectile
	add_child(cosmetic)
	cosmetic.configure(Vector2.RIGHT, 8.0, 400.0, true, true)
	var health_after_hit := victim.health.current_health
	cosmetic._on_body_entered(victim)
	_check(is_equal_approx(victim.health.current_health, health_after_hit), "Cosmetic client projectile must never deal damage")

	_cleanup([victim, spitter, projectile, cosmetic])


## Keep the test hit small so no enemy dies mid-measurement and clips the result.
const COUNTER_TEST_HIT := 5.0


func _damage_dealt(class_id: String, enemy_type_id: String) -> float:
	var attacker := _make_player(class_id)
	var victim := _make_enemy(Vector2(70.0, 0.0), enemy_type_id)
	var before := victim.health.current_health
	attacker._damage_enemy(victim, COUNTER_TEST_HIT)
	var dealt := before - victim.health.current_health
	_check(victim.health.current_health > 0.0, "Counter test killed a %s, so the measurement is clipped" % enemy_type_id)
	_cleanup([attacker, victim])
	return dealt


func _test_damage_counters() -> void:
	var lightning_vs_swarm := _damage_dealt("arclight", "swarmling")
	var lightning_vs_armour := _damage_dealt("arclight", "sentinel")
	_check(lightning_vs_swarm > COUNTER_TEST_HIT, "Lightning should shred swarms")
	_check(lightning_vs_armour < COUNTER_TEST_HIT, "Armour should shrug off lightning")

	var impact_vs_armour := _damage_dealt("bulwark", "sentinel")
	var impact_vs_flier := _damage_dealt("bulwark", "drifter")
	_check(impact_vs_armour > lightning_vs_armour, "Impact must beat lightning against armour")
	_check(impact_vs_flier < COUNTER_TEST_HIT, "A ground slam should barely touch fliers")

	var frost_vs_stalker := _damage_dealt("frostbinder", "stalker")
	var impact_vs_stalker := _damage_dealt("bulwark", "stalker")
	_check(frost_vs_stalker > impact_vs_stalker, "Frost must be the answer to stalkers")

	var nature_vs_hexer := _damage_dealt("warden", "hexer")
	var lightning_vs_hexer := _damage_dealt("arclight", "hexer")
	_check(nature_vs_hexer > lightning_vs_hexer, "Nature must be the answer to enemy support")

	var grunt_damage: Array[float] = []
	for class_id in PlayerClass.ids():
		grunt_damage.append(_damage_dealt(class_id, "grunt"))
	for dealt in grunt_damage:
		_check(is_equal_approx(dealt, COUNTER_TEST_HIT), "The plain grunt should have no resistances at all")


func _test_flying_and_exploding() -> void:
	var flier := _make_enemy(Vector2.ZERO, "drifter")
	_check(flier.flying, "Drifter must fly")
	_check(flier.collision_mask == 0, "Fliers must ignore world and ground collisions")
	var walker := _make_enemy(Vector2.ZERO, "grunt")
	_check(not walker.flying and walker.collision_mask == 7, "Ground enemies must keep colliding")
	_cleanup([flier, walker])

	var victim := _make_player("arclight", Vector2(40.0, 0.0))
	var bomber := _make_enemy(Vector2.ZERO, "bomber")
	_check(bomber.flying and bomber.explode_damage > 0.0, "Bomber must be a flying exploder")

	var blasts: Array[Dictionary] = []
	bomber.exploded.connect(
		func(origin: Vector2, radius: float, damage: float) -> void:
			blasts.append({"origin": origin, "radius": radius, "damage": damage})
	)
	var health_before := victim.health.current_health
	bomber._explode()
	_check(blasts.size() == 1, "Bomber did not report its explosion")
	_check(victim.health.current_health < health_before, "Bomber explosion missed a player inside its radius")
	_check(bomber.health.is_dead, "Bomber must die when it explodes")

	var survivor := _make_player("arclight", Vector2(600.0, 0.0))
	var bomber_two := _make_enemy(Vector2.ZERO, "bomber")
	var survivor_health := survivor.health.current_health
	bomber_two._explode()
	_check(is_equal_approx(survivor.health.current_health, survivor_health), "Explosion reached outside its radius")
	_cleanup([victim, bomber, survivor, bomber_two])


func _test_splitter_and_summoner() -> void:
	var splitter := _make_enemy(Vector2.ZERO, "splitter")
	var requests: Array[Dictionary] = []
	splitter.spawn_requested.connect(
		func(type_id: String, origin: Vector2, count: int) -> void:
			requests.append({"type_id": type_id, "count": count})
	)
	splitter.health.take_damage(999.0)
	_check(requests.size() == 1, "Splitter did not ask for children on death")
	if not requests.is_empty():
		_check(str(requests[0].type_id) == "swarmling", "Splitter should break into swarmlings")
		_check(int(requests[0].count) == 3, "Splitter should spawn three children")
	_cleanup([splitter])

	var victim := _make_player("arclight", Vector2(400.0, 0.0))
	var summoner := _make_enemy(Vector2.ZERO, "summoner")
	var summons: Array[Dictionary] = []
	summoner.spawn_requested.connect(
		func(type_id: String, origin: Vector2, count: int) -> void:
			summons.append({"type_id": type_id, "count": count})
	)
	summoner.target = victim
	summoner._update_summoning(0.1)
	_check(summons.is_empty(), "Summoner should wait for its interval")
	summoner._update_summoning(summoner.summon_interval)
	_check(summons.size() == 1, "Summoner never summoned")
	_cleanup([victim, summoner])


func _test_charger() -> void:
	var victim := _make_player("arclight", Vector2(250.0, 0.0))
	var charger := _make_enemy(Vector2.ZERO, "charger")
	charger.target = victim
	_check(charger.behaviour == EnemyType.Behaviour.CHARGER, "Charger must use charger behaviour")

	charger._process_charger(0.016)
	_check(charger.winding_up, "Charger should telegraph before dashing")
	_check(charger.velocity == Vector2.ZERO, "Charger must stand still while winding up")

	charger._process_charger(charger.charge_windup)
	_check(charger.charging and not charger.winding_up, "Charger should dash after its windup")
	_check(charger.charge_direction.dot(Vector2.RIGHT) > 0.9, "Charger must dash toward its target")
	_cleanup([victim, charger])


func _test_separation() -> void:
	var crowded := _make_enemy(Vector2.ZERO, "grunt")
	var neighbour_one := _make_enemy(Vector2(20.0, 0.0), "grunt")
	var neighbour_two := _make_enemy(Vector2(0.0, 20.0), "grunt")
	var push := crowded._separation_offset()
	_check(push.length() > 0.0, "Crowded enemies must push each other apart")
	_check(push.x < 0.0 and push.y < 0.0, "Separation must point away from neighbours, got %s" % str(push))
	_cleanup([neighbour_one, neighbour_two])

	var lonely_push := crowded._separation_offset()
	_check(lonely_push == Vector2.ZERO, "A lone enemy must not be pushed anywhere")
	_cleanup([crowded])


func _test_wave_archetypes() -> void:
	var director := WaveDirector.new()
	add_child(director)
	director.set_player_count(1)

	_check(director.theme_for_wave(10).archetype == WaveDirector.Archetype.BOSS, "Wave 10 must be a boss wave")
	_check(director.theme_for_wave(20).archetype == WaveDirector.Archetype.BOSS, "Wave 20 must be a boss wave")
	_check(director.theme_for_wave(30).archetype == WaveDirector.Archetype.BOSS, "Improvised tenth waves must stay boss waves")
	_check(director.theme_for_wave(25).archetype == WaveDirector.Archetype.ELITE, "Improvised fifth waves must be elite waves")
	_check(director.theme_for_wave(1).archetype == WaveDirector.Archetype.STANDARD, "The first wave must stay standard")

	var boss_groups := director.plan_wave(10, WaveDirector.Archetype.BOSS)
	var boss_count := 0
	for group in boss_groups:
		if EnemyType.is_boss(str(group.type_id)):
			boss_count += 1
	_check(boss_count == 1, "A boss wave must contain exactly one boss, got %d" % boss_count)
	_check(EnemyType.boss_for_wave(10) == "ravager", "Wave 10 should send the Ravager")
	_check(EnemyType.boss_for_wave(20) == "stormcaller", "Wave 20 should send the Stormcaller")

	var air_groups := director.plan_wave(9, WaveDirector.Archetype.AIR_ASSAULT)
	_check(not air_groups.is_empty(), "An air assault must send something")
	for group in air_groups:
		_check(bool(EnemyType.field(str(group.type_id), "flying")), "An air assault must only send fliers, found %s" % group.type_id)

	var sniper_groups := director.plan_wave(9, WaveDirector.Archetype.SNIPERS)
	for group in sniper_groups:
		_check(str(group.type_id) in ["spitter", "summoner", "stalker"], "A sniper wave sent an unexpected %s" % group.type_id)

	var ambush_groups := director.plan_wave(9, WaveDirector.Archetype.AMBUSH)
	for group in ambush_groups:
		_check(int(group.formation) == EnemyType.Formation.RING, "An ambush must surround the party")

	# Fliers only unlock later, so an early air wave has to fall back safely.
	var early_air := director.plan_wave(2, WaveDirector.Archetype.AIR_ASSAULT)
	_check(not early_air.is_empty(), "An archetype without unlocked types must fall back, not send nothing")

	var bosses_before_ten := 0
	for target_wave in range(1, 10):
		var theme := director.theme_for_wave(target_wave)
		for group in director.plan_wave(target_wave, theme.archetype, theme.modifier, theme.debut):
			if EnemyType.is_boss(str(group.type_id)):
				bosses_before_ten += 1
	_check(bosses_before_ten == 0, "No boss may appear before wave 10")

	director.free()


func _test_classic_mode() -> void:
	var director := WaveDirector.new()
	add_child(director)
	var groups: Array[Dictionary] = []
	director.group_ready.connect(
		func(type_id: String, _formation: int, count: int, health_multiplier: float, speed_multiplier: float) -> void:
			groups.append({"type_id": type_id, "count": count, "health_multiplier": health_multiplier, "speed_multiplier": speed_multiplier})
	)

	director.start(1, true)
	_check(director.classic_mode, "Classic mode flag was not set")
	_check(director.wave == 1, "Classic mode should stay on a single endless wave")

	for step in 100:
		director._process(0.1)

	_check(groups.size() > 3, "Classic mode must keep spawning on its timer")
	for group in groups:
		_check(str(group.type_id) == "grunt", "Classic mode must only ever spawn grunts, found %s" % group.type_id)
		_check(int(group.count) == 1, "Classic mode spawns one enemy at a time")
		_check(is_equal_approx(float(group.health_multiplier), 1.0), "Classic mode must not scale enemy health")
	_check(director.wave == 1, "Classic mode must never advance to wave 2")

	_check(GameRuntime.GameMode.CLASSIC != GameRuntime.GameMode.PJOTR, "The two game modes must be distinct")
	director.free()


func _test_wave_escalation() -> void:
	var director := WaveDirector.new()
	add_child(director)
	director.set_player_count(1)

	_check(director.budget_for_wave(5) > director.budget_for_wave(1), "Wave budget must grow over time")
	_check(director.health_multiplier_for_wave(1) == WaveDirector.BASE_HEALTH_MULTIPLIER, "Wave 1 should start at the doubled baseline health")
	_check(director.health_multiplier_for_wave(21) >= 2.0, "Late waves should meaningfully scale enemy health")

	director.set_player_count(4)
	var four_player_budget := director.budget_for_wave(3)
	director.set_player_count(1)
	_check(four_player_budget > director.budget_for_wave(3), "More players must raise the wave budget")

	var early_types := EnemyType.spawnable_for_wave(1)
	var late_types := EnemyType.spawnable_for_wave(30)
	_check(early_types.size() == 1, "Only the grunt should be available in wave 1")
	_check(late_types.size() > early_types.size(), "More enemy types must unlock over time")
	for type_data in late_types:
		_check(not EnemyType.is_boss(str(type_data.id)), "Bosses must never enter the normal spawn pool")

	var wave_one := director.plan_wave(1, WaveDirector.Archetype.STANDARD)
	_check(not wave_one.is_empty(), "Wave 1 must plan at least one group")
	for group in wave_one:
		_check(str(group.type_id) == "grunt", "Wave 1 should only contain grunts")

	var elite_wave := director.plan_wave(25, WaveDirector.Archetype.ELITE)
	var has_ring := false
	for group in elite_wave:
		if int(group.formation) == EnemyType.Formation.RING:
			has_ring = true
	_check(has_ring, "An elite wave should include a surrounding elite ring")

	var late_wave := director.plan_wave(12, WaveDirector.Archetype.STANDARD)
	var late_total := 0
	for group in late_wave:
		late_total += int(group.count)
	var early_total := 0
	for group in wave_one:
		early_total += int(group.count)
	_check(late_total > early_total, "Later waves must send more enemies, got %d vs %d" % [late_total, early_total])

	_test_wave_loop(director)
	director.free()


func _test_wave_loop(director: WaveDirector) -> void:
	var started_waves: Array[int] = []
	var spawned_groups: Array[Dictionary] = []
	director.wave_started.connect(func(wave: int, _name: String, _debut: String) -> void: started_waves.append(wave))
	director.group_ready.connect(
		func(type_id: String, formation: int, count: int, _health: float, _speed: float) -> void:
			spawned_groups.append({"type_id": type_id, "formation": formation, "count": count})
	)

	director.start(1)
	_check(started_waves == [1], "Starting the director must open wave 1")
	_check(spawned_groups.size() == 1, "Wave 1 should release its first group immediately")

	# Pretend the players clear everything instantly, then let the clock run. Step count is
	# generous on purpose: waves now queue noticeably more groups than they used to (higher
	# budget_for_wave, shorter GROUP_INTERVAL_SECONDS), so releasing a whole wave's groups
	# before the next intermission can start takes longer in simulated time than it did.
	director.report_enemy_count(0)
	for step in 900:
		director._process(0.1)
		director.report_enemy_count(0)

	_check(started_waves.size() >= 3, "The director should keep advancing waves, reached %d" % started_waves.size())
	_check(started_waves[0] == 1 and started_waves[1] == 2, "Waves must advance in order, got %s" % str(started_waves))
	_check(spawned_groups.size() > 1, "Later waves must release more groups")

	var seen_types: Dictionary = {}
	for group in spawned_groups:
		seen_types[group.type_id] = true
	_check(seen_types.has("grunt"), "Grunts should appear in the early waves")

	director.stop()
	var wave_before := director.wave
	director._process(10.0)
	_check(director.wave == wave_before, "A stopped director must not keep spawning waves")


func _test_sprite_art() -> void:
	var art_errors := SpriteArt.validation_errors()
	_check(art_errors.is_empty(), "Pixel art is malformed: %s" % ", ".join(art_errors))

	for class_id in PlayerClass.ids():
		_check(SpriteLibrary.texture_for(class_id) != null, "Hero %s has no sprite" % class_id)
	for type_data in EnemyType.TYPES:
		_check(SpriteLibrary.texture_for(str(type_data.id)) != null, "Enemy %s has no sprite" % type_data.id)
	for prop_name in ["spit", "bolt", "spark", "xp_orb", "coin"]:
		_check(SpriteLibrary.texture_for(prop_name) != null, "Prop %s has no sprite" % prop_name)

	for class_data in PlayerClass.CLASSES:
		for ability_id in class_data.ability_pool:
			_check(SpriteLibrary.texture_for(str(ability_id)) != null, "Ability %s has no icon" % ability_id)
			_check(SpriteLibrary.texture_for("%s_fx0" % ability_id) != null, "Ability %s has no cast animation" % ability_id)

	_check(SpriteLibrary.texture_for("arclight_static_bolt").get_width() == 16, "Ability icons must be 16×16")

	_check(SpriteLibrary.texture_for("does_not_exist") == null, "A missing sprite must resolve to null, not crash")

	var brute := _make_enemy(Vector2.ZERO, "brute")
	var swarmling := _make_enemy(Vector2(400.0, 0.0), "swarmling")
	_check(brute.has_sprite() and swarmling.has_sprite(), "Enemies should render their sprite")
	_check(brute.sprite.scale.x > swarmling.sprite.scale.x, "A brute must be drawn bigger than a swarmling")
	_cleanup([brute, swarmling])

	var hero := _make_player("arclight")
	_check(hero.has_sprite(), "The hero should render its sprite")
	_cleanup([hero])


func _test_wave_themes_and_debuts() -> void:
	var director := WaveDirector.new()
	add_child(director)
	director.set_player_count(1)

	var seen_debuts: Dictionary = {}
	for target_wave in range(1, WaveDirector.SCRIPTED_WAVES.size() + 1):
		var theme := director.theme_for_wave(target_wave)
		_check(not str(theme.name).is_empty(), "Wave %d has no theme name" % target_wave)
		var debut := str(theme.debut)
		if debut.is_empty():
			continue
		_check(EnemyType.is_valid_id(debut), "Wave %d debuts unknown enemy %s" % [target_wave, debut])
		_check(not seen_debuts.has(debut), "%s is introduced twice" % debut)
		seen_debuts[debut] = target_wave
		_check(
			int(EnemyType.field(debut, "unlock_wave")) <= target_wave,
			"%s debuts in wave %d before it is unlocked" % [debut, target_wave]
		)

	# Every enemy the player will meet should get a proper introduction.
	for type_data in EnemyType.TYPES:
		var type_id := str(type_data.id)
		if EnemyType.is_boss(type_id) or type_id == EnemyType.DEFAULT_TYPE_ID:
			continue
		_check(seen_debuts.has(type_id), "%s is never introduced in a debut wave" % type_id)

	var debut_wave := seen_debuts["drifter"] as int
	var debut_groups := director.plan_wave(debut_wave, WaveDirector.Archetype.STANDARD, WaveDirector.Modifier.NONE, "drifter")
	_check(str(debut_groups[0].type_id) == "drifter", "The debut group must arrive first")
	_check(int(debut_groups[0].count) == WaveDirector.DEBUT_COUNT, "A debut should stay small")
	var extra_drifters := 0
	for index in range(1, debut_groups.size()):
		if str(debut_groups[index].type_id) == "drifter":
			extra_drifters += 1
	_check(extra_drifters == 0, "A debut wave must not bury the new enemy in more of the same")

	# Wave 1 was front-loaded to be a real fight instead of easing players in, and the whole
	# curve was later doubled on top of that; the early game still has to stay bounded, just
	# at the new, much less forgiving baseline.
	_check(director.budget_for_wave(5) < 60.0, "The early game must stay bounded, got %.1f" % director.budget_for_wave(5))
	director.free()


func _test_wave_modifiers() -> void:
	var director := WaveDirector.new()
	add_child(director)
	director.set_player_count(1)

	var plain := director.plan_wave(8, WaveDirector.Archetype.STANDARD)
	var enraged := director.plan_wave(8, WaveDirector.Archetype.STANDARD, WaveDirector.Modifier.ENRAGED)
	var armored := director.plan_wave(8, WaveDirector.Archetype.STANDARD, WaveDirector.Modifier.ARMORED)
	var horde := director.plan_wave(8, WaveDirector.Archetype.STANDARD, WaveDirector.Modifier.FRAGILE_HORDE)

	_check(is_equal_approx(float(plain[0].speed_multiplier), 1.0), "A plain wave must not change speed")
	_check(float(enraged[0].speed_multiplier) > 1.0, "An enraged wave must run faster")
	_check(float(armored[0].health_multiplier) > float(plain[0].health_multiplier), "An armoured wave must be tougher")
	_check(float(horde[0].health_multiplier) < float(plain[0].health_multiplier), "A fragile horde must be squishier")

	var enraged_enemy := _make_enemy(Vector2.ZERO, "grunt", 1.0, 1.18)
	var plain_enemy := _make_enemy(Vector2(400.0, 0.0), "grunt")
	_check(enraged_enemy.movement_speed > plain_enemy.movement_speed, "The speed modifier never reached the enemy")
	_cleanup([enraged_enemy, plain_enemy])

	director.free()


func _test_gold_rewards() -> void:
	for type_data in EnemyType.TYPES:
		_check(int(type_data.gold_value) > 0, "%s drops no gold" % type_data.id)
	_check(
		int(EnemyType.field("brute", "gold_value")) > int(EnemyType.field("swarmling", "gold_value")),
		"Dangerous enemies must be worth more gold"
	)
	_check(
		int(EnemyType.field("ravager", "gold_value")) > int(EnemyType.field("brute", "gold_value")),
		"A boss must be the biggest payday"
	)

	var player := _make_player("arclight")
	_check(player.gold == 0, "A run starts without gold")
	player.add_gold(10)
	_check(player.gold == 10, "Gold was not credited")
	player.add_gold(-5)
	_check(player.gold == 10, "Negative gold must be ignored")

	player.gold_multiplier = 2.0
	player.gold = 0
	player.add_gold(100)
	_check(player.gold == 200, "The gold multiplier is not applied to income")
	_check(ShopCatalog.SHOP_PRICE_MULTIPLIER == 10, "Shop prices should be scaled up to match full gold income")
	_cleanup([player])


func _test_shop() -> void:
	var player := _make_player("arclight")

	_check(not player.buy("carapace"), "A broke player must not be able to buy anything")
	_check(is_equal_approx(player.thorns_ratio, 0.0), "A failed purchase must not apply its effect")

	player.gold = 4000
	var first_price := ShopCatalog.price_for("carapace", 0)
	_check(player.buy("carapace"), "A player with gold should be able to buy")
	_check(player.thorns_ratio > 0.0, "Spiked Carapace did not grant thorns")
	_check(player.gold == 4000 - first_price, "The purchase charged the wrong price")
	_check(player.stacks_of("carapace") == 1, "The purchase was not recorded")
	_check(ShopCatalog.price_for("carapace", 1) > first_price, "Prices must climb with every copy")

	_check(not player.buy("free_lunch"), "An unknown item must be refused")

	var sold_out_stacks := int(ShopCatalog.by_id("carapace").max_stacks)
	_check(ShopCatalog.is_sold_out("carapace", sold_out_stacks), "Items must eventually sell out")

	var proxy := _make_player("arclight")
	proxy.simulation_mode = Player.SimulationMode.PROXY
	proxy.gold = 1000
	_check(not proxy.buy("carapace"), "A client copy must never resolve its own purchase")

	var replicated := _make_player("arclight")
	replicated.simulation_mode = Player.SimulationMode.PROXY
	replicated.apply_network_state({"gold": 77, "shop_stacks": {"carapace": 2}})
	_check(replicated.gold == 77, "Gold must replicate to clients")
	_check(replicated.stacks_of("carapace") == 2, "Owned items must replicate so prices show correctly")

	_cleanup([player, proxy, replicated])


func _test_arena_field() -> void:
	var previous_mode := GameRuntime.game_mode
	GameRuntime.set_game_mode(GameRuntime.GameMode.PJOTR)
	var arena := ARENA_SCENE.instantiate()
	add_child(arena)

	_check(arena.obstacles.size() > 8, "The field should be littered with rocks, got %d" % arena.obstacles.size())
	for obstacle in arena.obstacles:
		_check(
			obstacle.global_position.length() >= arena.SPAWN_CLEARANCE,
			"A rock sits on top of the party spawn"
		)
		_check(arena._inside_playfield(obstacle.global_position), "A rock is stuck in the arena wall")
		for other in arena.obstacles:
			if other == obstacle:
				continue
			_check(
				obstacle.global_position.distance_to(other.global_position) >= arena.OBSTACLE_SPACING,
				"Two rocks are packed too tightly to walk between"
			)

	var rock: Obstacle = arena.obstacles[0]
	_check(arena.is_blocked(rock.global_position, 4.0), "is_blocked missed a rock it sits inside")
	_check(not arena.is_blocked(Vector2.ZERO, 4.0), "The spawn point must stay walkable")
	var freed: Vector2 = arena.free_position_near(rock.global_position, 22.0)
	_check(not arena.is_blocked(freed, 22.0), "free_position_near handed back a blocked spot")
	_check(rock.collision.shape is CircleShape2D, "Rocks need a collision shape to walk around")
	_check(rock.collision.shape != arena.obstacles[1].collision.shape, "Rocks must not share one collision shape")
	_check(rock.has_sprite(), "Rocks are missing their pixel art")

	# The layout is seeded, so every peer builds the same field without syncing it.
	var twin := ARENA_SCENE.instantiate()
	add_child(twin)
	_check(twin.obstacles.size() == arena.obstacles.size(), "The rock layout is not deterministic")
	for index in arena.obstacles.size():
		_check(
			arena.obstacles[index].global_position.is_equal_approx(twin.obstacles[index].global_position),
			"Rock %d landed somewhere else on a second build" % index
		)

	GameRuntime.set_game_mode(GameRuntime.GameMode.CLASSIC)
	var classic_arena := ARENA_SCENE.instantiate()
	add_child(classic_arena)
	_check(classic_arena.obstacles.is_empty(), "Classic mode must keep its clean grid arena")

	GameRuntime.set_game_mode(previous_mode)
	_cleanup([arena, twin, classic_arena])


func _test_shop_schedule() -> void:
	for next_wave in [2, 3, 5, 9, 10, 12, 20, 30]:
		_check(not WaveDirector.shop_opens_before(next_wave), "The shop must stay shut before wave %d" % next_wave)
	for next_wave in [11, 21, 31, 101]:
		_check(WaveDirector.shop_opens_before(next_wave), "The shop must open before wave %d" % next_wave)
	_check(not WaveDirector.shop_opens_before(1), "There is nothing to spend before the first wave")
	_check(
		WaveDirector.SHOP_INTERMISSION_SECONDS > WaveDirector.INTERMISSION_SECONDS,
		"A shopping break should be longer than a normal breather"
	)


## The shop must sell mechanics, never the plain stat lines the level-up pool sells.
func _test_shop_items_are_not_level_up_stats() -> void:
	var player := _make_player("arclight")
	var base_damage := player.weapon_damage
	var base_interval := player.attack_interval
	var base_speed := player.movement_speed
	var base_health := player.health.max_health
	var base_mitigation := player.health.damage_taken_multiplier

	for item_id in ShopCatalog.ids():
		_check(not PlayerClass.UPGRADES.has(item_id), "Shop item '%s' reuses a level-up id" % item_id)
		player.gold = 100000
		_check(player.buy(item_id), "Could not buy %s" % item_id)

	_check(is_equal_approx(player.weapon_damage, base_damage), "The shop must not sell raw weapon damage")
	_check(is_equal_approx(player.attack_interval, base_interval), "The shop must not sell raw attack speed")
	_check(is_equal_approx(player.movement_speed, base_speed), "The shop must not sell raw movement speed")
	_check(is_equal_approx(player.health.max_health, base_health), "The shop must not sell raw max health")
	_check(is_equal_approx(player.health.damage_taken_multiplier, base_mitigation), "The shop must not sell raw mitigation")

	_check(player.thorns_ratio > 0.0, "Spiked Carapace grants no reflect")
	_check(player.lifesteal_ratio > 0.0, "Bloodfang grants no lifesteal")
	_check(player.health_regen_per_second > 0.0, "Regrowth Pendant grants no regeneration")
	_check(player.resistance_pierce > 0.0, "Rending Prism pierces nothing")
	_check(player.ember_damage_per_second > 0.0, "Ember Aura burns nothing")
	_check(player.hit_slow_factor < 1.0, "Frostbite Charm slows nothing")
	_check(player.pickup_radius_bonus > 0.0, "Lodestone widens no pickup radius")
	_check(player.has_active_item(), "Phase Boots did not register as the active item")
	_cleanup([player])


func _test_item_effects() -> void:
	var player := _make_player("arclight")
	var enemy := _make_enemy(Vector2(40.0, 0.0), "grunt")

	player.gold = 100000
	player.buy("carapace")
	player.buy("bloodfang")
	player.health.take_damage(40.0)
	var healthy_enemy := enemy.health.current_health
	player.health.take_damage(40.0, enemy)
	_check(enemy.health.current_health < healthy_enemy, "Spiked Carapace did not reflect onto the attacker")

	var wounded := player.health.current_health
	player._damage_enemy(enemy, 20.0)
	_check(player.health.current_health > wounded, "Bloodfang did not heal on damage dealt")

	# Rending Prism should soften a resistance, never trim a weakness bonus.
	var plain := _damage_dealt("bulwark", "drifter")
	var pierced_player := _make_player("bulwark")
	pierced_player.gold = 100000
	pierced_player.buy("prism")
	var flier := _make_enemy(Vector2(40.0, 0.0), "drifter")
	var before := flier.health.current_health
	pierced_player._damage_enemy(flier, COUNTER_TEST_HIT)
	_check(before - flier.health.current_health > plain, "Rending Prism did not cut into the resistance")

	var aegis_player := _make_player("arclight")
	aegis_player.gold = 100000
	aegis_player.buy("aegis")
	aegis_player.health.take_damage(9999.0)
	_check(not aegis_player.health.is_dead, "Aegis Sigil failed to stop a lethal hit")
	_check(aegis_player.health.current_health > 0.0, "Aegis Sigil left the player at zero health")
	aegis_player.health.take_damage(9999.0)
	_check(aegis_player.health.is_dead, "Aegis Sigil must only save once per wave")
	aegis_player.health.is_dead = false
	aegis_player.health.current_health = aegis_player.health.max_health
	aegis_player.refresh_wave_items()
	aegis_player.health.take_damage(9999.0)
	_check(not aegis_player.health.is_dead, "Aegis Sigil must recharge when a new wave starts")

	var runner := _make_player("arclight")
	runner.gold = 100000
	runner.buy("phase_boots")
	runner._update_sprint(0.016, true)
	_check(runner.is_sprinting(), "Phase Boots did not fire")
	_check(runner.sprint_cooldown > 0.0, "Phase Boots did not go on cooldown")
	runner._update_sprint(Player.SPRINT_DURATION + 0.1, true)
	_check(not runner.is_sprinting(), "The sprint should expire")
	_check(runner.sprint_cooldown > 0.0, "Phase Boots must not fire again while on cooldown")

	var barefoot := _make_player("arclight")
	barefoot._update_sprint(0.016, true)
	_check(not barefoot.is_sprinting(), "A player without Phase Boots must not dash")

	_cleanup([player, enemy, pierced_player, flier, aegis_player, runner, barefoot])


func _test_ability_data_integrity() -> void:
	for class_data in PlayerClass.CLASSES:
		_check(class_data.ability_pool.size() == 12, "%s must have exactly 12 abilities, got %d" % [class_data.id, class_data.ability_pool.size()])
		var seen: Dictionary = {}
		for ability_id in class_data.ability_pool:
			_check(not seen.has(ability_id), "%s lists %s twice" % [class_data.id, ability_id])
			seen[ability_id] = true
			var data := PlayerClass.ability_info(str(ability_id))
			_check(not data.is_empty(), "%s references unknown ability %s" % [class_data.id, ability_id])
			_check(not str(data.get("name", "")).is_empty(), "Ability %s has no name" % ability_id)


func _test_ability_rank_scaling() -> void:
	var rank_one := PlayerClass.ability_values("arclight_static_bolt", 1)
	var rank_max := PlayerClass.ability_values("arclight_static_bolt", PlayerClass.MAX_ABILITY_RANK)
	_check(rank_max.power > rank_one.power, "Ranking up Static Bolt should raise its damage")
	_check(rank_max.cooldown < rank_one.cooldown, "Ranking up Static Bolt should lower its cooldown")
	_check(rank_one.cooldown > float(PlayerClass.ability_info("arclight_static_bolt").cooldown_base), "Rank 1 cooldown should already be stretched above the authored base")

	var chain_one := PlayerClass.ability_values("arclight_overcharge", 1)
	var chain_max := PlayerClass.ability_values("arclight_overcharge", PlayerClass.MAX_ABILITY_RANK)
	_check(chain_max.chain_count > chain_one.chain_count, "A maxed chain ability should bounce further than rank 1")

	var burst_one := PlayerClass.ability_values("bulwark_ground_slam", 1)
	var burst_max := PlayerClass.ability_values("bulwark_ground_slam", PlayerClass.MAX_ABILITY_RANK)
	_check(burst_max.radius > burst_one.radius, "A maxed AoE ability should cover more ground than rank 1")


func _test_ability_learn_and_upgrade() -> void:
	var player := _make_player("arclight")
	_check(player.known_abilities.is_empty(), "A fresh player should know no abilities")

	for ability_id in ["arclight_static_bolt", "arclight_overcharge", "arclight_ion_storm", "arclight_arc_flash"]:
		player.learn_ability(ability_id)
	_check(player.known_abilities.size() == PlayerClass.MAX_KNOWN_ABILITIES, "Learning 4 abilities should fill every slot")

	player.learn_ability("arclight_thunder_step")
	_check(player.known_abilities.size() == PlayerClass.MAX_KNOWN_ABILITIES, "A 5th ability must not be learnable while 4 are already known")

	player.learn_ability("arclight_static_bolt")
	_check(player.known_abilities[0].rank == 1, "Learning an already-known ability again must be a no-op, not a duplicate")

	for _step in PlayerClass.MAX_ABILITY_RANK:
		player.upgrade_ability("arclight_static_bolt")
	_check(player.known_abilities[0].rank == PlayerClass.MAX_ABILITY_RANK, "Static Bolt should cap out at MAX_ABILITY_RANK, got %d" % int(player.known_abilities[0].rank))
	_cleanup([player])


## The ability offer always tries for 4 total choices: one guaranteed upgrade slot per
## already-known (unmaxed) ability, and the rest filled with random not-yet-known ones.
func _test_ability_offer_alternation() -> void:
	var player := _make_player("arclight")
	var fresh_offer := PlayerClass.ability_offer_ids("arclight", player.known_abilities)
	_check(fresh_offer.size() == 4, "A fresh hero should see 4 fresh abilities to learn, got %d" % fresh_offer.size())
	for ability_id in fresh_offer:
		_check(ability_id in PlayerClass.by_id("arclight").ability_pool, "Offered id %s is not one of Arclight's abilities" % ability_id)

	player.learn_ability("arclight_static_bolt")
	var one_known_offer := PlayerClass.ability_offer_ids("arclight", player.known_abilities)
	_check(one_known_offer.size() == 4, "With 1 known ability the offer should still total 4, got %d" % one_known_offer.size())
	_check("arclight_static_bolt" in one_known_offer, "The one known ability must always get an upgrade slot")
	var new_count := 0
	for ability_id in one_known_offer:
		if ability_id != "arclight_static_bolt":
			new_count += 1
	_check(new_count == 3, "With 1 known ability, the other 3 slots must be fresh picks, got %d" % new_count)

	for ability_id in ["arclight_overcharge", "arclight_ion_storm", "arclight_arc_flash"]:
		player.learn_ability(ability_id)
	var full_offer := PlayerClass.ability_offer_ids("arclight", player.known_abilities)
	_check(full_offer.size() == 4, "With 4 known abilities the offer should still be 4, got %d" % full_offer.size())
	for ability_id in ["arclight_static_bolt", "arclight_overcharge", "arclight_ion_storm", "arclight_arc_flash"]:
		_check(ability_id in full_offer, "Once 4 abilities are known, every one of them must always be offered for upgrade, missing %s" % ability_id)

	for entry in player.known_abilities:
		for _step in PlayerClass.MAX_ABILITY_RANK:
			player.upgrade_ability(str(entry.id))
	var exhausted_offer := PlayerClass.ability_offer_ids("arclight", player.known_abilities)
	_check(exhausted_offer.is_empty(), "A fully maxed 4-ability loadout must have nothing left to offer")
	_cleanup([player])


func _test_ability_archetypes_smoke() -> void:
	var nuker := _make_player("arclight")
	var target := _make_enemy(Vector2(120.0, 0.0))
	nuker.learn_ability("arclight_static_bolt")
	var before := target.health.current_health
	nuker._cast_known_ability(0)
	_check(target.health.current_health < before, "Static Bolt did not damage its target")
	_check(nuker.ability_cooldowns[0] > 0.0, "Casting an ability must start its cooldown")
	_cleanup([nuker, target])

	var healer := _make_player("arclight")
	healer.health.take_damage(40.0)
	var wounded := healer.health.current_health
	healer.learn_ability("arclight_second_wind")
	healer._cast_known_ability(0)
	_check(healer.health.current_health > wounded, "Vital Surge (self_heal) did not heal its caster")
	_cleanup([healer])

	var blinker := _make_player("arclight")
	blinker.aim_world_position = blinker.global_position + Vector2(500.0, 0.0)
	var start_position := blinker.global_position
	blinker.learn_ability("arclight_thunder_step")
	blinker._cast_known_ability(0)
	_check(blinker.global_position.distance_to(start_position) > 100.0, "Thunder Step did not move its caster")
	_cleanup([blinker])

	var shielded := _make_player("bulwark")
	shielded.learn_ability("bulwark_fortify")
	shielded._cast_known_ability(0)
	_check(shielded.health.shield_amount > 0.0, "Fortify did not grant a shield")
	var health_before_shield := shielded.health.current_health
	shielded.health.take_damage(10.0)
	_check(is_equal_approx(shielded.health.current_health, health_before_shield), "A fresh shield should fully absorb a small hit")
	_cleanup([shielded])

	var puller := _make_player("bulwark", Vector2.ZERO)
	var nearby_enemy := _make_enemy(Vector2(100.0, 0.0))
	puller.learn_ability("bulwark_provoke")
	puller._cast_known_ability(0)
	_check(nearby_enemy.knockback_velocity.x < 0.0, "Provoke should pull the enemy back toward the caster")
	_cleanup([puller, nearby_enemy])

	var marker := _make_player("arclight")
	var marked_enemy := _make_enemy(Vector2(120.0, 0.0))
	marker.learn_ability("arclight_track")
	marker._cast_known_ability(0)
	_check(marked_enemy.vulnerability_bonus > 0.0, "Track did not mark its target as vulnerable")
	_cleanup([marker, marked_enemy])


func _test_ability_aoe_and_cooldown() -> void:
	var small_aoe := PlayerClass.ability_values("arclight_static_bolt", 1)
	var big_aoe := PlayerClass.ability_values("bulwark_ground_slam", 1)
	_check(small_aoe.footprint < big_aoe.footprint, "Static Bolt should have a smaller AoE footprint than Ground Slam")
	_check(small_aoe.cooldown < big_aoe.cooldown, "Smaller AoE spells should recycle faster than huge novas")

	var nuker := _make_player("arclight")
	var first := _make_enemy(Vector2(120.0, 0.0))
	var second := _make_enemy(Vector2(150.0, 40.0))
	nuker.learn_ability("arclight_static_bolt")
	var first_before := first.health.current_health
	var second_before := second.health.current_health
	nuker._cast_known_ability(0)
	_check(first.health.current_health < first_before, "Static Bolt did not damage the first enemy in its blast")
	_check(second.health.current_health < second_before, "Static Bolt did not damage the second enemy in its blast")
	_cleanup([nuker, first, second])


func _cleanup(nodes: Array) -> void:
	for node in nodes:
		if is_instance_valid(node):
			remove_child(node)
			node.free()
