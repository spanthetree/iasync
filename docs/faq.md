# FAQ

## What does iasync do?

It records what the game knows about your account into a file on your
computer: every character's gear, bags, builds, Armory builds, currencies,
crafting knowledge and progress, plus account-wide storage, achievements and
collections. It is meant to be read by
[ESO Armory](https://github.com/spanthetree/eso-armory), but the file is plain
Lua, so any tool can read it. The full list of fields is in the
[schema](schema.md).

## Does it change anything in my game?

No. iasync only reads. It never moves items, equips gear, changes builds or
sends anything to the game server, and it adds no windows or buttons. The
only sign it is running is a few `[iasync]` lines in chat after each scan.

## Does it upload my data anywhere?

No. iasync makes no network requests; ESO addons cannot. It writes one file,
`Documents\Elder Scrolls Online\live\SavedVariables\iasync.lua`, the same way
every addon saves its settings. Nothing leaves your computer unless you, or a
tool you run, send it.

## How does it work?

ESO lets addons read game data through its Lua API, and lets each addon keep a
table that the game saves to disk. iasync scans the game state when you log
in, reload the UI or change zone, staggering the scans over a few seconds so
data the game loads late (house chests, set collections) is ready. After that
it listens for game events, such as an inventory change, opening the bank or
earning an achievement, and updates only what changed.

The game writes the file to disk when you log out, switch characters or type
`/reloadui`, never while you play. Until then the newest data exists only in
memory.

## Does it need other addons?

No. It has no dependencies. If [Wizard's Wardrobe](https://www.esoui.com/downloads/info3170-WizardsWardrobe.html) is installed, iasync also reads
the logged-in character's saved Wizard's Wardrobe setups, without changing
them, so the skills in those setups get names and icons in
[ESO Armory](https://github.com/spanthetree/eso-armory).

## Why do I have to log in to every character?

ESO's API only exposes the character you are logged in as. iasync keeps each
character's data once it has seen it, so a single login per character is
enough; log in again whenever you want that character refreshed.

Bank contents, the craft bag and house chests are account-wide, but the game
only loads them when you open the bank or enter the house.

## Why are my Armory builds missing their skills?

The game only loads Armory skill bars and Champion stars once you have visited
an Armory station in this session. Everything else in a build (gear,
attributes, Mundus Stone) loads anywhere. Visit a station once and reload; from
then on iasync keeps the last bars it read, even when you scan elsewhere.

## Why is a piece of Armory gear listed as missing?

The Armory remembers the exact copy of each item, not just its set and slot.
If that copy was sold, deconstructed, or swapped for another copy of the same
item, the game can't find it, even when a lookalike sits in your bank, and it
gives no details about what it was. Items in your bank still count: the game
finds them there and lists their location.

If iasync scanned the build while the item still existed, it keeps that item
as `lastKnown`, so ESO Armory can show what used to be in the slot. To clear
the warning in game, equip the replacements and save over the build at an
Armory station.

Items in a house chest show as inaccessible: they still exist, but the Armory
can't equip them from there.

## Do I need to reload twice?

Only if you update iasync while the game is running. The first `/reloadui`
saves the data collected by the old version and loads the new one; the second
writes what the new version scanned. After a normal login, nothing extra is
needed.

## How do I update the data?

Play normally. For a fresh snapshot of the current character without
logging out, type `/reloadui`, or `/script iasync_scan()` followed by
`/reloadui`.

## Will it slow down my game?

Unlikely. The full scan runs once per login, reload or zone change and is
spread over about 9 seconds. Later updates touch only what changed. The file
grows with your account; a large account with many achievements and
collections is around 20 MB.

## A deleted character still shows up. How do I remove it?

iasync never deletes a character's data, because a character it can't see may
just be one you haven't logged into. To start fresh, quit the game, delete
`SavedVariables\iasync.lua`, then log in to each character again. Deleting
the file while the game is running does nothing: the game writes it back on
the next reload.

## Does it work on console?

No. Addons are only available on PC and Mac.

## Is it allowed?

iasync uses only the public addon API, under the
[ZeniMax addon terms](https://account.elderscrollsonline.com/add-on-terms). It
reads data the game already shows you and automates nothing.
