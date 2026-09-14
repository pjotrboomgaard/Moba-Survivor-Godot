extends Node
## Isolated test: verify the 5 renamed biome names + the 2 test-mode names
## render correctly from GameRuntime.biome_name(). No main scene, no arena,
## no HUD — just probe the autoload and write a report.

var _biome_results: Array = []
var _expected: Dictionary = {
	0: "Scrapyard Outskirts",
	1: "Molten Core",
	2: "Frostlab",
	3: "Assembly Plant",
	4: "Dock Bay",
	5: "Recruit Arena",
	6: "Camp Gauntlet",
}


func _ready() -> void:
	print("[BiomeNamesTest] start")
	for i in range(7):
		GameRuntime.set_biome(i, true)
		var name: String = GameRuntime.biome_name()
		var key: String = GameRuntime.biome_key()
		var ok: bool = (name == _expected[i])
		_biome_results.append({
			"index": i,
			"key": key,
			"got": name,
			"expected": _expected[i],
			"match": ok,
		})
		print("[BiomeNamesTest] biome %d key=%s name=%s expected=%s match=%s" % [i, key, name, _expected[i], ok])

	_finish()


func _finish() -> void:
	var all_ok: bool = true
	for r in _biome_results:
		if not r["match"]:
			all_ok = false
	var verdict := "PASS" if all_ok else "FAIL"
	var report := {
		"verdict": verdict,
		"scene": "biome_names_test",
		"results": _biome_results,
	}
	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[BiomeNamesTest] SUMMARY verdict=", verdict, " all_match=", all_ok)
	get_tree().quit(0)
