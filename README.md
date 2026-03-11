# FLAGGED (Godot 4 Prototype)

Top-down open-world action prototype with a Civility Index system, chase escalation, dialogue risk/reward, linear missions, and economy hooks.

## Run
1. Open this folder in Godot 4.2+.
2. Main scene: `res://scenes/title/title_screen.tscn`.
3. Press any key on title.

## Controls
- Move: `WASD` / arrow keys
- Interact / enter-exit vehicles: `E`
- Sprint: `Shift`
- Special action (robbery prototype): `F`
- Horn: `H`
- Pause: `Esc`
- Inventory: `Tab`

## Implemented Systems
- Procedural 96x96 city tilemap with district layout, roads, roundabouts, park, water, alleys.
- On-foot movement and camera follow smoothing.
- Stealable vehicles with hotwire delay, arcade handling, drift, damage and disable state.
- Civilian NPC patrols on pavement and scatter behavior when player drives nearby.
- Persistent HUD: Civility Index bar, money, mission objective text, notification queue, minimap.
- Dialogue system from `data/dialogues.json` with meter-cost choices and outcomes.
- Meter tiers (Green/Amber/Red/Black), passive accumulation, stop events, helicopter notifications.
- Police vehicle pursuit spawning/escalation and capture consequences by tier.
- Mission system with 8 missions loaded from `data/missions.json` and objective markers.
- Mission giver list UI (completed/current/locked).
- Interior scenes (flat/pub/shop) and world doors.
- Meter reduction interactions: workshop, compliance terminal, bribery terminal.
- Save/load one-slot JSON (`user://savegame.json`).
- Economy hooks: mission rewards, robbery income, bribery spending, contraband confiscation.

## Data Files
- `data/dialogues.json`
- `data/missions.json`
- `data/items.json`

## Notes
- Audio events are stubbed via `AudioSystem.play_event(...)` for quick SFX integration.
- Some advanced mission complications are represented as scripted prototype triggers rather than full bespoke set-pieces.
