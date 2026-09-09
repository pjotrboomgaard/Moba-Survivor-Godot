extends SceneTree

func _init() -> void:
	var path := "res://scripts/enemy_type.gd"
	var content := FileAccess.get_file_as_string(path)
	var f := FileAccess.open(path, FileAccess.READ)
	f.close()

	# 1) Add biome-specific boss entries to TYPES array (insert before closing "]\n" of TYPES)
	var types_close := "],\nconst BOSS_ROTATION"
	if content.find(types_close) < 0:
		print("FAIL: could not find TYPES close")
		quit()

	var new_bosses := "\t{\n\t\t\"id\": \"magma_golem\",\n\t\t\"name\": \"Magma Golem\",\n\t\t\"fill_color\": \"ff6b2a\",\n\t\t\"outline_color\": \"ffcc8a\",\n\t\t\"radius\": 74.0,\n\t\t\"max_health\": 1650.0,\n\t\t\"movement_speed\": 78.0,\n\t\t\"contact_damage\": 16.0,\n\t\t\"attack_interval\": 1.05,\n\t\t\"attack_distance\": 96.0,\n\t\t\"xp_value\": 480,\n\t\t\"gold_value\": 210,\n\t\t\"is_boss\": true,\n\t\t\"world_exclusive\": true,\n\t\t\"separation_weight\": 2.2,\n\t\t\"explode_radius\": 130.0,\n\t\t\"explode_damage\": 14.0,\n\t\t\"charge_speed\": 500.0,\n\t\t\"charge_windup\": 0.55,\n\t\t\"charge_duration\": 0.58,\n\t\t\"dash_interval\": 3.6,\n\t\t\"unlock_wave\": 5,\n\t\t\"cost\": 12.0,\n\t\t\"weight\": 0.0,\n\t\t\"formation\": Formation.LONE,\n\t\t\"group_min\": 1,\n\t\t\"group_max\": 1,\n\t\t\"resistances\": {\n\t\t\tPlayerClass.DamageType.FIRE: 0.55,\n\t\t\tPlayerClass.DamageType.FROST: 0.65,\n\t\t\tPlayerClass.DamageType.IMPACT: 1.25,\n\t\t},\n\t},\n\t{\n\t\t\"id\": \"frost_titan\",\n\t\t\"name\": \"Frost Titan\",\n\t\t\"fill_color\": \"7adfff\",\n\t\t\"outline_color\": \"e6faff\",\n\t\t\"radius\": 72.0,\n\t\t\"max_health\": 1900.0,\n\t\t\"movement_speed\": 70.0,\n\t\t\"contact_damage\": 11.0,\n\t\t\"attack_interval\": 0.95,\n\t\t\"attack_distance\": 110.0,\n\t\t\"preferred_distance\": 420.0,\n\t\t\"projectile_damage\": 18.0,\n\t\t\"projectile_speed\": 430.0,\n\t\t\"projectile_count\": 5,\n\t\t\"projectile_sprite\": \"frost_shard\",\n\t\t\"behaviour\": Behaviour.RANGED,\n\t\t\"flying\": false,\n\t\t\"xp_value\": 520,\n\t\t\"gold_value\": 230,\n\t\t\"is_boss\": true,\n\t\t\"world_exclusive\": true,\n\t\t\"separation_weight\": 2.2,\n\t\t\"aura_radius\": 300.0,\n\t\t\"aura_heal_per_second\": 8.0,\n\t\t\"charge_speed\": 520.0,\n\t\t\"charge_windup\": 0.48,\n\t\t\"charge_duration\": 0.55,\n\t\t\"dash_interval\": 4.4,\n\t\t\"unlock_wave\": 10,\n\t\t\"cost\": 12.0,\n\t\t\"weight\": 0.0,\n\t\t\"formation\": Formation.LONE,\n\t\t\"group_min\": 1,\n\t\t\"group_max\": 1,\n\t\t\"resistances\": {\n\t\t\tPlayerClass.DamageType.FIRE: 0.6,\n\t\t\tPlayerClass.DamageType.FROST: 1.4,\n\t\t\tPlayerClass.DamageType.IMPACT: 0.75,\n\t\t},\n\t},\n\t{\n\t\t\"id\": \"scrap_colossus\",\n\t\t\"name\": \"Scrap Colossus\",\n\t\t\"fill_color\": \"c0c8d4\",\n\t\t\"outline_color\": \"fff09a\",\n\t\t\"radius\": 80.0,\n\t\t\"max_health\": 2100.0,\n\t\t\"movement_speed\": 66.0,\n\t\t\"contact_damage\": 14.0,\n\t\t\"attack_interval\": 0.9,\n\t\t\"attack_distance\": 120.0,\n\t\t\"preferred_distance\": 360.0,\n\t\t\"projectile_damage\": 15.0,\n\t\t\"projectile_speed\": 520.0,\n\t\t\"projectile_count\": 4,\n\t\t\"projectile_sprite\": \"scrap_bolt\",\n\t\t\"behaviour\": Behaviour.RANGED,\n\t\t\"xp_value\": 560,\n\t\t\"gold_value\": 260,\n\t\t\"is_boss\": true,\n\t\t\"world_exclusive\": true,\n\t\t\"separation_weight\": 2.4,\n\t\t\"charge_speed\": 480.0,\n\t\t\"charge_windup\": 0.5,\n\t\t\"charge_duration\": 0.6,\n\t\t\"dash_interval\": 4.8,\n\t\t\"unlock_wave\": 10,\n\t\t\"cost\": 12.0,\n\t\t\"weight\": 0.0,\n\t\t\"formation\": Formation.LONE,\n\t\t\"group_min\": 1,\n\t\t\"group_max\": 1,\n\t\t\"resistances\": {\n\t\t\tPlayerClass.DamageType.LIGHTNING: 0.6,\n\t\t\tPlayerClass.DamageType.IMPACT: 0.5,\n\t\t\tPlayerClass.DamageType.FIRE: 1.2,\n\t\t},\n\t},\n\t{\n\t\t\"id\": \"dock_warden\",\n\t\t\"name\": \"Dock Warden\",\n\t\t\"fill_color\": \"3a9bc8\",\n\t\t\"outline_color\": \"bfe8ff\",\n\t\t\"radius\": 66.0,\n\t\t\"max_health\": 1350.0,\n\t\t\"movement_speed\": 98.0,\n\t\t\"contact_damage\": 13.0,\n\t\t\"attack_interval\": 0.8,\n\t\t\"attack_distance": 90.0,\n\t\t\"xp_value\": 440,\n\t\t\"gold_value\": 220,\n\t\t\"is_boss\": true,\n\t\t\"world_exclusive\": true,\n\t\t\"separation_weight\": 2.0,\n\t\t\"explode_radius\": 110.0,\n\t\t\"explode_damage\": 12.0,\n\t\t\"charge_speed\": 580.0,\n\t\t\"charge_windup\": 0.42,\n\t\t\"charge_duration\": 0.5,\n\t\t\"dash_interval\": 2.8,\n\t\t\"teleport_interval\": 4.0,\n\t\t\"teleport_range\": 180.0,\n\t\t\"unlock_wave\": 5,\n\t\t\"cost\": 12.0,\n\t\t\"weight\": 0.0,\n\t\t\"formation\": Formation.LONE,\n\t\t\"group_min\": 1,\n\t\t\"group_max\": 1,\n\t\t\"resistances\": {\n\t\t\tPlayerClass.DamageType.IMPACT: 0.65,\n\t\t\tPlayerClass.DamageType.FIRE: 1.15,\n\t\t\tPlayerClass.DamageType.NATURE: 1.2,\n\t\t},\n\t},\n"
	content = content.replace(types_close, new_bosses + "],\nconst BOSS_ROTATION")

	# 2) Replace BOSS_ROTATION with a function that's biome-aware
	var old_rotation := 'const BOSS_ROTATION: Array[String] = ["ravager", "stormcaller"]'
	var new_rotation := '## Base rotation for grass (biome 0). Biome-specific bosses override via BOSS_ROTATION_BY_BIOME.\nconst BOSS_ROTATION: Array[String] = ["ravager", "stormcaller"]\n\n## Per-biome boss rotation (biome_id -> rotation list). Grass falls back to BOSS_ROTATION.\nconst BOSS_ROTATION_BY_BIOME := {\n\t1: ["magma_golem", "frost_titan"],\n\t2: ["frost_titan", "magma_golem"],\n\t3: ["scrap_colossus", "dock_warden"],\n\t4: ["dock_warden", "scrap_colossus"],\n}'
	if content.find(old_rotation) < 0:
		print("FAIL: could not find BOSS_ROTATION")
		quit()
	content = content.replace(old_rotation, new_rotation)

	# 3) Update boss_for_wave to be biome-aware
	var old_func := '''static func boss_for_wave(wave: int) -> String:
	var unlocked: Array[String] = []
	for boss_id in BOSS_ROTATION:
		if int(by_id(boss_id).unlock_wave) <= wave:
			unlocked.append(boss_id)
	if unlocked.is_empty():
		return BOSS_ROTATION[0]
	return unlocked[(int(wave) / WaveDirector.BOSS_WAVE_INTERVAL - 1) % unlocked.size()]'''
	var new_func := '''static func boss_rotation_for_biome(biome_id: int) -> Array[String]:
	var raw: Variant = BOSS_ROTATION_BY_BIOME.get(biome_id, [])
	if raw is Array and not (raw as Array).is_empty():
		return raw as Array[String]
	return BOSS_ROTATION.duplicate()


static func boss_for_wave(wave: int) -> String:
	var rotation := boss_rotation_for_biome(GameRuntime.biome_id)
	var unlocked: Array[String] = []
	for boss_id in rotation:
		if int(by_id(boss_id).unlock_wave) <= wave:
			unlocked.append(boss_id)
	if unlocked.is_empty():
		return rotation[0]
	return unlocked[(int(wave) / WaveDirector.BOSS_WAVE_INTERVAL - 1) % unlocked.size()]'''
	if content.find(old_func) < 0:
		print("FAIL: could not find old boss_for_wave")
		quit()
	content = content.replace(old_func, new_func)

	# 4) Add TOBOR_NAMES entries for new bosses
	var old_names := '\t"ravager": "Magazijnbaas",\n\t"stormcaller": "Bewakingsblimp",\n}'
	var new_names := '\t"ravager": "Magazijnbaas",\n\t"stormcaller": "Bewakingsblimp",\n\t"magma_golem": "Magma Golem",\n\t"frost_titan": "Frost Titan",\n\t"scrap_colossus": "Scrap Colossus",\n\t"dock_warden": "Dock Warden",\n}'
	if content.find(old_names) < 0:
		print("WARN: could not find TOBOR_NAMES tail (may already be extended)")
	else:
		content = content.replace(old_names, new_names)

	var w := FileAccess.open(path, FileAccess.WRITE)
	w.store_string(content)
	w.close()
	print("OK: updated enemy_type.gd with 4 new biome bosses + biome-aware rotation")
	quit()
