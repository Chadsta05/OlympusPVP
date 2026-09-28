# Olympus PVP

Builds a clickable enemy and friendly roster from players in range, so world and battleground PvP is easier to track.

You get two boards: enemies in red, friendlies in blue. Each person is a small frame with name, level, class color, health, and mana/energy/rage. Click a frame to target them. Hit X if you want them gone. Pause stops new names from being added so a packed board does not keep growing.

People who leave range drop off after about ten seconds and can show up again when they come back. At around fifteen names the boards shrink and stack into taller columns so they do not eat the whole screen.

There is also a watch list for names you care about, with an optional prompt when you die in the open world asking if you want to mark who hit you. Friendly boards can be turned off if you only want enemies.

Made for Forever’s full character names. Drag the headers to put the boards where you like.

This is a separate addon from [Asmon Finder](https://github.com/Chadsta05/AsmonGoldFinder).

## Install

Copy the `OlympusPVP` folder into your AddOns directory (not `tests` or `.git`):

```text
World of Warcraft/_classic_beta_/World of Warcraft/_classic_beta_/Interface/AddOns/OlympusPVP
```

Enable **Olympus PVP** at the character select AddOns screen. `/reload` after updates.

## Commands

- `/olympus` or `/opvp` — open or close settings
- `/olympus pvpclear` — clear the boards
- `/olympus reset` — restore defaults
- `/olympus help`

## License

Use and share the addon as you like. Please keep credit to Chadsta05 if you redistribute it.
