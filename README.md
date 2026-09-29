# Avatar Continued

Shows your character model on screen as a decorative part of your World of
Warcraft UI.

Why spend hours and thousands of gold on a transmog set and then never see it
properly? Avatar puts your character on screen, where it can be moved, scaled
and rotated to fit any UI, relit to taste, posed, and dressed in any saved
Wardrobe outfit.

Avatar Continued revives the original Avatar addon by Sonaza (last updated for
Battle for Azeroth) for World of Warcraft 12.1, with the original author's
permission.

**[Download on CurseForge](https://www.curseforge.com/projects/1533608)**

## Features

- **Place it anywhere** — move, resize, rotate and zoom your character, with
  anchor, layer and opacity settings to fit any UI
- **Lighting** — ambient and direct light colour and intensity, plus the
  light's direction
- **Poses** — idle, walk, talk, dance, attack, spell cast, and emotes like
  wave, cheer, laugh, salute, sit, kneel and lie down
- **Reactions** — your avatar dances when you finish a key or earn an
  achievement, casts when you level up and falls down when you die (getting
  back up once you're alive). Each can be changed or turned off
- **Outfits** — dress your avatar in any saved Wardrobe outfit, or try on any
  item with `/avatar equip`
- **An outfit per specialization** — set each spec's outfit, with a preview,
  without switching spec; it goes on when you switch
- **Gear** — show or hide your weapons, armor, shirt, tabard and helm
- **Hide in combat**, if you'd rather it got out of the way
- **Profiles** per character or shared across all of them, with a live preview
  while you set it up

## Usage

| Command | What it does |
|---------|--------------|
| `/avatar` or `/av` | Open the settings window |
| `/avatar toggle` | Show or hide the avatar |
| `/avatar toggle weapon\|armor\|tabard` | Show or hide that part of your gear |
| `/avatar unlock` / `/avatar lock` | Unlock to move (left drag), resize (right drag) and rotate (mouse wheel) |
| `/avatar profile <name>` | Switch profile |
| `/avatar equip <item link or item ID>` | Try an item on the avatar |
| `/avatar anim <id>` | Play any animation by its ID |
| `/avatar notes` | What's new in this version |
| `/avatar help` | List the commands in game |

Settings are also reachable from Options > AddOns > Avatar Continued.

## Dependencies

None to install. The Ace3 libraries it uses (LibStub, CallbackHandler, AceAddon,
AceDB, AceEvent) are bundled in `libs/`.

## Releases

Published to [CurseForge](https://www.curseforge.com/projects/1533608) (project
1533608) from tagged versions of this repository.

## Support

If you enjoy using Avatar Continued, consider supporting development on
[Ko-fi](https://ko-fi.com/squizz) ❤️

## More addons by Squizz

- **[SquizzFrames](https://www.curseforge.com/projects/1649203)** — party, raid, pet and unit frames with a full indicator system, click-casting and a tank tracker
- **[Squizzumables](https://www.curseforge.com/projects/1483099)** — one-click reminders for food, flasks, oils and class buffs, plus raid tools and a restyled Cooldown Manager
- **[Squizzcap](https://www.curseforge.com/projects/1713974)** — what killed you, how hard it hit and how fast you went down, with every death of a key saved to look back on
- **[SquizzTalents](https://www.curseforge.com/projects/1705647)** — all your talent builds in one list, with a reminder when your build doesn't match the content
- **[DPS Report](https://www.curseforge.com/projects/1504877)** — a lightweight damage meter with spell breakdowns and an end-of-key MVP summary
- **[KSLBestDungeon](https://www.curseforge.com/projects/1599575)** — ranks Mythic+ dungeons by how many of your KeystoneLoot favorites drop there

## License

MIT, covering both Sonaza's original addon and the Avatar Continued changes --
see [LICENSE](LICENSE). The bundled Ace3 libraries in `libs/` keep their own
licences.
