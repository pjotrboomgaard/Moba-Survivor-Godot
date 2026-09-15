extends Node
## T3.88 — Isolated verification: upgrade diversity. Simulates N level-ups for a
## hero and records the offered upgrade ids, then asserts no single upgrade repeats
## more than expected. Compares against a "no recency" baseline.
##
## Empty-world: no scene dependencies — pure logic test on UpgradeCatalog.
class_name UpgradeDiversityTest

const LEVELS_TO_SIMULATE := 20
const HERO_CLASS := "tobor"
const AMOUNT := 4


func _ready() -> void:
	var report := {}
	var taken: Array = []
	var recent_history: Array = []

	var recent_picks: Dictionary = {}
	var no_recent_picks: Dictionary = {}

	# Simulate N level-ups WITH recency history (T3.88 fix).
	# Each level-up, the player "takes" the first stat upgrade offered, so it's
	# permanently removed from the pool. The rest stay as options. Recency
	# deprioritizes recently-offered stats.
	for i in LEVELS_TO_SIMULATE:
		var ids := PlayerClass.random_upgrade_ids(
			HERO_CLASS, AMOUNT, [], i + 1, taken, recent_history
		)
		var took := false
		for id in ids:
			recent_picks[id] = int(recent_picks.get(id, 0)) + 1
			# Only the FIRST stat upgrade offered is "taken" by the player
			# (simulating a real pick); the rest remain un-taken.
			if not took and not UpgradeCatalog.is_ability_token(id):
				taken.append(id)
				took = true
		# Update recency history (newest-first, capped at 8).
		for id in ids:
			if not UpgradeCatalog.is_ability_token(id):
				recent_history.erase(id)
				recent_history.push_front(id)
		while recent_history.size() > 8:
			recent_history.pop_back()

	# Simulate N level-ups WITHOUT recency (baseline).
	taken.clear()
	for i in LEVELS_TO_SIMULATE:
		var ids := PlayerClass.random_upgrade_ids(
			HERO_CLASS, AMOUNT, [], i + 1, taken, []
		)
		var took := false
		for id in ids:
			no_recent_picks[id] = int(no_recent_picks.get(id, 0)) + 1
			if not took and not UpgradeCatalog.is_ability_token(id):
				taken.append(id)
				took = true

	var recent_max := 0
	for id in recent_picks:
		recent_max = maxi(recent_max, int(recent_picks[id]))
	var baseline_max := 0
	for id in no_recent_picks:
		baseline_max = maxi(baseline_max, int(no_recent_picks[id]))

	report["hero"] = HERO_CLASS
	report["levels_simulated"] = LEVELS_TO_SIMULATE
	report["recent_distinct_upgrades"] = recent_picks.size()
	report["recent_max_repeats"] = recent_max
	report["baseline_distinct_upgrades"] = no_recent_picks.size()
	report["baseline_max_repeats"] = baseline_max
	# The fix should produce fewer max-repeats than the baseline (or at least
	# not more). PASS if recent_max_repeats <= baseline_max_repeats.
	report["verdict"] = "PASS" if recent_max <= baseline_max else "FAIL"
	report["recent_picks"] = recent_picks
	report["baseline_picks"] = no_recent_picks

	var f := FileAccess.open("user://selftest_report.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "\t"))
		f.close()
	print("[upgrade-diversity] report: %s" % JSON.stringify(report, "\t"))
	get_tree().quit()
