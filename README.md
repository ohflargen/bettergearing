# BetterGearing

Spec-aware gear upgrade advice for World of Warcraft: Forever. A replacement for Pawn that only scores gear for the spec you are actually playing.

## What it does

- **Scores gear for your current spec**, detected from your talent points.
- **Tooltip verdict** on every piece of gear: upgrade, worse, about the same, or equipped, with the stat changes that decided it.
- **Upgrade arrows** on Bagnon bag slots, on quest reward buttons, and after recipe names in the profession window. Recipes for an item you already wear show "equipped" instead, and a dimmed arrow with a level number marks a recipe that becomes an upgrade at that level (up to 5 levels ahead).
  - Green: an upgrade for your active profile.
  - Orange: an upgrade only for your other profile (for example a tanking piece while you are solo).
- **Sanity rules before scoring**: items you cannot equip, and items whose stats are mostly wasted on your spec (spell power on a hunter), are never suggested.
- **Tunable weights**: every stat weight can be changed in game and is saved account-wide.
- **Previews for other characters**: while crafting or shopping for an alt, `/bgear view <name>` adds that character's verdict to tooltips, compared with the gear they wore when last logged in. Each character is remembered once it has logged in with BetterGearing enabled. While a preview is on, the recipe list's arrows are for that character too.
- **Crafting for other players**: inspect someone and click the BetterGearing icon in the inspect window's title bar, next to the close button (or `/bgear view target`). Tooltips and your recipe list then show which of your recipes would be upgrades for them, and a line above the recipe search box names whose upgrades the arrows show. Their spec is read from their talents; if it can't be, or they play another spec, set it with `/bgear view target <spec>` (for example `holy`). Click the icon again, or `/bgear view off`, to go back to your own upgrades.
- **Upgrade percentages** are measured against everything you wear, not just the item being replaced, so a small gain over a starter item is not shown as +200%.

## How scoring works

Each profile gives every stat a weight: how much one point of that stat is worth to the spec (for percent stats such as crit, one percent). An item's **score** is each of its stats multiplied by its weight, added up. For example, with agility at 1.0, attack power at 0.5 and stamina at 0.1, an item with +10 agility, +20 attack power and +5 stamina scores 10 + 10 + 0.5 = 20.5.

The tooltip turns that into a verdict:

- **upgrade +X / worse -X**: the item's score minus the score of what it would replace. For rings, trinkets and one-handers that can go in two slots, it is compared against whichever slot gains the most.
- **The percentage**: that difference against the total score of all your worn gear, so a small gain over a nearly worthless starter item is not shown as +200%.
- **about the same**: less than 0.1 worse and not enough better to count (more than 0.1, and more than 1% of what it replaces).
- **equipped (score X)**: you are already wearing this item (another copy counts too); X is its own score.

Scores are relative numbers with no fixed scale, and only mean something within one profile: the same item scores differently for a tank and a damage dealer. Weights can be changed in the tuning window (`/bgear`) and are saved account-wide.

## Supported specs

Every class and talent tree has a profile:

| Class | Specs | Profiles |
|---|---|---|
| Druid | Balance, Restoration | One each |
| Druid | Feral | Cat (default), Bear (`/bgear profile bear` while tanking) |
| Hunter | Beast Mastery, Marksmanship, Survival | One each |
| Mage | Arcane, Fire, Frost | One each |
| Paladin | Holy, Protection, Retribution | One each |
| Priest | Discipline, Holy, Shadow | One each |
| Rogue | Assassination, Combat, Subtlety | One each |
| Shaman | Elemental, Enhancement, Restoration | One each |
| Warlock | Affliction, Demonology, Destruction | One each |
| Warrior | Arms, Fury | One each |
| Warrior | Protection | Tanking (in a group or dungeon), Solo (otherwise) |

Profiles live in `Profiles.lua`.

## Install

Install from [CurseForge](https://www.curseforge.com/projects/1830475), or copy this folder into `World of Warcraft\_forever_\Interface\AddOns\` as `BetterGearing`. Disable Pawn. Bagnon is optional but needed for bag arrows.

## Releasing

1. Add the new version's notes to the top of `CHANGELOG.md`; they become the CurseForge and GitHub release notes.
2. Commit, then push a tag that starts with `v`:

```
git tag v0.3.0
git push origin main v0.3.0
```

A GitHub Action (`.github/workflows/release.yml`) runs the [BigWigs packager](https://github.com/BigWigsMods/packager), which builds the zip, stamps the tag into the toc's `@project-version@`, uploads it to CurseForge (project 1830475, using the `CF_API_KEY` repository secret) and attaches it to a GitHub release. Tags containing `alpha` or `beta` are uploaded as alpha or beta files.

The CurseForge project description is not uploaded by the packager. Its text lives in `CURSEFORGE.md`; paste it into the project's description editor (Markdown) when it changes.

## Commands

| Command | Effect |
|---|---|
| `/bgear` | Open the weight tuning window |
| `/bgear status` | Show the detected spec, active profile and Bagnon hook state |
| `/bgear spec <name\|auto>` | Force a spec, or go back to talent detection |
| `/bgear profile <id\|auto>` | Force a profile such as `tank` or `solo` |
| `/bgear view <character>` | Also judge items for one of your other characters, against their gear |
| `/bgear view target [spec]` | Inspect your target and judge items for them, against the gear they wear now. Give a spec if their talents can't be read |
| `/bgear view <class> [spec]` | Also show item scores for any spec, such as `mage arcane` |
| `/bgear view off` | Stop previewing |
| `/bgear set <stat> <value>` | Change one weight on the active profile |
| `/bgear reset` | Reset the active profile to default weights |
| `/bgear debug [item link]` | List the stats read from an item |

## Limitations

- English client only: stats are read from tooltip text.
- Trinkets, "Use:" effects and "Chance on hit" effects are not scored.
- Hit keeps its full value past the cap; lower the weight by hand once capped.
- Default weights are starting estimates based on published leveling stat priorities, not simulations.
