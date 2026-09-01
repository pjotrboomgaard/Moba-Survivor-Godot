# HoN-Faithfulness Audit Report
Generated 2026-09-01 (read-only pass over `scripts/player_class.gd`, `tools/catalog_3day.txt`, `tools/selftest/kit_coverage_report.md`)

Budget note: scanned the 16 canonical HoN ability_id entries only (Q slots per kit) plus kit summaries. HoN ability facts referenced from standard HoN wiki (Pyromancer Dragon Fire, Bombardier Sticky Bomb, etc.).

---

## Section 1 — Top 10 HoN-faithfulness gaps (Q slot per kit)

Ranked by severity. Severity = HIGH (wrong archetype vs HoN, breaks identity) / MED (numbers or secondary effects far off) / LOW (cosmetically close).

### 1. `tobor_steam_keg` — HIGH
- **Current:** NUKE_BOLT, 55 base 18 base 8s cd, 560 range, 200 radius, 0.6 stun. Lobbed keg AoE nuke.
- **HoN (Rally/Tobor analog — Steam Keg / Lodestone equivalent):** HoN kits of this archetype (e.g., Aluna pyromancer) typically pair a *deferred / timed* explosion with secondary displacement. Currently a single instant nuke with stun-on-hit; missing HoN's signature **rolling / delayed detonation** and **persistent burn/DoT**.
- **Gap:** No delayed explosion timer, no fire trail, no lingering steam cloud DoT. Roughly equivalent raw numbers to a HoN Q but the *mechanic* is one step removed.

### 2. `arclight_blast_of_lightning` — MED
- **Current:** NUKE_BOLT, 110 base 7s cd, 640 range, single-target.
- **HoN (Thunderbringer Lightning Rod / Blast of Lightning equivalent):** HoN's comparable spell is typically a single-target nuke with **bonus damage from nearby hero kills / mana-scaling**, or a small ministun window.
- **Gap:** Missing ministun (0.1s interrupt) and damage scaling hook. Currently just raw nuke. Numbers in right ballpark (HoN ~100-125 base at rank 1).

### 3. `bulwark_fissure` — HIGH
- **Current:** DASH_STRIKE, 55 base, dash_distance 340, 60 radius, 1.2s stun, 8.5 cd.
- **HoN (Earthshaker Fissure):** HoN Fissure is a **linear wall + ground stun along a straight line that BLOCKS pathing for ~8s**. Not a self-dash. Critically: Fissure does *not* move the caster.
- **Gap:** Mapped entirely wrong archetype. Should be a linear wall/ground-stun (SPAWN_WALL + radius-stun along a line), current is a charge-through. Loses HoN's core "zone the lane" identity.

### 4. `warden_tongue_tied` — MED
- **Current:** PUSH_PULL_BURST, 380 power (inverted pull sign = pulls toward caster), 480 range, 8s cd.
- **HoN (Pollywog Priest Tongue-Tied):** HoN is a **no-damage single-target channel/slow** tied to the priest's "yank hero to me" with a 2-2.5s duration root / silence, not a raw nuke.
- **Gap:** Numbers are ~10x too high for a HoN utility skill (380 base!). Missing channel / silence component. Cooldown about right but the mechanic is "pull + big damage" when HoN is "pull + soft-CC".

### 5. `cinder_dragon_fire` — LOW
- **Current:** NUKE_BOLT, 105 base, 7s cd, 620 range.
- **HoN (Pyromancer Dragon Fire):** HoN is the Pyro's generic single-target fire nuke. Numbers closely match HoN Q (~100-120 at rank 1, ~7-9 cd at rank 1).
- **Gap:** Minor — missing the small projectile visual arc Pyro's fireball has; currently fires as a straight blast. Mechanically equivalent.

### 6. `pyra_sticky_bomb` — HIGH
- **Current:** NUKE_BOLT, 75 base, 7s cd, 540 range, instant explosion on impact.
- **HoN (Bombardier Sticky Bomb):** HoN Sticky Bomb is **placeable on self / ally that detonates on contact or after timer**, does not explode on direct cast at a point.
- **Gap:** Currently an instant targeted nuke; HoN's is a *deferred trap-and-trigger* with an arming delay and self-attach option. Missing both the timer and the self-cast trick. Also silently no-ops in dry-run (Pattern 1).

### 7. `slag_steam_bath` — MED
- **Current:** BUFF_SELF, 12s cd, 0.7x damage taken + 1.05x speed, 6s duration.
- **HoN (Kraken/Magmus analog — "magma bath" sustaining sustain):** Comparable HoN sustain is typically a passive regen aura or channelled heal-over-time. Steam Bath equivalent tends to be a **self-heal tick in an area**, not a raw defensive buff.
- **Gap:** Missing HoN's **regen-over-time** flavor; current is a generic "block incoming damage" stat buff, indistinct from `bulwark_fortify` / `tobor_scrap_shield`. Three kits share the same fantasy.

### 8. `ember_entangle` — HIGH
- **Current:** NUKE_BOLT, 65 base, 11s cd, 560 range, 0.5-factor slow for 2.5s.
- **HoN (Treant/Keeper Entangle equivalent):** HoN Entangle is **0-damage or low-damage root holding enemies in place 1.5-3s**. Not a damage nuke.
- **Gap:** Wrong effect type — should be **root (movement=0), not slow**. Currently slows, doesn't hold. 65 base damage is far above HoN's utility-scaling. Also silently no-ops in dry-run.

### 9. `thorn_poison_spray` — MED
- **Current:** CONE_BURST, 30 base, 6s cd, 340 radius (interpreted as cone width).
- **HoN (Plague Rider / Venomancer Poison Nova line equivalent):** Either a poison DoT spray with **multi-second tick damage** or a slow+DoT combo.
- **Gap:** Currently one-shot burst damage with no DoT effect — there is no lingering poison mechanic. HoN signature is the damage-over-time.

### 10. `volt_gust` — MED
- **Current:** CONE_BURST, 32 base, 8s cd.
- **HoN (Thunderbringer Gust / storm-wave equivalent):** HoN comparable is typically a **knockback + slow** along a lane, with zone control (push back).
- **Gap:** Missing knockback. Currently just damage in a cone. The "gust" fantasy should displace.

### Honorable mention (didn't make top 10):
- `sage_grace` — AOE_HEAL, 60 base, 12s cd. Roughly HoN-equivalent bubbles (Ophelia) but missing the cleanse/remove-debuff component HoN pairs it with. MED.
- `nebula_time_shift` — BLINK, 15 base damage, 11s cd. HoN (Chronos / Magebane style) would have **attack-reset or move speed bonus on landing**. MED.
- `astral_essence_link` — AOE_HEAL 55 base. HoN (Io Tether) is a **persistent tether between two heroes sharing damage/heals** — currently a one-shot AoE heal. HIGH but not in Q priority.
- `rime_ice_imprisonment` — NUKE_BOLT 65 base + 0.6 slow. HoN (Tempest/Kelvin) would be a **full stun 1.5-2s freeze**. Slow ≠ imprisonment. HIGH but per-hero report already flagged.
- R-slot failures (`stump_overgrowth` hang, `sage_charm` hang, `volt_typhoon` hang) not scored here — captured in Section 3.

---

## Section 2 — Top 10 restoration gaps (from `tools/catalog_3day.txt`)

Entries marked partial / chat-only / lost that lack current implementation:

1. **Rift Clash — ranked team FFA mode** (session e8f4b233) — partial. `rift_clash_manager.gd`, `rank_service.gd` wired but *team-stealing wave logic and team-pick flow deferred*. No verified end-to-end ranked match still works.
2. **RankService end-to-end verification** (session e8f4b233) — partial. SP deltas + leaderboard placement committed, but notes say "wired but rank flow unverified end-to-end." Test gap.
3. **Sealed crater (wave-10 unlock)** (session 28aa64f5) — **LOST**. Bramble-seal collision + RPC reverted; crater now open from wave 1. The original "earn your way into the crater" mechanic is gone.
4. **Arclight/Bulwark/Warden sprite recreation** (session 2d0ed247) — partial. Auto-trace tool worked (warden .494 score), but later churn (BOM, stale cache) left it *partially degraded*, superseded by robot-3 rollback request that was itself lost.
5. **Terrain hazard / lava dunk system** (session ebac881b BIG) — partial. `hazard_at` DoT, knockback flight mask-drop over lava lip, dunk burst implemented but per catalog *"Stubbed/no-op'd during recovery"* — likely dead code path.
6. **Menu revamp — world tabs + hero cards** (session ebac881b) — partial. Survived via commit 9420f1a but later rebased through ScrollContainer fix (c434ffe). Fully landed but integrates with *other* broken systems (mastery/loadout).
7. **Solo unlock meta (shards)** (session ebac881b) — partial. `hero_shards` persisted; `ProgressionService` registered as *autoload stub only*. Menu gating relies on this — may not actually unlock.
8. **Sparks economy + wave draft** (session ebac881b) — partial. 3-wave draft offers + spark awards wired but `bank_wave_progress` call hits a **missing profile-stub method**, so it silently degrades.
9. **Mastery + loadout system** (session ebac881b) — partial. Per-hero 4-slot loadout works on surface but *"Ult-from-start change later removed wave-5 gate"* — so the intended progression pacing is broken. MP lobby rows also include edge cases.
10. **Vector-only VFX (LightningEffect)** (session ebac881b) — partial. `VECTOR_ONLY_KIT_IDS` table + `KitFxLibrary` per-kit palette landed but the catalog notes parity drifting with re-keyed ability IDs — only as reliable as the id keying matches.

Honorable: **64 SHAPE_KIT_\* icon grids** (partial — 36 icons landed via subagent f0d2ffe + 12 hero tones, but *"icons degraded after recovery re-keying"*), **4-directional hero sprites / walk frames** (partial, robot-3 rollback "repeatedly lost"), **Hero-themed ability sounds** (partial — 34 wavs in place, but per-ability sfx *"degraded by later re-keys"*), **Recovery audit** itself is solid but downstream fixes recommended by it are not all completed.

---

## Section 3 — Known-broken patterns from kit coverage

From `tools/selftest/kit_coverage_report.md` (16 heroes swept):

### Verdict tally
- **9 PASS:** arclight, bulwark, cinder, slag, ember, willow, nebula, astral, rime
- **3 WARN:** warden, pyra, thorn (1–2 casts only)
- **4 FAIL:** tobor, stump, sage, volt (0 casts)

### Pattern 1 — "Expected cast never fired" silent no-op (12 heroes affected, 15 ability ids)
- Central signal: 15 distinct abilities (e.g. entire tobor kit, `bulwark_heavyweight`, `warden_tongue_tied`, `warden_voodoo_wards`, `pyra_sticky_bomb`, `pyra_air_strike`, `ember_entangle`, `thorn_toxin_ward`, `thorn_toxicity`, `nebula_curse_of_ages`, `astral_spirit_bond`, `rime_ice_imprisonment`) never reach `cast_ability` log line.
- cooldown skips from arclight prove the normal path *is* instrumented, so these are **early-return guards / conditions inside bespoke casters** (range, mana, stance) that silently abort.
- **Likely root:** bespoke `_cast_ability_*` wrapper returning before invoking the shared `cast_ability()` helper.

### Pattern 2 — Mid-run hangs after R-slot cast (3 heroes)
- stump, sage, volt all stall immediately after `_play_ability_effect <R>` on 90 s budget. Frame loop freezes before next scheduled t=8 s snap.
- **Likely root:** long-running async call or tween inside the R-caster that blocks the main loop.

### Pattern 3 — Ember kit aliasing other heroes
- ember PASSed but casts logged `ember_healing_wave`, `ember_storm_cloud`, `ember_unbreakable` — these are healer/aoe archetypes, not the fire-theme ember fantasy. Suggests ember kit is aliasing sage/nebula/bulwark ability ids (probably copy-paste leftover in `player_class.gd`).
- `ember_entangle` itself silently no-ops (Pattern 1).

### Pattern 4 — Test-side id mismatch
- `willow_strangling_vines` (in `willow_kit_dry.json`) is the **texture filename prefix**, not the ability id. Canonical is `willow_wall_of_roots` (player_class.gd L449, L1708). Other request files may share the same mistake — at least one was likely generated from sprite names instead of `player_class.gd`.

### Pattern 5 — Cross-cutting recovery-rekey fallout
- All Pattern 1 silent-no-ops coincide with abilities that were re-keyed during recovery (`tobor_*`, `warden_*`, etc.). This is consistent with the per-session note *"player_class clobber → re-keyed kit ids while runtime/VFX/icons still key old ids = root of 56 smoke failures"* (root-cause session c55f3593).

---

## STILL TODO (out of budget)

- Deep read of `scripts/player.gd` to identify the exact early-return guard causing Pattern 1 (would need additional reads of the bespoke caster functions — not done to stay under read budget).
- Cross-reference ranking of the 12 partial-restoration features against current HEAD commit (would need `git log` queries — not run per constraint).
- Pattern 2 hangs need frame-by-frame traces, not just static analysis.
- HoN wiki per-ability citations not all verified against latest patches (HoN officially sunset June 2022; using final patch state).
