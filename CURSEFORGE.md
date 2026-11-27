**Spec-aware gear upgrade advice for World of Warcraft: Forever.** A lightweight Pawn replacement that only scores gear for the spec you are actually playing, detected from your talents.

## Features

- **Tooltip verdict on every piece of gear**: upgrade, worse, about the same, or equipped, with the stat changes that decided it and the gain as a percentage of your whole kit.
- **Upgrade arrows** on Bagnon bag slots, quest rewards, and recipes in the profession window.
  - Green: an upgrade for your active profile.
  - Orange: an upgrade only for your other profile (for example a tanking piece while you are solo).
  - Dimmed arrow with a number: a recipe that becomes an upgrade at that level.
  - "equipped": a recipe for something you already wear.
- **Craft for other players**: inspect someone, click the BetterGearing icon in the inspect window's title bar, and your recipe list shows which of your recipes would be upgrades for them.
- **Previews for your alts**: `/bgear view <character>` judges items against another of your characters' gear, handy while crafting or shopping for them.
- **Sensible rules**: items you can't equip, and items whose stats are mostly wasted on your spec (spell power on a hunter), are never suggested.
- **Tunable stat weights** for every class and spec, editable in game with `/bgear`.

## Supported specs

Every class and talent tree has a profile. Protection warriors get separate tanking and solo profiles, chosen automatically by whether you are in a group, and feral druids get cat and bear profiles.

## Commands

| Command | Effect |
|---|---|
| `/bgear` | Open the stat weight window |
| `/bgear status` | Show the detected spec and active profile |
| `/bgear spec <name\|auto>` | Force a spec, or go back to talent detection |
| `/bgear profile <id\|auto>` | Force a profile such as `tank` or `solo` |
| `/bgear view <character>` | Judge items for one of your other characters |
| `/bgear view target [spec]` | Inspect your target and judge items for them |
| `/bgear view <class> [spec]` | Show item scores for any spec |
| `/bgear view off` | Stop previewing |

## Notes

- Bagnon is optional, and needed only for bag arrows. Disable Pawn to avoid two sets of arrows.
- English client only: stats are read from tooltip text.
- Trinkets and "Use:" / "Chance on hit" effects are not scored.
- Default weights are starting estimates based on leveling stat priorities; tune them to taste.

Source and issues: [GitHub](https://github.com/ohflargen/bettergearing)
