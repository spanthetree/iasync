<div align="center">
  <img src="header.svg" alt="iasync" width="860"/>

**Your whole Elder Scrolls Online account, exported to one local file.**

[![License: MIT](https://img.shields.io/badge/license-MIT-lightgrey)](LICENSE)

[Getting started](#getting-started) ·
[FAQ](docs/faq.md) ·
[Schema](docs/schema.md) ·
[Changelog](CHANGELOG.md)

</div>

ESO has no API for reading character data outside the game. The only
supported way to get data out is an addon's SavedVariables file, which the
game writes to disk. iasync reads the game's own APIs and writes a structured
snapshot of every character you log into: gear, storage, builds, achievements,
collections and progress. It is the data source for
[ESO Armory](https://github.com/spanthetree/eso-armory), a web app for
browsing all of it from a browser, and any tool that reads a Lua table can use
it too.

iasync is read-only. It never changes your inventory, builds or any other game
state, adds no in-game UI and has no library dependencies.

## Features

- **Characters.** Equipped gear and backpack, with trait, enchant, set,
  quality, armor weight, weapon type and icon for every item. Also level,
  Champion Points, title, zone, riding skill, guild ranks, Alliance War rank
  and every currency.
- **Builds.** Front, back and werewolf bars (scribed skills resolved to their
  base ability), slotted Champion stars, attributes, maximum resources and
  active Mundus Stone(s), with skill names and icons.
- **Armory builds.** Every build saved at an in-game Armory station: gear and
  where each piece is now, bars, Champion stars and points per discipline,
  attributes, skill points, Mundus Stone(s), curse and outfit.
- **Storage.** Bank, ESO Plus bank, craft bag, house storage chests and guild
  banks.
- **Achievements.** Every achievement with criteria progress, rewards,
  completion date and the character who earned it, with category totals that
  match the in-game summary.
- **Collections.** Set collection pieces, the Collections tree (mounts, pets,
  costumes, houses, outfit styles, Tales of Tribute patrons) and antiquities.
- **Crafting.** Trait research (including research in progress), known motif
  chapters and recipes, and unlocked scribing grimoires and scripts.
- **Activities.** Daily and weekly Endeavors, Tamriel Tome challenges and
  pass, and Golden Pursuits campaigns, with progress toward each.

## Privacy

Everything stays on your computer. iasync makes no network requests; it only
writes the SavedVariables file, like every other addon. What reads that file
is up to you.

## Getting started

**1. Install.** Copy the `iasync` folder into
`Documents\Elder Scrolls Online\live\AddOns\`.

**2. Enable.** Start ESO and tick **iasync** in the AddOns menu on the
character select screen.

**3. Play.** Log in to each character you want exported. Open your bank once,
view each guild bank, and enter your houses to capture their storage. The
data is written to
`Documents\Elder Scrolls Online\live\SavedVariables\iasync.lua` when you log
out, switch characters or type `/reloadui`.

Requires ESO on PC or Mac, API version `101051` (Update 51) or later.

### When data is captured

| When | What |
|---|---|
| Login, `/reloadui`, zone change | The character, its build and Armory builds, currencies and details; then achievements, activities, scribing, antiquities, set collections and collectibles over the next 9 seconds |
| Entering a house you own | Its storage chests |
| Opening the bank | Bank, ESO Plus bank, craft bag, banked currencies |
| Viewing a guild bank | That guild's bank, and again after deposits or withdrawals |
| Saving, restoring or renaming an Armory build | All Armory builds |
| Any inventory change, earning an achievement, activity progress | The change, as it happens |

To rescan the current character on demand, type `/script iasync_scan()` in
chat.

## Known limitations

- **One character at a time.** ESO only exposes the logged-in character, so
  log in to each character once to export it.
- **Skill names** resolve only for the logged-in character's own skills.
- **Armory skill bars and Champion stars** load only after you visit an Armory
  station. Until then iasync keeps the last ones it read.
- **An Armory item sold or deconstructed** since the build was saved shows as
  missing, with no item details.
- **Guild banks** are captured only after you view them, and only if your rank
  can see their contents.
- **Achievement attribution:** the character who earned an account-wide
  achievement is reported only when ESO can resolve it.

## Documentation

| | |
|---|---|
| [FAQ](docs/faq.md) | What iasync does, how it works, privacy, troubleshooting |
| [Schema](docs/schema.md) | Every field in the SavedVariables file |
| [Game API reference](docs/api.md) | Which ESO functions and events feed each part of the file |
| [Changelog](CHANGELOG.md) | What changed in each release |
| [AGENTS.md](AGENTS.md) | Coding guide: API notes, invariants, event flow |

## Related projects

| | |
|---|---|
| [ESO Armory](https://github.com/spanthetree/eso-armory) | The web app that reads this file and shows your account in a browser |
| [Wizard's Wardrobe](https://www.esoui.com/downloads/info3170-WizardsWardrobe.html) | Optional. If installed, iasync reads the logged-in character's saved setups, read-only, to name and icon the skills in them |
| [esoui/esoui](https://github.com/esoui/esoui) | ZeniMax's UI source and `ESOUIDocumentation.txt`, the reference for every API iasync calls. The Armory's "inaccessible" rule for house-chest items follows its base UI |
| [UESP](https://en.uesp.net/wiki/Online:Online) | Not used by iasync. The icon paths it exports are game texture paths; UESP mirrors those images at [esoicons.uesp.net](https://esoicons.uesp.net/), which is where ESO Armory gets them |

## Development

iasync is one Lua file, `iasync.lua`, running on ESO's Lua 5.1. The API it targets is documented in `ESOUIDocumentation.txt` on the `live` branch of [esoui/esoui](https://github.com/esoui/esoui). Check syntax
and run the mocked tests from the repository root:

```bash
luac5.1 -p iasync.lua
lua5.1 tests/ability_metadata.lua
lua5.1 tests/armory_builds.lua
```

In game, `/script iasync_scan()` reruns the scans and `/reloadui` writes the
file. If you edit `iasync.lua` while the game is running, reload twice: the
first reload saves the data from the old code and loads the new code, and the
second writes what the new code scanned.

Schema changes must be matched in ESO Armory's `data_processor.py`. See
[AGENTS.md](AGENTS.md) before making changes.

## License

[MIT](LICENSE).

iasync is not affiliated with, endorsed by or sponsored by ZeniMax Online
Studios, ZeniMax Media or Bethesda. The Elder Scrolls Online is a trademark of
ZeniMax Media Inc.
