# BetterGearing

Spec-aware gear upgrade advice for World of Warcraft: Forever. A replacement for Pawn that only scores gear for the spec you are actually playing.

## What it does

- **Scores gear for your current spec**, detected from your talent points.
- **Tooltip verdict** on every piece of gear: upgrade, worse, or about the same, with the stat changes that decided it.
- **Upgrade arrows** on Bagnon bag slots and on quest reward buttons.
  - Green: an upgrade for your active profile.
  - Orange: an upgrade only for your other profile (for example a tanking piece while you are solo).
- **Sanity rules before scoring**: items you cannot equip, and items whose stats are mostly wasted on your spec (spell power on a hunter), are never suggested.
- **Tunable weights**: every stat weight can be changed in game and is saved account-wide.
- **Previews for other characters**: while crafting or shopping for an alt, `/bgear view <name>` adds that character's verdict to tooltips, compared with the gear they wore when last logged in. Each character is remembered once it has logged in with BetterGearing enabled.
- **Upgrade percentages** are measured against everything you wear, not just the item being replaced, so a small gain over a starter item is not shown as +200%.

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

Copy this folder into `World of Warcraft\_forever_\Interface\AddOns\` as `BetterGearing`, and disable Pawn. Bagnon is optional but needed for bag arrows.

## Commands

| Command | Effect |
|---|---|
| `/bgear` | Open the weight tuning window |
| `/bgear status` | Show the detected spec, active profile and Bagnon hook state |
| `/bgear spec <name\|auto>` | Force a spec, or go back to talent detection |
| `/bgear profile <id\|auto>` | Force a profile such as `tank` or `solo` |
| `/bgear view <character>` | Also judge items for one of your other characters, against their gear |
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
