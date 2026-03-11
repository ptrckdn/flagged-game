# Phase Status

## Phase 1
- [x] World generation with distinct districts and connected roads.
- [x] Player walk/sprint with collision against non-walkable map tiles.
- [x] Vehicle entry/hotwire/driving/reverse/exit.
- [x] Parked car spawning with random colors.
- [x] NPC pavement patrol + car-proximity scatter.
- [x] Interior transitions via interactable doors.

## Phase 2
- [x] Persistent Civility Index HUD and tier color thresholds.
- [x] Dialogue choices with meter deltas and outcomes.
- [x] Tier-based consequence logic and notifications.
- [x] Meter reduction via workshop/compliance/bribery interactables.
- [x] Passive accumulation (movement repetition, social burst, curfew, restricted area).

## Phase 3
- [x] Police pursuit spawning/escalation.
- [x] Police vehicle AI pursuit and LOS timeout behavior.
- [x] Capture consequence pipeline integrated with mission fail path.

## Phase 4
- [x] Mission definitions for all 8 missions.
- [x] Sequential unlocks and mission selection UI.
- [x] Objective executor for location/collect/deliver/interact/escape/survive_time.
- [x] Prototype mission complications for higher-tier missions.

## Phase 5
- [x] Title screen and pause menu.
- [x] Visual notification and HUD polish hooks.
- [ ] Full SFX asset integration (event scaffolding complete, assets pending).

## Phase 6
- [x] Money rewards/spending hooks and robbery action.
- [x] Inventory carry mechanics and confiscation.
- [x] Safe meter-reduction economy interactions.
- [ ] Full purchasable item storefront/garage flow (hook-ready, not fully authored).

## Validation
Because Godot runtime is unavailable in this environment, run in-editor playtests for:
1. Vehicle feel tuning (acceleration/turn/drift) and map readability.
2. Tier threshold transitions and stop/chase cadence.
3. Full mission chain from `m1_induction` to `m8_broadcast_day`.
4. Save/load after interior entry and mission progression persistence.
