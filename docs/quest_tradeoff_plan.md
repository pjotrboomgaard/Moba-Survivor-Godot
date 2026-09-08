# Rift Survivors — Quest vs. Camps vs. Center Tradeoff Plan

## The Three Axes of Gameplay

A run is a constant decision: where do I spend the next 10-30 seconds?

| Axis | What it is | Reward | Cost | Risk |
|------|-----------|--------|------|------|
| **Center / Hero** | Fight waves at the arena center | Wave XP + Gold + occasional boss | Time spent in the open, taking damage | Waves get exponentially harder; one mistake = death |
| **Creep Camps** | Static tougher elites at 4 map corners (brute/sentinel/stalker/summoner, 2-4× HP) | Big XP chunk + Gold + item drops | Must travel to corner, fight 3-elite squad, then travel back | Camps respawn in 45s; if you're late you find 2-3 elites waiting |
| **Side Quests** | 26 quest types (chase/collect/smash/stand/visit/kill/rescue/dance) at the outskirts | 20-70 XP, 20-100 Gold, occasional buff/heal/minions | Detour time (5-20s); rescue quests require fighting NPCs' attackers | Low direct risk (outskirts), but the detour delays wave defense |

## Why This Matters (the "wave 20" question)

To reach wave 20 the player must **outpace the wave difficulty curve**. The budget grows ~9.5/wave and health grows per-wave. The only way to stay ahead is to **stack upgrades faster than the curve**. That means:

- **Maximize XP/s** — XP comes from kills, quests, and camp clears.
- **Minimize dead time** — kiting through a wave without killing is dead time.
- **Avoid HP death-spirals** — once HP < 40%, the bot must kite to a heal orb or land, or it dies.

The three axes compete for the same resource: **time**. The optimal strategy depends on your build.

## Build-Specific Strategies

### 1. TANK build (Tobor / Bulwark — healers & tanks)
**Goal:** survive long enough to out-troll the waves.
- **Early (waves 1-5):** prioritize **side quests** for free XP/gold while the waves are still small. Quests are low-risk and give steady XP. Don't chase camps yet — you're not strong enough for the elites.
- **Mid (waves 5-10):** start hitting **camps** between waves. The elites give 2-4× the XP of a normal kill. Your tankiness means you can solo a 3-elite camp without dying.
- **Late (waves 10+):** camp becomes the primary XP source. Quests still for gold. Center waves only to trigger boss.
- **Best upgrades:** `vitality`, `plating`, `ironhide`, `fortress` (HP), `flow` (heal), `boots` (speed).

### 2. TEMPO/Crit build (Cinder / Arclight — fast attackers)
**Goal:** kill everything as fast as possible; time = kills.
- **Early:** **center waves only.** Your high attack speed means you clear waves fastest, so you get to the next wave faster. Camps are too slow for your style.
- **Mid:** **camps** become very efficient — you one-shot the elites. Quests only if they're `stand` (buff) type.
- **Late:** camp → wave → camp loop. Your crits make camp elites trivial.
- **Best upgrades:** `rapid`, `overclock`, `haste` (AS), `keen_eye`, `lucky_strike`, `headhunter` (crit), `double_tap`, `echo_shot`.

### 3. RANGED/Volley build (Astral / Volt — AoE & range)
**Goal:** kill from distance, never get touched.
- **Early:** **center waves** but keep range. Your `reach` + `volley` means you clear waves without losing HP. Camps are dangerous (elites close the gap).
- **Mid:** **camps** once you have `reach` + `extra_bolt` + a drone. The drone holds elites while you snipe.
- **Late:** camp + quest mix. `rescue` quests are great for you (defend the NPC from range).
- **Best upgrades:** `reach`, `extra_bolt`, `split_shot`, `volley`, `blast`, `aftershock`, `nova_core`, `gun_drone`, `laser_drone`.

## Quest Reward Tiers (which quests are worth the detour)

**S-tier (always do):** `rescue_scout` (100g/70xp), `dance_giggle` (95g/70xp + buff), `kill_marked` (80g/55xp + you kill anyway), `collect_coins` (70g/20xp — pure gold, no risk)
**A-tier (do if nearby):** `smash_idol` (60g/40xp), `chase_wisp` (50g/44xp + speed buff), `stand_beacon` (50g/36xp + damage buff), `visit_runes` (52g/44xp)
**B-tier (skip if far):** `chase_butterfly`, `collect_shards`, `smash_crate`, `stand_cairn` — low reward, high detour
**C-tier (only for heal):** `stand_spring` (0g/24xp + 40 heal) — do ONLY when HP < 50%

## Creep Camp Economics

Each camp has 3 elites (2-4× HP). Killing all 3 gives ~3× the XP of a normal wave kill + camp Gold. **Break-even:** a camp is worth it if you're within 15s of travel time AND your HP > 60%. The 45s respawn timer means: if you kill a camp, the next time you return it's full again — so camps are a renewable XP farm.

**Camp + Build synergy:**
- Tank build: `fortress` + camp = you can solo even a 4× HP brute.
- Tempo build: `headhunter` + camp = elites die in 2 crits.
- Ranged build: `laser_drone` + camp = drone tanks the elite while you snipe.

## The Wave-20 Path (concrete plan)

```
Wave 1-3:   Center waves + S-tier quests (build base XP/gold)
Wave 4-6:   Start camp loops between waves (XP snowball)
Wave 7-9:   Camps primary, quests secondary, upgrades focused
Wave 10-14: Camps + boss kills (boss = big XP + item)
Wave 15-20: Camps only; quests only for heal; pure kill-streak
```

**XP budget to wave 20:** ~3,500 XP total. Camps give ~150 XP/clear × 8 clears = 1,200. Waves give ~100/wave × 20 = 2,000. Quests give ~50 × 10 = 500. Total ≈ 3,700. **Feasible if the bot camps at least 8 times.**

## Bot AI Implications (what the selftest bot should do)

1. **Quest priority:** when HP > 60% and a S/A-tier quest is within 200px, do it. (Currently: bot does this with QUEST_FOCUS_WINDOW=9s.)
2. **Camp priority:** when HP > 60% and no quest active, walk to nearest camp and clear it. (Currently: NOT implemented — bot ignores camps.)
3. **Wave priority:** if wave in progress and HP > 40%, stay and fight. If HP < 40%, kite to heal orb.
4. **Camp awareness:** the bot should track camp positions and insert camp-clears between waves.

## Open Items / Next Steps

- [ ] Add **camp-seeking behavior** to the survival AI (biggest win for wave-20)
- [ ] Add **quest tier awareness** (bot should prefer S/A-tier, skip B/C unless healing)
- [ ] Add **camp respawn timer** to the minimap (show how long until next camp is full)
- [ ] Add **quest reward preview** to the toast (show XP/gold so player knows the value)
- [ ] Verify quest diversity over a 20-minute run (bot currently sees 1-2 quest types in short runs)
- [ ] Test FFA mode with the new build picker (4 bots, each with a different build)
