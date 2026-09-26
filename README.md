# Olympus PVP

World of Warcraft Forever addon: sticky PVP raid frames, a gank list with raid warnings and coordinates, and player-clicked `/targetexact` targeting.

This is a separate addon from Asmon Finder. Copy the `OlympusPVP` folder into `Interface/AddOns`.

## Commands

- `/olympus` or `/opvp` — open or close settings
- `/olympus pvpclear` — clear raid frames
- `/olympus reset` — restore defaults
- `/olympus help`

## Behavior

- Combat with another player, targeting them, or being targeted by them adds a raid frame
- Frames stay in the same slot until you remove them, leave a battleground, reload, or hit the 40 cap
- At 40, the stalest name is dropped for a fresh opponent
- Columns of 5; frames shrink 10 pixels every 10 people
- Gank-list names get a raid warning, coordinates, and a Target queue
- Targeting is click-only. The addon never calls protected target APIs from the scanner

## Tests

From this folder:

```
busted tests
```
